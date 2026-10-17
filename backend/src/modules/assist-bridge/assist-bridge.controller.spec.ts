import { NotFoundException, UnauthorizedException, ValidationPipe, type ExecutionContext, type INestApplication } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';

import { GlobalExceptionFilter } from '../../common/filters/http-exception.filter';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { NOTIFICATION_OPT_OUT_TYPES, sanitizeOptOutTypes } from '../../common/notification-types';
import type { PrismaService } from '../prisma/prisma.service';
import { AssistBridgeAdminController, AssistBridgeStudentController } from './assist-bridge.controller';
import { assistBridgeCoachEnabled, assistBridgeMode, ASSIST_BRIDGE_OPT_OUT } from './assist-bridge.config';
import { AssistBridgeCronService } from './assist-bridge-cron.service';
import { AssistBridgeQueueService } from './assist-bridge-queue.service';
import { AssistBridgeService } from './assist-bridge.service';

const MODE = 'KPB_ASSIST_BRIDGE_MODE';
const COACH = 'KPB_ASSIST_BRIDGE_COACH';
const previous = { mode: process.env[MODE], coach: process.env[COACH] };

function restoreEnv() {
  if (previous.mode === undefined) delete process.env[MODE];
  else process.env[MODE] = previous.mode;
  if (previous.coach === undefined) delete process.env[COACH];
  else process.env[COACH] = previous.coach;
}

