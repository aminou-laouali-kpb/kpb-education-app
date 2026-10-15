// ─────────────────────────────────────────────────────────────────────────────
// L'état « suivre » d'un couple (étudiant, bourse), côté API étudiant.
//
//   suit                 = un favori OU une alerte « M'avertir » non mise en
//                          sourdine ;
//   annonce d'ouverture  = suit ET aucune sourdine — la sourdine prime sur le
//                          favori.
//
// C'est la définition de `opening/scholarship-follow.query.ts`, écrite pour
// des lignes déjà lues. La fiche (`follow`), la réponse du PATCH et la liste
// des bourses suivies passent toutes par `followFlags` : un même couple ne
// peut pas être « suivi » sur un écran et « non suivi » sur l'autre.
//
// `notifyOpening` est la PRÉFÉRENCE de l'étudiant, pas la promesse d'un envoi :
// tant que le mode n'est pas `outbox_followers`, un favori seul n'est pas
// prévenu (portée `alerts`), mais rien n'est à couper de son côté.
// ─────────────────────────────────────────────────────────────────────────────

import {
  audienceScopeForMode,
  FOLLOWED_SCHOLARSHIP_OPT_OUT,
  readScholarshipOpeningMode,
  type OpeningEnv,
  type ScholarshipFollowState,
} from './opening/scholarship-opening.contract';

/** `SavedItem.itemType` d'un favori de bourse. */
export const SCHOLARSHIP_SAVED_ITEM_TYPE = 'scholarship';

/**
 * Ce qu'il faut savoir d'un couple pour dire s'il est suivi — les colonnes
 * `viaFavorite` / `viaAlert` / `muted` des requêtes partagées, ou
 * `alertFacts(ligne Prisma)`.
 */
export interface FollowFacts {
  /** Un favori de cette bourse existe. */
  favorite: boolean;
  /** Une alerte non mise en sourdine existe. */
  activeAlert: boolean;
  /** Une alerte en sourdine existe. */
  mutedAlert: boolean;
}

export type FollowFlags = Omit<ScholarshipFollowState, 'globalOptOut'>;

export function followFlags(facts: FollowFacts): FollowFlags {
  const following = facts.favorite || facts.activeAlert;
  return {
    following,
    viaFavorite: facts.favorite,
    viaAlert: facts.activeAlert,
    notifyOpening: following && !facts.mutedAlert,
  };
}

/** Les faits d'alerte d'une ligne `ScholarshipAlertSubscription` lue (ou absente). */
export function alertFacts(
  alert: { mutedAt: Date | null } | null,
): Pick<FollowFacts, 'activeAlert' | 'mutedAlert'> {
  return {
    activeAlert: alert !== null && alert.mutedAt === null,
    mutedAlert: alert !== null && alert.mutedAt !== null,
  };
}

/**
 * La désinscription globale des annonces d'ouverture. Elle coupe le push
 * seulement (l'entrée d'inbox reste écrite) et jamais les rappels de date
 * limite.
 */
export function hasFollowedScholarshipOptOut(
  disabledNotificationTypes: readonly string[] | null | undefined,
): boolean {
  return (disabledNotificationTypes ?? []).includes(FOLLOWED_SCHOLARSHIP_OPT_OUT);
}

/**
 * Vrai en `outbox_followers` : la cloche pose aussi le favori, et retirer le
 * favori retire l'alerte (« Suivre » = un seul geste). Dans les autres modes,
 * seules les règles de sourdine s'appliquent — elles sont en service dès le
 * déploiement, pour qu'une « cloche coupée sur un favori » d'avant la bascule
 * soit encore respectée après.
 */
export function isFollowUnified(env: OpeningEnv = process.env): boolean {
  return audienceScopeForMode(readScholarshipOpeningMode(env)) === 'followers';
}
