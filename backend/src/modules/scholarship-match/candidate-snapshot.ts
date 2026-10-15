import { Inject, Injectable, Logger, Optional } from '@nestjs/common';

import { publicScholarshipWhere } from '../../common/public-scholarship-where';
import { PrismaService } from '../prisma/prisma.service';
import { ALGORITHM_VERSION, type MatchCycle, type MatchScholarship } from './assess';
import {
  ELIGIBLE_LEVELS,
  parseEligibilityCriteria,
  type EligibilityCriterion,
  type EligibleLevel,
} from './eligibility-criteria';
import { stableHash } from './match-inputs';

/**
 * Les bourses candidates du test, lues UNE fois par minute au plus.
 *
 * Candidates = les fiches PUBLIQUES seulement (`publicScholarshipWhere`) : une
 * fiche non publiée, désactivée ou dont la date limite est passée n'est jamais
 * analysée. Chaque fiche porte son cycle servi (même règle que l'index public :
 * ouvert, sinon prévision, sinon le plus récent).
 *
 * `GET /scholarships/match/state` et `POST /scholarships/match/runs` sont
 * appelés depuis trois points d'entrée de l'app : sans ce cache, chacun
 * relirait jusqu'à 500 fiches avec leurs cycles. Le cache vit 60 s, en
 * mémoire du processus — une fiche publiée apparaît donc au plus une minute
 * plus tard, ce qui est sans conséquence pour un test qu'on refait.
 *
 * `catalogHash` résume ce que le moteur LIT des candidates (et la version de
 * l'algorithme) : un run dont le `catalogHash` diffère est « à mettre à jour ».
 * Une description ou un logo modifiés ne le changent pas.
 */

/** Plafond de candidates, comme `listForProfile`. */
export const MAX_CANDIDATES = 500;

/** Durée de vie du cache, en millisecondes. */
export const SNAPSHOT_TTL_MS = 60_000;

/** Horloge injectable (tests) : `() => new Date()` par défaut. */
export const MATCH_CLOCK = Symbol('SCHOLARSHIP_MATCH_CLOCK');
export type MatchClock = () => Date;

/** Ce que la carte d'un résultat affiche, en plus de l'évaluation. */
export interface CandidateDisplay {
  nameFr: string;
  nameEn: string;
  countryNameFr: string;
  countryNameEn: string;
  typeOfFundingFr: string;
  typeOfFundingEn: string;
  levelEligibleFr: string;
  levelEligibleEn: string;
  deadlineLabelFr: string;
  deadlineLabelEn: string;
  applicationUrl: string | null;
  sourceUrl: string | null;
  academicYear: string | null;
}

export interface MatchCandidate {
  /** L'entrée du moteur (assess.ts). */
  scholarship: MatchScholarship;
  display: CandidateDisplay;
  /** Critères valides, par clé : la citation officielle d'un point « à vérifier ». */
  criteriaByKey: ReadonlyMap<string, EligibilityCriterion>;
}

export interface CandidateSnapshot {
  takenAt: Date;
  candidates: readonly MatchCandidate[];
  byId: ReadonlyMap<string, MatchCandidate>;
  catalogHash: string;
  /** Vrai quand le plafond de 500 a été atteint (le calcul reste honnête sur ce qu'il voit). */
  capped: boolean;
}

/** Les colonnes lues, et seulement elles. */
export const CANDIDATE_SELECT = {
  id: true,
  nameFr: true,
  nameEn: true,
  countryId: true,
  countryNameFr: true,
  countryNameEn: true,
  typeOfFundingFr: true,
  typeOfFundingEn: true,
  levelEligibleFr: true,
  levelEligibleEn: true,
  deadlineLabelFr: true,
  deadlineLabelEn: true,
  fundingType: true,
  relatedFieldIds: true,
  applicationUrl: true,
  sourceUrl: true,
  deadlineAt: true,
  eligibleLevels: true,
  fieldsScope: true,
  eligibilityCriteria: true,
  eligibilityStructuredAt: true,
  cycles: {
    orderBy: { academicYear: 'desc' as const },
    take: 5,
    select: {
      id: true,
      academicYear: true,
      status: true,
      dateConfidence: true,
      opensAt: true,
      closesAt: true,
      estimatedOpenAt: true,
      estimatedCloseAt: true,
    },
  },
};

