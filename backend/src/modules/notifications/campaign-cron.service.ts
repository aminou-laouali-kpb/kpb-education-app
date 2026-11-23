import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { PrismaService } from '../prisma/prisma.service';
import { claimCampaign } from './campaign-claim';
import {
  CAMPAIGN_HEARTBEAT_MS,
  CampaignExecutorService,
} from './campaign-executor.service';

/**
 * Une campagne immédiate est réservée (`draft` → `sending`) dans la
 * milliseconde qui suit sa création. Restée `draft` au-delà de ce délai, c'est
 * que le processus est mort entre les deux : rien n'est parti, on la reprend.
 */
export const ORPHAN_DRAFT_GRACE_MS = 5 * 60 * 1000;

/**
 * Au-delà, un `draft` orphelin n'est plus repris automatiquement : envoyer
 * « maintenant » un message rédigé il y a plus d'un jour (restauration de
 * base, panne longue) surprendrait plus qu'il ne servirait.
 */
export const ORPHAN_DRAFT_MAX_AGE_MS = 24 * 60 * 60 * 1000;

/**
 * Une campagne `sending` dont le battement de cœur (`updatedAt`, rafraîchi
 * chaque minute par l'exécuteur tant que le processus vit) s'est arrêté depuis
 * aussi longtemps n'a plus personne pour l'envoyer.
 */
export const STALE_SENDING_MS = 15 * CAMPAIGN_HEARTBEAT_MS;

type ClaimableCampaign = { id: string; name: string };

@Injectable()
export class CampaignCronService implements OnModuleDestroy {
  private readonly logger = new Logger(CampaignCronService.name);

  /**
   * In-process overlap guard. A large campaign sends one push at a time and
   * can outlast the one-minute period: the next tick must not start a second
   * batch of executions while the previous one is still running. A skipped
   * tick loses nothing — due campaigns stay `Scheduled` and are picked up by
   * the first tick that finds the slot free.
   */
  private running = false;
  /** Tick en cours, attendu à l'arrêt avant la déconnexion de Prisma. */
  private currentTick: Promise<void> | null = null;

