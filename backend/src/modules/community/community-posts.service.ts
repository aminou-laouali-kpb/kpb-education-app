import { BadRequestException, Injectable, Optional } from '@nestjs/common';
import { Prisma, type CommunityContentStatus, type CommunityPostType } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  COMMUNITY_EDIT_WINDOW_MS,
  COMMUNITY_FOR_YOU_WINDOW_DAYS,
  COMMUNITY_LIMITS,
  COMMUNITY_MAX_PINNED,
  COMMUNITY_PAGINATION,
} from './community.constants';
import { CommunityAccessService, type CommunityViewer } from './community-access.service';
import { CommunityCatalogService } from './community-catalog.service';
import {
  CommunityComposerService,
  mentionRows,
  statusForFlags,
} from './community-composer.service';
import { refreshPostCounters, refreshReplyCounters } from './community-counters';
import {
  cursorDate,
  cursorString,
  decodeCursor,
  encodeCursor,
  invalidCursor,
  type CursorPayload,
} from './community-cursor';
import { runDb } from './community-db';
import { CommunityErrors } from './community-errors';
import { CommunityFilterConfigService } from './community-filter-config.service';
import { forYouReasons, forYouSql, type ForYouReason, type ForYouRow } from './community-for-you';
import { CommunityNotificationsService } from './community-notifications.service';
import { CommunityVerifBotQueueService } from './community-verif-bot-queue.service';
import {
  POST_INCLUDE,
  REPLY_INCLUDE,
  postJson,
  postSummaryJson,
  replyJson,
  type PostRow,
  type PresentContext,
  type ReplyRow,
} from './community-presenter';
import {
  hashtagKey,
  isEntityType,
  searchTerms,
  type CommunityEntityTypeValue,
  type Lang,
} from './community-text';

const DAY_MS = 24 * 60 * 60 * 1000;

/** Le rang décimal d'un curseur « Pour toi » (texte numérique, jamais du SQL). */
function cursorRank(cursor: CursorPayload): string {
  const rank = cursorString(cursor, 's');
  if (!/^-?\d{1,6}(\.\d{1,12})?$/.test(rank)) throw invalidCursor();
  return rank;
}

export type FeedTab = 'for_you' | 'recent' | 'unanswered';

export interface FeedQuery {
  tab: FeedTab;
  type?: CommunityPostType;
  hashtag?: string;
  cursor?: string;
  limit?: number;
}

/** Les contenus d'auteurs en relation de blocage disparaissent (§6.2). */
function notBlocked(blocked: readonly string[]): Prisma.CommunityPostWhereInput {
  return blocked.length
    ? { OR: [{ authorMemberId: null }, { authorMemberId: { notIn: [...blocked] } }] }
    : {};
}

function notBlockedReply(blocked: readonly string[]): Prisma.CommunityReplyWhereInput {
  return blocked.length
    ? { OR: [{ authorMemberId: null }, { authorMemberId: { notIn: [...blocked] } }] }
    : {};
}

function clampLimit(raw: number | undefined, def: number, max: number): number {
  if (raw === undefined || raw === null || Number.isNaN(raw)) return def;
  return Math.max(1, Math.min(max, Math.floor(raw)));
}

/** Curseur (date décroissante, id décroissant). */
function descCursorWhere(
  field: 'createdAt' | 'lastActivityAt',
  at: Date,
  id: string,
): Prisma.CommunityPostWhereInput {
  return { OR: [{ [field]: { lt: at } }, { [field]: at, id: { lt: id } }] };
}

/**
 * Lectures et écritures ÉLÈVE de la communauté (§7 du contrat).
 */
