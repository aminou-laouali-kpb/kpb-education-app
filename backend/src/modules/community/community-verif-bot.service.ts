import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Prisma, type CommunityBotDraft, type CommunityBotDraftStatus, type InternalRole } from '@prisma/client';
import { randomUUID } from 'node:crypto';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { COMMUNITY_AUDIT_PURPOSE, COMMUNITY_LIMITS, COMMUNITY_PAGINATION } from './community.constants';
import { CommunityComposerService, mentionRows } from './community-composer.service';
import { refreshPostCounters } from './community-counters';
import { cursorDate, cursorString, decodeCursor, encodeCursor } from './community-cursor';
import { runDb } from './community-db';
import { CommunityErrors } from './community-errors';
import type { ModerationActor } from './community-moderation.service';
import { CommunityModerationService } from './community-moderation.service';
import { CommunityNotificationsService } from './community-notifications.service';
import type { Lang } from './community-text';
import { CommunityVerifBotCatalogService } from './community-verif-bot-catalog.service';
import { detectVerificationQuestion, type VerifIntent } from './community-verif-bot-detect';
import {
  assessFacts,
  factsHash,
  oldestVerifiedAt,
  type EntityRef,
  type FactEntityType,
  type FactSet,
} from './community-verif-bot-facts';
import { checkRewrite, composeText, renderDraft, rewritePrompt } from './community-verif-bot-writer';
import {
  KPB_ASSISTANT_NAME,
  VERIF_BOT_BATCH,
  VERIF_BOT_MAX_ATTEMPTS,
  VERIF_BOT_SYSTEM_AUTHOR_ID,
  verifBotLlmEnabled,
  verifBotMode,
} from './community-verif-bot.config';

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

export const DRAFT_LIST_STATUSES = ['proposed', 'published', 'rejected', 'obsolete', 'skipped', 'queued', 'all'] as const;
export type DraftListStatus = (typeof DRAFT_LIST_STATUSES)[number];

const FACT_TYPES: readonly FactEntityType[] = ['scholarship', 'institution', 'program', 'country'];

function clampLimit(raw: number | undefined, def: number, max: number): number {
  if (raw === undefined || raw === null || Number.isNaN(raw)) return def;
  return Math.max(1, Math.min(max, Math.floor(raw)));
}

function median(values: number[]): number | null {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length / 2;
  const m = sorted.length % 2 ? sorted[(sorted.length - 1) / 2] : (sorted[mid - 1] + sorted[mid]) / 2;
  return Math.round(m * 10) / 10;
}

function readEntities(raw: Prisma.JsonValue): EntityRef[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return [];
    const e = item as Record<string, unknown>;
    if (typeof e.type !== 'string' || !(FACT_TYPES as readonly string[]).includes(e.type) || typeof e.id !== 'string') return [];
    return [
      {
        type: e.type as FactEntityType,
        id: e.id,
        labelFr: typeof e.labelFr === 'string' ? e.labelFr : e.id,
        labelEn: typeof e.labelEn === 'string' ? e.labelEn : typeof e.labelFr === 'string' ? e.labelFr : e.id,
        resolvedBy: e.resolvedBy === 'name' ? 'name' : 'mention',
      },
    ];
  });
}

/** Ce que la génération écrit sur le brouillon. */
type Generated =
  | { kind: 'skipped'; reason: string; lang: string; intents: VerifIntent[] }
  | { kind: 'obsolete'; reason: string }
  | {
      kind: 'proposed';
      lang: 'fr' | 'en';
      intents: VerifIntent[];
      entities: EntityRef[];
      facts: FactSet;
      hash: string;
      text: string;
      writer: 'template' | 'llm';
      llmFallbackReason: string | null;
      confidence: string;
      complete: boolean;
      scamCaution: boolean;
    };

