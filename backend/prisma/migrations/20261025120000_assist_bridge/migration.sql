-- Bot « Passerelle » (chantier C3 bis) — contrat : docs/community-api-contract.md
-- §15 (révision 3), runbook : docs/runbook-bot-passerelle.md.
--
-- ADDITIF SEULEMENT : deux types énumérés et une table neufs. Aucune colonne
-- existante n'est modifiée ; un backend plus ancien ignore tout ce qui suit. La
-- table naît vide ; le bot est piloté par `KPB_ASSIST_BRIDGE_MODE` (défaut
-- `shadow` : il détecte et journalise, n'envoie rien). Aucun texte d'élève
-- n'y est stocké (ni publication, ni message au coach) : le besoin, la règle,
-- la version du catalogue et l'id de la source. Cascade avec le compte.

-- CreateEnum
CREATE TYPE "AssistBridgeSource" AS ENUM ('community_post', 'community_reply', 'coach_message');

-- CreateEnum
CREATE TYPE "AssistBridgeStatus" AS ENUM ('detected', 'sent', 'skipped', 'opened_feature', 'opened_whatsapp', 'dismissed');

-- CreateTable
CREATE TABLE "AssistBridgeEvent" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "source" "AssistBridgeSource" NOT NULL,
    "sourceId" TEXT NOT NULL,
    "needId" TEXT NOT NULL,
    "ruleId" TEXT NOT NULL,
    "ruleVersion" TEXT NOT NULL,
    "status" "AssistBridgeStatus" NOT NULL DEFAULT 'detected',
    "statusReason" TEXT,
    "mode" TEXT,
    "notBefore" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "notificationKey" TEXT,
    "pushOutcome" TEXT,
    "processedAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3),
    "openedFeatureAt" TIMESTAMP(3),
    "openedWhatsappAt" TIMESTAMP(3),
    "dismissedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AssistBridgeEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "AssistBridgeEvent_status_createdAt_idx" ON "AssistBridgeEvent"("status", "createdAt");

-- CreateIndex
CREATE INDEX "AssistBridgeEvent_userId_sentAt_idx" ON "AssistBridgeEvent"("userId", "sentAt");

-- CreateIndex
CREATE INDEX "AssistBridgeEvent_userId_needId_sentAt_idx" ON "AssistBridgeEvent"("userId", "needId", "sentAt");

-- CreateIndex
CREATE INDEX "AssistBridgeEvent_needId_createdAt_idx" ON "AssistBridgeEvent"("needId", "createdAt");

-- CreateIndex
CREATE INDEX "AssistBridgeEvent_createdAt_idx" ON "AssistBridgeEvent"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "AssistBridgeEvent_source_sourceId_key" ON "AssistBridgeEvent"("source", "sourceId");

-- AddForeignKey
ALTER TABLE "AssistBridgeEvent" ADD CONSTRAINT "AssistBridgeEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

