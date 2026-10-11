import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { DailyScholarshipService } from './daily-scholarship.service';
import { ScholarshipsIndexService } from './scholarships-index.service';

const DAY = 24 * 60 * 60 * 1000;

/**
 * Guards KPB-162: the daily pick rotates deterministically (no repeat within
 * the eligible set), and the 19h push targets only students at local 19:00,
 * honours the opt-out filter, and is inert while the flag is off.
 */
describe('DailyScholarshipService', () => {
  const ORIGINAL = process.env.KPB_DAILY_SCHOLARSHIP_ENABLED;
  afterEach(() => {
    if (ORIGINAL === undefined) {
      delete process.env.KPB_DAILY_SCHOLARSHIP_ENABLED;
    } else {
      process.env.KPB_DAILY_SCHOLARSHIP_ENABLED = ORIGINAL;
    }
  });

  function make(
    opts: {
      scholarships?: unknown[];
      recipients?: unknown[];
      enabled?: boolean;
    } = {},
  ) {
    if (opts.enabled) {
      process.env.KPB_DAILY_SCHOLARSHIP_ENABLED = 'true';
    } else {
      delete process.env.KPB_DAILY_SCHOLARSHIP_ENABLED;
    }

    const profileWheres: Array<Record<string, unknown>> = [];
    const scholarshipWheres: Array<Record<string, unknown>> = [];
    const client = {
      scholarship: {
        findMany: async ({ where }: { where: Record<string, unknown> }) => {
          scholarshipWheres.push(where);
          return opts.scholarships ?? [];
        },
      },
      userProfile: {
        findMany: async ({ where }: { where: Record<string, unknown> }) => {
          profileWheres.push(where);
          return opts.recipients ?? [];
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;

    const dispatched: Array<Record<string, unknown>> = [];
    const dispatch = {
      dispatch: async (input: Record<string, unknown>) => {
        dispatched.push(input);
        return 'pushed' as const;
      },
    } as unknown as NotificationDispatchService;

    const scholarships = {
      getForProfile: async (id: string) => ({ id }),
    } as unknown as ScholarshipsIndexService;

    return {
      service: new DailyScholarshipService(prisma, scholarships, dispatch),
      dispatched,
      profileWheres,
      scholarshipWheres,
    };
  }

  const sch = (id: string, deadlineInDays: number) => ({
    id,
    nameFr: `Bourse ${id}`,
    nameEn: `Scholarship ${id}`,
    countryNameFr: 'France',
    countryNameEn: 'France',
    deadlineAt: new Date(Date.now() + deadlineInDays * DAY),
  });

  it('pickForDate rotates deterministically by day over the eligible set', async () => {
    const { service } = make({
      scholarships: [sch('a', 10), sch('b', 20), sch('c', 30)],
    });
    const at = (dayNumber: number) => new Date(dayNumber * DAY + 12 * 3600_000);

    expect((await service.pickForDate(at(0)))?.id).toBe('a');
    expect((await service.pickForDate(at(1)))?.id).toBe('b');
    expect((await service.pickForDate(at(2)))?.id).toBe('c');
    expect((await service.pickForDate(at(3)))?.id).toBe('a'); // wraps (3 % 3)
    // Stable for the same day.
    expect((await service.pickForDate(at(1)))?.id).toBe('b');
  });

  it('returns null when nothing is eligible', async () => {
    const { service } = make({ scholarships: [] });
    expect(await service.pickForDate(new Date())).toBeNull();
  });

  it('pushes only to students at local 19:00 and applies the opt-out filter', async () => {
    // 19:00 UTC → local 19h at UTC+0 (Senegal), local 20h at UTC+1 (Niger).
    const now = new Date('2026-07-24T19:00:00Z');
    const { service, dispatched, profileWheres } = make({
      enabled: true,
      scholarships: [sch('x', 15)],
      recipients: [
        { id: 'u-sn', preferredLanguage: 'fr', countryOfResidence: 'SN' },
        { id: 'u-ne', preferredLanguage: 'fr', countryOfResidence: 'NE' },
      ],
    });

    await service.sendDailyPush(now);

    // Opt-out is enforced in the recipient query (AC3).
    expect(profileWheres[0]).toMatchObject({
      accountType: 'student',
      NOT: { disabledNotificationTypes: { has: 'daily_scholarship' } },
    });
    // Only the local-19h student is pushed.
    expect(dispatched).toHaveLength(1);
    expect(dispatched[0]).toMatchObject({
      userId: 'u-sn',
      kind: 'daily_scholarship',
      route: '/scholarships/x',
      scholarshipId: 'x',
    });
    expect(dispatched[0].dedupeKey).toBe('daily-scholarship:2026-07-24:u-sn');
  });

  it('is a no-op while the flag is off', async () => {
    const { service, dispatched } = make({
      enabled: false,
      scholarships: [sch('x', 15)],
      recipients: [
        { id: 'u-sn', preferredLanguage: 'fr', countryOfResidence: 'SN' },
      ],
    });
    await service.sendDailyPush(new Date('2026-07-24T19:00:00Z'));
    expect(dispatched).toHaveLength(0);
  });

  it('only picks scholarships the public detail view will serve', async () => {
    const { service, scholarshipWheres } = make();
    await service.pickForDate(new Date('2026-10-14T08:00:00.000Z'));
    expect(scholarshipWheres[0]).toMatchObject({
      isActive: true,
      moderationStatus: 'approved',
      lastVerifiedAt: { not: null },
    });
  });
});
