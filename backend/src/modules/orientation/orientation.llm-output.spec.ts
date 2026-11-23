import type { JsonCompletionResult, LlmService } from '../ai/llm.service';
import type { PrismaService } from '../prisma/prisma.service';
import {
  OrientationService,
  parseOrientationLlmOutput,
} from './orientation.service';

/**
 * Audit 22/11/2026, constat 32 : la sortie JSON du modèle n'était pas
 * validée. Un `recommendations` non tableau faisait une 500 (quota consommé),
 * une `explanationFr` non chaîne était enregistrée et rendait la session
 * illisible pour l'app.
 *
 * Toute sortie inexploitable (ou panne) donne, comme avant, la session
 * déterministe enregistrée sous `local-fallback`, en 2xx.
 */

const ANSWERS = { interests: ['tech'], ai_concern: ['ai_yes'] };

function makeService(result: JsonCompletionResult<unknown>) {
  const create = jest.fn(async ({ data }) => ({
    id: 'session-1',
    completedAt: new Date('2026-11-23T10:00:00.000Z'),
    iaModelUsed: data.iaModelUsed,
  }));
  const tryExecute = jest.fn(async (callback) =>
    callback({ orientationSession: { create } }),
  );
  const llm = { completeJson: jest.fn(async () => result) };
  const service = new OrientationService(
    llm as unknown as LlmService,
    { tryExecute } as unknown as PrismaService,
  );
  return { service, create };
}

async function topFieldIds(): Promise<string[]> {
  const { service } = makeService({
    data: {
      recommendations: ['d01', 'd02', 'd03', 'd04', 'd05', 'd06', 'd07', 'd08',
        'd09', 'd10', 'd11', 'd12'].map((fieldId) => ({
        fieldId,
        explanationFr: 'x',
      })),
    },
    model: 'm',
    billed: true,
  });
  const session = await service.createSession({ answers: ANSWERS });
  return session.recommendations.map((rec) => rec.fieldId);
}

describe('parseOrientationLlmOutput', () => {
  it('rejette une sortie sans tableau recommendations', () => {
    expect(parseOrientationLlmOutput(null)).toBeUndefined();
    expect(parseOrientationLlmOutput([])).toBeUndefined();
    expect(
      parseOrientationLlmOutput({ recommendations: { d03: { explanationFr: 'a' } } }),
    ).toBeUndefined();
    expect(parseOrientationLlmOutput({ recommendations: 'd03' })).toBeUndefined();
  });

  it('ignore les éléments mal formés et ne garde que des chaînes', () => {
    const parsed = parseOrientationLlmOutput({
      recommendations: [
        null,
        'd01',
        { fieldId: 42, explanationFr: 'a' },
        { fieldId: 'd02', explanationFr: ['phrase 1', 'phrase 2'] },
        { fieldId: 'd03', explanationFr: { fr: 'a' } },
        { fieldId: 'd04', explanationFr: '   ' },
        { fieldId: 'd05', explanationFr: '  Bien.  ', explanationEn: 7 },
        { fieldId: 'd06', explanationFr: 'Oui.', explanationEn: 'Yes.' },
        { fieldId: 'd06', explanationFr: 'Doublon.' },
      ],
    });
    expect(parsed && Object.fromEntries(parsed)).toEqual({
      d05: { fr: 'Bien.', en: 'Bien.' },
      d06: { fr: 'Oui.', en: 'Yes.' },
    });
  });

  it('tronque une explication démesurée', () => {
    const parsed = parseOrientationLlmOutput({
      recommendations: [{ fieldId: 'd01', explanationFr: 'a'.repeat(5000) }],
    });
    expect(parsed?.get('d01')?.fr).toHaveLength(1000);
  });
});

