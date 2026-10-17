import { isDisposableEmail } from './disposable-email-domains';
import { type QualificationRule, unrankableReason } from './campaign-rules';
import { type CampaignWindow, isWithinWindow } from './campaign-time';
import {
  type CompletionProfile,
  isEmailVerified,
  isProfileComplete,
} from './profile-completion';

/**
 * Le calcul de qualification d'une campagne — PUR et rejouable.
 *
 * Même entrée → même sortie (à l'instant `now` près, qui ne sert qu'à dater
 * une complétion jamais observée). Le service le relance toutes les 5 minutes
 * et à la demande ; il n'écrit que les différences.
 *
 * Un filleul est QUALIFIÉ à l'instant où les trois conditions de la décision
 * du 17/10/2026 sont réunies — compte créé (et, par défaut, créé dans la
 * fenêtre), e-mail vérifié, profil complété — à condition que son rattachement
 * au code (la ligne `Referral`) date de la fenêtre :
 *
 *   qualifiedAt = max(rattachement, création du compte, complétion du profil)
 *
 * et que cet instant tombe AVANT la fin de la fenêtre. Un signal automatique
 * (rafale, appareil déjà vu, e-mail jetable…) ne supprime rien : la ligne passe
 * « à vérifier » (`flagged`) et ne compte pas tant que l'équipe ne l'a pas
 * validée. Une exclusion par l'équipe l'emporte sur tout.
 */

export type ReferralStatus = 'pending' | 'qualified' | 'flagged' | 'excluded';

export type ReferralFlag =
  | 'disposable_email'
  | 'device_duplicate'
  | 'ip_burst'
  | 'ip_block_burst'
  | 'velocity_burst'
  | 'referee_is_participant';

export interface QualificationParticipant {
  id: string;
  profileId: string;
  status: string;
  minorStatus: string;
  parentalAuthStatus: string;
  ambassadorApproved: boolean;
  enrolledAt: Date;
}

export interface QualificationAttribution {
  refereeProfileId: string;
  referrerProfileId: string;
  attachedAt: Date;
}

export interface QualificationReferee extends CompletionProfile {
  id: string;
  email: string;
  supabaseUserId: string | null;
  createdAt: Date;
  profileCompletedAt: Date | null;
}

export interface QualificationSignal {
  ipHash: string | null;
  ipBlockHash: string | null;
  deviceHashes: readonly string[];
  clientDeviceHash: string | null;
}

export interface QualificationInput {
  window: CampaignWindow;
  rule: QualificationRule;
  now: Date;
  participants: readonly QualificationParticipant[];
  attributions: readonly QualificationAttribution[];
  referees: ReadonlyMap<string, QualificationReferee>;
  signals: ReadonlyMap<string, QualificationSignal>;
  /** Décision de l'équipe déjà posée sur la ligne du filleul, s'il y en a une. */
  decisions: ReadonlyMap<string, 'validated' | 'excluded'>;
}

export interface ComputedReferral {
  refereeProfileId: string;
  participantId: string;
  attachedAt: Date;
  accountCreatedAt: Date;
  profileCompletedAt: Date | null;
  qualifiedAt: Date | null;
  status: ReferralStatus;
  flags: ReferralFlag[];
}

export interface ComputedParticipant {
  id: string;
  qualifiedCount: number;
  flaggedCount: number;
  pendingCount: number;
  excludedCount: number;
  reachedCountAt: Date | null;
  rank: number | null;
  unrankableReason: string | null;
}

export interface QualificationOutput {
  referrals: ComputedReferral[];
  participants: ComputedParticipant[];
  /** Filleuls vus complets sans `profileCompletedAt` : l'appelant le pose à `now`. */
  completedNow: string[];
}

const maxDate = (...dates: Date[]): Date =>
  new Date(Math.max(...dates.map((d) => d.getTime())));

/**
 * Indices des éléments appartenant à au moins une fenêtre glissante
 * [t, t + windowMs[ contenant `threshold` éléments ou plus.
 */
