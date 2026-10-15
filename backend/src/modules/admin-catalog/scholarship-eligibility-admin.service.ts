import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { ISO_COUNTRIES, isSelectableCountryCode } from '../../common/iso-countries';
import { publicScholarshipWhere } from '../../common/public-scholarship-where';
import { PrismaService } from '../prisma/prisma.service';
import {
  ALGORITHM_VERSION,
  STRUCTURED_FRESHNESS_DAYS,
  type Assessment,
} from '../scholarship-match/assess';
import {
  CANDIDATE_SELECT,
  CandidateSnapshotService,
  MAX_CANDIDATES,
  snapshotReadinessOptions,
  toMatchCandidate,
  type CandidateRow,
  type MatchCandidate,
} from '../scholarship-match/candidate-snapshot';
import {
  normaliseCountryAnswer,
  normaliseResidence,
  PRIORITY_COUNTRY_CODES,
  type MatchLang,
} from '../scholarship-match/countries';
import {
  ageOn,
  DIPLOMAS,
  EXPERIENCE_BANDS,
  GRADE_BANDS,
  LANGUAGE_BANDS,
  normaliseProfile,
  parseLanguageTests,
  readiness,
  TARGET_LEVELS,
  type MatchProfile,
  type MatchProfileSource,
} from '../scholarship-match/match-inputs';
import { matchScholarships, MAX_RESULTS, type ExcludedSummary } from '../scholarship-match/rank';
import { renderPoint, type MatchPoint } from '../scholarship-match/reasons';
import { MatchPreviewDto } from './dto/match-preview.dto';
import {
  LAUNCH_GATE_PERCENT,
  summarizeCoverage,
  type EligibilityCoverage,
} from './scholarship-eligibility-admin';

/**
 * Le back-office de l'éligibilité structurée (chantier D4) : couverture du
 * catalogue public (la porte de lancement), aperçu du moteur pour un profil
 * saisi par l'admin (« Tester un profil », SANS RIEN PERSISTER) et liste des
 * pays servie à l'éditeur de critères.
 *
 * Le moteur est celui de `scholarship-match/` (assess, rank, reasons), réutilisé
 * tel quel, et les candidates sont lues par `CandidateSnapshotService` — même
 * filtre public, même plafond, même ordre de coupe, même cycle servi et même
 * conversion (`toMatchCandidate`) que le test élève : l'aperçu montre
 * exactement ce que l'élève verrait. Seule différence voulue : l'aperçu relit
 * le catalogue (`readFresh`) au lieu du cache de 60 s, pour qu'un critère
 * tamponné à l'instant s'y voie tout de suite.
 */

/** Plafond des candidates lues pour un aperçu : celui du test élève. */
export const PREVIEW_MAX_CANDIDATES = MAX_CANDIDATES;

// ── Aperçu : entrée ─────────────────────────────────────────────────────────

function isoDate(value: string | undefined): Date | null {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value
    ? date
    : null;
}

/** Le profil de l'aperçu, au format lu par le moteur. Confirmé par défaut. */
export function previewProfileSource(dto: MatchPreviewDto, now: Date): MatchProfileSource {
  return {
    nationalityCode: dto.nationalityCode ?? null,
    secondNationalityCode: dto.secondNationalityCode ?? null,
    countryOfResidence: dto.countryOfResidence ?? null,
    birthDate: isoDate(dto.birthDate),
    guardianConsentedAt: dto.guardianConsented ? now : null,
    highestDiploma: dto.highestDiploma ?? null,
    scholarshipTargetLevel: dto.scholarshipTargetLevel ?? null,
    fieldIds: dto.fieldIds ?? [],
    targetCountryIds: dto.targetCountryIds ?? [],
    gradeBandOn20: dto.gradeBandOn20 ?? null,
    englishLevel: dto.englishLevel ?? null,
    frenchLevel: dto.frenchLevel ?? null,
    languageTests: dto.languageTests ?? [],
    workExperienceBand: dto.workExperienceBand ?? null,
    scholarshipProfileConfirmedAt: dto.confirmed === false ? null : now,
  };
}

