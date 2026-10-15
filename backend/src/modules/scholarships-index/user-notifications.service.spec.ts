import { HttpStatus, RequestMethod, ServiceUnavailableException } from '@nestjs/common';
import {
  HTTP_CODE_METADATA,
  METHOD_METADATA,
  PATH_METADATA,
} from '@nestjs/common/constants';

import type { PrismaService } from '../prisma/prisma.service';
import { UserNotificationsController } from './user-notifications.controller';
import { UserNotificationsService } from './user-notifications.service';

type Args = Record<string, unknown>;

function make(opts: { count?: number; updated?: number; rows?: Args[] } = {}) {
  const calls: Record<'count' | 'updateMany' | 'findMany', Args[]> = {
    count: [],
    updateMany: [],
    findMany: [],
  };
  const client = {
    userNotification: {
      count: async (args: Args) => {
        calls.count.push(args);
        return opts.count ?? 0;
      },
      updateMany: async (args: Args) => {
        calls.updateMany.push(args);
        return { count: opts.updated ?? 0 };
      },
      findMany: async (args: Args) => {
        calls.findMany.push(args);
        return opts.rows ?? [];
      },
    },
  };
  const prisma = {
    isEnabled: true,
    execute: async <T>(fn: (c: typeof client) => Promise<T>) => fn(client),
  } as unknown as PrismaService;
  return { service: new UserNotificationsService(prisma), calls };
}

function handler(name: keyof UserNotificationsController): object {
  return Object.getOwnPropertyDescriptor(
    UserNotificationsController.prototype,
    name,
  )?.value as object;
}

describe('UserNotificationsService — badge et lecture par référence (chantier C)', () => {
  it('compte les non-lues de l’étudiant, sans rapatrier le fil', async () => {
    const { service, calls } = make({ count: 3 });

    await expect(service.unreadCount('usr-1')).resolves.toEqual({ unreadCount: 3 });
    expect(calls.count).toEqual([{ where: { userId: 'usr-1', readAt: null } }]);
    expect(calls.findMany).toEqual([]);
  });

  it('marque lues les entrées des références, toujours suffixées par l’étudiant connecté', async () => {
    const { service, calls } = make({ updated: 2 });

    await expect(
      service.markReadByRefs('usr-1', [
        'scholarship-opened:c1',
        'scholarship-opened:c2',
        'scholarship-opened:c1',
      ]),
    ).resolves.toEqual({ updated: 2 });

    expect(calls.updateMany).toEqual([
      {
        where: {
          userId: 'usr-1',
          readAt: null,
          dedupeKey: {
            in: ['scholarship-opened:c1:usr-1', 'scholarship-opened:c2:usr-1'],
          },
        },
        data: { readAt: expect.any(Date) },
      },
    ]);
  });

  it('une référence portant l’identifiant d’un autre étudiant ne vise que les entrées de l’appelant', async () => {
    const { service, calls } = make();

    // `scholarship-opened:c1:usr-2` (une dedupeKey complète d'un autre compte)
    // devient `…:usr-2:usr-1` : aucune ligne de usr-2 ne peut correspondre, et
    // `userId` borne de toute façon la mise à jour.
    await service.markReadByRefs('usr-1', ['scholarship-opened:c1:usr-2']);

    const where = calls.updateMany[0].where as {
      userId: string;
      dedupeKey: { in: string[] };
    };
    expect(where.userId).toBe('usr-1');
    expect(where.dedupeKey.in).toEqual(['scholarship-opened:c1:usr-2:usr-1']);
  });

  it('sans base configurée : 503, comme les autres routes du fil', async () => {
    const prisma = { isEnabled: false } as unknown as PrismaService;
    const service = new UserNotificationsService(prisma);
    await expect(service.unreadCount('usr-1')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    await expect(service.markReadByRefs('usr-1', ['r1'])).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('le fil existant garde sa forme', async () => {
    const createdAt = new Date('2026-10-15T08:00:00.000Z');
    const { service } = make({
      rows: [
        {
          id: 'n1',
          kind: 'scholarship_opened',
          scholarshipId: 'chevening',
          titleFr: 'C’est ouvert',
          titleEn: 'Applications are open',
          bodyFr: 'Corps',
          bodyEn: 'Body',
          route: '/scholarships/chevening',
          data: { cycleId: 'c1' },
          readAt: null,
          createdAt,
          pushStatus: 'pending',
          cycleId: 'c1',
        },
      ],
    });

    const result = await service.list('usr-1', 'fr');

    expect(Object.keys(result).sort()).toEqual(['items', 'unreadCount']);
    expect(result.items[0]).toEqual({
      id: 'n1',
      kind: 'scholarship_opened',
      scholarshipId: 'chevening',
      title: 'C’est ouvert',
      body: 'Corps',
      route: '/scholarships/chevening',
      data: { cycleId: 'c1' },
      readAt: null,
      createdAt: createdAt.toISOString(),
    });
  });
});

describe('UserNotificationsController — routes', () => {
  it('GET unread-count et POST read-by-ref (200), sans toucher aux routes existantes', () => {
    expect(Reflect.getMetadata(PATH_METADATA, handler('unreadCount'))).toBe('unread-count');
    expect(Reflect.getMetadata(METHOD_METADATA, handler('unreadCount'))).toBe(RequestMethod.GET);

    expect(Reflect.getMetadata(PATH_METADATA, handler('markReadByRefs'))).toBe('read-by-ref');
    expect(Reflect.getMetadata(METHOD_METADATA, handler('markReadByRefs'))).toBe(
      RequestMethod.POST,
    );
    expect(Reflect.getMetadata(HTTP_CODE_METADATA, handler('markReadByRefs'))).toBe(
      HttpStatus.OK,
    );

    expect(Reflect.getMetadata(PATH_METADATA, handler('list'))).toBe('/');
    expect(Reflect.getMetadata(PATH_METADATA, handler('markRead'))).toBe(':id/read');
    expect(Reflect.getMetadata(PATH_METADATA, handler('markAllRead'))).toBe('read-all');
    // `read-all` garde son 201 d'origine.
    expect(Reflect.getMetadata(HTTP_CODE_METADATA, handler('markAllRead'))).toBeUndefined();
  });

  it('passe l’étudiant connecté et ses références au service', async () => {
    const service = {
      markReadByRefs: jest.fn(async () => ({ updated: 1 })),
      unreadCount: jest.fn(async () => ({ unreadCount: 4 })),
    } as unknown as UserNotificationsService;
    const controller = new UserNotificationsController(service);
    const req = { studentUser: { id: 'usr-9' } };

    await expect(controller.unreadCount(req)).resolves.toEqual({ unreadCount: 4 });
    await controller.markReadByRefs({ refs: ['scholarship-opened:c1'] }, req);

    expect(service.unreadCount).toHaveBeenCalledWith('usr-9');
    expect(service.markReadByRefs).toHaveBeenCalledWith('usr-9', ['scholarship-opened:c1']);
  });
});
