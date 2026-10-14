import type { FollowerRow } from './scholarship-follow.query';
import {
  renotifySince,
  summarizeOpeningAudience,
} from './scholarship-opening-audience.service';

function follower(over: Partial<FollowerRow> = {}): FollowerRow {
  return {
    userId: `u-${Math.random().toString(36).slice(2)}`,
    viaFavorite: true,
    viaAlert: false,
    muted: false,
    pushEnabled: true,
    optedOut: false,
    followSince: new Date('2026-09-01T00:00:00Z'),
    alreadyNotified: false,
    recentlyNotified: false,
    followedBeforeAnnouncement: false,
    toNotify: true,
    hasFcmDevice: false,
    preferredLanguage: 'fr',
    countryOfResidence: 'Sénégal',
    ...over,
  };
}

const options = {
  sendAt: new Date('2026-10-15T12:00:00Z'),
  quiet: { startHour: 21, endHour: 8 },
  coalesceMinutes: 30,
  maxOpeningPushesPerDay: 2,
  recentPushes: new Map(),
};

describe('summarizeOpeningAudience', () => {
  it('découpe toNotify et compte chaque exclusion une fois', () => {
    const rows = [
      follower(),
      follower({ viaFavorite: false, viaAlert: true, preferredLanguage: 'en' }),
      follower({ viaAlert: true, hasFcmDevice: true }),
      follower({ muted: true, toNotify: false }),
      follower({ muted: true, alreadyNotified: true, toNotify: false }),
      follower({ alreadyNotified: true, toNotify: false }),
      follower({ recentlyNotified: true, toNotify: false }),
      follower({ followedBeforeAnnouncement: true, toNotify: false }),
      follower({ optedOut: true }),
      follower({ pushEnabled: false }),
    ];
    expect(summarizeOpeningAudience(rows, options)).toEqual({
      followers: 10,
      viaFavoriteOnly: 3,
      viaAlertOnly: 1,
      viaBoth: 1,
      muted: 2,
      alreadyNotifiedThisCycle: 1,
      recentlyNotified: 1,
      toNotify: 5,
      pushEligible: 3,
      optedOut: 1,
      pushDisabled: 1,
      deferredQuietHours: 0,
      deferredPacing: 0,
      byLanguage: { fr: 4, en: 1 },
      devices: { fcm: 1, oneSignalOnly: 2 },
    });
  });

  it('une sourdine seule (sans favori) n’est pas un abonné', () => {
    const summary = summarizeOpeningAudience(
      [follower({ viaFavorite: false, viaAlert: false, muted: true, toNotify: false })],
      options,
    );
    expect(summary.followers).toBe(0);
    expect(summary.muted).toBe(1);
  });

  it('heures calmes puis rythme, évalués à l’instant de l’envoi', () => {
    const paced = follower({ userId: 'paced' });
    const summary = summarizeOpeningAudience(
      [
        follower({ countryOfResidence: 'Chine' }), // 19 h 30 UTC = 3 h 30 à Pékin
        follower({ countryOfResidence: 'Cameroun' }), // 20 h 30 à Douala
        paced,
      ],
      {
        ...options,
        sendAt: new Date('2026-10-15T19:30:00Z'),
        recentPushes: new Map([
          ['paced', [{ pushedAt: new Date('2026-10-15T19:20:00Z'), batchId: 'b' }]],
        ]),
      },
    );
    expect(summary.deferredQuietHours).toBe(1);
    expect(summary.deferredPacing).toBe(1);
    expect(summary.pushEligible).toBe(3);
  });

  it('envoi immédiat (legacy) : aucun report compté, mêmes destinataires', () => {
    const rows = [
      follower({ countryOfResidence: 'Chine' }), // 3 h 30 à Pékin
      follower({ userId: 'paced' }),
      follower({ optedOut: true }),
      follower({ recentlyNotified: true, toNotify: false }),
    ];
    const at = {
      ...options,
      sendAt: new Date('2026-10-15T19:30:00Z'),
      recentPushes: new Map([
        ['paced', [{ pushedAt: new Date('2026-10-15T19:20:00Z'), batchId: 'b' }]],
      ]),
    };
    const scheduled = summarizeOpeningAudience(rows, at);
    const immediate = summarizeOpeningAudience(rows, { ...at, immediate: true });
    expect(scheduled).toMatchObject({ deferredQuietHours: 1, deferredPacing: 1 });
    expect(immediate).toEqual({ ...scheduled, deferredQuietHours: 0, deferredPacing: 0 });
    expect(immediate).toMatchObject({
      toNotify: 3,
      recentlyNotified: 1,
      optedOut: 1,
      pushEligible: 2,
    });
  });

  it('renotifySince : N jours avant', () => {
    expect(renotifySince(new Date('2026-10-31T00:00:00Z'), 30).toISOString()).toBe(
      '2026-10-01T00:00:00.000Z',
    );
  });
});
