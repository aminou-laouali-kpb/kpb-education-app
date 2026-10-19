import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { AssistBridgeEvent, AssistBridgeSource, AssistBridgeStatus, Prisma } from '@prisma/client';

import { isWithinQuietHours, utcOffsetHoursForCountry } from '../../common/country-timezone';
import { COMMUNITY_PAGINATION } from '../community/community.constants';
import { cursorDate, cursorString, decodeCursor, encodeCursor } from '../community/community-cursor';
import { runDb } from '../community/community-db';
import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { isScholarshipMatchEnabled } from '../scholarship-match/scholarship-match.feature';
import {
  ASSIST_BRIDGE_BATCH,
  ASSIST_BRIDGE_EXCERPT_MAX,
  ASSIST_BRIDGE_FEATURE_RECENT_DAYS,
  ASSIST_BRIDGE_KIND,
  ASSIST_BRIDGE_MAX_ATTEMPTS,
  ASSIST_BRIDGE_OPT_OUT,
  ASSIST_BRIDGE_RETENTION_DAYS,
  ASSIST_BRIDGE_SENDER,
  assistBridgeCoachEnabled,
  assistBridgeMode,
  type AssistBridgeMode,
} from './assist-bridge.config';
import { ASSIST_SKIP_REASONS, decide, type AssistFacts } from './assist-bridge.guards';
import { ASSIST_BRIDGE_RULES_VERSION, ASSIST_NEEDS, catalogJson, needById, type AssistNeed } from './assist-bridge.rules';

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

/** Dossier en cours = tout statut hors de ceux-ci. */
const CLOSED_CASE_STATUSES = ['completed', 'rejected', 'cancelled'] as const;
/** Achat de service en cours. */
const OPEN_PURCHASE_STATUSES = ['pending_payment', 'paid', 'in_progress'] as const;

export const ASSIST_ACTIONS = ['opened_feature', 'opened_whatsapp', 'dismissed'] as const;
export type AssistAction = (typeof ASSIST_ACTIONS)[number];

export const ASSIST_LIST_STATUSES = [
  'all',
  'detected',
  'sent',
  'skipped',
  'opened_feature',
  'opened_whatsapp',
  'dismissed',
] as const;
export type AssistListStatus = (typeof ASSIST_LIST_STATUSES)[number];

export const ASSIST_SOURCES = ['community_post', 'community_reply', 'coach_message'] as const;

const ACTION_FIELD: Record<AssistAction, 'openedFeatureAt' | 'openedWhatsappAt' | 'dismissedAt'> = {
  opened_feature: 'openedFeatureAt',
  opened_whatsapp: 'openedWhatsappAt',
  dismissed: 'dismissedAt',
};

function readEnvHour(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(23, Math.max(0, parsed));
}

/** Même fenêtre calme que `NotificationDispatchService` (21 h → 8 h local par défaut). */
function quietWindow(): { start: number; end: number } {
  return { start: readEnvHour('KPB_PUSH_QUIET_START', 21), end: readEnvHour('KPB_PUSH_QUIET_END', 8) };
}

function enabled(value: string | undefined): boolean {
  return value?.trim().toLowerCase() === 'true';
}

/** L'espace « Études en France » réel est-il ouvert ? (`eefSpace` de `/config/app`). */
function eefSpaceOpen(): boolean {
  return enabled(process.env.KPB_EEF_ENABLED) || enabled(process.env.KPB_EEF_SPACE_ENABLED);
}

function clampLimit(raw: number | undefined, def: number, max: number): number {
  if (raw === undefined || raw === null || Number.isNaN(raw)) return def;
  return Math.max(1, Math.min(max, Math.floor(raw)));
}

const MENTION_TOKEN_RE =
  /@\[([^\]\n]{1,80})\]\((?:scholarship|country|institution|program):[A-Za-z0-9_-]{1,64}\)/g;

