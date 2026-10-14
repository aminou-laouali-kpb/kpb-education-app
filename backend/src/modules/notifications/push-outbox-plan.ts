// ─────────────────────────────────────────────────────────────────────────────
// Boîte d'envoi des annonces d'ouverture — la décision, par élève.
//
// Pur : aucune base, aucune horloge, aucun hasard lus ici (l'heure et la source
// aléatoire sont passées). Le worker (`push-outbox-worker.service.ts`) réserve
// les lignes, les enrichit, appelle `planUserPushes`, puis applique le plan.
//
// Pour chaque élève, dans cet ordre :
//   0. un autre worker vivant tient une de ses lignes → tout est repoussé
//      (`deferred_busy`), rien d'autre n'est évalué ;
//   1. par ligne : périmée (TTL depuis `createdAt`), arrêtée par l'équipe,
//      désinscription globale, push coupé, sourdine, plus suivie, bourse plus
//      publique, cycle clos → la ligne est close sans appel au fournisseur ;
//   2. aucun fournisseur configuré → `push_unconfigured` (pas d'arriéré) ;
//   3. heures calmes → tout repoussé à 8 h locales + décalage stable ;
//   4. rythme : 1 push par 30 min, 2 par jour local ;
//   5. sinon un envoi : la ligne seule, ou un push groupé pour 2 lignes ou plus
//      (titre neutre si l'une d'elles est un « Dates confirmées »).
//
// Un report n'est jamais une tentative (`pushAttempts` inchangé).
// ─────────────────────────────────────────────────────────────────────────────

import { createHash } from 'node:crypto';

import {
  isWithinQuietHours,
  utcOffsetHoursForCountry,
} from '../../common/country-timezone';
import {
  localDayStart,
  nextLocalHour,
  userJitterMs,
  type QuietHours,
} from '../../common/push-quiet-hours';
import {
  openingBundlePushData,
  openingPushData,
  type OpeningCopyVariant,
  type PushDeferReason,
  type PushSkipReason,
} from '../scholarships-index/opening/scholarship-opening.contract';
import {
  buildBundleCopy,
  openingLanguage,
} from '../scholarships-index/opening/scholarship-opening.copy';

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

/** Report quand un autre worker tient l'élève : 60 s + 0–30 s au hasard. */
export const BUSY_DEFER_BASE_MS = 60_000;
export const BUSY_DEFER_JITTER_MS = 30_000;

/** Une ligne réservée, enrichie de ce qu'il faut pour décider. */
export interface OutboxPlanRow {
  id: string;
  userId: string;
  scholarshipId: string | null;
  cycleId: string | null;
  dedupeKey: string;
  titleFr: string;
  titleEn: string;
  bodyFr: string;
  bodyEn: string;
  pushAttempts: number;
  createdAt: Date;
  /**
   * `data.variant` de la ligne, posé à l'envoi : `dates_confirmed` quand
   * l'ouverture était encore à venir. `null` si absent ou illisible.
   */
  variant: OpeningCopyVariant | null;
  /** Un favori existe. */
  favorite: boolean;
  /** Une alerte non mise en sourdine existe. */
  alertActive: boolean;
  /** Une alerte en sourdine existe (prime sur le favori). */
  muted: boolean;
  /** `pushEnabled` de l'alerte (vrai sans alerte). */
  pushEnabled: boolean;
  /** La bourse passe `publicScholarshipWhere` à cet instant. */
  scholarshipPublic: boolean;
  scholarshipNameFr: string | null;
  scholarshipNameEn: string | null;
  /** Le cycle existe encore. */
  cycleExists: boolean;
  /** `COALESCE(closesAt, estimatedCloseAt)`. */
  cycleCloseAt: Date | null;
  /** `openingStoppedAt` : « Arrêter les envois restants ». */
  cycleStoppedAt: Date | null;
}

export interface OutboxPlanUser {
  userId: string;
  preferredLanguage: string | null;
  countryOfResidence: string | null;
  /** `followed_scholarship_updates` dans `disabledNotificationTypes`. */
  optedOut: boolean;
  /**
   * Push d'ouverture acceptés récemment (48 h). Une entrée = un push :
   * `pushedAt` n'est posé que sur la ligne de tête d'un groupé.
   */
  recentPushes: readonly RecentOpeningPush[];
  /** Un autre worker vivant tient une ligne en attente de cet élève. */
  contended: boolean;
  rows: readonly OutboxPlanRow[];
}

export interface RecentOpeningPush {
  pushedAt: Date;
  batchId: string | null;
}

export interface OutboxPlanSettings {
  ttlHours: number;
  coalesceMinutes: number;
  maxOpeningPushesPerDay: number;
  quiet: QuietHours;
  pushConfigured: boolean;
  /** Source aléatoire dans [0, 1) (report `deferred_busy`). */
  random: () => number;
}

