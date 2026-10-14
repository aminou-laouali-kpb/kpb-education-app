import { randomUUID } from 'node:crypto';

import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma, type PrismaClient } from '@prisma/client';

import {
  compareAcademicYear,
  defaultOpeningAcademicYear,
  isConsecutiveAcademicYear,
  nextAcademicYear,
} from '../../../common/academic-year';
import {
  publicScholarshipWhere,
  servedCycleStatus,
} from '../../../common/public-scholarship-where';
import { readQuietHours } from '../../../common/push-quiet-hours';
import { PushSenderService } from '../../notifications/push-sender.service';
import { PrismaService } from '../../prisma/prisma.service';
import type { OpeningPreviewQueryDto } from '../dto/opening-preview-query.dto';
import { ScholarshipContentQualityService } from '../scholarship-content-quality.service';
import type { OpeningActor } from '../scholarship-lifecycle.service';
import {
  ScholarshipOpeningAudienceService,
  summarizeOpeningAudience,
} from './scholarship-opening-audience.service';
import {
  followerCountsSql,
  type FollowerCountRow,
} from './scholarship-follow.query';
import {
  audienceScopeForMode,
  canSendAboveOpeningThreshold,
  CYCLE_OPENING_SKIP_REASONS,
  isOpeningAudienceScope,
  isOpeningBusyError,
  isOutboxOpeningMode,
  isPushOutboxEnabled,
  OPENING_ADMIN_TRANSACTION,
  OPENING_AUDIT_ACTIONS,
  OPENING_AUDIT_ENTITY_TYPE,
  OPENING_AUDIT_PURPOSE,
  OPENING_TODO_LIMIT,
  openingError,
  PUSH_SKIP_REASON_REPORT_KEY,
  PUSH_SKIP_REASONS,
  readOpeningTunables,
  readScholarshipOpeningMode,
  SCHOLARSHIP_OPENED_KIND,
  type CancelOpeningResponse,
  type CycleOpeningSkipReason,
  type OpeningAdminRef,
  type OpeningAudienceScope,
  type OpeningAuditAction,
  type OpeningOverviewItem,
  type OpeningOverviewResponse,
  type OpeningPreviewCycle,
  type OpeningPreviewResponse,
  type OpeningRecentEvent,
  type OpeningReportResponse,
  type OpeningTodoItem,
  type OpeningTodoResponse,
  type StopOpeningResponse,
} from './scholarship-opening.contract';
import {
  buildBundleCopy,
  buildOpeningCopy,
} from './scholarship-opening.copy';

/** Les derniers événements d'audit montrés dans l'aperçu. */
const RECENT_EVENTS_LIMIT = 5;

/** Une ligne du `GROUP BY` du rapport. */
export interface OpeningReportGroup {
  pushStatus: string | null;
  pushLastError: string | null;
  pushProvider: string | null;
  /** `pushNotBefore > now` (ligne repoussée, pas encore due). */
  future: boolean | null;
  n: number;
  read: number;
}

type OpeningReportCounts = Pick<OpeningReportResponse, 'inbox' | 'push' | 'byProvider'>;

/**
 * Les comptes du rapport, tirés du `GROUP BY pushStatus, pushLastError,
 * pushProvider, (pushNotBefore > now)`. Pur. `acceptedPushes` vient d'un
 * `count(DISTINCT pushBatchId)` à part : un groupé de 3 lignes est 1 push.
 */
