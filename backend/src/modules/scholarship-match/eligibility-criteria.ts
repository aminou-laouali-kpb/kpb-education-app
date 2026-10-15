import { isIsoCountryCode } from '../../common/iso-countries';

/**
 * Critères d'éligibilité structurés, version 1 (`Scholarship.eligibilityCriteria`).
 *
 * Un tableau JSON typé, vérifié par des gardes écrites à la main (pas de
 * class-validator : la même vérification sert au moteur, à l'admin et au
 * validateur du catalogue, hors de tout DTO).
 *
 * Règle d'or : un critère invalide est IGNORÉ et signalé, jamais excluant.
 * `parseEligibilityCriteria` ne lève jamais ; `validateEligibilityCriteria`
 * rend la liste des erreurs de forme pour l'admin et le catalogue.
 *
 * Codes pays : ISO 3166-1 alpha-3 minuscule, comme `Scholarship.countryId`.
 */

export const ELIGIBLE_LEVELS = [
  'secondary',
  'bachelor',
  'master',
  'doctorate',
] as const;
export type EligibleLevel = (typeof ELIGIBLE_LEVELS)[number];

export const CRITERION_TYPES = [
  'nationality',
  'age',
  'work_experience',
  'language',
  'academic_grade',
  'financial_need',
  'other',
] as const;
export type CriterionType = (typeof CRITERION_TYPES)[number];

/**
 * - `hard` : peut exclure (nationalité, âge, expérience seulement, et à des
 *   conditions strictes — voir assess.ts) ;
 * - `soft` : un écart donne « à vérifier », jamais une exclusion ;
 * - `informational` : citée, sans effet sur le statut.
 */
export const CRITERION_IMPACTS = ['hard', 'soft', 'informational'] as const;
export type CriterionImpact = (typeof CRITERION_IMPACTS)[number];

export const NATIONALITY_APPLIES_TO = [
  'nationality',
  'residence',
  'nationality_or_residence',
  'nationality_and_residence',
] as const;
export type NationalityAppliesTo = (typeof NATIONALITY_APPLIES_TO)[number];

export const NATIONALITY_MODES = ['include', 'exclude'] as const;
export type NationalityMode = (typeof NATIONALITY_MODES)[number];

export const CEFR_LEVELS = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'] as const;
export type CefrLevel = (typeof CEFR_LEVELS)[number];

/** Tests de langue reconnus, avec l'échelle de leur score. */
export const LANGUAGE_TEST_SCALES = {
  ielts: { min: 0, max: 9 },
  toefl_ibt: { min: 0, max: 120 },
  duolingo: { min: 10, max: 160 },
  tcf: { min: 100, max: 699 },
  tef: { min: 0, max: 699 },
} as const;
export type LanguageTestType = keyof typeof LANGUAGE_TEST_SCALES;
export const LANGUAGE_TEST_TYPES = Object.keys(
  LANGUAGE_TEST_SCALES,
) as LanguageTestType[];

export type AgeAsOf =
  | { kind: 'date'; date: string }
  | { kind: 'cycle_close' }
  | { kind: 'cycle_open' }
  | { kind: 'unspecified' };

interface CriterionBase {
  /** Identifiant stable, unique dans la fiche (slug). */
  key: string;
  impact: CriterionImpact;
  /** Citation exacte de la page officielle (exemptée de l'invariant « % »). */
  officialTextFr: string;
  officialTextEn: string;
  sourceUrl: string;
}

/**
 * Sémantique « n'importe laquelle » (écrite et testée) :
 * - `include` passe si UNE des nationalités de l'élève est listée ;
 * - `exclude` échoue si UNE d'elles est listée (Eiffel exclut les
 *   binationaux français, la Türkiye exclut tout citoyen turc).
 * `nationality_or_residence` : nationalité OU résidence ;
 * `nationality_and_residence` : nationalité ET résidence.
 */
export interface NationalityCriterion extends CriterionBase {
  type: 'nationality';
  appliesTo: NationalityAppliesTo;
  mode: NationalityMode;
  countries: string[];
}

export interface AgeCriterion extends CriterionBase {
  type: 'age';
  /** Limite propre à un niveau (Türkiye : < 21 en Licence, < 30 en Master). */
  level?: EligibleLevel;
  /** Âge minimal, inclus (« 16 ans au moins »). */
  min?: number;
  /** Âge maximal ; inclus si `maxInclusive` (« 29 ans au plus »), sinon exclu (« moins de 30 ans »). */
  max?: number;
  maxInclusive: boolean;
  asOf: AgeAsOf;
}

export interface WorkExperienceCriterion extends CriterionBase {
  type: 'work_experience';
  level?: EligibleLevel;
  minMonths: number;
}

