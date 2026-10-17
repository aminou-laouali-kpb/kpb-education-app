-- Compétition ambassadeurs (parrainage, novembre 2026).
--
-- ADDITIF SEULEMENT : un type énuméré, cinq tables neuves, quatre colonnes
-- nullables ou avec défaut sur `Ambassador`, une colonne nullable sur
-- `UserProfile`. Aucune colonne existante n'est modifiée ni supprimée ; un
-- backend plus ancien remis sur ce schéma ignore tout ce qui suit.
--
-- Trois rattrapages, tous idempotents :
--  1. `Ambassador.codeNormalized` (clé de recherche du code saisi, sans tirets
--     ni casse). Une collision après normalisation laisse la colonne NULL pour
--     les lignes concernées (la recherche retombe alors sur `code`, insensible
--     à la casse) plutôt que de faire échouer la migration.
--  2. `Ambassador.cashProgramEnabled = true` pour les lignes EXISTANTES : leur
--     app continue d'afficher l'espace « cash » comme avant. Un ambassadeur
--     activé pour la compétition naît à false.
--  3. `UserProfile.profileCompletedAt` pour les profils déjà complets, daté de
--     leur dernière modification (forcément antérieure à toute campagne : un
--     compte créé avant la fenêtre ne compte pas de toute façon). Le prédicat
--     est celui de `src/modules/referrals/campaigns/profile-completion.ts`.

-- CreateEnum
CREATE TYPE "ReferralCampaignStatus" AS ENUM ('draft', 'live', 'frozen', 'closed');

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN     "profileCompletedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "Ambassador" ADD COLUMN     "approvedAt" TIMESTAMP(3),
ADD COLUMN     "approvedByAdminId" TEXT,
ADD COLUMN     "cashProgramEnabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "codeNormalized" TEXT;

-- Rattrapage 1 : code normalisé, sauf collision.
UPDATE "Ambassador" AS a
SET "codeNormalized" = n."norm"
FROM (
    SELECT "id",
           upper(regexp_replace("code", '[^A-Za-z0-9]', '', 'g')) AS "norm",
           count(*) OVER (PARTITION BY upper(regexp_replace("code", '[^A-Za-z0-9]', '', 'g'))) AS "dup"
    FROM "Ambassador"
) AS n
WHERE a."id" = n."id" AND n."dup" = 1 AND a."codeNormalized" IS NULL;

-- Rattrapage 2 : les ambassadeurs existants gardent leur espace « cash ».
UPDATE "Ambassador" SET "cashProgramEnabled" = true;

-- Rattrapage 3 : profils déjà complets.
UPDATE "UserProfile"
SET "profileCompletedAt" = "updatedAt"
WHERE "profileCompletedAt" IS NULL
  AND "accountType" = 'student'
  AND "consentedAt" IS NOT NULL
  AND btrim("phone") <> ''
  AND "birthDate" IS NOT NULL
  AND cardinality("fieldIds") > 0
  AND cardinality("targetCountryIds") > 0
  AND ("birthDate" <= CURRENT_TIMESTAMP - INTERVAL '18 years' OR "guardianConsentedAt" IS NOT NULL);

