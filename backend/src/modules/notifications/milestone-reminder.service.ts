import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { hasEstimatedDeadline } from '../../common/current-scholarship-cycle';
import { followingPairsSql } from '../scholarships-index/opening/scholarship-follow.query';
import { readScholarshipOpeningMode } from '../scholarships-index/opening/scholarship-opening.contract';
import {
  DispatchOutcome,
  NotificationDispatchService,
} from './notification-dispatch.service';

const DAY_MS = 24 * 60 * 60 * 1000;
// Route inchangée (chantier C, §5) : le texte dit « Ouvre ton tracker », et la
// fiche `/scholarships/:id` applique `publicScholarshipWhere` (vérifiée, date
// non passée) que cette requête n'applique pas — un rappel J-0 ou une bourse
// approuvée sans `lastVerifiedAt` ouvrirait une 404 sur les builds 53/56.
const TRACKER_ROUTE = '/deadlines';
// KPB-155: escalating thresholds J-30 / J-14 / J-7 / J-3 / J-1 (+ day-of).
const SCHOLARSHIP_REMINDER_DAYS = new Set([30, 14, 7, 3, 1, 0]);
const CASE_REMINDER_DAYS = new Set([7, 3, 1, 0]);
const REMINDER_KIND = 'deadline_reminder';

// ── Garde de transition — À RETIRER APRÈS LE 2026-11-15 ────────────────────
//
// La `dedupeKey` d'un rappel de bourse porte désormais la date d'échéance.
// Le jour du déploiement, le cron de 08:00 de l'ancien code a déjà écrit les
// clés SANS date : un `POST /admin/push/deadline-reminders` relancé ensuite (ou
// un réplica encore ancien) produirait la clé AVEC date, que la base ne connaît
// pas, et donc un second push du même seuil. On saute tout rappel dont la clé
// ancienne a été écrite il y a moins de 36 h — fenêtre qui couvre « ce matin »
// sans jamais retenir la clé d'une année précédente, précisément celle qui
// bloquait à vie les seuils de la campagne suivante.
const LEGACY_KEY_GUARD_WINDOW_MS = 36 * 60 * 60 * 1000;
// Bien en dessous de la limite de paramètres liés de PostgreSQL (32 767).
const LEGACY_KEY_GUARD_CHUNK = 1000;

interface ReminderRecipient {
  id: string;
  fullName: string | null;
  preferredLanguage: string;
  countryOfResidence: string | null;
}

interface DueReminder {
  user: ReminderRecipient;
  kind: string;
  dedupeKey: string;
  scholarshipId?: string;
  titleFr: string;
  titleEn: string;
  bodyFr: string;
  bodyEn: string;
  route: string;
  data: Record<string, string>;
}

/** Une bourse confirmée dont l'échéance tombe sur un seuil aujourd'hui. */
interface DueScholarship {
  id: string;
  nameFr: string;
  nameEn: string;
  countryNameFr: string;
  countryNameEn: string;
  deadlineAt: Date;
  days: number;
}

/** Un abonné d'une bourse à un seuil aujourd'hui. */
interface ScholarshipFollower {
  scholarshipId: string;
  user: ReminderRecipient;
}

/** Ligne de `followerRecipientsSql` : un couple suivi, joint à son profil. */
interface FollowerRecipientRow {
  scholarshipId: string;
  userId: string;
  fullName: string | null;
  preferredLanguage: string;
  countryOfResidence: string | null;
}

interface CollectedReminders {
  reminders: DueReminder[];
  /** Déjà envoyés aujourd'hui sous la clé sans date (garde de transition). */
  legacyDuplicates: number;
}

@Injectable()
export class MilestoneReminderService {
  private readonly logger = new Logger(MilestoneReminderService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly dispatch: NotificationDispatchService,
  ) {}

