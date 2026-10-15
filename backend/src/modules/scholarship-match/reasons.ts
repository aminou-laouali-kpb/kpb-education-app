import { countryName, type MatchLang } from './countries';
import type { EligibleLevel } from './eligibility-criteria';

/**
 * Codes produits par le moteur et leurs libellés FR/EN, rendus CÔTÉ SERVEUR :
 * un libellé se corrige sans nouvelle build de l'app.
 *
 * Invariants (reasons.spec.ts) :
 * - chaque code a un libellé FR ET EN ;
 * - aucun libellé rédigé par KPB ne contient « % » ni « chance(s) ». Les
 *   citations officielles (`officialText*`) ne passent pas par ici et en sont
 *   exemptées : la Türkiye écrit littéralement « 70 % ».
 */

/** Raisons positives (« ✓ »). */
export const REASON_CODES = [
  'level_accepted',
  'nationality_accepted',
  'nationality_not_excluded',
  'residence_accepted',
  'age_within_limit',
  'experience_sufficient',
  'language_sufficient',
  'grade_sufficient',
  'field_listed',
  'fields_all',
  'destination_wanted',
] as const;
export type ReasonCode = (typeof REASON_CODES)[number];

/** Points à vérifier (« ⚠ »). Jamais une exclusion. */
export const TO_VERIFY_CODES = [
  'eligibility_not_structured',
  'eligibility_stale',
  'criteria_not_structured',
  'criterion_unreadable',
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
  'language_other',
  'grade_missing',
  'grade_below',
  'grade_check',
  'field_not_listed',
  'field_undecided',
  'condition_other',
] as const;
export type ToVerifyCode = (typeof TO_VERIFY_CODES)[number];

/** Motifs d'exclusion (`not_eligible`, `suspended`). */
export const EXCLUSION_CODES = [
  'level_other',
  'nationality_not_listed',
  'nationality_excluded',
  'residence_not_listed',
  'residence_excluded',
  'age_too_young',
  'age_too_old',
  'experience_insufficient',
  'suspended',
] as const;
export type ExclusionCode = (typeof EXCLUSION_CODES)[number];

export type MatchCode = ReasonCode | ToVerifyCode | ExclusionCode;

/**
 * Paramètres d'un libellé. Volontairement plats et sans donnée brute du
 * profil au-delà du nécessaire (âge en années, jamais la date de naissance).
 */
export interface MatchPointParams {
  level?: EligibleLevel;
  levels?: EligibleLevel[];
  countries?: string[];
  age?: number;
  min?: number;
  max?: number;
  /** Faux pour « moins de 30 ans » (30 exclu). */
  maxInclusive?: boolean;
  /** AAAA-MM-JJ : date de référence de l'âge, quand elle est connue. */
  asOfDate?: string;
  minMonths?: number;
  lang?: string;
  minCefr?: string;
  /** « ielts 6.5 », « toefl_ibt 90 »… */
  tests?: string[];
  minOn20?: number;
  waivable?: boolean;
}

export interface MatchPoint<C extends MatchCode = MatchCode> {
  code: C;
  /** Critère d'origine : l'app y retrouve la citation officielle et sa source. */
  criterionKey?: string;
  params?: MatchPointParams;
}

/** Groupes du résumé « Pourquoi certaines bourses n'apparaissent pas ». */
export type ExclusionGroup = 'level' | 'nationality' | 'age' | 'experience' | 'suspended';

export const EXCLUSION_GROUP: Record<ExclusionCode, ExclusionGroup> = {
  level_other: 'level',
  nationality_not_listed: 'nationality',
  nationality_excluded: 'nationality',
  residence_not_listed: 'nationality',
  residence_excluded: 'nationality',
  age_too_young: 'age',
  age_too_old: 'age',
  experience_insufficient: 'experience',
  suspended: 'suspended',
};

// ── Rendu ────────────────────────────────────────────────────────────────────

const LEVEL_LABELS: Record<EligibleLevel, { fr: string; en: string }> = {
  secondary: { fr: 'Lycée', en: 'Secondary school' },
  bachelor: { fr: 'Licence', en: 'Bachelor' },
  master: { fr: 'Master', en: 'Master' },
  doctorate: { fr: 'Doctorat', en: 'Doctorate' },
};

