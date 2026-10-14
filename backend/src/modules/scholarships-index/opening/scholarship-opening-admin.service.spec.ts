import { HttpException } from '@nestjs/common';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { PushSenderService } from '../../notifications/push-sender.service';
import type { PrismaService } from '../../prisma/prisma.service';
import type { ScholarshipContentQualityService } from '../scholarship-content-quality.service';
import {
  buildOpeningRecentEvent,
  buildOpeningReportCounts,
  ScholarshipOpeningAdminService,
  type OpeningAuditEventRow,
  type OpeningReportGroup,
} from './scholarship-opening-admin.service';
import type { ScholarshipOpeningAudienceService } from './scholarship-opening-audience.service';

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

// ── Annuler / arrêter quand le cycle est tenu par un envoi ──────────────────

type TxOptions = { maxWait?: number; timeout?: number } | undefined;

function makeAdmin(opts: {
  /** Erreur levée par l'UPDATE du cycle (attente de verrou). */
  cycleUpdateError?: unknown;
  /** Erreur levée par `$transaction` elle-même (délai de la transaction). */
  transactionError?: unknown;
}) {
  const statements: string[] = [];
  const txOptions: TxOptions[] = [];
  const audits: unknown[] = [];
  const lockedUpdate = () => {
    if (opts.cycleUpdateError) throw opts.cycleUpdateError;
  };
  const tx = {
    $executeRaw: async (strings: TemplateStringsArray) => {
      const text = strings.join('?');
      statements.push(text);
      if (text.includes('UPDATE "ScholarshipCycle"')) lockedUpdate();
      return 0;
    },
    scholarshipCycle: {
      findFirst: async () => ({
        academicYear: '2026-2027',
        openingFanoutDueAt: new Date('2026-10-15T12:02:00.000Z'),
        openingFanoutScope: 'alerts',
      }),
      updateMany: async () => {
        statements.push('updateMany ScholarshipCycle');
        lockedUpdate();
        return { count: 1 };
      },
      findUnique: async () => ({ openingLastFanoutAt: null }),
    },
    userNotification: { count: async () => 0 },
    adminAuditEvent: {
      create: async (args: unknown) => {
        audits.push(args);
        return {};
      },
    },
  };
  const client = {
    scholarshipCycle: { findFirst: async () => ({ academicYear: '2026-2027' }) },
    $transaction: async (fn: (t: typeof tx) => Promise<unknown>, options?: TxOptions) => {
      txOptions.push(options);
      if (opts.transactionError) throw opts.transactionError;
      return fn(tx);
    },
  };
  const prisma = {
    isEnabled: true,
    execute: async <T>(op: (p: unknown) => Promise<T>) => op(client),
  } as unknown as PrismaService;
  const admin = new ScholarshipOpeningAdminService(
    prisma,
    {} as ScholarshipOpeningAudienceService,
    {} as ScholarshipContentQualityService,
    {} as PushSenderService,
  );
  return { admin, statements, txOptions, audits };
}

const actor = { id: 'adm-1', role: InternalRole.Admin };
/** Prisma 6 : un 55P03 (`lock_timeout`) sur une requête brute. */
const lockTimeout = Object.assign(new Error('lock timeout'), {
  code: 'P2010',
  meta: { code: '55P03' },
});
/** Prisma : la transaction interactive a dépassé son délai. */
const transactionExpired = Object.assign(
  new Error('Transaction already closed: the timeout for this transaction was 15000 ms.'),
  { code: 'P2028' },
);

async function rejection(promise: Promise<unknown>): Promise<HttpException> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof HttpException) return error;
    throw error;
  }
  throw new Error('expected an HttpException');
}

describe.each(['stop', 'cancel'] as const)('%s : cycle tenu par un envoi en préparation', (op) => {
  const call = (admin: ScholarshipOpeningAdminService) =>
    op === 'stop'
      ? admin.stop('sch-1', 'cycle-1', actor, 'req-1')
      : admin.cancel('sch-1', 'cycle-1', actor, 'req-1');

  it('attend 5 s au plus (lock_timeout en tête), dans une transaction au délai explicite', async () => {
    const { admin, statements, txOptions } = makeAdmin({});
    await call(admin);
    expect(statements[0]).toContain(`SET LOCAL lock_timeout = '5s'`);
    expect(txOptions).toEqual([{ maxWait: 5_000, timeout: 15_000 }]);
  });

  it.each([
    ['lock_timeout (55P03)', lockTimeout, 'cycleUpdateError'],
    ['transaction expirée (P2028)', transactionExpired, 'transactionError'],
  ] as const)('%s → 409 OPENING_BUSY, message complet, rien d’audité', async (_label, error, where) => {
    const { admin, audits } = makeAdmin({ [where]: error });
    const conflict = await rejection(call(admin));
    expect(conflict.getStatus()).toBe(409);
    expect(conflict.getResponse()).toMatchObject({
      code: 'OPENING_BUSY',
      message:
        'Un envoi est en cours de préparation pour ce cycle. Réessayez dans quelques secondes.',
    });
    expect(audits).toHaveLength(0);
  });

  it('une autre panne reste une panne (pas un faux 409)', async () => {
    const { admin } = makeAdmin({
      cycleUpdateError: Object.assign(new Error('connection lost'), { code: 'P1001' }),
    });
    await expect(call(admin)).rejects.toMatchObject({ code: 'P1001' });
  });
});

