import { randomUUID } from 'node:crypto';
import { hostname } from 'node:os';

import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';

import { readQuietHours } from '../../common/push-quiet-hours';
import { PrismaService } from '../prisma/prisma.service';
import { ScholarshipOpeningFanoutService } from '../scholarships-index/opening/scholarship-opening-fanout.service';
import {
  FOLLOWED_SCHOLARSHIP_OPT_OUT,
  isOpeningCopyVariant,
  isPushOutboxEnabled,
  readOpeningTunables,
  retryDelayMs,
  SCHOLARSHIP_OPENED_KIND,
  type OpeningTunables,
  type PushDeferReason,
} from '../scholarships-index/opening/scholarship-opening.contract';
import {
  planUserPushes,
  type OutboxPlanRow,
  type OutboxPlanUser,
  type OutboxSend,
  type RecentOpeningPush,
  type UserPushPlan,
} from './push-outbox-plan';
import {
  PushSenderService,
  type PushDeliveryOutcome,
} from './push-sender.service';

const POLL_INTERVAL_MS = 10_000;
/** Fenêtre du rythme : plafond par jour local, fusion sur 30 min. */
const PACING_LOOKBACK_MS = 48 * 60 * 60 * 1000;

/** Une ligne réservée par ce worker. */
export interface ClaimedOutboxRow {
  id: string;
  userId: string;
  scholarshipId: string | null;
  cycleId: string | null;
  kind: string;
  dedupeKey: string;
  titleFr: string;
  titleEn: string;
  bodyFr: string;
  bodyEn: string;
  route: string;
  pushAttempts: number;
  createdAt: Date;
  /** `data->>'variant'` : `alert`, `favorite` ou `dates_confirmed`. */
  variant: string | null;
}

interface EnrichedRow {
  id: string;
  preferredLanguage: string | null;
  countryOfResidence: string | null;
  optedOut: boolean;
  favorite: boolean;
  muted: boolean;
  alertActive: boolean;
  pushEnabled: boolean;
  scholarshipPublic: boolean;
  nameFr: string | null;
  nameEn: string | null;
  cycleExists: boolean;
  closeAt: Date | null;
  stoppedAt: Date | null;
}

/** Le bilan d'un passage — la seule ligne de journal du worker. */
export interface PushOutboxTally {
  fanoutCycles: number;
  fanoutRows: number;
  accepted: number;
  acceptedPushes: number;
  noDevice: number;
  deferredQuiet: number;
  deferredPacing: number;
  deferredBusy: number;
  retry: number;
  failed: number;
  skipped: number;
  expired: number;
  released: number;
  leaseLost: number;
  /** Comptes par raison (sauts, échecs, réponses du fournisseur). */
  reasons: Record<string, number>;
}

export function emptyPushOutboxTally(): PushOutboxTally {
  return {
    fanoutCycles: 0,
    fanoutRows: 0,
    accepted: 0,
    acceptedPushes: 0,
    noDevice: 0,
    deferredQuiet: 0,
    deferredPacing: 0,
    deferredBusy: 0,
    retry: 0,
    failed: 0,
    skipped: 0,
    expired: 0,
    released: 0,
    leaseLost: 0,
    reasons: {},
  };
}

function countReason(tally: PushOutboxTally, reason: string | null, n = 1): void {
  if (!reason || n <= 0) return;
  tally.reasons[reason] = (tally.reasons[reason] ?? 0) + n;
}

/** Au plus `concurrency` appels en vol ; une erreur n'arrête pas les autres. */
async function runPool<T>(
  items: readonly T[],
  concurrency: number,
  worker: (item: T) => Promise<void>,
): Promise<void> {
  let next = 0;
  const lanes = Array.from(
    { length: Math.max(0, Math.min(concurrency, items.length)) },
    async () => {
      while (next < items.length) {
        const item = items[next];
        next += 1;
        await worker(item);
      }
    },
  );
  await Promise.all(lanes);
}

