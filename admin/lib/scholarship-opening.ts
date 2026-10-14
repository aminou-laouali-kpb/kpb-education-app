/**
 * Annonce d'ouverture d'une bourse suivie (chantier C) — règles d'affichage
 * du back-office.
 *
 * Ce module ne DÉCIDE rien : le serveur compte l'audience, refuse ce qui ne
 * doit pas partir (seuil, rôle, cycle pré-existant, audience qui a grossi) et
 * programme l'envoi. Il ne fait que (1) bâtir les corps d'écriture à partir de
 * ce que l'équipe a sous les yeux, (2) rendre lisibles les réponses et les
 * erreurs du serveur, et (3) formuler les libellés. Tout y est pur pour être
 * testé sans navigateur (vitest tourne en environnement node).
 *
 * Vocabulaire du rapport : « acceptées par le fournisseur », jamais « reçues »
 * ni « délivrées » — un 200 de FCM ou de OneSignal ne dit pas que le téléphone
 * a affiché quoi que ce soit.
 */

import type { ApiError } from './api-client';
import {
  OPENING_AUDIT_ACTIONS,
  OPENING_ERROR_CODES,
  OPENING_EVENT_OUTCOMES,
  OPENING_SCHEDULE_END_ACTIONS,
  type ActivateScholarshipBody,
  type ActivateScholarshipResponse,
  type CycleOpeningSkipReason,
  type LocalizedPushCopy,
  type OpeningAudienceScope,
  type OpeningAudienceSummary,
  type OpeningAuditAction,
  type OpeningErrorCode,
  type OpeningEventOutcome,
  type OpeningOverviewItem,
  type OpeningPreviewCopy,
  type OpeningPreviewCycle,
  type OpeningPreviewQuery,
  type OpeningPreviewResponse,
  type OpeningRecentEvent,
  type OpeningReportResponse,
  type OpeningTodoItem,
} from './scholarship-opening-types';

/** Le `t()` de `useLocale()` : clé pointée → texte (la clé si absente). */
export type Translate = (key: string) => string;

/** Après une saisie d'année ou de date, l'aperçu se recalcule après ce délai. */
export const PREVIEW_DEBOUNCE_MS = 400;
/** Le rapport est relu à ce rythme tant que des push attendent… */
export const REPORT_POLL_INTERVAL_MS = 5_000;
/** … pendant au plus 10 minutes ; ensuite, bouton « Actualiser ». */
export const REPORT_POLL_MAX_MS = 10 * 60_000;

/**
 * Remplace chaque `{nom}` du gabarit. Un nom absent de `values` reste tel quel :
 * une variable oubliée se voit à l'écran au lieu de disparaître en silence.
 */
export function fill(
  template: string,
  values: Readonly<Record<string, string | number>>,
): string {
  return template.replace(/\{(\w+)\}/g, (match, name: string) =>
    Object.prototype.hasOwnProperty.call(values, name)
      ? String(values[name])
      : match,
  );
}

// ── Brouillon de cycle et corps d'écriture ─────────────────────────────────

/** Les champs du panneau, au format des `<input type="date">` (`yyyy-mm-dd`). */
export interface OpeningDraft {
  academicYear: string;
  estimatedOpenAt: string;
  estimatedCloseAt: string;
  opensAt: string;
  closesAt: string;
  sourceUrl: string;
}

const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function dayOf(iso: string | null | undefined): string {
  return iso ? iso.slice(0, 10) : '';
}

/** Début du jour UTC : l'admin enregistre l'ouverture à `T00:00:00.000Z`. */
export function startOfDayIso(day: string): string {
  return `${day}T00:00:00.000Z`;
}

/** Fin du jour UTC : la clôture est stockée à `T23:59:59.999Z`. */
export function endOfDayIso(day: string): string {
  return `${day}T23:59:59.999Z`;
}

/**
 * Le brouillon d'une année : les dates du cycle s'il existe, vides pour un
 * nouveau cycle (la date limite de la fiche appartient au cycle précédent).
 * La source saisie est gardée d'une année à l'autre.
 */
export function draftForCycle(
  academicYear: string,
  cycle: OpeningPreviewCycle | undefined,
  sourceUrl: string,
): OpeningDraft {
  return {
    academicYear,
    estimatedOpenAt: dayOf(cycle?.estimatedOpenAt),
    estimatedCloseAt: dayOf(cycle?.estimatedCloseAt),
    opensAt: dayOf(cycle?.opensAt),
    closesAt: dayOf(cycle?.closesAt),
    sourceUrl,
  };
}

/** La clé de message d'une ouverture incomplète, ou `null` si elle est valide. */
export function activationDraftError(draft: OpeningDraft): string | null {
  if (
    !draft.academicYear ||
    !DAY_PATTERN.test(draft.opensAt) ||
    !DAY_PATTERN.test(draft.closesAt)
  ) {
    return 'scholarships.activationValidationError';
  }
  if (Date.parse(endOfDayIso(draft.closesAt)) <= Date.parse(startOfDayIso(draft.opensAt))) {
    return 'scholarships.activationDateError';
  }
  return null;
}

/** La clé de message d'une estimation incomplète, ou `null` si elle est valide. */
export function forecastDraftError(draft: OpeningDraft): string | null {
  if (
    !draft.academicYear ||
    !DAY_PATTERN.test(draft.estimatedOpenAt) ||
    !DAY_PATTERN.test(draft.estimatedCloseAt)
  ) {
    return 'scholarships.forecastValidationError';
  }
  if (
    Date.parse(endOfDayIso(draft.estimatedCloseAt)) <=
    Date.parse(startOfDayIso(draft.estimatedOpenAt))
  ) {
    return 'scholarships.activationDateError';
  }
  return null;
}

/**
 * Le corps de `POST /admin/scholarships/:id/activate`.
 *
 * `notify` est toujours explicite : absent, le serveur garde l'ancien
 * comportement (annonce à la première activation seulement), que ce panneau
 * ne veut jamais. `expectedRecipients` est le `toNotify` que l'équipe a vu et
 * confirmé : si l'audience a trop grossi depuis, le serveur refuse (409)
 * plutôt que d'écrire à plus d'étudiants que le nombre confirmé.
 */
export function buildActivateBody(
  draft: OpeningDraft,
  options: { notify: boolean; expectedRecipients?: number },
): ActivateScholarshipBody {
  const sourceUrl = draft.sourceUrl.trim();
  return {
    academicYear: draft.academicYear,
    opensAt: startOfDayIso(draft.opensAt),
    closesAt: endOfDayIso(draft.closesAt),
    dateConfidence: 'confirmed',
    ...(sourceUrl ? { sourceUrl } : {}),
    notify: options.notify,
    ...(options.expectedRecipients === undefined
      ? {}
      : { expectedRecipients: options.expectedRecipients }),
  };
}

