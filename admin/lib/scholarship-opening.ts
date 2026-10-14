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
  OPENING_ERROR_CODES,
  type ActivateScholarshipBody,
  type ActivateScholarshipResponse,
  type CycleOpeningSkipReason,
  type LocalizedPushCopy,
  type OpeningAudienceScope,
  type OpeningAudienceSummary,
  type OpeningAuditAction,
  type OpeningErrorCode,
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
  const scheduledAt = Date.parse(fanoutAt) - holdSeconds * 1000;
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
  /** `open_only` : personne à prévenir, l'ouverture part sans confirmation. */
  kind: 'announce' | 'open_only';
  /** Pourquoi le bouton est désactivé, ou `null`. */
  disabledReason: string | null;
}

/**
 * Le bouton principal du panneau, d'après l'aperçu.
 *
 * Désactivé, avec son explication, quand la fiche n'est pas prête, quand le
 * cycle était ouvert avant la mise en service (pas d'annonce rétroactive : le
 * serveur répondrait 409), quand l'audience dépasse le seuil et que l'équipier
 * n'a pas le droit d'y envoyer (le serveur répondrait 403), ou quand un envoi
 * est déjà programmé. Les dates restent enregistrables sans prévenir.
 */
export function primaryAction(
  preview: OpeningPreviewResponse,
  options: { canSendAboveThreshold: boolean },
  t: Translate,
): PrimaryAction {
  const toNotify = preview.audience.toNotify;
  const label =
    toNotify === 0
      ? t('scholarships.opening.openOnlyCta')
      : preview.target.alreadyAnnounced
        ? fill(t('scholarships.opening.notifyNewCta'), { n: toNotify })
        : t('scholarships.opening.primaryCta');
  let disabledReason: string | null = null;
  if (preview.target.fanoutScheduledAt) {
    disabledReason = t('scholarships.opening.alreadyScheduled');
  } else if (!preview.readiness.ready) {
    disabledReason = t('scholarships.opening.notReady');
  } else if (preview.target.preExistingOpen) {
    disabledReason = t('scholarships.opening.preExistingOpen');
  } else if (
    needsTypedConfirmation(toNotify, preview.confirmThreshold) &&
    !options.canSendAboveThreshold
  ) {
    disabledReason = fill(t('scholarships.opening.requiresAdmin'), {
      threshold: preview.confirmThreshold,
    });
  }
  return { label, kind: toNotify === 0 ? 'open_only' : 'announce', disabledReason };
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
      text: fill(t('scholarships.opening.legacyResult'), {
        pushesSent: response.pushesSent,
        subscribers: response.subscribers,
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

// ── Liste, « À faire », historique ─────────────────────────────────────────

/**
 * Colonne « Abonnés » : l'audience notifiable de la portée en vigueur.
 * L'aperçu global ne liste que les bourses suivies ou annoncées : absente, une
 * bourse a 0 abonné. `—` tant que l'aperçu n'est pas chargé.
 */
export function followersCell(item: OpeningOverviewItem | undefined, loaded: boolean): string {
  if (!loaded) return '—';
  return String(item?.notifiable ?? 0);
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

/** « Chevening · 2027-2028 · 312 abonnés · ouverte par le catalogue ». */
export function todoRowText(item: OpeningTodoItem, t: Translate): string {
  return fill(t('scholarships.opening.todoRow'), {
    name: item.nameFr,
    year: item.academicYear,
    n: item.followers,
    source: t(`scholarships.opening.todoSource_${item.source}`),
  });
}

/** `scholarship_cycle.notify_scheduled` → `scholarships.opening.event_notify_scheduled`. */
export function auditEventMessageKey(action: OpeningAuditAction): string {
  return `scholarships.opening.event_${action.replace(/^scholarship_cycle\./, '')}`;
}

/** « 07/10/2026 14:32 · Annonce programmée · Aminata D. · 2027-2028 · 312 ». */
export function recentEventLabel(event: OpeningRecentEvent, t: Translate): string {
  return [
    formatDateTime(event.occurredAt),
    t(auditEventMessageKey(event.action)),
    event.actorName ?? t('scholarships.opening.eventSystem'),
    event.academicYear,
    event.toNotify === null ? null : String(event.toNotify),
  ]
    .filter((part): part is string => part !== null && part !== '')
    .join(' · ');
}
