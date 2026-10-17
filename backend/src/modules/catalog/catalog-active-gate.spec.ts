// ─────────────────────────────────────────────────────────────────────────────
// La barrière « relu / non relu » sur les surfaces PUBLIQUES.
//
// POURQUOI CE FICHIER EXISTE
//
// L'import du catalogue « Études en France » crée ses lignes `isActive: false`
// et la documentation promet que rien ne s'affiche tant que personne n'a relu.
// Cette promesse était FAUSSE : le drapeau était écrit, et aucune lecture ne le
// lisait. `CatalogService` et `MatchesService` construisaient leur filtre à
// partir des seuls paramètres de requête, donc 10 247 formations non relues
// devenaient publiques à la seconde où l'import se terminait.
//
// Ces tests tiennent la promesse à la place du commentaire. Ils regardent la
// clause `where` réellement envoyée à Prisma, pas le résultat : une régression
// se voit à l'endroit où elle se produit.
// ─────────────────────────────────────────────────────────────────────────────
import { Test } from '@nestjs/testing';
import type { PrismaClient } from '@prisma/client';

import { CatalogService } from './catalog.service';
import { withoutSnapshotSegment } from './program-snapshot-order';
import { PrismaService } from '../prisma/prisma.service';

type Captured = { institutions?: unknown; programs?: unknown; hidden?: unknown };

