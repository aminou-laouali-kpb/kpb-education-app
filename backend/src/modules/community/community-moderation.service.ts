import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  type CommunityContentStatus,
  type CommunityPostType,
  type CommunityReportReason,
  type CommunityReportTarget,
  type CommunitySanctionKind,
  type InternalRole,
} from '@prisma/client';
import { randomUUID } from 'node:crypto';

import { PrismaService } from '../prisma/prisma.service';
import { publicNameFromFullName } from '../referrals/referral-code';
import {
  COMMUNITY_AUDIT_PURPOSE,
  COMMUNITY_LIMITS,
  COMMUNITY_MAX_PINNED,
  COMMUNITY_NEW_ACCOUNT_DAYS,
  COMMUNITY_PAGINATION,
  COMMUNITY_REPORT_HIDE_THRESHOLD,
} from './community.constants';
import { CommunityAccessService, type CommunityViewer } from './community-access.service';
import { CommunityComposerService, mentionRows } from './community-composer.service';
import {
  BUILTIN_ALLOWED_DOMAINS,
  BUILTIN_BLOCKED_TERMS_COUNT,
  FILTER_FLAGS,
} from './community-content-filter';
import { refreshPostCounters, refreshReplyCounters } from './community-counters';
import { cursorDate, cursorString, decodeCursor, encodeCursor } from './community-cursor';
import { runDb } from './community-db';
import { CommunityErrors } from './community-errors';
import { CommunityFilterConfigService } from './community-filter-config.service';
import { CommunityNotificationsService, type ModerationEvent } from './community-notifications.service';
import { CommunityPostsService } from './community-posts.service';
import {
  KPB_TEAM_NAME,
  POST_INCLUDE,
  REPLY_INCLUDE,
  memberAuthor,
  postJson,
  replyJson,
  type AuthorJson,
  type PostRow,
  type PresentContext,
  type ReplyRow,
} from './community-presenter';
import { searchTerms, type Lang } from './community-text';

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

export interface ModerationActor {
  id: string;
  fullName: string;
  role: string;
}

export type ContentAction = 'restore' | 'hide' | 'delete' | 'dismiss_reports';

interface AdminIdentity {
  userId: string;
  fullName: string | null;
  email: string | null;
  birthDate: Date | null;
  accountCreatedAt: Date;
}

function clampLimit(raw: number | undefined, def: number, max: number): number {
  if (raw === undefined || raw === null || Number.isNaN(raw)) return def;
  return Math.max(1, Math.min(max, Math.floor(raw)));
}

function isMinorAt(birthDate: Date | null, now: Date): boolean | null {
  if (!birthDate) return null;
  const adult = new Date(birthDate);
  adult.setUTCFullYear(adult.getUTCFullYear() + 18);
  return adult.getTime() > now.getTime();
}

/** Médiane arrondie au dixième, `null` sur une liste vide. */
function median(values: number[]): number | null {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length / 2;
  const m = sorted.length % 2 ? sorted[(sorted.length - 1) / 2] : (sorted[mid - 1] + sorted[mid]) / 2;
  return Math.round(m * 10) / 10;
}

function cleanReason(reason: string): string {
  const r = (reason ?? '').trim();
  if (r.length < COMMUNITY_LIMITS.adminReasonMin || r.length > COMMUNITY_LIMITS.adminReasonMax) {
    throw new BadRequestException(
      `reason must be ${COMMUNITY_LIMITS.adminReasonMin} to ${COMMUNITY_LIMITS.adminReasonMax} characters.`,
    );
  }
  return r;
}

/**
 * Signalements (élève) et tout le travail de l'équipe (§7.10, §8 du contrat) :
 * file, actions, sanctions, réponses d'équipe, vérification, épinglage,
 * statistiques, filtre. Chaque écriture admin laisse un `AdminAuditEvent` et,
 * pour la modération, une ligne `ForumModerationAction`.
 */
