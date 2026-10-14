// ─────────────────────────────────────────────────────────────────────────────
// « Qui suit cette bourse ? » — la seule définition SQL, partagée.
//
//   suit(u, s)            = un favori (SavedItem 'scholarship') OU une alerte
//                           « M'avertir » non mise en sourdine ;
//   prévenu à l'ouverture = suit(u, s) ET aucune alerte (u, s) en sourdine — la
//                           sourdine prime sur le favori.
//
// L'aperçu admin, le compte de `activate` et l'INSERT de l'envoi partent du
// MÊME texte (`followerRowsCte`) : à données égales, « 312 seront prévenus » à
// l'aperçu, `toNotify = 312` à la confirmation et 312 lignes écrites. Trois
// requêtes écrites à la main auraient divergé à la première correction.
//
// Les favoris orphelins (`itemId` d'une bourse supprimée : SavedItem n'a pas de
// clé étrangère) sont ignorés : chaque favori est joint à "Scholarship".
//
// Ces fonctions ne font que CONSTRUIRE des `Prisma.Sql` ; elles ne lisent rien.
// Aucun paramètre n'est jamais NULL (PostgreSQL ne sait pas typer `$1 IS NULL`) :
// les absences changent le texte, pas les valeurs.
// ─────────────────────────────────────────────────────────────────────────────

import { Prisma } from '@prisma/client';

import {
  FOLLOWED_SCHOLARSHIP_OPT_OUT,
  openingDedupeKey,
  SCHOLARSHIP_OPENED_KIND,
  type OpeningAudienceScope,
} from './scholarship-opening.contract';

/** Une ligne de `follow_rows` : un candidat de la portée, ou un exclu par sourdine. */
export interface FollowerRow {
  userId: string;
  /** Un favori existe. */
  viaFavorite: boolean;
  /** Une alerte non mise en sourdine existe. */
  viaAlert: boolean;
  /** Une alerte en sourdine existe : jamais prévenu, quoi qu'il suive. */
  muted: boolean;
  /** `pushEnabled` de l'alerte (vrai sans alerte). */
  pushEnabled: boolean;
  /** `followed_scholarship_updates` dans `disabledNotificationTypes`. */
  optedOut: boolean;
  /** Début du suivi : le plus ancien du favori et de l'alerte non en sourdine (l'alerte seule en portée `alerts`). */
  followSince: Date | null;
  /** Déjà une ligne pour ce cycle (`dedupeKey`). */
  alreadyNotified: boolean;
  /** Une ligne `scholarship_opened` d'un AUTRE cycle de la bourse depuis `renotifySince`. */
  recentlyNotified: boolean;
  /** Relance seulement : suivait déjà à la première annonce (`followSince` ≤ `openingNotifiedAt`). */
  followedBeforeAnnouncement: boolean;
  /** Sera écrit par l'envoi : aucune des quatre exclusions ci-dessus. */
  toNotify: boolean;
  /** Au moins un jeton FCM (build récente) ; sinon OneSignal, anciennes builds. */
  hasFcmDevice: boolean;
  preferredLanguage: string;
  countryOfResidence: string;
}

/**
 * Le texte commun : `WITH … follow_rows AS (…)`, prêt à recevoir
 * `SELECT … FROM follow_rows` ou `INSERT … SELECT … FROM follow_rows`.
 *
 * Candidats : toutes les alertes de la bourse (en sourdine comprises, pour les
 * compter) et, en portée `followers`, tous ses favoris.
 *
 * Forme choisie pour que le plan NE DÉPENDE PAS des estimations du
 * planificateur (statistiques périmées juste après une vague de favoris, base
 * jamais analysée) : aucune jointure entre deux ensembles dérivés. La version
 * précédente joignait l'union des candidats à la CTE des favoris, matérialisée
 * donc sans index : estimée à 1 ligne, elle devenait la boucle interne d'une
 * boucle imbriquée — n × n comparaisons (2,8 s à 5 000 abonnés, plus que les
 * 30 s d'`activate` vers 20 000). Ici :
 *   1. `follow_src` : favoris, alertes et annonces récentes de la bourse, mis
 *      bout à bout (`UNION ALL`, une lecture chacun) ;
 *   2. `follow_user` : une ligne par étudiant (`GROUP BY`, linéaire quel que
 *      soit le plan : hachage ou tri) — unicités (étudiant, bourse) du favori
 *      et de l'alerte, donc au plus une valeur de chaque ;
 *   3. `follow_base` : par étudiant, des recherches PAR CLÉ seulement (profil
 *      par sa clé primaire en `LATERAL`, `dedupeKey` unique, jeton FCM par son
 *      index) — calculée une fois (`MATERIALIZED`), les filtres de
 *      `follow_rows` la relisent sans recalculer les sous-requêtes.
 * Sémantique inchangée, prouvée contre l'ancien texte sur des données tirées
 * au hasard (`scholarship-follow.query.postgres.spec.ts`).
 *
 * @param scholarshipId bourse annoncée
 * @param scope portée figée de l'annonce
 * @param cycleId cycle annoncé ; `null` = cycle pas encore créé (aperçu d'une
 *   nouvelle année) : personne n'est « déjà prévenu »
 * @param renotifySince une ligne d'un autre cycle de la même bourse créée après
 *   cet instant exclut l'étudiant (`createdAt`, car les lignes héritées n'ont
 *   jamais de `pushedAt`)
 * @param followSince `openingNotifiedAt` sur une relance d'un cycle déjà
 *   annoncé ; `null` pour une première annonce
 */
