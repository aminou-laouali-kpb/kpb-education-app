import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  COMMUNITY_NOTIFICATION_GROUP_HOURS,
  COMMUNITY_NOTIFICATION_OPT_OUT,
} from './community.constants';

export type CommunityNotificationKind =
  | 'community_reply'
  | 'community_followed_reply'
  | 'community_verified_answer'
  | 'community_moderation';

export type ModerationEvent =
  | 'hidden'
  | 'restored'
  | 'deleted'
  | 'warning'
  | 'read_only'
  | 'ban';

interface Recipient {
  userId: string;
  memberId: string;
  preferredLanguage: string | null;
  countryOfResidence: string | null;
  optedOut: boolean;
}

interface Texts {
  title: { fr: string; en: string };
  body: { fr: string; en: string };
}

const HOUR_MS = 60 * 60 * 1000;

function quote(title: string): string {
  const t = title.replace(/\s+/g, ' ').trim();
  return `« ${t.length > 80 ? `${t.slice(0, 79)}…` : t} »`;
}

function quoteEn(title: string): string {
  const t = title.replace(/\s+/g, ' ').trim();
  return `“${t.length > 80 ? `${t.slice(0, 79)}…` : t}”`;
}

export function postRoute(postId: string): string {
  return `/community/posts/${postId}`;
}

/**
 * Notifications de la communauté (§11 du contrat) : fil in-app
 * (`UserNotification`) + push par le chemin commun (heures calmes, plafond).
 *
 * - La clé `community` de `disabledNotificationTypes` coupe le PUSH des
 *   réponses et des réponses vérifiées ; la ligne du fil est écrite quand même.
 *   Les notifications de modération ne sont jamais coupées.
 * - Regroupement : tant qu'une notification de réponse pour la même
 *   publication est non lue (24 h), les réponses suivantes la mettent à jour
 *   (« 3 nouvelles réponses ») sans nouveau push.
 * - Jamais de notification causée par un membre bloqué (dans un sens ou
 *   l'autre), ni envoyée à l'auteur de l'action.
 *
 * Une erreur ici ne fait JAMAIS échouer l'écriture qui l'a déclenchée.
 */
@Injectable()
export class CommunityNotificationsService {
  private readonly logger = new Logger(CommunityNotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatcher: NotificationDispatchService,
  ) {}

  private async recipients(memberIds: string[], actorMemberId: string | null): Promise<Recipient[]> {
    const ids = [...new Set(memberIds)].filter((id) => id && id !== actorMemberId);
    if (!ids.length) return [];
    const rows =
      (await this.prisma.execute(async (db) => {
        let excluded = new Set<string>();
        if (actorMemberId) {
          const blocks = await db.communityBlock.findMany({
            where: {
              OR: [
                { blockerMemberId: actorMemberId, blockedMemberId: { in: ids } },
                { blockedMemberId: actorMemberId, blockerMemberId: { in: ids } },
              ],
            },
            select: { blockerMemberId: true, blockedMemberId: true },
          });
          excluded = new Set(blocks.map((b) => (b.blockerMemberId === actorMemberId ? b.blockedMemberId : b.blockerMemberId)));
        }
        return db.communityMember.findMany({
          where: { id: { in: ids.filter((id) => !excluded.has(id)) } },
          select: {
            id: true,
            userId: true,
            user: { select: { preferredLanguage: true, countryOfResidence: true, disabledNotificationTypes: true } },
          },
        });
      })) ?? [];
    return rows.map((r) => ({
      userId: r.userId,
      memberId: r.id,
      preferredLanguage: r.user.preferredLanguage,
      countryOfResidence: r.user.countryOfResidence,
      optedOut: r.user.disabledNotificationTypes.includes(COMMUNITY_NOTIFICATION_OPT_OUT),
    }));
  }

