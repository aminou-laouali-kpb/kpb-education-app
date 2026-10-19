import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { CasesService } from '../cases/cases.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  AUDIENCE_REQUIRED_FILTER,
  audienceFilterInvalid,
  resolveExcludedCountries,
  audienceFilterMissing,
} from './campaign-audience';
import { CampaignExecutorService } from './campaign-executor.service';
import {
  campaignChannelBlock,
  countCampaignChannels,
  parseCampaignPurpose,
} from './campaign-purpose';
import { CreateNotificationCampaignDto } from './dto/create-notification-campaign.dto';
import { PreviewCampaignAudienceDto } from './dto/preview-campaign-audience.dto';
import { UpsertNotificationTemplateDto } from './dto/upsert-notification-template.dto';

interface TemplateTitle {
  fr: string;
  en: string;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly casesService: CasesService,
    private readonly prismaService: PrismaService,
    private readonly campaignExecutor: CampaignExecutorService,
  ) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async listTemplates() {
    this.assertDb();
    const items =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationTemplate.findMany({ orderBy: { createdAt: 'desc' } }),
      )) ?? [];
    return {
      items: items.map((item) => ({
        id: item.id,
        name: item.name,
        title: { fr: item.titleFr, en: item.titleEn },
        body: { fr: item.bodyFr, en: item.bodyEn },
        channels: item.channels,
        isCritical: item.isCritical,
      })),
    };
  }

  async createTemplate(input: UpsertNotificationTemplateDto) {
    this.assertDb();
    const name = (input['name'] as string | undefined) ?? 'New template';
    const title =
      (input['title'] as TemplateTitle | undefined) ??
      { fr: 'Nouveau template', en: 'New template' };
    const body = (input['body'] as TemplateTitle | undefined) ?? { fr: '', en: '' };
    const channels = (input['channels'] as string[] | undefined) ?? ['push'];
    const isCritical = (input['isCritical'] as boolean | undefined) ?? false;

    const created = await this.prismaService.execute((prisma) =>
      prisma.notificationTemplate.create({
        data: {
          name,
          titleFr: title.fr,
          titleEn: title.en,
          bodyFr: body.fr,
          bodyEn: body.en,
          channels: channels as ('push' | 'in_app' | 'email')[],
          isCritical,
        },
      }),
    );
    if (!created) {
      throw new ServiceUnavailableException('Failed to create template.');
    }
    return {
      id: created.id,
      name: created.name,
      title: { fr: created.titleFr, en: created.titleEn },
      body: { fr: created.bodyFr, en: created.bodyEn },
      channels: created.channels,
      isCritical: created.isCritical,
    };
  }

  async updateTemplate(id: string, input: UpsertNotificationTemplateDto) {
    this.assertDb();
    try {
      const updated = await this.prismaService.execute((prisma) =>
        prisma.notificationTemplate.update({
          where: { id },
          data: {
            ...(input['name'] ? { name: input['name'] as string } : {}),
            ...(input['title']
              ? {
                  titleFr: (input['title'] as TemplateTitle).fr,
                  titleEn: (input['title'] as TemplateTitle).en,
                }
              : {}),
            ...(input['body']
              ? {
                  bodyFr: (input['body'] as TemplateTitle).fr,
                  bodyEn: (input['body'] as TemplateTitle).en,
                }
              : {}),
            ...(input['channels']
              ? { channels: input['channels'] as ('push' | 'in_app' | 'email')[] }
              : {}),
            ...(input['isCritical'] !== undefined
              ? { isCritical: input['isCritical'] as boolean }
              : {}),
          },
        }),
      );
      if (!updated) {
        throw new NotFoundException(`Notification template ${id} not found.`);
      }
      return {
        id: updated.id,
        name: updated.name,
        title: { fr: updated.titleFr, en: updated.titleEn },
        body: { fr: updated.bodyFr, en: updated.bodyEn },
        channels: updated.channels,
        isCritical: updated.isCritical,
      };
    } catch (error) {
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        (error as { code: string }).code === 'P2025'
      ) {
        throw new NotFoundException(`Notification template ${id} not found.`);
      }
      throw error;
    }
  }

  async listCampaigns() {
    this.assertDb();
    const items =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.findMany({ orderBy: { createdAt: 'desc' } }),
      )) ?? [];
    return {
      items: items.map((item) => ({
        id: item.id,
        name: item.name,
        templateId: item.templateId,
        audienceType: item.audienceType,
        filters: item.filters as Record<string, unknown>,
        channels: item.channels,
        scheduledFor: item.scheduledFor?.toISOString() ?? null,
        status: item.status,
        linkedCaseId: item.linkedCaseId,
        route: item.route,
        purpose: parseCampaignPurpose(item.purpose),
        createdAt: item.createdAt.toISOString(),
      })),
    };
  }

  async createCampaign(input: CreateNotificationCampaignDto) {
    this.assertDb();
    const name = (input['name'] as string | undefined) ?? 'New campaign';
    const templateId = (input['templateId'] as string | null | undefined) ?? null;
    const audienceType =
      (input['audienceType'] as string | undefined) ?? 'all_students';
    const filters =
      (input['filters'] as Record<string, unknown> | undefined) ?? {};
    const channels = (input['channels'] as string[] | undefined) ?? ['push'];
    const scheduledFor =
      (input['scheduledFor'] as string | null | undefined) ?? null;
    const linkedCaseId =
      (input['linkedCaseId'] as string | null | undefined) ?? null;
    const route = (input['route'] as string | null | undefined) ?? null;
    // Défaut prudent : une campagne sans finalité déclarée est promotionnelle.
    const purpose = parseCampaignPurpose(input.purpose);
    // Un canal de contenu SANS modèle ne peut rien envoyer : l'exécuteur garde
    // ses deux boucles derrière `&& template`. La campagne partait quand même,
    // n'envoyait rien, et s'affichait « terminée ». Or « aucun modèle » est le
    // choix par défaut du formulaire — c'était donc le cas le plus courant.
    //
    // Refuser à la CRÉATION plutôt qu'échouer à l'exécution : l'exploitant
    // apprend ce qui manque pendant qu'il a le formulaire sous les yeux, pas
    // en ouvrant le détail des livraisons d'une campagne déjà partie.
    // Une audience ciblée sans son filtre ne vise PERSONNE (l'exécuteur échoue
    // fermé). Le dire ici évite d'envoyer une campagne vide et de le découvrir
    // dans le détail des livraisons : l'exploitant a encore le formulaire sous
    // les yeux.
    const filterFilters = filters as Record<string, unknown>;
    if (audienceFilterMissing(audienceType, filterFilters)) {
      throw new BadRequestException(
        `L'audience « ${audienceType} » exige le filtre ` +
          `« ${AUDIENCE_REQUIRED_FILTER[audienceType]} » : sans lui, la campagne ` +
          "ne vise aucun destinataire.",
      );
    }

    // Un filtre PRÉSENT mais mal formé (jeton d'exclusion mal écrit, clé inconnue)
    // est refusé de la même façon : envoyer « la campagne est ouverte » à un pays
    // suspendu parce que `eef_suspendd` n'excluait personne est l'accident que
    // l'exclusion existe pour empêcher.
    const filterInvalid = audienceFilterInvalid(audienceType, filterFilters);
    if (filterInvalid) {
      throw new BadRequestException(
        `Le filtre de l'audience « ${audienceType} » est inutilisable : ${filterInvalid}.`,
      );
    }

    const contentChannels = channels.filter((c) => c === 'push' || c === 'email');
    if (contentChannels.length > 0 && !templateId) {
      throw new BadRequestException(
        `Un modèle est obligatoire pour les canaux ${contentChannels.join(', ')} : ` +
          "sans lui, la campagne n'a aucun contenu à envoyer.",
      );
    }

    const initialStatus = scheduledFor
      ? NotificationCampaignStatus.Scheduled
      : NotificationCampaignStatus.Sending;

    const created = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.create({
        data: {
          name,
          templateId,
          audienceType,
          filters: filters as Prisma.InputJsonValue,
          channels: channels as ('push' | 'in_app' | 'email')[],
          scheduledFor: scheduledFor ? new Date(scheduledFor) : null,
          status: initialStatus,
          linkedCaseId,
          route,
          purpose,
        },
      }),
    );
    if (!created) {
      throw new ServiceUnavailableException('Failed to create campaign.');
    }

    if (!scheduledFor) {
      // L'échec d'exécution ne doit pas annuler la CRÉATION — la campagne
      // existe, et l'exploitant doit pouvoir la retrouver et la relancer. Mais
      // l'avaler sans un mot laissait l'API répondre 201 sur un envoi qui
      // venait d'échouer, sans la moindre trace côté serveur.
      //
      // Le statut de la campagne, lui, dit désormais la vérité : l'exécuteur
      // la passe à `failed` quand aucune livraison n'a abouti, et la liste de
      // l'admin le montre au rechargement qui suit.
      await this.campaignExecutor.execute(created.id).catch((error) => {
        this.logger.error(
          `Immediate execution of campaign ${created.id} failed:`,
          error instanceof Error ? error.stack : String(error),
        );
      });
    }

    if (linkedCaseId) {
      await this.casesService
        .createNotificationTimelineEvent(
          linkedCaseId,
          'Notification sent',
          `A ${audienceType} campaign was triggered from the operations dashboard.`,
        )
        .catch(() => undefined);
    }

    const refreshed = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.findUnique({ where: { id: created.id } }),
    );
    const final = refreshed ?? created;
    return {
      id: final.id,
      name: final.name,
      templateId: final.templateId,
      audienceType: final.audienceType,
      filters: final.filters,
      channels: final.channels,
      scheduledFor: final.scheduledFor?.toISOString() ?? null,
      status: final.status,
      linkedCaseId: final.linkedCaseId,
      route: final.route,
      purpose: parseCampaignPurpose(final.purpose),
    };
  }

  /**
   * Combien de comptes une campagne toucherait, SANS rien envoyer.
   *
   * Même résolution que l'exécuteur (même échec fermé sur filtre manquant) :
   * un aperçu qui compterait autrement que l'envoi mentirait précisément au
   * moment où l'exploitant décide.
   */
  async previewAudience(input: PreviewCampaignAudienceDto) {
    this.assertDb();
    const audienceType = input.audienceType ?? 'all_students';
    const filters = input.filters ?? {};
    const filterMissing = audienceFilterMissing(audienceType, filters);
    const filterInvalid = audienceFilterInvalid(audienceType, filters);
    const recipients =
      filterMissing || filterInvalid
        ? []
        : await this.campaignExecutor.resolveRecipients(audienceType, filters);
    const fr = recipients.filter((r) => r.preferredLanguage !== 'en').length;

    // Le nombre RÉEL par canal, après les filtres de consentement d'une
    // campagne promotionnelle — la même règle que l'exécuteur
    // (`campaign-purpose.ts`). `recipients` reste la taille de l'audience.
    const purpose = parseCampaignPurpose(input.purpose);
    const channels = input.channels?.length ? input.channels : ['push'];
    const now = new Date();
    const byChannel = countCampaignChannels(purpose, channels, recipients, now);
    const reachable = recipients.filter((r) =>
      channels.some(
        (channel) => campaignChannelBlock(purpose, channel, r, now) === null,
      ),
    ).length;

    // Ce que l'exclusion RETIRE, dit en clair : un aperçu qui n'affichait qu'un
    // nombre laissait croire à une exclusion efficace alors qu'elle pouvait ne
    // rien retirer (faute de frappe sur un nom de pays). Les pays lus et le
    // nombre de comptes retirés se vérifient d'un coup d'œil.
    let exclusion: { countries: string[]; removed: number } | undefined;
    if (
      !filterMissing &&
      !filterInvalid &&
      (audienceType === 'eef_interest' ||
        audienceType === 'all_students_except_countries')
    ) {
      const countries = resolveExcludedCountries(filters['exceptCountries']);
      if (countries.length > 0) {
        const baseType =
          audienceType === 'eef_interest' ? 'eef_interest' : 'all_students';
        const base = await this.campaignExecutor.resolveRecipients(baseType, {});
        exclusion = {
          countries,
          removed: Math.max(0, base.length - recipients.length),
        };
      }
    }

    return {
      audienceType,
      filters,
      filterMissing,
      // La raison, ou `null` : voir `audienceFilterInvalid`.
      filterInvalid,
      recipients: recipients.length,
      byLanguage: { fr, en: recipients.length - fr },
      purpose,
      // Comptes qui recevront au moins un canal, après les filtres.
      reachable,
      byChannel,
      ...(exclusion
        ? {
            excludedCountries: exclusion.countries,
            excludedRecipients: exclusion.removed,
          }
        : {}),
    };
  }

  async listDeliveries(campaignId: string) {
    this.assertDb();
    const items =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.findMany({
          where: { campaignId },
          orderBy: { createdAt: 'desc' },
        }),
      )) ?? [];
    return {
      items: items.map((item) => ({
        id: item.id,
        campaignId: item.campaignId,
        recipientId: item.recipientId,
        recipientName: item.recipientName,
        channel: item.channel,
        status: item.status,
        deliveredAt: item.deliveredAt?.toISOString() ?? null,
        openedAt: item.openedAt?.toISOString() ?? null,
      })),
    };
  }

  async campaignStats(campaignId: string) {
    this.assertDb();
    const groups = await this.prismaService.execute((prisma) =>
      prisma.notificationDelivery.groupBy({
        by: ['channel', 'status'],
        where: { campaignId },
        _count: { _all: true },
      }),
    );

    const byChannel: Record<
      string,
      { sent: number; delivered: number; failed: number; total: number }
    > = {};

    for (const group of groups ?? []) {
      const ch = group.channel as string;
      if (!byChannel[ch]) {
        byChannel[ch] = { sent: 0, delivered: 0, failed: 0, total: 0 };
      }
      const count = group._count._all;
      byChannel[ch].total += count;
      if (group.status === 'delivered') byChannel[ch].delivered += count;
      else if (group.status === 'queued' || group.status === 'sent')
        byChannel[ch].sent += count;
      else if (group.status === 'failed') byChannel[ch].failed += count;
    }

    // Ouvertures signalées par l'application au tap (push seulement). Le taux
    // se rapporte aux livraisons réussies : une notification jamais arrivée ne
    // peut pas être ouverte.
    const opened =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.count({
          where: { campaignId, channel: 'push', openedAt: { not: null } },
        }),
      )) ?? 0;
    const pushDelivered = byChannel['push']?.delivered ?? 0;

    const totalDeliveries = Object.values(byChannel).reduce(
      (sum, ch) => sum + ch.total,
      0,
    );
    const totalDelivered = Object.values(byChannel).reduce(
      (sum, ch) => sum + ch.delivered,
      0,
    );

    return {
      campaignId,
      byChannel,
      totals: {
        sent: totalDeliveries,
        delivered: totalDelivered,
        failed: Object.values(byChannel).reduce((s, c) => s + c.failed, 0),
        deliveryRate:
          totalDeliveries > 0
            ? Math.round((totalDelivered / totalDeliveries) * 100)
            : 0,
        opened,
        openRate:
          pushDelivered > 0 ? Math.round((opened / pushDelivered) * 100) : 0,
      },
    };
  }
}
