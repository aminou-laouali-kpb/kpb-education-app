import type { FcmSendResult, FcmSenderService } from './fcm-sender.service';
import type {
  OneSignalDetailedResult,
  OneSignalSenderService,
} from './onesignal-sender.service';
import { PushSenderService } from './push-sender.service';

function makeRouter(opts: {
  fcmConfigured?: boolean;
  fcmResult?: FcmSendResult;
  oneSignalConfigured?: boolean;
  oneSignalResult?: boolean;
  oneSignalDetailed?: OneSignalDetailedResult;
}) {
  const fcm = {
    isConfigured: opts.fcmConfigured ?? true,
    sendToUser: jest.fn(async () => opts.fcmResult ?? 'delivered'),
  };
  const oneSignal = {
    isConfigured: opts.oneSignalConfigured ?? true,
    sendToUser: jest.fn(async () => opts.oneSignalResult ?? true),
    sendToUserDetailed: jest.fn(
      async (): Promise<OneSignalDetailedResult> =>
        opts.oneSignalDetailed ?? { status: 'accepted', reason: null },
    ),
  };
  const router = new PushSenderService(
    fcm as unknown as FcmSenderService,
    oneSignal as unknown as OneSignalSenderService,
  );
  return { router, fcm, oneSignal };
}

describe('PushSenderService (transition OneSignal → FCM)', () => {
  it('passe par FCM quand l’élève a un appareil enregistré', async () => {
    const { router, oneSignal } = makeRouter({ fcmResult: 'delivered' });
    await expect(router.send('u1', 't', 'b')).resolves.toEqual({
      delivered: true,
      via: 'fcm',
    });
    expect(oneSignal.sendToUser).not.toHaveBeenCalled();
  });

  // Ancienne version de l'application : pas de jeton FCM, encore abonnée chez
  // OneSignal. Elle doit continuer à recevoir pendant la transition.
  it('se rabat sur OneSignal quand l’élève n’a aucun jeton FCM', async () => {
    const { router, oneSignal } = makeRouter({ fcmResult: 'no_device' });
    await expect(
      router.send('u1', 't', 'b', { route: '/deadlines' }),
    ).resolves.toEqual({ delivered: true, via: 'onesignal' });
    expect(oneSignal.sendToUser).toHaveBeenCalledWith('u1', 't', 'b', {
      route: '/deadlines',
    });
  });

  // L'élève a la nouvelle version (donc plus le SDK OneSignal) : un abonnement
  // OneSignal résiduel pourrait être compté « livré » sans rien afficher.
  it('ne se rabat PAS sur OneSignal quand FCM échoue avec des jetons', async () => {
    const { router, oneSignal } = makeRouter({ fcmResult: 'failed' });
    await expect(router.send('u1', 't', 'b')).resolves.toEqual({
      delivered: false,
      via: 'fcm',
    });
    expect(oneSignal.sendToUser).not.toHaveBeenCalled();
  });

  it('utilise OneSignal seul tant que FCM n’est pas configuré', async () => {
    const { router, fcm } = makeRouter({
      fcmConfigured: false,
      oneSignalResult: true,
    });
    await expect(router.sendToUser('u1', 't', 'b')).resolves.toBe(true);
    expect(fcm.sendToUser).not.toHaveBeenCalled();
  });

  it('fonctionne en FCM seul une fois OneSignal retiré', async () => {
    const { router } = makeRouter({
      fcmResult: 'no_device',
      oneSignalConfigured: false,
    });
    await expect(router.send('u1', 't', 'b')).resolves.toEqual({
      delivered: false,
      via: 'fcm',
    });
    expect(router.isConfigured).toBe(true);
    expect(router.providers).toEqual({ fcm: true, oneSignal: false });
  });

  it('ne fait rien sans fournisseur, ni sans destinataire', async () => {
    const { router } = makeRouter({
      fcmConfigured: false,
      oneSignalConfigured: false,
    });
    expect(router.isConfigured).toBe(false);
    await expect(router.send('u1', 't', 'b')).resolves.toEqual({
      delivered: false,
      via: null,
    });
    await expect(makeRouter({}).router.sendToUser('', 't', 'b')).resolves.toBe(
      false,
    );
  });
});

