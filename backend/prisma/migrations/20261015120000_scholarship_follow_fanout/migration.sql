-- Chantier C : suivre une bourse, annonce d'ouverture programmée et
-- annulable, boîte d'envoi push portée par UserNotification.
--
-- POURQUOI
--
-- « Suivre » = favori + alerte d'ouverture + rappels de date limite (décision
-- propriétaire). L'annonce part 120 s après le geste de l'équipe, annulable
-- d'ici là, puis un worker l'envoie au rythme permis (heures calmes, 1 push par
-- 30 min et 2 par jour et par étudiant). Il faut donc :
--   - la sourdine par bourse et la trace de la cloche (ScholarshipAlertSubscription) ;
--   - l'état d'annonce de chaque cycle (ScholarshipCycle) ;
--   - l'état d'envoi de chaque entrée d'inbox (UserNotification).
--
-- ADDITIF SEULEMENT : colonnes nullables ou à défaut constant (métadonnées
-- seules en PostgreSQL 15, aucune réécriture de table), un index sur une petite
-- table, deux reprises idempotentes sur ScholarshipCycle. Ni DROP, ni NOT NULL
-- sans défaut. Un backend plus ancien remis sur ce schéma ignore tout.
--
-- VERROUS
--
-- `prisma migrate deploy` envoie ce fichier comme UN script, que PostgreSQL
-- exécute dans UNE transaction implicite : le verrou ACCESS EXCLUSIVE de chaque
-- ALTER est tenu jusqu'à la fin du fichier. Rien de lent ici, donc. Les index
-- des grosses tables vivent dans 20261015120100, la reprise de UserNotification
-- dans 20261015120200. `lock_timeout` fait échouer vite plutôt que de geler
-- l'inbox derrière une longue requête : en cas d'échec,
-- `prisma migrate resolve --rolled-back 20261015120000_scholarship_follow_fanout`
-- puis relancer à une heure creuse.
SET LOCAL lock_timeout = '5s';

ALTER TABLE "ScholarshipAlertSubscription"
  ADD COLUMN "mutedAt" TIMESTAMP(3),
  ADD COLUMN "impliedFollow" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "ScholarshipCycle"
  ADD COLUMN "openingFanoutDueAt" TIMESTAMP(3),
  ADD COLUMN "openingFanoutScope" TEXT,
  ADD COLUMN "openingFanoutById" TEXT,
  ADD COLUMN "openingLastFanoutAt" TIMESTAMP(3),
  ADD COLUMN "openingNotifiedAt" TIMESTAMP(3),
  ADD COLUMN "openingNotifiedById" TEXT,
  ADD COLUMN "openingAudience" INTEGER,
  ADD COLUMN "openingSkippedAt" TIMESTAMP(3),
  ADD COLUMN "openingSkippedReason" TEXT,
  ADD COLUMN "openingStoppedAt" TIMESTAMP(3),
  ADD COLUMN "openingPreExisting" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "UserNotification"
  ADD COLUMN "cycleId" TEXT,
  ADD COLUMN "pushStatus" TEXT,
  ADD COLUMN "pushNotBefore" TIMESTAMP(3),
  ADD COLUMN "pushAttempts" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "pushLockedUntil" TIMESTAMP(3),
  ADD COLUMN "pushLockedBy" TEXT,
  ADD COLUMN "pushLastError" TEXT,
  ADD COLUMN "pushProvider" TEXT,
  ADD COLUMN "pushBatchId" TEXT;

-- Petite table (une ligne par bourse et par année) : construction immédiate.
CREATE INDEX "ScholarshipCycle_openingFanoutDueAt_idx" ON "ScholarshipCycle"("openingFanoutDueAt");

-- Reprise 1 (décision propriétaire : pas d'annonce rétroactive). Tout cycle
-- ouvert ou activé avant ce déploiement est hors annonce. Activé = déjà
-- annoncé, mais à ses seules alertes : ses favoris n'ont jamais été prévenus,
-- d'où le drapeau, qui interdit aussi la relance « nouveaux abonnés ».
UPDATE "ScholarshipCycle"
SET "openingPreExisting" = true,
    "openingNotifiedAt" = COALESCE("openingNotifiedAt", "activatedAt")
WHERE ("activatedAt" IS NOT NULL OR "status" = 'open')
  AND "openingPreExisting" = false;

-- Reprise 2 : un cycle ouvert par le catalogue (jamais activé) ne doit pas
-- apparaître dans « À faire » ; l'aperçu affiche la raison.
UPDATE "ScholarshipCycle"
SET "openingSkippedAt" = CURRENT_TIMESTAMP,
    "openingSkippedReason" = 'pre_existing_open'
WHERE "openingPreExisting" = true
  AND "activatedAt" IS NULL
  AND "openingNotifiedAt" IS NULL
  AND "openingSkippedAt" IS NULL;
