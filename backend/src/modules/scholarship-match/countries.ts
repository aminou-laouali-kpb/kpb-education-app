import {
  countryName,
  ISO_COUNTRIES,
  isSelectableCountryCode,
  resolveCountryCode,
} from '../../common/iso-countries';

/**
 * Pays pour « Mes 10 bourses » : la table vit dans `common/iso-countries.ts`
 * (partagée avec `country-timezone.ts`) ; ce fichier n'ajoute que ce qui est
 * propre au test — l'ordre de la liste servie et la normalisation des réponses.
 */

export type MatchLang = 'fr' | 'en';

/**
 * En tête de liste, dans cet ordre : l'Afrique francophone de l'Ouest et du
 * Centre (le public KPB), y compris Tchad, Gabon, Congo, RDC, Centrafrique,
 * Madagascar, Comores et Djibouti que la liste de l'onboarding oubliait, puis
 * le reste de l'Afrique francophone. Tout le reste suit par ordre alphabétique
 * de la langue demandée.
 */
export const PRIORITY_COUNTRY_CODES: readonly string[] = [
  'ner',
  'sen',
  'civ',
  'mli',
  'bfa',
  'gin',
  'ben',
  'tgo',
  'mrt',
  'cmr',
  'tcd',
  'gab',
  'cog',
  'cod',
  'caf',
  'gnq',
  'bdi',
  'rwa',
  'mdg',
  'com',
  'dji',
  'mar',
  'dza',
  'tun',
];

export interface CountryOption {
  code: string;
  name: string;
  /** Vrai pour les pays du groupe de tête (séparateur côté app). */
  priority: boolean;
}

/** La liste de pays servie (nationalité, résidence), dans la langue demandée. */
export function countryOptions(lang: MatchLang): CountryOption[] {
  const priority = new Set(PRIORITY_COUNTRY_CODES);
  const head = PRIORITY_COUNTRY_CODES.map((code) => ({
    code,
    name: countryName(code, lang),
    priority: true,
  }));
  const collator = new Intl.Collator(lang, { sensitivity: 'base' });
  const tail = ISO_COUNTRIES.filter(
    (country) => !priority.has(country.code) && isSelectableCountryCode(country.code),
  )
    .map((country) => ({
      code: country.code,
      name: countryName(country.code, lang),
      priority: false,
    }))
    .sort((a, b) => collator.compare(a.name, b.name) || a.code.localeCompare(b.code));
  return [...head, ...tail];
}

/**
 * Une réponse de nationalité (ou de pays de résidence) en code alpha-3, ou
 * null : un code inconnu ou un territoire inhabité est ABANDONNÉ, jamais
 * deviné ni refusé avec une 400.
 */
export function normaliseCountryAnswer(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const code = resolveCountryCode(value);
  return code && isSelectableCountryCode(code) ? code : null;
}

/** La résidence libre de l'onboarding (« Sénégal », « RDC », « Autre »…). */
export function normaliseResidence(value: string | null | undefined): string | null {
  return normaliseCountryAnswer(value ?? null);
}

export { countryName, isSelectableCountryCode };