export function buildOpeningReportCounts(
  groups: readonly OpeningReportGroup[],
  acceptedPushes: number,
): OpeningReportCounts {
  const report: OpeningReportCounts = {
    inbox: { total: 0, read: 0 },
    push: {
      accepted: 0,
      acceptedPushes,
      noDevice: 0,
      failed: 0,
      expired: 0,
      pending: 0,
      deferredQuietHours: 0,
      deferredPacing: 0,
      retrying: 0,
      skipped: {
        total: 0,
        optOut: 0,
        pushDisabled: 0,
        muted: 0,
        unfollowed: 0,
        notPublic: 0,
        cycleClosed: 0,
        pushUnconfigured: 0,
        stoppedByStaff: 0,
      },
      untracked: 0,
    },
    byProvider: { fcm: 0, onesignal: 0 },
  };
  for (const group of groups) {
    const n = group.n;
    report.inbox.total += n;
    report.inbox.read += group.read;
    switch (group.pushStatus) {
      case null:
        report.push.untracked += n;
        break;
      case 'accepted':
        report.push.accepted += n;
        if (group.pushProvider === 'fcm' || group.pushProvider === 'onesignal') {
          report.byProvider[group.pushProvider] += n;
        }
        break;
      case 'no_device':
        report.push.noDevice += n;
        break;
      case 'failed':
        report.push.failed += n;
        break;
      case 'expired':
        report.push.expired += n;
        break;
      case 'pending':
        report.push.pending += n;
        if (group.future) {
          if (group.pushLastError === 'deferred_quiet_hours') {
            report.push.deferredQuietHours += n;
          } else if (
            group.pushLastError === 'deferred_pacing' ||
            group.pushLastError === 'deferred_busy'
          ) {
            report.push.deferredPacing += n;
          } else if (group.pushLastError === 'retry_provider') {
            report.push.retrying += n;
          }
        }
        break;
      case 'skipped': {
        report.push.skipped.total += n;
        const reason = PUSH_SKIP_REASONS.find((r) => r === group.pushLastError);
        if (reason) report.push.skipped[PUSH_SKIP_REASON_REPORT_KEY[reason]] += n;
        break;
      }
      default:
        break;
    }
  }
  return report;
}

/** Une valeur de `AdminAuditEvent.changes` lue sans confiance. */
function jsonField(changes: Prisma.JsonValue | null, key: string): unknown {
  if (!changes || typeof changes !== 'object' || Array.isArray(changes)) {
    return undefined;
  }
  return (changes as Prisma.JsonObject)[key];
}

function iso(date: Date | null | undefined): string | null {
  return date ? date.toISOString() : null;
}

function skipReason(value: string | null): CycleOpeningSkipReason | null {
  return CYCLE_OPENING_SKIP_REASONS.find((reason) => reason === value) ?? null;
}

const PREVIEW_CYCLE_SELECT = {
  id: true,
  academicYear: true,
  status: true,
  dateConfidence: true,
  opensAt: true,
  closesAt: true,
  estimatedOpenAt: true,
  estimatedCloseAt: true,
  sourceUrl: true,
  activatedAt: true,
  openingNotifiedAt: true,
  openingNotifiedById: true,
  openingAudience: true,
  openingFanoutDueAt: true,
  openingLastFanoutAt: true,
  openingSkippedAt: true,
  openingSkippedReason: true,
  openingStoppedAt: true,
  openingPreExisting: true,
} satisfies Prisma.ScholarshipCycleSelect;

type PreviewCycleRow = Prisma.ScholarshipCycleGetPayload<{
  select: typeof PREVIEW_CYCLE_SELECT;
}>;

/**
 * Lectures et gestes de l'équipe sur l'annonce d'ouverture (chantier C) :
 * aperçu, annulation, arrêt des envois restants, rapport, « À faire »,
 * colonnes de la liste.
 *
 * Vocabulaire : un push est « accepté par le fournisseur », jamais « reçu » ni
 * « délivré » — un 200 de FCM ou de OneSignal ne dit pas que le téléphone a
 * affiché quoi que ce soit.
 */
