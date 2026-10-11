import { Injectable, Logger } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

export type AiQuotaDecision = {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetsAt: Date;
};

export type AiQuotaPeriod = 'day' | 'week';

/**
 * Quotas IA par utilisateur, persistés dans `AiQuotaBucket` (même table que le
 * diagnostic Success Lab ; déjà purgée à la suppression de compte et incluse
 * dans l'export RGPD).
 *
 * Un quota en mémoire repartait à zéro à chaque redéploiement ou redémarrage :
 * il ne bornait rien. La consommation est atomique (`used < limit` dans le
 * `WHERE` de l'incrément), donc deux requêtes simultanées ne dépassent pas la
 * limite.
 *
 * Sans base (dev local) ou si la base échoue, repli en mémoire : on préfère
 * laisser passer un étudiant plutôt que couper l'outil sur une panne DB.
 */
@Injectable()
export class AiQuotaService {
  private readonly logger = new Logger(AiQuotaService.name);
  private readonly memory = new Map<string, number>();

  constructor(private readonly prisma: PrismaService) {}

  async consume(input: {
    userId: string;
    feature: string;
    limit: number;
    period?: AiQuotaPeriod;
    now?: Date;
  }): Promise<AiQuotaDecision> {
    const now = input.now ?? new Date();
    const period = input.period ?? 'day';
    const { periodKey, resetsAt } = periodBounds(now, period);
    const key = { userId: input.userId, feature: input.feature, periodKey };

    const used = await this.prisma.tryExecute((client) =>
      client.$transaction(async (tx) => {
        await tx.aiQuotaBucket.upsert({
          where: { userId_feature_periodKey: key },
          create: { ...key, quotaLimit: input.limit, resetsAt },
          update: { quotaLimit: input.limit },
        });
        const incremented = await tx.aiQuotaBucket.updateMany({
          where: { ...key, used: { lt: input.limit } },
          data: { used: { increment: 1 }, version: { increment: 1 } },
        });
        const bucket = await tx.aiQuotaBucket.findUnique({
          where: { userId_feature_periodKey: key },
          select: { used: true },
        });
        return { allowed: incremented.count === 1, used: bucket?.used ?? 0 };
      }),
    );

    if (used) {
      return {
        allowed: used.allowed,
        limit: input.limit,
        remaining: Math.max(0, input.limit - used.used),
        resetsAt,
      };
    }

    // Repli mémoire (pas de base, ou base en échec).
    const memoryKey = `${input.userId}|${input.feature}|${periodKey}`;
    const count = this.memory.get(memoryKey) ?? 0;
    if (count >= input.limit) {
      return { allowed: false, limit: input.limit, remaining: 0, resetsAt };
    }
    this.memory.set(memoryKey, count + 1);
    if (this.memory.size > 50_000) this.memory.clear();
    return {
      allowed: true,
      limit: input.limit,
      remaining: input.limit - count - 1,
      resetsAt,
    };
  }

  /** Lecture sans consommation (affichage du quota restant). */
  async peek(input: {
    userId: string;
    feature: string;
    limit: number;
    period?: AiQuotaPeriod;
    now?: Date;
  }): Promise<AiQuotaDecision> {
    const now = input.now ?? new Date();
    const { periodKey, resetsAt } = periodBounds(now, input.period ?? 'day');
    const bucket = await this.prisma.tryExecute((client) =>
      client.aiQuotaBucket.findUnique({
        where: {
          userId_feature_periodKey: {
            userId: input.userId,
            feature: input.feature,
            periodKey,
          },
        },
        select: { used: true },
      }),
    );
    const used =
      bucket?.used ??
      this.memory.get(`${input.userId}|${input.feature}|${periodKey}`) ??
      0;
    return {
      allowed: used < input.limit,
      limit: input.limit,
      remaining: Math.max(0, input.limit - used),
      resetsAt,
    };
  }
}

export function periodBounds(
  now: Date,
  period: AiQuotaPeriod,
): { periodKey: string; resetsAt: Date } {
  if (period === 'day') {
    return {
      periodKey: now.toISOString().slice(0, 10),
      resetsAt: new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
      ),
    };
  }
  // Semaine ISO commençant le lundi (UTC).
  const day = now.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  const monday = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + diff),
  );
  return {
    periodKey: `w${monday.toISOString().slice(0, 10)}`,
    resetsAt: new Date(monday.getTime() + 7 * 24 * 60 * 60 * 1000),
  };
}
