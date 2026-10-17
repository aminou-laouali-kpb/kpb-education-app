import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { COMMUNITY_DELETED_RETENTION_DAYS } from './community.constants';

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Purge définitive des contenus supprimés (§12 du contrat) : un contenu retiré
 * par son auteur ou par l'équipe reste 30 jours lisible par l'équipe — preuve
 * en cas d'arnaque — puis disparaît (cascade : mentions, réactions,
 * signalements, réponses d'une publication).
 *
 * Chaque jour à 03 h 41 UTC. Une erreur est journalisée, jamais propagée.
 */
@Injectable()
export class CommunityPurgeCronService {
  private readonly logger = new Logger(CommunityPurgeCronService.name);

  constructor(private readonly prisma: PrismaService) {}

  async purge(now: Date = new Date()): Promise<{ posts: number; replies: number }> {
    const before = new Date(now.getTime() - COMMUNITY_DELETED_RETENTION_DAYS * DAY_MS);
    const result = await this.prisma.execute(async (db) => {
      const replies = await db.communityReply.deleteMany({
        where: { status: 'deleted', deletedAt: { lt: before } },
      });
      const posts = await db.communityPost.deleteMany({
        where: { status: 'deleted', deletedAt: { lt: before } },
      });
      return { posts: posts.count, replies: replies.count };
    });
    return result ?? { posts: 0, replies: 0 };
  }

  @Cron('41 3 * * *')
  async run(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    try {
      const { posts, replies } = await this.purge();
      if (posts + replies > 0) {
        this.logger.log(`${posts} publication(s) et ${replies} réponse(s) supprimées purgées.`);
      }
    } catch (error) {
      this.logger.error(
        `Purge de la communauté en échec : ${error instanceof Error ? error.name : 'erreur'}`,
      );
    }
  }
}
