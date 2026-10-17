import { Injectable, Logger } from '@nestjs/common';
import type { Prisma, PrismaClient, Program } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';
import {
  notEefInstitution,
  notEefProgram,
} from '../../common/eef-provenance';
import { publicScholarshipWhere } from '../../common/public-scholarship-where';
import {
  CATALOG_SOURCE_DATABASE,
  CATALOG_SOURCE_MOCK,
  catalogUnavailable,
  isMockCatalogFallbackAllowed,
  type CatalogSource,
} from './catalog-degraded-mode';
import { publicPartnerInstitutionWhere } from './catalog-consistency-checks';
import {
  mapCountry,
  mapField,
  mapInstitution,
  mapProgram,
  mapProgramCompact,
  mapScholarship,
} from './catalog.mapper';
import {
  PROGRAM_PAGE_MAX,
  planProgramPage,
  programSnapshotSegments,
  startOfUtcDay,
} from './program-snapshot-order';

export type ProgramCatalogQuery = {
  q?: string;
  fieldId?: string;
  countryId?: string;
  institutionId?: string;
  limit?: number;
  offset?: number;
  /** `compact` : sans les doublons à plat (voir `mapProgramCompact`). */
  view?: 'compact';
};

/** Every `/catalog/*` list response carries the provenance of its rows. */
export type CatalogListResponse<T> = {
  items: T[];
  source: CatalogSource;
};

@Injectable()
export class CatalogService {
  private readonly logger = new Logger(CatalogService.name);

  constructor(private readonly prismaService: PrismaService) {}

  async getFields(): Promise<CatalogListResponse<unknown>> {
    const rows = await this.readOrDegrade('fields', (prisma) =>
      prisma.field.findMany({ orderBy: { nameFr: 'asc' } }),
    );
    if (rows === null) return this.mockResponse(mockCatalog.fields);
    return { items: rows.map(mapField), source: CATALOG_SOURCE_DATABASE };
  }

  async getCountries(): Promise<CatalogListResponse<unknown>> {
    const rows = await this.readOrDegrade('countries', (prisma) =>
      prisma.country.findMany({
        where: { isActive: true },
        orderBy: { displayOrder: 'asc' },
      }),
    );
    if (rows === null) return this.mockResponse(mockCatalog.countries);
    return { items: rows.map(mapCountry), source: CATALOG_SOURCE_DATABASE };
  }