  // 08:00 UTC ≈ 08:00–09:00 across the core francophone market (UTC+0/+1), i.e.
  // safely outside the quiet window. The dispatcher still guards per-user quiet
  // hours and the daily cap, so this stays correct for other residences too.
  @Cron('0 8 * * *')
  async handleDailyMilestoneReminders(): Promise<{
    due: number;
    outcomes: Partial<Record<DispatchOutcome, number>>;
  }> {
    if (!this.prismaService.isEnabled) return { due: 0, outcomes: {} };

    const { reminders, legacyDuplicates } = await this.collect(new Date());
    const tally: Partial<Record<DispatchOutcome, number>> = {};
    // Pour l'admin, un rappel déjà parti ce matin sous l'ancienne clé est ce
    // qu'une relance du même jour a toujours rendu : `deduped`.
    if (legacyDuplicates > 0) tally.deduped = legacyDuplicates;
    for (const reminder of reminders) {
      const outcome = await this.dispatch.dispatch({
        userId: reminder.user.id,
        kind: reminder.kind,
        dedupeKey: reminder.dedupeKey,
        title: { fr: reminder.titleFr, en: reminder.titleEn },
        body: { fr: reminder.bodyFr, en: reminder.bodyEn },
        route: reminder.route,
        data: reminder.data,
        scholarshipId: reminder.scholarshipId ?? null,
        preferredLanguage: reminder.user.preferredLanguage,
        countryOfResidence: reminder.user.countryOfResidence,
      });
      tally[outcome] = (tally[outcome] ?? 0) + 1;
    }

    const due = reminders.length + legacyDuplicates;
    if (due > 0) {
      this.logger.log(`Milestone reminders: ${due} due (${formatTally(tally)}).`);
    }
    // Returned so the manual admin trigger can report what actually happened
    // (KPB-173) — `deduped` on a same-day re-run is the expected outcome, not a
    // failure.
    return { due, outcomes: tally };
  }

  async collectDueReminders(now: Date): Promise<DueReminder[]> {
    return (await this.collect(now)).reminders;
  }

  private async collect(now: Date): Promise<CollectedReminders> {
    if (!this.prismaService.isEnabled) {
      return { reminders: [], legacyDuplicates: 0 };
    }

    const [scholarshipReminders, caseReminders] = await Promise.all([
      this.collectFollowedScholarshipReminders(now),
      this.collectCaseMilestoneReminders(now),
    ]);
    return {
      reminders: [...scholarshipReminders.reminders, ...caseReminders],
      legacyDuplicates: scholarshipReminders.legacyDuplicates,
    };
  }

  // ── Rappels des bourses suivies ───────────────────────────────────────────
  //
  // D'abord les bourses à un seuil AUJOURD'HUI, ensuite leurs seuls abonnés
  // (`itemId IN (…)`, index `SavedItem(itemType, itemId)`). L'ordre inverse
  // chargeait chaque jour TOUS les favoris de bourse de la base pour en garder
  // une poignée.
  private async collectFollowedScholarshipReminders(
    now: Date,
  ): Promise<CollectedReminders> {
    const horizon = addDays(now, 30);
    const scholarships =
      (await this.prismaService.execute((prisma) =>
        prisma.scholarship.findMany({
          where: {
            isActive: true,
            moderationStatus: 'approved',
            deadlineAt: { gte: startOfDay(now), lte: horizon },
          },
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            deadlineAt: true,
            countryNameFr: true,
            countryNameEn: true,
            // TOUS les cycles, pas le plus récent : c'est
            // `hasEstimatedDeadline` qui applique la règle de sélection du
            // dépôt (ouvert → prévision → premier). Un `take: 1` sur l'année
            // rendait la PRÉVISION d'une bourse dont la campagne en cours est
            // ouverte et confirmée, et supprimait donc de vrais rappels.
            // Triés par année décroissante, comme les lectures de la fiche :
            // sans ordre, deux cycles `open` (l'ancien jamais refermé) étaient
            // départagés par l'ordre physique des lignes.
            cycles: {
              select: { status: true, dateConfidence: true },
              orderBy: { academicYear: 'desc' },
            },
          },
        }),
      )) ?? [];

