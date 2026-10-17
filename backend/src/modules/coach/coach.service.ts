import {
  Injectable,
  Logger,
  MessageEvent,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { Observable, Subscriber } from 'rxjs';

import { AiConsentService } from '../ai/ai-consent.service';
import { LlmService } from '../ai/llm.service';
import { AssistBridgeQueueService } from '../assist-bridge/assist-bridge-queue.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  buildCoachSystemPrompt,
  buildCoachSuggestions,
  freshnessAnnotation,
  resolveCoachLanguage,
  unsourcedFigureCaveat,
  type CoachLanguage,
} from './coach-prompt.builder';
import { CoachQuotaService } from './coach-quota.service';

type CoachRole = 'user' | 'assistant';

/** Longueur maximale d'un message étudiant envoyé au coach. */
export const COACH_MESSAGE_MAX_LENGTH = 2000;

/**
 * Le profil arrive du client sans DTO : on ne garde que des champs du bon type
 * pour qu'un `"targetCountryIds": "FR"` ne fasse pas planter `.map()` plus loin.
 */
export function sanitizeCoachProfile(raw: unknown): Record<string, unknown> {
  const source =
    raw && typeof raw === 'object' && !Array.isArray(raw)
      ? (raw as Record<string, unknown>)
      : {};
  const str = (v: unknown, max = 120) =>
    typeof v === 'string' ? v.slice(0, max) : undefined;
  const num = (v: unknown) =>
    typeof v === 'number' && Number.isFinite(v) ? v : undefined;
  const ids = Array.isArray(source.targetCountryIds)
    ? source.targetCountryIds
        .filter((v): v is string => typeof v === 'string')
        .map((v) => v.slice(0, 40))
        .slice(0, 20)
    : [];
  return {
    fullName: str(source.fullName),
    currentLevel: str(source.currentLevel),
    preferredLanguage: str(source.preferredLanguage, 10),
    targetCountryIds: ids,
    annualTuitionBudgetEur: num(source.annualTuitionBudgetEur),
    monthlyBudgetEur: num(source.monthlyBudgetEur),
  };
}

type CoachMessage = { role: CoachRole; content: string; createdAt: string };

type Conversation = {
  id: string;
  userId: string;
  messages: CoachMessage[];
  createdAt: string;
};

@Injectable()
export class CoachService {
  private readonly logger = new Logger(CoachService.name);
  /**
   * In-memory store. Used as the source of truth only when the database is
   * unavailable (no `DATABASE_URL`); otherwise conversations live in Postgres
   * and this map is bypassed.
   */
  private readonly conversations = new Map<string, Conversation>();
  private readonly aiConsent: AiConsentService;

  constructor(
    private readonly llmService: LlmService,
    private readonly quotaService: CoachQuotaService,
    private readonly prisma: PrismaService,
    @Optional() aiConsent?: AiConsentService,
    // Bot « Passerelle » (C3 bis) : source PRIVÉE, fermée par défaut
    // (KPB_ASSIST_BRIDGE_COACH). Optionnel pour les tests existants.
    @Optional() private readonly assistBridgeQueue?: AssistBridgeQueueService,
  ) {
    // Optional so the existing unit tests (`new CoachService(llm, quota, prisma)`)
    // keep constructing without a fourth argument. Production injects the
    // shared singleton from AppModule.
    this.aiConsent = aiConsent ?? new AiConsentService(prisma);
  }

  getQuota(userId: string) {
    return this.quotaService.getQuota(userId);
  }

  getSuggestions(profile: Record<string, unknown>) {
    return {
      suggestions: buildCoachSuggestions({
        fullName: profile.fullName as string | undefined,
        targetCountryIds: profile.targetCountryIds as string[] | undefined,
        language: resolveCoachLanguage(profile.preferredLanguage as string),
      }),
    };
  }

