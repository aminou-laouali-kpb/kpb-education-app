import { servedCycleStatus } from '../../common/public-scholarship-where';
import {
  CEFR_LEVELS,
  parseEligibilityCriteria,
  type AcademicGradeCriterion,
  type AgeCriterion,
  type EligibilityCriterion,
  type EligibleLevel,
  type LanguageCriterion,
  type NationalityCriterion,
  type WorkExperienceCriterion,
} from './eligibility-criteria';
import {
  ageOn,
  EXPERIENCE_BAND_MONTHS,
  GRADE_BAND_BOUNDS,
  LANGUAGE_BAND_CEFR,
  type MatchProfile,
} from './match-inputs';
import type {
  ExclusionCode,
  MatchPoint,
  MatchPointParams,
  ReasonCode,
  ToVerifyCode,
} from './reasons';

/**
 * Le moteur d'éligibilité : `assess(profile, scholarship, now)`, fonction PURE.
 *
 * Statuts :
 * - `eligible`      — « Compatible avec ton profil » ;
 * - `to_verify`     — « À vérifier avant de postuler » ;
 * - `not_eligible`  — exclue par une règle dure (jamais dans les résultats) ;
 * - `not_analyzed`  — fiche sans niveaux structurés (jamais montrée, comptée) ;
 * - `suspended`     — cycle suspendu par l'organisme (exclue).
 *
 * Une règle n'exclut QUE si TOUT est réuni :
 * - impact `hard`, et type nationalité / âge / expérience (ou le niveau) ;
 * - `eligibilityStructuredAt` posé et de moins de 400 jours ;
 * - la valeur du profil présente ET confirmée.
 * Sinon l'écart devient un point « à vérifier ». Le domaine, la moyenne, la
 * langue, la destination et le besoin financier n'excluent jamais.
 * Mieux vaut inclure à tort qu'exclure à tort.
 */

export type MatchStatus = 'eligible' | 'to_verify' | 'not_eligible' | 'not_analyzed' | 'suspended';

export const ALGORITHM_VERSION = 'sm-1';

/** Fraîcheur maximale du tampon de structuration pour qu'une règle exclue. */
export const STRUCTURED_FRESHNESS_DAYS = 400;

/** Marge autour d'une limite d'âge dont la date de référence est estimée. */
export const AGE_MARGIN_MONTHS = 12;

const DAY_MS = 24 * 60 * 60 * 1000;

export interface MatchCycle {
  id: string;
  /** Statut EN BASE ; le statut servi est recalculé ici (servedCycleStatus). */
  status: string;
  dateConfidence: 'estimated' | 'confirmed' | string;
  opensAt: Date | null;
  closesAt: Date | null;
  estimatedOpenAt: Date | null;
  estimatedCloseAt: Date | null;
}

export interface MatchScholarship {
  id: string;
  countryId: string;
  fundingType: 'fully_funded' | 'partially_funded' | 'unknown' | string;
  eligibleLevels: readonly EligibleLevel[];
  fieldsScope: 'unknown' | 'all' | 'listed' | string;
  relatedFieldIds: readonly string[];
  /** JSON brut de la colonne : lu par la garde, jamais supposé valide. */
  eligibilityCriteria: unknown;
  eligibilityStructuredAt: Date | null;
  deadlineAt: Date | null;
  /** Le cycle servi (le plus récent), ou null. */
  cycle: MatchCycle | null;
}

export interface Assessment {
  scholarshipId: string;
  cycleId: string | null;
  status: MatchStatus;
  reasons: MatchPoint<ReasonCode>[];
  toVerify: MatchPoint<ToVerifyCode>[];
  exclusions: MatchPoint<ExclusionCode>[];
  /** Critères `informational` : cités sur la fiche, sans effet sur le statut. */
  informationalKeys: string[];
  /** Critères ignorés car invalides (clé ou `#index`). */
  ignoredCriteria: string[];
  /** Tampon frais : les règles dures de cette fiche peuvent exclure. */
  structuredFresh: boolean;
}

/** Résultat d'une règle, en logique à trois valeurs. */
type Outcome<C extends string> =
  | { kind: 'pass'; code?: ReasonCode; params?: MatchPointParams }
  | { kind: 'fail'; code: C; params?: MatchPointParams; checkCode: ToVerifyCode }
  | { kind: 'unknown'; code: ToVerifyCode; params?: MatchPointParams }
  | { kind: 'skip' };

