import { ExecutionContext, HttpException, PayloadTooLargeException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { PrismaService } from '../prisma/prisma.service';
import { AI_QUOTA_KEY, AiQuotaGuard, AiQuotaOptions } from './ai-quota.guard';
import { AiQuotaService, periodBounds } from './ai-quota.service';

/** Fake Prisma qui reproduit l'incrément conditionnel `used < limit`. */
function makeDbPrisma() {
  const rows = new Map<string, { used: number; quotaLimit: number }>();
  const k = (w: any) => `${w.userId}|${w.feature}|${w.periodKey}`;
  const tx = {
    aiQuotaBucket: {
      upsert: async ({ where, create }: any) => {
        const key = k(where.userId_feature_periodKey);
        if (!rows.has(key)) rows.set(key, { used: 0, quotaLimit: create.quotaLimit });
        return rows.get(key);
      },
      updateMany: async ({ where }: any) => {
        const row = rows.get(k(where));
        if (!row || row.used >= where.used.lt) return { count: 0 };
        row.used += 1;
        return { count: 1 };
      },
      findUnique: async ({ where }: any) => rows.get(k(where.userId_feature_periodKey)) ?? null,
    },
  };
  const client = { ...tx, $transaction: async (fn: (t: typeof tx) => unknown) => fn(tx) };
  const prisma = {
    tryExecute: async (fn: (c: typeof client) => unknown) => fn(client),
  } as unknown as PrismaService;
  return { prisma, rows };
}

describe('AiQuotaService', () => {
  const now = new Date('2026-10-14T10:00:00.000Z'); // un mercredi

  it('persists usage and refuses beyond the limit', async () => {
    const { prisma } = makeDbPrisma();
    const service = new AiQuotaService(prisma);
    const results = [];
    for (let i = 0; i < 4; i++) {
      results.push(
        await service.consume({ userId: 'u1', feature: 'tools', limit: 3, now }),
      );
    }
    expect(results.map((r) => r.allowed)).toEqual([true, true, true, false]);
    expect(results.map((r) => r.remaining)).toEqual([2, 1, 0, 0]);

    // Un nouveau service (= redémarrage du process) relit le compteur en base.
    const restarted = new AiQuotaService(prisma);
    const after = await restarted.consume({ userId: 'u1', feature: 'tools', limit: 3, now });
    expect(after.allowed).toBe(false);
  });

  it('keeps users and features independent', async () => {
    const { prisma } = makeDbPrisma();
    const service = new AiQuotaService(prisma);
    await service.consume({ userId: 'u1', feature: 'tools', limit: 1, now });
    expect(
      (await service.consume({ userId: 'u2', feature: 'tools', limit: 1, now })).allowed,
    ).toBe(true);
    expect(
      (await service.consume({ userId: 'u1', feature: 'coach', limit: 1, now })).allowed,
    ).toBe(true);
  });

  it('falls back to memory when the database is unavailable', async () => {
    const prisma = { tryExecute: async () => null } as unknown as PrismaService;
    const service = new AiQuotaService(prisma);
    const a = await service.consume({ userId: 'u1', feature: 'tools', limit: 1, now });
    const b = await service.consume({ userId: 'u1', feature: 'tools', limit: 1, now });
    expect([a.allowed, b.allowed]).toEqual([true, false]);
  });

  it('computes UTC day and Monday-based week periods', () => {
    expect(periodBounds(now, 'day')).toEqual({
      periodKey: '2026-10-14',
      resetsAt: new Date('2026-10-15T00:00:00.000Z'),
    });
    expect(periodBounds(now, 'week')).toEqual({
      periodKey: 'w2026-10-12',
      resetsAt: new Date('2026-10-19T00:00:00.000Z'),
    });
    expect(periodBounds(new Date('2026-10-18T23:00:00.000Z'), 'week').periodKey).toBe(
      'w2026-10-12',
    );
  });
});

describe('AiQuotaGuard', () => {
  const options: AiQuotaOptions = {
    feature: 'tools',
    limitEnv: 'KPB_TEST_AI_QUOTA_UNSET',
    defaultDailyLimit: 1,
    maxBodyBytes: 100,
  };

  function context(body: unknown, withOptions = true): ExecutionContext {
    const handler = () => undefined;
    if (withOptions) Reflect.defineMetadata(AI_QUOTA_KEY, options, handler);
    return {
      getHandler: () => handler,
      getClass: () => class {},
      switchToHttp: () => ({
        getRequest: () => ({ studentUser: { id: 'u1' }, body }),
      }),
    } as unknown as ExecutionContext;
  }

  function makeGuard() {
    const { prisma } = makeDbPrisma();
    return new AiQuotaGuard(new Reflector(), new AiQuotaService(prisma));
  }

  it('lets routes without @AiQuota through', async () => {
    await expect(makeGuard().canActivate(context({}, false))).resolves.toBe(true);
  });

  it('rejects an oversized body before consuming quota', async () => {
    const guard = makeGuard();
    await expect(
      guard.canActivate(context({ text: 'x'.repeat(200) })),
    ).rejects.toBeInstanceOf(PayloadTooLargeException);
    await expect(guard.canActivate(context({ text: 'ok' }))).resolves.toBe(true);
  });

  it('answers 429 with a stable code once the daily quota is spent', async () => {
    const guard = makeGuard();
    await guard.canActivate(context({}));
    const error = await guard.canActivate(context({})).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(HttpException);
    expect((error as HttpException).getStatus()).toBe(429);
    expect((error as HttpException).getResponse()).toMatchObject({
      code: 'ai_daily_quota_reached',
    });
  });
});
