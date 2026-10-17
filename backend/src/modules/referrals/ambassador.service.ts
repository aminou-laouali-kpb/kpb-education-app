import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { ambassadorCodeFor, normalizeReferralCode } from './referral-code';

// ─────────────────────────────────────────────────────────────────────────────
// Ambassadeur program (App-engagement handoff · US-032→035).
//
// A CASH referral program: shareable code, FCFA commissions, a city
// leaderboard and Wave payouts — distinct from the no-cash review-credit
// `Referral`/`CreditTransaction` system. Backed by the Ambassador /
// AmbassadorReferral / Commission / Withdrawal tables, with a graceful SAMPLE
// fallback (same shape as the design mock) so the mobile surface renders even
// before the caller has activated their space or when the DB is unavailable.
//
// Money movement is intentionally NOT integrated here: `requestWithdrawal`
// records a `requested` Withdrawal (paid out via Wave within 48h by ops) — it
// never calls an external transfer API.
//
// Compétition ambassadeurs (novembre 2026) : une ligne `Ambassador` peut exister
// SANS l'espace « cash » (`cashProgramEnabled = false`, cas de tout ambassadeur
// activé par l'équipe pour la compétition). Pour elle, le tableau de bord reste
// l'aperçu non activé : l'app installée affiche l'écran de candidature, jamais
// des commissions promises. L'auto-activation est fermée côté serveur
// (`AMBASSADOR_SELF_ACTIVATION_ENABLED`, faux par défaut) : seule l'équipe active
// un ambassadeur (`POST /admin/ambassadors`).
// ─────────────────────────────────────────────────────────────────────────────

const MIN_WITHDRAWAL_FCFA = 20000; // US-035
const REWARD_SIGNUP_FCFA = 1000; // inscription + quiz complété
const REWARD_PLACED_FCFA = 35000; // filleul placé dans une école via KPB

type ReferralStatusKey =
  | 'signed_up'
  | 'quiz_completed'
  | 'application_created'
  | 'premium_subscribed'
  | 'placed'
  | 'churned';

interface AmbRow {
  displayName: string;
  campus: string;
  city: string;
  code: string;
  payoutMethod: string;
  payoutAccount: string;
  monthlyObjective: number;
  monthlyBonusFCFA: number;
}
interface RefRow {
  name: string;
  status: ReferralStatusKey;
  note: string;
  gainFCFA: number;
}
interface ComRow {
  reason: string;
  label: string;
  amountFCFA: number;
  earnedAt: string;
  batched: boolean;
}
interface WdrRow {
  amountFCFA: number;
  status: string;
  requestedAt: string;
}

@Injectable()
export class AmbassadorService {
  constructor(private readonly prismaService: PrismaService) {}

  // The design's Binta Sarr sample — also the not-activated preview + DB-down
  // fallback. Kept faithful to `Ambassadeur App.dc.html`.
  private readonly sample: {
    amb: AmbRow;
    referrals: RefRow[];
    commissions: ComRow[];
    withdrawals: WdrRow[];
    rankLabel: string;
    leaderboard: { name: string; referrals: number; isMe: boolean }[];
    balanceFCFA: number;
  } = {
    amb: {
      displayName: 'Binta Sarr',
      campus: 'Ambassadrice campus — UCAD Dakar',
      city: 'Dakar',
      code: 'KTOU-BS-7c21',
      payoutMethod: 'wave',
      payoutAccount: '+221 77 000 45 21',
      monthlyObjective: 15,
      monthlyBonusFCFA: 10000,
    },
    rankLabel: 'Top 3 Dakar',
    referrals: [
      { name: 'Aïcha Diallo', status: 'application_created', note: 'Dossier Grenoble 30 % · très active', gainFCFA: 1000 },
      { name: 'Moussa Dieng', status: 'placed', note: 'Admis à Laval 🎉 · placé via KPB', gainFCFA: 36000 },
      { name: 'Fatou Sow', status: 'quiz_completed', note: 'Quiz complété · explore les écoles', gainFCFA: 1000 },
      { name: 'Aminata Ba', status: 'signed_up', note: 'Inscrite hier · quiz non commencé', gainFCFA: 0 },
      { name: 'Cheikh Ndao', status: 'signed_up', note: 'Inscrit il y a 3 j · quiz abandonné Q4', gainFCFA: 0 },
    ],
    commissions: [
      { reason: 'referral_placed', label: 'Moussa placé — Université Laval', amountFCFA: 35000, earnedAt: '2026-07-02', batched: false },
      { reason: 'referral_signup', label: '3 inscriptions validées', amountFCFA: 3000, earnedAt: '2026-06-15', batched: false },
      { reason: 'bonus_leaderboard', label: 'Bonus objectif juin (15 filleuls)', amountFCFA: 10000, earnedAt: '2026-06-30', batched: false },
    ],
    withdrawals: [{ amountFCFA: 25000, status: 'completed', requestedAt: '2026-06-28' }],
    leaderboard: [
      { name: 'Omar F. — ESP Dakar', referrals: 19, isMe: false },
      { name: 'Binta Sarr — UCAD (toi)', referrals: 12, isMe: true },
      { name: 'Adama N. — UGB Saint-Louis', referrals: 11, isMe: false },
    ],
    balanceFCFA: 47000,
  };

