import { CasesService } from '../cases/cases.service';
import { PrismaService } from '../prisma/prisma.service';
import { CampaignExecutorService } from './campaign-executor.service';
import { CreateNotificationCampaignDto } from './dto/create-notification-campaign.dto';
import { NotificationsService } from './notifications.service';

/**
 * Audit §12 — une campagne immédiate ne part qu'UNE fois.
 *
 * Avant : la requête POST exécutait l'envoi complet avant de répondre ; un
 * double clic, ou une relance après délai dépassé, créait une seconde campagne
 * identique et toute la base recevait le message deux fois.
 *
 * Ce faux client reproduit les deux garanties sur lesquelles le correctif
 * s'appuie : `pg_advisory_xact_lock` (tenu jusqu'à la fin de la transaction) et
 * `UPDATE … WHERE status = …` (vérification et écriture d'un seul tenant).
 */
describe('NotificationsService.createCampaign — idempotence', () => {
  type Row = {
    id: string;
    name: string;
    templateId: string | null;
    audienceType: string;
    filters: Record<string, unknown>;
    channels: string[];
    scheduledFor: Date | null;
    status: string;
    linkedCaseId: string | null;
    route: string | null;
    purpose: string;
    createdAt: Date;
  };

  function makeDb() {
    const rows: Row[] = [];
    const locks = new Map<string, Promise<void>>();
    let seq = 0;

    const matches = (row: Row, where: Record<string, unknown>) =>
      Object.entries(where).every(([key, cond]) => {
        const value = row[key as keyof Row];
        if (cond && typeof cond === 'object' && !(cond instanceof Date)) {
          const c = cond as { not?: unknown; gte?: Date };
          if ('not' in c) return value !== c.not;
          if (c.gte) return (value as Date) >= c.gte;
          return true;
        }
        if (cond instanceof Date) {
          return value instanceof Date && value.getTime() === cond.getTime();
        }
        return value === cond;
      });

    const notificationCampaign = {
      findMany: async ({ where }: { where: Record<string, unknown> }) => {
        // Laisse la main : une requête concurrente peut avancer entre deux
        // instructions, comme sur une vraie connexion.
        await new Promise((r) => setImmediate(r));
        return rows.filter((r) => matches(r, where)).map((r) => ({ ...r }));
      },
      findUnique: async ({ where }: { where: { id: string } }) => {
        const row = rows.find((r) => r.id === where.id);
        return row ? { ...row } : null;
      },
      create: async ({ data }: { data: Omit<Row, 'id' | 'createdAt'> }) => {
        await new Promise((r) => setImmediate(r));
        const row: Row = { ...data, id: `c${++seq}`, createdAt: new Date() };
        rows.push(row);
        return { ...row };
      },
      updateMany: async ({
        where,
        data,
      }: {
        where: Record<string, unknown>;
        data: { status: string };
      }) => {
        const hit = rows.filter((r) => matches(r, where));
        hit.forEach((r) => (r.status = data.status));
        return { count: hit.length };
      },
      update: async ({
        where,
        data,
      }: {
        where: { id: string };
        data: { status: string };
      }) => {
        const row = rows.find((r) => r.id === where.id)!;
        row.status = data.status;
        return { ...row };
      },
    };

    const client = {
      notificationCampaign,
      // Transaction interactive : les verrous consultatifs pris dedans sont
      // relâchés à sa fin, comme `pg_advisory_xact_lock`.
      $transaction: async <T>(fn: (tx: unknown) => Promise<T>) => {
        const held: Array<() => void> = [];
        const tx = {
          notificationCampaign,
          $executeRaw: async (_sql: TemplateStringsArray, key: string) => {
            while (locks.has(key)) await locks.get(key);
            let release!: () => void;
            locks.set(key, new Promise<void>((r) => (release = r)));
            held.push(() => {
              locks.delete(key);
              release();
            });
            return 1;
          },
        };
        try {
          return await fn(tx);
        } finally {
          held.forEach((release) => release());
        }
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
      tryExecute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, rows };
  }

  function makeService() {
    const db = makeDb();
    const executed: string[] = [];
    let finishSend!: () => void;
    const sendGate = new Promise<void>((r) => (finishSend = r));
    const executor = {
      execute: jest.fn(async (id: string) => {
        executed.push(id);
        await sendGate;
        db.rows.find((r) => r.id === id)!.status = 'completed';
        return { enqueued: 1 };
      }),
    } as unknown as CampaignExecutorService;
    const service = new NotificationsService(
      {} as CasesService,
      db.prisma,
      executor,
    );
    return { service, db, executed, finishSend, executor };
  }

  const form: CreateNotificationCampaignDto = {
    name: 'Bourses 2027 ouvertes',
    templateId: 'tpl-1',
    audienceType: 'all_users',
    filters: {},
    channels: ['push'],
    purpose: 'informational',
  };

  it('double soumission concurrente → une seule campagne, un seul envoi', async () => {
    const { service, db, executed, finishSend } = makeService();

    const [first, second] = await Promise.all([
      service.createCampaign({ ...form }),
      service.createCampaign({ ...form }),
    ]);
    finishSend();
    await service.waitForInFlightCampaigns();

    expect(db.rows).toHaveLength(1);
    expect(second.id).toBe(first.id);
    expect([first.duplicate, second.duplicate].sort()).toEqual([false, true]);
    expect(executed).toEqual([first.id]);
    expect(db.rows[0].status).toBe('completed');
  });

  it('une relance après coup renvoie la campagne existante et son statut courant', async () => {
    const { service, db, executed, finishSend } = makeService();

    const first = await service.createCampaign({ ...form });
    // L'envoi tourne encore : la requête a répondu sans l'attendre.
    expect(first.status).toBe('sending');
    expect(first.duplicate).toBe(false);

    const retry = await service.createCampaign({ ...form });
    expect(retry).toMatchObject({ id: first.id, status: 'sending', duplicate: true });

    finishSend();
    await service.waitForInFlightCampaigns();
    expect(executed).toEqual([first.id]);
    expect(db.rows).toHaveLength(1);
  });

  it('une campagne en échec peut être resoumise (nouvelle campagne)', async () => {
    const { service, db, executed, finishSend } = makeService();
    finishSend();

    const first = await service.createCampaign({ ...form });
    await service.waitForInFlightCampaigns();
    db.rows[0].status = 'failed';

    const again = await service.createCampaign({ ...form });
    await service.waitForInFlightCampaigns();

    expect(again.id).not.toBe(first.id);
    expect(again.duplicate).toBe(false);
    expect(executed).toEqual([first.id, again.id]);
  });

  it('un formulaire différent n’est pas pris pour un doublon', async () => {
    const { service, executed, finishSend } = makeService();
    finishSend();

    const a = await service.createCampaign({ ...form });
    const b = await service.createCampaign({ ...form, channels: ['push', 'email'] });
    await service.waitForInFlightCampaigns();

    expect(b.id).not.toBe(a.id);
    expect(executed).toEqual([a.id, b.id]);
  });

  it('une campagne programmée reste au cron : la requête ne l’exécute pas', async () => {
    const { service, db, executed, finishSend } = makeService();
    finishSend();

    const created = await service.createCampaign({
      ...form,
      scheduledFor: new Date(Date.now() + 3_600_000).toISOString(),
    });
    await service.waitForInFlightCampaigns();
    expect(created.status).toBe('scheduled');
    expect(executed).toEqual([]);
    expect(db.rows[0].status).toBe('scheduled');
  });

  it('un échec d’exécution passe la campagne à failed (jamais bloquée en sending)', async () => {
    const { service, db, executor } = makeService();
    (executor.execute as jest.Mock).mockRejectedValueOnce(new Error('boom'));

    await service.createCampaign({ ...form });
    await service.waitForInFlightCampaigns();

    expect(db.rows[0].status).toBe('failed');
  });
});