export type OutboxRowFinal =
  | { rowId: string; status: 'expired' }
  | { rowId: string; status: 'skipped'; reason: PushSkipReason };

export interface OutboxDeferral {
  rowIds: string[];
  until: Date;
  reason: PushDeferReason;
}

export interface OutboxSendRow {
  id: string;
  pushAttempts: number;
}

export interface OutboxSend {
  kind: 'single' | 'bundle';
  /** Du plus récent au plus ancien ; la première est la ligne de tête. */
  rows: OutboxSendRow[];
  leadRowId: string;
  title: string;
  body: string;
  data: Record<string, string>;
  /** `dedupeKey`, ou les identifiants triés des lignes d'un groupé. */
  idempotencyKey: string;
  /** `kpb-` + 32 caractères hexadécimaux, tiré de la même clé. */
  collapseKey: string;
}

export interface UserPushPlan {
  userId: string;
  finals: OutboxRowFinal[];
  deferral: OutboxDeferral | null;
  send: OutboxSend | null;
}

/** La clé de regroupement FCM/OneSignal d'une clé d'envoi (64 octets au plus). */
export function openingCollapseKey(key: string): string {
  return `kpb-${createHash('sha1').update(key).digest('hex').slice(0, 32)}`;
}

/**
 * Le rythme d'un élève à `now` : `null` s'il peut recevoir un push d'ouverture
 * maintenant, sinon l'instant à partir duquel il le pourra.
 * - au plus `maxPerDay` push par jour LOCAL → 8 h locales du lendemain (+ son
 *   décalage stable) ;
 * - au plus 1 push par `coalesceMinutes` → dernier push + fenêtre.
 *
 * Partagé avec l'aperçu admin (« N plus tard (rythme) »).
 */
export function pacingDeferral(input: {
  userId: string;
  offsetHours: number;
  recentPushes: readonly RecentOpeningPush[];
  now: Date;
  coalesceMinutes: number;
  maxPerDay: number;
  quiet: QuietHours;
}): { until: Date } | null {
  const { now, offsetHours } = input;
  let until: number | null = null;

  const dayStart = localDayStart(now, offsetHours).getTime();
  const pushesToday = new Set(
    input.recentPushes
      .filter((push) => push.pushedAt.getTime() >= dayStart)
      .map((push) => push.batchId ?? `at:${push.pushedAt.toISOString()}`),
  );
  if (pushesToday.size >= input.maxPerDay) {
    // Le premier `endHour:00` du jour local suivant, jamais celui d'aujourd'hui.
    const tomorrow = new Date(dayStart + DAY_MS - 1);
    until =
      nextLocalHour(tomorrow, offsetHours, input.quiet.endHour).getTime() +
      userJitterMs(input.userId);
  }

  const last = input.recentPushes.reduce<number | null>(
    (max, push) =>
      max === null || push.pushedAt.getTime() > max
        ? push.pushedAt.getTime()
        : max,
    null,
  );
  if (last !== null) {
    const coalesceEnd = last + input.coalesceMinutes * MINUTE_MS;
    if (coalesceEnd > now.getTime()) {
      until = until === null ? coalesceEnd : Math.max(until, coalesceEnd);
    }
  }

  return until === null ? null : { until: new Date(until) };
}

function rowSkipReason(
  row: OutboxPlanRow,
  user: OutboxPlanUser,
  now: Date,
): PushSkipReason | null {
  if (row.cycleStoppedAt && row.createdAt.getTime() <= row.cycleStoppedAt.getTime()) {
    return 'stopped_by_staff';
  }
  if (user.optedOut) return 'opt_out';
  if (!row.pushEnabled) return 'push_disabled';
  if (row.muted) return 'muted';
  if (!row.favorite && !row.alertActive) return 'unfollowed';
  if (!row.scholarshipId || !row.scholarshipPublic) return 'not_public';
  if (
    !row.cycleId ||
    !row.cycleExists ||
    (row.cycleCloseAt && row.cycleCloseAt.getTime() <= now.getTime())
  ) {
    return 'cycle_closed';
  }
  return null;
}

function byMostRecent(a: OutboxPlanRow, b: OutboxPlanRow): number {
  return (
    b.createdAt.getTime() - a.createdAt.getTime() ||
    (a.id < b.id ? 1 : a.id > b.id ? -1 : 0)
  );
}

