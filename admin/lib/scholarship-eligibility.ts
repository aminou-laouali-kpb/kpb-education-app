import {
  AGE_AS_OF_KINDS,
  CEFR_LEVELS,
  CRITERION_IMPACTS,
  CRITERION_TYPES,
  ELIGIBLE_LEVELS,
  EXCLUDING_TYPES,
  FIELDS_SCOPES,
  LANGUAGE_TEST_SCALES,
  LANGUAGE_TEST_TYPES,
  MAX_CRITERIA,
  MAX_TEXT,
  NATIONALITY_APPLIES_TO,
  NATIONALITY_MODES,
  type AgeAsOfKind,
  type CefrLevel,
  type CriterionImpact,
  type CriterionType,
  type EligibilityCoverageState,
  type EligibilityCriterion,
  type EligibleLevel,
  type FieldsScope,
  type LanguageTestType,
  type MatchPreviewBody,
  type NationalityAppliesTo,
  type NationalityMode,
} from './scholarship-eligibility-types';

/**
 * Logique PURE de l'éditeur d'éligibilité (chantier D4) : état de couverture
 * d'une fiche, brouillon de formulaire ↔ critère v1 (sérialisation),
 * validation côté client (les mêmes règles que le validateur du serveur, qui
 * reste seul juge), lecture des erreurs 400 du serveur, corps de l'aperçu.
 */

export const DEFAULT_FRESHNESS_DAYS = 400;
const DAY_MS = 24 * 60 * 60 * 1000;

// ── Couverture d'une fiche (colonne « Éligibilité ») ────────────────────────

export interface EligibilityFields {
  eligibleLevels?: readonly string[] | null;
  eligibilityStructuredAt?: string | null;
}

/**
 * Même classement que le serveur (`eligibilityCoverageState`) :
 * - `not_analyzed` : aucun niveau (✗) ;
 * - `unstructured` : niveaux posés, jamais tamponnés (brouillon) ;
 * - `stale`        : tampon de 400 jours ou plus (périmée) ;
 * - `fresh`        : tampon de moins de 400 jours (✓).
 */
export function eligibilityStateOf(
  entry: EligibilityFields,
  now: Date,
  freshnessDays = DEFAULT_FRESHNESS_DAYS,
): EligibilityCoverageState {
  if (!entry.eligibleLevels || entry.eligibleLevels.length === 0) return 'not_analyzed';
  if (!entry.eligibilityStructuredAt) return 'unstructured';
  const stamped = new Date(entry.eligibilityStructuredAt);
  if (Number.isNaN(stamped.getTime())) return 'unstructured';
  return now.getTime() - stamped.getTime() < freshnessDays * DAY_MS ? 'fresh' : 'stale';
}

/** « À structurer » : tout ce qui n'est pas frais. */
export function needsStructuring(entry: EligibilityFields, now: Date, freshnessDays?: number) {
  return eligibilityStateOf(entry, now, freshnessDays) !== 'fresh';
}

/** Fiche importée du catalogue du dépôt (tags `catalog:…`) : le dépôt fait foi. */
export function isCatalogManaged(tags: readonly string[] | null | undefined): boolean {
  return (tags ?? []).some((tag) => tag.startsWith('catalog:'));
}

/** Pourcentage affiché « 86,1 % » / "86.1%" (une décimale, jamais arrondi vers le haut par ici). */
export function formatPercent(value: number, locale: 'fr' | 'en'): string {
  const text = (Math.floor(value * 10) / 10).toFixed(1).replace(/\.0$/, '');
  return locale === 'fr' ? `${text.replace('.', ',')} %` : `${text}%`;
}

// ── Brouillon de critère ────────────────────────────────────────────────────

export interface LanguageTestDraft {
  type: LanguageTestType;
  min: string;
}

