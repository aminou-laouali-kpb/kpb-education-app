// Lien `Case.counsellorId` <-> nom d'affectation libre (`assignedAdvisorName`).
//
// Le lien porte l'accès d'un conseiller (portée, messagerie, pièces) et le
// destinataire de l'alerte e-mail. Règles partagées par `CasesService`
// (assign / PATCH) et par le script one-shot
// `scripts/relink-case-counsellors.ts` (audit 2026-11-22, constat 2).

import type { Prisma } from "@prisma/client";

const normalize = (value: string | null | undefined) =>
  (value ?? "").trim().toLowerCase();

/**
 * Fiche conseiller correspondant au nom saisi à l'affectation (l'admin envoie
 * un nom libre, pas un identifiant) : par le nom de la fiche ou par celui du
 * compte admin lié, sans tenir compte de la casse. En cas d'homonymes, on
 * garde la seule fiche active ; sinon (aucune ou ambiguë) `null`.
 */
export async function resolveCounsellorIdForAdvisorName(
  tx: Prisma.TransactionClient,
  advisorName: string,
): Promise<string | null> {
  const name = advisorName.trim();
  if (!name) return null;
  const equals = { equals: name, mode: "insensitive" as const };
  const matches = await tx.counsellor.findMany({
    where: { OR: [{ fullName: equals }, { adminUser: { fullName: equals } }] },
    select: { id: true, isActive: true },
    orderBy: { createdAt: "asc" },
  });
  if (matches.length === 1) return matches[0].id;
  const active = matches.filter((c) => c.isActive);
  return active.length === 1 ? active[0].id : null;
}

/**
 * Vrai si le nom envoyé désigne réellement un autre conseiller que le nom
 * actuel du dossier (comparaison `trim` + insensible à la casse).
 */
export function isAdvisorNameChange(
  currentName: string | null | undefined,
  nextName: string,
): boolean {
  return normalize(currentName) !== normalize(nextName);
}

/**
 * Cas « même nom renvoyé » : faut-il corriger le lien existant ?
 *
 * Trou relevé en revue : un dossier réaffecté AVANT le correctif est en base
 * avec `assignedAdvisorName = 'Awa Koné'` et `counsellorId = Jojo`. Réaffecter
 * « à Awa » ne change pas le nom, donc le lien vers Jojo restait (accès et
 * alertes). Même chose pour un dossier `counsellorId = null` dont la fiche a
 * été créée depuis.
 *
 * Arbitrage retenu (ne rien casser chez un conseiller légitime) :
 *  - le conseiller lié porte encore ce nom (fiche OU compte admin lié, `trim`
 *    + casse ignorée) : on ne touche à rien ;
 *  - sinon (ou lien nul), on relance la résolution par nom, et on relie le
 *    dossier SEULEMENT si elle trouve, sans ambiguïté, une AUTRE fiche ;
 *  - résolution vide ou ambiguë : on ne change rien. Une fiche renommée
 *    (« Awa Kone » -> « Awa Koné », la comparaison n'ignore pas les accents)
 *    ne se distingue pas d'un ancien conseiller resté lié : couper le lien
 *    priverait Awa de son dossier, donc on le conserve.
 *
 * Renvoie le nouvel identifiant à écrire, ou `undefined` pour « ne rien
 * changer ».
 */
export async function relinkedCounsellorIdForSameName(
  tx: Prisma.TransactionClient,
  currentCounsellorId: string | null | undefined,
  advisorName: string,
): Promise<string | undefined> {
  if (
    currentCounsellorId &&
    (await linkedCounsellorBearsName(tx, currentCounsellorId, advisorName))
  ) {
    return undefined;
  }
  const resolved = await resolveCounsellorIdForAdvisorName(tx, advisorName);
  return resolved && resolved !== currentCounsellorId ? resolved : undefined;
}

/**
 * Vrai si la fiche liée porte ce nom (sur la fiche OU sur le compte admin
 * lié, `trim` + casse ignorée). Faux si la fiche n'existe plus.
 */
export async function linkedCounsellorBearsName(
  tx: Prisma.TransactionClient,
  counsellorId: string,
  advisorName: string,
): Promise<boolean> {
  const linked = await tx.counsellor.findUnique({
    where: { id: counsellorId },
    select: { fullName: true, adminUser: { select: { fullName: true } } },
  });
  const name = normalize(advisorName);
  return (
    !!linked &&
    (normalize(linked.fullName) === name ||
      normalize(linked.adminUser?.fullName) === name)
  );
}

/**
 * Valeur de `counsellorId` à écrire pour une affectation à `nextName`, ou
 * `undefined` pour laisser le lien tel quel.
 *  - nouveau nom : résolution ; `null` si aucune fiche ou ambiguë, pour ne
 *    jamais laisser l'ancien conseiller lié (il garde sinon accès et alertes) ;
 *  - même nom : voir `relinkedCounsellorIdForSameName`.
 */
export async function counsellorIdForAssignment(
  tx: Prisma.TransactionClient,
  current: { assignedAdvisorName: string | null; counsellorId: string | null },
  nextName: string,
): Promise<string | null | undefined> {
  if (isAdvisorNameChange(current.assignedAdvisorName, nextName)) {
    return resolveCounsellorIdForAdvisorName(tx, nextName);
  }
  return relinkedCounsellorIdForSameName(tx, current.counsellorId, nextName);
}