export interface LanguageCriterion extends CriterionBase {
  type: 'language';
  /** ISO 639-1 (`en`, `fr`, `de`…). Seuls `en` et `fr` se comparent au profil. */
  lang: string;
  minCefr?: CefrLevel;
  tests?: Array<{ type: LanguageTestType; min: number }>;
  /** L'organisme peut lever l'exigence (diplôme antérieur dans la langue…). */
  waivable: boolean;
}

export interface AcademicGradeCriterion extends CriterionBase {
  type: 'academic_grade';
  /** Moyenne minimale sur 20, quand la règle s'y ramène sans ambiguïté. */
  minOn20?: number;
  /** La règle telle que publiée (« 70 % en Licence »). Toujours gardée. */
  rawText: string;
}

export interface FinancialNeedCriterion extends CriterionBase {
  type: 'financial_need';
}

export interface OtherCriterion extends CriterionBase {
  type: 'other';
}

export type EligibilityCriterion =
  | NationalityCriterion
  | AgeCriterion
  | WorkExperienceCriterion
  | LanguageCriterion
  | AcademicGradeCriterion
  | FinancialNeedCriterion
  | OtherCriterion;

export interface CriterionIssue {
  /** Chemin JSON, par exemple `[2].countries[0]`. */
  path: string;
  code: string;
  message: string;
}

export interface ParsedEligibilityCriteria {
  criteria: EligibilityCriterion[];
  /** Erreurs de forme : chaque critère concerné a été IGNORÉ. */
  issues: CriterionIssue[];
  /** Clés (ou index) des critères ignorés. */
  ignoredKeys: string[];
}

const KEY_PATTERN = /^[a-z0-9]+(?:[_-][a-z0-9]+)*$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const LANG_PATTERN = /^[a-z]{2}$/;
const MAX_CRITERIA = 40;
const MAX_TEXT = 2_000;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isNonBlank(value: unknown, max = MAX_TEXT): value is string {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= max;
}

function isOneOf<T extends string>(
  values: readonly T[],
  value: unknown,
): value is T {
  return typeof value === 'string' && (values as readonly string[]).includes(value);
}

function isAge(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= 120;
}