/** Extrait court d'un contenu PUBLIC (jetons de mention lisibles, coupé au mot). */
export function shortExcerpt(text: string, max = ASSIST_BRIDGE_EXCERPT_MAX): string {
  const flat = text.replace(MENTION_TOKEN_RE, (_w, label: string) => `@${label}`).replace(/\s+/g, ' ').trim();
  if (flat.length <= max) return flat;
  const cut = flat.slice(0, max - 1);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut).replace(/[\s.,;:!?-]+$/u, '')}…`;
}

/** Première heure pleine, après `now`, hors de la fenêtre calme locale. */
export function nextSendableAt(now: Date, country: string | null | undefined): Date {
  const offset = utcOffsetHoursForCountry(country);
  const { start, end } = quietWindow();
  const probe = new Date(now.getTime());
  probe.setUTCMinutes(0, 0, 0);
  for (let i = 0; i < 26; i += 1) {
    probe.setTime(probe.getTime() + HOUR_MS);
    if (!isWithinQuietHours(probe, offset, start, end)) return probe;
  }
  return new Date(now.getTime() + HOUR_MS);
}

/**
 * Bot « Passerelle » (chantier C3 bis) : traitement de la file (garde-fous puis
 * envoi), suivi des clics de l'élève, et lecture pour la console. Contrat :
 * §15 de docs/community-api-contract.md (révision 3) ; exploitation :
 * docs/runbook-bot-passerelle.md.
 */
@Injectable()
export class AssistBridgeService {
  private readonly logger = new Logger(AssistBridgeService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatcher: NotificationDispatchService,
  ) {}

  // ── File ──────────────────────────────────────────────────────────────────

  /** Un passage de la tâche : jusqu'à `ASSIST_BRIDGE_BATCH` événements `detected` dus. */
  async processQueue(
    now: Date = new Date(),
  ): Promise<{ processed: number; sent: number; skipped: number; deferred: number }> {
    const out = { processed: 0, sent: 0, skipped: 0, deferred: 0 };
    const mode = assistBridgeMode();
    if (mode === 'off') return out;
    const due = await runDb(this.prisma, (db) =>
      db.assistBridgeEvent.findMany({
        where: { status: 'detected', OR: [{ notBefore: null }, { notBefore: { lte: now } }] },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take: ASSIST_BRIDGE_BATCH,
        select: { id: true, attempts: true },
      }),
    );
    for (const item of due) {
      // Prise de l'événement : un seul passage le traite (tentative comptée).
      const claim = await runDb(this.prisma, (db) =>
        db.assistBridgeEvent.updateMany({
          where: { id: item.id, status: 'detected', attempts: item.attempts },
          data: { attempts: item.attempts + 1 },
        }),
      );
      if (claim.count !== 1) continue;
      out.processed += 1;
      try {
        const result = await this.handle(item.id, item.attempts, mode, now);
        if (result === 'sent') out.sent += 1;
        else if (result === 'deferred') out.deferred += 1;
        else if (result === 'skipped') out.skipped += 1;
      } catch (error) {
        const name = error instanceof Error ? error.name : 'Error';
        const exhausted = item.attempts + 1 >= ASSIST_BRIDGE_MAX_ATTEMPTS;
        await runDb(this.prisma, (db) =>
          db.assistBridgeEvent.updateMany({
            where: { id: item.id, status: 'detected' },
            data: exhausted
              ? { status: 'skipped', statusReason: 'error', lastError: name, processedAt: now, mode }
              : { lastError: name },
          }),
        );
        if (exhausted) out.skipped += 1;
        this.logger.warn(`Passerelle : événement ${item.id} en échec (${name}).`);
      }
    }
    return out;
  }

  /** La source existe-t-elle encore, visible, et écrite par CET élève ? */
  private async sourceVisible(event: AssistBridgeEvent, memberId: string | null): Promise<boolean> {
    return runDb(this.prisma, async (db) => {
      if (event.source === 'community_post') {
        if (!memberId) return false;
        const post = await db.communityPost.findUnique({
          where: { id: event.sourceId },
          select: { status: true, authorKind: true, authorMemberId: true },
        });
        return !!post && post.status === 'visible' && post.authorKind === 'member' && post.authorMemberId === memberId;
      }
      if (event.source === 'community_reply') {
        if (!memberId) return false;
        const reply = await db.communityReply.findUnique({
          where: { id: event.sourceId },
          select: { status: true, authorKind: true, authorMemberId: true, post: { select: { status: true } } },
        });
        return (
          !!reply &&
          reply.status === 'visible' &&
          reply.post.status === 'visible' &&
          reply.authorKind === 'member' &&
          reply.authorMemberId === memberId
        );
      }
      const message = await db.coachMessage.findUnique({
        where: { id: event.sourceId },
        select: { role: true, conversation: { select: { userId: true } } },
      });
      return !!message && message.role === 'user' && message.conversation.userId === event.userId;
    });
  }

  /** La fonction cible est-elle servie en ce moment ? */
  private async featureAvailable(need: AssistNeed): Promise<boolean> {
    if (need.feature === 'scholarship_match') return isScholarshipMatchEnabled();
    if (need.feature === 'etudes_en_france') return eefSpaceOpen();
    if (need.feature === 'services') {
      // L'aide visa n'existe que si une offre `visa_kit` est publiée.
      const count = await runDb(this.prisma, (db) =>
        db.servicePackage.count({ where: { category: 'visa_kit', isActive: true } }),
      );
      return count > 0;
    }
    return true;
  }

  /** L'élève a-t-il déjà utilisé la fonction cible récemment (quand c'est vérifiable simplement) ? */
  private async featureUsedRecently(need: AssistNeed, userId: string, now: Date): Promise<boolean> {
    const since = new Date(now.getTime() - ASSIST_BRIDGE_FEATURE_RECENT_DAYS * DAY_MS);
    return runDb(this.prisma, async (db) => {
      switch (need.feature) {
        case 'document_review':
          // Quota IA de la relecture consommé dans la fenêtre : une relecture faite.
          return (
            (await db.aiQuotaBucket.count({
              where: { userId, feature: 'document_review', used: { gt: 0 }, updatedAt: { gte: since } },
            })) > 0
          );
        case 'scholarship_match':
          return (await db.scholarshipMatchRun.count({ where: { userId, createdAt: { gte: since } } })) > 0;
        case 'new_case': {
          // Un dossier en cours, ou un rendez-vous à venir : déjà accompagné.
          const openCase = await db.case.count({
            where: { userId, status: { notIn: [...CLOSED_CASE_STATUSES] } },
          });
          if (openCase > 0) return true;
          return (await db.appointment.count({ where: { userId, startsAt: { gte: now } } })) > 0;
        }
        case 'orientation':
          return (await db.orientationSession.count({ where: { userId, completedAt: { gte: since } } })) > 0;
        case 'services':
          return (
            (await db.servicePurchase.count({
              where: { userId, status: { in: [...OPEN_PURCHASE_STATUSES] }, package: { category: 'visa_kit' } },
            })) > 0
          );
        default:
          return false;
      }
    });
  }

  /**
   * Dernier envoi de l'élève (tous besoins, et pour ce besoin). En `shadow`,
   * un envoi SIMULÉ (`skipped / shadow`) compte aussi : les chiffres de la
   * console disent alors ce que le mode `on` aurait vraiment envoyé.
   */
  private async lastSends(
    event: AssistBridgeEvent,
    mode: Exclude<AssistBridgeMode, 'off'>,
  ): Promise<{ any: Date | null; need: Date | null }> {
    return runDb(this.prisma, async (db) => {
      const base = { userId: event.userId, id: { not: event.id } };
      const sent = (where: Prisma.AssistBridgeEventWhereInput) =>
        db.assistBridgeEvent.findFirst({
          where: { ...base, ...where, sentAt: { not: null } },
          orderBy: { sentAt: 'desc' },
          select: { sentAt: true },
        });
      const simulated = (where: Prisma.AssistBridgeEventWhereInput) =>
        mode === 'shadow'
          ? db.assistBridgeEvent.findFirst({
              where: { ...base, ...where, status: 'skipped', statusReason: 'shadow', processedAt: { not: null } },
              orderBy: { processedAt: 'desc' },
              select: { processedAt: true },
            })
          : Promise.resolve(null);
      const [anySent, anySim, needSent, needSim] = await Promise.all([
        sent({}),
        simulated({}),
        sent({ needId: event.needId }),
        simulated({ needId: event.needId }),
      ]);
      const latest = (a: Date | null | undefined, b: Date | null | undefined) =>
        a && b ? (a > b ? a : b) : (a ?? b ?? null);
      return {
        any: latest(anySent?.sentAt, anySim?.processedAt),
        need: latest(needSent?.sentAt, needSim?.processedAt),
      };
    });
  }

  private async handle(
    id: string,
    attempts: number,
    mode: Exclude<AssistBridgeMode, 'off'>,
    now: Date,
  ): Promise<'sent' | 'skipped' | 'deferred' | 'gone'> {
    const event = await runDb(this.prisma, (db) => db.assistBridgeEvent.findUnique({ where: { id } }));
    if (!event || event.status !== 'detected') return 'gone';
    const need = needById(event.needId);
    const skip = async (reason: string) => {
      await runDb(this.prisma, (db) =>
        db.assistBridgeEvent.updateMany({
          where: { id, status: 'detected' },
          data: { status: 'skipped', statusReason: reason, mode, processedAt: now, notBefore: null },
        }),
      );
      return 'skipped' as const;
    };
    // Besoin retiré du catalogue depuis la détection : on se tait.
    if (!need) return skip('feature_unavailable');
    const profile = await runDb(this.prisma, (db) =>
      db.userProfile.findUnique({
        where: { id: event.userId },
        select: {
          accountType: true,
          preferredLanguage: true,
          countryOfResidence: true,
          disabledNotificationTypes: true,
          communityMember: { select: { id: true } },
        },
      }),
    );
    if (!profile) return 'gone';
    const memberId = profile.communityMember?.id ?? null;
    const sanctioned = memberId
      ? (await runDb(this.prisma, (db) =>
          db.communitySanction.count({
            where: {
              memberId,
              revokedAt: null,
              kind: { in: ['read_only', 'ban'] },
              OR: [{ endsAt: null }, { endsAt: { gt: now } }],
            },
          }),
        )) > 0
      : false;
    const last = await this.lastSends(event, mode);
    const { start, end } = quietWindow();
    const facts: AssistFacts = {
      mode,
      now,
      detectedAt: event.createdAt,
      isStudent: profile.accountType === 'student',
      optedOut: profile.disabledNotificationTypes.includes(ASSIST_BRIDGE_OPT_OUT),
      sanctioned,
      coachSourceClosed: event.source === 'coach_message' && !assistBridgeCoachEnabled(),
      sourceVisible: await this.sourceVisible(event, memberId),
      featureAvailable: await this.featureAvailable(need),
      featureUsedRecently: await this.featureUsedRecently(need, event.userId, now),
      lastNeedSentAt: last.need,
      lastAnySentAt: last.any,
      quietHours: isWithinQuietHours(now, utcOffsetHoursForCountry(profile.countryOfResidence), start, end),
    };
    const decision = decide(facts);
    if (decision.action === 'skip') return skip(decision.reason);
    if (decision.action === 'defer') {
      // Heures calmes : l'événement attend, la tentative n'est pas comptée.
      await runDb(this.prisma, (db) =>
        db.assistBridgeEvent.updateMany({
          where: { id, status: 'detected' },
          data: { notBefore: nextSendableAt(now, profile.countryOfResidence), attempts },
        }),
      );
      return 'deferred';
    }
    const dedupeKey = `${ASSIST_BRIDGE_KIND}:${event.id}`;
    const outcome = await this.dispatcher.dispatch({
      userId: event.userId,
      kind: ASSIST_BRIDGE_KIND,
      dedupeKey,
      title: need.title,
      body: need.body,
      route: need.route,
      // Charge push : uniquement des chaînes. Le lien WhatsApp n'y est PAS : le
      // numéro officiel vit dans la configuration de l'app (`KPB_WHATSAPP_NUMBER`,
      // `AppConfig.whatsappNumber`) ; `whatsapp: "kpb"` dit à l'app de proposer
      // cette ligne-là, comme la bulle « Études en France ».
      data: {
        needId: need.id,
        feature: need.feature,
        eventId: event.id,
        whatsapp: 'kpb',
        sender: ASSIST_BRIDGE_SENDER,
        ruleVersion: event.ruleVersion,
      },
      preferredLanguage: profile.preferredLanguage,
      countryOfResidence: profile.countryOfResidence,
      now,
    });
    if (outcome === 'skipped') throw new Error('dispatch_skipped');
    await runDb(this.prisma, (db) =>
      db.assistBridgeEvent.updateMany({
        where: { id, status: 'detected' },
        data: {
          status: 'sent',
          statusReason: null,
          mode,
          processedAt: now,
          sentAt: now,
          notBefore: null,
          notificationKey: dedupeKey,
          pushOutcome: outcome,
          lastError: null,
        },
      }),
    );
    return 'sent';
  }

  /** Purge des événements au-delà de la durée de conservation (12 mois, validés le 18/10/2026). */
  async purge(now: Date = new Date()): Promise<number> {
    const before = new Date(now.getTime() - ASSIST_BRIDGE_RETENTION_DAYS * DAY_MS);
    const result = await this.prisma.execute((db) =>
      db.assistBridgeEvent.deleteMany({ where: { createdAt: { lt: before } } }),
    );
    return result?.count ?? 0;
  }

  // ── Élève : suivi des clics ───────────────────────────────────────────────

  /**
   * L'élève a ouvert la fonction, ouvert WhatsApp, ou fermé la feuille. Seul
   * le destinataire d'une notification ENVOYÉE peut le dire ; idempotent (la
   * première date est gardée, le statut suit la dernière action).
   */
  async recordAction(userId: string, id: string, action: AssistAction, now: Date = new Date()) {
    const event = await runDb(this.prisma, (db) =>
      db.assistBridgeEvent.findFirst({ where: { id, userId, sentAt: { not: null } } }),
    );
    if (!event) {
      throw new NotFoundException({ message: 'Assist bridge event not found.', code: 'assist_bridge_event_not_found' });
    }
    const field = ACTION_FIELD[action];
    const updated = await runDb(this.prisma, (db) =>
      db.assistBridgeEvent.update({
        where: { id },
        data: { status: action, [field]: event[field] ?? now },
      }),
    );
    return { id: updated.id, status: updated.status };
  }

  // ── Console ───────────────────────────────────────────────────────────────

  catalog() {
    return { mode: assistBridgeMode(), coachSource: assistBridgeCoachEnabled(), ...catalogJson() };
  }

  async stats(days: number, now: Date = new Date()) {
    const span = Math.max(1, Math.min(365, Math.floor(days || 30)));
    const from = new Date(now.getTime() - span * DAY_MS);
    const rows = await runDb(this.prisma, (db) =>
      db.assistBridgeEvent.findMany({
        where: { createdAt: { gte: from, lte: now } },
        select: {
          needId: true,
          source: true,
          status: true,
          statusReason: true,
          sentAt: true,
          openedFeatureAt: true,
          openedWhatsappAt: true,
          dismissedAt: true,
        },
      }),
    );
    type Counts = {
      detected: number;
      pending: number;
      sent: number;
      wouldSend: number;
      skipped: Record<string, number>;
      openedFeature: number;
      openedWhatsapp: number;
      dismissed: number;
    };
    const empty = (): Counts => ({
      detected: 0,
      pending: 0,
      sent: 0,
      wouldSend: 0,
      skipped: Object.fromEntries(ASSIST_SKIP_REASONS.map((r) => [r, 0])),
      openedFeature: 0,
      openedWhatsapp: 0,
      dismissed: 0,
    });
    const totals = empty();
    const byNeed = new Map<string, Counts>(ASSIST_NEEDS.map((n) => [n.id, empty()]));
    const bySource: Record<string, number> = Object.fromEntries(ASSIST_SOURCES.map((s) => [s, 0]));
    for (const row of rows) {
      bySource[row.source] = (bySource[row.source] ?? 0) + 1;
      let counts = byNeed.get(row.needId);
      if (!counts) {
        counts = empty();
        byNeed.set(row.needId, counts);
      }
      for (const c of [totals, counts]) {
        c.detected += 1;
        if (row.status === 'detected') c.pending += 1;
        if (row.sentAt) c.sent += 1;
        if (row.status === 'skipped') {
          const reason = row.statusReason ?? 'error';
          c.skipped[reason] = (c.skipped[reason] ?? 0) + 1;
          if (reason === 'shadow') c.wouldSend += 1;
        }
        if (row.openedFeatureAt) c.openedFeature += 1;
        if (row.openedWhatsappAt) c.openedWhatsapp += 1;
        if (row.dismissedAt) c.dismissed += 1;
      }
    }
    return {
      mode: assistBridgeMode(),
      coachSource: assistBridgeCoachEnabled(),
      rulesVersion: ASSIST_BRIDGE_RULES_VERSION,
      window: { from: from.toISOString(), to: now.toISOString(), days: span },
      totals,
      bySource,
      needs: [...byNeed.entries()].map(([needId, counts]) => {
        const need = needById(needId);
        return { needId, label: need?.label ?? { fr: needId, en: needId }, ...counts };
      }),
    };
  }

  /**
   * Les derniers événements, SANS texte pour la source coach ; un extrait court
   * seulement pour un contenu PUBLIC de la communauté (visible au moment de la
   * lecture), relu à la volée — jamais stocké. Aucune identité d'élève.
   */
  async list(
    filters: { status?: AssistListStatus; needId?: string; source?: AssistBridgeSource },
    rawCursor: string | undefined,
    rawLimit: number | undefined,
  ) {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const where: Prisma.AssistBridgeEventWhereInput = {};
    if (filters.status && filters.status !== 'all') where.status = filters.status as AssistBridgeStatus;
    if (filters.needId) where.needId = filters.needId;
    if (filters.source) where.source = filters.source;
    const feed = `assist_bridge:${filters.status ?? 'all'}:${filters.needId ?? ''}:${filters.source ?? ''}`;
    const cursor = decodeCursor(rawCursor, feed);
    if (cursor) {
      const at = cursorDate(cursor, 't');
      const cid = cursorString(cursor, 'i');
      where.OR = [{ createdAt: { lt: at } }, { createdAt: at, id: { lt: cid } }];
    }
    const rows = await runDb(this.prisma, (db) =>
      db.assistBridgeEvent.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const page = rows.slice(0, limit);
    const postIds = page.filter((r) => r.source === 'community_post').map((r) => r.sourceId);
    const replyIds = page.filter((r) => r.source === 'community_reply').map((r) => r.sourceId);
    const [posts, replies] = await runDb(this.prisma, (db) =>
      Promise.all([
        postIds.length
          ? db.communityPost.findMany({ where: { id: { in: postIds } }, select: { id: true, title: true, status: true } })
          : Promise.resolve([]),
        replyIds.length
          ? db.communityReply.findMany({
              where: { id: { in: replyIds } },
              select: { id: true, body: true, status: true, postId: true, post: { select: { status: true } } },
            })
          : Promise.resolve([]),
      ]),
    );
    const postById = new Map(posts.map((p) => [p.id, p]));
    const replyById = new Map(replies.map((r) => [r.id, r]));
    const last = page[page.length - 1];
    return {
      mode: assistBridgeMode(),
      items: page.map((r) => {
        let excerpt: string | null = null;
        let postId: string | null = null;
        if (r.source === 'community_post') {
          const p = postById.get(r.sourceId);
          if (p && p.status === 'visible') {
            excerpt = shortExcerpt(p.title);
            postId = p.id;
          }
        } else if (r.source === 'community_reply') {
          const rep = replyById.get(r.sourceId);
          if (rep && rep.status === 'visible' && rep.post.status === 'visible') {
            excerpt = shortExcerpt(rep.body);
            postId = rep.postId;
          }
        }
        return {
          id: r.id,
          source: r.source,
          needId: r.needId,
          ruleId: r.ruleId,
          ruleVersion: r.ruleVersion,
          status: r.status,
          statusReason: r.statusReason,
          mode: r.mode,
          pushOutcome: r.pushOutcome,
          createdAt: r.createdAt.toISOString(),
          processedAt: r.processedAt?.toISOString() ?? null,
          sentAt: r.sentAt?.toISOString() ?? null,
          openedFeatureAt: r.openedFeatureAt?.toISOString() ?? null,
          openedWhatsappAt: r.openedWhatsappAt?.toISOString() ?? null,
          dismissedAt: r.dismissedAt?.toISOString() ?? null,
          // Source coach : JAMAIS de texte, ni d'identifiant de conversation.
          excerpt,
          postId,
        };
      }),
      nextCursor:
        rows.length > limit && last ? encodeCursor({ f: feed, t: last.createdAt.toISOString(), i: last.id }) : null,
    };
  }
}