@Injectable()
export class CommunityModerationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: CommunityAccessService,
    private readonly composer: CommunityComposerService,
    private readonly filterConfig: CommunityFilterConfigService,
    private readonly notifications: CommunityNotificationsService,
    private readonly posts: CommunityPostsService,
  ) {}

  // ── Signaler (élève, §7.10) ───────────────────────────────────────────────

  async report(
    viewer: CommunityViewer,
    input: { targetType: CommunityReportTarget; targetId: string; reason: CommunityReportReason; details?: string },
    now: Date = new Date(),
  ) {
    // Re-signaler la même cible rend le signalement existant, même si la cible
    // a été masquée entre-temps (par exemple par le seuil que ce membre a
    // contribué à atteindre) : idempotent, jamais un 404 surprise.
    const targetKey = `${input.targetType}:${input.targetId}`;
    const existing = await runDb(this.prisma, (db) =>
      db.communityReport.findFirst({ where: { reporterMemberId: viewer.memberId, targetKey } }),
    );
    if (existing) return { created: false, report: this.reportJson(existing) };

    const blocked = await this.access.blockedIds(viewer.memberId);
    let postId: string | null = null;
    let replyId: string | null = null;
    let targetMemberId: string | null = null;

    await runDb(this.prisma, async (db) => {
      if (input.targetType === 'post') {
        const post = await db.communityPost.findUnique({ where: { id: input.targetId } });
        if (!post || !this.posts.canSeePost(post, viewer, blocked)) throw CommunityErrors.postNotFound();
        if (post.authorMemberId === viewer.memberId) throw CommunityErrors.cannotReportSelf();
        postId = post.id;
      } else if (input.targetType === 'reply') {
        const reply = await db.communityReply.findUnique({
          where: { id: input.targetId },
          include: { post: { select: { status: true, authorMemberId: true } } },
        });
        if (
          !reply ||
          !this.posts.canSeePost(reply.post, viewer, blocked) ||
          !this.posts.canSeeReply(reply, viewer, blocked)
        ) {
          throw CommunityErrors.replyNotFound();
        }
        if (reply.authorMemberId === viewer.memberId) throw CommunityErrors.cannotReportSelf();
        replyId = reply.id;
        postId = reply.postId;
      } else {
        if (input.targetId === viewer.memberId) throw CommunityErrors.cannotReportSelf();
        const member = await db.communityMember.findUnique({ where: { id: input.targetId }, select: { id: true } });
        if (!member) throw CommunityErrors.memberNotFound();
        targetMemberId = member.id;
      }
    });

    await this.access.assertQuota(viewer, 'reports_per_day', now);
    const details = input.details?.trim() || null;
    const report = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const created = await tx.communityReport.create({
          data: {
            reporterMemberId: viewer.memberId,
            targetType: input.targetType,
            targetKey,
            postId: input.targetType === 'post' ? postId : null,
            replyId,
            targetMemberId,
            reason: input.reason,
            details: details ? details.slice(0, COMMUNITY_LIMITS.reportDetailsMax) : null,
            createdAt: now,
          },
        });
        await this.applyReportThreshold(tx, input.targetType, input.targetId, now);
        if (replyId) await refreshReplyCounters(tx, [replyId]);
        if (postId) await refreshPostCounters(tx, [postId]);
        return created;
      }),
    );
    return { created: true, report: this.reportJson(report) };
  }

  /** §9.3 : 3 signaleurs distincts → masquage provisoire d'un contenu de membre. */
  private async applyReportThreshold(
    tx: Prisma.TransactionClient,
    targetType: CommunityReportTarget,
    targetId: string,
    now: Date,
  ): Promise<void> {
    if (targetType === 'member') return;
    const reporters = await tx.communityReport.findMany({
      where: { targetKey: `${targetType}:${targetId}`, status: 'open', reporterMemberId: { not: null } },
      select: { reporterMemberId: true },
      distinct: ['reporterMemberId'],
    });
    if (reporters.length < COMMUNITY_REPORT_HIDE_THRESHOLD) return;
    const data = { status: 'pending_review' as const, statusReason: 'reports_threshold', statusChangedAt: now };
    if (targetType === 'post') {
      await tx.communityPost.updateMany({ where: { id: targetId, status: 'visible', authorKind: 'member' }, data });
    } else {
      await tx.communityReply.updateMany({ where: { id: targetId, status: 'visible', authorKind: 'member' }, data });
    }
  }

  private reportJson(r: {
    id: string;
    targetType: string;
    targetKey: string;
    reason: string;
    status: string;
    createdAt: Date;
  }) {
    return {
      id: r.id,
      targetType: r.targetType,
      targetId: r.targetKey.slice(r.targetKey.indexOf(':') + 1),
      reason: r.reason,
      status: r.status,
      createdAt: r.createdAt.toISOString(),
    };
  }

  // ── Présentation admin (§8.1) ─────────────────────────────────────────────

  /**
   * Identité réelle (nom complet, e-mail) : Admin et SuperAdmin seulement.
   * Moderator, ContentManager et Counselor reçoivent `null` à la place, et
   * gardent les drapeaux utiles à la modération (mineur, compte récent).
   */
  static revealsIdentity(role: string): boolean {
    return role === 'admin' || role === 'super_admin';
  }

  private async adminIdentities(
    memberIds: Iterable<string | null | undefined>,
    role: string,
  ): Promise<Map<string, AdminIdentity>> {
    const reveal = CommunityModerationService.revealsIdentity(role);
    const ids = [...new Set([...memberIds].filter((id): id is string => !!id))];
    const out = new Map<string, AdminIdentity>();
    if (!ids.length) return out;
    const rows = await runDb(this.prisma, (db) =>
      db.communityMember.findMany({
        where: { id: { in: ids } },
        select: {
          id: true,
          userId: true,
          user: { select: { fullName: true, email: true, birthDate: true, createdAt: true } },
        },
      }),
    );
    for (const r of rows) {
      out.set(r.id, {
        userId: r.userId,
        fullName: reveal ? r.user.fullName : null,
        email: reveal ? r.user.email : null,
        birthDate: r.user.birthDate,
        accountCreatedAt: r.user.createdAt,
      });
    }
    return out;
  }

  private adminAuthor(
    author: AuthorJson,
    row: { authorMemberId: string | null; authorAdminId: string | null },
    identities: ReadonlyMap<string, AdminIdentity>,
    now: Date,
  ) {
    const identity = row.authorMemberId ? identities.get(row.authorMemberId) : undefined;
    return {
      ...author,
      userId: identity?.userId ?? null,
      fullName: identity?.fullName ?? null,
      email: identity?.email ?? null,
      isMinor: identity ? isMinorAt(identity.birthDate, now) : null,
      isNewAccount: identity
        ? now.getTime() - identity.accountCreatedAt.getTime() < COMMUNITY_NEW_ACCOUNT_DAYS * DAY_MS
        : null,
      accountCreatedAt: identity?.accountCreatedAt.toISOString() ?? null,
      adminId: row.authorAdminId,
    };
  }

  private async adminContext(
    posts: readonly PostRow[],
    replies: readonly ReplyRow[],
    lang: Lang,
    now: Date,
    role: string,
  ) {
    const ctx = await this.posts.presentContext(null, lang, now, posts, replies);
    const identities = await this.adminIdentities([
      ...posts.map((p) => p.authorMemberId),
      ...replies.map((r) => r.authorMemberId),
    ], role);
    return { ctx, identities };
  }

  private adminPostJson(row: PostRow, ctx: PresentContext, identities: ReadonlyMap<string, AdminIdentity>, now: Date) {
    const { viewer: _viewer, moderation: _moderation, ...base } = postJson(row, ctx);
    void _viewer;
    void _moderation;
    return {
      ...base,
      author: this.adminAuthor(base.author, row, identities, now),
      status: row.status,
      statusReason: row.statusReason,
      filterFlags: row.filterFlags,
      openReportCount: row.openReportCount,
      deletedAt: row.deletedAt?.toISOString() ?? null,
      pinnedAt: row.pinnedAt?.toISOString() ?? null,
    };
  }

  private adminReplyJson(row: ReplyRow, ctx: PresentContext, identities: ReadonlyMap<string, AdminIdentity>, now: Date) {
    const { viewer: _viewer, moderation: _moderation, ...base } = replyJson(row, ctx);
    void _viewer;
    void _moderation;
    return {
      ...base,
      author: this.adminAuthor(base.author, row, identities, now),
      status: row.status,
      statusReason: row.statusReason,
      filterFlags: row.filterFlags,
      openReportCount: row.openReportCount,
      deletedAt: row.deletedAt?.toISOString() ?? null,
    };
  }

  private async adminReports(where: Prisma.CommunityReportWhereInput, take: number) {
    const rows = await runDb(this.prisma, (db) =>
      db.communityReport.findMany({ where, orderBy: { createdAt: 'desc' }, take }),
    );
    const identities = await this.access.identities(rows.map((r) => r.reporterMemberId));
    return rows.map((r) => {
      const reporter = r.reporterMemberId ? identities.get(r.reporterMemberId) : undefined;
      return {
        ...this.reportJson(r),
        details: r.details,
        reporter: reporter
          ? { memberId: reporter.memberId, displayName: memberAuthor(reporter).displayName }
          : null,
        resolvedAt: r.resolvedAt?.toISOString() ?? null,
        resolvedBy: r.resolvedByName,
        resolutionNote: r.resolutionNote,
      };
    });
  }

  private async adminMember(memberId: string, now: Date, role: string) {
    const member = await runDb(this.prisma, (db) =>
      db.communityMember.findUnique({
        where: { id: memberId },
        include: { sanctions: { orderBy: { createdAt: 'desc' } } },
      }),
    );
    if (!member) throw CommunityErrors.memberNotFound();
    const [identities, adminIdentities, restriction, stats, openReportCount] = await Promise.all([
      this.access.identities([memberId]),
      this.adminIdentities([memberId], role),
      this.access.restriction(memberId, now),
      this.access.stats(memberId),
      runDb(this.prisma, (db) => db.communityReport.count({ where: { targetMemberId: memberId, status: 'open' } })),
    ]);
    const identity = identities.get(memberId);
    const author: AuthorJson = identity
      ? memberAuthor(identity)
      : { kind: 'member', memberId, displayName: 'Membre', countryName: null, badges: [] };
    return {
      ...this.adminAuthor(author, { authorMemberId: memberId, authorAdminId: null }, adminIdentities, now),
      charterVersion: member.charterVersion,
      charterAcceptedAt: member.charterAcceptedAt?.toISOString() ?? null,
      restriction: restriction
        ? { kind: restriction.kind, until: restriction.until?.toISOString() ?? null, reason: restriction.reason }
        : null,
      stats,
      sanctions: member.sanctions.map((s) => this.sanctionJson(s, now)),
      openReportCount,
    };
  }

  private sanctionJson(
    s: {
      id: string;
      kind: CommunitySanctionKind;
      reason: string;
      endsAt: Date | null;
      createdAt: Date;
      createdByAdminId: string;
      createdByName: string;
      revokedAt: Date | null;
      revokedByName: string | null;
    },
    now: Date,
  ) {
    const active =
      s.revokedAt === null && s.kind !== 'warning' && (s.endsAt === null || s.endsAt.getTime() > now.getTime());
    return {
      id: s.id,
      kind: s.kind,
      reason: s.reason,
      endsAt: s.endsAt?.toISOString() ?? null,
      createdAt: s.createdAt.toISOString(),
      createdBy: { adminId: s.createdByAdminId, name: s.createdByName },
      revokedAt: s.revokedAt?.toISOString() ?? null,
      revokedBy: s.revokedByName,
      active,
    };
  }

  // ── File de modération (§8.2) ─────────────────────────────────────────────

  async queue(
    role: string,
    kind: 'all' | 'auto_hidden' | 'reported' | 'members',
    rawCursor: string | undefined,
    rawLimit: number | undefined,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const feedKey = `queue:${kind}`;
    const cursor = decodeCursor(rawCursor, feedKey);
    const kindFilter =
      kind === 'auto_hidden'
        ? Prisma.sql`AND q."autoHidden"`
        : kind === 'reported'
          ? Prisma.sql`AND q."reported" AND q."t" <> 'member'`
          : kind === 'members'
            ? Prisma.sql`AND q."t" = 'member'`
            : Prisma.empty;
    const cursorFilter = cursor
      ? Prisma.sql`AND (q."flaggedAt" > ${cursorDate(cursor, 'c')}::timestamptz AT TIME ZONE 'UTC' OR (q."flaggedAt" = (${cursorDate(cursor, 'c')}::timestamptz AT TIME ZONE 'UTC') AND q."key" > ${cursorString(cursor, 'k')}))`
      : Prisma.empty;

    const base = Prisma.sql`
      WITH open_reports AS (
        SELECT "targetType"::text AS "t", COALESCE("postId", "replyId", "targetMemberId") AS "id",
               MIN("createdAt") AS "firstOpen", COUNT(*)::int AS "n"
        FROM "CommunityReport"
        WHERE "status" = 'open'
          AND (("targetType" = 'post' AND "postId" IS NOT NULL)
            OR ("targetType" = 'reply' AND "replyId" IS NOT NULL)
            OR ("targetType" = 'member' AND "targetMemberId" IS NOT NULL))
        GROUP BY 1, 2
      ),
      q AS (
        SELECT 'post'::text AS "t", p."id", 'post:' || p."id" AS "key",
               (p."status" = 'pending_review') AS "autoHidden",
               (r."firstOpen" IS NOT NULL) AS "reported",
               LEAST(
                 COALESCE(r."firstOpen", 'infinity'::timestamp),
                 CASE WHEN p."status" = 'pending_review' THEN COALESCE(p."statusChangedAt", p."createdAt") ELSE 'infinity'::timestamp END
               ) AS "flaggedAt"
        FROM "CommunityPost" p
        LEFT JOIN open_reports r ON r."t" = 'post' AND r."id" = p."id"
        WHERE p."status" <> 'deleted' AND (p."status" = 'pending_review' OR r."firstOpen" IS NOT NULL)
        UNION ALL
        SELECT 'reply', c."id", 'reply:' || c."id",
               (c."status" = 'pending_review'),
               (r."firstOpen" IS NOT NULL),
               LEAST(
                 COALESCE(r."firstOpen", 'infinity'::timestamp),
                 CASE WHEN c."status" = 'pending_review' THEN COALESCE(c."statusChangedAt", c."createdAt") ELSE 'infinity'::timestamp END
               )
        FROM "CommunityReply" c
        LEFT JOIN open_reports r ON r."t" = 'reply' AND r."id" = c."id"
        WHERE c."status" <> 'deleted' AND (c."status" = 'pending_review' OR r."firstOpen" IS NOT NULL)
        UNION ALL
        SELECT 'member', r."id", 'member:' || r."id", false, true, r."firstOpen"
        FROM open_reports r WHERE r."t" = 'member'
      )
    `;

    const [rows, counts] = await runDb(this.prisma, (db) =>
      Promise.all([
        db.$queryRaw<{ t: string; id: string; key: string; flaggedAt: Date }[]>`
          ${base}
          SELECT q."t", q."id", q."key", q."flaggedAt" FROM q
          WHERE true ${kindFilter} ${cursorFilter}
          ORDER BY q."flaggedAt" ASC, q."key" ASC
          LIMIT ${limit + 1}
        `,
        db.$queryRaw<{ autoHidden: number; reported: number; members: number }[]>`
          ${base}
          SELECT
            COUNT(*) FILTER (WHERE q."autoHidden")::int AS "autoHidden",
            COUNT(*) FILTER (WHERE q."reported" AND q."t" <> 'member')::int AS "reported",
            COUNT(*) FILTER (WHERE q."t" = 'member')::int AS "members"
          FROM q
        `,
      ]),
    );
    const page = rows.slice(0, limit);
    const postIds = page.filter((r) => r.t === 'post').map((r) => r.id);
    const replyIds = page.filter((r) => r.t === 'reply').map((r) => r.id);
    const [postRows, replyRows] = await runDb(this.prisma, (db) =>
      Promise.all([
        db.communityPost.findMany({ where: { id: { in: postIds } }, include: POST_INCLUDE }),
        db.communityReply.findMany({
          where: { id: { in: replyIds } },
          include: { ...REPLY_INCLUDE, post: { select: { id: true, title: true, status: true } } },
        }),
      ]),
    );
    const { ctx, identities } = await this.adminContext(postRows, replyRows, lang, now, role);
    const postById = new Map(postRows.map((p) => [p.id, p]));
    const replyById = new Map(replyRows.map((r) => [r.id, r]));

    const items = [];
    for (const row of page) {
      const reports = await this.adminReports({ targetKey: row.key, status: 'open' }, 10);
      const openReportCount = await runDb(this.prisma, (db) =>
        db.communityReport.count({ where: { targetKey: row.key, status: 'open' } }),
      );
      const post = row.t === 'post' ? postById.get(row.id) : undefined;
      const reply = row.t === 'reply' ? replyById.get(row.id) : undefined;
      items.push({
        key: row.key,
        targetType: row.t,
        post: post ? this.adminPostJson(post, ctx, identities, now) : null,
        reply: reply ? this.adminReplyJson(reply, ctx, identities, now) : null,
        member: row.t === 'member' ? await this.adminMember(row.id, now, role) : null,
        parentPost: reply ? { id: reply.post.id, title: reply.post.title, status: reply.post.status } : null,
        reports,
        openReportCount,
        flaggedAt: new Date(row.flaggedAt).toISOString(),
        waitingHours: Math.max(0, Math.floor((now.getTime() - new Date(row.flaggedAt).getTime()) / HOUR_MS)),
      });
    }
    const last = page[page.length - 1];
    return {
      counts: counts[0] ?? { autoHidden: 0, reported: 0, members: 0 },
      items,
      nextCursor:
        rows.length > limit && last
          ? encodeCursor({ f: feedKey, c: new Date(last.flaggedAt).toISOString(), k: last.key })
          : null,
    };
  }

  // ── Navigation (§8.3) ─────────────────────────────────────────────────────

  async listPosts(
    role: string,
    filters: { status?: CommunityContentStatus; type?: CommunityPostType; q?: string },
    rawCursor: string | undefined,
    rawLimit: number | undefined,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const cursor = decodeCursor(rawCursor, 'admin:posts');
    const where: Prisma.CommunityPostWhereInput[] = [];
    if (filters.status) where.push({ status: filters.status });
    if (filters.type) where.push({ type: filters.type });
    if (filters.q?.trim()) {
      for (const term of searchTerms(filters.q)) {
        where.push({ searchText: { contains: term } });
      }
    }
    if (cursor) {
      const at = cursorDate(cursor, 'c');
      const id = cursorString(cursor, 'i');
      where.push({ OR: [{ createdAt: { lt: at } }, { createdAt: at, id: { lt: id } }] });
    }
    const found = await runDb(this.prisma, (db) =>
      db.communityPost.findMany({
        where: { AND: where },
        include: POST_INCLUDE,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const rows = found.slice(0, limit);
    const { ctx, identities } = await this.adminContext(rows, [], lang, now, role);
    const last = rows[rows.length - 1];
    return {
      items: rows.map((r) => this.adminPostJson(r, ctx, identities, now)),
      nextCursor:
        found.length > limit && last
          ? encodeCursor({ f: 'admin:posts', c: last.createdAt.toISOString(), i: last.id })
          : null,
    };
  }

  async postDetail(role: string, postId: string, lang: Lang, now: Date = new Date()) {
    const [post, replies, log] = await runDb(this.prisma, (db) =>
      Promise.all([
        db.communityPost.findUnique({ where: { id: postId }, include: POST_INCLUDE }),
        db.communityReply.findMany({
          where: { postId },
          include: REPLY_INCLUDE,
          orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        }),
        db.forumModerationAction.findMany({ where: { postId }, orderBy: { createdAt: 'desc' }, take: 100 }),
      ]),
    );
    if (!post) throw CommunityErrors.postNotFound();
    const { ctx, identities } = await this.adminContext([post], replies, lang, now, role);
    const reports = await this.adminReports(
      { OR: [{ postId }, { replyId: { in: replies.map((r) => r.id) } }] },
      200,
    );
    return {
      post: this.adminPostJson(post, ctx, identities, now),
      replies: replies.map((r) => this.adminReplyJson(r, ctx, identities, now)),
      reports,
      log: log.map((l) => this.logJson(l)),
    };
  }

  async memberDetail(role: string, memberId: string, lang: Lang, now: Date = new Date()) {
    const member = await this.adminMember(memberId, now, role);
    const [posts, replies] = await runDb(this.prisma, (db) =>
      Promise.all([
        db.communityPost.findMany({
          where: { authorMemberId: memberId },
          include: POST_INCLUDE,
          orderBy: { createdAt: 'desc' },
          take: 10,
        }),
        db.communityReply.findMany({
          where: { authorMemberId: memberId },
          include: REPLY_INCLUDE,
          orderBy: { createdAt: 'desc' },
          take: 10,
        }),
      ]),
    );
    const { ctx, identities } = await this.adminContext(posts, replies, lang, now, role);
    return {
      ...member,
      recentPosts: posts.map((p) => this.adminPostJson(p, ctx, identities, now)),
      recentReplies: replies.map((r) => this.adminReplyJson(r, ctx, identities, now)),
    };
  }

  private logJson(l: {
    id: string;
    action: string;
    targetType: string;
    targetId: string;
    reason: string;
    moderatorName: string;
    moderatorRole: string;
    createdAt: Date;
    postId: string | null;
  }) {
    return {
      id: l.id,
      action: l.action,
      targetType: l.targetType,
      targetId: l.targetId,
      reason: l.reason,
      moderatorName: l.moderatorName,
      moderatorRole: l.moderatorRole,
      createdAt: l.createdAt.toISOString(),
      postId: l.postId,
    };
  }

  async moderationLog(rawCursor: string | undefined, rawLimit: number | undefined) {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const cursor = decodeCursor(rawCursor, 'admin:log');
    const found = await runDb(this.prisma, (db) =>
      db.forumModerationAction.findMany({
        where: cursor
          ? {
              OR: [
                { createdAt: { lt: cursorDate(cursor, 'c') } },
                { createdAt: cursorDate(cursor, 'c'), id: { lt: cursorString(cursor, 'i') } },
              ],
            }
          : {},
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const rows = found.slice(0, limit);
    const last = rows[rows.length - 1];
    return {
      items: rows.map((l) => this.logJson(l)),
      nextCursor:
        found.length > limit && last
          ? encodeCursor({ f: 'admin:log', c: last.createdAt.toISOString(), i: last.id })
          : null,
    };
  }

  // ── Journal et audit ──────────────────────────────────────────────────────

  private async journal(
    tx: Prisma.TransactionClient,
    input: {
      action: string;
      targetType: 'post' | 'reply' | 'member';
      targetId: string;
      reason: string;
      actor: ModerationActor;
      requestId: string;
      postId?: string | null;
      replyId?: string | null;
      memberId?: string | null;
      changes?: Prisma.InputJsonValue;
      now: Date;
    },
  ): Promise<void> {
    await tx.forumModerationAction.create({
      data: {
        targetType: input.targetType,
        targetId: input.targetId,
        reason: input.reason.slice(0, COMMUNITY_LIMITS.adminReasonMax),
        action: input.action,
        moderatorName: input.actor.fullName,
        moderatorRole: input.actor.role as InternalRole,
        createdAt: input.now,
        postId: input.postId ?? null,
        replyId: input.replyId ?? null,
        memberId: input.memberId ?? null,
        adminId: input.actor.id,
      },
    });
    await this.audit(tx, input);
  }

  private async audit(
    tx: Prisma.TransactionClient,
    input: {
      action: string;
      targetType: string;
      targetId: string;
      reason?: string;
      actor: ModerationActor;
      requestId: string;
      changes?: Prisma.InputJsonValue;
      now: Date;
    },
  ): Promise<void> {
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: input.actor.id,
        action: `community.${input.action}`,
        purposeCode: COMMUNITY_AUDIT_PURPOSE,
        entityType: `community_${input.targetType}`,
        entityId: input.targetId,
        requestId: input.requestId || randomUUID(),
        reasonCode: input.reason?.slice(0, 500),
        result: 'success',
        changes: input.changes ?? Prisma.JsonNull,
        occurredAt: input.now,
      },
    });
  }

  // ── Actions sur un contenu (§8.4) ─────────────────────────────────────────

  async contentAction(
    targetType: 'post' | 'reply',
    id: string,
    input: { action: ContentAction; reason: string; notifyAuthor?: boolean },
    actor: ModerationActor,
    requestId: string,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const reason = cleanReason(input.reason);
    const select = { status: true, statusReason: true, authorMemberId: true } as const;
    const current: {
      status: CommunityContentStatus;
      statusReason: string | null;
      authorMemberId: string | null;
      postId: string;
    } | null = await runDb(this.prisma, async (db) => {
      if (targetType === 'post') {
        const row = await db.communityPost.findUnique({ where: { id }, select });
        return row ? { ...row, postId: id } : null;
      }
      return db.communityReply.findUnique({ where: { id }, select: { ...select, postId: true } });
    });
    if (!current) throw targetType === 'post' ? CommunityErrors.postNotFound() : CommunityErrors.replyNotFound();
    const postId = current.postId;

    let next: { status: CommunityContentStatus; statusReason: string | null } | null = null;
    let reportStatus: 'actioned' | 'dismissed' = 'dismissed';
    let event: ModerationEvent | null = null;
    switch (input.action) {
      case 'restore':
        if (current.status === 'visible' || (current.status === 'deleted' && current.statusReason === 'author_deleted')) {
          throw CommunityErrors.invalidTransition(current.status);
        }
        next = { status: 'visible', statusReason: null };
        event = 'restored';
        break;
      case 'hide':
        if (current.status === 'hidden' || current.status === 'deleted') throw CommunityErrors.invalidTransition(current.status);
        next = { status: 'hidden', statusReason: 'moderation' };
        reportStatus = 'actioned';
        event = 'hidden';
        break;
      case 'delete':
        if (current.status === 'deleted') throw CommunityErrors.invalidTransition(current.status);
        next = { status: 'deleted', statusReason: 'moderation_deleted' };
        reportStatus = 'actioned';
        event = 'deleted';
        break;
      case 'dismiss_reports':
        if (current.status === 'deleted') throw CommunityErrors.invalidTransition(current.status);
        if (current.status === 'pending_review' && current.statusReason === 'reports_threshold') {
          next = { status: 'visible', statusReason: null };
        }
        break;
    }

    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (next) {
          const data = {
            status: next.status,
            statusReason: next.statusReason,
            statusChangedAt: now,
            deletedAt: next.status === 'deleted' ? now : null,
            ...(targetType === 'post' && next.status !== 'visible' ? { pinnedAt: null } : {}),
          };
          if (targetType === 'post') await tx.communityPost.update({ where: { id }, data });
          else await tx.communityReply.update({ where: { id }, data });
        }
        await tx.communityReport.updateMany({
          where: { targetKey: `${targetType}:${id}`, status: 'open' },
          data: {
            status: reportStatus,
            resolvedAt: now,
            resolvedByAdminId: actor.id,
            resolvedByName: actor.fullName,
            resolutionNote: reason,
          },
        });
        if (targetType === 'reply') await refreshReplyCounters(tx, [id]);
        await refreshPostCounters(tx, [postId]);
        await this.journal(tx, {
          action: input.action,
          targetType,
          targetId: id,
          reason,
          actor,
          requestId,
          postId,
          replyId: targetType === 'reply' ? id : null,
          memberId: current.authorMemberId,
          changes: { from: current.status, to: next?.status ?? current.status, reports: reportStatus },
          now,
        });
      }),
    );

    if (event && input.notifyAuthor !== false && current.authorMemberId) {
      await this.notifications.moderation({
        memberId: current.authorMemberId,
        event,
        contentKind: targetType,
        postId: event === 'deleted' ? null : postId,
        reason,
        referenceId: id,
        now,
      });
    }
    return this.adminContent(targetType, id, lang, now, actor.role);
  }

  private async adminContent(targetType: 'post' | 'reply', id: string, lang: Lang, now: Date, role: string) {
    if (targetType === 'post') {
      const row = await runDb(this.prisma, (db) =>
        db.communityPost.findUniqueOrThrow({ where: { id }, include: POST_INCLUDE }),
      );
      const { ctx, identities } = await this.adminContext([row], [], lang, now, role);
      return this.adminPostJson(row, ctx, identities, now);
    }
    const row = await runDb(this.prisma, (db) =>
      db.communityReply.findUniqueOrThrow({ where: { id }, include: REPLY_INCLUDE }),
    );
    const { ctx, identities } = await this.adminContext([], [row], lang, now, role);
    return this.adminReplyJson(row, ctx, identities, now);
  }

  // ── Sanctions (§8.5) ──────────────────────────────────────────────────────

  async createSanction(
    memberId: string,
    input: { kind: CommunitySanctionKind; reason: string; durationDays?: number; hideContent?: boolean },
    actor: ModerationActor,
    requestId: string,
    now: Date = new Date(),
  ) {
    const reason = cleanReason(input.reason);
    if (input.kind === 'read_only' && !input.durationDays) {
      throw new BadRequestException('durationDays is required for read_only.');
    }
    if (input.kind !== 'read_only' && input.durationDays !== undefined) {
      throw new BadRequestException('durationDays is only allowed for read_only.');
    }
    if (input.hideContent && input.kind !== 'ban') {
      throw new BadRequestException('hideContent is only allowed for ban.');
    }
    const member = await runDb(this.prisma, (db) =>
      db.communityMember.findUnique({ where: { id: memberId }, select: { id: true } }),
    );
    if (!member) throw CommunityErrors.memberNotFound();
    const endsAt = input.kind === 'read_only' ? new Date(now.getTime() + input.durationDays! * DAY_MS) : null;

    const sanction = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const created = await tx.communitySanction.create({
          data: {
            memberId,
            kind: input.kind,
            reason,
            endsAt,
            createdByAdminId: actor.id,
            createdByName: actor.fullName,
            createdAt: now,
          },
        });
        if (input.kind === 'ban' && input.hideContent) {
          const posts = await tx.communityPost.findMany({
            where: { authorMemberId: memberId, status: { in: ['visible', 'pending_review'] } },
            select: { id: true },
          });
          const replies = await tx.communityReply.findMany({
            where: { authorMemberId: memberId, status: { in: ['visible', 'pending_review'] } },
            select: { id: true, postId: true },
          });
          const data = { status: 'hidden' as const, statusReason: 'moderation', statusChangedAt: now };
          await tx.communityPost.updateMany({ where: { id: { in: posts.map((p) => p.id) } }, data: { ...data, pinnedAt: null } });
          await tx.communityReply.updateMany({ where: { id: { in: replies.map((r) => r.id) } }, data });
          await refreshPostCounters(tx, [...posts.map((p) => p.id), ...replies.map((r) => r.postId)]);
        }
        await tx.communityReport.updateMany({
          where: { targetMemberId: memberId, targetType: 'member', status: 'open' },
          data: {
            status: 'actioned',
            resolvedAt: now,
            resolvedByAdminId: actor.id,
            resolvedByName: actor.fullName,
            resolutionNote: reason,
          },
        });
        await this.journal(tx, {
          action: `sanction_${input.kind}`,
          targetType: 'member',
          targetId: memberId,
          reason,
          actor,
          requestId,
          memberId,
          changes: {
            kind: input.kind,
            endsAt: endsAt?.toISOString() ?? null,
            hideContent: input.hideContent ?? false,
          },
          now,
        });
        return created;
      }),
    );
    await this.notifications.moderation({
      memberId,
      event: input.kind,
      reason,
      until: endsAt,
      referenceId: sanction.id,
      now,
    });
    return this.sanctionJson(sanction, now);
  }

  async revokeSanction(
    sanctionId: string,
    input: { reason: string },
    actor: ModerationActor,
    requestId: string,
    now: Date = new Date(),
  ) {
    const reason = cleanReason(input.reason);
    const current = await runDb(this.prisma, (db) => db.communitySanction.findUnique({ where: { id: sanctionId } }));
    if (!current) throw CommunityErrors.memberNotFound();
    if (current.revokedAt) throw CommunityErrors.invalidTransition('revoked');
    const updated = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const row = await tx.communitySanction.update({
          where: { id: sanctionId },
          data: { revokedAt: now, revokedByAdminId: actor.id, revokedByName: actor.fullName, revokeReason: reason },
        });
        await this.journal(tx, {
          action: 'sanction_revoke',
          targetType: 'member',
          targetId: current.memberId,
          reason,
          actor,
          requestId,
          memberId: current.memberId,
          changes: { sanctionId, kind: current.kind },
          now,
        });
        return row;
      }),
    );
    return this.sanctionJson(updated, now);
  }

  /** `GET /admin/community/sanctions` : en cours (défaut) ou toutes, récentes d'abord. */
  async listSanctions(
    role: string,
    status: 'active' | 'all',
    rawCursor: string | undefined,
    rawLimit: number | undefined,
    now: Date = new Date(),
  ) {
    const limit = clampLimit(rawLimit, COMMUNITY_PAGINATION.defaultLimit, COMMUNITY_PAGINATION.maxLimit);
    const feedKey = `admin:sanctions:${status}`;
    const cursor = decodeCursor(rawCursor, feedKey);
    const where: Prisma.CommunitySanctionWhereInput[] = [];
    if (status === 'active') {
      where.push({
        revokedAt: null,
        kind: { in: ['read_only', 'ban'] },
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
      });
    }
    if (cursor) {
      const at = cursorDate(cursor, 'c');
      const id = cursorString(cursor, 'i');
      where.push({ OR: [{ createdAt: { lt: at } }, { createdAt: at, id: { lt: id } }] });
    }
    const found = await runDb(this.prisma, (db) =>
      db.communitySanction.findMany({
        where: { AND: where },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const rows = found.slice(0, limit);
    const [identities, adminIdentities] = await Promise.all([
      this.access.identities(rows.map((r) => r.memberId)),
      this.adminIdentities(rows.map((r) => r.memberId), role),
    ]);
    const last = rows[rows.length - 1];
    return {
      items: rows.map((r) => {
        const identity = identities.get(r.memberId);
        const author: AuthorJson = identity
          ? memberAuthor(identity)
          : { kind: 'member', memberId: r.memberId, displayName: 'Membre', countryName: null, badges: [] };
        return {
          ...this.sanctionJson(r, now),
          member: this.adminAuthor(author, { authorMemberId: r.memberId, authorAdminId: null }, adminIdentities, now),
        };
      }),
      nextCursor:
        found.length > limit && last
          ? encodeCursor({ f: feedKey, c: last.createdAt.toISOString(), i: last.id })
          : null,
    };
  }

  /**
   * Classe SANS SUITE les signalements ouverts visant un membre (aucune
   * sanction). Une sanction, elle, les clôt en `actioned`.
   */
  async dismissMemberReports(
    memberId: string,
    input: { reason: string },
    actor: ModerationActor,
    requestId: string,
    now: Date = new Date(),
  ) {
    const reason = cleanReason(input.reason);
    const member = await runDb(this.prisma, (db) =>
      db.communityMember.findUnique({ where: { id: memberId }, select: { id: true } }),
    );
    if (!member) throw CommunityErrors.memberNotFound();
    const dismissed = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const result = await tx.communityReport.updateMany({
          where: { targetMemberId: memberId, targetType: 'member', status: 'open' },
          data: {
            status: 'dismissed',
            resolvedAt: now,
            resolvedByAdminId: actor.id,
            resolvedByName: actor.fullName,
            resolutionNote: reason,
          },
        });
        await this.journal(tx, {
          action: 'member_reports_dismissed',
          targetType: 'member',
          targetId: memberId,
          reason,
          actor,
          requestId,
          memberId,
          changes: { dismissed: result.count },
          now,
        });
        return result.count;
      }),
    );
    return { memberId, dismissed };
  }

  // ── Équipe KPB (§8.6) ─────────────────────────────────────────────────────

  private teamName(as: 'kpb_team' | 'kpb_advisor', actor: ModerationActor): string {
    return as === 'kpb_team' ? KPB_TEAM_NAME : publicNameFromFullName(actor.fullName) || KPB_TEAM_NAME;
  }

  async teamReply(
    postId: string,
    input: { body: string; as: 'kpb_team' | 'kpb_advisor'; verified?: boolean },
    actor: ModerationActor,
    requestId: string,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const body = input.body.trim();
    if (body.length < COMMUNITY_LIMITS.replyBodyMin || body.length > COMMUNITY_LIMITS.replyBodyMax) {
      throw new BadRequestException(
        `body must be ${COMMUNITY_LIMITS.replyBodyMin} to ${COMMUNITY_LIMITS.replyBodyMax} characters.`,
      );
    }
    const post = await runDb(this.prisma, (db) => db.communityPost.findUnique({ where: { id: postId } }));
    if (!post || post.status === 'deleted') throw CommunityErrors.postNotFound();
    const prepared = await this.composer.prepare({ body, isPost: false, authorEmail: null, now });
    const replyId = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (input.verified) {
          await tx.communityReply.updateMany({ where: { postId, isVerified: true }, data: { isVerified: false } });
        }
        const reply = await tx.communityReply.create({
          data: {
            postId,
            body: prepared.body,
            authorKind: input.as,
            authorAdminId: actor.id,
            authorAdminName: this.teamName(input.as, actor),
            status: 'visible',
            createdAt: now,
            isVerified: input.verified ?? false,
            verifiedAt: input.verified ? now : null,
            verifiedByAdminId: input.verified ? actor.id : null,
            mentions: { create: mentionRows(prepared.mentions) },
          },
        });
        await refreshPostCounters(tx, [postId]);
        await this.audit(tx, {
          action: 'team_reply',
          targetType: 'reply',
          targetId: reply.id,
          actor,
          requestId,
          changes: { postId, as: input.as, verified: input.verified ?? false },
          now,
        });
        return reply.id;
      }),
    );
    if (post.status === 'visible') {
      await this.notifications.replyPosted({
        post: { id: post.id, title: post.title, type: post.type, authorMemberId: post.authorMemberId },
        reply: { id: replyId, authorMemberId: null },
        now,
      });
      if (input.verified) {
        await this.notifications.verifiedAnswer({
          post: { id: post.id, title: post.title, authorMemberId: post.authorMemberId },
          reply: { id: replyId, authorMemberId: null },
          now,
        });
      }
    }
    return this.adminContent('reply', replyId, lang, now, actor.role);
  }

  async setVerified(
    replyId: string,
    verified: boolean,
    actor: ModerationActor,
    requestId: string,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const reply = await runDb(this.prisma, (db) =>
      db.communityReply.findUnique({ where: { id: replyId }, include: { post: true } }),
    );
    if (!reply) throw CommunityErrors.replyNotFound();
    if (verified && (reply.status !== 'visible' || reply.post.status === 'deleted')) {
      throw CommunityErrors.invalidTransition(reply.status);
    }
    const changed = reply.isVerified !== verified;
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (verified) {
          await tx.communityReply.updateMany({
            where: { postId: reply.postId, isVerified: true, id: { not: replyId } },
            data: { isVerified: false },
          });
        }
        await tx.communityReply.update({
          where: { id: replyId },
          data: verified
            ? { isVerified: true, verifiedAt: reply.isVerified ? reply.verifiedAt : now, verifiedByAdminId: reply.isVerified ? reply.verifiedByAdminId : actor.id }
            : { isVerified: false, verifiedAt: null, verifiedByAdminId: null },
        });
        await refreshPostCounters(tx, [reply.postId]);
        await this.journal(tx, {
          action: verified ? 'verify_answer' : 'unverify_answer',
          targetType: 'reply',
          targetId: replyId,
          reason: verified ? 'Réponse vérifiée par KPB' : 'Vérification retirée',
          actor,
          requestId,
          postId: reply.postId,
          replyId,
          memberId: reply.authorMemberId,
          now,
        });
      }),
    );
    if (verified && changed && reply.post.status === 'visible') {
      await this.notifications.verifiedAnswer({
        post: { id: reply.post.id, title: reply.post.title, authorMemberId: reply.post.authorMemberId },
        reply: { id: replyId, authorMemberId: reply.authorMemberId },
        now,
      });
    }
    return this.adminContent('reply', replyId, lang, now, actor.role);
  }

  async setPinned(
    postId: string,
    pinned: boolean,
    actor: ModerationActor,
    requestId: string,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const post = await runDb(this.prisma, (db) => db.communityPost.findUnique({ where: { id: postId } }));
    if (!post) throw CommunityErrors.postNotFound();
    if (pinned && post.status !== 'visible') throw CommunityErrors.invalidTransition(post.status);
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (pinned && !post.pinnedAt) {
          const count = await tx.communityPost.count({ where: { pinnedAt: { not: null }, status: 'visible' } });
          if (count >= COMMUNITY_MAX_PINNED) throw CommunityErrors.pinLimit(COMMUNITY_MAX_PINNED);
        }
        await tx.communityPost.update({
          where: { id: postId },
          data: { pinnedAt: pinned ? (post.pinnedAt ?? now) : null },
        });
        await this.audit(tx, {
          action: pinned ? 'pin' : 'unpin',
          targetType: 'post',
          targetId: postId,
          actor,
          requestId,
          now,
        });
      }),
    );
    return this.adminContent('post', postId, lang, now, actor.role);
  }

  async teamPost(
    input: { type: CommunityPostType; title: string; body: string; as: 'kpb_team' | 'kpb_advisor'; pinned?: boolean },
    actor: ModerationActor,
    requestId: string,
    lang: Lang,
    now: Date = new Date(),
  ) {
    const title = input.title.trim();
    const body = input.body.trim();
    if (title.length < COMMUNITY_LIMITS.titleMin || title.length > COMMUNITY_LIMITS.titleMax) {
      throw new BadRequestException(`title must be ${COMMUNITY_LIMITS.titleMin} to ${COMMUNITY_LIMITS.titleMax} characters.`);
    }
    if (body.length < COMMUNITY_LIMITS.postBodyMin || body.length > COMMUNITY_LIMITS.postBodyMax) {
      throw new BadRequestException(`body must be ${COMMUNITY_LIMITS.postBodyMin} to ${COMMUNITY_LIMITS.postBodyMax} characters.`);
    }
    const prepared = await this.composer.prepare({ title, body, isPost: true, authorEmail: null, now });
    const postId = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        if (input.pinned) {
          const count = await tx.communityPost.count({ where: { pinnedAt: { not: null }, status: 'visible' } });
          if (count >= COMMUNITY_MAX_PINNED) throw CommunityErrors.pinLimit(COMMUNITY_MAX_PINNED);
        }
        const post = await tx.communityPost.create({
          data: {
            type: input.type,
            title,
            body: prepared.body,
            authorKind: input.as,
            authorAdminId: actor.id,
            authorAdminName: this.teamName(input.as, actor),
            status: 'visible',
            searchText: prepared.searchText,
            lastActivityAt: now,
            createdAt: now,
            pinnedAt: input.pinned ? now : null,
            mentions: { create: mentionRows(prepared.mentions) },
          },
        });
        await this.composer.writeHashtags(tx, post.id, prepared.hashtags);
        await this.audit(tx, {
          action: 'team_post',
          targetType: 'post',
          targetId: post.id,
          actor,
          requestId,
          changes: { as: input.as, pinned: input.pinned ?? false },
          now,
        });
        return post.id;
      }),
    );
    return this.adminContent('post', postId, lang, now, actor.role);
  }

  // ── Statistiques (§8.7) ───────────────────────────────────────────────────

  async stats(days: number, now: Date = new Date()) {
    const span = Math.max(1, Math.min(365, Math.floor(days || 30)));
    const from = new Date(now.getTime() - span * DAY_MS);
    const inWindow = { gte: from, lte: now };
    return runDb(this.prisma, async (db) => {
      const [
        postsByType,
        postsByStatus,
        repliesTotal,
        repliesByTeam,
        helpfulReactions,
        reportsOpened,
        reportsOpen,
        resolved,
        autoHiddenPosts,
        autoHiddenReplies,
        unansweredQuestions,
        unansweredOver48h,
        handlingActions,
        verifiedAnswers,
        newMembers,
        activeSanctions,
        active,
        daily,
      ] = await Promise.all([
        db.communityPost.groupBy({ by: ['type'], where: { createdAt: inWindow }, _count: { _all: true } }),
        db.communityPost.groupBy({ by: ['status'], where: { createdAt: inWindow }, _count: { _all: true } }),
        db.communityReply.count({ where: { createdAt: inWindow } }),
        db.communityReply.count({ where: { createdAt: inWindow, authorKind: { not: 'member' } } }),
        db.communityReaction.count({ where: { createdAt: inWindow } }),
        db.communityReport.count({ where: { createdAt: inWindow } }),
        db.communityReport.count({ where: { status: 'open' } }),
        db.communityReport.findMany({
          where: { resolvedAt: inWindow, status: { not: 'open' } },
          select: { createdAt: true, resolvedAt: true },
        }),
        db.communityPost.count({ where: { createdAt: inWindow, filterFlags: { isEmpty: false } } }),
        db.communityReply.count({ where: { createdAt: inWindow, filterFlags: { isEmpty: false } } }),
        db.communityPost.count({
          where: { status: 'visible', type: 'question', answerCount: 0, hasVerifiedAnswer: false },
        }),
        db.communityPost.count({
          where: {
            status: 'visible',
            type: 'question',
            answerCount: 0,
            hasVerifiedAnswer: false,
            createdAt: { lt: new Date(now.getTime() - 48 * HOUR_MS) },
          },
        }),
        db.forumModerationAction.findMany({
          where: {
            createdAt: inWindow,
            action: { in: ['restore', 'hide', 'delete'] },
            OR: [{ postId: { not: null } }, { replyId: { not: null } }],
          },
          select: { action: true, targetType: true, targetId: true, createdAt: true },
          orderBy: { createdAt: 'asc' },
        }),
        db.communityReply.count({ where: { verifiedAt: inWindow, isVerified: true } }),
        db.communityMember.count({ where: { createdAt: inWindow } }),
        db.communitySanction.count({
          where: {
            revokedAt: null,
            kind: { in: ['read_only', 'ban'] },
            OR: [{ endsAt: null }, { endsAt: { gt: now } }],
          },
        }),
        db.$queryRaw<{ n: number }[]>`
          SELECT COUNT(DISTINCT "m")::int AS "n" FROM (
            SELECT "authorMemberId" AS "m" FROM "CommunityPost" WHERE "createdAt" >= (${from}::timestamptz AT TIME ZONE 'UTC') AND "authorMemberId" IS NOT NULL
            UNION ALL
            SELECT "authorMemberId" FROM "CommunityReply" WHERE "createdAt" >= (${from}::timestamptz AT TIME ZONE 'UTC') AND "authorMemberId" IS NOT NULL
            UNION ALL
            SELECT "memberId" FROM "CommunityReaction" WHERE "createdAt" >= (${from}::timestamptz AT TIME ZONE 'UTC')
          ) a
        `,
        db.$queryRaw<{ date: string; posts: number; replies: number }[]>`
          SELECT to_char(d."day", 'YYYY-MM-DD') AS "date",
            (SELECT COUNT(*)::int FROM "CommunityPost" p WHERE date_trunc('day', p."createdAt") = d."day") AS "posts",
            (SELECT COUNT(*)::int FROM "CommunityReply" r WHERE date_trunc('day', r."createdAt") = d."day") AS "replies"
          FROM generate_series(
            date_trunc('day', (${from}::timestamptz AT TIME ZONE 'UTC')),
            date_trunc('day', (${now}::timestamptz AT TIME ZONE 'UTC')),
            interval '1 day'
          ) AS d("day")
          ORDER BY d."day"
        `,
      ]);
      const hours = resolved
        .map((r) => ((r.resolvedAt as Date).getTime() - r.createdAt.getTime()) / HOUR_MS)
        .sort((a, b) => a - b);
      const reportsMedian = median(hours);
      // Délai de traitement des contenus masqués AUTOMATIQUEMENT : de la
      // création (le masquage est immédiat) à la première décision humaine.
      const firstDecision = new Map<string, Date>();
      for (const a of handlingActions) {
        const key = `${a.targetType}:${a.targetId}`;
        if (!firstDecision.has(key)) firstDecision.set(key, a.createdAt);
      }
      const decidedPostIds = [...firstDecision.keys()].filter((k) => k.startsWith('post:')).map((k) => k.slice(5));
      const decidedReplyIds = [...firstDecision.keys()].filter((k) => k.startsWith('reply:')).map((k) => k.slice(6));
      const [autoPosts, autoReplies] = await Promise.all([
        db.communityPost.findMany({
          where: { id: { in: decidedPostIds }, filterFlags: { isEmpty: false } },
          select: { id: true, createdAt: true },
        }),
        db.communityReply.findMany({
          where: { id: { in: decidedReplyIds }, filterFlags: { isEmpty: false } },
          select: { id: true, createdAt: true },
        }),
      ]);
      const autoHours = [
        ...autoPosts.map((p) => ((firstDecision.get(`post:${p.id}`) as Date).getTime() - p.createdAt.getTime()) / HOUR_MS),
        ...autoReplies.map((r) => ((firstDecision.get(`reply:${r.id}`) as Date).getTime() - r.createdAt.getTime()) / HOUR_MS),
      ];
      const autoMedian = median(autoHours);
      const byType = { question: 0, experience: 0, advice: 0 } as Record<string, number>;
      for (const g of postsByType) byType[g.type] = g._count._all;
      const byStatus = { visible: 0, pending_review: 0, hidden: 0, deleted: 0 } as Record<string, number>;
      for (const g of postsByStatus) byStatus[g.status] = g._count._all;
      return {
        window: { from: from.toISOString(), to: now.toISOString(), days: span },
        posts: { total: Object.values(byType).reduce((a, b) => a + b, 0), byType, byStatus },
        replies: { total: repliesTotal, byTeam: repliesByTeam },
        helpfulReactions,
        reports: {
          opened: reportsOpened,
          open: reportsOpen,
          resolved: resolved.length,
          medianResolutionHours: reportsMedian,
        },
        autoHidden: autoHiddenPosts + autoHiddenReplies,
        autoHiddenMedianHandlingHours: autoMedian,
        unansweredQuestions,
        unansweredOver48h,
        verifiedAnswers,
        activeMembers: Number(active[0]?.n ?? 0),
        newMembers,
        activeSanctions,
        daily: daily.map((d) => ({ date: d.date, posts: Number(d.posts), replies: Number(d.replies) })),
      };
    });
  }

  // ── Filtre (§8.8) ─────────────────────────────────────────────────────────

  private filterEntryJson(e: { id: string; kind: string; value: string; createdAt: Date; createdByName: string | null }) {
    return { id: e.id, kind: e.kind, value: e.value, createdAt: e.createdAt.toISOString(), createdBy: e.createdByName };
  }

  async filters(now: Date = new Date()) {
    const rows = await runDb(this.prisma, (db) =>
      db.communityFilterEntry.findMany({ orderBy: [{ kind: 'asc' }, { value: 'asc' }] }),
    );
    return {
      allowedDomains: {
        builtin: [...BUILTIN_ALLOWED_DOMAINS],
        catalogHostsCount: await this.filterConfig.catalogHostsCount(now),
        custom: rows.filter((r) => r.kind === 'allowed_domain').map((r) => this.filterEntryJson(r)),
      },
      blockedTerms: {
        builtinCount: BUILTIN_BLOCKED_TERMS_COUNT,
        custom: rows.filter((r) => r.kind === 'blocked_term').map((r) => this.filterEntryJson(r)),
      },
    };
  }

  static normalizeFilterValue(kind: 'allowed_domain' | 'blocked_term', raw: string): string {
    const value = (raw ?? '').trim().toLowerCase();
    if (kind === 'allowed_domain') {
      const host = value.replace(/^https?:\/\//, '').replace(/\/.*$/, '').replace(/^www\./, '');
      if (!/^(\*\.)?[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(host) || host.length > 253) {
        throw new BadRequestException('value must be a host name (example.org) or a suffix (*.example.org).');
      }
      return host;
    }
    const term = value.replace(/\s+/g, ' ');
    if (term.length < 2 || term.length > 60) throw new BadRequestException('value must be 2 to 60 characters.');
    return term;
  }

  async addFilter(
    input: { kind: 'allowed_domain' | 'blocked_term'; value: string },
    actor: ModerationActor,
    requestId: string,
    now: Date = new Date(),
  ) {
    const value = CommunityModerationService.normalizeFilterValue(input.kind, input.value);
    const existing = await runDb(this.prisma, (db) =>
      db.communityFilterEntry.findUnique({ where: { kind_value: { kind: input.kind, value } } }),
    );
    if (existing) return { created: false, entry: this.filterEntryJson(existing) };
    const entry = await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        const row = await tx.communityFilterEntry.create({
          data: { kind: input.kind, value, createdByAdminId: actor.id, createdByName: actor.fullName, createdAt: now },
        });
        await this.audit(tx, {
          action: 'filter_add',
          targetType: 'filter',
          targetId: row.id,
          actor,
          requestId,
          changes: { kind: input.kind, value },
          now,
        });
        return row;
      }),
    );
    this.filterConfig.invalidate();
    return { created: true, entry: this.filterEntryJson(entry) };
  }

  async deleteFilter(id: string, actor: ModerationActor, requestId: string, now: Date = new Date()): Promise<void> {
    const existing = await runDb(this.prisma, (db) => db.communityFilterEntry.findUnique({ where: { id } }));
    if (!existing) throw new NotFoundException('Unknown filter entry.');
    await runDb(this.prisma, (db) =>
      db.$transaction(async (tx) => {
        await tx.communityFilterEntry.delete({ where: { id } });
        await this.audit(tx, {
          action: 'filter_delete',
          targetType: 'filter',
          targetId: id,
          actor,
          requestId,
          changes: { kind: existing.kind, value: existing.value },
          now,
        });
      }),
    );
    this.filterConfig.invalidate();
  }

  async testFilter(text: string, now: Date = new Date()) {
    const flags = await this.filterConfig.scan(text ?? '', now);
    return { flags: FILTER_FLAGS.filter((f) => flags.includes(f)), wouldHide: flags.length > 0 };
  }
}
