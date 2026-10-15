import { randomUUID } from 'node:crypto';

import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { publicScholarshipWhere } from '../../../common/public-scholarship-where';
import { PrismaService } from '../../prisma/prisma.service';
import { renotifySince } from './scholarship-opening-audience.service';
import { followerRowsCte } from './scholarship-follow.query';
import {
  isOpeningAudienceScope,
  openingDedupeKey,
  OPENING_AUDIT_ENTITY_TYPE,
  OPENING_AUDIT_PURPOSE,
  PUSH_OUTBOX_REQUEST_ID_PREFIX,
  readOpeningTunables,
  SCHOLARSHIP_OPENED_KIND,
  scholarshipRoute,
  type CycleOpeningSkipReason,
  type OpeningAudienceScope,
  type OpeningAuditAction,
  type OpeningTunables,
} from './scholarship-opening.contract';
import {
  buildOpeningCopy,
  type OpeningCopySet,
  type OpeningLanguage,
} from './scholarship-opening.copy';

const HOUR_MS = 60 * 60 * 1000;

/** Le cycle échu, relu sous `FOR UPDATE SKIP LOCKED`. */
interface DueCycle {
  id: string;
  scholarshipId: string;
  academicYear: string;
  opensAt: Date | null;
  closesAt: Date | null;
  estimatedCloseAt: Date | null;
  openingFanoutDueAt: Date;
  openingFanoutScope: string | null;
  openingFanoutById: string | null;
  openingNotifiedAt: Date | null;
  openingNotifiedById: string | null;
  openingAudience: number | null;
}

export interface OpeningFanoutTally {
  /** Cycles annoncés (lignes écrites, éventuellement zéro). */
  cycles: number;
  inserted: number;
  pending: number;
  skipped: number;
  /** Programmations abandonnées : trop tard, bourse retirée, cycle clos. */
  dropped: number;
}

type CycleOutcome =
  | { kind: 'none' }
  | { kind: 'dropped'; cycleId: string }
  | {
      kind: 'sent';
      cycleId: string;
      inserted: number;
      pending: number;
      skipped: number;
    };

/**
 * Phase 1 du worker : une annonce programmée arrivée à échéance devient une
 * ligne d'inbox par abonné — qui est aussi la ligne de la boîte d'envoi push
 * (`pushStatus`). Une transaction par cycle, le cycle verrouillé : une
 * annulation concurrente attend, puis ne trouve plus rien à annuler (409) ;
 * deux replicas ne prennent jamais le même cycle (`SKIP LOCKED`).
 *
 * L'audience est le texte SQL de l'aperçu et d'`activate`
 * (`scholarship-follow.query.ts`) : à données égales, « 312 seront prévenus »
 * fait 312 lignes.
 */
@Injectable()
export class ScholarshipOpeningFanoutService {
  private readonly logger = new Logger(ScholarshipOpeningFanoutService.name);

  constructor(private readonly prisma: PrismaService) {}

  async runDue(now: Date = new Date()): Promise<OpeningFanoutTally> {
    const tally: OpeningFanoutTally = {
      cycles: 0,
      inserted: 0,
      pending: 0,
      skipped: 0,
      dropped: 0,
    };
    if (!this.prisma.isEnabled) return tally;
    const tunables = readOpeningTunables();
    // Un cycle qui échoue (donnée inattendue) ne doit pas affamer les autres
    // dans ce passage : il est écarté jusqu'au suivant.
    const failed: string[] = [];

    for (let i = 0; i < tunables.fanoutCyclesPerTick; i += 1) {
      const current: { id: string | null } = { id: null };
      let outcome: CycleOutcome | null;
      try {
        outcome = await this.prisma.execute((prisma) =>
          prisma.$transaction(
            (tx) => this.fanoutOne(tx, now, tunables, failed, current),
            // Sous le défaut de 5 s, un gros INSERT … SELECT serait annulé à
            // chaque passage et le cycle ne partirait jamais.
            { maxWait: 5_000, timeout: 120_000 },
          ),
        );
      } catch (error) {
        if (current.id === null) throw error;
        failed.push(current.id);
        this.logger.error(
          `Opening fan-out failed for cycle ${current.id} (${safeErrorCode(error)}).`,
        );
        continue;
      }
      if (!outcome || outcome.kind === 'none') break;
      if (outcome.kind === 'dropped') {
        tally.dropped += 1;
        continue;
      }
      tally.cycles += 1;
      tally.inserted += outcome.inserted;
      tally.pending += outcome.pending;
      tally.skipped += outcome.skipped;
    }
    return tally;
  }

