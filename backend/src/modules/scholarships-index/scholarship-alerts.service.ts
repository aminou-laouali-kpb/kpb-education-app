import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import type { ScholarshipAlertPreferenceResponse } from './opening/scholarship-opening.contract';
import {
  alertFacts,
  followFlags,
  isFollowUnified,
  SCHOLARSHIP_SAVED_ITEM_TYPE,
  type FollowFlags,
} from './scholarship-follow-state';

/**
 * La cloche « M'avertir » d'une bourse (chantier C : « Suivre » = favori +
 * alerte d'ouverture + rappels).
 *
 * Les builds 53/56 ne connaissent que la cloche (POST / DELETE) et lisent son
 * état dans `GET /me/scholarship-alerts`, `isAlertEnabled` et `alert.*` : une
 * alerte en sourdine y est donc une cloche éteinte. Les builds récentes
 * passent par le PATCH, qui dit `notifyOpening` sans toucher au favori.
 *
 * Règles (tous modes, sauf mention) :
 * - cloche allumée : l'alerte perd sa sourdine ; en `outbox_followers`, le
 *   favori est posé aussi, `impliedFollow` seulement si c'est cet appel qui l'a
 *   créé ;
 * - cloche éteinte : favori posé par la cloche → alerte et favori retirés (on
 *   défait exactement ce qu'elle a fait) ; favori de l'étudiant → sourdine ;
 *   sinon l'alerte est supprimée, comme avant.
 */
