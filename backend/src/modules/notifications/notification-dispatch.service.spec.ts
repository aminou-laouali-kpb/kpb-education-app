import { PrismaService } from '../prisma/prisma.service';
import { NotificationDispatchService } from './notification-dispatch.service';
import { PushSenderService } from './push-sender.service';

/**
 * Guards KPB-155: dispatch always records the durable feed entry, dedups on
 * dedupeKey, and gates the push by quiet hours + the daily frequency cap.
 */
describe('NotificationDispatchService', () => {
  const KEY = 'deadline:scholarship:sch-1:u1:d7';

  function makeService(
    opts: { pushesInWindow?: number; pushConfigured?: boolean } = {},
  ) {
    const rows = new Map<
      string,
      { dedupeKey: string; pushedAt: Date | null }
    >();
    const created: string[] = [];
    const updated: Array<{ dedupeKey: string; pushedAt: Date | null }> = [];
    const sends: Array<{ userId: string; title: string; body: string }> = [];

    const client = {
      userNotification: {
        createMany: async ({
          data,
          skipDuplicates,
        }: {
          data: Array<{ dedupeKey: string }>;
          skipDuplicates?: boolean;
        }) => {
          let count = 0;
          for (const row of data) {
            if (skipDuplicates && rows.has(row.dedupeKey)) continue;
            rows.set(row.dedupeKey, { dedupeKey: row.dedupeKey, pushedAt: null });
            created.push(row.dedupeKey);
            count++;
          }
          return { count };
        },
        count: async () => opts.pushesInWindow ?? 0,
        update: async ({
          where,
          data,
        }: {
          where: { dedupeKey: string };
          data: { pushedAt: Date };
        }) => {
          const row = rows.get(where.dedupeKey);
          if (row) row.pushedAt = data.pushedAt;
          updated.push({ dedupeKey: where.dedupeKey, pushedAt: data.pushedAt });
          return row ?? {};
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const push = {
      isConfigured: opts.pushConfigured ?? true,
      sendToUser: async (userId: string, title: string, body: string) => {
        sends.push({ userId, title, body });
        return true;
      },
    } as unknown as PushSenderService;

    return {
      service: new NotificationDispatchService(prisma, push),
      created,
      updated,
      sends,
    };
  }

  const baseInput = (now: Date) => ({
    userId: 'u1',
    kind: 'deadline_reminder',
    dedupeKey: KEY,
    title: { fr: 'Bourse à J-7', en: 'Scholarship deadline in 7 days' },
    body: { fr: 'corps', en: 'body' },
    route: '/deadlines',
    preferredLanguage: 'fr',
    countryOfResidence: 'SN', // UTC+0
    now,
  });

  // 10:00 UTC → 10:00 local at UTC+0: outside the 21–08 quiet window.
  const daytime = new Date('2026-07-23T10:00:00Z');
  // 23:00 UTC → 23:00 local at UTC+0: inside the quiet window.
  const nighttime = new Date('2026-07-23T23:00:00Z');

  beforeEach(() => {
    delete process.env.KPB_PUSH_MAX_PER_DAY;
    delete process.env.KPB_PUSH_QUIET_START;
    delete process.env.KPB_PUSH_QUIET_END;
  });

  it('records the feed entry, pushes, and stamps pushedAt (happy path)', async () => {
    const { service, created, updated, sends } = makeService();
    const outcome = await service.dispatch(baseInput(daytime));
    expect(outcome).toBe('pushed');
    expect(created).toEqual([KEY]);
    expect(sends).toHaveLength(1);
    expect(sends[0].title).toBe('Bourse à J-7'); // FR user
    expect(updated).toHaveLength(1);
    expect(updated[0].pushedAt).toEqual(daytime);
  });

  it('pushes the English copy for an EN user', async () => {
    const { service, sends } = makeService();
    await service.dispatch({
      ...baseInput(daytime),
      preferredLanguage: 'en',
    });
    expect(sends[0].title).toBe('Scholarship deadline in 7 days');
  });

  it('dedups: a repeat dedupeKey records once and pushes once', async () => {
    const { service, created, sends } = makeService();
    const first = await service.dispatch(baseInput(daytime));
    const second = await service.dispatch(baseInput(daytime));
    expect(first).toBe('pushed');
    expect(second).toBe('deduped');
    expect(created).toEqual([KEY]); // recorded exactly once
    expect(sends).toHaveLength(1); // pushed exactly once
  });

  it('holds the push during local quiet hours but still records the feed', async () => {
    const { service, created, sends } = makeService();
    const outcome = await service.dispatch(baseInput(nighttime));
    expect(outcome).toBe('quiet_hours');
    expect(created).toEqual([KEY]); // durable entry written
    expect(sends).toHaveLength(0); // no phone ping at 23:00 local
  });

  it('holds the push once the daily cap is reached', async () => {
    const { service, created, sends } = makeService({ pushesInWindow: 3 });
    const outcome = await service.dispatch(baseInput(daytime));
    expect(outcome).toBe('capped');
    expect(created).toEqual([KEY]);
    expect(sends).toHaveLength(0);
  });

  it('records feed-only when OneSignal is not configured', async () => {
    const { service, created, sends } = makeService({ pushConfigured: false });
    const outcome = await service.dispatch(baseInput(daytime));
    expect(outcome).toBe('push_unconfigured');
    expect(created).toEqual([KEY]);
    expect(sends).toHaveLength(0);
  });

  it('does nothing when the database is disabled', async () => {
    const push = {
      isConfigured: true,
      sendToUser: async () => true,
    } as unknown as PushSenderService;
    const prisma = { isEnabled: false } as unknown as PrismaService;
    const service = new NotificationDispatchService(prisma, push);
    expect(await service.dispatch(baseInput(daytime))).toBe('skipped');
  });
});