/**
 * `sendWithStatus` : le même routage, un état par destinataire, pour la boîte
 * d'envoi des annonces d'ouverture. `send()` et `sendToUser()` sont gardés à
 * l'identique pour leurs sept appelants (tests ci-dessus inchangés).
 */
describe('PushSenderService.sendWithStatus', () => {
  const data = { route: '/scholarships/s1' };

  it('accepted via FCM, avec la clé de regroupement', async () => {
    const { router, fcm, oneSignal } = makeRouter({ fcmResult: 'delivered' });
    await expect(
      router.sendWithStatus('u1', 't', 'b', data, {
        collapseKey: 'kpb-abc',
        idempotencyKey: 'k',
      }),
    ).resolves.toEqual({ status: 'accepted', via: 'fcm', reason: null });
    expect(fcm.sendToUser).toHaveBeenCalledWith('u1', 't', 'b', data, {
      collapseKey: 'kpb-abc',
    });
    expect(oneSignal.sendToUserDetailed).not.toHaveBeenCalled();
  });

  // Règle de l'en-tête : un élève passé à la build FCM n'a plus le SDK
  // OneSignal ; un abonnement résiduel serait compté « accepté » sans rien
  // afficher. L'échec est retenté par la boîte d'envoi, borné.
  it('FCM failed → transient_error, SANS repli OneSignal', async () => {
    const { router, oneSignal } = makeRouter({ fcmResult: 'failed' });
    await expect(router.sendWithStatus('u1', 't', 'b', data)).resolves.toEqual(
      { status: 'transient_error', via: 'fcm', reason: 'fcm_failed' },
    );
    expect(oneSignal.sendToUserDetailed).not.toHaveBeenCalled();
    expect(oneSignal.sendToUser).not.toHaveBeenCalled();
  });

  it.each<[FcmSendResult]>([['no_device'], ['unconfigured']])(
    'FCM %s → OneSignal, dont l’état passe tel quel',
    async (fcmResult) => {
      const { router, oneSignal } = makeRouter({
        fcmResult,
        oneSignalDetailed: { status: 'no_device', reason: 'invalid_aliases' },
      });
      await expect(
        router.sendWithStatus('u1', 't', 'b', data, {
          collapseKey: 'kpb-abc',
          idempotencyKey: 'scholarship-opened:c1:u1',
        }),
      ).resolves.toEqual({
        status: 'no_device',
        via: 'onesignal',
        reason: 'invalid_aliases',
      });
      expect(oneSignal.sendToUserDetailed).toHaveBeenCalledWith(
        'u1',
        't',
        'b',
        data,
        { idempotencyKey: 'scholarship-opened:c1:u1', collapseKey: 'kpb-abc' },
      );
      // Le chemin bavard (une ligne de journal par élève) n'est jamais pris.
      expect(oneSignal.sendToUser).not.toHaveBeenCalled();
    },
  );

  it.each<[OneSignalDetailedResult['status']]>([
    ['accepted'],
    ['transient_error'],
    ['permanent_error'],
  ])('OneSignal seul : %s passe tel quel', async (status) => {
    const { router, fcm } = makeRouter({
      fcmConfigured: false,
      oneSignalDetailed: { status, reason: null },
    });
    await expect(router.sendWithStatus('u1', 't', 'b', data)).resolves.toEqual(
      { status, via: 'onesignal', reason: null },
    );
    expect(fcm.sendToUser).not.toHaveBeenCalled();
  });

  it('FCM seul et aucun jeton → no_device via fcm', async () => {
    const { router } = makeRouter({
      fcmResult: 'no_device',
      oneSignalConfigured: false,
    });
    await expect(router.sendWithStatus('u1', 't', 'b', data)).resolves.toEqual(
      { status: 'no_device', via: 'fcm', reason: 'fcm_no_device' },
    );
  });

  it('aucun fournisseur → unconfigured ; sans destinataire → permanent_error', async () => {
    const { router } = makeRouter({
      fcmConfigured: false,
      oneSignalConfigured: false,
    });
    await expect(router.sendWithStatus('u1', 't', 'b', data)).resolves.toEqual(
      { status: 'unconfigured', via: null, reason: null },
    );
    const { router: other } = makeRouter({});
    await expect(other.sendWithStatus('', 't', 'b', data)).resolves.toEqual({
      status: 'permanent_error',
      via: null,
      reason: 'no_user',
    });
  });
});