/**
 * Bot « Vérif » (chantier Communauté C3) : traitement de la file, rédaction,
 * et le travail de l'équipe sur les brouillons (lister, voir, modifier puis
 * publier, rejeter, régénérer, statistiques). Contrat : §8.9 de
 * docs/community-api-contract.md (révision 2) ; exploitation :
 * docs/runbook-bot-verif.md.
 */
@Injectable()
export class CommunityVerifBotService {
  private readonly logger = new Logger(CommunityVerifBotService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly catalog: CommunityVerifBotCatalogService,
    private readonly composer: CommunityComposerService,
    private readonly notifications: CommunityNotificationsService,
    private readonly moderation: CommunityModerationService,
    private readonly llm: LlmService,
  ) {}

  // ── File ──────────────────────────────────────────────────────────────────

  /**
   * Brouillon en file ou proposé dont la publication n'est plus visible
   * (supprimée, masquée, en revue) ⇒ obsolète. Appelé par la tâche et avant
   * chaque lecture de la file admin.
   */
  async sweepObsolete(now: Date = new Date()): Promise<number> {
    const result = await runDb(this.prisma, (db) =>
      db.communityBotDraft.updateMany({
        where: { status: { in: ['queued', 'proposed'] }, post: { status: { not: 'visible' } } },
        data: { status: 'obsolete', statusReason: 'post_not_visible', updatedAt: now },
      }),
    );
    return result.count;
  }

  /** Un passage de la tâche : jusqu'à `VERIF_BOT_BATCH` brouillons en file. */
  async processQueue(now: Date = new Date()): Promise<{ processed: number; proposed: number; autoPublished: number }> {
    const out = { processed: 0, proposed: 0, autoPublished: 0 };
    const mode = verifBotMode();
    if (mode === 'off') return out;
    await this.sweepObsolete(now);
    const queued = await runDb(this.prisma, (db) =>
      db.communityBotDraft.findMany({
        where: { status: 'queued' },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take: VERIF_BOT_BATCH,
        select: { id: true, attempts: true },
      }),
    );
    for (const item of queued) {
      // Prise du brouillon : un seul passage le traite (tentative comptée).
      const claim = await runDb(this.prisma, (db) =>
        db.communityBotDraft.updateMany({
          where: { id: item.id, status: 'queued', attempts: item.attempts },
          data: { attempts: item.attempts + 1 },
        }),
      );
      if (claim.count !== 1) continue;
      out.processed += 1;
      try {
        const draft = await this.generateAndStore(item.id, now);
        if (draft?.status === 'proposed') {
          out.proposed += 1;
          if (mode === 'auto' && draft.confidence === 'high' && draft.complete) {
            await this.publishInternal(draft.id, { verified: false }, null, randomUUID(), 'fr', now);
            out.autoPublished += 1;
          }
        }
      } catch (error) {
        const name = error instanceof Error ? error.name : 'Error';
        const exhausted = item.attempts + 1 >= VERIF_BOT_MAX_ATTEMPTS;
        await runDb(this.prisma, (db) =>
          db.communityBotDraft.updateMany({
            where: { id: item.id, status: 'queued' },
            data: exhausted ? { status: 'skipped', statusReason: 'error', lastError: name } : { lastError: name },
          }),
        );
        this.logger.warn(`Bot Vérif : brouillon ${item.id} en échec (${name}).`);
      }
    }
    return out;
  }

  // ── Génération ────────────────────────────────────────────────────────────

