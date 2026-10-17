-- Bot « Vérif » de la communauté (chantier Communauté C3) — contrat :
-- docs/community-api-contract.md (révision 2), runbook :
-- docs/runbook-bot-verif.md.
--
-- ADDITIF SEULEMENT : une valeur d'énumération (`kpb_assistant`), un type
-- énuméré et une table neufs, deux colonnes nullables sur `CommunityReply`.
-- Aucune colonne existante n'est modifiée ; un backend plus ancien ignore tout
-- ce qui suit (il ne lit jamais `kpb_assistant`, qui n'existe que sur des
-- réponses écrites par ce code). La table naît vide ; le bot est piloté par
-- `KPB_COMMUNITY_VERIF_BOT_MODE` (défaut `review`).

-- AlterEnum
ALTER TYPE "CommunityAuthorKind" ADD VALUE 'kpb_assistant';

-- CreateEnum
CREATE TYPE "CommunityBotDraftStatus" AS ENUM ('queued', 'skipped', 'proposed', 'published', 'rejected', 'obsolete');

-- AlterTable
ALTER TABLE "CommunityReply" ADD COLUMN "botDraftId" TEXT,
ADD COLUMN "botSourceVerifiedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "CommunityBotDraft" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "status" "CommunityBotDraftStatus" NOT NULL DEFAULT 'queued',
    "statusReason" TEXT,
    "lang" TEXT NOT NULL DEFAULT 'fr',
    "intents" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "entities" JSONB NOT NULL DEFAULT '[]',
    "facts" JSONB,
    "factsHash" TEXT,
    "proposedText" TEXT,
    "writer" TEXT,
    "llmFallbackReason" TEXT,
    "confidence" TEXT,
    "complete" BOOLEAN NOT NULL DEFAULT false,
    "scamCaution" BOOLEAN NOT NULL DEFAULT false,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "generatedAt" TIMESTAMP(3),
    "processedAt" TIMESTAMP(3),
    "processedByAdminId" TEXT,
    "processedByName" TEXT,
    "rejectReason" TEXT,
    "publishedReplyId" TEXT,
    "publishedVerified" BOOLEAN NOT NULL DEFAULT false,
    "autoPublished" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CommunityBotDraft_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CommunityBotDraft_postId_key" ON "CommunityBotDraft"("postId");

-- CreateIndex
CREATE INDEX "CommunityBotDraft_status_createdAt_idx" ON "CommunityBotDraft"("status", "createdAt");

-- AddForeignKey
ALTER TABLE "CommunityBotDraft" ADD CONSTRAINT "CommunityBotDraft_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;
