import { Logger } from '@nestjs/common';

import {
  LlmService,
  LlmUnavailableError,
  StructuredCompletionRequest,
} from './llm.service';

type Diagnostic = {
  strength: string;
  priorityImprovement: string;
  rationale: string;
  nextAction: string;
};

const fallback: Diagnostic = {
  strength: 'Ton dossier est commencé.',
  priorityImprovement: 'Complète la prochaine étape de ta checklist.',
  rationale: 'Cette action est vérifiable sans analyse automatique.',
  nextAction: 'Ouvre ton atelier et termine une étape.',
};

const request: StructuredCompletionRequest<Diagnostic> = {
  feature: 'success_lab_diagnostic',
  attemptKey: 'attempt-1',
  system: 'Give one bounded application improvement.',
  user: 'Verified application context.',
  responseSchema: {
    type: 'object',
    properties: {
      strength: { type: 'string' },
      priorityImprovement: { type: 'string' },
      rationale: { type: 'string' },
      nextAction: { type: 'string' },
    },
    required: ['strength', 'priorityImprovement', 'rationale', 'nextAction'],
    additionalProperties: false,
  },
  validate: (value): value is Diagnostic =>
    Boolean(
      value &&
      typeof value === 'object' &&
      typeof (value as Diagnostic).strength === 'string' &&
      typeof (value as Diagnostic).priorityImprovement === 'string' &&
      typeof (value as Diagnostic).rationale === 'string' &&
      typeof (value as Diagnostic).nextAction === 'string',
    ),
  fallback,
  temperature: 0.1,
  maxTokens: 220,
  promptVersion: 'success-lab-v1',
  model: 'openai/gpt-oss-20b',
};

const PROVIDER_ENV_VARS = [
  'LLM_API_KEY',
  'LLM_PROVIDER',
  'LLM_MODEL',
  'LLM_CHAT_COMPLETIONS_URL',
  'GROQ_API_KEY',
  'GROQ_MODEL',
] as const;