/**
 * L'état d'un formulaire de critère : TOUS les champs de tous les types, les
 * nombres en texte (tels que saisis). La sérialisation ne garde que ceux du
 * type choisi : changer de type ne perd pas la saisie commune.
 */
export interface CriterionDraft {
  /** Identifiant local de la carte (React), jamais envoyé. */
  uid: string;
  type: CriterionType;
  key: string;
  impact: CriterionImpact;
  officialTextFr: string;
  officialTextEn: string;
  sourceUrl: string;
  // nationalité / résidence
  appliesTo: NationalityAppliesTo;
  mode: NationalityMode;
  countries: string[];
  // âge, expérience
  level: EligibleLevel | '';
  min: string;
  max: string;
  maxInclusive: boolean;
  asOfKind: AgeAsOfKind;
  asOfDate: string;
  minMonths: string;
  // langue
  lang: string;
  minCefr: CefrLevel | '';
  tests: LanguageTestDraft[];
  waivable: boolean;
  // moyenne
  minOn20: string;
  rawText: string;
}

export interface EligibilityDraft {
  eligibleLevels: EligibleLevel[];
  fieldsScope: FieldsScope;
  criteria: CriterionDraft[];
}

let uidSeq = 0;
function nextUid(): string {
  uidSeq += 1;
  return `criterion-${uidSeq}`;
}

/** Impact par défaut d'un type : `hard` seulement là où il peut exclure. */
export function defaultImpact(type: CriterionType): CriterionImpact {
  if (type === 'financial_need') return 'informational';
  return EXCLUDING_TYPES.includes(type) ? 'hard' : 'soft';
}

/** Une clé libre dans la fiche : `age`, `age-2`… */
export function suggestKey(type: CriterionType, taken: readonly string[]): string {
  const base = type.replace(/_/g, '-');
  if (!taken.includes(base)) return base;
  let index = 2;
  while (taken.includes(`${base}-${index}`)) index += 1;
  return `${base}-${index}`;
}

export function emptyCriterionDraft(
  type: CriterionType,
  takenKeys: readonly string[] = [],
): CriterionDraft {
  return {
    uid: nextUid(),
    type,
    key: suggestKey(type, takenKeys),
    impact: defaultImpact(type),
    officialTextFr: '',
    officialTextEn: '',
    sourceUrl: '',
    appliesTo: 'nationality',
    mode: 'include',
    countries: [],
    level: '',
    min: '',
    max: '',
    maxInclusive: true,
    asOfKind: 'unspecified',
    asOfDate: '',
    minMonths: '',
    lang: 'en',
    minCefr: '',
    tests: [],
    waivable: false,
    minOn20: '',
    rawText: '',
  };
}

