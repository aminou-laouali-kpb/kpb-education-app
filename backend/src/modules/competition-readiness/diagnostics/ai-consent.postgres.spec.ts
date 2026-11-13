import { randomUUID } from "node:crypto";

import { PrismaClient } from "@prisma/client";

import {
  allowAllFeatures,
  cleanupFixtures,
  createAdultStudent,
  describePostgres,
  realPrismaService,
  withEnv,
} from "../common/advisory-lock.postgres-fixtures";
import { AiConsentService } from "./ai-consent.service";

/**
 * Consentement IA (tiers) sur un vrai Postgres : la transaction commence par
 * `pg_advisory_xact_lock`. Avec `tx.$queryRaw`, Prisma 6 lève « Failed to
 * deserialize column of type 'void' » avant toute écriture.
 *
 *   DATABASE_URL=… npm run test:integration:advisory-locks
 */
describePostgres("consentement IA — verrou, PostgreSQL", () => {
  const prisma = new PrismaClient();
  const s = randomUUID();
  const ids = { userId: `lock-ai-consent-user-${s}` };
  const service = new AiConsentService(
    realPrismaService(prisma),
    allowAllFeatures,
  );
  const input = {
    accepted: true,
    noticeVersion: "ai-diagnostic-v1",
    languageCode: "fr" as const,
  };
  let restoreEnv: () => void;

  beforeAll(async () => {
    restoreEnv = withEnv({
      KPB_AI_DIAGNOSTIC_ENABLED: "true",
      KPB_AI_DIAGNOSTIC_KILL_SWITCH: "false",
    });
    await createAdultStudent(prisma, ids.userId);
  });

  beforeEach(() =>
    prisma.consentReceipt.deleteMany({ where: { userId: ids.userId } }),
  );

  afterAll(async () => {
    restoreEnv();
    await cleanupFixtures(prisma, ids);
    await prisma.$disconnect();
  });

  it("enregistre le consentement (la transaction passe le verrou)", async () => {
    const granted = await service.grant(ids.userId, input);

    expect(granted.purpose).toBe("ai_third_party");
    const receipt = await prisma.consentReceipt.findUniqueOrThrow({
      where: { id: granted.receiptId },
    });
    expect(receipt.userId).toBe(ids.userId);
    expect(receipt.revokedAt).toBeNull();
  });

  it("deux accords simultanés laissent un seul reçu actif", async () => {
    const [a, b] = await Promise.all([
      service.grant(ids.userId, input),
      service.grant(ids.userId, input),
    ]);

    expect(a.receiptId).toBe(b.receiptId);
    const active = await prisma.consentReceipt.count({
      where: { userId: ids.userId, purpose: "ai_third_party", revokedAt: null },
    });
    expect(active).toBe(1);
  });
});
