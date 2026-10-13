import { PrismaService } from '../prisma/prisma.service';
import { PushSenderService } from './push-sender.service';
import { SalonReminderCronService } from './salon-reminder-cron.service';

/** Guards KPB-78: 24h + 1h salon reminders fire once each, deep-link to
 *  /salon, and are stamped so they never repeat. */
describe('SalonReminderCronService', () => {
  type Reg = {
    id: string;
    remindedAt: Date | null;
    reminded1hAt: Date | null;
    session: { startAt: Date; titleFr: string; titleEn: string };
    user: { id: string; preferredLanguage: string };
  };

  function makeService(regs: Reg[]) {
    const sent: Array<{ userId: string; data?: Record<string, string> }> = [];
    const updated: Array<{ id: string; data: Record<string, unknown> }> = [];
    const client = {
      salonRegistration: {
        findMany: async () => regs,
        update: async ({
          where,
          data,
        }: {
          where: { id: string };
          data: Record<string, unknown>;
        }) => {
          updated.push({ id: where.id, data });
          return {};
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const push = {
      sendToUser: async (
        userId: string,
        _title: string,
        _body: string,
        data?: Record<string, string>,
      ) => {
        sent.push({ userId, data });
        return true;
      },
    } as unknown as PushSenderService;
    return { service: new SalonReminderCronService(prisma, push), sent, updated };
  }

  function reg(overrides: Partial<Reg> & { minutesOut: number }): Reg {
    return {
      id: 'r1',
      remindedAt: null,
      reminded1hAt: null,
      session: {
        startAt: new Date(Date.now() + overrides.minutesOut * 60 * 1000),
        titleFr: 'Panel France',
        titleEn: 'France panel',
      },
      user: { id: 'u1', preferredLanguage: 'fr' },
      ...overrides,
    };
  }

  it('sends a 24h reminder (deep-link /salon) and stamps remindedAt', async () => {
    const { service, sent, updated } = makeService([reg({ minutesOut: 24 * 60 })]);
    const res = await service.run();
    expect(res.reminders24h).toBe(1);
    expect(sent).toHaveLength(1);
    expect(sent[0].data?.route).toBe('/salon');
    expect(updated[0].data).toHaveProperty('remindedAt');
  });

  it('sends a 1h reminder and stamps reminded1hAt', async () => {
    const { service, sent, updated } = makeService([reg({ minutesOut: 30 })]);
    const res = await service.run();
    expect(res.reminders1h).toBe(1);
    expect(sent[0].data?.route).toBe('/salon');
    expect(updated[0].data).toHaveProperty('reminded1hAt');
  });

  it('never re-sends the 24h reminder once stamped (idempotent)', async () => {
    const { service, sent } = makeService([
      reg({ minutesOut: 24 * 60, remindedAt: new Date() }),
    ]);
    const res = await service.run();
    expect(res.reminders24h).toBe(0);
    expect(sent).toHaveLength(0);
  });
});