    const dueScholarships = new Map<string, DueScholarship>();
    for (const scholarship of scholarships) {
      if (!scholarship.deadlineAt) continue;
      // ── Ne jamais pousser un rappel J-30/14/7/3/1 sur une date ESTIMÉE ──
      //
      // L'importeur remplit `deadlineAt` depuis `estimatedCloseAt` quand le
      // cycle n'est pas confirmé — utile pour CLASSER, jamais pour AFFIRMER.
      // Sans ce test, l'app envoyait « plus que 3 jours pour candidater » sur
      // une campagne dont personne n'a publié la date. Deux surfaces clientes
      // se taisaient déjà correctement dans ce cas (la pastille de la liste et
      // le calendrier) ; la notification, elle, ne consultait pas le champ —
      // et c'est la seule des trois qui réveille le téléphone.
      //
      if (hasEstimatedDeadline(scholarship.cycles)) continue;
      const days = daysUntil(now, scholarship.deadlineAt);
      if (!SCHOLARSHIP_REMINDER_DAYS.has(days)) continue;
      dueScholarships.set(scholarship.id, {
        id: scholarship.id,
        nameFr: scholarship.nameFr,
        nameEn: scholarship.nameEn,
        countryNameFr: scholarship.countryNameFr,
        countryNameEn: scholarship.countryNameEn,
        deadlineAt: scholarship.deadlineAt,
        days,
      });
    }
    if (dueScholarships.size === 0) {
      return { reminders: [], legacyDuplicates: 0 };
    }