describe('OrientationService.createSession — sortie du modèle', () => {
  type Stored = {
    iaModelUsed: string;
    recommendations: Array<{
      fieldId: string;
      explanation: { fr: unknown; en: unknown };
    }>;
  };
  const storedOf = (create: jest.Mock) =>
    create.mock.calls[0][0].data as Stored;

  function expectDeterministicFallback(create: jest.Mock, session: {
    iaModelUsed: string | null;
    recommendations: Array<{ explanation: { fr: string } }>;
  }) {
    expect(create).toHaveBeenCalledTimes(1);
    const stored = storedOf(create);
    expect(stored.iaModelUsed).toBe('local-fallback');
    expect(session.iaModelUsed).toBe('local-fallback');
    expect(stored.recommendations.length).toBeGreaterThan(0);
    for (const rec of stored.recommendations) {
      expect(rec.explanation.fr).toEqual(
        expect.stringContaining('ressort fortement'),
      );
    }
  }

  it('plus de 500 : recommendations non tableau => session déterministe enregistrée', async () => {
    const { service, create } = makeService({
      data: { recommendations: { d03: { explanationFr: '...' } } },
      model: 'm',
      billed: true,
    });
    const session = await service.createSession({ answers: ANSWERS });
    expectDeterministicFallback(create, session);
  });

  it('élément null dans recommendations => pas de TypeError', async () => {
    const { service, create } = makeService({
      data: { recommendations: [null, 'd01', 42] },
      model: 'm',
      billed: true,
    });
    const session = await service.createSession({ answers: ANSWERS });
    expectDeterministicFallback(create, session);
  });

  it("n'enregistre jamais une explication non chaîne", async () => {
    const [first, second] = await topFieldIds();
    const { service, create } = makeService({
      data: {
        recommendations: [
          { fieldId: first, explanationFr: ['phrase 1', 'phrase 2'] },
          { fieldId: second, explanationFr: 'Texte valide.' },
        ],
      },
      model: 'm',
      billed: true,
    });
    const session = await service.createSession({ answers: ANSWERS });
    const stored = storedOf(create);
    expect(stored.iaModelUsed).toBe('m');
    for (const rec of [...stored.recommendations, ...session.recommendations]) {
      expect(typeof rec.explanation.fr).toBe('string');
      expect(typeof rec.explanation.en).toBe('string');
    }
    const byId = new Map(stored.recommendations.map((rec) => [rec.fieldId, rec]));
    expect(byId.get(second)?.explanation).toEqual({
      fr: 'Texte valide.',
      en: 'Texte valide.',
    });
    // L'élément invalide garde l'explication déterministe.
    expect(byId.get(first)?.explanation.fr).toContain('ressort fortement');
  });

  it('aucun élément valide pour une filière classée => repli déterministe', async () => {
    const { service, create } = makeService({
      data: { recommendations: [{ fieldId: 'zz9', explanationFr: 'a' }] },
      model: 'm',
      billed: true,
    });
    const session = await service.createSession({ answers: ANSWERS });
    expectDeterministicFallback(create, session);
  });

  it('panne du fournisseur => session déterministe enregistrée, comme avant', async () => {
    for (const result of [
      { fallbackReason: 'provider_http_error', billed: false },
      { fallbackReason: 'provider_unconfigured', billed: false },
      { fallbackReason: 'provider_truncated', billed: true },
    ] as const) {
      const { service, create } = makeService({
        data: null,
        model: 'local-fallback',
        ...result,
      });
      const session = await service.createSession({ answers: ANSWERS });
      expectDeterministicFallback(create, session);
    }
  });
});

describe('OrientationService.getResults — session déjà enregistrée invalide', () => {
  it("rend des chaînes là où la base porte un tableau ou un objet", async () => {
    const tryExecute = jest.fn(async () => ({
      id: 'legacy',
      userId: 'u1',
      completedAt: new Date('2026-11-01T00:00:00.000Z'),
      answers: ANSWERS,
      recommendations: [
        { fieldId: 'd01', score: 80, explanation: { fr: ['a', 'b'], en: 'ok' } },
        { fieldId: 'd02', score: 70, explanation: { fr: 'Bien.', en: { x: 1 } } },
        { fieldId: 'd03', score: 60, explanation: 'texte' },
      ],
      iaModelUsed: 'm',
      nextActions: null,
    }));
    const service = new OrientationService(
      {} as LlmService,
      { tryExecute } as unknown as PrismaService,
    );
    const session = (await service.getResults('legacy', 'u1')) as {
      recommendations: Array<{ fieldId: string; explanation: unknown }>;
    };
    const byId = new Map(
      session.recommendations.map((rec) => [rec.fieldId, rec.explanation]),
    );
    expect(byId.get('d01')).toEqual({ fr: '', en: 'ok' });
    expect(byId.get('d02')).toEqual({ fr: 'Bien.', en: 'Bien.' });
    expect(byId.get('d03')).toEqual({ fr: '', en: '' });
  });
});