export function burstMembers(
  times: readonly number[],
  threshold: number,
  windowMs: number,
): Set<number> {
  const order = times.map((t, i) => ({ t, i })).sort((a, b) => a.t - b.t || a.i - b.i);
  const out = new Set<number>();
  let end = 0;
  for (let start = 0; start < order.length; start += 1) {
    if (end < start) end = start;
    while (end + 1 < order.length && order[end + 1].t - order[start].t < windowMs) end += 1;
    if (end - start + 1 >= threshold) {
      for (let k = start; k <= end; k += 1) out.add(order[k].i);
    }
  }
  return out;
}

function flagBursts(
  rows: readonly ComputedReferral[],
  keyOf: (row: ComputedReferral) => string | null,
  threshold: number,
  windowMinutes: number,
  flag: ReferralFlag,
  flags: Map<string, Set<ReferralFlag>>,
): void {
  const groups = new Map<string, ComputedReferral[]>();
  for (const row of rows) {
    const key = keyOf(row);
    if (!key) continue;
    const groupKey = `${row.participantId}\u0000${key}`;
    const list = groups.get(groupKey) ?? [];
    list.push(row);
    groups.set(groupKey, list);
  }
  for (const list of groups.values()) {
    if (list.length < threshold) continue;
    const members = burstMembers(
      list.map((r) => r.attachedAt.getTime()),
      threshold,
      windowMinutes * 60_000,
    );
    for (const idx of members) flags.get(list[idx].refereeProfileId)?.add(flag);
  }
}

/**
 * Un compte qualifié par appareil : les filleuls qui partagent un empreinte
 * d'appareil (jeton push ou identifiant d'installation de la build 57) forment
 * un groupe ; seul le premier qualifié (puis le premier rattaché) garde sa
 * place, les autres passent « à vérifier ».
 */
function flagDeviceDuplicates(
  rows: readonly ComputedReferral[],
  signals: ReadonlyMap<string, QualificationSignal>,
  flags: Map<string, Set<ReferralFlag>>,
): void {
  const parent = new Map<string, string>();
  const find = (x: string): string => {
    let root = x;
    while (parent.get(root) !== root) root = parent.get(root)!;
    let cur = x;
    while (parent.get(cur) !== root) {
      const next = parent.get(cur)!;
      parent.set(cur, root);
      cur = next;
    }
    return root;
  };
  const owner = new Map<string, string>();
  for (const row of rows) {
    parent.set(row.refereeProfileId, row.refereeProfileId);
  }
  for (const row of rows) {
    const s = signals.get(row.refereeProfileId);
    if (!s) continue;
    const hashes = [...s.deviceHashes, ...(s.clientDeviceHash ? [s.clientDeviceHash] : [])];
    for (const h of hashes) {
      const first = owner.get(h);
      if (!first) {
        owner.set(h, row.refereeProfileId);
      } else {
        const a = find(first);
        const b = find(row.refereeProfileId);
        if (a !== b) parent.set(b, a);
      }
    }
  }
  const groups = new Map<string, ComputedReferral[]>();
  for (const row of rows) {
    const root = find(row.refereeProfileId);
    const list = groups.get(root) ?? [];
    list.push(row);
    groups.set(root, list);
  }
  const INF = Number.MAX_SAFE_INTEGER;
  for (const list of groups.values()) {
    if (list.length < 2) continue;
    list.sort(
      (a, b) =>
        (a.qualifiedAt?.getTime() ?? INF) - (b.qualifiedAt?.getTime() ?? INF) ||
        a.attachedAt.getTime() - b.attachedAt.getTime() ||
        a.refereeProfileId.localeCompare(b.refereeProfileId),
    );
    for (const dup of list.slice(1)) flags.get(dup.refereeProfileId)?.add('device_duplicate');
  }
}

