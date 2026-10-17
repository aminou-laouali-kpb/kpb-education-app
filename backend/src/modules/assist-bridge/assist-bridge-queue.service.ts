import { Injectable, Logger } from '@nestjs/common';
import type { AssistBridgeSource } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { assistBridgeCoachEnabled, assistBridgeMode } from './assist-bridge.config';
import { detectNeed } from './assist-bridge.rules';

/**
 * La FILE du bot « Passerelle » (C3 bis), appelée par les chemins d'écriture :
 * publication ou réponse de la communauté créée VISIBLE, message de l'élève
 * au coach (si la source coach est ouverte).
 *
 * La détection est une expression régulière sur le texte déjà en mémoire
 * (microsecondes) ; seul un besoin repéré écrit UNE ligne `detected` — le
 * reste (garde-fous, envoi) se fait plus tard, dans la tâche de la minute
 * (`AssistBridgeCronService`). La publication et le coach n'attendent jamais
 * le bot.
 *
 * Idempotente (`source` + `sourceId` uniques : un même message ne déclenche
 * jamais deux fois) et JAMAIS bloquante : une erreur est journalisée, jamais
 * propagée. Aucun texte n'est écrit en base par ce service.
 */
@Injectable()
export class AssistBridgeQueueService {
  private readonly logger = new Logger(AssistBridgeQueueService.name);

  constructor(private readonly prisma: PrismaService) {}

  private async record(input: {
    userId: string;
    source: AssistBridgeSource;
    sourceId: string;
    text: string;
  }): Promise<boolean> {
    const detection = detectNeed(input.text);
    if (!detection.detected) return false;
    const created = await this.prisma.execute((db) =>
      db.assistBridgeEvent.createMany({
        data: [
          {
            userId: input.userId,
            source: input.source,
            sourceId: input.sourceId,
            needId: detection.needId,
            ruleId: detection.ruleId,
            ruleVersion: detection.ruleVersion,
          },
        ],
        skipDuplicates: true,
      }),
    );
    return (created?.count ?? 0) > 0;
  }

  /**
   * Une publication ou une réponse de la communauté. Relue en base : seule une
   * contribution VISIBLE d'un MEMBRE entre, pour le compte de son auteur
   * (jamais un contenu masqué ou en revue, jamais celui de l'équipe, jamais le
   * texte d'un autre).
   */
  async enqueueCommunity(kind: 'post' | 'reply', id: string): Promise<boolean> {
    if (assistBridgeMode() === 'off' || !this.prisma.isEnabled) return false;
    try {
      if (kind === 'post') {
        const post = await this.prisma.execute((db) =>
          db.communityPost.findUnique({
            where: { id },
            select: { title: true, body: true, status: true, authorKind: true, author: { select: { userId: true } } },
          }),
        );
        if (!post || post.status !== 'visible' || post.authorKind !== 'member' || !post.author) return false;
        return await this.record({
          userId: post.author.userId,
          source: 'community_post',
          sourceId: id,
          text: `${post.title}\n${post.body}`,
        });
      }
      const reply = await this.prisma.execute((db) =>
        db.communityReply.findUnique({
          where: { id },
          select: { body: true, status: true, authorKind: true, author: { select: { userId: true } } },
        }),
      );
      if (!reply || reply.status !== 'visible' || reply.authorKind !== 'member' || !reply.author) return false;
      return await this.record({ userId: reply.author.userId, source: 'community_reply', sourceId: id, text: reply.body });
    } catch (error) {
      this.logger.warn(`Passerelle : mise en file en échec (${error instanceof Error ? error.name : 'erreur'}).`);
      return false;
    }
  }

  /**
   * Un message de l'élève au coach IA (rôle `user`), déjà enregistré. Source
   * PRIVÉE, fermée par défaut (`KPB_ASSIST_BRIDGE_COACH`). Le texte sert à la
   * détection en mémoire puis est oublié : seuls le besoin, la règle et l'id
   * du message sont écrits.
   */
  async enqueueCoach(userId: string, messageId: string, text: string): Promise<boolean> {
    if (assistBridgeMode() === 'off' || !assistBridgeCoachEnabled() || !this.prisma.isEnabled) return false;
    try {
      return await this.record({ userId, source: 'coach_message', sourceId: messageId, text });
    } catch (error) {
      this.logger.warn(`Passerelle : mise en file (coach) en échec (${error instanceof Error ? error.name : 'erreur'}).`);
      return false;
    }
  }
}
