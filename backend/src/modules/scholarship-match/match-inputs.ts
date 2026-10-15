import { createHash } from 'node:crypto';

import { levelsInText } from '../scholarships-index/scholarship-level';
import { normaliseCountryAnswer, normaliseResidence } from './countries';
import {
  ELIGIBLE_LEVELS,
  LANGUAGE_TEST_SCALES,
  LANGUAGE_TEST_TYPES,
  type EligibleLevel,
  type LanguageTestType,
} from './eligibility-criteria';

/**
 * Les entrées du moteur : jetons des réponses, normalisation du profil,
 * préparation (ce qui manque, ce qui reste à confirmer), pré-remplissage
 * depuis les anciens champs, empreinte du profil et écritures de
 * compatibilité vers ces anciens champs.
 *
 * Le SERVEUR possède ces listes : l'app ignore les clés qu'elle ne connaît pas,
 * et le serveur abandonne les jetons qu'il ne connaît pas (jamais de 400).
 */

export const DIPLOMAS = ['none', 'bac', 'bac_plus_2', 'licence', 'master', 'doctorat'] as const;
export type Diploma = (typeof DIPLOMAS)[number];

export const TARGET_LEVELS = ELIGIBLE_LEVELS;
export type TargetLevel = EligibleLevel;

export const GRADE_BANDS = ['lt10', '10_12', '12_14', '14_16', '16_plus'] as const;
export type GradeBand = (typeof GRADE_BANDS)[number];

export const LANGUAGE_BANDS = ['none', 'a1_a2', 'b1', 'b2', 'c1_c2'] as const;
export type LanguageBand = (typeof LANGUAGE_BANDS)[number];

export const EXPERIENCE_BANDS = ['none', 'lt12', '12_24', '24_36', '36_60', '60_plus'] as const;
export type ExperienceBand = (typeof EXPERIENCE_BANDS)[number];

/** Bornes (sur 20) d'une tranche de moyenne : [basse incluse, haute exclue). */
export const GRADE_BAND_BOUNDS: Record<GradeBand, readonly [number, number]> = {
  lt10: [0, 10],
  '10_12': [10, 12],
  '12_14': [12, 14],
  '14_16': [14, 16],
  '16_plus': [16, 20.01],
};

/**
 * Bornes en mois d'une tranche d'expérience, INCLUSES des deux côtés : un
 * élève à 24 mois tout juste peut cocher « 1-2 ans » comme « 2-3 ans », la
 * tranche « 1-2 ans » est donc lue jusqu'à 24 (lecture la plus favorable).
 */
export const EXPERIENCE_BAND_MONTHS: Record<ExperienceBand, readonly [number, number]> = {
  none: [0, 0],
  lt12: [1, 11],
  '12_24': [12, 24],
  '24_36': [24, 36],
  '36_60': [36, 60],
  '60_plus': [60, Number.POSITIVE_INFINITY],
};

/** Rang CECRL d'une tranche de langue : [plus bas, plus haut] (a1 = 1 … c2 = 6). */
export const LANGUAGE_BAND_CEFR: Record<LanguageBand, readonly [number, number]> = {
  none: [0, 0],
  a1_a2: [1, 2],
  b1: [3, 3],
  b2: [4, 4],
  c1_c2: [5, 6],
};

export interface LanguageTestScore {
  type: LanguageTestType;
  score: number;
  /** AAAA-MM-JJ. */
  takenAt?: string;
}

/** Ce que le moteur lit du profil (sous-ensemble de UserProfile). */
export interface MatchProfileSource {
  nationalityCode?: string | null;
  secondNationalityCode?: string | null;
  countryOfResidence?: string | null;
  birthDate?: Date | null;
  guardianConsentedAt?: Date | null;
  highestDiploma?: string | null;
  scholarshipTargetLevel?: string | null;
  fieldIds?: readonly string[] | null;
  targetCountryIds?: readonly string[] | null;
  gradeBandOn20?: string | null;
  englishLevel?: string | null;
  frenchLevel?: string | null;
  languageTests?: unknown;
  workExperienceBand?: string | null;
  scholarshipProfileConfirmedAt?: Date | null;
  // Anciens champs, lus pour le pré-remplissage seulement.
  currentLevel?: string | null;
  targetLevel?: string | null;
  languageLevel?: string | null;
  gradeRange?: string | null;
}