export function isStructuredFresh(stampedAt: Date | null, now: Date): boolean {
  if (!stampedAt || Number.isNaN(stampedAt.getTime())) return false;
  return now.getTime() - stampedAt.getTime() < STRUCTURED_FRESHNESS_DAYS * DAY_MS;
}

function isoDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function addMonths(date: Date, months: number): Date {
  const out = new Date(date.getTime());
  out.setUTCMonth(out.getUTCMonth() + months);
  return out;
}

// ── Nationalité et résidence ────────────────────────────────────────────────

type Tri = 'yes' | 'no' | 'unknown';

function triAnd(a: Tri, b: Tri): Tri {
  if (a === 'no' || b === 'no') return 'no';
  if (a === 'unknown' || b === 'unknown') return 'unknown';
  return 'yes';
}

function triOr(a: Tri, b: Tri): Tri {
  if (a === 'yes' || b === 'yes') return 'yes';
  if (a === 'unknown' || b === 'unknown') return 'unknown';
  return 'no';
}

/** Une des valeurs est-elle listée ? (sémantique « n'importe laquelle ») */
function anyListed(values: readonly string[], listed: ReadonlySet<string>): Tri {
  if (values.length === 0) return 'unknown';
  return values.some((value) => listed.has(value)) ? 'yes' : 'no';
}

function evaluateNationality(
  c: NationalityCriterion,
  profile: MatchProfile,
): Outcome<ExclusionCode> {
  const listed = new Set(c.countries);
  const nat = anyListed(profile.nationalities, listed);
  const res = anyListed(profile.residenceCode ? [profile.residenceCode] : [], listed);
  const hit: Tri =
    c.appliesTo === 'nationality'
      ? nat
      : c.appliesTo === 'residence'
        ? res
        : c.appliesTo === 'nationality_or_residence'
          ? triOr(nat, res)
          : triAnd(nat, res);
  const residenceOnly = c.appliesTo === 'residence';
  const params = { countries: c.countries };

  if (hit === 'unknown') {
    // Il manque la valeur qui aurait tranché.
    const missingNationality = profile.nationalities.length === 0;
    const missingResidence = profile.residenceCode === null;
    const code: ToVerifyCode =
      residenceOnly || (!missingNationality && missingResidence)
        ? 'residence_missing'
        : 'nationality_missing';
    return { kind: 'unknown', code, params };
  }

  if (c.mode === 'include') {
    if (hit === 'yes') {
      // La raison cite le pays qui a fait passer la règle, pas la liste entière.
      const matched =
        !residenceOnly && nat === 'yes'
          ? profile.nationalities.filter((code) => listed.has(code))
          : profile.residenceCode
            ? [profile.residenceCode]
            : [];
      return {
        kind: 'pass',
        code: !residenceOnly && nat === 'yes' ? 'nationality_accepted' : 'residence_accepted',
        params: { countries: matched },
      };
    }
    return {
      kind: 'fail',
      code: residenceOnly ? 'residence_not_listed' : 'nationality_not_listed',
      params,
      checkCode: residenceOnly ? 'residence_check' : 'nationality_check',
    };
  }

  // exclude : échoue si UNE des valeurs est listée.
  if (hit === 'yes') {
    return {
      kind: 'fail',
      code: residenceOnly ? 'residence_excluded' : 'nationality_excluded',
      params,
      checkCode: residenceOnly ? 'residence_check' : 'nationality_check',
    };
  }
  // Une résidence non exclue ne mérite pas de raison affichée.
  return residenceOnly ? { kind: 'pass' } : { kind: 'pass', code: 'nationality_not_excluded' };
}

// ── Âge ─────────────────────────────────────────────────────────────────────

interface AgeReference {
  date: Date;
  /** Vrai pour une date exacte : pas de marge. */
  exact: boolean;
}

