import { Injectable, Logger } from '@nestjs/common';
import type { NotificationCampaign } from '@prisma/client';
import { NotificationCampaignStatus } from '../../common/enums/notification-campaign-status.enum';
import { PrismaService } from '../prisma/prisma.service';
import {
  audienceFilterInvalid,
  audienceFilterMissing,
  countryVariants,
  escapeLike,
  resolveExcludedCountries,
} from './campaign-audience';
import { CampaignMailService } from './campaign-mail.service';
import {
  campaignChannelBlock,
  type CampaignChannelBlock,
  type CampaignPurpose,
  parseCampaignPurpose,
} from './campaign-purpose';
import {
  promotionsEmailFooter,
  promotionsUnsubscribeUrl,
} from './promotions-unsubscribe';
import { PushSenderService } from './push-sender.service';

/**
 * Ce que l'exécuteur lit de chaque destinataire : de quoi lui écrire, et de
 * quoi décider si une campagne promotionnelle a le droit de le faire
 * (`campaign-purpose.ts`).
 */
const RECIPIENT_SELECT = {
  id: true,
  fullName: true,
  email: true,
  preferredLanguage: true,
  disabledNotificationTypes: true,
  promotionsEmailOptIn: true,
  birthDate: true,
  guardianConsentedAt: true,
} as const;

interface ResolvedTemplate {
  titleFr: string;
  titleEn: string;
  bodyFr: string;
  bodyEn: string;
}

/**
 * « Le pays de résidence n'est AUCUN de ceux-ci », insensible à la casse.
 *
 * `countryOfResidence` est un texte saisi (« Niger », « niger », parfois un
 * code) : une égalité stricte aurait laissé passer « NIGER ». La colonne est non
 * nulle (`String` au schéma), donc `NOT` ne retire pas par erreur les comptes
 * sans pays — le piège habituel de `NOT` sur une colonne nullable.
 *
 * **Limite assumée :** un compte dont le pays est vide (`''`, profil non
 * complété) n'est exclu de rien — on ne peut pas savoir qu'il est au Niger. Il
 * reçoit donc l'annonce. C'est le cas des comptes qui n'ont pas fini leur profil.
 *
 * Les jokers `%` et `_` sont ÉCHAPPÉS : `ILIKE` les interprète, et Prisma ne le
 * fait pas pour nous.
 */
export function countryExclusion(countries: readonly string[]) {
  return {
    OR: countries
      .flatMap((country) => countryVariants(country))
      .map((variant) => ({
        countryOfResidence: {
          equals: escapeLike(variant),
          mode: 'insensitive' as const,
        },
      })),
  };
}

@Injectable()
export class CampaignExecutorService {
  private readonly logger = new Logger(CampaignExecutorService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly pushService: PushSenderService,
    private readonly mailService: CampaignMailService,
  ) {}

  async execute(campaignId: string): Promise<{ enqueued: number }> {
    const campaign = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.findUnique({ where: { id: campaignId } }),
    );
    if (!campaign) {
      this.logger.warn(`Campaign ${campaignId} not found for execution.`);
      return { enqueued: 0 };
    }