const LANGUAGE_NAMES: Record<string, { fr: string; en: string }> = {
  en: { fr: 'anglais', en: 'English' },
  fr: { fr: 'français', en: 'French' },
  de: { fr: 'allemand', en: 'German' },
  es: { fr: 'espagnol', en: 'Spanish' },
  tr: { fr: 'turc', en: 'Turkish' },
  zh: { fr: 'chinois', en: 'Chinese' },
  ru: { fr: 'russe', en: 'Russian' },
  ar: { fr: 'arabe', en: 'Arabic' },
  pt: { fr: 'portugais', en: 'Portuguese' },
  it: { fr: 'italien', en: 'Italian' },
};

const TEST_NAMES: Record<string, string> = {
  ielts: 'IELTS',
  toefl_ibt: 'TOEFL iBT',
  duolingo: 'Duolingo',
  tcf: 'TCF',
  tef: 'TEF',
};

const MONTHS_FR = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const MONTHS_EN = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/** Rendu à la main plutôt qu'Intl : identique quelle que soit l'ICU du serveur. */
function formatDate(isoDate: string, lang: MatchLang): string {
  const [year, month, day] = isoDate.split('-').map(Number);
  if (!year || !month || !day) return isoDate;
  if (lang === 'en') return `${day} ${MONTHS_EN[month - 1]} ${year}`;
  return `${day === 1 ? '1er' : day} ${MONTHS_FR[month - 1]} ${year}`;
}

function levelName(level: EligibleLevel | undefined, lang: MatchLang): string {
  return level ? LEVEL_LABELS[level][lang] : '';
}

function levelList(levels: EligibleLevel[] | undefined, lang: MatchLang): string {
  return (levels ?? []).map((level) => LEVEL_LABELS[level][lang]).join(', ');
}

/** Au plus trois pays nommés, puis « … ». */
function countryList(codes: string[] | undefined, lang: MatchLang): string {
  const list = codes ?? [];
  const named = list.slice(0, 3).map((code) => countryName(code, lang));
  return list.length > 3 ? `${named.join(', ')}…` : named.join(', ');
}

function languageName(lang: string | undefined, target: MatchLang): string {
  if (!lang) return target === 'fr' ? 'langue' : 'language';
  return LANGUAGE_NAMES[lang]?.[target] ?? lang.toUpperCase();
}

function formatScore(value: string): string {
  const [type, score] = value.split(' ');
  return `${TEST_NAMES[type] ?? type.toUpperCase()} ${score ?? ''}`.trim();
}

/** Exigence de langue lisible : « IELTS 6.5 ou B2 ». */
function languageRequirement(p: MatchPointParams, lang: MatchLang): string {
  const parts = (p.tests ?? []).map(formatScore);
  if (p.minCefr) parts.push(p.minCefr.toUpperCase());
  return parts.join(lang === 'fr' ? ' ou ' : ' or ');
}

function asOfSuffix(p: MatchPointParams, lang: MatchLang): string {
  if (!p.asOfDate) return '';
  return lang === 'fr' ? ` au ${formatDate(p.asOfDate, 'fr')}` : ` on ${formatDate(p.asOfDate, 'en')}`;
}

/** Limite d'âge lisible : « 16 à 18 ans », « 29 ans au plus », « moins de 30 ans ». */
function ageLimit(p: MatchPointParams, lang: MatchLang): string {
  const { min, max } = p;
  const exclusive = max !== undefined && p.maxInclusive === false;
  if (lang === 'fr') {
    const upper = exclusive ? `moins de ${max} ans` : `${max} ans au plus`;
    if (min !== undefined && max !== undefined) {
      return exclusive ? `${min} ans au moins et ${upper}` : `${min} à ${max} ans`;
    }
    if (max !== undefined) return upper;
    if (min !== undefined) return `${min} ans au moins`;
    return 'limite d’âge';
  }
  const upper = exclusive ? `under ${max}` : `${max} years old at most`;
  if (min !== undefined && max !== undefined) {
    return exclusive ? `at least ${min} and ${upper}` : `${min} to ${max} years old`;
  }
  if (max !== undefined) return upper;
  if (min !== undefined) return `at least ${min} years old`;
  return 'age limit';
}

