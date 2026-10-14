// ─────────────────────────────────────────────────────────────────────────────
// Contrat partagé de l'annonce d'ouverture d'une bourse suivie (chantier C).
//
// « Suivre » = favori + alerte d'ouverture + rappels de date limite (décision
// propriétaire). Quand l'équipe ouvre un cycle, l'annonce est programmée 120 s
// plus tard, annulable d'ici là, puis écrite dans l'inbox de chaque abonné ; un
// worker envoie ensuite les push au rythme permis (heures calmes, 1 push par
// 30 min et 2 par jour et par étudiant, regroupement).
//
// Ce fichier ne porte AUCUN comportement métier : des noms, des bornes, des
// formes de réponse, et les quelques comparaisons que le serveur et l'admin
// doivent faire à l'identique. Les lots qui suivent (envoi, API étudiant,
// rappels, admin) s'y branchent ; toute modification de contrat passe par lui
// et par `docs/api-contracts.md`. L'admin en garde une copie manuelle :
// `admin/lib/scholarship-opening-types.ts`.
// ─────────────────────────────────────────────────────────────────────────────

import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  Logger,
} from '@nestjs/common';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { NotificationOptOutType } from '../../../common/notification-types';
import type { PushProvider } from '../../notifications/push-sender.service';
import type { ScholarshipReadinessReport } from '../scholarship-content-quality.service';

// ── Genres, routes, clés ────────────────────────────────────────────────────

/** `UserNotification.kind` d'une annonce d'ouverture (inchangé depuis KPB-173). */
export const SCHOLARSHIP_OPENED_KIND = 'scholarship_opened';
/** `type`/`kind` du push groupé (jamais une ligne d'inbox). */
export const SCHOLARSHIP_OPENED_BUNDLE_KIND = 'scholarship_opened_bundle';
/**
 * Route du push groupé, sur toutes les builds. Les builds 53/56 connaissent
 * `/saved`, mais leur écran Favoris n'a pas de section bourses ; le calendrier
 * des échéances liste les bourses et sait filtrer les favoris.
 */
export const OPENING_BUNDLE_ROUTE = '/deadlines';
/**
 * La clé de désinscription globale (`UserProfile.disabledNotificationTypes`).
 * Elle coupe le PUSH seulement : la ligne d'inbox est écrite, `skipped/opt_out`.
 */
export const FOLLOWED_SCHOLARSHIP_OPT_OUT =
  'followed_scholarship_updates' satisfies NotificationOptOutType;

/** Route d'une annonce seule — celle que les builds ≤ 56 savent ouvrir. */
export function scholarshipRoute(scholarshipId: string): string {
  return `/scholarships/${scholarshipId}`;
}

/** Préfixe des références d'annonce : une `dedupeKey` sans son `:<userId>`. */
export const OPENING_REF_PREFIX = 'scholarship-opened';

/** `scholarship-opened:<cycleId>` — ce que le push groupé et l'app renvoient. */
export function openingRef(cycleId: string): string {
  return `${OPENING_REF_PREFIX}:${cycleId}`;
}

/**
 * `scholarship-opened:<cycleId>:<userId>` — le format d'avant ce chantier, gardé
 * à l'octet près : une ligne écrite par l'ancien `activate` et une ligne écrite
 * par le worker pour le même cycle et le même étudiant sont LA MÊME ligne.
 */
export function openingDedupeKey(cycleId: string, userId: string): string {
  return `${openingRef(cycleId)}:${userId}`;
}

/** La `dedupeKey` d'une référence pour un étudiant (`POST /me/notifications/read-by-ref`). */
export function notificationKeyForRef(ref: string, userId: string): string {
  return `${ref}:${userId}`;
}

// ── Modes et portées ────────────────────────────────────────────────────────

/**
 * `KPB_SCHOLARSHIP_OPENING_MODE`, lu à chaque appel (bascule sans redémarrage
 * d'image) :
 * - `legacy` (défaut, et toute valeur illisible) : le chemin d'avant, envoi
 *   immédiat aux seules alertes non mises en sourdine ;
 * - `outbox_alerts` : envoi programmé et worker, alertes seulement ;
 * - `outbox_followers` : envoi programmé et worker, favoris ∪ alertes.
 */
export const SCHOLARSHIP_OPENING_MODES = [
  'legacy',
  'outbox_alerts',
  'outbox_followers',
] as const;
export type ScholarshipOpeningMode = (typeof SCHOLARSHIP_OPENING_MODES)[number];

/** Qui une annonce vise ; figée sur le cycle au moment de la programmation. */
export const OPENING_AUDIENCE_SCOPES = ['alerts', 'followers'] as const;
export type OpeningAudienceScope = (typeof OPENING_AUDIENCE_SCOPES)[number];

/** `process.env` ou un extrait (tests). */
export type OpeningEnv = Readonly<Record<string, string | undefined>>;

export const SCHOLARSHIP_OPENING_MODE_ENV = 'KPB_SCHOLARSHIP_OPENING_MODE';
export const PUSH_OUTBOX_ENABLED_ENV = 'KPB_PUSH_OUTBOX_ENABLED';

const contractLogger = new Logger('ScholarshipOpening');
const warnedInvalidModes = new Set<string>();

