import type { AiQuotaService } from '../ai/ai-quota.service';
import type { PassService } from '../pass/pass.service';
import { CoachQuotaService, PASS_COACH_DAILY_LIMIT } from './coach-quota.service';

const NOW = new Date('2026-11-22T10:00:00Z');

function fakeQuota() {
  const calls: Array<{ op: string; feature: string; period?: string; limit?: number }> = [];
  const decision = (limit: number) => ({
    allowed: true,
    limit,
    remaining: limit - 1,
    resetsAt: new Date('2026-11-23T00:00:00Z'),
  });
  const quota = {
    peek: jest.fn(async (input: { feature: string; period: string; limit: number }) => {
      calls.push({ op: 'peek', ...input });
      return decision(input.limit);
    }),
    consume: jest.fn(async (input: { feature: string; period: string; limit: number }) => {
      calls.push({ op: 'consume', ...input });
      return decision(input.limit);
    }),
    refund: jest.fn(async (input: { feature: string; period: string }) => {
      calls.push({ op: 'refund', ...input });
    }),
  };
  return { quota: quota as unknown as AiQuotaService, calls };
}

const pass = (active: boolean | Error) =>
  ({
    hasActivePass: jest.fn(async () => {
      if (active instanceof Error) throw active;
      return active;
    }),
  }) as unknown as PassService;

describe('CoachQuotaService et Pass Karatou', () => {
  it('sans Pass : 5 messages par semaine, compteur « coach »', async () => {
    const { quota, calls } = fakeQuota();
    const service = new CoachQuotaService(quota, undefined, pass(false));
    const view = await service.getQuota('u1', NOW);
    expect(view).toMatchObject({ quotaLimit: 5, unlimited: false });
    expect(calls[0]).toMatchObject({ feature: 'coach', period: 'week', limit: 5 });
  });

  it('avec un Pass actif : illimité, sous le garde-fou du jour, compteur séparé', async () => {
    const { quota, calls } = fakeQuota();
    const service = new CoachQuotaService(quota, undefined, pass(true));
    const consumed = await service.consume('u1', NOW);
    expect(consumed).toMatchObject({
      allowed: true,
      unlimited: true,
      bucket: { feature: 'coach_pass', period: 'day' },
    });
    expect(calls[0]).toMatchObject({ limit: PASS_COACH_DAILY_LIMIT });
    expect((await service.getQuota('u1', NOW)).unlimited).toBe(true);
  });

  it('rembourse le compteur réellement décompté', async () => {
    const { quota, calls } = fakeQuota();
    const service = new CoachQuotaService(quota, undefined, pass(true));
    const consumed = await service.consume('u1', NOW);
    await service.refund('u1', NOW, consumed.bucket);
    expect(calls[1]).toMatchObject({ op: 'refund', feature: 'coach_pass', period: 'day' });
  });

  it('une panne de lecture du Pass retombe sur le quota gratuit, sans bloquer', async () => {
    const { quota } = fakeQuota();
    const service = new CoachQuotaService(quota, undefined, pass(new Error('db down')));
    await expect(service.consume('u1', NOW)).resolves.toMatchObject({
      allowed: true,
      unlimited: false,
      bucket: { feature: 'coach', period: 'week' },
    });
  });

  it('sans service Pass (tests existants) : quota gratuit', async () => {
    const { quota } = fakeQuota();
    await expect(new CoachQuotaService(quota).getQuota('u1', NOW)).resolves.toMatchObject({
      unlimited: false,
    });
  });
});