  // ── Public API ──────────────────────────────────────────────────────────────

  async getDashboard(profileId: string) {
    const amb = await this.loadAmbassador(profileId);
    if (!amb) {
      // Not activated (or DB unavailable): preview the sample surface.
      return this.buildDashboard({
        activated: false,
        isSample: true,
        amb: this.sample.amb,
        rankLabel: this.sample.rankLabel,
        referrals: this.sample.referrals,
        commissions: this.sample.commissions,
        withdrawals: this.sample.withdrawals,
        leaderboard: this.sample.leaderboard,
        // The design's headline figures are cumulative aggregates, independent
        // of the 5 illustrative filleul cards — pin them so the preview matches.
        overrides: {
          activeReferrals: 12,
          placed: 3,
          earnedFCFA: 117000,
          objectiveCurrent: 12,
          balanceFCFA: this.sample.balanceFCFA,
        },
      });
    }
    return this.buildDashboard({ activated: true, isSample: false, ...amb });
  }

  async activate(
    profileId: string,
    input: { displayName?: string; campus?: string; city?: string; payoutAccount?: string },
  ) {
    const created = await this.prismaService.execute(async (prisma) => {
      const existing = await prisma.ambassador.findUnique({
        where: { userProfileId: profileId },
      });
      if (existing) return existing;
      // Garde serveur : plus d'auto-activation tant que le programme rémunéré
      // n'est pas ouvert. L'app installée n'appelle pas cette route (aucun
      // bouton ne la déclenche quand KPB_AMBASSADOR_CASH_ENABLED est faux) ;
      // une ancienne build qui l'appellerait reçoit un 403 explicite.
      if (!selfActivationEnabled()) {
        throw new ForbiddenException({
          statusCode: 403,
          code: 'ambassador_activation_admin_only',
          message:
            'L’espace ambassadeur est activé par l’équipe KPB. Écris-nous sur WhatsApp pour candidater.',
        });
      }
      try {
        const code = ambassadorCodeFor(profileId, input.displayName ?? '');
        return await prisma.ambassador.create({
          data: {
            userProfileId: profileId,
            // Code is derived from the (unique) profile id, so it is stable and
            // collision-free across re-activations of the same user.
            code,
            codeNormalized: normalizeReferralCode(code),
            displayName: input.displayName ?? '',
            campus: input.campus ?? '',
            city: input.city ?? '',
            payoutAccount: input.payoutAccount ?? '',
            // L'auto-activation est celle du programme rémunéré.
            cashProgramEnabled: true,
          },
        });
      } catch (error) {
        // Idempotent under a concurrent activation: a parallel create wins the
        // userProfileId unique constraint (P2002) — re-fetch and return it
        // instead of surfacing a raw 500.
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002'
        ) {
          const again = await prisma.ambassador.findUnique({
            where: { userProfileId: profileId },
          });
          if (again) return again;
        }
        throw error;
      }
    });
    if (!created) {
      throw new BadRequestException(
        'Impossible d’activer l’espace ambassadeur pour le moment.',
      );
    }
    return this.getDashboard(profileId);
  }

  // Withdrawals always pay out the FULL available balance (the design's
  // "Retirer <solde>" button — there is no partial-amount UI). The amount is
  // computed from the commissions actually CLAIMED inside the transaction, so
  // it can never drift from what was batched, and concurrent requests can't
  // double-spend: the second request's updateMany matches 0 already-claimed
  // rows → sum 0 → below the floor → the whole transaction rolls back.
  async requestWithdrawal(profileId: string) {
    const amb = await this.loadAmbassadorRaw(profileId);
    if (!amb || !amb.cashProgramEnabled) {
      throw new BadRequestException(
        'Active ton espace ambassadeur avant de demander un retrait.',
      );
    }
    // Fast pre-check for the common "nothing to withdraw" case (authoritative
    // guard is inside the transaction below).
    if (this.withdrawable(amb.commissions) < MIN_WITHDRAWAL_FCFA) {
      throw new BadRequestException(
        `Le retrait minimum est de ${MIN_WITHDRAWAL_FCFA} FCFA.`,
      );
    }

    const done = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        // 1. Open the payout request (amount filled in step 3).
        const withdrawal = await tx.withdrawal.create({
          data: {
            ambassadorId: amb.id,
            amountFCFA: 0,
            method: amb.payoutMethod as never,
            destinationAccount: amb.payoutAccount,
            status: 'requested',
          },
        });
        // 2. Atomically claim every unpaid commission (row-locks them).
        await tx.commission.updateMany({
          where: { ambassadorId: amb.id, withdrawalId: null },
          data: { withdrawalId: withdrawal.id },
        });
        // 3. The payout is exactly the sum of what THIS request claimed.
        const agg = await tx.commission.aggregate({
          where: { withdrawalId: withdrawal.id },
          _sum: { amountFCFA: true },
        });
        const amount = agg._sum.amountFCFA ?? 0;
        if (amount < MIN_WITHDRAWAL_FCFA) {
          // Nothing (or too little) claimed — likely a concurrent request beat
          // us to the balance. Roll everything back.
          throw new BadRequestException(
            `Le retrait minimum est de ${MIN_WITHDRAWAL_FCFA} FCFA.`,
          );
        }
        return tx.withdrawal.update({
          where: { id: withdrawal.id },
          data: { amountFCFA: amount },
        });
      }),
    );
    if (!done) {
      throw new BadRequestException('Retrait indisponible pour le moment.');
    }
    return {
      id: done.id,
      amountFCFA: done.amountFCFA,
      status: done.status,
      etaHours: 48,
    };
  }

  async getWithdrawalHistory(profileId: string) {
    const amb = await this.loadAmbassador(profileId);
    const rows = amb ? amb.withdrawals : this.sample.withdrawals;
    return {
      items: rows.map((w) => ({
        amountFCFA: w.amountFCFA,
        status: w.status,
        requestedAt: w.requestedAt,
      })),
    };
  }

  // ── Loading / normalization ──────────────────────────────────────────────────

  private async loadAmbassadorRaw(profileId: string) {
    return this.prismaService.execute((prisma) =>
      prisma.ambassador.findUnique({
        where: { userProfileId: profileId },
        include: {
          referrals: { orderBy: { signedUpAt: 'desc' } },
          commissions: { orderBy: { earnedAt: 'desc' } },
          withdrawals: { orderBy: { requestedAt: 'desc' } },
        },
      }),
    );
  }

  private async loadAmbassador(profileId: string): Promise<
    | ({
        amb: AmbRow;
        rankLabel: string;
        referrals: RefRow[];
        commissions: ComRow[];
        withdrawals: WdrRow[];
        leaderboard: { name: string; referrals: number; isMe: boolean }[];
      })
    | null
  > {
    const row = await this.loadAmbassadorRaw(profileId);
    // Sans l'espace « cash » (ambassadeur de la compétition), aperçu non activé.
    if (!row || !row.cashProgramEnabled) return null;

    const referrals: RefRow[] = row.referrals.map((r) => ({
      name: r.refereeName || 'Filleul',
      status: r.status as ReferralStatusKey,
      note: r.note ?? '',
      gainFCFA: row.commissions
        .filter((c) => c.referralId === r.id)
        .reduce((sum, c) => sum + c.amountFCFA, 0),
    }));
    const commissions: ComRow[] = row.commissions.map((c) => ({
      reason: c.reason,
      label: c.label ?? '',
      amountFCFA: c.amountFCFA,
      earnedAt: c.earnedAt.toISOString().slice(0, 10),
      batched: c.withdrawalId != null,
    }));
    const withdrawals: WdrRow[] = row.withdrawals.map((w) => ({
      amountFCFA: w.amountFCFA,
      status: w.status,
      requestedAt: w.requestedAt.toISOString().slice(0, 10),
    }));

    const leaderboard = await this.buildLeaderboard(row.city, row.id);

    return {
      amb: {
        displayName: row.displayName,
        campus: row.campus,
        city: row.city,
        code: row.code,
        payoutMethod: row.payoutMethod,
        payoutAccount: row.payoutAccount,
        monthlyObjective: row.monthlyObjective,
        monthlyBonusFCFA: row.monthlyBonusFCFA,
      },
      rankLabel: this.rankLabel(leaderboard),
      referrals,
      commissions,
      withdrawals,
      leaderboard,
    };
  }

  private async buildLeaderboard(city: string, myId: string) {
    const rows = await this.prismaService.execute((prisma) =>
      prisma.ambassador.findMany({
        where: city ? { city } : {},
        orderBy: { totalReferrals: 'desc' },
        take: 3,
      }),
    );
    if (!rows || rows.length === 0) return [] as { name: string; referrals: number; isMe: boolean }[];
    return rows.map((a) => ({
      name: `${a.displayName}${a.campus ? ` — ${a.campus.split('—').pop()?.trim() ?? ''}` : ''}`.trim(),
      referrals: a.totalReferrals,
      isMe: a.id === myId,
    }));
  }

  private rankLabel(
    leaderboard: { referrals: number; isMe: boolean }[],
  ): string {
    const idx = leaderboard.findIndex((l) => l.isMe);
    return idx >= 0 && idx < 3 ? `Top ${idx + 1}` : '';
  }

  // Sum of commissions not yet attached to a withdrawal.
  private withdrawable(
    commissions: { amountFCFA: number; withdrawalId: string | null }[],
  ): number {
    return commissions
      .filter((c) => c.withdrawalId == null)
      .reduce((sum, c) => sum + c.amountFCFA, 0);
  }

  // ── DTO assembly (single shape for sample + real) ────────────────────────────

  private buildDashboard(src: {
    activated: boolean;
    isSample: boolean;
    amb: AmbRow;
    rankLabel: string;
    referrals: RefRow[];
    commissions: ComRow[];
    withdrawals: WdrRow[];
    leaderboard: { name: string; referrals: number; isMe: boolean }[];
    overrides?: {
      activeReferrals: number;
      placed: number;
      earnedFCFA: number;
      objectiveCurrent: number;
      balanceFCFA: number;
    };
  }) {
    const { amb, referrals, commissions, overrides } = src;
    const activeReferrals =
      overrides?.activeReferrals ??
      referrals.filter((r) => r.status !== 'churned').length;
    const placed =
      overrides?.placed ?? referrals.filter((r) => r.status === 'placed').length;
    const earnedFCFA =
      overrides?.earnedFCFA ?? commissions.reduce((s, c) => s + c.amountFCFA, 0);
    const withdrawableFCFA =
      overrides?.balanceFCFA ??
      commissions.filter((c) => !c.batched).reduce((s, c) => s + c.amountFCFA, 0);
    const objectiveCurrent = overrides?.objectiveCurrent ?? activeReferrals;

    return {
      activated: src.activated,
      isSample: src.isSample,
      ambassador: {
        displayName: amb.displayName,
        campus: amb.campus,
        city: amb.city,
        initials: this.initials(amb.displayName),
        code: amb.code,
        rankLabel: src.rankLabel,
        payoutMethod: amb.payoutMethod,
        payoutAccountMasked: this.maskAccount(amb.payoutAccount),
      },
      stats: { activeReferrals, placed, earnedFCFA },
      objective: {
        target: amb.monthlyObjective,
        current: objectiveCurrent,
        bonusFCFA: amb.monthlyBonusFCFA,
      },
      rewards: [
        { reason: 'referral_signup', amountFCFA: REWARD_SIGNUP_FCFA },
        { reason: 'referral_placed', amountFCFA: REWARD_PLACED_FCFA },
      ],
      leaderboard: src.leaderboard.map((l, i) => ({
        rank: i + 1,
        name: l.name,
        initials: this.initials(l.name),
        referrals: l.referrals,
        isMe: l.isMe,
      })),
      referrals: referrals.map((r) => ({
        name: r.name,
        initials: this.initials(r.name),
        note: r.note,
        status: r.status,
        gainFCFA: r.gainFCFA,
      })),
      balanceFCFA: withdrawableFCFA,
      withdrawableFCFA,
      minWithdrawalFCFA: MIN_WITHDRAWAL_FCFA,
      history: commissions
        .map((c) => ({
          label: c.label,
          date: c.earnedAt,
          kind: c.reason,
          amountFCFA: c.amountFCFA,
        }))
        .concat(
          src.withdrawals.map((w) => ({
            label: 'Retrait Wave',
            date: w.requestedAt,
            kind: 'withdrawal',
            amountFCFA: -w.amountFCFA,
          })),
        )
        .sort((a, b) => (a.date < b.date ? 1 : -1)),
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  private initials(name: string): string {
    const parts = name
      .replace(/\(.*?\)/g, '')
      .split(/[\s—-]+/)
      .filter((p) => p && /[A-Za-zÀ-ÿ]/.test(p));
    if (parts.length === 0) return '★';
    if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  private maskAccount(account: string): string {
    const digits = account.replace(/\D/g, '');
    if (digits.length < 4) return account;
    const tail = digits.slice(-4);
    return `${account.slice(0, Math.max(0, account.length - 7))}••• ${tail.slice(0, 2)} ${tail.slice(2)}`.trim();
  }
}

/** `AMBASSADOR_SELF_ACTIVATION_ENABLED=true` rouvre l'auto-activation (programme rémunéré). */
export function selfActivationEnabled(): boolean {
  return process.env.AMBASSADOR_SELF_ACTIVATION_ENABLED === 'true';
}
