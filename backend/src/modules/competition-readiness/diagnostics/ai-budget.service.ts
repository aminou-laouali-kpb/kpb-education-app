import { createHmac } from 'node:crypto';

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import type { StructuredCompletionResult } from '../../ai/llm.service';
import { PrismaService } from '../../prisma/prisma.service';
import { utcTimestamp } from '../../../common/sql-time';
import {
  estimateAiCostMicrosUsd,
  parseMicrosUsd,
  type AiModelRates,
} from './ai-cost.policy';

const FEATURE = 'success_lab_diagnostic';

type BudgetBlockReason =
  | 'budget_not_configured'
  | 'price_not_configured'
  | 'daily_cap_reached'
  | 'user_attempt_cap_reached'
  | 'monthly_budget_exhausted';

export type AiBudgetReservation = {
  allowed: true;
  diagnosticId: string;
  budgetPeriodId: string;
  attemptKey: string;
  attemptNumber: number;
  priceVersion: string;
  reservedMicrosUsd: bigint;
  rates: AiModelRates;
};

export type AiBudgetDecision =
  AiBudgetReservation | { allowed: false; reason: BudgetBlockReason };

class ReservationBlocked extends Error {
  constructor(readonly reason: BudgetBlockReason) {
    super(reason);
  }
}

function positiveInteger(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function utcDay(now: Date) {
  return now.toISOString().slice(0, 10);
}

function utcMonth(now: Date) {
  return now.toISOString().slice(0, 7);
}

function startOfNextUtcDay(now: Date): Date {
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
  );
}

function monthBounds(now: Date): { startsAt: Date; endsAt: Date } {
  return {
    startsAt: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)),
    endsAt: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)),
  };
}

@Injectable()
export class AiBudgetService {
  constructor(private readonly prismaService: PrismaService) {}

