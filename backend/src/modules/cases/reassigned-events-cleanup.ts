// Nettoyage des événements « Dossier réattribué » écrits en boucle avant la
// PR #397 (07/11/2026) : la tâche planifiée réattribuait le même dossier
// toutes les 10 h, d'où ~66 lignes par dossier dans l'historique que
// l'étudiant voit (`case_detail_screen.dart`).
//
// Règle, validée par le propriétaire : par dossier, on GARDE la plus récente
// (c'est elle qui nomme le conseiller actuel, et c'est elle que relit la tâche
// corrigée pour savoir si l'attente en cours a déjà été traitée) et on
// supprime les autres. Rien d'autre n'est touché : ni les autres événements,
// ni les dossiers. Aucune table ne référence `CaseTimelineEvent`.
//
// Rejouable : une seconde exécution trouve 0 ligne.

import { REASSIGNED_EVENT_TITLE } from "./case-reassignment-cron.service";

export type Executeur = {
  $queryRawUnsafe<T = unknown>(query: string, ...values: unknown[]): Promise<T>;
  $executeRawUnsafe(query: string, ...values: unknown[]): Promise<number>;
};

export type Releve = {
  /** Lignes « Dossier réattribué » en base. */
  total: number;
  /** Dossiers qui en ont au moins une. */
  dossiers: number;
  /** Lignes en trop : `total - dossiers`. */
  enTrop: number;
  /** Le plus grand nombre de lignes pour un même dossier. */
  maxParDossier: number;
};

export async function relever(db: Executeur): Promise<Releve> {
  const [r] = await db.$queryRawUnsafe<
    { total: bigint; dossiers: bigint; max: bigint | null }[]
  >(
    `SELECT count(*)::bigint AS total,
            count(DISTINCT "caseId")::bigint AS dossiers,
            (SELECT max(n) FROM (SELECT count(*) AS n FROM "CaseTimelineEvent"
               WHERE title = $1 GROUP BY "caseId") t)::bigint AS max
       FROM "CaseTimelineEvent" WHERE title = $1`,
    REASSIGNED_EVENT_TITLE,
  );
  const total = Number(r.total);
  const dossiers = Number(r.dossiers);
  return {
    total,
    dossiers,
    enTrop: total - dossiers,
    maxParDossier: Number(r.max ?? 0),
  };
}

/**
 * Supprime, pour chaque dossier, toutes les lignes « Dossier réattribué » sauf
 * la plus récente (à date égale, l'id le plus grand départage). Renvoie le
 * nombre de lignes supprimées.
 */
export async function nettoyer(db: Executeur): Promise<number> {
  return db.$executeRawUnsafe(
    `WITH classees AS (
       SELECT id, row_number() OVER (
                PARTITION BY "caseId" ORDER BY "createdAt" DESC, id DESC
              ) AS rang
         FROM "CaseTimelineEvent"
        WHERE title = $1
     )
     DELETE FROM "CaseTimelineEvent" e
      USING classees c
      WHERE e.id = c.id AND c.rang > 1`,
    REASSIGNED_EVENT_TITLE,
  );
}