function buildSend(
  user: OutboxPlanUser,
  rows: OutboxPlanRow[],
): OutboxSend {
  const ordered = [...rows].sort(byMostRecent);
  const lead = ordered[0];
  const lang = openingLanguage(user.preferredLanguage);
  const sendRows = ordered.map((row) => ({
    id: row.id,
    pushAttempts: row.pushAttempts,
  }));

  if (ordered.length === 1) {
    return {
      kind: 'single',
      rows: sendRows,
      leadRowId: lead.id,
      title: lang === 'en' ? lead.titleEn : lead.titleFr,
      body: lang === 'en' ? lead.bodyEn : lead.bodyFr,
      data: openingPushData({
        // Non nuls : `rowSkipReason` a écarté les lignes sans bourse ni cycle.
        scholarshipId: lead.scholarshipId ?? '',
        cycleId: lead.cycleId ?? '',
        userId: user.userId,
      }),
      idempotencyKey: lead.dedupeKey,
      collapseKey: openingCollapseKey(lead.dedupeKey),
    };
  }

  const names = ordered.map((row) =>
    lang === 'en'
      ? (row.scholarshipNameEn ?? row.scholarshipNameFr ?? '')
      : (row.scholarshipNameFr ?? row.scholarshipNameEn ?? ''),
  );
  // Une ligne « Dates confirmées » (ou de variante inconnue) n'annonce pas
  // une ouverture : le groupé ne dit alors pas « ouvertes ».
  const allOpened = ordered.every(
    (row) => row.variant === 'alert' || row.variant === 'favorite',
  );
  const copy = buildBundleCopy(
    names,
    lang,
    allOpened ? 'opened' : 'dates_confirmed',
  );
  const key = ordered
    .map((row) => row.id)
    .sort()
    .join(',');
  return {
    kind: 'bundle',
    rows: sendRows,
    leadRowId: lead.id,
    title: copy.title,
    body: copy.body,
    data: openingBundlePushData(
      ordered.map((row) => ({
        scholarshipId: row.scholarshipId ?? '',
        cycleId: row.cycleId ?? '',
      })),
    ),
    idempotencyKey: key,
    collapseKey: openingCollapseKey(key),
  };
}

export function planUserPush(
  user: OutboxPlanUser,
  now: Date,
  settings: OutboxPlanSettings,
): UserPushPlan {
  const plan: UserPushPlan = {
    userId: user.userId,
    finals: [],
    deferral: null,
    send: null,
  };
  if (user.rows.length === 0) return plan;

  // 0. Un autre worker tient cet élève : se retirer, au hasard (un décalage
  //    propre à l'élève donnerait la même heure aux deux et ils se
  //    recroiseraient).
  if (user.contended) {
    plan.deferral = {
      rowIds: user.rows.map((row) => row.id),
      until: new Date(
        now.getTime() +
          BUSY_DEFER_BASE_MS +
          Math.floor(settings.random() * BUSY_DEFER_JITTER_MS),
      ),
      reason: 'deferred_busy',
    };
    return plan;
  }

  // 1. Ce qui ne partira jamais.
  const ttlMs = settings.ttlHours * HOUR_MS;
  const sendable: OutboxPlanRow[] = [];
  for (const row of user.rows) {
    if (row.createdAt.getTime() < now.getTime() - ttlMs) {
      plan.finals.push({ rowId: row.id, status: 'expired' });
      continue;
    }
    const reason = rowSkipReason(row, user, now);
    if (reason) {
      plan.finals.push({ rowId: row.id, status: 'skipped', reason });
      continue;
    }
    sendable.push(row);
  }
  if (sendable.length === 0) return plan;

  // 2. Aucun fournisseur : clore plutôt que laisser un arriéré grossir.
  if (!settings.pushConfigured) {
    for (const row of sendable) {
      plan.finals.push({
        rowId: row.id,
        status: 'skipped',
        reason: 'push_unconfigured',
      });
    }
    return plan;
  }

  const offset = utcOffsetHoursForCountry(user.countryOfResidence);
  const rowIds = sendable.map((row) => row.id);

  // 3. Heures calmes.
  if (
    isWithinQuietHours(
      now,
      offset,
      settings.quiet.startHour,
      settings.quiet.endHour,
    )
  ) {
    plan.deferral = {
      rowIds,
      until: new Date(
        nextLocalHour(now, offset, settings.quiet.endHour).getTime() +
          userJitterMs(user.userId),
      ),
      reason: 'deferred_quiet_hours',
    };
    return plan;
  }

  // 4. Rythme.
  const pacing = pacingDeferral({
    userId: user.userId,
    offsetHours: offset,
    recentPushes: user.recentPushes,
    now,
    coalesceMinutes: settings.coalesceMinutes,
    maxPerDay: settings.maxOpeningPushesPerDay,
    quiet: settings.quiet,
  });
  if (pacing) {
    plan.deferral = { rowIds, until: pacing.until, reason: 'deferred_pacing' };
    return plan;
  }

  // 5. Un push : la ligne seule, ou un groupé.
  plan.send = buildSend(user, sendable);
  return plan;
}

export function planUserPushes(
  users: readonly OutboxPlanUser[],
  now: Date,
  settings: OutboxPlanSettings,
): UserPushPlan[] {
  return users.map((user) => planUserPush(user, now, settings));
}