export function readScholarshipOpeningMode(
  env: OpeningEnv = process.env,
): ScholarshipOpeningMode {
  const raw = env[SCHOLARSHIP_OPENING_MODE_ENV]?.trim().toLowerCase() ?? '';
  if (raw === '') return 'legacy';
  const known = SCHOLARSHIP_OPENING_MODES.find((mode) => mode === raw);
  if (known) return known;
  // Une seule ligne par valeur illisible : ce lecteur tourne à chaque activation
  // et à chaque aperçu.
  if (!warnedInvalidModes.has(raw)) {
    warnedInvalidModes.add(raw);
    contractLogger.warn(
      `${SCHOLARSHIP_OPENING_MODE_ENV}="${raw.slice(0, 40)}" is not one of ${SCHOLARSHIP_OPENING_MODES.join(', ')}; using legacy.`,
    );
  }
  return 'legacy';
}

export function audienceScopeForMode(
  mode: ScholarshipOpeningMode,
): OpeningAudienceScope {
  return mode === 'outbox_followers' ? 'followers' : 'alerts';
}

/** Vrai hors `legacy` : l'annonce est programmée puis envoyée par le worker. */
export function isOutboxOpeningMode(mode: ScholarshipOpeningMode): boolean {
  return mode !== 'legacy';
}

/** Lecture sûre de `ScholarshipCycle.openingFanoutScope` (un `String` en base). */
export function isOpeningAudienceScope(
  value: unknown,
): value is OpeningAudienceScope {
  return OPENING_AUDIENCE_SCOPES.some((scope) => scope === value);
}

/**
 * Interrupteur d'urgence du worker (`KPB_PUSH_OUTBOX_ENABLED`). Allumé sauf
 * valeur `false` : le mode par défaut, `legacy`, ne programme jamais rien, donc
 * un worker allumé ne fait rien tant que l'exploitation n'a pas basculé.
 * Éteint, les deux phases s'arrêtent (programmations et push en attente
 * patientent ; la péremption évite une rafale à la remise en route).
 */
export function isPushOutboxEnabled(env: OpeningEnv = process.env): boolean {
  return env[PUSH_OUTBOX_ENABLED_ENV]?.trim().toLowerCase() !== 'false';
}

// ── États d'envoi et raisons ────────────────────────────────────────────────

/**
 * `UserNotification.pushStatus`. NULL = ligne héritée ou du dispatcher, que le
 * worker ne touche jamais. Un `String` en base et non une enum Prisma, comme
 * `NotificationDelivery.status` : pas de migration pour un état de plus.
 */
export const PUSH_ROW_STATUSES = [
  'pending',
  'accepted',
  'no_device',
  'failed',
  'skipped',
  'expired',
] as const;
export type PushRowStatus = (typeof PUSH_ROW_STATUSES)[number];

/** `pushLastError` d'une ligne `skipped` : on n'a pas appelé le fournisseur. */
export const PUSH_SKIP_REASONS = [
  'opt_out',
  'push_disabled',
  'muted',
  'unfollowed',
  'not_public',
  'cycle_closed',
  'push_unconfigured',
  'stopped_by_staff',
] as const;
export type PushSkipReason = (typeof PUSH_SKIP_REASONS)[number];

/** `pushLastError` d'une ligne encore `pending`, repoussée (`pushNotBefore`). */
export const PUSH_DEFER_REASONS = [
  'deferred_quiet_hours',
  'deferred_pacing',
  'deferred_busy',
  'retry_provider',
] as const;
export type PushDeferReason = (typeof PUSH_DEFER_REASONS)[number];

/** `pushLastError` d'une ligne `failed`. */
export const PUSH_FAIL_REASONS = ['max_attempts', 'provider_permanent'] as const;
export type PushFailReason = (typeof PUSH_FAIL_REASONS)[number];

export type PushLastError = PushSkipReason | PushDeferReason | PushFailReason;

/** `ScholarshipCycle.openingSkippedReason` : cycle volontairement non annoncé. */
export const CYCLE_OPENING_SKIP_REASONS = [
  'pre_existing_open',
  'dates_only',
  'not_public_at_fanout',
  'cycle_closed_at_fanout',
] as const;
export type CycleOpeningSkipReason = (typeof CYCLE_OPENING_SKIP_REASONS)[number];

/** Variante de copie d'une ligne d'inbox (`data.variant`). */
export const OPENING_COPY_VARIANTS = ['alert', 'favorite', 'dates_confirmed'] as const;
export type OpeningCopyVariant = (typeof OPENING_COPY_VARIANTS)[number];

/** Lecture sûre de `data.variant` (un `Json` en base). */
export function isOpeningCopyVariant(value: unknown): value is OpeningCopyVariant {
  return OPENING_COPY_VARIANTS.some((variant) => variant === value);
}

// ── Réglages ────────────────────────────────────────────────────────────────

/**
 * Entier borné lu dans l'environnement, avec la sémantique du dispatcher
 * (`notification-dispatch.service.ts`) : vide ou illisible = défaut, sinon
 * ramené dans [min, max]. `docker-compose.yml` relaie ces variables avec un
 * défaut vide, qui vaut donc « défaut du code ».
 */