  /** Écrit la ligne du fil et pousse — ou, désinscrit, écrit seulement. */
  private async deliver(
    recipient: Recipient,
    kind: CommunityNotificationKind,
    dedupeKey: string,
    texts: Texts,
    route: string,
    data: Record<string, string>,
    silencePush: boolean,
    now: Date,
  ): Promise<void> {
    if (silencePush) {
      await this.prisma.execute((db) =>
        db.userNotification.createMany({
          data: [
            {
              userId: recipient.userId,
              kind,
              dedupeKey,
              titleFr: texts.title.fr,
              titleEn: texts.title.en,
              bodyFr: texts.body.fr,
              bodyEn: texts.body.en,
              route,
              data: data as Prisma.InputJsonValue,
              createdAt: now,
            },
          ],
          skipDuplicates: true,
        }),
      );
      return;
    }
    await this.dispatcher.dispatch({
      userId: recipient.userId,
      kind,
      dedupeKey,
      title: texts.title,
      body: texts.body,
      route,
      data,
      preferredLanguage: recipient.preferredLanguage,
      countryOfResidence: recipient.countryOfResidence,
      now,
    });
  }

  /** Regroupe sur une ligne non lue récente, sinon livre une ligne neuve. */
  private async groupedReply(
    recipient: Recipient,
    kind: 'community_reply' | 'community_followed_reply',
    postId: string,
    replyId: string,
    texts: (count: number) => Texts,
    now: Date,
  ): Promise<void> {
    const existing = await this.prisma.execute((db) =>
      db.userNotification.findFirst({
        where: {
          userId: recipient.userId,
          kind,
          readAt: null,
          createdAt: { gte: new Date(now.getTime() - COMMUNITY_NOTIFICATION_GROUP_HOURS * HOUR_MS) },
          data: { path: ['postId'], equals: postId },
        },
        orderBy: { createdAt: 'desc' },
      }),
    );
    if (existing) {
      const data = (existing.data ?? {}) as Record<string, unknown>;
      const count = (Number.parseInt(String(data.count ?? '1'), 10) || 1) + 1;
      const t = texts(count);
      await this.prisma.execute((db) =>
        db.userNotification.update({
          where: { id: existing.id },
          data: {
            titleFr: t.title.fr,
            titleEn: t.title.en,
            bodyFr: t.body.fr,
            bodyEn: t.body.en,
            data: { ...data, postId, replyId, count: String(count) } as Prisma.InputJsonValue,
          },
        }),
      );
      return;
    }
    await this.deliver(
      recipient,
      kind,
      `${kind}:${postId}:${recipient.userId}:${replyId}`,
      texts(1),
      postRoute(postId),
      { postId, replyId, count: '1' },
      recipient.optedOut,
      now,
    );
  }

  /** Une réponse VISIBLE vient d'être publiée (membre ou équipe). */
  async replyPosted(input: {
    post: { id: string; title: string; type: string; authorMemberId: string | null };
    reply: { id: string; authorMemberId: string | null };
    now?: Date;
  }): Promise<void> {
    const now = input.now ?? new Date();
    try {
      const followers =
        (await this.prisma.execute((db) =>
          db.communityFollow.findMany({ where: { postId: input.post.id }, select: { memberId: true } }),
        )) ?? [];
      const ids = [
        ...(input.post.authorMemberId ? [input.post.authorMemberId] : []),
        ...followers.map((f) => f.memberId),
      ];
      const recipients = await this.recipients(ids, input.reply.authorMemberId);
      const isQuestion = input.post.type === 'question';
      for (const r of recipients) {
        if (r.memberId === input.post.authorMemberId) {
          await this.groupedReply(r, 'community_reply', input.post.id, input.reply.id, (n) => ({
            title:
              n === 1
                ? {
                    fr: isQuestion ? 'Nouvelle réponse à ta question' : 'Nouvelle réponse à ta publication',
                    en: isQuestion ? 'New answer to your question' : 'New reply to your post',
                  }
                : {
                    fr: `${n} nouvelles réponses à ta ${isQuestion ? 'question' : 'publication'}`,
                    en: `${n} new replies to your ${isQuestion ? 'question' : 'post'}`,
                  },
            body: { fr: quote(input.post.title), en: quoteEn(input.post.title) },
          }), now);
        } else {
          await this.groupedReply(r, 'community_followed_reply', input.post.id, input.reply.id, (n) => ({
            title:
              n === 1
                ? { fr: 'Nouvelle réponse dans une discussion suivie', en: 'New reply in a discussion you follow' }
                : { fr: `${n} nouvelles réponses dans une discussion suivie`, en: `${n} new replies in a discussion you follow` },
            body: { fr: quote(input.post.title), en: quoteEn(input.post.title) },
          }), now);
        }
      }
    } catch (error) {
      this.logger.error(`Notification de réponse en échec (${error instanceof Error ? error.name : 'erreur'}).`);
    }
  }

