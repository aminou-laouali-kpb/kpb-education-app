// ─────────────────────────────────────────────────────────────────────────────
// Fil « Pour toi » — le score (§10 du contrat docs/community-api-contract.md).
//
// Classement simple et transparent, calculé EN SQL (forYouSql) :
//
//   âge_h      = max(0, (asOf − createdAt) en heures)
//   affinité   = 4·[bourse suivie] + 2·[pays visé] + 1·[niveau visé] + 1·[discussion suivie]
//   engagement = ln(1 + replyCount + 2·helpfulCount)
//   vérifiée   = 2·[hasVerifiedAnswer]
//   score      = (1 + affinité + engagement + vérifiée) / (âge_h + 2)^1.2
//
// `forYouScore` est le MIROIR TypeScript de la même formule : il documente les
// poids et sert aux tests (le spec Postgres vérifie que l'ordre SQL et l'ordre
// du miroir coïncident, à horloge fixée).
// ─────────────────────────────────────────────────────────────────────────────

import { Prisma } from '@prisma/client';

export const FOR_YOU_WEIGHTS = {
  followedScholarship: 4,
  targetCountry: 2,
  targetLevel: 1,
  followedDiscussion: 1,
  verifiedAnswer: 2,
  helpfulMultiplier: 2,
  ageOffsetHours: 2,
  gravity: 1.2,
  /** Engagement à partir duquel la raison `popular` s'affiche : ln(1 + 5). */
  popularEngagement: Math.log(6),
} as const;

export interface ForYouSignals {
  ageHours: number;
  followedScholarship: boolean;
  targetCountry: boolean;
  targetLevel: boolean;
  followedDiscussion: boolean;
  replyCount: number;
  helpfulCount: number;
  hasVerifiedAnswer: boolean;
}

export type ForYouReason =
  | 'followed_scholarship'
  | 'target_country'
  | 'target_level'
  | 'followed_discussion'
  | 'verified_answer'
  | 'popular';

export function forYouEngagement(replyCount: number, helpfulCount: number): number {
  return Math.log(1 + replyCount + FOR_YOU_WEIGHTS.helpfulMultiplier * helpfulCount);
}

export function forYouScore(s: ForYouSignals): number {
  const w = FOR_YOU_WEIGHTS;
  const affinity =
    (s.followedScholarship ? w.followedScholarship : 0) +
    (s.targetCountry ? w.targetCountry : 0) +
    (s.targetLevel ? w.targetLevel : 0) +
    (s.followedDiscussion ? w.followedDiscussion : 0);
  const verified = s.hasVerifiedAnswer ? w.verifiedAnswer : 0;
  const engagement = forYouEngagement(s.replyCount, s.helpfulCount);
  const age = Math.max(0, s.ageHours);
  return (1 + affinity + engagement + verified) / Math.pow(age + w.ageOffsetHours, w.gravity);
}

/** Les raisons affichées, dans l'ordre du contrat. */
export function forYouReasons(s: Omit<ForYouSignals, 'ageHours'>): ForYouReason[] {
  const out: ForYouReason[] = [];
  if (s.followedScholarship) out.push('followed_scholarship');
  if (s.targetCountry) out.push('target_country');
  if (s.targetLevel) out.push('target_level');
  if (s.followedDiscussion) out.push('followed_discussion');
  if (s.hasVerifiedAnswer) out.push('verified_answer');
  if (forYouEngagement(s.replyCount, s.helpfulCount) >= FOR_YOU_WEIGHTS.popularEngagement) {
    out.push('popular');
  }
  return out;
}

/**
 * Valeur sentinelle des tableaux vides : `ANY('{}')` serait juste, mais un
 * tableau vide n'a pas de type pour Postgres. Jamais un identifiant réel (les
 * ids sont des cuid / codes sans `:`), et jamais un octet NUL (refusé en UTF-8).
 */
const NONE = ':none:';

export interface ForYouQueryInput {
  asOf: Date;
  windowStart: Date;
  viewerMemberId: string;
  followedScholarshipIds: string[];
  targetCountryIds: string[];
  targetLevel: string | null;
  blockedMemberIds: string[];
  type: string | null;
  hashtag: string | null;
  /** `rank` = le score arrondi à 12 décimales, en texte (exact, voir plus bas). */
  cursor: { rank: string; id: string } | null;
  limit: number;
}

export interface ForYouRow {
  id: string;
  score: number;
  rank: string;
  followedScholarship: boolean;
  targetCountry: boolean;
  targetLevel: boolean;
  followedDiscussion: boolean;
}

