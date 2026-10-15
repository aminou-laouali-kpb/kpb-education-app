import { ORIENTATION_FIELDS } from '../orientation/orientation-fields.data';
import { isAtLeastAge, MINIMUM_ACCOUNT_AGE } from '../profiles/profile-age.policy';
import { countryName, normaliseCountryAnswer, normaliseResidence } from './countries';
import {
  DIPLOMAS,
  EXPERIENCE_BANDS,
  GRADE_BANDS,
  LANGUAGE_BANDS,
  legacyCompatibilityWrites,
  parseLanguageTests,
  TARGET_LEVELS,
  type LanguageTestScore,
} from './match-inputs';

/**
 * Les réponses du test (`answers` de `POST /scholarships/match/runs`), lues par
 * une garde écrite à la main — PAS par un DTO imbriqué.
 *
 * Pourquoi : `ValidationPipe` tourne en `forbidNonWhitelisted`. Un DTO imbriqué
 * (`@ValidateNested`) répondrait 400 à une clé de réponse qu'une app plus
 * récente connaît et que ce serveur ne connaît pas, et des `@IsIn` stricts à un
 * jeton nouveau. Ici, une clé inconnue, un jeton inconnu ou une valeur du
 * mauvais type sont ABANDONNÉS (comme `sanitizeOptOutTypes`), jamais refusés :
 * la requête aboutit, et `readiness` dit ce qui manque encore.
 *
 * Seul le corps de premier niveau (`lang`, `trigger`, `answers`, `confirm`)
 * est déclaré dans le DTO ; `answers` y est un simple objet.
 */

/** Clés de réponse comprises. Toute autre clé est ignorée. */
export const MATCH_ANSWER_KEYS = [
  'nationalityCode',
  'secondNationalityCode',
  'residence',
  'birthDate',
  'guardianName',
  'guardianContact',
  'guardianConsent',
  'highestDiploma',
  'scholarshipTargetLevel',
  'fieldIds',
  'targetCountryIds',
  'gradeBandOn20',
  'englishLevel',
  'frenchLevel',
  'languageTests',
  'workExperienceBand',
] as const;
export type MatchAnswerKey = (typeof MATCH_ANSWER_KEYS)[number];

/** Domaines proposés à l'étape « Domaine(s) » : ceux du catalogue (d01…d13). */
export const MATCH_FIELD_IDS: readonly string[] = ORIENTATION_FIELDS.map((field) => field.id);

/** Au plus trois domaines (trois puces) ; au-delà, les premiers. */
export const MAX_FIELD_ANSWERS = 3;

/** Destinations : code alpha-3 minuscule, ou `int` (programme multi-pays). */
const DESTINATION_ID = /^(?:[a-z]{3}|int)$/;

const MAX_GUARDIAN_TEXT = 120;

/**
 * Ce que les réponses écrivent sur `UserProfile`. Seules les clés présentes ET
 * valides y figurent ; `null` efface une valeur facultative.
 */
export interface MatchAnswersPatch {
  nationalityCode?: string;
  secondNationalityCode?: string | null;
  countryOfResidence?: string;
  birthDate?: Date;
  guardianName?: string;
  guardianContact?: string;
  /** Vrai : l'accord du représentant légal est donné (horodaté par le serveur). */
  guardianConsent?: true;
  highestDiploma?: string;
  scholarshipTargetLevel?: string;
  fieldIds?: string[];
  targetCountryIds?: string[];
  gradeBandOn20?: string;
  englishLevel?: string;
  frenchLevel?: string | null;
  languageTests?: LanguageTestScore[];
  workExperienceBand?: string;
  /** Écritures de compatibilité vers les anciens champs (univoques seulement). */
  languageLevel?: string;
  gradeRange?: string;
}

export interface ParsedMatchAnswers {
  patch: MatchAnswersPatch;
  /** Clés reçues mais abandonnées (inconnues ou valeur illisible), pour le journal. */
  ignored: string[];
}

function token(values: readonly string[], value: unknown): string | null {
  return typeof value === 'string' && values.includes(value.trim()) ? value.trim() : null;
}

function boundedText(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed && trimmed.length <= max ? trimmed : null;
}

/** `AAAA-MM-JJ` (ou un instant ISO) → minuit UTC de ce jour, ou null. */
export function parseBirthDate(value: unknown, now: Date): Date | null {
  if (typeof value !== 'string') return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})(?:T.*)?$/.exec(value.trim());
  if (!match) return null;
  const [, y, m, d] = match;
  const date = new Date(Date.UTC(Number(y), Number(m) - 1, Number(d)));
  // Un 30 février n'est pas ramené au 2 mars : il est abandonné.
  if (
    date.getUTCFullYear() !== Number(y) ||
    date.getUTCMonth() !== Number(m) - 1 ||
    date.getUTCDate() !== Number(d)
  ) {
    return null;
  }
  // Même plancher que le compte (16 ans) : en dessous, la valeur est abandonnée.
  if (!isAtLeastAge(date, MINIMUM_ACCOUNT_AGE, now)) return null;
  return date;
}

function stringArray(value: unknown): string[] | null {
  if (!Array.isArray(value)) return null;
  return value.filter((item): item is string => typeof item === 'string').map((item) => item.trim());
}

/**
 * La résidence telle qu'écrite dans `countryOfResidence` : le nom français,
 * apostrophe droite comme l'onboarding (« Côte d'Ivoire »), lu par les autres
 * consommateurs de ce champ libre (fuseau, pays suspendus EEF, pilote).
 */
export function residenceLabel(code: string): string {
  return countryName(code, 'fr').replace(/’/g, "'");
}

