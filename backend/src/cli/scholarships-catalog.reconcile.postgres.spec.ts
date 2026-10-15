/**
 * `catalog:reconcile` prouvé contre un vrai PostgreSQL.
 *
 * ## Pourquoi une base réelle, alors que le plan est déjà testé sans elle
 *
 * `scholarship-catalog.reconcile.spec.ts` prouve la DÉCISION : quel champ
 * diverge, lequel est réaligné, lequel reste à la base. Il ne prouve rien de
 * l'ÉCRITURE — que l'`update` porte bien sur la bonne ligne, que la clé
 * composite `scholarshipId_academicYear` existe, qu'aucune cascade ne part.
 * L'écart mesuré en production était précisément un écart entre ce que le dépôt
 * croyait servir et ce que la base servait vraiment ; le vérifier sur une
 * maquette aurait rejoué la même erreur d'un cran.
 *
 * ## Le décor est l'état de production du 31/08/2026
 *
 * Une fiche créée par `import` depuis une version du catalogue où le cycle était
 * `estimated`, puis PUBLIÉE par `switch` — donc `isActive: true`,
 * `moderationStatus: 'approved'`, servie aux étudiants. Le dépôt dit
 * `confirmed` depuis la re-vérification du 24/08. C'est l'état exact de
 * `york_pise_2027_forecast` et `jj_wbgsp_2027_forecast`.
 *
 * L'identifiant est suffixé : le test doit rester hermétique si un `import` a
 * déjà tourné sur la même base. Ce sont les CHAMPS qui reproduisent l'incident,
 * pas la chaîne de l'identifiant.
 *
 * ## Vu rouge par mutation
 *
 * | Mutation appliquée à `scholarships-catalog.cli.ts` | Tests qui tombent |
 * |---|---|
 * | `applyReconciliation` n'écrit plus le cycle | « la base sert désormais la date ferme » ; « un second passage ne trouve plus rien à faire » |
 * | `moderationDifferences` renvoie toujours `[]` | « le filet attrape une publication qui contournerait le planificateur » |
 * | Les étapes sont supprimées puis recréées (le « delete + recreate » naïf) | « l'étape ajoutée dans l'admin survit » ; « un second passage … » |
 * | La règle de révocation rendue inopérante dans `reconcile.ts` | « une vérification révoquée ne redevient pas publique » |
 * | `sameValue` compare les objets par identité | « un second passage ne trouve plus rien à faire » (les critères `jsonb` reviennent clés réordonnées) |
 * | La règle du tampon d'éligibilité rendue inopérante | « une éligibilité relue dans l'admin survit au réalignement » |
 */
import { randomUUID } from 'node:crypto';

import { PrismaClient, type Prisma } from '@prisma/client';

import { publicScholarshipWhere } from '../common/public-scholarship-where';
import { buildScholarshipCreateData } from '../modules/scholarships-index/data/scholarship-catalog.create-data';
import {
  planIsEmpty,
  planScholarshipReconciliation,
  type ReconcilableScholarshipRow,
} from '../modules/scholarships-index/data/scholarship-catalog.reconcile';
import { SCHOLARSHIP_CATALOG_V1 } from '../modules/scholarships-index/data/scholarship-catalog.v1';
import type { VerifiedScholarshipCatalogRecord } from '../modules/scholarships-index/data/scholarship-catalog.types';
import {
  applyReconciliation,
  moderationDifferences,
} from './scholarships-catalog.cli';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

const VERSION = SCHOLARSHIP_CATALOG_V1.catalogVersion;

