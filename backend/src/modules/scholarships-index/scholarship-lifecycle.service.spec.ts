import { HttpException } from '@nestjs/common';

import { InternalRole } from '../../common/enums/internal-role.enum';
import type { PushSenderService } from '../notifications/push-sender.service';
import type { PrismaService } from '../prisma/prisma.service';
import type { ActivateScholarshipDto } from './dto/activate-scholarship.dto';
import type {
  FollowerAudienceCounts,
  FollowerRow,
} from './opening/scholarship-follow.query';
import type {
  OpeningAudienceQuery,
  ScholarshipOpeningAudienceService,
} from './opening/scholarship-opening-audience.service';
import type { ScholarshipContentQualityService } from './scholarship-content-quality.service';
import {
  ScholarshipLifecycleService,
  type OpeningActor,
} from './scholarship-lifecycle.service';

type CycleRow = {
  id: string;
  academicYear: string;
  status: string;
  activatedAt: Date | null;
  activationKey: string | null;
  openingPreExisting: boolean;
  openingNotifiedAt: Date | null;
  openingNotifiedById: string | null;
  openingFanoutDueAt: Date | null;
  openingFanoutScope: string | null;
  openingFanoutById: string | null;
  openingLastFanoutAt: Date | null;
  openingSkippedAt: Date | null;
  openingSkippedReason: string | null;
  openingAudience: number | null;
  opensAt: Date | null;
  closesAt: Date | null;
};

type Subscriber = {
  userId: string;
  pushEnabled: boolean;
  inAppEnabled: boolean;
  mutedAt: Date | null;
  user: { preferredLanguage: string };
};

/** Ce que le chemin legacy lit de `follow_rows`. */
type Follower = Pick<FollowerRow, 'userId' | 'toNotify' | 'optedOut'>;

type Write = { op: string; data?: unknown };

const admin: OpeningActor = { id: 'adm-1', role: InternalRole.Admin };
const contentManager: OpeningActor = {
  id: 'adm-2',
  role: InternalRole.ContentManager,
};

const input: ActivateScholarshipDto = {
  academicYear: '2026-2027',
  opensAt: '2026-08-01T00:00:00.000Z',
  closesAt: '2026-11-01T23:59:59.999Z',
  dateConfidence: 'confirmed',
  sourceUrl: 'https://example.org/official',
};

function cycleRow(over: Partial<CycleRow> = {}): CycleRow {
  return {
    id: 'cycle-1',
    academicYear: '2026-2027',
    status: 'open',
    activatedAt: null,
    activationKey: null,
    openingPreExisting: false,
    openingNotifiedAt: null,
    openingNotifiedById: null,
    openingFanoutDueAt: null,
    openingFanoutScope: null,
    openingFanoutById: null,
    openingLastFanoutAt: null,
    openingSkippedAt: null,
    openingSkippedReason: null,
    openingAudience: null,
    opensAt: null,
    closesAt: null,
    ...over,
  };
}

function counts(over: Partial<FollowerAudienceCounts> = {}): FollowerAudienceCounts {
  return {
    audience: 2,
    muted: 0,
    toNotify: 2,
    viaFavoriteOnly: 1,
    viaAlertOnly: 0,
    viaBoth: 1,
    ...over,
  };
}

/**
 * Un faux client de transaction, en mémoire : assez pour suivre ce
 * qu'`activate` lit sous verrou, ce qu'il écrit, et dans quel ordre.
 */
