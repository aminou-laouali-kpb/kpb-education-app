-- Diagnostic EN LECTURE SEULE du catalogue de production.
-- Exécuté par .github/workflows/db-info.yml — voir ce fichier pour le contexte.
--
-- Postgres refuse toute écriture dans cette transaction : la lecture seule est
-- garantie par le serveur, pas seulement par notre bonne volonté.
BEGIN READ ONLY;

\echo '=== 1. Répartition publication/activation des bourses ==='
SELECT "moderationStatus", "isActive", COUNT(*) AS lignes
FROM "Scholarship" GROUP BY 1, 2 ORDER BY 3 DESC;

\echo ''
\echo '=== 2. Le filtre exact des endpoints publics ==='
SELECT COUNT(*) AS bourses_visibles_par_lapp
FROM "Scholarship"
WHERE "isActive" = true AND "moderationStatus" = 'approved';

\echo ''
\echo '=== 3. Parmi les visibles : domaines renseignés ? dates vivantes ? ==='
SELECT COUNT(*)                                                    AS visibles,
       COUNT(*) FILTER (WHERE cardinality("relatedFieldIds") > 0)   AS avec_domaines,
       COUNT(*) FILTER (WHERE "deadlineAt" IS NULL)                 AS sans_date_limite,
       COUNT(*) FILTER (WHERE "deadlineAt" > now())                 AS date_limite_future
FROM "Scholarship"
WHERE "isActive" = true AND "moderationStatus" = 'approved';

\echo ''
\echo '=== 4. Les deux cartes vues sur l app existent-elles en base ? ==='
\echo '    0 ligne = ce sont des donnees fictives servies par le repli mock'
SELECT id, "nameFr", "isActive", "moderationStatus"
FROM "Scholarship"
WHERE "nameFr" ILIKE '%MacBain%' OR "nameFr" ILIKE '%Mastercard%';

\echo ''
\echo '=== 5. Controle : les programmes, eux, sont bien la ==='
\echo '    L app en affiche 344. Si le compte concorde, la base est vivante et'
\echo '    le probleme est propre aux bourses. Program n a pas de colonne de'
\echo '    publication : sa visibilite ne depend que de la presence des lignes.'
SELECT COUNT(*) AS programmes FROM "Program";

\echo ''
\echo '=== 6. Agregat des domaines declares dans les profils ==='
\echo '    Aucune donnee nominative : uniquement des compteurs.'
SELECT COUNT(*)                                              AS profils,
       COUNT(*) FILTER (WHERE cardinality("fieldIds") > 0)    AS avec_domaines_choisis
FROM "UserProfile";

\echo ''
\echo '=== 7. Catalogue « Études en France » : ce qui est en base ==='
\echo '    Identifiants eef-univ-% / eef-prog-% : les lignes de l import. Aucune'
\echo '    donnee nominative, uniquement des compteurs.'
SELECT "isActive"              AS publie,
       (id LIKE 'eef-univ-%')  AS import_eef,
       COUNT(*)                AS etablissements,
       COUNT(*) FILTER (WHERE "lastVerifiedAt" IS NOT NULL) AS verifies
FROM "Institution"
GROUP BY 1, 2 ORDER BY 2 DESC, 1 DESC;

SELECT "isActive"                     AS publie,
       (id LIKE 'eef-prog-%')         AS import_eef,
       ("procedureType" IS NOT NULL)  AS avec_procedure,
       COUNT(*)                       AS formations,
       COUNT(*) FILTER (WHERE "lastVerifiedAt" IS NOT NULL) AS verifiees
FROM "Program"
GROUP BY 1, 2, 3 ORDER BY 2 DESC, 1 DESC, 3 DESC;

\echo ''
\echo '=== 8. Les lignes de l import, par cycle et par procedure ==='
SELECT "cycle", "procedureType", COUNT(*) AS formations,
       COUNT(*) FILTER (WHERE "isActive") AS publiees
