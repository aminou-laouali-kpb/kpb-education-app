-- Correctifs 57 (XC-06) — campagnes de l'admin : finalité et consentement.
--
-- ADDITIF SEULEMENT : trois colonnes neuves, aucune colonne existante modifiée.
-- Un backend plus ancien les ignore.
--
-- `NotificationCampaign.purpose` : `informational` | `promotional`. Défaut
-- PRUDENT `promotional`, y compris pour les campagnes déjà créées (texte libre :
-- on ne peut pas prouver qu'elles étaient de service).
--
-- `UserProfile.promotionsEmailOptIn` : « recevoir par e-mail les nouvelles et
-- offres de KPB », DISTINCT de la newsletter bourses. Défaut NON pour tout le
-- monde : personne n'est réputé avoir consenti.

-- AlterTable
ALTER TABLE "NotificationCampaign" ADD COLUMN "purpose" TEXT NOT NULL DEFAULT 'promotional';

-- AlterTable
ALTER TABLE "UserProfile" ADD COLUMN "promotionsEmailOptIn" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "promotionsEmailConsentedAt" TIMESTAMP(3);
