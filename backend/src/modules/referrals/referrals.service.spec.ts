import {
  ForbiddenException,
  HttpException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

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
    /** Ambassadeurs connus : code stocké → ligne. */
    ambassadors?: Array<{ id: string; userProfileId: string; code: string }>;
    lastHourCount?: number;
    deviceTokens?: string[];
    ambassadorReferralConflict?: boolean;
  }) {
    const calls = {
      created: 0,
      updated: 0,
      createdReferral: [] as Array<{ referrerId: string; refereeProfileId: string }>,
      ambassadorReferrals: [] as Array<Record<string, unknown>>,
      ambassadorIncrements: 0,
      signals: [] as Array<Record<string, unknown>>,
      lookedUpCodes: [] as string[],
    };
    const ambassadors = opts.ambassadors ?? [];
    const norm = (c: string) => c.toUpperCase().replace(/[^A-Z0-9]/g, '');
    const db = {
      userProfile: {
        findUnique: async ({
          where,
        }: {
          where: { id?: string; referralCode?: string };
        }) => {
          if (where.referralCode !== undefined) {
            calls.lookedUpCodes.push(where.referralCode);
            return opts.referrerByCode ?? null;
          }
          if (where.id === 'u2') return { fullName: 'fatou sow', referralCode: null };
          return opts.profile ?? null;
        },
        update: async ({ data }: { data: { referralCode: string } }) => {
          calls.updated += 1;
          return { referralCode: data.referralCode };
        },
      },
      ambassador: {
        findUnique: async ({
          where,
        }: {
          where: { userProfileId?: string; codeNormalized?: string };
        }) => {
          if (where.userProfileId !== undefined) {
            return ambassadors.find((a) => a.userProfileId === where.userProfileId) ?? null;
          }
          return ambassadors.find((a) => norm(a.code) === where.codeNormalized) ?? null;
        },
        findFirst: async () => null,
        update: async () => {
          calls.ambassadorIncrements += 1;
          return {};
        },
      },
      ambassadorReferral: {
        create: async ({ data }: { data: Record<string, unknown> }) => {
          if (opts.ambassadorReferralConflict) {
            throw new Prisma.PrismaClientKnownRequestError('dup', {
              code: 'P2002',
              clientVersion: 'test',
            });
          }
          calls.ambassadorReferrals.push(data);
          return data;
        },
      },
      referral: {
        count: async ({ where }: { where: { referee?: unknown; createdAt?: unknown } }) => {
          if (where.createdAt) return opts.lastHourCount ?? 0;
          return where.referee ? (opts.caseCreated ?? 0) : (opts.signedUp ?? 0);
        },
        findUnique: async () => opts.existingReferral ?? null,
        findFirst: async () => opts.reverseReferral ?? null,
        create: async ({ data }: { data: { referrerId: string; refereeProfileId: string } }) => {
          calls.created += 1;
          calls.createdReferral.push(data);
          return {};
        },
      },
      case: { count: async () => opts.existingCases ?? 0 },
      deviceToken: {
        findMany: async () => (opts.deviceTokens ?? []).map((token) => ({ token })),
      },
      referralAttributionSignal: {
        upsert: async ({ create }: { create: Record<string, unknown> }) => {
          calls.signals.push(create);
          return create;
        },
      },
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

  describe('codes unifiés (compétition ambassadeurs)', () => {
    const amb = { id: 'amb-1', userProfileId: 'p-amb', code: 'KTOU-AK-1a2b3c' };

    it('accepte un code ambassadeur mis en majuscules par l’app, et rattache au PROFIL', async () => {
      const { service, calls } = makeService({ ambassadors: [amb] });
      const out = await service.redeem('u2', 'KTOU-AK-1A2B3C');
      expect(out).toEqual({ attributed: true, alreadyReferred: false });
      expect(calls.createdReferral).toEqual([
        { referrerId: 'p-amb', refereeProfileId: 'u2' },
      ]);
      // … et la ligne de l'espace ambassadeur, avec un nom « Prénom I. ».
      expect(calls.ambassadorReferrals).toEqual([
        { ambassadorId: 'amb-1', refereeProfileId: 'u2', refereeName: 'Fatou S.' },
      ]);
      expect(calls.ambassadorIncrements).toBe(1);
    });

    it.each(['ktou-ak-1a2b3c', ' KTOU AK 1A2B3C ', 'KTOUAK1A2B3C', 'ktou_ak.1a2b3c'])(
      'ignore la casse, les espaces et les tirets (%s)',
      async (typed) => {
        const { service, calls } = makeService({ ambassadors: [amb] });
        expect((await service.redeem('u2', typed)).attributed).toBe(true);
        expect(calls.createdReferral[0].referrerId).toBe('p-amb');
      },
    );

    it('normalise aussi un code personnel saisi en minuscules avec tirets', async () => {
      const { service, calls } = makeService({ referrerByCode: { id: 'r1' } });
      await service.redeem('u2', 'k7pq-2mza');
      expect(calls.lookedUpCodes).toEqual(['K7PQ2MZA']);
    });

    it('le code personnel d’un ambassadeur crée aussi la ligne ambassadeur', async () => {
      const { service, calls } = makeService({
        referrerByCode: { id: 'p-amb' },
        ambassadors: [amb],
      });
      await service.redeem('u2', 'K7PQ2MZA');
      expect(calls.createdReferral[0].referrerId).toBe('p-amb');
      expect(calls.ambassadorReferrals).toHaveLength(1);
    });

    it('refuse son propre code ambassadeur', async () => {
      const { service } = makeService({ ambassadors: [amb] });
      await expect(service.redeem('p-amb', 'KTOU-AK-1A2B3C')).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('ne recrée pas une ligne ambassadeur déjà présente (contrainte unique)', async () => {
      const { service, calls } = makeService({
        ambassadors: [amb],
        ambassadorReferralConflict: true,
      });
      expect((await service.redeem('u2', 'KTOU-AK-1A2B3C')).attributed).toBe(true);
      expect(calls.ambassadorIncrements).toBe(0);
    });

    it('plafonne les rattachements par code et par heure (429, rien n’est créé)', async () => {
      const { service, calls } = makeService({ ambassadors: [amb], lastHourCount: 30 });
      const err = await service.redeem('u2', 'KTOU-AK-1A2B3C').catch((e: unknown) => e);
      expect(err).toBeInstanceOf(HttpException);
      expect((err as HttpException).getStatus()).toBe(429);
      expect(calls.created).toBe(0);
    });

    it('relève des empreintes hachées (IP, plage, jeton push), jamais en clair', async () => {
      const { service, calls } = makeService({
        ambassadors: [amb],
        deviceTokens: ['fcm-token-abc'],
      });
      await service.redeem('u2', 'KTOU-AK-1A2B3C', { ip: '::ffff:41.203.10.7' });
      expect(calls.signals).toHaveLength(1);
      const signal = calls.signals[0];
      expect(signal.codeKind).toBe('ambassador');
      expect(signal.referrerProfileId).toBe('p-amb');
      expect(signal.ipHash).toMatch(/^[0-9a-f]{32}$/);
      expect(signal.ipBlockHash).toMatch(/^[0-9a-f]{32}$/);
      expect(signal.deviceHashes).toHaveLength(1);
      expect(JSON.stringify(signal)).not.toContain('41.203');
      expect(JSON.stringify(signal)).not.toContain('fcm-token-abc');
      expect(signal.clientDeviceHash).toBeNull();
    });

    it('un code trop court après normalisation est inconnu', async () => {
      const { service } = makeService({});
      await expect(service.redeem('u2', '- - -')).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
