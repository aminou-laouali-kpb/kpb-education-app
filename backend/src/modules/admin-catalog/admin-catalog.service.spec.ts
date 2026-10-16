import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import {
  AdminCatalogService,
  VERIFICATION_QUEUE_LIMIT,
} from './admin-catalog.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Guards the Bourses enrichment (applicationRequirement + admin-authored
 * application steps): a scholarship created/updated without an explicit
 * requirement must default to "separate_application" (the majority case
 * among scraped rows), an invalid value must never reach Prisma, and a
 * duplicate step number must surface as a readable 400, not a raw P2002.
 */
describe('AdminCatalogService — scholarship application requirement & steps', () => {
  function makeService(
    opts: {
      createThrows?: unknown;
      updateThrows?: unknown;
      deleteThrows?: unknown;
    } = {},
  ) {
    const scholarshipCreates: Array<Record<string, unknown>> = [];
    const scholarshipUpdates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    const stepCreates: Array<Record<string, unknown>> = [];
    const stepUpdates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    const stepDeletes: Array<{ where: Record<string, unknown> }> = [];
    const stepFindManyCalls: Array<Record<string, unknown>> = [];

    const client = {
      scholarship: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          scholarshipCreates.push(data);
          return { id: 'sch-1', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          if (opts.updateThrows) throw opts.updateThrows;
          scholarshipUpdates.push({ where, data });
          return { id: where.id, ...data };
        },
      },
      scholarshipApplicationStep: {
        findMany: async (args: Record<string, unknown>) => {
          stepFindManyCalls.push(args);
          return [];
        },
        create: async ({ data }: { data: Record<string, unknown> }) => {
          if (opts.createThrows) throw opts.createThrows;
          stepCreates.push(data);
          return { id: 'step-1', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          if (opts.updateThrows) throw opts.updateThrows;
          stepUpdates.push({ where, data });
          return { id: where.id, ...data };
        },
        delete: async ({ where }: { where: Record<string, unknown> }) => {
          if (opts.deleteThrows) throw opts.deleteThrows;
          stepDeletes.push({ where });
          return { id: where.id };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return {
      service: new AdminCatalogService(prisma),
      scholarshipCreates,
      scholarshipUpdates,
      stepCreates,
      stepUpdates,
      stepDeletes,
      stepFindManyCalls,
    };
  }

  describe('applicationRequirement', () => {
    it('createScholarship defaults to separate_application when omitted', async () => {
      const { service, scholarshipCreates } = makeService();
      await service.createScholarship({ nameFr: 'Bourse X', countryId: 'fr' });
      expect(scholarshipCreates[0].applicationRequirement).toBe(
        'separate_application',
      );
      expect(scholarshipCreates[0].moderationStatus).toBe('pending');
    });

    it('createScholarship accepts an explicit automatic value', async () => {
      const { service, scholarshipCreates } = makeService();
      await service.createScholarship({
        nameFr: 'Bourse X',
        countryId: 'fr',
        applicationRequirement: 'automatic',
      });
      expect(scholarshipCreates[0].applicationRequirement).toBe('automatic');
    });

    it('createScholarship falls back to the default on an invalid value', async () => {
      const { service, scholarshipCreates } = makeService();
      await service.createScholarship({
        nameFr: 'Bourse X',
        countryId: 'fr',
        applicationRequirement: 'not-a-real-value',
      });
      expect(scholarshipCreates[0].applicationRequirement).toBe(
        'separate_application',
      );
    });

    it('updateScholarship maps a valid applicationRequirement', async () => {
      const { service, scholarshipUpdates } = makeService();
      await service.updateScholarship('sch-1', {
        applicationRequirement: 'automatic',
      });
      expect(scholarshipUpdates[0].data.applicationRequirement).toBe(
        'automatic',
      );
    });

    it('updateScholarship drops an invalid applicationRequirement instead of writing it', async () => {
      const { service, scholarshipUpdates } = makeService();
      await service.updateScholarship('sch-1', {
        applicationRequirement: 'bogus',
      });
      expect(scholarshipUpdates[0].data).not.toHaveProperty(
        'applicationRequirement',
      );
    });
  });

  describe('application steps', () => {
    it('createApplicationStep persists titleFr/stepNumber and defaults titleEn to titleFr', async () => {
      const { service, stepCreates } = makeService();
      await service.createApplicationStep('sch-1', {
        stepNumber: 1,
        titleFr: 'Formulaire en ligne',
      });
      expect(stepCreates[0]).toMatchObject({
        stepNumber: 1,
        titleFr: 'Formulaire en ligne',
        titleEn: 'Formulaire en ligne',
      });
    });

    it('createApplicationStep requires stepNumber', async () => {
      const { service } = makeService();
      await expect(
        service.createApplicationStep('sch-1', { titleFr: 'Étape' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('createApplicationStep requires titleFr', async () => {
      const { service } = makeService();
      await expect(
        service.createApplicationStep('sch-1', { stepNumber: 1 }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('createApplicationStep maps a duplicate stepNumber (P2002) to a readable 400', async () => {
      const { service } = makeService({ createThrows: { code: 'P2002' } });
      await expect(
        service.createApplicationStep('sch-1', {
          stepNumber: 1,
          titleFr: 'Étape',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('updateApplicationStep only sends the provided fields', async () => {
      const { service, stepUpdates } = makeService();
      await service.updateApplicationStep('sch-1', 'step-1', {
        titleFr: 'Nouveau titre',
      });
      expect(stepUpdates[0].data).toEqual({ titleFr: 'Nouveau titre' });
    });

    it('updateApplicationStep maps a P2025 (not found) to NotFoundException', async () => {
      const { service } = makeService({ updateThrows: { code: 'P2025' } });
      await expect(
        service.updateApplicationStep('sch-1', 'missing', { titleFr: 'x' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('deleteApplicationStep removes the step by id', async () => {
      const { service, stepDeletes } = makeService();
      await service.deleteApplicationStep('sch-1', 'step-1');
      expect(stepDeletes[0].where).toEqual({ id: 'step-1' });
    });

    it('listApplicationSteps orders by stepNumber ascending', async () => {
      const { service, stepFindManyCalls } = makeService();
      await service.listApplicationSteps('sch-1');
      expect(stepFindManyCalls[0]).toMatchObject({
        where: { scholarshipId: 'sch-1' },
        orderBy: { stepNumber: 'asc' },
      });
    });
  });
});

/**
 * Guards KPB-161: the freshness SLA summary aggregates the verification queue
 * by category — overdue count, never-verified count, and oldest age — so the
 * daily ops alert reports what admins see.
 */
describe('AdminCatalogService — verification SLA (KPB-161)', () => {
  const DAY = 24 * 60 * 60 * 1000;

  function makeService(rows: {
    countries?: unknown[];
    institutions?: unknown[];
    programs?: unknown[];
    scholarships?: unknown[];
  }) {
    const client = {
      country: { findMany: async () => rows.countries ?? [] },
      institution: { findMany: async () => rows.institutions ?? [] },
      program: { findMany: async () => rows.programs ?? [] },
      scholarship: { findMany: async () => rows.scholarships ?? [] },
      $transaction: async (ps: Promise<unknown>[]) => Promise.all(ps),
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return new AdminCatalogService(prisma);
  }

  it('groups overdue items by category with never-verified + oldest age',
      async () => {
    const now = new Date();
    const service = makeService({
      countries: [
        {
          id: 'c1',
          nameFr: 'Niger',
          nameEn: 'Niger',
          lastVerifiedAt: null, // never verified
          verifiedByName: null,
          sourceUrl: null,
        },
      ],
      scholarships: [
        {
          id: 's1',
          nameFr: 'Bourse X',
          nameEn: 'Scholarship X',
          countryId: 'fra',
          deadlineLabelFr: 'Juin',
          lastVerifiedAt: new Date(now.getTime() - 45 * DAY),
          verifiedByName: 'Amina',
          sourceUrl: null,
        },
      ],
    });

    const sla = await service.verificationSlaSummary(now);

    expect(sla.totalOverdue).toBe(2);
    expect(sla.neverVerified).toBe(1);
    expect(sla.byCategory.country_visa.overdue).toBe(1);
    expect(sla.byCategory.country_visa.neverVerified).toBe(1);
    expect(sla.byCategory.country_visa.oldestDays).toBeNull();
    expect(sla.byCategory.scholarship_deadline.overdue).toBe(1);
    expect(sla.byCategory.scholarship_deadline.oldestDays).toBe(45);
  });

  it('reports zero overdue when the queue is empty', async () => {
    const service = makeService({});
    const sla = await service.verificationSlaSummary();
    expect(sla.totalOverdue).toBe(0);
    expect(sla.neverVerified).toBe(0);
    expect(sla.byCategory.scholarship_deadline.overdue).toBe(0);
  });
});

/**
 * La file de revérification face à l'import « Études en France ».
 *
 * L'import crée 10 500 lignes INACTIVES, toutes « jamais vérifiées ». La file
 * liste des fiches PUBLIÉES dont la cadence est échue : sans exclusion, ces
 * lignes y entraient d'un coup. La page admin rend un champ par ligne (et sert
 * aussi à revérifier les bourses), et l'alerte de 07 h annonçait chaque matin
 * « SLA breach : 10 5xx never verified » jusqu'à ne plus rien vouloir dire.
 *
 * Ces tests regardent la clause envoyée à la base, pas ce qu'elle rend : la
 * régression se voit à l'endroit où elle se produit.
 */
describe('AdminCatalogService — file de revérification et import EEF', () => {
  function neverVerifiedProgram(index: number) {
    return {
      id: `prog-${index}`,
      nameFr: `Formation ${index}`,
      nameEn: `Programme ${index}`,
      countryId: 'fra',
      institutionId: 'inst-1',
      lastVerifiedAt: null,
      verifiedByName: null,
      sourceUrl: null,
    };
  }

  function makeService(
    rows: {
      programs?: unknown[];
      institutions?: unknown[];
      countries?: unknown[];
      scholarships?: unknown[];
    } = {},
  ) {
    const wheres: Record<string, unknown[]> = {
      institution: [],
      program: [],
    };
    const client = {
      country: { findMany: async () => rows.countries ?? [] },
      institution: {
        findMany: async (args: { where: unknown }) => {
          wheres.institution.push(args.where);
          return rows.institutions ?? [];
        },
      },
      program: {
        findMany: async (args: { where: unknown }) => {
          wheres.program.push(args.where);
          return rows.programs ?? [];
        },
      },
      scholarship: { findMany: async () => rows.scholarships ?? [] },
      $transaction: async (ps: Promise<unknown>[]) => Promise.all(ps),
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new AdminCatalogService(prisma), wheres };
  }

  it('ne met jamais en file une ligne EEF importée et pas encore publiée', async () => {
    const { service, wheres } = makeService();

    await service.listVerificationDue();

    // « importée par l'EEF ET inactive » — ni plus (les lignes EEF PUBLIÉES
    // doivent être revérifiées à leur cadence), ni moins.
    expect((wheres.program[0] as { AND: unknown[] }).AND).toContainEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-prog-' } }, { isActive: false }],
      },
    });
    expect((wheres.institution[0] as { AND: unknown[] }).AND).toContainEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-univ-' } }, { isActive: false }],
      },
    });
  });

  it('garde la cadence : jamais vérifié, ou vérifié avant la limite', async () => {
    const { service, wheres } = makeService();
    await service.listVerificationDue();
    const clause = (wheres.program[0] as { AND: Record<string, unknown>[] }).AND[0];
    expect(clause.OR).toEqual([
      { lastVerifiedAt: null },
      { lastVerifiedAt: { lt: expect.any(Date) } },
    ]);
  });

  it('applique la même exclusion au calcul du SLA de 07 h', async () => {
    // Le SLA se calcule sur la file : si la file exclut les lignes en attente,
    // l'alerte aussi — c'est ce qui l'empêche d'annoncer 10 5xx lignes. La
    // clause EXACTE, pas une sous-chaîne : `toContain('eef-prog-')` serait vrai
    // d'une clause qui n'exclurait rien.
    const { service, wheres } = makeService();
    await service.verificationSlaSummary();
    expect((wheres.program[0] as { AND: unknown[] }).AND).toContainEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-prog-' } }, { isActive: false }],
      },
    });
    expect((wheres.institution[0] as { AND: unknown[] }).AND).toContainEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-univ-' } }, { isActive: false }],
      },
    });
  });

  describe('plafond de la réponse', () => {
    it('ne tronque pas sous le plafond, et le dit', async () => {
      const { service } = makeService({
        programs: Array.from({ length: 3 }, (_, i) => neverVerifiedProgram(i)),
      });
      const queue = await service.listVerificationDue();
      expect(queue.items).toHaveLength(3);
      expect(queue.total).toBe(3);
      expect(queue.truncated).toBe(false);
    });

    it('plafonne la réponse, donne le compte COMPLET et dit qu’il en reste', async () => {
      // Une page qui rend un champ par ligne cesse de s'ouvrir bien avant dix
      // mille lignes, et elle sert aussi à revérifier les bourses.
      const { service } = makeService({
        programs: Array.from({ length: VERIFICATION_QUEUE_LIMIT + 100 }, (_, i) =>
          neverVerifiedProgram(i),
        ),
      });
      const queue = await service.listVerificationDue();
      expect(queue.items).toHaveLength(VERIFICATION_QUEUE_LIMIT);
      expect(queue.total).toBe(VERIFICATION_QUEUE_LIMIT + 100);
      expect(queue.truncated).toBe(true);
    });

    it('garde ce qui presse le plus : les jamais-vérifiés passent avant les anciens', async () => {
      const DAY = 24 * 60 * 60 * 1000;
      const old = Array.from({ length: VERIFICATION_QUEUE_LIMIT }, (_, i) => ({
        ...neverVerifiedProgram(10_000 + i),
        lastVerifiedAt: new Date(Date.now() - 400 * DAY),
        verifiedByName: 'Amina',
      }));
      const fresh = Array.from({ length: 5 }, (_, i) => neverVerifiedProgram(i));
      // Les anciens sont listés AVANT les jamais-vérifiés : c'est le tri, pas
      // l'ordre de la base, qui doit décider de ce que le plafond garde.
      const { service } = makeService({ programs: [...old, ...fresh] });

      const queue = await service.listVerificationDue();

      expect(queue.items.slice(0, 5).map((item) => item.id)).toEqual(
        fresh.map((row) => row.id),
      );
      expect(queue.truncated).toBe(true);
    });

    it('ne dit « tronqué » qu’AU-DELÀ du plafond : exactement 500 tient', async () => {
      // La frontière, des deux côtés. Un `>=` à la place du `>` annoncerait
      // « il en reste » pour une file de 500 qui s'affiche en entier.
      const exactly = makeService({
        programs: Array.from({ length: VERIFICATION_QUEUE_LIMIT }, (_, i) =>
          neverVerifiedProgram(i),
        ),
      });
      const full = await exactly.service.listVerificationDue();
      expect(full.items).toHaveLength(VERIFICATION_QUEUE_LIMIT);
      expect(full.total).toBe(VERIFICATION_QUEUE_LIMIT);
      expect(full.truncated).toBe(false);

      const over = makeService({
        programs: Array.from({ length: VERIFICATION_QUEUE_LIMIT + 1 }, (_, i) =>
          neverVerifiedProgram(i),
        ),
      });
      const cut = await over.service.listVerificationDue();
      expect(cut.items).toHaveLength(VERIFICATION_QUEUE_LIMIT);
      expect(cut.total).toBe(VERIFICATION_QUEUE_LIMIT + 1);
      expect(cut.truncated).toBe(true);
    });

    it('ne laisse pas 800 formations jamais vérifiées chasser les bourses en retard', async () => {
      // Deux universités publiées par `PATCH { isActive: true }` : `updateProgram`
      // ne pose pas `lastVerifiedAt`, donc plus de 800 formations « jamais
      // vérifiées ». Elles passent devant toutes les fiches vérifiées, dont les
      // bourses en retard — seule catégorie qui périme en 30 jours, et que cette
      // page sert à revérifier chaque mois.
      const DAY = 24 * 60 * 60 * 1000;
      const { service } = makeService({
        programs: Array.from({ length: 830 }, (_, i) => neverVerifiedProgram(i)),
        scholarships: [1, 2, 3].map((n) => ({
          id: `bourse-${n}`,
          nameFr: `Bourse ${n}`,
          nameEn: `Scholarship ${n}`,
          countryId: 'fra',
          deadlineLabelFr: 'Juin',
          lastVerifiedAt: new Date(Date.now() - 45 * DAY),
          verifiedByName: 'Amina',
          sourceUrl: null,
        })),
        countries: [
          {
            id: 'pays-1',
            nameFr: 'Maroc',
            nameEn: 'Morocco',
            lastVerifiedAt: new Date(Date.now() - 60 * DAY),
            verifiedByName: 'Amina',
            sourceUrl: null,
          },
        ],
      });

      const queue = await service.listVerificationDue();
      const shown = new Set(queue.items.map((item) => item.id));

      expect(queue.truncated).toBe(true);
      expect(queue.total).toBe(834);
      for (const id of ['bourse-1', 'bourse-2', 'bourse-3', 'pays-1']) {
        expect(shown.has(id)).toBe(true);
      }
      expect(queue.items).toHaveLength(VERIFICATION_QUEUE_LIMIT);
    });

    it('trie les vérifiées par ÉCHÉANCE : la bourse en retard de 70 jours avant la formation en retard d’un jour', async () => {
      const DAY = 24 * 60 * 60 * 1000;
      const { service } = makeService({
        programs: [
          {
            ...neverVerifiedProgram(1),
            id: 'formation-181-jours',
            lastVerifiedAt: new Date(Date.now() - 181 * DAY),
            verifiedByName: 'Amina',
          },
        ],
        scholarships: [
          {
            id: 'bourse-100-jours',
            nameFr: 'Bourse',
            nameEn: 'Scholarship',
            countryId: 'fra',
            deadlineLabelFr: 'Juin',
            lastVerifiedAt: new Date(Date.now() - 100 * DAY),
            verifiedByName: 'Amina',
            sourceUrl: null,
          },
        ],
      });

      const queue = await service.listVerificationDue();

      // L'âge brut (181 > 100) mettait la formation devant.
      expect(queue.items.map((item) => item.id)).toEqual([
        'bourse-100-jours',
        'formation-181-jours',
      ]);
    });

    it('calcule le SLA sur la file COMPLÈTE, pas sur la version plafonnée', async () => {
      // Un SLA sur la réponse plafonnée annoncerait « 500 en retard » quand il
      // y en a 600 — l'alarme minimiserait précisément le jour où elle compte.
      const { service } = makeService({
        programs: Array.from({ length: VERIFICATION_QUEUE_LIMIT + 100 }, (_, i) =>
          neverVerifiedProgram(i),
        ),
      });
      const sla = await service.verificationSlaSummary();
      expect(sla.totalOverdue).toBe(VERIFICATION_QUEUE_LIMIT + 100);
      expect(sla.neverVerified).toBe(VERIFICATION_QUEUE_LIMIT + 100);
      expect(sla.byCategory.program_scolarite.overdue).toBe(
        VERIFICATION_QUEUE_LIMIT + 100,
      );
    });
  });
});

/**
 * Guards the match-scoring columns on Program writes (lot 1).
 *
 * `minGpaRequired`, `tuitionMinEur`, `applicationDeadline`, `teachingLanguages`
 * and `campusOfferings` feed matches.service.ts. Before this lot the admin API
 * accepted them and threw them away: every program created from the back-office
 * landed with null scoring inputs, which the scorer turns into a neutral 0.5
 * factor and a permanent `isEstimate` flag — a silent catalogue degradation
 * that nothing surfaced. These tests pin BOTH halves: the values must reach
 * Prisma, and a present-but-malformed value must fail loudly instead of being
 * dropped.
 */
describe('AdminCatalogService — Program match-scoring columns', () => {
  function makeService() {
    const creates: Array<Record<string, unknown>> = [];
    const updates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    const client = {
      program: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          creates.push(data);
          return { id: 'prog-1', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          updates.push({ where, data });
          return { id: where.id, ...data };
        },
        // Ajoutés quand le service s'est mis à entretenir
        // `Institution.programIds` : ces tests portent sur les colonnes de
        // scoring, mais toute écriture de formation touche désormais aussi la
        // liste de son établissement. Un harnais qui ne l'expose pas ferait
        // échouer le service pour une raison étrangère à ce qu'il vérifie.
        findUnique: async () => ({ institutionId: 'omnes-ece' }),
        findMany: async () => [{ id: 'prog-1' }],
      },
      institution: {
        updateMany: async () => ({ count: 1 }),
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new AdminCatalogService(prisma), creates, updates };
  }

  const required = {
    institutionId: 'omnes-ece',
    countryId: 'fra',
    fieldId: 'd01',
    nameFr: 'Bachelor Cybersécurité',
  };

  describe('createProgram', () => {
    it('persists every match-scoring column instead of dropping it', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        minGpaRequired: 12.5,
        tuitionMinEur: 6690,
        applicationDeadline: '2027-03-01T00:00:00.000Z',
        teachingLanguages: ['fr', 'en'],
      });
      expect(creates).toHaveLength(1);
      expect(creates[0].minGpaRequired).toBe(12.5);
      expect(creates[0].tuitionMinEur).toBe(6690);
      expect(creates[0].applicationDeadline).toEqual(
        new Date('2027-03-01T00:00:00.000Z'),
      );
      expect(creates[0].teachingLanguages).toEqual(['fr', 'en']);
    });

    it('truncates tuitionMinEur to an integer (the column is Int?)', async () => {
      const { service, creates } = makeService();
      await service.createProgram({ ...required, tuitionMinEur: 6690.9 });
      expect(creates[0].tuitionMinEur).toBe(6690);
    });

    it('defaults teachingLanguages to [] and leaves the other columns unset', async () => {
      const { service, creates } = makeService();
      await service.createProgram(required);
      expect(creates[0].teachingLanguages).toEqual([]);
      expect(creates[0].minGpaRequired).toBeUndefined();
      expect(creates[0].tuitionMinEur).toBeUndefined();
      expect(creates[0].applicationDeadline).toBeUndefined();
      expect(creates[0].campusOfferings).toBeUndefined();
    });

    it('rejects a non-numeric minGpaRequired instead of silently dropping it', async () => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, minGpaRequired: '12.5' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    it('rejects an unparseable applicationDeadline', async () => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, applicationDeadline: 'bientôt' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    // Revue #271 (P2) : `new Date(str)` accepte bien plus que de l'ISO-8601 et
    // lit les autres formes en heure LOCALE. Mesuré sous Node avant correctif :
    //   '1 mars 2027'  → 2027-02-28T23:00Z   (accepté, et décalé d'un jour)
    //   '03/01/2027'   → 2027-02-28T23:00Z   (accepté, ambigu FR/US)
    //   '2027-02-30'   → 2027-03-02T00:00Z   (jour inexistant, reporté)
    // Une faute de frappe devenait donc une échéance valide et fausse.
    it.each([
      ['une date en toutes lettres', '1 mars 2027'],
      ['un format anglo-saxon', 'March 1 2027'],
      ['un format ambigu à slashes', '03/01/2027'],
      ['un format compact sans tirets', '20270301'],
      ['une date-heure sans décalage UTC', '2027-03-01T10:00:00'],
    ])('rejette %s comme applicationDeadline', async (_label, value) => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, applicationDeadline: value }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    it.each([
      ['le 30 février', '2027-02-30'],
      ['le 31 avril', '2027-04-31'],
      ['un 29 février hors année bissextile', '2027-02-29'],
      ['un mois 13', '2027-13-01'],
    ])('rejette %s : jour inexistant au calendrier', async (_label, value) => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({ ...required, applicationDeadline: value }),
      ).rejects.toThrow(BadRequestException);
      expect(creates).toHaveLength(0);
    });

    it('accepte le 29 février d\'une vraie année bissextile', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        applicationDeadline: '2028-02-29',
      });
      expect(creates[0].applicationDeadline).toEqual(
        new Date('2028-02-29T00:00:00.000Z'),
      );
    });

    it('lit une date seule en UTC, sans décalage de fuseau', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        applicationDeadline: '2027-03-01',
      });
      // Le jour stocké doit rester le 1er mars quel que soit le fuseau du
      // serveur : c'est ce que garantit la forme date-seule de la spec ES.
      const stored = creates[0].applicationDeadline as Date;
      expect(stored.toISOString()).toBe('2027-03-01T00:00:00.000Z');
    });

    it('accepte une date-heure portant un décalage explicite', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        applicationDeadline: '2027-03-01T10:00:00+01:00',
      });
      expect((creates[0].applicationDeadline as Date).toISOString()).toBe(
        '2027-03-01T09:00:00.000Z',
      );
    });

    it('rejects teachingLanguages that is not an array of strings', async () => {
      const { service } = makeService();
      await expect(
        service.createProgram({ ...required, teachingLanguages: 'fr' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('campusOfferings', () => {
    it('keeps the documented shape and drops unknown keys', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        campusOfferings: [
          {
            campus: 'Lyon',
            tuitionUpfront: 6690,
            tuitionInstallments: 7025,
            intake: 'Mars 2027',
            prixSecret: 999,
          },
        ],
      });
      expect(creates[0].campusOfferings).toEqual([
        {
          campus: 'Lyon',
          tuitionUpfront: 6690,
          tuitionInstallments: 7025,
          intake: 'Mars 2027',
        },
      ]);
    });

    it('fills the optional members with null rather than omitting them', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        campusOfferings: [{ campus: 'Paris' }],
      });
      expect(creates[0].campusOfferings).toEqual([
        {
          campus: 'Paris',
          tuitionUpfront: null,
          tuitionInstallments: null,
          intake: null,
        },
      ]);
    });

    it('rejects an entry without a campus, naming the offending index', async () => {
      const { service, creates } = makeService();
      await expect(
        service.createProgram({
          ...required,
          campusOfferings: [{ campus: 'Lyon' }, { tuitionUpfront: 6690 }],
        }),
      ).rejects.toThrow(/campusOfferings\[1\]\.campus/);
      expect(creates).toHaveLength(0);
    });

    it('rejects a non-numeric tuition inside an entry', async () => {
      const { service } = makeService();
      await expect(
        service.createProgram({
          ...required,
          campusOfferings: [{ campus: 'Lyon', tuitionUpfront: '6690 €' }],
        }),
      ).rejects.toThrow(/campusOfferings\[0\]\.tuitionUpfront/);
    });

    // Chantier E/J : une retouche dans l'admin ne doit pas effacer la rentrée
    // décalée — l'app en tire son libellé, et l'import de printemps reconnaît
    // une offre déjà là à sa session.
    it('keeps a known session and rhythm, drops an unknown one', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        campusOfferings: [
          { campus: 'Paris', intake: '01/03/2027', session: 'spring', rhythm: 'alternance' },
          { campus: 'Lyon', intake: '01/10/2026', session: 'hiver', rhythm: 'mi-temps' },
        ],
      });
      expect(creates[0].campusOfferings).toEqual([
        {
          campus: 'Paris',
          tuitionUpfront: null,
          tuitionInstallments: null,
          intake: '01/03/2027',
          session: 'spring',
          rhythm: 'alternance',
        },
        {
          campus: 'Lyon',
          tuitionUpfront: null,
          tuitionInstallments: null,
          intake: '01/10/2026',
        },
      ]);
    });
  });

  describe('campusOfferings — rentrée reconduite', () => {
    // Décision du 16/10/2026 : une offre d'automne 2026 reconduite en 2027
    // porte sa date d'origine et « à confirmer ». Une retouche dans l'admin
    // ne doit pas effacer la mention à l'insu de l'éditeur.
    it('keeps rolledFromIntake and intakeEstimated, drops malformed ones', async () => {
      const { service, creates } = makeService();
      await service.createProgram({
        ...required,
        campusOfferings: [
          {
            campus: 'Paris',
            intake: '14/09/2027 · 01/10/2027',
            rolledFromIntake: '14/09/2026 · 01/10/2026',
            intakeEstimated: true,
          },
          { campus: 'Lyon', intake: '01/10/2027', rolledFromIntake: 'octobre', intakeEstimated: 'oui' },
        ],
      });
      expect(creates[0].campusOfferings).toEqual([
        {
          campus: 'Paris',
          tuitionUpfront: null,
          tuitionInstallments: null,
          intake: '14/09/2027 · 01/10/2027',
          rolledFromIntake: '14/09/2026 · 01/10/2026',
          intakeEstimated: true,
        },
        {
          campus: 'Lyon',
          tuitionUpfront: null,
          tuitionInstallments: null,
          intake: '01/10/2027',
        },
      ]);
    });
  });

  describe('recognition', () => {
    it('persists the recognition labels, EN falling back to FR', async () => {
      const { service, creates } = makeService();
      await service.createProgram({ ...required, recognitionFr: ' Titre RNCP ' });
      expect(creates[0].recognitionFr).toBe('Titre RNCP');
      expect(creates[0].recognitionEn).toBe('Titre RNCP');
    });

    it('leaves recognition untouched on an update that omits it, clears it on null', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { nameFr: 'Bachelor' });
      expect('recognitionFr' in updates[0].data).toBe(false);
      await service.updateProgram('prog-1', { recognitionFr: null, recognitionEn: '' });
      expect(updates[1].data.recognitionFr).toBeNull();
      expect(updates[1].data.recognitionEn).toBeNull();
    });
  });

  // L'import « Études en France » se publie par UNE porte : l'écran « Publication
  // EEF » (`admin/etudes-en-france/publication`), qui vérifie la source, la
  // procédure et le domaine, demande de confirmer le nombre et signe du nom de
  // l'administrateur connecté. Les routes génériques ci-dessous restent la
  // porte des fiches qui ne sont PAS de l'import (partenaires, saisie à la main) ;
  // si elles acceptaient aussi `isActive: true` sur une ligne de l'import, la
  // porte gardée ne garderait rien — `content_manager` y a accès, pas à elle.
  describe("l'import ne se publie pas par les routes génériques", () => {
    function makeGuarded(
      before: {
        institutionId: string;
        isActive: boolean;
        campusCity?: string | null;
        searchText?: string | null;
      } | null,
    ) {
      const programUpdates: Array<Record<string, unknown>> = [];
      const programCreates: Array<Record<string, unknown>> = [];
      const institutionUpdates: Array<Record<string, unknown>> = [];
      const client = {
        program: {
          create: async ({ data }: { data: Record<string, unknown> }) => {
            programCreates.push(data);
            return { id: 'created', ...data };
          },
          update: async ({ where, data }: { where: Record<string, unknown>; data: Record<string, unknown> }) => {
            programUpdates.push(data);
            return { id: where.id, ...data };
          },
          findUnique: async () => before,
          findMany: async () => [],
        },
        institution: {
          update: async ({ where, data }: { where: Record<string, unknown>; data: Record<string, unknown> }) => {
            institutionUpdates.push(data);
            return { id: where.id, ...data };
          },
          updateMany: async () => ({ count: 1 }),
        },
      };
      const prisma = {
        isEnabled: true,
        execute: async (fn: (c: typeof client) => unknown) => fn(client),
      } as unknown as PrismaService;
      return {
        service: new AdminCatalogService(prisma),
        programUpdates,
        programCreates,
        institutionUpdates,
      };
    }
    const EEF_INST = 'eef-univ-0123456789abcdef';
    const EEF_PROG = 'eef-prog-0123456789abcdef';

    describe('établissement', () => {
      it("refuse de publier un établissement de l'import", async () => {
        const { service, institutionUpdates } = makeGuarded(null);
        await expect(
          service.updateInstitution(EEF_INST, { isActive: true }),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(institutionUpdates).toEqual([]);
      });

      it('laisse retirer un établissement de l’import, ou l’éditer sans toucher au drapeau', async () => {
        const { service, institutionUpdates } = makeGuarded(null);
        await service.updateInstitution(EEF_INST, { isActive: false });
        await service.updateInstitution(EEF_INST, { nameFr: 'Nouveau nom' });
        expect(institutionUpdates).toHaveLength(2);
        expect(institutionUpdates[0].isActive).toBe(false);
        expect(Object.keys(institutionUpdates[1])).not.toContain('isActive');
      });

      it("publie toujours un établissement qui n'est pas de l'import", async () => {
        const { service, institutionUpdates } = makeGuarded(null);
        await service.updateInstitution('omnes-ece', { isActive: true });
        expect(institutionUpdates[0].isActive).toBe(true);
      });
    });

    // `Program.searchText` est DÉRIVÉ de l'intitulé et de la ville. Une formation
    // renommée dont le texte ne suit pas rend des résultats faux : l'ancien mot la
    // trouve, le nouveau la manque.
    describe('texte cherchable d’une formation renommée', () => {
      const PUBLISHED = { institutionId: EEF_INST, isActive: true };

      it('le recalcule quand l’intitulé change, avec la ville de la ligne', async () => {
        const { service, programUpdates } = makeGuarded({
          ...PUBLISHED,
          campusCity: 'Besançon',
          searchText: 'l1 droit besancon',
        });
        await service.updateProgram(EEF_PROG, { nameFr: 'L1 - Économie' });
        expect(programUpdates[0].searchText).toBe('l1 economie besancon');
      });

      it('laisse nul le texte d’une ligne qui n’en a pas — la recherche brute la couvre', async () => {
        const { service, programUpdates } = makeGuarded({
          ...PUBLISHED,
          campusCity: 'Rennes',
          searchText: null,
        });
        await service.updateProgram(EEF_PROG, { nameFr: 'Économie' });
        expect(programUpdates[0]).not.toHaveProperty('searchText');
      });

      it('n’y touche pas quand l’intitulé ne change pas', async () => {
        const { service, programUpdates } = makeGuarded({
          ...PUBLISHED,
          campusCity: 'Rennes',
          searchText: 'l1 droit rennes',
        });
        await service.updateProgram(EEF_PROG, { durationFr: '4 ans' });
        expect(programUpdates[0]).not.toHaveProperty('searchText');
      });

      it('gère une ville absente', async () => {
        const { service, programUpdates } = makeGuarded({
          ...PUBLISHED,
          campusCity: null,
          searchText: 'l1 droit',
        });
        await service.updateProgram(EEF_PROG, { nameFr: 'L1 - Histoire' });
        expect(programUpdates[0].searchText).toBe('l1 histoire');
      });
    });

    describe('formation', () => {
      it("refuse de publier une formation de l'import même rangée sous un autre établissement", async () => {
        // Le préfixe de la formation suffit : un établissement réaffecté ne blanchit pas.
        const { service, programUpdates } = makeGuarded({
          institutionId: 'omnes-ece',
          isActive: false,
        });
        await expect(
          service.updateProgram(EEF_PROG, { isActive: true }),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(programUpdates).toEqual([]);
      });

      it("refuse de publier une formation de l'import", async () => {
        const { service, programUpdates } = makeGuarded({
          institutionId: EEF_INST,
          isActive: false,
        });
        await expect(
          service.updateProgram(EEF_PROG, { isActive: true }),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(programUpdates).toEqual([]);
      });

      it("refuse de publier une formation saisie à la main SOUS un établissement de l'import", async () => {
        // Son identifiant n'a pas le préfixe, son parent l'a : c'est la définition
        // de la provenance (`eefProgramWhere`), et la recherche la servirait.
        const { service, programUpdates } = makeGuarded({
          institutionId: EEF_INST,
          isActive: false,
        });
        await expect(
          service.updateProgram('manual-1', { isActive: true }),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(programUpdates).toEqual([]);
      });

      it("refuse de ranger une formation PUBLIÉE sous un établissement de l'import", async () => {
        const { service, programUpdates } = makeGuarded({
          institutionId: 'omnes-ece',
          isActive: true,
        });
        await expect(
          service.updateProgram('partner-1', { institutionId: EEF_INST }),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(programUpdates).toEqual([]);
      });

      it("laisse éditer, retirer ou renommer une formation de l'import déjà publiée", async () => {
        const { service, programUpdates } = makeGuarded({
          institutionId: EEF_INST,
          isActive: true,
        });
        await service.updateProgram(EEF_PROG, { tuitionMinEur: 7025 });
        await service.updateProgram(EEF_PROG, { isActive: false });
        await service.updateProgram(EEF_PROG, { isActive: true }); // déjà publiée : rien ne change
        expect(programUpdates).toHaveLength(3);
      });

      it("publie toujours une formation qui n'est pas de l'import", async () => {
        const { service, programUpdates } = makeGuarded({
          institutionId: 'omnes-ece',
          isActive: false,
        });
        await service.updateProgram('partner-1', { isActive: true });
        expect(programUpdates[0].isActive).toBe(true);
      });

      it("ne crée pas, publiée, une formation sous un établissement de l'import", async () => {
        const { service, programCreates } = makeGuarded(null);
        await expect(
          service.createProgram({ ...required, institutionId: EEF_INST }),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(programCreates).toEqual([]);
      });

      it("crée en attente une formation sous un établissement de l'import", async () => {
        const { service, programCreates } = makeGuarded(null);
        await service.createProgram({
          ...required,
          institutionId: EEF_INST,
          isActive: false,
        });
        expect(programCreates[0].isActive).toBe(false);
      });

      it("crée publiée, comme avant, une formation d'un autre établissement", async () => {
        const { service, programCreates } = makeGuarded(null);
        await service.createProgram(required);
        expect(programCreates[0].isActive).toBe(true);
      });
    });
  });

  describe('publier une ligne importée', () => {
    // Les fiches créées `isActive: false` qui ne sont PAS de l'import « Études en
    // France » (partenaires, saisie à la main) se publient par ce chemin ; celles
    // de l'import ont le leur (voir le bloc précédent).
    it('accepte isActive pour publier une formation en attente', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { isActive: true });
      expect(updates[0].data.isActive).toBe(true);
    });

    it('accepte isActive pour remettre une formation en attente', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { isActive: false });
      expect(updates[0].data.isActive).toBe(false);
    });

    it("ne touche pas au drapeau quand l'appelant n'en parle pas", async () => {
      // `clean()` retire les clés `undefined` : éditer un tarif ne doit pas
      // republier une fiche que quelqu'un avait retirée.
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { tuitionMinEur: 7025 });
      expect(Object.keys(updates[0].data)).not.toContain('isActive');
    });

    it('une formation saisie à la main est publiée par défaut', async () => {
      // Celui qui écrit la fiche la relit en l'écrivant ; seul l'import de
      // masse met en attente.
      const { service, creates } = makeService();
      await service.createProgram({
        institutionId: 'omnes-ece',
        countryId: 'fra',
        fieldId: 'd01',
        nameFr: 'Licence Informatique',
        levelFr: 'Bachelor',
      });
      expect(creates[0].isActive).toBe(true);
    });
  });

  describe('updateProgram', () => {
    it('sends only the columns that were provided', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { tuitionMinEur: 7025 });
      expect(Object.keys(updates[0].data)).toEqual(['tuitionMinEur']);
      expect(updates[0].data.tuitionMinEur).toBe(7025);
    });

    // Revue #271 (P2) : le commentaire du service promet « null explicite =
    // colonne vidée » pour les cinq colonnes de scoring. teachingLanguages
    // faisait exception — il renvoyait undefined, clean() retirait la clé, et
    // l'ancien tableau survivait à l'édition. La colonne n'étant pas nullable,
    // « vider » veut dire tableau vide.
    it('clears teachingLanguages with [] when the caller sends null', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { teachingLanguages: null });
      expect(updates[0].data.teachingLanguages).toEqual([]);
    });

    it('clears a scalar column when the caller sends an explicit null', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', {
        minGpaRequired: null,
        applicationDeadline: null,
      });
      expect(updates[0].data.minGpaRequired).toBeNull();
      expect(updates[0].data.applicationDeadline).toBeNull();
    });

    it('clears campusOfferings with Prisma.DbNull, not a bare null', async () => {
      const { service, updates } = makeService();
      await service.updateProgram('prog-1', { campusOfferings: null });
      // A bare `null` on a Json? column is rejected by Prisma at runtime; the
      // mock here would happily accept it, so assert the sentinel explicitly.
      expect(updates[0].data.campusOfferings).toBe(Prisma.DbNull);
    });

    it('validates campusOfferings on update too, not only on create', async () => {
      const { service, updates } = makeService();
      await expect(
        service.updateProgram('prog-1', { campusOfferings: [{ intake: 'Mars' }] }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(updates).toHaveLength(0);
    });
  });
});

