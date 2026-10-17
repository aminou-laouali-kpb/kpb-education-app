import { HttpException } from '@nestjs/common';

import type { PrismaService } from '../prisma/prisma.service';
import { COMMUNITY_CHARTER_VERSION, COMMUNITY_QUOTAS } from './community.constants';
import { CommunityAccessService, type CommunityViewer } from './community-access.service';
import { statusForFlags } from './community-composer.service';
import { CommunityPostsService } from './community-posts.service';

const NOW = new Date('2026-10-17T12:00:00.000Z');
const DAY = 24 * 60 * 60 * 1000;

function viewer(over: Partial<CommunityViewer> = {}): CommunityViewer {
  return {
    memberId: 'me',
    userId: 'u-me',
    email: 'me@gmail.com',
    fullName: 'Aïcha Konaté',
    countryOfResidence: 'Niger',
    profileCreatedAt: new Date(NOW.getTime() - 30 * DAY),
    targetCountryIds: [],
    scholarshipTargetLevel: null,
    disabledNotificationTypes: [],
    charterVersion: COMMUNITY_CHARTER_VERSION,
    charterAcceptedAt: new Date(NOW.getTime() - DAY),
    alumniApproved: false,
    alumniBadgeVisible: true,
    ...over,
  };
}

/** Un client Prisma réduit aux tables lues par ces tests. */
function fakePrisma(tables: {
  sanctions?: { kind: string; endsAt: Date | null; revokedAt: Date | null; reason: string; createdAt: Date }[];
  posts?: { createdAt: Date }[];
  replies?: { createdAt: Date }[];
  reports?: { createdAt: Date }[];
  profile?: { accountType: string } | null;
}): PrismaService {
  const since = (rows: { createdAt: Date }[] = [], where: { createdAt: { gte: Date } }) =>
    rows.filter((r) => r.createdAt >= where.createdAt.gte).sort((a, b) => +a.createdAt - +b.createdAt);
  const client = {
    communitySanction: {
      findMany: jest.fn(async ({ where }: { where: { kind: { in: string[] } } }) =>
        (tables.sanctions ?? []).filter(
          (s) =>
            s.revokedAt === null &&
            where.kind.in.includes(s.kind) &&
            (s.endsAt === null || s.endsAt > NOW),
        ),
      ),
    },
    communityPost: { findMany: jest.fn(async ({ where }) => since(tables.posts, where)) },
    communityReply: { findMany: jest.fn(async ({ where }) => since(tables.replies, where)) },
    communityReport: { findMany: jest.fn(async ({ where }) => since(tables.reports, where)) },
    userProfile: {
      findUnique: jest.fn(async () =>
        tables.profile === null
          ? null
          : {
              id: 'u-me',
              accountType: tables.profile?.accountType ?? 'student',
              email: 'me@gmail.com',
              fullName: 'Aïcha Konaté',
              countryOfResidence: 'Niger',
              createdAt: NOW,
              targetCountryIds: [],
              scholarshipTargetLevel: null,
              disabledNotificationTypes: [],
              alumniStatus: 'none',
              alumniBadgeVisible: true,
            },
      ),
    },
    communityMember: {
      upsert: jest.fn(async () => ({ id: 'me', charterVersion: null, charterAcceptedAt: null })),
    },
  };
  return {
    isEnabled: true,
    execute: async (op: (c: unknown) => Promise<unknown>) => op(client),
  } as unknown as PrismaService;
}

async function codeOf(promise: Promise<unknown>): Promise<{ status: number; code?: string; details?: unknown }> {
  try {
    await promise;
  } catch (error) {
    const e = error as HttpException;
    const body = e.getResponse() as { code?: string; details?: unknown };
    return { status: e.getStatus(), code: body.code, details: body.details };
  }
  throw new Error('expected a rejection');
}

