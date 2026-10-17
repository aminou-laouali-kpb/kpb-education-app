import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { assistBridgeMode } from './assist-bridge.config';
import { AssistBridgeService } from './assist-bridge.service';

/**
 * Bot « Passerelle » (C3 bis) — la tâche de la minute (garde-fous, puis envoi
 * en mode `on` ou journal en mode `shadow`) et la purge quotidienne (12 mois).
 * Un passage à la fois ; une erreur est journalisée, jamais propagée. `off` :
 * aucun traitement (la purge, elle, continue : la conservation ne dépend pas
 * du mode).
 */
@Injectable()
export class AssistBridgeCronService {
  private readonly logger = new Logger(AssistBridgeCronService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly bridge: AssistBridgeService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async run(): Promise<void> {
    if (!this.prisma.isEnabled || assistBridgeMode() === 'off' || this.running) return;
    this.running = true;
    try {
      const { processed, sent, skipped, deferred } = await this.bridge.processQueue();
      if (processed > 0) {
        this.logger.log(
          `Passerelle (${assistBridgeMode()}) : ${processed} traité(s), ${sent} envoyé(s), ${skipped} ignoré(s), ${deferred} reporté(s).`,
        );
      }
    } catch (error) {
      this.logger.error(`Passerelle en échec : ${error instanceof Error ? error.name : 'erreur'}`);
    } finally {
      this.running = false;
    }
  }

  /** Chaque jour à 03 h 47 UTC (après la purge de la communauté, 03 h 41). */
  @Cron('47 3 * * *')
  async purge(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    try {
      const count = await this.bridge.purge();
      if (count > 0) this.logger.log(`Passerelle : ${count} événement(s) de plus de 12 mois purgé(s).`);
    } catch (error) {
      this.logger.error(`Purge de la passerelle en échec : ${error instanceof Error ? error.name : 'erreur'}`);
    }
  }
}
