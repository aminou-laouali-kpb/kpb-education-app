import { generateKeyPairSync } from 'crypto';
import { Logger } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import {
  FcmSenderService,
  isDeadTokenError,
  parseServiceAccount,
} from './fcm-sender.service';

const { privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});

const ACCOUNT = {
  project_id: 'kpb-test',
  client_email: 'push@kpb-test.iam.gserviceaccount.com',
  private_key: privateKey,
};

function makePrisma(tokens: string[]) {
  const deleteMany = jest.fn(async () => ({ count: 0 }));
  const prisma = {
    execute: jest.fn(async (op: (p: unknown) => Promise<unknown>) =>
      op({
        deviceToken: {
          findMany: jest.fn(async () => tokens.map((token) => ({ token }))),
          deleteMany,
        },
      }),
    ),
  } as unknown as PrismaService;
  return { prisma, deleteMany };
}

const jsonResponse = (body: unknown, ok = true, status = 200) =>
  ({
    ok,
    status,
    json: async () => body,
    text: async () => JSON.stringify(body),
  }) as unknown as Response;

const TOKEN_RESPONSE = jsonResponse({ access_token: 'ya29.test', expires_in: 3600 });

/** Répond au jeton OAuth, puis à chaque envoi selon `sends` (dans l'ordre). */
function mockFetch(sends: Array<() => Response>) {
  let i = 0;
  global.fetch = jest.fn(async (url: string) => {
    if (String(url).startsWith('https://oauth2.googleapis.com/')) {
      return TOKEN_RESPONSE;
    }
    const next = sends[Math.min(i, sends.length - 1)];
    i += 1;
    return next();
  }) as unknown as typeof fetch;
}

const unregistered = () =>
  jsonResponse(
    {
      error: {
        code: 404,
        status: 'NOT_FOUND',
        message: 'Requested entity was not found.',
        details: [
          {
            '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
            errorCode: 'UNREGISTERED',
          },
        ],
      },
    },
    false,
    404,
  );