describe('Passerelle — réglages', () => {
  afterEach(restoreEnv);

  it.each([
    [undefined, 'shadow'],
    ['', 'shadow'],
    ['shadow', 'shadow'],
    [' ON ', 'on'],
    ['off', 'off'],
    ['oui', 'shadow'],
    ['true', 'shadow'],
  ])('%p → %s (une faute de frappe ne vaut jamais on)', (raw, mode) => {
    if (raw === undefined) delete process.env[MODE];
    else process.env[MODE] = raw;
    expect(assistBridgeMode()).toBe(mode);
  });

  it('source coach FERMÉE par défaut, ouverte seulement par `true`', () => {
    delete process.env[COACH];
    expect(assistBridgeCoachEnabled()).toBe(false);
    for (const v of ['', 'yes', '1', 'on']) {
      process.env[COACH] = v;
      expect(assistBridgeCoachEnabled()).toBe(false);
    }
    process.env[COACH] = ' TRUE ';
    expect(assistBridgeCoachEnabled()).toBe(true);
  });

  it('la clé de désinscription `assist_bridge` survit au filtrage du profil', () => {
    expect(NOTIFICATION_OPT_OUT_TYPES).toContain(ASSIST_BRIDGE_OPT_OUT);
    expect(sanitizeOptOutTypes(['assist_bridge', 'community', 'inconnue'])).toEqual(['assist_bridge', 'community']);
  });

  it('off : la file n’écrit rien, la tâche ne traite rien', async () => {
    process.env[MODE] = 'off';
    const execute = jest.fn();
    const queue = new AssistBridgeQueueService({ isEnabled: true, execute } as unknown as PrismaService);
    expect(await queue.enqueueCommunity('post', 'p1')).toBe(false);
    expect(await queue.enqueueCoach('u1', 'm1', 'Je cherche une bourse pour un master en France')).toBe(false);
    expect(execute).not.toHaveBeenCalled();
    const processQueue = jest.fn();
    const cron = new AssistBridgeCronService(
      { isEnabled: true } as unknown as PrismaService,
      { processQueue } as unknown as AssistBridgeService,
    );
    await cron.run();
    expect(processQueue).not.toHaveBeenCalled();
  });

  it('source coach fermée par défaut : rien n’est écrit, même en mode on', async () => {
    process.env[MODE] = 'on';
    delete process.env[COACH];
    const execute = jest.fn();
    const queue = new AssistBridgeQueueService({ isEnabled: true, execute } as unknown as PrismaService);
    expect(await queue.enqueueCoach('u1', 'm1', 'Je cherche une bourse pour un master en France')).toBe(false);
    expect(execute).not.toHaveBeenCalled();
  });

  it('source coach ouverte : seuls le besoin, la règle et l’id du message sont écrits (jamais le texte)', async () => {
    process.env[MODE] = 'shadow';
    process.env[COACH] = 'true';
    const createMany = jest.fn(async () => ({ count: 1 }));
    const queue = new AssistBridgeQueueService({
      isEnabled: true,
      execute: async (op: (db: unknown) => unknown) => op({ assistBridgeEvent: { createMany } }),
    } as unknown as PrismaService);
    const text = 'Je cherche une bourse pour un master en France, quelle bourse pour moi ?';
    expect(await queue.enqueueCoach('u1', 'm1', text)).toBe(true);
    const calls = createMany.mock.calls as unknown as Array<[{ data: Array<Record<string, unknown>> }]>;
    const row = calls[0][0].data[0];
    expect(row).toEqual({
      userId: 'u1',
      source: 'coach_message',
      sourceId: 'm1',
      needId: 'scholarship_match',
      ruleId: 'scholarship_match.which',
      ruleVersion: 'ab-1',
    });
    expect(JSON.stringify(row)).not.toContain('master');
    // Aucun besoin : aucune écriture.
    createMany.mockClear();
    expect(await queue.enqueueCoach('u1', 'm2', 'Merci beaucoup pour ta réponse, c’est très clair !')).toBe(false);
    expect(createMany).not.toHaveBeenCalled();
  });

  it('la file ne propage jamais une erreur (publication et coach jamais bloqués)', async () => {
    process.env[MODE] = 'on';
    process.env[COACH] = 'true';
    const queue = new AssistBridgeQueueService({
      isEnabled: true,
      execute: jest.fn(async () => {
        throw new Error('boom');
      }),
    } as unknown as PrismaService);
    await expect(queue.enqueueCommunity('reply', 'r1')).resolves.toBe(false);
    await expect(queue.enqueueCoach('u1', 'm1', 'Je cherche une bourse pour un master en France')).resolves.toBe(false);
  });

  it('la file ignore le contenu masqué, celui de l’équipe, et lit le texte de l’AUTEUR seulement', async () => {
    process.env[MODE] = 'on';
    const createMany = jest.fn(async () => ({ count: 1 }));
    const rows: Record<string, unknown> = {
      hidden: { title: 'Quelle bourse pour moi ?', body: 'Je cherche une bourse', status: 'pending_review', authorKind: 'member', author: { userId: 'u1' } },
      team: { title: 'Quelle bourse pour moi ?', body: 'Je cherche une bourse', status: 'visible', authorKind: 'kpb_team', author: null },
      ok: { title: 'Quelle bourse pour moi ?', body: 'Je cherche une bourse pour mon master', status: 'visible', authorKind: 'member', author: { userId: 'u9' } },
    };
    const queue = new AssistBridgeQueueService({
      isEnabled: true,
      execute: async (op: (db: unknown) => unknown) =>
        op({
          communityPost: { findUnique: async ({ where }: { where: { id: string } }) => rows[where.id] ?? null },
          assistBridgeEvent: { createMany },
        }),
    } as unknown as PrismaService);
    expect(await queue.enqueueCommunity('post', 'hidden')).toBe(false);
    expect(await queue.enqueueCommunity('post', 'team')).toBe(false);
    expect(await queue.enqueueCommunity('post', 'absent')).toBe(false);
    expect(createMany).not.toHaveBeenCalled();
    expect(await queue.enqueueCommunity('post', 'ok')).toBe(true);
    const calls = createMany.mock.calls as unknown as Array<[{ data: Array<Record<string, unknown>> }]>;
    expect(calls[0][0].data[0]).toMatchObject({ userId: 'u9', source: 'community_post', sourceId: 'ok' });
  });
});

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

/** `X-Test-Student: <id>` ; sans en-tête : 401. */
const fakeStudentGuard = {
  canActivate: (context: ExecutionContext) => {
    const request = context.switchToHttp().getRequest();
    const id = request.headers?.['x-test-student'] as string | undefined;
    if (!id) throw new UnauthorizedException('Missing authorization token.');
    request.studentUser = { id, accountType: 'student' };
    return true;
  },
};