/**
 * `Institution.programIds` est une liste DÉNORMALISÉE que l'app lit pour
 * compter les formations d'un établissement, en afficher un aperçu, et ouvrir
 * la navigation depuis une fiche pays — désactivée quand la liste est vide
 * (`country_detail_screen.dart:241`). Rien en base ne la lie aux lignes
 * `Program` : créer une formation sans l'entretenir produit une formation qui
 * existe mais reste inatteignable, sans la moindre erreur.
 *
 * Mesuré en production le 18/09 : 46 formations Mundiapolis dans ce cas, créées
 * par un import qui écrivait une liste vide. La page Catalogue livrée en #275
 * reproduisait le défaut à chaque création.
 */
describe('AdminCatalogService — entretien de Institution.programIds', () => {
  function makeService(programsByInstitution: Record<string, string[]> = {}) {
    const rows: Record<string, string[]> = { ...programsByInstitution };
    const institutionUpdates: Array<{ where: Record<string, unknown>; data: Record<string, unknown> }> = [];
    let seq = 0;
    const client = {
      program: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          const id = `prog-${++seq}`;
          const inst = data.institutionId as string;
          (rows[inst] ??= []).push(id);
          return { id, ...data };
        },
        update: async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
          const next = data.institutionId as string | undefined;
          if (next) {
            for (const key of Object.keys(rows)) {
              rows[key] = rows[key].filter((x) => x !== where.id);
            }
            (rows[next] ??= []).push(where.id);
          }
          return { id: where.id, ...data };
        },
        delete: async ({ where }: { where: { id: string } }) => {
          for (const key of Object.keys(rows)) {
            rows[key] = rows[key].filter((x) => x !== where.id);
          }
          return { id: where.id };
        },
        findUnique: async ({ where }: { where: { id: string } }) => {
          for (const [inst, ids] of Object.entries(rows)) {
            if (ids.includes(where.id)) return { institutionId: inst };
          }
          return null;
        },
        findMany: async ({ where }: { where: { institutionId: string } }) =>
          (rows[where.institutionId] ?? []).map((id) => ({ id })),
      },
      institution: {
        updateMany: async (args: { where: Record<string, unknown>; data: Record<string, unknown> }) => {
          institutionUpdates.push(args);
          return { count: 1 };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new AdminCatalogService(prisma), institutionUpdates, rows };
  }

  const required = {
    institutionId: 'partner-mundiapolis',
    countryId: 'mar',
    fieldId: 'd04',
    nameFr: 'Licence Infirmier',
  };

  it('créer une formation renseigne la liste de son établissement', async () => {
    const { service, institutionUpdates } = makeService();
    await service.createProgram(required);
    expect(institutionUpdates).toHaveLength(1);
    expect(institutionUpdates[0].where).toMatchObject({ id: 'partner-mundiapolis' });
    expect(institutionUpdates[0].data.programIds).toEqual(['prog-1']);
  });

  it('la liste est reconstruite depuis la base, pas incrémentée à l’aveugle', async () => {
    const { service, institutionUpdates } = makeService({
      'partner-mundiapolis': ['déjà-là'],
    });
    await service.createProgram(required);
    expect(institutionUpdates[0].data.programIds).toEqual(['déjà-là', 'prog-1']);
  });

  it('supprimer une formation la retire de la liste', async () => {
    const { service, institutionUpdates } = makeService({
      'partner-mundiapolis': ['prog-a', 'prog-b'],
    });
    await service.deleteProgram('prog-a');
    expect(institutionUpdates).toHaveLength(1);
    expect(institutionUpdates[0].data.programIds).toEqual(['prog-b']);
  });

  // Le cas qui se perd le plus facilement : changer d'établissement doit
  // toucher les DEUX listes, celle qu'on quitte et celle qu'on rejoint.
  it('déplacer une formation met à jour les deux établissements', async () => {
    const { service, institutionUpdates } = makeService({
      'inst-a': ['prog-x'],
      'inst-b': [],
    });
    await service.updateProgram('prog-x', { institutionId: 'inst-b' });
    const touched = institutionUpdates.map((u) => (u.where as { id: string }).id).sort();
    expect(touched).toEqual(['inst-a', 'inst-b']);
    const byInst = Object.fromEntries(
      institutionUpdates.map((u) => [(u.where as { id: string }).id, u.data.programIds]),
    );
    expect(byInst['inst-a']).toEqual([]);
    expect(byInst['inst-b']).toEqual(['prog-x']);
  });

  it('une modification sans changement d’établissement n’en touche qu’un', async () => {
    const { service, institutionUpdates } = makeService({ 'inst-a': ['prog-x'] });
    await service.updateProgram('prog-x', { nameFr: 'Nouveau nom' });
    expect(institutionUpdates).toHaveLength(1);
    expect((institutionUpdates[0].where as { id: string }).id).toBe('inst-a');
  });
});