describe('LlmService.completeStructured', () => {
  const previousEnv = Object.fromEntries(
    PROVIDER_ENV_VARS.map((name) => [name, process.env[name]]),
  );
  const originalFetch = global.fetch;

  beforeEach(() => {
    for (const name of PROVIDER_ENV_VARS) delete process.env[name];
  });

  afterEach(() => {
    global.fetch = originalFetch;
    for (const name of PROVIDER_ENV_VARS) {
      const value = previousEnv[name];
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  });

  it('fails closed to the deterministic result when no provider is configured', async () => {
    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        data: fallback,
        provider: 'local',
        model: 'local-fallback',
        outcome: 'fallback',
        fallbackReason: 'provider_unconfigured',
      }),
    );
  });

  it('returns only a whole JSON document that passes runtime validation', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    const data: Diagnostic = {
      strength: 'Objectif clair',
      priorityImprovement: 'Ajouter une preuve chiffrée',
      rationale: 'Le critère leadership demande des résultats démontrables.',
      nextAction: 'Ajoute un résultat mesurable à ton premier exemple.',
    };
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          id: 'provider-1',
          choices: [{ message: { content: JSON.stringify(data) } }],
          usage: {
            prompt_tokens: 110,
            completion_tokens: 45,
            total_tokens: 155,
            prompt_tokens_details: { cached_tokens: 10 },
          },
        }),
        { status: 200 },
      ),
    );

    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        data,
        provider: 'groq',
        model: 'openai/gpt-oss-20b',
        providerRequestId: 'provider-1',
        inputTokens: 110,
        cachedInputTokens: 10,
        outputTokens: 45,
        totalTokens: 155,
        outcome: 'success',
      }),
    );
    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        body: expect.stringContaining('"strict":true'),
      }),
    );
  });

  it('routes through OpenRouter with no-retention pinning when LLM_API_KEY is set', async () => {
    process.env.LLM_API_KEY = 'openrouter-key';
    const data: Diagnostic = {
      strength: 'Objectif clair',
      priorityImprovement: 'Ajouter une preuve chiffrée',
      rationale: 'Le critère leadership demande des résultats démontrables.',
      nextAction: 'Ajoute un résultat mesurable à ton premier exemple.',
    };
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          id: 'provider-2',
          choices: [{ message: { content: JSON.stringify(data) } }],
        }),
        { status: 200 },
      ),
    );

    await expect(
      new LlmService().completeStructured({
        ...request,
        model: 'deepseek/deepseek-v4-flash',
      }),
    ).resolves.toEqual(
      expect.objectContaining({
        data,
        provider: 'openrouter',
        model: 'deepseek/deepseek-v4-flash',
        outcome: 'success',
      }),
    );

    const [url, init] = (global.fetch as jest.Mock).mock.calls[0] as [
      string,
      RequestInit,
    ];
    expect(url).toBe('https://openrouter.ai/api/v1/chat/completions');
    const body = JSON.parse(init.body as string) as Record<string, unknown>;
    expect(body.provider).toEqual({
      zdr: true,
      data_collection: 'deny',
      require_parameters: true,
    });
    // Strict schema on OpenRouter regardless of model family.
    expect(JSON.stringify(body)).toContain('"strict":true');
    expect((init.headers as Record<string, string>).authorization).toBe(
      'Bearer openrouter-key',
    );
  });

  it('keeps the legacy Groq path (no routing block) when only GROQ_API_KEY is set', async () => {
    process.env.GROQ_API_KEY = 'groq-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(JSON.stringify({ choices: [] }), { status: 200 }),
    );

    await new LlmService().completeStructured(request);

    const [url, init] = (global.fetch as jest.Mock).mock.calls[0] as [
      string,
      RequestInit,
    ];
    expect(url).toBe('https://api.groq.com/openai/v1/chat/completions');
    const body = JSON.parse(init.body as string) as Record<string, unknown>;
    expect(body.provider).toBeUndefined();
  });

  it('prefers the LLM_* configuration over a lingering GROQ_API_KEY', async () => {
    process.env.LLM_API_KEY = 'openrouter-key';
    process.env.GROQ_API_KEY = 'groq-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(JSON.stringify({ choices: [] }), { status: 200 }),
    );

    const service = new LlmService();
    expect(service.providerName).toBe('openrouter');
    await service.completeStructured(request);
    expect((global.fetch as jest.Mock).mock.calls[0][0]).toBe(
      'https://openrouter.ai/api/v1/chat/completions',
    );
  });

  it('does not extract a JSON-looking substring from an invalid response', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          choices: [
            {
              message: {
                content: `Here is the result: ${JSON.stringify(fallback)}`,
              },
            },
          ],
        }),
        { status: 200 },
      ),
    );

    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        data: fallback,
        outcome: 'error',
        fallbackReason: 'provider_invalid_json',
      }),
    );
  });

  it('rejects valid JSON that does not satisfy the application schema', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: '{"strength":"only one key"}' } }],
        }),
        { status: 200 },
      ),
    );

    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        outcome: 'error',
        fallbackReason: 'provider_schema_mismatch',
      }),
    );
  });

  it('never logs provider error bodies that can echo student content', async () => {
    process.env.LLM_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        'student@example.test passport-123 secret-access-token',
        { status: 400 },
      ),
    );
    const service = new LlmService();
    const warn = jest.fn();
    Object.defineProperty(service, 'logger', { value: { warn } });

    await service.completeJson({
      system: 'system',
      user: 'private student content',
      fallback,
    });

    const output = JSON.stringify(warn.mock.calls);
    expect(output).toContain('openrouter error 400');
    expect(output).not.toContain('student@example.test');
    expect(output).not.toContain('passport-123');
    expect(output).not.toContain('secret-access-token');
  });

  it('never logs raw provider exceptions', async () => {
    process.env.LLM_API_KEY = 'test-key';
    global.fetch = jest
      .fn()
      .mockRejectedValue(
        new Error('student@example.test Authorization Bearer secret-token'),
      );
    const service = new LlmService();
    const warn = jest.fn();
    Object.defineProperty(service, 'logger', { value: { warn } });

    await service.completeJson({
      system: 'system',
      user: 'private student content',
      fallback,
    });

    const output = JSON.stringify(warn.mock.calls);
    expect(output).toContain('openrouter call failed');
    expect(output).not.toContain('student@example.test');
    expect(output).not.toContain('secret-token');
  });
});