@Injectable()
export class CommunityPostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: CommunityAccessService,
    private readonly composer: CommunityComposerService,
    private readonly filterConfig: CommunityFilterConfigService,
    private readonly notifications: CommunityNotificationsService,
    private readonly catalog: CommunityCatalogService,
    // Bot « Vérif » (C3) : file asynchrone, jamais bloquante. Absente des
    // tests qui ne la fournissent pas.
    @Optional() private readonly verifBotQueue?: CommunityVerifBotQueueService,
  ) {}

  // ── Présentation ──────────────────────────────────────────────────────────

  async presentContext(
    viewerMemberId: string | null,
    lang: Lang,
    now: Date,
    posts: readonly PostRow[],
    replies: readonly ReplyRow[] = [],
  ): Promise<PresentContext> {
    const postIds = posts.map((p) => p.id);
    const replyIds = replies.map((r) => r.id);
    const [identities, filterContext, reactions, follows] = await Promise.all([
      this.access.identities([...posts.map((p) => p.authorMemberId), ...replies.map((r) => r.authorMemberId)]),
      this.filterConfig.context(now),
      viewerMemberId && (postIds.length || replyIds.length)
        ? runDb(this.prisma, (db) =>
            db.communityReaction.findMany({
              where: {
                memberId: viewerMemberId,
                OR: [{ postId: { in: postIds } }, { replyId: { in: replyIds } }],
              },
              select: { postId: true, replyId: true },
            }),
          )
        : Promise.resolve([]),
      viewerMemberId && postIds.length
        ? runDb(this.prisma, (db) =>
            db.communityFollow.findMany({
              where: { memberId: viewerMemberId, postId: { in: postIds } },
              select: { postId: true },
            }),
          )
        : Promise.resolve([]),
    ]);
    return {
      viewerMemberId,
      lang,
      now,
      isAllowedHost: filterContext.isAllowedHost,
      identities,
      helpfulPostIds: new Set(reactions.map((r) => r.postId).filter((id): id is string => !!id)),
      helpfulReplyIds: new Set(reactions.map((r) => r.replyId).filter((id): id is string => !!id)),
      followedPostIds: new Set(follows.map((f) => f.postId)),
    };
  }

  private async summaries(
    viewer: CommunityViewer,
    rows: PostRow[],
    lang: Lang,
    now: Date,
    reasons?: Map<string, ForYouReason[]>,
  ) {
    const ctx = await this.presentContext(viewer.memberId, lang, now, rows);
    return rows.map((row) => postSummaryJson(row, ctx, reasons?.get(row.id)));
  }

  // ── Visibilité ────────────────────────────────────────────────────────────

  canSeePost(
    post: { status: CommunityContentStatus; authorMemberId: string | null },
    viewer: CommunityViewer,
    blocked: readonly string[],
  ): boolean {
    if (post.status === 'deleted') return false;
    if (post.authorMemberId && post.authorMemberId === viewer.memberId) return true;
    if (post.status !== 'visible') return false;
    return !(post.authorMemberId && blocked.includes(post.authorMemberId));
  }

  canSeeReply(
    reply: { status: CommunityContentStatus; authorMemberId: string | null },
    viewer: CommunityViewer,
    blocked: readonly string[],
  ): boolean {
    return this.canSeePost(reply, viewer, blocked);
  }

  private async loadVisiblePost(viewer: CommunityViewer, postId: string, blocked: readonly string[]): Promise<PostRow> {
    const post = await runDb(this.prisma, (db) =>
      db.communityPost.findUnique({ where: { id: postId }, include: POST_INCLUDE }),
    );
    if (!post || !this.canSeePost(post, viewer, blocked)) throw CommunityErrors.postNotFound();
    return post;
  }

  private async loadVisibleReply(
    viewer: CommunityViewer,
    replyId: string,
    blocked: readonly string[],
  ): Promise<ReplyRow & { post: { id: string; status: CommunityContentStatus; authorMemberId: string | null } }> {
    const reply = await runDb(this.prisma, (db) =>
      db.communityReply.findUnique({
        where: { id: replyId },
        include: { ...REPLY_INCLUDE, post: { select: { id: true, status: true, authorMemberId: true } } },
      }),
    );
    if (
      !reply ||
      !this.canSeePost(reply.post, viewer, blocked) ||
      !this.canSeeReply(reply, viewer, blocked)
    ) {
      throw CommunityErrors.replyNotFound();
    }
    return reply;
  }

  // ── Fils (§7.2) ───────────────────────────────────────────────────────────

  async feed(viewer: CommunityViewer, query: FeedQuery, lang: Lang, now: Date = new Date()) {
    const limit = clampLimit(query.limit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const blocked = await this.access.blockedIds(viewer.memberId);
    const hashtag = query.hashtag ? hashtagKey(query.hashtag.replace(/^#/, '')) : null;
    const feedKey = `feed:${query.tab}`;
    const cursor = decodeCursor(query.cursor, feedKey);

    const pinnedRows = cursor
      ? []
      : await runDb(this.prisma, (db) =>
          db.communityPost.findMany({
            where: { AND: [{ status: 'visible', pinnedAt: { not: null } }, notBlocked(blocked)] },
            include: POST_INCLUDE,
            orderBy: { pinnedAt: 'desc' },
            take: COMMUNITY_MAX_PINNED,
          }),
        );

    let rows: PostRow[];
    let nextCursor: string | null = null;
    let reasons: Map<string, ForYouReason[]> | undefined;

    if (query.tab === 'for_you') {
      const asOf = cursor ? cursorDate(cursor, 'a') : now;
      const followed = await runDb(this.prisma, async (db) => {
        const [saved, alerts] = await Promise.all([
          db.savedItem.findMany({ where: { userId: viewer.userId, itemType: 'scholarship' }, select: { itemId: true } }),
          db.scholarshipAlertSubscription.findMany({ where: { userId: viewer.userId }, select: { scholarshipId: true } }),
        ]);
        return [...new Set([...saved.map((s) => s.itemId), ...alerts.map((a) => a.scholarshipId)])];
      });
      const scored = await runDb(this.prisma, (db) =>
        db.$queryRaw<ForYouRow[]>(
          forYouSql({
            asOf,
            windowStart: new Date(asOf.getTime() - COMMUNITY_FOR_YOU_WINDOW_DAYS * DAY_MS),
            viewerMemberId: viewer.memberId,
            followedScholarshipIds: followed,
            targetCountryIds: viewer.targetCountryIds,
            targetLevel: viewer.scholarshipTargetLevel,
            blockedMemberIds: blocked,
            type: query.type ?? null,
            hashtag,
            cursor: cursor ? { rank: cursorRank(cursor), id: cursorString(cursor, 'i') } : null,
            limit: limit + 1,
          }),
        ),
      );
      const page = scored.slice(0, limit);
      const byId = new Map(
        (
          await runDb(this.prisma, (db) =>
            db.communityPost.findMany({ where: { id: { in: page.map((r) => r.id) } }, include: POST_INCLUDE }),
          )
        ).map((p) => [p.id, p]),
      );
      rows = page.map((r) => byId.get(r.id)).filter((p): p is PostRow => !!p);
      reasons = new Map(
        page.map((r) => {
          const post = byId.get(r.id);
          return [
            r.id,
            forYouReasons({
              followedScholarship: r.followedScholarship,
              targetCountry: r.targetCountry,
              targetLevel: r.targetLevel,
              followedDiscussion: r.followedDiscussion,
              replyCount: post?.replyCount ?? 0,
              helpfulCount: post?.helpfulCount ?? 0,
              hasVerifiedAnswer: post?.hasVerifiedAnswer ?? false,
            }),
          ];
        }),
      );
      if (scored.length > limit) {
        const last = page[page.length - 1];
        nextCursor = encodeCursor({ f: feedKey, a: asOf.toISOString(), s: last.rank, i: last.id });
      }
    } else {
      const filters: Prisma.CommunityPostWhereInput[] = [
        { status: 'visible', pinnedAt: null },
        notBlocked(blocked),
      ];
      if (query.tab === 'unanswered') {
        filters.push({ type: 'question', answerCount: 0, hasVerifiedAnswer: false });
      } else if (query.type) {
        filters.push({ type: query.type });
      }
      if (hashtag) filters.push({ hashtags: { some: { hashtag: { tag: hashtag } } } });
      if (cursor) filters.push(descCursorWhere('createdAt', cursorDate(cursor, 'c'), cursorString(cursor, 'i')));
      const found = await runDb(this.prisma, (db) =>
        db.communityPost.findMany({
          where: { AND: filters },
          include: POST_INCLUDE,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: limit + 1,
        }),
      );
      rows = found.slice(0, limit);
      if (found.length > limit) {
        const last = rows[rows.length - 1];
        nextCursor = encodeCursor({ f: feedKey, c: last.createdAt.toISOString(), i: last.id });
      }
    }

    const [items, pinned] = await Promise.all([
      this.summaries(viewer, rows, lang, now, reasons),
      this.summaries(viewer, pinnedRows, lang, now),
    ]);
    return { tab: query.tab, items, nextCursor, pinned };
  }

  // ── Espaces d'entités et compteurs (§7.3) ─────────────────────────────────

  private entityWhere(type: CommunityEntityTypeValue, id: string): Prisma.CommunityPostWhereInput {
    return { mentions: { some: { entityType: type, entityId: id } } };
  }

  async entitySpace(
    viewer: CommunityViewer,
    type: CommunityEntityTypeValue,
    id: string,
    sort: 'recent' | 'unanswered',
    rawCursor: string | undefined,
    rawLimit: number | undefined,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const entity = await this.catalog.getEntity(type, id, now);
    if (!entity) throw CommunityErrors.entityNotFound();
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const feedKey = `space:${type}:${id}:${sort}`;
    const cursor = decodeCursor(rawCursor, feedKey);
    const blocked = await this.access.blockedIds(viewer.memberId);
    const filters: Prisma.CommunityPostWhereInput[] = [
      { status: 'visible' },
      this.entityWhere(type, id),
      notBlocked(blocked),
    ];
    if (sort === 'unanswered') filters.push({ type: 'question', answerCount: 0, hasVerifiedAnswer: false });
    if (cursor) filters.push(descCursorWhere('createdAt', cursorDate(cursor, 'c'), cursorString(cursor, 'i')));
    const [found, discussionCount] = await runDb(this.prisma, (db) =>
      Promise.all([
        db.communityPost.findMany({
          where: { AND: filters },
          include: POST_INCLUDE,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: limit + 1,
        }),
        db.communityPost.count({ where: { status: 'visible', ...this.entityWhere(type, id) } }),
      ]),
    );
    const rows = found.slice(0, limit);
    return {
      entity: {
        type,
        id,
        label: lang === 'en' ? entity.labelEn : entity.labelFr,
        countryId: entity.countryId,
      },
      discussionCount,
      items: await this.summaries(viewer, rows, lang, now),
      nextCursor:
        found.length > limit
          ? encodeCursor({ f: feedKey, c: rows[rows.length - 1].createdAt.toISOString(), i: rows[rows.length - 1].id })
          : null,
    };
  }

  async entityCount(type: CommunityEntityTypeValue, id: string) {
    const discussionCount = await runDb(this.prisma, (db) =>
      db.communityPost.count({ where: { status: 'visible', ...this.entityWhere(type, id) } }),
    );
    return { type, id, discussionCount };
  }

  async entityCounts(rawRefs: string) {
    const refs: { type: CommunityEntityTypeValue; id: string }[] = [];
    const seen = new Set<string>();
    for (const part of rawRefs.split(',')) {
      const trimmed = part.trim();
      if (!trimmed) continue;
      const sep = trimmed.indexOf(':');
      const type = trimmed.slice(0, sep);
      const id = trimmed.slice(sep + 1);
      if (sep <= 0 || !isEntityType(type) || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) {
        throw new BadRequestException(`Invalid entity reference: ${trimmed.slice(0, 80)}`);
      }
      const key = `${type}:${id}`;
      if (seen.has(key)) continue;
      seen.add(key);
      refs.push({ type, id });
    }
    if (refs.length > COMMUNITY_LIMITS.countRefsMax) {
      throw new BadRequestException(`At most ${COMMUNITY_LIMITS.countRefsMax} references.`);
    }
    if (!refs.length) return { items: [] };
    const rows = await runDb(this.prisma, (db) =>
      db.$queryRaw<{ entityType: string; entityId: string; n: number }[]>`
        SELECT m."entityType"::text AS "entityType", m."entityId", COUNT(DISTINCT p."id")::int AS "n"
        FROM "CommunityMention" m
        JOIN "CommunityPost" p ON p."id" = m."postId"
        WHERE p."status" = 'visible'
          AND (m."entityType"::text, m."entityId") IN (
            SELECT * FROM unnest(${refs.map((r) => r.type)}::text[], ${refs.map((r) => r.id)}::text[])
          )
        GROUP BY 1, 2
      `,
    );
    const counts = new Map(rows.map((r) => [`${r.entityType}:${r.entityId}`, Number(r.n)]));
    return {
      items: refs.map((r) => ({ type: r.type, id: r.id, discussionCount: counts.get(`${r.type}:${r.id}`) ?? 0 })),
    };
  }

  // ── Recherche (§7.4) ──────────────────────────────────────────────────────

  async search(
    viewer: CommunityViewer,
    q: string,
    type: CommunityPostType | undefined,
    rawCursor: string | undefined,
    rawLimit: number | undefined,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const trimmed = q.trim();
    if (trimmed.length < COMMUNITY_LIMITS.searchMin || trimmed.length > COMMUNITY_LIMITS.searchMax) {
      throw new BadRequestException(
        `q must be ${COMMUNITY_LIMITS.searchMin} to ${COMMUNITY_LIMITS.searchMax} characters.`,
      );
    }
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const cursor = decodeCursor(rawCursor, 'search');
    const blocked = await this.access.blockedIds(viewer.memberId);
    const filters: Prisma.CommunityPostWhereInput[] = [{ status: 'visible' }, notBlocked(blocked)];
    if (trimmed.startsWith('#')) {
      const tag = hashtagKey(trimmed.slice(1));
      if (!tag) return { items: [], nextCursor: null };
      filters.push({ hashtags: { some: { hashtag: { tag } } } });
    } else {
      const terms = searchTerms(trimmed);
      if (!terms.length) return { items: [], nextCursor: null };
      for (const term of terms) filters.push({ searchText: { contains: term } });
    }
    if (type) filters.push({ type });
    if (cursor) filters.push(descCursorWhere('createdAt', cursorDate(cursor, 'c'), cursorString(cursor, 'i')));
    const found = await runDb(this.prisma, (db) =>
      db.communityPost.findMany({
        where: { AND: filters },
        include: POST_INCLUDE,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const rows = found.slice(0, limit);
    return {
      items: await this.summaries(viewer, rows, lang, now),
      nextCursor:
        found.length > limit
          ? encodeCursor({ f: 'search', c: rows[rows.length - 1].createdAt.toISOString(), i: rows[rows.length - 1].id })
          : null,
    };
  }

  /** Autocomplétion des hashtags (§7.5) : préfixe, les plus utilisés d'abord. */
  async suggestHashtags(q: string | undefined, rawLimit: number | undefined) {
    const limit = clampLimit(rawLimit, 10, COMMUNITY_PAGINATION.suggestMaxLimit);
    const prefix = hashtagKey((q ?? '').replace(/^#/, '')).slice(0, COMMUNITY_LIMITS.hashtagMax);
    const like = `${prefix.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const rows = await runDb(this.prisma, (db) =>
      db.$queryRaw<{ tag: string; display: string; n: number }[]>`
        SELECT h."tag", h."display", COUNT(p."id")::int AS "n"
        FROM "CommunityHashtag" h
        JOIN "CommunityPostHashtag" ph ON ph."hashtagId" = h."id"
        JOIN "CommunityPost" p ON p."id" = ph."postId" AND p."status" = 'visible'
        WHERE h."tag" LIKE ${like}
        GROUP BY h."id", h."tag", h."display"
        ORDER BY "n" DESC, h."tag" ASC
        LIMIT ${limit}
      `,
    );
    return { items: rows.map((r) => ({ tag: r.tag, display: r.display, postCount: Number(r.n) })) };
  }

  // ── Détail et réponses (§7.6) ─────────────────────────────────────────────

  async getPost(viewer: CommunityViewer, postId: string, lang: Lang, now: Date = new Date()) {
    const blocked = await this.access.blockedIds(viewer.memberId);
    const post = await this.loadVisiblePost(viewer, postId, blocked);
    const replies = await this.replyPage(viewer, post.id, blocked, undefined, undefined);
    const ctx = await this.presentContext(viewer.memberId, lang, now, [post], replies.rows);
    return {
      post: postJson(post, ctx),
      replies: { items: replies.rows.map((r) => replyJson(r, ctx)), nextCursor: replies.nextCursor },
    };
  }

  async listReplies(
    viewer: CommunityViewer,
    postId: string,
    rawCursor: string | undefined,
    rawLimit: number | undefined,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const blocked = await this.access.blockedIds(viewer.memberId);
    const post = await this.loadVisiblePost(viewer, postId, blocked);
    const page = await this.replyPage(viewer, post.id, blocked, rawCursor, rawLimit);
    const ctx = await this.presentContext(viewer.memberId, lang, now, [], page.rows);
    return { items: page.rows.map((r) => replyJson(r, ctx)), nextCursor: page.nextCursor };
  }

  /**
   * Réponses lisibles : la vérifiée en tête (première page), puis l'ordre
   * chronologique. Les siennes, même masquées, restent visibles de l'auteur.
   */
  private async replyPage(
    viewer: CommunityViewer,
    postId: string,
    blocked: readonly string[],
    rawCursor: string | undefined,
    rawLimit: number | undefined,
  ): Promise<{ rows: ReplyRow[]; nextCursor: string | null }> {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.repliesDefaultLimit, COMMUNITY_PAGINATION.repliesMaxLimit);
    const feedKey = `replies:${postId}`;
    const cursor = decodeCursor(rawCursor, feedKey);
    const readable: Prisma.CommunityReplyWhereInput = {
      OR: [
        { AND: [{ status: 'visible' }, notBlockedReply(blocked)] },
        { authorMemberId: viewer.memberId, status: { in: ['pending_review', 'hidden'] } },
      ],
    };
    return runDb(this.prisma, async (db) => {
      const verified = cursor
        ? null
        : await db.communityReply.findFirst({
            where: { AND: [{ postId, isVerified: true, status: 'visible' }, notBlockedReply(blocked)] },
            include: REPLY_INCLUDE,
          });
      const filters: Prisma.CommunityReplyWhereInput[] = [{ postId }, readable, { NOT: { isVerified: true, status: 'visible' } }];
      if (cursor) {
        const at = cursorDate(cursor, 'c');
        const id = cursorString(cursor, 'i');
        filters.push({ OR: [{ createdAt: { gt: at } }, { createdAt: at, id: { gt: id } }] });
      }
      const take = limit - (verified ? 1 : 0);
      const found = await db.communityReply.findMany({
        where: { AND: filters },
        include: REPLY_INCLUDE,
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        take: take + 1,
      });
      const page = found.slice(0, take);
      const last = page[page.length - 1];
      return {
        rows: [...(verified ? [verified] : []), ...page],
        nextCursor:
          found.length > take && last
            ? encodeCursor({ f: feedKey, c: last.createdAt.toISOString(), i: last.id })
            : null,
      };
    });
  }

  // ── Écritures : publications (§7.6) ───────────────────────────────────────

  private validateTitle(title: string): string {
    const t = title.trim();
    if (t.length < COMMUNITY_LIMITS.titleMin || t.length > COMMUNITY_LIMITS.titleMax) {
      throw new BadRequestException(
        `title must be ${COMMUNITY_LIMITS.titleMin} to ${COMMUNITY_LIMITS.titleMax} characters.`,
      );
    }
    return t;
  }

  private validateBody(body: string, min: number, max: number): string {
    const b = body.trim();
    if (b.length < min || b.length > max) {
      throw new BadRequestException(`body must be ${min} to ${max} characters.`);
    }
    return b;
  }

  async createPost(
    viewer: CommunityViewer,
    input: { type: CommunityPostType; title: string; body: string },
    lang: Lang,
    now: Date = new Date(),
  ) {
    const title = this.validateTitle(input.title);
    const body = this.validateBody(input.body, COMMUNITY_LIMITS.postBodyMin, COMMUNITY_LIMITS.postBodyMax);
    await this.access.assertCanWrite(viewer, now);
    await this.access.assertQuota(viewer, 'posts_per_day', now);
    const prepared = await this.composer.prepare({ title, body, isPost: true, authorEmail: viewer.email, now });
    const decision = statusForFlags(prepared.flags);
    const postId = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const post = await tx.communityPost.create({
          data: {
            type: input.type,
            title,
            body: prepared.body,
            authorKind: 'member',
            authorMemberId: viewer.memberId,
            status: decision.status,
            statusReason: decision.statusReason,
            statusChangedAt: decision.status === 'visible' ? null : now,
            filterFlags: prepared.flags,
            searchText: prepared.searchText,
            lastActivityAt: now,
            createdAt: now,
            mentions: { create: mentionRows(prepared.mentions) },
          },
        });
        await this.composer.writeHashtags(tx, post.id, prepared.hashtags);
        await tx.communityFollow.create({ data: { memberId: viewer.memberId, postId: post.id, createdAt: now } });
        return post.id;
      }),
    );
    if (decision.status === 'visible') await this.verifBotQueue?.enqueue(postId);
    const row = await runDb(this.prisma, (db) =>
      db.communityPost.findUniqueOrThrow({ where: { id: postId }, include: POST_INCLUDE }),
    );
    const ctx = await this.presentContext(viewer.memberId, lang, now, [row]);
    return postJson(row, ctx);
  }

  private assertEditable(row: { authorMemberId: string | null; createdAt: Date; status: string }, viewer: CommunityViewer, now: Date) {
    if (row.authorMemberId !== viewer.memberId) throw CommunityErrors.notAuthor();
    const until = new Date(row.createdAt.getTime() + COMMUNITY_EDIT_WINDOW_MS);
    if (now.getTime() > until.getTime()) throw CommunityErrors.editWindowClosed(until);
  }

  /**
   * Statut après modification : un contenu visible ou masqué PAR LE FILTRE est
   * re-jugé ; un contenu masqué par l'équipe ou par les signalements le reste.
   */
  private statusAfterEdit(
    current: { status: CommunityContentStatus; statusReason: string | null },
    flags: Parameters<typeof statusForFlags>[0],
  ): { status: CommunityContentStatus; statusReason: string | null } {
    const rejudged =
      current.status === 'visible' ||
      (current.status === 'pending_review' &&
        (current.statusReason === 'auto_filter' || current.statusReason === 'new_account_review'));
    return rejudged ? statusForFlags(flags) : { status: current.status, statusReason: current.statusReason };
  }

  async updatePost(
    viewer: CommunityViewer,
    postId: string,
    input: { type?: CommunityPostType; title?: string; body?: string },
    lang: Lang,
    now: Date = new Date(),
  ) {
    if (input.type === undefined && input.title === undefined && input.body === undefined) {
      throw new BadRequestException('Nothing to update.');
    }
    const existing = await runDb(this.prisma, (db) => db.communityPost.findUnique({ where: { id: postId } }));
    if (!existing || existing.status === 'deleted') throw CommunityErrors.postNotFound();
    if (existing.authorMemberId !== viewer.memberId) {
      const blocked = await this.access.blockedIds(viewer.memberId);
      if (!this.canSeePost(existing, viewer, blocked)) throw CommunityErrors.postNotFound();
    }
    this.assertEditable(existing, viewer, now);
    await this.access.assertCanWrite(viewer, now);
    const title = input.title !== undefined ? this.validateTitle(input.title) : existing.title;
    const body =
      input.body !== undefined
        ? this.validateBody(input.body, COMMUNITY_LIMITS.postBodyMin, COMMUNITY_LIMITS.postBodyMax)
        : existing.body;
    const prepared = await this.composer.prepare({ title, body, isPost: true, authorEmail: viewer.email, now });
    const next = this.statusAfterEdit(existing, prepared.flags);
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        await tx.communityMention.deleteMany({ where: { postId } });
        await tx.communityPost.update({
          where: { id: postId },
          data: {
            type: input.type ?? existing.type,
            title,
            body: prepared.body,
            status: next.status,
            statusReason: next.statusReason,
            statusChangedAt: next.status !== existing.status ? now : existing.statusChangedAt,
            filterFlags: prepared.flags,
            searchText: prepared.searchText,
            editedAt: now,
            mentions: { create: mentionRows(prepared.mentions) },
          },
        });
        await this.composer.writeHashtags(tx, postId, prepared.hashtags);
      }),
    );
    // Texte modifié : le brouillon du bot (s'il n'est ni publié ni rejeté) est refait.
    if (next.status === 'visible') await this.verifBotQueue?.enqueue(postId, { reset: true });
    const row = await runDb(this.prisma, (db) =>
      db.communityPost.findUniqueOrThrow({ where: { id: postId }, include: POST_INCLUDE }),
    );
    const ctx = await this.presentContext(viewer.memberId, lang, now, [row]);
    return postJson(row, ctx);
  }

  async deletePost(viewer: CommunityViewer, postId: string, now: Date = new Date()): Promise<void> {
    const existing = await runDb(this.prisma, (db) => db.communityPost.findUnique({ where: { id: postId } }));
    if (!existing || existing.status === 'deleted') throw CommunityErrors.postNotFound();
    if (existing.authorMemberId !== viewer.memberId) {
      const blocked = await this.access.blockedIds(viewer.memberId);
      if (!this.canSeePost(existing, viewer, blocked)) throw CommunityErrors.postNotFound();
      throw CommunityErrors.notAuthor();
    }
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        await tx.communityPost.update({
          where: { id: postId },
          data: { status: 'deleted', statusReason: 'author_deleted', statusChangedAt: now, deletedAt: now, pinnedAt: null },
        });
        // Contenu retiré par son auteur : ses signalements ouverts sont clos.
        await tx.communityReport.updateMany({
          where: { status: 'open', OR: [{ postId }, { reply: { postId } }] },
          data: { status: 'dismissed', resolvedAt: now, resolutionNote: 'content_deleted_by_author' },
        });
        await refreshPostCounters(tx, [postId]);
      }),
    );
  }

  // ── Écritures : réponses (§7.7) ───────────────────────────────────────────

  async createReply(
    viewer: CommunityViewer,
    postId: string,
    input: { body: string },
    lang: Lang,
    now: Date = new Date(),
  ) {
    const body = this.validateBody(input.body, COMMUNITY_LIMITS.replyBodyMin, COMMUNITY_LIMITS.replyBodyMax);
    const blocked = await this.access.blockedIds(viewer.memberId);
    const post = await this.loadVisiblePost(viewer, postId, blocked);
    if (post.status !== 'visible') throw CommunityErrors.postNotOpen();
    await this.access.assertCanWrite(viewer, now);
    await this.access.assertQuota(viewer, 'replies_per_hour', now);
    const prepared = await this.composer.prepare({ body, isPost: false, authorEmail: viewer.email, now });
    const decision = statusForFlags(prepared.flags);
    const replyId = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const reply = await tx.communityReply.create({
          data: {
            postId,
            body: prepared.body,
            authorKind: 'member',
            authorMemberId: viewer.memberId,
            status: decision.status,
            statusReason: decision.statusReason,
            statusChangedAt: decision.status === 'visible' ? null : now,
            filterFlags: prepared.flags,
            createdAt: now,
            mentions: { create: mentionRows(prepared.mentions) },
          },
        });
        await tx.communityFollow.createMany({
          data: [{ memberId: viewer.memberId, postId, createdAt: now }],
          skipDuplicates: true,
        });
        await refreshPostCounters(tx, [postId]);
        return reply.id;
      }),
    );
    if (decision.status === 'visible') {
      await this.notifications.replyPosted({
        post: { id: post.id, title: post.title, type: post.type, authorMemberId: post.authorMemberId },
        reply: { id: replyId, authorMemberId: viewer.memberId },
        now,
      });
    }
    const row = await runDb(this.prisma, (db) =>
      db.communityReply.findUniqueOrThrow({ where: { id: replyId }, include: REPLY_INCLUDE }),
    );
    const ctx = await this.presentContext(viewer.memberId, lang, now, [], [row]);
    return replyJson(row, ctx);
  }

  async updateReply(
    viewer: CommunityViewer,
    replyId: string,
    input: { body: string },
    lang: Lang,
    now: Date = new Date(),
  ) {
    const blocked = await this.access.blockedIds(viewer.memberId);
    const existing = await this.loadVisibleReply(viewer, replyId, blocked);
    this.assertEditable(existing, viewer, now);
    await this.access.assertCanWrite(viewer, now);
    const body = this.validateBody(input.body, COMMUNITY_LIMITS.replyBodyMin, COMMUNITY_LIMITS.replyBodyMax);
    const prepared = await this.composer.prepare({ body, isPost: false, authorEmail: viewer.email, now });
    const next = this.statusAfterEdit(existing, prepared.flags);
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        await tx.communityMention.deleteMany({ where: { replyId } });
        await tx.communityReply.update({
          where: { id: replyId },
          data: {
            body: prepared.body,
            status: next.status,
            statusReason: next.statusReason,
            statusChangedAt: next.status !== existing.status ? now : existing.statusChangedAt,
            filterFlags: prepared.flags,
            editedAt: now,
            mentions: { create: mentionRows(prepared.mentions) },
          },
        });
        await refreshPostCounters(tx, [existing.postId]);
      }),
    );
    const row = await runDb(this.prisma, (db) =>
      db.communityReply.findUniqueOrThrow({ where: { id: replyId }, include: REPLY_INCLUDE }),
    );
    const ctx = await this.presentContext(viewer.memberId, lang, now, [], [row]);
    return replyJson(row, ctx);
  }

  async deleteReply(viewer: CommunityViewer, replyId: string, now: Date = new Date()): Promise<void> {
    const blocked = await this.access.blockedIds(viewer.memberId);
    const existing = await this.loadVisibleReply(viewer, replyId, blocked);
    if (existing.authorMemberId !== viewer.memberId) throw CommunityErrors.notAuthor();
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        await tx.communityReply.update({
          where: { id: replyId },
          data: { status: 'deleted', statusReason: 'author_deleted', statusChangedAt: now, deletedAt: now },
        });
        await tx.communityReport.updateMany({
          where: { status: 'open', replyId },
          data: { status: 'dismissed', resolvedAt: now, resolutionNote: 'content_deleted_by_author' },
        });
        await refreshReplyCounters(tx, [replyId]);
        await refreshPostCounters(tx, [existing.postId]);
      }),
    );
  }

  // ── « Utile » et suivi (§7.8, §7.9) ───────────────────────────────────────

  async setPostHelpful(viewer: CommunityViewer, postId: string, on: boolean, now: Date = new Date()) {
    const blocked = await this.access.blockedIds(viewer.memberId);
    const post = await this.loadVisiblePost(viewer, postId, blocked);
    if (post.status !== 'visible') throw CommunityErrors.postNotFound();
    if (post.authorMemberId === viewer.memberId) throw CommunityErrors.cannotReactOwn();
    await this.access.assertCanWrite(viewer, now);
    return runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (on) {
          await tx.communityReaction.createMany({
            data: [{ memberId: viewer.memberId, postId, createdAt: now }],
            skipDuplicates: true,
          });
        } else {
          await tx.communityReaction.deleteMany({ where: { memberId: viewer.memberId, postId } });
        }
        await refreshPostCounters(tx, [postId]);
        const row = await tx.communityPost.findUniqueOrThrow({ where: { id: postId }, select: { helpfulCount: true } });
        return { helpfulCount: row.helpfulCount, hasMarkedHelpful: on };
      }),
    );
  }

  async setReplyHelpful(viewer: CommunityViewer, replyId: string, on: boolean, now: Date = new Date()) {
    const blocked = await this.access.blockedIds(viewer.memberId);
    const reply = await this.loadVisibleReply(viewer, replyId, blocked);
    if (reply.status !== 'visible' || reply.post.status !== 'visible') throw CommunityErrors.replyNotFound();
    if (reply.authorMemberId === viewer.memberId) throw CommunityErrors.cannotReactOwn();
    await this.access.assertCanWrite(viewer, now);
    return runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (on) {
          await tx.communityReaction.createMany({
            data: [{ memberId: viewer.memberId, replyId, createdAt: now }],
            skipDuplicates: true,
          });
        } else {
          await tx.communityReaction.deleteMany({ where: { memberId: viewer.memberId, replyId } });
        }
        await refreshReplyCounters(tx, [replyId]);
        const row = await tx.communityReply.findUniqueOrThrow({ where: { id: replyId }, select: { helpfulCount: true } });
        return { helpfulCount: row.helpfulCount, hasMarkedHelpful: on };
      }),
    );
  }

  async setFollow(viewer: CommunityViewer, postId: string, on: boolean) {
    const blocked = await this.access.blockedIds(viewer.memberId);
    await this.loadVisiblePost(viewer, postId, blocked);
    await runDb(this.prisma, (db) =>
      on
        ? db.communityFollow.createMany({ data: [{ memberId: viewer.memberId, postId }], skipDuplicates: true })
        : db.communityFollow.deleteMany({ where: { memberId: viewer.memberId, postId } }),
    );
    return { isFollowing: on };
  }

  // ── Mes publications, mes suivis (§7.1) ───────────────────────────────────

  async myPosts(viewer: CommunityViewer, rawCursor: string | undefined, rawLimit: number | undefined, lang: Lang, now: Date = new Date()) {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const cursor = decodeCursor(rawCursor, 'me:posts');
    const filters: Prisma.CommunityPostWhereInput[] = [
      { authorMemberId: viewer.memberId, status: { not: 'deleted' } },
    ];
    if (cursor) filters.push(descCursorWhere('createdAt', cursorDate(cursor, 'c'), cursorString(cursor, 'i')));
    const found = await runDb(this.prisma, (db) =>
      db.communityPost.findMany({
        where: { AND: filters },
        include: POST_INCLUDE,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const rows = found.slice(0, limit);
    return {
      items: await this.summaries(viewer, rows, lang, now),
      nextCursor:
        found.length > limit
          ? encodeCursor({ f: 'me:posts', c: rows[rows.length - 1].createdAt.toISOString(), i: rows[rows.length - 1].id })
          : null,
    };
  }

  async myFollowing(viewer: CommunityViewer, rawCursor: string | undefined, rawLimit: number | undefined, lang: Lang, now: Date = new Date()) {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const cursor = decodeCursor(rawCursor, 'me:following');
    const blocked = await this.access.blockedIds(viewer.memberId);
    const filters: Prisma.CommunityPostWhereInput[] = [
      { status: 'visible', follows: { some: { memberId: viewer.memberId } } },
      notBlocked(blocked),
    ];
    if (cursor) {
      filters.push(descCursorWhere('lastActivityAt', cursorDate(cursor, 'c'), cursorString(cursor, 'i')));
    }
    const found = await runDb(this.prisma, (db) =>
      db.communityPost.findMany({
        where: { AND: filters },
        include: POST_INCLUDE,
        orderBy: [{ lastActivityAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const rows = found.slice(0, limit);
    return {
      items: await this.summaries(viewer, rows, lang, now),
      nextCursor:
        found.length > limit
          ? encodeCursor({
              f: 'me:following',
              c: rows[rows.length - 1].lastActivityAt.toISOString(),
              i: rows[rows.length - 1].id,
            })
          : null,
    };
  }
}