describe('CommunityAccessService — portes d’écriture', () => {
  it('refuse un compte parent ou partenaire, avant toute lecture', async () => {
    const service = new CommunityAccessService(fakePrisma({}));
    await expect(codeOf(service.resolveViewer('u-me', 'parent'))).resolves.toMatchObject({
      status: 403,
      code: 'community_students_only',
    });
  });

  it('refuse aussi un profil non élève lu en base (jeton sans type)', async () => {
    const service = new CommunityAccessService(fakePrisma({ profile: { accountType: 'partner' } }));
    await expect(codeOf(service.resolveViewer('u-me'))).resolves.toMatchObject({ code: 'community_students_only' });
  });

  it('crée la fiche membre au premier appel', async () => {
    const prisma = fakePrisma({});
    const service = new CommunityAccessService(prisma);
    const v = await service.resolveViewer('u-me', 'student');
    expect(v.memberId).toBe('me');
    expect(v.charterVersion).toBeNull();
  });

  it('charte absente ou périmée → 403 community_charter_required avec la version courante', async () => {
    const service = new CommunityAccessService(fakePrisma({}));
    for (const charterVersion of [null, '2025-01-v0']) {
      await expect(codeOf(service.assertCanWrite(viewer({ charterVersion }), NOW))).resolves.toEqual({
        status: 403,
        code: 'community_charter_required',
        details: { charterVersion: COMMUNITY_CHARTER_VERSION },
      });
    }
  });

  it('lecture seule active → 403 community_read_only avec sa date de fin', async () => {
    const endsAt = new Date(NOW.getTime() + 3 * DAY);
    const service = new CommunityAccessService(
      fakePrisma({ sanctions: [{ kind: 'read_only', endsAt, revokedAt: null, reason: 'Spam', createdAt: NOW }] }),
    );
    await expect(codeOf(service.assertCanWrite(viewer(), NOW))).resolves.toEqual({
      status: 403,
      code: 'community_read_only',
      details: { kind: 'read_only', until: endsAt.toISOString() },
    });
  });

  it('le bannissement prime sur la lecture seule ; une sanction levée ou échue ne compte plus', async () => {
    const service = new CommunityAccessService(
      fakePrisma({
        sanctions: [
          { kind: 'read_only', endsAt: new Date(NOW.getTime() + DAY), revokedAt: null, reason: 'a', createdAt: NOW },
          { kind: 'ban', endsAt: null, revokedAt: null, reason: 'Arnaque', createdAt: NOW },
        ],
      }),
    );
    await expect(service.restriction('me', NOW)).resolves.toEqual({ kind: 'ban', until: null, reason: 'Arnaque' });

    const cleared = new CommunityAccessService(
      fakePrisma({
        sanctions: [
          { kind: 'ban', endsAt: null, revokedAt: NOW, reason: 'levée', createdAt: NOW },
          { kind: 'read_only', endsAt: new Date(NOW.getTime() - 1), revokedAt: null, reason: 'échue', createdAt: NOW },
          { kind: 'warning', endsAt: null, revokedAt: null, reason: 'avertissement', createdAt: NOW },
        ],
      }),
    );
    await expect(cleared.assertCanWrite(viewer(), NOW)).resolves.toBeUndefined();
  });
});

describe('CommunityAccessService — quotas (§4.3)', () => {
  const hoursAgo = (h: number) => ({ createdAt: new Date(NOW.getTime() - h * 60 * 60 * 1000) });

  it('nouveau compte : 3 publications par 24 h, puis 429 avec Retry-After calculé', async () => {
    const fresh = viewer({ profileCreatedAt: new Date(NOW.getTime() - 2 * DAY) });
    const service = new CommunityAccessService(fakePrisma({ posts: [hoursAgo(20), hoursAgo(5), hoursAgo(1), hoursAgo(30)] }));
    const result = await codeOf(service.assertQuota(fresh, 'posts_per_day', NOW));
    expect(result).toEqual({
      status: 429,
      code: 'community_rate_limited',
      details: { scope: 'posts_per_day', limit: COMMUNITY_QUOTAS.postsPerDay.newAccount, retryAfterSeconds: 4 * 3600 },
    });
  });

  it('compte établi : la même activité passe', async () => {
    const service = new CommunityAccessService(fakePrisma({ posts: [hoursAgo(20), hoursAgo(5), hoursAgo(1)] }));
    await expect(service.assertQuota(viewer(), 'posts_per_day', NOW)).resolves.toBeUndefined();
  });

  it('réponses : 10 par heure pour un nouveau compte, 30 sinon', async () => {
    const replies = Array.from({ length: 10 }, (_, i) => ({ createdAt: new Date(NOW.getTime() - (i + 1) * 60_000) }));
    const service = new CommunityAccessService(fakePrisma({ replies }));
    const fresh = viewer({ profileCreatedAt: NOW });
    await expect(codeOf(service.assertQuota(fresh, 'replies_per_hour', NOW))).resolves.toMatchObject({
      status: 429,
      details: { scope: 'replies_per_hour', limit: 10 },
    });
    await expect(service.assertQuota(viewer(), 'replies_per_hour', NOW)).resolves.toBeUndefined();
  });
});

describe('visibilité d’un contenu (§6)', () => {
  const posts = new CommunityPostsService(
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
  );
  const me = viewer();

  it.each([
    ['visible d’un autre', { status: 'visible', authorMemberId: 'other' }, [], true],
    ['visible d’un membre bloqué (dans un sens ou l’autre)', { status: 'visible', authorMemberId: 'other' }, ['other'], false],
    ['de l’équipe, même avec des blocages', { status: 'visible', authorMemberId: null }, ['other'], true],
    ['en attente de revue d’un autre', { status: 'pending_review', authorMemberId: 'other' }, [], false],
    ['masqué par la modération d’un autre', { status: 'hidden', authorMemberId: 'other' }, [], false],
    ['mon contenu en attente de revue', { status: 'pending_review', authorMemberId: 'me' }, [], true],
    ['mon contenu masqué', { status: 'hidden', authorMemberId: 'me' }, [], true],
    ['mon contenu supprimé', { status: 'deleted', authorMemberId: 'me' }, [], false],
    ['supprimé d’un autre', { status: 'deleted', authorMemberId: 'other' }, [], false],
  ] as const)('%s', (_label, post, blocked, expected) => {
    expect(posts.canSeePost(post as never, me, blocked)).toBe(expected);
  });
});

describe('statut de naissance d’un contenu (§9.1)', () => {
  it('aucun drapeau → visible ; e-mail jetable seul → revue « nouveau compte » ; sinon filtre', () => {
    expect(statusForFlags([])).toEqual({ status: 'visible', statusReason: null });
    expect(statusForFlags(['disposable_email'])).toEqual({ status: 'pending_review', statusReason: 'new_account_review' });
    expect(statusForFlags(['phone', 'disposable_email'])).toEqual({ status: 'pending_review', statusReason: 'auto_filter' });
  });
});