describe('LlmService.completeJson', () => {
  const ENV = [...PROVIDER_ENV_VARS, 'LLM_REASONING_ENABLED', 'LLM_TIMEOUT_MS'];
  const previousEnv = Object.fromEntries(
    ENV.map((name) => [name, process.env[name]]),
  );
  const originalFetch = global.fetch;
  const params = {
    system: 'Personnalise la lettre.',
    user: 'Domaine : Informatique',
    maxTokens: 1500,
    fallback: { fr: 'MODELE', en: 'MODELE' },
  };
  const okResponse = () =>
    new Response(
      JSON.stringify({
        choices: [
          {
            finish_reason: 'stop',
            message: { content: '{"fr":"Lettre","en":"Letter"}' },
          },
        ],
      }),
      { status: 200 },
    );

  beforeEach(() => {
    for (const name of ENV) delete process.env[name];
  });

  afterEach(() => {
    jest.restoreAllMocks();
    global.fetch = originalFetch;
    for (const name of ENV) {
      const value = previousEnv[name];
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  });

  const sentBody = () =>
    JSON.parse(
      ((global.fetch as jest.Mock).mock.calls[0] as [string, RequestInit])[1]
        .body as string,
    ) as Record<string, unknown>;

  it('disables hidden reasoning on OpenRouter so it cannot eat max_tokens', async () => {
    process.env.LLM_API_KEY = 'openrouter-key';
    global.fetch = jest.fn().mockResolvedValue(okResponse());

    await expect(new LlmService().completeJson(params)).resolves.toEqual({
      data: { fr: 'Lettre', en: 'Letter' },
      model: 'deepseek/deepseek-v4-flash',
    });
    expect(sentBody().reasoning).toEqual({ enabled: false });
  });

  it('lets ops restore the provider reasoning default', async () => {
    process.env.LLM_API_KEY = 'openrouter-key';
    process.env.LLM_REASONING_ENABLED = 'true';
    global.fetch = jest.fn().mockResolvedValue(okResponse());

    await new LlmService().completeJson(params);
    expect(sentBody()).not.toHaveProperty('reasoning');
  });

  it('sends no OpenRouter-only reasoning field to Groq', async () => {
    process.env.GROQ_API_KEY = 'groq-key';
    global.fetch = jest.fn().mockResolvedValue(okResponse());

    await new LlmService().completeJson(params);
    expect(sentBody()).not.toHaveProperty('reasoning');
  });

  it('reports a max_tokens truncation instead of degrading silently', async () => {
    process.env.LLM_API_KEY = 'openrouter-key';
    const warn = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => undefined);
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          choices: [{ finish_reason: 'length', message: { content: '{"fr":"Lettre tronq' } }],
          usage: { completion_tokens: 1500 },
        }),
        { status: 200 },
      ),
    );

    await expect(new LlmService().completeJson(params)).resolves.toEqual({
      data: params.fallback,
      model: 'local-fallback',
    });
    expect(warn).toHaveBeenCalledWith(
      expect.stringContaining('truncated at max_tokens'),
    );
  });

  it('honours a per-call timeout longer than the env default', async () => {
    process.env.LLM_API_KEY = 'openrouter-key';
    process.env.LLM_TIMEOUT_MS = '20';
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    // Answers after 60 ms, but gives up as soon as the caller aborts.
    global.fetch = jest.fn(
      (_url: string, init: RequestInit) =>
        new Promise<Response>((resolve, reject) => {
          const timer = setTimeout(() => resolve(okResponse()), 60);
          init.signal?.addEventListener('abort', () => {
            clearTimeout(timer);
            const error = new Error('aborted');
            error.name = 'AbortError';
            reject(error);
          });
        }),
    ) as unknown as typeof fetch;

    // Env default (20 ms) aborts both attempts: the harness CAN fail.
    await expect(new LlmService().completeJson(params)).resolves.toEqual({
      data: params.fallback,
      model: 'local-fallback',
    });
    // The per-call budget lets the same slow provider answer.
    await expect(
      new LlmService().completeJson({ ...params, timeoutMs: 500 }),
    ).resolves.toEqual({
      data: { fr: 'Lettre', en: 'Letter' },
      model: 'deepseek/deepseek-v4-flash',
    });
  });
});

// Audit avant la 59 : quand le fournisseur ne répondait pas, le flux rendait sa
// phrase de panne comme une réponse. Le coach la gardait dans l'historique et
// décomptait un message. Il demande maintenant au service de LEVER.
describe('LlmService.streamText — fournisseur en panne', () => {
  const previousEnv = Object.fromEntries(
    PROVIDER_ENV_VARS.map((name) => [name, process.env[name]]),
  );
  const originalFetch = global.fetch;

  beforeEach(() => {
    for (const name of PROVIDER_ENV_VARS) delete process.env[name];
    process.env.GROQ_API_KEY = 'test-key';
    global.fetch = jest
      .fn()
      .mockResolvedValue({ ok: false, status: 400, text: async () => '' });
  });

  afterEach(() => {
    global.fetch = originalFetch;
    for (const name of PROVIDER_ENV_VARS) {
      const value = previousEnv[name];
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  });

  const collect = async (throwOnUnavailable?: boolean) => {
    const chunks: string[] = [];
    for await (const chunk of new LlmService().streamText({
      system: 'sys',
      messages: [{ role: 'user', content: 'Bonjour' }],
      lang: 'fr',
      throwOnUnavailable,
    })) {
      chunks.push(chunk);
    }
    return chunks;
  };

  it('par défaut, rend la phrase de repli (appelants historiques)', async () => {
    const chunks = await collect();
    expect(chunks).toHaveLength(1);
    expect(chunks[0].length).toBeGreaterThan(10);
  });

  it('avec throwOnUnavailable, lève LlmUnavailableError sans rien rendre', async () => {
    await expect(collect(true)).rejects.toBeInstanceOf(LlmUnavailableError);
  });
});