export function followerRowsCte(
  scholarshipId: string,
  scope: OpeningAudienceScope,
  cycleId: string | null,
  renotifySince: Date,
  followSince: Date | null,
): Prisma.Sql {
  // Candidats : en portée `alerts`, les seuls porteurs d'une alerte (le favori
  // ne sert qu'à `viaFavorite`) ; en portée `followers`, favoris et alertes.
  // Un étudiant seulement « prévenu récemment » n'est jamais candidat.
  const candidates =
    scope === 'followers'
      ? Prisma.sql`bool_or(src."kind" IN ('fav', 'alert'))`
      : Prisma.sql`bool_or(src."kind" = 'alert')`;
  // En portée `alerts`, seule l'alerte date le suivi : un favori ancien ne doit
  // pas faire passer pour « ancien abonné » quelqu'un qui vient d'activer la
  // cloche.
  const followSinceExpr =
    scope === 'followers'
      ? Prisma.sql`LEAST(u."favAt", CASE WHEN u."mutedAt" IS NULL THEN u."alertAt" END)`
      : Prisma.sql`CASE WHEN u."mutedAt" IS NULL THEN u."alertAt" END`;
  const alreadyNotifiedExpr =
    cycleId === null
      ? Prisma.sql`false`
      : Prisma.sql`EXISTS (
          SELECT 1 FROM "UserNotification" n
          WHERE n."dedupeKey" = ${openingDedupeKey(cycleId, '')} || u."userId"
        )`;
  const otherCycleClause =
    cycleId === null
      ? Prisma.empty
      : Prisma.sql`AND r."cycleId" IS DISTINCT FROM ${cycleId}`;
  // NOT (followSince > $followSince) : un début de suivi inconnu compte comme
  // ancien, jamais comme nouveau.
  const beforeAnnouncementExpr =
    followSince === null
      ? Prisma.sql`false`
      : Prisma.sql`(b."followSince" IS NULL OR b."followSince" <= ${followSince})`;

  return Prisma.sql`
    WITH follow_src AS (
      SELECT si."userId", 'fav'::text AS "kind", si."createdAt" AS "favAt",
             NULL::timestamp(3) AS "alertAt", NULL::timestamp(3) AS "mutedAt",
             NULL::boolean AS "alertPushEnabled"
      FROM "SavedItem" si
      JOIN "Scholarship" s ON s."id" = si."itemId"
      WHERE si."itemType" = 'scholarship' AND si."itemId" = ${scholarshipId}
      UNION ALL
      SELECT a."userId", 'alert'::text, NULL, a."createdAt", a."mutedAt", a."pushEnabled"
      FROM "ScholarshipAlertSubscription" a
      WHERE a."scholarshipId" = ${scholarshipId}
      UNION ALL
      SELECT r."userId", 'recent'::text, NULL, NULL, NULL, NULL
      FROM "UserNotification" r
      WHERE r."kind" = ${SCHOLARSHIP_OPENED_KIND}
        AND r."scholarshipId" = ${scholarshipId}
        ${otherCycleClause}
        AND r."createdAt" > ${renotifySince}
    ),
    follow_user AS (
      SELECT
        src."userId",
        bool_or(src."kind" = 'fav') AS "hasFavorite",
        bool_or(src."kind" = 'alert') AS "hasAlert",
        bool_or(src."kind" = 'recent') AS "recentlyNotified",
        max(src."favAt") AS "favAt",
        max(src."alertAt") AS "alertAt",
        max(src."mutedAt") AS "mutedAt",
        bool_and(src."alertPushEnabled") AS "alertPushEnabled"
      FROM follow_src src
      GROUP BY src."userId"
      HAVING ${candidates}
    ),
    follow_base AS MATERIALIZED (
      SELECT
        u."userId" AS "userId",
        u."hasFavorite" AS "viaFavorite",
        (u."hasAlert" AND u."mutedAt" IS NULL) AS "viaAlert",
        (u."mutedAt" IS NOT NULL) AS "muted",
        COALESCE(u."alertPushEnabled", true) AS "pushEnabled",
        (${FOLLOWED_SCHOLARSHIP_OPT_OUT} = ANY(p."disabledNotificationTypes")) AS "optedOut",
        ${followSinceExpr} AS "followSince",
        ${alreadyNotifiedExpr} AS "alreadyNotified",
        u."recentlyNotified" AS "recentlyNotified",
        EXISTS (
          SELECT 1 FROM "DeviceToken" d WHERE d."userProfileId" = u."userId"
        ) AS "hasFcmDevice",
        p."preferredLanguage" AS "preferredLanguage",
        p."countryOfResidence" AS "countryOfResidence"
      FROM follow_user u
      CROSS JOIN LATERAL (
        SELECT pr."disabledNotificationTypes", pr."preferredLanguage", pr."countryOfResidence"
        FROM "UserProfile" pr
        WHERE pr."id" = u."userId"
      ) p
    ),
    follow_rows AS (
      SELECT
        b.*,
        ${beforeAnnouncementExpr} AS "followedBeforeAnnouncement",
        (
          NOT b."muted"
          AND NOT b."alreadyNotified"
          AND NOT b."recentlyNotified"
          AND NOT ${beforeAnnouncementExpr}
        ) AS "toNotify"
      FROM follow_base b
    )
  `;
}

