/**
 * Réattribution d'un prix déclaré forfait (correctifs 57) — calcul pur.
 *
 * Règlement (décisions du propriétaire du 18/10/2026) : un lauréat injoignable
 * ou sans informations de versement 15 jours après la validation perd son prix,
 * qui PASSE AU SUIVANT du classement. Jusqu'ici le seul moyen était de retirer
 * le lauréat puis de revalider le podium, ce que le serveur refuse dès qu'un
 * premier versement est noté (« podium figé »).
 *
 * Règle appliquée, rang de prix par rang de prix :
 *  - un prix DÉJÀ VERSÉ ne bouge jamais, et son titulaire n'est plus candidat ;
 *  - un prix non versé d'un rang PLUS PETIT que le rang perdu ne bouge pas ;
 *  - les prix non versés à partir du rang perdu sont redistribués, dans
 *    l'ordre, aux participants CLASSÉS (rang non nul) qui ne tiennent aucun des
 *    prix gardés et n'ont jamais été déclarés forfait — c'est le même
 *    « décalage » que la revalidation (le 3e monte au 2e prix, le 4e entre au
 *    3e prix…), sans toucher aux versements ;
 *  - plus de candidat : le prix reste non attribué (`null`).
 *
 * Le classement lui-même (ordre réel, rangs) ne change pas : seule
 * l'attribution des prix est décalée.
 */

export interface PrizeSlot {
  /** Rang du PRIX (1, 2, 3…). */
  rank: number;
  /** Titulaire actuel, ou `null` (prix non attribué). */
  participantId: string | null;
  paid: boolean;
}

export interface RankedParticipant {
  id: string;
  /** Rang au classement (jamais nul ici : seuls les classés sont candidats). */
  rank: number;
}

export interface PrizeAssignment {
  rank: number;
  participantId: string | null;
}

/**
 * Les nouveaux titulaires des prix touchés par le forfait du prix
 * [forfeitRank]. Ne rend QUE les rangs de prix ≥ [forfeitRank] non versés ;
 * tout autre prix est inchangé par construction.
 *
 * [forfeited] : tous les participants déjà déclarés forfait dans la campagne,
 * y compris celui de ce forfait.
 */
export function reassignAfterForfeit(
  slots: readonly PrizeSlot[],
  forfeitRank: number,
  forfeited: ReadonlySet<string>,
  ranked: readonly RankedParticipant[],
): PrizeAssignment[] {
  const kept = slots.filter((s) => s.paid || s.rank < forfeitRank);
  const keptHolders = new Set(
    kept.map((s) => s.participantId).filter((id): id is string => id !== null),
  );
  const targets = slots
    .filter((s) => !s.paid && s.rank >= forfeitRank)
    .sort((a, b) => a.rank - b.rank);
  const candidates = [...ranked]
    .sort((a, b) => a.rank - b.rank || a.id.localeCompare(b.id))
    .filter((p) => !forfeited.has(p.id) && !keptHolders.has(p.id));
  return targets.map((slot, i) => ({
    rank: slot.rank,
    participantId: candidates[i]?.id ?? null,
  }));
}

/**
 * Le podium d'une (re)validation : un prix par rang, aux classés dans l'ordre,
 * en sautant les participants déclarés forfait. Sans forfait, c'est exactement
 * l'ancienne règle (le rang N reçoit le prix N).
 */
export function podiumAssignments(
  prizeRanks: readonly number[],
  forfeited: ReadonlySet<string>,
  ranked: readonly RankedParticipant[],
): PrizeAssignment[] {
  const candidates = [...ranked]
    .sort((a, b) => a.rank - b.rank || a.id.localeCompare(b.id))
    .filter((p) => !forfeited.has(p.id));
  return [...prizeRanks]
    .sort((a, b) => a - b)
    .map((rank, i) => ({ rank, participantId: candidates[i]?.id ?? null }));
}
