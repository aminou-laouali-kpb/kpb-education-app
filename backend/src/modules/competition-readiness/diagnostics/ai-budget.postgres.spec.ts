import { randomUUID } from "node:crypto";

import { PrismaClient } from "@prisma/client";

import {
  cleanupFixtures,
  createAdultStudent,
  createWorkspace,
  describePostgres,
  realPrismaService,
  withEnv,
} from "../common/advisory-lock.postgres-fixtures";
import { AiBudgetService } from "./ai-budget.service";

const FEATURE = "success_lab_diagnostic";

/**
 * Réservation du budget IA sur un vrai Postgres : la transaction commence par
 * `pg_advisory_xact_lock` (clé = fonctionnalité + jour UTC). Avec
 * `tx.$queryRaw`, Prisma 6 lève « Failed to deserialize column of type
 * 'void' » : `reserve()` ne le traite pas comme un refus de budget, l'erreur
 * remonte à l'appelant (le diagnostic IA).
 *
 * Le cas simultané prouve que le verrou sérialise vraiment le plafond
 * quotidien global (compter puis insérer) : deux réservations au dernier
 * créneau, une seule passe.
 *
 *   DATABASE_URL=… npm run test:integration:advisory-locks
 */
describePostgres("budget IA — verrou, PostgreSQL", () => {
  const prisma = new PrismaClient();
  const s = randomUUID();
  const ids = {
    userId: `lock-budget-user-${s}`,
    scholarship: `lock-budget-sch-${s}`,
    cycle: `lock-budget-cyc-${s}`,
    workspace: `lock-budget-ws-${s}`,
    diagnostic: `lock-budget-diag-${s}`,
  };
  const priceVersion = `lock-budget-price-${s}`;
  const provider = "openrouter";
  const model = "lock-test-model";
  const service = new AiBudgetService(realPrismaService(prisma));
  let attempt = 0;
  const reserve = () => {
    attempt += 1;
    return service.reserve({
      userId: ids.userId,
      diagnosticId: ids.diagnostic,
      attemptKey: `${ids.diagnostic}:${attempt}`,
      attemptNumber: attempt,
      provider,
      model,
      promptVersion: "success-lab-v1",
    });
  };
  const attemptsToday = () =>
    prisma.aiUsageAttempt.count({
      where: {
        feature: FEATURE,
        createdAt: {
          gte: new Date(
            `${new Date().toISOString().slice(0, 10)}T00:00:00.000Z`,
          ),
        },
      },
    });
  let restoreEnv: () => void;

  beforeAll(async () => {
    restoreEnv = withEnv({
      KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD: "1000000000000",
      KPB_AI_DIAGNOSTIC_PRICE_VERSION: priceVersion,
      KPB_AI_DIAGNOSTIC_USER_DAILY_ATTEMPT_CAP: "50",
      KPB_AI_DIAGNOSTIC_DAILY_CALL_CAP: "100000",
    });
    await createAdultStudent(prisma, ids.userId);
    await createWorkspace(prisma, ids);
    await prisma.aiDiagnostic.create({
      data: {
        id: ids.diagnostic,
        workspaceId: ids.workspace,
        entitlementKey: `lock-budget-${s}`,
        promptVersion: "success-lab-v1",
      },
    });
    await prisma.aiModelPrice.create({
      data: {
        priceVersion,
        provider,
        model,
        inputMicrosUsdPerM: 1_000_000n,
        outputMicrosUsdPerM: 2_000_000n,
        effectiveAt: new Date("2026-01-01T00:00:00.000Z"),
      },
    });
  });

  afterAll(async () => {
    restoreEnv();
    const transactions = await prisma.aiBudgetTransaction.findMany({
      where: { diagnosticId: ids.diagnostic },
      select: { budgetPeriodId: true },
    });
    await prisma.aiBudgetTransaction.deleteMany({
      where: { diagnosticId: ids.diagnostic },
    });
    // Rend la période du mois à son état d'avant la spec si plus rien n'y est
    // rattaché (bases locales réutilisées d'un passage à l'autre).
    for (const periodId of new Set(transactions.map((t) => t.budgetPeriodId))) {
      const remaining = await prisma.aiBudgetTransaction.count({
        where: { budgetPeriodId: periodId },
      });
      if (remaining === 0) {
        await prisma.aiBudgetPeriod.deleteMany({ where: { id: periodId } });
      }
    }
    await prisma.aiUsageAttempt.deleteMany({
      where: { diagnosticId: ids.diagnostic },
    });
    await prisma.aiModelPrice.deleteMany({ where: { priceVersion } });
    await prisma.scholarshipWorkspace.deleteMany({
      where: { id: ids.workspace },
    });
    await cleanupFixtures(prisma, ids);
    await prisma.$disconnect();
  });

  it("réserve une tentative (la transaction passe le verrou)", async () => {
    const decision = await reserve();

    expect(decision.allowed).toBe(true);
    if (!decision.allowed) return;
    expect(decision.reservedMicrosUsd).toBeGreaterThan(0n);
    const row = await prisma.aiUsageAttempt.findUniqueOrThrow({
      where: { attemptKey: decision.attemptKey },
    });
    expect(row.outcome).toBe("reserved");
  });

  it("deux réservations simultanées au dernier créneau du jour : une seule passe", async () => {
    process.env.KPB_AI_DIAGNOSTIC_DAILY_CALL_CAP = String(
      (await attemptsToday()) + 1,
    );
    try {
      const decisions = await Promise.all([reserve(), reserve()]);

      expect(decisions.filter((d) => d.allowed)).toHaveLength(1);
      expect(decisions.filter((d) => !d.allowed)).toEqual([
        { allowed: false, reason: "daily_cap_reached" },
      ]);
    } finally {
      process.env.KPB_AI_DIAGNOSTIC_DAILY_CALL_CAP = "100000";
    }
  });
});