FROM "Program"
WHERE id LIKE 'eef-prog-%'
GROUP BY 1, 2 ORDER BY 3 DESC;

\echo ''
\echo '=== 9. Avis conseillers sans auteur (a traiter par reviews-purge-orphans) ==='
SELECT COUNT(*) AS sans_auteur,
       COUNT(*) FILTER (WHERE NOT EXISTS (
         SELECT 1 FROM "Case" c WHERE c."id" = r."caseId")) AS dont_orphelins
FROM "CounsellorReview" r
WHERE r."reviewerUserId" IS NULL;

\echo ''
\echo '=== 10. Domaines d01..d12 : la liste que l app affiche, contre les formations de l import ==='
-- Les formations de l import portent le nom canonique de l orientation
-- (Informatique, Commerce & Management, Ingenierie & Sciences, Sante...).
-- Si un nom ci-dessous en differe, NE PAS reimporter avant d avoir compris pourquoi.
SELECT f."id", f."nameFr",
       COUNT(p."id")                            AS formations_import,
       COUNT(p."id") FILTER (WHERE p."isActive") AS publiees
FROM "Field" f
LEFT JOIN "Program" p ON p."fieldId" = f."id" AND p."id" LIKE 'eef-prog-%'
GROUP BY 1, 2 ORDER BY 1;

\echo ''
\echo '=== 11. Texte cherchable des formations de l import (a combler par eef:backfill:search) ==='
-- Sans texte normalise, la recherche libre retombe sur la comparaison brute :
-- « genie » ne trouve alors pas « Genie civil ». 0 = rien a faire. La requete est
-- construite par \gexec pour ne pas echouer sur une base dont le backend n est pas
-- encore deploye (colonne absente).
SELECT 'SELECT COUNT(*) AS formations_import, COUNT(*) FILTER (WHERE "searchText" IS NULL) AS sans_texte_cherchable FROM "Program" WHERE id LIKE ''eef-prog-%'''
WHERE EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_name = 'Program' AND column_name = 'searchText')
\gexec
SELECT 'colonne Program.searchText absente : deployer le backend (migration) d abord' AS etat
WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_name = 'Program' AND column_name = 'searchText');

\echo ''
\echo '=== 12. Audit de publication : integrite des lignes de l import (aucune donnee nominative) ==='
\echo '    Etablissements : tout doit etre a 0 SAUF sans_logo (information : un logo absent est'
\echo '    assume, on n affiche pas une marque sous copyright pour combler le trou).'
SELECT COUNT(*)                                                                     AS etablissements,
       COUNT(*) FILTER (WHERE i."isActive")                                         AS deja_publies,
       COUNT(*) FILTER (WHERE i."sourceUrl" IS NULL OR i."sourceUrl" !~ '^https://') AS sans_source_https,
       COUNT(*) FILTER (WHERE i."websiteUrl" IS NULL OR i."websiteUrl" !~ '^https://') AS sans_site_https,
       COUNT(*) FILTER (WHERE btrim(i."nameFr") = '' OR btrim(i."nameEn") = '')      AS sans_nom,
       COUNT(*) FILTER (WHERE btrim(i."locationFr") = '')                            AS sans_ville,
       COUNT(*) FILTER (WHERE i."uaiCode" IS NULL)                                   AS sans_uai,
       COUNT(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM "Country" c WHERE c."id" = i."countryId")) AS pays_inexistant,
       COUNT(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM "Program" p WHERE p."institutionId" = i."id")) AS sans_formation,
       COUNT(*) FILTER (WHERE i."logoUrl" IS NULL)                                   AS sans_logo
FROM "Institution" i
WHERE i."id" LIKE 'eef-univ-%';

SELECT COUNT(*) AS codes_uai_en_double
FROM (SELECT "uaiCode" FROM "Institution"
      WHERE "id" LIKE 'eef-univ-%' AND "uaiCode" IS NOT NULL
      GROUP BY 1 HAVING COUNT(*) > 1) d;