/** Forme courte après « Tu as 24 ans — » : « limite 29 ans », « limite : moins de 30 ans ». */
function shortAgeLimit(p: MatchPointParams, lang: MatchLang): string {
  if (p.max !== undefined) {
    if (p.maxInclusive === false) {
      return lang === 'fr' ? `limite : moins de ${p.max} ans` : `limit: under ${p.max}`;
    }
    return lang === 'fr' ? `limite ${p.max} ans` : `limit ${p.max}`;
  }
  if (p.min !== undefined) return lang === 'fr' ? `minimum ${p.min} ans` : `minimum ${p.min}`;
  return lang === 'fr' ? 'âge accepté' : 'age accepted';
}

/** « 24 mois » ; un ancien run sans paramètre renvoie à la condition officielle. */
function months(p: MatchPointParams, lang: MatchLang): string {
  if (p.minMonths === undefined) return lang === 'fr' ? 'voir la durée officielle' : 'see the official duration';
  return lang === 'fr' ? `${p.minMonths} mois` : `${p.minMonths} months`;
}

function gradeMin(p: MatchPointParams, lang: MatchLang): string {
  if (p.minOn20 === undefined) return '—';
  const value = String(p.minOn20);
  return `${lang === 'fr' ? value.replace('.', ',') : value}/20`;
}

type Renderer = (p: MatchPointParams) => string;

