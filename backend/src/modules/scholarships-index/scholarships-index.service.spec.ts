import { GreatYopScraper } from './scrapers/greatyop.scraper';
import { MastereTnScraper } from './scrapers/mastereTn.scraper';
import { ScholarshipsIndexService } from './scholarships-index.service';
import { PrismaService } from '../prisma/prisma.service';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';
import { BadRequestException } from '@nestjs/common';

/**
 * Guards the Bourses enrichment surfacing on both consumers of the live
 * index: the public listing (`listForProfile`, localized single-language)
 * and the admin moderation queue (`listForModeration`, both languages so the
 * admin can edit either). Neither must silently drop `applicationRequirement`
 * or `applicationSteps` — that would leave the mobile UI with nothing to
 * render and the admin UI with nothing to edit.
 */
describe('ScholarshipsIndexService — application requirement & steps', () => {
  const baseRow = {
    id: 'sch-1',
    nameFr: 'Bourse Chevening',
    nameEn: 'Chevening Scholarship',
    countryId: 'gb',
    countryNameFr: 'Royaume-Uni',
    countryNameEn: 'United Kingdom',
    levelEligibleFr: 'Master',
    levelEligibleEn: 'Master',
    fundingType: 'fully_funded',
    applicationRequirement: 'separate_application',
    descriptionFr: 'Description FR',
    descriptionEn: 'Description EN',
    advantagesFr: ['Avantage FR'],
    advantagesEn: ['Benefit EN'],
    eligibilityFr: ['Critère FR'],
    eligibilityEn: ['Criterion EN'],
    deadlineLabelFr: 'Novembre',
    deadlineLabelEn: 'November',
    deadlineAt: null,
    applicationUrl: 'https://chevening.org',
    sourceUrl: null,
    tags: ['uk'],
    relatedFieldIds: [],
    baseMatch: 30,
    sourceKey: null,
    applicationUrl2: undefined,
    moderationStatus: 'pending',
    lastVerifiedAt: null,
    applicationSteps: [
      {
        id: 'step-1',
        stepNumber: 1,
        titleFr: 'Formulaire en ligne',
        titleEn: 'Online form',
        descriptionFr: 'Remplir le formulaire',
        descriptionEn: 'Fill in the form',
        estimatedDurationDays: 30,
      },
    ],
  };

  function makeService(rows: Array<Record<string, unknown>>) {
    const findManyCalls: Array<Record<string, unknown>> = [];
    const client = {
      scholarship: {
        findMany: async (args: Record<string, unknown>) => {
          findManyCalls.push(args);
          return rows;
        },
        count: async () => rows.length,
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ScholarshipsIndexService(
      prisma,
      {} as unknown as GreatYopScraper,
      {} as unknown as MastereTnScraper,
      {
        assertReady: jest.fn(),
      } as unknown as ScholarshipContentQualityService,
    );
    return { service, findManyCalls };
  }

  describe('listForProfile (public, single-language)', () => {
    it('includes applicationRequirement and localized applicationSteps (fr)', async () => {
      const { service } = makeService([baseRow]);
      const result = await service.listForProfile({ lang: 'fr' });

      expect(result.items[0].applicationRequirement).toBe(
        'separate_application',
      );
      expect(result.items[0].applicationSteps).toEqual([
        {
          id: 'step-1',
          stepNumber: 1,
          title: 'Formulaire en ligne',
          description: 'Remplir le formulaire',
          estimatedDurationDays: 30,
        },
      ]);
    });

    it('localizes applicationSteps to English when lang=en', async () => {
      const { service } = makeService([baseRow]);
      const result = await service.listForProfile({ lang: 'en' });

      expect(result.items[0].applicationSteps[0]).toMatchObject({
        title: 'Online form',
        description: 'Fill in the form',
      });
    });

    it('requests applicationSteps ordered by stepNumber ascending', async () => {
      const { service, findManyCalls } = makeService([baseRow]);
      await service.listForProfile({ lang: 'fr' });

      expect(findManyCalls[0].include).toMatchObject({
        applicationSteps: { orderBy: { stepNumber: 'asc' } },
      });
    });

    it('defaults to an empty steps array when a scholarship has none', async () => {
      const { service } = makeService([{ ...baseRow, applicationSteps: [] }]);
      const result = await service.listForProfile({ lang: 'fr' });

      expect(result.items[0].applicationSteps).toEqual([]);
    });
  });

  describe('listForModeration (admin, bilingual)', () => {
    it('exposes applicationRequirement and both-language applicationSteps for editing', async () => {
      const { service } = makeService([baseRow]);
      const result = await service.listForModeration('pending');

      expect(result.items[0].applicationRequirement).toBe(
        'separate_application',
      );
      expect(result.items[0].applicationSteps).toEqual([
        {
          id: 'step-1',
          stepNumber: 1,
          titleFr: 'Formulaire en ligne',
          titleEn: 'Online form',
          descriptionFr: 'Remplir le formulaire',
          descriptionEn: 'Fill in the form',
          estimatedDurationDays: 30,
        },
      ]);
    });
  });

  /**
   * `relatedFieldIds` is empty on every write path into the table (legacy seed,
   * verified-catalog import, scraper upsert) until an admin curates it. Applied
   * as an exclusion, a student's profile fields therefore hid the ENTIRE
   * published catalog and the app rendered "no scholarships found" — a curation
   * gap indistinguishable from an outage. The profile fields must rank, never
   * exclude everything.
   */
  // Les centres d'intérêt du profil CLASSENT la liste, ils ne la filtrent pas.
  //
  // L'état mesuré en production le 21/08/2026 : 10 fiches publiées, UNE SEULE
  // avec un `relatedFieldIds` non vide. Le filtre dur `hasSome` rendait donc les
  // neuf autres invisibles à tout étudiant ayant renseigné un domaine, et le
  // repli ne s'armait qu'à ZÉRO résultat — avec une fiche qui passait, l'écran
  // affichait « 1 bourse trouvée » sans un mot d'explication.
  describe('listForProfile — profile fields rank, they never exclude', () => {
    function makeFilteringService(rows: Array<Record<string, unknown>>) {
      const wheres: Array<Record<string, unknown>> = [];
      const client = {
        scholarship: {
          findMany: async (args: Record<string, unknown>) => {
            const where = args.where as Record<string, unknown>;
            wheres.push(where);
            const fieldFilter = where.relatedFieldIds as
              | { hasSome: string[] }
              | undefined;
            if (!fieldFilter) return rows;
            return rows.filter((row) =>
              (row.relatedFieldIds as string[]).some((id) =>
                fieldFilter.hasSome.includes(id),
              ),
            );
          },
          count: async (args: Record<string, unknown>) => {
            const where = args.where as Record<string, unknown>;
            return where.relatedFieldIds ? 0 : rows.length;
          },
        },
        scholarshipAlertSubscription: { findMany: async () => [] },
      };
      const prisma = {
        isEnabled: true,
        execute: async (fn: (c: typeof client) => unknown) => fn(client),
      } as unknown as PrismaService;
      const service = new ScholarshipsIndexService(
        prisma,
        {} as unknown as GreatYopScraper,
        {} as unknown as MastereTnScraper,
        { assertReady: jest.fn() } as unknown as ScholarshipContentQualityService,
      );
      return { service, wheres };
    }

    it('serves a scholarship whose relatedFieldIds is empty, and queries once', async () => {
      // Tous les chemins d'écriture créent la ligne avec un tableau VIDE : c'est
      // le cas NORMAL, pas le cas limite.
      const { service, wheres } = makeFilteringService([
        { ...baseRow, relatedFieldIds: [] },
      ]);

      const result = await service.listForProfile({
        lang: 'fr',
        fieldIds: ['d01', 'd05'],
      });

      expect(result.items).toHaveLength(1);
      // Plus de premier essai perdu puis de reprise : une seule requête suffit.
      expect(wheres).toHaveLength(1);
      // Rien n'a été restreint, donc il n'y a rien à annoncer au client.
      expect(result.fieldFilterRelaxed).toBe(false);
    });

    it('never puts relatedFieldIds in the query, whatever the profile asks', async () => {
      // La garde structurelle : elle tombe à la seconde où quelqu'un remet un
      // filtre dur, sans dépendre du contenu des fiches de test.
      const { service, wheres } = makeFilteringService([
        { ...baseRow, id: 'a', relatedFieldIds: ['d01'] },
        { ...baseRow, id: 'b', relatedFieldIds: [] },
      ]);

      await service.listForProfile({
        lang: 'fr',
        level: 'Master',
        fieldIds: ['d01', 'd02', 'd03'],
      });

      for (const where of wheres) {
        expect(where.relatedFieldIds).toBeUndefined();
      }
    });

    it('ranks the curated scholarship first without hiding the other nine', async () => {
      // La forme exacte de la production : une fiche curée, neuf vides.
      const rows = [
        { ...baseRow, id: 'curated', relatedFieldIds: ['d02', 'd03'] },
        ...Array.from({ length: 9 }, (_, i) => ({
          ...baseRow,
          id: `uncurated-${i}`,
          relatedFieldIds: [],
        })),
      ];
      const { service } = makeFilteringService(rows);

      const result = await service.listForProfile({
        lang: 'fr',
        fieldIds: ['d02'],
      });

      // Les DIX sont servies — c'est le constat que ce test ferme.
      expect(result.items).toHaveLength(10);
      // Et le recouvrement de domaine se paie en rang, pas en visibilité.
      expect(result.items[0].id).toBe('curated');
      expect(result.items[0].matchScore).toBeGreaterThan(
        result.items[1].matchScore,
      );
    });

    it('keeps a student-chosen funding filter hard', async () => {
      // Le correctif ne doit pas emporter les filtres que l'étudiant VOIT et
      // peut retirer lui-même : ceux-là restent des exclusions.
      const { service, wheres } = makeFilteringService([
        { ...baseRow, relatedFieldIds: [] },
      ]);

      await service.listForProfile({
        lang: 'fr',
        fieldIds: ['d01'],
        fundingType: 'fully_funded',
      });

      expect(wheres).toHaveLength(1);
      expect(wheres[0]).toMatchObject({
        fundingType: 'fully_funded',
        isActive: true,
        moderationStatus: 'approved',
      });
    });

    it('flags an unconfigured database instead of reporting an empty catalog', async () => {
      const prisma = {
        isEnabled: false,
        execute: async () => null,
      } as unknown as PrismaService;
      const service = new ScholarshipsIndexService(
        prisma,
        {} as unknown as GreatYopScraper,
        {} as unknown as MastereTnScraper,
        { assertReady: jest.fn() } as unknown as ScholarshipContentQualityService,
      );

      const result = await service.listForProfile({
        lang: 'fr',
        fieldIds: ['d01'],
      });

      expect(result.items).toEqual([]);
      expect(result.databaseUnavailable).toBe(true);
    });
  });

  // Le bonus de niveau (+30) se compare en niveaux CANONIQUES. L'ancien test
  // cherchait `level` en sous-chaîne dans le seul libellé de la langue
  // demandée : l'app envoie « Bachelor », la fiche française dit « Licence »,
  // et aucun étudiant en Licence n'était jamais classé par niveau en français.
  describe('listForProfile — level boost compares canonical levels', () => {
    const licenceRow = {
      ...baseRow,
      id: 'licence',
      levelEligibleFr: 'Licence de quatre ans à Berekuso',
      levelEligibleEn: 'Four-year Bachelor at Berekuso',
      tags: ['bachelor', 'ghana', 'ashesi'],
      baseMatch: 30,
    };
    const masterRow = {
      ...baseRow,
      id: 'master',
      levelEligibleFr: 'Master d’un an',
      levelEligibleEn: 'One-year Master',
      tags: ['master', 'uk'],
      baseMatch: 30,
    };
    const scoreOf = (
      items: Array<{ id: string; matchScore: number }>,
      id: string,
    ) => items.find((item) => item.id === id)?.matchScore;

    it('cible Bachelor en locale FR : +30 sur une fiche Licence, rien sur un niveau étranger', async () => {
      const { service } = makeService([masterRow, licenceRow]);

      const result = await service.listForProfile({
        lang: 'fr',
        level: 'Bachelor',
      });

      expect(scoreOf(result.items, 'licence')).toBe(60);
      expect(scoreOf(result.items, 'master')).toBe(30);
      expect(result.items.map((item) => item.id)).toEqual([
        'licence',
        'master',
      ]);
    });

    it('scores identically whatever the request language', async () => {
      const { service } = makeService([masterRow, licenceRow]);

      const fr = await service.listForProfile({ lang: 'fr', level: 'Bachelor' });
      const en = await service.listForProfile({ lang: 'en', level: 'Bachelor' });

      expect(fr.items.map((item) => [item.id, item.matchScore])).toEqual(
        en.items.map((item) => [item.id, item.matchScore]),
      );
    });

    it('falls back to BOTH labels when the scholarship has no level tag', async () => {
      // Saisie admin ou seed héritée : pas de tag de niveau, seulement les
      // libellés. Le libellé anglais ne nomme aucun niveau : en locale EN, le
      // bonus ne peut venir que du libellé français.
      const untagged = {
        ...licenceRow,
        id: 'untagged',
        levelEligibleFr: 'Licence',
        levelEligibleEn: 'Four-year degree in Cairo',
        tags: ['legacy-seed'],
      };
      const { service } = makeService([untagged]);

      for (const lang of ['fr', 'en'] as const) {
        const result = await service.listForProfile({ lang, level: 'Bachelor' });
        expect(scoreOf(result.items, 'untagged')).toBe(60);
      }
    });

    it('trusts the level tags over a label that cites an excluded level', async () => {
      const partnerRow = {
        ...baseRow,
        id: 'partner',
        levelEligibleFr:
          'Secondaire, Licence ou Master selon le partenaire — pas de doctorat',
        levelEligibleEn:
          'Secondary, Bachelor or Master depending on the partner — no doctorate',
        tags: ['secondary', 'bachelor', 'master', 'mastercard-foundation'],
        baseMatch: 30,
      };
      const { service } = makeService([partnerRow]);

      const phd = await service.listForProfile({ lang: 'fr', level: 'PhD' });
      const bachelor = await service.listForProfile({
        lang: 'fr',
        level: 'Bachelor',
      });

      expect(scoreOf(phd.items, 'partner')).toBe(30);
      expect(scoreOf(bachelor.items, 'partner')).toBe(60);
    });

    it('matches whole words only in the label fallback', async () => {
      // « Mastercard » contient « master » : en sous-chaîne, une Licence
      // financée par la Mastercard Foundation passait pour un master.
      const { service } = makeService([
        {
          ...baseRow,
          id: 'mcf',
          levelEligibleFr: 'Licence — Mastercard Foundation',
          levelEligibleEn: 'Undergraduate — Mastercard Foundation',
          tags: [],
          baseMatch: 30,
        },
      ]);

      const result = await service.listForProfile({ lang: 'fr', level: 'Master' });

      expect(scoreOf(result.items, 'mcf')).toBe(30);
    });

    it('gives no boost for an unrecognised or blank target level', async () => {
      const { service } = makeService([licenceRow]);

      for (const level of ['', '   ', 'BTS']) {
        const result = await service.listForProfile({ lang: 'fr', level });
        expect(scoreOf(result.items, 'licence')).toBe(30);
      }
    });

    it('leaves the response shape unchanged', async () => {
      const { service } = makeService([licenceRow]);

      const result = await service.listForProfile({
        lang: 'fr',
        level: 'Bachelor',
      });

      expect(Object.keys(result).sort()).toEqual([
        'databaseUnavailable',
        'fieldFilterRelaxed',
        'hasMore',
        'items',
        'limit',
        'offset',
        'total',
      ]);
      expect(Object.keys(result.items[0]).sort()).toEqual([
        'advantages',
        'applicationRequirement',
        'applicationSteps',
        'applicationUrl',
        'countryId',
        'countryName',
        'currentCycle',
        'deadlineAt',
        'deadlineLabel',
        'description',
        'eligibility',
        'featuredVideo',
        'fundingType',
        'id',
        'isAlertEnabled',
        'keyRequirements',
        'lastVerifiedAt',
        'level',
        'matchScore',
        'relatedFieldIds',
        'sourceUrl',
        'tags',
        'title',
        'typeOfFunding',
      ]);
      // `level` reste le libellé localisé affiché par l'app, pas le niveau
      // canonique qui sert au classement.
      expect(result.items[0].level).toBe('Licence de quatre ans à Berekuso');
      expect(result.items[0].tags).toEqual(['bachelor', 'ghana', 'ashesi']);
      expect(typeof result.items[0].matchScore).toBe('number');
    });
  });

  describe('publication safety and detail route', () => {
    it('does not approve a scholarship rejected by the quality gate', async () => {
      const update = jest.fn();
      const quality = {
        assertReady: jest
          .fn()
          .mockRejectedValue(new BadRequestException('not ready')),
      };
      const prisma = {
        isEnabled: true,
        execute: async (fn: (client: unknown) => unknown) =>
          fn({ scholarship: { update } }),
      } as unknown as PrismaService;
      const service = new ScholarshipsIndexService(
        prisma,
        {} as GreatYopScraper,
        {} as MastereTnScraper,
        quality as unknown as ScholarshipContentQualityService,
      );

      await expect(service.setModeration('sch-1', 'approved')).rejects.toThrow(
        'not ready',
      );
      expect(update).not.toHaveBeenCalled();
    });

    it('returns a localized detail with published videos and alert state', async () => {
      const detailRow = {
        ...baseRow,
        typeOfFundingFr: 'Financement complet',
        typeOfFundingEn: 'Fully funded',
        keyRequirementsFr: ['Deux recommandations'],
        keyRequirementsEn: ['Two references'],
        cycles: [
          {
            id: 'cycle-1',
            academicYear: '2026-2027',
            status: 'open',
            dateConfidence: 'confirmed',
            estimatedOpenAt: null,
            estimatedCloseAt: null,
            opensAt: new Date('2026-08-01T00:00:00.000Z'),
            closesAt: new Date('2026-11-01T00:00:00.000Z'),
            sourceUrl: 'https://official.example.org',
            verifiedAt: new Date('2026-07-16T00:00:00.000Z'),
          },
        ],
        videos: [
          {
            id: 'video-1',
            youtubeVideoId: 'dQw4w9WgXcQ',
            titleFr: 'Comment postuler',
            titleEn: 'How to apply',
            descriptionFr: 'Tutoriel',
            descriptionEn: 'Tutorial',
            thumbnailUrl: 'https://img.youtube.com/test.jpg',
            durationSeconds: 180,
            languageCode: 'fr',
            isFeatured: true,
            displayOrder: 0,
          },
        ],
      };
      const client = {
        scholarship: { findFirst: async () => detailRow },
        scholarshipAlertSubscription: {
          findUnique: async () => ({
            pushEnabled: true,
            inAppEnabled: true,
          }),
        },
      };
      const prisma = {
        isEnabled: true,
        execute: async (fn: (value: typeof client) => unknown) => fn(client),
      } as unknown as PrismaService;
      const service = new ScholarshipsIndexService(
        prisma,
        {} as GreatYopScraper,
        {} as MastereTnScraper,
        {} as ScholarshipContentQualityService,
      );

      const result = await service.getForProfile('sch-1', {
        lang: 'fr',
        userId: 'user-1',
      });

      expect(result.videos[0]).toMatchObject({
        title: 'Comment postuler',
        youtubeVideoId: 'dQw4w9WgXcQ',
        shareUrl: 'https://youtu.be/dQw4w9WgXcQ',
      });
      expect(result.currentCycle).toMatchObject({ id: 'cycle-1' });
      expect(result.alert).toEqual({
        subscribed: true,
        pushEnabled: true,
        inAppEnabled: true,
      });
    });
  });
});

describe('ScholarshipsIndexService — refresh never wipes or overwrites curated data', () => {
  const scraped = (sourceKey: string, nameEn = sourceKey) => ({
    sourceKey,
    sourceUrl: `https://example.org/${sourceKey}`,
    applicationUrl: `https://example.org/${sourceKey}/apply`,
    deadlineAt: null,
    nameFr: nameEn,
    nameEn,
    countryId: 'fra',
    countryNameFr: 'France',
    countryNameEn: 'France',
    descriptionFr: 'd',
    descriptionEn: 'd',
    advantagesFr: [],
    advantagesEn: [],
    eligibilityFr: [],
    eligibilityEn: [],
    fundingType: 'unknown',
    levelEligibleFr: '',
    levelEligibleEn: '',
    deadlineLabelFr: '',
    deadlineLabelEn: '',
    tags: [],
    contentScore: 1,
  });

  function makeService(opts: {
    greatYop: () => Promise<unknown[]>;
    mastereTn?: () => Promise<unknown[]>;
    existing?: Record<string, string>;
  }) {
    const upserts: Array<Record<string, any>> = [];
    const updateManyCalls: Array<Record<string, any>> = [];
    const client = {
      scholarship: {
        findUnique: async ({ where }: any) =>
          opts.existing?.[where.sourceKey]
            ? { moderationStatus: opts.existing[where.sourceKey] }
            : null,
        upsert: async (args: any) => {
          upserts.push(args);
          return { id: args.where.sourceKey };
        },
        updateMany: async (args: any) => {
          updateManyCalls.push(args);
          return { count: 0 };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
      tryExecute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const greatYop = {
      prefix: 'greatyop',
      name: 'GreatYop',
      fetch: opts.greatYop,
    } as unknown as GreatYopScraper;
    const mastereTn = {
      prefix: 'masteretn',
      name: 'MastereTn',
      fetch: opts.mastereTn ?? (async () => []),
    } as unknown as MastereTnScraper;
    const service = new ScholarshipsIndexService(
      prisma,
      greatYop,
      mastereTn,
      {} as ScholarshipContentQualityService,
    );
    return { service, upserts, updateManyCalls };
  }

  it('does not deactivate anything for a source that returned zero rows', async () => {
    const { service, updateManyCalls } = makeService({
      greatYop: async () => [],
    });
    await service.refresh();
    expect(updateManyCalls).toHaveLength(0);
  });

  it('does not deactivate anything for a source that threw', async () => {
    const { service, updateManyCalls } = makeService({
      greatYop: async () => {
        throw new Error('503');
      },
    });
    const result = await service.refresh();
    expect(result.sources[0].error).toBe('503');
    expect(updateManyCalls).toHaveLength(0);
  });

  it('never deactivates approved rows, and counts merged-away keys as seen', async () => {
    const { service, updateManyCalls } = makeService({
      greatYop: async () => [scraped('greatyop-a', 'Same Scholarship')],
      mastereTn: async () => [
        { ...scraped('masteretn-b', 'Same Scholarship'), contentScore: 9 },
      ],
    });
    await service.refresh();
    const greatYopCall = updateManyCalls.find(
      (c) => c.where.sourceKey.startsWith === 'greatyop-',
    );
    expect(greatYopCall!.where.moderationStatus).toEqual({ not: 'approved' });
    expect(greatYopCall!.where.NOT.sourceKey.in).toContain('greatyop-a');
  });

  it('leaves an approved row untouched and does not reactivate a rejected one', async () => {
    const { service, upserts } = makeService({
      greatYop: async () => [scraped('greatyop-approved'), scraped('greatyop-rejected')],
      existing: {
        'greatyop-approved': 'approved',
        'greatyop-rejected': 'rejected',
      },
    });
    await service.refresh();
    expect(upserts.map((u) => u.where.sourceKey)).toEqual(['greatyop-rejected']);
    expect(upserts[0].update.isActive).toBeUndefined();
  });

  it('refuses a second refresh while one is running', async () => {
    let release!: () => void;
    let calls = 0;
    const { service } = makeService({
      greatYop: () =>
        calls++ === 0
          ? new Promise<unknown[]>((resolve) => {
              release = () => resolve([]);
            })
          : Promise.resolve([]),
    });
    const first = service.refresh();
    await expect(service.refresh()).rejects.toThrow('already running');
    release();
    await first;
    // Released: a new run is accepted again.
    await expect(service.refresh()).resolves.toBeDefined();
  });
});
