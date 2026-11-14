/**
 * Specs Postgres : la session SQL est toujours en UTC.
 *
 * Prisma range ses `DateTime` dans des colonnes `timestamp(3)` SANS fuseau,
 * en heure UTC. Tout SQL brut qui compare ces colonnes à `now()` ou convertit
 * une date en `::timestamp(3)` dépend donc du fuseau de la SESSION. En CI et
 * en production, la base (image `postgres:15-alpine`) est en UTC. Le Postgres
 * Homebrew d'un Mac prend le fuseau de la machine (`Africa/Niamey`, UTC+1) :
 * `test:integration:opening-fanout` y échouait (7 tests sur 63, dont des
 * attentes de 180 s) alors qu'il passe en CI.
 *
 * Ce fichier ajoute `options=-c timezone=UTC` à DATABASE_URL avant le
 * chargement de chaque fichier de test, sauf si l'URL fixe déjà `options`.
 * Il n'agit que si KPB_RUN_POSTGRES_INTEGRATION=true : les tests unitaires
 * ne touchent à aucune base.
 */
const url = process.env.DATABASE_URL;

if (
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' &&
  url &&
  !/[?&]options=/.test(url)
) {
  const separator = url.includes('?') ? '&' : '?';
  process.env.DATABASE_URL = `${url}${separator}options=${encodeURIComponent('-c timezone=UTC')}`;
}
