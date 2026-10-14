import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { AccountType, Prisma, PrismaClient } from '@prisma/client';

/**
 * Les reprises du chantier C, rejouées contre un vrai PostgreSQL.
 *
 * `prisma migrate deploy` a déjà appliqué les migrations quand cette suite
 * tourne : la base est neuve, aucune ligne héritée n'a été reprise. La suite
 * insère donc des lignes « d'avant » (cycle activé, cycle ouvert par le
 * catalogue, prévision, lignes `scholarship_opened` dont le cycle ne vit que
 * dans `data`), puis rejoue les `UPDATE` des fichiers 1 et 3 LUS SUR DISQUE —
 * pas une copie, qui prouverait sa propre justesse.
 *
 * Tout se passe dans une transaction annulée : les `UPDATE` rejoués touchent
 * toute la table, et une base de développement ne doit pas en garder trace.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

const MIGRATIONS = resolve(process.cwd(), 'prisma/migrations');

function updateStatements(directory: string): string[] {
  const sql = readFileSync(resolve(MIGRATIONS, directory, 'migration.sql'), 'utf8');
  return sql
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((statement) => statement.trim())
    .filter((statement) => /^UPDATE\b/i.test(statement));
}

class Rollback extends Error {}

describePostgres('Migration chantier C — reprises (intégration PostgreSQL)', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID().slice(0, 8);
  const ids = {
    user: `follow-mig-user-${suffix}`,
    scholarship: `follow-mig-sch-${suffix}`,
    activated: `follow-mig-activated-${suffix}`,
    catalogue: `follow-mig-catalogue-${suffix}`,
    forecast: `follow-mig-forecast-${suffix}`,
  };
  const activatedAt = new Date('2025-10-01T10:00:00.000Z');

  const fanoutUpdates = updateStatements('20261015120000_scholarship_follow_fanout');
  const backfillUpdates = updateStatements(
    '20261015120200_scholarship_follow_notification_backfill',
  );

  afterAll(async () => {
    await prisma.$disconnect();
  });

  /** Exécute `body` puis annule tout ce qu'il a écrit. */
  async function rolledBack(
    body: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<void> {
    await expect(
      prisma.$transaction(
        async (tx) => {
          await body(tx);
          throw new Rollback();
        },
        { maxWait: 5_000, timeout: 30_000 },
      ),
    ).rejects.toBeInstanceOf(Rollback);
  }

  async function seedLegacyRows(tx: Prisma.TransactionClient): Promise<void> {
    await tx.userProfile.create({
      data: {
        id: ids.user,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: 'Reprise chantier C',
        email: `${ids.user}@example.test`,
        phone: '',
        countryOfResidence: 'Sénégal',
      },
    });
    await tx.scholarship.create({
      data: {
        id: ids.scholarship,
        nameFr: 'Bourse reprise',
        nameEn: 'Backfill scholarship',
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
        lastVerifiedAt: new Date(),
      },
    });
    // Les trois états qu'un cycle pouvait avoir avant le chantier.
    await tx.scholarshipCycle.createMany({
      data: [
        {
          id: ids.activated,
          scholarshipId: ids.scholarship,
          academicYear: '2025-2026',
          status: 'open',
          dateConfidence: 'confirmed',
          activatedAt,
          activationKey: `scholarship-open:${ids.scholarship}:2025-2026`,
        },
        {
          id: ids.catalogue,
          scholarshipId: ids.scholarship,
          academicYear: '2026-2027',
          status: 'open',
          dateConfidence: 'confirmed',
        },
        {
          id: ids.forecast,
          scholarshipId: ids.scholarship,
          academicYear: '2027-2028',
          status: 'forecast',
          dateConfidence: 'estimated',
        },
      ],
    });
    // Ce qu'écrivait l'ancien `activate` : le cycle seulement dans `data`.
    await tx.userNotification.create({
      data: {
        userId: ids.user,
        scholarshipId: ids.scholarship,
        kind: 'scholarship_opened',
        dedupeKey: `scholarship-opened:${ids.activated}:${ids.user}`,
        titleFr: 'La bourse est ouverte',
        titleEn: 'Scholarship applications are open',
        bodyFr: '…',
        bodyEn: '…',
        route: `/scholarships/${ids.scholarship}`,
        data: { scholarshipId: ids.scholarship, cycleId: ids.activated },
      },
    });
  }

  async function replay(tx: Prisma.TransactionClient): Promise<number[]> {
    const counts: number[] = [];
    for (const statement of [...fanoutUpdates, ...backfillUpdates]) {
      counts.push(await tx.$executeRawUnsafe(statement));
    }
    return counts;
  }

  it('lit bien les quatre UPDATE sur disque (garde non morte)', () => {
    expect(fanoutUpdates).toHaveLength(2);
    expect(backfillUpdates).toHaveLength(2);
  });

  it('activé → pré-existant, annoncé à sa date d’activation ; catalogue → pré-existant et sauté ; prévision intacte', async () => {
    await rolledBack(async (tx) => {
      await seedLegacyRows(tx);
      await replay(tx);

      const cycles = await tx.scholarshipCycle.findMany({
        where: { scholarshipId: ids.scholarship },
      });
      const byId = new Map(cycles.map((cycle) => [cycle.id, cycle]));

      expect(byId.get(ids.activated)).toMatchObject({
        openingPreExisting: true,
        openingNotifiedAt: activatedAt,
        openingSkippedAt: null,
        openingSkippedReason: null,
        openingAudience: 1,
      });
      expect(byId.get(ids.catalogue)).toMatchObject({
        openingPreExisting: true,
        openingNotifiedAt: null,
        openingSkippedReason: 'pre_existing_open',
      });
      expect(byId.get(ids.catalogue)?.openingSkippedAt).toBeInstanceOf(Date);
      expect(byId.get(ids.forecast)).toMatchObject({
        openingPreExisting: false,
        openingNotifiedAt: null,
        openingSkippedAt: null,
        openingSkippedReason: null,
        openingAudience: null,
        openingFanoutDueAt: null,
      });

      const notification = await tx.userNotification.findUniqueOrThrow({
        where: { dedupeKey: `scholarship-opened:${ids.activated}:${ids.user}` },
      });
      expect(notification.cycleId).toBe(ids.activated);
      // Une ligne héritée n'entre jamais dans la boîte d'envoi du worker.
      expect(notification.pushStatus).toBeNull();
      expect(notification.pushAttempts).toBe(0);
    });
  });

  it('une seconde exécution ne touche aucune ligne', async () => {
    await rolledBack(async (tx) => {
      await seedLegacyRows(tx);
      const first = await replay(tx);
      expect(first.every((count) => count >= 1)).toBe(true);

      const before = await tx.scholarshipCycle.findMany({
        where: { scholarshipId: ids.scholarship },
        orderBy: { id: 'asc' },
      });
      expect(await replay(tx)).toEqual([0, 0, 0, 0]);
      const after = await tx.scholarshipCycle.findMany({
        where: { scholarshipId: ids.scholarship },
        orderBy: { id: 'asc' },
      });
      expect(after).toEqual(before);
    });
  });
});