const LABELS: Record<MatchCode, { fr: Renderer; en: Renderer }> = {
  // ── Raisons ──
  level_accepted: {
    fr: (p) => `Niveau ${levelName(p.level, 'fr')} accepté`,
    en: (p) => `${levelName(p.level, 'en')} level accepted`,
  },
  nationality_accepted: {
    fr: (p) => `Ouverte à ta nationalité (${countryList(p.countries, 'fr')})`,
    en: (p) => `Open to your nationality (${countryList(p.countries, 'en')})`,
  },
  nationality_not_excluded: {
    fr: () => 'Ta nationalité n’est pas exclue',
    en: () => 'Your nationality is not excluded',
  },
  residence_accepted: {
    fr: (p) => `Ouverte aux résidents de ton pays (${countryList(p.countries, 'fr')})`,
    en: (p) => `Open to residents of your country (${countryList(p.countries, 'en')})`,
  },
  age_within_limit: {
    fr: (p) =>
      p.age !== undefined
        ? `Tu as ${p.age} ans — ${shortAgeLimit(p, 'fr')}${asOfSuffix(p, 'fr')}`
        : `Âge accepté (${ageLimit(p, 'fr')})`,
    en: (p) =>
      p.age !== undefined
        ? `You are ${p.age} — ${shortAgeLimit(p, 'en')}${asOfSuffix(p, 'en')}`
        : `Age accepted (${ageLimit(p, 'en')})`,
  },
  experience_sufficient: {
    fr: (p) => `Ton expérience pro suffit (${months(p, 'fr')} demandés)`,
    en: (p) => `Your work experience is enough (${months(p, 'en')} required)`,
  },
  language_sufficient: {
    fr: (p) => `Ton niveau en ${languageName(p.lang, 'fr')} suffit (${languageRequirement(p, 'fr')} demandé)`,
    en: (p) => `Your ${languageName(p.lang, 'en')} level is enough (${languageRequirement(p, 'en')} required)`,
  },
  grade_sufficient: {
    fr: (p) => `Ta moyenne suffit (${gradeMin(p, 'fr')} demandé)`,
    en: (p) => `Your grades are enough (${gradeMin(p, 'en')} required)`,
  },
  field_listed: {
    fr: () => 'Ton domaine fait partie des domaines acceptés',
    en: () => 'Your field is among the accepted fields',
  },
  fields_all: {
    fr: () => 'Tous les domaines sont acceptés',
    en: () => 'All fields of study are accepted',
  },
  destination_wanted: {
    fr: (p) => `Dans un pays que tu vises (${countryList(p.countries, 'fr')})`,
    en: (p) => `In a country you want (${countryList(p.countries, 'en')})`,
  },

  // ── À vérifier ──
  eligibility_not_structured: {
    fr: () => 'KPB n’a pas encore vérifié toutes les conditions de cette bourse',
    en: () => 'KPB has not yet checked all the conditions of this scholarship',
  },
  eligibility_stale: {
    fr: () => 'Conditions vérifiées par KPB il y a plus d’un an : relis la page officielle',
    en: () => 'KPB checked these conditions over a year ago: read the official page again',
  },
  criteria_not_structured: {
    fr: () => 'Conditions détaillées pas encore analysées par KPB',
    en: () => 'Detailed conditions not yet analysed by KPB',
  },
  criterion_unreadable: {
    fr: () => 'Une condition n’a pas pu être lue : vérifie la page officielle',
    en: () => 'One condition could not be read: check the official page',
  },
  profile_unconfirmed: {
    fr: () => 'Confirme tes réponses pour un résultat sûr',
    en: () => 'Confirm your answers for a reliable result',
  },
  level_missing: {
    fr: () => 'Indique le niveau que tu vises',
    en: () => 'Tell us which level you are aiming for',
  },
  level_check: {
    fr: (p) => `Niveaux annoncés : ${levelList(p.levels, 'fr')} — vérifie que ton niveau est accepté`,
    en: (p) => `Listed levels: ${levelList(p.levels, 'en')} — check that your level is accepted`,
  },
  nationality_missing: {
    fr: () => 'Indique ta nationalité pour vérifier cette condition',
    en: () => 'Add your nationality to check this condition',
  },
  residence_missing: {
    fr: () => 'Indique ton pays de résidence pour vérifier cette condition',
    en: () => 'Add your country of residence to check this condition',
  },
  nationality_check: {
    fr: (p) => `Condition de nationalité à vérifier (${countryList(p.countries, 'fr')})`,
    en: (p) => `Nationality condition to check (${countryList(p.countries, 'en')})`,
  },
  residence_check: {
    fr: (p) => `Condition de résidence à vérifier (${countryList(p.countries, 'fr')})`,
    en: (p) => `Residence condition to check (${countryList(p.countries, 'en')})`,
  },
  age_missing: {
    fr: () => 'Indique ta date de naissance pour vérifier la limite d’âge',
    en: () => 'Add your date of birth to check the age limit',
  },
  age_borderline: {
    fr: (p) => `Tu es proche de la limite d’âge (${ageLimit(p, 'fr')}) : vérifie la date de référence`,
    en: (p) => `You are close to the age limit (${ageLimit(p, 'en')}): check the reference date`,
  },
  age_check: {
    fr: (p) => `Limite d’âge à vérifier (${ageLimit(p, 'fr')}${asOfSuffix(p, 'fr')})`,
    en: (p) => `Age limit to check (${ageLimit(p, 'en')}${asOfSuffix(p, 'en')})`,
  },
  experience_missing: {
    fr: (p) => `Expérience pro demandée : ${months(p, 'fr')} — indique la tienne`,
    en: (p) => `Work experience required: ${months(p, 'en')} — add yours`,
  },
  experience_borderline: {
    fr: (p) => `Expérience pro demandée : ${months(p, 'fr')} — vérifie ton total exact`,
    en: (p) => `Work experience required: ${months(p, 'en')} — check your exact total`,
  },
  experience_check: {
    fr: (p) => `Expérience pro demandée : ${months(p, 'fr')} — à vérifier`,
    en: (p) => `Work experience required: ${months(p, 'en')} — to check`,
  },
  language_missing: {
    fr: (p) => `${languageRequirement(p, 'fr')} en ${languageName(p.lang, 'fr')} demandé — tu n’as pas indiqué de score`,
    en: (p) => `${languageRequirement(p, 'en')} in ${languageName(p.lang, 'en')} required — you have not added a score`,
  },
  language_below: {
    fr: (p) =>
      `${languageRequirement(p, 'fr')} en ${languageName(p.lang, 'fr')} demandé — ton niveau indiqué est peut-être plus bas` +
      (p.waivable ? ' (exigence parfois levée)' : ''),
    en: (p) =>
      `${languageRequirement(p, 'en')} in ${languageName(p.lang, 'en')} required — your stated level may be lower` +
      (p.waivable ? ' (sometimes waived)' : ''),
  },
  language_other: {
    fr: (p) => `Niveau en ${languageName(p.lang, 'fr')} demandé : vérifie la condition officielle`,
    en: (p) => `${languageName(p.lang, 'en')} level required: check the official condition`,
  },
  grade_missing: {
    fr: () => 'Indique ta moyenne pour vérifier cette condition',
    en: () => 'Add your average grade to check this condition',
  },
  grade_below: {
    fr: (p) => `Moyenne demandée : ${gradeMin(p, 'fr')} — la tienne est peut-être plus basse`,
    en: (p) => `Average required: ${gradeMin(p, 'en')} — yours may be lower`,
  },
  grade_check: {
    fr: () => 'Condition de notes à vérifier sur la page officielle',
    en: () => 'Grade condition to check on the official page',
  },
  field_not_listed: {
    fr: () => 'Ton domaine n’est pas dans la liste publiée : vérifie',
    en: () => 'Your field is not in the published list: check',
  },
  field_undecided: {
    fr: () => 'Bourse réservée à certains domaines : vérifie la liste',
    en: () => 'Scholarship limited to some fields: check the list',
  },
  condition_other: {
    fr: () => 'Condition particulière à vérifier',
    en: () => 'Specific condition to check',
  },

  // ── Exclusions ──
  level_other: {
    fr: (p) => `Vise un autre niveau (${levelList(p.levels, 'fr')})`,
    en: (p) => `For another level (${levelList(p.levels, 'en')})`,
  },
  nationality_not_listed: {
    fr: (p) => `Réservée à d’autres nationalités (${countryList(p.countries, 'fr')})`,
    en: (p) => `Only for other nationalities (${countryList(p.countries, 'en')})`,
  },
  nationality_excluded: {
    fr: (p) => `Fermée aux ressortissants de : ${countryList(p.countries, 'fr')}`,
    en: (p) => `Closed to nationals of: ${countryList(p.countries, 'en')}`,
  },
  residence_not_listed: {
    fr: (p) => `Réservée aux résidents d’autres pays (${countryList(p.countries, 'fr')})`,
    en: (p) => `Only for residents of other countries (${countryList(p.countries, 'en')})`,
  },
  residence_excluded: {
    fr: (p) => `Fermée aux résidents de : ${countryList(p.countries, 'fr')}`,
    en: (p) => `Closed to residents of: ${countryList(p.countries, 'en')}`,
  },
  age_too_young: {
    fr: (p) => `Âge demandé : ${ageLimit(p, 'fr')}${asOfSuffix(p, 'fr')}`,
    en: (p) => `Age required: ${ageLimit(p, 'en')}${asOfSuffix(p, 'en')}`,
  },
  age_too_old: {
    fr: (p) => `Âge demandé : ${ageLimit(p, 'fr')}${asOfSuffix(p, 'fr')}`,
    en: (p) => `Age required: ${ageLimit(p, 'en')}${asOfSuffix(p, 'en')}`,
  },
  experience_insufficient: {
    fr: (p) => `Expérience pro demandée : ${months(p, 'fr')} au moins`,
    en: (p) => `Work experience required: at least ${months(p, 'en')}`,
  },
  suspended: {
    fr: () => 'Session suspendue par l’organisme',
    en: () => 'Session suspended by the organisation',
  },
};