export interface CandidateCycleRow {
  id: string;
  academicYear: string;
  status: string;
  dateConfidence: string;
  opensAt: Date | null;
  closesAt: Date | null;
  estimatedOpenAt: Date | null;
  estimatedCloseAt: Date | null;
}

export interface CandidateRow {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
  typeOfFundingFr: string;
  typeOfFundingEn: string;
  levelEligibleFr: string;
  levelEligibleEn: string;
  deadlineLabelFr: string;
  deadlineLabelEn: string;
  fundingType: string;
  relatedFieldIds: string[];
  applicationUrl: string | null;
  sourceUrl: string | null;
  deadlineAt: Date | null;
  eligibleLevels: string[];
  fieldsScope: string;
  eligibilityCriteria: unknown;
  eligibilityStructuredAt: Date | null;
  cycles: CandidateCycleRow[];
}

/** Même règle que l'index public : un cycle ouvert, sinon une prévision, sinon le plus récent. */
export function selectServedCycle(
  cycles: readonly CandidateCycleRow[],
): CandidateCycleRow | null {
  return (
    cycles.find((cycle) => cycle.status === 'open') ??
    cycles.find((cycle) => cycle.status === 'forecast') ??
    cycles[0] ??
    null
  );
}

function toMatchCycle(cycle: CandidateCycleRow | null): MatchCycle | null {
  if (!cycle) return null;
  return {
    id: cycle.id,
    status: cycle.status,
    dateConfidence: cycle.dateConfidence,
    opensAt: cycle.opensAt,
    closesAt: cycle.closesAt,
    estimatedOpenAt: cycle.estimatedOpenAt,
    estimatedCloseAt: cycle.estimatedCloseAt,
  };
}

function knownLevels(levels: readonly string[]): EligibleLevel[] {
  return ELIGIBLE_LEVELS.filter((level) => levels.includes(level));
}

function iso(date: Date | null): string | null {
  return date ? date.toISOString() : null;
}

/**
 * Une ligne lue (`CANDIDATE_SELECT`) → la candidate du moteur et sa carte.
 * Seule conversion du dépôt : le test élève et l'aperçu admin (« Tester un
 * profil ») la partagent, pour que l'aperçu montre exactement ce que l'élève
 * verrait (même cycle servi, mêmes niveaux reconnus, mêmes citations).
 */
export function toMatchCandidate(row: CandidateRow): MatchCandidate {
  const cycle = selectServedCycle(row.cycles ?? []);
  const parsed = parseEligibilityCriteria(row.eligibilityCriteria);
  return {
    scholarship: {
      id: row.id,
      countryId: row.countryId,
      fundingType: row.fundingType,
      eligibleLevels: knownLevels(row.eligibleLevels ?? []),
      fieldsScope: row.fieldsScope,
      relatedFieldIds: row.relatedFieldIds ?? [],
      eligibilityCriteria: row.eligibilityCriteria,
      eligibilityStructuredAt: row.eligibilityStructuredAt,
      deadlineAt: row.deadlineAt,
      cycle: toMatchCycle(cycle),
    },
    display: {
      nameFr: row.nameFr,
      nameEn: row.nameEn,
      countryNameFr: row.countryNameFr,
      countryNameEn: row.countryNameEn,
      typeOfFundingFr: row.typeOfFundingFr,
      typeOfFundingEn: row.typeOfFundingEn,
      levelEligibleFr: row.levelEligibleFr,
      levelEligibleEn: row.levelEligibleEn,
      deadlineLabelFr: row.deadlineLabelFr,
      deadlineLabelEn: row.deadlineLabelEn,
      applicationUrl: row.applicationUrl,
      sourceUrl: row.sourceUrl,
      academicYear: cycle?.academicYear ?? null,
    },
    criteriaByKey: new Map(parsed.criteria.map((criterion) => [criterion.key, criterion])),
  };
}

/**
 * Les options de `readiness()` qui dépendent du catalogue : la question
 * « niveau lycée » n'est utile que si une candidate l'accepte. Partagées par
 * le test élève et l'aperçu admin.
 */
export function snapshotReadinessOptions(snapshot: Pick<CandidateSnapshot, 'candidates'>): {
  hasSecondaryCandidates: boolean;
} {
  return {
    hasSecondaryCandidates: snapshot.candidates.some((candidate) =>
      candidate.scholarship.eligibleLevels.includes('secondary'),
    ),
  };
}

