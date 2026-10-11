import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { HttpException } from '@nestjs/common';
import type { Institution, PrismaClient, Program } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';
import {
  CATALOG_SOURCE_DATABASE,
  CATALOG_SOURCE_MOCK,
  degradedServiceUnavailable,
  isMockCatalogFallbackAllowed,
  type CatalogSource,
} from '../../common/degraded-mode';
import {
  notEefInstitution,
  notEefProgram,
} from '../../common/eef-provenance';
import {
  ALGORITHM_VERSION,
  MatchScore,
  ScoringProfile,
  ScoringProgram,
  scoreProgram,
} from './matching';

/**
 * 503 returned instead of matches scored on fixtures. Same envelope as the
 * catalog's `CATALOG_UNAVAILABLE` (`{ code, message, details }`), so the app
 * treats both outages the same way: the AHA screen already catches any error
 * and degrades to its local affinity estimate (flagged `isEstimate`), which is
 * honest — unlike a "70% match" on a program that does not exist.
 */
export function matchesUnavailable(resource: string): HttpException {
  return degradedServiceUnavailable(
    'MATCHES_UNAVAILABLE',
    'Match scoring is temporarily unavailable.',
    resource,
  );
}

const MATCH_TTL_MS = 24 * 60 * 60 * 1000; // kit: Match rows expire after 24h
const AHA_DEFAULT_LIMIT = 3;
const AHA_MAX_LIMIT = 10;

export interface MatchDto {
  institutionId: string;
  institutionName: { fr: string; en: string };
  programId: string;
  programName: { fr: string; en: string };
  probability: number;
  zone: string;
  isEstimate: boolean;
  algorithmVersion: string;
  factors: Array<{
    name: string;
    weight: number;
    score: number;
    isEstimate: boolean;
  }>;
  narrative: { fr: string; en: string };
  /** Provenance of the rows this match was scored on (never 'mock' in prod). */
  source: CatalogSource;
}

interface ScoringInstitution {
  id: string;
  nameFr: string;
  nameEn: string;
  studyLevels: string[];
}

type MockProgram = {
  id: string;
  institutionId: string;
  countryId: string;
  fieldId: string;
  name: { fr: string; en: string };
  level: { fr: string; en: string };
  minGpaRequired?: number;
  tuitionMinEur?: number;
  applicationDeadline?: string;
  teachingLanguages?: string[];
};

type MockInstitution = {
  id: string;
  name: { fr: string; en: string };
  countryId: string;
  levels: string[];
};

@Injectable()
export class MatchesService {
  private readonly logger = new Logger(MatchesService.name);

  constructor(private readonly prismaService: PrismaService) {}

  /** US-004 — best-scoring program of one institution for the caller. */
  async schoolMatch(userId: string, institutionId: string): Promise<MatchDto> {
    const profile = await this.loadProfile(userId);
    const { institutions, source: institutionSource } =
      await this.loadInstitutions([institutionId]);
    const institution = institutions[0];
    if (!institution) {
      throw new NotFoundException('Institution not found.');
    }
    const { programs, source: programSource } = await this.loadPrograms({
      institutionId,
    });
    if (programs.length === 0) {
      throw new NotFoundException('No programs found for this institution.');
    }
    const source = this.combineSources(programSource, institutionSource);

    const scored = programs
      .map((program) => this.toDto(profile, program, institution, source))
      .sort((a, b) => b.probability - a.probability);
    const best = scored[0];
    // Pas de persistance ici : la table Match n'est lue que par le recalcul
    // hebdomadaire, qui la compare au dernier « moment aha » affiché. Une ligne
    // écrite par une fiche établissement entrait dans ce top et déclenchait
    // chaque semaine un faux push « Tes matches ont bougé ».
    return best;
  }