describe('AdminCatalogService — institution country change', () => {
  function makeService(programsElsewhere: number) {
    const updates: unknown[] = [];
    const counts: unknown[] = [];
    const client = {
      program: {
        count: async (args: unknown) => {
          counts.push(args);
          return programsElsewhere;
        },
      },
      institution: {
        update: async (args: { where: { id: string } }) => {
          updates.push(args);
          return { id: args.where.id };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new AdminCatalogService(prisma), updates, counts };
  }

  it('refuses to move an institution whose programs belong to another country', async () => {
    const { service, updates, counts } = makeService(3);
    await expect(
      service.updateInstitution('inst-1', { countryId: 'deu' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(counts).toEqual([
      { where: { institutionId: 'inst-1', countryId: { not: 'deu' } } },
    ]);
    expect(updates).toHaveLength(0);
  });

  it('allows the move when every program already matches (or there are none)', async () => {
    const { service, updates } = makeService(0);
    await service.updateInstitution('inst-1', { countryId: 'deu' });
    expect(updates).toHaveLength(1);
  });

  it('does not query programs when the country is unchanged in the payload', async () => {
    const { service, counts } = makeService(5);
    await service.updateInstitution('inst-1', { nameFr: 'Nom' });
    expect(counts).toHaveLength(0);
  });
});