function hasSend(plan: UserPushPlan): plan is UserPushPlan & { send: OutboxSend } {
  return plan.send !== null;
}

/**
 * Le worker de la boîte d'envoi des annonces d'ouverture (chantier C).
 *
 * Toutes les 10 s, dans un budget de temps (`KPB_PUSH_OUTBOX_TICK_BUDGET_MS`) :
 *   1. les annonces programmées échues deviennent des lignes d'inbox
 *      (`ScholarshipOpeningFanoutService`, rejoué entre deux lots pour qu'une
 *      annonce échue pendant un long passage ne prenne pas 90 s de retard) ;
 *   2. les lignes `pending` échues sont réservées (`FOR UPDATE SKIP LOCKED`,
 *      bail fencé par `pushLockedBy`), avec toutes celles du même élève ;
 *   3. `planUserPushes` décide (heures calmes, rythme, groupé, sauts) ;
 *   4. les envois partent par `PushSenderService.sendWithStatus`, 8 en vol ;
 *      chaque finalisation exige encore le bail (`pushLockedBy = moi`), sans
 *      transaction ouverte pendant l'appel au fournisseur.
 *
 * Plusieurs replicas peuvent tourner : un cycle, une ligne et un élève ne sont
 * jamais traités par deux workers à la fois (verrous, bail, règle de
 * contention du plan). Interrupteur d'urgence : `KPB_PUSH_OUTBOX_ENABLED=false`
 * arrête les deux phases.
 */
