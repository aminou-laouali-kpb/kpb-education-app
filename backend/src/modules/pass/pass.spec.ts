import {
  ValidationPipe,
  type ExecutionContext,
  type INestApplication,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';

import { AppModule } from '../../app.module';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import type { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import type { PrismaService } from '../prisma/prisma.service';
import {
  AdminPassController,
  PassWebhookController,
  StudentPassController,
} from './pass.controller';
import { PassWebhookGuard, PASS_WEBHOOK_HEADER } from './pass-webhook.guard';
import { grantState, normalizePaymentReference, PassService } from './pass.service';

const SECRET = 'x'.repeat(40);
const NOW = new Date('2026-11-22T10:00:00Z');
const DAY = 24 * 60 * 60 * 1000;

function contextWith(headers: Record<string, string>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ headers }) }),
  } as unknown as ExecutionContext;
}

describe('PassWebhookGuard', () => {
  const guard = new PassWebhookGuard();
  afterEach(() => {
    delete process.env.KPB_PASS_WEBHOOK_SECRET;
  });

  it('reste fermé (503) tant qu’aucun secret solide n’est configuré', () => {
    process.env.KPB_PASS_WEBHOOK_SECRET = 'court';
    expect(() => guard.canActivate(contextWith({ [PASS_WEBHOOK_HEADER]: 'court' }))).toThrow(
      'Pass webhook is not configured.',
    );
  });

  it('refuse un secret absent ou faux (401)', () => {
    process.env.KPB_PASS_WEBHOOK_SECRET = SECRET;
    expect(() => guard.canActivate(contextWith({}))).toThrow('Invalid webhook secret.');
    expect(() =>
      guard.canActivate(contextWith({ [PASS_WEBHOOK_HEADER]: `${SECRET}y` })),
    ).toThrow('Invalid webhook secret.');
  });

  it('laisse passer le bon secret', () => {
    process.env.KPB_PASS_WEBHOOK_SECRET = SECRET;
    expect(guard.canActivate(contextWith({ [PASS_WEBHOOK_HEADER]: ` ${SECRET} ` }))).toBe(true);
  });
});

describe('règles du Pass', () => {
  it('compare les références sur leurs lettres et chiffres, sans casse', () => {
    for (const typed of ['OM-2611-4455', ' om 2611 4455 ', 'OM.2611/4455']) {
      expect(normalizePaymentReference(typed)).toBe('OM26114455');
    }
  });

  it.each([
    [{ startsAt: new Date(NOW.getTime() + DAY), endsAt: new Date(NOW.getTime() + 2 * DAY), revokedAt: null }, 'upcoming'],
    [{ startsAt: new Date(NOW.getTime() - DAY), endsAt: new Date(NOW.getTime() + DAY), revokedAt: null }, 'active'],
    [{ startsAt: new Date(NOW.getTime() - 2 * DAY), endsAt: new Date(NOW.getTime() - DAY), revokedAt: null }, 'expired'],
    [{ startsAt: new Date(NOW.getTime() - DAY), endsAt: new Date(NOW.getTime() + DAY), revokedAt: NOW }, 'revoked'],
  ])('état %#', (grant, expected) => {
    expect(grantState(grant, NOW)).toBe(expected);
  });
});

