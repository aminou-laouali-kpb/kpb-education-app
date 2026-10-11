import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { ReferralCreditsReconcileCronService } from './referral-credits-reconcile-cron.service';
import {
  CREDITS_PER_REFERRAL,
  ReferralCreditsService,
} from './referral-credits.service';

/// Lazy thenable so `$transaction([...])` executes ops in order and a rejected
/// op aborts before the next — mirrors referral-credits.service.spec.ts.
function lazy<T>(run: () => T) {
  return {
    then(onF: (v: T) => unknown, onR: (e: unknown) => unknown) {
      return Promise.resolve()
        .then(() => run())
        .then(onF, onR);
    },
  };
}

interface Setup {
  profiles: Map<string, { reviewCredits: number }>;
  referrals: Array<{ id: string; referrerId: string; refereeProfileId: string }>;
  caseCountByUser: Map<string, number>;
  txns: Array<{
    profileId: string;
    amount: number;
    reason: string;
    dedupeKey: string;
    metadata: any;
    createdAt: Date;
  }>;
}

/// Builds a real PrismaService-shaped stand-in wired to the real
/// ReferralCreditsService, so the cron is tested end-to-end against the same
/// idempotent crediting path the inline hook uses.
function makeCron(setup: Setup): {
  cron: ReferralCreditsReconcileCronService;
  setup: Setup;
} {
  const { profiles, referrals, caseCountByUser, txns } = setup;
  const dedupeKeys = new Set(txns.map((t) => t.dedupeKey));

  const db: any = {
    referral: {
      findMany: () =>
        lazy(() =>
          referrals.map((r) => ({
            id: r.id,
            referrerId: r.referrerId,
            refereeProfileId: r.refereeProfileId,
          })),
        ),
      findUnique: ({ where }: any) =>
        lazy(
          () =>
            referrals.find(
              (r) => r.refereeProfileId === where.refereeProfileId,
            ) ?? null,
        ),
    },
    case: {
      count: ({ where }: any) =>
        lazy(() => caseCountByUser.get(where.userId) ?? 0),
      // The first case is filed after the referral (created "now" in tests).
      findFirst: ({ where }: any) =>
        lazy(() =>
          (caseCountByUser.get(where.userId) ?? 0) > 0
            ? { createdAt: new Date('2099-01-01T00:00:00Z') }
            : null,
        ),
    },
    creditTransaction: {
      create: ({ data }: any) =>
        lazy(() => {
          // The service checks `instanceof Prisma.PrismaClientKnownRequestError`
          // with code P2002, so a collision must throw the real error type.
          if (dedupeKeys.has(data.dedupeKey)) throw makeP2002();
          dedupeKeys.add(data.dedupeKey);
          txns.push({ ...data, createdAt: new Date() });
          return { ...data };
        }),
      findMany: ({ where }: any) =>
        lazy(() =>
          txns
            .filter((t) => !where?.reason || t.reason === where.reason)
            .map((t) => ({ dedupeKey: t.dedupeKey })),
        ),
      count: ({ where }: any) =>
        lazy(
          () =>
            txns.filter((t) => !where?.reason || t.reason === where.reason)
              .length,
        ),
    },
    userProfile: {
      update: ({ where, data }: any) =>
        lazy(() => {
          const prof = profiles.get(where.id)!;
          prof.reviewCredits += data.reviewCredits.increment;
          return { reviewCredits: prof.reviewCredits };
        }),
    },
    $transaction: (arg: any) => {
      if (Array.isArray(arg)) {
        return (async () => {
          const out = [];
          for (const op of arg) out.push(await op);
          return out;
        })();
      }
      return arg(db);
    },
  };

  const prisma = {
    isEnabled: true,
    execute: async (fn: (c: any) => Promise<any>) => fn(db),
    tryExecute: async (fn: (c: any) => Promise<any>) => {
      try {
        return await fn(db);
      } catch {
        return null;
      }
    },
  } as unknown as PrismaService;

  const credits = new ReferralCreditsService(prisma);
  const cron = new ReferralCreditsReconcileCronService(prisma, credits);
  return { cron, setup };
}

function makeP2002(): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: 'test',
  });
}

function emptySetup(): Setup {
  return {
    profiles: new Map(),
    referrals: [],
    caseCountByUser: new Map(),
    txns: [],
  };
}

