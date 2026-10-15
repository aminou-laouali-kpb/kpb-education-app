-- Chantier C : les index des grosses tables, à part.
--
-- Chaque CREATE INDEX prend un verrou SHARE (il bloque les écritures) le temps
-- de la construction. Ils ne sont PAS dans 20261015120000 : ce fichier-là tient
-- l'ACCESS EXCLUSIVE de `ALTER TABLE "UserNotification"` jusqu'à sa fin, et
-- l'inbox entière aurait attendu trois constructions d'index.
--
-- IF NOT EXISTS : au-delà d'environ un million de lignes (`db-info.yml` donne
-- les volumes), l'exploitation les construit à la main AVANT le déploiement,
-- en CREATE INDEX CONCURRENTLY sous ces noms exacts, puis vérifie que
-- `SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid` est vide
-- (un CONCURRENTLY raté laisse un index INVALID que IF NOT EXISTS garderait).
-- Ce fichier ne fait alors plus rien, sans `prisma migrate resolve`.

-- Les abonnés d'une bourse (annonce, rappels) : itemType = 'scholarship' AND itemId IN (…).
CREATE INDEX IF NOT EXISTS "SavedItem_itemType_itemId_idx" ON "SavedItem"("itemType", "itemId");

-- La file du worker : pushStatus = 'pending' AND pushNotBefore <= now.
CREATE INDEX IF NOT EXISTS "UserNotification_pushStatus_pushNotBefore_idx" ON "UserNotification"("pushStatus", "pushNotBefore");

-- Le rapport d'un cycle, l'arrêt des envois et le garde de réannonce.
CREATE INDEX IF NOT EXISTS "UserNotification_cycleId_kind_idx" ON "UserNotification"("cycleId", "kind");
