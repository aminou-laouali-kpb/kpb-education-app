import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  CREDITS_PER_REFERRAL,
  ReferralCreditsService,
  VOUCHER_COST,
} from './referral-credits.service';

/// A tiny in-memory Prisma stand-in. Every method returns a LAZY thenable so
/// `$transaction([...])` only executes an op when it is awaited in order — a
/// rejected op (e.g. dedupeKey collision → P2002) aborts before the next op
/// runs, faithfully modelling the atomic earn/decrement the service relies on.
function lazy<T>(run: () => T) {
  return {
    then(onF: (v: T) => unknown, onR: (e: unknown) => unknown) {
      return Promise.resolve()
        .then(() => run())
        .then(onF, onR);
    },
  };
}

function p2002(): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
    code: 'P2002',
    clientVersion: 'test',
  });
}

interface Setup {
  profiles: Map<string, { reviewCredits: number }>;
  referralsByReferee: Map<string, { id: string; referrerId: string }>;
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

function makeService(setup: Setup): ReferralCreditsService {
  const { profiles, referralsByReferee, caseCountByUser, txns } = setup;
  const dedupeKeys = new Set(txns.map((t) => t.dedupeKey));

  const db: any = {
    referral: {
      findUnique: ({ where }: any) =>
        lazy(() => referralsByReferee.get(where.refereeProfileId) ?? null),
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
          if (dedupeKeys.has(data.dedupeKey)) throw p2002();
          dedupeKeys.add(data.dedupeKey);
          txns.push({ ...data, createdAt: new Date() });
          return { ...data };
        }),
      findUnique: ({ where }: any) =>
        lazy(() => txns.find((t) => t.dedupeKey === where.dedupeKey) ?? null),
      findMany: ({ where }: any) =>
        lazy(() =>
          txns
            .filter((t) => t.profileId === where.profileId)
            .map((t) => ({
              amount: t.amount,
              reason: t.reason,
              createdAt: t.createdAt,
            })),
        ),
    },
    userProfile: {
      findUnique: ({ where }: any) =>
        lazy(() => {
          const prof = profiles.get(where.id);
          return prof ? { reviewCredits: prof.reviewCredits } : null;
        }),
      update: ({ where, data }: any) =>
        lazy(() => {
          const prof = profiles.get(where.id)!;
          prof.reviewCredits += data.reviewCredits.increment;
          return { reviewCredits: prof.reviewCredits };
        }),
      updateMany: ({ where, data }: any) =>
        lazy(() => {
          const prof = profiles.get(where.id);
          if (prof && prof.reviewCredits >= where.reviewCredits.gte) {
            prof.reviewCredits -= data.reviewCredits.decrement;
            return { count: 1 };
          }
          return { count: 0 };
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

  return new ReferralCreditsService(prisma);
}

function emptySetup(): Setup {
  return {
    profiles: new Map(),
    referralsByReferee: new Map(),
    caseCountByUser: new Map(),
    txns: [],
  };
}

describe('ReferralCreditsService — crediting (earn)', () => {
  it('does nothing when the referee was never referred', async () => {
    const s = emptySetup();
    s.caseCountByUser.set('referee', 1);
    const svc = makeService(s);
    await svc.creditReferrerForFirstCase('referee');
    expect(s.txns).toHaveLength(0);
  });

  it('does nothing on the 2nd+ case (only the first case earns)', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referralsByReferee.set('referee', { id: 'R1', referrerId: 'ref' });
    s.caseCountByUser.set('referee', 2);
    const svc = makeService(s);
    await svc.creditReferrerForFirstCase('referee');
    expect(s.profiles.get('ref')!.reviewCredits).toBe(0);
    expect(s.txns).toHaveLength(0);
  });

  it('credits the referrer once on the first case', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referralsByReferee.set('referee', { id: 'R1', referrerId: 'ref' });
    s.caseCountByUser.set('referee', 1);
    const svc = makeService(s);
    await svc.creditReferrerForFirstCase('referee');
    expect(s.profiles.get('ref')!.reviewCredits).toBe(CREDITS_PER_REFERRAL);
    expect(s.txns).toHaveLength(1);
    expect(s.txns[0].dedupeKey).toBe('firstcase:R1');
    expect(s.txns[0].amount).toBe(CREDITS_PER_REFERRAL);
  });

  it('is idempotent — a second call never double-credits', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referralsByReferee.set('referee', { id: 'R1', referrerId: 'ref' });
    s.caseCountByUser.set('referee', 1);
    const svc = makeService(s);
    await svc.creditReferrerForFirstCase('referee');
    await svc.creditReferrerForFirstCase('referee');
    expect(s.profiles.get('ref')!.reviewCredits).toBe(CREDITS_PER_REFERRAL);
    expect(s.txns).toHaveLength(1);
  });

  it('does not credit a case filed before the referral existed', async () => {
    const s = emptySetup();
    s.profiles.set('ref', { reviewCredits: 0 });
    s.referralsByReferee.set('referee', {
      id: 'R1',
      referrerId: 'ref',
      // Referral recorded after the (2099) first case of the fixture.
      createdAt: new Date('2100-01-01T00:00:00Z'),
    } as any);
    s.caseCountByUser.set('referee', 1);
    const svc = makeService(s);
    expect(await svc.creditReferrerForFirstCase('referee')).toBe(false);
    expect(s.txns).toHaveLength(0);
  });
});

