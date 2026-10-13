import type { FcmSendResult, FcmSenderService } from './fcm-sender.service';
import type { OneSignalSenderService } from './onesignal-sender.service';
import { PushSenderService } from './push-sender.service';

function makeRouter(opts: {
  fcmConfigured?: boolean;
  fcmResult?: FcmSendResult;
  oneSignalConfigured?: boolean;
  oneSignalResult?: boolean;
}) {
  const fcm = {
    isConfigured: opts.fcmConfigured ?? true,
    sendToUser: jest.fn(async () => opts.fcmResult ?? 'delivered'),
  };
  const oneSignal = {
    isConfigured: opts.oneSignalConfigured ?? true,
    sendToUser: jest.fn(async () => opts.oneSignalResult ?? true),
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