  /** US-003 — top-N matches across the caller's target countries/fields. */
  async ahaMoment(
    userId: string,
    limit?: number,
  ): Promise<{ items: MatchDto[]; isEstimate: boolean; source: CatalogSource }> {
    const profile = await this.loadProfile(userId);
    const take = Math.min(Math.max(limit ?? AHA_DEFAULT_LIMIT, 1), AHA_MAX_LIMIT);

    let { programs, source: programSource } = await this.loadPrograms({
      countryIds: profile.targetCountryIds,
      fieldIds: profile.fieldIds,
    });
    // Preference filters are progressive, not absolute: an empty result set
    // (e.g. no catalog rows for the chosen countries yet) falls back to the
    // whole catalog rather than an empty AHA moment.
    if (programs.length === 0) {
      ({ programs, source: programSource } = await this.loadPrograms({}));
    }
    if (programs.length === 0) {
      return { items: [], isEstimate: false, source: programSource };
    }

    const { institutions, source: institutionSource } =
      await this.loadInstitutions([
        ...new Set(programs.map((p) => p.institutionId)),
      ]);
    const institutionById = new Map(institutions.map((i) => [i.id, i]));
    const source = this.combineSources(programSource, institutionSource);

    const scored = programs
      .map((program) =>
        this.toDto(
          profile,
          program,
          institutionById.get(program.institutionId),
          source,
        ),
      )
      .sort((a, b) => b.probability - a.probability);

    // One entry per institution (the AHA moment presents schools, not a list
    // of near-duplicate programs from the same place).
    const items: MatchDto[] = [];
    const seenInstitutions = new Set<string>();
    for (const match of scored) {
      if (seenInstitutions.has(match.institutionId)) continue;
      seenInstitutions.add(match.institutionId);
      items.push(match);
      if (items.length >= take) break;
    }

    await Promise.all(items.map((item) => this.persist(userId, item)));
    await this.pruneOutsideTop(userId, items, source);
    return { items, isEstimate: items.some((i) => i.isEstimate), source };
  }

  // ── Data loading (DB, with the shared degraded-mode policy) ───────────────
  //
  // Same treatment as CatalogService.readOrDegrade: a database outage NEVER
  // silently turns into fixture data in production. Fixture matches are worse
  // than fixture catalog rows — the app would tell a student "this program is
  // a 70% match for you" about a program that does not exist.

  private async loadProfile(userId: string): Promise<ScoringProfile> {
    const row = await this.readOrDegrade('profile', (prisma) =>
      prisma.userProfile.findUnique({
        where: { id: userId },
        select: {
          gradeRange: true,
          languageLevel: true,
          targetLevel: true,
          annualTuitionBudgetEur: true,
          fieldIds: true,
          targetCountryIds: true,
        },
      }),
    );
    // There is no mock profile to degrade to: a degraded (non-production)
    // process 404s here exactly like a live database with no such row.
    if (!row) {
      throw new NotFoundException('Profile not found.');
    }
    return row;
  }

  private async loadPrograms(filter: {
    institutionId?: string;
    countryIds?: string[];
    fieldIds?: string[];
  }): Promise<{ programs: ScoringProgram[]; source: CatalogSource }> {
    // Une recommandation est une surface publique comme une autre : proposer
    // à un étudiant une formation que personne n'a relue est exactement ce que
    // le drapeau doit empêcher.
    //
    // Et le moteur ne connaît pas l'import « Études en France » : sans profil
    // exploitable il se replie sur `loadPrograms({})`, donc sur TOUT le catalogue
    // actif, sans limite. Dès la première université publiée, ses formations
    // (facteurs neutres : ni frais ni note minimale) se retrouveraient en
    // concurrence avec la dizaine d'écoles partenaires dans le « moment aha »,
    // et chaque requête chargerait des milliers de lignes en mémoire. L'espace
    // EEF a sa propre shortlist ; voir `common/eef-provenance.ts`.
    const where: Record<string, unknown> = {
      isActive: true,
      ...notEefProgram(),
    };
    if (filter.institutionId) where.institutionId = filter.institutionId;
    if (filter.countryIds?.length) where.countryId = { in: filter.countryIds };
    if (filter.fieldIds?.length) where.fieldId = { in: filter.fieldIds };

    const rows = await this.readOrDegrade('programs', (prisma) =>
      prisma.program.findMany({ where }),
    );
    if (rows) {
      return {
        programs: rows.map((row) => this.fromDbProgram(row)),
        source: CATALOG_SOURCE_DATABASE,
      };
    }

    // Degraded mode (non-production only, see readOrDegrade).
    const programs = (mockCatalog.programs as MockProgram[])
      .filter((p) => !filter.institutionId || p.institutionId === filter.institutionId)
      .filter(
        (p) => !filter.countryIds?.length || filter.countryIds.includes(p.countryId),
      )
      .filter((p) => !filter.fieldIds?.length || filter.fieldIds.includes(p.fieldId))
      .map((p) => this.fromMockProgram(p));
    return { programs, source: CATALOG_SOURCE_MOCK };
  }

