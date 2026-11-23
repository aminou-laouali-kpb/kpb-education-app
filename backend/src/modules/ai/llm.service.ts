import { Injectable, Logger } from '@nestjs/common';

export type LlmMessage = {
  role: 'user' | 'assistant' | 'system';
  content: string;
};
type Lang = 'fr' | 'en';

export type LlmProviderName = 'openrouter' | 'groq';

type ProviderConfig = {
  name: LlmProviderName;
  chatUrl: string;
  apiKey: string;
  model: string;
};

type ProviderChatResponse = {
  id?: string;
  choices?: Array<{
    finish_reason?: string | null;
    message?: { content?: string; refusal?: string | null };
    delta?: { content?: string };
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
    prompt_tokens_details?: { cached_tokens?: number };
  };
};

export type JsonSchema = Readonly<Record<string, unknown>>;

export type StructuredCompletionRequest<T> = {
  feature: 'success_lab_diagnostic';
  attemptKey: string;
  system: string;
  user: string;
  responseSchema: JsonSchema;
  validate: (value: unknown) => value is T;
  fallback: T;
  temperature: number;
  maxTokens: number;
  promptVersion: string;
  model: string;
};

export type StructuredCompletionResult<T> = {
  data: T;
  provider: LlmProviderName | 'local';
  model: string;
  providerRequestId?: string;
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  latencyMs: number;
  outcome: 'success' | 'fallback' | 'refused' | 'error';
  fallbackReason?: string;
};

const OPENROUTER_CHAT_URL = 'https://openrouter.ai/api/v1/chat/completions';
const GROQ_CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_OPENROUTER_MODEL = 'deepseek/deepseek-v4-flash';
const DEFAULT_GROQ_MODEL = 'llama-3.3-70b-versatile';
const DEFAULT_TIMEOUT_MS = 18000;
/** Durée totale maximale d'une réponse du coach en flux (en-têtes + corps). */
const DEFAULT_STREAM_TOTAL_TIMEOUT_MS = 60000;

/**
 * Le fournisseur du modèle n'a pas répondu (panne, délai, refus).
 *
 * [billed] : le fournisseur avait déjà accepté la requête (200) avant la
 * panne — génération commencée, donc potentiellement facturée. Seule une
 * panne NON facturée justifie de rendre le quota à l'élève : sinon un élève
 * qui provoque l'échec (coupure, sortie vide) consommerait sans limite.
 */
export class LlmUnavailableError extends Error {
  readonly billed: boolean;

  constructor(message: string, options: { billed?: boolean } = {}) {
    super(message);
    this.name = 'LlmUnavailableError';
    this.billed = options.billed ?? false;
  }
}

/**
 * Motif d'un repli de `completeJson`. Les trois premiers (`*_unconfigured`,
 * `*_http_error`, `*_network_error`) viennent d'une requête que le
 * fournisseur n'a jamais acceptée ; les autres, d'une réponse 200 reçue.
 */
export type JsonFallbackReason =
  | 'provider_unconfigured'
  | 'provider_http_error'
  | 'provider_network_error'
  | 'provider_interrupted'
  | 'provider_truncated'
  | 'provider_no_json'
  | 'provider_invalid_json';

export type JsonCompletionResult<T> = {
  data: T;
  model: string;
  /** Présent seulement quand [data] est la valeur de repli. */
  fallbackReason?: JsonFallbackReason;
  /**
   * Vrai dès qu'une tentative a reçu une réponse 200 du fournisseur (donc
   * potentiellement facturée), y compris quand le résultat est un repli.
   */
  billed: boolean;
};

@Injectable()
export class LlmService {
  private readonly logger = new Logger(LlmService.name);

  get isConfigured(): boolean {
    return Boolean(this.provider);
  }

  /** Ledger/analytics label of the active provider ('openrouter' when unset). */
  get providerName(): LlmProviderName {
    return this.provider?.name ?? 'openrouter';
  }

