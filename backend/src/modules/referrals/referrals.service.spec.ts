import { ForbiddenException, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { ReferralsService } from './referrals.service';

/**
 * Guards the referral attribution loop (KPB-69): stable code generation,
 * derived stats, and safe redemption (no self-referral, single attribution).
 */
describe('ReferralsService', () => {
  function makeService(opts: {
    profile?: { referralCode: string | null } | null;
    referrerByCode?: { id: string } | null;
    existingReferral?: { referrerId: string } | null;
    signedUp?: number;
    caseCreated?: number;
    reverseReferral?: { id: string } | null;
    existingCases?: number;
  }) {
    const calls = { created: 0, updated: 0 };
    const db = {
      userProfile: {
        findUnique: async ({
          where,
        }: {
          where: { id?: string; referralCode?: string };
        }) => {
          if (where.referralCode !== undefined) return opts.referrerByCode ?? null;
          return opts.profile ?? null;
        },
        update: async ({ data }: { data: { referralCode: string } }) => {
          calls.updated += 1;
          return { referralCode: data.referralCode };
        },
      },
      referral: {
        count: async ({ where }: { where: { referee?: unknown } }) =>
          where.referee ? (opts.caseCreated ?? 0) : (opts.signedUp ?? 0),
        findUnique: async () => opts.existingReferral ?? null,
        findFirst: async () => opts.reverseReferral ?? null,
        create: async () => {
          calls.created += 1;
          return {};
        },
      },
      case: { count: async () => opts.existingCases ?? 0 },
    };
    const prisma = {
      execute: async (fn: (c: typeof db) => unknown) => fn(db),
    } as unknown as PrismaService;
    return { service: new ReferralsService(prisma), calls };
  }

  it('returns an existing code with derived stats', async () => {
    const { service } = makeService({
      profile: { referralCode: 'ABC12345' },
      signedUp: 3,
      caseCreated: 1,
    });
    expect(await service.getMine('u1')).toEqual({
      code: 'ABC12345',
      signedUpCount: 3,
      caseCreatedCount: 1,
    });
  });

  it('generates + persists a code on first read', async () => {
    const { service, calls } = makeService({ profile: { referralCode: null } });
    const out = await service.getMine('u1');
    expect(out.code).toMatch(/^[A-Z2-9]{8}$/);
    expect(calls.updated).toBe(1);
  });

  it('attributes a valid redemption', async () => {
    const { service, calls } = makeService({
      referrerByCode: { id: 'r1' },
      existingReferral: null,
    });
    expect(await service.redeem('u2', 'code1234')).toEqual({
      attributed: true,
      alreadyReferred: false,
    });
    expect(calls.created).toBe(1);
  });

  it('rejects using your own code', async () => {
    const { service } = makeService({ referrerByCode: { id: 'u1' } });
    await expect(service.redeem('u1', 'mycode12')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('rejects an unknown code', async () => {
    const { service } = makeService({ referrerByCode: null });
    await expect(service.redeem('u2', 'nope1234')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('is idempotent — never re-attributes an already-referred user', async () => {
    const { service, calls } = makeService({
      referrerByCode: { id: 'r1' },
      existingReferral: { referrerId: 'r1' },
    });
    const out = await service.redeem('u2', 'code1234');
    expect(out.alreadyReferred).toBe(true);
    expect(calls.created).toBe(0);
  });

  it('refuses a mutual referral (A refers B, then B refers A)', async () => {
    const { service, calls } = makeService({
      referrerByCode: { id: 'u2' },
      reverseReferral: { id: 'r-1' },
    });
    await expect(service.redeem('u1', 'abc12345')).rejects.toThrow('Mutual');
    expect(calls.created).toBe(0);
  });

  it('refuses a code redeemed after the first request', async () => {
    const { service, calls } = makeService({
      referrerByCode: { id: 'u2' },
      existingCases: 1,
    });
    await expect(service.redeem('u1', 'abc12345')).rejects.toThrow('first request');
    expect(calls.created).toBe(0);
  });
});