describe('Passerelle — routes (HTTP)', () => {
  let app: INestApplication;
  let base: string;
  const bridge = {
    stats: jest.fn(async () => ({ mode: 'shadow' })),
    list: jest.fn(async () => ({ mode: 'shadow', items: [], nextCursor: null })),
    catalog: jest.fn(() => ({ version: 'ab-1', needs: [] })),
    recordAction: jest.fn(async () => ({ id: 'e1', status: 'opened_feature' })),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [AssistBridgeAdminController, AssistBridgeStudentController],
      providers: [Reflector, RolesGuard, { provide: AssistBridgeService, useValue: bridge }],
    })
      .overrideGuard(AdminAuthGuard)
      .useValue(fakeAdminGuard)
      .overrideGuard(StudentAuthGuard)
      .useValue(fakeStudentGuard)
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => jest.clearAllMocks());

  function call(method: string, path: string, options: { role?: string; student?: string; body?: unknown } = {}) {
    return fetch(`${base}${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(options.role ? { 'x-test-role': options.role } : {}),
        ...(options.student ? { 'x-test-student': options.student } : {}),
      },
      ...(options.body !== undefined ? { body: JSON.stringify(options.body) } : {}),
    });
  }

  it('console : 401 sans session ; 403 pour le conseiller et le commercial', async () => {
    expect((await call('GET', '/admin/community/assist-bridge/stats')).status).toBe(401);
    for (const role of ['counselor', 'commercial']) {
      const res = await call('GET', '/admin/community/assist-bridge/events', { role });
      expect({ role, status: res.status }).toEqual({ role, status: 403 });
    }
    expect(bridge.list).not.toHaveBeenCalled();
  });

  it.each(['moderator', 'content_manager', 'admin', 'super_admin'])('rôle R (%s) : stats, événements, catalogue, no-store', async (role) => {
    const stats = await call('GET', '/admin/community/assist-bridge/stats?days=7', { role });
    expect(stats.status).toBe(200);
    expect(stats.headers.get('cache-control')).toBe('private, no-store');
    expect(bridge.stats).toHaveBeenCalledWith(7);
    const events = await call('GET', '/admin/community/assist-bridge/events?status=sent&needId=visa&source=coach_message&limit=10', { role });
    expect(events.status).toBe(200);
    expect(bridge.list).toHaveBeenCalledWith({ status: 'sent', needId: 'visa', source: 'coach_message' }, undefined, 10);
    expect((await call('GET', '/admin/community/assist-bridge/catalog', { role })).status).toBe(200);
  });

  it('console : validation stricte (statut, besoin, source inconnus)', async () => {
    for (const q of ['status=done', 'needId=logement', 'source=whatsapp', 'days=0', 'limit=0']) {
      const path = q.startsWith('days') ? `/admin/community/assist-bridge/stats?${q}` : `/admin/community/assist-bridge/events?${q}`;
      expect({ q, status: (await call('GET', path, { role: 'admin' })).status }).toEqual({ q, status: 400 });
    }
  });

  it('élève : clic enregistré pour SON compte ; action inconnue ou champ en trop refusés', async () => {
    expect((await call('POST', '/me/assist-bridge/events/e1', { body: { action: 'dismissed' } })).status).toBe(401);
    const res = await call('POST', '/me/assist-bridge/events/e1', { student: 'u1', body: { action: 'opened_feature' } });
    expect(res.status).toBe(200);
    expect(res.headers.get('cache-control')).toBe('private, no-store');
    expect(bridge.recordAction).toHaveBeenCalledWith('u1', 'e1', 'opened_feature');
    for (const body of [{ action: 'shared' }, { action: 'dismissed', extra: 1 }, {}]) {
      expect((await call('POST', '/me/assist-bridge/events/e1', { student: 'u1', body })).status).toBe(400);
    }
    expect((await call('POST', '/me/assist-bridge/events/e%201', { student: 'u1', body: { action: 'dismissed' } })).status).toBe(400);
  });

  it('élève : 404 assist_bridge_event_not_found (événement d’un autre ou jamais envoyé)', async () => {
    bridge.recordAction.mockRejectedValueOnce(
      new NotFoundException({ message: 'Assist bridge event not found.', code: 'assist_bridge_event_not_found' }),
    );
    const res = await call('POST', '/me/assist-bridge/events/e9', { student: 'u2', body: { action: 'opened_whatsapp' } });
    expect(res.status).toBe(404);
    expect(await res.json()).toMatchObject({ code: 'assist_bridge_event_not_found' });
  });
});