  private async fanoutOne(
    tx: Prisma.TransactionClient,
    now: Date,
    tunables: OpeningTunables,
    exclude: readonly string[],
    current: { id: string | null },
  ): Promise<CycleOutcome> {
    const excludeClause =
      exclude.length > 0
        ? Prisma.sql`AND "id" <> ALL(${[...exclude]}::text[])`
        : Prisma.empty;
    const [cycle] = await tx.$queryRaw<DueCycle[]>`
      SELECT "id", "scholarshipId", "academicYear", "opensAt", "closesAt",
             "estimatedCloseAt", "openingFanoutDueAt", "openingFanoutScope",
             "openingFanoutById", "openingNotifiedAt", "openingNotifiedById",
             "openingAudience"
      FROM "ScholarshipCycle"
      WHERE "openingFanoutDueAt" <= ${now} ${excludeClause}
      ORDER BY "openingFanoutDueAt"
      FOR UPDATE SKIP LOCKED
      LIMIT 1
    `;
    if (!cycle) return { kind: 'none' };
    current.id = cycle.id;
    const scope: OpeningAudienceScope = isOpeningAudienceScope(
      cycle.openingFanoutScope,
    )
      ? cycle.openingFanoutScope
      : 'alerts';
    const base = { cycle, scope, now };

    // 1. Trop tard (interrupteur resté coupé, retour arrière puis
    //    redéploiement) : personne ne reçoit un « C'est ouvert » vieux de
    //    plusieurs jours. Le cycle revient dans « À faire ».
    const lateCutoff = now.getTime() - tunables.fanoutMaxLatenessHours * HOUR_MS;
    if (cycle.openingFanoutDueAt.getTime() < lateCutoff) {
      await this.dropSchedule(tx, base, 'scholarship_cycle.fanout_expired', null);
      return { kind: 'dropped', cycleId: cycle.id };
    }

    // 2. La bourse n'est plus publique : jamais d'annonce vers une fiche qui
    //    répondrait 404.
    const scholarship = await tx.scholarship.findFirst({
      where: { id: cycle.scholarshipId, ...publicScholarshipWhere(now) },
      select: { nameFr: true, nameEn: true },
    });
    if (!scholarship) {
      await this.dropSchedule(
        tx,
        base,
        'scholarship_cycle.fanout_completed',
        'not_public_at_fanout',
      );
      return { kind: 'dropped', cycleId: cycle.id };
    }

    // 3. La clôture est passée pendant l'attente (ou a été saisie dans le
    //    passé) : jamais « C'est ouvert » sur une fenêtre close.
    const closeAt = cycle.closesAt ?? cycle.estimatedCloseAt;
    if (closeAt && closeAt.getTime() <= now.getTime()) {
      await this.dropSchedule(
        tx,
        base,
        'scholarship_cycle.fanout_completed',
        'cycle_closed_at_fanout',
      );
      return { kind: 'dropped', cycleId: cycle.id };
    }

    // Les textes sont construits MAINTENANT : une correction de dates pendant
    // l'attente est prise en compte.
    const copy = buildOpeningCopy(
      { fr: scholarship.nameFr, en: scholarship.nameEn },
      cycle.opensAt,
      closeAt,
      now,
    );
    const statuses = await tx.$queryRaw<{ pushStatus: string }[]>(
      fanoutInsertSql({
        scholarshipId: cycle.scholarshipId,
        cycleId: cycle.id,
        scope,
        now,
        renotifySince: renotifySince(now, tunables.renotifyDays),
        // Relance d'un cycle déjà annoncé : seulement les abonnés postérieurs.
        followSince: cycle.openingNotifiedAt,
        copy,
      }),
    );
    const inserted = statuses.length;
    const pending = statuses.filter((row) => row.pushStatus === 'pending').length;
    const skipped = inserted - pending;

    await tx.scholarshipCycle.update({
      where: { id: cycle.id },
      data: {
        openingFanoutDueAt: null,
        openingFanoutScope: null,
        openingFanoutById: null,
        openingLastFanoutAt: now,
        openingNotifiedAt: cycle.openingNotifiedAt ?? now,
        // L'auteur de la PREMIÈRE annonce ; une relance ne le remplace pas.
        openingNotifiedById: cycle.openingNotifiedById ?? cycle.openingFanoutById,
        openingAudience: (cycle.openingAudience ?? 0) + inserted,
      },
    });
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: null,
        action: 'scholarship_cycle.fanout_completed' satisfies OpeningAuditAction,
        purposeCode: OPENING_AUDIT_PURPOSE,
        entityType: OPENING_AUDIT_ENTITY_TYPE,
        entityId: cycle.id,
        requestId: `${PUSH_OUTBOX_REQUEST_ID_PREFIX}${randomUUID()}`,
        result: 'success',
        changes: {
          academicYear: cycle.academicYear,
          scope,
          variant: copy.variant,
          scheduledById: cycle.openingFanoutById,
          inserted,
          pending,
          skipped,
        },
      },
    });
    return { kind: 'sent', cycleId: cycle.id, inserted, pending, skipped };
  }

  /** Efface la programmation, sans aucune ligne d'inbox, et l'écrit à l'audit. */
  private async dropSchedule(
    tx: Prisma.TransactionClient,
    base: { cycle: DueCycle; scope: OpeningAudienceScope; now: Date },
    action: OpeningAuditAction,
    skipReason: CycleOpeningSkipReason | null,
  ): Promise<void> {
    const { cycle, scope, now } = base;
    // Le motif ne s'inscrit que sur une PREMIÈRE annonce : un cycle déjà
    // annoncé le reste, et ne doit pas apparaître comme « sauté ».
    const markSkipped = skipReason !== null && cycle.openingNotifiedAt === null;
    await tx.scholarshipCycle.update({
      where: { id: cycle.id },
      data: {
        openingFanoutDueAt: null,
        openingFanoutScope: null,
        openingFanoutById: null,
        ...(markSkipped
          ? { openingSkippedAt: now, openingSkippedReason: skipReason }
          : {}),
      },
    });
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: null,
        action,
        purposeCode: OPENING_AUDIT_PURPOSE,
        entityType: OPENING_AUDIT_ENTITY_TYPE,
        entityId: cycle.id,
        requestId: `${PUSH_OUTBOX_REQUEST_ID_PREFIX}${randomUUID()}`,
        reasonCode: skipReason ?? 'fanout_too_late',
        result: 'skipped',
        changes: {
          academicYear: cycle.academicYear,
          scope,
          dueAt: cycle.openingFanoutDueAt.toISOString(),
          scheduledById: cycle.openingFanoutById,
          inserted: 0,
        },
      },
    });
  }
}