/** Construit l'instantané à partir des lignes lues. Pur : testé sans base. */
export function buildCandidateSnapshot(
  rows: readonly CandidateRow[],
  takenAt: Date,
): CandidateSnapshot {
  const candidates: MatchCandidate[] = rows.map(toMatchCandidate);

  // Ordre stable (par identifiant) : l'empreinte ne dépend pas de l'ordre de lecture.
  const sorted = [...candidates].sort((a, b) =>
    a.scholarship.id < b.scholarship.id ? -1 : a.scholarship.id > b.scholarship.id ? 1 : 0,
  );
  const catalogHash = stableHash({
    algorithmVersion: ALGORITHM_VERSION,
    candidates: sorted.map(({ scholarship: s }) => ({
      id: s.id,
      countryId: s.countryId,
      fundingType: s.fundingType,
      eligibleLevels: s.eligibleLevels,
      fieldsScope: s.fieldsScope,
      relatedFieldIds: [...s.relatedFieldIds].sort(),
      eligibilityCriteria: s.eligibilityCriteria ?? null,
      eligibilityStructuredAt: iso(s.eligibilityStructuredAt),
      deadlineAt: iso(s.deadlineAt),
      cycle: s.cycle
        ? {
            id: s.cycle.id,
            status: s.cycle.status,
            dateConfidence: s.cycle.dateConfidence,
            opensAt: iso(s.cycle.opensAt),
            closesAt: iso(s.cycle.closesAt),
            estimatedOpenAt: iso(s.cycle.estimatedOpenAt),
            estimatedCloseAt: iso(s.cycle.estimatedCloseAt),
          }
        : null,
    })),
  });

  return {
    takenAt,
    candidates,
    byId: new Map(candidates.map((candidate) => [candidate.scholarship.id, candidate])),
    catalogHash,
    capped: rows.length >= MAX_CANDIDATES,
  };
}

@Injectable()
export class CandidateSnapshotService {
  private readonly logger = new Logger(CandidateSnapshotService.name);
  private readonly clock: MatchClock;
  private cached: { snapshot: CandidateSnapshot; expiresAt: number } | null = null;
  /** Une seule lecture en vol : dix requêtes simultanées ne lisent pas dix fois. */
  private inflight: Promise<CandidateSnapshot | null> | null = null;

  constructor(
    private readonly prismaService: PrismaService,
    @Optional() @Inject(MATCH_CLOCK) clock?: MatchClock,
  ) {
    this.clock = clock ?? (() => new Date());
  }

  /** L'instantané courant, ou null sans base de données. */
  async get(): Promise<CandidateSnapshot | null> {
    const now = this.clock();
    if (this.cached && now.getTime() < this.cached.expiresAt) {
      return this.cached.snapshot;
    }
    if (!this.inflight) {
      this.inflight = this.load(now).finally(() => {
        this.inflight = null;
      });
    }
    return this.inflight;
  }

  /** Oublie le cache (tests, ou après une écriture admin qu'on veut voir tout de suite). */
  invalidate(): void {
    this.cached = null;
  }

  /**
   * Un instantané relu à l'instant, SANS passer par le cache ni le remplir :
   * l'aperçu admin (« Tester un profil ») voit tout de suite le critère qu'on
   * vient de tamponner. Même requête, même filtre public, même plafond que
   * `get()`. Lecture seule.
   */
  async readFresh(now: Date = this.clock()): Promise<CandidateSnapshot | null> {
    return this.read(now);
  }

  private async load(now: Date): Promise<CandidateSnapshot | null> {
    const snapshot = await this.read(now);
    if (snapshot) {
      this.cached = { snapshot, expiresAt: now.getTime() + SNAPSHOT_TTL_MS };
    }
    return snapshot;
  }

  private async read(now: Date): Promise<CandidateSnapshot | null> {
    const rows = await this.prismaService.execute((prisma) =>
      prisma.scholarship.findMany({
        where: publicScholarshipWhere(now),
        // Les plus anciennes d'abord, puis l'identifiant : au-delà du plafond,
        // la même coupe à chaque lecture.
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take: MAX_CANDIDATES,
        select: CANDIDATE_SELECT,
      }),
    );
    if (rows === null) return null;
    const snapshot = buildCandidateSnapshot(rows as CandidateRow[], now);
    if (snapshot.capped) {
      this.logger.warn(
        `Scholarship match hit the ${MAX_CANDIDATES}-candidate cap; later scholarships are not analysed.`,
      );
    }
    return snapshot;
  }
}
