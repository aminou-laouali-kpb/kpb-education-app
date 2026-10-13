import { PrismaService } from '../prisma/prisma.service';
import { PushOpensController } from './push-opens.controller';

function makePrisma() {
  const deliveryUpdate = jest.fn(async () => ({ count: 1 }));
  const reminderUpdate = jest.fn(async () => ({ count: 1 }));
  const prisma = {
    execute: jest.fn(async (op: (p: unknown) => Promise<unknown>) =>
      op({
        notificationDelivery: { updateMany: deliveryUpdate },
        userNotification: { updateMany: reminderUpdate },
      }),
    ),
  } as unknown as PrismaService;
  return { prisma, deliveryUpdate, reminderUpdate };
}

const req = { studentUser: { id: 'usr-42' } };

describe('PushOpensController', () => {
  // Borné à l'élève connecté : on ne peut marquer ouverte que SA livraison.
  it('marque ouverte la livraison push de cet élève, une seule fois', async () => {
    const { prisma, deliveryUpdate, reminderUpdate } = makePrisma();
    const result = await new PushOpensController(prisma).opened(
      { campaignId: 'camp-1' },
      req,
    );

    expect(result).toEqual({ ok: true, updated: 1 });
    expect(deliveryUpdate).toHaveBeenCalledWith({
      where: {
        campaignId: 'camp-1',
        recipientId: 'usr-42',
        channel: 'push',
        openedAt: null,
      },
      data: { openedAt: expect.any(Date) },
    });
    expect(reminderUpdate).not.toHaveBeenCalled();
  });

  it('marque lu le rappel du fil de cet élève', async () => {
    const { prisma, deliveryUpdate, reminderUpdate } = makePrisma();
    await new PushOpensController(prisma).opened(
      { notificationKey: 'deadline:usr-42:sch-9:7' },
      req,
    );

    expect(reminderUpdate).toHaveBeenCalledWith({
      where: {
        dedupeKey: 'deadline:usr-42:sch-9:7',
        userId: 'usr-42',
        readAt: null,
      },
      data: { readAt: expect.any(Date) },
    });
    expect(deliveryUpdate).not.toHaveBeenCalled();
  });

  it('ne touche à rien sans identifiant', async () => {
    const { prisma, deliveryUpdate, reminderUpdate } = makePrisma();
    await expect(
      new PushOpensController(prisma).opened({}, req),
    ).resolves.toEqual({ ok: true, updated: 0 });
    expect(deliveryUpdate).not.toHaveBeenCalled();
    expect(reminderUpdate).not.toHaveBeenCalled();
  });
});
