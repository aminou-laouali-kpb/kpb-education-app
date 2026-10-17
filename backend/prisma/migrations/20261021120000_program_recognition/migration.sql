-- Chantier E/J : reconnaissance du diplôme d'une formation (« Titre RNCP »,
-- « Grade de licence », « Diplôme visé »…), affichée sur la fiche formation.
--
-- Les grilles partenaires (IGENSIA Education d'abord) la donnent formation par
-- formation. Elle ne tient ni dans `levelFr` (le niveau est normalisé et filtré :
-- « Bachelor », « Master »…) ni dans `requirementsFr` (ce que l'élève doit
-- fournir, pas ce qu'il obtient).
--
-- ADDITIF SEULEMENT : deux colonnes nullables, sans défaut ni réécriture de
-- table. NULL = reconnaissance non renseignée ; l'app n'affiche alors rien. Un
-- backend plus ancien remis sur ce schéma les ignore.
ALTER TABLE "Program" ADD COLUMN "recognitionFr" TEXT;
ALTER TABLE "Program" ADD COLUMN "recognitionEn" TEXT;