  /** Détection → entités → faits → texte, pour la publication d'un brouillon. */
  async generate(postId: string, now: Date): Promise<Generated> {
    const post = await runDb(this.prisma, (db) =>
      db.communityPost.findUnique({ where: { id: postId }, include: { mentions: true } }),
    );
    if (!post || post.status !== 'visible') return { kind: 'obsolete', reason: 'post_not_visible' };
    const detection = detectVerificationQuestion({
      type: post.type,
      authorKind: post.authorKind,
      title: post.title,
      body: post.body,
    });
    if (!detection.candidate) {
      return { kind: 'skipped', reason: detection.skip ?? 'no_intent', lang: detection.lang, intents: detection.intents };
    }
    let refs: EntityRef[] = post.mentions
      .filter((m) => (FACT_TYPES as readonly string[]).includes(m.entityType))
      .map((m) => ({
        type: m.entityType as FactEntityType,
        id: m.entityId,
        labelFr: m.labelFr,
        labelEn: m.labelEn,
        resolvedBy: 'mention' as const,
      }));
    if (!refs.length) {
      const resolved = await this.catalog.resolveByText(detection.plain, now);
      if (resolved.kind === 'ambiguous') {
        return { kind: 'skipped', reason: 'ambiguous_entity', lang: detection.lang, intents: detection.intents };
      }
      if (resolved.kind === 'resolved') {
        // Un pays cité au passage (« Campus France », « étudier au Canada »)
        // n'est retenu seul que pour une question de rentrée, de visa ou de statut.
        const others = resolved.refs.filter((r) => r.type !== 'country');
        const countryUseful = detection.intents.some((i) => i === 'visa' || i === 'intake' || i === 'status');
        refs = others.length ? others : countryUseful ? resolved.refs : [];
      }
    }
    if (!refs.length) return { kind: 'skipped', reason: 'no_entity', lang: detection.lang, intents: detection.intents };
    const facts = await this.catalog.loadFacts(refs, now);
    if (!facts.entities.length) {
      return { kind: 'skipped', reason: 'entity_not_public', lang: detection.lang, intents: detection.intents };
    }
    const assessment = assessFacts(facts, detection.intents);
    const rendered = renderDraft({
      facts,
      intents: detection.intents,
      unanswered: assessment.unanswered,
      lang: detection.lang,
      scamCaution: detection.scamCaution,
    });
    let body = rendered.body;
    let writer: 'template' | 'llm' = 'template';
    let llmFallbackReason: string | null = null;
    if (verifBotLlmEnabled()) {
      const prompt = rewritePrompt(rendered, detection.lang);
      try {
        const result = await this.llm.completeJson<{ text?: unknown }>({
          system: prompt.system,
          user: prompt.user,
          maxTokens: 900,
          fallback: {},
        });
        if (result.model === 'local-fallback') {
          llmFallbackReason = 'llm_unavailable';
        } else {
          const check = checkRewrite(result.data?.text, rendered);
          if (check.ok) {
            body = String(result.data.text).trim();
            writer = 'llm';
          } else {
            llmFallbackReason = check.reason;
          }
        }
      } catch {
        llmFallbackReason = 'llm_error';
      }
    }
    return {
      kind: 'proposed',
      lang: detection.lang,
      intents: detection.intents,
      entities: facts.entities.map((e) => e.ref),
      facts,
      hash: factsHash(facts),
      text: composeText(body, rendered.footer),
      writer,
      llmFallbackReason,
      confidence: assessment.confidence,
      complete: assessment.complete,
      scamCaution: detection.scamCaution,
    };
  }

  private async generateAndStore(draftId: string, now: Date): Promise<CommunityBotDraft | null> {
    const draft = await runDb(this.prisma, (db) => db.communityBotDraft.findUnique({ where: { id: draftId } }));
    if (!draft) return null;
    const result = await this.generate(draft.postId, now);
    const data: Prisma.CommunityBotDraftUpdateInput =
      result.kind === 'proposed'
        ? {
            status: 'proposed',
            statusReason: null,
            lang: result.lang,
            intents: result.intents,
            entities: result.entities as unknown as Prisma.InputJsonValue,
            facts: result.facts as unknown as Prisma.InputJsonValue,
            factsHash: result.hash,
            proposedText: result.text,
            writer: result.writer,
            llmFallbackReason: result.llmFallbackReason,
            confidence: result.confidence,
            complete: result.complete,
            scamCaution: result.scamCaution,
            generatedAt: now,
            lastError: null,
          }
        : result.kind === 'skipped'
          ? {
              status: 'skipped',
              statusReason: result.reason,
              lang: result.lang,
              intents: result.intents,
              facts: Prisma.DbNull,
              factsHash: null,
              proposedText: null,
              confidence: null,
              complete: false,
              generatedAt: now,
              lastError: null,
            }
          : { status: 'obsolete', statusReason: result.reason, lastError: null };
    return runDb(this.prisma, (db) => db.communityBotDraft.update({ where: { id: draftId }, data }));
  }