// ── « Derniers événements » : ce qui s'est réellement passé ─────────────────

describe('buildOpeningRecentEvent', () => {
  const at = new Date('2026-10-15T12:00:00.000Z');
  const admins = new Map([['adm-1', { id: 'adm-1', name: 'Aminata D.' }]]);
  const event = (over: Partial<OpeningAuditEventRow>): OpeningAuditEventRow => ({
    action: 'scholarship_cycle.notify_scheduled',
    occurredAt: at,
    actorAdminId: 'adm-1',
    entityId: 'cycle-1',
    result: 'success',
    reasonCode: null,
    changes: { academicYear: '2027-2028', toNotify: 312 },
    ...over,
  });

  it('un geste fait : outcome sent, sans reasonCode', () => {
    expect(buildOpeningRecentEvent(event({}), admins, new Map())).toEqual({
      action: 'scholarship_cycle.notify_scheduled',
      occurredAt: at.toISOString(),
      actorName: 'Aminata D.',
      academicYear: '2027-2028',
      toNotify: 312,
      outcome: 'sent',
    });
  });

  it.each([
    ['not_public_at_fanout', 'scholarship_cycle.fanout_completed'],
    ['cycle_closed_at_fanout', 'scholarship_cycle.fanout_completed'],
    ['fanout_too_late', 'scholarship_cycle.fanout_expired'],
  ])('un envoi abandonné (%s) : outcome skipped, jamais lu comme un envoi fait', (reasonCode, action) => {
    const row = buildOpeningRecentEvent(
      event({
        action,
        actorAdminId: null,
        result: 'skipped',
        reasonCode,
        changes: { academicYear: '2027-2028', inserted: 0 },
      }),
      admins,
      new Map(),
    );
    expect(row).toMatchObject({ action, outcome: 'skipped', reasonCode, toNotify: 0, actorName: null });
  });

  it('une activation refusée : outcome refused, le code en reasonCode', () => {
    const row = buildOpeningRecentEvent(
      event({
        entityId: 'sch-1',
        result: 'refused',
        reasonCode: 'OPENING_AUDIENCE_CHANGED',
        changes: { academicYear: '2027-2028', toNotify: 130, expectedRecipients: 100 },
      }),
      admins,
      new Map(),
    );
    expect(row).toMatchObject({
      outcome: 'refused',
      reasonCode: 'OPENING_AUDIENCE_CHANGED',
      academicYear: '2027-2028',
      toNotify: 130,
    });
  });

  it('année absente des changements : celle du cycle', () => {
    const row = buildOpeningRecentEvent(
      event({ changes: null }),
      admins,
      new Map([['cycle-1', '2026-2027']]),
    );
    expect(row).toMatchObject({ academicYear: '2026-2027', toNotify: null, outcome: 'sent' });
  });
});

// ── « À faire » : le même nombre que la colonne « Abonnés » ─────────────────

describe('todo : abonnés à prévenir', () => {
  const now = new Date('2026-10-15T12:00:00.000Z');
  const previousMode = process.env.KPB_SCHOLARSHIP_OPENING_MODE;

  afterEach(() => {
    if (previousMode === undefined) delete process.env.KPB_SCHOLARSHIP_OPENING_MODE;
    else process.env.KPB_SCHOLARSHIP_OPENING_MODE = previousMode;
  });

  function makeTodoAdmin(
    counts: Array<{ scholarshipId: string; followers: number; notifiable: number }>,
  ) {
    const cycle = (scholarshipId: string, nameFr: string) => ({
      id: `cycle-${scholarshipId}`,
      scholarshipId,
      academicYear: '2026-2027',
      status: 'open',
      opensAt: null,
      closesAt: new Date('2026-12-01T00:00:00.000Z'),
      estimatedCloseAt: null,
      activatedAt: null,
      scholarship: { nameFr },
    });
    const client = {
      scholarshipCycle: {
        findMany: async () => [cycle('a', 'Bourse A'), cycle('b', 'Bourse B')],
      },
      $queryRaw: async () => counts,
    };
    const prisma = {
      isEnabled: true,
      execute: async <T>(op: (p: unknown) => Promise<T>) => op(client),
    } as unknown as PrismaService;
    return new ScholarshipOpeningAdminService(
      prisma,
      {} as ScholarshipOpeningAudienceService,
      {} as ScholarshipContentQualityService,
      {} as PushSenderService,
    );
  }

  it('chaque ligne porte `notifiable` (colonne « Abonnés ») et la file est triée dessus', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    // A : beaucoup de favoris, peu d'alertes ; B : l'inverse. En portée
    // « alertes », c'est B qu'il faut annoncer d'abord.
    const admin = makeTodoAdmin([
      { scholarshipId: 'a', followers: 300, notifiable: 12 },
      { scholarshipId: 'b', followers: 80, notifiable: 80 },
    ]);
    const todo = await admin.todo(now);
    expect(todo.scope).toBe('alerts');
    expect(todo.items.map((item) => [item.scholarshipId, item.followers, item.notifiable])).toEqual([
      ['b', 80, 80],
      ['a', 300, 12],
    ]);
  });
});
