import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Réservation atomique d'une campagne avant son exécution.
 *
 * `UPDATE … SET status = 'sending' WHERE id = ? AND status = <from>` : la
 * vérification et l'écriture se font dans la même instruction SQL, donc deux
 * workers (deux ticks du cron, deux répliques de l'API, la requête HTTP et le
 * cron) ne peuvent pas gagner tous les deux. Seul celui qui obtient
 * `count === 1` a le droit d'appeler l'exécuteur ; les autres s'abstiennent.
 *
 * Utilisée par le cron (`scheduled` → `sending`) et par la création d'une
 * campagne immédiate (`draft` → `sending`).
 */
export async function claimCampaign(
  prismaService: PrismaService,
  campaignId: string,
  from: NotificationCampaignStatus.Draft | NotificationCampaignStatus.Scheduled,
): Promise<boolean> {
  const claim = await prismaService.execute((prisma) =>
    prisma.notificationCampaign.updateMany({
      where: { id: campaignId, status: from },
      data: { status: NotificationCampaignStatus.Sending },
    }),
  );
  return claim?.count === 1;
}