@Injectable()
export class ScholarshipAlertsService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async list(userId: string) {
    this.assertDb();
    const rows = await this.prismaService.execute((prisma) =>
      prisma.scholarshipAlertSubscription.findMany({
        // Une alerte en sourdine est une cloche éteinte pour les builds 53/56.
        where: { userId, mutedAt: null },
        select: {
          id: true,
          scholarshipId: true,
          pushEnabled: true,
          inAppEnabled: true,
          createdAt: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
    );
    return {
      items: (rows ?? []).map((row) => ({
        ...row,
        createdAt: row.createdAt.toISOString(),
      })),
    };
  }

  async subscribe(userId: string, scholarshipId: string) {
    this.assertDb();
    const unified = isFollowUnified();
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        if (!(await this.isFollowable(tx, scholarshipId))) return null;
        await this.turnBellOn(tx, userId, scholarshipId, unified);
        return true;
      }),
    );
    if (!result) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }
    return { scholarshipId, subscribed: true };
  }

  async unsubscribe(userId: string, scholarshipId: string) {
    this.assertDb();
    const now = new Date();
    await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const alert = await tx.scholarshipAlertSubscription.findUnique({
          where: { userId_scholarshipId: { userId, scholarshipId } },
          select: { impliedFollow: true },
        });
        if (alert?.impliedFollow) {
          await tx.scholarshipAlertSubscription.deleteMany({
            where: { userId, scholarshipId },
          });
          await tx.savedItem.deleteMany({
            where: {
              userId,
              itemType: SCHOLARSHIP_SAVED_ITEM_TYPE,
              itemId: scholarshipId,
            },
          });
          return;
        }
        const favorite = await tx.savedItem.findUnique({
          where: {
            userId_itemType_itemId: {
              userId,
              itemType: SCHOLARSHIP_SAVED_ITEM_TYPE,
              itemId: scholarshipId,
            },
          },
          select: { id: true },
        });
        if (favorite) {
          // Le favori est celui de l'étudiant : on ne le retire pas, on coupe
          // l'annonce. Un favori orphelin (bourse supprimée) n'a plus d'alerte
          // possible : rien à couper.
          if (alert || (await this.exists(tx, scholarshipId))) {
            await this.mute(tx, userId, scholarshipId, alert !== null, now);
          }
          return;
        }
        await tx.scholarshipAlertSubscription.deleteMany({
          where: { userId, scholarshipId },
        });
      }),
    );
    return { scholarshipId, subscribed: false };
  }

  /**
   * `PATCH /me/scholarship-alerts/:scholarshipId` (builds récentes).
   * `notifyOpening: false` met l'annonce en sourdine sans retirer le favori :
   * la bourse reste suivie (rappels, liste). `true` vaut la cloche allumée.
   * `following` est relu après l'écriture, jamais supposé.
   */
  async updatePreference(
    userId: string,
    scholarshipId: string,
    notifyOpening: boolean,
  ): Promise<ScholarshipAlertPreferenceResponse> {
    this.assertDb();
    const unified = isFollowUnified();
    const now = new Date();
    const flags = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        if (!(await this.isFollowable(tx, scholarshipId))) return null;
        if (notifyOpening) {
          await this.turnBellOn(tx, userId, scholarshipId, unified);
        } else {
          const alert = await tx.scholarshipAlertSubscription.findUnique({
            where: { userId_scholarshipId: { userId, scholarshipId } },
            select: { id: true },
          });
          await this.mute(tx, userId, scholarshipId, alert !== null, now);
        }
        return this.readFlags(tx, userId, scholarshipId);
      }),
    );
    if (!flags) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }
    return {
      scholarshipId,
      following: flags.following,
      notifyOpening: flags.notifyOpening,
    };
  }

  /** Même porte que la cloche d'avant : une bourse approuvée et active. */
  private async isFollowable(
    tx: Prisma.TransactionClient,
    scholarshipId: string,
  ): Promise<boolean> {
    const scholarship = await tx.scholarship.findFirst({
      where: { id: scholarshipId, moderationStatus: 'approved', isActive: true },
      select: { id: true },
    });
    return scholarship !== null;
  }

  private async exists(
    tx: Prisma.TransactionClient,
    scholarshipId: string,
  ): Promise<boolean> {
    const scholarship = await tx.scholarship.findUnique({
      where: { id: scholarshipId },
      select: { id: true },
    });
    return scholarship !== null;
  }

  private async turnBellOn(
    tx: Prisma.TransactionClient,
    userId: string,
    scholarshipId: string,
    unified: boolean,
  ): Promise<void> {
    let createdFavorite = false;
    if (unified) {
      // `skipDuplicates` : le compte dit si CET appel a créé le favori. Un
      // favori déjà là est celui de l'étudiant, la cloche ne se l'approprie pas.
      const created = await tx.savedItem.createMany({
        data: [
          {
            userId,
            itemType: SCHOLARSHIP_SAVED_ITEM_TYPE,
            itemId: scholarshipId,
          },
        ],
        skipDuplicates: true,
      });
      createdFavorite = created.count === 1;
    }
    await tx.scholarshipAlertSubscription.upsert({
      where: { userId_scholarshipId: { userId, scholarshipId } },
      create: { userId, scholarshipId, impliedFollow: createdFavorite },
      update: {
        pushEnabled: true,
        inAppEnabled: true,
        mutedAt: null,
        ...(createdFavorite ? { impliedFollow: true } : {}),
      },
    });
  }

  /** Pose la sourdine ; une sourdine déjà posée garde sa date. */
  private async mute(
    tx: Prisma.TransactionClient,
    userId: string,
    scholarshipId: string,
    alertExists: boolean,
    now: Date,
  ): Promise<void> {
    if (alertExists) {
      await tx.scholarshipAlertSubscription.updateMany({
        where: { userId, scholarshipId, mutedAt: null },
        data: { mutedAt: now },
      });
      return;
    }
    await tx.scholarshipAlertSubscription.createMany({
      data: [{ userId, scholarshipId, mutedAt: now }],
      skipDuplicates: true,
    });
  }

  private async readFlags(
    tx: Prisma.TransactionClient,
    userId: string,
    scholarshipId: string,
  ): Promise<FollowFlags> {
    const favorite = await tx.savedItem.findUnique({
      where: {
        userId_itemType_itemId: {
          userId,
          itemType: SCHOLARSHIP_SAVED_ITEM_TYPE,
          itemId: scholarshipId,
        },
      },
      select: { id: true },
    });
    const alert = await tx.scholarshipAlertSubscription.findUnique({
      where: { userId_scholarshipId: { userId, scholarshipId } },
      select: { mutedAt: true },
    });
    return followFlags({ favorite: favorite !== null, ...alertFacts(alert) });
  }
}