export function readBoundedEnvInt(
  env: OpeningEnv,
  name: string,
  fallback: number,
  min: number,
  max: number,
): number {
  const raw = env[name]?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

export interface OpeningTunables {
  /** Délai entre le geste de l'équipe et l'envoi, annulable (120 s). */
  holdSeconds: number;
  /** Au-delà (strictement), confirmation saisie et rôle admin exigés (500). */
  confirmThreshold: number;
  /** Au plus un push d'ouverture par étudiant sur cette fenêtre (30 min). */
  coalesceMinutes: number;
  /** Au plus N push d'ouverture par étudiant et par jour local (2). */
  maxOpeningPushesPerDay: number;
  /** Pas de nouvelle annonce de la même bourse à un étudiant prévenu depuis moins de N jours (30). */
  renotifyDays: number;
  /** Une ligne encore `pending` N heures après sa création passe `expired` (72). */
  outboxTtlHours: number;
  /** Durée d'un passage du worker avant de rendre la main (60 s). */
  tickBudgetMs: number;
  /** Envois simultanés (8). */
  concurrency: number;
  /** Lignes réservées par lot (200). */
  batchSize: number;
  /** Bail d'une réservation ; jamais moins que `tickBudgetMs + 120 s`. */
  leaseMs: number;
  /** Appels fournisseur avant `failed/max_attempts` (5). */
  maxAttempts: number;
  /** Cycles programmés traités par passage (5). */
  fanoutCyclesPerTick: number;
  /** Une programmation en retard de plus de N heures est abandonnée (24). */
  fanoutMaxLatenessHours: number;
}

/** Marge du bail sur le budget : un envoi peut déborder d'environ 30 s. */
export const PUSH_OUTBOX_LEASE_MARGIN_MS = 120_000;

/** Nom, défaut et bornes de chaque réglage : la seule liste à tenir à jour. */
export const OPENING_TUNABLE_ENV = {
  holdSeconds: { name: 'KPB_OPENING_HOLD_SECONDS', fallback: 120, min: 10, max: 3_600 },
  confirmThreshold: { name: 'KPB_OPENING_CONFIRM_THRESHOLD', fallback: 500, min: 1, max: 1_000_000 },
  coalesceMinutes: { name: 'KPB_OPENING_COALESCE_MINUTES', fallback: 30, min: 1, max: 1_440 },
  maxOpeningPushesPerDay: { name: 'KPB_OPENING_MAX_PER_DAY', fallback: 2, min: 1, max: 10 },
  renotifyDays: { name: 'KPB_OPENING_RENOTIFY_DAYS', fallback: 30, min: 0, max: 365 },
  outboxTtlHours: { name: 'KPB_PUSH_OUTBOX_TTL_HOURS', fallback: 72, min: 1, max: 336 },
  tickBudgetMs: { name: 'KPB_PUSH_OUTBOX_TICK_BUDGET_MS', fallback: 60_000, min: 5_000, max: 300_000 },
  concurrency: { name: 'KPB_PUSH_OUTBOX_CONCURRENCY', fallback: 8, min: 1, max: 32 },
  batchSize: { name: 'KPB_PUSH_OUTBOX_BATCH', fallback: 200, min: 10, max: 1_000 },
  leaseMs: { name: 'KPB_PUSH_OUTBOX_LEASE_MS', fallback: 300_000, min: 60_000, max: 3_600_000 },
  maxAttempts: { name: 'KPB_PUSH_OUTBOX_MAX_ATTEMPTS', fallback: 5, min: 1, max: 10 },
  fanoutCyclesPerTick: { name: 'KPB_OPENING_FANOUT_CYCLES_PER_TICK', fallback: 5, min: 1, max: 50 },
  fanoutMaxLatenessHours: { name: 'KPB_OPENING_FANOUT_MAX_LATENESS_HOURS', fallback: 24, min: 1, max: 168 },
} as const satisfies Record<
  keyof OpeningTunables,
  { name: string; fallback: number; min: number; max: number }
>;

export function readOpeningTunables(
  env: OpeningEnv = process.env,
): OpeningTunables {
  const read = (key: keyof OpeningTunables): number => {
    const spec = OPENING_TUNABLE_ENV[key];
    return readBoundedEnvInt(env, spec.name, spec.fallback, spec.min, spec.max);
  };
  const tickBudgetMs = read('tickBudgetMs');
  return {
    holdSeconds: read('holdSeconds'),
    confirmThreshold: read('confirmThreshold'),
    coalesceMinutes: read('coalesceMinutes'),
    maxOpeningPushesPerDay: read('maxOpeningPushesPerDay'),
    renotifyDays: read('renotifyDays'),
    outboxTtlHours: read('outboxTtlHours'),
    tickBudgetMs,
    concurrency: read('concurrency'),
    batchSize: read('batchSize'),
    // Un bail plus court que le budget plus un envoi lent serait volé à un
    // worker vivant : deux envois de la même ligne.
    leaseMs: Math.max(read('leaseMs'), tickBudgetMs + PUSH_OUTBOX_LEASE_MARGIN_MS),
    maxAttempts: read('maxAttempts'),
    fanoutCyclesPerTick: read('fanoutCyclesPerTick'),
    fanoutMaxLatenessHours: read('fanoutMaxLatenessHours'),
  };
}

/** Attente avant la tentative suivante, indexée par le nombre d'appels déjà faits. */
export const RETRY_BACKOFF_MS = [60_000, 300_000, 1_200_000, 3_600_000] as const;

export function retryDelayMs(previousAttempts: number): number {
  const index = Math.min(
    Math.max(0, Math.trunc(previousAttempts)),
    RETRY_BACKOFF_MS.length - 1,
  );
  return RETRY_BACKOFF_MS[index];
}

// ── Seuil, rôles, tolérance ─────────────────────────────────────────────────

/**
 * « Confirmation saisie AU-DELÀ de 500 destinataires » (propriétaire) : 500
 * exactement n'en demande pas. La seule comparaison du serveur ; l'admin a la
 * même (`needsTypedConfirmation`).
 */
export function isAboveOpeningThreshold(
  toNotify: number,
  threshold: number,
): boolean {
  return toNotify > threshold;
}

/** Les rôles autorisés à envoyer au-delà du seuil. */
export const OPENING_SEND_ROLES: readonly string[] = [
  InternalRole.Admin,
  InternalRole.SuperAdmin,
];

export function canSendAboveOpeningThreshold(
  role: string | null | undefined,
): boolean {
  return role != null && OPENING_SEND_ROLES.includes(role);
}

/**
 * L'audience a-t-elle trop grossi depuis l'aperçu confirmé ? Une baisse est
 * toujours acceptée (moins de destinataires n'est jamais la mauvaise surprise,
 * et l'envoi recalcule à T+120 s) ; une hausse au-delà de max(10, 10 %), ou un
 * franchissement du seuil que la confirmation n'avait pas couvert, est refusée.
 */
export function isOpeningAudienceChangeRejected(
  toNotify: number,
  expectedRecipients: number,
  threshold: number,
): boolean {
  const tolerance = Math.max(10, Math.ceil(0.1 * expectedRecipients));
  return (
    toNotify > expectedRecipients + tolerance ||
    (toNotify > threshold && threshold >= expectedRecipients)
  );
}

// ── Erreurs ─────────────────────────────────────────────────────────────────

export const OPENING_ERROR_CODES = [
  'OPENING_BUSY',
  'OPENING_NOT_RETROACTIVE',
  'OPENING_CONFIRMATION_REQUIRED',
  'OPENING_REQUIRES_ADMIN',
  'OPENING_AUDIENCE_CHANGED',
  'OPENING_NOT_SCHEDULED',
] as const;
export type OpeningErrorCode = (typeof OPENING_ERROR_CODES)[number];

/** `details` de chaque code (celui que `GlobalExceptionFilter` laisse passer). */
export interface OpeningErrorDetails {
  OPENING_BUSY: undefined;
  OPENING_NOT_RETROACTIVE: undefined;
  OPENING_CONFIRMATION_REQUIRED: { toNotify: number; threshold: number };
  OPENING_REQUIRES_ADMIN: { toNotify: number; threshold: number };
  OPENING_AUDIENCE_CHANGED: { toNotify: number; expectedRecipients: number };
  OPENING_NOT_SCHEDULED: { lastFanoutAt: string | null };
}

export const OPENING_ERROR_STATUS = {
  OPENING_BUSY: 409,
  OPENING_NOT_RETROACTIVE: 409,
  OPENING_CONFIRMATION_REQUIRED: 400,
  OPENING_REQUIRES_ADMIN: 403,
  OPENING_AUDIENCE_CHANGED: 409,
  OPENING_NOT_SCHEDULED: 409,
} as const satisfies Record<OpeningErrorCode, 400 | 403 | 409>;

export interface OpeningErrorBody<C extends OpeningErrorCode = OpeningErrorCode> {
  message: string;
  code: C;
  details?: OpeningErrorDetails[C];
}

function count(value: number): string {
  return value.toLocaleString('fr-FR');
}

/**
 * Le message de chaque code, complet et en français (équipe, vouvoiement).
 * L'admin déjà déployé n'affiche que `message` (`readableErrorText`), et il
 * tournera contre ce backend jusqu'au déploiement du nouvel admin : un code nu
 * serait illisible.
 */
export function openingErrorMessage<C extends OpeningErrorCode>(
  code: C,
  details: OpeningErrorDetails[C],
): string {
  // `details` est relu par code : TypeScript ne réduit pas un générique.
  const d = details as Partial<
    OpeningErrorDetails['OPENING_CONFIRMATION_REQUIRED'] &
      OpeningErrorDetails['OPENING_AUDIENCE_CHANGED']
  >;
  switch (code) {
    case 'OPENING_BUSY':
      return 'Un envoi est en cours de préparation pour ce cycle. Réessayez dans quelques secondes.';
    case 'OPENING_NOT_RETROACTIVE':
      return 'Ce cycle était déjà ouvert avant la mise en service des annonces : il ne peut pas être annoncé après coup.';
    case 'OPENING_CONFIRMATION_REQUIRED':
      return `Plus de ${count(d.threshold ?? 0)} étudiants seraient prévenus. Rechargez la page d'administration pour confirmer l'envoi avec le nombre exact.`;
    case 'OPENING_REQUIRES_ADMIN':
      return `Au-delà de ${count(d.threshold ?? 0)} destinataires, l'envoi est réservé aux administrateurs.`;
    case 'OPENING_AUDIENCE_CHANGED':
      return `Le nombre d'abonnés à prévenir a changé (${count(d.toNotify ?? 0)} au lieu de ${count(d.expectedRecipients ?? 0)}). Vérifiez l'aperçu avant de confirmer.`;
    case 'OPENING_NOT_SCHEDULED':
      return "Aucun envoi n'est programmé pour ce cycle : il a déjà commencé ou a été annulé.";
    default:
      return "Annonce d'ouverture refusée.";
  }
}

/** L'exception HTTP d'un code, avec son statut, son message et ses `details`. */
export function openingError<C extends OpeningErrorCode>(
  code: C,
  ...rest: OpeningErrorDetails[C] extends undefined ? [] : [OpeningErrorDetails[C]]
): HttpException {
  const details = rest[0] as OpeningErrorDetails[C];
  const body: OpeningErrorBody<C> = {
    message: openingErrorMessage(code, details),
    code,
    ...(details === undefined ? {} : { details }),
  };
  switch (OPENING_ERROR_STATUS[code]) {
    case 400:
      return new BadRequestException(body);
    case 403:
      return new ForbiddenException(body);
    default:
      return new ConflictException(body);
  }
}

/**
 * Transaction interactive d'annuler et d'arrêter. Chaque geste de l'équipe sur
 * un cycle (`activate`, annuler, arrêter) commence par `SET LOCAL lock_timeout
 * = '5s'` : le worker tient la ligne du cycle `FOR UPDATE` pendant tout un
 * envoi (jusqu'à 120 s). Délais EXPLICITES : le défaut de Prisma (5 s)
 * expirerait pendant l'attente du verrou et rendrait une 500 ; `timeout` >
 * `lock_timeout`, c'est donc le verrou qui cède le premier (409).
 */
export const OPENING_ADMIN_TRANSACTION = { maxWait: 5_000, timeout: 15_000 } as const;

/**
 * Le cycle est occupé : attente de verrou au-delà de `lock_timeout` (`55P03`,
 * que Prisma 6 transmet en `P2010` sur une requête brute) ou transaction
 * interactive expirée / impossible à ouvrir à temps (`P2028`). Les deux se
 * réessaient dans quelques secondes : 409 `OPENING_BUSY`, jamais une 500.
 */
export function isOpeningBusyError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const candidate = error as {
    code?: unknown;
    meta?: { code?: unknown } | null;
    message?: unknown;
  };
  if (candidate.code === '55P03' || candidate.code === 'P2028') return true;
  if (candidate.code === 'P2010' && candidate.meta?.code === '55P03') return true;
  return (
    typeof candidate.message === 'string' &&
    /55P03|lock timeout/i.test(candidate.message)
  );
}

