import { ServiceUnavailableException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { FollowedScholarshipsController } from './followed-scholarships.controller';
import {
  compareFollowedItems,
  followedDisplayStatus,
  FollowedScholarshipsService,
  type FollowedCycle,
} from './followed-scholarships.service';
import {
  followedScholarshipIdsSql,
  type FollowedScholarshipRow,
} from './opening/scholarship-follow.query';
import type { FollowedScholarshipItem } from './opening/scholarship-opening.contract';

const NOW = new Date('2026-10-15T12:00:00.000Z');
const d = (iso: string) => new Date(iso);

interface FakeScholarship {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
  deadlineAt: Date | null;
  isActive: boolean;
  moderationStatus: string;
  lastVerifiedAt: Date | null;
  cycles: FollowedCycle[];
}

type Where = Record<string, unknown>;

/** Les opérateurs Prisma que le service emploie : égalité, `in`, `not`, `gte`, `OR`. */
function matches(row: FakeScholarship, where: Where): boolean {
  return Object.entries(where).every(([key, expected]) => {
    if (key === 'OR') {
      return (expected as Where[]).some((branch) => matches(row, branch));
    }
    const value = (row as unknown as Record<string, unknown>)[key];
    if (expected !== null && typeof expected === 'object' && !(expected instanceof Date)) {
      const op = expected as { in?: unknown[]; not?: unknown; gte?: Date };
      if (op.in) return op.in.includes(value);
      if ('not' in op) return value !== op.not;
      if (op.gte) return value instanceof Date && value.getTime() >= op.gte.getTime();
      return false;
    }
    return value === expected;
  });
}

function scholarship(
  id: string,
  overrides: Partial<FakeScholarship> = {},
): FakeScholarship {
  return {
    id,
    nameFr: `Bourse ${id}`,
    nameEn: `Scholarship ${id}`,
    countryId: 'gbr',
    countryNameFr: 'Royaume-Uni',
    countryNameEn: 'United Kingdom',
    deadlineAt: null,
    isActive: true,
    moderationStatus: 'approved',
    lastVerifiedAt: d('2026-09-01T00:00:00.000Z'),
    cycles: [],
    ...overrides,
  };
}

function cycle(overrides: Partial<FollowedCycle>): FollowedCycle {
  return {
    academicYear: '2026-2027',
    status: 'open',
    dateConfidence: 'confirmed',
    opensAt: null,
    closesAt: null,
    estimatedOpenAt: null,
    estimatedCloseAt: null,
    ...overrides,
  };
}

function pair(
  scholarshipId: string,
  flags: Partial<Omit<FollowedScholarshipRow, 'scholarshipId'>> = {},
): FollowedScholarshipRow {
  return { scholarshipId, viaFavorite: true, viaAlert: false, muted: false, ...flags };
}

function make(opts: {
  pairs: FollowedScholarshipRow[];
  scholarships: FakeScholarship[];
  disabledNotificationTypes?: string[];
}) {
  const rawQueries: Prisma.Sql[] = [];
  const findManyWheres: Where[] = [];
  const client = {
    $queryRaw: async (sql: Prisma.Sql) => {
      rawQueries.push(sql);
      return opts.pairs;
    },
    scholarship: {
      findMany: async (args: {
        where: Where;
        select: Record<string, unknown>;
      }) => {
        findManyWheres.push(args.where);
        const cyclesSelect = args.select.cycles as
          | { orderBy?: { academicYear?: 'asc' | 'desc' } }
          | undefined;
        return opts.scholarships
          .filter((row) => matches(row, args.where))
          .map((row) => ({
            ...row,
            cycles:
              cyclesSelect?.orderBy?.academicYear === 'desc'
                ? [...row.cycles].sort((a, b) =>
                    b.academicYear.localeCompare(a.academicYear),
                  )
                : row.cycles,
          }));
      },
    },
    userProfile: {
      findUnique: async () => ({
        disabledNotificationTypes: opts.disabledNotificationTypes ?? [],
      }),
    },
  };
  const prisma = {
    isEnabled: true,
    execute: async <T>(fn: (c: typeof client) => Promise<T>) => fn(client),
  } as unknown as PrismaService;
  return {
    service: new FollowedScholarshipsService(prisma),
    rawQueries,
    findManyWheres,
  };
}

describe('followedDisplayStatus', () => {
  it.each([
    ['ouvert, ouverture passée', cycle({ opensAt: d('2026-09-01T00:00:00Z'), closesAt: d('2026-11-30T23:59:59.999Z') }), null, 'open'],
    ['ouvert sans date d’ouverture', cycle({ closesAt: d('2026-11-30T23:59:59.999Z') }), null, 'open'],
    ['ouvert, ouverture confirmée à venir', cycle({ opensAt: d('2026-11-01T00:00:00Z'), closesAt: d('2026-12-15T23:59:59.999Z') }), null, 'opening_confirmed'],
    ['ouvert mais clôture passée (statut servi)', cycle({ closesAt: d('2026-10-01T23:59:59.999Z') }), null, 'closed'],
    ['ouvert, clôture estimée passée', cycle({ estimatedCloseAt: d('2026-10-01T00:00:00Z') }), null, 'closed'],
    ['prévision', cycle({ status: 'forecast', estimatedOpenAt: d('2027-01-01T00:00:00Z') }), null, 'forecast'],
    ['close', cycle({ status: 'closed' }), null, 'closed'],
    ['suspendue', cycle({ status: 'suspended' }), null, 'closed'],
    ['sans cycle, date limite à venir', undefined, d('2026-12-01T00:00:00Z'), 'open'],
    ['sans cycle ni date', undefined, null, 'open'],
    ['sans cycle, date limite passée', undefined, d('2026-10-01T00:00:00Z'), 'closed'],
  ] as const)('%s → %s', (_label, current, deadlineAt, expected) => {
    expect(followedDisplayStatus(current, deadlineAt, NOW)).toBe(expected);
  });
});

describe('FollowedScholarshipsService.list', () => {
  it('lit les couples suivis par la requête partagée, pour CET étudiant', async () => {
    const { service, rawQueries } = make({ pairs: [], scholarships: [] });

    await service.list('stu-1', 'fr', NOW);

    const expected = followedScholarshipIdsSql('stu-1');
    expect(rawQueries).toHaveLength(1);
    expect(rawQueries[0].sql).toBe(expected.sql);
    expect(rawQueries[0].values).toEqual(expected.values);
  });

  it('ne suit rien : liste vide, aucune lecture de bourse', async () => {
    const { service, findManyWheres } = make({ pairs: [], scholarships: [] });

    await expect(service.list('stu-1', 'fr', NOW)).resolves.toEqual({
      items: [],
      total: 0,
      globalOptOut: false,
    });
    expect(findManyWheres).toEqual([]);
  });

  it('garde les bourses closes, écarte les fiches non approuvées, inactives, jamais vérifiées ou supprimées', async () => {
    const { service } = make({
      pairs: [
        pair('closed-one'),
        pair('pending-one'),
        pair('inactive-one'),
        pair('unverified-one'),
        pair('deleted-one'),
      ],
      scholarships: [
        scholarship('closed-one', {
          deadlineAt: d('2026-03-01T00:00:00Z'),
          cycles: [cycle({ academicYear: '2025-2026', closesAt: d('2026-03-01T23:59:59.999Z') })],
        }),
        scholarship('pending-one', { moderationStatus: 'pending' }),
        scholarship('inactive-one', { isActive: false }),
        scholarship('unverified-one', { lastVerifiedAt: null }),
      ],
    });

    const result = await service.list('stu-1', 'fr', NOW);

    expect(result.total).toBe(1);
    expect(result.items).toEqual([
      expect.objectContaining({
        id: 'closed-one',
        displayStatus: 'closed',
        // La fiche répondrait 404 (date limite passée) : l'app ne doit pas y mener.
        detailAvailable: false,
      }),
    ]);
  });

  it('choisit le cycle courant, pas l’année la plus récente', async () => {
    const { service } = make({
      pairs: [pair('chevening')],
      scholarships: [
        scholarship('chevening', {
          deadlineAt: d('2026-11-05T23:59:59.999Z'),
          // Volontairement dans l'ordre croissant : le service demande l'ordre.
          cycles: [
            cycle({
              academicYear: '2026-2027',
              opensAt: d('2026-08-01T00:00:00Z'),
              closesAt: d('2026-11-05T23:59:59.999Z'),
            }),
            cycle({
              academicYear: '2027-2028',
              status: 'forecast',
              dateConfidence: 'estimated',
              estimatedOpenAt: d('2027-08-01T00:00:00Z'),
              estimatedCloseAt: d('2027-11-05T00:00:00Z'),
            }),
          ],
        }),
      ],
    });

    const [item] = (await service.list('stu-1', 'fr', NOW)).items;

    expect(item).toEqual({
      id: 'chevening',
      title: 'Bourse chevening',
      countryId: 'gbr',
      countryName: 'Royaume-Uni',
      displayStatus: 'open',
      academicYear: '2026-2027',
      opensAt: '2026-08-01T00:00:00.000Z',
      closesAt: '2026-11-05T23:59:59.999Z',
      estimatedOpenAt: null,
      estimatedCloseAt: null,
      deadlineAt: '2026-11-05T23:59:59.999Z',
      dateConfidence: 'confirmed',
      viaFavorite: true,
      viaAlert: false,
      notifyOpening: true,
      detailAvailable: true,
    });
  });

  it('trie : ouvertes par clôture proche, ouverture confirmée, prévisions, closes', async () => {
    const { service } = make({
      pairs: ['late', 'soon', 'confirmed', 'forecast', 'closed', 'legacy'].map((id) => pair(id)),
      scholarships: [
        scholarship('closed', {
          cycles: [cycle({ closesAt: d('2026-09-30T23:59:59.999Z') })],
        }),
        scholarship('forecast', {
          cycles: [cycle({ status: 'forecast', estimatedOpenAt: d('2027-01-01T00:00:00Z') })],
        }),
        scholarship('confirmed', {
          cycles: [cycle({ opensAt: d('2026-11-01T00:00:00Z'), closesAt: d('2026-12-01T23:59:59.999Z') })],
        }),
        scholarship('late', {
          cycles: [cycle({ closesAt: d('2026-12-31T23:59:59.999Z') })],
        }),
        scholarship('soon', {
          cycles: [cycle({ closesAt: d('2026-10-20T23:59:59.999Z') })],
        }),
        // Fiche héritée sans cycle ni date : ouverte, après celles qui ont une date.
        scholarship('legacy'),
      ],
    });

    const result = await service.list('stu-1', 'fr', NOW);

    expect(result.items.map((item) => [item.id, item.displayStatus])).toEqual([
      ['soon', 'open'],
      ['late', 'open'],
      ['legacy', 'open'],
      ['confirmed', 'opening_confirmed'],
      ['forecast', 'forecast'],
      ['closed', 'closed'],
    ]);
  });

  it('dit comment la bourse est suivie, et si l’annonce d’ouverture est coupée', async () => {
    const { service } = make({
      pairs: [
        pair('fav-muted', { viaFavorite: true, muted: true }),
        pair('alert-only', { viaFavorite: false, viaAlert: true }),
        pair('both', { viaFavorite: true, viaAlert: true }),
      ],
      scholarships: [scholarship('fav-muted'), scholarship('alert-only'), scholarship('both')],
      disabledNotificationTypes: ['followed_scholarship_updates'],
    });

    const result = await service.list('stu-1', 'fr', NOW);
    const flags = Object.fromEntries(
      result.items.map((item) => [
        item.id,
        [item.viaFavorite, item.viaAlert, item.notifyOpening],
      ]),
    );

    expect(flags).toEqual({
      'fav-muted': [true, false, false],
      'alert-only': [false, true, true],
      both: [true, true, true],
    });
    expect(result.globalOptOut).toBe(true);
  });

  it('localise en anglais', async () => {
    const { service } = make({
      pairs: [pair('chevening')],
      scholarships: [scholarship('chevening')],
    });

    const [item] = (await service.list('stu-1', 'en', NOW)).items;

    expect(item.title).toBe('Scholarship chevening');
    expect(item.countryName).toBe('United Kingdom');
  });

  it('plafonne à 200 lignes, `total` compte tout', async () => {
    const ids = Array.from({ length: 205 }, (_, i) => `s${String(i).padStart(3, '0')}`);
    const { service } = make({
      pairs: ids.map((id) => pair(id)),
      scholarships: ids.map((id) => scholarship(id)),
    });

    const result = await service.list('stu-1', 'fr', NOW);

    expect(result.items).toHaveLength(200);
    expect(result.total).toBe(205);
  });

  it('503 sans base configurée', async () => {
    const service = new FollowedScholarshipsService({
      isEnabled: false,
    } as unknown as PrismaService);
    await expect(service.list('stu-1', 'fr', NOW)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});

describe('compareFollowedItems', () => {
  const base: FollowedScholarshipItem = {
    id: 'a',
    title: 'A',
    countryId: 'gbr',
    countryName: 'Royaume-Uni',
    displayStatus: 'closed',
    academicYear: null,
    opensAt: null,
    closesAt: null,
    estimatedOpenAt: null,
    estimatedCloseAt: null,
    deadlineAt: null,
    dateConfidence: null,
    viaFavorite: true,
    viaAlert: false,
    notifyOpening: true,
    detailAvailable: false,
  };

  it('les closes les plus récentes d’abord, puis par titre', () => {
    const items = [
      { ...base, id: 'old', title: 'Old', closesAt: '2025-03-01T00:00:00.000Z' },
      { ...base, id: 'none', title: 'None' },
      { ...base, id: 'recent', title: 'Recent', closesAt: '2026-09-01T00:00:00.000Z' },
      { ...base, id: 'none-b', title: 'Alpha' },
    ];
    expect(items.sort(compareFollowedItems).map((item) => item.id)).toEqual([
      'recent',
      'old',
      'none-b',
      'none',
    ]);
  });
});

describe('FollowedScholarshipsController', () => {
  it.each([
    ['en', 'en'],
    ['fr', 'fr'],
    ['de', 'fr'],
    [undefined, 'fr'],
  ] as const)('lang=%s → %s, pour l’étudiant connecté', async (lang, expected) => {
    const service = {
      list: jest.fn(async () => ({ items: [], total: 0, globalOptOut: false })),
    } as unknown as FollowedScholarshipsService;
    const controller = new FollowedScholarshipsController(service);

    await controller.list({ studentUser: { id: 'stu-7' } }, lang);

    expect(service.list).toHaveBeenCalledWith('stu-7', expected);
  });
});
