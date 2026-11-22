import { Injectable, Optional } from '@nestjs/common';

import { AiQuotaService, type AiQuotaPeriod } from '../ai/ai-quota.service';
import { PassService } from '../pass/pass.service';
import { PrismaService } from '../prisma/prisma.service';

const COACH_WEEKLY_LIMIT = 5;
const FEATURE = 'coach';

/**
 * Pass Karatou : KPB Intelligence « illimité ». Un plafond reste, très haut et
 * par JOUR, contre l'abus (un script, un compte partagé) : chaque message coûte
 * un appel au modèle. Un élève qui travaille ne le croise pas.
 */
export const PASS_COACH_DAILY_LIMIT = 100;
const PASS_FEATURE = 'coach_pass';

/** Le compteur décompté, pour rembourser exactement celui-là. */
export interface CoachQuotaBucket {
  feature: string;
  period: AiQuotaPeriod;
}

interface CoachPlan extends CoachQuotaBucket {
  limit: number;
  unlimited: boolean;
}

const FREE_PLAN: CoachPlan = {
  feature: FEATURE,
  period: 'week',
  limit: COACH_WEEKLY_LIMIT,
  unlimited: false,
};

const PASS_PLAN: CoachPlan = {
  feature: PASS_FEATURE,
  period: 'day',
  limit: PASS_COACH_DAILY_LIMIT,
  unlimited: true,
};

/**
 * Quota du coach. Sans Pass : 5 messages par semaine (UTC, lundi). Avec un Pass
 * Karatou actif : usage illimité, sous le garde-fou quotidien ci-dessus, sur un
 * compteur SÉPARÉ — un Pass révoqué retrouve son compteur gratuit intact.
 * Persisté en base via `AiQuotaService`.
 */
@Injectable()
export class CoachQuotaService {
  private readonly quota: AiQuotaService;

  constructor(
    @Optional() quota?: AiQuotaService,
    @Optional() prisma?: PrismaService,
    @Optional() private readonly pass?: PassService,
  ) {
    this.quota =
      quota ??
      new AiQuotaService(
        prisma ?? ({ tryExecute: async () => null } as unknown as PrismaService),
      );
  }

  /** Le Pass est relu à chaque appel : une révocation vaut tout de suite. */
  private async plan(userId: string, now: Date): Promise<CoachPlan> {
    if (!this.pass) return FREE_PLAN;
    try {
      return (await this.pass.hasActivePass(userId, now)) ? PASS_PLAN : FREE_PLAN;
    } catch {
      // Une panne de lecture du Pass ne doit pas bloquer le coach : quota gratuit.
      return FREE_PLAN;
    }
  }

  async getQuota(userId: string, now: Date = new Date()) {
    const plan = await this.plan(userId, now);
    const decision = await this.quota.peek({
      userId,
      feature: plan.feature,
      limit: plan.limit,
      period: plan.period,
      now,
    });
    return {
      quotaLimit: decision.limit,
      quotaRemaining: decision.remaining,
      quotaResetAt: decision.resetsAt.toISOString().slice(0, 10),
      unlimited: plan.unlimited,
    };
  }

  async consume(
    userId: string,
    now: Date = new Date(),
  ): Promise<{
    allowed: boolean;
    remaining: number;
    unlimited: boolean;
    bucket: CoachQuotaBucket;
  }> {
    const plan = await this.plan(userId, now);
    const decision = await this.quota.consume({
      userId,
      feature: plan.feature,
      limit: plan.limit,
      period: plan.period,
      now,
    });
    return {
      allowed: decision.allowed,
      remaining: decision.remaining,
      unlimited: plan.unlimited,
      bucket: { feature: plan.feature, period: plan.period },
    };
  }

  /**
   * Rend le message décompté quand le modèle n'a pas répondu. [now] est
   * l'instant du décompte et [bucket] le compteur alors décompté : le même est
   * visé, même si le remboursement tombe après minuit ou si le Pass a changé.
   */
  async refund(
    userId: string,
    now?: Date,
    bucket: CoachQuotaBucket = FREE_PLAN,
  ): Promise<void> {
    await this.quota.refund({
      userId,
      feature: bucket.feature,
      period: bucket.period,
      now,
    });
  }
}
