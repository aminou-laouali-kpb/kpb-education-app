// L'ordre et la pagination de `/catalog/programs` (program-snapshot-order.ts) :
// aucun plafond pour les builds récentes, et la première page des builds
// installées réservée aux partenaires, puis aux formations datées.
import { Test } from '@nestjs/testing';
import type { Prisma, PrismaClient } from '@prisma/client';

import { CatalogService } from './catalog.service';
import {
  PROGRAM_PAGE_MAX,
  planProgramPage,
  programSnapshotSegments,
  startOfUtcDay,
  withoutSnapshotSegment,
} from './program-snapshot-order';
import { PrismaService } from '../prisma/prisma.service';

describe('planProgramPage', () => {
  it('lit la fenêtre dans la première tranche quand elle suffit', () => {
    expect(planProgramPage([50, 10, 10], 0, 20)).toEqual([
      { segment: 0, skip: 0, take: 20 },
    ]);
  });

  it('enjambe les tranches, dans l’ordre', () => {
    expect(planProgramPage([5, 3, 10], 0, 10)).toEqual([
      { segment: 0, skip: 0, take: 5 },
      { segment: 1, skip: 0, take: 3 },
      { segment: 2, skip: 0, take: 2 },
    ]);
    expect(planProgramPage([5, 3, 10], 6, 4)).toEqual([
      { segment: 1, skip: 1, take: 2 },
      { segment: 2, skip: 0, take: 2 },
    ]);
  });

  it('saute les tranches vides et ne lit rien au-delà du total', () => {
    expect(planProgramPage([0, 0, 4], 0, 10)).toEqual([
      { segment: 2, skip: 0, take: 4 },
    ]);
    expect(planProgramPage([5, 3, 10], 18, 10)).toEqual([]);
    expect(planProgramPage([5, 3, 10], 0, 0)).toEqual([]);
  });

  it('couvre chaque ligne exactement une fois, quelle que soit la taille de page', () => {
    const counts = [640, 37, 1673];
    const total = counts.reduce((a, b) => a + b, 0);
    for (const pageSize of [1, 7, 400, 1000]) {
      let covered = 0;
      for (let offset = 0; offset < total; offset += pageSize) {
        covered += planProgramPage(counts, offset, pageSize).reduce(
          (sum, slice) => sum + slice.take,
          0,
        );
      }
      expect(covered).toBe(total);
    }
  });
});

describe('programSnapshotSegments', () => {
  const today = new Date('2026-10-17T00:00:00.000Z');

  it('garde la clause de base intacte et ajoute la condition dans AND', () => {
    const base: Prisma.ProgramWhereInput = {
      isActive: true,
      institutionId: 'omnes-ece',
      OR: [{ nameFr: { contains: 'data' } }],
    };
    for (const segment of programSnapshotSegments(base, ['omnes-ece'], today)) {
      expect(segment.isActive).toBe(true);
      expect(segment.institutionId).toBe('omnes-ece');
      expect(segment.OR).toEqual(base.OR);
      expect(withoutSnapshotSegment(segment)).toEqual(base);
    }
    expect(base).not.toHaveProperty('AND');
  });

  it('préserve un AND déjà présent', () => {
    const base: Prisma.ProgramWhereInput = { AND: [{ fieldId: 'd01' }] };
    const [partners] = programSnapshotSegments(base, ['a'], today);
    expect(partners.AND).toEqual([
      { fieldId: 'd01' },
      { institutionId: { in: ['a'] } },
    ]);
    expect(withoutSnapshotSegment(partners)).toEqual(base);
  });

  it('borne « à venir » à minuit UTC', () => {
    expect(startOfUtcDay(new Date('2026-10-17T23:59:59.999Z')).toISOString()).toBe(
      '2026-10-17T00:00:00.000Z',
    );
  });
});

// ── Le service, sur un faux catalogue qui évalue vraiment les tranches ───────

type Row = {
  id: string;
  institutionId: string;
  nameFr: string;
  applicationDeadline: Date | null;
};

/** Évalue les seules formes de clause que `programSnapshotSegments` produit. */
function matches(row: Row, where: Prisma.ProgramWhereInput): boolean {
  const clauses = (where.AND as Prisma.ProgramWhereInput[] | undefined) ?? [];
  return clauses.every((clause) => {
    const inst = clause.institutionId as { in?: string[]; notIn?: string[] } | undefined;
    if (inst?.in && !inst.in.includes(row.institutionId)) return false;
    if (inst?.notIn && inst.notIn.includes(row.institutionId)) return false;
    const deadline = clause.applicationDeadline as { gte?: Date } | undefined;
    if (deadline?.gte) {
      if (!row.applicationDeadline || row.applicationDeadline < deadline.gte) return false;
    }
    if (clause.OR) {
      const bound = (clause.OR as { applicationDeadline: { lt: Date } | null }[])[1]
        .applicationDeadline as { lt: Date };
      if (row.applicationDeadline && row.applicationDeadline >= bound.lt) return false;
    }
    return true;
  });
}

function fakeCatalog(rows: Row[], partnerIds: string[]): PrismaClient {
  const sorted = (list: Row[]) =>
    [...list].sort((a, b) =>
      a.nameFr === b.nameFr ? (a.id < b.id ? -1 : 1) : a.nameFr < b.nameFr ? -1 : 1,
    );
  const client: Record<string, unknown> = {
    institution: {
      findMany: jest.fn(async () => partnerIds.map((id) => ({ id }))),
    },
    program: {
      count: jest.fn(async ({ where }: { where: Prisma.ProgramWhereInput }) =>
        rows.filter((row) => matches(row, where)).length,
      ),
      findMany: jest.fn(
        async ({ where, skip, take }: { where: Prisma.ProgramWhereInput; skip: number; take: number }) =>
          sorted(rows.filter((row) => matches(row, where)))
            .slice(skip, skip + take)
            .map((row) => programRow(row)),
      ),
    },
    $transaction: jest.fn(
      async (fn: (tx: unknown) => Promise<unknown>): Promise<unknown> => fn(client),
    ),
  };
  return client as unknown as PrismaClient;
}

