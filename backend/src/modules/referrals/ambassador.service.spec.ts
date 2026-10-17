import { BadRequestException, ForbiddenException } from '@nestjs/common';

import { AmbassadorService } from './ambassador.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * The Ambassadeur surface must render before activation (sample preview) and
 * from real data after. Withdrawals are recorded requests (no external
 * transfer) and must enforce the 20 000 FCFA floor + available balance.
 */
describe('AmbassadorService', () => {
  const nullPrisma = { execute: async () => null } as unknown as PrismaService;

  function dbPrisma(
    ambassador: Record<string, unknown> | null,
    // Sum returned by commission.aggregate after claiming (the batched total).
    claimedSumFCFA = 0,
  ) {
    const calls = {
      withdrawalCreate: [] as unknown[],
      withdrawalUpdate: [] as unknown[],
      commissionUpdateMany: [] as unknown[],
    };
    const client = {
      ambassador: {
        findUnique: async () => ambassador,
        findMany: async () => (ambassador ? [ambassador] : []),
        create: async ({ data }: { data: Record<string, unknown> }) => ({ id: 'amb-new', ...data }),
      },
      withdrawal: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          calls.withdrawalCreate.push(data);
          return { id: 'wd-1', ...data };
        },
        update: async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
          calls.withdrawalUpdate.push({ where, data });
          return { id: where.id, status: 'requested', ...data };
        },
      },
      commission: {
        updateMany: async (args: unknown) => {
          calls.commissionUpdateMany.push(args);
          return { count: 1 };
        },
        aggregate: async () => ({ _sum: { amountFCFA: claimedSumFCFA } }),
      },
      $transaction: async (fn: (tx: unknown) => unknown) => fn(client),
    };
    const prisma = {
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, calls };
  }

  describe('getDashboard — sample preview (not activated / DB down)', () => {
    it('returns the Binta Sarr sample with the design headline figures', async () => {
      const svc = new AmbassadorService(nullPrisma);
      const d = await svc.getDashboard('profile-x');
      expect(d.activated).toBe(false);
      expect(d.isSample).toBe(true);
      expect(d.ambassador.code).toBe('KTOU-BS-7c21');
      expect(d.ambassador.initials).toBe('BS');
      expect(d.stats).toEqual({ activeReferrals: 12, placed: 3, earnedFCFA: 117000 });
      expect(d.objective).toEqual({ target: 15, current: 12, bonusFCFA: 10000 });
      expect(d.balanceFCFA).toBe(47000);
      expect(d.referrals).toHaveLength(5);
      expect(d.leaderboard.find((l) => l.isMe)?.rank).toBe(2);
      expect(d.minWithdrawalFCFA).toBe(20000);
    });

    it('maps reward tiers (signup 1 000 / placed 35 000)', async () => {
      const svc = new AmbassadorService(nullPrisma);
      const d = await svc.getDashboard('p');
      const byReason = Object.fromEntries(d.rewards.map((r) => [r.reason, r.amountFCFA]));
      expect(byReason['referral_signup']).toBe(1000);
      expect(byReason['referral_placed']).toBe(35000);
    });
  });

  describe('getDashboard — real data', () => {
    it('derives stats from the ambassador row', async () => {
      const amb = {
        id: 'amb-1',
        userProfileId: 'p1',
        code: 'KTOU-AL-1a2b',
        displayName: 'Awa Lo',
        campus: 'UCAD',
        city: 'Dakar',
        payoutMethod: 'wave',
        payoutAccount: '+221770000000',
        monthlyObjective: 15,
        monthlyBonusFCFA: 10000,
        cashProgramEnabled: true,
        referrals: [
          { id: 'r1', refereeName: 'X', status: 'placed', note: '', signedUpAt: new Date() },
          { id: 'r2', refereeName: 'Y', status: 'signed_up', note: '', signedUpAt: new Date() },
        ],
        commissions: [
          { id: 'c1', referralId: 'r1', reason: 'referral_placed', label: '', amountFCFA: 35000, earnedAt: new Date(), withdrawalId: null },
        ],
        withdrawals: [],
      };
      const { prisma } = dbPrisma(amb);
      const svc = new AmbassadorService(prisma);
      const d = await svc.getDashboard('p1');
      expect(d.activated).toBe(true);
      expect(d.isSample).toBe(false);
      expect(d.stats.placed).toBe(1);
      expect(d.stats.activeReferrals).toBe(2);
      expect(d.stats.earnedFCFA).toBe(35000);
      expect(d.balanceFCFA).toBe(35000); // unbatched commission
      expect(d.referrals[0].gainFCFA).toBe(35000);
    });
  });

  describe('requestWithdrawal (full balance only)', () => {
    const ambWithBalance = {
      id: 'amb-1',
      cashProgramEnabled: true,
      payoutMethod: 'wave',
      payoutAccount: '+221770000000',
      commissions: [{ amountFCFA: 47000, withdrawalId: null }],
    };

    it('rejects when not activated', async () => {
      const svc = new AmbassadorService(nullPrisma);
      await expect(svc.requestWithdrawal('p')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects when the available balance is below the 20 000 FCFA floor', async () => {
      const { prisma } = dbPrisma({
        ...ambWithBalance,
        commissions: [{ amountFCFA: 5000, withdrawalId: null }],
      });
      const svc = new AmbassadorService(prisma);
      await expect(svc.requestWithdrawal('p1')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('pays out exactly the claimed total (amount = batched sum) and batches once', async () => {
      const { prisma, calls } = dbPrisma(ambWithBalance, 47000);
      const svc = new AmbassadorService(prisma);
      const res = await svc.requestWithdrawal('p1');
      expect(res.status).toBe('requested');
      expect(res.amountFCFA).toBe(47000);
      expect(res.etaHours).toBe(48);
      expect(calls.withdrawalCreate).toHaveLength(1);
      expect(calls.commissionUpdateMany).toHaveLength(1);
      // The recorded amount is set from the aggregate of claimed commissions.
      expect((calls.withdrawalUpdate[0] as { data: { amountFCFA: number } }).data.amountFCFA)
          .toBe(47000);
    });

    it('rolls back when a concurrent request already claimed the balance (0 claimed)', async () => {
      // Pre-check passes (unbatched 47000) but the in-tx aggregate sees 0 —
      // i.e. another request claimed the commissions first.
      const { prisma } = dbPrisma(ambWithBalance, 0);
      const svc = new AmbassadorService(prisma);
      await expect(svc.requestWithdrawal('p1')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('compétition : ambassadeur sans espace « cash »', () => {
    const competitionAmb = {
      id: 'amb-c',
      userProfileId: 'p9',
      code: 'KTOU-AK-abc123',
      displayName: 'Aïcha Konaté',
      campus: '',
      city: 'Niamey',
      payoutMethod: 'wave',
      payoutAccount: '',
      monthlyObjective: 15,
      monthlyBonusFCFA: 10000,
      cashProgramEnabled: false,
      referrals: [],
      commissions: [],
      withdrawals: [],
    };

    it('garde l’aperçu non activé : l’app installée ne montre aucune commission', async () => {
      const { prisma } = dbPrisma(competitionAmb);
      const d = await new AmbassadorService(prisma).getDashboard('p9');
      expect(d.activated).toBe(false);
      expect(d.isSample).toBe(true);
    });

    it('refuse un retrait', async () => {
      const { prisma } = dbPrisma({ ...competitionAmb, commissions: [{ amountFCFA: 50000, withdrawalId: null }] });
      await expect(new AmbassadorService(prisma).requestWithdrawal('p9')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('activate — garde serveur', () => {
    const OLD = process.env.AMBASSADOR_SELF_ACTIVATION_ENABLED;
    afterEach(() => {
      if (OLD === undefined) delete process.env.AMBASSADOR_SELF_ACTIVATION_ENABLED;
      else process.env.AMBASSADOR_SELF_ACTIVATION_ENABLED = OLD;
    });

    it('refuse l’auto-activation par défaut (403, rien n’est créé)', async () => {
      delete process.env.AMBASSADOR_SELF_ACTIVATION_ENABLED;
      const created: unknown[] = [];
      const client = {
        ambassador: {
          findUnique: async () => null,
          create: async (args: unknown) => {
            created.push(args);
            return {};
          },
        },
      };
      const prisma = {
        execute: async (fn: (c: typeof client) => unknown) => fn(client),
      } as unknown as PrismaService;
      await expect(new AmbassadorService(prisma).activate('p1', {})).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      expect(created).toHaveLength(0);
    });

    it('rend le tableau de bord d’une ligne existante sans rien modifier', async () => {
      delete process.env.AMBASSADOR_SELF_ACTIVATION_ENABLED;
      const { prisma } = dbPrisma({
        id: 'amb-1',
        userProfileId: 'p1',
        code: 'KTOU-AL-1a2b',
        displayName: 'Awa Lo',
        campus: '',
        city: 'Dakar',
        payoutMethod: 'wave',
        payoutAccount: '',
        monthlyObjective: 15,
        monthlyBonusFCFA: 10000,
        cashProgramEnabled: true,
        referrals: [],
        commissions: [],
        withdrawals: [],
      });
      const d = await new AmbassadorService(prisma).activate('p1', {});
      expect(d.activated).toBe(true);
    });

    it('rouvre l’auto-activation (programme rémunéré) quand le drapeau serveur est posé', async () => {
      process.env.AMBASSADOR_SELF_ACTIVATION_ENABLED = 'true';
      const created: Array<{ data: Record<string, unknown> }> = [];
      const client = {
        ambassador: {
          findUnique: async () => null,
          findMany: async () => [],
          create: async (args: { data: Record<string, unknown> }) => {
            created.push(args);
            return { id: 'amb-n', ...args.data };
          },
        },
      };
      const prisma = {
        execute: async (fn: (c: typeof client) => unknown) => fn(client),
      } as unknown as PrismaService;
      await new AmbassadorService(prisma).activate('profile-1', { displayName: 'Awa Lo' });
      expect(created[0].data.code).toMatch(/^KTOU-AL-[0-9a-z]{6}$/);
      expect(created[0].data.codeNormalized).toBe(
        String(created[0].data.code).toUpperCase().replace(/-/g, ''),
      );
      expect(created[0].data.cashProgramEnabled).toBe(true);
    });
  });
});