describePostgres('catalog:reconcile — intégration PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID().slice(0, 8);

  const source = SCHOLARSHIP_CATALOG_V1.records.find(
    (record) => record.scholarship.id === 'york_pise_2027_forecast',
  )!;

  /** La fiche telle que le dépôt la dit AUJOURD'HUI, sous un identifiant à nous. */
  const current: VerifiedScholarshipCatalogRecord = {
    ...source,
    scholarship: { ...source.scholarship, id: `reconcile-${suffix}` },
  };
  /**
   * La même, telle que le dépôt la disait AVANT la re-vérification du 24/08.
   *
   * Ce n'est pas un décor inventé : c'est le littéral retiré par le commit
   * 1176f22 (« second acte du 24/08 — les 24 non publiées relues, 2 promues en
   * dates fermes »). La ligne de production a été créée depuis celui-ci, et
   * `import` ne l'a jamais relue depuis.
   */
  const beforeReverification: VerifiedScholarshipCatalogRecord = {
    ...current,
    // Importée avant la 1.5.0 : aucune éligibilité structurée.
    eligibility: undefined,
    cycle: {
      academicYear: '2027-2028',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-11-01T00:00:00.000Z',
      estimatedCloseAt: '2027-01-26T23:59:59.000Z',
      sourceUrl: current.cycle.sourceUrl,
    },
  };

  const id = current.scholarship.id;

  async function readRow() {
    const row = await prisma.scholarship.findUnique({
      where: { id },
      include: {
        applicationSteps: { orderBy: { stepNumber: 'asc' } },
        cycles: { orderBy: { academicYear: 'desc' } },
      },
    });
    if (!row) throw new Error(`ligne ${id} absente`);
    return row;
  }

  async function reconcileOnce() {
    return prisma.$transaction(async (tx) => {
      const row = await tx.scholarship.findUnique({
        where: { id },
        include: {
          applicationSteps: { orderBy: { stepNumber: 'asc' } },
          cycles: { orderBy: { academicYear: 'desc' } },
        },
      });
      const plan = planScholarshipReconciliation(
        current,
        VERSION,
        row as unknown as ReconcilableScholarshipRow | null,
      );
      await applyReconciliation(tx, plan);
      return plan;
    });
  }

  beforeAll(async () => {
    // 1. `import` crée la ligne depuis la fiche d'avant correction…
    await prisma.scholarship.create({
      data: buildScholarshipCreateData(
        beforeReverification,
        VERSION,
      ) as Prisma.ScholarshipCreateInput,
    });
    // 2. …puis `switch` la publie. C'est l'état servi aux étudiants.
    await prisma.scholarship.update({
      where: { id },
      data: { isActive: true, moderationStatus: 'approved' },
    });
    // 3. Un relecteur a ajouté une étape depuis l'admin : elle n'est dans aucune
    //    version du catalogue et ne doit pas disparaître au réalignement.
    await prisma.scholarshipApplicationStep.create({
      data: {
        scholarshipId: id,
        stepNumber: 99,
        titleFr: 'Étape ajoutée dans l’admin',
        titleEn: 'Step added in the admin',
        descriptionFr: '',
        descriptionEn: '',
      },
    });
  }, 60_000);

  afterAll(async () => {
    await prisma.scholarship.deleteMany({ where: { id } });
    await prisma.$disconnect();
  });

  it("part bien de l'état mesuré en production : cycle estimé, fiche publiée", () => {
    // Sans cette assertion, un décor qui se monterait mal rendrait tout le
    // reste vert pour de mauvaises raisons.
    return readRow().then((row) => {
      expect(row.cycles[0].dateConfidence).toBe('estimated');
      expect(row.isActive).toBe(true);
      expect(row.moderationStatus).toBe('approved');
      // La date SERVIE aux étudiants était la projection, pas la date ferme.
      expect(row.deadlineAt?.toISOString()).toBe('2027-01-26T23:59:59.000Z');
      expect(current.cycle.dateConfidence).toBe('confirmed');
      expect(current.cycle.closesAt).toBe('2027-01-28T04:59:00.000Z');
    });
  });

  it('la base sert désormais la date ferme du dépôt', async () => {
    const plan = await reconcileOnce();
    expect(plan.cycle.action).toBe('update');

    const row = await readRow();
    expect(row.cycles[0].dateConfidence).toBe('confirmed');
    expect(row.cycles[0].closesAt?.toISOString()).toBe(
      '2027-01-28T04:59:00.000Z',
    );
    // Les projections doivent DISPARAÎTRE, pas cohabiter avec la date ferme :
    // `decidePublication` lit l'une ou l'autre selon `dateConfidence`, et une
    // valeur périmée qui traîne finit toujours par être relue par quelqu'un.
    expect(row.cycles[0].estimatedCloseAt).toBeNull();
    expect(row.cycles[0].estimatedOpenAt).toBeNull();
    // Le champ que l'étudiant voit, dérivé de la confiance.
    expect(row.deadlineAt?.toISOString()).toBe('2027-01-28T04:59:00.000Z');
  });

  it("écrit l'éligibilité structurée du dépôt, en brouillon non tamponné", async () => {
    const row = await readRow();
    expect(row.eligibleLevels).toEqual(['bachelor']);
    expect(row.eligibilityCriteria).toEqual(
      JSON.parse(JSON.stringify(current.eligibility!.criteria)),
    );
    expect(row.eligibilityStructuredBy).toBe('draft');
    // Un brouillon n'exclut personne : aucun tampon n'est posé.
    expect(row.eligibilityStructuredAt).toBeNull();
  });

  it("n'a ni publié ni dépublié en réalignant", async () => {
    const row = await readRow();
    expect(row.isActive).toBe(true);
    expect(row.moderationStatus).toBe('approved');
    // Et la fiche reste servable : `lastVerifiedAt` n'a pas été effacé, ce que
    // `publicScholarshipWhere` exige.
    expect(row.lastVerifiedAt).not.toBeNull();
  });

  it("l'étape ajoutée dans l'admin survit au réalignement", async () => {
    const row = await readRow();
    expect(row.applicationSteps.map((step) => step.stepNumber)).toContain(99);
  });

  it('un second passage ne trouve plus rien à faire', async () => {
    // L'idempotence est ce qui rend la commande sûre à relancer après un
    // incident : sans elle, on hésiterait à la rejouer, et c'est cette
    // hésitation qui laisse une base dériver.
    const plan = await reconcileOnce();
    expect(planIsEmpty(plan)).toBe(true);
    expect(plan.drifts.filter((drift) => drift.reconciled)).toEqual([]);
  });

  it("une éligibilité relue dans l'admin survit au réalignement", async () => {
    // Ce qu'écrit l'admin : un bloc relu, tamponné, plus récent que tout
    // brouillon du dépôt.
    const reviewed = [
      {
        key: 'relu-dans-l-admin',
        type: 'other',
        impact: 'soft',
        officialTextFr: current.scholarship.eligibilityFr[0],
        officialTextEn: current.scholarship.eligibilityEn[0],
        sourceUrl: current.scholarship.sourceUrl,
      },
    ];
    const stampedAt = new Date('2026-10-10T08:00:00.000Z');
    await prisma.scholarship.update({
      where: { id },
      data: {
        eligibleLevels: ['bachelor', 'master'],
        fieldsScope: 'all',
        eligibilityCriteria: reviewed,
        eligibilityStructuredAt: stampedAt,
        eligibilityStructuredBy: 'Éditrice KPB',
      },
    });

    const plan = await reconcileOnce();

    expect(planIsEmpty(plan)).toBe(true);
    expect(
      plan.drifts.filter((drift) => drift.field === 'eligibilityCriteria')[0]?.reconciled,
    ).toBe(false);
    const row = await readRow();
    expect(row.eligibilityCriteria).toEqual(reviewed);
    expect(row.eligibleLevels).toEqual(['bachelor', 'master']);
    expect(row.fieldsScope).toBe('all');
    expect(row.eligibilityStructuredAt?.toISOString()).toBe(stampedAt.toISOString());
    expect(row.eligibilityStructuredBy).toBe('Éditrice KPB');
  });

  it("une vérification révoquée ne redevient pas publique d'elle-même", async () => {
    // `AdminCatalogService.setVerification(..., false)` : le tampon est effacé
    // pour dire « à confirmer », et `isActive`/`moderationStatus` ne bougent PAS.
    // La fiche n'est donc masquée que par `lastVerifiedAt: { not: null }`.
    await prisma.scholarship.update({
      where: { id },
      data: { lastVerifiedAt: null, verifiedById: null, verifiedByName: null },
    });
    const hiddenBefore = await prisma.scholarship.count({
      where: { ...publicScholarshipWhere(), id },
    });
    // Le décor doit bien être « masquée, mais toujours active » : sinon la suite
    // ne prouverait rien.
    expect(hiddenBefore).toBe(0);
    expect((await readRow()).isActive).toBe(true);

    await reconcileOnce();

    const row = await readRow();
    expect(row.lastVerifiedAt).toBeNull();
    expect(row.verifiedByName).toBeNull();
    // La preuve qui compte : ce que la lecture publique rendra vraiment.
    await expect(
      prisma.scholarship.count({ where: { ...publicScholarshipWhere(), id } }),
    ).resolves.toBe(0);
  });

  it('le filet attrape une publication qui contournerait le planificateur', async () => {
    // Le plan ne nomme jamais `isActive`. Ce test simule le PROCHAIN chemin
    // d'écriture qui l'oublierait — c'est exactement ainsi que 11 fiches de
    // démonstration sont devenues publiques.
    const before = new Map(
      (
        await prisma.scholarship.findMany({
          select: { id: true, isActive: true, moderationStatus: true },
        })
      ).map((row) => [row.id, `${String(row.isActive)}/${row.moderationStatus}`]),
    );

    await prisma.$transaction(async (tx) => {
      await applyReconciliation(tx, {
        scholarshipId: id,
        presentInDatabase: true,
        drifts: [],
        scholarshipUpdate: { moderationStatus: 'pending', isActive: false },
        cycle: { academicYear: current.cycle.academicYear, action: 'none', data: {} },
        steps: { create: [], update: [], extraInDatabase: [] },
      });

      const after = new Map(
        (
          await tx.scholarship.findMany({
            select: { id: true, isActive: true, moderationStatus: true },
          })
        ).map((row) => [
          row.id,
          `${String(row.isActive)}/${row.moderationStatus}`,
        ]),
      );
      const changed = moderationDifferences(before, after);
      expect(changed).toEqual([`${id} (true/approved → false/pending)`]);

      // La transaction de `reconcile` annule sur cette différence ; on annule
      // ici de la même façon pour laisser la base dans l'état attendu.
      throw new Error('rollback');
    }).catch((error: unknown) => {
      if ((error as Error).message !== 'rollback') throw error;
    });

    const row = await readRow();
    expect(row.isActive).toBe(true);
    expect(row.moderationStatus).toBe('approved');
  });
});