  async createConversation(userId: string, profile: Record<string, unknown>) {
    const lang = resolveCoachLanguage(profile.preferredLanguage as string);
    // No name in the greeting: it is persisted and later replayed to the LLM
    // provider as conversation history, so personalizing it here would leak the identity
    // we deliberately keep out of the prompt. The client shows a name locally.
    const greetingContent =
      lang === 'en'
        ? `Hi! I'm your KPB Coach. Ask me anything about studying abroad, your budget, or partner schools.`
        : `Salut ! Je suis ton Coach KPB. Pose-moi tes questions sur les études à l'étranger, le budget ou les écoles partenaires.`;

    const persisted = await this.prisma.tryExecute((client) =>
      client.coachConversation.create({
        data: {
          userId,
          messages: {
            create: { role: 'assistant', content: greetingContent },
          },
        },
        include: { messages: { orderBy: { createdAt: 'asc' } } },
      }),
    );

    if (persisted) {
      const greeting = persisted.messages[0];
      return {
        conversationId: persisted.id,
        greeting: {
          role: greeting.role as CoachRole,
          content: greeting.content,
          createdAt: greeting.createdAt.toISOString(),
        },
        ...(await this.quotaService.getQuota(userId)),
      };
    }

    // ── In-memory fallback ──────────────────────────────────────────────────
    const id = `coach-${Date.now()}`;
    const conversation: Conversation = {
      id,
      userId,
      createdAt: new Date().toISOString(),
      messages: [
        {
          role: 'assistant',
          content: greetingContent,
          createdAt: new Date().toISOString(),
        },
      ],
    };
    this.conversations.set(id, conversation);
    return {
      conversationId: id,
      greeting: conversation.messages[0],
      ...(await this.quotaService.getQuota(userId)),
    };
  }

  async getMessages(
    conversationId: string,
    userId: string,
  ): Promise<CoachMessage[]> {
    const conversation = await this.loadConversation(conversationId);
    // Treat "not yours" the same as "not found" so we don't leak existence.
    if (!conversation || conversation.userId !== userId) {
      throw new NotFoundException(`Conversation ${conversationId} not found.`);
    }
    return conversation.messages;
  }

  streamReply(params: {
    conversationId: string;
    userId: string;
    message: string;
    profile: Record<string, unknown>;
  }): Observable<MessageEvent> {
    return new Observable((subscriber) => {
      // Tout le tour est dans un try/catch : la promesse est lancée par `void`,
      // donc une exception qui s'en échapperait deviendrait un rejet non géré
      // qui arrête le process Node (et toutes les requêtes en cours).
      void (async () => {
        try {
          await this.runStreamTurn(params, subscriber);
        } catch (error) {
          this.logger.error(
            `Coach stream failed: ${error instanceof Error ? error.message : String(error)}`,
          );
          if (!subscriber.closed) {
            subscriber.next({
              data: { type: 'error', message: 'Coach temporairement indisponible.' },
            } as MessageEvent);
            subscriber.complete();
          }
        }
      })();
    });
  }

