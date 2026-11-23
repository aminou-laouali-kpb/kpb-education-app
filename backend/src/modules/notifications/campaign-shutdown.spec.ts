import { BeforeApplicationShutdown, Injectable } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { CasesService } from '../cases/cases.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  CampaignExecutorService,
  startCampaignHeartbeat,
} from './campaign-executor.service';
import { NotificationsService } from './notifications.service';

/**
 * Arrêt de l'application pendant un envoi immédiat (revue de b472d59).
 *
 * Les envois tournent hors requête : l'arrêt doit les attendre au plus tôt.
 * Dans Nest 11, `close()` enchaîne onModuleDestroy → beforeApplicationShutdown
 * → fermeture HTTP → onApplicationShutdown ; l'ancien `onApplicationShutdown`
 * attendait donc après tout le reste. Ce test monte un vrai contexte Nest
 * (même module, comme `AppModule`) et vérifie que l'envoi est terminé avant
 * même la phase `beforeApplicationShutdown`.
 */
describe('NotificationsService — arrêt pendant un envoi', () => {
  it('l’arrêt attend la fin de l’envoi dès onModuleDestroy', async () => {
    const events: string[] = [];
    let finishSend!: () => void;
    const sendGate = new Promise<void>((r) => (finishSend = r));

    const rows: Array<{ id: string; status: string }> = [];
    const client = {
      notificationCampaign: {
        findMany: async () => [],
        create: async ({ data }: { data: { status: string } }) => {
          const row = { ...data, id: 'c1', createdAt: new Date() };
          rows.push(row);
          return row;
        },
        findUnique: async () => rows[0],
        updateMany: async ({ data }: { data: { status: string } }) => {
          rows[0].status = data.status;
          return { count: 1 };
        },
      },
      $transaction: async (fn: (tx: unknown) => Promise<unknown>) =>
        fn({ ...client, $executeRaw: async () => 1 }),
    };

    @Injectable()
    class FakePrisma {
      isEnabled = true;
      execute = async (fn: (c: typeof client) => unknown) => fn(client);
      tryExecute = async (fn: (c: typeof client) => unknown) => fn(client);
      async onModuleDestroy() {
        events.push('prisma-disconnect');
      }
    }

    @Injectable()
    class Sentinel implements BeforeApplicationShutdown {
      beforeApplicationShutdown() {
        events.push('before-application-shutdown');
      }
    }

    const executor = {
      execute: async () => {
        await sendGate;
        events.push('send-done');
        return { enqueued: 1 };
      },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        NotificationsService,
        Sentinel,
        { provide: PrismaService, useClass: FakePrisma },
        { provide: CasesService, useValue: {} },
        { provide: CampaignExecutorService, useValue: executor },
      ],
    }).compile();
    await moduleRef.init();

    const service = moduleRef.get(NotificationsService);
    const created = await service.createCampaign({
      name: 'Arrêt',
      templateId: 'tpl-1',
      audienceType: 'all_users',
      channels: ['push'],
    });
    expect(created.status).toBe('sending');

    let closed = false;
    const closing = moduleRef.close().then(() => {
      closed = true;
    });
    await new Promise((r) => setImmediate(r));
    expect(closed).toBe(false);

    finishSend();
    await closing;

    expect(events.indexOf('send-done')).toBeGreaterThanOrEqual(0);
    expect(events.indexOf('send-done')).toBeLessThan(
      events.indexOf('before-application-shutdown'),
    );
  });
});

describe('startCampaignHeartbeat', () => {
  afterEach(() => jest.useRealTimers());

  it('rafraîchit updatedAt (si toujours sending) à chaque période, jusqu’à l’arrêt', async () => {
    jest.useFakeTimers();
    const calls: Array<Record<string, unknown>> = [];
    const prisma = {
      tryExecute: async (
        fn: (c: {
          notificationCampaign: { updateMany: (a: Record<string, unknown>) => unknown };
        }) => unknown,
      ) =>
        fn({
          notificationCampaign: {
            updateMany: (args) => {
              calls.push(args);
              return { count: 1 };
            },
          },
        }),
    } as unknown as PrismaService;

    const stop = startCampaignHeartbeat(prisma, 'c1', 1000);
    jest.advanceTimersByTime(3500);
    expect(calls).toHaveLength(3);
    expect(calls[0]).toMatchObject({
      where: { id: 'c1', status: 'sending' },
      data: { updatedAt: expect.any(Date) },
    });

    stop();
    jest.advanceTimersByTime(5000);
    expect(calls).toHaveLength(3);
  });
});