/** Toutes les lignes de `follow_rows` (aperçu admin), triées par `userId`. */
export function followerRowsSql(
  scholarshipId: string,
  scope: OpeningAudienceScope,
  cycleId: string | null,
  renotifySince: Date,
  followSince: Date | null,
): Prisma.Sql {
  return Prisma.sql`${followerRowsCte(
    scholarshipId,
    scope,
    cycleId,
    renotifySince,
    followSince,
  )}
    SELECT
      "userId", "viaFavorite", "viaAlert", "muted", "pushEnabled", "optedOut",
      "followSince", "alreadyNotified", "recentlyNotified",
      "followedBeforeAnnouncement", "toNotify", "hasFcmDevice",
      "preferredLanguage", "countryOfResidence"
    FROM follow_rows
    ORDER BY "userId"
  `;
}

/** Les comptes de `activate` et de l'audit, sans rapatrier les lignes. */
export interface FollowerAudienceCounts {
  /** Audience de la portée avant déduplication (hors sourdine) : `subscribers`. */
  audience: number;
  muted: number;
  toNotify: number;
  /** Les trois suivants découpent `toNotify`. */
  viaFavoriteOnly: number;
  viaAlertOnly: number;
  viaBoth: number;
}

export function followerAudienceCountsSql(
  scholarshipId: string,
  scope: OpeningAudienceScope,
  cycleId: string | null,
  renotifySince: Date,
  followSince: Date | null,
): Prisma.Sql {
  return Prisma.sql`${followerRowsCte(
    scholarshipId,
    scope,
    cycleId,
    renotifySince,
    followSince,
  )}
    SELECT
      count(*) FILTER (WHERE NOT "muted")::int AS "audience",
      count(*) FILTER (WHERE "muted")::int AS "muted",
      count(*) FILTER (WHERE "toNotify")::int AS "toNotify",
      count(*) FILTER (WHERE "toNotify" AND "viaFavorite" AND NOT "viaAlert")::int AS "viaFavoriteOnly",
      count(*) FILTER (WHERE "toNotify" AND "viaAlert" AND NOT "viaFavorite")::int AS "viaAlertOnly",
      count(*) FILTER (WHERE "toNotify" AND "viaAlert" AND "viaFavorite")::int AS "viaBoth"
    FROM follow_rows
  `;
}

// ── Couples (étudiant, bourse) suivis ───────────────────────────────────────

/** Un couple suivi : favori, ou alerte non mise en sourdine. */
export interface FollowingPair {
  userId: string;
  scholarshipId: string;
  viaFavorite: boolean;
  viaAlert: boolean;
  /** Favori + alerte en sourdine : suivi (rappels), mais pas d'annonce d'ouverture. */
  muted: boolean;
}

