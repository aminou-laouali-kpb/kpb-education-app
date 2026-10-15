import { servedCycleStatus } from '../../common/public-scholarship-where';
import { assess, type Assessment, type MatchScholarship, type MatchStatus } from './assess';
import type { MatchProfile } from './match-inputs';
import {
  EXCLUSION_GROUP,
  type ExclusionCode,
  type ExclusionGroup,
  type ReasonCode,
  type ToVerifyCode,
} from './reasons';

/**
 * Pertinence INTERNE (0-100) et composition des « jusqu'à 10 bourses ».
 *
 * La pertinence ne sert qu'à ordonner : elle n'est JAMAIS exposée, ni en
 * pourcentage ni en « chances ». Le budget n'y entre pas (le test ne le
 * demande pas). Tri déterministe à `now` fixé : statut, pertinence, date de
 * clôture la plus proche, puis identifiant.
 */

export const MAX_RESULTS = 10;

/** Au plus N noms par groupe du résumé des bourses écartées. */
export const EXCLUDED_NAMES_PER_GROUP = 20;

/** Points par composante ; la somme des maxima vaut 100. */
export const RELEVANCE_WEIGHTS = {
  field: 30,
  destination: 20,
  funding: 20,
  timing: 15,
  certainty: 15,
} as const;

/** Date de clôture servie (confirmée, sinon estimée, sinon date limite de la fiche). */
export function closingDate(scholarship: MatchScholarship): Date | null {
  return (
    scholarship.cycle?.closesAt ??
    scholarship.cycle?.estimatedCloseAt ??
    scholarship.deadlineAt ??
    null
  );
}

function fieldScore(profile: MatchProfile, scholarship: MatchScholarship): number {
  const w = RELEVANCE_WEIGHTS.field;
  if (scholarship.fieldsScope === 'listed' && scholarship.relatedFieldIds.length > 0) {
    const listed = new Set(scholarship.relatedFieldIds);
    if (profile.fieldIds.some((field) => listed.has(field))) return w;
    return profile.fieldIds.length > 0 ? Math.round(w * 0.1) : Math.round(w * 0.3);
  }
  if (scholarship.fieldsScope === 'all') return Math.round(w * 0.7);
  return Math.round(w * 0.4);
}

function destinationScore(profile: MatchProfile, scholarship: MatchScholarship): number {
  const w = RELEVANCE_WEIGHTS.destination;
  if (profile.targetCountryIds.length === 0) return Math.round(w * 0.5);
  if (profile.targetCountryIds.includes(scholarship.countryId)) return w;
  // `int` : programme multi-pays, peut couvrir une destination visée.
  if (scholarship.countryId === 'int') return Math.round(w * 0.6);
  return Math.round(w * 0.2);
}

function fundingScore(scholarship: MatchScholarship): number {
  const w = RELEVANCE_WEIGHTS.funding;
  if (scholarship.fundingType === 'fully_funded') return w;
  if (scholarship.fundingType === 'partially_funded') return Math.round(w * 0.6);
  return Math.round(w * 0.3);
}

function timingScore(scholarship: MatchScholarship, now: Date): number {
  const w = RELEVANCE_WEIGHTS.timing;
  const cycle = scholarship.cycle;
  if (!cycle) return Math.round(w * 0.4);
  const status = servedCycleStatus(cycle.status, cycle.closesAt, cycle.estimatedCloseAt, now);
  if (status === 'open') {
    return cycle.dateConfidence === 'confirmed' && cycle.closesAt ? w : Math.round(w * 0.8);
  }
  if (status === 'forecast') return Math.round(w * 0.6);
  return Math.round(w * 0.3);
}