  private async runStreamTurn(
    rawParams: {
      conversationId: string;
      userId: string;
      message: string;
      profile: Record<string, unknown>;
    },
    subscriber: Subscriber<MessageEvent>,
  ): Promise<void> {
    const params = {
      ...rawParams,
      message: typeof rawParams.message === 'string' ? rawParams.message : '',
      profile: sanitizeCoachProfile(rawParams.profile),
    };
    if (!params.message.trim() || params.message.length > COACH_MESSAGE_MAX_LENGTH) {
      subscriber.next({
        data: {
          type: 'error',
          code: 'invalid_message',
          message: `Message vide ou trop long (${COACH_MESSAGE_MAX_LENGTH} caractères max).`,
        },
      } as MessageEvent);
      subscriber.complete();
      return;
    }
    const conversation = await this.loadConversation(params.conversationId);
    // Ownership check: reject streaming into someone else's conversation
    // (same "not found" message so existence isn't leaked).
    if (!conversation || conversation.userId !== params.userId) {
      subscriber.next({
        data: {
          type: 'error',
          message: `Conversation ${params.conversationId} not found.`,
        },
      } as MessageEvent);
      subscriber.complete();
      return;
    }

    // Consent gates (defense-in-depth; the client also gates entry to the
    // coach). When the DB is available and the authoritative profile has
    // not opted into AI processing — or is a minor without recorded
    // guardian consent — refuse before any PII reaches the LLM provider.
    const consentBlock = await this.aiConsent.consentBlockCode(
      params.userId,
    );
    if (consentBlock) {
      subscriber.next({
        data: {
          type: 'error',
          code: consentBlock,
          message:
            consentBlock === 'guardian_consent_required'
              ? 'Guardian consent required for minors.'
              : consentBlock === 'age_verification_required'
                ? 'Birth date verification is required before AI processing.'
                : 'AI processing consent required.',
        },
      } as MessageEvent);
      subscriber.complete();
      return;
    }

    const quota = await this.quotaService.consume(params.userId);
    if (!quota.allowed) {
      subscriber.next({
        data: {
          type: 'error',
          message:
            'Quota hebdomadaire atteint (5 messages). Premium bientôt disponible.',
        },
      } as MessageEvent);
      subscriber.complete();
      return;
    }

    const userMessageId = await this.appendMessage(conversation, 'user', params.message);
    // Passerelle : détection en mémoire, jamais attendue par le coach, jamais
    // d'erreur propagée (la file l'avale). Rien n'est écrit si la source coach
    // est fermée (défaut) ; jamais le texte, seulement l'id du message.
    if (userMessageId && this.assistBridgeQueue) {
      void this.assistBridgeQueue.enqueueCoach(params.userId, userMessageId, params.message);
    }

    const lang = resolveCoachLanguage(
      params.profile.preferredLanguage as string,
    );

    // RAG: ground the reply in verified catalog facts for this question.
    const verifiedContext = await this.retrieveContext(
      params.message,
      (params.profile.targetCountryIds as string[] | undefined) ?? [],
      lang,
    );

    // PII minimization: the student's name is intentionally NOT forwarded
    // to the LLM (the prompt builder pseudonymizes the remaining context).
    const system = buildCoachSystemPrompt({
      currentLevel: params.profile.currentLevel as string | undefined,
      targetCountryIds: params.profile.targetCountryIds as string[] | undefined,
      annualTuitionBudgetEur:
        params.profile.annualTuitionBudgetEur as number | undefined,
      monthlyBudgetEur: params.profile.monthlyBudgetEur as number | undefined,
      verifiedContext,
      language: lang,
    });

    const history = conversation.messages.slice(-8).map((item) => ({
      role: item.role,
      content: item.content,
    }));

    let full = '';
    try {
      for await (const chunk of this.llmService.streamText({
        system,
        messages: history,
        lang,
      })) {
        full += chunk;
        subscriber.next({ data: { type: 'token', text: chunk } } as MessageEvent);
      }
      // Output guardrail: if the model emitted a concrete figure while we
      // had NO verified context to ground it, it was invented — append a
      // localized caveat (streamed as a normal token so it persists too).
      const caveat = unsourcedFigureCaveat(full, verifiedContext, lang);
      if (caveat) {
        full += caveat;
        subscriber.next({
          data: { type: 'token', text: caveat },
        } as MessageEvent);
      }
      await this.appendMessage(conversation, 'assistant', full.trim());
      subscriber.next({
        data: {
          type: 'done',
          quotaRemaining: quota.remaining,
        },
      } as MessageEvent);
      subscriber.complete();
    } catch (error) {
      this.logger.error(
        `Coach LLM stream failed: ${error instanceof Error ? error.message : String(error)}`,
      );
      subscriber.next({
        data: { type: 'error', message: 'Coach temporairement indisponible.' },
      } as MessageEvent);
      subscriber.complete();
    }
  }

  // ── RAG retrieval ───────────────────────────────────────────────────────────

