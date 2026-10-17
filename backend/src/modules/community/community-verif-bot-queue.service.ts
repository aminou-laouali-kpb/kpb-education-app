import { Injectable, Logger } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { verifBotMode } from './community-verif-bot.config';

/** États qu'une nouvelle mise en file remet à zéro (jamais publié ni rejeté). */
const RESETTABLE = ['queued', 'skipped', 'proposed', 'obsolete'] as const;

/**
 * La FILE du bot « Vérif » (C3), appelée par les chemins d'écriture de la
 * communauté (publication créée, modifiée, rétablie). Elle n'écrit qu'une
 * ligne `queued` — le travail se fait plus tard, dans la tâche de la minute
 * (`CommunityVerifBotCronService`) : la publication n'attend jamais le bot.
 *
 * Idempotente (`postId` unique : au plus un brouillon par publication) et
 * JAMAIS bloquante : une erreur est journalisée, jamais propagée. Seules les
 * QUESTIONS VISIBLES d'un MEMBRE entrent : jamais un contenu masqué ou en
 * attente de revue, jamais une publication de l'équipe.
 */
@Injectable()
export class CommunityVerifBotQueueService {
  private readonly logger = new Logger(CommunityVerifBotQueueService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Met la publication en file. `reset` (modification, rétablissement) remet
   * un brouillon existant non traité en file, pour qu'il soit refait sur le
   * texte et les faits du moment ; un brouillon publié ou rejeté ne bouge pas.
   */
  async enqueue(postId: string, options: { reset?: boolean } = {}): Promise<boolean> {
    if (verifBotMode() === 'off' || !this.prisma.isEnabled) return false;
    try {
      const result = await this.prisma.execute(async (db) => {
        const post = await db.communityPost.findUnique({
          where: { id: postId },
          select: { status: true, type: true, authorKind: true },
        });
        if (!post || post.status !== 'visible' || post.type !== 'question' || post.authorKind !== 'member') {
          return false;
        }
        const created = await db.communityBotDraft.createMany({ data: [{ postId }], skipDuplicates: true });
        if (created.count === 0 && options.reset) {
          await db.communityBotDraft.updateMany({
            where: { postId, status: { in: [...RESETTABLE] } },
            data: {
              status: 'queued',
              statusReason: null,
              attempts: 0,
              lastError: null,
            },
          });
        }
        return true;
      });
      return result ?? false;
    } catch (error) {
      this.logger.warn(
        `Mise en file du bot Vérif en échec : ${error instanceof Error ? error.name : 'erreur'}`,
      );
      return false;
    }
  }
}