    try {
      return await this.run(campaign, campaignId);
    } catch (error) {
      // Never leave a campaign stuck in `Sending`: any failure transitions it
      // to `Failed` so the cron won't re-pick it and operators can see it.
      this.logger.error(`Campaign ${campaignId} execution failed:`, error);
      await this.prismaService.tryExecute((prisma) =>
        prisma.notificationCampaign.update({
          where: { id: campaignId },
          data: { status: NotificationCampaignStatus.Failed },
        }),
      );
      throw error;
    }
  }

  private async run(
    campaign: NotificationCampaign,
    campaignId: string,
  ): Promise<{ enqueued: number }> {
    const templateRow = campaign.templateId
      ? await this.prismaService.execute((prisma) =>
          prisma.notificationTemplate.findUnique({
            where: { id: campaign.templateId! },
          }),
        )
      : null;
    const template: ResolvedTemplate | null = templateRow
      ? {
          titleFr: templateRow.titleFr,
          titleEn: templateRow.titleEn,
          bodyFr: templateRow.bodyFr,
          bodyEn: templateRow.bodyEn,
        }
      : null;

    const audience = await this.resolveRecipients(
      campaign.audienceType,
      (campaign.filters as Record<string, unknown>) ?? {},
    );

    // ── Finalité : qui a le droit de recevoir quoi (XC-06) ────────────────
    //
    // Une campagne promotionnelle ne crée AUCUNE livraison vers un compte qui
    // n'y a pas droit sur ce canal (e-mail sans consentement, push coupé) :
    // rien n'est tenté, donc rien ne peut partir par erreur plus bas. Les
    // comptes qui n'ont plus aucun canal ouvert sortent de la liste.
    const purpose = parseCampaignPurpose(campaign.purpose);
    const now = new Date();
    const blockedCounts: Partial<Record<CampaignChannelBlock, number>> = {};
    const allowedChannels = new Map<string, string[]>();
    for (const user of audience) {
      const open = campaign.channels.filter((channel) => {
        const block = campaignChannelBlock(purpose, channel, user, now);
        if (block) blockedCounts[block] = (blockedCounts[block] ?? 0) + 1;
        return block === null;
      });
      if (open.length > 0) allowedChannels.set(user.id, open);
    }
    const recipients = audience.filter((user) => allowedChannels.has(user.id));
    const allowed = (userId: string, channel: string) =>
      allowedChannels.get(userId)?.includes(channel) ?? false;
    if (Object.keys(blockedCounts).length > 0) {
      this.logger.log(
        `Campaign ${campaignId} (${purpose}): consent filters removed ` +
          `${JSON.stringify(blockedCounts)} channel delivery(ies).`,
      );
    }

    if (recipients.length === 0) {
      await this.prismaService.execute((prisma) =>
        prisma.notificationCampaign.update({
          where: { id: campaignId },
          data: { status: NotificationCampaignStatus.Completed },
        }),
      );
      return { enqueued: 0 };
    }

    await this.prismaService.execute((prisma) =>
      prisma.notificationDelivery.createMany({
        data: recipients.flatMap((user) =>
          allowedChannels.get(user.id)!.map((channel) => ({
            campaignId,
            caseId: campaign.linkedCaseId,
            recipientId: user.id,
            recipientName: user.fullName ?? user.email ?? user.id,
            channel: channel as 'push' | 'in_app' | 'email',
            status: 'queued',
          })),
        ),
      }),
    );

    // KPB-173: admin broadcasts keep their own delivery path — they carry
    // per-recipient delivery records, their own scheduling and their own
    // segmentation. Whether they should also inherit quiet hours and the daily
    // cap is a product decision, tracked separately (KPB-175).
    // Un canal choisi SANS modèle n'envoyait rien, et ne le disait pas : les
    // deux boucles ci-dessous sont gardées par `&& template`, si bien que les
    // livraisons créées juste au-dessus restaient « queued » à vie pendant que
    // la campagne passait à « terminée ». Or l'absence de modèle est le choix
    // PAR DÉFAUT du formulaire admin — c'était donc le cas le plus courant.
    //
    // On ne peut pas inventer un contenu ; on peut refuser de faire semblant.
    if (!template) {
      const affected = await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.updateMany({
          where: { campaignId, status: 'queued' },
          data: { status: 'failed' },
        }),
      );
      this.logger.error(
        `Campaign ${campaignId} has no template: ${affected?.count ?? 0} ` +
          'queued delivery(ies) marked failed — nothing could be sent.',
      );
    }

    let delivered = 0;
    if (campaign.channels.includes('push') && template) {
      for (const user of recipients) {
        if (!allowed(user.id, 'push')) continue;
        const title =
          user.preferredLanguage === 'en' ? template.titleEn : template.titleFr;
        const body =
          user.preferredLanguage === 'en' ? template.bodyEn : template.bodyFr;
        const ok = await this.pushService.sendToUser(user.id, title, body, {
          campaignId,
          ...(campaign.route ? { route: campaign.route } : {}),
          ...(campaign.linkedCaseId ? { caseId: campaign.linkedCaseId } : {}),
        });
        if (ok) delivered += 1;

        // Record the real per-recipient outcome instead of blanket-marking
        // every queued push as delivered (no token / send failure → failed).
        await this.prismaService.execute((prisma) =>
          prisma.notificationDelivery.updateMany({
            where: {
              campaignId,
              recipientId: user.id,
              channel: 'push',
              status: 'queued',
            },
            data: ok
              ? { status: 'delivered', deliveredAt: new Date() }
              : { status: 'failed' },
          }),
        );
      }
    }

    // `in_app` est accepté par le DTO, proposé par l'admin, et n'a AUCUNE
    // branche d'exécution : ces livraisons restaient « queued » indéfiniment,
    // ce qui se lit comme « en cours » alors que rien ne viendra jamais.
    //
    // Écrire réellement dans le fil (`userNotification`) est une décision
    // PRODUIT — quelle `dedupeKey`, quel `kind`, quelle route, quelle durée de
    // vie — et non un correctif. En attendant, on marque l'échec au lieu de
    // laisser une file d'attente perpétuelle, et l'admin cesse de proposer ce
    // canal.
    if (campaign.channels.includes('in_app')) {
      const affected = await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.updateMany({
          where: { campaignId, channel: 'in_app', status: 'queued' },
          data: { status: 'failed' },
        }),
      );
      if ((affected?.count ?? 0) > 0) {
        this.logger.warn(
          `Campaign ${campaignId}: the in_app channel has no delivery path — ` +
            `${affected?.count} delivery(ies) marked failed instead of staying queued.`,
        );
      }
    }

    let emailsSent = 0;
    if (campaign.channels.includes('email') && template) {
      if (this.mailService.isEnabled) {
        for (const user of recipients) {
          if (!allowed(user.id, 'email')) continue;
          const lang = user.preferredLanguage === 'en' ? 'en' : 'fr';
          const subject = lang === 'en' ? template.titleEn : template.titleFr;
          const body = lang === 'en' ? template.bodyEn : template.bodyFr;
          const mail = this.promotionalMail(purpose, user.id, body, lang);
          const ok =
            user.email && mail
              ? await this.mailService.send(
                  user.email,
                  subject,
                  mail.text,
                  mail.headers ? { headers: mail.headers } : undefined,
                )
              : false;
          if (ok) emailsSent += 1;

          // Same honesty rule as push: record the real per-recipient outcome
          // (no address / provider failure → failed, never fake "delivered").
          await this.prismaService.execute((prisma) =>
            prisma.notificationDelivery.updateMany({
              where: {
                campaignId,
                recipientId: user.id,
                channel: 'email',
                status: 'queued',
              },
              data: ok
                ? { status: 'delivered', deliveredAt: new Date() }
                : { status: 'failed' },
            }),
          );
        }
      } else {
        // No email provider configured (RESEND_API_KEY unset). We must NOT
        // fabricate a "delivered" status: nothing is actually sent, so queued
        // email deliveries are marked failed and campaign stats stay honest.
        const emailRecipients = recipients.filter((u) => u.email).length;
        await this.prismaService.execute((prisma) =>
          prisma.notificationDelivery.updateMany({
            where: { campaignId, channel: 'email', status: 'queued' },
            data: { status: 'failed' },
          }),
        );
        this.logger.warn(
          `Email provider not configured — ${emailRecipients} email recipient(s) ` +
            `for campaign ${campaignId} marked failed (not sent).`,
        );
      }
    }

    // Le statut se calcule sur les livraisons, il ne se décrète plus.
    //
    // `Completed` était écrit inconditionnellement : le 04/09/2026, la campagne
    // « Rentree Decalee » a trouvé 2 destinataires, n'en a livré aucun, et
    // s'est affichée en vert dans l'admin. Un exploitant n'avait aucune raison
    // d'aller ouvrir le détail des livraisons — donc personne n'a vu la panne
    // pendant que les notifications ne partaient plus.
    //
    // Règle : au moins une livraison réussie ⇒ `completed` (une campagne
    // partiellement livrée reste une campagne livrée). Aucune réussite alors
    // qu'on a tenté ⇒ `failed`. Rien à tenter ⇒ `completed`, il n'y a pas
    // d'échec à signaler.
    const deliveredCount =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.count({
          where: { campaignId, status: 'delivered' },
        }),
      )) ?? 0;
    const attemptedCount =
      (await this.prismaService.execute((prisma) =>
        prisma.notificationDelivery.count({ where: { campaignId } }),
      )) ?? 0;
    const finalStatus =
      attemptedCount > 0 && deliveredCount === 0
        ? NotificationCampaignStatus.Failed
        : NotificationCampaignStatus.Completed;

    await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.update({
        where: { id: campaignId },
        data: { status: finalStatus },
      }),
    );

    const line =
      `Campaign ${campaignId} (${purpose}) executed: ${recipients.length} recipients, ` +
      `${delivered} push sent, ${emailsSent} emails sent → ${finalStatus}.`;
    if (finalStatus === NotificationCampaignStatus.Failed) {
      this.logger.error(line);
    } else {
      this.logger.log(line);
    }
    return { enqueued: recipients.length };
  }

  /**
   * Le texte (et les en-têtes) d'un e-mail de campagne. Promotionnel : pied
   * de désinscription + `List-Unsubscribe` (RFC 8058) ; sans secret pour
   * signer le lien, `null` — l'e-mail ne part pas plutôt que de partir sans
   * issue. De service : le texte tel quel.
   */
  private promotionalMail(
    purpose: CampaignPurpose,
    userId: string,
    body: string,
    lang: 'fr' | 'en',
  ): { text: string; headers?: Record<string, string> } | null {
    if (purpose !== 'promotional') return { text: body };
    const url = promotionsUnsubscribeUrl(userId);
    if (!url) {
      this.logger.error(
        'Promotional campaign email NOT sent: no unsubscribe secret ' +
          '(KPB_PROMOTIONS_UNSUBSCRIBE_SECRET or KPB_JWT_SECRET) to sign the link.',
      );
      return null;
    }
    return {
      text: `${body}\n\n${promotionsEmailFooter(url, lang)}`,
      headers: {
        'List-Unsubscribe': `<${url}>`,
        'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
      },
    };
  }

  /** Public pour l'aperçu d'audience : une seule résolution, jamais deux. */
  async resolveRecipients(
    audienceType: string,
    filters: Record<string, unknown>,
  ) {
    // ── Échouer FERMÉ, avant toute requête ────────────────────────────────
    //
    // `where: undefined` en Prisma ne signifie pas « personne » mais « aucun
    // filtre », donc TOUS LES COMPTES. Trois audiences construisaient
    // exactement ça (`filtre ? {…} : undefined`) : un filtre oublié ou mal
    // orthographié transformait un envoi ciblé en diffusion à toute la base.
    //
    // La règle existait déjà pour `country` et `single_user`, avec ce
    // commentaire : « A missing filter must NOT fall through to "everyone" ».
    // Elle vaut pour toutes. Envoyer à personne se constate et se corrige ;
    // envoyer à tout le monde ne se rattrape pas.
    if (audienceFilterMissing(audienceType, filters)) {
      this.logger.error(
        `Audience "${audienceType}" is missing its required filter — resolving ` +
          'to 0 recipient instead of falling through to every account.',
      );
      return [];
    }

    // Un filtre PRÉSENT mais mal formé (jeton mal écrit, clé inconnue…) vaut
    // « personne », comme un filtre absent : voir [audienceFilterInvalid].
    const invalid = audienceFilterInvalid(audienceType, filters);
    if (invalid) {
      this.logger.error(
        `Audience "${audienceType}" has an unusable filter (${invalid}) — ` +
          'resolving to 0 recipient instead of ignoring the exclusion.',
      );
      return [];
    }

    return (
      (await this.prismaService.execute((prisma) => {
        switch (audienceType) {
          case 'all_users': {
            // Every account, including parents — no accountType filter.
            return prisma.userProfile.findMany({
              select: RECIPIENT_SELECT,
            });
          }
          case 'all_students': {
            return prisma.userProfile.findMany({
              where: { accountType: 'student' },
              select: RECIPIENT_SELECT,
            });
          }
          // ── Les déclarants « Études en France » ───────────────────────
          //
          // Qui a déclaré son intérêt ET accepté d'être rappelé (la ligne n'existe
          // que sur consentement ; un retrait la supprime). Comptes étudiants
          // seulement : la table ne peut pas porter d'autres comptes, mais le
          // filtre est écrit ici plutôt que supposé.
          //
          // `exceptCountries` retire les pays suspendus : « la campagne est
          // ouverte » n'est pas une bonne nouvelle pour un pays dont l'État dit
          // que les dossiers ne sont pas traités.
          case 'eef_interest': {
            const excluded = resolveExcludedCountries(
              filters['exceptCountries'],
            );
            return prisma.userProfile.findMany({
              where: {
                accountType: 'student',
                eefInterest: { isNot: null },
                ...(excluded.length > 0
                  ? { NOT: countryExclusion(excluded) }
                  : {}),
              },
              select: RECIPIENT_SELECT,
            });
          }
          // Tous les étudiants, sauf des pays donnés. Le filtre est exigé en
          // amont (`audienceFilterMissing`) ; la garde ci-dessous est la seconde
          // ligne : une valeur illisible vaut zéro destinataire, jamais « tous ».
          case 'all_students_except_countries': {
            const excluded = resolveExcludedCountries(
              filters['exceptCountries'],
            );
            if (excluded.length === 0) return Promise.resolve([]);
            return prisma.userProfile.findMany({
              where: {
                accountType: 'student',
                NOT: countryExclusion(excluded),
              },
              select: RECIPIENT_SELECT,
            });
          }
          case 'country': {
            const countryId = filters['countryId'] as string | undefined;
            // A missing filter must NOT fall through to "everyone".
            if (!countryId) return Promise.resolve([]);
            return prisma.userProfile.findMany({
              where: { countryOfResidence: countryId },
              select: RECIPIENT_SELECT,
            });
          }
          case 'case_status': {
            const status = filters['status'] as string | undefined;
            return prisma.userProfile
              .findMany({
                where: { cases: { some: { status: status as any } } },
                select: RECIPIENT_SELECT,
              })
              .catch(() => []);
          }
          case 'single_user': {
            const userId = filters['userId'] as string | undefined;
            if (!userId) return Promise.resolve([]);
            return prisma.userProfile.findMany({
              where: { id: userId },
              select: RECIPIENT_SELECT,
            });
          }
          // ── Persona (account type) ─────────────────────────────────────
          case 'account_type': {
            const accountType = filters['accountType'] as string | undefined;
            return prisma.userProfile.findMany({
              where: {
                accountType: accountType as 'student' | 'parent' | 'partner',
              },
              select: RECIPIENT_SELECT,
            });
          }
          // ── Study level ────────────────────────────────────────────────
          case 'study_level': {
            const levels = filters['levels'] as string[] | string | undefined;
            const levelArray = Array.isArray(levels)
              ? levels
              : levels
                ? [levels]
                : undefined;
            return prisma.userProfile.findMany({
              where: {
                accountType: 'student',
                currentLevel: { in: levelArray as string[] },
              },
              select: RECIPIENT_SELECT,
            });
          }
          // ── Country of residence ───────────────────────────────────────
          case 'country_of_residence': {
            const countryCode = filters['countryCode'] as string | undefined;
            return prisma.userProfile.findMany({
              where: { countryOfResidence: countryCode },
              select: RECIPIENT_SELECT,
            });
          }
          default:
            return Promise.resolve([]);
        }
      })) ?? []
    );
  }
}
