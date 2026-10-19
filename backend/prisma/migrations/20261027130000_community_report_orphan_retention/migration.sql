-- Chantier juridique 57 — signalements conservés 12 mois après la suppression
-- du compte de leur auteur.
--
-- ADDITIF SEULEMENT : une colonne neuve, nullable. Posée par la suppression du
-- compte (juste avant que `reporterMemberId` passe à NULL) ; la purge
-- quotidienne efface les signalements orphelins 12 mois après. Les orphelins
-- antérieurs à cette colonne (date inconnue) sont purgés 12 mois après leur
-- création, donc jamais plus tard que 12 mois après la suppression.

-- AlterTable
ALTER TABLE "CommunityReport" ADD COLUMN "reporterDeletedAt" TIMESTAMP(3);