/**
 * Les clés saisies dont la valeur a été ABANDONNÉE par la normalisation
 * (jeton inconnu, pays introuvable, date impossible) : l'admin voit ce que le
 * moteur n'a pas pu lire, au lieu d'un résultat silencieusement différent.
 */
export function droppedPreviewKeys(dto: MatchPreviewDto): string[] {
  const dropped: string[] = [];
  const filled = (value: string | undefined): value is string =>
    typeof value === 'string' && value.trim() !== '';
  const token = (key: keyof MatchPreviewDto, values: readonly string[]) => {
    const value = dto[key];
    if (typeof value === 'string' && filled(value) && !values.includes(value)) dropped.push(key);
  };
  if (filled(dto.nationalityCode) && normaliseCountryAnswer(dto.nationalityCode) === null) {
    dropped.push('nationalityCode');
  }
  if (
    filled(dto.secondNationalityCode) &&
    normaliseCountryAnswer(dto.secondNationalityCode) === null
  ) {
    dropped.push('secondNationalityCode');
  }
  if (filled(dto.countryOfResidence) && normaliseResidence(dto.countryOfResidence) === null) {
    dropped.push('countryOfResidence');
  }
  if (filled(dto.birthDate) && isoDate(dto.birthDate) === null) dropped.push('birthDate');
  token('highestDiploma', DIPLOMAS);
  token('scholarshipTargetLevel', TARGET_LEVELS);
  token('gradeBandOn20', GRADE_BANDS);
  token('englishLevel', LANGUAGE_BANDS);
  token('frenchLevel', LANGUAGE_BANDS);
  token('workExperienceBand', EXPERIENCE_BANDS);
  if (
    Array.isArray(dto.languageTests) &&
    parseLanguageTests(dto.languageTests).length < dto.languageTests.length
  ) {
    dropped.push('languageTests');
  }
  return dropped;
}

// ── Aperçu : sortie ─────────────────────────────────────────────────────────

export interface PreviewPoint {
  code: string;
  /** Libellé KPB rendu par le serveur (reasons.ts). */
  label: string;
  criterionKey?: string;
  /** Citation officielle du critère d'origine, dans la langue demandée. */
  officialText?: string;
  sourceUrl?: string;
}

export interface PreviewEntry {
  scholarshipId: string;
  name: string;
  status: Assessment['status'];
  cycleId: string | null;
  structuredFresh: boolean;
  reasons: PreviewPoint[];
  toVerify: PreviewPoint[];
  exclusions: PreviewPoint[];
  /** Critères stockés illisibles, ignorés par le moteur. */
  ignoredCriteria: string[];
}

export interface MatchPreviewResponse {
  /** Toujours faux : l'aperçu n'écrit rien (ni profil, ni run). */
  persisted: false;
  algorithmVersion: string;
  generatedAt: string;
  lang: MatchLang;
  profile: {
    nationalities: string[];
    residenceCode: string | null;
    targetLevel: string | null;
    age: number | null;
    confirmed: boolean;
  };
  dropped: string[];
  readiness: { ready: boolean; required: string[]; toConfirm: string[] };
  counts: {
    candidateCount: number;
    eligibleCount: number;
    toVerifyCount: number;
    excludedCount: number;
    notAnalyzedCount: number;
  };
  /** Les « jusqu'à 10 bourses », comme l'élève les verrait. */
  items: Array<PreviewEntry & { rank: number; section: 'compatible' | 'to_verify' }>;
  /** Compatibles ou à vérifier au-delà des 10 montrées. */
  beyondLimitCount: number;
  /** Bourses écartées (non éligibles ou suspendues), avec leurs motifs. */
  excluded: PreviewEntry[];
  excludedSummary: ExcludedSummary;
  notAnalyzed: Array<{ scholarshipId: string; name: string }>;
  /** La bourse demandée par `focusScholarshipId`, publique ou non. */
  focus: { public: boolean; entry: PreviewEntry } | null;
}

function renderPoints(
  points: readonly MatchPoint[],
  candidate: MatchCandidate,
  lang: MatchLang,
): PreviewPoint[] {
  return points.map((point) => {
    const criterion = point.criterionKey
      ? candidate.criteriaByKey.get(point.criterionKey)
      : undefined;
    return {
      code: point.code,
      label: renderPoint(point, lang),
      ...(point.criterionKey ? { criterionKey: point.criterionKey } : {}),
      ...(criterion
        ? {
            officialText: lang === 'en' ? criterion.officialTextEn : criterion.officialTextFr,
            sourceUrl: criterion.sourceUrl,
          }
        : {}),
    };
  });
}

