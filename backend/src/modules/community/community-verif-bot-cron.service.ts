import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { CommunityVerifBotService } from './community-verif-bot.service';
import { verifBotMode } from './community-verif-bot.config';

/**
 * Bot « Vérif » (C3) — la tâche de la minute : marque obsolètes les brouillons
 * dont la publication n'est plus visible, puis traite la file (détection,
 * faits, texte ; publication seule en mode `auto`). Un passage à la fois ; une
 * erreur est journalisée, jamais propagée. `off` : rien.
 */
@Injectable()
export class CommunityVerifBotCronService {
  private readonly logger = new Logger(CommunityVerifBotCronService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly bot: CommunityVerifBotService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async run(): Promise<void> {
    if (!this.prisma.isEnabled || verifBotMode() === 'off' || this.running) return;
    this.running = true;
    try {
      const { processed, proposed, autoPublished } = await this.bot.processQueue();
      if (processed > 0) {
        this.logger.log(`Bot Vérif : ${processed} traité(s), ${proposed} proposé(s), ${autoPublished} publié(s) seul(s).`);
      }
    } catch (error) {
      this.logger.error(`Bot Vérif en échec : ${error instanceof Error ? error.name : 'erreur'}`);
    } finally {
      this.running = false;
    }
  }
}
