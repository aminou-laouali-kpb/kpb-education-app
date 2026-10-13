-- Dernière build de l'app vue par compte : quelle part des comptes actifs
-- tourne sur quelle build.
--
-- POURQUOI
--
-- Depuis la build 54, chaque requête de l'app porte `X-KPB-App-Version` et
-- `X-KPB-App-Build`, mais aucun code serveur ne les lisait. Relever
-- `minVersion` (écran de mise à jour qu'on ne ferme pas) ou changer de
-- fournisseur de push se décidait donc à l'aveugle : personne ne savait combien
-- de comptes actifs étaient encore sur une 53.
--
-- `lastAppSeenAt` est posé même quand les en-têtes manquent : c'est ce qui
-- distingue « actif sur une build ≤ 53 » (vu, build inconnue) de « inactif »
-- (jamais vu). Les trois colonnes sont lues en agrégat seulement
-- (GET /admin/app-builds) et partent avec le profil à la suppression du compte.
--
-- ADDITIF SEULEMENT : trois colonnes nullables, sans défaut, sans reprise, sans
-- index, sans DROP et sans NOT NULL. Ajout sans réécriture de table. Les lignes
-- existantes gardent NULL = « jamais vu », et un backend plus ancien remis sur
-- ce schéma continue de fonctionner en ignorant les colonnes.
ALTER TABLE "UserProfile" ADD COLUMN "lastAppVersion" TEXT;
ALTER TABLE "UserProfile" ADD COLUMN "lastAppBuild" INTEGER;
ALTER TABLE "UserProfile" ADD COLUMN "lastAppSeenAt" TIMESTAMP(3);