function ageReference(c: AgeCriterion, cycle: MatchCycle | null, now: Date): AgeReference {
  const confirmed = cycle?.dateConfidence === 'confirmed';
  switch (c.asOf.kind) {
    case 'date':
      return { date: new Date(`${c.asOf.date}T00:00:00.000Z`), exact: true };
    case 'cycle_close': {
      if (cycle?.closesAt && confirmed) return { date: cycle.closesAt, exact: true };
      const estimated = cycle?.estimatedCloseAt ?? cycle?.closesAt;
      return { date: estimated ?? now, exact: false };
    }
    case 'cycle_open': {
      if (cycle?.opensAt && confirmed) return { date: cycle.opensAt, exact: true };
      const estimated = cycle?.estimatedOpenAt ?? cycle?.opensAt;
      return { date: estimated ?? now, exact: false };
    }
    case 'unspecified':
    default: {
      // Aucune date publiée : on raisonne au moment de la candidature, avec marge.
      const close = cycle?.closesAt ?? cycle?.estimatedCloseAt;
      return { date: close ?? now, exact: false };
    }
  }
}

function ageVerdict(c: AgeCriterion, age: number): 'ok' | 'too_young' | 'too_old' {
  if (c.min !== undefined && age < c.min) return 'too_young';
  if (c.max !== undefined && (c.maxInclusive ? age > c.max : age >= c.max)) return 'too_old';
  return 'ok';
}

function evaluateAge(
  c: AgeCriterion,
  profile: MatchProfile,
  cycle: MatchCycle | null,
  now: Date,
): Outcome<ExclusionCode> {
  const limit: MatchPointParams = {
    ...(c.min !== undefined ? { min: c.min } : {}),
    ...(c.max !== undefined ? { max: c.max, maxInclusive: c.maxInclusive } : {}),
  };
  if (c.level) {
    // Niveau visé inconnu : déjà signalé (« level_missing ») par l'étape niveau.
    if (profile.targetLevel === null) return { kind: 'skip' };
    if (profile.targetLevel !== c.level) return { kind: 'skip' };
  }
  if (!profile.birthDate) return { kind: 'unknown', code: 'age_missing', params: limit };

  const ref = ageReference(c, cycle, now);
  const params: MatchPointParams = {
    ...limit,
    ...(ref.exact ? { asOfDate: isoDay(ref.date) } : {}),
  };
  const age = ageOn(profile.birthDate, ref.date);

  let verdict: 'ok' | 'too_young' | 'too_old';
  if (ref.exact) {
    verdict = ageVerdict(c, age);
  } else {
    // Date estimée ou non précisée : on ne tranche que si la réponse est la
    // même sur toute la fenêtre de ± 12 mois autour de la référence.
    const early = ageVerdict(c, ageOn(profile.birthDate, addMonths(ref.date, -AGE_MARGIN_MONTHS)));
    const late = ageVerdict(c, ageOn(profile.birthDate, addMonths(ref.date, AGE_MARGIN_MONTHS)));
    if (early !== late || early !== ageVerdict(c, age)) {
      return { kind: 'unknown', code: 'age_borderline', params };
    }
    verdict = early;
  }

  if (verdict === 'ok') {
    return { kind: 'pass', code: 'age_within_limit', params: { ...params, age } };
  }
  return {
    kind: 'fail',
    code: verdict === 'too_old' ? 'age_too_old' : 'age_too_young',
    params,
    checkCode: 'age_check',
  };
}

// ── Expérience ──────────────────────────────────────────────────────────────

function evaluateExperience(
  c: WorkExperienceCriterion,
  profile: MatchProfile,
): Outcome<ExclusionCode> {
  const params = { minMonths: c.minMonths };
  if (c.level) {
    // Niveau visé inconnu : déjà signalé (« level_missing ») par l'étape niveau.
    if (profile.targetLevel === null) return { kind: 'skip' };
    if (profile.targetLevel !== c.level) return { kind: 'skip' };
  }
  if (!profile.workExperienceBand) {
    return { kind: 'unknown', code: 'experience_missing', params };
  }
  const [low, high] = EXPERIENCE_BAND_MONTHS[profile.workExperienceBand];
  if (low >= c.minMonths) return { kind: 'pass', code: 'experience_sufficient', params };
  if (high < c.minMonths) {
    return { kind: 'fail', code: 'experience_insufficient', params, checkCode: 'experience_check' };
  }
  // La tranche chevauche le minimum.
  return { kind: 'unknown', code: 'experience_borderline', params };
}

// ── Langue, moyenne (jamais d'exclusion) ────────────────────────────────────