export function computeQualification(input: QualificationInput): QualificationOutput {
  const { window, rule, now } = input;
  const byProfile = new Map(input.participants.map((p) => [p.profileId, p]));
  const participantProfiles = new Set(byProfile.keys());
  const completedNow: string[] = [];
  const rows: ComputedReferral[] = [];
  const seen = new Set<string>();

  for (const a of input.attributions) {
    const participant = byProfile.get(a.referrerProfileId);
    if (!participant) continue;
    if (!isWithinWindow(a.attachedAt, window)) continue;
    const referee = input.referees.get(a.refereeProfileId);
    if (!referee || seen.has(referee.id)) continue;
    seen.add(referee.id);

    let completedAt = referee.profileCompletedAt;
    if (!completedAt && isProfileComplete(referee, now)) {
      completedAt = now;
      completedNow.push(referee.id);
    }
    const accountOk =
      !rule.requireAccountCreatedInWindow || isWithinWindow(referee.createdAt, window);
    let qualifiedAt: Date | null = null;
    if (accountOk && isEmailVerified(referee) && completedAt) {
      const candidate = maxDate(a.attachedAt, referee.createdAt, completedAt);
      if (candidate.getTime() < window.endsAt.getTime()) qualifiedAt = candidate;
    }
    rows.push({
      refereeProfileId: referee.id,
      participantId: participant.id,
      attachedAt: a.attachedAt,
      accountCreatedAt: referee.createdAt,
      profileCompletedAt: completedAt,
      qualifiedAt,
      status: 'pending',
      flags: [],
    });
  }

  // ── Signaux automatiques ──────────────────────────────────────────────────
  const flags = new Map<string, Set<ReferralFlag>>(
    rows.map((r) => [r.refereeProfileId, new Set<ReferralFlag>()]),
  );
  for (const row of rows) {
    const referee = input.referees.get(row.refereeProfileId)!;
    if (isDisposableEmail(referee.email)) flags.get(row.refereeProfileId)!.add('disposable_email');
    if (participantProfiles.has(row.refereeProfileId)) {
      flags.get(row.refereeProfileId)!.add('referee_is_participant');
    }
  }
  const sig = (r: ComputedReferral) => input.signals.get(r.refereeProfileId);
  flagBursts(rows, (r) => sig(r)?.ipHash ?? null, rule.ipBurstThreshold, rule.ipBurstWindowMinutes, 'ip_burst', flags);
  flagBursts(
    rows,
    (r) => sig(r)?.ipBlockHash ?? null,
    rule.ipBlockBurstThreshold,
    rule.ipBlockBurstWindowMinutes,
    'ip_block_burst',
    flags,
  );
  flagBursts(
    rows,
    () => 'all',
    rule.velocityBurstThreshold,
    rule.velocityBurstWindowMinutes,
    'velocity_burst',
    flags,
  );
  flagDeviceDuplicates(rows, input.signals, flags);

  // ── Statut de chaque ligne ────────────────────────────────────────────────
  for (const row of rows) {
    row.flags = [...flags.get(row.refereeProfileId)!].sort();
    const decision = input.decisions.get(row.refereeProfileId);
    if (decision === 'excluded') row.status = 'excluded';
    else if (!row.qualifiedAt) row.status = 'pending';
    else if (row.flags.length > 0 && decision !== 'validated') row.status = 'flagged';
    else row.status = 'qualified';
  }
  rows.sort(
    (a, b) =>
      a.participantId.localeCompare(b.participantId) ||
      a.attachedAt.getTime() - b.attachedAt.getTime() ||
      a.refereeProfileId.localeCompare(b.refereeProfileId),
  );

  // ── Agrégats et classement ────────────────────────────────────────────────
  const aggregates: ComputedParticipant[] = input.participants.map((p) => {
    const own = rows.filter((r) => r.participantId === p.id);
    const qualified = own.filter((r) => r.status === 'qualified');
    const reached = qualified.length
      ? maxDate(...qualified.map((r) => r.qualifiedAt!))
      : null;
    return {
      id: p.id,
      qualifiedCount: qualified.length,
      flaggedCount: own.filter((r) => r.status === 'flagged').length,
      pendingCount: own.filter((r) => r.status === 'pending').length,
      excludedCount: own.filter((r) => r.status === 'excluded').length,
      reachedCountAt: reached,
      rank: null,
      unrankableReason: unrankableReason(p),
    };
  });
  const enrolled = new Map(input.participants.map((p) => [p.id, p.enrolledAt.getTime()]));
  const ranked = aggregates
    .filter((a) => a.unrankableReason === null && a.qualifiedCount > 0)
    .sort(
      (a, b) =>
        b.qualifiedCount - a.qualifiedCount ||
        a.reachedCountAt!.getTime() - b.reachedCountAt!.getTime() ||
        enrolled.get(a.id)! - enrolled.get(b.id)! ||
        a.id.localeCompare(b.id),
    );
  ranked.forEach((a, i) => {
    a.rank = i + 1;
  });

  return { referrals: rows, participants: aggregates, completedNow };
}
