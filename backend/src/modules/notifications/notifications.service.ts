import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnApplicationShutdown,
  ServiceUnavailableException,
} from '@nestjs/common';
import { NotificationCampaign, Prisma } from '@prisma/client';

import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { CasesService } from '../cases/cases.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  AUDIENCE_REQUIRED_FILTER,
  audienceFilterInvalid,
  resolveExcludedCountries,
  audienceFilterMissing,
} from './campaign-audience';
import { claimCampaign } from './campaign-claim';
import { CampaignExecutorService } from './campaign-executor.service';
import {
  campaignChannelBlock,
  countCampaignChannels,
  parseCampaignPurpose,
} from './campaign-purpose';
import { CreateNotificationCampaignDto } from './dto/create-notification-campaign.dto';
import { PreviewCampaignAudienceDto } from './dto/preview-campaign-audience.dto';
import { UpsertNotificationTemplateDto } from './dto/upsert-notification-template.dto';

/**
 * Fenêtre pendant laquelle une soumission identique est traitée comme un
 * double clic (ou une relance après délai dépassé) et non comme une nouvelle
 * campagne.
 */
const DUPLICATE_WINDOW_MS = 10 * 60 * 1000;

/** JSON à clés triées : deux objets égaux donnent la même empreinte. */
function canonicalJson(value: unknown): string {
  const normalize = (v: unknown): unknown => {
    if (Array.isArray(v)) return v.map(normalize);
    if (v && typeof v === 'object') {
      return Object.fromEntries(
        Object.keys(v as Record<string, unknown>)
          .sort()
          .map((key) => [key, normalize((v as Record<string, unknown>)[key])]),
      );
    }
    return v;
  };
  return JSON.stringify(normalize(value));
}

interface TemplateTitle {
  fr: string;
  en: string;
}

@Injectable()
export class NotificationsService implements OnApplicationShutdown {
  private readonly logger = new Logger(NotificationsService.name);
  /** Envois de campagnes immédiates lancés hors requête et pas encore finis. */
  private readonly inFlightCampaigns = new Set<Promise<void>>();

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

    // ── Idempotence : une soumission en double ne crée PAS une 2e campagne ──
    //
    // Audit §12 : la requête restait bloquée le temps d'envoyer toute
    // l'audience ; l'exploitant recliquait (ou le proxy coupait et il
    // réessayait) et toute la base recevait le même push et le même e-mail
    // deux fois. Désormais :
    //  1. Un formulaire IDENTIQUE (mêmes champs, même échéance) soumis dans
    //     les `DUPLICATE_WINDOW_MS` renvoie la campagne déjà créée, avec son
    //     statut courant, au lieu d'en créer une seconde. Une campagne `failed`
    //     ne compte pas : la resoumettre est la façon de la relancer.
    //  2. Vérification et création se font sous un verrou consultatif Postgres
    //     (`pg_advisory_xact_lock`) pris sur l'empreinte du formulaire : deux
    //     requêtes concurrentes, même sur deux répliques, sont sérialisées et
    //     la seconde voit la campagne de la première.
    //  3. Une campagne immédiate naît `draft`, puis est RÉSERVÉE atomiquement
    //     (`draft` → `sending`, comme le cron le fait pour `scheduled`) avant
    //     tout envoi, et l'envoi tourne hors de la requête HTTP.
    const scheduledDate = scheduledFor ? new Date(scheduledFor) : null;
    const fingerprint = canonicalJson({
      name,
      templateId,
      audienceType,
      filters,
      channels: [...channels].sort(),
      scheduledFor: scheduledDate?.toISOString() ?? null,
      linkedCaseId,
      route,
      purpose,
    });
    const since = new Date(Date.now() - DUPLICATE_WINDOW_MS);