function nameOf(candidate: MatchCandidate, lang: MatchLang): string {
  return lang === 'en' ? candidate.display.nameEn : candidate.display.nameFr;
}

function toEntry(
  candidate: MatchCandidate,
  assessment: Assessment,
  lang: MatchLang,
): PreviewEntry {
  return {
    scholarshipId: candidate.scholarship.id,
    name: nameOf(candidate, lang),
    status: assessment.status,
    cycleId: assessment.cycleId,
    structuredFresh: assessment.structuredFresh,
    reasons: renderPoints(assessment.reasons, candidate, lang),
    toVerify: renderPoints(assessment.toVerify, candidate, lang),
    exclusions: renderPoints(assessment.exclusions, candidate, lang),
    ignoredCriteria: assessment.ignoredCriteria,
  };
}

/** L'aperçu complet, PUR : mêmes entrées, même sortie (à `now` fixé). */
export function buildMatchPreview(
  dto: MatchPreviewDto,
  candidates: readonly MatchCandidate[],
  focus: { candidate: MatchCandidate; public: boolean } | null,
  now: Date,
): MatchPreviewResponse {
  const lang: MatchLang = dto.lang === 'en' ? 'en' : 'fr';
  const profile: MatchProfile = normaliseProfile(previewProfileSource(dto, now));
  const byId = new Map(candidates.map((candidate) => [candidate.scholarship.id, candidate]));
  const run = matchScholarships(
    profile,
    candidates.map((candidate) => candidate.scholarship),
    now,
  );
  const assessments = new Map(
    run.entries.map((entry) => [entry.scholarship.id, entry.assessment]),
  );
  const entryOf = (id: string) => toEntry(byId.get(id)!, assessments.get(id)!, lang);

  const sorted = [...run.entries].sort((a, b) =>
    a.scholarship.id < b.scholarship.id ? -1 : a.scholarship.id > b.scholarship.id ? 1 : 0,
  );
  // Mêmes options que le test élève (question « lycée » selon le catalogue).
  const ready = readiness(profile, now, snapshotReadinessOptions({ candidates }));

  let focusOut: MatchPreviewResponse['focus'] = null;
  if (focus) {
    const assessment =
      assessments.get(focus.candidate.scholarship.id) ??
      matchScholarships(profile, [focus.candidate.scholarship], now).entries[0].assessment;
    focusOut = { public: focus.public, entry: toEntry(focus.candidate, assessment, lang) };
  }

  return {
    persisted: false,
    algorithmVersion: ALGORITHM_VERSION,
    generatedAt: now.toISOString(),
    lang,
    profile: {
      nationalities: profile.nationalities,
      residenceCode: profile.residenceCode,
      targetLevel: profile.targetLevel,
      age: profile.birthDate ? ageOn(profile.birthDate, now) : null,
      confirmed: profile.confirmed,
    },
    dropped: droppedPreviewKeys(dto),
    readiness: { ready: ready.ready, required: ready.required, toConfirm: ready.toConfirm },
    counts: {
      candidateCount: run.candidateCount,
      eligibleCount: run.eligibleCount,
      toVerifyCount: run.toVerifyCount,
      excludedCount: run.excludedCount,
      notAnalyzedCount: run.notAnalyzedCount,
    },
    items: run.items.map((item) => ({
      ...entryOf(item.scholarshipId),
      rank: item.rank,
      section: item.section,
    })),
    beyondLimitCount: Math.max(0, run.eligibleCount + run.toVerifyCount - run.items.length),
    excluded: sorted
      .filter(
        (entry) =>
          entry.assessment.status === 'not_eligible' || entry.assessment.status === 'suspended',
      )
      .map((entry) => entryOf(entry.scholarship.id)),
    excludedSummary: run.excludedSummary,
    notAnalyzed: sorted
      .filter((entry) => entry.assessment.status === 'not_analyzed')
      .map((entry) => {
        return {
          scholarshipId: entry.scholarship.id,
          name: nameOf(byId.get(entry.scholarship.id)!, lang),
        };
      }),
    focus: focusOut,
  };
}