describe('ReferralCreditsService — redeem (spend)', () => {
  it('reads the balance and history', async () => {
    const s = emptySetup();
    s.profiles.set('me', { reviewCredits: 3 });
    s.txns.push({
      profileId: 'me',
      amount: 1,
      reason: 'referralFirstCase',
      dedupeKey: 'firstcase:R1',
      metadata: {},
      createdAt: new Date(),
    });
    const svc = makeService(s);
    const out = await svc.getCredits('me');
    expect(out.balance).toBe(3);
    expect(out.history).toHaveLength(1);
  });

  it('refuses to redeem with insufficient credits (balance never goes negative)', async () => {
    const s = emptySetup();
    s.profiles.set('me', { reviewCredits: 0 });
    const svc = makeService(s);
    const out = await svc.redeemReviewVoucher('me', 'tap-1');
    expect(out).toEqual({ ok: false, reason: 'insufficient' });
    expect(s.profiles.get('me')!.reviewCredits).toBe(0);
    expect(s.txns).toHaveLength(0);
  });

  it('spends a credit and mints a voucher code', async () => {
    const s = emptySetup();
    s.profiles.set('me', { reviewCredits: 1 });
    const svc = makeService(s);
    const out = await svc.redeemReviewVoucher('me', 'tap-1');
    expect(out.ok).toBe(true);
    if (out.ok) {
      expect(out.balance).toBe(1 - VOUCHER_COST);
      expect(out.voucherCode).toMatch(/^KPB-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
    }
    expect(s.txns).toHaveLength(1);
    expect(s.txns[0].amount).toBe(-VOUCHER_COST);
  });

  it('is idempotent per clientRef — a retried tap returns the same voucher, spends once', async () => {
    const s = emptySetup();
    s.profiles.set('me', { reviewCredits: 1 });
    const svc = makeService(s);
    const first = await svc.redeemReviewVoucher('me', 'tap-1');
    const second = await svc.redeemReviewVoucher('me', 'tap-1');
    expect(first.ok && second.ok).toBe(true);
    if (first.ok && second.ok) {
      expect(second.voucherCode).toBe(first.voucherCode);
    }
    expect(s.profiles.get('me')!.reviewCredits).toBe(0);
    expect(s.txns).toHaveLength(1);
  });

  it('scopes the clientRef per user — a shared clientRef never replays another user\'s voucher', async () => {
    const s = emptySetup();
    s.profiles.set('alice', { reviewCredits: 1 });
    s.profiles.set('bob', { reviewCredits: 1 });
    const svc = makeService(s);
    const a = await svc.redeemReviewVoucher('alice', 'shared-ref');
    const b = await svc.redeemReviewVoucher('bob', 'shared-ref');
    expect(a.ok && b.ok).toBe(true);
    if (a.ok && b.ok) {
      // Bob mints his OWN voucher and spends his OWN credit — not Alice's.
      expect(b.voucherCode).not.toBe(a.voucherCode);
    }
    expect(s.profiles.get('alice')!.reviewCredits).toBe(0);
    expect(s.profiles.get('bob')!.reviewCredits).toBe(0);
    expect(s.txns).toHaveLength(2);
  });
});
