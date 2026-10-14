import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import {
  isWithinQuietHours,
  utcOffsetHoursForCountry,
} from '../../../common/country-timezone';
import type { QuietHours } from '../../../common/push-quiet-hours';
import {
  pacingDeferral,
  type RecentOpeningPush,
} from '../../notifications/push-outbox-plan';
import { PrismaService } from '../../prisma/prisma.service';
import {
  followerAudienceCountsSql,
  followerRowsSql,
  type FollowerAudienceCounts,
  type FollowerRow,
} from './scholarship-follow.query';
import {
  SCHOLARSHIP_OPENED_KIND,
  type OpeningAudienceScope,
  type OpeningAudienceSummary,
} from './scholarship-opening.contract';
import { openingLanguage } from './scholarship-opening.copy';

const DAY_MS = 24 * 60 * 60 * 1000;
/** Fenêtre lue pour le rythme : le plafond est par jour local, la fusion 30 min. */
const PACING_LOOKBACK_MS = 48 * 60 * 60 * 1000;

/** Le client d'une transaction interactive, ou le client lui-même. */
export type OpeningDb = Prisma.TransactionClient;

export interface OpeningAudienceQuery {
  scholarshipId: string;
  scope: OpeningAudienceScope;
  /** `null` : cycle pas encore créé, personne n'est « déjà prévenu ». */
  cycleId: string | null;
  now: Date;
  /** `openingNotifiedAt` sur une relance ; `null` pour une première annonce. */
  followSince: Date | null;
  renotifyDays: number;
}

/** Une ligne d'un AUTRE cycle de la bourse plus récente que ceci exclut l'élève. */
export function renotifySince(now: Date, renotifyDays: number): Date {
  return new Date(now.getTime() - renotifyDays * DAY_MS);
}

export interface OpeningAudienceSummaryOptions {
  /** L'instant de l'envoi (aperçu : maintenant + délai d'annulation). */
  sendAt: Date;
  quiet: QuietHours;
  coalesceMinutes: number;
  maxOpeningPushesPerDay: number;
  /** Push d'ouverture acceptés récents, par élève. */
  recentPushes: ReadonlyMap<string, readonly RecentOpeningPush[]>;
}

/**
 * Les comptes de l'aperçu, tirés des lignes de `follow_rows`. Pur.
 *
 * Toutes les clés décrivent l'ensemble `toNotify`, sauf `followers`, `muted`,
 * `alreadyNotifiedThisCycle` et `recentlyNotified` (les exclusions, chacune
 * comptée une fois, dans cet ordre). Le report (heures calmes, puis rythme)
 * est évalué à `sendAt` avec les règles mêmes du worker.
 */
export function summarizeOpeningAudience(
  rows: readonly FollowerRow[],
  options: OpeningAudienceSummaryOptions,
): OpeningAudienceSummary {
  const summary: OpeningAudienceSummary = {
    followers: 0,
    viaFavoriteOnly: 0,
    viaAlertOnly: 0,
    viaBoth: 0,
    muted: 0,
    alreadyNotifiedThisCycle: 0,
    recentlyNotified: 0,
    toNotify: 0,
    pushEligible: 0,
    optedOut: 0,
    pushDisabled: 0,
    deferredQuietHours: 0,
    deferredPacing: 0,
    byLanguage: { fr: 0, en: 0 },
    devices: { fcm: 0, oneSignalOnly: 0 },
  };

  for (const row of rows) {
    if (row.viaFavorite || row.viaAlert) summary.followers += 1;
    if (row.muted) {
      summary.muted += 1;
      continue;
    }
    if (row.alreadyNotified) {
      summary.alreadyNotifiedThisCycle += 1;
      continue;
    }
    if (row.recentlyNotified) {
      summary.recentlyNotified += 1;
      continue;
    }
    if (!row.toNotify) continue;

    summary.toNotify += 1;
    if (row.viaFavorite && row.viaAlert) summary.viaBoth += 1;
    else if (row.viaFavorite) summary.viaFavoriteOnly += 1;
    else summary.viaAlertOnly += 1;
    summary.byLanguage[openingLanguage(row.preferredLanguage)] += 1;

    if (row.optedOut) {
      summary.optedOut += 1;
      continue;
    }
    if (!row.pushEnabled) {
      summary.pushDisabled += 1;
      continue;
    }
    summary.pushEligible += 1;
    if (row.hasFcmDevice) summary.devices.fcm += 1;
    else summary.devices.oneSignalOnly += 1;

    const offset = utcOffsetHoursForCountry(row.countryOfResidence);
    if (
      isWithinQuietHours(
        options.sendAt,
        offset,
        options.quiet.startHour,
        options.quiet.endHour,
      )
    ) {
      summary.deferredQuietHours += 1;
      continue;
    }
    const pacing = pacingDeferral({
      userId: row.userId,
      offsetHours: offset,
      recentPushes: options.recentPushes.get(row.userId) ?? [],
      now: options.sendAt,
      coalesceMinutes: options.coalesceMinutes,
      maxPerDay: options.maxOpeningPushesPerDay,
      quiet: options.quiet,
    });
    if (pacing) summary.deferredPacing += 1;
  }
  return summary;
}

