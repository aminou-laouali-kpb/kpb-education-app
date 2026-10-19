/**
 * Finalité d'une campagne de notifications (correctifs 57, XC-06) — miroir de
 * `backend/src/modules/notifications/campaign-purpose.ts`.
 *
 * `promotional` est le DÉFAUT du formulaire, comme côté serveur : un texte
 * libre est réputé promotionnel tant que l'équipe ne dit pas le contraire.
 * Promotionnel ⇒ e-mail seulement aux comptes qui ont consenti, push jamais
 * vers ceux qui ont coupé « Nouvelles et offres de KPB ».
 */
export const CAMPAIGN_PURPOSES = ['promotional', 'informational'] as const;
export type CampaignPurpose = (typeof CAMPAIGN_PURPOSES)[number];
export const DEFAULT_CAMPAIGN_PURPOSE: CampaignPurpose = 'promotional';

export type CampaignChannelBlock =
  | 'push_opted_out'
  | 'email_no_consent'
  | 'email_minor_without_guardian';

export interface CampaignChannelCount {
  channel: string;
  eligible: number;
  blocked: Partial<Record<CampaignChannelBlock, number>>;
}

/** Réponse de `POST /admin/notifications/campaigns/preview`. */
export interface CampaignAudiencePreview {
  audienceType: string;
  filterMissing: boolean;
  filterInvalid: string | null;
  recipients: number;
  byLanguage: { fr: number; en: number };
  /** Absent d'un serveur antérieur aux correctifs 57. */
  purpose?: CampaignPurpose;
  reachable?: number;
  byChannel?: CampaignChannelCount[];
  excludedCountries?: string[];
  excludedRecipients?: number;
}

/** Le corps de l'aperçu : mêmes champs que la création. */
export function previewBody(input: {
  audienceType: string;
  filters: unknown;
  channels: string[];
  purpose: CampaignPurpose;
}) {
  return {
    audienceType: input.audienceType,
    filters: input.filters,
    channels: input.channels.length > 0 ? input.channels : ['push'],
    purpose: input.purpose,
  };
}

const BLOCK_ORDER: CampaignChannelBlock[] = [
  'push_opted_out',
  'email_no_consent',
  'email_minor_without_guardian',
];

/**
 * « email : 120 (filtrés : 40 sans consentement, 3 mineurs sans accord) ».
 * [labels] donne le libellé de chaque motif dans la langue de l'admin.
 */
export function channelCountLine(
  count: CampaignChannelCount,
  labels: Record<CampaignChannelBlock, string>,
  filteredWord: string,
): string {
  const blocked = BLOCK_ORDER.filter((k) => (count.blocked[k] ?? 0) > 0).map(
    (k) => `${count.blocked[k]} ${labels[k]}`,
  );
  return blocked.length > 0
    ? `${count.channel} : ${count.eligible} (${filteredWord} : ${blocked.join(', ')})`
    : `${count.channel} : ${count.eligible}`;
}
