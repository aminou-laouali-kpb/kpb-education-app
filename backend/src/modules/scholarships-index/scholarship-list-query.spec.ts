import { BadRequestException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';
import {
  parseScholarshipListQuery,
  parseScholarshipListSort,
  parseScholarshipListStatuses,
  scholarshipServedStatus,
  ScholarshipStatusFacts,
} from './scholarship-list-query';
import { ScholarshipsIndexService } from './scholarships-index.service';
import { GreatYopScraper } from './scrapers/greatyop.scraper';
import { MastereTnScraper } from './scrapers/mastereTn.scraper';

/**
 * `GET /scholarships` — paramètres OPTIONNELS `q`, `status`, `sort` (chantier I).
 *
 * Deux promesses tenues ici :
 *  · rétrocompatibilité — sans ces paramètres, la réponse est celle d'avant
 *    (même ordre, même total) : les builds en store ne les envoient pas ;
 *  · honnêteté — une valeur inconnue est un 400, jamais un filtre ignoré en
 *    silence sous un libellé « Ouvertes ».
 */
const NOW = new Date('2026-10-15T12:00:00.000Z');
const iso = (days: number) =>
  new Date(NOW.getTime() + days * 24 * 3600 * 1000).toISOString();

function cycle(
  overrides: Partial<NonNullable<ScholarshipStatusFacts['currentCycle']>>,
): NonNullable<ScholarshipStatusFacts['currentCycle']> {
  return {
    status: 'forecast',
    dateConfidence: 'estimated',
    opensAt: null,
    closesAt: null,
    estimatedOpenAt: null,
    estimatedCloseAt: null,
    ...overrides,
  };
}

describe('scholarship list query — parsing', () => {
  it('treats absent or blank values as "no parameter"', () => {
    expect(parseScholarshipListQuery(undefined)).toBeUndefined();
    expect(parseScholarshipListQuery('   ')).toBeUndefined();
    expect(parseScholarshipListStatuses(undefined)).toBeUndefined();
    expect(parseScholarshipListStatuses(' , ')).toBeUndefined();
    expect(parseScholarshipListSort(undefined)).toBe('relevance');
    expect(parseScholarshipListSort('')).toBe('relevance');
  });

  it('collapses whitespace in q and bounds its length', () => {
    expect(parseScholarshipListQuery('  bourse   eiffel ')).toBe('bourse eiffel');
    expect(parseScholarshipListQuery('x'.repeat(100))).toHaveLength(100);
    expect(() => parseScholarshipListQuery('x'.repeat(101))).toThrow(
      BadRequestException,
    );
  });

  it('rejects a repeated query parameter (array) instead of guessing', () => {
    const asArray = ['a', 'b'] as unknown as string;
    expect(() => parseScholarshipListQuery(asArray)).toThrow(BadRequestException);
    expect(() => parseScholarshipListStatuses(asArray)).toThrow(
      BadRequestException,
    );
    expect(() => parseScholarshipListSort(asArray)).toThrow(BadRequestException);
  });

  it('accepts comma-separated statuses, deduplicated', () => {
    expect(parseScholarshipListStatuses('open,upcoming,open')).toEqual([
      'open',
      'upcoming',
    ]);
  });

  it('refuses an unknown status or sort (400), never ignores it', () => {
    expect(() => parseScholarshipListStatuses('open,closed')).toThrow(
      BadRequestException,
    );
    expect(() => parseScholarshipListSort('popularity')).toThrow(
      BadRequestException,
    );
  });
});

describe('scholarshipServedStatus — same rule as the app status line', () => {
  const at = (facts: Partial<ScholarshipStatusFacts>) =>
    scholarshipServedStatus(
      { deadlineAt: null, currentCycle: null, ...facts },
      NOW,
    );

  it('open cycle, already opened → open', () => {
    expect(
      at({
        currentCycle: cycle({
          status: 'open',
          dateConfidence: 'confirmed',
          opensAt: iso(-3),
          closesAt: iso(40),
        }),
      }),
    ).toBe('open');
  });

  it('open cycle whose confirmed opening is still ahead → upcoming', () => {
    expect(
      at({
        currentCycle: cycle({
          status: 'open',
          dateConfidence: 'confirmed',
          opensAt: iso(5),
        }),
      }),
    ).toBe('upcoming');
  });

  it('confirmed forecast opening ahead → upcoming; estimated → forecast', () => {
    expect(
      at({
        currentCycle: cycle({ dateConfidence: 'confirmed', opensAt: iso(30) }),
      }),
    ).toBe('upcoming');
    expect(
      at({
        currentCycle: cycle({ estimatedOpenAt: iso(90), opensAt: iso(90) }),
      }),
    ).toBe('forecast');
  });

  it('a confirmed closing in the past → closed, an estimated one does not', () => {
    expect(
      at({
        currentCycle: cycle({
          status: 'open',
          dateConfidence: 'confirmed',
          closesAt: iso(-1),
        }),
      }),
    ).toBe('closed');
    expect(
      at({
        deadlineAt: iso(-1),
        currentCycle: cycle({ estimatedCloseAt: iso(-1) }),
      }),
    ).toBe('forecast');
  });

  it('no cycle: a deadline reads open, nothing at all reads forecast', () => {
    expect(at({ deadlineAt: iso(10) })).toBe('open');
    expect(at({})).toBe('forecast');
  });
});

describe('ScholarshipsIndexService.listForProfile — q, status, sort', () => {
  const baseRow = {
    nameFr: 'Bourse',
    nameEn: 'Scholarship',
    countryId: 'fra',
    countryNameFr: 'France',
    countryNameEn: 'France',
    levelEligibleFr: 'Master',
    levelEligibleEn: 'Master',
    typeOfFundingFr: '',
    typeOfFundingEn: '',
    fundingType: 'fully_funded',
    applicationRequirement: 'separate_application',
    descriptionFr: '',
    descriptionEn: '',
    advantagesFr: [],
    advantagesEn: [],
    eligibilityFr: [],
    eligibilityEn: [],
    keyRequirementsFr: [],
    keyRequirementsEn: [],
    deadlineLabelFr: '',
    deadlineLabelEn: '',
    deadlineAt: null as Date | null,
    applicationUrl: 'https://example.org',
    sourceUrl: null,
    lastVerifiedAt: new Date('2026-09-01T00:00:00.000Z') as Date | null,
    tags: [],
    relatedFieldIds: [],
    eligibleLevels: [],
    baseMatch: 30,
    applicationSteps: [],
    videos: [],
    cycles: [] as Array<Record<string, unknown>>,
  };

  function dbCycle(overrides: Record<string, unknown>) {
    return {
      id: 'cycle',
      academicYear: '2027-2028',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: null,
      estimatedCloseAt: null,
      opensAt: null,
      closesAt: null,
      sourceUrl: null,
      verifiedAt: null,
      ...overrides,
    };
  }

  const day = (days: number) => new Date(Date.now() + days * 24 * 3600 * 1000);

  // Ouverte, clôture dans 40 j, vérifiée en septembre, la plus pertinente.
  const openRow = {
    ...baseRow,
    id: 'open',
    nameFr: 'Zeta ouverte',
    baseMatch: 50,
    cycles: [
      dbCycle({
        status: 'open',
        dateConfidence: 'confirmed',
        opensAt: day(-5),
        closesAt: day(40),
      }),
    ],
  };
  // Ouverture confirmée à venir, clôture dans 20 j après.
  const upcomingRow = {
    ...baseRow,
    id: 'upcoming',
    nameFr: 'alpha à venir',
    baseMatch: 40,
    lastVerifiedAt: new Date('2026-10-10T00:00:00.000Z'),
    cycles: [
      dbCycle({
        dateConfidence: 'confirmed',
        opensAt: day(5),
        closesAt: day(20),
      }),
    ],
  };
  // Estimée, pas de clôture connue.
  const forecastRow = {
    ...baseRow,
    id: 'forecast',
    nameFr: 'Éclair estimée',
    baseMatch: 30,
    lastVerifiedAt: new Date('2026-08-01T00:00:00.000Z'),
    cycles: [dbCycle({ estimatedOpenAt: day(120) })],
  };

  function makeService(rows: Array<Record<string, unknown>>, count = 3) {
    const wheres: Array<Record<string, unknown>> = [];
    const client = {
      scholarship: {
        findMany: async (args: Record<string, unknown>) => {
          wheres.push(args.where as Record<string, unknown>);
          return rows;
        },
        count: async () => count,
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

  const rows = [forecastRow, upcomingRow, openRow];

  it('without the new parameters: relevance order, DB total, query echoed', async () => {
    const { service, wheres } = makeService(rows, 42);
    const result = await service.listForProfile({ lang: 'fr' });

    expect(result.items.map((item) => item.id)).toEqual([
      'open',
      'upcoming',
      'forecast',
    ]);
    // Le total est celui de la base (indépendant du plafond de candidates).
    expect(result.total).toBe(42);
    expect(result.query).toEqual({ q: null, status: null, sort: 'relevance' });
    // Aucun `AND` de recherche n'est ajouté sans `q`.
    expect(wheres[0].AND).toBeUndefined();
  });

  it('q searches names and country names, without dropping the deadline OR', async () => {
    const { service, wheres } = makeService(rows);
    await service.listForProfile({ lang: 'fr', q: '  eiffel ' });

    const where = wheres[0];
    // La clause publique est intacte…
    expect(where).toMatchObject({
      isActive: true,
      moderationStatus: 'approved',
      lastVerifiedAt: { not: null },
    });
    expect(where.OR).toEqual(
      expect.arrayContaining([{ deadlineAt: null }]),
    );
    // … et la recherche passe par `AND`.
    expect(where.AND).toEqual([
      {
        OR: [
          { nameFr: { contains: 'eiffel', mode: 'insensitive' } },
          { nameEn: { contains: 'eiffel', mode: 'insensitive' } },
          { countryNameFr: { contains: 'eiffel', mode: 'insensitive' } },
          { countryNameEn: { contains: 'eiffel', mode: 'insensitive' } },
        ],
      },
    ]);
  });

  it('status filters on the served cycle, and total counts the filtered list', async () => {
    const { service } = makeService(rows, 3);

    const open = await service.listForProfile({ lang: 'fr', status: 'open' });
    expect(open.items.map((item) => item.id)).toEqual(['open']);
    expect(open.total).toBe(1);
    expect(open.hasMore).toBe(false);

    const ahead = await service.listForProfile({
      lang: 'fr',
      status: 'upcoming,forecast',
    });
    expect(ahead.items.map((item) => item.id)).toEqual([
      'upcoming',
      'forecast',
    ]);
    expect(ahead.total).toBe(2);
    expect(ahead.query.status).toEqual(['upcoming', 'forecast']);
  });

  it('paginates the filtered list (hasMore, total)', async () => {
    const { service } = makeService(rows, 3);
    const first = await service.listForProfile({
      lang: 'fr',
      status: 'open,upcoming,forecast',
      limit: 2,
    });
    expect(first.items).toHaveLength(2);
    expect(first.total).toBe(3);
    expect(first.hasMore).toBe(true);
  });

  it('sort=deadline: nearest closing first, unknown closing last', async () => {
    const { service } = makeService(rows);
    const result = await service.listForProfile({ lang: 'fr', sort: 'deadline' });
    expect(result.items.map((item) => item.id)).toEqual([
      'upcoming',
      'open',
      'forecast',
    ]);
  });

  it('sort=verified: most recently verified first', async () => {
    const { service } = makeService(rows);
    const result = await service.listForProfile({ lang: 'fr', sort: 'verified' });
    expect(result.items.map((item) => item.id)).toEqual([
      'upcoming',
      'open',
      'forecast',
    ]);
  });

  it('sort=title: A-Z in the request language, accents and case folded', async () => {
    const { service } = makeService(rows);
    const result = await service.listForProfile({ lang: 'fr', sort: 'title' });
    expect(result.items.map((item) => item.title)).toEqual([
      'alpha à venir',
      'Éclair estimée',
      'Zeta ouverte',
    ]);
  });

  it('refuses unknown values before reading the database', async () => {
    const { service, wheres } = makeService(rows);
    await expect(
      service.listForProfile({ lang: 'fr', status: 'expired' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.listForProfile({ lang: 'fr', sort: 'random' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.listForProfile({ lang: 'fr', q: 'x'.repeat(101) }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(wheres).toHaveLength(0);
  });
});