/** Libellé rendu d'un point, dans la langue demandée. */
export function renderPoint(point: MatchPoint, lang: MatchLang): string {
  return LABELS[point.code][lang](point.params ?? {});
}

/**
 * Ordre d'affichage des raisons positives : les plus parlantes d'abord
 * (« Ouverte aux ressortissants… », « Niveau Master accepté », l'âge…).
 */
const REASON_PRIORITY: readonly ReasonCode[] = [
  'nationality_accepted',
  'residence_accepted',
  'level_accepted',
  'age_within_limit',
  'field_listed',
  'experience_sufficient',
  'language_sufficient',
  'grade_sufficient',
  'destination_wanted',
  'fields_all',
  'nationality_not_excluded',
];

/** Les `limit` raisons à montrer sur une carte (≤ 3 par défaut). */
export function topReasons(
  points: readonly MatchPoint<ReasonCode>[],
  limit = 3,
): MatchPoint<ReasonCode>[] {
  return [...points]
    .sort((a, b) => REASON_PRIORITY.indexOf(a.code) - REASON_PRIORITY.indexOf(b.code))
    .slice(0, limit);
}

/** Codes exposés pour les tests de parité. */
export const ALL_MATCH_CODES: readonly MatchCode[] = [
  ...REASON_CODES,
  ...TO_VERIFY_CODES,
  ...EXCLUSION_CODES,
];

/** Vrai si un libellé KPB respecte l'invariant (ni « % » ni « chance »). */
export function isHonestLabel(text: string): boolean {
  return !text.includes('%') && !/chance/i.test(text);
}
