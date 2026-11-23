import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { OrientationService } from './orientation.service';
import { ORIENTATION_FIELDS } from './orientation-fields.data';

/** Sortie bien formée du modèle : une explication par filière. */
function validLlmOutput() {
  return {
    data: {
      recommendations: ORIENTATION_FIELDS.map((field) => ({
        fieldId: field.id,
        explanationFr: `Explication ${field.id}.`,
        explanationEn: `Explanation ${field.id}.`,
      })),
    },
    model: 'test-model',
    billed: true,
  };
}

describe('OrientationService', () => {
  let service: OrientationService;
  let tryExecute: jest.Mock;

  beforeEach(async () => {
    tryExecute = jest.fn(async () => null);
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrientationService,
        {
          provide: LlmService,
          useValue: {
            completeJson: jest.fn(async () => validLlmOutput()),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            tryExecute,
          },
        },
      ],
    }).compile();

    service = module.get<OrientationService>(OrientationService);
  });

  /**
   * The answer set that used to publish "160 %" on two cards at once. The
   * percentages asserted here are the ones the Flutter engine computes for the
   * same answers — see `orientation-scorer.spec.ts` for the full parity suite.
   */
  const COLLIDING_ANSWERS = {
    interests: ['tech'],
    strengths: ['analysis'],
    goal: ['global_job'],
    environment: ['office'],
    level: ['bac3'],
    ai_concern: ['ai_yes'],
    languages: ['lang_fr'],
    avoid: ['avoid_desk'],
    budget_band: ['budget_low'],
    mobility: ['mobility_yes'],
  };

  it('returns ranked recommendations for M4 answer ids', async () => {
    const session = await service.createSession({
      answers: {
        interests: ['tech'],
        ai_concern: ['ai_yes'],
      },
      profile: { fullName: 'Aminata Diallo' },
    });

    expect(session.recommendations.length).toBeGreaterThan(0);
    expect(session.recommendations[0].fieldId).toMatch(/^d\d{2}$/);
    expect(session.recommendations[0].iaResilience).toBeDefined();
    // Same answers, same percentages as the Flutter engine.
    expect(
      session.recommendations.map((rec) => [rec.fieldId, rec.score]),
    ).toEqual([
      ['d01', 98],
      ['d05', 63],
      ['d03', 42],
      ['d04', 28],
      ['d07', 28],
    ]);
  });

  it('publishes percentages, not raw points, and never ties the top two', async () => {
    const session = await service.createSession({
      answers: COLLIDING_ANSWERS,
      profile: { fullName: 'Aminata Diallo' },
    });

    for (const rec of session.recommendations) {
      expect(rec.score).toBeGreaterThanOrEqual(0);
      expect(rec.score).toBeLessThanOrEqual(100);
    }
    // Used to be 160 for both d01 and d03, floored at 55 for everything weak.
    expect(session.recommendations.map((rec) => rec.score)).toEqual([
      87, 80, 41, 37, 17,
    ]);
    expect(session.recommendations[0].score).not.toBe(
      session.recommendations[1].score,
    );
  });

  it('falls back to the declared profile fields when nothing scores', async () => {
    const session = await service.createSession({
      answers: {},
      profile: { fullName: 'Aminata Diallo', fieldIds: ['d07', 'd02', 'd07'] },
    });

    expect(session.recommendations.map((rec) => [rec.fieldId, rec.score])).toEqual([
      ['d02', 55],
      ['d07', 55],
    ]);
  });

  function persistedSession(recommendations: unknown[]) {
    return {
      id: 'legacy-1',
      userId: 'student-1',
      completedAt: new Date('2026-07-01T10:00:00.000Z'),
      answers: COLLIDING_ANSWERS,
      recommendations,
      iaModelUsed: 'legacy',
      nextActions: null,
    };
  }

  type PublicSession = {
    recommendations: Array<{ fieldId: string; score: number }>;
  };

  it('re-scores and re-ranks a session persisted with the old raw-points scale', async () => {
    // A session written before the fix: `rawPoints * 10`, floored at 55, and
    // ordered on AI resilience before the score (d03 ahead of d01 while both
    // read "160 %").
    tryExecute.mockImplementationOnce(async () =>
      persistedSession([
        { fieldId: 'd03', score: 160 },
        { fieldId: 'd01', score: 160 },
        { fieldId: 'd02', score: 55 },
        { fieldId: 'd12', score: 55 },
      ]),
    );

    const session = (await service.getResults(
      'legacy-1',
      'student-1',
    )) as unknown as PublicSession;

    expect(session.recommendations.map((rec) => [rec.fieldId, rec.score])).toEqual([
      ['d01', 87],
      ['d03', 80],
      ['d02', 41],
      ['d12', 17],
    ]);
  });

  it('clamps — and keeps the stored order for — a score it cannot recompute', async () => {
    tryExecute.mockImplementationOnce(async () =>
      persistedSession([
        { fieldId: 'd01', score: 160 },
        { fieldId: 'zz9', score: 420 },
      ]),
    );

    const session = (await service.getResults(
      'legacy-1',
      'student-1',
    )) as unknown as PublicSession;

    expect(session.recommendations.map((rec) => [rec.fieldId, rec.score])).toEqual([
      ['d01', 87],
      // Not scorable from the answers: clamped instead of leaking 420 %.
      ['zz9', 100],
    ]);
  });

  it('throws NotFoundException for unknown session ID', async () => {
    await expect(
      service.getResults('invalid-id', 'student-1'),
    ).rejects.toThrow(NotFoundException);
  });

  it('scopes persisted result lookup to the authenticated owner', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    tryExecute.mockImplementationOnce(async (callback) =>
      callback({ orientationSession: { findFirst } }),
    );

    await expect(
      service.getResults('session-1', 'student-1'),
    ).rejects.toThrow(NotFoundException);
    expect(findFirst).toHaveBeenCalledWith({
      where: { id: 'session-1', userId: 'student-1' },
    });
  });
});
