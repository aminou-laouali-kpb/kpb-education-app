/**
 * Contrat de l'éligibilité structurée côté admin (« Mes 10 bourses »,
 * chantier D4).
 *
 * Les petites énumérations sont un MIROIR de
 * `backend/src/modules/scholarship-match/eligibility-criteria.ts` et
 * `match-inputs.ts` (le test `scholarship-eligibility-types.test.ts` relit ces
 * fichiers quand le dépôt est complet). La table des pays, elle, n'est pas
 * copiée : elle est servie par `GET /admin/scholarships/eligibility-options`.
 */

export const ELIGIBLE_LEVELS = ['secondary', 'bachelor', 'master', 'doctorate'] as const;
export type EligibleLevel = (typeof ELIGIBLE_LEVELS)[number];

export const FIELDS_SCOPES = ['unknown', 'all', 'listed'] as const;
export type FieldsScope = (typeof FIELDS_SCOPES)[number];

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

export const CRITERION_IMPACTS = ['hard', 'soft', 'informational'] as const;
export type CriterionImpact = (typeof CRITERION_IMPACTS)[number];

/** Les seuls types qu'une règle `hard` peut faire exclure (assess.ts). */
export const EXCLUDING_TYPES: readonly CriterionType[] = ['nationality', 'age', 'work_experience'];

export const NATIONALITY_APPLIES_TO = [
  'nationality',
  'residence',
  'nationality_or_residence',
  'nationality_and_residence',
] as const;
export type NationalityAppliesTo = (typeof NATIONALITY_APPLIES_TO)[number];

export const NATIONALITY_MODES = ['include', 'exclude'] as const;
export type NationalityMode = (typeof NATIONALITY_MODES)[number];

export const AGE_AS_OF_KINDS = ['date', 'cycle_close', 'cycle_open', 'unspecified'] as const;
export type AgeAsOfKind = (typeof AGE_AS_OF_KINDS)[number];

export const CEFR_LEVELS = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'] as const;
export type CefrLevel = (typeof CEFR_LEVELS)[number];

export const LANGUAGE_TEST_SCALES = {
  ielts: { min: 0, max: 9 },
  toefl_ibt: { min: 0, max: 120 },
  duolingo: { min: 10, max: 160 },
  tcf: { min: 100, max: 699 },
  tef: { min: 0, max: 699 },
} as const;
export type LanguageTestType = keyof typeof LANGUAGE_TEST_SCALES;
export const LANGUAGE_TEST_TYPES = Object.keys(LANGUAGE_TEST_SCALES) as LanguageTestType[];

/** Au plus 40 critères par fiche (au-delà, le moteur les ignore). */
export const MAX_CRITERIA = 40;
export const MAX_TEXT = 2_000;

// ── Critères v1 (forme stockée dans `Scholarship.eligibilityCriteria`) ──────

export type AgeAsOf =
  | { kind: 'date'; date: string }
  | { kind: 'cycle_close' }
  | { kind: 'cycle_open' }
  | { kind: 'unspecified' };

interface CriterionBase {
  key: string;
  impact: CriterionImpact;
  officialTextFr: string;
  officialTextEn: string;
  sourceUrl: string;
}

export type EligibilityCriterion =
  | (CriterionBase & {
      type: 'nationality';
      appliesTo: NationalityAppliesTo;
      mode: NationalityMode;
      countries: string[];
    })
  | (CriterionBase & {
      type: 'age';
      level?: EligibleLevel;
      min?: number;
      max?: number;
      maxInclusive: boolean;
      asOf: AgeAsOf;
    })
  | (CriterionBase & { type: 'work_experience'; level?: EligibleLevel; minMonths: number })
  | (CriterionBase & {
      type: 'language';
      lang: string;
      minCefr?: CefrLevel;
      tests?: Array<{ type: LanguageTestType; min: number }>;
      waivable: boolean;
    })
  | (CriterionBase & { type: 'academic_grade'; minOn20?: number; rawText: string })
  | (CriterionBase & { type: 'financial_need' })
  | (CriterionBase & { type: 'other' });