@Injectable()
export class ScholarshipOpeningAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audience: ScholarshipOpeningAudienceService,
    private readonly contentQuality: ScholarshipContentQualityService,
    private readonly push: PushSenderService,
  ) {}

  private assertDb(): void {
    if (!this.prisma.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  /**
   * `execute` rend `null` sans base ; une lecture peut AUSSI rendre `null`
   * (introuvable). La valeur est mise en boîte pour ne jamais confondre les
   * deux : un 404 reste un 404.
   */
  private async run<T>(
    operation: (client: PrismaClient) => Promise<T>,
  ): Promise<T> {
    const box = await this.prisma.execute(async (p) => ({
      value: await operation(p),
    }));
    if (box === null) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
    return box.value;
  }

  // ── Aperçu ────────────────────────────────────────────────────────────────

  async preview(
    scholarshipId: string,
    query: OpeningPreviewQueryDto,
    actor: OpeningActor,
    now: Date = new Date(),
  ): Promise<OpeningPreviewResponse> {
    this.assertDb();
    const scholarship = await this.run((p) =>
      p.scholarship.findUnique({
        where: { id: scholarshipId },
        select: {
          id: true,
          nameFr: true,
          nameEn: true,
          cycles: { select: PREVIEW_CYCLE_SELECT },
        },
      }),
    );
    if (!scholarship) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }

    const mode = readScholarshipOpeningMode();
    const scope = audienceScopeForMode(mode);
    const tunables = readOpeningTunables();
    const quiet = readQuietHours();
    const sendAt = new Date(now.getTime() + tunables.holdSeconds * 1000);

    const cycles = [...scholarship.cycles].sort((a, b) =>
      compareAcademicYear(b.academicYear, a.academicYear),
    );
    const academicYear =
      query.academicYear ?? defaultOpeningAcademicYear(cycles, now);
    const target = cycles.find((cycle) => cycle.academicYear === academicYear) ?? null;
    const newest = cycles.find((cycle) => isConsecutiveAcademicYear(cycle.academicYear));
    const opensAt = query.opensAt ? new Date(query.opensAt) : (target?.opensAt ?? null);
    const closesAt = query.closesAt
      ? new Date(query.closesAt)
      : (target?.closesAt ?? null);

    const [readiness, rows, oldestDue, events] = await Promise.all([
      // La complétude telle qu'`activate` la vérifiera, avec les dates du
      // formulaire.
      this.contentQuality.getReadiness(
        scholarshipId,
        {
          academicYear,
          status: 'open',
          dateConfidence: 'confirmed',
          opensAt,
          closesAt,
          estimatedOpenAt: target?.estimatedOpenAt ?? null,
          estimatedCloseAt: target?.estimatedCloseAt ?? null,
          sourceUrl: target?.sourceUrl ?? null,
          verifiedAt: now,
        },
        now,
      ),
      this.audience.rows({
        scholarshipId,
        scope,
        cycleId: target?.id ?? null,
        now,
        followSince: target?.openingNotifiedAt ?? null,
        renotifyDays: tunables.renotifyDays,
      }),
      this.run((p) =>
        p.userNotification.findFirst({
          where: {
            pushStatus: 'pending',
            kind: SCHOLARSHIP_OPENED_KIND,
            pushNotBefore: { lte: now },
          },
          orderBy: { pushNotBefore: 'asc' },
          select: { pushNotBefore: true },
        }),
      ),
      this.recentEventRows(cycles.map((cycle) => cycle.id)),
    ]);

    const recentPushes = await this.audience.recentPushes(
      rows.filter((row) => row.toNotify).map((row) => row.userId),
      sendAt,
    );
    const audience = summarizeOpeningAudience(rows, {
      sendAt,
      quiet,
      coalesceMinutes: tunables.coalesceMinutes,
      maxOpeningPushesPerDay: tunables.maxOpeningPushesPerDay,
      recentPushes,
      // Ancien mode : `activate` envoie dans la requête, sans heures calmes ni
      // rythme. Les destinataires et le « seulement dans l'app » restent ceux
      // d'`activate` (même texte `follow_rows`).
      immediate: !isOutboxOpeningMode(mode),
    });

    const admins = await this.adminRefs([
      ...cycles.map((cycle) => cycle.openingNotifiedById),
      ...events.map((event) => event.actorAdminId),
    ]);

    const copy = buildOpeningCopy(
      { fr: scholarship.nameFr, en: scholarship.nameEn },
      opensAt,
      closesAt ?? target?.estimatedCloseAt ?? null,
      sendAt,
    );
    const pick = (lang: 'fr' | 'en') =>
      copy.variant === 'dates_confirmed'
        ? { alert: copy[lang].dates_confirmed, favorite: copy[lang].dates_confirmed }
        : { alert: copy[lang].alert, favorite: copy[lang].favorite };

    const firstActivation = target?.activatedAt == null;
    const preExisting = target?.openingPreExisting ?? false;
    const yearById = new Map(cycles.map((cycle) => [cycle.id, cycle.academicYear]));

    return {
      scholarshipId,
      name: { fr: scholarship.nameFr, en: scholarship.nameEn },
      mode,
      scope,
      holdSeconds: tunables.holdSeconds,
      confirmThreshold: tunables.confirmThreshold,
      canSendAboveThreshold: canSendAboveOpeningThreshold(actor.role),
      worker: {
        enabled: isPushOutboxEnabled(),
        oldestDuePendingSeconds: oldestDue?.pushNotBefore
          ? Math.max(
              0,
              Math.floor((now.getTime() - oldestDue.pushNotBefore.getTime()) / 1000),
            )
          : 0,
      },
      push: {
        configured: this.push.isConfigured,
        fcm: this.push.providers.fcm,
        oneSignal: this.push.providers.oneSignal,
      },
      cycles: cycles.map((cycle) => this.previewCycle(cycle, admins, now)),
      nextAcademicYear: newest
        ? nextAcademicYear(newest.academicYear)
        : defaultOpeningAcademicYear([], now),
      target: {
        academicYear,
        cycleId: target?.id ?? null,
        exists: target !== null,
        firstActivation,
        alreadyAnnounced: target?.openingNotifiedAt != null,
        preExistingOpen: preExisting,
        fanoutScheduledAt: iso(target?.openingFanoutDueAt),
        // Ce qu'`activate` ferait sans `notify` (admin déjà déployé).
        defaultNotify: firstActivation && !preExisting,
      },
      readiness,
      audience,
      copy: {
        variant: copy.variant,
        fr: pick('fr'),
        en: pick('en'),
        // Le groupé tel qu'il partirait avec cette ligne : neutre quand elle
        // est un « Dates confirmées ».
        bundleExample: {
          fr: buildBundleCopy(
            [scholarship.nameFr, 'Bourse B', 'Bourse C'],
            'fr',
            copy.variant,
          ),
          en: buildBundleCopy(
            [scholarship.nameEn, 'Scholarship B', 'Scholarship C'],
            'en',
            copy.variant,
          ),
        },
      },
      recentEvents: events.map((event) =>
        this.recentEvent(event, admins, yearById),
      ),
    };
  }

  private previewCycle(
    cycle: PreviewCycleRow,
    admins: ReadonlyMap<string, OpeningAdminRef>,
    now: Date,
  ): OpeningPreviewCycle {
    return {
      id: cycle.id,
      academicYear: cycle.academicYear,
      status: servedCycleStatus(
        cycle.status,
        cycle.closesAt,
        cycle.estimatedCloseAt,
        now,
      ),
      rawStatus: cycle.status,
      dateConfidence: cycle.dateConfidence,
      opensAt: iso(cycle.opensAt),
      closesAt: iso(cycle.closesAt),
      estimatedOpenAt: iso(cycle.estimatedOpenAt),
      estimatedCloseAt: iso(cycle.estimatedCloseAt),
      activatedAt: iso(cycle.activatedAt),
      openingNotifiedAt: iso(cycle.openingNotifiedAt),
      openingNotifiedBy: cycle.openingNotifiedById
        ? (admins.get(cycle.openingNotifiedById) ?? null)
        : null,
      openingAudience: cycle.openingAudience,
      openingFanoutDueAt: iso(cycle.openingFanoutDueAt),
      openingLastFanoutAt: iso(cycle.openingLastFanoutAt),
      openingSkippedAt: iso(cycle.openingSkippedAt),
      openingSkippedReason: skipReason(cycle.openingSkippedReason),
      openingStoppedAt: iso(cycle.openingStoppedAt),
      openingPreExisting: cycle.openingPreExisting,
    };
  }

  // ── Annuler / arrêter ─────────────────────────────────────────────────────

  /**
   * Annule une annonce programmée : rien n'avait été écrit pour les
   * étudiants. Le worker tient le cycle `FOR UPDATE` pendant l'envoi : une
   * annulation qui l'attend relit la ligne à jour et ne trouve plus rien à
   * annuler (409 `OPENING_NOT_SCHEDULED`, avec `lastFanoutAt`).
   */
  async cancel(
    scholarshipId: string,
    cycleId: string,
    actor: OpeningActor,
    requestId: string,
  ): Promise<CancelOpeningResponse> {
    this.assertDb();
    await this.assertCycle(scholarshipId, cycleId);
    let outcome: { cancelled: true } | { cancelled: false; lastFanoutAt: Date | null };
    try {
      outcome = await this.run((p) =>
        p.$transaction(
          async (
            tx,
          ): Promise<
            { cancelled: true } | { cancelled: false; lastFanoutAt: Date | null }
          > => {
            await tx.$executeRaw`SET LOCAL lock_timeout = '5s'`;
            const scheduled = await tx.scholarshipCycle.findFirst({
              where: { id: cycleId, scholarshipId },
              select: { academicYear: true, openingFanoutDueAt: true, openingFanoutScope: true },
            });
            const { count } = await tx.scholarshipCycle.updateMany({
              where: { id: cycleId, scholarshipId, openingFanoutDueAt: { not: null } },
              data: {
                openingFanoutDueAt: null,
                openingFanoutScope: null,
                openingFanoutById: null,
              },
            });
            if (count === 0) {
              const fresh = await tx.scholarshipCycle.findUnique({
                where: { id: cycleId },
                select: { openingLastFanoutAt: true },
              });
              return { cancelled: false, lastFanoutAt: fresh?.openingLastFanoutAt ?? null };
            }
            await this.audit(tx, {
              action: 'scholarship_cycle.notify_cancelled',
              cycleId,
              actor,
              requestId,
              changes: {
                academicYear: scheduled?.academicYear ?? null,
                fanoutAt: iso(scheduled?.openingFanoutDueAt),
                scope: scheduled?.openingFanoutScope ?? null,
              },
            });
            return { cancelled: true };
          },
          OPENING_ADMIN_TRANSACTION,
        ),
      );
    } catch (error) {
      if (isOpeningBusyError(error)) throw openingError('OPENING_BUSY');
      throw error;
    }
    if (!outcome.cancelled) {
      throw openingError('OPENING_NOT_SCHEDULED', {
        lastFanoutAt: iso(outcome.lastFanoutAt),
      });
    }
    return { cycleId, cancelled: true };
  }

  /**
   * « Arrêter les envois restants » : les push en attente passent `skipped /
   * stopped_by_staff`, les entrées d'inbox restent. Les lignes en vol (bail
   * vivant) ne sont pas touchées — leur envoi est peut-être déjà chez le
   * fournisseur — mais `openingStoppedAt` (horloge de la base, comme
   * `createdAt`) fait sauter au prochain passage toute ligne écrite avant,
   * y compris une ligne qui reviendrait en nouvelle tentative.
   */
  async stop(
    scholarshipId: string,
    cycleId: string,
    actor: OpeningActor,
    requestId: string,
  ): Promise<StopOpeningResponse> {
    this.assertDb();
    const cycle = await this.assertCycle(scholarshipId, cycleId);
    let result: { stopped: number; inFlight: number };
    try {
      result = await this.run((p) =>
        p.$transaction(async (tx) => {
          // Le worker tient la ligne du cycle pendant un envoi (jusqu'à
          // 120 s) : 5 s d'attente au plus, puis 409 OPENING_BUSY — comme
          // activate et l'annulation —, jamais une requête pendue puis 500.
          await tx.$executeRaw`SET LOCAL lock_timeout = '5s'`;
          await tx.$executeRaw`
            UPDATE "ScholarshipCycle"
            SET "openingStoppedAt" = now(), "updatedAt" = now()
            WHERE "id" = ${cycleId} AND "scholarshipId" = ${scholarshipId}
          `;
          const stopped = await tx.$executeRaw`
            UPDATE "UserNotification"
            SET "pushStatus" = 'skipped', "pushLastError" = 'stopped_by_staff'
            WHERE "cycleId" = ${cycleId}
              AND "kind" = ${SCHOLARSHIP_OPENED_KIND}
              AND "pushStatus" = 'pending'
              AND ("pushLockedUntil" IS NULL OR "pushLockedUntil" < now())
          `;
          const inFlight = await tx.userNotification.count({
            where: { cycleId, kind: SCHOLARSHIP_OPENED_KIND, pushStatus: 'pending' },
          });
          await this.audit(tx, {
            action: 'scholarship_cycle.notify_stopped',
            cycleId,
            actor,
            requestId,
            changes: { academicYear: cycle.academicYear, stopped, inFlight },
          });
          return { stopped, inFlight };
        }, OPENING_ADMIN_TRANSACTION),
      );
    } catch (error) {
      if (isOpeningBusyError(error)) throw openingError('OPENING_BUSY');
      throw error;
    }
    return { cycleId, stopped: result.stopped, inFlight: result.inFlight };
  }

  // ── Rapport ───────────────────────────────────────────────────────────────

  async report(
    scholarshipId: string,
    cycleId: string,
    now: Date = new Date(),
  ): Promise<OpeningReportResponse> {
    this.assertDb();
    const cycle = await this.run((p) =>
      p.scholarshipCycle.findFirst({
        where: { id: cycleId, scholarshipId },
        select: {
          academicYear: true,
          openingFanoutDueAt: true,
          openingFanoutScope: true,
          openingNotifiedAt: true,
          openingNotifiedById: true,
          openingLastFanoutAt: true,
          openingStoppedAt: true,
        },
      }),
    );
    if (!cycle) {
      throw new NotFoundException(`Cycle ${cycleId} not found for this scholarship.`);
    }

    const [groups, [extra], lastFanout] = await Promise.all([
      this.run((p) =>
        p.$queryRaw<OpeningReportGroup[]>`
          SELECT "pushStatus", "pushLastError", "pushProvider",
                 ("pushNotBefore" > ${now}) AS "future",
                 count(*)::int AS "n",
                 count("readAt")::int AS "read"
          FROM "UserNotification"
          WHERE "cycleId" = ${cycleId} AND "kind" = ${SCHOLARSHIP_OPENED_KIND}
          GROUP BY 1, 2, 3, 4
        `,
      ),
      this.run((p) =>
        p.$queryRaw<{ acceptedPushes: number; oldestDuePendingAt: Date | null }[]>`
          SELECT
            count(DISTINCT "pushBatchId") FILTER (WHERE "pushStatus" = 'accepted')::int
              AS "acceptedPushes",
            min("pushNotBefore") FILTER (
              WHERE "pushStatus" = 'pending' AND "pushNotBefore" <= ${now}
            ) AS "oldestDuePendingAt"
          FROM "UserNotification"
          WHERE "cycleId" = ${cycleId} AND "kind" = ${SCHOLARSHIP_OPENED_KIND}
        `,
      ),
      // La portée est effacée avec la programmation : celle de la dernière
      // annonce exécutée est dans son événement d'audit.
      this.run((p) =>
        p.adminAuditEvent.findFirst({
          where: {
            entityType: OPENING_AUDIT_ENTITY_TYPE,
            entityId: cycleId,
            action: 'scholarship_cycle.fanout_completed',
            result: 'success',
          },
          orderBy: { occurredAt: 'desc' },
          select: { changes: true },
        }),
      ),
    ]);

    const scope = cycle.openingFanoutScope ?? jsonField(lastFanout?.changes ?? null, 'scope');
    const admins = await this.adminRefs([cycle.openingNotifiedById]);
    const counts = buildOpeningReportCounts(groups, extra?.acceptedPushes ?? 0);
    return {
      scholarshipId,
      cycleId,
      academicYear: cycle.academicYear,
      fanout: {
        scheduledAt: iso(cycle.openingFanoutDueAt),
        completedAt: iso(cycle.openingNotifiedAt),
        lastFanoutAt: iso(cycle.openingLastFanoutAt),
        stoppedAt: iso(cycle.openingStoppedAt),
        notifiedBy: cycle.openingNotifiedById
          ? (admins.get(cycle.openingNotifiedById) ?? null)
          : null,
        scope: isOpeningAudienceScope(scope) ? scope : null,
      },
      ...counts,
      oldestDuePendingAt: iso(extra?.oldestDuePendingAt),
      generatedAt: now.toISOString(),
    };
  }

  // ── « À faire » et colonnes de la liste ───────────────────────────────────

  /**
   * Cycles servis ouverts (ouverture passée ou inconnue), jamais annoncés, ni
   * sautés, ni programmés, ni ouverts avant la mise en service, d'une bourse
   * publique. Triés par abonnés, 100 au plus.
   */
  async todo(now: Date = new Date()): Promise<OpeningTodoResponse> {
    this.assertDb();
    const mode = readScholarshipOpeningMode();
    const scope = audienceScopeForMode(mode);
    const cycles = await this.run((p) =>
      p.scholarshipCycle.findMany({
        where: {
          status: 'open',
          openingNotifiedAt: null,
          openingSkippedAt: null,
          openingFanoutDueAt: null,
          openingPreExisting: false,
          OR: [{ opensAt: null }, { opensAt: { lte: now } }],
          scholarship: publicScholarshipWhere(now),
        },
        select: {
          id: true,
          scholarshipId: true,
          academicYear: true,
          status: true,
          opensAt: true,
          closesAt: true,
          estimatedCloseAt: true,
          activatedAt: true,
          scholarship: { select: { nameFr: true } },
        },
      }),
    );
    const served = cycles.filter(
      (cycle) =>
        servedCycleStatus(cycle.status, cycle.closesAt, cycle.estimatedCloseAt, now) ===
        'open',
    );
    const counts = await this.followerCounts(
      scope,
      served.map((cycle) => cycle.scholarshipId),
    );
    const items: OpeningTodoItem[] = served
      .map((cycle) => ({
        scholarshipId: cycle.scholarshipId,
        nameFr: cycle.scholarship.nameFr,
        cycleId: cycle.id,
        academicYear: cycle.academicYear,
        opensAt: iso(cycle.opensAt),
        closesAt: iso(cycle.closesAt),
        source: cycle.activatedAt === null ? ('catalogue' as const) : ('admin' as const),
        followers: counts.get(cycle.scholarshipId)?.followers ?? 0,
      }))
      .sort(
        (a, b) =>
          b.followers - a.followers ||
          a.nameFr.localeCompare(b.nameFr, 'fr') ||
          compareAcademicYear(b.academicYear, a.academicYear),
      );
    return { mode, scope, items: items.slice(0, OPENING_TODO_LIMIT), total: items.length };
  }

  /** « Abonnés » (`notifiable`) et « Annoncé » de la liste admin, fusionnés par id. */
  async overview(): Promise<OpeningOverviewResponse> {
    this.assertDb();
    const mode = readScholarshipOpeningMode();
    const scope = audienceScopeForMode(mode);
    const [counts, cycles] = await Promise.all([
      this.followerCounts(scope),
      this.run((p) =>
        p.scholarshipCycle.findMany({
          where: {
            OR: [
              { openingNotifiedAt: { not: null } },
              { openingFanoutDueAt: { not: null } },
            ],
          },
          select: {
            id: true,
            scholarshipId: true,
            academicYear: true,
            openingNotifiedAt: true,
            openingLastFanoutAt: true,
            openingAudience: true,
            openingFanoutDueAt: true,
          },
        }),
      ),
    ]);

    const items = new Map<string, OpeningOverviewItem>();
    const itemFor = (scholarshipId: string): OpeningOverviewItem => {
      let item = items.get(scholarshipId);
      if (!item) {
        const count = counts.get(scholarshipId);
        item = {
          scholarshipId,
          followers: count?.followers ?? 0,
          notifiable: count?.notifiable ?? 0,
          lastAnnounced: null,
          scheduledAt: null,
        };
        items.set(scholarshipId, item);
      }
      return item;
    };
    for (const scholarshipId of counts.keys()) itemFor(scholarshipId);
    for (const cycle of cycles) {
      const item = itemFor(cycle.scholarshipId);
      const at = cycle.openingLastFanoutAt ?? cycle.openingNotifiedAt;
      if (at && (!item.lastAnnounced || at.toISOString() > item.lastAnnounced.at)) {
        item.lastAnnounced = {
          cycleId: cycle.id,
          academicYear: cycle.academicYear,
          at: at.toISOString(),
          audience: cycle.openingAudience,
        };
      }
      const due = cycle.openingFanoutDueAt?.toISOString() ?? null;
      if (due && (!item.scheduledAt || due < item.scheduledAt)) item.scheduledAt = due;
    }
    return {
      mode,
      scope,
      items: [...items.values()].sort((a, b) =>
        a.scholarshipId.localeCompare(b.scholarshipId),
      ),
    };
  }

  // ── Audit ─────────────────────────────────────────────────────────────────

  /** Les 5 derniers événements d'annonce des cycles d'une bourse. */
  async recentEvents(cycleIds: readonly string[]): Promise<OpeningRecentEvent[]> {
    this.assertDb();
    const events = await this.recentEventRows(cycleIds);
    const admins = await this.adminRefs(events.map((event) => event.actorAdminId));
    return events.map((event) => this.recentEvent(event, admins, new Map()));
  }

  private async recentEventRows(cycleIds: readonly string[]) {
    if (cycleIds.length === 0) return [];
    return this.run((p) =>
      p.adminAuditEvent.findMany({
        where: {
          entityType: OPENING_AUDIT_ENTITY_TYPE,
          entityId: { in: [...cycleIds] },
          action: { in: [...OPENING_AUDIT_ACTIONS] },
        },
        orderBy: { occurredAt: 'desc' },
        take: RECENT_EVENTS_LIMIT,
        select: {
          action: true,
          occurredAt: true,
          actorAdminId: true,
          entityId: true,
          changes: true,
        },
      }),
    );
  }

  private recentEvent(
    event: {
      action: string;
      occurredAt: Date;
      actorAdminId: string | null;
      entityId: string;
      changes: Prisma.JsonValue | null;
    },
    admins: ReadonlyMap<string, OpeningAdminRef>,
    yearById: ReadonlyMap<string, string>,
  ): OpeningRecentEvent {
    const year = jsonField(event.changes, 'academicYear');
    const toNotify = jsonField(event.changes, 'toNotify') ?? jsonField(event.changes, 'inserted');
    return {
      action: OPENING_AUDIT_ACTIONS.find((a) => a === event.action) ?? 'scholarship_cycle.opened',
      occurredAt: event.occurredAt.toISOString(),
      actorName: event.actorAdminId
        ? (admins.get(event.actorAdminId)?.name ?? null)
        : null,
      academicYear: typeof year === 'string' ? year : (yearById.get(event.entityId) ?? null),
      toNotify: typeof toNotify === 'number' ? toNotify : null,
    };
  }

  private async audit(
    tx: Prisma.TransactionClient,
    input: {
      action: OpeningAuditAction;
      cycleId: string;
      actor: OpeningActor;
      requestId: string;
      changes: Prisma.InputJsonObject;
    },
  ): Promise<void> {
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: input.actor.id,
        action: input.action,
        purposeCode: OPENING_AUDIT_PURPOSE,
        entityType: OPENING_AUDIT_ENTITY_TYPE,
        entityId: input.cycleId,
        requestId: input.requestId || randomUUID(),
        result: 'success',
        changes: input.changes,
      },
    });
  }

  // ── Aides ─────────────────────────────────────────────────────────────────

  private async assertCycle(
    scholarshipId: string,
    cycleId: string,
  ): Promise<{ academicYear: string }> {
    const cycle = await this.run((p) =>
      p.scholarshipCycle.findFirst({
        where: { id: cycleId, scholarshipId },
        select: { academicYear: true },
      }),
    );
    if (!cycle) {
      throw new NotFoundException(`Cycle ${cycleId} not found for this scholarship.`);
    }
    return cycle;
  }

  private async followerCounts(
    scope: OpeningAudienceScope,
    scholarshipIds?: readonly string[],
  ): Promise<Map<string, FollowerCountRow>> {
    if (scholarshipIds && scholarshipIds.length === 0) return new Map();
    const rows = await this.run((p) =>
      p.$queryRaw<FollowerCountRow[]>(followerCountsSql(scope, scholarshipIds)),
    );
    return new Map(rows.map((row) => [row.scholarshipId, row]));
  }

  private async adminRefs(
    ids: readonly (string | null)[],
  ): Promise<Map<string, OpeningAdminRef>> {
    const unique = [...new Set(ids.filter((id): id is string => Boolean(id)))];
    if (unique.length === 0) return new Map();
    const admins = await this.run((p) =>
      p.adminUser.findMany({
        where: { id: { in: unique } },
        select: { id: true, fullName: true },
      }),
    );
    return new Map(admins.map((a) => [a.id, { id: a.id, name: a.fullName }]));
  }
}
