import { MessageEvent, NotFoundException } from '@nestjs/common';
import { Observable } from 'rxjs';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { CoachQuotaService } from './coach-quota.service';
import { COACH_MESSAGE_MAX_LENGTH, CoachService } from './coach.service';

/**
 * Guards the IDOR fix: a coach conversation must only be readable by its owner.
 * Prisma is stubbed to null so the service uses its in-memory conversation path.
 */
describe('CoachService — conversation ownership', () => {
  function makeService(): CoachService {
    const llm = {} as unknown as LlmService;
    const quota = {
      getQuota: () => ({ remaining: 5, limit: 5, allowed: true }),
    } as unknown as CoachQuotaService;
    const prisma = {
      tryExecute: async () => null,
    } as unknown as PrismaService;
    return new CoachService(llm, quota, prisma);
  }

  it('returns messages for the conversation owner', async () => {
    const service = makeService();
    const created = await service.createConversation('user-a', {
      fullName: 'Aïcha',
    });
    const messages = await service.getMessages(created.conversationId, 'user-a');
    expect(messages.length).toBeGreaterThan(0);
  });

  it("rejects another user's conversation as not found", async () => {
    const service = makeService();
    const created = await service.createConversation('user-a', {
      fullName: 'Aïcha',
    });
    await expect(
      service.getMessages(created.conversationId, 'user-b'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

/**
 * Guards the AI-processing consent gate (KPB-66): when the authoritative
 * profile has not opted into AI processing, streamReply must refuse BEFORE any
 * PII reaches the LLM; when it has, the turn proceeds and streams tokens.
 */
describe('CoachService — AI consent gate', () => {
  type Events = Array<Record<string, unknown>>;

  function collect(obs: Observable<MessageEvent>): Promise<Events> {
    return new Promise((resolve) => {
      const events: Events = [];
      obs.subscribe({
        next: (e) => events.push(e.data as Record<string, unknown>),
        complete: () => resolve(events),
      });
    });
  }

  // Prisma stub that runs the caller's callback against a fake client; all
  // tables return null (→ in-memory conversation path) except userProfile,
  // whose consent/birth-date values are parameterized per test.
  function makeService(
    aiConsentedAt: Date | null,
    profileExtra: {
      birthDate?: Date | null;
      guardianConsentedAt?: Date | null;
    } = {},
  ) {
    const llm = {
      // eslint-disable-next-line @typescript-eslint/require-await
      async *streamText() {
        yield 'Je peux ';
        yield 'aider.';
      },
    } as unknown as LlmService;
    const quota = {
      getQuota: () => ({ remaining: 5, limit: 5, allowed: true }),
      consume: () => ({ allowed: true, remaining: 4, limit: 5 }),
    } as unknown as CoachQuotaService;
    const fakeClient = {
      coachConversation: {
        findUnique: async () => null,
        create: async () => null,
        update: async () => null,
      },
      coachMessage: { create: async () => null },
      country: { findMany: async () => null },
      scholarship: { findMany: async () => null },
      userProfile: {
        findUnique: async () => ({
          aiConsentedAt,
          birthDate:
            'birthDate' in profileExtra
              ? (profileExtra.birthDate ?? null)
              : new Date('2000-01-01T00:00:00.000Z'),
          guardianConsentedAt: profileExtra.guardianConsentedAt ?? null,
        }),
      },
    };
    const prisma = {
      tryExecute: async (fn: (c: typeof fakeClient) => unknown) => fn(fakeClient),
    } as unknown as PrismaService;
    return new CoachService(llm, quota, prisma);
  }

  it('blocks the turn with ai_consent_required when consent is absent', async () => {
    const service = makeService(null);
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Quel budget pour le Canada ?',
        profile: { preferredLanguage: 'fr' },
      }),
    );
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({
      type: 'error',
      code: 'ai_consent_required',
    });
    // The LLM must never have been reached.
    expect(events.some((e) => e.type === 'token')).toBe(false);
  });

  it('streams the reply once AI consent is present', async () => {
    const service = makeService(new Date());
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Bonjour',
        profile: { preferredLanguage: 'fr' },
      }),
    );
    expect(events.some((e) => e.type === 'token')).toBe(true);
    expect(events.some((e) => e.type === 'done')).toBe(true);
    expect(events.some((e) => e.code === 'ai_consent_required')).toBe(false);
  });

  // ── Bodies malformés : ne doivent jamais faire tomber le process ──────────

  it('streams normally when targetCountryIds is a string instead of an array', async () => {
    const service = makeService(new Date());
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Bonjour',
        profile: { targetCountryIds: 'FR', preferredLanguage: 42 },
      }),
    );
    expect(events.some((e) => e.type === 'done')).toBe(true);
  });

  it('turns an unexpected internal failure into an error event', async () => {
    const service = makeService(new Date());
    const created = await service.createConversation('user-a', {});
    jest
      .spyOn(service as any, 'retrieveContext')
      .mockRejectedValue(new Error('boom'));
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Bonjour',
        profile: {},
      }),
    );
    expect(events.at(-1)).toMatchObject({ type: 'error' });
    expect(JSON.stringify(events)).not.toContain('boom');
  });

  it('rejects an oversized message before reaching the LLM', async () => {
    const service = makeService(new Date());
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'x'.repeat(COACH_MESSAGE_MAX_LENGTH + 1),
        profile: {},
      }),
    );
    expect(events).toEqual([
      expect.objectContaining({ type: 'error', code: 'invalid_message' }),
    ]);
  });

  // ── Guardian consent gate (minors) ─────────────────────────────────────────

  function birthDateYearsAgo(years: number): Date {
    const date = new Date();
    date.setFullYear(date.getFullYear() - years);
    return date;
  }

  it('blocks a minor without guardian consent (guardian_consent_required)', async () => {
    const service = makeService(new Date(), {
      birthDate: birthDateYearsAgo(15),
      guardianConsentedAt: null,
    });
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Bonjour',
        profile: { preferredLanguage: 'fr' },
      }),
    );
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({
      type: 'error',
      code: 'guardian_consent_required',
    });
    expect(events.some((e) => e.type === 'token')).toBe(false);
  });

  it('streams for a minor once guardian consent is recorded', async () => {
    const service = makeService(new Date(), {
      birthDate: birthDateYearsAgo(15),
      guardianConsentedAt: new Date(),
    });
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Bonjour',
        profile: { preferredLanguage: 'fr' },
      }),
    );
    expect(events.some((e) => e.type === 'token')).toBe(true);
    expect(events.some((e) => e.code === 'guardian_consent_required')).toBe(false);
  });

  it('does not require guardian consent for an adult', async () => {
    const service = makeService(new Date(), {
      birthDate: birthDateYearsAgo(25),
      guardianConsentedAt: null,
    });
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Bonjour',
        profile: { preferredLanguage: 'fr' },
      }),
    );
    expect(events.some((e) => e.type === 'token')).toBe(true);
    expect(events.some((e) => e.code === 'guardian_consent_required')).toBe(false);
  });

  it('fails closed when birthDate is unknown', async () => {
    const service = makeService(new Date(), {
      birthDate: null,
      guardianConsentedAt: null,
    });
    const created = await service.createConversation('user-a', {});
    const events = await collect(
      service.streamReply({
        conversationId: created.conversationId,
        userId: 'user-a',
        message: 'Bonjour',
        profile: { preferredLanguage: 'fr' },
      }),
    );
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({
      type: 'error',
      code: 'age_verification_required',
    });
    expect(events.some((e) => e.type === 'token')).toBe(false);
  });
});