  /**
   * Active provider, resolved from the environment on every call so ops can
   * rotate keys without a restart. LLM_* (OpenRouter by default) wins; the
   * legacy GROQ_* variables keep working until ops finishes the migration.
   */
  private get provider(): ProviderConfig | undefined {
    const llmKey = process.env.LLM_API_KEY?.trim();
    if (llmKey) {
      const name: LlmProviderName =
        process.env.LLM_PROVIDER?.trim().toLowerCase() === 'groq'
          ? 'groq'
          : 'openrouter';
      return {
        name,
        chatUrl:
          process.env.LLM_CHAT_COMPLETIONS_URL?.trim() ||
          (name === 'groq' ? GROQ_CHAT_URL : OPENROUTER_CHAT_URL),
        apiKey: llmKey,
        model:
          process.env.LLM_MODEL?.trim() ||
          (name === 'groq' ? DEFAULT_GROQ_MODEL : DEFAULT_OPENROUTER_MODEL),
      };
    }
    const groqKey = process.env.GROQ_API_KEY?.trim();
    if (groqKey) {
      return {
        name: 'groq',
        chatUrl: GROQ_CHAT_URL,
        apiKey: groqKey,
        model: process.env.GROQ_MODEL?.trim() || DEFAULT_GROQ_MODEL,
      };
    }
    return undefined;
  }

  /**
   * OpenRouter fans requests out to third-party clouds; student prompts must
   * never be retained there (IA-T2 posture, same promise as the consent copy).
   * `zdr: true` pins routing to zero-data-retention endpoints — the actual
   * guarantee; `data_collection: 'deny'` alone only filters on the provider's
   * declared collection policy. `require_parameters` keeps requests off
   * providers that would silently drop `response_format`. The key collision is
   * intentional: OpenRouter's routing field is literally named `provider`.
   */
  private routingPolicy(name: LlmProviderName): Record<string, unknown> {
    return name === 'openrouter'
      ? {
          provider: {
            zdr: true,
            data_collection: 'deny',
            require_parameters: true,
          },
        }
      : {};
  }

  /**
   * deepseek-v4-flash is a hybrid model: some OpenRouter endpoints serve it in
   * thinking mode unless told otherwise. Measured on prod (26/09/2026, letter
   * personalisation, 15 requests): on the Relace and OpenInference endpoints
   * the model spent the WHOLE 1500-token budget on hidden reasoning
   * (`finish_reason: length`, no JSON) or hit the 18 s abort — 9 requests out
   * of 15 silently came back as the untouched template, some after 36–49 s.
   * With `reasoning.enabled: false`, 9/9 runs stopped normally with 0
   * reasoning tokens. `LLM_REASONING_ENABLED=true` restores the provider
   * default if a future model needs it.
   */
  private reasoningPolicy(name: LlmProviderName): Record<string, unknown> {
    if (name !== 'openrouter') return {};
    if (process.env.LLM_REASONING_ENABLED?.trim().toLowerCase() === 'true') {
      return {};
    }
    return { reasoning: { enabled: false } };
  }

  /// Per-request upper bound so a stalled provider connection can never hang
  /// the SSE response (or a JSON call) indefinitely. Configurable via env.
  /// Pour un appel JSON, il couvre l'échange ENTIER (en-têtes ET corps) ; pour
  /// le flux du coach, c'est le délai maximal sans nouveau jeton.
  private get timeoutMs(): number {
    const raw = Number(
      process.env.LLM_TIMEOUT_MS ?? process.env.GROQ_TIMEOUT_MS,
    );
    return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_TIMEOUT_MS;
  }

  /// Durée totale maximale d'une réponse en flux : des commentaires keep-alive
  /// du fournisseur ne peuvent pas la prolonger. Configurable via env.
  private get streamTotalTimeoutMs(): number {
    const raw = Number(process.env.LLM_STREAM_TIMEOUT_MS);
    return Number.isFinite(raw) && raw > 0
      ? raw
      : DEFAULT_STREAM_TOTAL_TIMEOUT_MS;
  }