/**
 * Les points « à vérifier » qui tiennent au PROFIL de l'élève : une réponse
 * manquante ou non confirmée, une valeur à la limite, une règle que ce profil
 * ne remplit pas mais qui ne peut pas exclure. Eux seuls entament la
 * certitude.
 *
 * Les autres tiennent au CATALOGUE — fiche non relue ou périmée, critère
 * illisible, condition que le test ne pose pas (`condition_other` : liste de
 * pays non reproduite, leadership…), langue autre que l'anglais ou le
 * français, exigence de notes non chiffrée. Ils restent affichés tels quels,
 * mais ne classent pas : sinon une fiche détaillée par KPB en conditions
 * qu'aucun élève ne peut lever passerait derrière des fiches moins
 * pertinentes pour lui, uniquement à cause de la façon dont KPB a structuré
 * ses données. (Mesuré sur le catalogue 1.5.0 : SI Global Professionals,
 * quatre conditions « autres », au-delà des 10 du Sénégalais de 26 ans.)
 */
export const PROFILE_DEPENDENT_TO_VERIFY: ReadonlySet<ToVerifyCode> = new Set<ToVerifyCode>([
  'profile_unconfirmed',
  'level_missing',
  'level_check',
  'nationality_missing',
  'residence_missing',
  'nationality_check',
  'residence_check',
  'age_missing',
  'age_borderline',
  'age_check',
  'experience_missing',
  'experience_borderline',
  'experience_check',
  'language_missing',
  'language_below',
  'grade_missing',
  'grade_below',
  'field_not_listed',
  'field_undecided',
]);

/** Points de certitude retirés par incertitude qui tient au profil. */
export const CERTAINTY_PENALTY_PER_POINT = 4;

function certaintyScore(assessment: Assessment): number {
  const w = RELEVANCE_WEIGHTS.certainty;
  const profileDependent = assessment.toVerify.filter((point) =>
    PROFILE_DEPENDENT_TO_VERIFY.has(point.code),
  ).length;
  return Math.max(0, w - CERTAINTY_PENALTY_PER_POINT * profileDependent);
}

/** Pertinence interne, entier de 0 à 100. */
export function relevance(
  profile: MatchProfile,
  scholarship: MatchScholarship,
  assessment: Assessment,
  now: Date,
): number {
  const total =
    fieldScore(profile, scholarship) +
    destinationScore(profile, scholarship) +
    fundingScore(scholarship) +
    timingScore(scholarship, now) +
    certaintyScore(assessment);
  return Math.max(0, Math.min(100, Math.round(total)));
}

export interface RankedEntry {
  scholarship: MatchScholarship;
  assessment: Assessment;
  relevance: number;
}

const STATUS_ORDER: Record<MatchStatus, number> = {
  eligible: 0,
  to_verify: 1,
  not_eligible: 2,
  suspended: 3,
  not_analyzed: 4,
};

/** Ordre total et déterministe. */
export function compareEntries(a: RankedEntry, b: RankedEntry): number {
  const byStatus = STATUS_ORDER[a.assessment.status] - STATUS_ORDER[b.assessment.status];
  if (byStatus !== 0) return byStatus;
  if (a.relevance !== b.relevance) return b.relevance - a.relevance;
  const closeA = closingDate(a.scholarship)?.getTime() ?? Number.POSITIVE_INFINITY;
  const closeB = closingDate(b.scholarship)?.getTime() ?? Number.POSITIVE_INFINITY;
  if (closeA !== closeB) return closeA < closeB ? -1 : 1;
  return a.scholarship.id < b.scholarship.id ? -1 : a.scholarship.id > b.scholarship.id ? 1 : 0;
}

export type ResultSection = 'compatible' | 'to_verify';

export interface RankedItem {
  scholarshipId: string;
  cycleId: string | null;
  rank: number;
  section: ResultSection;
  status: 'eligible' | 'to_verify';
  relevance: number;
  reasonCodes: ReasonCode[];
  toVerifyCodes: ToVerifyCode[];
}

export interface ExcludedGroupSummary {
  group: ExclusionGroup;
  count: number;
  /** Au plus 20 identifiants, triés. */
  scholarshipIds: string[];
}

export interface ExcludedSummary {
  groups: ExcludedGroupSummary[];
  notAnalyzedCount: number;
}