  /// Pull the verified catalog facts most relevant to the question (the user's
  /// target countries + any country/scholarship named in the message), as a
  /// compact, citable context block. Returns '' when the DB is unavailable — the
  /// prompt then tells the model it has no verified data (so it won't invent).
  private async retrieveContext(
    message: string,
    targetCountryIds: string[],
    lang: CoachLanguage = 'fr',
  ): Promise<string> {
    const q = ' ' + message.toLowerCase() + ' ';
    const targets = new Set(targetCountryIds.map((c) => c.toLowerCase()));

    const [countries, scholarships] = await Promise.all([
      this.prisma.tryExecute((p) =>
        p.country.findMany({ where: { isActive: true }, take: 30 }),
      ),
      this.prisma.tryExecute((p) =>
        p.scholarship.findMany({
          where: { isActive: true, moderationStatus: 'approved' },
          orderBy: { nameFr: 'asc' },
          take: 60,
        }),
      ),
    ]);
    if (!countries && !scholarships) return '';

    const relCountries = (countries ?? [])
      .filter(
        (c) =>
          targets.has(c.id.toLowerCase()) ||
          targets.has(c.code.toLowerCase()) ||
          (!!c.nameFr && q.includes(c.nameFr.toLowerCase())) ||
          (!!c.nameEn && q.includes(c.nameEn.toLowerCase())),
      )
      .slice(0, 4);
    const relCountryIds = new Set(relCountries.map((c) => c.id));

    const relScholarships = (scholarships ?? [])
      .filter(
        (s) =>
          relCountryIds.has(s.countryId) ||
          (!!s.nameFr && q.includes(s.nameFr.toLowerCase())) ||
          (!!s.nameEn && q.includes(s.nameEn.toLowerCase())),
      )
      .slice(0, 6);

    const en = lang === 'en';
    const na = en ? 'n/a' : 'n/d';
    const lines: string[] = [];
    if (relCountries.length) {
      lines.push(en ? 'COUNTRIES:' : 'PAYS:');
      for (const c of relCountries) {
        // Decay the trust signal over time: a fact verified long ago is
        // flagged STALE so the coach won't quote a year-old figure as current.
        const verified = freshnessAnnotation(c.lastVerifiedAt, lang);
        const src = en ? 'KPB catalogue' : 'catalogue KPB';
        lines.push(
          en
            ? `- ${c.nameEn}: tuition ${c.tuitionRangeEn || na}; living cost ${c.livingCostRangeEn || na}; visa ${c.visaOverviewEn || na}; admission ${c.admissionDifficultyEn || na} [source: ${src}, ${verified}]`
            : `- ${c.nameFr}: frais ${c.tuitionRangeFr || na}; coût de vie ${c.livingCostRangeFr || na}; visa ${c.visaOverviewFr || na}; admission ${c.admissionDifficultyFr || na} [source: ${src}, ${verified}]`,
        );
      }
    }
    if (relScholarships.length) {
      lines.push(en ? 'SCHOLARSHIPS:' : 'BOURSES:');
      for (const s of relScholarships) {
        const elig = en
          ? (s.eligibilityEn ?? []).slice(0, 2).join(' / ')
          : (s.eligibilityFr ?? []).slice(0, 2).join(' / ');
        const fallbackSrc = en ? 'KPB catalogue' : 'catalogue KPB';
        lines.push(
          en
            ? `- ${s.nameEn} (${s.countryNameEn || s.countryId}): funding ${s.typeOfFundingEn || na}; deadline ${s.deadlineLabelEn || na}; eligibility ${elig || 'see details'} [source: ${s.sourceUrl || fallbackSrc}]`
            : `- ${s.nameFr} (${s.countryNameFr || s.countryId}): financement ${s.typeOfFundingFr || na}; date limite ${s.deadlineLabelFr || na}; éligibilité ${elig || 'voir détail'} [source: ${s.sourceUrl || fallbackSrc}]`,
        );
      }
    }
    return lines.join('\n');
  }

  // ── Storage helpers ─────────────────────────────────────────────────────────

  private async loadConversation(id: string): Promise<Conversation | null> {
    const persisted = await this.prisma.tryExecute((client) =>
      client.coachConversation.findUnique({
        where: { id },
        include: { messages: { orderBy: { createdAt: 'asc' } } },
      }),
    );

    if (persisted) {
      return {
        id: persisted.id,
        userId: persisted.userId,
        createdAt: persisted.createdAt.toISOString(),
        messages: persisted.messages.map((m) => ({
          role: m.role as CoachRole,
          content: m.content,
          createdAt: m.createdAt.toISOString(),
        })),
      };
    }

    return this.conversations.get(id) ?? null;
  }

  /** Ajoute le message ; rend son id quand il est enregistré en base. */
  private async appendMessage(
    conversation: Conversation,
    role: CoachRole,
    content: string,
  ): Promise<string | null> {
    const message: CoachMessage = {
      role,
      content,
      createdAt: new Date().toISOString(),
    };

    // Keep the in-memory snapshot in sync so `history` reflects this turn even
    // when persistence is enabled (we already hold the hydrated conversation).
    conversation.messages.push(message);

    const persisted = await this.prisma.tryExecute((client) =>
      client.coachMessage.create({
        data: { conversationId: conversation.id, role, content },
      }),
    );

    if (persisted) {
      await this.prisma.tryExecute((client) =>
        client.coachConversation.update({
          where: { id: conversation.id },
          data: { updatedAt: new Date() },
        }),
      );
    } else if (!this.conversations.has(conversation.id)) {
      // DB disabled and this conversation isn't tracked yet — register it.
      this.conversations.set(conversation.id, conversation);
    }
    return persisted?.id ?? null;
  }
}