/**
 * L'audience d'une annonce d'ouverture : lignes (aperçu) et comptes
 * (`activate`), tirés du texte SQL que partagent l'aperçu, `activate` et
 * l'envoi (`scholarship-follow.query.ts`). À données égales, le `toNotify` de
 * l'aperçu, celui d'`activate` et le nombre de lignes écrites sont égaux.
 */
@Injectable()
export class ScholarshipOpeningAudienceService {
  constructor(private readonly prisma: PrismaService) {}

  /** Chaque candidat de la portée, sourdines comprises (aperçu). */
  async rows(query: OpeningAudienceQuery, db?: OpeningDb): Promise<FollowerRow[]> {
    const sql = followerRowsSql(
      query.scholarshipId,
      query.scope,
      query.cycleId,
      renotifySince(query.now, query.renotifyDays),
      query.followSince,
    );
    if (db) return db.$queryRaw<FollowerRow[]>(sql);
    return (await this.prisma.execute((p) => p.$queryRaw<FollowerRow[]>(sql))) ?? [];
  }

  /**
   * Les comptes d'`activate`, dans SA transaction (après le verrou du cycle) :
   * `audience` (avant déduplication), `toNotify` et son découpage.
   */
  async countToNotify(
    db: OpeningDb,
    query: OpeningAudienceQuery,
  ): Promise<FollowerAudienceCounts> {
    const [counts] = await db.$queryRaw<FollowerAudienceCounts[]>(
      followerAudienceCountsSql(
        query.scholarshipId,
        query.scope,
        query.cycleId,
        renotifySince(query.now, query.renotifyDays),
        query.followSince,
      ),
    );
    return (
      counts ?? {
        audience: 0,
        muted: 0,
        toNotify: 0,
        viaFavoriteOnly: 0,
        viaAlertOnly: 0,
        viaBoth: 0,
      }
    );
  }

  /**
   * Les push d'ouverture acceptés des 48 dernières heures de ces élèves : une
   * ligne par push (`pushedAt` n'est posé que sur la ligne de tête).
   */
  async recentPushes(
    userIds: readonly string[],
    now: Date,
    db?: OpeningDb,
  ): Promise<Map<string, RecentOpeningPush[]>> {
    const byUser = new Map<string, RecentOpeningPush[]>();
    if (userIds.length === 0) return byUser;
    const sql = Prisma.sql`
      SELECT "userId", "pushedAt", "pushBatchId"
      FROM "UserNotification"
      WHERE "userId" = ANY(${[...userIds]}::text[])
        AND "kind" = ${SCHOLARSHIP_OPENED_KIND}
        AND "pushStatus" = 'accepted'
        AND "pushedAt" >= ${new Date(now.getTime() - PACING_LOOKBACK_MS)}
    `;
    type Row = { userId: string; pushedAt: Date; pushBatchId: string | null };
    const rows = db
      ? await db.$queryRaw<Row[]>(sql)
      : ((await this.prisma.execute((p) => p.$queryRaw<Row[]>(sql))) ?? []);
    for (const row of rows) {
      const list = byUser.get(row.userId) ?? [];
      list.push({ pushedAt: row.pushedAt, batchId: row.pushBatchId });
      byUser.set(row.userId, list);
    }
    return byUser;
  }
}
