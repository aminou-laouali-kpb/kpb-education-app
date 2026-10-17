import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../../prisma/prisma.service';
import { ReferralCampaignService } from './referral-campaign.service';

/**
 * Tâches planifiées de la compétition ambassadeurs.
 *
 * - toutes les 5 minutes : recalcul des campagnes `live` (classement « en
 *   direct ») et gel automatique d'une campagne dont la fenêtre est passée ;
 * - chaque jour à 03 h 17 UTC : purge des empreintes anti-fraude au-delà de la
 *   durée de conservation.
 *
 * Une erreur est journalisée, jamais propagée : un rejet non géré arrêterait le
 * planificateur de toutes les tâches du process.
 */
@Injectable()
export class ReferralCampaignCronService {
  private readonly logger = new Logger(ReferralCampaignCronService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly campaigns: ReferralCampaignService,
  ) {}

  @Cron('*/5 * * * *')
  async recomputeLive(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    try {
      await this.campaigns.recomputeLive();
    } catch (error) {
      this.logger.error(
        `Recalcul planifié en échec : ${error instanceof Error ? error.message : 'erreur'}`,
      );
    }
  }

  @Cron('17 3 * * *')
  async purgeSignals(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    try {
      const n = await this.campaigns.purgeSignals();
      if (n > 0) this.logger.log(`${n} empreinte(s) anti-fraude purgée(s).`);
    } catch (error) {
      this.logger.error(
        `Purge des empreintes en échec : ${error instanceof Error ? error.message : 'erreur'}`,
      );
    }
  }
}
