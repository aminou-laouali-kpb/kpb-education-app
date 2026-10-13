// Les contrôles de cohérence de `npm run verify:catalog` (voir
// `catalog-consistency-checks.ts`). Tout est joué sur des agrégats en mémoire,
// sauf le dernier bloc, qui compare la clause des contrôles à celle que
// `CatalogService` envoie réellement à Prisma.
import { Test } from '@nestjs/testing';
import type { PrismaClient } from '@prisma/client';

import { CatalogService } from './catalog.service';
import {
  INSTALLED_APP_PROGRAM_SNAPSHOT_LIMIT,
  MAX_DETAIL_LINES,
  evaluateCatalogConsistency,
  findOrphanProgramFieldIds,
  findPartnersWithoutPrograms,
  findProgramSnapshotOverflow,
  parseVerifyCatalogArgs,
  publicCatalogProgramWhere,
  publicPartnerInstitutionWhere,
  renderCatalogConsistencyReport,
  type CatalogConsistencyInput,
} from './catalog-consistency-checks';
import { PrismaService } from '../prisma/prisma.service';

/** Un catalogue sain : chaque contrôle passe. Les tests en dégradent une partie. */
function healthyInput(over: Partial<CatalogConsistencyInput> = {}): CatalogConsistencyInput {
  return {
    fieldIds: ['d01', 'd02'],
    programsByField: [
      { fieldId: 'd01', isActive: true, count: 3 },
      { fieldId: 'd02', isActive: false, count: 1 },
    ],
    partnerInstitutions: [{ id: 'icn', nameFr: 'ICN Business School' }],
    publicProgramsByInstitution: [{ institutionId: 'icn', count: 3 }],
    publicProgramCount: 3,
    ...over,
  };
}

describe('parseVerifyCatalogArgs', () => {
  it('reste non strict sans argument — c’est l’appel du déploiement', () => {
    expect(parseVerifyCatalogArgs([])).toEqual({ strict: false });
  });

  it('passe en strict avec --strict — c’est l’appel de la CI', () => {
    expect(parseVerifyCatalogArgs(['--strict'])).toEqual({ strict: true });
  });

  it('refuse un argument inconnu au lieu de retomber en mode non bloquant', () => {
    expect(() => parseVerifyCatalogArgs(['--strcit'])).toThrow(/unknown argument "--strcit"/);
    expect(() => parseVerifyCatalogArgs(['--strict', 'oui'])).toThrow(/unknown argument "oui"/);
  });
});

describe('findOrphanProgramFieldIds', () => {
  it('ne signale rien quand chaque fieldId existe', () => {
    expect(
      findOrphanProgramFieldIds(['d01'], [{ fieldId: 'd01', isActive: true, count: 5 }]),
    ).toEqual([]);
  });

  it('compte toutes les formations orphelines, publiées ou en attente', () => {
    expect(
      findOrphanProgramFieldIds(
        new Set(['d01']),
        [
          { fieldId: 'd01', isActive: true, count: 5 },
          { fieldId: 'droit', isActive: true, count: 2 },
          { fieldId: 'droit', isActive: false, count: 7 },
          { fieldId: '', isActive: false, count: 1 },
        ],
      ),
    ).toEqual([
      // Une chaîne vide n'est pas un domaine : elle est signalée comme les autres.
      { fieldId: '', programs: 1, activePrograms: 0 },
      { fieldId: 'droit', programs: 9, activePrograms: 2 },
    ]);
  });

  it('signale tout quand la table Field est vide', () => {
    expect(
      findOrphanProgramFieldIds([], [{ fieldId: 'd01', isActive: true, count: 1 }]),
    ).toEqual([{ fieldId: 'd01', programs: 1, activePrograms: 1 }]);
  });
});

