-- Pass Karatou : accès accordés hors de l'app, et cours réservés. Additif :
-- une table neuve, deux booléens à défaut `false` (rien ne se ferme seul).

-- AlterTable
ALTER TABLE "AcademyCourse" ADD COLUMN     "requiresPass" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "AcademyLesson" ADD COLUMN     "isFreePreview" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "PassGrant" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "durationDays" INTEGER NOT NULL,
    "paymentReference" TEXT NOT NULL,
    "amountXof" INTEGER,
    "source" TEXT NOT NULL,
    "grantedBy" TEXT NOT NULL,
    "note" TEXT,
    "revokedAt" TIMESTAMP(3),
    "revokedBy" TEXT,
    "revokedReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PassGrant_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PassGrant_paymentReference_key" ON "PassGrant"("paymentReference");

-- CreateIndex
CREATE INDEX "PassGrant_userId_endsAt_idx" ON "PassGrant"("userId", "endsAt");

-- CreateIndex
CREATE INDEX "PassGrant_createdAt_idx" ON "PassGrant"("createdAt");

-- AddForeignKey
ALTER TABLE "PassGrant" ADD CONSTRAINT "PassGrant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
