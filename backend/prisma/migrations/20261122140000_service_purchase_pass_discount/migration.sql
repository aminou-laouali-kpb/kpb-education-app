-- Remise du Pass Karatou sur les ventes de services : additif (une colonne à
-- défaut, deux nullables). Les ventes existantes gardent leur montant.

-- AlterTable
ALTER TABLE "ServicePurchase" ADD COLUMN     "discountPercent" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "discountReason" TEXT,
ADD COLUMN     "listPriceXOF" INTEGER;