/** Une bourse suivie par un étudiant. */
export interface FollowedScholarshipRow {
  scholarshipId: string;
  viaFavorite: boolean;
  viaAlert: boolean;
  muted: boolean;
}

function followingPairsBody(filter: {
  scholarshipIds?: readonly string[];
  userId?: string;
}): Prisma.Sql {
  const favFilter = Prisma.sql`${
    filter.scholarshipIds
      ? Prisma.sql`AND si."itemId" = ANY(${[...filter.scholarshipIds]}::text[])`
      : Prisma.empty
  } ${
    filter.userId !== undefined
      ? Prisma.sql`AND si."userId" = ${filter.userId}`
      : Prisma.empty
  }`;
  const alertFilter = Prisma.sql`${
    filter.scholarshipIds
      ? Prisma.sql`AND a."scholarshipId" = ANY(${[...filter.scholarshipIds]}::text[])`
      : Prisma.empty
  } ${
    filter.userId !== undefined
      ? Prisma.sql`AND a."userId" = ${filter.userId}`
      : Prisma.empty
  }`;
  return Prisma.sql`
    SELECT
      COALESCE(f."userId", a."userId") AS "userId",
      COALESCE(f."scholarshipId", a."scholarshipId") AS "scholarshipId",
      (f."userId" IS NOT NULL) AS "viaFavorite",
      (a."userId" IS NOT NULL AND a."mutedAt" IS NULL) AS "viaAlert",
      (a."mutedAt" IS NOT NULL) AS "muted"
    FROM (
      SELECT si."userId", si."itemId" AS "scholarshipId"
      FROM "SavedItem" si
      JOIN "Scholarship" s ON s."id" = si."itemId"
      WHERE si."itemType" = 'scholarship' ${favFilter}
    ) f
    FULL OUTER JOIN (
      SELECT a."userId", a."scholarshipId", a."mutedAt"
      FROM "ScholarshipAlertSubscription" a
      WHERE true ${alertFilter}
    ) a ON a."userId" = f."userId" AND a."scholarshipId" = f."scholarshipId"
    WHERE f."userId" IS NOT NULL OR a."mutedAt" IS NULL
  `;
}

/**
 * Les couples suivis de ces bourses (rappels d'échéance en mode
 * `outbox_followers`, bloc `follow` de la fiche). Une sourdine ne retire PAS le
 * couple : elle ne coupe que l'annonce d'ouverture. Liste vide → aucune ligne.
 * `itemId = ANY(…)` passe par l'index `SavedItem(itemType, itemId)`.
 */
export function followingPairsSql(
  scholarshipIds: readonly string[],
  userId?: string,
): Prisma.Sql {
  return Prisma.sql`${followingPairsBody({ scholarshipIds, userId })}
    ORDER BY 2, 1
  `;
}

/** Les bourses que suit cet étudiant (`GET /me/followed-scholarships`). */
export function followedScholarshipIdsSql(userId: string): Prisma.Sql {
  return Prisma.sql`
    SELECT "scholarshipId", "viaFavorite", "viaAlert", "muted"
    FROM (${followingPairsBody({ userId })}) pairs
    ORDER BY "scholarshipId"
  `;
}

/** Par bourse suivie au moins une fois : `followers` et l'audience de la portée. */
export interface FollowerCountRow {
  scholarshipId: string;
  /** Suivent (favori ou alerte non mise en sourdine). */
  followers: number;
  /** Portée `alerts` : alertes non en sourdine ; portée `followers` : suivent, hors sourdine. */
  notifiable: number;
}

/**
 * Les colonnes « Abonnés » de la liste admin et la file « À faire ».
 * `scholarshipIds` absent = toutes les bourses (bornées par le catalogue).
 */
export function followerCountsSql(
  scope: OpeningAudienceScope,
  scholarshipIds?: readonly string[],
): Prisma.Sql {
  const notifiable =
    scope === 'alerts' ? Prisma.sql`"viaAlert"` : Prisma.sql`NOT "muted"`;
  return Prisma.sql`
    SELECT
      "scholarshipId",
      count(*)::int AS "followers",
      count(*) FILTER (WHERE ${notifiable})::int AS "notifiable"
    FROM (${followingPairsBody({ scholarshipIds })}) pairs
    GROUP BY "scholarshipId"
    ORDER BY "scholarshipId"
  `;
}