  private async loadInstitutions(
    ids: string[],
  ): Promise<{ institutions: ScoringInstitution[]; source: CatalogSource }> {
    if (ids.length === 0) {
      return { institutions: [], source: CATALOG_SOURCE_DATABASE };
    }
    // `schoolMatch` reçoit un identifiant d'établissement du client : sans
    // cette clause, celui d'une université EEF (publiée ou non) était lu ici,
    // et seul le filtre des formations, plus loin, l'empêchait d'aboutir — une
    // protection à un endroit, quand la lecture voisine en avait besoin aussi.
    const rows = await this.readOrDegrade('institutions', (prisma) =>
      prisma.institution.findMany({
        where: { id: { in: ids }, ...notEefInstitution() },
      }),
    );
    if (rows) {
      return {
        institutions: rows.map((row: Institution) => ({
          id: row.id,
          nameFr: row.nameFr,
          nameEn: row.nameEn,
          studyLevels: row.studyLevels,
        })),
        source: CATALOG_SOURCE_DATABASE,
      };
    }

    // Degraded mode (non-production only, see readOrDegrade).
    const institutions = (mockCatalog.institutions as MockInstitution[])
      .filter((i) => ids.includes(i.id))
      .map((i) => ({
        id: i.id,
        nameFr: i.name.fr,
        nameEn: i.name.en,
        studyLevels: i.levels,
      }));
    return { institutions, source: CATALOG_SOURCE_MOCK };
  }

