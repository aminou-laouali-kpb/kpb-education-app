import {
  buildOpeningReportCounts,
  type OpeningReportGroup,
} from './scholarship-opening-admin.service';

const group = (over: Partial<OpeningReportGroup>): OpeningReportGroup => ({
  pushStatus: 'accepted',
  pushLastError: null,
  pushProvider: null,
  future: false,
  n: 1,
  read: 0,
  ...over,
});

describe('buildOpeningReportCounts', () => {
  it('répartit les lignes par état, raison et fournisseur', () => {
    const report = buildOpeningReportCounts(
      [
        group({ pushStatus: 'accepted', pushProvider: 'fcm', n: 12, read: 5 }),
        group({ pushStatus: 'accepted', pushProvider: 'onesignal', n: 268, read: 30 }),
        group({ pushStatus: 'no_device', pushProvider: 'onesignal', n: 10 }),
        group({ pushStatus: 'pending', pushLastError: 'deferred_quiet_hours', future: true, n: 4 }),
        group({ pushStatus: 'pending', pushLastError: 'deferred_pacing', future: true, n: 1 }),
        group({ pushStatus: 'pending', pushLastError: 'deferred_busy', future: true, n: 1 }),
        group({ pushStatus: 'pending', pushLastError: 'retry_provider', future: true, n: 1 }),
        // Échue : en attente, mais plus « reportée ».
        group({ pushStatus: 'pending', pushLastError: 'deferred_quiet_hours', future: false, n: 2 }),
        group({ pushStatus: 'skipped', pushLastError: 'opt_out', n: 9, read: 2 }),
        group({ pushStatus: 'skipped', pushLastError: 'push_disabled', n: 5 }),
        group({ pushStatus: 'skipped', pushLastError: 'stopped_by_staff', n: 3 }),
        group({ pushStatus: 'failed', pushLastError: 'max_attempts', n: 2 }),
        group({ pushStatus: 'expired', n: 1 }),
        group({ pushStatus: null, n: 7 }),
      ],
      265,
    );
    expect(report.inbox).toEqual({ total: 326, read: 37 });
    expect(report.push).toEqual({
      accepted: 280,
      acceptedPushes: 265,
      noDevice: 10,
      failed: 2,
      expired: 1,
      pending: 9,
      deferredQuietHours: 4,
      deferredPacing: 2,
      retrying: 1,
      skipped: {
        total: 17,
        optOut: 9,
        pushDisabled: 5,
        muted: 0,
        unfollowed: 0,
        notPublic: 0,
        cycleClosed: 0,
        pushUnconfigured: 0,
        stoppedByStaff: 3,
      },
      untracked: 7,
    });
    expect(report.byProvider).toEqual({ fcm: 12, onesignal: 268 });
  });

  it('un rapport vide est à zéro', () => {
    const report = buildOpeningReportCounts([], 0);
    expect(report.inbox).toEqual({ total: 0, read: 0 });
    expect(report.push.accepted).toBe(0);
    expect(report.byProvider).toEqual({ fcm: 0, onesignal: 0 });
  });
});
