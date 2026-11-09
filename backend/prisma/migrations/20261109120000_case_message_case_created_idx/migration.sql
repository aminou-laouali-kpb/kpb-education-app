-- Fil d'un dossier lu page par page (admin) : additif, sans verrou long sur
-- une table de quelques milliers de lignes.
CREATE INDEX IF NOT EXISTS "CaseMessage_caseId_createdAt_idx" ON "CaseMessage"("caseId", "createdAt");
