import {
  UnauthorizedException,
  ValidationPipe,
  type ExecutionContext,
  type INestApplication,
} from '@nestjs/common';
import { APP_GUARD, Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import { GlobalExceptionFilter } from '../../common/filters/http-exception.filter';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { buildThrottlerOptions } from '../../common/throttler-options';
import { CommunityAccessService } from './community-access.service';
import { CommunityAdminController } from './community-admin.controller';
import { CommunityCatalogService } from './community-catalog.service';
import { CommunityErrors } from './community-errors';
import { CommunityModerationService } from './community-moderation.service';
import { CommunityPostsService } from './community-posts.service';
import { CommunityStudentController } from './community-student.controller';
import { CommunityEnabledGuard } from './community.feature';

/**
 * Les deux contrôleurs de la communauté sur HTTP réel : la ValidationPipe de
 * `main.ts`, le filtre global, le limiteur, les vrais gardes de drapeau et de
 * rôles. Les services sont des doublures : ce qui est testé ici, ce sont les
 * portes, les codes HTTP et la forme des erreurs du contrat.
 */

const FLAG = 'KPB_COMMUNITY_ENABLED';
const previousFlag = process.env[FLAG];

const fakeStudentGuard = {
  canActivate: (context: ExecutionContext) => {
    const request = context.switchToHttp().getRequest();
    const header = request.headers?.authorization as string | undefined;
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException('Missing authorization token.');
    request.studentUser = { id: 'u-me', accountType: header.slice(7) };
    return true;
  },
};

/** `X-Test-Role: <role>` ; sans en-tête : 401. */
const fakeAdminGuard = {
  canActivate: (context: ExecutionContext) => {
    const request = context.switchToHttp().getRequest();
    const role = request.headers?.['x-test-role'] as string | undefined;
    if (!role) throw new UnauthorizedException('Missing admin authorization token.');
    request.adminUser = { id: 'adm-1', fullName: 'Fatou Diallo', email: 'f@kpb.test', role, languageScope: [] };
    return true;
  },
};

const VIEWER = { memberId: 'me', userId: 'u-me' };

describe('Communauté — contrôleurs (HTTP)', () => {
  let app: INestApplication;
  let base: string;
  const access = {
    resolveViewer: jest.fn(async (_id: string, accountType?: string) => {
      if (accountType && accountType !== 'student') throw CommunityErrors.studentsOnly();
      return VIEWER;
    }),
    me: jest.fn(async () => ({ member: {}, charter: {} })),
    acceptCharter: jest.fn(async () => ({ acceptedVersion: 'v', acceptedAt: 'x' })),
    block: jest.fn(async () => ({ isBlocked: true })),
    unblock: jest.fn(async () => ({ isBlocked: false })),
    listBlocks: jest.fn(async () => ({ items: [], nextCursor: null })),
    memberProfile: jest.fn(async () => ({})),
  };
  const posts = {
    feed: jest.fn(async () => ({ tab: 'recent', items: [], nextCursor: null, pinned: [] })),
    createPost: jest.fn(async () => ({ id: 'p1' })),
    deletePost: jest.fn(async () => undefined),
    entityCounts: jest.fn(async () => ({ items: [] })),
    entityCount: jest.fn(async (type: string, id: string) => ({ type, id, discussionCount: 2 })),
    entitySpace: jest.fn(async () => ({})),
    getPost: jest.fn(async () => {
      throw CommunityErrors.postNotFound();
    }),
    setPostHelpful: jest.fn(async () => ({ helpfulCount: 1, hasMarkedHelpful: true })),
  };
  const moderation = {
    report: jest.fn(),
    queue: jest.fn(async () => ({ counts: {}, items: [], nextCursor: null })),
    listPosts: jest.fn(async () => ({ items: [], nextCursor: null })),
    createSanction: jest.fn(async () => ({ id: 's1' })),
    addFilter: jest.fn(async () => ({ created: true, entry: { id: 'f1' } })),
    teamReply: jest.fn(async () => ({ id: 'r1' })),
    stats: jest.fn(async () => ({})),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ThrottlerModule.forRoot(buildThrottlerOptions('test'))],
      controllers: [CommunityStudentController, CommunityAdminController],
      providers: [
        { provide: APP_GUARD, useClass: ThrottlerGuard },
        Reflector,
        RolesGuard,
        CommunityEnabledGuard,
        { provide: CommunityAccessService, useValue: access },
        { provide: CommunityPostsService, useValue: posts },
        { provide: CommunityModerationService, useValue: moderation },
        { provide: CommunityCatalogService, useValue: { suggest: jest.fn(async () => []) } },
      ],
    })
      .overrideGuard(StudentAuthGuard)
      .useValue(fakeStudentGuard)
      .overrideGuard(AdminAuthGuard)
      .useValue(fakeAdminGuard)
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(async () => {
    await app.close();
    if (previousFlag === undefined) delete process.env[FLAG];
    else process.env[FLAG] = previousFlag;
  });

  beforeEach(() => {
    process.env[FLAG] = 'true';
    jest.clearAllMocks();
  });

  function call(
    method: string,
    path: string,
    options: { token?: string; role?: string; body?: unknown } = {},
  ): Promise<Response> {
    return fetch(`${base}${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
        ...(options.role ? { 'x-test-role': options.role } : {}),
      },
      ...(options.body !== undefined ? { body: JSON.stringify(options.body) } : {}),
    });
  }

  describe('drapeau KPB_COMMUNITY_ENABLED', () => {
    it.each([
      ['GET', '/community/me', undefined],
      ['GET', '/community/feed?tab=recent', undefined],
      ['POST', '/community/posts', { type: 'question', title: 'Bonjour à tous', body: 'x'.repeat(30) }],
      ['POST', '/community/reports', { targetType: 'post', targetId: 'p1', reason: 'scam' }],
      ['GET', '/community/entities/scholarship/s1/count', undefined],
    ])('coupé : %s %s → 404 { disabled: true }, avant l’authentification', async (method, path, body) => {
      for (const value of [undefined, '', 'false', 'yes']) {
        if (value === undefined) delete process.env[FLAG];
        else process.env[FLAG] = value;
        const response = await call(method, path, { body });
        expect(response.status).toBe(404);
        await expect(response.json()).resolves.toEqual({
          statusCode: 404,
          disabled: true,
          code: 'community_disabled',
          message: 'Community is disabled.',
        });
      }
      expect(access.resolveViewer).not.toHaveBeenCalled();
    });

    it('coupé : les routes admin restent ouvertes', async () => {
      delete process.env[FLAG];
      const response = await call('GET', '/admin/community/queue', { role: 'moderator' });
      expect(response.status).toBe(200);
    });
  });

  describe('portes élève', () => {
    it('sans jeton → 401', async () => {
      expect((await call('GET', '/community/me')).status).toBe(401);
    });

    it('compte parent → 403 community_students_only', async () => {
      const response = await call('GET', '/community/me', { token: 'parent' });
      expect(response.status).toBe(403);
      await expect(response.json()).resolves.toMatchObject({ code: 'community_students_only' });
    });

    it('rejette un champ inconnu (forbidNonWhitelisted) et un onglet inconnu', async () => {
      const extra = await call('POST', '/community/posts', {
        token: 'student',
        body: { type: 'question', title: 'Bonjour à tous', body: 'x'.repeat(30), authorId: 'someone' },
      });
      expect(extra.status).toBe(400);
      expect((await call('GET', '/community/feed?tab=popular', { token: 'student' })).status).toBe(400);
      expect((await call('GET', '/community/feed?tab=recent&limit=51', { token: 'student' })).status).toBe(400);
      expect(posts.createPost).not.toHaveBeenCalled();
    });

    it('rejette un type d’entité inconnu', async () => {
      expect((await call('GET', '/community/entities/user/u1/count', { token: 'student' })).status).toBe(400);
    });

    it('route à segment fixe `entities/counts` non capturée par `:type/:id`', async () => {
      const response = await call('GET', '/community/entities/counts?refs=scholarship:s1,country:fra', { token: 'student' });
      expect(response.status).toBe(200);
      expect(posts.entityCounts).toHaveBeenCalledWith('scholarship:s1,country:fra');
    });

    it('publier → 201 ; supprimer → 204 sans corps', async () => {
      const created = await call('POST', '/community/posts?lang=fr', {
        token: 'student',
        body: { type: 'question', title: 'Bonjour à tous', body: 'x'.repeat(30) },
      });
      expect(created.status).toBe(201);
      const deleted = await call('DELETE', '/community/posts/p1', { token: 'student' });
      expect(deleted.status).toBe(204);
      expect(await deleted.text()).toBe('');
    });

    it('signaler : 201 la première fois, 200 au doublon', async () => {
      moderation.report
        .mockResolvedValueOnce({ created: true, report: { id: 'r1' } })
        .mockResolvedValueOnce({ created: false, report: { id: 'r1' } });
      const body = { targetType: 'reply', targetId: 'c1', reason: 'scam', details: 'Demande d’argent' };
      expect((await call('POST', '/community/reports', { token: 'student', body })).status).toBe(201);
      expect((await call('POST', '/community/reports', { token: 'student', body })).status).toBe(200);
      const bad = await call('POST', '/community/reports', { token: 'student', body: { ...body, reason: 'boring' } });
      expect(bad.status).toBe(400);
    });

    it('les erreurs métier gardent leur `code` (404 community_post_not_found)', async () => {
      const response = await call('GET', '/community/posts/p404', { token: 'student' });
      expect(response.status).toBe(404);
      await expect(response.json()).resolves.toMatchObject({ code: 'community_post_not_found' });
      expect(response.headers.get('cache-control')).toBe('private, no-store');
    });

    it('« utile » : PUT idempotent', async () => {
      const response = await call('PUT', '/community/posts/p1/helpful', { token: 'student' });
      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toEqual({ helpfulCount: 1, hasMarkedHelpful: true });
    });
  });

  describe('rôles admin', () => {
    it('sans session → 401', async () => {
      expect((await call('GET', '/admin/community/queue')).status).toBe(401);
    });

    it.each([
      ['moderator', 200],
      ['content_manager', 200],
      ['admin', 200],
      ['super_admin', 200],
      ['counselor', 403],
      ['commercial', 403],
    ])('file de modération pour %s → %d', async (role, status) => {
      expect((await call('GET', '/admin/community/queue', { role })).status).toBe(status);
    });

    it('le conseiller lit les discussions et y répond, sans voir la file', async () => {
      expect((await call('GET', '/admin/community/posts', { role: 'counselor' })).status).toBe(200);
      const reply = await call('POST', '/admin/community/posts/p1/replies', {
        role: 'counselor',
        body: { body: 'Réponse du conseiller', as: 'kpb_advisor' },
      });
      expect(reply.status).toBe(201);
      expect((await call('GET', '/admin/community/stats', { role: 'counselor' })).status).toBe(403);
    });

    it('sanctions : Moderator oui, ContentManager non ; durée bornée', async () => {
      const body = { kind: 'read_only', reason: 'Spam répété', durationDays: 7 };
      expect((await call('POST', '/admin/community/members/m1/sanctions', { role: 'moderator', body })).status).toBe(201);
      expect((await call('POST', '/admin/community/members/m1/sanctions', { role: 'content_manager', body })).status).toBe(403);
      const tooLong = await call('POST', '/admin/community/members/m1/sanctions', {
        role: 'admin',
        body: { ...body, durationDays: 400 },
      });
      expect(tooLong.status).toBe(400);
    });

    it('filtre : seuls Admin et SuperAdmin le configurent', async () => {
      const body = { kind: 'allowed_domain', value: 'univ-lyon1.fr' };
      expect((await call('POST', '/admin/community/filters', { role: 'moderator', body })).status).toBe(403);
      const ok = await call('POST', '/admin/community/filters', { role: 'admin', body });
      expect(ok.status).toBe(201);
      expect(ok.headers.get('x-request-id')).toBeTruthy();
    });

    it('le rôle est transmis au service (identité réelle réservée à Admin/SuperAdmin)', async () => {
      await call('GET', '/admin/community/queue?kind=reported', { role: 'moderator' });
      expect(moderation.queue).toHaveBeenCalledWith('moderator', 'reported', undefined, undefined, 'fr');
    });
  });
});
