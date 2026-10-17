import type { Prisma, PrismaClient } from '@prisma/client';

type Db = PrismaClient | Prisma.TransactionClient;

/**
 * Recalcule les compteurs dénormalisés d'une publication DEPUIS les tables —
 * jamais par incrément : un incrément manqué (course, erreur) se corrigerait
 * pas tout seul, un recalcul si.
 *
 * - `replyCount` : réponses visibles ;
 * - `answerCount` : réponses visibles d'un autre que l'auteur (équipe incluse) ;
 * - `helpfulCount` : « utile » sur la publication ;
 * - `hasVerifiedAnswer` : une réponse visible et vérifiée ;
 * - `openReportCount` : signalements ouverts visant la publication ;
 * - `lastActivityAt` : dernière réponse visible, sinon création.
 */
export async function refreshPostCounters(db: Db, postIds: readonly string[]): Promise<void> {
  const ids = [...new Set(postIds)];
  if (!ids.length) return;
  await db.$executeRaw`
    UPDATE "CommunityPost" p SET
      "replyCount" = (
        SELECT COUNT(*)::int FROM "CommunityReply" r
        WHERE r."postId" = p."id" AND r."status" = 'visible'
      ),
      "answerCount" = (
        SELECT COUNT(*)::int FROM "CommunityReply" r
        WHERE r."postId" = p."id" AND r."status" = 'visible'
          AND (r."authorMemberId" IS NULL OR p."authorMemberId" IS NULL OR r."authorMemberId" <> p."authorMemberId")
      ),
      "helpfulCount" = (
        SELECT COUNT(*)::int FROM "CommunityReaction" x WHERE x."postId" = p."id"
      ),
      "hasVerifiedAnswer" = EXISTS (
        SELECT 1 FROM "CommunityReply" r
        WHERE r."postId" = p."id" AND r."status" = 'visible' AND r."isVerified"
      ),
      "openReportCount" = (
        SELECT COUNT(*)::int FROM "CommunityReport" c
        WHERE c."postId" = p."id" AND c."targetType" = 'post' AND c."status" = 'open'
      ),
      "lastActivityAt" = GREATEST(p."createdAt", COALESCE((
        SELECT MAX(r."createdAt") FROM "CommunityReply" r
        WHERE r."postId" = p."id" AND r."status" = 'visible'
      ), p."createdAt"))
    WHERE p."id" = ANY(${ids}::text[])
  `;
}

/** `helpfulCount` et `openReportCount` d'une ou plusieurs réponses. */
export async function refreshReplyCounters(db: Db, replyIds: readonly string[]): Promise<void> {
  const ids = [...new Set(replyIds)];
  if (!ids.length) return;
  await db.$executeRaw`
    UPDATE "CommunityReply" r SET
      "helpfulCount" = (
        SELECT COUNT(*)::int FROM "CommunityReaction" x WHERE x."replyId" = r."id"
      ),
      "openReportCount" = (
        SELECT COUNT(*)::int FROM "CommunityReport" c
        WHERE c."replyId" = r."id" AND c."targetType" = 'reply' AND c."status" = 'open'
      )
    WHERE r."id" = ANY(${ids}::text[])
  `;
}