// ── Profil de l'aperçu (mêmes jetons que le test élève) ─────────────────────

export const DIPLOMAS = ['none', 'bac', 'bac_plus_2', 'licence', 'master', 'doctorat'] as const;
export const GRADE_BANDS = ['lt10', '10_12', '12_14', '14_16', '16_plus'] as const;
export const LANGUAGE_BANDS = ['none', 'a1_a2', 'b1', 'b2', 'c1_c2'] as const;
export const EXPERIENCE_BANDS = ['none', 'lt12', '12_24', '24_36', '36_60', '60_plus'] as const;

// ── Réponses des routes admin ───────────────────────────────────────────────

export interface EligibilityCountryOption {
  code: string;
  nameFr: string;
  nameEn: string;
  priority: boolean;
  /** Faux pour un territoire inhabité (valide dans un critère). */
  selectable: boolean;
}

export interface EligibilityOptionsResponse {
  countries: EligibilityCountryOption[];
  freshnessDays: number;
  launchGatePercent: number;
  maxResults: number;
}

export type EligibilityCoverageState = 'fresh' | 'stale' | 'unstructured' | 'not_analyzed';

export interface EligibilityCoverageItem {
  id: string;
  nameFr: string;
  nameEn: string;
  state: Exclude<EligibilityCoverageState, 'fresh'>;
  structuredAt: string | null;
  structuredBy: string | null;
}

export interface EligibilityCoverageResponse {
  generatedAt: string;
  freshnessDays: number;
  launchGatePercent: number;
  total: number;
  structuredFresh: number;
  stale: number;
  unstructured: number;
  notAnalyzed: number;
  invalidCriteria: number;
  coveragePercent: number;
  launchReady: boolean;
  toStructure: EligibilityCoverageItem[];
  toStructureIds: string[];
  truncated: boolean;
}

export type MatchStatus = 'eligible' | 'to_verify' | 'not_eligible' | 'not_analyzed' | 'suspended';

export interface MatchPreviewPoint {
  code: string;
  label: string;
  criterionKey?: string;
  officialText?: string;
  sourceUrl?: string;
}

export interface MatchPreviewEntry {
  scholarshipId: string;
  name: string;
  status: MatchStatus;
  cycleId: string | null;
  structuredFresh: boolean;
  reasons: MatchPreviewPoint[];
  toVerify: MatchPreviewPoint[];
  exclusions: MatchPreviewPoint[];
  ignoredCriteria: string[];
}

export interface MatchPreviewResponse {
  persisted: false;
  algorithmVersion: string;
  generatedAt: string;
  lang: 'fr' | 'en';
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
  items: Array<MatchPreviewEntry & { rank: number; section: 'compatible' | 'to_verify' }>;
  beyondLimitCount: number;
  excluded: MatchPreviewEntry[];
  excludedSummary: {
    groups: Array<{ group: string; count: number; scholarshipIds: string[] }>;
    notAnalyzedCount: number;
  };
  notAnalyzed: Array<{ scholarshipId: string; name: string }>;
  focus: { public: boolean; entry: MatchPreviewEntry } | null;
}

/** Corps de `POST /admin/scholarships/match-preview` (champs du test). */
export interface MatchPreviewBody {
  lang?: 'fr' | 'en';
  nationalityCode?: string;
  secondNationalityCode?: string;
  countryOfResidence?: string;
  birthDate?: string;
  guardianConsented?: boolean;
  highestDiploma?: string;
  scholarshipTargetLevel?: string;
  fieldIds?: string[];
  targetCountryIds?: string[];
  gradeBandOn20?: string;
  englishLevel?: string;
  frenchLevel?: string;
  languageTests?: Array<{ type: string; score: number }>;
  workExperienceBand?: string;
  confirmed?: boolean;
  focusScholarshipId?: string;
}
