/**
 * Règles d'une campagne de parrainage : seuils de comptage et d'anti-fraude,
 * prix, transitions de statut, qui peut être classé.
 *
 * Tout est pur (aucun accès base) : le calcul de qualification et les écrans
 * admin s'appuient sur les mêmes fonctions, testées seules.
 */

export type CampaignStatus = 'draft' | 'live' | 'frozen' | 'closed';

export interface QualificationRule {
  /** Le compte du filleul doit être créé PENDANT la fenêtre (décision du 17/10). */
  requireAccountCreatedInWindow: boolean;
  /** Rafale même IP : au moins N rattachements au même code en `ipBurstWindowMinutes`. */
  ipBurstThreshold: number;
  ipBurstWindowMinutes: number;
  /** Rafale même plage (/24, /48) : N rattachements au même code en M minutes. */
  ipBlockBurstThreshold: number;
  ipBlockBurstWindowMinutes: number;
  /** Rafale tous réseaux confondus : N rattachements au même code en M minutes. */
  velocityBurstThreshold: number;
  velocityBurstWindowMinutes: number;
}

export const DEFAULT_QUALIFICATION_RULE: Readonly<QualificationRule> = Object.freeze({
  requireAccountCreatedInWindow: true,
  ipBurstThreshold: 3,
  ipBurstWindowMinutes: 60,
  ipBlockBurstThreshold: 5,
  ipBlockBurstWindowMinutes: 10,
  velocityBurstThreshold: 10,
  velocityBurstWindowMinutes: 10,
});

function intIn(value: unknown, fallback: number, min: number, max: number): number {
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(n)));
}

/** JSON stocké → règle complète ; toute clé absente ou invalide prend le défaut. */
export function parseQualificationRule(raw: unknown): QualificationRule {
  const r = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const d = DEFAULT_QUALIFICATION_RULE;
  return {
    requireAccountCreatedInWindow:
      typeof r.requireAccountCreatedInWindow === 'boolean'
        ? r.requireAccountCreatedInWindow
        : d.requireAccountCreatedInWindow,
    ipBurstThreshold: intIn(r.ipBurstThreshold, d.ipBurstThreshold, 2, 1000),
    ipBurstWindowMinutes: intIn(r.ipBurstWindowMinutes, d.ipBurstWindowMinutes, 1, 1440),
    ipBlockBurstThreshold: intIn(r.ipBlockBurstThreshold, d.ipBlockBurstThreshold, 2, 1000),
    ipBlockBurstWindowMinutes: intIn(r.ipBlockBurstWindowMinutes, d.ipBlockBurstWindowMinutes, 1, 1440),
    velocityBurstThreshold: intIn(r.velocityBurstThreshold, d.velocityBurstThreshold, 2, 1000),
    velocityBurstWindowMinutes: intIn(r.velocityBurstWindowMinutes, d.velocityBurstWindowMinutes, 1, 1440),
  };
}

export interface CampaignPrize {
  rank: number;
  amountFcfa: number;
  label?: string;
}

/** Prix de la compétition de novembre 2026 (décision du propriétaire). */
export const NOVEMBER_2026_PRIZES: readonly CampaignPrize[] = Object.freeze([
  { rank: 1, amountFcfa: 100000 },
  { rank: 2, amountFcfa: 50000 },
  { rank: 3, amountFcfa: 30000 },
]);

/**
 * JSON stocké → prix triés par rang. Rejette (null) une liste incohérente :
 * rangs non entiers, doublons, trous (1, 3), montant négatif.
 */
export function parsePrizes(raw: unknown): CampaignPrize[] | null {
  if (!Array.isArray(raw)) return null;
  const out: CampaignPrize[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') return null;
    const { rank, amountFcfa, label } = item as Record<string, unknown>;
    if (!Number.isInteger(rank) || (rank as number) < 1) return null;
    if (!Number.isInteger(amountFcfa) || (amountFcfa as number) < 0) return null;
    out.push({
      rank: rank as number,
      amountFcfa: amountFcfa as number,
      ...(typeof label === 'string' && label.trim() ? { label: label.trim().slice(0, 80) } : {}),
    });
  }
  out.sort((a, b) => a.rank - b.rank);
  for (let i = 0; i < out.length; i += 1) {
    if (out[i].rank !== i + 1) return null;
  }
  return out;
}

// ── Statuts ─────────────────────────────────────────────────────────────────

export type CampaignAction = 'launch' | 'freeze' | 'unfreeze' | 'validate_podium' | 'close';

/**
 * Transitions autorisées. `unfreeze` répare un gel trop tôt, tant que le podium
 * n'est pas validé ; `close` exige un podium validé (vérifié par l'appelant).
 */
const TRANSITIONS: Record<CampaignAction, { from: CampaignStatus[]; to: CampaignStatus }> = {
  launch: { from: ['draft'], to: 'live' },
  freeze: { from: ['live'], to: 'frozen' },
  unfreeze: { from: ['frozen'], to: 'live' },
  validate_podium: { from: ['frozen'], to: 'frozen' },
  close: { from: ['frozen'], to: 'closed' },
};

export function nextStatus(current: CampaignStatus, action: CampaignAction): CampaignStatus | null {
  const t = TRANSITIONS[action];
  return t.from.includes(current) ? t.to : null;
}

/** Champs modifiables selon le statut (le reste est figé). */
export function editableFields(status: CampaignStatus): readonly string[] {
  switch (status) {
    case 'draft':
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
        'qualificationRule',
      ];
    case 'live':
    case 'frozen':
      // Changer les dates, les prix ou l'éligibilité en cours de route serait
      // changer la règle du jeu : seuls les textes restent modifiables.
      return ['nameFr', 'nameEn', 'rulesText', 'rulesUrl'];
    default:
      return [];
  }
}

/** Le public voit une campagne lancée, gelée ou close ; jamais un brouillon. */
export function isPubliclyVisible(status: CampaignStatus): boolean {
  return status !== 'draft';
}

// ── Participants ────────────────────────────────────────────────────────────

export type MinorStatus = 'adult' | 'minor' | 'unknown';
export type ParentalAuthStatus = 'not_required' | 'pending' | 'verified' | 'refused';
export type ParticipantStatus = 'active' | 'withdrawn' | 'disqualified';

export interface RankabilityInput {
  status: string;
  minorStatus: string;
  parentalAuthStatus: string;
  ambassadorApproved: boolean;
}

/**
 * Motif pour lequel un participant n'est PAS classable (ni affiché au public ni
 * primé), ou null s'il l'est. Un mineur sans autorisation parentale vérifiée,
 * un âge inconnu, un ambassadeur dont l'activation a été retirée : non classés.
 */
export function unrankableReason(p: RankabilityInput): string | null {
  if (!p.ambassadorApproved) return 'ambassador_not_approved';
  if (p.status !== 'active') return `participant_${p.status}`;
  if (p.minorStatus === 'unknown') return 'age_unknown';
  if (p.minorStatus === 'minor' && p.parentalAuthStatus !== 'verified') {
    return 'parental_authorization_missing';
  }
  return null;
}

/** Normalise une ville ou un pays pour comparer (« niamey » = « Niamey »). */
export function placeKey(value: string): string {
  return (value ?? '')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .trim()
    .toLowerCase();
}

/** Vrai si la liste est vide (pas de restriction) ou contient la valeur. */
export function isEligiblePlace(value: string, allowed: readonly string[]): boolean {
  if (allowed.length === 0) return true;
  const key = placeKey(value);
  return key !== '' && allowed.some((a) => placeKey(a) === key);
}