/**
 * Lit les réponses. Ne lève jamais. `currentResidence` évite de réécrire une
 * résidence déjà équivalente (« Niger » reste « Niger »).
 */
export function parseMatchAnswers(
  raw: unknown,
  now: Date,
  currentResidence?: string | null,
): ParsedMatchAnswers {
  const patch: MatchAnswersPatch = {};
  const ignored: string[] = [];
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return { patch, ignored };
  }
  const input = raw as Record<string, unknown>;
  const known = new Set<string>(MATCH_ANSWER_KEYS);

  const keep = (key: string, ok: boolean) => {
    if (!ok) ignored.push(key);
  };

  for (const key of Object.keys(input)) {
    if (!known.has(key)) ignored.push(key);
  }

  const has = (key: MatchAnswerKey) => Object.prototype.hasOwnProperty.call(input, key);

  if (has('nationalityCode')) {
    const code = normaliseCountryAnswer(input.nationalityCode);
    if (code) patch.nationalityCode = code;
    keep('nationalityCode', code !== null);
  }
  if (has('secondNationalityCode')) {
    const value = input.secondNationalityCode;
    if (value === null || value === '') {
      patch.secondNationalityCode = null;
    } else {
      const code = normaliseCountryAnswer(value);
      if (code) patch.secondNationalityCode = code;
      keep('secondNationalityCode', code !== null);
    }
  }
  if (has('residence')) {
    const code = normaliseCountryAnswer(input.residence);
    if (code && normaliseResidence(currentResidence ?? null) !== code) {
      patch.countryOfResidence = residenceLabel(code);
    }
    keep('residence', code !== null);
  }
  if (has('birthDate')) {
    const date = parseBirthDate(input.birthDate, now);
    if (date) patch.birthDate = date;
    keep('birthDate', date !== null);
  }
  if (has('guardianName')) {
    const text = boundedText(input.guardianName, MAX_GUARDIAN_TEXT);
    if (text) patch.guardianName = text;
    keep('guardianName', text !== null);
  }
  if (has('guardianContact')) {
    const text = boundedText(input.guardianContact, MAX_GUARDIAN_TEXT);
    if (text) patch.guardianContact = text;
    keep('guardianContact', text !== null);
  }
  if (has('guardianConsent')) {
    if (input.guardianConsent === true) patch.guardianConsent = true;
    keep('guardianConsent', input.guardianConsent === true);
  }

  const tokens: Array<[MatchAnswerKey, readonly string[]]> = [
    ['highestDiploma', DIPLOMAS],
    ['scholarshipTargetLevel', TARGET_LEVELS],
    ['gradeBandOn20', GRADE_BANDS],
    ['englishLevel', LANGUAGE_BANDS],
    ['workExperienceBand', EXPERIENCE_BANDS],
  ];
  for (const [key, values] of tokens) {
    if (!has(key)) continue;
    const value = token(values, input[key]);
    if (value) (patch as Record<string, unknown>)[key] = value;
    keep(key, value !== null);
  }
  if (has('frenchLevel')) {
    // Facultatif : `null` efface.
    if (input.frenchLevel === null) {
      patch.frenchLevel = null;
    } else {
      const value = token(LANGUAGE_BANDS, input.frenchLevel);
      if (value) patch.frenchLevel = value;
      keep('frenchLevel', value !== null);
    }
  }

  if (has('fieldIds')) {
    const list = stringArray(input.fieldIds);
    if (list) {
      // `[]` est une réponse : « Pas encore décidé ». Les domaines inconnus
      // sont abandonnés un par un, sans perdre les autres.
      const fields = list
        .filter((id, index) => MATCH_FIELD_IDS.includes(id) && list.indexOf(id) === index)
        .slice(0, MAX_FIELD_ANSWERS);
      if (list.length === 0 || fields.length > 0) patch.fieldIds = fields;
      keep('fieldIds', list.length === 0 || fields.length > 0);
    } else {
      keep('fieldIds', false);
    }
  }
  if (has('targetCountryIds')) {
    const list = stringArray(input.targetCountryIds);
    if (list) {
      const ids = list
        .map((id) => id.toLowerCase())
        .filter((id, index, all) => DESTINATION_ID.test(id) && all.indexOf(id) === index)
        .slice(0, 30);
      if (list.length === 0 || ids.length > 0) patch.targetCountryIds = ids;
      keep('targetCountryIds', list.length === 0 || ids.length > 0);
    } else {
      keep('targetCountryIds', false);
    }
  }
  if (has('languageTests')) {
    if (Array.isArray(input.languageTests)) {
      // La garde de match-inputs : chaque entrée invalide est abandonnée.
      patch.languageTests = parseLanguageTests(input.languageTests);
    } else {
      keep('languageTests', false);
    }
  }

  Object.assign(
    patch,
    legacyCompatibilityWrites({
      englishLevel: patch.englishLevel,
      gradeBandOn20: patch.gradeBandOn20,
    }),
  );

  return { patch, ignored };
}

/** Le trigger d'un run demandé par l'app ; `recompute` est réservé au serveur. */
export const CLIENT_RUN_TRIGGERS = ['wizard', 'rerun', 'stale_refresh', 'edit'] as const;
export type ClientRunTrigger = (typeof CLIENT_RUN_TRIGGERS)[number] | 'other';

export function parseTrigger(value: unknown): ClientRunTrigger {
  const found = token(CLIENT_RUN_TRIGGERS, value);
  return (found as ClientRunTrigger | null) ?? 'other';
}

export function parseLang(value: unknown): 'fr' | 'en' {
  return typeof value === 'string' && value.trim().toLowerCase().startsWith('en') ? 'en' : 'fr';
}
