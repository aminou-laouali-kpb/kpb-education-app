import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { PrismaService } from '../prisma/prisma.service';
import { CampaignExecutorService } from './campaign-executor.service';

@Injectable()
export class CampaignCronService {
  private readonly logger = new Logger(CampaignCronService.name);

  /**
   * In-process overlap guard. A large campaign sends one push at a time and
   * can outlast the one-minute period: the next tick must not start a second
   * batch of executions while the previous one is still running. A skipped
   * tick loses nothing — due campaigns stay `Scheduled` and are picked up by
   * the first tick that finds the slot free.
   */
  private running = false;

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
    try {
      const now = new Date();
      
      const pendingCampaigns = await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.findMany({
          where: {
            status: NotificationCampaignStatus.Scheduled,
            scheduledFor: { lte: now },
          },
          take: 10,
        }),
      );

      if (!pendingCampaigns || pendingCampaigns.length === 0) {
        return;
      }

      this.logger.log(`Found ${pendingCampaigns.length} scheduled campaigns to execute.`);

      for (const campaign of pendingCampaigns) {
        // Atomic claim. The list above is a snapshot: another API replica (or
        // an overlapping tick) may have read the same rows and already moved
        // one to `Sending`. A plain `update` by id overwrote that and both
        // workers sent the campaign. Only the worker whose conditional update
        // actually flips `Scheduled` → `Sending` (count === 1) executes it.
        const claim = await this.prismaService.execute((prisma) =>
          prisma.notificationCampaign.updateMany({
            where: {
              id: campaign.id,
              status: NotificationCampaignStatus.Scheduled,
            },
            data: { status: NotificationCampaignStatus.Sending },
          }),
        );
        if (claim?.count !== 1) {
          this.logger.log(
            `Scheduled campaign ${campaign.id} already claimed by another worker — skipping.`,
          );
          continue;
        }

        this.logger.log(`Executing scheduled campaign ${campaign.id} ("${campaign.name}")`);
        await this.campaignExecutor.execute(campaign.id).catch(async (error) => {
          this.logger.error(`Failed to execute scheduled campaign ${campaign.id}:`, error);
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
    } catch (error) {
      this.logger.error('Error while checking for scheduled campaigns:', error);
    } finally {
      this.running = false;
    }
  }
}