\echo ''
\echo '    Formations : tout doit etre a 0 SAUF formations et deja_publiees. publiables_par_le_plan'
\echo '    reprend les trois controles du plan de publication (source https, procedure, domaine).'
SELECT COUNT(*)                                                                      AS formations,
       COUNT(*) FILTER (WHERE p."isActive")                                          AS deja_publiees,
       COUNT(*) FILTER (WHERE p."sourceUrl" IS NULL OR p."sourceUrl" !~ '^https://')  AS sans_source_https,
       COUNT(*) FILTER (WHERE p."procedureType" IS NULL OR btrim(p."procedureType") = '') AS sans_procedure,
       COUNT(*) FILTER (WHERE p."procedureType" IS NOT NULL
                          AND p."procedureType" NOT IN ('dap_blanche','dap_jaune','eef','parcoursup','hors_eef')) AS procedure_inconnue,
       COUNT(*) FILTER (WHERE p."cycle" IS NULL)                                     AS sans_cycle,
       COUNT(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM "Field" f WHERE f."id" = p."fieldId")) AS domaine_hors_referentiel,
       COUNT(*) FILTER (WHERE btrim(p."nameFr") = '' OR btrim(p."nameEn") = '')       AS sans_nom,
       COUNT(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM "Institution" i WHERE i."id" = p."institutionId")) AS orphelines,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM "Institution" i
                                      WHERE i."id" = p."institutionId" AND i."id" NOT LIKE 'eef-univ-%')) AS parent_hors_import,
       COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM "Institution" i
                                      WHERE i."id" = p."institutionId" AND i."countryId" <> p."countryId")) AS pays_different_du_parent,
       COUNT(*) FILTER (WHERE p."sourceUrl" ~ '^https://'
                          AND p."procedureType" IS NOT NULL AND btrim(p."procedureType") <> ''
                          AND EXISTS (SELECT 1 FROM "Field" f WHERE f."id" = p."fieldId")) AS publiables_par_le_plan
FROM "Program" p
WHERE p."id" LIKE 'eef-prog-%';

\echo ''
\echo '    Le catalogue general (les autres espaces) : ces totaux ne doivent PAS bouger apres une'
\echo '    publication Etudes en France (avant le 01/10/2026 : 69 etablissements, 634 formations).'
SELECT (SELECT COUNT(*) FROM "Institution" WHERE "isActive" AND "id" NOT LIKE 'eef-univ-%') AS etablissements_hors_import_actifs,
       (SELECT COUNT(*) FROM "Program"     WHERE "isActive" AND "id" NOT LIKE 'eef-prog-%') AS formations_hors_import_actives;

\echo ''
\echo '    Comptes pouvant signer une publication (nombres seulement) : au moins 1 attendu.'
SELECT "role", COUNT(*) AS comptes_actifs
FROM "AdminUser"
WHERE "isActive" AND "role" IN ('admin', 'super_admin')
GROUP BY 1 ORDER BY 1;

\echo ''
\echo '    Build 57 - prealables des migrations scholarship_follow (docs/api-contracts.md) :'
\echo '    au-dela d environ 1 million de lignes, construire les index AVANT le deploiement.'
SELECT (SELECT COUNT(*) FROM "SavedItem") AS saved_items,
       (SELECT COUNT(*) FROM "UserNotification") AS user_notifications;

\echo ''
\echo '    Cycles a academicYear invalide : DOIT etre vide avant le deploiement de la 57.'
SELECT "scholarshipId", "academicYear" FROM "ScholarshipCycle"
WHERE NOT CASE
  WHEN "academicYear" ~ '^\d{4}$' THEN true
  WHEN "academicYear" ~ '^\d{4}-\d{4}$'
    THEN split_part("academicYear", '-', 2)::int = split_part("academicYear", '-', 1)::int + 1
  ELSE false
END;

\echo ''
\echo '    Index INVALID (CONCURRENTLY rate) : DOIT etre vide.'
SELECT indexrelid::regclass AS index_invalide FROM pg_index WHERE NOT indisvalid;

COMMIT;