describe('ReferralCreditsReconcileCronService', () => {
  it('backfills a referral whose referee has a case but no credit', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referrals.push({ id: 'R1', referrerId: 'ref', refereeProfileId: 'referee' });
    s.caseCountByUser.set('referee', 1);

    const { cron } = makeCron(s);
    const out = await cron.run();

    expect(out).toEqual({ referralsChecked: 1, creditsBackfilled: 1 });
    expect(s.profiles.get('ref')!.reviewCredits).toBe(CREDITS_PER_REFERRAL);
    expect(s.txns).toHaveLength(1);
    expect(s.txns[0].dedupeKey).toBe('firstcase:R1');
  });

  it('skips a referral already credited (no double-credit, not a candidate)', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: CREDITS_PER_REFERRAL });
    s.referrals.push({ id: 'R1', referrerId: 'ref', refereeProfileId: 'referee' });
    s.caseCountByUser.set('referee', 1);
    s.txns.push({
      profileId: 'ref',
      amount: CREDITS_PER_REFERRAL,
      reason: 'referralFirstCase',
      dedupeKey: 'firstcase:R1',
      metadata: { refereeId: 'referee' },
      createdAt: new Date(),
    });

    const { cron } = makeCron(s);
    const out = await cron.run();

    // Already credited → filtered out by the dedupeKey pre-scan, never inspected.
    expect(out).toEqual({ referralsChecked: 0, creditsBackfilled: 0 });
    expect(s.profiles.get('ref')!.reviewCredits).toBe(CREDITS_PER_REFERRAL);
    expect(s.txns).toHaveLength(1);
  });

  it('skips a referral whose referee has no case yet', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referrals.push({ id: 'R1', referrerId: 'ref', refereeProfileId: 'referee' });
    // no case for referee
    const { cron } = makeCron(s);
    const out = await cron.run();

    expect(out).toEqual({ referralsChecked: 0, creditsBackfilled: 0 });
    expect(s.txns).toHaveLength(0);
  });

  it('does not credit when the referee is past their first case (2nd+ case)', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referrals.push({ id: 'R1', referrerId: 'ref', refereeProfileId: 'referee' });
    s.caseCountByUser.set('referee', 2); // caseCount !== 1 → service no-ops

    const { cron } = makeCron(s);
    const out = await cron.run();

    // It IS a candidate (has a case, no credit) but the idempotent service
    // refuses to credit beyond the first-case milestone.
    expect(out).toEqual({ referralsChecked: 1, creditsBackfilled: 0 });
    expect(s.profiles.get('ref')!.reviewCredits).toBe(0);
    expect(s.txns).toHaveLength(0);
  });

  it('backfills only the uncredited referral in a mixed batch', async () => {
    const s = emptySetup();
    s.profiles.set('refA', { reviewCredits: CREDITS_PER_REFERRAL });
    s.profiles.set('refB', { reviewCredits: 0 });
    s.referrals.push(
      { id: 'RA', referrerId: 'refA', refereeProfileId: 'refereeA' },
      { id: 'RB', referrerId: 'refB', refereeProfileId: 'refereeB' },
    );
    s.caseCountByUser.set('refereeA', 1);
    s.caseCountByUser.set('refereeB', 1);
    // refereeA already credited
    s.txns.push({
      profileId: 'refA',
      amount: CREDITS_PER_REFERRAL,
      reason: 'referralFirstCase',
      dedupeKey: 'firstcase:RA',
      metadata: {},
      createdAt: new Date(),
    });

    const { cron } = makeCron(s);
    const out = await cron.run();

    expect(out).toEqual({ referralsChecked: 1, creditsBackfilled: 1 });
    expect(s.profiles.get('refB')!.reviewCredits).toBe(CREDITS_PER_REFERRAL);
    expect(s.txns.map((t) => t.dedupeKey).sort()).toEqual([
      'firstcase:RA',
      'firstcase:RB',
    ]);
  });

  it('scheduledRun is a no-op when the database is disabled', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referrals.push({ id: 'R1', referrerId: 'ref', refereeProfileId: 'referee' });
    s.caseCountByUser.set('referee', 1);

    const { cron } = makeCron(s);
    // Force disabled.
    (cron as any).prisma.isEnabled = false;
    await cron.scheduledRun();

    expect(s.txns).toHaveLength(0);
  });
});
