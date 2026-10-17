-- Communauté d'entraide (chantier Communauté C1 + C2) — contrat :
-- docs/community-api-contract.md.
--
-- ADDITIF SEULEMENT : neuf types énumérés, treize tables neuves, cinq colonnes
-- nullables (et trois index) sur `ForumModerationAction`, réutilisée comme
-- journal de modération. Aucune colonne existante n'est modifiée ni supprimée ;
-- un backend plus ancien remis sur ce schéma ignore tout ce qui suit. Aucun
-- rattrapage : les tables naissent vides, la fonction est derrière
-- `KPB_COMMUNITY_ENABLED` (fermé par défaut).
--
-- Suppression du compte : cascade depuis `CommunityMember` (lui-même en
-- cascade depuis `UserProfile`) ; les signalements RÉDIGÉS par le membre
-- survivent sans auteur (SET NULL).

-- CreateEnum
CREATE TYPE "CommunityPostType" AS ENUM ('question', 'experience', 'advice');

-- CreateEnum
CREATE TYPE "CommunityContentStatus" AS ENUM ('visible', 'pending_review', 'hidden', 'deleted');

-- CreateEnum
CREATE TYPE "CommunityAuthorKind" AS ENUM ('member', 'kpb_team', 'kpb_advisor');

-- CreateEnum
CREATE TYPE "CommunityEntityType" AS ENUM ('scholarship', 'country', 'institution', 'program');

-- CreateEnum
CREATE TYPE "CommunityReportTarget" AS ENUM ('post', 'reply', 'member');

-- CreateEnum
CREATE TYPE "CommunityReportReason" AS ENUM ('scam', 'harassment', 'inappropriate', 'spam', 'personal_info', 'misinformation', 'other');

-- CreateEnum
CREATE TYPE "CommunityReportStatus" AS ENUM ('open', 'actioned', 'dismissed');

-- CreateEnum
CREATE TYPE "CommunitySanctionKind" AS ENUM ('warning', 'read_only', 'ban');

-- CreateEnum
CREATE TYPE "CommunityFilterKind" AS ENUM ('allowed_domain', 'blocked_term');

-- AlterTable
ALTER TABLE "ForumModerationAction" ADD COLUMN     "adminId" TEXT,
ADD COLUMN     "memberId" TEXT,
ADD COLUMN     "postId" TEXT,
ADD COLUMN     "replyId" TEXT,
ADD COLUMN     "reportId" TEXT;

