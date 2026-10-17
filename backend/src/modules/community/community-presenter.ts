// ─────────────────────────────────────────────────────────────────────────────
// Communauté — la forme JSON du contrat (§5). Fonctions pures : la base est lue
// ailleurs, ici on ne fait que traduire des lignes en réponses.
// ─────────────────────────────────────────────────────────────────────────────

import { Prisma } from '@prisma/client';

import { publicNameFromFullName } from '../referrals/referral-code';
import { COMMUNITY_EDIT_WINDOW_MS } from './community.constants';
import type { ForYouReason } from './community-for-you';
import {
  buildSegments,
  excerptOf,
  mentionKey,
  type Lang,
  type MentionLabels,
  type Segment,
} from './community-text';

export const POST_INCLUDE = {
  mentions: true,
  hashtags: { include: { hashtag: true } },
} satisfies Prisma.CommunityPostInclude;

export const REPLY_INCLUDE = {
  mentions: true,
} satisfies Prisma.CommunityReplyInclude;

export type PostRow = Prisma.CommunityPostGetPayload<{ include: typeof POST_INCLUDE }>;
export type ReplyRow = Prisma.CommunityReplyGetPayload<{ include: typeof REPLY_INCLUDE }>;

export type Badge = 'kpb_team' | 'kpb_advisor' | 'verified_alumni' | 'ambassador';
const BADGE_ORDER: readonly Badge[] = ['kpb_team', 'kpb_advisor', 'verified_alumni', 'ambassador'];

export interface AuthorJson {
  kind: 'member' | 'kpb_team' | 'kpb_advisor';
  memberId: string | null;
  displayName: string;
  countryName: string | null;
  badges: Badge[];
}

export const KPB_TEAM_NAME = 'Équipe KPB';

/** Ce qu'il faut savoir d'un membre pour l'afficher (lu depuis le profil). */
export interface MemberIdentity {
  memberId: string;
  fullName: string;
  countryOfResidence: string | null;
  alumniApproved: boolean;
  alumniBadgeVisible: boolean;
  ambassadorApproved: boolean;
}

export function sortBadges(badges: Iterable<Badge>): Badge[] {
  const set = new Set(badges);
  return BADGE_ORDER.filter((b) => set.has(b));
}

export function memberAuthor(identity: MemberIdentity): AuthorJson {
  const badges: Badge[] = [];
  if (identity.alumniApproved && identity.alumniBadgeVisible) badges.push('verified_alumni');
  if (identity.ambassadorApproved) badges.push('ambassador');
  return {
    kind: 'member',
    memberId: identity.memberId,
    displayName: publicNameFromFullName(identity.fullName) || 'Membre',
    countryName: identity.countryOfResidence?.trim() || null,
    badges: sortBadges(badges),
  };
}

export function teamAuthor(kind: 'kpb_team' | 'kpb_advisor', adminName: string | null): AuthorJson {
  return {
    kind,
    memberId: null,
    displayName: kind === 'kpb_team' ? KPB_TEAM_NAME : adminName || KPB_TEAM_NAME,
    countryName: null,
    badges: kind === 'kpb_team' ? ['kpb_team'] : ['kpb_advisor'],
  };
}

/** Auteur d'un contenu, d'après sa ligne et la table des identités. */
export function contentAuthor(
  row: { authorKind: string; authorMemberId: string | null; authorAdminName: string | null },
  identities: ReadonlyMap<string, MemberIdentity>,
): AuthorJson {
  if (row.authorKind === 'kpb_team' || row.authorKind === 'kpb_advisor') {
    return teamAuthor(row.authorKind, row.authorAdminName);
  }
  const identity = row.authorMemberId ? identities.get(row.authorMemberId) : undefined;
  if (!identity) {
    return { kind: 'member', memberId: row.authorMemberId, displayName: 'Membre', countryName: null, badges: [] };
  }
  return memberAuthor(identity);
}

export interface MentionJson {
  type: string;
  id: string;
  label: string;
  countryId: string | null;
}

type MentionRowLike = {
  entityType: string;
  entityId: string;
  labelFr: string;
  labelEn: string;
  countryId: string | null;
};

export function mentionLabelMap(rows: readonly MentionRowLike[]): Map<string, MentionLabels> {
  return new Map(rows.map((m) => [mentionKey(m.entityType, m.entityId), { labelFr: m.labelFr, labelEn: m.labelEn }]));
}

export function mentionsJson(rows: readonly MentionRowLike[], lang: Lang): MentionJson[] {
  return rows.map((m) => ({
    type: m.entityType,
    id: m.entityId,
    label: lang === 'en' ? m.labelEn : m.labelFr,
    countryId: m.countryId,
  }));
}