/** Profil normalisé : seulement des jetons connus, des codes ISO, des dates. */
export interface MatchProfile {
  /** Nationalités déclarées, la principale d'abord, sans doublon. */
  nationalities: string[];
  residenceCode: string | null;
  birthDate: Date | null;
  guardianConsented: boolean;
  highestDiploma: Diploma | null;
  targetLevel: TargetLevel | null;
  fieldIds: string[];
  targetCountryIds: string[];
  gradeBand: GradeBand | null;
  englishLevel: LanguageBand | null;
  frenchLevel: LanguageBand | null;
  languageTests: LanguageTestScore[];
  workExperienceBand: ExperienceBand | null;
  /** Récapitulatif validé par l'élève : seule condition pour qu'une valeur exclue. */
  confirmed: boolean;
}

function token<T extends string>(values: readonly T[], value: unknown): T | null {
  return typeof value === 'string' && (values as readonly string[]).includes(value)
    ? (value as T)
    : null;
}

function validDate(value: unknown): Date | null {
  return value instanceof Date && !Number.isNaN(value.getTime()) ? value : null;
}

function stringList(value: readonly string[] | null | undefined, max = 20): string[] {
  if (!Array.isArray(value)) return [];
  const out: string[] = [];
  for (const item of value) {
    if (typeof item !== 'string') continue;
    const trimmed = item.trim();
    if (trimmed && trimmed.length <= 64 && !out.includes(trimmed)) out.push(trimmed);
    if (out.length >= max) break;
  }
  return out;
}

/**
 * `languageTests` lu par une garde : chaque entrée invalide est abandonnée,
 * une par type au plus (la meilleure).
 */
export function parseLanguageTests(value: unknown): LanguageTestScore[] {
  if (!Array.isArray(value)) return [];
  const best = new Map<LanguageTestType, LanguageTestScore>();
  for (const raw of value.slice(0, 10)) {
    if (typeof raw !== 'object' || raw === null) continue;
    const entry = raw as Record<string, unknown>;
    const type = token(LANGUAGE_TEST_TYPES, entry.type);
    if (!type) continue;
    const score = typeof entry.score === 'string' ? Number(entry.score.replace(',', '.')) : entry.score;
    const scale = LANGUAGE_TEST_SCALES[type];
    if (typeof score !== 'number' || !Number.isFinite(score) || score < scale.min || score > scale.max) {
      continue;
    }
    const takenAt =
      typeof entry.takenAt === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(entry.takenAt)
        ? entry.takenAt
        : undefined;
    const previous = best.get(type);
    if (!previous || previous.score < score) {
      best.set(type, { type, score, ...(takenAt ? { takenAt } : {}) });
    }
  }
  return LANGUAGE_TEST_TYPES.filter((type) => best.has(type)).map((type) => best.get(type)!);
}

/** Normalise le profil : tout jeton inconnu devient null, jamais une erreur. */
export function normaliseProfile(source: MatchProfileSource): MatchProfile {
  const first = normaliseCountryAnswer(source.nationalityCode);
  const second = normaliseCountryAnswer(source.secondNationalityCode);
  const nationalities = [first, second].filter(
    (code, index, all): code is string => !!code && all.indexOf(code) === index,
  );
  return {
    nationalities,
    residenceCode: normaliseResidence(source.countryOfResidence),
    birthDate: validDate(source.birthDate),
    guardianConsented: validDate(source.guardianConsentedAt) !== null,
    highestDiploma: token(DIPLOMAS, source.highestDiploma),
    targetLevel: token(TARGET_LEVELS, source.scholarshipTargetLevel),
    fieldIds: stringList(source.fieldIds),
    targetCountryIds: stringList(source.targetCountryIds, 30),
    gradeBand: token(GRADE_BANDS, source.gradeBandOn20),
    englishLevel: token(LANGUAGE_BANDS, source.englishLevel),
    frenchLevel: token(LANGUAGE_BANDS, source.frenchLevel),
    languageTests: parseLanguageTests(source.languageTests),
    workExperienceBand: token(EXPERIENCE_BANDS, source.workExperienceBand),
    confirmed: validDate(source.scholarshipProfileConfirmedAt) !== null,
  };
}

// ── Âge ─────────────────────────────────────────────────────────────────────

/**
 * Âge révolu (en années) à une date, en calendrier UTC. Né un 29 février :
 * l'année non bissextile, l'anniversaire tombe le 1er mars.
 */