  /** « Réponse vérifiée par KPB » posée : auteur + abonnés, une fois par réponse. */
  async verifiedAnswer(input: {
    post: { id: string; title: string; authorMemberId: string | null };
    reply: { id: string; authorMemberId: string | null };
    now?: Date;
  }): Promise<void> {
    const now = input.now ?? new Date();
    try {
      const followers =
        (await this.prisma.execute((db) =>
          db.communityFollow.findMany({ where: { postId: input.post.id }, select: { memberId: true } }),
        )) ?? [];
      const ids = [
        ...(input.post.authorMemberId ? [input.post.authorMemberId] : []),
        ...followers.map((f) => f.memberId),
      ];
      // L'auteur de la réponse vérifiée n'est pas notifié de sa propre réponse
      // comme d'une nouveauté ; les blocages se jugent par rapport à lui.
      const recipients = await this.recipients(ids, input.reply.authorMemberId);
      for (const r of recipients) {
        await this.deliver(
          r,
          'community_verified_answer',
          `community_verified_answer:${input.reply.id}:${r.userId}`,
          {
            title: { fr: 'Réponse vérifiée par KPB', en: 'Answer verified by KPB' },
            body: { fr: quote(input.post.title), en: quoteEn(input.post.title) },
          },
          postRoute(input.post.id),
          { postId: input.post.id, replyId: input.reply.id },
          r.optedOut,
          now,
        );
      }
    } catch (error) {
      this.logger.error(`Notification de réponse vérifiée en échec (${error instanceof Error ? error.name : 'erreur'}).`);
    }
  }

  /** Décision de l'équipe sur un contenu ou un membre. Jamais coupée par l'opt-out. */
  async moderation(input: {
    memberId: string;
    event: ModerationEvent;
    contentKind?: 'post' | 'reply';
    postId?: string | null;
    reason: string;
    until?: Date | null;
    referenceId: string;
    now?: Date;
  }): Promise<void> {
    const now = input.now ?? new Date();
    try {
      const [recipient] = await this.recipients([input.memberId], null);
      if (!recipient) return;
      const isPost = input.contentKind !== 'reply';
      const what = { fr: isPost ? 'Ta publication' : 'Ta réponse', en: isPost ? 'Your post' : 'Your reply' };
      const untilFr = input.until
        ? input.until.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' })
        : '';
      const untilEn = input.until
        ? input.until.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' })
        : '';
      const reason = input.reason.trim();
      const texts: Record<ModerationEvent, Texts> = {
        hidden: {
          title: { fr: `${what.fr} a été masquée`, en: `${what.en} was hidden` },
          body: { fr: `Motif : ${reason}`, en: `Reason: ${reason}` },
        },
        restored: {
          title: { fr: `${what.fr} est de nouveau visible`, en: `${what.en} is visible again` },
          body: { fr: "L'équipe KPB l'a relue : elle respecte la charte.", en: 'The KPB team reviewed it: it follows the guidelines.' },
        },
        deleted: {
          title: { fr: `${what.fr} a été supprimée`, en: `${what.en} was removed` },
          body: { fr: `Motif : ${reason}`, en: `Reason: ${reason}` },
        },
        warning: {
          title: { fr: 'Avertissement de la modération', en: 'Moderation warning' },
          body: { fr: reason, en: reason },
        },
        read_only: {
          title: {
            fr: `Ton accès à la communauté est en lecture seule jusqu'au ${untilFr}`,
            en: `Your community access is read-only until ${untilEn}`,
          },
          body: { fr: `Motif : ${reason}`, en: `Reason: ${reason}` },
        },
        ban: {
          title: { fr: 'Ton accès à la communauté est suspendu', en: 'Your community access is suspended' },
          body: { fr: `Motif : ${reason}`, en: `Reason: ${reason}` },
        },
      };
      await this.deliver(
        recipient,
        'community_moderation',
        `community_moderation:${input.event}:${input.referenceId}:${now.getTime()}`,
        texts[input.event],
        input.postId ? postRoute(input.postId) : '/community',
        { ...(input.postId ? { postId: input.postId } : {}), event: input.event },
        false,
        now,
      );
    } catch (error) {
      this.logger.error(`Notification de modération en échec (${error instanceof Error ? error.name : 'erreur'}).`);
    }
  }
}
