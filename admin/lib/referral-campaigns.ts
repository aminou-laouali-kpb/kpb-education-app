/**
 * Compétition ambassadeurs — types, règles d'affichage et appels de la console.
 *
 * Miroir de `backend/src/modules/referrals/campaigns/` (contrats :
 * `docs/api-contracts.md`, section « Compétition ambassadeurs »). Les règles
 * dupliquées ici (actions possibles par statut, champs modifiables) ne servent
 * qu'à griser des boutons : le serveur refuse de toute façon.
 */
import { apiFetch, apiFetchText } from './api-client';

export type CampaignStatus = 'draft' | 'live' | 'frozen' | 'closed';
export type CampaignAction = 'launch' | 'freeze' | 'unfreeze' | 'validate_podium' | 'close';
export type ReferralStatus = 'pending' | 'qualified' | 'flagged' | 'excluded';

export interface CampaignPrize {
  rank: number;
  amountFcfa: number;
  label?: string;
}

export interface Campaign {
  id: string;
  slug: string;
  nameFr: string;
  nameEn: string;
  timeZone: string;
  startDate: string;
  endDate: string;
  startsAt: string;
  endsAt: string;
  status: CampaignStatus;
  prizes: CampaignPrize[];
  rulesText: string | null;
  rulesUrl: string | null;
  eligibleCities: string[];
  eligibleCountries: string[];
  lastComputedAt: string | null;
  frozenAt: string | null;
  podiumValidatedAt: string | null;
  closedAt: string | null;
  publicPath: string;
  counts?: { participants: number; referrals: number };
}

export interface LeaderboardItem {
  id: string;
  ambassadorId: string;
  ambassadorCode: string;
  personalCode: string | null;
  fullName: string;
  email: string;
  publicName: string;
  displayName: string;
  city: string;
  country: string;
  status: 'active' | 'withdrawn' | 'disqualified';
  statusReason: string | null;
  minorStatus: 'adult' | 'minor' | 'unknown';
  parentalAuthStatus: 'not_required' | 'pending' | 'verified' | 'refused';
  parentalAuthVerifiedAt: string | null;
  parentalAuthNote: string | null;
  qualifiedCount: number;
  flaggedCount: number;
  pendingCount: number;
  excludedCount: number;
  reachedCountAt: string | null;
  rank: number | null;
  unrankableReason: string | null;
}

export interface Leaderboard {
  campaign: Campaign;
  cities: string[];
  countries: string[];
  items: LeaderboardItem[];
}

export interface CampaignReferralRow {
  id: string;
  refereeName: string;
  refereeEmail: string;
  attachedAt: string;
  accountCreatedAt: string;
  profileCompletedAt: string | null;
  qualifiedAt: string | null;
  status: ReferralStatus;
  flags: string[];
  adminDecision: 'validated' | 'excluded' | null;
  adminDecisionReason: string | null;
}

export interface PrizeAward {
  id: string;
  rank: number;
  /** Lauréat actuel (null : compte disparu). */
  participantId: string | null;
  publicNameSnapshot: string;
  amountFcfa: number;
  recipient: 'ambassador' | 'parent';
  payoutStatus: 'pending' | 'paid';
  payoutMethod: string;
  payoutReference: string | null;
  paidAmountFcfa: number | null;
  paidAt: string | null;
  paidByAdminId: string | null;
}

/** Un prix déclaré forfait (correctifs 57) : trace du lauréat qui l'a perdu. */
export interface PrizeForfeit {
  id: string;
  rank: number;
  participantId: string | null;
  publicNameSnapshot: string;
  amountFcfa: number;
  reason: string;
  forfeitedAt: string;
  forfeitedByAdminId: string;
  /** Qui tient ce prix après la réattribution (null : non réattribué). */
  replacedByParticipantId: string | null;
}

/**
 * « Déclarer le prix forfait et réattribuer » n'a de sens que pour un prix
 * attribué et NON versé : le serveur refuse le reste (409), l'écran ne le
 * propose pas.
 */
export function canForfeit(award: Pick<PrizeAward, 'payoutStatus' | 'participantId'>): boolean {
  return award.payoutStatus !== 'paid' && award.participantId !== null;
}

export interface AmbassadorRow {
  id: string;
  code: string;
  personalCode: string | null;
  displayName: string;
  city: string;
  fullName: string;
  email: string;
  minorStatus: 'adult' | 'minor' | 'unknown';
  approvedAt: string | null;
  cashProgramEnabled: boolean;
}

// ── Règles d'affichage ──────────────────────────────────────────────────────

const ACTIONS: Record<CampaignStatus, CampaignAction[]> = {
  draft: ['launch'],
  live: ['freeze'],
  frozen: ['unfreeze', 'validate_podium', 'close'],
  closed: [],
};