    const followers = await this.followersOf([...dueScholarships.keys()]);
    const candidates: Array<{ reminder: DueReminder; legacyKey: string }> = [];
    for (const follower of followers) {
      const scholarship = dueScholarships.get(follower.scholarshipId);
      if (!scholarship) continue;
      const { days } = scholarship;
      const reminder: DueReminder = {
        user: follower.user,
        kind: REMINDER_KIND,
        // La date d'échéance dans la clé : les seuils se réarment à chaque
        // campagne annuelle et après une prolongation. Sans elle, le J-7 de
        // l'an dernier bloquait à vie le J-7 de cette année (même bourse, même
        // étudiant, même seuil → même clé → `deduped`).
        dedupeKey: scholarshipReminderKey(
          scholarship.id,
          scholarship.deadlineAt,
          follower.user.id,
          days,
        ),
        scholarshipId: scholarship.id,
        titleFr:
          days === 0 ? 'Échéance bourse aujourd’hui' : `Bourse à J-${days}`,
        titleEn:
          days === 0
            ? 'Scholarship deadline today'
            : `Scholarship deadline in ${days} day${days > 1 ? 's' : ''}`,
        bodyFr: `${scholarship.nameFr} (${scholarship.countryNameFr || 'destination à confirmer'}) arrive bientôt. Ouvre ton tracker pour vérifier les étapes restantes.`,
        bodyEn: `${scholarship.nameEn} (${scholarship.countryNameEn || 'destination pending'}) is coming up. Open your tracker to review the remaining steps.`,
        route: TRACKER_ROUTE,
        data: {
          type: 'milestone_reminder',
          reminderType: 'saved_scholarship',
          scholarshipId: scholarship.id,
          daysUntil: String(days),
        },
      };
      candidates.push({
        reminder,
        legacyKey: legacyScholarshipReminderKey(
          scholarship.id,
          follower.user.id,
          days,
        ),
      });
    }
    return this.withoutLegacyDuplicates(candidates, now);
  }

  /**
   * Qui reçoit les rappels de ces bourses.
   *
   * - `outbox_followers` : ceux qui SUIVENT (favori ∪ alerte non mise en
   *   sourdine), par la définition partagée `followingPairsSql`. Une sourdine
   *   ne coupe que l'annonce d'ouverture, et la désinscription globale
   *   `followed_scholarship_updates` aussi : un rappel d'échéance est
   *   transactionnel (`common/notification-types.ts`).
   * - Autres modes : les favoris, comme avant le chantier C. Les étudiants
   *   « alerte seule » n'entrent dans les rappels qu'à la bascule.
   *
   * Lu à chaque passage : la bascule de mode ne demande pas de redémarrage.
   */
  private async followersOf(
    scholarshipIds: string[],
  ): Promise<ScholarshipFollower[]> {
    if (readScholarshipOpeningMode() === 'outbox_followers') {
      const rows =
        (await this.prismaService.execute((prisma) =>
          prisma.$queryRaw<FollowerRecipientRow[]>(
            followerRecipientsSql(scholarshipIds),
          ),
        )) ?? [];
      return rows.map((row) => ({
        scholarshipId: row.scholarshipId,
        user: {
          id: row.userId,
          fullName: row.fullName,
          preferredLanguage: row.preferredLanguage,
          countryOfResidence: row.countryOfResidence,
        },
      }));
    }

    const savedItems =
      (await this.prismaService.execute((prisma) =>
        prisma.savedItem.findMany({
          where: { itemType: 'scholarship', itemId: { in: scholarshipIds } },
          select: {
            itemId: true,
            user: {
              select: {
                id: true,
                fullName: true,
                preferredLanguage: true,
                countryOfResidence: true,
              },
            },
          },
        }),
      )) ?? [];
    return savedItems.map((item) => ({
      scholarshipId: item.itemId,
      user: item.user,
    }));
  }

  /** Garde de transition (voir `LEGACY_KEY_GUARD_WINDOW_MS`). */
  private async withoutLegacyDuplicates(
    candidates: ReadonlyArray<{ reminder: DueReminder; legacyKey: string }>,
    now: Date,
  ): Promise<CollectedReminders> {
    if (candidates.length === 0) return { reminders: [], legacyDuplicates: 0 };

    const since = new Date(now.getTime() - LEGACY_KEY_GUARD_WINDOW_MS);
    const legacyKeys = candidates.map((candidate) => candidate.legacyKey);
    const alreadySent = new Set<string>();
    for (let i = 0; i < legacyKeys.length; i += LEGACY_KEY_GUARD_CHUNK) {
      const chunk = legacyKeys.slice(i, i + LEGACY_KEY_GUARD_CHUNK);
      const rows =
        (await this.prismaService.execute((prisma) =>
          prisma.userNotification.findMany({
            where: { dedupeKey: { in: chunk }, createdAt: { gte: since } },
            select: { dedupeKey: true },
          }),
        )) ?? [];
      for (const row of rows) alreadySent.add(row.dedupeKey);
    }

    const reminders = candidates
      .filter((candidate) => !alreadySent.has(candidate.legacyKey))
      .map((candidate) => candidate.reminder);
    return {
      reminders,
      legacyDuplicates: candidates.length - reminders.length,
    };
  }

  private async collectCaseMilestoneReminders(
    now: Date,
  ): Promise<DueReminder[]> {
    const horizon = addDays(now, 7);
    const cases =
      (await this.prismaService.execute((prisma) =>
        prisma.case.findMany({
          where: {
            status: { notIn: ['completed', 'rejected', 'cancelled'] },
            OR: [
              { scheduledAt: { gte: startOfDay(now), lte: horizon } },
              {
                tasks: {
                  some: {
                    dueAt: { gte: startOfDay(now), lte: horizon },
                    status: { notIn: ['done', 'completed', 'cancelled'] },
                  },
                },
              },
            ],
          },
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                preferredLanguage: true,
                countryOfResidence: true,
              },
            },
            tasks: {
              where: {
                dueAt: { gte: startOfDay(now), lte: horizon },
                status: { notIn: ['done', 'completed', 'cancelled'] },
              },
              orderBy: { dueAt: 'asc' },
            },
          },
        }),
      )) ?? [];

    const reminders: DueReminder[] = [];
    for (const item of cases) {
      if (item.scheduledAt) {
        const days = daysUntil(now, item.scheduledAt);
        if (CASE_REMINDER_DAYS.has(days)) {
          reminders.push({
            user: item.user,
            kind: REMINDER_KIND,
            dedupeKey: `deadline:case-schedule:${item.id}:${item.user.id}:d${days}`,
            titleFr:
              days === 0 ? 'Rendez-vous dossier aujourd’hui' : `Dossier à J-${days}`,
            titleEn:
              days === 0
                ? 'Case appointment today'
                : `Case milestone in ${days} day${days > 1 ? 's' : ''}`,
            bodyFr: `${item.referenceCode}: ${item.nextStepTitle}. Ouvre ton dossier pour confirmer la prochaine action.`,
            bodyEn: `${item.referenceCode}: ${item.nextStepTitle}. Open your case to confirm the next action.`,
            route: `/cases/${item.id}`,
            data: {
              type: 'milestone_reminder',
              reminderType: 'case_schedule',
              caseId: item.id,
              daysUntil: String(days),
            },
          });
        }
      }

      for (const task of item.tasks) {
        if (!task.dueAt) continue;
        const days = daysUntil(now, task.dueAt);
        if (!CASE_REMINDER_DAYS.has(days)) continue;
        reminders.push({
          user: item.user,
          kind: REMINDER_KIND,
          dedupeKey: `deadline:case-task:${task.id}:${item.user.id}:d${days}`,
          titleFr:
            days === 0 ? 'Action dossier aujourd’hui' : `Action dossier à J-${days}`,
          titleEn:
            days === 0
              ? 'Case action due today'
              : `Case action due in ${days} day${days > 1 ? 's' : ''}`,
          bodyFr: `${item.referenceCode}: ${task.title}.`,
          bodyEn: `${item.referenceCode}: ${task.title}.`,
          route: `/cases/${item.id}`,
          data: {
            type: 'milestone_reminder',
            reminderType: 'case_task',
            caseId: item.id,
            taskId: task.id,
            daysUntil: String(days),
          },
        });
      }
    }
    return reminders;
  }
}