  constructor(
    private readonly prismaService: PrismaService,
    private readonly campaignExecutor: CampaignExecutorService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async handleScheduledCampaigns() {
    if (!this.prismaService.isEnabled) {
      return;
    }
    if (this.running) {
      this.logger.log(
        'Previous scheduled-campaign tick still running — skipping this one.',
      );
      return;
    }

    this.running = true;
    this.currentTick = this.tick();
    try {
      await this.currentTick;
    } finally {
      this.currentTick = null;
      this.running = false;
    }
  }

  /** Même hook d'arrêt que `NotificationsService` (voir son commentaire). */
  async onModuleDestroy(): Promise<void> {
    await this.currentTick;
  }

  private async tick(): Promise<void> {
    try {
      const now = new Date();

      await this.failStaleSendingCampaigns(now);

      const pendingCampaigns = await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.findMany({
          where: {
            status: NotificationCampaignStatus.Scheduled,
            scheduledFor: { lte: now },
          },
          take: 10,
        }),
      );

      // Campagnes immédiates jamais réservées (processus mort entre la
      // création et la réservation). Reprises par la même réservation
      // atomique : si la requête d'origine l'a prise entre-temps, la prise
      // échoue ici et rien ne part deux fois.
      const orphanDrafts = await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.findMany({
          where: {
            status: NotificationCampaignStatus.Draft,
            scheduledFor: null,
            createdAt: {
              lte: new Date(now.getTime() - ORPHAN_DRAFT_GRACE_MS),
              gte: new Date(now.getTime() - ORPHAN_DRAFT_MAX_AGE_MS),
            },
          },
          take: 10,
        }),
      );

      const batch: Array<{
        campaign: ClaimableCampaign;
        from: NotificationCampaignStatus.Scheduled | NotificationCampaignStatus.Draft;
      }> = [
        ...(pendingCampaigns ?? []).map((campaign) => ({
          campaign,
          from: NotificationCampaignStatus.Scheduled as const,
        })),
        ...(orphanDrafts ?? []).map((campaign) => ({
          campaign,
          from: NotificationCampaignStatus.Draft as const,
        })),
      ];
      if (batch.length === 0) {
        return;
      }

      this.logger.log(`Found ${batch.length} campaign(s) to execute.`);

      for (const { campaign, from } of batch) {
        await this.claimAndExecute(campaign, from);
      }
    } catch (error) {
      this.logger.error('Error while checking for scheduled campaigns:', error);
    }
  }

  private async claimAndExecute(
    campaign: ClaimableCampaign,
    from: NotificationCampaignStatus.Scheduled | NotificationCampaignStatus.Draft,
  ): Promise<void> {
    // Atomic claim. The list above is a snapshot: another API replica (or
    // an overlapping tick) may have read the same rows and already moved
    // one to `Sending`. A plain `update` by id overwrote that and both
    // workers sent the campaign. Only the worker whose conditional update
    // actually flips `from` → `Sending` (count === 1) executes it.
    const claimed = await claimCampaign(this.prismaService, campaign.id, from);
    if (!claimed) {
      this.logger.log(
        `Campaign ${campaign.id} already claimed by another worker — skipping.`,
      );
      return;
    }

    if (from === NotificationCampaignStatus.Draft) {
      this.logger.warn(
        `Recovering orphaned immediate campaign ${campaign.id} ("${campaign.name}") ` +
          'left in draft — executing it now.',
      );
    } else {
      this.logger.log(`Executing scheduled campaign ${campaign.id} ("${campaign.name}")`);
    }
    await this.campaignExecutor.execute(campaign.id).catch(async (error) => {
      this.logger.error(`Failed to execute campaign ${campaign.id}:`, error);
      // Safety net: ensure the campaign never stays stuck in `Sending`,
      // even if the executor threw before marking it Failed itself.
      await this.prismaService.tryExecute((prisma) =>
        prisma.notificationCampaign.update({
          where: { id: campaign.id },
          data: { status: NotificationCampaignStatus.Failed },
        }),
      );
    });
  }

  /**
   * `sending` sans battement de cœur depuis `STALE_SENDING_MS` ⇒ le processus
   * qui l'envoyait est mort. On la passe à `failed` pour que l'exploitant la
   * voie et puisse la relancer.
   *
   * Pourquoi c'est sûr : l'exécuteur rafraîchit `updatedAt` chaque minute par
   * un minuteur, indépendamment de la vitesse des envois ; un envoi vivant
   * n'atteint donc jamais 15 minutes de silence. La condition sur `updatedAt`
   * est dans le même `UPDATE` que le changement de statut : un battement
   * arrivé entre la lecture et l'écriture fait échouer la mise en échec.
   *
   * On ne relance PAS automatiquement : une partie des destinataires a pu
   * recevoir le message, et un renvoi complet le leur enverrait deux fois.
   */
  private async failStaleSendingCampaigns(now: Date): Promise<void> {
    const cutoff = new Date(now.getTime() - STALE_SENDING_MS);
    const stale = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.findMany({
        where: {
          status: NotificationCampaignStatus.Sending,
          updatedAt: { lt: cutoff },
        },
        select: { id: true, name: true },
        take: 10,
      }),
    );
    for (const campaign of stale ?? []) {
      const marked = await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.updateMany({
          where: {
            id: campaign.id,
            status: NotificationCampaignStatus.Sending,
            updatedAt: { lt: cutoff },
          },
          data: { status: NotificationCampaignStatus.Failed },
        }),
      );
      if (marked?.count !== 1) continue;
      // Les livraisons jamais tentées ne partiront plus : les laisser
      // « queued » se lirait comme un envoi encore en cours.
      const abandoned = await this.prismaService.tryExecute((prisma) =>
        prisma.notificationDelivery.updateMany({
          where: { campaignId: campaign.id, status: 'queued' },
          data: { status: 'failed' },
        }),
      );
      this.logger.error(
        `Campaign ${campaign.id} ("${campaign.name}") stuck in sending with no ` +
          `heartbeat since ${cutoff.toISOString()} — marked failed ` +
          `(${abandoned?.count ?? 0} queued delivery(ies) abandoned).`,
      );
    }
  }
}
