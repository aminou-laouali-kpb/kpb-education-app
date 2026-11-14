/**
 * Specs Postgres : fuseau de la session SQL imposé.
 *
 * Prisma range ses `DateTime` dans des colonnes `timestamp(3)` SANS fuseau,
 * en heure UTC, et passe les dates JavaScript des requêtes brutes comme des
 * `timestamptz`. Un SQL brut qui compare l'un à l'autre, convertit en
 * `::timestamp(3)` ou écrit `now()` dans une colonne dépend donc du fuseau
 * de la SESSION. Le SQL du backend est écrit pour n'en pas dépendre
 * (`(… ::timestamptz AT TIME ZONE 'UTC')`, `(now() AT TIME ZONE 'UTC')`).
 *
 * Par défaut la session est en UTC, comme la production (`postgres:15-alpine`).
 * `KPB_POSTGRES_TEST_TIMEZONE` en impose un autre : la CI rejoue les specs
 * Postgres en `Pacific/Kiritimati` (UTC+14) pour prouver que le SQL ne dépend
 * pas du fuseau. Le Postgres Homebrew d'un Mac, lui, est en `Africa/Niamey`.
 *
 * Ce fichier ajoute `options=-c timezone=…` à DATABASE_URL avant chaque
 * fichier de test, sauf si l'URL fixe déjà `options`. Il n'agit que si
 * KPB_RUN_POSTGRES_INTEGRATION=true : les tests unitaires ne touchent à
 * aucune base.
 */
const url = process.env.DATABASE_URL;
const timezone = process.env.KPB_POSTGRES_TEST_TIMEZONE?.trim() || 'UTC';

if (
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' &&
  url &&
  !/[?&]options=/.test(url)
) {
  const separator = url.includes('?') ? '&' : '?';
  process.env.DATABASE_URL = `${url}${separator}options=${encodeURIComponent(`-c timezone=${timezone}`)}`;
}
