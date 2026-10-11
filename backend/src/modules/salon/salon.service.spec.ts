import { ConflictException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { SalonService } from './salon.service';

function makeService(registrations: Array<Record<string, unknown>>, capacity = 1) {
  const calls: Record<string, unknown[]> = { create: [], update: [] };
  const client = {
    salonSession: {
      findUnique: async () => ({ id: 's1', status: 'scheduled', capacity, registrations }),
    },
    salonRegistration: {
      create: async (args: any) => {
        calls.create.push(args);
        return { id: 'new', ...args.data };
      },
      update: async (args: any) => {
        calls.update.push(args);
        return { id: args.where.id, ...args.data };
      },
    },
  };
  const prisma = {
    execute: async (fn: (c: typeof client) => unknown) => fn(client),
  } as unknown as PrismaService;
  return { service: new SalonService(prisma), calls };
}

describe('SalonService.register', () => {
  it('reactivates a cancelled registration instead of returning it', async () => {
    const { service, calls } = makeService([
      { id: 'r1', userId: 'u1', status: 'cancelled' },
    ]);
    const result = await service.register('u1', 's1');
    expect(result).toMatchObject({ id: 'r1', status: 'registered' });
    expect(calls.update).toHaveLength(1);
    expect(calls.create).toHaveLength(0);
  });

  it('does not count cancelled registrations against capacity', async () => {
    const { service } = makeService([
      { id: 'r1', userId: 'other', status: 'cancelled' },
    ]);
    await expect(service.register('u1', 's1')).resolves.toMatchObject({
      status: 'registered',
    });
  });

  it('still refuses when active registrations fill the session', async () => {
    const { service } = makeService([
      { id: 'r1', userId: 'other', status: 'registered' },
    ]);
    await expect(service.register('u1', 's1')).rejects.toBeInstanceOf(ConflictException);
  });
});
