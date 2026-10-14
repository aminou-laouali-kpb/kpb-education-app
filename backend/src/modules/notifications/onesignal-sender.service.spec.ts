import { Logger } from '@nestjs/common';

import {
  idempotencyUuid,
  OneSignalSenderService,
} from './onesignal-sender.service';

/**
 * Le seul code qui parle à OneSignal, et il n'avait aucun test — alors qu'il
 * décide, pour chaque destinataire, si la livraison est inscrite « delivered »
 * ou « failed ». Les six autres services du même dossier en avaient un.
 */
describe('OneSignalSenderService', () => {
  const previous = {
    id: process.env.ONESIGNAL_APP_ID,
    key: process.env.ONESIGNAL_REST_API_KEY,
  };
  let errors: string[] = [];
  let warns: string[] = [];

  beforeEach(() => {
    process.env.ONESIGNAL_APP_ID = 'app-id';
    process.env.ONESIGNAL_REST_API_KEY = 'rest-key';
    errors = [];
    warns = [];
    jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation((m: unknown) => void errors.push(String(m)));
    jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation((m: unknown) => void warns.push(String(m)));
  });

  afterEach(() => {
    for (const [k, v] of [
      ['ONESIGNAL_APP_ID', previous.id],
      ['ONESIGNAL_REST_API_KEY', previous.key],
    ] as const) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    jest.restoreAllMocks();
  });

  function mockFetch(impl: () => Promise<unknown>) {
    global.fetch = jest.fn(impl) as unknown as typeof fetch;
  }

  const jsonResponse = (body: unknown, ok = true, status = 200) =>
    ({
      ok,
      status,
      json: async () => body,
      text: async () => JSON.stringify(body),
    }) as unknown as Response;

  it('rend true et n’alerte pas quand OneSignal livre', async () => {
    mockFetch(async () => jsonResponse({ id: 'n1', recipients: 3 }));
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(true);
    expect(errors).toEqual([]);
  });

  // Le défaut central : la charge `errors` était désérialisée puis JETÉE. Le
  // 04/09/2026 la production n'a su dire que « provider errors », ce qui rendait
  // la cause indiagnosticable depuis les journaux.
  it('journalise la charge d’erreur d’OneSignal, pas une phrase fixe', async () => {
    mockFetch(async () =>
      jsonResponse({ errors: ['App has no delivery platform configured'] }),
    );
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(errors.join(' ')).toContain('no delivery platform configured');
  });

  it('journalise le corps quand OneSignal répond en erreur HTTP', async () => {
    mockFetch(async () =>
      jsonResponse({ errors: ['Invalid app_id format'] }, false, 400),
    );
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    const joined = errors.join(' ');
    expect(joined).toContain('400');
    expect(joined).toContain('Invalid app_id format');
  });

  // « Zéro destinataire » était compté comme un SUCCÈS : l'appelant inscrivait
  // alors la livraison comme `delivered`, et les statistiques décrivaient une
  // distribution qui n'avait pas eu lieu.
  it('ne compte pas « 0 destinataire » comme une livraison', async () => {
    mockFetch(async () => jsonResponse({ id: 'n1', recipients: 0 }));
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(warns.join(' ')).toContain('0 device');
  });

  it('nomme le motif quand la requête elle-même échoue', async () => {
    mockFetch(async () => {
      const e = new Error('The operation was aborted');
      e.name = 'AbortError';
      throw e;
    });
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(errors.join(' ')).toContain('AbortError');
  });

  it('ne tente rien sans identifiants, et le dit', async () => {
    delete process.env.ONESIGNAL_APP_ID;
    mockFetch(async () => jsonResponse({ recipients: 1 }));
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(global.fetch).not.toHaveBeenCalled();
    expect(warns.join(' ')).toContain('not configured');
  });

  // La clé REST ne doit jamais atterrir dans un journal : elle ne circule que
  // dans l'en-tête `authorization`.
  it('ne journalise jamais la clé REST', async () => {
    process.env.ONESIGNAL_REST_API_KEY = 'os_v2_supersecret';
    mockFetch(async () => jsonResponse({ errors: ['boom'] }, false, 500));
    await new OneSignalSenderService().sendToUser('u1', 't', 'b');
    expect([...errors, ...warns].join(' ')).not.toContain('os_v2_supersecret');
  });

  /**
   * `sendToUserDetailed` : le chemin de la boîte d'envoi. Les réponses sont
   * celles que l'API REST v1 renvoie pour un envoi par `include_aliases`
   * (formes relevées dans la documentation OneSignal, à recaler sur une
   * réponse réelle en recette — risque 2 du plan).
   */
  describe('sendToUserDetailed', () => {
    const FIXTURES = {
      accepted: { id: 'b98881cc-1e94-4366-bbd9-db8f3429292b', recipients: 1 },
      invalidAliases: {
        id: '',
        errors: { invalid_aliases: { external_id: ['u1'] } },
      },
      notSubscribed: {
        id: '',
        errors: ['All included players are not subscribed'],
      },
      zeroRecipients: { id: 'b98881cc', recipients: 0 },
      otherErrors: { errors: ['Message Notifications must have English language content'] },
      badRequest: { errors: ['Invalid app_id format'] },
      rateLimited: { errors: ['API rate limit exceeded'] },
      unavailable: { errors: ['Service Unavailable'] },
    } as const;

    const send = () =>
      new OneSignalSenderService().sendToUserDetailed('u1', 't', 'b', {
        route: '/scholarships/s1',
      });

    it.each([
      ['accepted', jsonResponse(FIXTURES.accepted), 'accepted', null],
      ['invalid_aliases', jsonResponse(FIXTURES.invalidAliases), 'no_device', 'invalid_aliases'],
      ['« not subscribed »', jsonResponse(FIXTURES.notSubscribed), 'no_device', 'not_subscribed'],
      ['recipients: 0', jsonResponse(FIXTURES.zeroRecipients), 'no_device', 'zero_recipients'],
      ['autres erreurs', jsonResponse(FIXTURES.otherErrors), 'permanent_error', 'provider_errors'],
      ['HTTP 400', jsonResponse(FIXTURES.badRequest, false, 400), 'permanent_error', 'http_4xx'],
      ['HTTP 429', jsonResponse(FIXTURES.rateLimited, false, 429), 'transient_error', 'http_429'],
      ['HTTP 503', jsonResponse(FIXTURES.unavailable, false, 503), 'transient_error', 'http_5xx'],
    ] as const)('%s → %s', async (_label, response, status, reason) => {
      mockFetch(async () => response);
      await expect(send()).resolves.toEqual({ status, reason });
    });

    it.each([
      ['AbortError', 'abort'],
      ['TypeError', 'network'],
    ] as const)('%s levée → transient_error/%s', async (name, reason) => {
      mockFetch(async () => {
        const e = new Error('boom');
        e.name = name;
        throw e;
      });
      await expect(send()).resolves.toEqual({
        status: 'transient_error',
        reason,
      });
    });

    it('sans identifiants → unconfigured, sans appel', async () => {
      delete process.env.ONESIGNAL_REST_API_KEY;
      mockFetch(async () => jsonResponse(FIXTURES.accepted));
      await expect(send()).resolves.toEqual({
        status: 'unconfigured',
        reason: null,
      });
      expect(global.fetch).not.toHaveBeenCalled();
    });

    // À 5 000 abonnés d'anciennes builds, une ligne « … for user <id> » par
    // élève sans abonnement noierait le journal d'identifiants.
    it('n’écrit AUCUNE ligne de journal, quelle que soit la réponse', async () => {
      for (const response of [
        jsonResponse(FIXTURES.zeroRecipients),
        jsonResponse(FIXTURES.invalidAliases),
        jsonResponse(FIXTURES.otherErrors),
        jsonResponse(FIXTURES.unavailable, false, 503),
      ]) {
        mockFetch(async () => response);
        await send();
      }
      delete process.env.ONESIGNAL_APP_ID;
      await send();
      expect([...errors, ...warns]).toEqual([]);
    });

    it('porte idempotency_key (UUID) et collapse_id quand on les donne', async () => {
      mockFetch(async () => jsonResponse(FIXTURES.accepted));
      await new OneSignalSenderService().sendToUserDetailed(
        'u1',
        't',
        'b',
        {},
        { idempotencyKey: 'scholarship-opened:c1:u1', collapseKey: 'kpb-1234' },
      );
      const init = (global.fetch as jest.Mock).mock.calls[0][1] as RequestInit;
      const body = JSON.parse(String(init.body)) as Record<string, unknown>;
      expect(body.idempotency_key).toBe(
        idempotencyUuid('scholarship-opened:c1:u1'),
      );
      expect(body.collapse_id).toBe('kpb-1234');
    });

    it('idempotencyUuid : UUID v4 valide, stable, distinct par clé', () => {
      const uuid = idempotencyUuid('scholarship-opened:c1:u1');
      expect(uuid).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
      );
      expect(idempotencyUuid('scholarship-opened:c1:u1')).toBe(uuid);
      expect(idempotencyUuid('scholarship-opened:c1:u2')).not.toBe(uuid);
    });
  });

  // `sendToUser` garde son corps et ses lignes d'avant, mot pour mot.
  it('sendToUser : corps inchangé, sans clé d’idempotence ni collapse_id', async () => {
    mockFetch(async () => jsonResponse({ id: 'n1', recipients: 1 }));
    await new OneSignalSenderService().sendToUser('u1', 't', 'b', { a: '1' });
    const init = (global.fetch as jest.Mock).mock.calls[0][1] as RequestInit;
    expect(JSON.parse(String(init.body))).toEqual({
      app_id: 'app-id',
      target_channel: 'push',
      include_aliases: { external_id: ['u1'] },
      headings: { en: 't', fr: 't' },
      contents: { en: 'b', fr: 'b' },
      data: { a: '1' },
    });
  });

  it('sendToUser : la ligne « 0 device » nomme toujours l’utilisateur', async () => {
    mockFetch(async () => jsonResponse({ id: 'n1', recipients: 0 }));
    await new OneSignalSenderService().sendToUser('u42', 't', 'b');
    expect(warns).toEqual([
      'OneSignal accepted the request but delivered to 0 device for user u42 ' +
        '(no subscribed device, or no delivery platform configured on the OneSignal app).',
    ]);
  });
});