export function ageOn(birthDate: Date, on: Date): number {
  let age = on.getUTCFullYear() - birthDate.getUTCFullYear();
  const beforeBirthday =
    on.getUTCMonth() < birthDate.getUTCMonth() ||
    (on.getUTCMonth() === birthDate.getUTCMonth() && on.getUTCDate() < birthDate.getUTCDate());
  if (beforeBirthday) age -= 1;
  return age;
}

// ── Préparation ─────────────────────────────────────────────────────────────

export const REQUIRED_KEYS = [
  'nationalityCode',
  'residence',
  'birthDate',
  'guardianConsent',
  'highestDiploma',
  'scholarshipTargetLevel',
  'fields',
  'gradeBandOn20',
  'englishLevel',
  'workExperienceBand',
] as const;
export type RequiredKey = (typeof REQUIRED_KEYS)[number];

export const OPTIONAL_KEYS = [
  'targetCountryIds',
  'frenchLevel',
  'languageTests',
  'secondNationalityCode',
] as const;
export type OptionalKey = (typeof OPTIONAL_KEYS)[number];

export type ReadinessKey = RequiredKey | OptionalKey;

export interface Readiness {
  /** Vrai quand rien ne manque ET que le récapitulatif a été validé. */
  ready: boolean;
  /** Clés obligatoires sans valeur. */
  required: RequiredKey[];
  /** Valeurs utilisées mais pas encore confirmées par l'élève. */
  toConfirm: ReadinessKey[];
  /** Compléments facultatifs encore vides (« améliore la précision »). */
  optional: OptionalKey[];
  /** Niveaux proposables à l'étape « Tu vises une bourse pour ». */
  targetLevelOptions: TargetLevel[];
}

/** Le lycée international (UWC) n'est proposé que jusqu'à 19 ans (UWC Kenya). */
export const SECONDARY_MAX_AGE = 19;

export interface ReadinessOptions {
  /** Le catalogue sert-il au moins une bourse de lycée ? (défaut : oui) */
  hasSecondaryCandidates?: boolean;
}

/**
 * Ce qui manque et ce qui reste à confirmer.
 *
 * Obligatoires : nationalité, résidence normalisable, date de naissance,
 * diplôme, niveau visé, domaines (ou « pas encore décidé » confirmé),
 * moyenne, anglais ; l'expérience pour un Master ou un Doctorat ; l'accord du
 * représentant légal pour un mineur.
 */
export function readiness(
  profile: MatchProfile,
  now: Date,
  options: ReadinessOptions = {},
): Readiness {
  const age = profile.birthDate ? ageOn(profile.birthDate, now) : null;
  const present: Record<RequiredKey, boolean | null> = {
    nationalityCode: profile.nationalities.length > 0,
    residence: profile.residenceCode !== null,
    birthDate: profile.birthDate !== null,
    // null = clé sans objet pour ce profil.
    guardianConsent: age !== null && age < 18 ? profile.guardianConsented : null,
    highestDiploma: profile.highestDiploma !== null,
    scholarshipTargetLevel: profile.targetLevel !== null,
    // « Pas encore décidé » est une réponse : une liste vide CONFIRMÉE suffit.
    fields: profile.fieldIds.length > 0 || profile.confirmed,
    gradeBandOn20: profile.gradeBand !== null,
    englishLevel: profile.englishLevel !== null,
    workExperienceBand:
      profile.targetLevel === 'master' || profile.targetLevel === 'doctorate'
        ? profile.workExperienceBand !== null
        : null,
  };
  const optionalPresent: Record<OptionalKey, boolean> = {
    targetCountryIds: profile.targetCountryIds.length > 0,
    frenchLevel: profile.frenchLevel !== null,
    languageTests: profile.languageTests.length > 0,
    secondNationalityCode: profile.nationalities.length > 1,
  };

  const required = REQUIRED_KEYS.filter((key) => present[key] === false);
  const toConfirm: ReadinessKey[] = profile.confirmed
    ? []
    : [
        // L'accord parental n'est pas une valeur à relire : il ne se « confirme » pas.
        ...REQUIRED_KEYS.filter((key) => key !== 'guardianConsent' && present[key] === true),
        ...OPTIONAL_KEYS.filter((key) => optionalPresent[key]),
      ];
  const optional = OPTIONAL_KEYS.filter((key) => !optionalPresent[key]);

  const offerSecondary =
    age !== null && age <= SECONDARY_MAX_AGE && options.hasSecondaryCandidates !== false;
  const targetLevelOptions = TARGET_LEVELS.filter(
    (level) => level !== 'secondary' || offerSecondary,
  );

  return {
    ready: required.length === 0 && toConfirm.length === 0,
    required,
    toConfirm,
    optional,
    targetLevelOptions,
  };
}

