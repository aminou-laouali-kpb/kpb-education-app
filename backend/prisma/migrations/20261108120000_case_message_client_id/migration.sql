-- Messages de dossier : identifiant client pour l'idempotence (revue avant la
-- 58, PR #408).
--
-- L'app renvoie depuis sa file d'envoi un message dont le POST a pu aboutir
-- sans qu'elle reçoive la réponse (app tuée, réseau coupé). Avec
-- `clientMessageId`, le serveur rend alors le message existant au lieu d'en
-- créer un second chez le conseiller.
--
-- ADDITIF SEULEMENT : colonne nullable, aucune donnée réécrite. Les messages
-- existants, ceux des anciennes apps et ceux du personnel gardent NULL ; un
-- index unique Postgres admet plusieurs NULL, il ne contraint donc que les
-- messages qui portent un identifiant.
ALTER TABLE "CaseMessage" ADD COLUMN "clientMessageId" TEXT;

CREATE UNIQUE INDEX "CaseMessage_caseId_clientMessageId_key" ON "CaseMessage"("caseId", "clientMessageId");
