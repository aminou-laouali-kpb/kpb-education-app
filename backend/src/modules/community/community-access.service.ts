import { Injectable } from '@nestjs/common';
import type { PrismaClient } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  COMMUNITY_CHARTER,
  COMMUNITY_CHARTER_VERSION,
  COMMUNITY_NEW_ACCOUNT_DAYS,
  COMMUNITY_NOTIFICATION_OPT_OUT,
  COMMUNITY_PAGINATION,
  COMMUNITY_QUOTAS,
} from './community.constants';
import { cursorDate, cursorString, decodeCursor, encodeCursor } from './community-cursor';
import { runDb } from './community-db';
import { CommunityErrors } from './community-errors';
import { memberAuthor, type MemberIdentity } from './community-presenter';
import type { Lang } from './community-text';

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

export interface CommunityViewer {
  memberId: string;
  userId: string;
  email: string;
  fullName: string;
  countryOfResidence: string;
  profileCreatedAt: Date;
  targetCountryIds: string[];
  scholarshipTargetLevel: string | null;
  disabledNotificationTypes: string[];
  charterVersion: string | null;
  charterAcceptedAt: Date | null;
  alumniApproved: boolean;
  alumniBadgeVisible: boolean;
}

export interface Restriction {
  kind: 'read_only' | 'ban';
  until: Date | null;
  reason: string;
}

export type QuotaScope = 'posts_per_day' | 'replies_per_hour' | 'reports_per_day';

/**
 * Le membre vu par la communauté : sa fiche (créée au premier appel), sa
 * charte, ses sanctions, ses blocages, ses quotas, et l'identité publique des
 * autres membres (« Prénom I. », pays, badges).
 */
@Injectable()
export class CommunityAccessService {
  constructor(private readonly prisma: PrismaService) {}

  /** Résout l'élève connecté ; crée sa fiche membre si besoin (§2.2). */
  async resolveViewer(userId: string, accountType?: string): Promise<CommunityViewer> {
    if (accountType && accountType !== 'student') throw CommunityErrors.studentsOnly();
    return runDb(this.prisma, async (db) => {
      const profile = await db.userProfile.findUnique({
        where: { id: userId },
        select: {
          id: true,
          accountType: true,
          email: true,
          fullName: true,
          countryOfResidence: true,
          createdAt: true,
          targetCountryIds: true,
          scholarshipTargetLevel: true,
          disabledNotificationTypes: true,
          alumniStatus: true,
          alumniBadgeVisible: true,
        },
      });
      if (!profile) throw CommunityErrors.memberNotFound();
      if (profile.accountType !== 'student') throw CommunityErrors.studentsOnly();
      const member = await db.communityMember.upsert({
        where: { userId },
        create: { userId },
        update: {},
      });
      return {
        memberId: member.id,
        userId,
        email: profile.email,
        fullName: profile.fullName,
        countryOfResidence: profile.countryOfResidence,
        profileCreatedAt: profile.createdAt,
        targetCountryIds: profile.targetCountryIds,
        scholarshipTargetLevel: profile.scholarshipTargetLevel,
        disabledNotificationTypes: profile.disabledNotificationTypes,
        charterVersion: member.charterVersion,
        charterAcceptedAt: member.charterAcceptedAt,
        alumniApproved: profile.alumniStatus === 'approved',
        alumniBadgeVisible: profile.alumniBadgeVisible,
      };
    });
  }

  isNewAccount(viewer: CommunityViewer, now: Date): boolean {
    return now.getTime() - viewer.profileCreatedAt.getTime() < COMMUNITY_NEW_ACCOUNT_DAYS * DAY_MS;
  }

  /** Sanction active la plus forte : bannissement, sinon lecture seule la plus longue. */
  async restriction(memberId: string, now: Date): Promise<Restriction | null> {
    const rows = await runDb(this.prisma, (db) =>
      db.communitySanction.findMany({
        where: {
          memberId,
          revokedAt: null,
          kind: { in: ['read_only', 'ban'] },
          OR: [{ endsAt: null }, { endsAt: { gt: now } }],
        },
        orderBy: { createdAt: 'desc' },
      }),
    );
    const ban = rows.find((r) => r.kind === 'ban');
    if (ban) return { kind: 'ban', until: null, reason: ban.reason };
    if (!rows.length) return null;
    const longest = rows.reduce((a, b) => ((b.endsAt?.getTime() ?? 0) > (a.endsAt?.getTime() ?? 0) ? b : a));
    return { kind: 'read_only', until: longest.endsAt, reason: longest.reason };
  }