function copyExpr(
  copy: OpeningCopySet,
  lang: OpeningLanguage,
  field: 'title' | 'body',
): Prisma.Sql {
  if (copy.variant === 'dates_confirmed') {
    return Prisma.sql`${copy[lang].dates_confirmed[field]}::text`;
  }
  // Portée « alerts » : toutes les lignes ont une alerte active.
  return Prisma.sql`CASE WHEN r."viaAlert" THEN ${copy[lang].alert[field]}::text ELSE ${copy[lang].favorite[field]}::text END`;
}

/**
 * L'INSERT de l'envoi : une ligne par abonné à prévenir (`toNotify` du texte
 * partagé), idempotente (`dedupeKey` au format d'avant). L'identifiant est
 * fourni ici : `@default(cuid())` est appliqué par Prisma, pas par la base.
 */
export function fanoutInsertSql(input: {
  scholarshipId: string;
  cycleId: string;
  scope: OpeningAudienceScope;
  now: Date;
  renotifySince: Date;
  followSince: Date | null;
  copy: OpeningCopySet;
}): Prisma.Sql {
  const { scholarshipId, cycleId, copy } = input;
  const variant =
    copy.variant === 'dates_confirmed'
      ? Prisma.sql`'dates_confirmed'`
      : Prisma.sql`CASE WHEN r."viaAlert" THEN 'alert' ELSE 'favorite' END`;
  return Prisma.sql`${followerRowsCte(
    scholarshipId,
    input.scope,
    cycleId,
    input.renotifySince,
    input.followSince,
  )}
    INSERT INTO "UserNotification" (
      "id", "userId", "scholarshipId", "cycleId", "kind", "dedupeKey",
      "titleFr", "titleEn", "bodyFr", "bodyEn", "route", "data",
      "pushStatus", "pushNotBefore", "pushLastError"
    )
    SELECT
      gen_random_uuid()::text,
      r."userId",
      ${scholarshipId}::text,
      ${cycleId}::text,
      ${SCHOLARSHIP_OPENED_KIND}::text,
      ${openingDedupeKey(cycleId, '')}::text || r."userId",
      ${copyExpr(copy, 'fr', 'title')},
      ${copyExpr(copy, 'en', 'title')},
      ${copyExpr(copy, 'fr', 'body')},
      ${copyExpr(copy, 'en', 'body')},
      ${scholarshipRoute(scholarshipId)}::text,
      jsonb_build_object(
        'scholarshipId', ${scholarshipId}::text,
        'cycleId', ${cycleId}::text,
        'variant', ${variant}
      ),
      -- Désinscription globale ou push coupé : l'entrée d'inbox est écrite,
      -- seul le push est sauté.
      CASE WHEN r."optedOut" OR NOT r."pushEnabled" THEN 'skipped' ELSE 'pending' END,
      ${input.now},
      CASE
        WHEN r."optedOut" THEN 'opt_out'
        WHEN NOT r."pushEnabled" THEN 'push_disabled'
      END
    FROM follow_rows r
    WHERE r."toNotify"
    ON CONFLICT ("dedupeKey") DO NOTHING
    RETURNING "pushStatus"
  `;
}

function safeErrorCode(error: unknown): string {
  if (!error || typeof error !== 'object' || !('code' in error)) {
    return 'UNKNOWN';
  }
  const code = (error as { code?: unknown }).code;
  return typeof code === 'string' && /^P\d{4}$/.test(code) ? code : 'UNKNOWN';
}