// ── Audit ───────────────────────────────────────────────────────────────────

export const OPENING_AUDIT_ENTITY_TYPE = 'ScholarshipCycle';
/**
 * Un refus d'activation sur une année dont le cycle n'existe pas encore (rien
 * n'est écrit avant les vérifications) : l'événement porte sur la bourse.
 */
export const OPENING_AUDIT_SCHOLARSHIP_ENTITY_TYPE = 'Scholarship';
export const OPENING_AUDIT_PURPOSE = 'scholarship_opening';
/** `requestId` des événements écrits par le worker (pas de requête HTTP). */
export const PUSH_OUTBOX_REQUEST_ID_PREFIX = 'push-outbox:';

export const OPENING_AUDIT_ACTIONS = [
  'scholarship_cycle.opened',
  'scholarship_cycle.notify_scheduled',
  'scholarship_cycle.notified_legacy',
  'scholarship_cycle.dates_updated',
  'scholarship_cycle.notify_cancelled',
  'scholarship_cycle.notify_stopped',
  'scholarship_cycle.fanout_completed',
  'scholarship_cycle.fanout_expired',
] as const;
export type OpeningAuditAction = (typeof OPENING_AUDIT_ACTIONS)[number];

/**
 * L'issue d'un événement d'annonce, telle que le fil de l'équipe doit la dire
 * (`AdminAuditEvent.result`) :
 * - `sent` : le geste a eu lieu tel que l'action le nomme (`success`) ;
 * - `skipped` : une annonce programmée abandonnée sans rien écrire pour les
 *   étudiants — `reasonCode` : `not_public_at_fanout`, `cycle_closed_at_fanout`
 *   ou `fanout_too_late` ;
 * - `refused` : une activation refusée par le serveur — `reasonCode` : le code
 *   d'erreur (`OPENING_REFUSAL_AUDIT_CODES`), l'action étant celle tentée.
 */