/**
 * La requête du fil. Les signaux sont des EXISTS sur les mentions figées
 * (`CommunityMention.countryId`, `.levels`) : aucun accès au catalogue. Le
 * score est recalculé à l'identique pour les pages suivantes (même `asOf`, mêmes
 * entrées → même float8). Le curseur ne transporte pourtant pas ce float : un
 * paramètre flottant repasse par du texte et peut s'arrondir au-dessus de la
 * valeur calculée — la ligne du curseur se reproposait alors à l'infini. On
 * trie et on pagine sur le score arrondi à 12 décimales, en `numeric`, transporté
 * en texte : une comparaison exacte des deux côtés.
 */
export function forYouSql(q: ForYouQueryInput): Prisma.Sql {
  const w = FOR_YOU_WEIGHTS;
  const followed = q.followedScholarshipIds.length ? q.followedScholarshipIds : [NONE];
  const countries = q.targetCountryIds.length ? q.targetCountryIds : [NONE];
  const blocked = q.blockedMemberIds.length ? q.blockedMemberIds : [NONE];
  const level = q.targetLevel ?? NONE;

  const typeFilter = q.type
    ? Prisma.sql`AND p."type" = ${q.type}::"CommunityPostType"`
    : Prisma.empty;
  const hashtagFilter = q.hashtag
    ? Prisma.sql`AND EXISTS (SELECT 1 FROM "CommunityPostHashtag" ph JOIN "CommunityHashtag" h ON h."id" = ph."hashtagId" WHERE ph."postId" = p."id" AND h."tag" = ${q.hashtag})`
    : Prisma.empty;
  const cursorFilter = q.cursor
    ? Prisma.sql`WHERE (s."rank" < ${q.cursor.rank}::numeric OR (s."rank" = ${q.cursor.rank}::numeric AND s."id" < ${q.cursor.id}))`
    : Prisma.empty;

  return Prisma.sql`
    WITH signals AS (
      SELECT
        p."id",
        p."replyCount",
        p."helpfulCount",
        p."hasVerifiedAnswer",
        GREATEST(0, EXTRACT(EPOCH FROM ((${q.asOf}::timestamptz AT TIME ZONE 'UTC') - p."createdAt")) / 3600.0)::float8 AS "ageHours",
        EXISTS (
          SELECT 1 FROM "CommunityMention" m
          WHERE m."postId" = p."id" AND m."entityType" = 'scholarship' AND m."entityId" = ANY(${followed}::text[])
        ) AS "followedScholarship",
        EXISTS (
          SELECT 1 FROM "CommunityMention" m
          WHERE m."postId" = p."id" AND m."countryId" = ANY(${countries}::text[])
        ) AS "targetCountry",
        EXISTS (
          SELECT 1 FROM "CommunityMention" m
          WHERE m."postId" = p."id" AND m."entityType" = 'scholarship' AND ${level}::text = ANY(m."levels")
        ) AS "targetLevel",
        EXISTS (
          SELECT 1 FROM "CommunityFollow" f
          WHERE f."postId" = p."id" AND f."memberId" = ${q.viewerMemberId}
        ) AS "followedDiscussion"
      FROM "CommunityPost" p
      WHERE p."status" = 'visible'
        AND p."pinnedAt" IS NULL
        AND p."createdAt" >= (${q.windowStart}::timestamptz AT TIME ZONE 'UTC')
        AND p."createdAt" <= (${q.asOf}::timestamptz AT TIME ZONE 'UTC')
        AND (p."authorMemberId" IS NULL OR (p."authorMemberId" <> ${q.viewerMemberId} AND NOT (p."authorMemberId" = ANY(${blocked}::text[]))))
        ${typeFilter}
        ${hashtagFilter}
    ),
    scored AS (
      SELECT
        "id",
        "followedScholarship",
        "targetCountry",
        "targetLevel",
        "followedDiscussion",
        ((1
          + (CASE WHEN "followedScholarship" THEN ${w.followedScholarship} ELSE 0 END)
          + (CASE WHEN "targetCountry" THEN ${w.targetCountry} ELSE 0 END)
          + (CASE WHEN "targetLevel" THEN ${w.targetLevel} ELSE 0 END)
          + (CASE WHEN "followedDiscussion" THEN ${w.followedDiscussion} ELSE 0 END)
          + LN(1 + "replyCount" + ${w.helpfulMultiplier} * "helpfulCount")
          + (CASE WHEN "hasVerifiedAnswer" THEN ${w.verifiedAnswer} ELSE 0 END)
        )::float8 / POWER("ageHours" + ${w.ageOffsetHours}, ${w.gravity})::float8)::float8 AS "score"
      FROM signals
    )
    , ranked AS (
      SELECT *, ROUND("score"::numeric, 12) AS "rank" FROM scored
    )
    SELECT s."id", s."score", s."rank"::text AS "rank", s."followedScholarship", s."targetCountry",
           s."targetLevel", s."followedDiscussion"
    FROM ranked s
    ${cursorFilter}
    ORDER BY s."rank" DESC, s."id" DESC
    LIMIT ${q.limit}
  `;
}