function fakePrisma(
  captured: Captured,
  rows: {
    institutions?: Record<string, unknown>[];
    programs?: Record<string, unknown>[];
    hidden?: { id: string }[];
  } = {},
) {
  const institutionRows = rows.institutions ?? [];
  const programRows = rows.programs ?? [];
  const hiddenRows = rows.hidden ?? [];
  const client: Record<string, unknown> = {
    institution: {
      findMany: jest.fn(async (args: { where: unknown }) => {
        captured.institutions = args.where;
        return institutionRows;
      }),
    },
    program: {
      findMany: jest.fn(async (args: { where: Record<string, unknown> }) => {
        // Les deux requêtes `program.findMany` du service se distinguent par
        // leur `isActive` : la publique demande les actives, celle qui nettoie
        // `programIds` demande les inactives.
        if (args.where?.isActive === false) {
          captured.hidden = args.where;
          return hiddenRows;
        }
        // `getPrograms` lit par tranches (partenaires d'abord — voir
        // program-snapshot-order.ts) : on capture la clause PUBLIQUE, sans la
        // condition de tranche.
        captured.programs = withoutSnapshotSegment(args.where);
        return programRows;
      }),
      // Toutes les lignes du faux catalogue tombent dans la première tranche :
      // une seule lecture, pas de doublon.
      count: jest.fn(async (args: { where: Record<string, unknown> }) => {
        captured.programs = withoutSnapshotSegment(args.where);
        return isPartnerSegment(args.where) ? programRows.length : 0;
      }),
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

function isPartnerSegment(where: Record<string, unknown>): boolean {
  const and = where.AND as Record<string, { in?: unknown }>[];
  return Array.isArray(and) && and[and.length - 1]?.institutionId?.in !== undefined;
}

function institutionRow(over: Record<string, unknown> = {}) {
  return {
    id: 'eef-univ-0353074b',
    nameFr: 'Université de Rennes',
    nameEn: 'University of Rennes',
    countryId: 'france',
    locationFr: 'Rennes, Bretagne',
    locationEn: 'Rennes, Bretagne',
    overviewFr: 'x',
    overviewEn: 'x',
    studyLevels: ['Bachelor'],
    tuitionLabelFr: 'x',
    tuitionLabelEn: 'x',
    languageRequirementsFr: 'x',
    languageRequirementsEn: 'x',
    intakePeriods: [],
    programIds: ['prog-relu', 'prog-en-attente'],
    isPartner: false,
    isActive: true,
    lastVerifiedAt: null,
    sourceUrl: null,
    ...over,
  };
}

describe('CatalogService — la barrière relu / non relu', () => {
  let service: CatalogService;
  const prismaService = {
    isEnabled: true,
    execute: jest.fn(),
  };

  // Ce que le catalogue général exclut de l'import « Études en France » (voir
  // `common/eef-provenance.ts`). Une formation est « de l'import » si son
  // identifiant OU celui de son établissement porte le préfixe : une formation
  // créée à la main sous une université de l'import (identifiant généré, active
  // par défaut) en est aussi.
  const EXCLUDES_EEF_PROGRAMS = {
    OR: [
      { id: { startsWith: 'eef-prog-' } },
      { institutionId: { startsWith: 'eef-univ-' } },
    ],
  };
  const EXCLUDES_EEF_INSTITUTIONS = { id: { startsWith: 'eef-univ-' } };

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef = await Test.createTestingModule({
      providers: [
        CatalogService,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();
    service = moduleRef.get(CatalogService);
  });

  it('ne sert que les formations relues, quels que soient les filtres', async () => {
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma(captured)),
    );

    // La clause EXACTE de l'appel sans filtre : rien d'autre que le drapeau et la
    // frontière de l'import. Toute clause parasite (un `countryId` par défaut, un
    // `isPartner`…) doit faire rougir — `toBe(true)` sur `isActive` seul ne la
    // verrait pas.
    await service.getPrograms();
    expect(captured.programs).toEqual({
      isActive: true,
      NOT: EXCLUDES_EEF_PROGRAMS,
    });

    await service.getPrograms({ fieldId: 'd07', countryId: 'france', q: 'droit' });
    expect((captured.programs as Record<string, unknown>).isActive).toBe(true);
  });

  it('ne sert que les établissements relus', async () => {
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma(captured, { institutions: [institutionRow()] })),
    );

    await service.getInstitutions();
    expect(captured.institutions).toEqual({
      isActive: true,
      NOT: EXCLUDES_EEF_INSTITUTIONS,
    });

    await service.getInstitutions({ countryId: 'france', partnerOnly: true });
    expect((captured.institutions as Record<string, unknown>).isActive).toBe(true);
  });

  // ── La frontière avec l'espace « Études en France » ────────────────────────
  //
  // `isActive` sépare le relu du non relu. Il ne sépare PAS le catalogue général
  // de l'espace EEF : le jour où une université est publiée, ses lignes seraient
  // servies ici, dans l'instantané de 1 000 formations que chaque build installée
  // charge d'un appel et que le serveur ne peut pas adapter à la build (aucun
  // en-tête de version). Elles chasseraient les formations partenaires.
  //
  // Ces tests regardent la clause envoyée à Prisma, pour chaque combinaison de
  // filtres : l'exclusion ne doit dépendre d'aucun paramètre de requête.

  it('n’envoie au catalogue général aucune formation de l’import EEF', async () => {
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma(captured)),
    );

    const combinations = [
      {},
      { q: 'droit' },
      { fieldId: 'd07', countryId: 'france' },
      // Le paramètre qui pourrait « ouvrir la porte » : demander explicitement
      // les formations d'une université EEF ne doit pas les faire sortir.
      { institutionId: 'eef-univ-0353074b' },
      { q: 'droit', fieldId: 'd07', countryId: 'france', institutionId: 'x', limit: 50 },
    ];
    for (const query of combinations) {
      await service.getPrograms(query);
      const where = captured.programs as Record<string, unknown>;
      expect(where.isActive).toBe(true);
      expect(where.NOT).toEqual(EXCLUDES_EEF_PROGRAMS);
    }
  });

  it('n’envoie au catalogue général aucun établissement de l’import EEF', async () => {
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma(captured, { institutions: [institutionRow()] })),
    );

    for (const query of [
      {},
      { countryId: 'france' },
      { partnerOnly: true },
      { countryId: 'france', partnerOnly: true },
    ]) {
      await service.getInstitutions(query);
      const where = captured.institutions as Record<string, unknown>;
      expect(where.isActive).toBe(true);
      expect(where.NOT).toEqual(EXCLUDES_EEF_INSTITUTIONS);
    }
  });

  it('laisse passer une formation partenaire, même qualifiée par une procédure', async () => {
    // Le critère est la PROVENANCE, pas `procedureType`. Le schéma prévoit la
    // valeur `hors_eef` : le jour où l'exploitation qualifie les 133 formations
    // partenaires, un filtre sur la procédure les ferait disparaître d'Explore.
    // La clause ne mentionne donc aucune colonne de procédure.
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma(captured, { institutions: [institutionRow()] })),
    );

    await service.getPrograms({ countryId: 'france' });
    await service.getInstitutions({ countryId: 'france' });

    for (const where of [captured.programs, captured.institutions]) {
      const text = JSON.stringify(where);
      expect(text).not.toMatch(/procedureType|uaiCode|institutionType|cycle/);
    }
  });

  it('retire de programIds les formations non relues', async () => {
    // `programIds` est dénormalisé et contient TOUTES les formations, relues
    // ou non. L'app s'en sert pour compter, prévisualiser et naviguer : le
    // servir brut publierait des références vers des fiches non relues même
    // une fois la liste des formations filtrée.
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(
        fakePrisma(captured, {
          institutions: [institutionRow()],
          hidden: [{ id: 'prog-en-attente' }],
        }),
      ),
    );

    const result = await service.getInstitutions();

    expect(captured.hidden).toEqual({
      isActive: false,
      institutionId: { in: ['eef-univ-0353074b'] },
    });
    expect((result.items[0] as { programIds: string[] }).programIds).toEqual([
      'prog-relu',
    ]);
  });

  it('laisse intacte une référence orpheline', async () => {
    // Nettoyer un identifiant qui ne correspond à aucune formation serait un
    // changement de comportement sans rapport avec la relecture. On ne retire
    // que ce qu'on sait inactif.
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(
        fakePrisma(captured, {
          institutions: [institutionRow({ programIds: ['prog-relu', 'prog-fantome'] })],
          hidden: [],
        }),
      ),
    );

    const result = await service.getInstitutions();

    expect((result.items[0] as { programIds: string[] }).programIds).toEqual([
      'prog-relu',
      'prog-fantome',
    ]);
  });
});