  /**
   * AbortController armé d'un délai, relié au signal de l'appelant. Le délai
   * reste armé jusqu'à `dispose()` : il borne aussi la lecture du corps, pas
   * seulement l'arrivée des en-têtes (audit 22/11/2026, constat 15 — avant,
   * le minuteur tombait dès que `fetch` résolvait, et un fournisseur qui
   * s'arrêtait après ses en-têtes bloquait la lecture jusqu'à 300 s).
   */
  private abortScope(timeoutMs: number, parent?: AbortSignal) {
    const controller = new AbortController();
    const abort = () => controller.abort();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const rearm = () => {
      if (timer) clearTimeout(timer);
      timer = setTimeout(abort, timeoutMs);
    };
    if (parent?.aborted) abort();
    else parent?.addEventListener('abort', abort, { once: true });
    rearm();
    return {
      signal: controller.signal,
      abort,
      rearm,
      dispose: () => {
        if (timer) clearTimeout(timer);
        parent?.removeEventListener('abort', abort);
      },
    };
  }

  /// `fetch` + lecture du corps par [read], le tout sous le même délai. Lève
  /// sur délai dépassé pour que le chemin de reprise/repli de l'appelant joue.
  private async fetchWithTimeout<R>(
    url: string,
    init: RequestInit,
    read: (response: Response) => Promise<R>,
    timeoutMs: number = this.timeoutMs,
  ): Promise<R> {
    const scope = this.abortScope(timeoutMs);
    try {
      const response = await fetch(url, { ...init, signal: scope.signal });
      return await read(response);
    } finally {
      scope.dispose();
    }
  }

  /// Lit la réponse d'un appel JSON : en cas d'erreur HTTP, vide le corps sans
  /// jamais le journaliser (il peut renvoyer le prompt de l'élève).
  private async readChatResponse(
    response: Response,
  ): Promise<
    | { ok: true; payload: ProviderChatResponse }
    | { ok: false; status: number }
  > {
    if (!response.ok) {
      await response.text();
      return { ok: false, status: response.status };
    }
    return {
      ok: true,
      payload: (await response.json()) as ProviderChatResponse,
    };
  }

