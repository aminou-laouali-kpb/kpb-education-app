import type { MatchCycle, MatchScholarship } from '../assess';
import type { EligibilityCriterion } from '../eligibility-criteria';
import type { MatchProfile } from '../match-inputs';

/**
 * Fabriques partagées par les specs du moteur. Les fiches « Eiffel »,
 * « Türkiye », « UWC Kenya » et « UWC Burkina » reprennent la forme des
 * règles publiées (catalogue v1) sans dépendre des données du catalogue,
 * structurées à l'étape D3.
 */

export const NOW = new Date('2026-10-13T12:00:00.000Z');

export const DAY_MS = 24 * 60 * 60 * 1000;

export function daysBefore(days: number, from: Date = NOW): Date {
  return new Date(from.getTime() - days * DAY_MS);
}

export function date(iso: string): Date {
  return new Date(`${iso}T00:00:00.000Z`);
}

export function makeProfile(overrides: Partial<MatchProfile> = {}): MatchProfile {
  return {
    nationalities: ['ner'],
    residenceCode: 'ner',
    birthDate: date('2006-05-10'),
    guardianConsented: false,
    highestDiploma: 'bac',
    targetLevel: 'bachelor',
    fieldIds: ['engineering'],
    targetCountryIds: [],
    gradeBand: '12_14',
    englishLevel: 'b1',
    frenchLevel: 'c1_c2',
    languageTests: [],
    workExperienceBand: 'none',
    confirmed: true,
    ...overrides,
  };
}

export function makeCycle(overrides: Partial<MatchCycle> = {}): MatchCycle {
  return {
    id: 'cycle-1',
    status: 'open',
    dateConfidence: 'confirmed',
    opensAt: date('2026-09-01'),
    closesAt: date('2027-01-15'),
    estimatedOpenAt: null,
    estimatedCloseAt: null,
    ...overrides,
  };
}

export function makeScholarship(overrides: Partial<MatchScholarship> = {}): MatchScholarship {
  return {
    id: 'sch-test',
    countryId: 'fra',
    fundingType: 'fully_funded',
    eligibleLevels: ['bachelor'],
    fieldsScope: 'all',
    relatedFieldIds: [],
    eligibilityCriteria: [
      other('autres-conditions', 'informational'),
    ],
    eligibilityStructuredAt: daysBefore(30),
    deadlineAt: null,
    cycle: makeCycle(),
    ...overrides,
  };
}

const QUOTE = {
  officialTextFr: 'Texte officiel.',
  officialTextEn: 'Official text.',
  sourceUrl: 'https://example.org/eligibility',
};

type Impact = EligibilityCriterion['impact'];

export function nationality(
  key: string,
  mode: 'include' | 'exclude',
  countries: string[],
  appliesTo:
    | 'nationality'
    | 'residence'
    | 'nationality_or_residence'
    | 'nationality_and_residence' = 'nationality',
  impact: Impact = 'hard',
): EligibilityCriterion {
  return { key, type: 'nationality', impact, appliesTo, mode, countries, ...QUOTE };
}

export function age(
  key: string,
  bounds: {
    min?: number;
    max?: number;
    maxInclusive?: boolean;
    level?: 'secondary' | 'bachelor' | 'master' | 'doctorate';
    asOf?:
      | { kind: 'date'; date: string }
      | { kind: 'cycle_close' }
      | { kind: 'cycle_open' }
      | { kind: 'unspecified' };
  },
  impact: Impact = 'hard',
): EligibilityCriterion {
  return {
    key,
    type: 'age',
    impact,
    ...(bounds.level ? { level: bounds.level } : {}),
    ...(bounds.min !== undefined ? { min: bounds.min } : {}),
    ...(bounds.max !== undefined ? { max: bounds.max } : {}),
    maxInclusive: bounds.maxInclusive ?? true,
    asOf: bounds.asOf ?? { kind: 'unspecified' },
    ...QUOTE,
  };
}

export function experience(
  key: string,
  minMonths: number,
  impact: Impact = 'hard',
  level?: 'master' | 'doctorate',
): EligibilityCriterion {
  return {
    key,
    type: 'work_experience',
    impact,
    minMonths,
    ...(level ? { level } : {}),
    ...QUOTE,
  };
}