  // ── Équipe : publier, rejeter, régénérer ──────────────────────────────────

  private async loadDraft(id: string): Promise<CommunityBotDraft> {
    const draft = await runDb(this.prisma, (db) => db.communityBotDraft.findUnique({ where: { id } }));
    if (!draft) throw CommunityErrors.botDraftNotFound();
    return draft;
  }

  private async markObsolete(id: string, reason: string, now: Date): Promise<void> {
    await runDb(this.prisma, (db) =>
      db.communityBotDraft.updateMany({
        where: { id, status: { in: ['queued', 'proposed'] } },
        data: { status: 'obsolete', statusReason: reason, updatedAt: now },
      }),
    );
  }

  private async audit(
    tx: Prisma.TransactionClient,
    input: { action: string; draftId: string; actor: ModerationActor | null; requestId: string; reason?: string; changes?: Prisma.InputJsonValue; now: Date },
  ): Promise<void> {
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: input.actor?.id ?? null,
        action: `community.${input.action}`,
        purposeCode: COMMUNITY_AUDIT_PURPOSE,
        entityType: 'community_bot_draft',
        entityId: input.draftId,
        requestId: input.requestId || randomUUID(),
        reasonCode: input.reason?.slice(0, 500),
        result: 'success',
        changes: input.changes ?? Prisma.JsonNull,
        occurredAt: input.now,
      },
    });
  }

  /**
   * Publie le brouillon comme réponse « Assistant KPB ». Les faits sont
   * RE-VÉRIFIÉS à cet instant : publication plus visible ou faits changés ⇒
   * brouillon obsolète et 409 `community_bot_draft_obsolete` (l'admin
   * régénère). `actor = null` : publication automatique (mode `auto`).
   */
  async publish(
    id: string,
    input: { text?: string; verified?: boolean },
    actor: ModerationActor,
    requestId: string,
    lang: Lang,
    now: Date = new Date(),
  ) {
    return this.publishInternal(id, input, actor, requestId, lang, now);
  }

  private async publishInternal(
    id: string,
    input: { text?: string; verified?: boolean },
    actor: ModerationActor | null,
    requestId: string,
    lang: Lang,
    now: Date,
  ) {
    const draft = await this.loadDraft(id);
    if (draft.status === 'obsolete') throw CommunityErrors.botDraftObsolete(draft.statusReason ?? 'obsolete');
    if (draft.status !== 'proposed') throw CommunityErrors.invalidTransition(draft.status);
    const post = await runDb(this.prisma, (db) => db.communityPost.findUnique({ where: { id: draft.postId } }));
    if (!post || post.status !== 'visible') {
      await this.markObsolete(id, 'post_not_visible', now);
      throw CommunityErrors.botDraftObsolete('post_not_visible');
    }
    const refs = readEntities(draft.entities);
    const facts = await this.catalog.loadFacts(refs, now);
    if (!facts.entities.length || factsHash(facts) !== draft.factsHash) {
      await this.markObsolete(id, 'facts_changed', now);
      throw CommunityErrors.botDraftObsolete('facts_changed');
    }
    const text = (input.text ?? draft.proposedText ?? '').trim();
    if (text.length < COMMUNITY_LIMITS.replyBodyMin || text.length > COMMUNITY_LIMITS.replyBodyMax) {
      throw new BadRequestException(
        `text must be ${COMMUNITY_LIMITS.replyBodyMin} to ${COMMUNITY_LIMITS.replyBodyMax} characters.`,
      );
    }
    const prepared = await this.composer.prepare({ body: text, isPost: false, authorEmail: null, now });
    const verified = input.verified === true;
    const edited = input.text !== undefined && text !== (draft.proposedText ?? '').trim();
    const replyId = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const claimed = await tx.communityBotDraft.updateMany({
          where: { id, status: 'proposed' },
          data: {
            status: 'published',
            statusReason: null,
            processedAt: now,
            processedByAdminId: actor?.id ?? null,
            processedByName: actor?.fullName ?? null,
            publishedVerified: verified,
            autoPublished: actor === null,
          },
        });
        if (claimed.count !== 1) throw CommunityErrors.invalidTransition('published');
        if (verified) {
          await tx.communityReply.updateMany({ where: { postId: post.id, isVerified: true }, data: { isVerified: false } });
        }
        const reply = await tx.communityReply.create({
          data: {
            postId: post.id,
            body: prepared.body,
            authorKind: 'kpb_assistant',
            authorAdminId: actor?.id ?? VERIF_BOT_SYSTEM_AUTHOR_ID,
            authorAdminName: KPB_ASSISTANT_NAME,
            status: 'visible',
            createdAt: now,
            isVerified: verified,
            verifiedAt: verified ? now : null,
            verifiedByAdminId: verified ? actor?.id ?? null : null,
            botDraftId: id,
            botSourceVerifiedAt: (() => {
              const oldest = oldestVerifiedAt(facts);
              return oldest ? new Date(oldest) : null;
            })(),
            mentions: { create: mentionRows(prepared.mentions) },
          },
        });
        await tx.communityBotDraft.update({ where: { id }, data: { publishedReplyId: reply.id } });
        await refreshPostCounters(tx, [post.id]);
        await this.audit(tx, {
          action: actor ? 'bot_publish' : 'bot_auto_publish',
          draftId: id,
          actor,
          requestId,
          changes: { postId: post.id, replyId: reply.id, verified, edited, confidence: draft.confidence },
          now,
        });
        if (verified && actor) {
          // La vérification reste une décision humaine : elle va au journal.
          await tx.forumModerationAction.create({
            data: {
              targetType: 'reply',
              targetId: reply.id,
              reason: 'Réponse vérifiée par KPB',
              action: 'verify_answer',
              moderatorName: actor.fullName,
              moderatorRole: actor.role as InternalRole,
              createdAt: now,
              postId: post.id,
              replyId: reply.id,
              adminId: actor.id,
            },
          });
        }
        return reply.id;
      }),
    );
    await this.notifications.replyPosted({
      post: { id: post.id, title: post.title, type: post.type, authorMemberId: post.authorMemberId },
      reply: { id: replyId, authorMemberId: null },
      now,
    });
    if (verified) {
      await this.notifications.verifiedAnswer({
        post: { id: post.id, title: post.title, authorMemberId: post.authorMemberId },
        reply: { id: replyId, authorMemberId: null },
        now,
      });
    }
    const reply = await this.moderation.adminContent('reply', replyId, lang, now, actor?.role ?? 'moderator');
    return { draft: await this.draftJson(await this.loadDraft(id)), reply };
  }

  async reject(id: string, reason: string, actor: ModerationActor, requestId: string, now: Date = new Date()) {
    const r = (reason ?? '').trim();
    if (r.length < COMMUNITY_LIMITS.adminReasonMin || r.length > COMMUNITY_LIMITS.adminReasonMax) {
      throw new BadRequestException(
        `reason must be ${COMMUNITY_LIMITS.adminReasonMin} to ${COMMUNITY_LIMITS.adminReasonMax} characters.`,
      );
    }
    const draft = await this.loadDraft(id);
    if (draft.status !== 'proposed' && draft.status !== 'obsolete') throw CommunityErrors.invalidTransition(draft.status);
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const done = await tx.communityBotDraft.updateMany({
          where: { id, status: { in: ['proposed', 'obsolete'] } },
          data: {
            status: 'rejected',
            rejectReason: r,
            processedAt: now,
            processedByAdminId: actor.id,
            processedByName: actor.fullName,
          },
        });
        if (done.count !== 1) throw CommunityErrors.invalidTransition(draft.status);
        await this.audit(tx, { action: 'bot_reject', draftId: id, actor, requestId, reason: r, changes: { from: draft.status }, now });
      }),
    );
    return this.draftJson(await this.loadDraft(id));
  }

  /** Refait détection, faits et texte (jamais publié seul, même en mode `auto`). */
  async regenerate(id: string, actor: ModerationActor, requestId: string, now: Date = new Date()) {
    const draft = await this.loadDraft(id);
    if (draft.status === 'published') throw CommunityErrors.invalidTransition(draft.status);
    const updated = await this.generateAndStore(id, now);
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (updated && updated.status !== 'rejected') {
          await tx.communityBotDraft.update({
            where: { id },
            data: { rejectReason: null, processedAt: null, processedByAdminId: null, processedByName: null },
          });
        }
        await this.audit(tx, {
          action: 'bot_regenerate',
          draftId: id,
          actor,
          requestId,
          changes: { from: draft.status, to: updated?.status ?? draft.status },
          now,
        });
      }),
    );
    return this.draftJson(await this.loadDraft(id));
  }

  // ── Lecture ───────────────────────────────────────────────────────────────

  async draftJson(draft: CommunityBotDraft, post?: { id: string; title: string; type: string; status: string; createdAt: Date } | null) {
    const facts = (draft.facts ?? null) as unknown as FactSet | null;
    return {
      id: draft.id,
      postId: draft.postId,
      status: draft.status,
      statusReason: draft.statusReason,
      lang: draft.lang,
      intents: draft.intents,
      entities: readEntities(draft.entities).map((e) => ({
        type: e.type,
        id: e.id,
        label: draft.lang === 'en' ? e.labelEn : e.labelFr,
        resolvedBy: e.resolvedBy,
      })),
      facts,
      sources: (facts?.entities ?? []).map((e) => ({
        type: e.ref.type,
        id: e.ref.id,
        label: e.ref.labelFr,
        url: e.source.url,
        verifiedAt: e.source.verifiedAt,
        stale: e.source.stale,
      })),
      factsHash: draft.factsHash,
      proposedText: draft.proposedText,
      writer: draft.writer,
      llmFallbackReason: draft.llmFallbackReason,
      confidence: draft.confidence,
      complete: draft.complete,
      scamCaution: draft.scamCaution,
      createdAt: draft.createdAt.toISOString(),
      generatedAt: draft.generatedAt?.toISOString() ?? null,
      processedAt: draft.processedAt?.toISOString() ?? null,
      processedBy: draft.processedByAdminId
        ? { adminId: draft.processedByAdminId, name: draft.processedByName ?? '' }
        : null,
      rejectReason: draft.rejectReason,
      publishedReplyId: draft.publishedReplyId,
      publishedVerified: draft.publishedVerified,
      autoPublished: draft.autoPublished,
      ...(post !== undefined
        ? {
            post: post
              ? { id: post.id, title: post.title, type: post.type, status: post.status, createdAt: post.createdAt.toISOString() }
              : null,
          }
        : {}),
    };
  }

  async list(
    status: DraftListStatus,
    rawCursor: string | undefined,
    rawLimit: number | undefined,
    now: Date = new Date(),
  ) {
    await this.sweepObsolete(now);
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const where: Prisma.CommunityBotDraftWhereInput = status === 'all' ? {} : { status: status as CommunityBotDraftStatus };
    const feed = `bot_drafts:${status}`;
    const cursor = decodeCursor(rawCursor, feed);
    if (cursor) {
      const at = cursorDate(cursor, 't');
      const cid = cursorString(cursor, 'i');
      where.OR = [{ createdAt: { lt: at } }, { createdAt: at, id: { lt: cid } }];
    }
    const rows = await runDb(this.prisma, (db) =>
      db.communityBotDraft.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
        include: { post: { select: { id: true, title: true, type: true, status: true, createdAt: true } } },
      }),
    );
    const page = rows.slice(0, limit);
    const last = page[page.length - 1];
    const items = await Promise.all(page.map((r) => this.draftJson(r, r.post)));
    return {
      mode: verifBotMode(),
      items,
      nextCursor:
        rows.length > limit && last
          ? encodeCursor({ f: feed, t: last.createdAt.toISOString(), i: last.id })
          : null,
    };
  }

  /**
   * Un brouillon, sa publication (forme admin) et un contrôle EN DIRECT :
   * publication toujours visible ? faits toujours identiques ? (l'indicateur
   * « obsolète » de la console, avant même de cliquer sur Publier).
   */
  async detail(id: string, role: string, lang: Lang, now: Date = new Date()) {
    await this.sweepObsolete(now);
    const draft = await this.loadDraft(id);
    const post = await this.moderation.adminContent('post', draft.postId, lang, now, role);
    let factsChanged = false;
    if (draft.status === 'proposed') {
      const facts = await this.catalog.loadFacts(readEntities(draft.entities), now);
      factsChanged = !facts.entities.length || factsHash(facts) !== draft.factsHash;
    }
    return {
      mode: verifBotMode(),
      draft: await this.draftJson(draft),
      post,
      live: { postVisible: post.status === 'visible', factsChanged },
    };
  }

  async stats(days: number, now: Date = new Date()) {
    const span = Math.max(1, Math.min(365, Math.floor(days || 30)));
    const from = new Date(now.getTime() - span * DAY_MS);
    await this.sweepObsolete(now);
    return runDb(this.prisma, async (db) => {
      const [byStatus, windowRows, autoPublished, verified] = await Promise.all([
        db.communityBotDraft.groupBy({ by: ['status'], _count: { _all: true } }),
        db.communityBotDraft.findMany({
          where: { createdAt: { gte: from, lte: now } },
          select: { status: true, createdAt: true, generatedAt: true, processedAt: true, autoPublished: true, writer: true },
        }),
        db.communityBotDraft.count({ where: { autoPublished: true, processedAt: { gte: from, lte: now } } }),
        db.communityBotDraft.count({ where: { publishedVerified: true, processedAt: { gte: from, lte: now } } }),
      ]);
      const counts: Record<string, number> = { queued: 0, skipped: 0, proposed: 0, published: 0, rejected: 0, obsolete: 0 };
      for (const row of byStatus) counts[row.status] = row._count._all;
      const windowCounts: Record<string, number> = { queued: 0, skipped: 0, proposed: 0, published: 0, rejected: 0, obsolete: 0 };
      for (const row of windowRows) windowCounts[row.status] = (windowCounts[row.status] ?? 0) + 1;
      const handled = windowRows.filter((r) => r.processedAt && (r.status === 'published' || r.status === 'rejected') && !r.autoPublished);
      return {
        mode: verifBotMode(),
        llmEnabled: verifBotLlmEnabled(),
        window: { from: from.toISOString(), to: now.toISOString(), days: span },
        current: counts,
        created: windowCounts,
        autoPublished,
        publishedVerified: verified,
        llmWritten: windowRows.filter((r) => r.writer === 'llm').length,
        // Délai humain : brouillon prêt → décision (publié ou rejeté), en heures.
        medianHandlingHours: median(
          handled.map((r) => (r.processedAt!.getTime() - (r.generatedAt ?? r.createdAt).getTime()) / HOUR_MS),
        ),
      };
    });
  }
}