describe('FcmSenderService', () => {
  const previous = process.env.FCM_SERVICE_ACCOUNT_JSON;
  let errors: string[] = [];

  beforeEach(() => {
    process.env.FCM_SERVICE_ACCOUNT_JSON = JSON.stringify(ACCOUNT);
    errors = [];
    jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation((m: unknown) => void errors.push(String(m)));
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
  });

  afterEach(() => {
    if (previous === undefined) delete process.env.FCM_SERVICE_ACCOUNT_JSON;
    else process.env.FCM_SERVICE_ACCOUNT_JSON = previous;
    jest.restoreAllMocks();
  });

  it('accepte le compte de service en JSON brut ou en base64', () => {
    const raw = JSON.stringify(ACCOUNT);
    expect(parseServiceAccount(raw)?.projectId).toBe('kpb-test');
    expect(
      parseServiceAccount(Buffer.from(raw).toString('base64'))?.clientEmail,
    ).toBe(ACCOUNT.client_email);
    expect(parseServiceAccount('')).toBeNull();
    expect(parseServiceAccount('{"project_id":"x"}')).toBeNull();
    expect(parseServiceAccount('pas du json')).toBeNull();
  });

  it('livre à chaque appareil de l’élève, avec le canal Android de l’app', async () => {
    const { prisma } = makePrisma(['tok-a', 'tok-b']);
    mockFetch([() => jsonResponse({ name: 'm1' })]);

    await expect(
      new FcmSenderService(prisma).sendToUser('u1', 'Titre', 'Corps', {
        route: '/deadlines',
      }),
    ).resolves.toBe('delivered');

    const sends = (global.fetch as jest.Mock).mock.calls.filter(([url]) =>
      String(url).includes('/messages:send'),
    );
    expect(sends).toHaveLength(2);
    expect(String(sends[0][0])).toContain('/projects/kpb-test/');
    const message = JSON.parse(sends[0][1].body).message;
    expect(message.notification).toEqual({ title: 'Titre', body: 'Corps' });
    expect(message.data).toEqual({ route: '/deadlines' });
    expect(message.android.notification.channel_id).toBe('kpb_default');
    expect(sends[0][1].headers.authorization).toBe('Bearer ya29.test');
  });

  it('rend no_device sans jeton, sans appeler Google', async () => {
    const { prisma } = makePrisma([]);
    mockFetch([() => jsonResponse({})]);
    await expect(
      new FcmSenderService(prisma).sendToUser('u1', 't', 'b'),
    ).resolves.toBe('no_device');
    expect(global.fetch).not.toHaveBeenCalled();
  });

  // Un jeton révoqué (application désinstallée) doit disparaître, sinon chaque
  // envoi futur repaie le même refus.
  it('supprime les jetons révoqués et livre aux autres', async () => {
    const { prisma, deleteMany } = makePrisma(['dead', 'alive']);
    mockFetch([unregistered, () => jsonResponse({ name: 'm1' })]);

    await expect(
      new FcmSenderService(prisma).sendToUser('u1', 't', 'b'),
    ).resolves.toBe('delivered');
    expect(deleteMany).toHaveBeenCalledWith({
      where: { token: { in: ['dead'] } },
    });
  });

  it('rend no_device quand tous les jetons étaient révoqués', async () => {
    const { prisma } = makePrisma(['dead']);
    mockFetch([unregistered]);
    await expect(
      new FcmSenderService(prisma).sendToUser('u1', 't', 'b'),
    ).resolves.toBe('no_device');
  });

  it('rend failed et journalise le motif quand FCM refuse', async () => {
    const { prisma, deleteMany } = makePrisma(['tok']);
    mockFetch([
      () =>
        jsonResponse(
          { error: { code: 403, message: 'APNs auth key missing' } },
          false,
          403,
        ),
    ]);
    await expect(
      new FcmSenderService(prisma).sendToUser('u1', 't', 'b'),
    ).resolves.toBe('failed');
    expect(deleteMany).not.toHaveBeenCalled();
    expect(errors.join(' ')).toContain('APNs auth key missing');
  });

  it('rend failed sans jeton d’accès Google, et ne journalise pas la clé', async () => {
    const { prisma } = makePrisma(['tok']);
    global.fetch = jest.fn(async () =>
      jsonResponse({ error: 'invalid_grant' }, false, 400),
    ) as unknown as typeof fetch;
    await expect(
      new FcmSenderService(prisma).sendToUser('u1', 't', 'b'),
    ).resolves.toBe('failed');
    expect(errors.join(' ')).toContain('invalid_grant');
    expect(errors.join(' ')).not.toContain('PRIVATE KEY');
  });

  it('ne tente rien sans compte de service', async () => {
    delete process.env.FCM_SERVICE_ACCOUNT_JSON;
    const { prisma } = makePrisma(['tok']);
    mockFetch([() => jsonResponse({})]);
    const sender = new FcmSenderService(prisma);
    expect(sender.isConfigured).toBe(false);
    await expect(sender.sendToUser('u1', 't', 'b')).resolves.toBe(
      'unconfigured',
    );
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('garde le jeton d’accès en cache entre deux envois', async () => {
    const { prisma } = makePrisma(['tok']);
    mockFetch([() => jsonResponse({ name: 'm1' })]);
    const sender = new FcmSenderService(prisma);
    await sender.sendToUser('u1', 't', 'b');
    await sender.sendToUser('u1', 't', 'b');
    const oauthCalls = (global.fetch as jest.Mock).mock.calls.filter(([url]) =>
      String(url).startsWith('https://oauth2.googleapis.com/'),
    );
    expect(oauthCalls).toHaveLength(1);
  });

  // Un renvoi après un crash (bail perdu entre l'acceptation et l'écriture
  // de l'état) doit remplacer la notification affichée, pas s'empiler.
  it('pose tag et apns-collapse-id quand une clé de regroupement est donnée', async () => {
    const { prisma } = makePrisma(['tok']);
    mockFetch([() => jsonResponse({ name: 'm1' })]);
    await new FcmSenderService(prisma).sendToUser('u1', 't', 'b', {}, {
      collapseKey: 'kpb-0123456789abcdef',
    });
    const send = (global.fetch as jest.Mock).mock.calls.find(([url]) =>
      String(url).includes('/messages:send'),
    );
    const message = JSON.parse(send[1].body).message;
    expect(message.android.notification).toEqual({
      channel_id: 'kpb_default',
      tag: 'kpb-0123456789abcdef',
    });
    expect(message.apns).toEqual({
      headers: { 'apns-collapse-id': 'kpb-0123456789abcdef' },
      payload: { aps: { sound: 'default' } },
    });
  });

  it('garde la charge d’avant sans clé de regroupement', async () => {
    const { prisma } = makePrisma(['tok']);
    mockFetch([() => jsonResponse({ name: 'm1' })]);
    await new FcmSenderService(prisma).sendToUser('u1', 't', 'b', { a: '1' });
    const send = (global.fetch as jest.Mock).mock.calls.find(([url]) =>
      String(url).includes('/messages:send'),
    );
    expect(JSON.parse(send[1].body).message).toEqual({
      token: 'tok',
      notification: { title: 't', body: 'b' },
      data: { a: '1' },
      android: { priority: 'HIGH', notification: { channel_id: 'kpb_default' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  });

  // La boîte d'envoi lance 8 envois en parallèle : un cache vide ne doit
  // demander qu'un seul jeton à Google.
  it('8 envois simultanés, cache vide : un seul échange OAuth', async () => {
    const { prisma } = makePrisma(['tok']);
    let release: () => void = () => undefined;
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    global.fetch = jest.fn(async (url: string) => {
      if (String(url).startsWith('https://oauth2.googleapis.com/')) {
        await gate;
        return TOKEN_RESPONSE;
      }
      return jsonResponse({ name: 'm1' });
    }) as unknown as typeof fetch;
    const sender = new FcmSenderService(prisma);
    const sends = Array.from({ length: 8 }, (_, i) =>
      sender.sendToUser(`u${i}`, 't', 'b'),
    );
    await new Promise((resolve) => setImmediate(resolve));
    release();
    await expect(Promise.all(sends)).resolves.toEqual(
      Array(8).fill('delivered'),
    );
    const oauthCalls = (global.fetch as jest.Mock).mock.calls.filter(([url]) =>
      String(url).startsWith('https://oauth2.googleapis.com/'),
    );
    expect(oauthCalls).toHaveLength(1);
  });

  /**
   * La boîte d'envoi des annonces : à 5 000 abonnés, `sendToUser` écrirait une
   * ligne par jeton révoqué (avec l'identifiant de l'élève) et une par refus.
   * La variante détaillée rend un état et un motif bornés, et n'écrit RIEN.
   */
  describe('sendToUserDetailed (boîte d’envoi) : aucune ligne par élève', () => {
    let lines: string[];

    beforeEach(() => {
      lines = [];
      const capture = (...args: unknown[]) => void lines.push(String(args[0]));
      for (const level of ['log', 'warn', 'error', 'debug', 'verbose'] as const) {
        jest.spyOn(Logger.prototype, level).mockImplementation(capture);
      }
    });

    const sendsInOrder = (outcomes: Array<() => Response>) => {
      let i = 0;
      global.fetch = jest.fn(async (url: string) => {
        if (String(url).startsWith('https://oauth2.googleapis.com/')) {
          return TOKEN_RESPONSE;
        }
        const next = outcomes[i];
        i += 1;
        return next();
      }) as unknown as typeof fetch;
    };

    it('jeton révoqué, refus 503 et coupure réseau : état, motif, ménage des jetons, aucune ligne', async () => {
      const { prisma, deleteMany } = makePrisma(['dead', 'busy', 'cut']);
      sendsInOrder([
        unregistered,
        () => jsonResponse({ error: { code: 503, message: 'unavailable' } }, false, 503),
        () => {
          throw Object.assign(new Error('socket hang up'), { name: 'TypeError' });
        },
      ]);
      await expect(
        new FcmSenderService(prisma).sendToUserDetailed('u-secret', 't', 'b', {}, {
          collapseKey: 'kpb-x',
        }),
      ).resolves.toEqual({ result: 'failed', reason: 'http_5xx' });
      expect(deleteMany).toHaveBeenCalledWith({ where: { token: { in: ['dead'] } } });
      expect(lines).toEqual([]);
    });

    it.each([
      ['429', () => jsonResponse({}, false, 429), 'http_429'],
      ['403', () => jsonResponse({ error: { message: 'APNs' } }, false, 403), 'http_4xx'],
      [
        'délai',
        () => {
          throw Object.assign(new Error('aborted'), { name: 'AbortError' });
        },
        'abort',
      ],
    ] as const)('refus %s → failed/%s, aucune ligne', async (_label, outcome, reason) => {
      const { prisma } = makePrisma(['tok']);
      sendsInOrder([outcome]);
      await expect(
        new FcmSenderService(prisma).sendToUserDetailed('u1', 't', 'b', {}),
      ).resolves.toEqual({ result: 'failed', reason });
      expect(lines).toEqual([]);
    });

    it('tous les jetons révoqués → no_device/tokens_revoked ; livré → delivered', async () => {
      const { prisma } = makePrisma(['dead']);
      sendsInOrder([unregistered]);
      await expect(
        new FcmSenderService(prisma).sendToUserDetailed('u1', 't', 'b', {}),
      ).resolves.toEqual({ result: 'no_device', reason: 'tokens_revoked' });

      const ok = makePrisma(['tok']);
      sendsInOrder([() => jsonResponse({ name: 'm1' })]);
      await expect(
        new FcmSenderService(ok.prisma).sendToUserDetailed('u1', 't', 'b', {}),
      ).resolves.toEqual({ result: 'delivered', reason: null });
      expect(lines).toEqual([]);
    });

    it('sendToUser garde ses lignes d’avant (autres appelants)', async () => {
      const { prisma } = makePrisma(['dead', 'busy']);
      sendsInOrder([
        unregistered,
        () => jsonResponse({ error: { code: 503, message: 'unavailable' } }, false, 503),
      ]);
      await expect(
        new FcmSenderService(prisma).sendToUser('u1', 't', 'b'),
      ).resolves.toBe('failed');
      expect(lines).toContain('FCM: 1 jeton(s) révoqué(s) supprimé(s) pour u1.');
      expect(lines.join(' ')).toContain('FCM send failed with status 503');
    });
  });

  describe('isDeadTokenError', () => {
    it('reconnaît UNREGISTERED et SENDER_ID_MISMATCH', async () => {
      expect(isDeadTokenError(404, await unregistered().json())).toBe(true);
      expect(
        isDeadTokenError(403, {
          error: { details: [{ errorCode: 'SENDER_ID_MISMATCH' }] },
        }),
      ).toBe(true);
    });

    // INVALID_ARGUMENT couvre aussi une charge mal formée : ce n'est pas une
    // raison de jeter un jeton valide.
    it('ne supprime pas un jeton pour une charge invalide', () => {
      expect(
        isDeadTokenError(400, {
          error: {
            message: 'Invalid value at message.data',
            details: [{ errorCode: 'INVALID_ARGUMENT' }],
          },
        }),
      ).toBe(false);
      expect(
        isDeadTokenError(400, {
          error: {
            message: 'The registration token is not a valid FCM registration token',
            details: [{ errorCode: 'INVALID_ARGUMENT' }],
          },
        }),
      ).toBe(true);
    });
  });
});