function evaluateLanguage(c: LanguageCriterion, profile: MatchProfile): Outcome<never> {
  const params: MatchPointParams = {
    lang: c.lang,
    ...(c.minCefr ? { minCefr: c.minCefr } : {}),
    ...(c.tests ? { tests: c.tests.map((test) => `${test.type} ${test.min}`) } : {}),
    waivable: c.waivable,
  };
  if (c.lang !== 'en' && c.lang !== 'fr') {
    return { kind: 'unknown', code: 'language_other', params };
  }
  // Un score officiel suffisant l'emporte.
  const scored = (c.tests ?? []).some((test) =>
    profile.languageTests.some((taken) => taken.type === test.type && taken.score >= test.min),
  );
  if (scored) return { kind: 'pass', code: 'language_sufficient', params };

  const band = c.lang === 'en' ? profile.englishLevel : profile.frenchLevel;
  if (c.minCefr) {
    if (!band) return { kind: 'unknown', code: 'language_missing', params };
    const [low] = LANGUAGE_BAND_CEFR[band];
    const required = CEFR_LEVELS.indexOf(c.minCefr) + 1;
    if (low >= required) return { kind: 'pass', code: 'language_sufficient', params };
    return { kind: 'unknown', code: 'language_below', params };
  }
  // Seuls des scores sont demandés et l'élève n'en a pas indiqué de suffisant.
  const hasScoreForListed = (c.tests ?? []).some((test) =>
    profile.languageTests.some((taken) => taken.type === test.type),
  );
  return {
    kind: 'unknown',
    code: hasScoreForListed ? 'language_below' : 'language_missing',
    params,
  };
}

function evaluateGrade(c: AcademicGradeCriterion, profile: MatchProfile): Outcome<never> {
  if (c.minOn20 === undefined) return { kind: 'unknown', code: 'grade_check' };
  const params = { minOn20: c.minOn20 };
  if (!profile.gradeBand) return { kind: 'unknown', code: 'grade_missing', params };
  const [low] = GRADE_BAND_BOUNDS[profile.gradeBand];
  if (low >= c.minOn20) return { kind: 'pass', code: 'grade_sufficient', params };
  return { kind: 'unknown', code: 'grade_below', params };
}

function evaluateCriterion(
  c: EligibilityCriterion,
  profile: MatchProfile,
  cycle: MatchCycle | null,
  now: Date,
): Outcome<ExclusionCode> {
  switch (c.type) {
    case 'nationality':
      return evaluateNationality(c, profile);
    case 'age':
      return evaluateAge(c, profile, cycle, now);
    case 'work_experience':
      return evaluateExperience(c, profile);
    case 'language':
      return evaluateLanguage(c, profile);
    case 'academic_grade':
      return evaluateGrade(c, profile);
    case 'other':
      return { kind: 'unknown', code: 'condition_other' };
    case 'financial_need':
    default:
      return { kind: 'skip' };
  }
}

/** Seuls ces types peuvent exclure, et seulement en impact `hard`. */
const EXCLUDING_TYPES = new Set(['nationality', 'age', 'work_experience']);

// ── Évaluation d'une fiche ──────────────────────────────────────────────────