describe('PassService.grant', () => {
  const user = {
    id: 'user-1',
    fullName: 'Aïcha K.',
    email: 'aicha@example.org',
    preferredLanguage: 'fr',
    countryOfResidence: 'ner',
  };

  function setup(opts: {
    user?: typeof user | null;
    existing?: Record<string, unknown> | null;
    latestEndsAt?: Date | null;
    dispatchFails?: boolean;
  }) {
    const created: Array<Record<string, unknown>> = [];
    const audits: Array<Record<string, unknown>> = [];
    const client = {
      userProfile: { findFirst: jest.fn(async () => (opts.user === undefined ? user : opts.user)) },
      passGrant: {
        findUnique: jest.fn(async () => opts.existing ?? null),
        findFirst: jest.fn(async () =>
          opts.latestEndsAt ? { endsAt: opts.latestEndsAt } : null,
        ),
        create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
          const row = { id: 'grant-1', createdAt: NOW, revokedAt: null, ...data };
          created.push(row);
          return row;
        }),
        findMany: jest.fn(async () =>
          created.map((row) => ({ startsAt: row.startsAt, endsAt: row.endsAt })),
        ),
      },
      adminAuditEvent: {
        create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
          audits.push(data);
          return data;
        }),
      },
      $transaction: async (fn: (tx: unknown) => unknown) => fn(client),
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: unknown) => unknown) => fn(client),
      tryExecute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    const dispatch = {
      dispatch: jest.fn(async () => {
        if (opts.dispatchFails) throw new Error('push down');
        return 'pushed';
      }),
    };
    const service = new PassService(prisma, dispatch as unknown as NotificationDispatchService);
    return { service, client, created, audits, dispatch };
  }

  const input = {
    email: ' Aicha@Example.org ',
    durationDays: 30,
    paymentReference: 'om-123',
    source: 'webhook' as const,
    grantedBy: 'Moussa (ventes)',
    actorAdminId: null,
    requestId: 'req-1',
  };

  it('ouvre 30 jours, trace l’accès et prévient l’élève', async () => {
    const { service, created, audits, dispatch } = setup({});

    const result = await service.grant(input, NOW);

    expect(created[0]).toMatchObject({
      userId: 'user-1',
      paymentReference: 'OM123',
      startsAt: NOW,
      endsAt: new Date(NOW.getTime() + 30 * DAY),
      source: 'webhook',
      grantedBy: 'Moussa (ventes)',
    });
    expect(audits[0]).toMatchObject({ action: 'pass.granted', entityId: 'grant-1' });
    expect(dispatch.dispatch).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        kind: 'pass_activated',
        dedupeKey: 'pass-activated:grant-1',
      }),
    );
    expect(result).toMatchObject({
      status: 'granted',
      account: { fullName: 'Aïcha K.', email: 'aicha@example.org' },
    });
  });

  it('prolonge un Pass en cours au lieu de le chevaucher', async () => {
    const currentEnd = new Date(NOW.getTime() + 10 * DAY);
    const { service, created } = setup({ latestEndsAt: currentEnd });
    await service.grant(input, NOW);
    expect(created[0]).toMatchObject({
      startsAt: currentEnd,
      endsAt: new Date(currentEnd.getTime() + 30 * DAY),
    });
  });

  it('rejouer le même paiement rend l’accès existant, sans rien créer ni notifier', async () => {
    const existing = {
      id: 'grant-0',
      userId: 'user-1',
      startsAt: NOW,
      endsAt: new Date(NOW.getTime() + 30 * DAY),
    };
    const { service, client, dispatch } = setup({ existing });
    const result = await service.grant(input, NOW);
    expect(result).toMatchObject({ status: 'already_granted', grantId: 'grant-0' });
    expect(client.passGrant.create).not.toHaveBeenCalled();
    expect(dispatch.dispatch).not.toHaveBeenCalled();
  });

  it('refuse une référence déjà utilisée par un autre compte (409)', async () => {
    const { service } = setup({ existing: { id: 'g', userId: 'someone-else' } });
    await expect(service.grant(input, NOW)).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'PAYMENT_REFERENCE_TAKEN' }),
    });
  });

  it('refuse un e-mail sans compte (404 nommé)', async () => {
    const { service } = setup({ user: null });
    await expect(service.grant(input, NOW)).rejects.toMatchObject({
      status: 404,
      response: expect.objectContaining({ code: 'ACCOUNT_NOT_FOUND' }),
    });
  });

  it('garde l’accès même si la notification échoue', async () => {
    const { service } = setup({ dispatchFails: true });
    await expect(service.grant(input, NOW)).resolves.toMatchObject({ status: 'granted' });
  });

  it('sans base, le statut est « pas de Pass », jamais un faux accès', async () => {
    const service = new PassService(
      { isEnabled: false, tryExecute: async () => null } as unknown as PrismaService,
      {} as NotificationDispatchService,
    );
    await expect(service.status('user-1', NOW)).resolves.toEqual({
      active: false,
      activeUntil: null,
    });
  });
});