-- CreateTable
CREATE TABLE "ReferralCampaign" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "nameFr" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "timeZone" TEXT NOT NULL DEFAULT 'Africa/Lagos',
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "status" "ReferralCampaignStatus" NOT NULL DEFAULT 'draft',
    "prizes" JSONB NOT NULL DEFAULT '[]',
    "rulesText" TEXT,
    "rulesUrl" TEXT,
    "eligibleCities" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "eligibleCountries" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "qualificationRule" JSONB NOT NULL DEFAULT '{}',
    "lastComputedAt" TIMESTAMP(3),
    "launchedAt" TIMESTAMP(3),
    "frozenAt" TIMESTAMP(3),
    "podiumValidatedAt" TIMESTAMP(3),
    "podiumValidatedByAdminId" TEXT,
    "closedAt" TIMESTAMP(3),
    "createdByAdminId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReferralCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralCampaignParticipant" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "ambassadorId" TEXT NOT NULL,
    "publicName" TEXT NOT NULL,
    "city" TEXT NOT NULL DEFAULT '',
    "country" TEXT NOT NULL DEFAULT '',
    "status" TEXT NOT NULL DEFAULT 'active',
    "statusReason" TEXT,
    "minorStatus" TEXT NOT NULL DEFAULT 'unknown',
    "parentalAuthStatus" TEXT NOT NULL DEFAULT 'not_required',
    "parentalAuthVerifiedAt" TIMESTAMP(3),
    "parentalAuthVerifiedByAdminId" TEXT,
    "parentalAuthNote" TEXT,
    "qualifiedCount" INTEGER NOT NULL DEFAULT 0,
    "flaggedCount" INTEGER NOT NULL DEFAULT 0,
    "pendingCount" INTEGER NOT NULL DEFAULT 0,
    "excludedCount" INTEGER NOT NULL DEFAULT 0,
    "reachedCountAt" TIMESTAMP(3),
    "rank" INTEGER,
    "enrolledAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "enrolledByAdminId" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReferralCampaignParticipant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralCampaignReferral" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "participantId" TEXT NOT NULL,
    "refereeProfileId" TEXT NOT NULL,
    "attachedAt" TIMESTAMP(3) NOT NULL,
    "accountCreatedAt" TIMESTAMP(3) NOT NULL,
    "profileCompletedAt" TIMESTAMP(3),
    "qualifiedAt" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'pending',
    "flags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "adminDecision" TEXT,
    "adminDecisionReason" TEXT,
    "adminDecisionByAdminId" TEXT,
    "adminDecisionAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReferralCampaignReferral_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralAttributionSignal" (
    "id" TEXT NOT NULL,
    "refereeProfileId" TEXT NOT NULL,
    "referrerProfileId" TEXT NOT NULL,
    "codeKind" TEXT NOT NULL,
    "ipHash" TEXT,
    "ipBlockHash" TEXT,
    "deviceHashes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "clientDeviceHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReferralAttributionSignal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralCampaignPrizeAward" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "rank" INTEGER NOT NULL,
    "participantId" TEXT,
    "publicNameSnapshot" TEXT NOT NULL,
    "amountFcfa" INTEGER NOT NULL,
    "recipient" TEXT NOT NULL DEFAULT 'ambassador',
    "payoutStatus" TEXT NOT NULL DEFAULT 'pending',
    "payoutMethod" TEXT NOT NULL DEFAULT 'wave',
    "payoutReference" TEXT,
    "paidAmountFcfa" INTEGER,
    "paidAt" TIMESTAMP(3),
    "paidByAdminId" TEXT,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReferralCampaignPrizeAward_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ReferralCampaign_slug_key" ON "ReferralCampaign"("slug");

-- CreateIndex
CREATE INDEX "ReferralCampaign_status_idx" ON "ReferralCampaign"("status");

-- CreateIndex
CREATE INDEX "ReferralCampaignParticipant_campaignId_rank_idx" ON "ReferralCampaignParticipant"("campaignId", "rank");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralCampaignParticipant_campaignId_ambassadorId_key" ON "ReferralCampaignParticipant"("campaignId", "ambassadorId");

-- CreateIndex
CREATE INDEX "ReferralCampaignReferral_participantId_status_idx" ON "ReferralCampaignReferral"("participantId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralCampaignReferral_campaignId_refereeProfileId_key" ON "ReferralCampaignReferral"("campaignId", "refereeProfileId");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralAttributionSignal_refereeProfileId_key" ON "ReferralAttributionSignal"("refereeProfileId");

-- CreateIndex
CREATE INDEX "ReferralAttributionSignal_referrerProfileId_createdAt_idx" ON "ReferralAttributionSignal"("referrerProfileId", "createdAt");

-- CreateIndex
CREATE INDEX "ReferralAttributionSignal_createdAt_idx" ON "ReferralAttributionSignal"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralCampaignPrizeAward_campaignId_rank_key" ON "ReferralCampaignPrizeAward"("campaignId", "rank");

-- CreateIndex
CREATE UNIQUE INDEX "Ambassador_codeNormalized_key" ON "Ambassador"("codeNormalized");

-- AddForeignKey
ALTER TABLE "ReferralCampaignParticipant" ADD CONSTRAINT "ReferralCampaignParticipant_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "ReferralCampaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCampaignParticipant" ADD CONSTRAINT "ReferralCampaignParticipant_ambassadorId_fkey" FOREIGN KEY ("ambassadorId") REFERENCES "Ambassador"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCampaignReferral" ADD CONSTRAINT "ReferralCampaignReferral_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "ReferralCampaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCampaignReferral" ADD CONSTRAINT "ReferralCampaignReferral_participantId_fkey" FOREIGN KEY ("participantId") REFERENCES "ReferralCampaignParticipant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCampaignPrizeAward" ADD CONSTRAINT "ReferralCampaignPrizeAward_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "ReferralCampaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCampaignPrizeAward" ADD CONSTRAINT "ReferralCampaignPrizeAward_participantId_fkey" FOREIGN KEY ("participantId") REFERENCES "ReferralCampaignParticipant"("id") ON DELETE SET NULL ON UPDATE CASCADE;

