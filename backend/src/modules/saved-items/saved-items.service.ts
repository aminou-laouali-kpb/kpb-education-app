import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import {
  isFollowUnified,
  SCHOLARSHIP_SAVED_ITEM_TYPE,
} from '../scholarships-index/scholarship-follow-state';
import { CreateSavedItemDto } from './dto/create-saved-item.dto';

/** Borne de lecture : une liste de favoris n'a pas de raison d'être illimitée. */
const SAVED_ITEMS_MAX = 1000;

@Injectable()
export class SavedItemsService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async findAll(userId: string) {
    this.assertDb();
    const items = await this.prismaService.execute((prisma) =>
      prisma.savedItem.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: SAVED_ITEMS_MAX,
      }),
    );
    return (items ?? []).map((item) => ({
      id: item.id,
      userId: item.userId,
      type: item.itemType,
      itemId: item.itemId,
      createdAt: item.createdAt.toISOString(),
    }));
  }

  async create(input: CreateSavedItemDto, userId: string) {
    this.assertDb();
    // Upsert atomique : la séquence lecture puis création renvoyait un 409
    // (contrainte unique) sur un double tap, au lieu d'être idempotente.
    const created = await this.prismaService.execute(async (prisma) => {
      const upsert = prisma.savedItem.upsert({
        where: {
          userId_itemType_itemId: {
            userId,
            itemType: input.type,
            itemId: input.itemId,
          },
        },
        create: { userId, itemType: input.type, itemId: input.itemId },
        update: {},
      });
      if (input.type !== SCHOLARSHIP_SAVED_ITEM_TYPE) return upsert;
      // Chantier C : le favori devient celui de l'étudiant. Sans cela,
      // « cloche allumée » (favori posé par la cloche), puis ce favori
      // explicite, puis « cloche éteinte » retirait le favori qu'il venait de
      // demander.
      const [row] = await prisma.$transaction([
        upsert,
        prisma.scholarshipAlertSubscription.updateMany({
          where: { userId, scholarshipId: input.itemId, impliedFollow: true },
          data: { impliedFollow: false },
        }),
      ]);
      return row;
    });
    if (!created) {
      throw new ServiceUnavailableException('Failed to persist saved item.');
    }
    return {
      id: created.id,
      userId: created.userId,
      type: created.itemType,
      itemId: created.itemId,
      createdAt: created.createdAt.toISOString(),
    };
  }

  async remove(id: string, userId: string) {
    this.assertDb();
    const unified = isFollowUnified();
    // Scope deletion to the owner: a missing item and another user's item
    // are both reported as not found (IDOR protection).
    const removed = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const item = await tx.savedItem.findFirst({
          where: { id, userId },
          select: { itemType: true, itemId: true },
        });
        if (!item) return false;
        const result = await tx.savedItem.deleteMany({ where: { id, userId } });
        if (result.count === 0) return false;
        if (item.itemType === SCHOLARSHIP_SAVED_ITEM_TYPE) {
          // Chantier C. Une alerte en sourdine n'existait que pour couper
          // l'annonce de ce favori : elle part avec lui, dans tous les modes.
          // En `outbox_followers`, « Suivre » est un seul geste : retirer le
          // favori retire aussi l'alerte.
          await tx.scholarshipAlertSubscription.deleteMany({
            where: {
              userId,
              scholarshipId: item.itemId,
              ...(unified ? {} : { mutedAt: { not: null } }),
            },
          });
        }
        return true;
      }),
    );
    if (!removed) {
      throw new NotFoundException(`Saved item ${id} not found.`);
    }
    return { id };
  }
}