  async completeJson<T>(params: {
    system: string;
    user: string;
    maxTokens?: number;
    fallback: T;
    /// Per-attempt provider timeout for long generations (the env default
    /// fits short answers). Up to two attempts run, so the caller's HTTP
    /// client must wait at least twice this long.
    timeoutMs?: number;
  }): Promise<JsonCompletionResult<T>> {
    const config = this.provider;
    if (!config) {
      return {
        data: params.fallback,
        model: 'local-fallback',
        fallbackReason: 'provider_unconfigured',
        billed: false,
      };
    }

    const body = JSON.stringify({
      model: config.model,
      max_tokens: params.maxTokens ?? 1200,
      temperature: 0.4,
      response_format: { type: 'json_object' },
      ...this.routingPolicy(config.name),
      ...this.reasoningPolicy(config.name),
      messages: [
        {
          role: 'system',
          content: `${params.system}\nRéponds uniquement avec un objet JSON valide.`,
        },
        { role: 'user', content: params.user },
      ],
    });

    // Une réponse 200 reçue à N'IMPORTE QUELLE tentative rend l'appel
    // facturé : le motif de repli le dit à l'appelant, qui ne doit alors pas
    // rembourser le quota (revue du constat 16).
    let billed = false;
    const fallback = (
      fallbackReason: JsonFallbackReason,
    ): JsonCompletionResult<T> => ({
      data: params.fallback,
      model: 'local-fallback',
      fallbackReason,
      billed,
    });

    // One transient retry (timeout / network / 5xx) before degrading to the
    // local fallback, so a single blip doesn't drop the feature.
    for (let attempt = 0; attempt < 2; attempt++) {
      let accepted = false;
      let response: Awaited<ReturnType<LlmService['readChatResponse']>>;
      try {
        response = await this.fetchWithTimeout(
          config.chatUrl,
          {
            method: 'POST',
            headers: {
              'content-type': 'application/json',
              authorization: `Bearer ${config.apiKey}`,
            },
            body,
          },
          (res) => {
            // En-têtes 200 reçus : la génération a commencé.
            accepted = res.ok;
            if (res.ok) billed = true;
            return this.readChatResponse(res);
          },
          params.timeoutMs,
        );
      } catch {
        this.logger.warn(
          `${config.name} call failed (attempt ${attempt + 1}).`,
        );
        if (attempt === 0) continue;
        return fallback(
          accepted ? 'provider_interrupted' : 'provider_network_error',
        );
      }

      if (!response.ok) {
        // Drain the provider response but never log it: error bodies can
        // echo prompts, document excerpts or provider diagnostics.
        this.logger.warn(
          `${config.name} error ${response.status} (attempt ${attempt + 1}).`,
        );
        if (response.status >= 500 && attempt === 0) continue;
        return fallback('provider_http_error');
      }

      // À partir d'ici la réponse est payée : pas de seconde tentative.
      const payload = response.payload;
      if (payload.choices?.[0]?.finish_reason === 'length') {
        // Truncated at max_tokens: the JSON is incomplete (or was never
        // started, when the budget went to reasoning). This used to degrade
        // to the fallback without a trace.
        this.logger.warn(
          `${config.name} response truncated at max_tokens (attempt ${attempt + 1}, completion_tokens=${payload.usage?.completion_tokens ?? '?'}).`,
        );
        return fallback('provider_truncated');
      }
      const text = payload.choices?.[0]?.message?.content ?? '';
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return fallback('provider_no_json');
      }
      try {
        return {
          data: JSON.parse(jsonMatch[0]) as T,
          model: config.model,
          billed,
        };
      } catch {
        // Avant : relancé comme une panne réseau, donc payé deux fois.
        return fallback('provider_invalid_json');
      }
    }
    return fallback('provider_network_error');
  }

  /**
   * Executes exactly one provider attempt and returns a fully validated value.
   * Retry policy belongs to the feature service so every paid attempt can be
   * recorded independently in the usage ledger.
   */
  async completeStructured<T>(
    params: StructuredCompletionRequest<T>,
  ): Promise<StructuredCompletionResult<T>> {
    const startedAt = Date.now();
    const model = params.model.trim();
    const config = this.provider;
    if (!config || !model) {
      return this.structuredFallback(
        params.fallback,
        startedAt,
        'provider_unconfigured',
      );
    }

    // OpenRouter routing already excludes providers that cannot honor a strict
    // schema; on Groq only the gpt-oss models accept strict mode.
    const strict =
      config.name === 'openrouter' ||
      /^openai\/gpt-oss-(?:20b|120b)$/.test(model);
    const body = JSON.stringify({
      model,
      max_tokens: params.maxTokens,
      temperature: params.temperature,
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'success_lab_diagnostic',
          strict,
          schema: params.responseSchema,
        },
      },
      ...this.routingPolicy(config.name),
      // Sans lui, un modèle hybride peut dépenser les 220 jetons en raisonnement
      // caché et ne rien rendre (audit 22/11/2026, constat 14).
      ...this.reasoningPolicy(config.name),
      messages: [
        {
          role: 'system',
          content: `${params.system}\nReturn only the JSON object required by the schema.`,
        },
        { role: 'user', content: params.user },
      ],
    });

    try {
      const response = await this.fetchWithTimeout(
        config.chatUrl,
        {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${config.apiKey}`,
            'x-client-request-id': params.attemptKey,
          },
          body,
        },
        (res) => this.readChatResponse(res),
      );
      const latencyMs = Date.now() - startedAt;
      if (!response.ok) {
        this.logger.warn(
          `${config.name} structured request failed (${response.status}, feature=${params.feature}, prompt=${params.promptVersion}).`,
        );
        return {
          data: params.fallback,
          provider: config.name,
          model,
          latencyMs,
          outcome: 'error',
          fallbackReason:
            response.status === 429
              ? 'provider_rate_limited'
              : response.status >= 500
                ? 'provider_unavailable'
                : 'provider_rejected_request',
        };
      }

      const payload = response.payload;
      const usage = payload.usage;
      const refusal = payload.choices?.[0]?.message?.refusal;
      if (refusal) {
        return {
          data: params.fallback,
          provider: config.name,
          model,
          providerRequestId: payload.id,
          inputTokens: usage?.prompt_tokens,
          cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens,
          outputTokens: usage?.completion_tokens,
          totalTokens: usage?.total_tokens,
          latencyMs,
          outcome: 'refused',
          fallbackReason: 'provider_refusal',
        };
      }

      const raw = payload.choices?.[0]?.message?.content?.trim();
      if (!raw) {
        return this.invalidStructuredResponse(
          params,
          config.name,
          payload,
          latencyMs,
          'provider_empty_response',
        );
      }
      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch {
        return this.invalidStructuredResponse(
          params,
          config.name,
          payload,
          latencyMs,
          'provider_invalid_json',
        );
      }
      if (!params.validate(parsed)) {
        return this.invalidStructuredResponse(
          params,
          config.name,
          payload,
          latencyMs,
          'provider_schema_mismatch',
        );
      }

      return {
        data: parsed,
        provider: config.name,
        model,
        providerRequestId: payload.id,
        inputTokens: usage?.prompt_tokens,
        cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens,
        outputTokens: usage?.completion_tokens,
        totalTokens: usage?.total_tokens,
        latencyMs,
        outcome: 'success',
      };
    } catch (error) {
      const timedOut = error instanceof Error && error.name === 'AbortError';
      this.logger.warn(
        `${config.name} structured request failed (feature=${params.feature}, prompt=${params.promptVersion}, error=${timedOut ? 'timeout' : 'network'}).`,
      );
      return {
        data: params.fallback,
        provider: config.name,
        model,
        latencyMs: Date.now() - startedAt,
        outcome: 'error',
        fallbackReason:
          timedOut
            ? 'provider_timeout'
            : 'provider_network_error',
      };
    }
  }

  private structuredFallback<T>(
    fallback: T,
    startedAt: number,
    reason: string,
  ): StructuredCompletionResult<T> {
    return {
      data: fallback,
      provider: 'local',
      model: 'local-fallback',
      latencyMs: Date.now() - startedAt,
      outcome: 'fallback',
      fallbackReason: reason,
    };
  }

  private invalidStructuredResponse<T>(
    params: StructuredCompletionRequest<T>,
    provider: LlmProviderName,
    payload: ProviderChatResponse,
    latencyMs: number,
    reason: string,
  ): StructuredCompletionResult<T> {
    return {
      data: params.fallback,
      provider,
      model: params.model,
      providerRequestId: payload.id,
      inputTokens: payload.usage?.prompt_tokens,
      cachedInputTokens: payload.usage?.prompt_tokens_details?.cached_tokens,
      outputTokens: payload.usage?.completion_tokens,
      totalTokens: payload.usage?.total_tokens,
      latencyMs,
      outcome: 'error',
      fallbackReason: reason,
    };
  }

  /**
   * [throwOnUnavailable] : quand le fournisseur ne répond pas, lève
   * [LlmUnavailableError] au lieu de rendre la phrase de repli comme si
   * c'était une réponse. Le coach s'en sert pour ne pas décompter un message
   * ni garder cette phrase dans l'historique (audit avant la 59).
   *
   * [signal] : abandon par l'appelant (l'élève a fermé l'écran). La requête
   * au fournisseur est alors annulée, connexion comprise.
   *
   * Délais (audit 22/11/2026, constat 15) : le premier jeton doit arriver dans
   * [timeoutMs], puis chaque jeton suivant dans [timeoutMs] après le précédent
   * (les commentaires keep-alive ne comptent pas), et la réponse entière dans
   * [streamTotalTimeoutMs]. Au-delà, le flux est coupé et lève
   * [LlmUnavailableError], même après des jetons.
   */
  async *streamText(params: {
    system: string;
    messages: LlmMessage[];
    maxTokens?: number;
    lang?: Lang;
    throwOnUnavailable?: boolean;
    signal?: AbortSignal;
  }): AsyncGenerator<string> {
    const lang: Lang = params.lang === 'en' ? 'en' : 'fr';

    const config = this.provider;
    if (!config) {
      yield* this.fallbackWords(this.noKeyFallback(lang));
      return;
    }

    const conversationMessages = params.messages.filter(
      (item) => item.role !== 'system',
    );
    const body = JSON.stringify({
      model: config.model,
      max_tokens: params.maxTokens ?? 600,
      temperature: 0.6,
      stream: true,
      ...this.routingPolicy(config.name),
      // Comme completeJson : sinon tout le budget peut partir en raisonnement
      // caché et le flux se termine sans un seul jeton (constat 14).
      ...this.reasoningPolicy(config.name),
      messages: [
        { role: 'system', content: params.system },
        ...conversationMessages,
      ],
    });

    // One transient retry on the initial connection before yielding the
    // localized "temporarily unavailable" fallback (graceful degradation).
    let response: Response | null = null;
    let scope: ReturnType<LlmService['abortScope']> | null = null;
    for (let attempt = 0; attempt < 2; attempt++) {
      if (params.signal?.aborted) break;
      scope = this.abortScope(this.timeoutMs, params.signal);
      try {
        response = await fetch(config.chatUrl, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${config.apiKey}`,
          },
          body,
          signal: scope.signal,
        });
        if (response.ok && response.body) break;
        if (!response.ok) await response.text();
        this.logger.warn(
          `${config.name} stream error ${response.status} (attempt ${attempt + 1}).`,
        );
        scope.dispose();
        scope = null;
        if (response.status >= 500 && attempt === 0) {
          response = null;
          continue;
        }
        response = null;
        break;
      } catch {
        this.logger.warn(
          `${config.name} stream failed (attempt ${attempt + 1}).`,
        );
        scope?.dispose();
        scope = null;
        response = null;
        if (attempt === 0) continue;
      }
    }

    if (!scope || !response || !response.ok || !response.body) {
      scope?.dispose();
      if (params.throwOnUnavailable || params.signal?.aborted) {
        throw new LlmUnavailableError(`${config.name} did not answer.`);
      }
      yield this.unavailableFallback(lang);
      return;
    }

    // Le délai d'inactivité reste armé pendant la lecture ; un délai total
    // borne la réponse entière.
    const activeScope = scope;
    const totalTimer = setTimeout(
      activeScope.abort,
      this.streamTotalTimeoutMs,
    );
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    try {
      while (true) {
        let result: ReadableStreamReadResult<Uint8Array>;
        try {
          result = await reader.read();
        } catch {
          // Le flux avait été accepté (200) : génération commencée.
          throw new LlmUnavailableError(
            activeScope.signal.aborted
              ? `${config.name} stream aborted (timeout or client gone).`
              : `${config.name} stream interrupted.`,
            { billed: true },
          );
        }
        const { done, value } = result;
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          const payload = trimmed.slice(5).trim();
          if (!payload || payload === '[DONE]') continue;
          try {
            const event = JSON.parse(payload) as ProviderChatResponse;
            const chunk = event.choices?.[0]?.delta?.content;
            if (chunk) {
              // Seul un vrai jeton relance le délai d'inactivité.
              activeScope.rearm();
              yield chunk;
            }
          } catch {
            // Ignore malformed SSE chunks.
          }
        }
      }
    } finally {
      // Fin normale, erreur, ou consommateur qui arrête d'itérer : on libère
      // la connexion au fournisseur et les minuteurs.
      clearTimeout(totalTimer);
      activeScope.dispose();
      reader.cancel().catch(() => undefined);
    }
  }

  // ── Localized fallbacks ─────────────────────────────────────────────────────

  private noKeyFallback(lang: Lang): string {
    return lang === 'en'
      ? 'I am the KPB Coach. The AI service is not configured yet. In the meantime, explore the 9 KPB destinations and request guidance from the app.'
      : 'Je suis le Coach KPB. Le service IA n’est pas encore configuré. En attendant, explore les 9 destinations KPB et demande un accompagnement depuis l’app.';
  }

  private unavailableFallback(lang: Lang): string {
    return lang === 'en'
      ? 'Sorry, the AI coach is temporarily unavailable. Please try again shortly or contact a KPB advisor.'
      : 'Désolé, le coach IA est momentanément indisponible. Réessaie dans un instant ou contacte un conseiller KPB.';
  }

  private *fallbackWords(text: string): Generator<string> {
    for (const word of text.split(' ')) {
      yield `${word} `;
    }
  }
}
