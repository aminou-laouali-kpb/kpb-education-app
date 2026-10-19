-- Correctifs 57 — compétition ambassadeurs : prix déclaré forfait et réattribué.
--
-- ADDITIF SEULEMENT : une table neuve, vide. Aucune colonne existante modifiée ;
-- un backend plus ancien l'ignore. Cascade avec la campagne ; SET NULL avec le
-- participant (la trace du forfait reste).

-- CreateTable
CREATE TABLE "ReferralCampaignPrizeForfeit" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "rank" INTEGER NOT NULL,
    "participantId" TEXT,
    "publicNameSnapshot" TEXT NOT NULL,
    "amountFcfa" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "forfeitedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "forfeitedByAdminId" TEXT NOT NULL,
    "replacedByParticipantId" TEXT,

    CONSTRAINT "ReferralCampaignPrizeForfeit_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ReferralCampaignPrizeForfeit_campaignId_idx" ON "ReferralCampaignPrizeForfeit"("campaignId");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralCampaignPrizeForfeit_campaignId_participantId_key" ON "ReferralCampaignPrizeForfeit"("campaignId", "participantId");

-- AddForeignKey
ALTER TABLE "ReferralCampaignPrizeForfeit" ADD CONSTRAINT "ReferralCampaignPrizeForfeit_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "ReferralCampaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCampaignPrizeForfeit" ADD CONSTRAINT "ReferralCampaignPrizeForfeit_participantId_fkey" FOREIGN KEY ("participantId") REFERENCES "ReferralCampaignParticipant"("id") ON DELETE SET NULL ON UPDATE CASCADE;