function programRow(row: Row) {
  return {
    ...row,
    countryId: 'fra',
    fieldId: 'd01',
    nameEn: row.nameFr,
    levelFr: 'Master',
    levelEn: 'Master',
    durationFr: '2 ans',
    durationEn: '2 years',
    tuitionFr: '—',
    tuitionEn: '—',
    languageFr: 'Français',
    languageEn: 'French',
    requirementsFr: [],
    requirementsEn: [],
    campusOfferings: null,
    recognitionFr: null,
    recognitionEn: null,
    minGpaRequired: null,
    tuitionMinEur: null,
    teachingLanguages: [],
    lastVerifiedAt: null,
    sourceUrl: null,
    verifiedById: null,
    verifiedByName: null,
  };
}

describe('CatalogService.getPrograms — pagination sans plafond', () => {
  let service: CatalogService;
  const prismaService = { isEnabled: true, execute: jest.fn() };

  // 2 350 formations : 640 partenaires, 37 non partenaires datées à venir,
  // 20 datées passées, le reste sans date. Les noms des partenaires commencent
  // par « Z » : par ordre alphabétique seul, ils auraient tous été perdus par
  // les builds installées.
  const future = new Date(Date.UTC(2099, 0, 15));
  const past = new Date(Date.UTC(2020, 0, 15));
  const rows: Row[] = [];
  for (let i = 0; i < 640; i++) {
    rows.push({ id: `p${i}`, institutionId: `partner-${i % 7}`, nameFr: `Z partenaire ${String(i).padStart(4, '0')}`, applicationDeadline: null });
  }
  for (let i = 0; i < 37; i++) {
    rows.push({ id: `d${i}`, institutionId: 'mcgill', nameFr: `Y daté ${String(i).padStart(4, '0')}`, applicationDeadline: future });
  }
  for (let i = 0; i < 20; i++) {
    rows.push({ id: `o${i}`, institutionId: 'mcgill', nameFr: `A passé ${String(i).padStart(4, '0')}`, applicationDeadline: past });
  }
  for (let i = 0; i < 1653; i++) {
    rows.push({ id: `n${i}`, institutionId: `uni-${i % 40}`, nameFr: `A autre ${String(i).padStart(4, '0')}`, applicationDeadline: null });
  }
  const partnerIds = Array.from({ length: 7 }, (_, i) => `partner-${i}`);

  beforeEach(async () => {
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakeCatalog(rows, partnerIds)),
    );
    const moduleRef = await Test.createTestingModule({
      providers: [CatalogService, { provide: PrismaService, useValue: prismaService }],
    }).compile();
    service = moduleRef.get(CatalogService);
  });

  it('une build récente récupère TOUT en suivant nextOffset, sans doublon', async () => {
    const seen = new Set<string>();
    let offset: number | null = 0;
    let pages = 0;
    while (offset !== null) {
      const page = await service.getPrograms({ limit: 500, offset });
      for (const item of page.items as { id: string }[]) seen.add(item.id);
      expect(page.total).toBe(2350);
      offset = page.nextOffset;
      pages++;
    }
    expect(pages).toBe(5);
    expect(seen.size).toBe(2350);
  });

  it('le serveur ne tronque plus le catalogue, seulement la page', async () => {
    const page = await service.getPrograms({ limit: 5000 });
    expect(page.limit).toBe(PROGRAM_PAGE_MAX);
    expect(page.items).toHaveLength(1000);
    expect(page.total).toBe(2350);
    expect(page.nextOffset).toBe(1000);
  });

  it('une build installée (limit=1000, sans offset) garde partenaires puis datées', async () => {
    const page = await service.getPrograms({ limit: 1000 });
    const ids = (page.items as { id: string }[]).map((item) => item.id);
    expect(ids.slice(0, 640).every((id) => id.startsWith('p'))).toBe(true);
    expect(ids.slice(640, 677).every((id) => id.startsWith('d'))).toBe(true);
    // Puis le reste, par nom : les « A … » passés et sans date se mêlent.
    expect(ids).toHaveLength(1000);
    expect(new Set(ids).size).toBe(1000);
    expect(page.nextOffset).toBe(1000);
  });

  it('la vue compact retire les doublons à plat, pas les objets localisés', async () => {
    const full = (await service.getPrograms({ limit: 1 })).items[0] as Record<string, unknown>;
    const compact = (await service.getPrograms({ limit: 1, view: 'compact' }))
      .items[0] as Record<string, unknown>;
    expect(full).toHaveProperty('nameFr');
    expect(compact).not.toHaveProperty('nameFr');
    expect(compact).not.toHaveProperty('requirementsEn');
    expect(compact.name).toEqual(full.name);
    expect(compact.requirements).toEqual(full.requirements);
    expect(compact.id).toBe(full.id);
  });

  it('la dernière page rend nextOffset null', async () => {
    const page = await service.getPrograms({ limit: 1000, offset: 2000 });
    expect(page.items).toHaveLength(350);
    expect(page.nextOffset).toBeNull();
    const beyond = await service.getPrograms({ limit: 1000, offset: 5000 });
    expect(beyond.items).toHaveLength(0);
    expect(beyond.nextOffset).toBeNull();
  });
});