/** Actions proposées pour un statut (le podium et la clôture ont leurs gardes). */
export function availableActions(campaign: Pick<Campaign, 'status' | 'podiumValidatedAt'>): CampaignAction[] {
  return ACTIONS[campaign.status].filter((action) => {
    if (action === 'close') return Boolean(campaign.podiumValidatedAt);
    if (action === 'unfreeze') return !campaign.podiumValidatedAt;
    return true;
  });
}

/** Champs modifiables (miroir de `editableFields` côté serveur). */
export function editableFields(status: CampaignStatus): readonly string[] {
  if (status === 'draft') {
    return [
      'nameFr',
      'nameEn',
      'startDate',
      'endDate',
      'timeZone',
      'prizes',
      'rulesText',
      'rulesUrl',
      'eligibleCities',
      'eligibleCountries',
    ];
  }
  if (status === 'live' || status === 'frozen') return ['nameFr', 'nameEn', 'rulesText', 'rulesUrl'];
  return [];
}

export const STATUS_VARIANT: Record<CampaignStatus, 'neutral' | 'success' | 'warning' | 'info'> = {
  draft: 'neutral',
  live: 'success',
  frozen: 'warning',
  closed: 'info',
};

export const REFERRAL_VARIANT: Record<ReferralStatus, 'neutral' | 'success' | 'warning' | 'danger'> = {
  pending: 'neutral',
  qualified: 'success',
  flagged: 'warning',
  excluded: 'danger',
};

export const REFERRAL_FLAGS = [
  'disposable_email',
  'device_duplicate',
  'ip_burst',
  'ip_block_burst',
  'velocity_burst',
  'referee_is_participant',
] as const;

export const UNRANKABLE_REASONS = [
  'ambassador_not_approved',
  'participant_withdrawn',
  'participant_disqualified',
  'age_unknown',
  'parental_authorization_missing',
] as const;

/**
 * « 100000, 50000, 30000 » → prix rangés 1, 2, 3. Null si une valeur n'est pas
 * un entier positif ou nul.
 */
export function parsePrizeAmounts(text: string): CampaignPrize[] | null {
  const parts = text
    .split(/[,;\n]/)
    .map((p) => p.replace(/[\s .]/g, ''))
    .filter(Boolean);
  if (parts.length === 0) return [];
  const out: CampaignPrize[] = [];
  for (const [i, part] of parts.entries()) {
    if (!/^\d+$/.test(part)) return null;
    out.push({ rank: i + 1, amountFcfa: Number(part) });
  }
  return out;
}

export function prizeAmountsText(prizes: readonly CampaignPrize[]): string {
  return prizes.map((p) => String(p.amountFcfa)).join(', ');
}

/** « Maradi, Niamey ; Cotonou » → liste sans doublon ni vide. */
export function parseList(text: string): string[] {
  return [
    ...new Set(
      text
        .split(/[,;\n]/)
        .map((p) => p.trim())
        .filter(Boolean),
    ),
  ];
}

export function formatFcfa(amount: number, locale: 'fr' | 'en' = 'fr'): string {
  return `${new Intl.NumberFormat(locale === 'fr' ? 'fr-FR' : 'en-GB').format(amount)} FCFA`;
}

/** Lien public du classement (site statique kpbeducation.cloud). */
export function publicLeaderboardUrl(slug: string, origin = 'https://kpbeducation.cloud'): string {
  return `${origin}/classement/?c=${encodeURIComponent(slug)}`;
}

/** Lien d'invitation d'un ambassadeur (page qui affiche et copie le code). */
export function inviteUrl(code: string, origin = 'https://kpbeducation.cloud'): string {
  return `${origin}/invite.html?ref=${encodeURIComponent(code)}`;
}

export interface CampaignFormInput {
  slug: string;
  nameFr: string;
  nameEn: string;
  startDate: string;
  endDate: string;
  timeZone: string;
  prizesText: string;
  rulesText: string;
  rulesUrl: string;
  citiesText: string;
  countriesText: string;
}

/** Valeurs par défaut du formulaire : la compétition de novembre 2026. */
export const NOVEMBER_2026_DEFAULTS: CampaignFormInput = {
  slug: 'ambassadeurs-novembre-2026',
  nameFr: 'Compétition ambassadeurs — novembre 2026',
  nameEn: 'Ambassador challenge — November 2026',
  startDate: '2026-11-01',
  endDate: '2026-11-10',
  timeZone: 'Africa/Lagos',
  prizesText: '100000, 50000, 30000',
  rulesText: '',
  rulesUrl: '',
  citiesText: 'Maradi, Niamey, Cotonou, Abidjan, Douala',
  countriesText: '',
};