// ── Pré-remplissage depuis les anciens champs ───────────────────────────────

export type PrefillKey =
  | 'nationalityCode'
  | 'residence'
  | 'highestDiploma'
  | 'scholarshipTargetLevel'
  | 'gradeBandOn20'
  | 'englishLevel';

export interface PrefillSuggestion {
  key: PrefillKey;
  value: string;
  /** Champ d'origine. */
  source: 'countryOfResidence' | 'currentLevel' | 'targetLevel' | 'languageLevel' | 'gradeRange';
  /**
   * Vrai quand l'ancienne valeur ne se ramène pas exactement à un jeton
   * (« 15+/20 » couvre 14-16 ET 16+) : l'app DOIT poser la question, pas
   * seulement l'afficher au récapitulatif. Un pré-remplissage n'est de toute
   * façon jamais une valeur confirmée.
   */
  ambiguous: boolean;
}

function fold(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9+]+/g, ' ')
    .trim();
}

/**
 * Année en cours (`currentLevel` : « High school », « Terminale »,
 * « Bachelor 2 », « Master 1 », « Doctorat »… ; voir study_level.dart côté
 * app) → plus haut diplôme OBTENU. Toujours approximatif : on ne sait pas si
 * l'année en cours est validée.
 */
export function diplomaFromCurrentLevel(currentLevel: string | null | undefined): Diploma | null {
  if (!currentLevel) return null;
  const s = fold(currentLevel).replace(/\s+/g, '');
  if (!s) return null;
  if (s.includes('highschool') || s.includes('terminale') || s.includes('lycee') || s === 'bac') {
    return 'none';
  }
  if (s.includes('doctorat') || s.includes('phd') || s.includes('these')) return 'master';
  if (/^(?:master|m)[12]?$/.test(s) || s.includes('master')) return 'licence';
  if (/(?:bachelor|licence|l|b)3/.test(s)) return 'bac_plus_2';
  if (/(?:bachelor|licence|l|b)[12]/.test(s) || s.includes('bachelor') || s.includes('licence')) {
    return 'bac';
  }
  return null;
}

/** Ancien `targetLevel` (« Bachelor », « Master », « PhD », « Licence »…). */
export function targetFromLegacy(targetLevel: string | null | undefined): TargetLevel | null {
  const levels = [...levelsInText(targetLevel)];
  return levels.length === 1 ? levels[0] : null;
}

/** Ancien `languageLevel` (Beginner / Intermediate / Advanced, ou libellé FR). */
const LANGUAGE_LEVEL_PREFILL: Record<string, { value: LanguageBand; ambiguous: boolean }> = {
  beginner: { value: 'a1_a2', ambiguous: false },
  debutant: { value: 'a1_a2', ambiguous: false },
  intermediate: { value: 'b1', ambiguous: false },
  intermediaire: { value: 'b1', ambiguous: false },
  // « Avancé » couvre B2 comme C1-C2 : la tranche la plus basse, à confirmer.
  advanced: { value: 'b2', ambiguous: true },
  avance: { value: 'b2', ambiguous: true },
};

/** Anciennes fourchettes `gradeRange` (onboarding_m2_constants.dart). */
const GRADE_RANGE_PREFILL: Record<string, { value: GradeBand; ambiguous: boolean }> = {
  '10 12/20': { value: '10_12', ambiguous: false },
  '12 14/20': { value: '12_14', ambiguous: false },
  // « 15+ » couvre 14-16 ET 16+ : la tranche la plus basse, TOUJOURS à confirmer.
  '15+/20': { value: '14_16', ambiguous: true },
};