  /**
   * Runs a read against Postgres and returns its rows, or `null` when the
   * caller should score `mock-catalog.ts` fixtures instead.
   *
   * `null` is only ever returned outside production. In production a missing
   * or failing database throws 503 `MATCHES_UNAVAILABLE` — the matching engine
   * must never score fixtures and present them as personalized results.
   *
   * Uses `PrismaService.execute()`, not `tryExecute()`: `tryExecute` downgrades
   * every database error to a swallowed `warn`, which is how the catalog
   * incident stayed invisible in the logs.
   *
   * Unlike the catalog variant, a `null` operation result is NOT treated as a
   * degradation: `loadProfile` goes through here with `findUnique`, whose null
   * legitimately means "no such row" (the `isEnabled` guard already covers the
   * only case where `execute()` itself returns null).
   */
  private async readOrDegrade<T>(
    resource: string,
    operation: (prisma: PrismaClient) => Promise<T>,
  ): Promise<T | null> {
    if (!this.prismaService.isEnabled) {
      return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
    }
    try {
      return await this.prismaService.execute(operation);
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
        `Matches "${resource}" data is unavailable (${reason}). Refusing to ` +
          'score mock-catalog fixtures; answering 503 MATCHES_UNAVAILABLE.',
      );
      throw matchesUnavailable(resource);
    }
    this.logger.warn(
      `Matches "${resource}" data is unavailable (${reason}). Degrading to ` +
        'mock-catalog fixtures where they exist — results are tagged ' +
        'source="mock" (non-production only).',
    );
    return null;
  }

  /** A match is only as trustworthy as its least trustworthy input. */
  private combineSources(...sources: CatalogSource[]): CatalogSource {
    return sources.includes(CATALOG_SOURCE_MOCK)
      ? CATALOG_SOURCE_MOCK
      : CATALOG_SOURCE_DATABASE;
  }

  private fromDbProgram(row: Program): ScoringProgram {
    return {
      id: row.id,
      institutionId: row.institutionId,
      countryId: row.countryId,
      fieldId: row.fieldId,
      nameFr: row.nameFr,
      nameEn: row.nameEn,
      levelFr: row.levelFr,
      levelEn: row.levelEn,
      minGpaRequired: row.minGpaRequired,
      tuitionMinEur: row.tuitionMinEur,
      applicationDeadline: row.applicationDeadline,
      teachingLanguages: row.teachingLanguages,
    };
  }

  private fromMockProgram(p: MockProgram): ScoringProgram {
    return {
      id: p.id,
      institutionId: p.institutionId,
      countryId: p.countryId,
      fieldId: p.fieldId,
      nameFr: p.name.fr,
      nameEn: p.name.en,
      levelFr: p.level.fr,
      levelEn: p.level.en,
      minGpaRequired: p.minGpaRequired ?? null,
      tuitionMinEur: p.tuitionMinEur ?? null,
      applicationDeadline: p.applicationDeadline
        ? new Date(p.applicationDeadline)
        : null,
      teachingLanguages: p.teachingLanguages ?? [],
    };
  }

  // ── Scoring → DTO → persistence ───────────────────────────────────────────

  private toDto(
    profile: ScoringProfile,
    program: ScoringProgram,
    institution: ScoringInstitution | undefined,
    source: CatalogSource,
  ): MatchDto {
    const score = scoreProgram(profile, program, {
      institutionStudyLevels: institution?.studyLevels,
    });
    return {
      source,
      institutionId: program.institutionId,
      institutionName: {
        fr: institution?.nameFr ?? '',
        en: institution?.nameEn ?? '',
      },
      programId: program.id,
      programName: { fr: program.nameFr, en: program.nameEn },
      probability: score.probability,
      zone: score.zone,
      isEstimate: score.isEstimate,
      algorithmVersion: ALGORITHM_VERSION,
      factors: score.factors,
      narrative: this.narrative(program, score),
    };
  }

  // Static bilingual narrative (v1 — an LLM narrative is deliberately out of
  // scope so the score path stays deterministic and free).
  private narrative(
    program: ScoringProgram,
    score: MatchScore,
  ): { fr: string; en: string } {
    const pct = Math.round(score.probability * 100);
    const byZone = {
      green: {
        fr: `Ton profil correspond très bien à ${program.nameFr} (${pct}% de compatibilité). Fonce, tes chances sont réelles.`,
        en: `Your profile is a strong match for ${program.nameEn} (${pct}% compatibility). Go for it — your chances are real.`,
      },
      yellow: {
        fr: `Ton profil est compatible avec ${program.nameFr} (${pct}%). Un dossier soigné ou une bourse peut faire la différence.`,
        en: `Your profile is compatible with ${program.nameEn} (${pct}%). A polished application or a scholarship can make the difference.`,
      },
      blue: {
        fr: `${program.nameFr} est ambitieux pour ton profil actuel (${pct}%). Garde-le en objectif et renforce ton dossier.`,
        en: `${program.nameEn} is a reach for your current profile (${pct}%). Keep it as a goal and strengthen your application.`,
      },
    } as const;
    const base = byZone[score.zone];
    if (!score.isEstimate) return { fr: base.fr, en: base.en };
    return {
      fr: `${base.fr} Estimation — complète ton profil pour plus de précision.`,
      en: `${base.en} Estimate — complete your profile for more precision.`,
    };
  }

  /**
   * Garde dans Match exactement le dernier top affiché : les lignes d'écoles
   * sorties du top (jamais supprimées jusque-là) gardaient leur probabilité et
   * pouvaient rester dans l'instantané du recalcul hebdomadaire.
   */
  private async pruneOutsideTop(
    userId: string,
    items: MatchDto[],
    source: MatchDto['source'],
  ): Promise<void> {
    if (source === CATALOG_SOURCE_MOCK || items.length === 0) return;
    await this.prismaService.tryExecute((prisma) =>
      prisma.match.deleteMany({
        where: {
          userProfileId: userId,
          programId: { notIn: items.map((i) => i.programId) },
        },
      }),
    );
  }

  /**
   * Best-effort 24h cache write; failures never break the response.
   *
   * Fixture-scored matches are never written: the Match table is what the
   * weekly recompute (KPB-168) diffs against, and a fixture row cached there
   * would keep producing "your matches moved" pushes about programs that do not
   * exist long after the database came back.
   */
  private async persist(userId: string, dto: MatchDto): Promise<void> {
    if (dto.source === CATALOG_SOURCE_MOCK) return;
    const expiresAt = new Date(Date.now() + MATCH_TTL_MS);
    await this.prismaService.tryExecute(async (prisma) => {
      const match = await prisma.match.upsert({
        where: {
          userProfileId_programId: {
            userProfileId: userId,
            programId: dto.programId,
          },
        },
        create: {
          userProfileId: userId,
          programId: dto.programId,
          institutionId: dto.institutionId,
          probability: dto.probability,
          zone: dto.zone as 'green' | 'yellow' | 'blue',
          algorithmVersion: dto.algorithmVersion,
          isEstimate: dto.isEstimate,
          expiresAt,
        },
        update: {
          probability: dto.probability,
          zone: dto.zone as 'green' | 'yellow' | 'blue',
          algorithmVersion: dto.algorithmVersion,
          isEstimate: dto.isEstimate,
          expiresAt,
        },
      });
      await prisma.matchExplanation.upsert({
        where: { matchId: match.id },
        create: {
          matchId: match.id,
          factors: dto.factors,
          narrativeFr: dto.narrative.fr,
          narrativeEn: dto.narrative.en,
        },
        update: {
          factors: dto.factors,
          narrativeFr: dto.narrative.fr,
          narrativeEn: dto.narrative.en,
        },
      });
      return match;
    });
  }
}
