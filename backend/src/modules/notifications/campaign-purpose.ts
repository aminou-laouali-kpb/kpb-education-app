import type { NotificationOptOutType } from '../../common/notification-types';

/**
 * Finalité d'une campagne de l'admin, et ce qu'elle permet d'envoyer à qui
 * (correctifs 57, XC-06).
 *
 * ── Pourquoi ──────────────────────────────────────────────────────────────
 *
 * Le propriétaire a décidé le 18/10/2026 de ne pas déclarer de finalité
 * « Marketing » aux stores, SOUS RÉSERVE qu'aucun envoi promotionnel ne parte
 * sans consentement. Or `CampaignExecutorService` envoyait un modèle libre en
 * push et par e-mail à des audiences larges (`all_users`, pays…) sans aucun
 * filtre. Ce fichier est la règle unique, appliquée à l'aperçu ET à l'envoi :
 *
 * - `informational` (message de service : maintenance, changement des
 *   conditions, rappel lié au compte) : aucun filtre de plus qu'avant. Les
 *   familles récurrentes ont leurs propres clés de désinscription ; une
 *   campagne de service n'en est pas une.
 * - `promotional` (offre, mise en avant, annonce marketing) — le DÉFAUT, y
 *   compris pour une valeur absente ou illisible :
 *   - **e-mail** : seulement si le compte a coché « Recevoir par e-mail les
 *     nouvelles et offres de KPB » (`promotionsEmailOptIn`, défaut NON) ; un
 *     mineur déclaré (date de naissance connue, moins de 18 ans) doit EN PLUS
 *     avoir l'accord de son représentant légal (`guardianConsentedAt`), la
 *     même porte que le coach IA ; chaque e-mail porte un lien de
 *     désinscription (voir `promotions-unsubscribe.ts`) ;
 *   - **push** : jamais vers un compte qui a coupé `kpb_promotions`
 *     (Notifications → préférences, dans l'app).
 *
 * La classification reste un choix humain fait dans l'admin : le code garantit
 * le filtre d'une campagne marquée promotionnelle, et le défaut prudent, pas
 * l'honnêteté du choix.
 */

export const CAMPAIGN_PURPOSES = ['informational', 'promotional'] as const;
export type CampaignPurpose = (typeof CAMPAIGN_PURPOSES)[number];

/** Défaut prudent : une campagne en texte libre est réputée promotionnelle. */
export const DEFAULT_CAMPAIGN_PURPOSE: CampaignPurpose = 'promotional';

/** La clé de désinscription des push promotionnels (`disabledNotificationTypes`). */
export const PROMOTIONS_OPT_OUT: NotificationOptOutType = 'kpb_promotions';

/** Âge en dessous duquel un compte est mineur. */
const MAJORITY_AGE = 18;

/** Une valeur absente, inconnue ou mal écrite vaut `promotional`. */
export function parseCampaignPurpose(value: unknown): CampaignPurpose {
  return value === 'informational' ? 'informational' : 'promotional';
}

/** Les champs du profil que la règle lit. */
export interface CampaignConsentFields {
  email?: string | null;
  disabledNotificationTypes?: readonly string[] | null;
  promotionsEmailOptIn?: boolean | null;
  birthDate?: Date | null;
  guardianConsentedAt?: Date | null;
}

export type CampaignChannelBlock =
  | 'push_opted_out'
  | 'email_no_consent'
  | 'email_minor_without_guardian';

/** Moins de 18 ans à `now`, date de naissance CONNUE. Inconnue ⇒ `false`. */
export function isDeclaredMinor(birthDate: Date | null | undefined, now: Date): boolean {
  if (!birthDate || Number.isNaN(birthDate.getTime())) return false;
  const majority = new Date(birthDate.getTime());
  majority.setUTCFullYear(majority.getUTCFullYear() + MAJORITY_AGE);
  return majority.getTime() > now.getTime();
}

/**
 * Pourquoi ce canal est fermé à ce compte pour cette finalité, ou `null` s'il
 * est ouvert. `in_app` n'a pas de chemin d'envoi (l'exécuteur le marque en
 * échec) : il n'est donc jamais filtré ici.
 */
export function campaignChannelBlock(
  purpose: CampaignPurpose,
  channel: string,
  recipient: CampaignConsentFields,
  now: Date,
): CampaignChannelBlock | null {
  if (purpose !== 'promotional') return null;
  if (channel === 'push') {
    return (recipient.disabledNotificationTypes ?? []).includes(PROMOTIONS_OPT_OUT)
      ? 'push_opted_out'
      : null;
  }
  if (channel === 'email') {
    if (recipient.promotionsEmailOptIn !== true) return 'email_no_consent';
    if (isDeclaredMinor(recipient.birthDate, now) && !recipient.guardianConsentedAt) {
      return 'email_minor_without_guardian';
    }
    return null;
  }
  return null;
}

/** Combien de comptes chaque canal toucherait réellement, et combien sont filtrés. */
export interface CampaignChannelCount {
  channel: string;
  eligible: number;
  blocked: Partial<Record<CampaignChannelBlock, number>>;
}

export function countCampaignChannels(
  purpose: CampaignPurpose,
  channels: readonly string[],
  recipients: readonly CampaignConsentFields[],
  now: Date,
): CampaignChannelCount[] {
  return channels.map((channel) => {
    const blocked: Partial<Record<CampaignChannelBlock, number>> = {};
    let eligible = 0;
    for (const recipient of recipients) {
      const block = campaignChannelBlock(purpose, channel, recipient, now);
      if (block) blocked[block] = (blocked[block] ?? 0) + 1;
      else eligible += 1;
    }
    return { channel, eligible, blocked };
  });
}
