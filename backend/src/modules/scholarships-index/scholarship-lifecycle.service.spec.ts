import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { ScholarshipLifecycleService } from './scholarship-lifecycle.service';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';

describe('ScholarshipLifecycleService', () => {
  const input = {
    academicYear: '2026-2027',
    opensAt: '2026-08-01T00:00:00.000Z',
    closesAt: '2026-11-01T23:59:59.999Z',
    dateConfidence: 'confirmed' as const,
    sourceUrl: 'https://example.org/official',
  };

  function makeService(alreadyActivated = false) {
    const notifications: Array<Record<string, unknown>> = [];
    const pushes: Array<{ userId: string; title: string; data?: object }> = [];
    const client: any = {
      $transaction: async (fn: (tx: any) => unknown) => fn(client),
      scholarship: {
        findUnique: async () => ({
          id: 'sch-1',
          nameFr: 'Bourse Test',
          nameEn: 'Test Scholarship',
        }),
        update: async () => ({ id: 'sch-1' }),
      },
      scholarshipCycle: {
        findUnique: async () =>
          alreadyActivated
            ? { id: 'cycle-1', activatedAt: new Date('2026-08-01') }
            : null,
        upsert: async () => ({
          id: 'cycle-1',
          status: 'open',
        }),
      },
      scholarshipAlertSubscription: {
        findMany: async () => [
          {
            userId: 'user-fr',
            pushEnabled: true,
            inAppEnabled: true,
            user: { preferredLanguage: 'fr' },
          },
          {
            userId: 'user-en',
            pushEnabled: true,
            inAppEnabled: true,
            user: { preferredLanguage: 'en' },
          },
        ],
      },
      userNotification: {
        createMany: async ({ data }: { data: Record<string, unknown>[] }) => {
          notifications.push(...data);
          return { count: data.length };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (db: typeof client) => unknown) => fn(client),
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
    return {
      service: new ScholarshipLifecycleService(
        prisma,
        push,
        {
          assertReady: async () => ({ ready: true }),
        } as unknown as ScholarshipContentQualityService,
      ),
      notifications,
      pushes,
    };
  }

  it('stores in-app rows and sends localized pushes on first activation', async () => {
    const { service, notifications, pushes } = makeService();

    const result = await service.activate('sch-1', input);

    expect(result).toMatchObject({
      firstActivation: true,
      subscribers: 2,
      pushesSent: 2,
    });
    expect(notifications).toHaveLength(2);
    expect(notifications[0]).toMatchObject({
      kind: 'scholarship_opened',
      route: '/scholarships/sch-1',
    });
    expect(pushes[0].data).toMatchObject({ route: '/scholarships/sch-1' });
    expect(pushes.map((item) => item.title)).toEqual([
      'La bourse est ouverte',
      'Scholarship applications are open',
    ]);
  });

  it('updates confirmed dates without notifying twice', async () => {
    const { service, notifications, pushes } = makeService(true);

    const result = await service.activate('sch-1', input);

    expect(result.firstActivation).toBe(false);
    expect(result.pushesSent).toBe(0);
    expect(notifications).toHaveLength(0);
    expect(pushes).toHaveLength(0);
  });

  it('stores forecast dates without creating notifications or pushes', async () => {
    const { service, notifications, pushes } = makeService();

    await service.saveForecast('sch-1', {
      academicYear: '2026-2027',
      estimatedOpenAt: '2026-07-15T00:00:00.000Z',
      estimatedCloseAt: '2026-10-15T00:00:00.000Z',
      sourceUrl: 'https://example.org/previous-cycle',
    });

    expect(notifications).toHaveLength(0);
    expect(pushes).toHaveLength(0);
  });

  it('rejects a closing date before the opening date', async () => {
    const { service } = makeService();
    await expect(
      service.activate('sch-1', {
        ...input,
        closesAt: '2026-07-01T00:00:00.000Z',
      }),
    ).rejects.toThrow('closesAt must be after opensAt');
  });
});
