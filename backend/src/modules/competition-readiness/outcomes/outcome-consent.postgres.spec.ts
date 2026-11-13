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
import { OutcomeConsentService } from "./outcome-consent.service";

/**
 * Consentement « preuves de résultat » sur un vrai Postgres : la transaction
 * commence par `pg_advisory_xact_lock`. Avec `tx.$queryRaw`, Prisma 6 lève
 * « Failed to deserialize column of type 'void' » et la méthode échoue avant
 * toute écriture ; les doubles des tests unitaires ne le voient pas.
 *
 *   createdb -h /tmp kpb_it_verrous
 *   DATABASE_URL="postgresql://aminou@localhost/kpb_it_verrous?host=/tmp&schema=public" npx prisma migrate deploy
 *   DATABASE_URL=… npm run test:integration:advisory-locks
 */
describePostgres(
  "consentement preuves de résultat — verrou, PostgreSQL",
  () => {
    const prisma = new PrismaClient();
    const s = randomUUID();
    const ids = {
      userId: `lock-outcome-user-${s}`,
      scholarship: `lock-outcome-sch-${s}`,
      cycle: `lock-outcome-cyc-${s}`,
      workspace: `lock-outcome-ws-${s}`,
    };
    const service = new OutcomeConsentService(realPrismaService(prisma));
    const input = {
      purpose: "outcome_evidence" as const,
      accepted: true,
      noticeVersion: "outcome-evidence-v1",
      languageCode: "fr" as const,
    };
    let restoreEnv: () => void;

    beforeAll(async () => {
      restoreEnv = withEnv({
        KPB_COMPETITION_READINESS_ENABLED: "true",
        KPB_SUCCESS_LAB_ENABLED: "true",
        KPB_OUTCOME_EVIDENCE_ENABLED: "true",
      });
      await createAdultStudent(prisma, ids.userId);
      await createWorkspace(prisma, ids);
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
      const granted = await service.grant(ids.userId, ids.workspace, input);

      expect(granted.purpose).toBe("outcome_evidence");
      const receipt = await prisma.consentReceipt.findUniqueOrThrow({
        where: { id: granted.receiptId },
      });
      expect(receipt.userId).toBe(ids.userId);
      expect(receipt.revokedAt).toBeNull();
    });

    it("deux accords simultanés laissent un seul reçu actif", async () => {
      const [a, b] = await Promise.all([
        service.grant(ids.userId, ids.workspace, input),
        service.grant(ids.userId, ids.workspace, input),
      ]);

      // Le second attend le verrou, voit le reçu du premier et le rend.
      expect(a.receiptId).toBe(b.receiptId);
      const active = await prisma.consentReceipt.count({
        where: {
          userId: ids.userId,
          purpose: "outcome_evidence",
          revokedAt: null,
        },
      });
      expect(active).toBe(1);
    });
  },
);
