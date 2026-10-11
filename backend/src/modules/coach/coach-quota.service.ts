import { Injectable, Optional } from '@nestjs/common';

import { AiQuotaService } from '../ai/ai-quota.service';
import { PrismaService } from '../prisma/prisma.service';

const COACH_WEEKLY_LIMIT = 5;
const FEATURE = 'coach';

/**
 * Quota hebdomadaire du coach (5 messages, semaine UTC commençant le lundi).
 * Persisté en base via `AiQuotaService` : l'ancienne `Map` en mémoire
 * repartait à zéro à chaque redéploiement ou redémarrage du process.
 */
@Injectable()
export class CoachQuotaService {
  private readonly quota: AiQuotaService;

  constructor(
    @Optional() quota?: AiQuotaService,
    @Optional() prisma?: PrismaService,
  ) {
    this.quota =
      quota ??
      new AiQuotaService(
        prisma ?? ({ tryExecute: async () => null } as unknown as PrismaService),
      );
  }

  async getQuota(userId: string) {
    const decision = await this.quota.peek({
      userId,
      feature: FEATURE,
      limit: COACH_WEEKLY_LIMIT,
      period: 'week',
    });
    return {
      quotaLimit: decision.limit,
      quotaRemaining: decision.remaining,
      quotaResetAt: decision.resetsAt.toISOString().slice(0, 10),
    };
  }

  async consume(userId: string): Promise<{ allowed: boolean; remaining: number }> {
    const decision = await this.quota.consume({
      userId,
      feature: FEATURE,
      limit: COACH_WEEKLY_LIMIT,
      period: 'week',
    });
    return { allowed: decision.allowed, remaining: decision.remaining };
  }
}