  async reserve(input: {
    userId: string;
    diagnosticId: string;
    attemptKey: string;
    attemptNumber: number;
    provider: string;
    model: string;
    promptVersion: string;
    now?: Date;
  }): Promise<AiBudgetDecision> {
    const now = input.now ?? new Date();
    const configuredBudget = parseMicrosUsd(
      process.env.KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD,
    );
    const priceVersion =
      process.env.KPB_AI_DIAGNOSTIC_PRICE_VERSION?.trim() ?? '';
    if (!configuredBudget) {
      return { allowed: false, reason: 'budget_not_configured' };
    }
    if (!priceVersion) {
      return { allowed: false, reason: 'price_not_configured' };
    }
    if (!this.prismaService.isEnabled) {
      return { allowed: false, reason: 'budget_not_configured' };
    }

    const dailyCap = positiveInteger(
      process.env.KPB_AI_DIAGNOSTIC_DAILY_CALL_CAP,
      100,
    );
    const userAttemptCap = positiveInteger(
      process.env.KPB_AI_DIAGNOSTIC_USER_DAILY_ATTEMPT_CAP,
      3,
    );
    const maxInputTokens = positiveInteger(
      process.env.KPB_AI_DIAGNOSTIC_MAX_BILLABLE_INPUT_TOKENS,
      12_000,
    );
    const maxOutputTokens = positiveInteger(
      process.env.KPB_AI_DIAGNOSTIC_MAX_OUTPUT_TOKENS,
      220,
    );
    const periodKey = utcMonth(now);
    const dayKey = utcDay(now);
    const { startsAt, endsAt } = monthBounds(now);

    try {
      const reservation = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          // Serializes the small pilot quota allocation section across API
          // instances. The provider call happens after this transaction.
          await tx.$executeRaw(
            Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`${FEATURE}:${dayKey}`}))`,
          );

          const existingAttempt = await tx.aiUsageAttempt.findUnique({
            where: { attemptKey: input.attemptKey },
          });
          if (existingAttempt) {
            const period = await tx.aiBudgetPeriod.findUnique({
              where: { feature_periodKey: { feature: FEATURE, periodKey } },
            });
            const price = await tx.aiModelPrice.findUnique({
              where: { priceVersion },
            });
            const transaction = await tx.aiBudgetTransaction.findUnique({
              where: { dedupeKey: `reserve:${input.attemptKey}` },
            });
            if (!period || !price || !transaction) {
              throw new ReservationBlocked('price_not_configured');
            }
            return {
              allowed: true as const,
              diagnosticId: input.diagnosticId,
              budgetPeriodId: period.id,
              attemptKey: input.attemptKey,
              attemptNumber: existingAttempt.attemptNumber,
              priceVersion,
              reservedMicrosUsd: transaction.reservedDeltaMicrosUsd,
              rates: this.rates(price),
            };
          }

          const globalAttempts = await tx.aiUsageAttempt.count({
            where: {
              feature: FEATURE,
              createdAt: { gte: new Date(`${dayKey}T00:00:00.000Z`) },
            },
          });
          if (globalAttempts >= dailyCap) {
            throw new ReservationBlocked('daily_cap_reached');
          }

          const price = await tx.aiModelPrice.findUnique({
            where: { priceVersion },
          });
          if (
            !price ||
            price.provider !== input.provider ||
            price.model !== input.model ||
            price.effectiveAt > now ||
            (price.retiredAt !== null && price.retiredAt <= now)
          ) {
            throw new ReservationBlocked('price_not_configured');
          }
          const rates = this.rates(price);
          const reservedMicrosUsd = estimateAiCostMicrosUsd(
            {
              inputTokens: maxInputTokens,
              outputTokens: maxOutputTokens,
            },
            rates,
          );
          if (reservedMicrosUsd <= 0n) {
            throw new ReservationBlocked('price_not_configured');
          }

          await tx.aiQuotaBucket.upsert({
            where: {
              userId_feature_periodKey: {
                userId: input.userId,
                feature: FEATURE,
                periodKey: dayKey,
              },
            },
            create: {
              userId: input.userId,
              feature: FEATURE,
              periodKey: dayKey,
              quotaLimit: userAttemptCap,
              resetsAt: startOfNextUtcDay(now),
            },
            update: { resetsAt: startOfNextUtcDay(now) },
          });
          const quota = await tx.aiQuotaBucket.updateMany({
            where: {
              userId: input.userId,
              feature: FEATURE,
              periodKey: dayKey,
              used: { lt: userAttemptCap },
            },
            data: { used: { increment: 1 }, version: { increment: 1 } },
          });
          if (quota.count !== 1) {
            throw new ReservationBlocked('user_attempt_cap_reached');
          }

          const period = await tx.aiBudgetPeriod.upsert({
            where: { feature_periodKey: { feature: FEATURE, periodKey } },
            create: {
              feature: FEATURE,
              periodKey,
              budgetMicrosUsd: configuredBudget,
              startsAt,
              endsAt,
            },
            update: {},
          });
          const budgetRows = await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              UPDATE "AiBudgetPeriod"
              SET "reservedMicrosUsd" = "reservedMicrosUsd" + ${reservedMicrosUsd},
                  "version" = "version" + 1,
                  "updatedAt" = ${utcTimestamp(now)}
              WHERE "id" = ${period.id}
                AND "spentMicrosUsd" + "reservedMicrosUsd" + ${reservedMicrosUsd} <= "budgetMicrosUsd"
              RETURNING "id"
            `,
          );
          if (budgetRows.length !== 1) {
            throw new ReservationBlocked('monthly_budget_exhausted');
          }

          await tx.aiBudgetTransaction.create({
            data: {
              budgetPeriodId: period.id,
              diagnosticId: input.diagnosticId,
              dedupeKey: `reserve:${input.attemptKey}`,
              reason: 'provider_attempt_reserved',
              reservedDeltaMicrosUsd: reservedMicrosUsd,
            },
          });
          await tx.aiUsageAttempt.create({
            data: {
              diagnosticId: input.diagnosticId,
              actorKey: this.actorKey(input.userId),
              attemptKey: input.attemptKey,
              attemptNumber: input.attemptNumber,
              feature: FEATURE,
              provider: input.provider,
              model: input.model,
              promptVersion: input.promptVersion,
              priceVersion,
              outcome: 'reserved',
              startedAt: now,
            },
          });

          return {
            allowed: true as const,
            diagnosticId: input.diagnosticId,
            budgetPeriodId: period.id,
            attemptKey: input.attemptKey,
            attemptNumber: input.attemptNumber,
            priceVersion,
            reservedMicrosUsd,
            rates,
          };
        }),
      );
      return reservation ?? { allowed: false, reason: 'budget_not_configured' };
    } catch (error) {
      if (error instanceof ReservationBlocked) {
        return { allowed: false, reason: error.reason };
      }
      throw error;
    }
  }

  async settle<T>(
    reservation: AiBudgetReservation,
    result: StructuredCompletionResult<T>,
    now = new Date(),
  ): Promise<bigint> {
    const estimatedCostMicrosUsd = estimateAiCostMicrosUsd(
      {
        inputTokens: result.inputTokens ?? 0,
        cachedInputTokens: result.cachedInputTokens,
        outputTokens: result.outputTokens ?? 0,
      },
      reservation.rates,
    );
    if (estimatedCostMicrosUsd > reservation.reservedMicrosUsd) {
      throw new Error('Provider cost exceeded the conservative reservation.');
    }

    const settled = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const dedupeKey = `settle:${reservation.attemptKey}`;
        const existing = await tx.aiBudgetTransaction.findUnique({
          where: { dedupeKey },
        });
        if (existing) return existing.spentDeltaMicrosUsd;

        const rows = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            UPDATE "AiBudgetPeriod"
            SET "reservedMicrosUsd" = "reservedMicrosUsd" - ${reservation.reservedMicrosUsd},
                "spentMicrosUsd" = "spentMicrosUsd" + ${estimatedCostMicrosUsd},
                "version" = "version" + 1,
                "updatedAt" = ${utcTimestamp(now)}
            WHERE "id" = ${reservation.budgetPeriodId}
              AND "reservedMicrosUsd" >= ${reservation.reservedMicrosUsd}
              AND "spentMicrosUsd" + ${estimatedCostMicrosUsd} <= "budgetMicrosUsd"
            RETURNING "id"
          `,
        );
        if (rows.length !== 1) {
          throw new Error('AI budget settlement invariant failed.');
        }

        await tx.aiUsageAttempt.update({
          where: { attemptKey: reservation.attemptKey },
          data: {
            usageSource: result.provider !== 'local' ? 'provider' : 'fallback',
            inputTokens: result.inputTokens,
            cachedInputTokens: result.cachedInputTokens,
            outputTokens: result.outputTokens,
            totalTokens: result.totalTokens,
            latencyMs: result.latencyMs,
            estimatedCostMicrosUsd,
            providerRequestId: result.providerRequestId,
            outcome: result.outcome,
            errorCode: result.fallbackReason,
            completedAt: now,
          },
        });
        await tx.aiBudgetTransaction.create({
          data: {
            budgetPeriodId: reservation.budgetPeriodId,
            diagnosticId: reservation.diagnosticId,
            dedupeKey,
            reason: 'provider_attempt_settled',
            reservedDeltaMicrosUsd: -reservation.reservedMicrosUsd,
            spentDeltaMicrosUsd: estimatedCostMicrosUsd,
          },
        });
        return estimatedCostMicrosUsd;
      }),
    );
    return settled ?? 0n;
  }

  private rates(price: {
    inputMicrosUsdPerM: bigint;
    cachedInputMicrosUsdPerM: bigint | null;
    outputMicrosUsdPerM: bigint;
  }): AiModelRates {
    return {
      inputMicrosUsdPerMillion: price.inputMicrosUsdPerM,
      cachedInputMicrosUsdPerMillion: price.cachedInputMicrosUsdPerM,
      outputMicrosUsdPerMillion: price.outputMicrosUsdPerM,
    };
  }

  private actorKey(userId: string): string | null {
    const secret = process.env.KPB_ANALYTICS_ACTOR_SECRET?.trim();
    return secret
      ? createHmac('sha256', secret).update(userId).digest('hex')
      : null;
  }
}
