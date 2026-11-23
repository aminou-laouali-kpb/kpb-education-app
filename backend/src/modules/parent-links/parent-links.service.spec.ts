import { ConflictException, NotFoundException } from '@nestjs/common';

import { ParentLinksService } from './parent-links.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Audit 22 : deux élèves qui acceptent le même code en même temps recevaient
 * tous deux un 200 alors qu'un seul childId restait en base. L'activation est
 * désormais conditionnée à `status: 'pending'`.
 */
describe('ParentLinksService.accept — acceptation atomique', () => {
  function setup() {
    // Ligne partagée : simule la base vue par deux requêtes concurrentes.
    const row: Record<string, unknown> = {
      id: 'link-1',
      parentId: 'parent-1',
      childId: null,
      inviteCode: 'ABCD1234',
      status: 'pending',
    };
    const client = {
      userProfile: {
        findUnique: async ({ where }: { where: { id: string } }) => ({
          id: where.id,
          accountType: 'student',
        }),
      },
      parentChildLink: {
        // Instantané : les deux requêtes lisent `pending` avant toute écriture.
        findUnique: jest.fn(async () => ({ ...row })),
        updateMany: jest.fn(
          async ({ where, data }: { where: Record<string, unknown>; data: Record<string, unknown> }) => {
            if (where.id !== row.id || row.status !== where.status) return { count: 0 };
            Object.assign(row, data);
            return { count: 1 };
          },
        ),
        update: jest.fn(async () => {
          throw new Error('update non conditionnel interdit');
        }),
      },
    };
    const prisma = {
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { service: new ParentLinksService(prisma), row, client };
  }

  it('active le lien pour un seul élève quand deux acceptations se croisent', async () => {
    const { service, row } = setup();
    const results = await Promise.allSettled([
      service.accept('child-a', 'ABCD1234'),
      service.accept('child-b', 'ABCD1234'),
    ]);
    const ok = results.filter((r) => r.status === 'fulfilled');
    const ko = results.filter((r) => r.status === 'rejected');
    expect(ok).toHaveLength(1);
    expect(ko).toHaveLength(1);
    expect((ko[0] as PromiseRejectedResult).reason).toBeInstanceOf(ConflictException);
    // Le gagnant reçoit bien la ligne qui est en base.
    const winner = (ok[0] as PromiseFulfilledResult<Record<string, unknown>>).value;
    expect(winner.childId).toBe(row.childId);
    expect(row.status).toBe('active');
  });

  it('conditionne la mise à jour au statut `pending`', async () => {
    const { service, client } = setup();
    await service.accept('child-a', 'ABCD1234');
    expect(client.parentChildLink.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'link-1', status: 'pending' } }),
    );
  });

  it('404 pour un code déjà utilisé (lecture séquentielle)', async () => {
    const { service } = setup();
    await service.accept('child-a', 'ABCD1234');
    await expect(service.accept('child-b', 'ABCD1234')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