export interface ModerationJson {
  status: 'pending_review' | 'hidden';
  reason: string;
  since: string;
}

export interface PresentContext {
  viewerMemberId: string | null;
  lang: Lang;
  now: Date;
  isAllowedHost: (host: string) => boolean;
  identities: ReadonlyMap<string, MemberIdentity>;
  helpfulPostIds: ReadonlySet<string>;
  helpfulReplyIds: ReadonlySet<string>;
  followedPostIds: ReadonlySet<string>;
}

function moderationFor(
  row: { status: string; statusReason: string | null; statusChangedAt: Date | null; createdAt: Date; authorMemberId: string | null },
  ctx: PresentContext,
): ModerationJson | null {
  if (row.status !== 'pending_review' && row.status !== 'hidden') return null;
  if (!ctx.viewerMemberId || row.authorMemberId !== ctx.viewerMemberId) return null;
  return {
    status: row.status,
    reason: row.statusReason ?? (row.status === 'hidden' ? 'moderation' : 'auto_filter'),
    since: (row.statusChangedAt ?? row.createdAt).toISOString(),
  };
}

function viewerFlags(
  row: { authorMemberId: string | null; createdAt: Date; status: string },
  ctx: PresentContext,
) {
  const isAuthor = !!ctx.viewerMemberId && row.authorMemberId === ctx.viewerMemberId;
  const editableUntil = new Date(row.createdAt.getTime() + COMMUNITY_EDIT_WINDOW_MS);
  const canEdit = isAuthor && row.status !== 'deleted' && ctx.now.getTime() <= editableUntil.getTime();
  return {
    isAuthor,
    canEdit,
    canDelete: isAuthor && row.status !== 'deleted',
    editableUntil: canEdit ? editableUntil.toISOString() : null,
  };
}

export function postSummaryJson(
  row: PostRow,
  ctx: PresentContext,
  forYouReasons?: ForYouReason[],
) {
  const labels = mentionLabelMap(row.mentions);
  const flags = viewerFlags(row, ctx);
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    excerpt: excerptOf(row.body, labels, ctx.lang),
    author: contentAuthor(row, ctx.identities),
    createdAt: row.createdAt.toISOString(),
    editedAt: row.editedAt?.toISOString() ?? null,
    lastActivityAt: row.lastActivityAt.toISOString(),
    replyCount: row.replyCount,
    helpfulCount: row.helpfulCount,
    hasVerifiedAnswer: row.hasVerifiedAnswer,
    isPinned: row.pinnedAt !== null,
    mentions: mentionsJson(row.mentions, ctx.lang),
    hashtags: row.hashtags.map((h) => ({ tag: h.hashtag.tag, display: h.hashtag.display })),
    viewer: {
      isAuthor: flags.isAuthor,
      hasMarkedHelpful: ctx.helpfulPostIds.has(row.id),
      isFollowing: ctx.followedPostIds.has(row.id),
      canEdit: flags.canEdit,
      canDelete: flags.canDelete,
      editableUntil: flags.editableUntil,
    },
    moderation: moderationFor(row, ctx),
    ...(forYouReasons ? { forYouReasons } : {}),
  };
}

export type PostSummaryJson = ReturnType<typeof postSummaryJson>;

export function postJson(row: PostRow, ctx: PresentContext) {
  const labels = mentionLabelMap(row.mentions);
  return {
    ...postSummaryJson(row, ctx),
    body: row.body,
    segments: buildSegments(row.body, labels, ctx.lang, ctx.isAllowedHost) as Segment[],
  };
}

export function replyJson(row: ReplyRow, ctx: PresentContext) {
  const labels = mentionLabelMap(row.mentions);
  const flags = viewerFlags(row, ctx);
  return {
    id: row.id,
    postId: row.postId,
    body: row.body,
    segments: buildSegments(row.body, labels, ctx.lang, ctx.isAllowedHost) as Segment[],
    mentions: mentionsJson(row.mentions, ctx.lang),
    author: contentAuthor(row, ctx.identities),
    createdAt: row.createdAt.toISOString(),
    editedAt: row.editedAt?.toISOString() ?? null,
    helpfulCount: row.helpfulCount,
    isVerified: row.isVerified,
    verifiedAt: row.verifiedAt?.toISOString() ?? null,
    viewer: {
      isAuthor: flags.isAuthor,
      hasMarkedHelpful: ctx.helpfulReplyIds.has(row.id),
      canEdit: flags.canEdit,
      canDelete: flags.canDelete,
      editableUntil: flags.editableUntil,
    },
    moderation: moderationFor(row, ctx),
  };
}
