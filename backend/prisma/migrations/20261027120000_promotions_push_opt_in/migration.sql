-- Chantier juridique 57 — push promotionnel en OPT-IN (App Store 4.5.4).
--
-- ADDITIF SEULEMENT : deux colonnes neuves, aucune colonne existante modifiée.
-- Un backend plus ancien les ignore.
--
-- `UserProfile.promotionsPushOptIn` : « recevoir par notification les
-- nouvelles et offres de KPB ». Défaut NON pour tout le monde, comptes
-- existants compris : personne n'est réputé avoir consenti, et une build qui
-- ne connaît pas le champ ne reçoit donc plus de push promotionnel.
-- `promotionsPushConsentedAt` : preuve horodatée du dernier opt-in.

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN "promotionsPushOptIn" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "promotionsPushConsentedAt" TIMESTAMP(3);