export function assess(
  profile: MatchProfile,
  scholarship: MatchScholarship,
  now: Date,
): Assessment {
  const cycle = scholarship.cycle;
  const result: Assessment = {
    scholarshipId: scholarship.id,
    cycleId: cycle?.id ?? null,
    status: 'to_verify',
    reasons: [],
    toVerify: [],
    exclusions: [],
    informationalKeys: [],
    ignoredCriteria: [],
    structuredFresh: isStructuredFresh(scholarship.eligibilityStructuredAt, now),
  };

  // 1. Cycle suspendu par l'organisme : exclue, quoi que dise le reste.
  if (
    cycle &&
    servedCycleStatus(cycle.status, cycle.closesAt, cycle.estimatedCloseAt, now) === 'suspended'
  ) {
    result.status = 'suspended';
    result.exclusions.push({ code: 'suspended' });
    return result;
  }

  // 2. Aucun niveau structuré : fiche non analysée, jamais montrée.
  if (scholarship.eligibleLevels.length === 0) {
    result.status = 'not_analyzed';
    return result;
  }

  const fresh = result.structuredFresh;
  const canExclude = (hard: boolean) => hard && fresh && profile.confirmed;
  let blockedByProfile = false;

  // 3. Niveau visé — gardé lui aussi par le tampon : un niveau repris des
  // tags et jamais relu n'exclut personne.
  const levels = [...scholarship.eligibleLevels];
  if (profile.targetLevel === null) {
    result.toVerify.push({ code: 'level_missing' });
  } else if (levels.includes(profile.targetLevel)) {
    result.reasons.push({ code: 'level_accepted', params: { level: profile.targetLevel } });
  } else if (canExclude(true)) {
    result.exclusions.push({ code: 'level_other', params: { levels } });
  } else {
    if (fresh && !profile.confirmed) blockedByProfile = true;
    result.toVerify.push({ code: 'level_check', params: { levels } });
  }

  // 4. Critères structurés. Un critère invalide est ignoré, jamais excluant.
  const parsed = parseEligibilityCriteria(scholarship.eligibilityCriteria);
  result.ignoredCriteria = parsed.ignoredKeys;
  for (const criterion of parsed.criteria) {
    if (criterion.impact === 'informational') {
      result.informationalKeys.push(criterion.key);
      continue;
    }
    const outcome = evaluateCriterion(criterion, profile, cycle, now);
    const criterionKey = criterion.key;
    switch (outcome.kind) {
      case 'skip':
        break;
      case 'pass':
        if (outcome.code) {
          result.reasons.push({
            code: outcome.code,
            criterionKey,
            ...(outcome.params ? { params: outcome.params } : {}),
          });
        }
        break;
      case 'unknown':
        result.toVerify.push({
          code: outcome.code,
          criterionKey,
          ...(outcome.params ? { params: outcome.params } : {}),
        });
        break;
      case 'fail': {
        const hard = criterion.impact === 'hard' && EXCLUDING_TYPES.has(criterion.type);
        if (canExclude(hard)) {
          result.exclusions.push({
            code: outcome.code,
            criterionKey,
            ...(outcome.params ? { params: outcome.params } : {}),
          });
        } else {
          if (hard && fresh && !profile.confirmed) blockedByProfile = true;
          result.toVerify.push({
            code: outcome.checkCode,
            criterionKey,
            ...(outcome.params ? { params: outcome.params } : {}),
          });
        }
        break;
      }
    }
  }

  // 5. Domaines (jamais d'exclusion).
  if (scholarship.fieldsScope === 'all') {
    result.reasons.push({ code: 'fields_all' });
  } else if (scholarship.fieldsScope === 'listed' && scholarship.relatedFieldIds.length > 0) {
    const listed = new Set(scholarship.relatedFieldIds);
    if (profile.fieldIds.some((field) => listed.has(field))) {
      result.reasons.push({ code: 'field_listed' });
    } else if (profile.fieldIds.length > 0) {
      result.toVerify.push({ code: 'field_not_listed' });
    } else {
      result.toVerify.push({ code: 'field_undecided' });
    }
  }

  // 6. Destination : une préférence, jamais une condition (pertinence seulement).
  if (profile.targetCountryIds.includes(scholarship.countryId)) {
    result.reasons.push({ code: 'destination_wanted', params: { countries: [scholarship.countryId] } });
  }

  // 7. Ce qui plafonne à « à vérifier » : données KPB absentes, périmées ou
  // incomplètes, critère illisible, réponse non confirmée qui a bloqué une
  // exclusion.
  if (!scholarship.eligibilityStructuredAt) {
    result.toVerify.unshift({ code: 'eligibility_not_structured' });
  } else if (!fresh) {
    result.toVerify.unshift({ code: 'eligibility_stale' });
  } else if (parsed.criteria.length === 0) {
    result.toVerify.unshift({ code: 'criteria_not_structured' });
  }
  if (parsed.ignoredKeys.length > 0) result.toVerify.push({ code: 'criterion_unreadable' });
  if (blockedByProfile) result.toVerify.push({ code: 'profile_unconfirmed' });

  if (result.exclusions.length > 0) {
    result.status = 'not_eligible';
  } else if (result.toVerify.length > 0) {
    result.status = 'to_verify';
  } else {
    result.status = 'eligible';
  }
  return result;
}
