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
import { StudyReviewConsentService } from "./study-review-consent.service";

/**
 * Consentement « partage de documents avec un conseiller » sur un vrai
 * Postgres : la transaction commence par `pg_advisory_xact_lock`. Avec
 * `tx.$queryRaw`, Prisma 6 lève « Failed to deserialize column of type
 * 'void' » avant toute écriture.
 *
 *   DATABASE_URL=… npm run test:integration:advisory-locks
 */
describePostgres(
  "consentement relecture de dossier — verrou, PostgreSQL",
  () => {
    const prisma = new PrismaClient();
    const s = randomUUID();
    const ids = { userId: `lock-review-user-${s}` };
    const service = new StudyReviewConsentService(
      realPrismaService(prisma),
      allowAllFeatures,
    );
    const input = {
      accepted: true,
      noticeVersion: "advisor-document-share-v1",
      languageCode: "fr" as const,
    };
    let restoreEnv: () => void;

    beforeAll(async () => {
      restoreEnv = withEnv({
        KPB_APPLICATION_ARTIFACTS_ENABLED: "true",
        KPB_STUDY_REVIEW_ENABLED: "true",
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

      expect(granted.purpose).toBe("advisor_document_share");
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
        where: {
          userId: ids.userId,
          purpose: "advisor_document_share",
          revokedAt: null,
        },
      });
      expect(active).toBe(1);
    });
  },
);