export function language(
  key: string,
  spec: { lang?: string; minCefr?: 'a1' | 'a2' | 'b1' | 'b2' | 'c1' | 'c2'; tests?: Array<{ type: 'ielts' | 'toefl_ibt' | 'duolingo'; min: number }>; waivable?: boolean },
  impact: Impact = 'soft',
): EligibilityCriterion {
  return {
    key,
    type: 'language',
    impact,
    lang: spec.lang ?? 'en',
    ...(spec.minCefr ? { minCefr: spec.minCefr } : {}),
    ...(spec.tests ? { tests: spec.tests } : {}),
    waivable: spec.waivable ?? false,
    ...QUOTE,
  };
}

export function grade(key: string, minOn20?: number, impact: Impact = 'soft'): EligibilityCriterion {
  return {
    key,
    type: 'academic_grade',
    impact,
    ...(minOn20 !== undefined ? { minOn20 } : {}),
    rawText: 'Avoir au minimum 70 % pour la Licence',
    ...QUOTE,
  };
}

export function other(key: string, impact: Impact = 'soft'): EligibilityCriterion {
  return { key, type: 'other', impact, ...QUOTE };
}

export function financialNeed(key: string): EligibilityCriterion {
  return { key, type: 'financial_need', impact: 'informational', ...QUOTE };
}

// ── Fiches modelées sur le catalogue v1 ─────────────────────────────────────

/** Eiffel (europe-master.v1.ts) : pas de Français, « 29 ans au plus » sans date. */
export function eiffel(overrides: Partial<MatchScholarship> = {}): MatchScholarship {
  return makeScholarship({
    id: 'eiffel',
    countryId: 'fra',
    fundingType: 'partially_funded',
    eligibleLevels: ['master'],
    eligibilityCriteria: [
      nationality('pas-francais', 'exclude', ['fra']),
      age('age-max', { max: 29, maxInclusive: true, asOf: { kind: 'unspecified' } }),
    ],
    ...overrides,
  });
}

/** Türkiye Burslari (multi-level.v1.ts) : pas de Turcs, < 21 en Licence, < 30 en Master, 70 % souple. */
export function turkiye(overrides: Partial<MatchScholarship> = {}): MatchScholarship {
  return makeScholarship({
    id: 'turkiye',
    countryId: 'tur',
    eligibleLevels: ['bachelor', 'master'],
    eligibilityCriteria: [
      nationality('pas-turc', 'exclude', ['tur']),
      age('age-licence', { level: 'bachelor', max: 21, maxInclusive: false }),
      age('age-master', { level: 'master', max: 30, maxInclusive: false }),
      grade('moyenne-70', undefined, 'informational'),
    ],
    cycle: makeCycle({
      status: 'forecast',
      dateConfidence: 'estimated',
      opensAt: null,
      closesAt: null,
      estimatedOpenAt: date('2027-01-10'),
      estimatedCloseAt: date('2027-02-20'),
    }),
    ...overrides,
  });
}

/** UWC Kenya (records.v1.ts) : citoyen OU résident du Kenya, double nationalité comprise. */
export function uwcKenya(overrides: Partial<MatchScholarship> = {}): MatchScholarship {
  return makeScholarship({
    id: 'uwc_kenya',
    countryId: 'ken',
    eligibleLevels: ['secondary'],
    eligibilityCriteria: [
      nationality('citoyen-ou-resident', 'include', ['ken'], 'nationality_or_residence'),
      age('age', { min: 16, max: 19, maxInclusive: true, asOf: { kind: 'unspecified' } }),
    ],
    ...overrides,
  });
}

/** UWC Burkina Faso (records.v1.ts) : citoyen ET résident permanent. */
export function uwcBurkina(overrides: Partial<MatchScholarship> = {}): MatchScholarship {
  return makeScholarship({
    id: 'uwc_burkina',
    countryId: 'bfa',
    eligibleLevels: ['secondary'],
    eligibilityCriteria: [
      nationality('citoyen-et-resident', 'include', ['bfa'], 'nationality_and_residence'),
      age('age', { min: 16, max: 18, maxInclusive: true, asOf: { kind: 'unspecified' } }),
    ],
    ...overrides,
  });
}
