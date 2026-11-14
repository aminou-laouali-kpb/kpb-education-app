import { Prisma } from '@prisma/client';

/**
 * Dates dans le SQL brut, indépendantes du fuseau de la session Postgres.
 *
 * Prisma range ses `DateTime` dans des colonnes `timestamp(3)` SANS fuseau,
 * en heure UTC. Mais dans une requête brute (`$queryRaw`, `$executeRaw`,
 * `Prisma.sql`), une date JavaScript arrive comme un `timestamptz`, et
 * `now()` est un `timestamptz`. Les comparer à une colonne, les y écrire ou
 * les convertir en `::timestamp(3)` passe par le fuseau de la SESSION : en
 * UTC (la production aujourd'hui) le résultat est juste, ailleurs il est
 * décalé de l'écart au fuseau (une heure au Niger, quatorze à Kiritimati).
 *
 * Toujours passer par ces deux formes, qui donnent un `timestamp` en UTC :
 *
 *   WHERE "createdAt" > ${utcTimestamp(since)}
 *   SET "updatedAt" = ${SQL_NOW_UTC}
 *
 * La CI rejoue les specs Postgres en `Pacific/Kiritimati` (UTC+14) pour le
 * vérifier (voir `backend/jest.postgres-utc.js`).
 */
export function utcTimestamp(date: Date): Prisma.Sql {
  return Prisma.sql`(${date}::timestamptz AT TIME ZONE 'UTC')`;
}

/** `now()` en heure UTC, comparable aux colonnes `timestamp(3)` de Prisma. */
export const SQL_NOW_UTC = Prisma.sql`(now() AT TIME ZONE 'UTC')`;
