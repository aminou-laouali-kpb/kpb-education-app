-- Chantier C : reprise de UserNotification."cycleId" et de
-- ScholarshipCycle."openingAudience".
--
-- Le cycle annoncé n'existait que dans le JSON `data` des lignes
-- `scholarship_opened` (scholarship-lifecycle.service.ts). Le rapport, le garde
-- de réannonce à 30 jours et `openingAudience` lisent désormais la colonne.
--
-- Fichier à part : il lit séquentiellement UserNotification (aucun index sur
-- `kind`). Seul dans sa transaction, il ne prend que ROW EXCLUSIVE sur les
-- lignes touchées : l'inbox reste lisible et inscriptible pendant ce temps.
-- Idempotent : une seconde exécution ne touche aucune ligne.
UPDATE "UserNotification"
SET "cycleId" = "data"->>'cycleId'
WHERE "kind" = 'scholarship_opened'
  AND "cycleId" IS NULL
  AND "data" ? 'cycleId';

UPDATE "ScholarshipCycle" c
SET "openingAudience" = sub.n
FROM (
  SELECT "cycleId", count(*)::int AS n
  FROM "UserNotification"
  WHERE "kind" = 'scholarship_opened' AND "cycleId" IS NOT NULL
  GROUP BY 1
) sub
WHERE c."id" = sub."cycleId"
  AND c."openingAudience" IS NULL;
