// Rattrapage des dates de naissance enregistrées avant le correctif T4-06
// (audit de la 57, 07/11/2026) : le serveur lisait le minuit local envoyé par
// l'app dans son propre fuseau (Africa/Niamey, UTC+1) et gardait 23:00Z la
// veille. L'app affichait donc la veille.
//
// Même règle que `birthDateAtUtcMidnight` : on ramène chaque valeur au minuit
// UTC le plus proche. Une valeur déjà à minuit ne bouge pas ; la condition est
// portée par l'UPDATE lui-même. Rejouable : 0 la seconde fois.

export type Executeur = {
  $queryRawUnsafe<T = unknown>(query: string, ...values: unknown[]): Promise<T>;
  $executeRawUnsafe(query: string, ...values: unknown[]): Promise<number>;
};

const HORS_MINUIT = `"birthDate" IS NOT NULL AND "birthDate"::time <> '00:00:00'`;

/** Nombre de dates hors minuit UTC, par heure (pour lire la simulation). */
export async function releverHeures(
  db: Executeur,
): Promise<{ heure: string; n: number }[]> {
  const rows = await db.$queryRawUnsafe<{ heure: string; n: bigint }[]>(
    `SELECT to_char("birthDate", 'HH24:MI:SS') AS heure, count(*)::bigint AS n
       FROM "UserProfile" WHERE ${HORS_MINUIT}
      GROUP BY 1 ORDER BY 2 DESC`,
  );
  return rows.map((r) => ({ heure: r.heure, n: Number(r.n) }));
}

export async function ramenerAMinuit(db: Executeur): Promise<number> {
  return db.$executeRawUnsafe(
    `UPDATE "UserProfile"
        SET "birthDate" = date_trunc('day', "birthDate" + interval '12 hours')
      WHERE ${HORS_MINUIT}`,
  );
}