/** Le corps de `POST /admin/scholarships/:id/forecast` (route existante). */
export interface ForecastScholarshipBody {
  academicYear: string;
  estimatedOpenAt: string;
  estimatedCloseAt: string;
  sourceUrl?: string;
}

export function buildForecastBody(draft: OpeningDraft): ForecastScholarshipBody {
  const sourceUrl = draft.sourceUrl.trim();
  return {
    academicYear: draft.academicYear,
    estimatedOpenAt: startOfDayIso(draft.estimatedOpenAt),
    estimatedCloseAt: endOfDayIso(draft.estimatedCloseAt),
    ...(sourceUrl ? { sourceUrl } : {}),
  };
}

/**
 * La requête d'aperçu du brouillon : l'année, et les dates confirmées
 * lorsqu'elles sont complètes (elles décident de la complétude et du message
 * « Dates confirmées » quand l'ouverture est à venir).
 */
export function previewQueryForDraft(draft: OpeningDraft): OpeningPreviewQuery {
  return {
    academicYear: draft.academicYear,
    ...(DAY_PATTERN.test(draft.opensAt) ? { opensAt: startOfDayIso(draft.opensAt) } : {}),
    ...(DAY_PATTERN.test(draft.closesAt) ? { closesAt: endOfDayIso(draft.closesAt) } : {}),
  };
}

/** Une clé stable de la requête : deux brouillons de même clé ont le même aperçu. */
export function previewQueryKey(query: OpeningPreviewQuery): string {
  return [query.academicYear ?? '', query.opensAt ?? '', query.closesAt ?? ''].join('|');
}

// ── Confirmation ───────────────────────────────────────────────────────────

/**
 * « Confirmation saisie AU-DELÀ de 500 destinataires » : 500 exactement n'en
 * demande pas. Même comparaison que le serveur (`isAboveOpeningThreshold`).
 */
export function needsTypedConfirmation(toNotify: number, threshold: number): boolean {
  return toNotify > threshold;
}

/**
 * La saisie confirme le nombre exact. Les espaces sont ignorés (« 1 234 » se
 * tape comme il se lit en français), rien d'autre : « 1234 » ≠ « 1235 ».
 */
export function isTypedConfirmationValid(typed: string, toNotify: number): boolean {
  return typed.replace(/\s/g, '') === String(toNotify);
}

// ── Erreurs du serveur ─────────────────────────────────────────────────────

export interface OpeningApiError {
  status: number | null;
  /** Le `code` d'annonce du corps d'erreur, `null` pour toute autre erreur. */
  code: OpeningErrorCode | null;
  details: Readonly<Record<string, unknown>>;
  /** Le message déjà lisible (`apiFetch` extrait `message` du corps Nest). */
  message: string;
}

function isOpeningErrorCode(value: unknown): value is OpeningErrorCode {
  return (
    typeof value === 'string' &&
    (OPENING_ERROR_CODES as readonly string[]).includes(value)
  );
}

/**
 * Relit `ApiError.body` (le JSON brut de `GlobalExceptionFilter`) pour en
 * tirer le `code` et les `details` d'une erreur d'annonce.
 */
export function apiErrorCode(error: unknown): OpeningApiError {
  const apiError = error instanceof Error ? (error as ApiError) : null;
  const parsed: OpeningApiError = {
    status: typeof apiError?.status === 'number' ? apiError.status : null,
    code: null,
    details: {},
    message: apiError?.message ?? '',
  };
  if (!apiError?.body) return parsed;
  try {
    const body: unknown = JSON.parse(apiError.body);
    if (body && typeof body === 'object') {
      const { code, details } = body as { code?: unknown; details?: unknown };
      if (isOpeningErrorCode(code)) parsed.code = code;
      if (details && typeof details === 'object' && !Array.isArray(details)) {
        parsed.details = details as Record<string, unknown>;
      }
    }
  } catch {
    // Pas du JSON (proxy, passerelle) : seul le message reste.
  }
  return parsed;
}