// ── Pays servis à l'éditeur ─────────────────────────────────────────────────

export interface EligibilityCountryOption {
  code: string;
  nameFr: string;
  nameEn: string;
  /** Afrique francophone en tête (même groupe que le test élève). */
  priority: boolean;
  /** Territoire inhabité : valide dans un critère, jamais proposé à l'élève. */
  selectable: boolean;
}

export interface EligibilityOptionsResponse {
  countries: EligibilityCountryOption[];
  freshnessDays: number;
  launchGatePercent: number;
  maxResults: number;
}

/**
 * La table ISO 3166-1 du serveur (`common/iso-countries.ts`), servie telle
 * quelle : l'admin ne tient pas sa propre copie. Groupe de tête d'abord, puis
 * ordre alphabétique français.
 */
export function eligibilityOptions(): EligibilityOptionsResponse {
  const priority = new Set(PRIORITY_COUNTRY_CODES);
  const collator = new Intl.Collator('fr', { sensitivity: 'base' });
  const countries = ISO_COUNTRIES.map((country) => ({
    code: country.code,
    nameFr: country.nameFr,
    nameEn: country.nameEn,
    priority: priority.has(country.code),
    selectable: isSelectableCountryCode(country.code),
  })).sort((a, b) => {
    if (a.priority !== b.priority) return a.priority ? -1 : 1;
    if (a.priority) {
      return PRIORITY_COUNTRY_CODES.indexOf(a.code) - PRIORITY_COUNTRY_CODES.indexOf(b.code);
    }
    return collator.compare(a.nameFr, b.nameFr) || a.code.localeCompare(b.code);
  });
  return {
    countries,
    freshnessDays: STRUCTURED_FRESHNESS_DAYS,
    launchGatePercent: LAUNCH_GATE_PERCENT,
    maxResults: MAX_RESULTS,
  };
}

@Injectable()
export class ScholarshipEligibilityAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly snapshots: CandidateSnapshotService,
  ) {}

  private assertDb() {
    if (!this.prisma.isEnabled) {
      throw new ServiceUnavailableException('Database is not configured. Set DATABASE_URL.');
    }
  }

  /** Couverture des bourses PUBLIQUES (publicScholarshipWhere) : la porte de lancement. */
  async coverage(now: Date = new Date()): Promise<EligibilityCoverage> {
    this.assertDb();
    const rows = await this.prisma.execute((db) =>
      db.scholarship.findMany({
        where: publicScholarshipWhere(now),
        select: {
          id: true,
          nameFr: true,
          nameEn: true,
          eligibleLevels: true,
          eligibilityCriteria: true,
          eligibilityStructuredAt: true,
          eligibilityStructuredBy: true,
        },
        orderBy: { id: 'asc' },
      }),
    );
    return summarizeCoverage(rows ?? [], now);
  }

  options(): EligibilityOptionsResponse {
    return eligibilityOptions();
  }

  /**
   * « Tester un profil » : le moteur sur les bourses publiques, pour un profil
   * saisi par l'admin. LECTURE SEULE — aucun profil, aucun run, aucune
   * notification n'est écrit.
   */
  async matchPreview(dto: MatchPreviewDto, now: Date = new Date()): Promise<MatchPreviewResponse> {
    this.assertDb();
    const snapshot = await this.snapshots.readFresh(now);
    const candidates = snapshot?.candidates ?? [];

    let focus: { candidate: MatchCandidate; public: boolean } | null = null;
    const focusId = dto.focusScholarshipId?.trim();
    if (focusId) {
      const inPublic = snapshot?.byId.get(focusId);
      if (inPublic) {
        focus = { candidate: inPublic, public: true };
      } else {
        const row = await this.prisma.execute((db) =>
          db.scholarship.findUnique({ where: { id: focusId }, select: CANDIDATE_SELECT }),
        );
        if (row) focus = { candidate: toMatchCandidate(row as CandidateRow), public: false };
      }
    }
    return buildMatchPreview(dto, candidates, focus, now);
  }
}
