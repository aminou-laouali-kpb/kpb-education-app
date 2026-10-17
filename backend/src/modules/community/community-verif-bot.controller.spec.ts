import { UnauthorizedException, ValidationPipe, type ExecutionContext, type INestApplication } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';

import { GlobalExceptionFilter } from '../../common/filters/http-exception.filter';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import type { PrismaService } from '../prisma/prisma.service';
import { CommunityErrors } from './community-errors';
import { CommunityVerifBotController } from './community-verif-bot.controller';
import { CommunityVerifBotCronService } from './community-verif-bot-cron.service';
import { CommunityVerifBotQueueService } from './community-verif-bot-queue.service';
import { CommunityVerifBotService } from './community-verif-bot.service';
import { verifBotLlmEnabled, verifBotMode } from './community-verif-bot.config';

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

const MODE = 'KPB_COMMUNITY_VERIF_BOT_MODE';
const LLM = 'KPB_COMMUNITY_VERIF_BOT_LLM';
const previous = { mode: process.env[MODE], llm: process.env[LLM] };

function restoreEnv() {
  if (previous.mode === undefined) delete process.env[MODE];
  else process.env[MODE] = previous.mode;
  if (previous.llm === undefined) delete process.env[LLM];
  else process.env[LLM] = previous.llm;
}

describe('Bot Vérif — réglage du mode', () => {
  afterEach(restoreEnv);

  it.each([
    [undefined, 'review'],
    ['', 'review'],
    ['review', 'review'],
    [' AUTO ', 'auto'],
    ['off', 'off'],
    ['automatique', 'review'],
  ])('%p → %s (une faute de frappe ne vaut jamais auto)', (raw, mode) => {
    if (raw === undefined) delete process.env[MODE];
    else process.env[MODE] = raw;
    expect(verifBotMode()).toBe(mode);
  });

  it('LLM fermé sauf `true`', () => {
    delete process.env[LLM];
    expect(verifBotLlmEnabled()).toBe(false);
    process.env[LLM] = 'TRUE';
    expect(verifBotLlmEnabled()).toBe(true);
  });

  it('off : la file n’écrit rien, la tâche ne lance rien', async () => {
    process.env[MODE] = 'off';
    const execute = jest.fn();
    const queue = new CommunityVerifBotQueueService({ isEnabled: true, execute } as unknown as PrismaService);
    expect(await queue.enqueue('p1')).toBe(false);
    expect(execute).not.toHaveBeenCalled();
    const processQueue = jest.fn();
    const cron = new CommunityVerifBotCronService(
      { isEnabled: true } as unknown as PrismaService,
      { processQueue } as unknown as CommunityVerifBotService,
    );
    await cron.run();
    expect(processQueue).not.toHaveBeenCalled();
  });

  it('la file ne propage jamais une erreur (publication jamais bloquée)', async () => {
    process.env[MODE] = 'review';
    const queue = new CommunityVerifBotQueueService({
      isEnabled: true,
      execute: jest.fn(async () => {
        throw new Error('boom');
      }),
    } as unknown as PrismaService);
    await expect(queue.enqueue('p1')).resolves.toBe(false);
  });
});