export const OPENING_EVENT_OUTCOMES = ['sent', 'skipped', 'refused'] as const;
export type OpeningEventOutcome = (typeof OPENING_EVENT_OUTCOMES)[number];

/** `AdminAuditEvent.result` → issue du fil ; un résultat inconnu reste `sent`. */
export function openingEventOutcome(result: string): OpeningEventOutcome {
  if (result === 'skipped') return 'skipped';
  if (result === 'refused') return 'refused';
  return 'sent';
}

/** Les refus d'activation écrits à l'audit (`result: 'refused'`). */
export const OPENING_REFUSAL_AUDIT_CODES = [
  'OPENING_REQUIRES_ADMIN',
  'OPENING_AUDIENCE_CHANGED',
  'OPENING_NOT_RETROACTIVE',
] as const satisfies readonly OpeningErrorCode[];
export type OpeningRefusalAuditCode = (typeof OPENING_REFUSAL_AUDIT_CODES)[number];

/**
 * `AdminAuditEvent.changes` d'une activation refusée : des comptes et des
 * réglages, aucune donnée personnelle (l'auteur est `actorAdminId`).
 * `toNotify` est `null` quand le refus précède le compte (rétroactivité).
 */
export interface OpeningRefusalAuditChanges {
  academicYear: string;
  notify: boolean | null;
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  toNotify: number | null;
  expectedRecipients: number | null;
  threshold: number;
  actorRole: string;
}

