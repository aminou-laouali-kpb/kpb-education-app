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

  /**
   * Audit §13 : annuler une session ou l'événement ne touche pas aux
   * inscriptions. Le filtre doit donc vivre dans la REQUÊTE du cron — ce faux
   * client l'applique comme le ferait Postgres, sur les champs du schéma
   * (`SalonRegistration.status`, `SalonSession.status`, `SalonEvent.status`).
   */
  describe('sessions / événements annulés', () => {
    type Row = {
      id: string;
      status: string;
      session: {
        startAt: Date;
        status: string;
        titleFr: string;
        titleEn: string;
        event: { status: string };
      };
      user: { id: string; preferredLanguage: string };
      remindedAt: Date | null;
      reminded1hAt: Date | null;
    };
    type StatusIn = { in: string[] };
    type Where = {
      status: string;
      session: {
        startAt: { gt: Date; lte: Date };
        status?: StatusIn;
        event?: { status?: StatusIn };
      };
    };

    const ok = (filter: StatusIn | undefined, value: string) =>
      !filter || filter.in.includes(value);

    function makeFilteringService(rows: Row[]) {
      const sent: string[] = [];
      const client = {
        salonRegistration: {
          findMany: async ({ where }: { where: Where }) =>
            rows.filter(
              (r) =>
                r.status === where.status &&
                r.session.startAt > where.session.startAt.gt &&
                r.session.startAt <= where.session.startAt.lte &&
                ok(where.session.status, r.session.status) &&
                ok(where.session.event?.status, r.session.event.status),
            ),
          update: async () => ({}),
        },
      };
      const prisma = {
        isEnabled: true,
        execute: async (fn: (c: typeof client) => unknown) => fn(client),
      } as unknown as PrismaService;
      const push = {
        sendToUser: async (userId: string) => {
          sent.push(userId);
          return true;
        },
      } as unknown as PushSenderService;
      return { service: new SalonReminderCronService(prisma, push), sent };
    }

    function row(
      id: string,
      minutesOut: number,
      statuses: { registration?: string; session?: string; event?: string } = {},
    ): Row {
      return {
        id,
        status: statuses.registration ?? 'registered',
        remindedAt: null,
        reminded1hAt: null,
        session: {
          startAt: new Date(Date.now() + minutesOut * 60 * 1000),
          status: statuses.session ?? 'scheduled',
          titleFr: 'Panel France',
          titleEn: 'France panel',
          event: { status: statuses.event ?? 'scheduled' },
        },
        user: { id: `user-${id}`, preferredLanguage: 'fr' },
      };
    }

    it('aucun rappel pour une session annulée (24 h comme 1 h)', async () => {
      const { service, sent } = makeFilteringService([
        row('day', 24 * 60, { session: 'cancelled' }),
        row('hour', 30, { session: 'cancelled' }),
      ]);
      const res = await service.run();
      expect(res).toEqual({ reminders24h: 0, reminders1h: 0 });
      expect(sent).toEqual([]);
    });

    it('aucun rappel quand tout l’événement est annulé (ou encore en brouillon)', async () => {
      const { service, sent } = makeFilteringService([
        row('cancelled-event', 24 * 60, { event: 'cancelled' }),
        row('draft-event', 30, { event: 'draft' }),
      ]);
      await service.run();
      expect(sent).toEqual([]);
    });

    it('aucun rappel pour une inscription annulée ou une session déjà terminée', async () => {
      const { service, sent } = makeFilteringService([
        row('unregistered', 24 * 60, { registration: 'cancelled' }),
        row('ended', 30, { session: 'ended' }),
      ]);
      await service.run();
      expect(sent).toEqual([]);
    });

    it('les sessions maintenues reçoivent toujours leur rappel', async () => {
      const { service, sent } = makeFilteringService([
        row('kept', 24 * 60),
        row('live', 30, { session: 'live', event: 'live' }),
        row('dropped', 30, { session: 'cancelled' }),
      ]);
      const res = await service.run();
      expect(res).toEqual({ reminders24h: 1, reminders1h: 1 });
      expect(sent.sort()).toEqual(['user-kept', 'user-live']);
    });
  });
});
