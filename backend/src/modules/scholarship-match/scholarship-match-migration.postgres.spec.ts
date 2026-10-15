import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { AccountType, Prisma, PrismaClient } from '@prisma/client';

/**
 * La migration du chantier D, rejouée contre un vrai PostgreSQL.
 *
 * `prisma migrate deploy` a déjà appliqué les migrations quand cette suite
 * tourne : la base est neuve, aucune fiche n'a été reprise. La suite insère
 * donc des fiches « d'avant » (catalogue vérifié, saisie admin, collecte),
 * remet `eligibleLevels` à vide, puis rejoue l'`UPDATE` de reprise LU SUR
 * DISQUE — pas une copie, qui prouverait sa propre justesse.
 *
 * Ce qu'elle prouve :
 * - la reprise ne touche QUE les fiches taguées `catalog:%` ;
 * - elle ne tamponne JAMAIS `eligibilityStructuredAt` (un niveau repris des
 *   tags ne peut exclure personne) ;
 * - elle est idempotente ;
 * - les relations ajoutées se comportent comme annoncé (run supprimé avec le
 *   profil, dossier détaché d'une fiche supprimée).
 *
 * Tout se passe dans une transaction annulée : l'`UPDATE` rejoué touche toute
 * la table, et une base de développement ne doit pas en garder trace.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

const MIGRATION = resolve(
  process.cwd(),
  'prisma/migrations/20261020120000_scholarship_match_v1/migration.sql',
);

function updateStatements(): string[] {
  return readFileSync(MIGRATION, 'utf8')
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((statement) => statement.trim())
    .filter((statement) => /^UPDATE\b/i.test(statement));
}

class Rollback extends Error {}

describePostgres('Migration chantier D — reprise des niveaux (intégration PostgreSQL)', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID().slice(0, 8);
  const ids = {
    catalog: `match-mig-catalog-${suffix}`,
    catalogCase: `match-mig-catalog-case-${suffix}`,
    catalogNoLevel: `match-mig-catalog-nolevel-${suffix}`,
    admin: `match-mig-admin-${suffix}`,
    scraped: `match-mig-scraped-${suffix}`,
    lookalike: `match-mig-lookalike-${suffix}`,
    user: `match-mig-user-${suffix}`,
  };
  const updates = updateStatements();

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

  function scholarship(id: string, tags: string[]): Prisma.ScholarshipCreateManyInput {
    return {
      id,
      nameFr: `Bourse ${id}`,
      nameEn: `Scholarship ${id}`,
      countryId: 'fra',
      levelEligibleFr: 'Licence ou Master',
      levelEligibleEn: "Bachelor's or Master's",
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
      tags,
    };
  }

  async function seedRows(tx: Prisma.TransactionClient): Promise<void> {
    await tx.scholarship.createMany({
      data: [
        // Catalogue vérifié : tags de niveau exacts + tag de version.
        scholarship(ids.catalog, ['bachelor', 'master', 'uwc', 'catalog:1.4.0']),
        // Casse et espaces tolérés comme dans scholarship-level.ts.
        scholarship(ids.catalogCase, [' Master ', 'catalog:1.4.0', 'doctorate']),
        // Catalogue sans tag de niveau : rien à reprendre.
        scholarship(ids.catalogNoLevel, ['open', 'catalog:1.4.0']),
        // Saisie admin : tags de niveau, mais pas du catalogue.
        scholarship(ids.admin, ['bachelor', 'master']),
        // Collecte : tags de collecteur, jamais des niveaux.
        scholarship(ids.scraped, ['undergraduate', 'masters', 'phd', 'greatyop']),
        // Un tag qui ressemble sans être `catalog:` en préfixe.
        scholarship(ids.lookalike, ['master', 'not-catalog:1.4.0', 'catalog']),
      ],
    });
  }

  async function replay(tx: Prisma.TransactionClient): Promise<number[]> {
    const counts: number[] = [];
    for (const statement of updates) counts.push(await tx.$executeRawUnsafe(statement));
    return counts;
  }

  async function levelsById(tx: Prisma.TransactionClient) {
    const rows = await tx.scholarship.findMany({
      where: { id: { in: Object.values(ids) } },
      select: {
        id: true,
        eligibleLevels: true,
        eligibilityStructuredAt: true,
        eligibilityStructuredBy: true,
        fieldsScope: true,
        eligibilityCriteria: true,
      },
    });
    return new Map(rows.map((row) => [row.id, row]));
  }

  it('lit bien l’UPDATE de reprise sur disque (garde non morte)', () => {
    expect(updates).toHaveLength(1);
    expect(updates[0]).toContain("LIKE 'catalog:%'");
  });

  it('les colonnes neuves ont leurs défauts : vide, `unknown`, `[]`, aucun tampon', async () => {
    await rolledBack(async (tx) => {
      await seedRows(tx);
      for (const row of (await levelsById(tx)).values()) {
        expect(row).toMatchObject({
          eligibleLevels: [],
          fieldsScope: 'unknown',
          eligibilityCriteria: [],
          eligibilityStructuredAt: null,
          eligibilityStructuredBy: null,
        });
      }
    });
  });

  it('reprend les niveaux des SEULES fiches `catalog:%`, sans jamais tamponner', async () => {
    await rolledBack(async (tx) => {
      await seedRows(tx);
      const [count] = await replay(tx);
      expect(count).toBeGreaterThanOrEqual(2);

      const rows = await levelsById(tx);
      expect(rows.get(ids.catalog)?.eligibleLevels).toEqual(['bachelor', 'master']);
      expect(rows.get(ids.catalogCase)?.eligibleLevels).toEqual(['master', 'doctorate']);
      expect(rows.get(ids.catalogNoLevel)?.eligibleLevels).toEqual([]);
      expect(rows.get(ids.admin)?.eligibleLevels).toEqual([]);
      expect(rows.get(ids.scraped)?.eligibleLevels).toEqual([]);
      expect(rows.get(ids.lookalike)?.eligibleLevels).toEqual([]);
      for (const row of rows.values()) {
        expect(row.eligibilityStructuredAt).toBeNull();
        expect(row.eligibilityStructuredBy).toBeNull();
      }
    });
  });

  it('idempotente : une seconde exécution ne touche aucune ligne et n’écrase pas une saisie', async () => {
    await rolledBack(async (tx) => {
      await seedRows(tx);
      await replay(tx);
      // Un éditeur a corrigé les niveaux d'une fiche du catalogue entre-temps.
      await tx.scholarship.update({
        where: { id: ids.catalog },
        data: { eligibleLevels: ['master'] },
      });
      expect(await replay(tx)).toEqual([0]);
      expect((await levelsById(tx)).get(ids.catalog)?.eligibleLevels).toEqual(['master']);
    });
  });

  it('un run disparaît avec le profil ; un dossier survit à sa bourse (scholarshipId → NULL)', async () => {
    await rolledBack(async (tx) => {
      await seedRows(tx);
      await tx.userProfile.create({
        data: {
          id: ids.user,
          accountType: AccountType.student,
          preferredLanguage: 'fr',
          fullName: 'Migration chantier D',
          email: `${ids.user}@example.test`,
          phone: '',
          countryOfResidence: 'Niger',
        },
      });
      await tx.scholarshipMatchRun.create({
        data: {
          userId: ids.user,
          algorithmVersion: 'sm-1',
          trigger: 'wizard',
          profileHash: 'p',
          catalogHash: 'c',
          inputsSummary: {},
          items: [],
          excludedSummary: { groups: [], notAnalyzedCount: 0 },
        },
      });
      const created = await tx.case.create({
        data: {
          referenceCode: `KPB-MIG-${suffix}`,
          userId: ids.user,
          type: 'scholarship_support',
          status: 'submitted',
          title: 'Candidature',
          description: '',
          contextLabel: '',
          nextStepTitle: '',
          nextStepDescription: '',
          scholarshipId: ids.admin,
        },
      });
      expect(created.scholarshipId).toBe(ids.admin);

      await tx.scholarship.delete({ where: { id: ids.admin } });
      expect(
        (await tx.case.findUniqueOrThrow({ where: { id: created.id } })).scholarshipId,
      ).toBeNull();

      // La suppression d'un profil passe par ses dossiers d'abord (pas de
      // cascade sur Case) ; le run, lui, part avec le profil.
      await tx.case.delete({ where: { id: created.id } });
      await tx.userProfile.delete({ where: { id: ids.user } });
      expect(await tx.scholarshipMatchRun.count({ where: { userId: ids.user } })).toBe(0);
    });
  });
});