function gradeRangeKey(gradeRange: string): string {
  return gradeRange
    .toLowerCase()
    .replace(/\s*\/\s*/g, '/')
    .replace(/\s*[-–]\s*/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Suggestions pour les clés encore vides, tirées des anciens champs. Jamais
 * écrites telles quelles : l'élève les voit au récapitulatif et les valide.
 */
export function prefill(source: MatchProfileSource, profile: MatchProfile): PrefillSuggestion[] {
  const out: PrefillSuggestion[] = [];
  if (profile.residenceCode !== null && !source.nationalityCode) {
    // « Tu vis au Niger — nationalité nigérienne ? »
    out.push({
      key: 'nationalityCode',
      value: profile.residenceCode,
      source: 'countryOfResidence',
      ambiguous: true,
    });
  }
  if (profile.residenceCode !== null) {
    out.push({
      key: 'residence',
      value: profile.residenceCode,
      source: 'countryOfResidence',
      ambiguous: false,
    });
  }
  if (profile.highestDiploma === null) {
    const diploma = diplomaFromCurrentLevel(source.currentLevel);
    if (diploma) {
      out.push({ key: 'highestDiploma', value: diploma, source: 'currentLevel', ambiguous: true });
    }
  }
  if (profile.targetLevel === null) {
    const target = targetFromLegacy(source.targetLevel);
    if (target) {
      out.push({
        key: 'scholarshipTargetLevel',
        value: target,
        source: 'targetLevel',
        ambiguous: false,
      });
    }
  }
  if (profile.englishLevel === null && source.languageLevel) {
    const mapped = LANGUAGE_LEVEL_PREFILL[fold(source.languageLevel)];
    if (mapped) out.push({ key: 'englishLevel', source: 'languageLevel', ...mapped });
  }
  if (profile.gradeBand === null && source.gradeRange) {
    const mapped = GRADE_RANGE_PREFILL[gradeRangeKey(source.gradeRange)];
    if (mapped) out.push({ key: 'gradeBandOn20', source: 'gradeRange', ...mapped });
  }
  return out;
}

// ── Écritures de compatibilité vers les anciens champs ──────────────────────

/**
 * Quand l'élève enregistre `englishLevel` ou `gradeBandOn20`, l'ancien champ
 * est réécrit SI la correspondance est univoque — le matching écoles
 * (`gradeRangeMidpoint`, matching.ts) et les anciennes builds restent alignés.
 * Sinon on ne touche pas l'ancien champ.
 */
const ENGLISH_TO_LEGACY: Partial<Record<LanguageBand, string>> = {
  a1_a2: 'Beginner',
  b1: 'Intermediate',
  // b2 : entre « Intermediate » et « Advanced », rien d'univoque.
  c1_c2: 'Advanced',
};

const GRADE_TO_LEGACY: Partial<Record<GradeBand, string>> = {
  // lt10 : aucune ancienne fourchette en dessous de 10.
  '10_12': '10 - 12/20',
  '12_14': '12 - 14/20',
  // 14_16 : ni « 12 - 14 » ni « 15+ ».
  '16_plus': '15+/20',
};

export function legacyCompatibilityWrites(answers: {
  englishLevel?: string | null;
  gradeBandOn20?: string | null;
}): { languageLevel?: string; gradeRange?: string } {
  const out: { languageLevel?: string; gradeRange?: string } = {};
  const english = token(LANGUAGE_BANDS, answers.englishLevel);
  if (english && ENGLISH_TO_LEGACY[english]) out.languageLevel = ENGLISH_TO_LEGACY[english];
  const grade = token(GRADE_BANDS, answers.gradeBandOn20);
  if (grade && GRADE_TO_LEGACY[grade]) out.gradeRange = GRADE_TO_LEGACY[grade];
  return out;
}

// ── Empreinte ───────────────────────────────────────────────────────────────

/** JSON canonique : clés d'objet triées récursivement, dates en ISO. */
export function stableStringify(value: unknown): string {
  if (value instanceof Date) return JSON.stringify(value.toISOString());
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  if (value && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, v]) => v !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${stableStringify(v)}`).join(',')}}`;
  }
  return JSON.stringify(value ?? null);
}

export function stableHash(value: unknown): string {
  return createHash('sha256').update(stableStringify(value)).digest('hex');
}

/**
 * Empreinte de ce que le moteur lit du profil, indépendante de l'ordre des
 * clés et de l'ordre des listes sans ordre (domaines, destinations). Le jour
 * de naissance seul compte, pas l'heure. Change avec la confirmation, qui
 * change ce qui peut exclure.
 */
export function profileHash(profile: MatchProfile): string {
  return stableHash({
    ...profile,
    birthDate: profile.birthDate ? profile.birthDate.toISOString().slice(0, 10) : null,
    fieldIds: [...profile.fieldIds].sort(),
    targetCountryIds: [...profile.targetCountryIds].sort(),
  });
}