function detailNumber(details: Readonly<Record<string, unknown>>, key: string): number | null {
  const value = details[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function detailString(details: Readonly<Record<string, unknown>>, key: string): string | null {
  const value = details[key];
  return typeof value === 'string' ? value : null;
}

const ERROR_MESSAGE_KEY: Record<OpeningErrorCode, string> = {
  OPENING_BUSY: 'scholarships.opening.busy',
  OPENING_NOT_RETROACTIVE: 'scholarships.opening.notRetroactive',
  OPENING_CONFIRMATION_REQUIRED: 'scholarships.opening.confirmationRequired',
  OPENING_REQUIRES_ADMIN: 'scholarships.opening.requiresAdmin',
  OPENING_AUDIENCE_CHANGED: 'scholarships.opening.audienceChanged',
  OPENING_NOT_SCHEDULED: 'scholarships.opening.notScheduled',
};

/** La clé de message d'un code d'erreur d'annonce. */
export function openingErrorMessageKey(code: OpeningErrorCode): string {
  return ERROR_MESSAGE_KEY[code];
}

/**
 * Le texte traduit d'une erreur d'annonce, sinon le message du serveur, sinon
 * `fallback`. Le serveur rédige ses messages en français : sans cette
 * traduction, l'admin en anglais les afficherait tels quels.
 * `OPENING_NOT_SCHEDULED` n'est pas traduit ici : son texte dépend du moment
 * de la programmation (`cancelConflictMessageKey`).
 */
export function openingErrorText(error: unknown, t: Translate, fallback: string): string {
  const parsed = apiErrorCode(error);
  if (parsed.code && parsed.code !== 'OPENING_NOT_SCHEDULED') {
    const toNotify = detailNumber(parsed.details, 'toNotify');
    const threshold = detailNumber(parsed.details, 'threshold');
    return fill(t(openingErrorMessageKey(parsed.code)), {
      ...(toNotify === null ? {} : { n: toNotify }),
      ...(threshold === null ? {} : { threshold }),
    });
  }
  return parsed.message || fallback;
}

/**
 * Le texte d'un refus d'`activate`, et s'il faut relire l'aperçu : quand
 * l'audience a changé (ou que le cycle s'avère pré-existant), les chiffres à
 * l'écran sont faux et doivent être recalculés avant toute nouvelle
 * confirmation.
 */
export function activateErrorText(
  error: unknown,
  t: Translate,
  fallback: string,
): { text: string; refreshPreview: boolean } {
  const { code } = apiErrorCode(error);
  return {
    text: openingErrorText(error, t, fallback),
    refreshPreview:
      code === 'OPENING_AUDIENCE_CHANGED' ||
      code === 'OPENING_NOT_RETROACTIVE' ||
      code === 'OPENING_CONFIRMATION_REQUIRED',
  };
}

/**
 * Pourquoi l'annulation a échoué (409 `OPENING_NOT_SCHEDULED`).
 *
 * « Trop tard » seulement si le worker a fait un envoi APRÈS le moment où cet
 * envoi a été programmé (`fanoutAt − holdSeconds`). `openingNotifiedAt` ne
 * sert pas : sur une relance ou une double annulation, c'est la date de la
 * première annonce, et il ferait dire « trop tard » à tort.
 */
export function cancelConflictMessageKey(
  error: unknown,
  fanoutAt: string,
  holdSeconds: number,
): string {
  const lastFanoutAt = detailString(apiErrorCode(error).details, 'lastFanoutAt');
  const last = lastFanoutAt ? Date.parse(lastFanoutAt) : Number.NaN;
  const scheduledAt = fanoutScheduledAtMs(fanoutAt, holdSeconds);
  return Number.isFinite(last) && Number.isFinite(scheduledAt) && last > scheduledAt
    ? 'scholarships.opening.tooLateToCancel'
    : 'scholarships.opening.notScheduled';
}

// ── Temps ──────────────────────────────────────────────────────────────────

/** Secondes entières restantes jusqu'à `iso` (0 si passé ou illisible). */
export function secondsUntil(iso: string | number, now: number): number {
  const target = typeof iso === 'number' ? iso : Date.parse(iso);
  if (!Number.isFinite(target)) return 0;
  return Math.max(0, Math.ceil((target - now) / 1000));
}

/** `m:ss` — « 1:58 », « 0:07 ». */
export function formatCountdown(totalSeconds: number): string {
  const seconds = Math.max(0, Math.floor(totalSeconds));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

/**
 * L'échéance de l'envoi sur l'HORLOGE DU NAVIGATEUR.
 *
 * Pour une programmation qui vient d'être faite (`scheduled`), le serveur a
 * posé `fanoutAt = son maintenant + holdSeconds`, et son « maintenant » est
 * postérieur au départ de la requête : `départ + holdSeconds` est donc une
 * borne prudente, juste même si l'horloge du poste dérive de plusieurs
 * minutes (sinon le bouton « Annuler » disparaîtrait trop tôt, ou resterait
 * proposé alors que l'envoi est parti). Sinon, l'heure absolue du serveur.
 */
export function localFanoutDeadline(input: {
  state: ActivateScholarshipResponse['notification']['state'] | null;
  fanoutAt: string;
  holdSeconds: number;
  requestStartedAt: number;
}): number {
  if (input.state === 'scheduled') {
    return input.requestStartedAt + input.holdSeconds * 1000;
  }
  const absolute = Date.parse(input.fanoutAt);
  return Number.isFinite(absolute) ? absolute : input.requestStartedAt;
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}

function validDate(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? null : date;
}

/** `HH:mm`, heure locale du poste. */
export function formatTime(iso: string | null | undefined): string {
  const date = validDate(iso);
  return date ? `${pad2(date.getHours())}:${pad2(date.getMinutes())}` : '—';
}

/** `dd/mm`, comme « annoncée le 07/10 ». */
export function formatDayMonth(iso: string | null | undefined): string {
  const date = validDate(iso);
  return date ? `${pad2(date.getDate())}/${pad2(date.getMonth() + 1)}` : '—';
}

/** `dd/mm/yyyy`. */
export function formatDate(iso: string | null | undefined): string {
  const date = validDate(iso);
  return date
    ? `${pad2(date.getDate())}/${pad2(date.getMonth() + 1)}/${date.getFullYear()}`
    : '—';
}

/** `dd/mm/yyyy HH:mm`. */
export function formatDateTime(iso: string | null | undefined): string {
  const date = validDate(iso);
  return date ? `${formatDate(iso)} ${formatTime(iso)}` : '—';
}

// ── Sélecteur de cycle ─────────────────────────────────────────────────────

/** Les statuts servis qui ont un libellé ; tout autre s'affiche brut. */
export const CYCLE_STATUSES = ['open', 'forecast', 'closed', 'suspended'] as const;

export function cycleStatusMessageKey(status: string): string | null {
  return (CYCLE_STATUSES as readonly string[]).includes(status)
    ? `scholarships.opening.cycleStatus_${status}`
    : null;
}

export function skipReasonMessageKey(reason: CycleOpeningSkipReason): string {
  return `scholarships.opening.cycleSkipped_${reason}`;
}

/**
 * « 2027-2028 · ouverte · annoncée le 07/10 par Aminata D. (312) »,
 * « … · envoi programmé à 14:34 », « … · non annoncée ».
 */
export function cycleOptionLabel(cycle: OpeningPreviewCycle, t: Translate): string {
  const statusKey = cycleStatusMessageKey(cycle.status);
  const parts = [cycle.academicYear, statusKey ? t(statusKey) : cycle.status];
  if (cycle.openingFanoutDueAt) {
    parts.push(
      fill(t('scholarships.opening.cycleScheduled'), {
        time: formatTime(cycle.openingFanoutDueAt),
      }),
    );
  } else if (cycle.openingNotifiedAt) {
    const date = formatDayMonth(cycle.openingNotifiedAt);
    const announced = cycle.openingNotifiedBy
      ? fill(t('scholarships.opening.cycleAnnouncedBy'), {
          date,
          name: cycle.openingNotifiedBy.name,
        })
      : fill(t('scholarships.opening.cycleAnnounced'), { date });
    parts.push(
      cycle.openingAudience === null
        ? announced
        : `${announced} (${cycle.openingAudience})`,
    );
  } else if (cycle.openingSkippedReason) {
    parts.push(t(skipReasonMessageKey(cycle.openingSkippedReason)));
  } else {
    parts.push(t('scholarships.opening.cycleNotAnnounced'));
  }
  return parts.join(' · ');
}

export interface CycleOption {
  value: string;
  label: string;
}

/** Plus récente d'abord : `2028-2029` > `2027-2028` > `2027` (ordre du texte). */
function byAcademicYearDesc(a: { academicYear: string }, b: { academicYear: string }): number {
  return b.academicYear.localeCompare(a.academicYear);
}

/** Les cycles de l'aperçu, plus récents d'abord, puis « Nouveau cycle {année} ». */
export function cycleOptions(preview: OpeningPreviewResponse, t: Translate): CycleOption[] {
  const options = [...preview.cycles]
    .sort(byAcademicYearDesc)
    .map((cycle) => ({ value: cycle.academicYear, label: cycleOptionLabel(cycle, t) }));
  if (!preview.cycles.some((cycle) => cycle.academicYear === preview.nextAcademicYear)) {
    options.push({
      value: preview.nextAcademicYear,
      label: fill(t('scholarships.opening.newCycleOption'), {
        year: preview.nextAcademicYear,
      }),
    });
  }
  return options;
}

export function cycleForYear(
  preview: OpeningPreviewResponse | null,
  academicYear: string | null,
): OpeningPreviewCycle | undefined {
  return preview?.cycles.find((cycle) => cycle.academicYear === academicYear);
}

/** Le cycle dont l'annonce attend encore son heure, s'il y en a un. */
export function scheduledCycle(
  preview: OpeningPreviewResponse | null,
): OpeningPreviewCycle | undefined {
  return preview?.cycles.find((cycle) => cycle.openingFanoutDueAt !== null);
}

// ── Action principale ──────────────────────────────────────────────────────

export interface PrimaryAction {
  label: string;
  /**
   * `announce` : prévenir les abonnés, après l'aperçu et la confirmation.
   * `open_only` : l'aperçu ne compte personne à prévenir ; l'ouverture part
   * SANS PRÉVENIR (`notify: false`), voir `announcementRequest`.
   */
  kind: 'announce' | 'open_only';
  /** Pourquoi le bouton est désactivé, ou `null`. */
  disabledReason: string | null;
}

/**
 * Le bouton principal du panneau, d'après l'aperçu.
 *
 * Désactivé, avec son explication, quand un envoi est déjà programmé, quand la
 * fiche n'est pas prête (le serveur refuserait toute ouverture), et, pour une
 * annonce seulement : quand le cycle était ouvert avant la mise en service
 * (pas d'annonce rétroactive : le serveur répondrait 409) ou quand l'audience
 * dépasse le seuil et que l'équipier n'a pas le droit d'y envoyer (403). Les
 * dates restent enregistrables sans prévenir.
 */
export function primaryAction(
  preview: OpeningPreviewResponse,
  options: { canSendAboveThreshold: boolean },
  t: Translate,
): PrimaryAction {
  const toNotify = preview.audience.toNotify;
  const kind: PrimaryAction['kind'] = toNotify === 0 ? 'open_only' : 'announce';
  const label =
    kind === 'open_only'
      ? t('scholarships.opening.openOnlyCta')
      : preview.target.alreadyAnnounced
        ? fill(t('scholarships.opening.notifyNewCta'), { n: toNotify })
        : t('scholarships.opening.primaryCta');
  let disabledReason: string | null = null;
  if (preview.target.fanoutScheduledAt) {
    disabledReason = t('scholarships.opening.alreadyScheduled');
  } else if (!preview.readiness.ready) {
    disabledReason = t('scholarships.opening.notReady');
  } else if (kind === 'announce' && preview.target.preExistingOpen) {
    disabledReason = t('scholarships.opening.preExistingOpen');
  } else if (
    kind === 'announce' &&
    needsTypedConfirmation(toNotify, preview.confirmThreshold) &&
    !options.canSendAboveThreshold
  ) {
    disabledReason = fill(t('scholarships.opening.requiresAdmin'), {
      threshold: preview.confirmThreshold,
    });
  }
  return { label, kind, disabledReason };
}

/** Ce que le bouton principal demande au serveur (`notify`, `expectedRecipients`). */
export interface AnnouncementRequest {
  notify: boolean;
  expectedRecipients?: number;
}

/**
 * Le corps de l'action principale.
 *
 * « Ouvrir le cycle » (personne à prévenir d'après l'aperçu) n'envoie JAMAIS
 * `notify: true` : avec `expectedRecipients: 0`, le serveur tolère une hausse
 * de 10 destinataires (et l'envoi recalcule l'audience à l'heure dite), si
 * bien que des abonnés arrivés entre l'aperçu et le clic seraient prévenus
 * sans que personne ait rien confirmé. `notify: false` ouvre le cycle sans
 * prévenir ; s'il y a plus tard des abonnés, le panneau propose de les
 * prévenir, avec l'aperçu et la confirmation habituels.
 */
export function announcementRequest(
  kind: PrimaryAction['kind'],
  confirmedCount: number,
): AnnouncementRequest {
  return kind === 'open_only'
    ? { notify: false }
    : { notify: true, expectedRecipients: confirmedCount };
}

/**
 * Le bouton secondaire « Enregistrer les dates sans prévenir » fait la même
 * requête que « Ouvrir le cycle sans prévenir » : inutile de proposer deux
 * boutons identiques côte à côte. Il reste affiché quand le bouton principal
 * est désactivé (corriger les dates d'une annonce programmée, p. ex.).
 */
export function showDatesOnlyAction(action: PrimaryAction | null): boolean {
  return !(action?.kind === 'open_only' && action.disabledReason === null);
}

/**
 * « 312 abonnés à prévenir pour 2027-2028 (334 abonnés au total). » — le
 * nombre de l'aperçu, avec le total quand il diffère (sourdine, déjà prévenus).
 */
export function previewSummaryText(preview: OpeningPreviewResponse, t: Translate): string {
  const { toNotify, followers } = preview.audience;
  const values = { n: toNotify, year: preview.target.academicYear, total: followers };
  return followers > toNotify
    ? fill(t('scholarships.opening.previewSummaryWithTotal'), values)
    : fill(t('scholarships.opening.previewSummary'), values);
}

// ── Bandeaux de l'aperçu ───────────────────────────────────────────────────

export interface OpeningBanner {
  variant: 'info' | 'warning';
  text: string;
}

/** Les avertissements à lire avant de confirmer, du plus général au plus précis. */
export function previewBanners(preview: OpeningPreviewResponse, t: Translate): OpeningBanner[] {
  const banners: OpeningBanner[] = [];
  if (preview.mode === 'legacy') {
    banners.push({ variant: 'warning', text: t('scholarships.opening.modeLegacy') });
  }
  if (preview.mode !== 'outbox_followers') {
    banners.push({ variant: 'info', text: t('scholarships.opening.modeAlertsOnly') });
  }
  if (preview.mode !== 'legacy' && !preview.worker.enabled) {
    banners.push({ variant: 'warning', text: t('scholarships.opening.workerDisabled') });
  }
  if (!preview.push.configured) {
    banners.push({ variant: 'warning', text: t('scholarships.opening.providerUnconfigured') });
  }
  if (preview.target.preExistingOpen) {
    banners.push({ variant: 'warning', text: t('scholarships.opening.preExistingOpen') });
  } else if (preview.target.alreadyAnnounced) {
    banners.push({ variant: 'info', text: t('scholarships.opening.alreadyAnnounced') });
  }
  if (preview.copy.variant === 'dates_confirmed') {
    banners.push({ variant: 'info', text: t('scholarships.opening.datesConfirmedNotice') });
  }
  if (preview.audience.toNotify === 0) {
    banners.push({ variant: 'info', text: t('scholarships.opening.zeroFollowers') });
  }
  return banners;
}

// ── Lignes d'audience ──────────────────────────────────────────────────────

export interface AudienceLines {
  audience: string;
  exclusions: string | null;
  delivery: string;
  devices: string;
  languages: string;
}

/**
 * « 312 étudiants seront prévenus : 240 favoris, 50 alertes « M'avertir »,
 * 22 les deux », les exclusions, puis la répartition des envois.
 */
export function audienceLines(audience: OpeningAudienceSummary, t: Translate): AudienceLines {
  const exclusions = [
    audience.followers > audience.toNotify
      ? fill(t('scholarships.opening.followersTotal'), { n: audience.followers })
      : null,
    audience.muted > 0
      ? fill(t('scholarships.opening.mutedExcluded'), { n: audience.muted })
      : null,
    audience.alreadyNotifiedThisCycle > 0
      ? fill(t('scholarships.opening.alreadyNotifiedExcluded'), {
          n: audience.alreadyNotifiedThisCycle,
        })
      : null,
    audience.recentlyNotified > 0
      ? fill(t('scholarships.opening.recentlyNotifiedExcluded'), {
          n: audience.recentlyNotified,
        })
      : null,
  ].filter((part): part is string => part !== null);
  return {
    audience: fill(t('scholarships.opening.audienceLine'), {
      n: audience.toNotify,
      favorites: audience.viaFavoriteOnly,
      alerts: audience.viaAlertOnly,
      both: audience.viaBoth,
    }),
    exclusions: exclusions.length > 0 ? exclusions.join(' · ') : null,
    delivery: fill(t('scholarships.opening.deliveryLine'), {
      push: audience.pushEligible,
      inAppOnly: Math.max(0, audience.toNotify - audience.pushEligible),
      quiet: audience.deferredQuietHours,
      pacing: audience.deferredPacing,
    }),
    devices: fill(t('scholarships.opening.devicesLine'), {
      fcm: audience.devices.fcm,
      oneSignal: audience.devices.oneSignalOnly,
    }),
    languages: fill(t('scholarships.opening.languagesLine'), {
      fr: audience.byLanguage.fr,
      en: audience.byLanguage.en,
    }),
  };
}

// ── Aperçu sur téléphone ───────────────────────────────────────────────────

export type PhoneTab = 'alert' | 'favorite' | 'dates' | 'bundle';

/**
 * Les onglets utiles. Quand l'ouverture est à venir, chaque étudiant reçoit
 * le message « Dates confirmées » (le serveur le met à la place des variantes
 * alerte et favori) ; la variante « favori » n'existe qu'en portée
 * `followers`.
 */
export function phoneTabs(
  variant: OpeningPreviewCopy['variant'],
  scope: OpeningAudienceScope,
): PhoneTab[] {
  if (variant === 'dates_confirmed') return ['dates', 'bundle'];
  return scope === 'followers' ? ['alert', 'favorite', 'bundle'] : ['alert', 'bundle'];
}

const PHONE_TAB_KEY: Record<PhoneTab, string> = {
  alert: 'scholarships.opening.phoneTabAlert',
  favorite: 'scholarships.opening.phoneTabFavorite',
  dates: 'scholarships.opening.phoneTabDates',
  bundle: 'scholarships.opening.phoneTabBundle',
};

export function phoneTabMessageKey(tab: PhoneTab): string {
  return PHONE_TAB_KEY[tab];
}

/** Le texte FR et EN d'un onglet. */
export function phoneCopy(
  copy: OpeningPreviewCopy,
  tab: PhoneTab,
): { fr: LocalizedPushCopy; en: LocalizedPushCopy } {
  switch (tab) {
    case 'favorite':
      return { fr: copy.fr.favorite, en: copy.en.favorite };
    case 'bundle':
      return { fr: copy.bundleExample.fr, en: copy.bundleExample.en };
    case 'alert':
    case 'dates':
    default:
      return { fr: copy.fr.alert, en: copy.en.alert };
  }
}

// ── Résultat d'une ouverture ───────────────────────────────────────────────

export type ActivateOutcome =
  | { kind: 'scheduled'; cycleId: string; fanoutAt: string; toNotify: number }
  | { kind: 'message'; text: string };

/** Ce que l'équipe voit après `activate`, selon `notification.state`. */
export function activateOutcome(
  response: ActivateScholarshipResponse,
  t: Translate,
): ActivateOutcome {
  const { notification } = response;
  if (
    (notification.state === 'scheduled' || notification.state === 'already_scheduled') &&
    notification.fanoutAt
  ) {
    return {
      kind: 'scheduled',
      cycleId: response.cycleId,
      fanoutAt: notification.fanoutAt,
      toNotify: notification.toNotify,
    };
  }
  if (notification.state === 'sent_legacy') {
    return {
      kind: 'message',
      // `toNotify` : les destinataires confirmés à l'aperçu (déjà prévenus
      // exclus) ; `subscribers` compte toutes les alertes actives.
      text: fill(t('scholarships.opening.legacyResult'), {
        toNotify: notification.toNotify,
        pushesSent: response.pushesSent,
      }),
    };
  }
  return { kind: 'message', text: t('scholarships.opening.datesOnlyResult') };
}

// ── Rapport d'envoi ────────────────────────────────────────────────────────

/**
 * « 280 acceptées par le fournisseur · 10 sans appareil · 7 reportées ·
 * 0 échecs · 15 non envoyées · 37 lues ».
 *
 * « Reportées » = tout ce qui attend encore (heures calmes, rythme, nouvelle
 * tentative, ou simplement pas encore traité). « Non envoyées » = sautées
 * (désinscription, sourdine, arrêt…) plus expirées (72 h sans pouvoir partir).
 * Seules les lignes de l'ancien mode, sans suivi, n'y figurent pas.
 */
export function formatReportLine(report: OpeningReportResponse, t: Translate): string {
  return fill(t('scholarships.opening.reportLine'), {
    accepted: report.push.accepted,
    noDevice: report.push.noDevice,
    deferred: report.push.pending,
    failed: report.push.failed,
    skipped: report.push.skipped.total + report.push.expired,
    read: report.inbox.read,
  });
}

/** Le détail des reports, quand il y en a. */
export function reportDeferredDetail(report: OpeningReportResponse, t: Translate): string | null {
  if (report.push.pending === 0) return null;
  return fill(t('scholarships.opening.reportDeferredDetail'), {
    quiet: report.push.deferredQuietHours,
    pacing: report.push.deferredPacing,
    retrying: report.push.retrying,
  });
}

/** Les push (un groupé compte pour un) et leur fournisseur. */
export function reportProvidersLine(report: OpeningReportResponse, t: Translate): string {
  return fill(t('scholarships.opening.reportProviders'), {
    pushes: report.push.acceptedPushes,
    fcm: report.byProvider.fcm,
    onesignal: report.byProvider.onesignal,
  });
}

/**
 * Relire le rapport ? Oui tant que l'annonce n'a pas encore été préparée par
 * le worker (`scheduledAt` encore posé) ou que des push attendent — et au plus
 * 10 minutes, après quoi l'équipe actualise à la main. Un rapport pas encore
 * chargé (ou en erreur passagère) se relit aussi.
 */
export function shouldPollReport(
  report: OpeningReportResponse | null,
  startedAt: number,
  now: number,
): boolean {
  if (now - startedAt >= REPORT_POLL_MAX_MS) return false;
  return report === null || report.fanout.scheduledAt !== null || report.push.pending > 0;
}

// ── Carte de programmation ─────────────────────────────────────────────────

/**
 * L'instant où l'envoi suivi a été programmé, en ms sur l'horloge du serveur :
 * `fanoutAt − holdSeconds`. `NaN` si `fanoutAt` manque ou est illisible.
 */
export function fanoutScheduledAtMs(fanoutAt: string | null, holdSeconds: number): number {
  return fanoutAt ? Date.parse(fanoutAt) - holdSeconds * 1000 : Number.NaN;
}

function isScheduleEndAction(action: string): boolean {
  return (OPENING_SCHEDULE_END_ACTIONS as readonly string[]).includes(action);
}

/**
 * Comment la programmation suivie par la carte a pris fin, selon le serveur :
 * - `started` : les notifications sont écrites (`lastFanoutAt` postérieur à la
 *   programmation — la règle de `cancelConflictMessageKey` —, ou l'événement
 *   `fanout_completed` fait) ;
 * - `dropped` : le worker l'a abandonnée (`skipped` : bourse plus publique,
 *   cycle clos, trop en retard) — l'événement porte le motif ;
 * - `cancelled` : un équipier l'a annulée, ici ou ailleurs (l'événement dit qui) ;
 * - `unscheduled` : plus rien de programmé, rien n'est parti, motif encore
 *   inconnu.
 *
 * `null` tant que le serveur la rapporte programmée, ou que le rapport n'est
 * pas lu. Le motif vient de `report.fanout.lastScheduleEnd` ; à défaut
 * (backend antérieur), des « Derniers événements » de l'aperçu pour la même
 * année. Seul compte un événement postérieur à la programmation : l'annulation
 * d'une programmation précédente ne dit rien de celle-ci.
 */
export type ScheduleEnd =
  | { kind: 'started'; event: OpeningRecentEvent | null }
  | { kind: 'dropped'; event: OpeningRecentEvent }
  | { kind: 'cancelled'; event: OpeningRecentEvent }
  | { kind: 'unscheduled'; event: null };

export function scheduleEnd(input: {
  report: OpeningReportResponse | null;
  fanoutAt: string | null;
  holdSeconds: number;
  academicYear: string;
  recentEvents?: readonly OpeningRecentEvent[];
}): ScheduleEnd | null {
  const { report } = input;
  if (report === null || report.fanout.scheduledAt !== null) return null;
  const scheduledAt = fanoutScheduledAtMs(input.fanoutAt, input.holdSeconds);
  const since = (iso: string | null | undefined, strict: boolean): boolean => {
    const at = iso ? Date.parse(iso) : Number.NaN;
    if (!Number.isFinite(at)) return false;
    if (!Number.isFinite(scheduledAt)) return true;
    return strict ? at > scheduledAt : at >= scheduledAt;
  };

  if (since(report.fanout.lastFanoutAt, true)) return { kind: 'started', event: null };

  const event = [
    report.fanout.lastScheduleEnd ?? null,
    ...(input.recentEvents ?? []).filter((e) => e.academicYear === input.academicYear),
  ].find(
    (candidate): candidate is OpeningRecentEvent =>
      candidate !== null &&
      isScheduleEndAction(candidate.action) &&
      candidate.outcome !== 'refused' &&
      since(candidate.occurredAt, false),
  );
  if (!event) return { kind: 'unscheduled', event: null };
  // Sans `outcome` (backend antérieur), un événement se lit comme fait.
  if (event.outcome === 'skipped') return { kind: 'dropped', event };
  if (event.action === 'scholarship_cycle.notify_cancelled') return { kind: 'cancelled', event };
  return { kind: 'started', event };
}

/**
 * Où en est une annonce programmée, du point de vue de l'équipe :
 * - `scheduled` : avant l'heure d'envoi (compte à rebours) ;
 * - `awaiting` : l'heure est passée sur le poste, mais le serveur n'a pas
 *   encore lancé l'envoi (worker en file, interrupteur coupé, horloge du
 *   poste en avance) — ou on ne le sait pas encore (rapport pas encore lu).
 *   Le serveur accepte l'annulation jusqu'à ce que le worker la prenne ;
 * - `started` : le serveur rapporte les notifications écrites ;
 * - `dropped` : le worker a abandonné l'envoi (motif dans l'événement) ;
 * - `cancelled` : annulé, par cette carte ou ailleurs ;
 * - `unscheduled` : plus rien de programmé, rien n'est parti, motif inconnu ;
 * - `report` : simple rapport d'un envoi passé (carte ouverte sans programmation).
 *
 * Plus de `scheduledAt` ne veut donc PAS dire « commencé » : le worker qui
 * abandonne l'envoi et l'annulation l'effacent aussi.
 */
export type ScheduledCardStatus =
  | 'scheduled'
  | 'awaiting'
  | 'started'
  | 'dropped'
  | 'cancelled'
  | 'unscheduled'
  | 'report';

export type ScheduledCardPhase = 'countdown' | 'cancelled' | 'report';

/**
 * Le serveur a refusé l'annulation (409 `OPENING_NOT_SCHEDULED`) : `too_late`
 * (l'envoi a commencé) ou `not_scheduled` (plus rien de programmé, rien n'est
 * parti). Vrai même si le dernier rapport lu, plus ancien, la montre encore
 * programmée.
 */
export type CancelRefusal = 'too_late' | 'not_scheduled';

export interface ScheduledCardInput {
  phase: ScheduledCardPhase;
  /** La carte suit une programmation (`fanoutAt` connu), pas un envoi passé. */
  scheduled: boolean;
  report: OpeningReportResponse | null;
  fanoutAt?: string | null;
  holdSeconds?: number;
  academicYear?: string;
  /** Les « Derniers événements » de l'aperçu (backend sans `lastScheduleEnd`). */
  recentEvents?: readonly OpeningRecentEvent[];
  cancelRefusal?: CancelRefusal | null;
}

export interface ScheduledCardState {
  status: ScheduledCardStatus;
  /** L'événement qui a mis fin à la programmation, s'il est connu (motif, auteur). */
  event: OpeningRecentEvent | null;
}

export function scheduledCardState(input: ScheduledCardInput): ScheduledCardState {
  switch (input.phase) {
    case 'countdown':
      return { status: 'scheduled', event: null };
    case 'cancelled':
      return { status: 'cancelled', event: null };
    case 'report':
    default: {
      if (!input.scheduled) return { status: 'report', event: null };
      const end = scheduleEnd({
        report: input.report,
        fanoutAt: input.fanoutAt ?? null,
        holdSeconds: input.holdSeconds ?? 0,
        academicYear: input.academicYear ?? '',
        recentEvents: input.recentEvents,
      });
      if (end) return { status: end.kind, event: end.event };
      if (input.cancelRefusal === 'too_late') return { status: 'started', event: null };
      if (input.cancelRefusal === 'not_scheduled') {
        return { status: 'unscheduled', event: null };
      }
      return { status: 'awaiting', event: null };
    }
  }
}

export function scheduledCardStatus(input: ScheduledCardInput): ScheduledCardStatus {
  return scheduledCardState(input).status;
}

/** [Annuler l'envoi] reste proposé tant que le serveur n'a pas lancé l'envoi. */
export function canCancelScheduled(status: ScheduledCardStatus): boolean {
  return status === 'scheduled' || status === 'awaiting';
}

/**
 * Le texte d'une programmation terminée sans envoi : « Annonce non envoyée :
 * bourse plus publique. Aucun étudiant n'a été prévenu. », « Moussa K. a
 * annulé l'envoi… », « L'envoi n'est plus programmé… ». `null` sinon.
 */
export function scheduledCardEndText(
  status: ScheduledCardStatus,
  event: OpeningRecentEvent | null,
  t: Translate,
): string | null {
  switch (status) {
    case 'dropped':
      return fill(t('scholarships.opening.droppedLine'), {
        reason: event ? recentEventTitle(event, t) : t('scholarships.opening.eventSkipped'),
      });
    case 'cancelled':
      return event?.actorName
        ? fill(t('scholarships.opening.cancelledBy'), { name: event.actorName })
        : t('scholarships.opening.cancelled');
    case 'unscheduled':
      return t('scholarships.opening.unscheduledLine');
    default:
      return null;
  }
}

/**
 * Ce que la région `aria-live` de la carte annonce : les changements d'état
 * seulement (programmé, en attente d'envoi, commencé, abandonné et pourquoi,
 * annulé et par qui, plus programmé), jamais le compte à rebours de chaque
 * seconde ni les chiffres du rapport relu toutes les 5 s. `''` = rien à
 * annoncer (les refus ont leur propre alerte).
 */
export function scheduledCardAnnouncement(
  status: ScheduledCardStatus,
  context: {
    toNotify: number | null;
    fanoutAt: string | null;
    event?: OpeningRecentEvent | null;
  },
  t: Translate,
): string {
  switch (status) {
    case 'scheduled':
      return context.toNotify === null
        ? fill(t('scholarships.opening.scheduledLineNoCount'), {
            time: formatTime(context.fanoutAt),
          })
        : fill(t('scholarships.opening.scheduledLine'), {
            n: context.toNotify,
            time: formatTime(context.fanoutAt),
          });
    case 'awaiting':
      return t('scholarships.opening.awaitingLive');
    case 'started':
      return t('scholarships.opening.startedLive');
    case 'dropped':
    case 'cancelled':
    case 'unscheduled':
      return scheduledCardEndText(status, context.event ?? null, t) ?? '';
    case 'report':
    default:
      return '';
  }
}

const PENDING_CARD_STATUSES: readonly ScheduledCardStatus[] = ['scheduled', 'awaiting'];
const ENDED_CARD_STATUSES: readonly ScheduledCardStatus[] = [
  'started',
  'dropped',
  'cancelled',
  'unscheduled',
];

/**
 * Faut-il relire l'aperçu et les listes (« Annoncé », « À faire ») ? Quand la
 * programmation prend fin côté serveur — envoi lancé, abandonné, annulé ici
 * ou ailleurs —, pas quand le compte à rebours du poste arrive à zéro : à ce
 * moment-là, l'envoi peut encore attendre (et rester annulable).
 */
export function scheduledCardChanged(
  before: ScheduledCardStatus,
  after: ScheduledCardStatus,
): boolean {
  return PENDING_CARD_STATUSES.includes(before) && ENDED_CARD_STATUSES.includes(after);
}

// ── Liste, « À faire », historique ─────────────────────────────────────────

/**
 * Colonne « Abonnés à prévenir » : ceux que le bouton de l'aperçu
 * préviendrait. Cycle proposé déjà annoncé : les nouveaux abonnés depuis
 * l'annonce (`announcedTarget.newFollowers`) — l'audience de la portée
 * (`notifiable`) compterait des étudiants déjà prévenus. Sinon `notifiable`.
 * L'aperçu global ne liste que les bourses suivies ou annoncées : absente,
 * une bourse a 0 abonné. `—` tant que l'aperçu n'est pas chargé.
 */
export function followersCell(item: OpeningOverviewItem | undefined, loaded: boolean): string {
  if (!loaded) return '—';
  if (item?.announcedTarget) return String(item.announcedTarget.newFollowers);
  return String(item?.notifiable ?? 0);
}

/**
 * Sous la colonne « Abonnés à prévenir » : « nouveaux depuis l'annonce
 * 2027-2028 » pour un cycle déjà annoncé, et « 334 au total » quand des
 * abonnés ne seront pas prévenus (déjà prévenus, sourdine, portée
 * « M'avertir » seulement) ; sinon rien.
 */
export function followersSubText(
  item: OpeningOverviewItem | undefined,
  loaded: boolean,
  t: Translate,
): string | null {
  if (!loaded || !item) return null;
  const target = item.announcedTarget;
  if (target) {
    const values = { year: target.academicYear, n: item.followers };
    return item.followers > target.newFollowers
      ? fill(t('scholarships.opening.colFollowersNewWithTotal'), values)
      : fill(t('scholarships.opening.colFollowersNew'), values);
  }
  if (item.followers <= item.notifiable) return null;
  return fill(t('scholarships.opening.colFollowersTotal'), { n: item.followers });
}

/** Colonne « Annoncé » : `dd/mm/yyyy (n)`, « programmé » ou `—`. */
export function announcedCell(
  item: OpeningOverviewItem | undefined,
  loaded: boolean,
  t: Translate,
): string {
  if (!loaded || !item) return '—';
  if (item.scheduledAt) return t('scholarships.opening.announcedScheduled');
  if (item.lastAnnounced) {
    const date = formatDate(item.lastAnnounced.at);
    return item.lastAnnounced.audience === null
      ? date
      : `${date} (${item.lastAnnounced.audience})`;
  }
  return '—';
}

/**
 * « Chevening · 2027-2028 · 312 abonnés à prévenir (334 au total) · ouverte
 * par le catalogue ». Le nombre est celui de la colonne de la liste
 * (`notifiable`) ; un backend antérieur ne le donne pas : la ligne montre alors
 * le total, libellé « abonnés » et non « à prévenir ».
 */
export function todoRowText(item: OpeningTodoItem, t: Translate): string {
  const notifiable =
    typeof item.notifiable === 'number' && Number.isFinite(item.notifiable)
      ? item.notifiable
      : null;
  const values = {
    name: item.nameFr,
    year: item.academicYear,
    source: t(`scholarships.opening.todoSource_${item.source}`),
  };
  if (notifiable === null) {
    return fill(t('scholarships.opening.todoRowFollowers'), { ...values, n: item.followers });
  }
  return item.followers > notifiable
    ? fill(t('scholarships.opening.todoRowWithTotal'), {
        ...values,
        n: notifiable,
        total: item.followers,
      })
    : fill(t('scholarships.opening.todoRow'), { ...values, n: notifiable });
}

function isKnownAuditAction(action: string): action is OpeningAuditAction {
  return (OPENING_AUDIT_ACTIONS as readonly string[]).includes(action);
}

/**
 * `scholarship_cycle.notify_scheduled` → `scholarships.opening.event_notify_scheduled`.
 * Une action inconnue de cet admin (backend plus récent) a un libellé générique
 * plutôt que sa clé brute.
 */
export function auditEventMessageKey(action: string): string {
  return isKnownAuditAction(action)
    ? `scholarships.opening.event_${action.replace(/^scholarship_cycle\./, '')}`
    : 'scholarships.opening.event_unknown';
}

/** Les motifs (`reasonCode`) qui ont un libellé ; tout autre s'affiche brut. */
export const EVENT_REASON_CODES = [
  // Annonce non envoyée (`skipped`).
  'not_public_at_fanout',
  'cycle_closed_at_fanout',
  'fanout_too_late',
  'dates_only',
  'pre_existing_open',
  'already_announced',
  'nothing_to_send',
  'legacy_first_activation_only',
  // Demande refusée (`refused`) : les codes d'erreur du serveur.
  ...OPENING_ERROR_CODES,
  'SCHOLARSHIP_NOT_READY',
] as const;

/** `OPENING_CONFIRMATION_REQUIRED` → `scholarships.opening.eventReason_opening_confirmation_required`. */
export function eventReasonMessageKey(code: string): string | null {
  return (EVENT_REASON_CODES as readonly string[]).includes(code)
    ? `scholarships.opening.eventReason_${code.toLowerCase()}`
    : null;
}

function isEventOutcome(value: unknown): value is OpeningEventOutcome {
  return (
    typeof value === 'string' && (OPENING_EVENT_OUTCOMES as readonly string[]).includes(value)
  );
}

function refusedMessageKey(action: string): string {
  switch (action) {
    case 'scholarship_cycle.notify_cancelled':
      return 'scholarships.opening.eventRefused_cancel';
    case 'scholarship_cycle.notify_stopped':
      return 'scholarships.opening.eventRefused_stop';
    default:
      return 'scholarships.opening.eventRefused_opening';
  }
}

/**
 * Le libellé d'un événement, selon ce qu'il a réellement produit :
 * « Annonce non envoyée : bourse plus publique », « Ouverture refusée :
 * confirmation requise »… Sans `outcome` (backend antérieur) ou avec
 * `sent`, le libellé de l'action.
 */
export function recentEventTitle(event: OpeningRecentEvent, t: Translate): string {
  const outcome = isEventOutcome(event.outcome) ? event.outcome : 'sent';
  if (outcome === 'sent') return t(auditEventMessageKey(event.action));
  const code = typeof event.reasonCode === 'string' ? event.reasonCode.trim() : '';
  const reasonKey = code ? eventReasonMessageKey(code) : null;
  const reason = reasonKey
    ? t(reasonKey)
    : code
      ? fill(t('scholarships.opening.eventReasonUnknown'), { code })
      : null;
  const prefix =
    outcome === 'skipped' ? t('scholarships.opening.eventSkipped') : t(refusedMessageKey(event.action));
  return reason === null
    ? prefix
    : fill(t('scholarships.opening.eventWithReason'), { event: prefix, reason });
}

/** « 07/10/2026 14:32 · Annonce programmée · Aminata D. · 2027-2028 · 312 ». */
export function recentEventLabel(event: OpeningRecentEvent, t: Translate): string {
  // Un « 0 » après « Annonce non envoyée » se lirait comme un envoi à zéro
  // étudiant : rien n'est parti, le nombre n'apporte rien.
  const count =
    event.toNotify === null || (event.outcome === 'skipped' && event.toNotify === 0)
      ? null
      : String(event.toNotify);
  return [
    formatDateTime(event.occurredAt),
    recentEventTitle(event, t),
    event.actorName ?? t('scholarships.opening.eventSystem'),
    event.academicYear,
    count,
  ]
    .filter((part): part is string => part !== null && part !== '')
    .join(' · ');
}