  /** Portes 4 et 5 du §2.2 : charte courante, aucune sanction. */
  async assertCanWrite(viewer: CommunityViewer, now: Date): Promise<void> {
    if (viewer.charterVersion !== COMMUNITY_CHARTER_VERSION) {
      throw CommunityErrors.charterRequired(COMMUNITY_CHARTER_VERSION);
    }
    const restriction = await this.restriction(viewer.memberId, now);
    if (restriction) throw CommunityErrors.readOnly(restriction.kind, restriction.until);
  }

  quotaLimit(viewer: CommunityViewer, scope: QuotaScope, now: Date): number {
    const fresh = this.isNewAccount(viewer, now);
    if (scope === 'posts_per_day') {
      return fresh ? COMMUNITY_QUOTAS.postsPerDay.newAccount : COMMUNITY_QUOTAS.postsPerDay.established;
    }
    if (scope === 'replies_per_hour') {
      return fresh ? COMMUNITY_QUOTAS.repliesPerHour.newAccount : COMMUNITY_QUOTAS.repliesPerHour.established;
    }
    return COMMUNITY_QUOTAS.reportsPerDay;
  }

  /**
   * Contenus déjà écrits dans la fenêtre glissante — supprimés compris : effacer
   * puis republier ne rend pas de quota. Renvoie aussi le plus ancien, pour
   * calculer `retryAfterSeconds`.
   */
  private async usage(
    db: PrismaClient,
    memberId: string,
    scope: QuotaScope,
    since: Date,
  ): Promise<{ count: number; oldest: Date | null }> {
    const where = { createdAt: { gte: since } };
    if (scope === 'posts_per_day') {
      const rows = await db.communityPost.findMany({
        where: { ...where, authorMemberId: memberId },
        select: { createdAt: true },
        orderBy: { createdAt: 'asc' },
      });
      return { count: rows.length, oldest: rows[0]?.createdAt ?? null };
    }
    if (scope === 'replies_per_hour') {
      const rows = await db.communityReply.findMany({
        where: { ...where, authorMemberId: memberId },
        select: { createdAt: true },
        orderBy: { createdAt: 'asc' },
      });
      return { count: rows.length, oldest: rows[0]?.createdAt ?? null };
    }
    const rows = await db.communityReport.findMany({
      where: { ...where, reporterMemberId: memberId },
      select: { createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    return { count: rows.length, oldest: rows[0]?.createdAt ?? null };
  }

  static windowMs(scope: QuotaScope): number {
    return scope === 'replies_per_hour' ? HOUR_MS : DAY_MS;
  }

  async assertQuota(viewer: CommunityViewer, scope: QuotaScope, now: Date): Promise<void> {
    const windowMs = CommunityAccessService.windowMs(scope);
    const limit = this.quotaLimit(viewer, scope, now);
    const { count, oldest } = await runDb(this.prisma, (db) =>
      this.usage(db, viewer.memberId, scope, new Date(now.getTime() - windowMs)),
    );
    if (count >= limit) {
      const freeAt = (oldest?.getTime() ?? now.getTime()) + windowMs;
      const retryAfterSeconds = Math.max(1, Math.ceil((freeAt - now.getTime()) / 1000));
      throw CommunityErrors.rateLimited(scope, limit, retryAfterSeconds);
    }
  }

  /** Les membres en relation de blocage avec `memberId`, dans un sens ou l'autre. */
  async blockedIds(memberId: string): Promise<string[]> {
    const rows = await runDb(this.prisma, (db) =>
      db.communityBlock.findMany({
        where: { OR: [{ blockerMemberId: memberId }, { blockedMemberId: memberId }] },
        select: { blockerMemberId: true, blockedMemberId: true },
      }),
    );
    const ids = new Set<string>();
    for (const r of rows) ids.add(r.blockerMemberId === memberId ? r.blockedMemberId : r.blockerMemberId);
    return [...ids];
  }

  /** Identités publiques d'une liste de membres. */
  async identities(memberIds: Iterable<string | null | undefined>): Promise<Map<string, MemberIdentity>> {
    const ids = [...new Set([...memberIds].filter((id): id is string => !!id))];
    const out = new Map<string, MemberIdentity>();
    if (!ids.length) return out;
    await runDb(this.prisma, async (db) => {
      const members = await db.communityMember.findMany({
        where: { id: { in: ids } },
        select: {
          id: true,
          userId: true,
          user: {
            select: { fullName: true, countryOfResidence: true, alumniStatus: true, alumniBadgeVisible: true },
          },
        },
      });
      const ambassadors = await db.ambassador.findMany({
        where: { userProfileId: { in: members.map((m) => m.userId) }, approvedAt: { not: null } },
        select: { userProfileId: true },
      });
      const approved = new Set(ambassadors.map((a) => a.userProfileId));
      for (const m of members) {
        out.set(m.id, {
          memberId: m.id,
          fullName: m.user.fullName,
          countryOfResidence: m.user.countryOfResidence,
          alumniApproved: m.user.alumniStatus === 'approved',
          alumniBadgeVisible: m.user.alumniBadgeVisible,
          ambassadorApproved: approved.has(m.userId),
        });
      }
    });
    return out;
  }

  /** Statistiques publiques (§5.7) : contenus VISIBLES seulement. */
  async stats(memberId: string) {
    return runDb(this.prisma, async (db) => {
      const [postsCount, repliesCount, helpfulAnswersCount] = await Promise.all([
        db.communityPost.count({ where: { authorMemberId: memberId, status: 'visible' } }),
        db.communityReply.count({
          where: { authorMemberId: memberId, status: 'visible', post: { status: 'visible' } },
        }),
        db.communityReply.count({
          where: {
            authorMemberId: memberId,
            status: 'visible',
            post: { status: 'visible' },
            OR: [{ helpfulCount: { gt: 0 } }, { isVerified: true }],
          },
        }),
      ]);
      return { helpfulAnswersCount, postsCount, repliesCount };
    });
  }

  charterJson(viewer: { charterVersion: string | null; charterAcceptedAt: Date | null }, lang: Lang) {
    return {
      currentVersion: COMMUNITY_CHARTER_VERSION,
      acceptedVersion: viewer.charterVersion,
      acceptedAt: viewer.charterAcceptedAt?.toISOString() ?? null,
      required: viewer.charterVersion !== COMMUNITY_CHARTER_VERSION,
      title: COMMUNITY_CHARTER.title[lang],
      rules: COMMUNITY_CHARTER.rules.map((r) => ({ id: r.id, title: r.title[lang], body: r.body[lang] })),
    };
  }

  /** `GET /community/me` (§5.8). */
  async me(viewer: CommunityViewer, lang: Lang, now: Date = new Date()) {
    const [restriction, stats, postsUsage, repliesUsage, identities] = await Promise.all([
      this.restriction(viewer.memberId, now),
      this.stats(viewer.memberId),
      runDb(this.prisma, (db) => this.usage(db, viewer.memberId, 'posts_per_day', new Date(now.getTime() - DAY_MS))),
      runDb(this.prisma, (db) => this.usage(db, viewer.memberId, 'replies_per_hour', new Date(now.getTime() - HOUR_MS))),
      this.identities([viewer.memberId]),
    ]);
    const identity = identities.get(viewer.memberId);
    return {
      member: identity
        ? memberAuthor(identity)
        : memberAuthor({
            memberId: viewer.memberId,
            fullName: viewer.fullName,
            countryOfResidence: viewer.countryOfResidence,
            alumniApproved: viewer.alumniApproved,
            alumniBadgeVisible: viewer.alumniBadgeVisible,
            ambassadorApproved: false,
          }),
      charter: this.charterJson(viewer, lang),
      restriction: restriction
        ? { kind: restriction.kind, until: restriction.until?.toISOString() ?? null, reason: restriction.reason }
        : null,
      limits: {
        newAccount: this.isNewAccount(viewer, now),
        postsPerDay: this.quotaLimit(viewer, 'posts_per_day', now),
        postsToday: postsUsage.count,
        repliesPerHour: this.quotaLimit(viewer, 'replies_per_hour', now),
        repliesThisHour: repliesUsage.count,
      },
      stats,
      notificationsOptedOut: viewer.disabledNotificationTypes.includes(COMMUNITY_NOTIFICATION_OPT_OUT),
    };
  }

  /** `POST /community/charter/accept` — idempotent, historisé (§9.4). */
  async acceptCharter(viewer: CommunityViewer, version: string, now: Date = new Date()) {
    if (version !== COMMUNITY_CHARTER_VERSION) {
      throw CommunityErrors.charterOutdated(COMMUNITY_CHARTER_VERSION);
    }
    if (viewer.charterVersion === version && viewer.charterAcceptedAt) {
      return { acceptedVersion: version, acceptedAt: viewer.charterAcceptedAt.toISOString() };
    }
    await runDb(this.prisma, (db) =>
      db.$transaction([
        db.communityCharterAcceptance.upsert({
          where: { memberId_version: { memberId: viewer.memberId, version } },
          create: { memberId: viewer.memberId, version, acceptedAt: now },
          update: {},
        }),
        db.communityMember.update({
          where: { id: viewer.memberId },
          data: { charterVersion: version, charterAcceptedAt: now },
        }),
      ]),
    );
    return { acceptedVersion: version, acceptedAt: now.toISOString() };
  }

  // ── Blocages (§7.11) ──────────────────────────────────────────────────────

  async block(viewer: CommunityViewer, targetMemberId: string) {
    if (targetMemberId === viewer.memberId) throw CommunityErrors.cannotBlockSelf();
    await runDb(this.prisma, async (db) => {
      const target = await db.communityMember.findUnique({ where: { id: targetMemberId }, select: { id: true } });
      if (!target) throw CommunityErrors.memberNotFound();
      await db.communityBlock.createMany({
        data: [{ blockerMemberId: viewer.memberId, blockedMemberId: targetMemberId }],
        skipDuplicates: true,
      });
    });
    return { isBlocked: true };
  }

  async unblock(viewer: CommunityViewer, targetMemberId: string) {
    await runDb(this.prisma, (db) =>
      db.communityBlock.deleteMany({
        where: { blockerMemberId: viewer.memberId, blockedMemberId: targetMemberId },
      }),
    );
    return { isBlocked: false };
  }

  async listBlocks(viewer: CommunityViewer, rawCursor: string | undefined, rawLimit?: number) {
    const limit = Math.max(1, Math.min(COMMUNITY_PAGINATION.maxLimit, Math.floor(rawLimit ?? COMMUNITY_PAGINATION.defaultLimit)));
    const cursor = decodeCursor(rawCursor, 'blocks');
    const rows = await runDb(this.prisma, (db) =>
      db.communityBlock.findMany({
        where: {
          blockerMemberId: viewer.memberId,
          ...(cursor
            ? {
                OR: [
                  { createdAt: { lt: cursorDate(cursor, 'c') } },
                  { createdAt: cursorDate(cursor, 'c'), id: { lt: cursorString(cursor, 'i') } },
                ],
              }
            : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
    );
    const page = rows.slice(0, limit);
    const identities = await this.identities(page.map((r) => r.blockedMemberId));
    return {
      items: page.map((r) => {
        const identity = identities.get(r.blockedMemberId);
        return {
          member: identity
            ? memberAuthor(identity)
            : { kind: 'member' as const, memberId: r.blockedMemberId, displayName: 'Membre', countryName: null, badges: [] },
          blockedAt: r.createdAt.toISOString(),
        };
      }),
      nextCursor:
        rows.length > limit
          ? encodeCursor({ f: 'blocks', c: page[page.length - 1].createdAt.toISOString(), i: page[page.length - 1].id })
          : null,
    };
  }

  /** `GET /community/members/:memberId` (§7.12). */
  async memberProfile(viewer: CommunityViewer, memberId: string) {
    const [member, outgoing, incoming] = await runDb(this.prisma, (db) =>
      Promise.all([
        db.communityMember.findUnique({ where: { id: memberId }, select: { id: true, createdAt: true } }),
        db.communityBlock.findUnique({
          where: { blockerMemberId_blockedMemberId: { blockerMemberId: viewer.memberId, blockedMemberId: memberId } },
        }),
        db.communityBlock.findUnique({
          where: { blockerMemberId_blockedMemberId: { blockerMemberId: memberId, blockedMemberId: viewer.memberId } },
        }),
      ]),
    );
    if (!member) throw CommunityErrors.memberNotFound();
    // Bloqué PAR lui : il n'existe plus pour moi. Bloqué par moi : je le vois
    // encore ici, pour pouvoir le débloquer.
    if (incoming && !outgoing) throw CommunityErrors.memberNotFound();
    const [identities, stats] = await Promise.all([this.identities([memberId]), this.stats(memberId)]);
    const identity = identities.get(memberId);
    if (!identity) throw CommunityErrors.memberNotFound();
    return {
      member: memberAuthor(identity),
      stats,
      memberSince: member.createdAt.toISOString().slice(0, 7),
      viewer: { isMe: memberId === viewer.memberId, isBlocked: !!outgoing },
    };
  }
}
