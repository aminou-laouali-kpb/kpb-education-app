-- Administration des cours Academy (préparation HSK, etc.) : additif.
-- Deux colonnes avec défaut, une colonne nullable, deux index. Un code plus
-- ancien les ignore ; aucune ligne existante ne change de sens (les leçons
-- existantes deviennent « published », ce qu'elles étaient implicitement).

-- AlterTable
ALTER TABLE "AcademyCourse" ADD COLUMN     "displayOrder" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "slug" TEXT;

-- AlterTable
ALTER TABLE "AcademyLesson" ADD COLUMN     "status" "PublicationStatus" NOT NULL DEFAULT 'published';

-- CreateIndex
CREATE UNIQUE INDEX "AcademyCourse_slug_key" ON "AcademyCourse"("slug");

-- CreateIndex
CREATE INDEX "AcademyLesson_courseId_order_idx" ON "AcademyLesson"("courseId", "order");