function oneOf<T extends string>(values: readonly T[], value: unknown, fallback: T): T {
  return typeof value === 'string' && (values as readonly string[]).includes(value)
    ? (value as T)
    : fallback;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function num(value: unknown): string {
  return typeof value === 'number' && Number.isFinite(value) ? String(value) : '';
}

/**
 * Un critère stocké (JSON brut, peut-être invalide) → brouillon de formulaire.
 * Tolérant : un champ illisible devient vide, la validation le signalera.
 */
export function criterionToDraft(raw: unknown): CriterionDraft {
  const source = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const type = oneOf(CRITERION_TYPES, source.type, 'other');
  const draft = emptyCriterionDraft(type);
  const asOf = (source.asOf && typeof source.asOf === 'object' ? source.asOf : {}) as Record<
    string,
    unknown
  >;
  return {
    ...draft,
    key: text(source.key),
    impact: oneOf(CRITERION_IMPACTS, source.impact, defaultImpact(type)),
    officialTextFr: text(source.officialTextFr),
    officialTextEn: text(source.officialTextEn),
    sourceUrl: text(source.sourceUrl),
    appliesTo: oneOf(NATIONALITY_APPLIES_TO, source.appliesTo, 'nationality'),
    mode: oneOf(NATIONALITY_MODES, source.mode, 'include'),
    countries: Array.isArray(source.countries)
      ? source.countries.filter((code): code is string => typeof code === 'string')
      : [],
    level: oneOf<EligibleLevel | ''>(ELIGIBLE_LEVELS, source.level, ''),
    min: num(source.min),
    max: num(source.max),
    maxInclusive: source.maxInclusive !== false,
    asOfKind: oneOf(AGE_AS_OF_KINDS, asOf.kind, 'unspecified'),
    asOfDate: text(asOf.date),
    minMonths: num(source.minMonths),
    lang: text(source.lang) || 'en',
    minCefr: oneOf<CefrLevel | ''>(CEFR_LEVELS, source.minCefr, ''),
    tests: Array.isArray(source.tests)
      ? source.tests
          .filter((test): test is Record<string, unknown> => !!test && typeof test === 'object')
          .map((test) => ({
            type: oneOf(LANGUAGE_TEST_TYPES, test.type, 'ielts'),
            min: num(test.min),
          }))
      : [],
    waivable: source.waivable === true,
    minOn20: num(source.minOn20),
    rawText: text(source.rawText),
  };
}

export function eligibilityDraftFrom(entry: {
  eligibleLevels?: readonly string[] | null;
  fieldsScope?: string | null;
  eligibilityCriteria?: unknown;
}): EligibilityDraft {
  return {
    eligibleLevels: ELIGIBLE_LEVELS.filter((level) => (entry.eligibleLevels ?? []).includes(level)),
    fieldsScope: oneOf(FIELDS_SCOPES, entry.fieldsScope, 'unknown'),
    criteria: Array.isArray(entry.eligibilityCriteria)
      ? entry.eligibilityCriteria.map(criterionToDraft)
      : [],
  };
}

/** Nombre saisi (virgule acceptée) ; `undefined` pour un champ vide ; NaN si illisible. */
export function parseNumber(value: string): number | undefined {
  const trimmed = value.trim();
  if (trimmed === '') return undefined;
  return Number(trimmed.replace(',', '.'));
}

/** Brouillon → critère v1, au format attendu par le serveur (sans champ d'un autre type). */
export function draftToCriterion(draft: CriterionDraft): EligibilityCriterion {
  const base = {
    key: draft.key.trim(),
    impact: draft.type === 'financial_need' ? 'informational' : draft.impact,
    officialTextFr: draft.officialTextFr.trim(),
    officialTextEn: draft.officialTextEn.trim(),
    sourceUrl: draft.sourceUrl.trim(),
  } as const;
  const level = draft.level ? { level: draft.level } : {};
  switch (draft.type) {
    case 'nationality':
      return {
        ...base,
        type: 'nationality',
        appliesTo: draft.appliesTo,
        mode: draft.mode,
        countries: [...new Set(draft.countries)],
      };
    case 'age': {
      const min = parseNumber(draft.min);
      const max = parseNumber(draft.max);
      return {
        ...base,
        type: 'age',
        ...level,
        ...(min !== undefined ? { min } : {}),
        ...(max !== undefined ? { max } : {}),
        maxInclusive: draft.maxInclusive,
        asOf:
          draft.asOfKind === 'date'
            ? { kind: 'date', date: draft.asOfDate.trim() }
            : { kind: draft.asOfKind },
      };
    }
    case 'work_experience':
      return {
        ...base,
        type: 'work_experience',
        ...level,
        minMonths: parseNumber(draft.minMonths) ?? Number.NaN,
      };
    case 'language':
      return {
        ...base,
        type: 'language',
        lang: draft.lang.trim().toLowerCase(),
        ...(draft.minCefr ? { minCefr: draft.minCefr } : {}),
        ...(draft.tests.length > 0
          ? {
              tests: draft.tests.map((test) => ({
                type: test.type,
                min: parseNumber(test.min) ?? Number.NaN,
              })),
            }
          : {}),
        waivable: draft.waivable,
      };
    case 'academic_grade': {
      const minOn20 = parseNumber(draft.minOn20);
      return {
        ...base,
        type: 'academic_grade',
        ...(minOn20 !== undefined ? { minOn20 } : {}),
        rawText: draft.rawText.trim(),
      };
    }
    case 'financial_need':
      return { ...base, type: 'financial_need' };
    case 'other':
    default:
      return { ...base, type: 'other' };
  }
}

// ── Validation côté client ──────────────────────────────────────────────────

export const CLIENT_ERROR_CODES = [
  'invalid_key',
  'duplicate_key',
  'missing_official_text_fr',
  'missing_official_text_en',
  'invalid_source_url',
  'invalid_countries',
  'unknown_country',
  'missing_age_bound',
  'invalid_age',
  'inverted_age_bounds',
  'invalid_as_of_date',
  'invalid_min_months',
  'invalid_lang',
  'missing_language_requirement',
  'invalid_test_score',
  'invalid_min_on_20',
  'missing_raw_text',
  'too_many_criteria',
  'levels_required',
] as const;
export type ClientErrorCode = (typeof CLIENT_ERROR_CODES)[number];

export interface DraftIssue {
  /** Index du critère, ou null pour la fiche entière. */
  index: number | null;
  field: string;
  code: ClientErrorCode;
}

const KEY_PATTERN = /^[a-z0-9]+(?:[_-][a-z0-9]+)*$/;

function isBlank(value: string): boolean {
  return value.trim() === '';
}

function isHttpUrl(value: string): boolean {
  if (value.length > MAX_TEXT) return false;
  try {
    const url = new URL(value.trim());
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

function isAge(value: number | undefined): boolean {
  return value !== undefined && Number.isInteger(value) && value >= 0 && value <= 120;
}

function isIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

/**
 * Les erreurs d'UN critère. `knownCountries` (la table servie) est facultatif :
 * sans elle, le serveur reste seul juge des codes pays.
 */
export function validateCriterionDraft(
  draft: CriterionDraft,
  index: number,
  knownCountries?: ReadonlySet<string>,
): DraftIssue[] {
  const issues: DraftIssue[] = [];
  const push = (field: string, code: ClientErrorCode) => issues.push({ index, field, code });
  const key = draft.key.trim();
  if (!KEY_PATTERN.test(key) || key.length > 64) push('key', 'invalid_key');
  if (isBlank(draft.officialTextFr) || draft.officialTextFr.length > MAX_TEXT) {
    push('officialTextFr', 'missing_official_text_fr');
  }
  if (isBlank(draft.officialTextEn) || draft.officialTextEn.length > MAX_TEXT) {
    push('officialTextEn', 'missing_official_text_en');
  }
  if (!isHttpUrl(draft.sourceUrl)) push('sourceUrl', 'invalid_source_url');

  switch (draft.type) {
    case 'nationality':
      if (draft.countries.length === 0) push('countries', 'invalid_countries');
      if (knownCountries && draft.countries.some((code) => !knownCountries.has(code))) {
        push('countries', 'unknown_country');
      }
      break;
    case 'age': {
      const min = parseNumber(draft.min);
      const max = parseNumber(draft.max);
      if (min === undefined && max === undefined) push('min', 'missing_age_bound');
      if (min !== undefined && !isAge(min)) push('min', 'invalid_age');
      if (max !== undefined && !isAge(max)) push('max', 'invalid_age');
      if (isAge(min) && isAge(max) && (min as number) > (max as number)) {
        push('max', 'inverted_age_bounds');
      }
      if (draft.asOfKind === 'date' && !isIsoDate(draft.asOfDate.trim())) {
        push('asOfDate', 'invalid_as_of_date');
      }
      break;
    }
    case 'work_experience': {
      const months = parseNumber(draft.minMonths);
      if (months === undefined || !Number.isInteger(months) || months < 1 || months > 600) {
        push('minMonths', 'invalid_min_months');
      }
      break;
    }
    case 'language': {
      if (!/^[a-z]{2}$/.test(draft.lang.trim().toLowerCase())) push('lang', 'invalid_lang');
      if (!draft.minCefr && draft.tests.length === 0) {
        push('minCefr', 'missing_language_requirement');
      }
      draft.tests.forEach((test, i) => {
        const score = parseNumber(test.min);
        const scale = LANGUAGE_TEST_SCALES[test.type];
        if (score === undefined || !Number.isFinite(score) || score < scale.min || score > scale.max) {
          push(`tests[${i}]`, 'invalid_test_score');
        }
      });
      break;
    }
    case 'academic_grade': {
      const minOn20 = parseNumber(draft.minOn20);
      if (minOn20 !== undefined && (!Number.isFinite(minOn20) || minOn20 < 0 || minOn20 > 20)) {
        push('minOn20', 'invalid_min_on_20');
      }
      if (isBlank(draft.rawText) || draft.rawText.length > MAX_TEXT) push('rawText', 'missing_raw_text');
      break;
    }
    default:
      break;
  }
  return issues;
}

/**
 * Les erreurs de la fiche. `forStamp` ajoute la règle du tampon : on ne
 * certifie pas une fiche sans niveau.
 */
export function validateEligibilityDraft(
  draft: EligibilityDraft,
  options: { knownCountries?: ReadonlySet<string>; forStamp?: boolean } = {},
): DraftIssue[] {
  const issues: DraftIssue[] = [];
  if (options.forStamp && draft.eligibleLevels.length === 0) {
    issues.push({ index: null, field: 'eligibleLevels', code: 'levels_required' });
  }
  if (draft.criteria.length > MAX_CRITERIA) {
    issues.push({ index: null, field: 'criteria', code: 'too_many_criteria' });
  }
  const seen = new Set<string>();
  draft.criteria.forEach((criterion, index) => {
    issues.push(...validateCriterionDraft(criterion, index, options.knownCountries));
    const key = criterion.key.trim();
    if (key && seen.has(key)) issues.push({ index, field: 'key', code: 'duplicate_key' });
    seen.add(key);
  });
  return issues;
}

/** Corps du PATCH `/admin/catalog/scholarships/:id` pour l'éligibilité. */
export function eligibilityPatchBody(
  draft: EligibilityDraft,
  markStructured?: boolean,
): {
  eligibleLevels: EligibleLevel[];
  fieldsScope: FieldsScope;
  eligibilityCriteria: EligibilityCriterion[];
  markStructured?: boolean;
} {
  return {
    eligibleLevels: ELIGIBLE_LEVELS.filter((level) => draft.eligibleLevels.includes(level)),
    fieldsScope: draft.fieldsScope,
    eligibilityCriteria: draft.criteria.map(draftToCriterion),
    ...(markStructured !== undefined ? { markStructured } : {}),
  };
}

/** Deux brouillons équivalents (pour savoir s'il reste des modifications). */
export function sameEligibility(a: EligibilityDraft, b: EligibilityDraft): boolean {
  return JSON.stringify(eligibilityPatchBody(a)) === JSON.stringify(eligibilityPatchBody(b));
}

// ── Erreurs 400 du serveur ──────────────────────────────────────────────────

export interface ServerIssue {
  index: number | null;
  path: string;
  message: string;
}

/**
 * Lit le corps d'une 400 d'éligibilité
 * (`{ code, message: string[], issues: [{ path: '[2].countries[0]', … }] }`).
 * Rend `null` si ce n'en est pas une.
 */
export function readEligibilityError(
  error: unknown,
): { code: string; issues: ServerIssue[] } | null {
  const body = (error as { body?: unknown } | null)?.body;
  if (typeof body !== 'string' || body === '') return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== 'object') return null;
  const { code, issues } = parsed as { code?: unknown; issues?: unknown };
  if (typeof code !== 'string') return null;
  const list = Array.isArray(issues) ? issues : [];
  return {
    code,
    issues: list
      .filter((issue): issue is Record<string, unknown> => !!issue && typeof issue === 'object')
      .map((issue) => {
        const path = typeof issue.path === 'string' ? issue.path : '';
        const match = /^\[(\d+)\]/.exec(path);
        return {
          index: match ? Number(match[1]) : null,
          path,
          message: typeof issue.message === 'string' ? issue.message : String(issue.code ?? ''),
        };
      }),
  };
}

// ── Aperçu « Tester un profil » ─────────────────────────────────────────────

export interface PreviewForm {
  lang: 'fr' | 'en';
  nationalityCode: string;
  secondNationalityCode: string;
  countryOfResidence: string;
  birthDate: string;
  guardianConsented: boolean;
  highestDiploma: string;
  scholarshipTargetLevel: string;
  fieldIds: string;
  targetCountryIds: string;
  gradeBandOn20: string;
  englishLevel: string;
  frenchLevel: string;
  languageTestType: string;
  languageTestScore: string;
  workExperienceBand: string;
  confirmed: boolean;
}

export const EMPTY_PREVIEW_FORM: PreviewForm = {
  lang: 'fr',
  nationalityCode: '',
  secondNationalityCode: '',
  countryOfResidence: '',
  birthDate: '',
  guardianConsented: false,
  highestDiploma: '',
  scholarshipTargetLevel: '',
  fieldIds: '',
  targetCountryIds: '',
  gradeBandOn20: '',
  englishLevel: '',
  frenchLevel: '',
  languageTestType: '',
  languageTestScore: '',
  workExperienceBand: '',
  confirmed: true,
};

function list(value: string): string[] {
  return value
    .split(/[\s,;]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

/** Formulaire → corps de l'aperçu : les champs vides ne sont pas envoyés. */
export function previewBody(form: PreviewForm, focusScholarshipId?: string | null): MatchPreviewBody {
  const body: MatchPreviewBody = { lang: form.lang, confirmed: form.confirmed };
  const set = <K extends keyof MatchPreviewBody>(key: K, value: string) => {
    if (value.trim() !== '') body[key] = value.trim() as MatchPreviewBody[K];
  };
  set('nationalityCode', form.nationalityCode);
  set('secondNationalityCode', form.secondNationalityCode);
  set('countryOfResidence', form.countryOfResidence);
  set('birthDate', form.birthDate);
  set('highestDiploma', form.highestDiploma);
  set('scholarshipTargetLevel', form.scholarshipTargetLevel);
  set('gradeBandOn20', form.gradeBandOn20);
  set('englishLevel', form.englishLevel);
  set('frenchLevel', form.frenchLevel);
  set('workExperienceBand', form.workExperienceBand);
  if (form.guardianConsented) body.guardianConsented = true;
  const fields = list(form.fieldIds);
  if (fields.length > 0) body.fieldIds = fields;
  const destinations = list(form.targetCountryIds).map((code) => code.toLowerCase());
  if (destinations.length > 0) body.targetCountryIds = destinations;
  const score = parseNumber(form.languageTestScore);
  if (form.languageTestType && score !== undefined && Number.isFinite(score)) {
    body.languageTests = [{ type: form.languageTestType, score }];
  }
  if (focusScholarshipId) body.focusScholarshipId = focusScholarshipId;
  return body;
}

// ── Liens ───────────────────────────────────────────────────────────────────

/** `/scholarships?scholarshipId=…` ouvre la fiche dans la file de modération. */
export const SCHOLARSHIP_QUERY_PARAM = 'scholarshipId';

export function scholarshipAdminHref(scholarshipId: string): string {
  return `/scholarships?${SCHOLARSHIP_QUERY_PARAM}=${encodeURIComponent(scholarshipId)}`;
}
