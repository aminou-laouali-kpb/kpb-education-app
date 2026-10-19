import type { PrismaService } from '../prisma/prisma.service';
import { CommunityPurgeCronService } from './community-purge-cron.service';
import {
  COMMUNITY_DELETED_RETENTION_DAYS,
  COMMUNITY_ORPHAN_REPORT_RETENTION_DAYS,
} from './community.constants';

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Chantier juridique 57 : les signalements rédigés par un compte supprimé sont
 * gardés 12 mois après la suppression, puis purgés — jamais ceux dont
 * l'auteur existe encore. Le comportement réel est vérifié contre Postgres
 * (`community.postgres.spec.ts`) ; ici, la requête et les durées.
 */
describe('CommunityPurgeCronService', () => {
  function make() {
    const calls: Record<string, unknown[]> = { reply: [], post: [], report: [] };
    const db = {
      communityReply: { deleteMany: async (args: unknown) => (calls.reply.push(args), { count: 1 }) },
      communityPost: { deleteMany: async (args: unknown) => (calls.post.push(args), { count: 2 }) },
      communityReport: { deleteMany: async (args: unknown) => (calls.report.push(args), { count: 3 }) },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof db) => unknown) => fn(db),
    } as unknown as PrismaService;
    return { service: new CommunityPurgeCronService(prisma), calls };
  }

  it('durées : 30 jours pour les contenus supprimés, 12 mois pour les signalements orphelins', () => {
    expect(COMMUNITY_DELETED_RETENTION_DAYS).toBe(30);
    expect(COMMUNITY_ORPHAN_REPORT_RETENTION_DAYS).toBe(365);
  });

  it('ne purge que les signalements SANS auteur, 12 mois après la suppression du compte', async () => {
    const { service, calls } = make();
    const now = new Date('2027-11-01T03:41:00Z');
    const result = await service.purge(now);
    expect(result).toEqual({ posts: 2, replies: 1, reports: 3 });
    const cutoff = new Date(now.getTime() - 365 * DAY_MS);
    expect(calls.report).toEqual([
      {
        where: {
          reporterMemberId: null,
          OR: [
            { reporterDeletedAt: { lt: cutoff } },
            // Orphelin d'avant la colonne : 12 mois après sa création, donc
            // jamais plus tard que 12 mois après la suppression.
            { reporterDeletedAt: null, createdAt: { lt: cutoff } },
          ],
        },
      },
    ]);
  });

  it('sans base : rien à purger, pas d’erreur', async () => {
    const prisma = { isEnabled: false, execute: async () => null } as unknown as PrismaService;
    expect(await new CommunityPurgeCronService(prisma).purge()).toEqual({
      posts: 0,
      replies: 0,
      reports: 0,
    });
  });
});