/**
 * `deadline:scholarship:<id>:<AAAA-MM-JJ>:<userId>:d<jours>`. La date est celle
 * de l'échéance en UTC (l'admin enregistre `T23:59:59.999Z`).
 */
function scholarshipReminderKey(
  scholarshipId: string,
  deadlineAt: Date,
  userId: string,
  days: number,
): string {
  return `deadline:scholarship:${scholarshipId}:${ymdUtc(deadlineAt)}:${userId}:d${days}`;
}

/** La clé d'avant la date (garde de transition seulement). */
function legacyScholarshipReminderKey(
  scholarshipId: string,
  userId: string,
  days: number,
): string {
  return `deadline:scholarship:${scholarshipId}:${userId}:d${days}`;
}

function ymdUtc(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/**
 * Les couples suivis de ces bourses (`followingPairsSql`, la définition
 * partagée), joints au profil dans le même aller-retour : pas de seconde
 * requête `id IN (…)` à plusieurs milliers d'identifiants.
 */
function followerRecipientsSql(scholarshipIds: readonly string[]): Prisma.Sql {
  return Prisma.sql`
    SELECT
      pairs."scholarshipId" AS "scholarshipId",
      p."id" AS "userId",
      p."fullName" AS "fullName",
      p."preferredLanguage" AS "preferredLanguage",
      p."countryOfResidence" AS "countryOfResidence"
    FROM (${followingPairsSql(scholarshipIds)}) pairs
    JOIN "UserProfile" p ON p."id" = pairs."userId"
    ORDER BY pairs."scholarshipId", p."id"
  `;
}

function startOfDay(date: Date) {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function addDays(date: Date, days: number) {
  return new Date(startOfDay(date).getTime() + days * DAY_MS);
}

function daysUntil(now: Date, target: Date) {
  return Math.round(
    (startOfDay(target).getTime() - startOfDay(now).getTime()) / DAY_MS,
  );
}

function formatTally(tally: Partial<Record<DispatchOutcome, number>>): string {
  const parts = Object.entries(tally).map(([k, v]) => `${k}=${v}`);
  return parts.length ? parts.join(', ') : 'none';
}