export interface ComposedRun {
  items: RankedItem[];
  excludedSummary: ExcludedSummary;
  /** Totaux sur TOUTES les candidates, pas seulement les 10 montrées. */
  eligibleCount: number;
  toVerifyCount: number;
  excludedCount: number;
  notAnalyzedCount: number;
  candidateCount: number;
}

const GROUP_PRIORITY: readonly ExclusionGroup[] = [
  'suspended',
  'level',
  'nationality',
  'age',
  'experience',
];

/** Le groupe d'une bourse écartée : le motif le plus structurant. */
function primaryGroup(exclusions: readonly { code: ExclusionCode }[]): ExclusionGroup {
  const groups = exclusions.map((exclusion) => EXCLUSION_GROUP[exclusion.code]);
  return GROUP_PRIORITY.find((group) => groups.includes(group)) ?? 'level';
}

/**
 * Les « jusqu'à 10 bourses » : d'abord les compatibles, puis les « à
 * vérifier », chacune triée par `compareEntries`. Jamais complétée : une
 * bourse `not_eligible`, `suspended` ou `not_analyzed` n'entre JAMAIS dans
 * `items`.
 */
export function composeRun(entries: readonly RankedEntry[], limit = MAX_RESULTS): ComposedRun {
  const sorted = [...entries].sort(compareEntries);
  const shown = sorted.filter(
    (entry) => entry.assessment.status === 'eligible' || entry.assessment.status === 'to_verify',
  );
  const items: RankedItem[] = shown.slice(0, limit).map((entry, index) => ({
    scholarshipId: entry.scholarship.id,
    cycleId: entry.assessment.cycleId,
    rank: index + 1,
    section: entry.assessment.status === 'eligible' ? 'compatible' : 'to_verify',
    status: entry.assessment.status as 'eligible' | 'to_verify',
    relevance: entry.relevance,
    reasonCodes: entry.assessment.reasons.map((point) => point.code),
    toVerifyCodes: entry.assessment.toVerify.map((point) => point.code),
  }));

  const byGroup = new Map<ExclusionGroup, string[]>();
  let notAnalyzedCount = 0;
  for (const entry of sorted) {
    const { status, exclusions } = entry.assessment;
    if (status === 'not_analyzed') {
      notAnalyzedCount += 1;
    } else if (status === 'not_eligible' || status === 'suspended') {
      const group = primaryGroup(exclusions);
      byGroup.set(group, [...(byGroup.get(group) ?? []), entry.scholarship.id]);
    }
  }
  const groups: ExcludedGroupSummary[] = [...byGroup.entries()]
    .map(([group, ids]) => ({
      group,
      count: ids.length,
      scholarshipIds: [...ids].sort().slice(0, EXCLUDED_NAMES_PER_GROUP),
    }))
    .sort(
      (a, b) =>
        b.count - a.count || GROUP_PRIORITY.indexOf(a.group) - GROUP_PRIORITY.indexOf(b.group),
    );

  const count = (status: MatchStatus) =>
    entries.filter((entry) => entry.assessment.status === status).length;
  return {
    items,
    excludedSummary: { groups, notAnalyzedCount },
    eligibleCount: count('eligible'),
    toVerifyCount: count('to_verify'),
    excludedCount: count('not_eligible') + count('suspended'),
    notAnalyzedCount,
    candidateCount: entries.length,
  };
}

/** Le passage complet, pur : évaluer chaque candidate, la noter, composer. */
export function matchScholarships(
  profile: MatchProfile,
  scholarships: readonly MatchScholarship[],
  now: Date,
  limit = MAX_RESULTS,
): ComposedRun & { entries: RankedEntry[] } {
  const entries = scholarships.map((scholarship) => {
    const assessment = assess(profile, scholarship, now);
    return { scholarship, assessment, relevance: relevance(profile, scholarship, assessment, now) };
  });
  return { ...composeRun(entries, limit), entries };
}
