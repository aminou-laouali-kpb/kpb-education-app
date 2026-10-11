import { PrismaService } from '../prisma/prisma.service';
import { SavedItemsService } from './saved-items.service';

describe('SavedItemsService', () => {
  function make() {
    const calls: Record<string, any[]> = { upsert: [], findMany: [] };
    const row = {
      id: 's1',
      userId: 'u1',
      itemType: 'program',
      itemId: 'p1',
      createdAt: new Date('2026-10-01T00:00:00Z'),
    };
    const client = {
      savedItem: {
        upsert: async (args: any) => {
          calls.upsert.push(args);
          return row;
        },
        findMany: async (args: any) => {
          calls.findMany.push(args);
          return [row];
        },
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
    const a = await service.create({ type: 'program', itemId: 'p1' } as any, 'u1');
    const b = await service.create({ type: 'program', itemId: 'p1' } as any, 'u1');
    expect(a.id).toBe(b.id);
    expect(calls.upsert[0]).toMatchObject({ update: {} });
  });

  it('bounds the list read', async () => {
    const { service, calls } = make();
    await service.findAll('u1');
    expect(calls.findMany[0].take).toBe(1000);
  });
});