function makeService(
  opts: {
    cycles?: CycleRow[];
    counts?: FollowerAudienceCounts;
    subscribers?: Subscriber[];
    /** `follow_rows` ; par défaut, chaque abonné non en sourdine est à prévenir. */
    followers?: Follower[];
    failFirstUpsertWith?: unknown;
    lockError?: unknown;
  } = {},
) {
  const cycles = new Map<string, CycleRow>(
    (opts.cycles ?? []).map((cycle) => [cycle.academicYear, cycle]),
  );
  const writes: Write[] = [];
  const transactionOptions: unknown[] = [];
  const pushes: Array<{ userId: string; title: string; data?: object }> = [];
  const audienceQueries: OpeningAudienceQuery[] = [];
  const rowQueries: OpeningAudienceQuery[] = [];
  let upsertFailures = opts.failFirstUpsertWith ? 1 : 0;
  let nextId = cycles.size + 1;
  const subscribers = opts.subscribers ?? [
    {
      userId: 'user-fr',
      pushEnabled: true,
      inAppEnabled: true,
      mutedAt: null,
      user: { preferredLanguage: 'fr' },
    },
    {
      userId: 'user-en',
      pushEnabled: true,
      inAppEnabled: true,
      mutedAt: null,
      user: { preferredLanguage: 'en' },
    },
  ];

  const byId = (id: string) =>
    [...cycles.values()].find((cycle) => cycle.id === id);

  const client = {
    $transaction: async (
      fn: (tx: unknown) => Promise<unknown>,
      options?: unknown,
    ): Promise<unknown> => {
      transactionOptions.push(options);
      return fn(client);
    },
    $executeRaw: async () => 0,
    $queryRaw: async (strings: TemplateStringsArray, ...values: unknown[]) => {
      if (opts.lockError) throw opts.lockError;
      expect(strings.join('?')).toContain('FOR UPDATE');
      const cycle = cycles.get(String(values[1]));
      return cycle ? [{ ...cycle }] : [];
    },
    scholarship: {
      findUnique: async () => ({
        id: 'sch-1',
        nameFr: 'Bourse Test',
        nameEn: 'Test Scholarship',
      }),
      update: async (args: { data: unknown }) => {
        writes.push({ op: 'scholarship.update', data: args.data });
        return { id: 'sch-1' };
      },
    },
    scholarshipCycle: {
      upsert: async (args: {
        where: { scholarshipId_academicYear: { academicYear: string } };
        create: Partial<CycleRow>;
        update: Partial<CycleRow>;
      }) => {
        if (upsertFailures > 0) {
          upsertFailures -= 1;
          throw opts.failFirstUpsertWith;
        }
        const year = args.where.scholarshipId_academicYear.academicYear;
        const existing = cycles.get(year);
        writes.push({ op: 'cycle.upsert', data: existing ? args.update : args.create });
        const next = existing
          ? { ...existing, ...stripUndefined(args.update) }
          : cycleRow({ id: `cycle-${nextId++}`, academicYear: year, ...args.create });
        cycles.set(year, next);
        return { ...next };
      },
      updateMany: async (args: {
        where: { id: string; activatedAt: null };
        data: Partial<CycleRow>;
      }) => {
        const cycle = byId(args.where.id);
        if (!cycle || cycle.activatedAt !== null) return { count: 0 };
        writes.push({ op: 'cycle.activate', data: args.data });
        Object.assign(cycle, args.data);
        return { count: 1 };
      },
      update: async (args: { where: { id: string }; data: Partial<CycleRow> }) => {
        writes.push({ op: 'cycle.update', data: args.data });
        const cycle = byId(args.where.id);
        if (cycle) Object.assign(cycle, args.data);
        return cycle;
      },
    },
    scholarshipAlertSubscription: {
      findMany: async (args: { where: { mutedAt?: null } }) => {
        expect(args.where.mutedAt).toBeNull();
        return subscribers.filter((subscriber) => subscriber.mutedAt === null);
      },
    },
    userNotification: {
      createMany: async ({ data }: { data: Record<string, unknown>[] }) => {
        writes.push({ op: 'userNotification.createMany', data });
        return { count: data.length };
      },
    },
    adminAuditEvent: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        writes.push({ op: 'audit', data });
        return data;
      },
    },
  };

  const prisma = {
    isEnabled: true,
    execute: async <T>(fn: (db: unknown) => Promise<T>) => fn(client),
  } as unknown as PrismaService;
  const push = {
    sendToUser: async (
      userId: string,
      title: string,
      _body: string,
      data?: object,
    ) => {
      pushes.push({ userId, title, data });
      return true;
    },
  } as unknown as PushSenderService;
  const audience = {
    countToNotify: async (_db: unknown, query: OpeningAudienceQuery) => {
      audienceQueries.push(query);
      return opts.counts ?? counts();
    },
    rows: async (query: OpeningAudienceQuery, db?: unknown): Promise<Follower[]> => {
      // Lu dans la transaction d'activate, après le verrou du cycle.
      expect(db).toBe(client);
      rowQueries.push(query);
      return (
        opts.followers ??
        subscribers
          .filter((subscriber) => subscriber.mutedAt === null)
          .map((subscriber) => ({
            userId: subscriber.userId,
            toNotify: true,
            optedOut: false,
          }))
      );
    },
  } as unknown as ScholarshipOpeningAudienceService;

  return {
    service: new ScholarshipLifecycleService(
      prisma,
      push,
      {
        assertReady: async () => ({ ready: true }),
      } as unknown as ScholarshipContentQualityService,
      audience,
    ),
    cycles,
    writes,
    pushes,
    audienceQueries,
    rowQueries,
    transactionOptions,
  };
}