describe('Pass — périmètre des routes', () => {
  const reflector = new Reflector();

  it('webhook : secret partagé, pas de session', () => {
    expect(Reflect.getMetadata('__guards__', PassWebhookController)).toEqual([PassWebhookGuard]);
  });

  it('élève : session élève', () => {
    expect(Reflect.getMetadata('__guards__', StudentPassController)).toEqual([StudentAuthGuard]);
  });

  it('console : commercial, admin et super admin seulement', () => {
    expect(Reflect.getMetadata('__guards__', AdminPassController)).toEqual([
      AdminAuthGuard,
      RolesGuard,
    ]);
    expect([...reflector.get<InternalRole[]>(ROLES_KEY, AdminPassController)].sort()).toEqual(
      [InternalRole.Admin, InternalRole.Commercial, InternalRole.SuperAdmin].sort(),
    );
  });

  it('est branché dans AppModule', () => {
    const controllers = (Reflect.getMetadata('controllers', AppModule) ?? []) as unknown[];
    const providers = (Reflect.getMetadata('providers', AppModule) ?? []) as unknown[];
    expect(controllers).toEqual(
      expect.arrayContaining([PassWebhookController, StudentPassController, AdminPassController]),
    );
    expect(providers).toEqual(expect.arrayContaining([PassService, PassWebhookGuard]));
  });
});

/** Le webhook en HTTP, avec le pipe global de main.ts et le vrai garde. */
describe('POST /integrations/pass/grant (HTTP)', () => {
  let app: INestApplication;
  let base: string;
  const pass = { grant: jest.fn(async () => ({ status: 'granted' })) };

  beforeAll(async () => {
    process.env.KPB_PASS_WEBHOOK_SECRET = SECRET;
    const moduleRef = await Test.createTestingModule({
      controllers: [PassWebhookController],
      providers: [{ provide: PassService, useValue: pass }, PassWebhookGuard],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(async () => {
    delete process.env.KPB_PASS_WEBHOOK_SECRET;
    await app.close();
  });
  beforeEach(() => jest.clearAllMocks());

  const body = {
    email: 'aicha@example.org',
    durationDays: 30,
    paymentReference: 'OM-2611-4455',
    amountXof: 15000,
    salesAgent: 'Moussa',
  };
  const post = (payload: unknown, secret: string | null = SECRET) =>
    fetch(`${base}/integrations/pass/grant`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(secret ? { [PASS_WEBHOOK_HEADER]: secret } : {}),
      },
      body: JSON.stringify(payload),
    });

  it('accepte un envoi n8n valide (200)', async () => {
    const response = await post(body);
    expect(response.status).toBe(200);
    expect(pass.grant).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'aicha@example.org',
        source: 'webhook',
        grantedBy: 'Moussa',
        actorAdminId: null,
      }),
    );
  });

  it('refuse sans le secret (401)', async () => {
    expect((await post(body, null)).status).toBe(401);
    expect(pass.grant).not.toHaveBeenCalled();
  });

  it.each([
    ['un e-mail invalide', { ...body, email: 'pas-un-email' }],
    ['une durée nulle', { ...body, durationDays: 0 }],
    ['plus de deux ans', { ...body, durationDays: 731 }],
    ['une référence trop courte', { ...body, paymentReference: 'A' }],
    ['sans commercial', { ...body, salesAgent: '' }],
    ['un champ inconnu', { ...body, userId: 'user-1' }],
  ])('refuse %s (400)', async (_label, payload) => {
    expect((await post(payload)).status).toBe(400);
    expect(pass.grant).not.toHaveBeenCalled();
  });
});

describe('/me/pass (HTTP)', () => {
  it('lit le statut de l’élève connecté', async () => {
    const pass = { status: jest.fn(async () => ({ active: true, activeUntil: '2026-12-22' })) };
    const moduleRef = await Test.createTestingModule({
      controllers: [StudentPassController],
      providers: [{ provide: PassService, useValue: pass }],
    })
      .overrideGuard(StudentAuthGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          context.switchToHttp().getRequest().studentUser = { id: 'user-1' };
          return true;
        },
      })
      .compile();
    const app = moduleRef.createNestApplication();
    await app.listen(0, '127.0.0.1');
    const port = (app.getHttpServer().address() as { port: number }).port;
    const response = await fetch(`http://127.0.0.1:${port}/me/pass`);
    await app.close();
    expect(await response.json()).toEqual({ active: true, activeUntil: '2026-12-22' });
    expect(pass.status).toHaveBeenCalledWith('user-1');
  });
});
