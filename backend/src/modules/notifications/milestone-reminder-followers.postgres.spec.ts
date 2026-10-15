import { randomUUID } from 'node:crypto';

import { AccountType, Prisma, PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { followingPairsSql } from '../scholarships-index/opening/scholarship-follow.query';
import { MilestoneReminderService } from './milestone-reminder.service';
import type { NotificationDispatchService } from './notification-dispatch.service';

/**
 * Les rappels d'échéance des bourses suivies, contre un vrai PostgreSQL.
 *
 * Le test unitaire prouve QUELLE requête part selon le mode. Celui-ci prouve ce
 * que la base en fait (chantier C, §5) :
 * - hors `outbox_followers`, les favoris seulement ; en `outbox_followers`,
 *   ceux qui suivent — l'étudiant « alerte seule » entre dans les rappels,
 *   l'alerte en sourdine sans favori n'y entre pas ;
 * - ni la sourdine d'un favori, ni la désinscription globale
 *   `followed_scholarship_updates` ne coupent un rappel (transactionnel) ;
 * - un favori orphelin (aucune FK sur `itemId`) n'est jamais lu ;
 * - la clé porte la date UTC de l'échéance, et la garde de transition saute la
 *   clé ancienne écrite ce matin, jamais celle de l'an dernier ;
 * - deux cycles `open` : le plus récent par année l'emporte ;
 * - la lecture des abonnés passe par l'index `SavedItem(itemType, itemId)`.
 *
 * Tout se passe dans une transaction annulée : rien à nettoyer, et deux
 * exécutions concurrentes ne se voient pas.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

class Rollback extends Error {}

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;
const MODE_ENV = 'KPB_SCHOLARSHIP_OPENING_MODE';

describePostgres('Rappels des bourses suivies — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const suffix = randomUUID().slice(0, 8);
  // Midi UTC, loin dans le futur : aucune bourse du catalogue n'y a
  // d'échéance, et `daysUntil` (jours locaux) vaut 7 dans tout fuseau.
  const now = new Date('2031-03-10T12:00:00.000Z');
  const deadline = new Date(now.getTime() + 7 * DAY);
  const deadlineYmd = '2031-03-17';

  const sid = `remind-f-sch-${suffix}`;
  const orphanId = `remind-f-missing-${suffix}`;
  const user = (key: string) => `remind-f-${key}-${suffix}`;
  const u = {
    fav: user('fav'),
    alert: user('alert'),
    both: user('both'),
    mutedFav: user('mutedfav'),
    mutedOnly: user('mutedonly'),
    optOut: user('optout'),
    orphanOnly: user('orphan'),
    sentThisMorning: user('morning'),
    sentLastYear: user('lastyear'),
  };

  const savedMode = process.env[MODE_ENV];
  afterEach(() => {
    if (savedMode === undefined) delete process.env[MODE_ENV];
    else process.env[MODE_ENV] = savedMode;
  });
  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function rolledBack(
    body: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<void> {
    await expect(
      prisma.$transaction(
        async (tx) => {
          await seed(tx);
          await body(tx);
          throw new Rollback();
        },
        { maxWait: 5_000, timeout: 30_000 },
      ),
    ).rejects.toBeInstanceOf(Rollback);
  }

  /** Le service, branché sur la transaction du test. */
  function serviceOn(tx: Prisma.TransactionClient): MilestoneReminderService {
    const prismaService = {
      isEnabled: true,
      execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
        operation(tx as unknown as PrismaClient),
    } as unknown as PrismaService;
    return new MilestoneReminderService(
      prismaService,
      {} as NotificationDispatchService,
    );
  }

  /** Les destinataires des rappels de NOTRE bourse, triés. */
  async function remindedUsers(tx: Prisma.TransactionClient): Promise<string[]> {
    const reminders = await serviceOn(tx).collectDueReminders(now);
    return reminders
      .filter((reminder) => reminder.scholarshipId === sid)
      .map((reminder) => reminder.user.id)
      .sort();
  }

  async function seed(tx: Prisma.TransactionClient): Promise<void> {
    await tx.userProfile.createMany({
      data: Object.entries(u).map(([key, id]) => ({
        id,
        accountType: AccountType.student,
        preferredLanguage: key === 'alert' ? 'en' : 'fr',
        fullName: `Rappel ${key}`,
        email: `${id}@example.test`,
        phone: '',
        countryOfResidence: 'Sénégal',
        disabledNotificationTypes:
          key === 'optOut' ? ['followed_scholarship_updates'] : [],
      })),
    });
    await tx.scholarship.create({
      data: {
        id: sid,
        nameFr: `Bourse ${sid}`,
        nameEn: `Scholarship ${sid}`,
        countryId: 'gbr',
        levelEligibleFr: 'Master',
        levelEligibleEn: "Master's",
        typeOfFundingFr: 'Complète',
        typeOfFundingEn: 'Full',
        deadlineLabelFr: '—',
        deadlineLabelEn: '—',
        keyRequirementsFr: [],
        keyRequirementsEn: [],
        relatedFieldIds: [],
        isActive: true,
        moderationStatus: 'approved',
        // Les rappels n'exigent pas `lastVerifiedAt` (la fiche, si).
        lastVerifiedAt: null,
        deadlineAt: deadline,
      },
    });
    // Deux cycles `open`, l'ANCIEN inséré d'abord (et estimé) : sans tri par
    // année, l'ordre physique le rendrait courant et le rappel serait tu.
    await tx.scholarshipCycle.create({
      data: {
        scholarshipId: sid,
        academicYear: '2030-2031',
        status: 'open',
        dateConfidence: 'estimated',
      },
    });
    await tx.scholarshipCycle.create({
      data: {
        scholarshipId: sid,
        academicYear: '2031-2032',
        status: 'open',
        dateConfidence: 'confirmed',
      },
    });

    const favorite = (userId: string, itemId = sid) => ({
      userId,
      itemType: 'scholarship',
      itemId,
    });
    await tx.savedItem.createMany({
      data: [
        favorite(u.fav),
        favorite(u.both),
        favorite(u.mutedFav),
        favorite(u.optOut),
        favorite(u.sentThisMorning),
        favorite(u.sentLastYear),
        // Favori orphelin : `itemId` d'une bourse qui n'existe pas.
        favorite(u.orphanOnly, orphanId),
      ],
    });
    await tx.scholarshipAlertSubscription.createMany({
      data: [
        { userId: u.alert, scholarshipId: sid },
        { userId: u.both, scholarshipId: sid },
        { userId: u.mutedFav, scholarshipId: sid, mutedAt: now },
        { userId: u.mutedOnly, scholarshipId: sid, mutedAt: now },
      ],
    });

    // Clés SANS date (ancien code) : ce matin, et il y a un an.
    const legacyRow = (userId: string, createdAt: Date) => ({
      userId,
      scholarshipId: sid,
      kind: 'deadline_reminder',
      dedupeKey: `deadline:scholarship:${sid}:${userId}:d7`,
      titleFr: 'Bourse à J-7',
      titleEn: 'Scholarship deadline in 7 days',
      bodyFr: 'b',
      bodyEn: 'b',
      route: '/deadlines',
      createdAt,
    });
    await tx.userNotification.createMany({
      data: [
        legacyRow(u.sentThisMorning, new Date(now.getTime() - 4 * HOUR)),
        legacyRow(u.sentLastYear, new Date(now.getTime() - 365 * DAY)),
      ],
    });
  }

  it.each(['legacy', 'outbox_alerts'])(
    'mode %s : les favoris seulement (sourdine et désinscription comprises)',
    async (mode) => {
      process.env[MODE_ENV] = mode;
      await rolledBack(async (tx) => {
        expect(await remindedUsers(tx)).toEqual(
          [u.fav, u.both, u.mutedFav, u.optOut, u.sentLastYear].sort(),
        );
      });
    },
  );

  it('mode outbox_followers : ceux qui suivent, l’alerte seule comprise', async () => {
    process.env[MODE_ENV] = 'outbox_followers';
    await rolledBack(async (tx) => {
      // `alert` entre ; `mutedOnly` (alerte en sourdine, pas de favori) ne
      // suit plus ; `mutedFav` et `optOut` restent rappelés.
      expect(await remindedUsers(tx)).toEqual(
        [u.fav, u.alert, u.both, u.mutedFav, u.optOut, u.sentLastYear].sort(),
      );
    });
  });

  it('un seul rappel pour qui a un favori ET une alerte', async () => {
    process.env[MODE_ENV] = 'outbox_followers';
    await rolledBack(async (tx) => {
      const users = await remindedUsers(tx);
      expect(users.filter((id) => id === u.both)).toHaveLength(1);
    });
  });

  it.each(['legacy', 'outbox_followers'])(
    'mode %s : le favori orphelin n’est jamais lu',
    async (mode) => {
      process.env[MODE_ENV] = mode;
      await rolledBack(async (tx) => {
        const reminders = await serviceOn(tx).collectDueReminders(now);
        expect(reminders.map((r) => r.user.id)).not.toContain(u.orphanOnly);
        expect(reminders.map((r) => r.scholarshipId)).not.toContain(orphanId);
      });
    },
  );

  it('clé datée, profil complet, route /deadlines', async () => {
    process.env[MODE_ENV] = 'outbox_followers';
    await rolledBack(async (tx) => {
      const reminders = await serviceOn(tx).collectDueReminders(now);
      const forAlert = reminders.find((r) => r.user.id === u.alert);
      expect(forAlert).toMatchObject({
        dedupeKey: `deadline:scholarship:${sid}:${deadlineYmd}:${u.alert}:d7`,
        route: '/deadlines',
        user: {
          id: u.alert,
          fullName: 'Rappel alert',
          preferredLanguage: 'en',
          countryOfResidence: 'Sénégal',
        },
      });
    });
  });

  it('garde de transition : la clé ancienne de ce matin bloque, celle de l’an dernier non', async () => {
    await rolledBack(async (tx) => {
      const users = await remindedUsers(tx);
      expect(users).not.toContain(u.sentThisMorning);
      expect(users).toContain(u.sentLastYear);
    });
  });

  // Vérification douce : sur une table minuscule le planificateur préfère le
  // parcours séquentiel, d'où `enable_seqscan = off` (local à la transaction
  // annulée). On vérifie qu'un index ADAPTÉ existe et sert la requête.
  it('les abonnés sont lus par l’index SavedItem(itemType, itemId)', async () => {
    await rolledBack(async (tx) => {
      await tx.$executeRawUnsafe('SET LOCAL enable_seqscan = off');
      const plan = await tx.$queryRaw<Array<{ 'QUERY PLAN': string }>>(
        Prisma.sql`EXPLAIN ${followingPairsSql([sid])}`,
      );
      const text = plan.map((row) => row['QUERY PLAN']).join('\n');
      expect(text).toContain('SavedItem_itemType_itemId_idx');
    });
  });
});
