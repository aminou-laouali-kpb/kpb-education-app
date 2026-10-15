import { NotFoundException } from '@nestjs/common';

import { SCHOLARSHIP_OPENING_MODE_ENV } from '../scholarships-index/opening/scholarship-opening.contract';
import { PrismaService } from '../prisma/prisma.service';
import { SavedItemsService } from './saved-items.service';

type Args = Record<string, unknown>;

describe('SavedItemsService', () => {
  const previousMode = process.env[SCHOLARSHIP_OPENING_MODE_ENV];
  afterEach(() => {
    if (previousMode === undefined) delete process.env[SCHOLARSHIP_OPENING_MODE_ENV];
    else process.env[SCHOLARSHIP_OPENING_MODE_ENV] = previousMode;
  });

  function make(
    stored: { itemType: string; itemId: string } | null = {
      itemType: 'program',
      itemId: 'p1',
    },
  ) {
    const calls: Record<string, Args[]> = {
      upsert: [],
      findMany: [],
      findFirst: [],
      deleteMany: [],
      alertUpdateMany: [],
      alertDeleteMany: [],
      transaction: [],
    };
    const row = {
      id: 's1',
      userId: 'u1',
      itemType: 'program',
      itemId: 'p1',
      createdAt: new Date('2026-10-01T00:00:00Z'),
    };
    const client = {
      savedItem: {
        upsert: async (args: Args) => {
          calls.upsert.push(args);
          const create = args.create as { itemType: string; itemId: string };
          return { ...row, itemType: create.itemType, itemId: create.itemId };
        },
        findMany: async (args: Args) => {
          calls.findMany.push(args);
          return [row];
        },
        findFirst: async (args: Args) => {
          calls.findFirst.push(args);
          return stored;
        },
        deleteMany: async (args: Args) => {
          calls.deleteMany.push(args);
          return { count: stored ? 1 : 0 };
        },
      },
      scholarshipAlertSubscription: {
        updateMany: async (args: Args) => {
          calls.alertUpdateMany.push(args);
          return { count: 1 };
        },
        deleteMany: async (args: Args) => {
          calls.alertDeleteMany.push(args);
          return { count: 1 };
        },
      },
      $transaction: async (arg: unknown): Promise<unknown> => {
        calls.transaction.push({ kind: typeof arg });
        return typeof arg === 'function'
          ? (arg as (tx: typeof client) => Promise<unknown>)(client)
          : Promise.all(arg as Promise<unknown>[]);
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new SavedItemsService(prisma), calls };
  }

  it('creates idempotently with a single upsert (double tap = same row, no 409)', async () => {
    const { service, calls } = make();
    const a = await service.create({ type: 'program', itemId: 'p1' }, 'u1');
    const b = await service.create({ type: 'program', itemId: 'p1' }, 'u1');
    expect(a.id).toBe(b.id);
    expect(calls.upsert[0]).toMatchObject({ update: {} });
  });

  it('a non-scholarship save is the same single upsert as before: no transaction, no alert write', async () => {
    const { service, calls } = make();
    const created = await service.create({ type: 'program', itemId: 'p1' }, 'u1');
    expect(created).toEqual({
      id: 's1',
      userId: 'u1',
      type: 'program',
      itemId: 'p1',
      createdAt: '2026-10-01T00:00:00.000Z',
    });
    expect(calls.transaction).toEqual([]);
    expect(calls.alertUpdateMany).toEqual([]);
  });

  // Chantier C : cloche allumée (favori posé par la cloche), puis favori
  // explicite, puis cloche éteinte — le favori demandé ne doit pas partir.
  it('a scholarship save makes the favourite the student’s own (impliedFollow cleared), same response', async () => {
    const { service, calls } = make();
    const created = await service.create(
      { type: 'scholarship', itemId: 'chevening' },
      'u1',
    );
    expect(Object.keys(created).sort()).toEqual([
      'createdAt',
      'id',
      'itemId',
      'type',
      'userId',
    ]);
    expect(created.type).toBe('scholarship');
    expect(calls.transaction).toEqual([{ kind: 'object' }]);
    expect(calls.alertUpdateMany).toEqual([
      {
        where: { userId: 'u1', scholarshipId: 'chevening', impliedFollow: true },
        data: { impliedFollow: false },
      },
    ]);
  });

  it('bounds the list read', async () => {
    const { service, calls } = make();
    await service.findAll('u1');
    expect(calls.findMany[0].take).toBe(1000);
  });

  describe('remove', () => {
    it('reads and deletes scoped to the owner; another user’s item is a 404', async () => {
      const { service, calls } = make(null);
      await expect(service.remove('s1', 'u1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(calls.findFirst[0]).toMatchObject({ where: { id: 's1', userId: 'u1' } });
      expect(calls.deleteMany).toEqual([]);
    });

    it('a program favourite: same response, no alert touched', async () => {
      const { service, calls } = make();
      await expect(service.remove('s1', 'u1')).resolves.toEqual({ id: 's1' });
      expect(calls.deleteMany).toEqual([{ where: { id: 's1', userId: 'u1' } }]);
      expect(calls.alertDeleteMany).toEqual([]);
    });

    it.each(['legacy', 'outbox_alerts'])(
      'a scholarship favourite in %s: only its muted alert goes with it',
      async (mode) => {
        process.env[SCHOLARSHIP_OPENING_MODE_ENV] = mode;
        const { service, calls } = make({ itemType: 'scholarship', itemId: 'chevening' });
        await service.remove('s1', 'u1');
        expect(calls.alertDeleteMany).toEqual([
          {
            where: {
              userId: 'u1',
              scholarshipId: 'chevening',
              mutedAt: { not: null },
            },
          },
        ]);
      },
    );

    it('a scholarship favourite in outbox_followers: any alert goes with it', async () => {
      process.env[SCHOLARSHIP_OPENING_MODE_ENV] = 'outbox_followers';
      const { service, calls } = make({ itemType: 'scholarship', itemId: 'chevening' });
      await service.remove('s1', 'u1');
      expect(calls.alertDeleteMany).toEqual([
        { where: { userId: 'u1', scholarshipId: 'chevening' } },
      ]);
    });
  });
});