describe('Bot Vérif — routes admin (HTTP)', () => {
  let app: INestApplication;
  let base: string;
  const bot = {
    list: jest.fn(async () => ({ mode: 'review', items: [], nextCursor: null })),
    stats: jest.fn(async () => ({ mode: 'review' })),
    detail: jest.fn(async () => ({ draft: { id: 'd1' } })),
    publish: jest.fn(async () => ({ draft: { id: 'd1', status: 'published' }, reply: { id: 'r1' } })),
    reject: jest.fn(async () => ({ id: 'd1', status: 'rejected' })),
    regenerate: jest.fn(async () => ({ id: 'd1', status: 'proposed' })),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [CommunityVerifBotController],
      providers: [Reflector, RolesGuard, { provide: CommunityVerifBotService, useValue: bot }],
    })
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
  });

  beforeEach(() => jest.clearAllMocks());

  function call(method: string, path: string, options: { role?: string; body?: unknown } = {}) {
    return fetch(`${base}${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(options.role ? { 'x-test-role': options.role } : {}),
      },
      ...(options.body !== undefined ? { body: JSON.stringify(options.body) } : {}),
    });
  }

  it('401 sans session ; 403 pour le conseiller et le commercial', async () => {
    expect((await call('GET', '/admin/community/bot/drafts')).status).toBe(401);
    for (const role of ['counselor', 'commercial']) {
      const res = await call('GET', '/admin/community/bot/drafts', { role });
      expect({ role, status: res.status }).toEqual({ role, status: 403 });
    }
    expect(bot.list).not.toHaveBeenCalled();
  });

  it.each(['moderator', 'content_manager', 'admin', 'super_admin'])('rôle R (%s) : lecture et publication, no-store', async (role) => {
    const res = await call('GET', '/admin/community/bot/drafts?status=proposed&limit=10', { role });
    expect(res.status).toBe(200);
    expect(res.headers.get('cache-control')).toBe('private, no-store');
    expect(bot.list).toHaveBeenCalledWith('proposed', undefined, 10);
    const pub = await call('POST', '/admin/community/bot/drafts/d1/publish', { role, body: { text: 'Texte modifié', verified: true } });
    expect(pub.status).toBe(200);
    expect(pub.headers.get('x-request-id')).toBeTruthy();
    expect(bot.publish).toHaveBeenCalledWith('d1', { text: 'Texte modifié', verified: true }, expect.objectContaining({ id: 'adm-1', role }), expect.any(String), 'fr');
  });

  it('défaut : la file des brouillons proposés', async () => {
    await call('GET', '/admin/community/bot/drafts', { role: 'moderator' });
    expect(bot.list).toHaveBeenCalledWith('proposed', undefined, undefined);
  });

  it('validation stricte : statut inconnu, champ inconnu, motif trop court, id illisible', async () => {
    expect((await call('GET', '/admin/community/bot/drafts?status=done', { role: 'admin' })).status).toBe(400);
    expect((await call('POST', '/admin/community/bot/drafts/d1/publish', { role: 'admin', body: { autoVerify: true } })).status).toBe(400);
    expect((await call('POST', '/admin/community/bot/drafts/d1/reject', { role: 'admin', body: { reason: 'no' } })).status).toBe(400);
    expect((await call('POST', '/admin/community/bot/drafts/d%201/regenerate', { role: 'admin' })).status).toBe(400);
  });

  it('rejeter avec motif ; régénérer ; statistiques', async () => {
    const rej = await call('POST', '/admin/community/bot/drafts/d1/reject', { role: 'moderator', body: { reason: 'Faits hors sujet' } });
    expect(rej.status).toBe(200);
    expect(bot.reject).toHaveBeenCalledWith('d1', 'Faits hors sujet', expect.objectContaining({ id: 'adm-1' }), expect.any(String));
    expect((await call('POST', '/admin/community/bot/drafts/d1/regenerate', { role: 'moderator' })).status).toBe(200);
    expect((await call('GET', '/admin/community/bot/stats?days=7', { role: 'moderator' })).status).toBe(200);
    expect(bot.stats).toHaveBeenCalledWith(7);
  });

  it('erreurs du contrat : 409 community_bot_draft_obsolete avec le motif', async () => {
    bot.publish.mockRejectedValueOnce(CommunityErrors.botDraftObsolete('facts_changed'));
    const res = await call('POST', '/admin/community/bot/drafts/d1/publish', { role: 'admin', body: {} });
    expect(res.status).toBe(409);
    expect(await res.json()).toMatchObject({ code: 'community_bot_draft_obsolete', details: { reason: 'facts_changed' } });
  });
});
