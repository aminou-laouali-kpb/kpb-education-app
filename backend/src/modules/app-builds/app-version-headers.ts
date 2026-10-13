/**
 * Lecture des en-têtes de version posés par l'app depuis la build 54
 * (`lib/app/core/repositories/app_version_headers.dart`).
 *
 * Ces en-têtes sont informatifs et viennent d'un client : on les lit comme une
 * entrée hostile. Une valeur absente, répétée, trop longue ou mal formée vaut
 * « inconnue » — jamais une erreur, jamais une requête refusée. Les builds 53
 * et antérieures n'envoient rien et doivent continuer de fonctionner à
 * l'identique.
 */

/** Noms tels que Node les expose : toujours en minuscules. */
export const APP_VERSION_HEADER = 'x-kpb-app-version';
export const APP_BUILD_HEADER = 'x-kpb-app-build';

const MAX_VERSION_LENGTH = 32;

/**
 * Une version d'app, rien d'autre : `2.3.0`, éventuellement suivie d'un
 * suffixe `-beta.1` ou `+56`. Le motif est volontairement étroit — la valeur
 * finit en clé d'un tableau de back-office, et un en-tête libre y ferait
 * entrer n'importe quel texte saisi par n'importe quel client.
 */
const VERSION_PATTERN = /^\d+(\.\d+){0,3}([+-][0-9A-Za-z.-]+)?$/;

/** Entier strictement positif et < 10 000 000 : sept chiffres au plus. */
const BUILD_PATTERN = /^\d{1,7}$/;

export interface AppVersionReading {
  version: string | null;
  build: number | null;
}

export type IncomingHeaders = Readonly<
  Record<string, string | string[] | undefined>
>;

/**
 * Un en-tête répété arrive en tableau, ou joint par `, ` selon le nom : les
 * deux formes sont ambiguës, donc ignorées.
 */
function singleValue(raw: string | string[] | undefined): string | null {
  if (typeof raw !== 'string') return null;
  const value = raw.trim();
  return value.length > 0 ? value : null;
}

export function parseAppVersion(
  raw: string | string[] | undefined,
): string | null {
  const value = singleValue(raw);
  if (!value || value.length > MAX_VERSION_LENGTH) return null;
  return VERSION_PATTERN.test(value) ? value : null;
}

export function parseAppBuild(
  raw: string | string[] | undefined,
): number | null {
  const value = singleValue(raw);
  if (!value || !BUILD_PATTERN.test(value)) return null;
  const build = Number(value);
  return build > 0 ? build : null;
}

export function parseAppVersionHeaders(
  headers: IncomingHeaders | undefined,
): AppVersionReading {
  return {
    version: parseAppVersion(headers?.[APP_VERSION_HEADER]),
    build: parseAppBuild(headers?.[APP_BUILD_HEADER]),
  };
}