    const outcome = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        // Verrou relâché automatiquement à la fin de la transaction.
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${fingerprint}))`;
        const candidates = await tx.notificationCampaign.findMany({
          where: {
            name,
            templateId,
            audienceType,
            scheduledFor: scheduledDate,
            linkedCaseId,
            route,
            purpose,
            createdAt: { gte: since },
            status: { not: NotificationCampaignStatus.Failed },
          },
          orderBy: { createdAt: 'desc' },
        });
        const existing = candidates.find(
          (candidate) =>
            canonicalJson({
              name: candidate.name,
              templateId: candidate.templateId,
              audienceType: candidate.audienceType,
              filters: candidate.filters,
              channels: [...candidate.channels].sort(),
              scheduledFor: candidate.scheduledFor?.toISOString() ?? null,
              linkedCaseId: candidate.linkedCaseId,
              route: candidate.route,
              purpose: parseCampaignPurpose(candidate.purpose),
            }) === fingerprint,
        );
        if (existing) {
          return { campaign: existing, duplicate: true };
        }
        const created = await tx.notificationCampaign.create({
          data: {
            name,
            templateId,
            audienceType,
            filters: filters as Prisma.InputJsonValue,
            channels: channels as ('push' | 'in_app' | 'email')[],
            scheduledFor: scheduledDate,
            status: scheduledDate
              ? NotificationCampaignStatus.Scheduled
              : NotificationCampaignStatus.Draft,
            linkedCaseId,
            route,
            purpose,
          },
        });
        return { campaign: created, duplicate: false };
      }),
    );
    if (!outcome) {
      throw new ServiceUnavailableException('Failed to create campaign.');
    }

    if (outcome.duplicate) {
      this.logger.warn(
        `Duplicate submission of campaign ${outcome.campaign.id} ignored ` +
          `(status ${outcome.campaign.status}).`,
      );
      return { ...this.toCampaignResponse(outcome.campaign), duplicate: true };
    }
    const created = outcome.campaign;

    if (!scheduledDate) {
      this.startImmediateCampaign(created.id);
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
    return {
      ...this.toCampaignResponse(refreshed ?? created),
      duplicate: false,
    };
  }

  private toCampaignResponse(campaign: NotificationCampaign) {
    return {
      id: campaign.id,
      name: campaign.name,
      templateId: campaign.templateId,
      audienceType: campaign.audienceType,
      filters: campaign.filters,
      channels: campaign.channels,
      scheduledFor: campaign.scheduledFor?.toISOString() ?? null,
      status: campaign.status,
      linkedCaseId: campaign.linkedCaseId,
      route: campaign.route,
      purpose: parseCampaignPurpose(campaign.purpose),
    };
  }

  /**
   * Réserve (`draft` → `sending`) puis exécute une campagne immédiate HORS de
   * la requête HTTP : l'API répond aussitôt `sending`, la liste de l'admin
   * montre l'avancement au rechargement, et une requête coupée par le client
   * ou le proxy ne pousse plus personne à recliquer.
   *
   * L'échec d'exécution n'annule pas la CRÉATION — la campagne existe, et
   * l'exploitant doit pouvoir la retrouver et la relancer : l'exécuteur la
   * passe à `failed`, et le filet ci-dessous garantit qu'elle ne reste jamais
   * bloquée en `sending` (même filet que le cron).
   */
  private startImmediateCampaign(campaignId: string): void {
    const run = (async () => {
      const claimed = await claimCampaign(
        this.prismaService,
        campaignId,
        NotificationCampaignStatus.Draft,
      );
      if (!claimed) {
        this.logger.warn(
          `Immediate campaign ${campaignId} already claimed — not sending it twice.`,
        );
        return;
      }
      await this.campaignExecutor.execute(campaignId).catch(async (error) => {
        this.logger.error(
          `Immediate execution of campaign ${campaignId} failed:`,
          error instanceof Error ? error.stack : String(error),
        );
        await this.prismaService.tryExecute((prisma) =>
          prisma.notificationCampaign.updateMany({
            where: { id: campaignId, status: NotificationCampaignStatus.Sending },
            data: { status: NotificationCampaignStatus.Failed },
          }),
        );
      });
    })().catch((error) => {
      this.logger.error(
        `Immediate campaign ${campaignId} could not be started:`,
        error instanceof Error ? error.stack : String(error),
      );
    });
    this.inFlightCampaigns.add(run);
    void run.finally(() => this.inFlightCampaigns.delete(run));
  }

  /**
   * Attend la fin des envois immédiats en cours. Appelée à l'arrêt de
   * l'application (un déploiement ne coupe pas une campagne en plein envoi
   * sans attendre) et par les tests, qui vérifient ce qui est parti.
   */
  async waitForInFlightCampaigns(): Promise<void> {
    while (this.inFlightCampaigns.size > 0) {
      await Promise.allSettled([...this.inFlightCampaigns]);
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await this.waitForInFlightCampaigns();
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