/** Erreurs de saisie (clés de messages `parrainage.form.*`), ou corps prêt à l'envoi. */
export function buildCampaignPayload(
  input: CampaignFormInput,
): { ok: true; body: Record<string, unknown> } | { ok: false; errors: Record<string, string> } {
  const errors: Record<string, string> = {};
  if (!/^[a-z0-9][a-z0-9-]{2,60}$/.test(input.slug.trim())) errors.slug = 'errorSlug';
  if (!input.nameFr.trim()) errors.nameFr = 'errorRequired';
  if (!input.nameEn.trim()) errors.nameEn = 'errorRequired';
  const date = /^\d{4}-\d{2}-\d{2}$/;
  if (!date.test(input.startDate)) errors.startDate = 'errorDate';
  if (!date.test(input.endDate)) errors.endDate = 'errorDate';
  if (!errors.startDate && !errors.endDate && input.endDate < input.startDate) errors.endDate = 'errorDateOrder';
  const prizes = parsePrizeAmounts(input.prizesText);
  if (!prizes) errors.prizesText = 'errorPrizes';
  const url = input.rulesUrl.trim();
  if (url && !/^https:\/\/\S+$/.test(url)) errors.rulesUrl = 'errorUrl';
  if (Object.keys(errors).length) return { ok: false, errors };
  return {
    ok: true,
    body: {
      slug: input.slug.trim(),
      nameFr: input.nameFr.trim(),
      nameEn: input.nameEn.trim(),
      startDate: input.startDate,
      endDate: input.endDate,
      timeZone: input.timeZone.trim() || 'Africa/Lagos',
      prizes,
      ...(input.rulesText.trim() ? { rulesText: input.rulesText.trim() } : {}),
      ...(url ? { rulesUrl: url } : {}),
      eligibleCities: parseList(input.citiesText),
      eligibleCountries: parseList(input.countriesText),
    },
  };
}

// ── Appels ──────────────────────────────────────────────────────────────────

const BASE = '/admin/referral-campaigns';

export const campaignsApi = {
  list: () => apiFetch<{ items: Campaign[] }>(BASE),
  get: (id: string) => apiFetch<Campaign>(`${BASE}/${id}`),
  create: (body: Record<string, unknown>) => apiFetch<Campaign>(BASE, { method: 'POST', body }),
  update: (id: string, body: Record<string, unknown>) =>
    apiFetch<Campaign>(`${BASE}/${id}`, { method: 'PATCH', body }),
  transition: (id: string, action: CampaignAction) =>
    apiFetch<Campaign>(`${BASE}/${id}/transition`, { method: 'POST', body: { action } }),
  recompute: (id: string) =>
    apiFetch<{ created: number; updated: number; deleted: number; unchanged: number }>(
      `${BASE}/${id}/recompute`,
      { method: 'POST' },
    ),
  leaderboard: (id: string, filters: { city?: string; country?: string } = {}) => {
    const q = new URLSearchParams();
    if (filters.city) q.set('city', filters.city);
    if (filters.country) q.set('country', filters.country);
    const qs = q.toString();
    return apiFetch<Leaderboard>(`${BASE}/${id}/leaderboard${qs ? `?${qs}` : ''}`);
  },
  enroll: (id: string, body: Record<string, unknown>) =>
    apiFetch(`${BASE}/${id}/participants`, { method: 'POST', body }),
  updateParticipant: (id: string, participantId: string, body: Record<string, unknown>) =>
    apiFetch(`${BASE}/${id}/participants/${participantId}`, { method: 'PATCH', body }),
  referrals: (id: string, participantId: string) =>
    apiFetch<{ items: CampaignReferralRow[] }>(`${BASE}/${id}/participants/${participantId}/referrals`),
  decide: (id: string, referralId: string, decision: 'validated' | 'excluded' | 'clear', reason?: string) =>
    apiFetch(`${BASE}/${id}/referrals/${referralId}/decision`, {
      method: 'POST',
      body: { decision, ...(reason ? { reason } : {}) },
    }),
  prizes: (id: string) =>
    apiFetch<{ items: PrizeAward[]; forfeits?: PrizeForfeit[] }>(`${BASE}/${id}/prizes`),
  forfeit: (id: string, rank: number, body: { participantId: string; reason: string }) =>
    apiFetch<{ items: PrizeAward[]; forfeits: PrizeForfeit[] }>(`${BASE}/${id}/prizes/${rank}/forfeit`, {
      method: 'POST',
      body,
    }),
  payout: (id: string, rank: number, body: Record<string, unknown>) =>
    apiFetch<PrizeAward>(`${BASE}/${id}/prizes/${rank}/payout`, { method: 'POST', body }),
  exportCsv: (id: string, scope: 'leaderboard' | 'referrals') =>
    apiFetchText(`${BASE}/${id}/export.csv?scope=${scope}`),
};

export const ambassadorsApi = {
  list: (search?: string) =>
    apiFetch<{ items: AmbassadorRow[] }>(
      `/admin/ambassadors${search ? `?search=${encodeURIComponent(search)}` : ''}`,
    ),
  activate: (body: { email: string; city: string; displayName?: string }) =>
    apiFetch<AmbassadorRow>('/admin/ambassadors', { method: 'POST', body }),
  revoke: (id: string, reason: string) =>
    apiFetch(`/admin/ambassadors/${id}/revoke`, { method: 'POST', body: { reason } }),
};