describe('findPartnersWithoutPrograms', () => {
  const partners = [
    { id: 'omnes', nameFr: 'OMNES Education' },
    { id: 'icn', nameFr: 'ICN Business School' },
    { id: 'mundia', nameFr: 'Mundiapolis' },
  ];

  it('ne signale rien quand chaque partenaire a une formation publique', () => {
    expect(
      findPartnersWithoutPrograms(partners, [
        { institutionId: 'omnes', count: 40 },
        { institutionId: 'icn', count: 1 },
        { institutionId: 'mundia', count: 12 },
      ]),
    ).toEqual([]);
  });

  it('signale les partenaires absents du décompte ou à zéro, triés par nom', () => {
    expect(
      findPartnersWithoutPrograms(partners, [
        { institutionId: 'icn', count: 0 },
        { institutionId: 'omnes', count: 40 },
        // Un établissement qui n'est pas partenaire ne compte pour personne.
        { institutionId: 'essec', count: 3 },
      ]),
    ).toEqual([
      { id: 'icn', nameFr: 'ICN Business School' },
      { id: 'mundia', nameFr: 'Mundiapolis' },
    ]);
  });

  it('ne signale rien sans partenaire', () => {
    expect(findPartnersWithoutPrograms([], [])).toEqual([]);
  });
});

describe('findProgramSnapshotOverflow', () => {
  it('suit la limite de l’app installée (1 000)', () => {
    expect(INSTALLED_APP_PROGRAM_SNAPSHOT_LIMIT).toBe(1000);
  });

  it('tient jusqu’à 1 000 formations comprises', () => {
    expect(findProgramSnapshotOverflow(0)).toBeNull();
    expect(findProgramSnapshotOverflow(1000)).toBeNull();
  });

  it('déborde à 1 001 et compte les formations que l’app ne verra pas', () => {
    expect(findProgramSnapshotOverflow(1001)).toEqual({
      publicPrograms: 1001,
      limit: 1000,
      hiddenFromInstalledApps: 1,
    });
    expect(findProgramSnapshotOverflow(1634, 1000)?.hiddenFromInstalledApps).toBe(634);
  });
});

describe('evaluateCatalogConsistency', () => {
  it('ne trouve rien sur un catalogue sain', () => {
    expect(evaluateCatalogConsistency(healthyInput())).toEqual([]);
  });

  it('rapporte chaque contrôle en défaut, dans un ordre stable', () => {
    const findings = evaluateCatalogConsistency(
      healthyInput({
        programsByField: [
          { fieldId: 'd01', isActive: true, count: 3 },
          { fieldId: 'd99', isActive: true, count: 2 },
        ],
        publicProgramsByInstitution: [],
        publicProgramCount: 1200,
      }),
    );

    expect(findings.map((f) => f.check)).toEqual([
      'orphan-field-id',
      'partner-without-programs',
      'program-snapshot-overflow',
    ]);
    expect(findings[0].details).toEqual(['fieldId="d99" (2 row(s), 2 active)']);
    expect(findings[1].details).toEqual(['"ICN Business School" (id=icn)']);
    expect(findings[2].summary).toContain('200 are invisible');
  });
});