/** `AdminAuditEvent.changes` d'une activation. */
export interface OpeningActivationAuditChanges {
  academicYear: string;
  opensAt: string;
  closesAt: string;
  notify: boolean | null;
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  toNotify: number;
  expectedRecipients: number | null;
  viaFavoriteOnly: number;
  viaAlertOnly: number;
  viaBoth: number;
}

// ── Charge utile push v1 (toutes les valeurs sont des chaînes) ──────────────

/** Au plus 20 références dans un push groupé. */
export const OPENING_BUNDLE_MAX_REFS = 20;

/**
 * Annonce seule. Les builds ≤ 56 ne lisent que `route` et `scholarshipId` ;
 * `notificationKey` permet à la build FCM de marquer l'entrée lue au tap
 * (`POST /me/push-opens`) sans code nouveau.
 */
export type OpeningPushData = {
  route: string;
  scholarshipId: string;
  cycleId: string;
  type: typeof SCHOLARSHIP_OPENED_KIND;
  kind: typeof SCHOLARSHIP_OPENED_KIND;
  notificationKey: string;
  ref: string;
};

/**
 * Push groupé. PAS de `scholarshipId` : un lecteur qui s'y fie ouvrirait une
 * bourse arbitraire du groupe.
 */
export type OpeningBundlePushData = {
  route: typeof OPENING_BUNDLE_ROUTE;
  type: typeof SCHOLARSHIP_OPENED_BUNDLE_KIND;
  kind: typeof SCHOLARSHIP_OPENED_BUNDLE_KIND;
  count: string;
  refs: string;
  scholarshipIds: string;
};

export function openingPushData(input: {
  scholarshipId: string;
  cycleId: string;
  userId: string;
}): OpeningPushData {
  return {
    route: scholarshipRoute(input.scholarshipId),
    scholarshipId: input.scholarshipId,
    cycleId: input.cycleId,
    type: SCHOLARSHIP_OPENED_KIND,
    kind: SCHOLARSHIP_OPENED_KIND,
    notificationKey: openingDedupeKey(input.cycleId, input.userId),
    ref: openingRef(input.cycleId),
  };
}

/**
 * `rows` du plus récent au plus ancien ; `count` les compte TOUS, `refs` et
 * `scholarshipIds` ne portent que les 20 premiers.
 */
export function openingBundlePushData(
  rows: readonly { scholarshipId: string; cycleId: string }[],
): OpeningBundlePushData {
  const head = rows.slice(0, OPENING_BUNDLE_MAX_REFS);
  return {
    route: OPENING_BUNDLE_ROUTE,
    type: SCHOLARSHIP_OPENED_BUNDLE_KIND,
    kind: SCHOLARSHIP_OPENED_BUNDLE_KIND,
    count: String(rows.length),
    refs: head.map((row) => openingRef(row.cycleId)).join(','),
    scholarshipIds: head.map((row) => row.scholarshipId).join(','),
  };
}

// ── Réponses HTTP (dates en ISO 8601) ───────────────────────────────────────

export type IsoDateTime = string;

export interface LocalizedPushCopy {
  title: string;
  body: string;
}

export interface OpeningAdminRef {
  id: string;
  name: string;
}

/** `POST /admin/scholarships/:id/activate` — notification.state. */
export const OPENING_NOTIFICATION_STATES = [
  'scheduled',
  'already_scheduled',
  'nothing_to_send',
  'sent_legacy',
  'none',
] as const;
export type OpeningNotificationState = (typeof OPENING_NOTIFICATION_STATES)[number];

export const OPENING_NOTIFICATION_REASONS = [
  'dates_only',
  'already_announced',
  'pre_existing_open',
  'legacy_first_activation_only',
] as const;
export type OpeningNotificationReason = (typeof OPENING_NOTIFICATION_REASONS)[number];

/** Les six premières clés sont celles d'avant ce chantier, mêmes types. */
export interface ActivateScholarshipResponse {
  scholarshipId: string;
  cycleId: string;
  status: string;
  firstActivation: boolean;
  /** legacy : alertes non mises en sourdine lues ; envoi programmé : audience de la portée avant déduplication. */
  subscribers: number;
  /** 0 hors legacy. */
  pushesSent: number;
  academicYear: string;
  mode: ScholarshipOpeningMode;
  notification: {
    state: OpeningNotificationState;
    toNotify: number;
    fanoutAt: IsoDateTime | null;
    reason: OpeningNotificationReason | null;
  };
}