function stripUndefined<T extends object>(value: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(value).filter(([, v]) => v !== undefined),
  ) as Partial<T>;
}

async function rejection(promise: Promise<unknown>): Promise<HttpException> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof HttpException) return error;
    throw error;
  }
  throw new Error('expected a rejection');
}

function body(error: HttpException): { code?: string; details?: unknown; message?: string } {
  return error.getResponse() as { code?: string; details?: unknown; message?: string };
}

describe('ScholarshipLifecycleService.activate', () => {
  const previousMode = process.env.KPB_SCHOLARSHIP_OPENING_MODE;
  const previousThreshold = process.env.KPB_OPENING_CONFIRM_THRESHOLD;

  afterEach(() => {
    for (const [name, value] of [
      ['KPB_SCHOLARSHIP_OPENING_MODE', previousMode],
      ['KPB_OPENING_CONFIRM_THRESHOLD', previousThreshold],
    ] as const) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  });

  const setMode = (mode: string) => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = mode;
  };

  describe('legacy (défaut)', () => {
    it('première activation : lignes avec la colonne cycleId, push localisés, clés d’avant gardées', async () => {
      delete process.env.KPB_SCHOLARSHIP_OPENING_MODE;
      const { service, writes, pushes, cycles } = makeService();

      const result = await service.activate('sch-1', input, admin, 'req-1');

      expect(result).toMatchObject({
        scholarshipId: 'sch-1',
        status: 'open',
        firstActivation: true,
        subscribers: 2,
        pushesSent: 2,
        academicYear: '2026-2027',
        mode: 'legacy',
        notification: { state: 'sent_legacy', toNotify: 2, fanoutAt: null, reason: null },
      });
      expect(Object.keys(result).slice(0, 6)).toEqual([
        'scholarshipId',
        'cycleId',
        'status',
        'firstActivation',
        'subscribers',
        'pushesSent',
      ]);
      const rows = writes.find((w) => w.op === 'userNotification.createMany')
        ?.data as Array<Record<string, unknown>>;
      expect(rows).toHaveLength(2);
      expect(rows[0]).toMatchObject({
        kind: 'scholarship_opened',
        cycleId: result.cycleId,
        dedupeKey: `scholarship-opened:${result.cycleId}:user-fr`,
        route: '/scholarships/sch-1',
      });
      expect(pushes.map((p) => p.title)).toEqual([
        'La bourse est ouverte',
        'Scholarship applications are open',
      ]);
      expect(pushes[0].data).toMatchObject({ route: '/scholarships/sch-1' });
      const cycle = cycles.get('2026-2027');
      expect(cycle?.openingNotifiedAt).toBeInstanceOf(Date);
      expect(cycle?.openingLastFanoutAt).toBeInstanceOf(Date);
      expect(cycle?.openingAudience).toBe(2);
      expect(cycle?.openingNotifiedById).toBe('adm-1');
      expect(writes.find((w) => w.op === 'audit')?.data).toMatchObject({
        action: 'scholarship_cycle.notified_legacy',
        actorAdminId: 'adm-1',
        requestId: 'req-1',
        entityType: 'ScholarshipCycle',
        purposeCode: 'scholarship_opening',
      });
    });

    it('ignore les alertes en sourdine', async () => {
      const { service, pushes } = makeService({
        counts: counts({ audience: 1, toNotify: 1 }),
        subscribers: [
          {
            userId: 'muted',
            pushEnabled: true,
            inAppEnabled: true,
            mutedAt: new Date(),
            user: { preferredLanguage: 'fr' },
          },
          {
            userId: 'live',
            pushEnabled: true,
            inAppEnabled: true,
            mutedAt: null,
            user: { preferredLanguage: 'fr' },
          },
        ],
      });
      const result = await service.activate('sch-1', input, admin, 'req');
      expect(pushes.map((p) => p.userId)).toEqual(['live']);
      expect(result.subscribers).toBe(1);
    });

    it('les destinataires de l’aperçu : prévenus récemment exclus, désinscrits sans push', async () => {
      const live = (userId: string): Subscriber => ({
        userId,
        pushEnabled: true,
        inAppEnabled: true,
        mutedAt: null,
        user: { preferredLanguage: 'fr' },
      });
      const { service, writes, pushes, audienceQueries, rowQueries } = makeService({
        counts: counts({ audience: 4, toNotify: 2 }),
        subscribers: [live('fresh'), live('opted-out'), live('recent'), live('already')],
        followers: [
          { userId: 'fresh', toNotify: true, optedOut: false },
          { userId: 'opted-out', toNotify: true, optedOut: true },
          // Prévenu il y a 3 jours pour un autre cycle de la bourse.
          { userId: 'recent', toNotify: false, optedOut: false },
          { userId: 'already', toNotify: false, optedOut: false },
        ],
      });

      const result = await service.activate(
        'sch-1',
        { ...input, notify: true, expectedRecipients: 2 },
        admin,
        'req',
      );

      expect(rowQueries).toEqual(audienceQueries);
      expect(result).toMatchObject({
        subscribers: 4,
        pushesSent: 1,
        notification: { state: 'sent_legacy', toNotify: 2 },
      });
      expect(pushes.map((p) => p.userId)).toEqual(['fresh']);
      const rows = writes.find((w) => w.op === 'userNotification.createMany')
        ?.data as Array<Record<string, unknown>>;
      expect(rows.map((row) => row.userId)).toEqual(['fresh', 'opted-out']);
      expect(writes.find((w) => w.op === 'audit')?.data).toMatchObject({
        action: 'scholarship_cycle.notified_legacy',
        changes: expect.objectContaining({ toNotify: 2, expectedRecipients: 2 }),
      });
    });

    it('mauvaise année corrigée : l’aperçu dit 0, « Ouvrir le cycle » passe sans 409 ni push', async () => {
      const subscribers: Subscriber[] = Array.from({ length: 50 }, (_, i) => ({
        userId: `u${i}`,
        pushEnabled: true,
        inAppEnabled: true,
        mutedAt: null,
        user: { preferredLanguage: 'fr' },
      }));
      const { service, pushes, writes } = makeService({
        counts: counts({ audience: 50, toNotify: 0, viaFavoriteOnly: 0, viaBoth: 0 }),
        subscribers,
        followers: subscribers.map((s) => ({ userId: s.userId, toNotify: false, optedOut: false })),
      });
      const result = await service.activate(
        'sch-1',
        { ...input, academicYear: '2027-2028', notify: true, expectedRecipients: 0 },
        admin,
        'req',
      );
      expect(result.notification).toMatchObject({ state: 'sent_legacy', toNotify: 0 });
      expect(result.pushesSent).toBe(0);
      expect(pushes).toEqual([]);
      expect(writes.some((w) => w.op === 'userNotification.createMany')).toBe(false);
    });

    it('cycle déjà activé : dates corrigées sans prévenir deux fois', async () => {
      const activatedAt = new Date('2026-08-01');
      const { service, writes, pushes } = makeService({
        cycles: [
          cycleRow({ activatedAt, openingNotifiedAt: activatedAt }),
        ],
      });
      const result = await service.activate('sch-1', input, admin, 'req');
      expect(result.firstActivation).toBe(false);
      expect(result.pushesSent).toBe(0);
      expect(result.notification).toEqual({
        state: 'none',
        toNotify: 0,
        fanoutAt: null,
        reason: 'already_announced',
      });
      expect(writes.some((w) => w.op === 'userNotification.createMany')).toBe(false);
      expect(pushes).toHaveLength(0);
      expect(writes.find((w) => w.op === 'audit')?.data).toMatchObject({
        action: 'scholarship_cycle.dates_updated',
      });
    });

    it('notify:true sur un cycle déjà activé : rien (legacy annonce à la première activation seulement)', async () => {
      const { service, pushes } = makeService({
        cycles: [cycleRow({ activatedAt: new Date('2026-08-01') })],
      });
      const result = await service.activate('sch-1', { ...input, notify: true }, admin, 'req');
      expect(result.notification).toMatchObject({
        state: 'none',
        reason: 'legacy_first_activation_only',
      });
      expect(pushes).toHaveLength(0);
    });
  });

  describe('modes boîte d’envoi', () => {
    beforeEach(() => setMode('outbox_followers'));

    it('première activation : programme à +120 s, n’écrit rien pour les étudiants et n’appelle aucun fournisseur', async () => {
      const { service, writes, pushes, cycles, transactionOptions } = makeService();
      const before = Date.now();

      const result = await service.activate('sch-1', input, admin, 'req-42');

      expect(result).toMatchObject({
        firstActivation: true,
        subscribers: 2,
        pushesSent: 0,
        mode: 'outbox_followers',
        notification: { state: 'scheduled', toNotify: 2, reason: null },
      });
      const fanoutAt = Date.parse(result.notification.fanoutAt ?? '');
      expect(fanoutAt - before).toBeGreaterThanOrEqual(120_000);
      expect(fanoutAt - Date.now()).toBeLessThanOrEqual(120_000);
      expect(writes.some((w) => w.op === 'userNotification.createMany')).toBe(false);
      expect(pushes).toHaveLength(0);
      const cycle = cycles.get('2026-2027');
      expect(cycle).toMatchObject({
        openingFanoutScope: 'followers',
        openingFanoutById: 'adm-1',
        openingNotifiedById: null,
      });
      expect(writes.find((w) => w.op === 'audit')?.data).toMatchObject({
        action: 'scholarship_cycle.notify_scheduled',
        actorAdminId: 'adm-1',
        requestId: 'req-42',
        result: 'success',
        changes: {
          academicYear: '2026-2027',
          notify: null,
          mode: 'outbox_followers',
          scope: 'followers',
          toNotify: 2,
          expectedRecipients: null,
          viaFavoriteOnly: 1,
          viaAlertOnly: 0,
          viaBoth: 1,
        },
      });
      expect(transactionOptions).toEqual([{ maxWait: 5_000, timeout: 30_000 }]);
    });

    it('outbox_alerts : portée « alerts » figée sur le cycle', async () => {
      setMode('outbox_alerts');
      const { service, cycles, audienceQueries } = makeService();
      await service.activate('sch-1', input, admin, 'req');
      expect(cycles.get('2026-2027')?.openingFanoutScope).toBe('alerts');
      expect(audienceQueries[0].scope).toBe('alerts');
    });

    it('notify:false : rien de programmé, cycle marqué dates_only', async () => {
      const { service, cycles, writes } = makeService();
      const result = await service.activate('sch-1', { ...input, notify: false }, admin, 'req');
      expect(result.notification).toEqual({
        state: 'none',
        toNotify: 0,
        fanoutAt: null,
        reason: 'dates_only',
      });
      expect(cycles.get('2026-2027')).toMatchObject({
        openingFanoutDueAt: null,
        openingSkippedReason: 'dates_only',
      });
      expect(writes.find((w) => w.op === 'audit')?.data).toMatchObject({
        action: 'scholarship_cycle.opened',
      });
    });

    it('notify absent : programme à la première activation seulement ; une nouvelle année programme encore', async () => {
      const activatedAt = new Date('2026-08-01');
      const { service, cycles } = makeService({
        cycles: [cycleRow({ activatedAt, openingNotifiedAt: activatedAt })],
      });
      const same = await service.activate('sch-1', input, admin, 'req');
      expect(same.notification.state).toBe('none');
      const next = await service.activate(
        'sch-1',
        { ...input, academicYear: '2027-2028' },
        admin,
        'req',
      );
      expect(next.firstActivation).toBe(true);
      expect(next.notification.state).toBe('scheduled');
      expect(cycles.get('2027-2028')?.openingFanoutDueAt).toBeInstanceOf(Date);
    });

    it.each([
      [
        'ouvert par le catalogue',
        cycleRow({
          openingPreExisting: true,
          openingSkippedAt: new Date('2026-10-15'),
          openingSkippedReason: 'pre_existing_open',
        }),
      ],
      [
        'activé avant le déploiement',
        cycleRow({
          openingPreExisting: true,
          activatedAt: new Date('2026-09-01'),
          openingNotifiedAt: new Date('2026-09-01'),
        }),
      ],
    ])('cycle pré-existant (%s) : notify:true → 409 sans écriture ; absent → pas d’annonce', async (_label, preExisting) => {
      const { service, writes } = makeService({ cycles: [{ ...preExisting }] });
      const error = await rejection(
        service.activate('sch-1', { ...input, notify: true }, admin, 'req'),
      );
      expect(error.getStatus()).toBe(409);
      expect(body(error).code).toBe('OPENING_NOT_RETROACTIVE');
      expect(body(error).message).toContain('déjà ouvert');
      expect(writes).toEqual([]);

      const result = await service.activate('sch-1', input, admin, 'req');
      expect(result.notification).toMatchObject({
        state: 'none',
        reason: 'pre_existing_open',
      });
    });

    it.each([
      ['notify:false', { notify: false }],
      ['notify absent (second clic)', {}],
    ])('%s pendant l’attente : la programmation est gardée, sans dates_only', async (_label, extra) => {
      const dueAt = new Date(Date.now() + 60_000);
      const { service, cycles } = makeService({
        cycles: [
          cycleRow({
            activatedAt: new Date(),
            openingFanoutDueAt: dueAt,
            openingFanoutScope: 'followers',
            openingFanoutById: 'adm-1',
          }),
        ],
      });
      const result = await service.activate('sch-1', { ...input, ...extra }, admin, 'req');
      expect(result.notification).toMatchObject({
        state: 'already_scheduled',
        fanoutAt: dueAt.toISOString(),
        reason: null,
      });
      expect(cycles.get('2026-2027')).toMatchObject({
        openingFanoutDueAt: dueAt,
        openingSkippedReason: null,
      });
    });

    it('double programmation idempotente : même heure, une seule programmation', async () => {
      const { service, writes } = makeService();
      const first = await service.activate('sch-1', { ...input, notify: true }, admin, 'r1');
      const second = await service.activate('sch-1', { ...input, notify: true }, admin, 'r2');
      expect(first.notification.state).toBe('scheduled');
      expect(second.notification).toMatchObject({
        state: 'already_scheduled',
        fanoutAt: first.notification.fanoutAt,
      });
      expect(
        writes.filter(
          (w) =>
            w.op === 'cycle.update' &&
            (w.data as Partial<CycleRow>).openingFanoutDueAt !== undefined,
        ),
      ).toHaveLength(1);
    });

    it('relance d’un cycle annoncé : followSince = openingNotifiedAt, auteur de la première annonce gardé', async () => {
      const announcedAt = new Date('2026-09-01T10:00:00Z');
      const { service, cycles, audienceQueries } = makeService({
        cycles: [
          cycleRow({
            activatedAt: announcedAt,
            openingNotifiedAt: announcedAt,
            openingNotifiedById: 'adm-first',
            openingAudience: 10,
          }),
        ],
        counts: counts({ toNotify: 3 }),
      });
      const result = await service.activate('sch-1', { ...input, notify: true }, admin, 'req');
      expect(audienceQueries[0]).toMatchObject({
        cycleId: 'cycle-1',
        followSince: announcedAt,
      });
      expect(result.notification).toMatchObject({ state: 'scheduled', toNotify: 3 });
      expect(cycles.get('2026-2027')).toMatchObject({
        openingNotifiedById: 'adm-first',
        openingFanoutById: 'adm-1',
      });
    });

    it('relance sans nouvel abonné : nothing_to_send, already_announced', async () => {
      const announcedAt = new Date('2026-09-01T10:00:00Z');
      const { service } = makeService({
        cycles: [cycleRow({ activatedAt: announcedAt, openingNotifiedAt: announcedAt })],
        counts: counts({ toNotify: 0 }),
      });
      const result = await service.activate('sch-1', { ...input, notify: true }, admin, 'req');
      expect(result.notification).toEqual({
        state: 'nothing_to_send',
        toNotify: 0,
        fanoutAt: null,
        reason: 'already_announced',
      });
    });

    it('première annonce sans abonné : nothing_to_send, le cycle sort de « À faire »', async () => {
      const { service, cycles } = makeService({ counts: counts({ audience: 0, toNotify: 0 }) });
      const result = await service.activate('sch-1', input, admin, 'req');
      expect(result.notification).toMatchObject({ state: 'nothing_to_send', reason: null });
      expect(cycles.get('2026-2027')?.openingNotifiedAt).toBeInstanceOf(Date);
      expect(cycles.get('2026-2027')?.openingAudience).toBe(0);
    });
  });

  describe('seuil, rôle et audience confirmée', () => {
    beforeEach(() => {
      setMode('outbox_followers');
      process.env.KPB_OPENING_CONFIRM_THRESHOLD = '500';
    });

    it('500 exactement : pas de confirmation demandée', async () => {
      const { service } = makeService({ counts: counts({ toNotify: 500, audience: 500 }) });
      const result = await service.activate('sch-1', input, contentManager, 'req');
      expect(result.notification.state).toBe('scheduled');
    });

    it('501 sans expectedRecipients → 400 avec message complet, rien d’écrit', async () => {
      const { service, writes } = makeService({ counts: counts({ toNotify: 501 }) });
      const error = await rejection(service.activate('sch-1', input, admin, 'req'));
      expect(error.getStatus()).toBe(400);
      expect(body(error)).toMatchObject({
        code: 'OPENING_CONFIRMATION_REQUIRED',
        details: { toNotify: 501, threshold: 500 },
      });
      expect(body(error).message).toContain('Plus de 500 étudiants');
      expect(writes).toEqual([]);
    });

    it('501 confirmés par un ContentManager → 403', async () => {
      const { service, writes } = makeService({ counts: counts({ toNotify: 501 }) });
      const error = await rejection(
        service.activate('sch-1', { ...input, expectedRecipients: 501 }, contentManager, 'req'),
      );
      expect(error.getStatus()).toBe(403);
      expect(body(error).code).toBe('OPENING_REQUIRES_ADMIN');
      expect(writes).toEqual([]);
    });

    it('501 confirmés par un admin → programmé', async () => {
      const { service } = makeService({ counts: counts({ toNotify: 501 }) });
      const result = await service.activate(
        'sch-1',
        { ...input, expectedRecipients: 501 },
        admin,
        'req',
      );
      expect(result.notification).toMatchObject({ state: 'scheduled', toNotify: 501 });
    });

    it('audience qui a trop grossi depuis l’aperçu → 409 et rien d’écrit', async () => {
      const { service, writes } = makeService({ counts: counts({ toNotify: 130 }) });
      const error = await rejection(
        service.activate('sch-1', { ...input, expectedRecipients: 100 }, admin, 'req'),
      );
      expect(error.getStatus()).toBe(409);
      expect(body(error)).toMatchObject({
        code: 'OPENING_AUDIENCE_CHANGED',
        details: { toNotify: 130, expectedRecipients: 100 },
      });
      expect(writes).toEqual([]);
    });

    it('une baisse est acceptée', async () => {
      const { service } = makeService({ counts: counts({ toNotify: 40 }) });
      const result = await service.activate(
        'sch-1',
        { ...input, expectedRecipients: 100 },
        admin,
        'req',
      );
      expect(result.notification).toMatchObject({ state: 'scheduled', toNotify: 40 });
    });

    it('legacy compte aussi : l’admin déjà déployé reçoit 400 au-delà du seuil', async () => {
      setMode('legacy');
      const { service, pushes } = makeService({ counts: counts({ audience: 501, toNotify: 501 }) });
      const error = await rejection(service.activate('sch-1', input, admin, 'req'));
      expect(body(error).code).toBe('OPENING_CONFIRMATION_REQUIRED');
      expect(pushes).toHaveLength(0);
    });

    it('legacy lit le toNotify de l’aperçu, pas l’audience : 495 confirmés par un ContentManager passent', async () => {
      setMode('legacy');
      const { service } = makeService({ counts: counts({ audience: 501, toNotify: 495 }) });
      const result = await service.activate(
        'sch-1',
        { ...input, notify: true, expectedRecipients: 495 },
        contentManager,
        'req',
      );
      expect(result.notification.state).toBe('sent_legacy');
    });

    it('legacy : une audience qui a trop grossi depuis l’aperçu → 409 sur toNotify', async () => {
      setMode('legacy');
      const { service, pushes } = makeService({ counts: counts({ audience: 60, toNotify: 30 }) });
      const error = await rejection(
        service.activate('sch-1', { ...input, notify: true, expectedRecipients: 10 }, admin, 'req'),
      );
      expect(body(error)).toMatchObject({
        code: 'OPENING_AUDIENCE_CHANGED',
        details: { toNotify: 30, expectedRecipients: 10 },
      });
      expect(pushes).toHaveLength(0);
    });
  });

  describe('concurrence', () => {
    beforeEach(() => setMode('outbox_followers'));

    it('attente du verrou au-delà de lock_timeout (P2010/55P03) → 409 OPENING_BUSY, jamais 500', async () => {
      const lockError = Object.assign(new Error('Raw query failed. Code: `55P03`.'), {
        code: 'P2010',
        meta: { code: '55P03', message: 'canceling statement due to lock timeout' },
      });
      const { service, writes } = makeService({ lockError });
      const error = await rejection(service.activate('sch-1', input, admin, 'req'));
      expect(error.getStatus()).toBe(409);
      expect(body(error).code).toBe('OPENING_BUSY');
      expect(writes).toEqual([]);
    });

    it('P2002 (deux premiers clics) : une seconde passe, pas de 500', async () => {
      const conflict = Object.assign(new Error('Unique constraint failed'), { code: 'P2002' });
      const { service, transactionOptions } = makeService({ failFirstUpsertWith: conflict });
      const result = await service.activate('sch-1', input, admin, 'req');
      expect(result.notification.state).toBe('scheduled');
      expect(transactionOptions).toHaveLength(2);
    });

    it('une autre erreur n’est pas retentée', async () => {
      const boom = Object.assign(new Error('boom'), { code: 'P2025' });
      const { service, transactionOptions } = makeService({ failFirstUpsertWith: boom });
      await expect(service.activate('sch-1', input, admin, 'req')).rejects.toBe(boom);
      expect(transactionOptions).toHaveLength(1);
    });
  });

  it('refuse une clôture avant l’ouverture', async () => {
    const { service } = makeService();
    await expect(
      service.activate(
        'sch-1',
        { ...input, closesAt: '2026-07-01T00:00:00.000Z' },
        admin,
        'req',
      ),
    ).rejects.toThrow('closesAt must be after opensAt');
  });
});