  async getInstitutions(
    query: { countryId?: string; partnerOnly?: boolean } = {},
  ): Promise<CatalogListResponse<unknown> & { total: number }> {
    // `isActive` n'est pas un filtre de requête : c'est la frontière entre ce
    // qui est relu et ce qui ne l'est pas. Elle n'est donc jamais optionnelle
    // ici — la surface publique ne sert que du relu.
    //
    // Les établissements de l'import « Études en France » sont exclus de cette
    // surface, PUBLIÉS OU NON : leur espace est `/etudes-en-france/*`. Les
    // laisser ici ferait apparaître 84 universités dans Explore des builds déjà
    // installées, avec des compteurs de formations dont presque aucune n'est
    // joignable. Voir `common/eef-provenance.ts`.
    const where: Prisma.InstitutionWhereInput = {
      isActive: true,
      ...notEefInstitution(),
    };
    if (query.countryId) where.countryId = query.countryId;
    if (query.partnerOnly) where.isPartner = true;

    const result = await this.readOrDegrade('institutions', (prisma) =>
      prisma.$transaction(async (tx) => {
        const institutions = await tx.institution.findMany({
          where,
          orderBy: { nameFr: 'asc' },
        });
        // `Institution.programIds` est dénormalisé et contient TOUTES les
        // formations de l'établissement, relues ou non — c'est
        // `syncInstitutionProgramIds` qui le remplit, sans regarder
        // `isActive`. Or l'app s'en sert pour compter, prévisualiser,
        // naviguer et comparer : le servir tel quel publierait des
        // références vers des fiches que personne n'a relues, même une fois
        // la liste des formations filtrée.
        //
        // On retire donc les identifiants CONNUS comme inactifs, et rien
        // d'autre : une référence orpheline reste servie comme avant, parce
        // que la nettoyer ici serait un changement de comportement sans
        // rapport avec la relecture.
        const hidden = await tx.program.findMany({
          where: {
            isActive: false,
            institutionId: { in: institutions.map((row) => row.id) },
          },
          select: { id: true },
        });
        return { institutions, hidden };
      }),
    );
    if (result === null) {
      const fallback = this.mockResponse(mockCatalog.institutions);
      return { ...fallback, total: fallback.items.length };
    }
    const hiddenIds = new Set(result.hidden.map((row) => row.id));
    const items = result.institutions.map((row) =>
      mapInstitution({
        ...row,
        programIds: row.programIds.filter((id) => !hiddenIds.has(id)),
      }),
    );
    return {
      items,
      total: items.length,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async getPrograms(
    query: ProgramCatalogQuery = {},
  ): Promise<
    CatalogListResponse<unknown> & {
      total: number;
      limit: number;
      offset: number;
      nextOffset: number | null;
    }
  > {
    // Voir `getInstitutions` : jamais optionnel. Une formation importée mais
    // non relue ne doit apparaître ni dans une liste, ni dans une recherche,
    // ni — surtout — dans les 1 000 lignes de l'instantané mobile, où elle
    // prendrait la place d'une fiche publiée.
    //
    // Et une formation de l'import « Études en France » n'y apparaît JAMAIS,
    // relue ou non. Chaque build installée charge cette liste d'un seul appel
    // (`limit=1000`, trié par nom) : dès plus de 366 lignes EEF actives, elles
    // chasseraient des formations partenaires de l'app de tout le monde. Le
    // serveur ne sait pas quelle build l'appelle — aucun en-tête de version —,
    // la garde doit donc valoir pour tous.
    //
    // Pagination (17/10/2026, décision du propriétaire : aucun plafond de
    // formations). Une page fait au plus `PROGRAM_PAGE_MAX` lignes, mais rien
    // ne borne le catalogue : les builds récentes enchaînent les pages
    // (`offset` / `nextOffset`) jusqu'à épuisement. Les builds installées
    // n'envoient que `limit=1000`, sans `offset`, et ne voient que la première
    // page : l'ordre de `programSnapshotSegments` y garde les formations
    // partenaires, puis celles dont la date limite est à venir.
    const where: Prisma.ProgramWhereInput = {
      isActive: true,
      ...notEefProgram(),
    };
    if (query.fieldId) where.fieldId = query.fieldId;
    if (query.countryId) where.countryId = query.countryId;
    if (query.institutionId) where.institutionId = query.institutionId;
    if (query.q?.trim()) {
      where.OR = [
        { nameFr: { contains: query.q.trim(), mode: 'insensitive' } },
        { nameEn: { contains: query.q.trim(), mode: 'insensitive' } },
        { levelFr: { contains: query.q.trim(), mode: 'insensitive' } },
      ];
    }

    const limit = Math.min(
      Math.max(query.limit ?? PROGRAM_PAGE_MAX, 1),
      PROGRAM_PAGE_MAX,
    );
    const offset = Math.max(query.offset ?? 0, 0);

    const result = await this.readOrDegrade('programs', (prisma) =>
      prisma.$transaction(async (tx) => {
        // L'ordre de l'instantané (voir `programSnapshotSegments`) : les
        // formations partenaires d'abord, puis celles dont la date limite est à
        // venir, puis le reste — chaque tranche triée par nom puis par id.
        const partners = await tx.institution.findMany({
          where: publicPartnerInstitutionWhere(),
          select: { id: true },
        });
        const segments = programSnapshotSegments(
          where,
          partners.map((row) => row.id),
          startOfUtcDay(new Date()),
        );
        const counts: number[] = [];
        for (const segment of segments) {
          counts.push(await tx.program.count({ where: segment }));
        }
        const rows: Program[] = [];
        for (const slice of planProgramPage(counts, offset, limit)) {
          rows.push(
            ...(await tx.program.findMany({
              where: segments[slice.segment],
              orderBy: [{ nameFr: 'asc' }, { id: 'asc' }],
              skip: slice.skip,
              take: slice.take,
            })),
          );
        }
        return { rows, total: counts.reduce((sum, n) => sum + n, 0) };
      }),
    );

    if (result === null) {
      const fallback = this.mockResponse(mockCatalog.programs);
      return {
        ...fallback,
        total: fallback.items.length,
        limit,
        offset,
        nextOffset: null,
      };
    }

    const { rows, total } = result;
    const end = offset + rows.length;
    return {
      items: rows.map(query.view === 'compact' ? mapProgramCompact : mapProgram),
      total,
      limit,
      offset,
      // Le curseur de la page suivante, ou `null` quand tout est servi. Les
      // builds récentes bouclent dessus ; les anciennes l'ignorent.
      nextOffset: rows.length > 0 && end < total ? end : null,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async getScholarships(): Promise<CatalogListResponse<unknown>> {
    const rows = await this.readOrDegrade('scholarships', (prisma) =>
      prisma.scholarship.findMany({
        // Le commentaire qui vivait ici affirmait masquer les fiches expirées.
        // C'était faux : le `where` n'avait aucun filtre de date, et trois
        // bourses closes depuis 13 à 90 jours étaient servies comme
        // disponibles. La règle est maintenant partagée avec `/scholarships`,
        // en un seul endroit, pour qu'un commentaire ne puisse plus tenir lieu
        // de filtre.
        where: publicScholarshipWhere(),
        orderBy: { nameFr: 'asc' },
        // Les cycles voyagent avec la fiche pour que le client sache si
        // `deadlineAt` est une date CONFIRMÉE ou une PROJECTION. 20 des 31
        // fiches publiées ont un cycle `estimated` : sans cette information,
        // le calendrier d'échéances posait un jalon ferme — « J-146 » — sur
        // une date que personne n'a confirmée. L'onglet Bourses sait déjà se
        // taire dans ce cas ; ce endpoint doit donner au calendrier le moyen
        // d'en faire autant.
        include: { cycles: { orderBy: { academicYear: 'desc' }, take: 5 } },
      }),
    );
    if (rows === null) return this.mockResponse(mockCatalog.scholarships);
    return { items: rows.map(mapScholarship), source: CATALOG_SOURCE_DATABASE };
  }

  /**
   * Runs a read against Postgres and returns its rows, or `null` when the
   * caller should serve `mock-catalog.ts` fixtures instead.
   *
   * `null` is only ever returned outside production. In production a missing
   * or failing database throws 503 `CATALOG_UNAVAILABLE`, so a client can tell
   * "the catalog is empty" (200 with `items: []`) from "the catalog service is
   * down" (503) — and never receives a fixture dressed up as a real row.
   *
   * Note this uses `PrismaService.execute()`, not `tryExecute()`: `tryExecute`
   * downgrades every database error to a `warn` and swallows it, which is how
   * this incident stayed invisible in the logs.
   */
  private async readOrDegrade<T>(
    resource: string,
    operation: (prisma: PrismaClient) => Promise<T>,
  ): Promise<T | null> {
    if (!this.prismaService.isEnabled) {
      return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
    }
    try {
      const result = await this.prismaService.execute(operation);
      // `execute()` only returns null when no client is configured, which the
      // guard above already covered; treat it as a degradation regardless.
      if (result === null) {
        return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
      }
      return result;
    } catch {
      // PrismaService.execute() already logged the bounded, PII-free error code
      // at `error` level before rethrowing.
      return this.degrade(resource, 'DATABASE_ERROR');
    }
  }

  /** Decides what a database outage means for this process. Never silent. */
  private degrade(resource: string, reason: string): null {
    if (!isMockCatalogFallbackAllowed()) {
      this.logger.error(
        `Catalog "${resource}" is unavailable (${reason}). Refusing to serve ` +
          'mock-catalog fixtures; answering 503 CATALOG_UNAVAILABLE.',
      );
      throw catalogUnavailable(resource);
    }
    this.logger.warn(
      `Catalog "${resource}" is unavailable (${reason}). Serving mock-catalog ` +
        'fixtures tagged source="mock" (non-production only).',
    );
    return null;
  }

  private mockResponse(rows: unknown[]): CatalogListResponse<unknown> {
    return {
      items: rows as Record<string, unknown>[],
      source: CATALOG_SOURCE_MOCK,
    };
  }
}
