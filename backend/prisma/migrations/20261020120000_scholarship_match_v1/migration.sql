-- Chantier D : « Mes 10 bourses », moteur d'éligibilité (v1).
--
-- POURQUOI
--
-- Le moteur n'exclut un élève que sur des données structurées, fraîches et
-- confirmées. Il faut donc :
--   - l'éligibilité structurée de chaque bourse (niveaux, domaines, critères
--     typés, tampon de structuration) ;
--   - les réponses du test sur le profil (toutes facultatives) ;
--   - les passages du moteur (ScholarshipMatchRun, 5 derniers par élève) ;
--   - le lien d'un dossier vers la bourse qu'il accompagne (Case.scholarshipId).
--
-- ADDITIF SEULEMENT : colonnes nullables ou à défaut constant (métadonnées
-- seules en PostgreSQL 15, aucune réécriture de table), une table neuve, deux
-- index, une clé étrangère sur une colonne entièrement NULL. Ni DROP, ni
-- NOT NULL sans défaut. Un backend plus ancien remis sur ce schéma ignore tout.
--
-- REPRISE
--
-- `eligibleLevels` est repris des tags de niveau (vocabulaire exact de
-- scholarship-level.ts : secondary, bachelor, master, doctorate), et
-- SEULEMENT sur les fiches du catalogue vérifié (tag `catalog:<version>`), où
-- les tags reprennent exactement `levels`. Les fiches saisies à la main ou
-- collectées restent vides, donc « non analysées ».
--
-- La reprise NE TAMPONNE PAS `eligibilityStructuredAt` : un niveau repris des
-- tags n'a été relu par personne et ne peut donc exclure aucun élève tant
-- qu'un éditeur ne l'a pas confirmé. Idempotente : elle ne touche que les
-- fiches encore vides.
--
-- VERROUS
--
-- `prisma migrate deploy` exécute ce fichier dans UNE transaction implicite.
-- `lock_timeout` fait échouer vite plutôt que de geler les lectures derrière
-- une longue requête : en cas d'échec,
-- `prisma migrate resolve --rolled-back 20261020120000_scholarship_match_v1`
-- puis relancer à une heure creuse.
SET LOCAL lock_timeout = '5s';

-- CreateEnum
CREATE TYPE "ScholarshipEligibleLevel" AS ENUM ('secondary', 'bachelor', 'master', 'doctorate');

-- CreateEnum
CREATE TYPE "ScholarshipFieldsScope" AS ENUM ('unknown', 'all', 'listed');

-- AlterTable
ALTER TABLE "UserProfile"
  ADD COLUMN "englishLevel" TEXT,
  ADD COLUMN "frenchLevel" TEXT,
  ADD COLUMN "gradeBandOn20" TEXT,
  ADD COLUMN "highestDiploma" TEXT,
  ADD COLUMN "languageTests" JSONB,
  ADD COLUMN "nationalityCode" TEXT,
  ADD COLUMN "scholarshipMatchAlertsOptInAt" TIMESTAMP(3),
  ADD COLUMN "scholarshipProfileConfirmedAt" TIMESTAMP(3),
  ADD COLUMN "scholarshipTargetLevel" TEXT,
  ADD COLUMN "secondNationalityCode" TEXT,
  ADD COLUMN "workExperienceBand" TEXT;

-- AlterTable
ALTER TABLE "Case" ADD COLUMN "scholarshipId" TEXT;

-- AlterTable
ALTER TABLE "Scholarship"
  ADD COLUMN "eligibilityCriteria" JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN "eligibilityStructuredAt" TIMESTAMP(3),
  ADD COLUMN "eligibilityStructuredBy" TEXT,
  ADD COLUMN "eligibleLevels" "ScholarshipEligibleLevel"[] DEFAULT ARRAY[]::"ScholarshipEligibleLevel"[],
  ADD COLUMN "fieldsScope" "ScholarshipFieldsScope" NOT NULL DEFAULT 'unknown';

-- CreateTable
CREATE TABLE "ScholarshipMatchRun" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "algorithmVersion" TEXT NOT NULL,
    "trigger" TEXT NOT NULL,
    "profileHash" TEXT NOT NULL,
    "catalogHash" TEXT NOT NULL,
    "inputsSummary" JSONB NOT NULL,
    "items" JSONB NOT NULL,
    "excludedSummary" JSONB NOT NULL,
    "eligibleCount" INTEGER NOT NULL DEFAULT 0,
    "toVerifyCount" INTEGER NOT NULL DEFAULT 0,
    "excludedCount" INTEGER NOT NULL DEFAULT 0,
    "candidateCount" INTEGER NOT NULL DEFAULT 0,
    "notAnalyzedCount" INTEGER NOT NULL DEFAULT 0,
    "notifiedScholarshipIds" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ScholarshipMatchRun_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ScholarshipMatchRun_userId_createdAt_idx" ON "ScholarshipMatchRun"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "Case_scholarshipId_idx" ON "Case"("scholarshipId");

-- AddForeignKey
ALTER TABLE "Case" ADD CONSTRAINT "Case_scholarshipId_fkey" FOREIGN KEY ("scholarshipId") REFERENCES "Scholarship"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ScholarshipMatchRun" ADD CONSTRAINT "ScholarshipMatchRun_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Reprise des niveaux : fiches `catalog:%` seulement, sans tampon.
UPDATE "Scholarship" AS s
SET "eligibleLevels" = ARRAY(
  SELECT DISTINCT lower(btrim(tag))::"ScholarshipEligibleLevel" AS level
  FROM unnest(s."tags") AS tag
  WHERE lower(btrim(tag)) IN ('secondary', 'bachelor', 'master', 'doctorate')
  ORDER BY level
)
WHERE s."eligibleLevels" = ARRAY[]::"ScholarshipEligibleLevel"[]
  AND EXISTS (
    SELECT 1 FROM unnest(s."tags") AS tag WHERE tag LIKE 'catalog:%'
  )
  AND EXISTS (
    SELECT 1 FROM unnest(s."tags") AS tag
    WHERE lower(btrim(tag)) IN ('secondary', 'bachelor', 'master', 'doctorate')
  );