describe('renderCatalogConsistencyReport', () => {
  const finding = {
    check: 'partner-without-programs' as const,
    summary: '1 active partner institution(s) have zero active programs',
    details: ['"ICN Business School" (id=icn)'],
  };

  it('imprime OK et sort à 0 sans constat, strict ou non', () => {
    for (const strict of [false, true]) {
      const report = renderCatalogConsistencyReport([], { strict, publicProgramCount: 634 });
      expect(report).toMatchObject({ ok: true, exitCode: 0 });
      expect(report.lines).toHaveLength(1);
      expect(report.lines[0]).toMatch(/^OK — .*\(634\/1000 programs\)/);
    }
  });

  it('AVERTIT et sort à 0 sans --strict — le déploiement continue', () => {
    const report = renderCatalogConsistencyReport([finding], {
      strict: false,
      publicProgramCount: 634,
    });

    expect(report.ok).toBe(false);
    expect(report.exitCode).toBe(0);
    expect(report.lines[0]).toBe(
      '::warning::Catalog check [partner-without-programs]: ' +
        '1 active partner institution(s) have zero active programs',
    );
    expect(report.lines[1]).toBe('  "ICN Business School" (id=icn)');
    expect(report.lines[report.lines.length - 1]).toMatch(/^WARN — 1 catalog consistency/);
    expect(report.lines.some((line) => line.startsWith('::error::'))).toBe(false);
  });

  it('ÉCHOUE et sort à 1 avec --strict — la CI rougit', () => {
    const report = renderCatalogConsistencyReport([finding], {
      strict: true,
      publicProgramCount: 634,
    });

    expect(report.exitCode).toBe(1);
    expect(report.lines[0]).toMatch(/^::error::Catalog check \[partner-without-programs\]/);
    expect(report.lines[report.lines.length - 1]).toBe(
      'FAIL — 1 catalog consistency check(s) flagged (--strict).',
    );
  });

  it('résume les détails au-delà de la limite au lieu d’inonder le journal', () => {
    const details = Array.from({ length: MAX_DETAIL_LINES + 3 }, (_, i) => `row ${i}`);
    const report = renderCatalogConsistencyReport([{ ...finding, details }], {
      strict: false,
      publicProgramCount: 0,
    });

    const detailLines = report.lines.filter((line) => line.startsWith('  '));
    expect(detailLines).toHaveLength(MAX_DETAIL_LINES + 1);
    expect(detailLines[detailLines.length - 1]).toBe('  … and 3 more');
  });
});

// ── La clause des contrôles est celle de l'app ───────────────────────────────
//
// Le contrôle 3 n'a de sens que s'il compte EXACTEMENT ce que `/catalog/programs`
// sert aux builds installées, et le contrôle 2 que s'il lit les partenaires que
// `/catalog/institutions?partnerOnly=true` sert. On capture la clause que
// `CatalogService` envoie à Prisma et on la compare à celle du script : si l'une
// bouge sans l'autre, ce test rougit.
describe('les contrôles comptent le même ensemble que le catalogue public', () => {
  let service: CatalogService;
  const captured: { programs?: unknown; institutions?: unknown } = {};
  const prismaService = { isEnabled: true, execute: jest.fn() };

  function fakePrisma(): PrismaClient {
    const client = {
      institution: {
        findMany: jest.fn(async (args: { where: unknown }) => {
          captured.institutions = args.where;
          return [];
        }),
      },
      program: {
        findMany: jest.fn(async (args: { where: unknown }) => {
          captured.programs = args.where;
          return [];
        }),
        count: jest.fn(async () => 0),
      },
      $transaction: jest.fn(
        async (arg: unknown): Promise<unknown> =>
          typeof arg === 'function'
            ? await (arg as (tx: unknown) => Promise<unknown>)(client)
            : await Promise.all(arg as Promise<unknown>[]),
      ),
    };
    return client as unknown as PrismaClient;
  }

  beforeEach(async () => {
    jest.clearAllMocks();
    delete captured.programs;
    delete captured.institutions;
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma()),
    );
    const moduleRef = await Test.createTestingModule({
      providers: [CatalogService, { provide: PrismaService, useValue: prismaService }],
    }).compile();
    service = moduleRef.get(CatalogService);
  });

  it('formations : la clause de l’instantané de 1 000 sans filtre', async () => {
    await service.getPrograms({ limit: INSTALLED_APP_PROGRAM_SNAPSHOT_LIMIT });
    expect(captured.programs).toEqual(publicCatalogProgramWhere());
  });

  it('partenaires : la clause de /catalog/institutions?partnerOnly=true', async () => {
    await service.getInstitutions({ partnerOnly: true });
    expect(captured.institutions).toEqual(publicPartnerInstitutionWhere());
  });

  it('chaque appel rend une clause neuve, que l’appelant peut compléter', () => {
    const first = publicCatalogProgramWhere();
    first.fieldId = 'd01';
    expect(publicCatalogProgramWhere()).not.toHaveProperty('fieldId');
  });
});