/** `GET /admin/scholarships/:id/opening-preview` — un cycle de la bourse. */
export interface OpeningPreviewCycle {
  id: string;
  academicYear: string;
  /** Statut servi (`servedCycleStatus`) ; `rawStatus` est le littéral en base. */
  status: string;
  rawStatus: string;
  dateConfidence: string;
  opensAt: IsoDateTime | null;
  closesAt: IsoDateTime | null;
  estimatedOpenAt: IsoDateTime | null;
  estimatedCloseAt: IsoDateTime | null;
  activatedAt: IsoDateTime | null;
  openingNotifiedAt: IsoDateTime | null;
  openingNotifiedBy: OpeningAdminRef | null;
  openingAudience: number | null;
  openingFanoutDueAt: IsoDateTime | null;
  openingLastFanoutAt: IsoDateTime | null;
  openingSkippedAt: IsoDateTime | null;
  openingSkippedReason: CycleOpeningSkipReason | null;
  openingStoppedAt: IsoDateTime | null;
  openingPreExisting: boolean;
}

export interface OpeningPreviewTarget {
  academicYear: string;
  cycleId: string | null;
  exists: boolean;
  firstActivation: boolean;
  alreadyAnnounced: boolean;
  /** = `openingPreExisting` : ouvert ou activé avant la mise en service. */
  preExistingOpen: boolean;
  fanoutScheduledAt: IsoDateTime | null;
  defaultNotify: boolean;
}

/**
 * Toutes les clés décrivent l'ensemble `toNotify`, sauf `followers`, `muted`,
 * `alreadyNotifiedThisCycle` et `recentlyNotified`, qui décrivent les
 * exclusions. Sur une relance, `toNotify` exclut déjà ceux qui suivaient avant
 * la première annonce ; `followers` non.
 */
export interface OpeningAudienceSummary {
  followers: number;
  viaFavoriteOnly: number;
  viaAlertOnly: number;
  viaBoth: number;
  muted: number;
  alreadyNotifiedThisCycle: number;
  recentlyNotified: number;
  toNotify: number;
  pushEligible: number;
  optedOut: number;
  pushDisabled: number;
  /** Évalué à `now + holdSeconds`. */
  deferredQuietHours: number;
  deferredPacing: number;
  byLanguage: { fr: number; en: number };
  devices: { fcm: number; oneSignalOnly: number };
}

export type OpeningPreviewCopyVariant = 'opened' | 'dates_confirmed';

export interface OpeningPreviewCopy {
  variant: OpeningPreviewCopyVariant;
  fr: { alert: LocalizedPushCopy; favorite: LocalizedPushCopy };
  en: { alert: LocalizedPushCopy; favorite: LocalizedPushCopy };
  bundleExample: { fr: LocalizedPushCopy; en: LocalizedPushCopy };
}

export interface OpeningRecentEvent {
  action: OpeningAuditAction;
  occurredAt: IsoDateTime;
  actorName: string | null;
  academicYear: string | null;
  toNotify: number | null;
  /**
   * Ce qui s'est réellement passé (`OPENING_EVENT_OUTCOMES`) : un envoi
   * abandonné (`skipped`) ou une activation refusée (`refused`) ne se lit pas
   * comme un envoi fait, quelle que soit l'action.
   */
  outcome: OpeningEventOutcome;
  /** Pourquoi, pour `skipped` et `refused` ; absent pour `sent`. */
  reasonCode?: string;
}

export interface OpeningPreviewResponse {
  scholarshipId: string;
  name: { fr: string; en: string };
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  holdSeconds: number;
  confirmThreshold: number;
  canSendAboveThreshold: boolean;
  worker: { enabled: boolean; oldestDuePendingSeconds: number };
  push: { configured: boolean; fcm: boolean; oneSignal: boolean };
  cycles: OpeningPreviewCycle[];
  nextAcademicYear: string;
  target: OpeningPreviewTarget;
  readiness: ScholarshipReadinessReport;
  audience: OpeningAudienceSummary;
  copy: OpeningPreviewCopy;
  recentEvents: OpeningRecentEvent[];
}

/** `POST …/cycles/:cycleId/opening/cancel` (rien n'a été écrit pour les étudiants). */
export interface CancelOpeningResponse {
  cycleId: string;
  cancelled: true;
}

/** `POST …/cycles/:cycleId/opening/stop` (les entrées d'inbox restent). */
export interface StopOpeningResponse {
  cycleId: string;
  stopped: number;
  inFlight: number;
}

export interface OpeningReportSkipped {
  total: number;
  optOut: number;
  pushDisabled: number;
  muted: number;
  unfollowed: number;
  notPublic: number;
  cycleClosed: number;
  pushUnconfigured: number;
  stoppedByStaff: number;
}

/** La clé du rapport de chaque raison de saut — vérifiée exhaustive par le typage. */
export const PUSH_SKIP_REASON_REPORT_KEY = {
  opt_out: 'optOut',
  push_disabled: 'pushDisabled',
  muted: 'muted',
  unfollowed: 'unfollowed',
  not_public: 'notPublic',
  cycle_closed: 'cycleClosed',
  push_unconfigured: 'pushUnconfigured',
  stopped_by_staff: 'stoppedByStaff',
} as const satisfies Record<PushSkipReason, Exclude<keyof OpeningReportSkipped, 'total'>>;

/**
 * `GET …/cycles/:cycleId/opening-report`. Vocabulaire : « acceptées par le
 * fournisseur », jamais « reçues » ni « délivrées » — un 200 de FCM ou de
 * OneSignal ne dit pas que le téléphone a affiché quoi que ce soit.
 */