-- CreateTable
CREATE TABLE "CommunityMember" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "charterVersion" TEXT,
    "charterAcceptedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CommunityMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityCharterAcceptance" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "acceptedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityCharterAcceptance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityPost" (
    "id" TEXT NOT NULL,
    "type" "CommunityPostType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "authorKind" "CommunityAuthorKind" NOT NULL DEFAULT 'member',
    "authorMemberId" TEXT,
    "authorAdminId" TEXT,
    "authorAdminName" TEXT,
    "status" "CommunityContentStatus" NOT NULL DEFAULT 'visible',
    "statusReason" TEXT,
    "statusChangedAt" TIMESTAMP(3),
    "filterFlags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "searchText" TEXT NOT NULL DEFAULT '',
    "replyCount" INTEGER NOT NULL DEFAULT 0,
    "answerCount" INTEGER NOT NULL DEFAULT 0,
    "helpfulCount" INTEGER NOT NULL DEFAULT 0,
    "openReportCount" INTEGER NOT NULL DEFAULT 0,
    "hasVerifiedAnswer" BOOLEAN NOT NULL DEFAULT false,
    "pinnedAt" TIMESTAMP(3),
    "lastActivityAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "editedAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CommunityPost_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityReply" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "authorKind" "CommunityAuthorKind" NOT NULL DEFAULT 'member',
    "authorMemberId" TEXT,
    "authorAdminId" TEXT,
    "authorAdminName" TEXT,
    "status" "CommunityContentStatus" NOT NULL DEFAULT 'visible',
    "statusReason" TEXT,
    "statusChangedAt" TIMESTAMP(3),
    "filterFlags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "helpfulCount" INTEGER NOT NULL DEFAULT 0,
    "openReportCount" INTEGER NOT NULL DEFAULT 0,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "verifiedAt" TIMESTAMP(3),
    "verifiedByAdminId" TEXT,
    "editedAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CommunityReply_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityReaction" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "postId" TEXT,
    "replyId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityReaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityMention" (
    "id" TEXT NOT NULL,
    "postId" TEXT,
    "replyId" TEXT,
    "entityType" "CommunityEntityType" NOT NULL,
    "entityId" TEXT NOT NULL,
    "labelFr" TEXT NOT NULL,
    "labelEn" TEXT NOT NULL,
    "countryId" TEXT,
    "levels" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityMention_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityHashtag" (
    "id" TEXT NOT NULL,
    "tag" TEXT NOT NULL,
    "display" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityHashtag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityPostHashtag" (
    "postId" TEXT NOT NULL,
    "hashtagId" TEXT NOT NULL,

    CONSTRAINT "CommunityPostHashtag_pkey" PRIMARY KEY ("postId","hashtagId")
);

-- CreateTable
CREATE TABLE "CommunityFollow" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityFollow_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityBlock" (
    "id" TEXT NOT NULL,
    "blockerMemberId" TEXT NOT NULL,
    "blockedMemberId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityBlock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityReport" (
    "id" TEXT NOT NULL,
    "reporterMemberId" TEXT,
    "targetType" "CommunityReportTarget" NOT NULL,
    "targetKey" TEXT NOT NULL,
    "postId" TEXT,
    "replyId" TEXT,
    "targetMemberId" TEXT,
    "reason" "CommunityReportReason" NOT NULL,
    "details" TEXT,
    "status" "CommunityReportStatus" NOT NULL DEFAULT 'open',
    "resolvedAt" TIMESTAMP(3),
    "resolvedByAdminId" TEXT,
    "resolvedByName" TEXT,
    "resolutionNote" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunitySanction" (
    "id" TEXT NOT NULL,
    "memberId" TEXT NOT NULL,
    "kind" "CommunitySanctionKind" NOT NULL,
    "reason" TEXT NOT NULL,
    "endsAt" TIMESTAMP(3),
    "createdByAdminId" TEXT NOT NULL,
    "createdByName" TEXT NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "revokedByAdminId" TEXT,
    "revokedByName" TEXT,
    "revokeReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunitySanction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommunityFilterEntry" (
    "id" TEXT NOT NULL,
    "kind" "CommunityFilterKind" NOT NULL,
    "value" TEXT NOT NULL,
    "createdByAdminId" TEXT,
    "createdByName" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommunityFilterEntry_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CommunityMember_userId_key" ON "CommunityMember"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityCharterAcceptance_memberId_version_key" ON "CommunityCharterAcceptance"("memberId", "version");

-- CreateIndex
CREATE INDEX "CommunityPost_status_createdAt_id_idx" ON "CommunityPost"("status", "createdAt" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "CommunityPost_status_type_answerCount_createdAt_idx" ON "CommunityPost"("status", "type", "answerCount", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "CommunityPost_authorMemberId_createdAt_idx" ON "CommunityPost"("authorMemberId", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityPost_status_pinnedAt_idx" ON "CommunityPost"("status", "pinnedAt");

-- CreateIndex
CREATE INDEX "CommunityPost_status_deletedAt_idx" ON "CommunityPost"("status", "deletedAt");

-- CreateIndex
CREATE INDEX "CommunityReply_postId_status_createdAt_idx" ON "CommunityReply"("postId", "status", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityReply_authorMemberId_createdAt_idx" ON "CommunityReply"("authorMemberId", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityReply_status_createdAt_idx" ON "CommunityReply"("status", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityReply_status_deletedAt_idx" ON "CommunityReply"("status", "deletedAt");

-- CreateIndex
CREATE INDEX "CommunityReaction_postId_idx" ON "CommunityReaction"("postId");

-- CreateIndex
CREATE INDEX "CommunityReaction_replyId_idx" ON "CommunityReaction"("replyId");

-- CreateIndex
CREATE INDEX "CommunityReaction_createdAt_idx" ON "CommunityReaction"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityReaction_memberId_postId_key" ON "CommunityReaction"("memberId", "postId");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityReaction_memberId_replyId_key" ON "CommunityReaction"("memberId", "replyId");

-- CreateIndex
CREATE INDEX "CommunityMention_entityType_entityId_idx" ON "CommunityMention"("entityType", "entityId");

-- CreateIndex
CREATE INDEX "CommunityMention_countryId_idx" ON "CommunityMention"("countryId");

-- CreateIndex
CREATE INDEX "CommunityMention_postId_idx" ON "CommunityMention"("postId");

-- CreateIndex
CREATE INDEX "CommunityMention_replyId_idx" ON "CommunityMention"("replyId");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityHashtag_tag_key" ON "CommunityHashtag"("tag");

-- CreateIndex
CREATE INDEX "CommunityPostHashtag_hashtagId_idx" ON "CommunityPostHashtag"("hashtagId");

-- CreateIndex
CREATE INDEX "CommunityFollow_postId_idx" ON "CommunityFollow"("postId");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityFollow_memberId_postId_key" ON "CommunityFollow"("memberId", "postId");

-- CreateIndex
CREATE INDEX "CommunityBlock_blockedMemberId_idx" ON "CommunityBlock"("blockedMemberId");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityBlock_blockerMemberId_blockedMemberId_key" ON "CommunityBlock"("blockerMemberId", "blockedMemberId");

-- CreateIndex
CREATE INDEX "CommunityReport_status_createdAt_idx" ON "CommunityReport"("status", "createdAt");

-- CreateIndex
CREATE INDEX "CommunityReport_targetKey_status_idx" ON "CommunityReport"("targetKey", "status");

-- CreateIndex
CREATE INDEX "CommunityReport_reporterMemberId_createdAt_idx" ON "CommunityReport"("reporterMemberId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityReport_reporterMemberId_targetKey_key" ON "CommunityReport"("reporterMemberId", "targetKey");

-- CreateIndex
CREATE INDEX "CommunitySanction_memberId_createdAt_idx" ON "CommunitySanction"("memberId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "CommunityFilterEntry_kind_value_key" ON "CommunityFilterEntry"("kind", "value");

-- CreateIndex
CREATE INDEX "ForumModerationAction_createdAt_idx" ON "ForumModerationAction"("createdAt");

-- CreateIndex
CREATE INDEX "ForumModerationAction_postId_idx" ON "ForumModerationAction"("postId");

-- CreateIndex
CREATE INDEX "ForumModerationAction_memberId_idx" ON "ForumModerationAction"("memberId");

-- AddForeignKey
ALTER TABLE "CommunityMember" ADD CONSTRAINT "CommunityMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityCharterAcceptance" ADD CONSTRAINT "CommunityCharterAcceptance_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityPost" ADD CONSTRAINT "CommunityPost_authorMemberId_fkey" FOREIGN KEY ("authorMemberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReply" ADD CONSTRAINT "CommunityReply_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReply" ADD CONSTRAINT "CommunityReply_authorMemberId_fkey" FOREIGN KEY ("authorMemberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReaction" ADD CONSTRAINT "CommunityReaction_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReaction" ADD CONSTRAINT "CommunityReaction_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReaction" ADD CONSTRAINT "CommunityReaction_replyId_fkey" FOREIGN KEY ("replyId") REFERENCES "CommunityReply"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityMention" ADD CONSTRAINT "CommunityMention_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityMention" ADD CONSTRAINT "CommunityMention_replyId_fkey" FOREIGN KEY ("replyId") REFERENCES "CommunityReply"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityPostHashtag" ADD CONSTRAINT "CommunityPostHashtag_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityPostHashtag" ADD CONSTRAINT "CommunityPostHashtag_hashtagId_fkey" FOREIGN KEY ("hashtagId") REFERENCES "CommunityHashtag"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityFollow" ADD CONSTRAINT "CommunityFollow_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityFollow" ADD CONSTRAINT "CommunityFollow_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityBlock" ADD CONSTRAINT "CommunityBlock_blockerMemberId_fkey" FOREIGN KEY ("blockerMemberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityBlock" ADD CONSTRAINT "CommunityBlock_blockedMemberId_fkey" FOREIGN KEY ("blockedMemberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReport" ADD CONSTRAINT "CommunityReport_reporterMemberId_fkey" FOREIGN KEY ("reporterMemberId") REFERENCES "CommunityMember"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReport" ADD CONSTRAINT "CommunityReport_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReport" ADD CONSTRAINT "CommunityReport_replyId_fkey" FOREIGN KEY ("replyId") REFERENCES "CommunityReply"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunityReport" ADD CONSTRAINT "CommunityReport_targetMemberId_fkey" FOREIGN KEY ("targetMemberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CommunitySanction" ADD CONSTRAINT "CommunitySanction_memberId_fkey" FOREIGN KEY ("memberId") REFERENCES "CommunityMember"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- « Utile » et mention : exactement une cible (publication OU réponse).
ALTER TABLE "CommunityReaction" ADD CONSTRAINT "CommunityReaction_one_target_check" CHECK (num_nonnulls("postId", "replyId") = 1);
ALTER TABLE "CommunityMention" ADD CONSTRAINT "CommunityMention_one_target_check" CHECK (num_nonnulls("postId", "replyId") = 1);

-- Un contenu a un auteur membre OU un auteur de l'équipe, jamais aucun des deux.
-- (Un contenu de membre perd sa ligne avec le membre, par cascade : il ne peut
-- donc pas rester orphelin.)
ALTER TABLE "CommunityPost" ADD CONSTRAINT "CommunityPost_author_check" CHECK (("authorKind" = 'member' AND "authorMemberId" IS NOT NULL) OR ("authorKind" <> 'member' AND "authorAdminId" IS NOT NULL));
ALTER TABLE "CommunityReply" ADD CONSTRAINT "CommunityReply_author_check" CHECK (("authorKind" = 'member' AND "authorMemberId" IS NOT NULL) OR ("authorKind" <> 'member' AND "authorAdminId" IS NOT NULL));

-- Une seule réponse vérifiée par publication.
CREATE UNIQUE INDEX "CommunityReply_one_verified_per_post" ON "CommunityReply"("postId") WHERE "isVerified";