describe('ScholarshipLifecycleService.saveForecast', () => {
  it('enregistre une prévision sans notification ni push', async () => {
    const cycleUpserts: unknown[] = [];
    const prisma = {
      isEnabled: true,
      execute: async <T>(fn: (db: unknown) => Promise<T>) =>
        fn({
          scholarship: { findUnique: async () => ({ id: 'sch-1' }) },
          scholarshipCycle: {
            findUnique: async () => null,
            upsert: async (args: unknown) => {
              cycleUpserts.push(args);
              return { id: 'c1', status: 'forecast', dateConfidence: 'estimated' };
            },
          },
        }),
    } as unknown as PrismaService;
    const forecastService = new ScholarshipLifecycleService(
      prisma,
      {} as PushSenderService,
      {} as ScholarshipContentQualityService,
      {} as ScholarshipOpeningAudienceService,
    );
    await forecastService.saveForecast('sch-1', {
      academicYear: '2026-2027',
      estimatedOpenAt: '2026-07-15T00:00:00.000Z',
      estimatedCloseAt: '2026-10-15T00:00:00.000Z',
      sourceUrl: 'https://example.org/previous-cycle',
    });
    // Le faux client n'a ni `userNotification` ni `adminAuditEvent` : une
    // écriture d'inbox ou un push ferait échouer l'appel.
    expect(cycleUpserts).toHaveLength(1);
  });
});
