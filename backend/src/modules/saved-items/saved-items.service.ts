import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
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
    const created = await this.prismaService.execute((prisma) =>
      prisma.savedItem.upsert({
        where: {
          userId_itemType_itemId: {
            userId,
            itemType: input.type,
            itemId: input.itemId,
          },
        },
        create: { userId, itemType: input.type, itemId: input.itemId },
        update: {},
      }),
    );
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
    // Scope deletion to the owner: a missing item and another user's item
    // are both reported as not found (IDOR protection).
    const result = await this.prismaService.execute((prisma) =>
      prisma.savedItem.deleteMany({ where: { id, userId } }),
    );
    if (!result || result.count === 0) {
      throw new NotFoundException(`Saved item ${id} not found.`);
    }
    return { id };
  }
}