function isHttpUrl(value: unknown): value is string {
  if (typeof value !== 'string' || value.length > MAX_TEXT) return false;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

function isValidIsoDate(value: unknown): value is string {
  if (typeof value !== 'string' || !DATE_PATTERN.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

/**
 * Vérifie UN critère. Rend le critère typé (copie sans champ superflu) ou les
 * erreurs qui le font ignorer.
 */
export function checkCriterion(
  raw: unknown,
  index: number,
): { criterion: EligibilityCriterion | null; issues: CriterionIssue[] } {
  const root = `[${index}]`;
  const issues: CriterionIssue[] = [];
  const push = (path: string, code: string, message: string) =>
    issues.push({ path: `${root}${path}`, code, message });

  if (!isRecord(raw)) {
    push('', 'not_object', 'Un critère est un objet.');
    return { criterion: null, issues };
  }

  if (!isOneOf(CRITERION_TYPES, raw.type)) {
    push('.type', 'unknown_type', `Type inconnu : ${String(raw.type)}.`);
  }
  if (typeof raw.key !== 'string' || !KEY_PATTERN.test(raw.key) || raw.key.length > 64) {
    push('.key', 'invalid_key', 'Clé attendue : slug minuscule stable (64 caractères au plus).');
  }
  if (!isOneOf(CRITERION_IMPACTS, raw.impact)) {
    push('.impact', 'invalid_impact', "Impact attendu : 'hard', 'soft' ou 'informational'.");
  }
  if (!isNonBlank(raw.officialTextFr)) {
    push('.officialTextFr', 'missing_official_text', 'Citation officielle FR obligatoire.');
  }
  if (!isNonBlank(raw.officialTextEn)) {
    push('.officialTextEn', 'missing_official_text', 'Citation officielle EN obligatoire.');
  }
  if (!isHttpUrl(raw.sourceUrl)) {
    push('.sourceUrl', 'invalid_source_url', 'URL source http(s) obligatoire.');
  }
  if (issues.length > 0 && !isOneOf(CRITERION_TYPES, raw.type)) {
    return { criterion: null, issues };
  }

  const base = {
    key: raw.key as string,
    impact: raw.impact as CriterionImpact,
    officialTextFr: raw.officialTextFr as string,
    officialTextEn: raw.officialTextEn as string,
    sourceUrl: raw.sourceUrl as string,
  };
  const checkLevel = (): EligibleLevel | undefined => {
    if (raw.level === undefined || raw.level === null) return undefined;
    if (!isOneOf(ELIGIBLE_LEVELS, raw.level)) {
      push('.level', 'invalid_level', `Niveau inconnu : ${String(raw.level)}.`);
      return undefined;
    }
    return raw.level;
  };

  let criterion: EligibilityCriterion | null = null;
  switch (raw.type as CriterionType) {
    case 'nationality': {
      if (!isOneOf(NATIONALITY_APPLIES_TO, raw.appliesTo)) {
        push('.appliesTo', 'invalid_applies_to', 'appliesTo inconnu.');
      }
      if (!isOneOf(NATIONALITY_MODES, raw.mode)) {
        push('.mode', 'invalid_mode', "mode attendu : 'include' ou 'exclude'.");
      }
      const countries: string[] = [];
      if (!Array.isArray(raw.countries) || raw.countries.length === 0) {
        push('.countries', 'invalid_countries', 'Liste de pays non vide attendue.');
      } else {
        raw.countries.forEach((code: unknown, i: number) => {
          if (!isIsoCountryCode(code)) {
            push(
              `.countries[${i}]`,
              'unknown_country',
              `Code pays inconnu (ISO 3166-1 alpha-3 minuscule) : ${String(code)}.`,
            );
          } else if (!countries.includes(code)) {
            countries.push(code);
          }
        });
      }
      criterion = {
        ...base,
        type: 'nationality',
        appliesTo: raw.appliesTo as NationalityAppliesTo,
        mode: raw.mode as NationalityMode,
        countries,
      };
      break;
    }
    case 'age': {
      const level = checkLevel();
      const min = raw.min ?? undefined;
      const max = raw.max ?? undefined;
      if (min !== undefined && !isAge(min)) {
        push('.min', 'invalid_age', 'min : entier entre 0 et 120.');
      }
      if (max !== undefined && !isAge(max)) {
        push('.max', 'invalid_age', 'max : entier entre 0 et 120.');
      }
      if (min === undefined && max === undefined) {
        push('', 'missing_age_bound', 'Un critère d’âge a au moins min ou max.');
      }
      if (isAge(min) && isAge(max) && min > max) {
        push('', 'inverted_age_bounds', 'min est supérieur à max.');
      }
      if (typeof raw.maxInclusive !== 'boolean') {
        push('.maxInclusive', 'invalid_max_inclusive', 'maxInclusive : booléen obligatoire.');
      }
      let asOf: AgeAsOf | null = null;
      if (!isRecord(raw.asOf)) {
        push('.asOf', 'invalid_as_of', 'asOf : objet { kind } obligatoire.');
      } else if (raw.asOf.kind === 'date') {
        if (!isValidIsoDate(raw.asOf.date)) {
          push('.asOf.date', 'invalid_as_of', 'asOf.date : AAAA-MM-JJ.');
        } else {
          asOf = { kind: 'date', date: raw.asOf.date };
        }
      } else if (
        raw.asOf.kind === 'cycle_close' ||
        raw.asOf.kind === 'cycle_open' ||
        raw.asOf.kind === 'unspecified'
      ) {
        asOf = { kind: raw.asOf.kind };
      } else {
        push('.asOf.kind', 'invalid_as_of', 'asOf.kind inconnu.');
      }
      criterion = {
        ...base,
        type: 'age',
        ...(level ? { level } : {}),
        ...(isAge(min) ? { min } : {}),
        ...(isAge(max) ? { max } : {}),
        maxInclusive: raw.maxInclusive === true,
        asOf: asOf ?? { kind: 'unspecified' },
      };
      break;
    }
    case 'work_experience': {
      const level = checkLevel();
      const minMonths = raw.minMonths;
      if (
        typeof minMonths !== 'number' ||
        !Number.isInteger(minMonths) ||
        minMonths < 1 ||
        minMonths > 600
      ) {
        push('.minMonths', 'invalid_min_months', 'minMonths : entier entre 1 et 600.');
      }
      criterion = {
        ...base,
        type: 'work_experience',
        ...(level ? { level } : {}),
        minMonths: minMonths as number,
      };
      break;
    }
    case 'language': {
      if (typeof raw.lang !== 'string' || !LANG_PATTERN.test(raw.lang)) {
        push('.lang', 'invalid_lang', 'lang : code ISO 639-1 minuscule (en, fr…).');
      }
      const minCefr = raw.minCefr ?? undefined;
      if (minCefr !== undefined && !isOneOf(CEFR_LEVELS, minCefr)) {
        push('.minCefr', 'invalid_cefr', 'minCefr : a1, a2, b1, b2, c1 ou c2.');
      }
      const tests: Array<{ type: LanguageTestType; min: number }> = [];
      if (raw.tests !== undefined && raw.tests !== null) {
        if (!Array.isArray(raw.tests)) {
          push('.tests', 'invalid_tests', 'tests : tableau attendu.');
        } else {
          raw.tests.forEach((test: unknown, i: number) => {
            if (!isRecord(test) || !isOneOf(LANGUAGE_TEST_TYPES, test.type)) {
              push(`.tests[${i}].type`, 'invalid_test_type', 'Type de test inconnu.');
              return;
            }
            const scale = LANGUAGE_TEST_SCALES[test.type];
            if (
              typeof test.min !== 'number' ||
              !Number.isFinite(test.min) ||
              test.min < scale.min ||
              test.min > scale.max
            ) {
              push(
                `.tests[${i}].min`,
                'invalid_test_score',
                `Score hors échelle (${scale.min}–${scale.max}).`,
              );
              return;
            }
            tests.push({ type: test.type, min: test.min });
          });
        }
      }
      if (minCefr === undefined && (raw.tests === undefined || raw.tests === null)) {
        push('', 'missing_language_requirement', 'minCefr ou tests obligatoire.');
      }
      if (typeof raw.waivable !== 'boolean') {
        push('.waivable', 'invalid_waivable', 'waivable : booléen obligatoire.');
      }
      criterion = {
        ...base,
        type: 'language',
        lang: raw.lang as string,
        ...(isOneOf(CEFR_LEVELS, minCefr) ? { minCefr } : {}),
        ...(tests.length > 0 ? { tests } : {}),
        waivable: raw.waivable === true,
      };
      break;
    }
    case 'academic_grade': {
      const minOn20 = raw.minOn20 ?? undefined;
      if (
        minOn20 !== undefined &&
        (typeof minOn20 !== 'number' || !Number.isFinite(minOn20) || minOn20 < 0 || minOn20 > 20)
      ) {
        push('.minOn20', 'invalid_min_on_20', 'minOn20 : nombre entre 0 et 20.');
      }
      if (!isNonBlank(raw.rawText)) {
        push('.rawText', 'missing_raw_text', 'rawText : la règle telle que publiée.');
      }
      criterion = {
        ...base,
        type: 'academic_grade',
        ...(typeof minOn20 === 'number' ? { minOn20 } : {}),
        rawText: raw.rawText as string,
      };
      break;
    }
    case 'financial_need': {
      // Jamais un filtre : le besoin financier ne se déclare pas dans le test.
      if (raw.impact !== 'informational') {
        push('.impact', 'financial_need_not_informational', "financial_need : impact 'informational' seulement.");
      }
      criterion = { ...base, type: 'financial_need' };
      break;
    }
    case 'other': {
      criterion = { ...base, type: 'other' };
      break;
    }
  }

  return issues.length > 0 ? { criterion: null, issues } : { criterion, issues };
}

/**
 * Lecture tolérante pour le moteur : chaque critère invalide est ignoré (et
 * signalé dans `issues`), une valeur qui n'est pas un tableau donne une liste
 * vide. Ne lève jamais.
 */
export function parseEligibilityCriteria(json: unknown): ParsedEligibilityCriteria {
  if (json === null || json === undefined) {
    return { criteria: [], issues: [], ignoredKeys: [] };
  }
  if (!Array.isArray(json)) {
    return {
      criteria: [],
      issues: [{ path: '', code: 'not_array', message: 'eligibilityCriteria : tableau attendu.' }],
      ignoredKeys: ['*'],
    };
  }
  const criteria: EligibilityCriterion[] = [];
  const issues: CriterionIssue[] = [];
  const ignoredKeys: string[] = [];
  const seen = new Set<string>();
  json.slice(0, MAX_CRITERIA).forEach((raw, index) => {
    const checked = checkCriterion(raw, index);
    let criterion = checked.criterion;
    issues.push(...checked.issues);
    if (criterion && seen.has(criterion.key)) {
      issues.push({
        path: `[${index}].key`,
        code: 'duplicate_key',
        message: `Clé en double : ${criterion.key}.`,
      });
      criterion = null;
    }
    if (criterion) {
      seen.add(criterion.key);
      criteria.push(criterion);
    } else {
      ignoredKeys.push(
        isRecord(raw) && typeof raw.key === 'string' && raw.key ? raw.key : `#${index}`,
      );
    }
  });
  if (json.length > MAX_CRITERIA) {
    issues.push({
      path: '',
      code: 'too_many_criteria',
      message: `Au plus ${MAX_CRITERIA} critères ; les suivants sont ignorés.`,
    });
    for (let index = MAX_CRITERIA; index < json.length; index += 1) {
      ignoredKeys.push(`#${index}`);
    }
  }
  return { criteria, issues, ignoredKeys };
}

/**
 * Validateur réutilisable (admin, catalogue) : la liste des erreurs de forme,
 * vide quand tout est valide. Même règles que le moteur, aucun repli.
 */
export function validateEligibilityCriteria(json: unknown): CriterionIssue[] {
  if (!Array.isArray(json)) {
    return [{ path: '', code: 'not_array', message: 'eligibilityCriteria : tableau attendu.' }];
  }
  return parseEligibilityCriteria(json).issues;
}
