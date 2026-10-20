import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { IsOptional, IsString, MaxLength } from 'class-validator';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

class PushOpenedDto {
  /** Campagne admin : la livraison push de cet élève reçoit `openedAt`. */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  campaignId?: string;

  /**
   * Rappel du fil, marqué lu. Deux formes acceptées : l'identifiant opaque de
   * la ligne (`UserNotification.id`, ce que le serveur envoie depuis l'audit
   * 57, F06) et l'ancienne `dedupeKey` (pushs déjà partis avant ce correctif).
   */
  @IsOptional()
  @IsString()
  @MaxLength(256)
  notificationKey?: string;
}

/**
 * Tap sur une notification push, signalé par l'application.
 *
 * Remplace les taux d'ouverture du tableau de bord OneSignal : avec FCM en
 * direct, personne d'autre que nous ne voit les ouvertures. Toujours borné à
 * l'élève connecté — on ne peut marquer ouverte que SA livraison ou SON rappel.
 * Idempotent : un second tap ne déplace pas la première date.
 */
@Controller('me/push-opens')
@UseGuards(StudentAuthGuard)
export class PushOpensController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  async opened(@Body() input: PushOpenedDto, @Req() req: any) {
    const userId = req.studentUser.id as string;
    const now = new Date();
    let campaign = 0;
    let reminder = 0;

    if (input.campaignId) {
      const result = await this.prisma.execute((p) =>
        p.notificationDelivery.updateMany({
          where: {
            campaignId: input.campaignId,
            recipientId: userId,
            channel: 'push',
            openedAt: null,
          },
          data: { openedAt: now },
        }),
      );
      campaign = result?.count ?? 0;
    }

    if (input.notificationKey) {
      const result = await this.prisma.execute((p) =>
        p.userNotification.updateMany({
          where: {
            userId,
            readAt: null,
            OR: [{ id: input.notificationKey }, { dedupeKey: input.notificationKey }],
          },
          data: { readAt: now },
        }),
      );
      reminder = result?.count ?? 0;
    }

    return { ok: true, updated: campaign + reminder };
  }
}