export interface OpeningReportResponse {
  scholarshipId: string;
  cycleId: string;
  academicYear: string;
  fanout: {
    scheduledAt: IsoDateTime | null;
    /** = `openingNotifiedAt` (première annonce). */
    completedAt: IsoDateTime | null;
    lastFanoutAt: IsoDateTime | null;
    stoppedAt: IsoDateTime | null;
    notifiedBy: OpeningAdminRef | null;
    scope: OpeningAudienceScope | null;
  };
  inbox: { total: number; read: number };
  push: {
    /** Lignes acceptées ; `acceptedPushes` compte les push (un groupé = 1). */
    accepted: number;
    acceptedPushes: number;
    noDevice: number;
    failed: number;
    expired: number;
    pending: number;
    deferredQuietHours: number;
    /** `deferred_pacing` + `deferred_busy`. */
    deferredPacing: number;
    retrying: number;
    skipped: OpeningReportSkipped;
    /** Lignes héritées (`pushStatus IS NULL`). */
    untracked: number;
  };
  byProvider: Record<PushProvider, number>;
  oldestDuePendingAt: IsoDateTime | null;
  generatedAt: IsoDateTime;
}

/** `GET /admin/scholarships/opening-todo` : au plus 100 lignes. */
export const OPENING_TODO_LIMIT = 100;

export interface OpeningTodoItem {
  scholarshipId: string;
  nameFr: string;
  cycleId: string;
  academicYear: string;
  opensAt: IsoDateTime | null;
  closesAt: IsoDateTime | null;
  /** `catalogue` quand `activatedAt IS NULL`, sinon `admin`. */
  source: 'catalogue' | 'admin';
  /** Suivent la bourse (favori ou alerte non mise en sourdine), toute portée. */
  followers: number;
  /**
   * « Abonnés à prévenir » : l'audience de la portée — le MÊME nombre que la
   * colonne « Abonnés » de la liste (`OpeningOverviewItem.notifiable`, même
   * requête) et, pour ce cycle jamais annoncé, que le `toNotify` de l'aperçu
   * (hors étudiants prévenus pour un autre cycle de la bourse depuis 30 jours).
   * Portée `alerts` : alertes non mises en sourdine ; `followers` : suivent,
   * hors sourdine. La file est triée sur ce nombre.
   */
  notifiable: number;
}

export interface OpeningTodoResponse {
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  items: OpeningTodoItem[];
  total: number;
}

/** `GET /admin/scholarships/opening-overview` — colonnes « Abonnés » et « Annoncé ». */
export interface OpeningOverviewItem {
  scholarshipId: string;
  /** Suivent (favori ou alerte non mise en sourdine). */
  followers: number;
  /** L'audience de la portée (portée `alerts` : alertes non mises en sourdine). */
  notifiable: number;
  lastAnnounced: {
    cycleId: string;
    academicYear: string;
    at: IsoDateTime;
    audience: number | null;
  } | null;
  scheduledAt: IsoDateTime | null;
}

export interface OpeningOverviewResponse {
  mode: ScholarshipOpeningMode;
  scope: OpeningAudienceScope;
  items: OpeningOverviewItem[];
}

// ── Routes étudiant ─────────────────────────────────────────────────────────

/** `PATCH /me/scholarship-alerts/:scholarshipId` — `following` relu après écriture. */
export interface ScholarshipAlertPreferenceResponse {
  scholarshipId: string;
  following: boolean;
  notifyOpening: boolean;
}

/** Bloc additif `follow` de `GET /scholarships/:id`. */
export interface ScholarshipFollowState {
  following: boolean;
  viaFavorite: boolean;
  viaAlert: boolean;
  notifyOpening: boolean;
  globalOptOut: boolean;
}

export const FOLLOWED_DISPLAY_STATUSES = [
  'open',
  'opening_confirmed',
  'forecast',
  'closed',
] as const;
export type FollowedDisplayStatus = (typeof FOLLOWED_DISPLAY_STATUSES)[number];

/** `GET /me/followed-scholarships` : au plus 200 lignes, bourses closes comprises. */
export const FOLLOWED_SCHOLARSHIPS_LIMIT = 200;

export interface FollowedScholarshipItem {
  id: string;
  title: string;
  countryId: string;
  countryName: string;
  displayStatus: FollowedDisplayStatus;
  academicYear: string | null;
  opensAt: IsoDateTime | null;
  closesAt: IsoDateTime | null;
  estimatedOpenAt: IsoDateTime | null;
  estimatedCloseAt: IsoDateTime | null;
  deadlineAt: IsoDateTime | null;
  dateConfidence: string | null;
  viaFavorite: boolean;
  viaAlert: boolean;
  notifyOpening: boolean;
  /** Passe `publicScholarshipWhere` : sinon la fiche répondrait 404. */
  detailAvailable: boolean;
}

export interface FollowedScholarshipsResponse {
  items: FollowedScholarshipItem[];
  total: number;
  globalOptOut: boolean;
}

/** `GET /me/notifications/unread-count`. */
export interface UnreadNotificationsCountResponse {
  unreadCount: number;
}

/** `POST /me/notifications/read-by-ref` : au plus 20 références par appel. */
export const READ_BY_REF_MAX_REFS = 20;
export const READ_BY_REF_MAX_LENGTH = 200;
export const READ_BY_REF_PATTERN = /^[A-Za-z0-9:_-]+$/;

export interface ReadNotificationsByRefResponse {
  updated: number;
}