@Injectable()
export class PushOutboxWorkerService {
  private readonly logger = new Logger(PushOutboxWorkerService.name);
  /** Public pour les sondes et les tests (bail fencé). */
  readonly workerId = `${hostname()}:${process.pid}:${randomUUID()}`;
  private polling = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushSenderService,
    private readonly fanout: ScholarshipOpeningFanoutService,
  ) {}

  @Interval(POLL_INTERVAL_MS)
  async poll(): Promise<void> {
    if (this.polling || !this.prisma.isEnabled || !isPushOutboxEnabled()) {
      return;
    }
    this.polling = true;
    try {
      await this.runOnce();
    } catch (error) {
      this.logger.error(`Push outbox tick failed (${safeErrorCode(error)}).`);
    } finally {
      this.polling = false;
    }
  }

  /**
   * Un passage. `clock` part de `now` et avance avec le temps réel, sauf si
   * un test en fournit une : chaque décision par élève (heures calmes, rythme,
   * `pushedAt`) lit l'heure au moment où elle est prise, pas celle du début
   * d'un passage qui peut durer 90 s.
   */
  async runOnce(
    now: Date = new Date(),
    clock?: () => number,
  ): Promise<PushOutboxTally> {
    const realStart = Date.now();
    const tick = clock ?? (() => now.getTime() + (Date.now() - realStart));
    const tunables = readOpeningTunables();
    const quiet = readQuietHours();
    const tally = emptyPushOutboxTally();
    const start = tick();
    const outOfBudget = () => tick() - start >= tunables.tickBudgetMs;
    const held = new Set<string>();

    try {
      while (!outOfBudget()) {
        await this.runFanout(new Date(tick()), tally);

        const batchNow = new Date(tick());
        const claimed = await this.claim(batchNow, tunables.batchSize, tunables.leaseMs);
        if (claimed.length === 0) break;
        const siblings = await this.claimSiblings(
          [...new Set(claimed.map((row) => row.userId))],
          batchNow,
          tunables.leaseMs,
        );
        const rows = [...claimed, ...siblings];
        for (const row of rows) held.add(row.id);

        const users = await this.enrich(rows, new Date(tick()));
        const planNow = new Date(tick());
        const plans = planUserPushes(users, planNow, {
          ttlHours: tunables.outboxTtlHours,
          coalesceMinutes: tunables.coalesceMinutes,
          maxOpeningPushesPerDay: tunables.maxOpeningPushesPerDay,
          quiet,
          pushConfigured: this.push.isConfigured,
          random: Math.random,
        });
        await this.applyWithoutSend(plans, tally);

        await runPool(plans.filter(hasSend), tunables.concurrency, async (plan) => {
          const ids = plan.send.rows.map((row) => row.id);
          if (outOfBudget()) {
            tally.released += await this.release(ids);
            return;
          }
          try {
            const outcome = await this.push.sendWithStatus(
              plan.userId,
              plan.send.title,
              plan.send.body,
              plan.send.data,
              {
                collapseKey: plan.send.collapseKey,
                idempotencyKey: plan.send.idempotencyKey,
              },
            );
            await this.finalize(plan.send, outcome, new Date(tick()), tunables, tally);
          } catch (error) {
            // Le fournisseur a peut-être accepté avant l'erreur : ces lignes
            // restent sous bail et ne reviennent qu'à son expiration, jamais
            // par la libération de fin de passage (renvoi immédiat).
            for (const rowId of ids) held.delete(rowId);
            this.logger.error(`Push outbox send failed (${safeErrorCode(error)}).`);
          }
        });

        if (claimed.length < tunables.batchSize) break;
      }
    } finally {
      // Ce qui reste réservé (budget épuisé, élève sans profil) repart au
      // prochain passage au lieu d'attendre la fin du bail.
      if (held.size > 0) {
        try {
          tally.released += await this.release([...held]);
        } catch (error) {
          this.logger.error(`Push outbox release failed (${safeErrorCode(error)}).`);
        }
      }
    }

    this.logTally(tally, tick() - start);
    return tally;
  }

  private async runFanout(now: Date, tally: PushOutboxTally): Promise<void> {
    try {
      const result = await this.fanout.runDue(now);
      tally.fanoutCycles += result.cycles;
      tally.fanoutRows += result.inserted;
    } catch (error) {
      this.logger.error(`Opening fan-out failed (${safeErrorCode(error)}).`);
    }
  }

  /**
   * Réserve un lot de lignes échues. `pushAttempts` n'est PAS incrémenté ici :
   * seul un appel au fournisseur compte comme une tentative.
   */
  async claim(
    now: Date,
    batchSize = readOpeningTunables().batchSize,
    leaseMs = readOpeningTunables().leaseMs,
  ): Promise<ClaimedOutboxRow[]> {
    return this.claimWhere(now, leaseMs, Prisma.empty, Prisma.sql`LIMIT ${batchSize}`);
  }

  /**
   * Toutes les autres lignes échues des mêmes élèves, pour un seul push
   * groupé. Celles qu'un autre worker tient sont sautées (`SKIP LOCKED`) ; la
   * règle de contention du plan s'en charge.
   */
  async claimSiblings(
    userIds: readonly string[],
    now: Date,
    leaseMs = readOpeningTunables().leaseMs,
  ): Promise<ClaimedOutboxRow[]> {
    if (userIds.length === 0) return [];
    return this.claimWhere(
      now,
      leaseMs,
      Prisma.sql`AND "userId" = ANY(${[...userIds]}::text[])`,
      Prisma.empty,
    );
  }

  private async claimWhere(
    now: Date,
    leaseMs: number,
    filter: Prisma.Sql,
    limit: Prisma.Sql,
  ): Promise<ClaimedOutboxRow[]> {
    const lockedUntil = new Date(now.getTime() + leaseMs);
    const rows = await this.prisma.execute((p) =>
      p.$queryRaw<ClaimedOutboxRow[]>`
        WITH c AS (
          SELECT "id"
          FROM "UserNotification"
          WHERE "pushStatus" = 'pending'
            AND "kind" = ${SCHOLARSHIP_OPENED_KIND}
            AND "pushNotBefore" <= ${now}
            AND ("pushLockedUntil" IS NULL OR "pushLockedUntil" < ${now})
            ${filter}
          ORDER BY "pushNotBefore", "id"
          FOR UPDATE SKIP LOCKED
          ${limit}
        )
        UPDATE "UserNotification" AS n
        SET "pushLockedUntil" = ${lockedUntil}, "pushLockedBy" = ${this.workerId}
        FROM c
        WHERE n."id" = c."id"
        RETURNING n."id", n."userId", n."scholarshipId", n."cycleId", n."kind",
                  n."dedupeKey", n."titleFr", n."titleEn", n."bodyFr", n."bodyEn",
                  n."route", n."pushAttempts", n."createdAt",
                  n."data"->>'variant' AS "variant"
      `,
    );
    return rows ?? [];
  }

  /**
   * Trois lectures par lot : l'état de chaque ligne (profil, favori, alerte,
   * bourse publique, cycle), les push d'ouverture récents (rythme) et les
   * élèves qu'un autre worker vivant tient (contention).
   */
  private async enrich(
    rows: readonly ClaimedOutboxRow[],
    now: Date,
  ): Promise<OutboxPlanUser[]> {
    if (rows.length === 0) return [];
    const ids = rows.map((row) => row.id);
    const userIds = [...new Set(rows.map((row) => row.userId))];

    const [details, recent, contended] =
      (await this.prisma.execute((p) =>
        Promise.all([
          p.$queryRaw<EnrichedRow[]>`
            SELECT
              n."id",
              pr."preferredLanguage",
              pr."countryOfResidence",
              (${FOLLOWED_SCHOLARSHIP_OPT_OUT} = ANY(pr."disabledNotificationTypes")) AS "optedOut",
              EXISTS (
                SELECT 1 FROM "SavedItem" si
                WHERE si."userId" = n."userId"
                  AND si."itemType" = 'scholarship'
                  AND si."itemId" = n."scholarshipId"
              ) AS "favorite",
              (a."id" IS NOT NULL AND a."mutedAt" IS NOT NULL) AS "muted",
              (a."id" IS NOT NULL AND a."mutedAt" IS NULL) AS "alertActive",
              COALESCE(a."pushEnabled", true) AS "pushEnabled",
              COALESCE(
                s."isActive"
                  AND s."moderationStatus" = 'approved'
                  AND s."lastVerifiedAt" IS NOT NULL
                  AND (s."deadlineAt" IS NULL OR s."deadlineAt" >= ${now}),
                false
              ) AS "scholarshipPublic",
              s."nameFr",
              s."nameEn",
              (c."id" IS NOT NULL) AS "cycleExists",
              COALESCE(c."closesAt", c."estimatedCloseAt") AS "closeAt",
              c."openingStoppedAt" AS "stoppedAt"
            FROM "UserNotification" n
            JOIN "UserProfile" pr ON pr."id" = n."userId"
            LEFT JOIN "ScholarshipAlertSubscription" a
              ON a."userId" = n."userId" AND a."scholarshipId" = n."scholarshipId"
            LEFT JOIN "Scholarship" s ON s."id" = n."scholarshipId"
            LEFT JOIN "ScholarshipCycle" c ON c."id" = n."cycleId"
            WHERE n."id" = ANY(${ids}::text[])
          `,
          // Une ligne = un push : `pushedAt` n'est posé que sur la ligne de
          // tête d'un groupé.
          p.$queryRaw<{ userId: string; pushedAt: Date; pushBatchId: string | null }[]>`
            SELECT "userId", "pushedAt", "pushBatchId"
            FROM "UserNotification"
            WHERE "userId" = ANY(${userIds}::text[])
              AND "kind" = ${SCHOLARSHIP_OPENED_KIND}
              AND "pushStatus" = 'accepted'
              AND "pushedAt" >= ${new Date(now.getTime() - PACING_LOOKBACK_MS)}
          `,
          // Chaque réservation est validée avant l'enrichissement de son
          // worker : de deux workers qui tiennent le même élève, au moins un
          // voit l'autre ici.
          p.$queryRaw<{ userId: string }[]>`
            SELECT DISTINCT "userId"
            FROM "UserNotification"
            WHERE "userId" = ANY(${userIds}::text[])
              AND "kind" = ${SCHOLARSHIP_OPENED_KIND}
              AND "pushStatus" = 'pending'
              AND "pushLockedBy" <> ${this.workerId}
              AND "pushLockedUntil" > ${now}
          `,
        ]),
      )) ?? [[], [], []];

    const detailById = new Map(details.map((detail) => [detail.id, detail]));
    const recentByUser = new Map<string, RecentOpeningPush[]>();
    for (const push of recent) {
      const list = recentByUser.get(push.userId) ?? [];
      list.push({ pushedAt: push.pushedAt, batchId: push.pushBatchId });
      recentByUser.set(push.userId, list);
    }
    const contendedUsers = new Set(contended.map((row) => row.userId));

    const users = new Map<string, OutboxPlanUser & { rows: OutboxPlanRow[] }>();
    for (const row of rows) {
      const detail = detailById.get(row.id);
      // Profil supprimé entre-temps (cascade) : la ligne disparaît avec lui.
      if (!detail) continue;
      let user = users.get(row.userId);
      if (!user) {
        user = {
          userId: row.userId,
          preferredLanguage: detail.preferredLanguage,
          countryOfResidence: detail.countryOfResidence,
          optedOut: detail.optedOut,
          recentPushes: recentByUser.get(row.userId) ?? [],
          contended: contendedUsers.has(row.userId),
          rows: [],
        };
        users.set(row.userId, user);
      }
      user.rows.push({
        id: row.id,
        userId: row.userId,
        scholarshipId: row.scholarshipId,
        cycleId: row.cycleId,
        dedupeKey: row.dedupeKey,
        titleFr: row.titleFr,
        titleEn: row.titleEn,
        bodyFr: row.bodyFr,
        bodyEn: row.bodyEn,
        pushAttempts: row.pushAttempts,
        createdAt: row.createdAt,
        variant: isOpeningCopyVariant(row.variant) ? row.variant : null,
        favorite: detail.favorite,
        alertActive: detail.alertActive,
        muted: detail.muted,
        pushEnabled: detail.pushEnabled,
        scholarshipPublic: detail.scholarshipPublic,
        scholarshipNameFr: detail.nameFr,
        scholarshipNameEn: detail.nameEn,
        cycleExists: detail.cycleExists,
        cycleCloseAt: detail.closeAt,
        cycleStoppedAt: detail.stoppedAt,
      });
    }
    return [...users.values()];
  }

  /** Clôtures et reports en masse, chacun fencé par le bail. */
  private async applyWithoutSend(
    plans: readonly UserPushPlan[],
    tally: PushOutboxTally,
  ): Promise<void> {
    const finals = new Map<string, { status: 'expired' | 'skipped'; reason: string | null; ids: string[] }>();
    const deferred: { id: string; until: string; reason: PushDeferReason }[] = [];
    for (const plan of plans) {
      for (const final of plan.finals) {
        const reason = final.status === 'skipped' ? final.reason : null;
        const key = `${final.status}:${reason ?? ''}`;
        const group = finals.get(key) ?? { status: final.status, reason, ids: [] };
        group.ids.push(final.rowId);
        finals.set(key, group);
      }
      if (plan.deferral) {
        for (const id of plan.deferral.rowIds) {
          deferred.push({
            id,
            until: plan.deferral.until.toISOString(),
            reason: plan.deferral.reason,
          });
        }
      }
    }

    for (const group of finals.values()) {
      const updated = await this.updateHeld(group.ids, {
        pushStatus: group.status,
        pushLastError: group.reason,
        pushLockedUntil: null,
        pushLockedBy: null,
      });
      if (group.status === 'expired') tally.expired += updated;
      else tally.skipped += updated;
      countReason(tally, group.reason, updated);
      this.noteLeaseLoss(tally, group.ids.length, updated);
    }

    if (deferred.length > 0) {
      // Un report n'est pas une tentative : `pushAttempts` ne bouge pas.
      const updated =
        (await this.prisma.execute((p) =>
          p.$executeRaw`
            UPDATE "UserNotification" AS n
            SET "pushNotBefore" = (v."notBefore"::timestamptz AT TIME ZONE 'UTC'),
                "pushLastError" = v."reason",
                "pushLockedUntil" = NULL,
                "pushLockedBy" = NULL
            FROM unnest(
              ${deferred.map((d) => d.id)}::text[],
              ${deferred.map((d) => d.until)}::text[],
              ${deferred.map((d) => d.reason)}::text[]
            ) AS v("id", "notBefore", "reason")
            WHERE n."id" = v."id"
              AND n."pushLockedBy" = ${this.workerId}
              AND n."pushStatus" = 'pending'
          `,
        )) ?? 0;
      for (const entry of deferred) {
        if (entry.reason === 'deferred_quiet_hours') tally.deferredQuiet += 1;
        else if (entry.reason === 'deferred_busy') tally.deferredBusy += 1;
        else tally.deferredPacing += 1;
      }
      this.noteLeaseLoss(tally, deferred.length, updated);
    }
  }

  /**
   * L'issue d'un envoi sur TOUTES les lignes du push (un groupé partage
   * l'issue). `pushedAt` n'est posé que sur la ligne de tête : le plafond du
   * dispatcher compte des lignes, et un groupé de 3 ne doit consommer qu'une
   * place sur 3.
   */
  async finalize(
    send: OutboxSend,
    outcome: PushDeliveryOutcome,
    now: Date,
    tunables: Pick<OpeningTunables, 'maxAttempts'>,
    tally: PushOutboxTally = emptyPushOutboxTally(),
  ): Promise<number> {
    const ids = send.rows.map((row) => row.id);
    const unlock = { pushLockedUntil: null, pushLockedBy: null };
    let updated = 0;

    switch (outcome.status) {
      case 'accepted': {
        const accepted = {
          pushStatus: 'accepted',
          pushProvider: outcome.via,
          pushBatchId: randomUUID(),
          pushAttempts: { increment: 1 },
          pushLastError: null,
          ...unlock,
        } satisfies Prisma.UserNotificationUpdateManyMutationInput;
        const lead = await this.updateHeld([send.leadRowId], {
          ...accepted,
          pushedAt: now,
        });
        const others = ids.filter((id) => id !== send.leadRowId);
        const rest = others.length > 0 ? await this.updateHeld(others, accepted) : 0;
        updated = lead + rest;
        tally.accepted += updated;
        if (updated > 0) tally.acceptedPushes += 1;
        break;
      }
      case 'no_device':
        updated = await this.updateHeld(ids, {
          pushStatus: 'no_device',
          pushProvider: outcome.via,
          pushAttempts: { increment: 1 },
          pushLastError: null,
          ...unlock,
        });
        tally.noDevice += updated;
        countReason(tally, outcome.reason, updated);
        break;
      case 'transient_error': {
        // Les lignes d'un groupé n'ont pas forcément le même passé.
        const byAttempts = new Map<number, string[]>();
        for (const row of send.rows) {
          const list = byAttempts.get(row.pushAttempts) ?? [];
          list.push(row.id);
          byAttempts.set(row.pushAttempts, list);
        }
        for (const [attempts, group] of byAttempts) {
          if (attempts + 1 >= tunables.maxAttempts) {
            const n = await this.updateHeld(group, {
              pushStatus: 'failed',
              pushProvider: outcome.via,
              pushAttempts: { increment: 1 },
              pushLastError: 'max_attempts',
              ...unlock,
            });
            tally.failed += n;
            countReason(tally, 'max_attempts', n);
            updated += n;
          } else {
            const n = await this.updateHeld(group, {
              pushAttempts: { increment: 1 },
              pushNotBefore: new Date(now.getTime() + retryDelayMs(attempts)),
              pushLastError: 'retry_provider',
              ...unlock,
            });
            tally.retry += n;
            updated += n;
          }
        }
        countReason(tally, outcome.reason, updated);
        break;
      }
      case 'permanent_error':
        updated = await this.updateHeld(ids, {
          pushStatus: 'failed',
          pushProvider: outcome.via,
          pushAttempts: { increment: 1 },
          pushLastError: 'provider_permanent',
          ...unlock,
        });
        tally.failed += updated;
        countReason(tally, outcome.reason ?? 'provider_permanent', updated);
        break;
      default:
        updated = await this.updateHeld(ids, {
          pushStatus: 'skipped',
          pushLastError: 'push_unconfigured',
          ...unlock,
        });
        tally.skipped += updated;
        countReason(tally, 'push_unconfigured', updated);
    }

    this.noteLeaseLoss(tally, ids.length, updated);
    return updated;
  }

  /** Rend des lignes encore réservées par ce worker, sans rien changer d'autre. */
  async release(ids: readonly string[]): Promise<number> {
    if (ids.length === 0) return 0;
    return this.updateHeld(ids, { pushLockedUntil: null, pushLockedBy: null });
  }

  /** Toute écriture exige encore le bail : une ligne reprise par un autre est intouchable. */
  private async updateHeld(
    ids: readonly string[],
    data: Prisma.UserNotificationUpdateManyMutationInput,
  ): Promise<number> {
    const result = await this.prisma.execute((p) =>
      p.userNotification.updateMany({
        where: {
          id: { in: [...ids] },
          pushLockedBy: this.workerId,
          pushStatus: 'pending',
        },
        data,
      }),
    );
    return result?.count ?? 0;
  }

  private noteLeaseLoss(
    tally: PushOutboxTally,
    expected: number,
    updated: number,
  ): void {
    if (updated >= expected) return;
    tally.leaseLost += expected - updated;
    this.logger.warn(
      `Push outbox: lease lost on ${expected - updated} row(s) before finalizing.`,
    );
  }

  private logTally(tally: PushOutboxTally, elapsedMs: number): void {
    const busy =
      tally.fanoutCycles +
      tally.fanoutRows +
      tally.accepted +
      tally.noDevice +
      tally.deferredQuiet +
      tally.deferredPacing +
      tally.deferredBusy +
      tally.retry +
      tally.failed +
      tally.skipped +
      tally.expired +
      tally.released +
      tally.leaseLost;
    if (busy === 0) return;
    const reasons = Object.entries(tally.reasons)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([reason, n]) => `${reason}:${n}`)
      .join(',');
    this.logger.log(
      `Push outbox: fanout cycles=${tally.fanoutCycles} rows=${tally.fanoutRows} | ` +
        `accepted=${tally.accepted} pushes=${tally.acceptedPushes} no_device=${tally.noDevice} ` +
        `deferred_quiet=${tally.deferredQuiet} deferred_pacing=${tally.deferredPacing} ` +
        `deferred_busy=${tally.deferredBusy} retry=${tally.retry} failed=${tally.failed} ` +
        `skipped=${tally.skipped} expired=${tally.expired} released=${tally.released}` +
        `${tally.leaseLost ? ` lease_lost=${tally.leaseLost}` : ''}` +
        `${reasons ? ` reasons=${reasons}` : ''} (${(elapsedMs / 1000).toFixed(1)}s)`,
    );
  }
}

function safeErrorCode(error: unknown): string {
  if (!error || typeof error !== 'object' || !('code' in error)) {
    return 'PUSH_OUTBOX_FAILED';
  }
  const code = (error as { code?: unknown }).code;
  if (typeof code !== 'string') return 'PUSH_OUTBOX_FAILED';
  if (/^P\d{4}$/.test(code)) return code;
  return ['ECONNREFUSED', 'ECONNRESET', 'ENETUNREACH', 'ENOTFOUND', 'ETIMEDOUT'].includes(
    code,
  )
    ? code
    : 'PUSH_OUTBOX_FAILED';
}
