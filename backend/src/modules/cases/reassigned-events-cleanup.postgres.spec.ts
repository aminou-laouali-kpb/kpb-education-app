import { randomUUID } from "node:crypto";

import {
  AccountType,
  CaseStatus,
  CaseType,
  PrismaClient,
} from "@prisma/client";

import { REASSIGNED_EVENT_TITLE } from "./case-reassignment-cron.service";
import { nettoyer, relever } from "./reassigned-events-cleanup";

/**
 * Preuve du nettoyage des « Dossier réattribué » en boucle, sur un vrai
 * Postgres (le nettoyage est du SQL à fenêtre, que seul Postgres juge).
 *
 *   createdb kpb_nettoyage_test
 *   DATABASE_URL=postgresql://…/kpb_nettoyage_test npx prisma migrate deploy
 *   KPB_RUN_POSTGRES_INTEGRATION=true DATABASE_URL=… npm run test:integration:reassigned-cleanup
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === "true"
    ? describe
    : describe.skip;

describePostgres(
  "nettoyage des « Dossier réattribué » — intégration PostgreSQL",
  () => {
    const prisma = new PrismaClient();
    const s = randomUUID();
    const userId = `nettoyage-user-${s}`;
    const enBoucle = `nettoyage-boucle-${s}`;
    const uneSeule = `nettoyage-une-${s}`;
    const T0 = new Date("2026-10-01T08:00:00.000Z");
    const h = (n: number) => new Date(T0.getTime() + n * 3_600_000);

    const dossier = (id: string, ref: string) =>
      prisma.case.create({
        data: {
          id,
          referenceCode: `KPB-NET-${ref}-${s.slice(0, 8)}`,
          userId,
          type: CaseType.consultation,
          status: CaseStatus.counselor_assigned,
          title: "Consultation",
          description: "Dossier de test du nettoyage.",
          contextLabel: "Test",
          nextStepTitle: "Un conseiller vous a été attribué",
          nextStepDescription: "Il vous contactera bientôt.",
        },
      });

    const reattribue = (caseId: string, at: Date, qui: string) => ({
      caseId,
      status: CaseStatus.counselor_assigned,
      title: REASSIGNED_EVENT_TITLE,
      description: `Votre dossier a été réattribué à ${qui}.`,
      createdAt: at,
    });

    beforeAll(async () => {
      await prisma.userProfile.create({
        data: {
          id: userId,
          accountType: AccountType.student,
          preferredLanguage: "fr",
          fullName: "Étudiant du nettoyage",
          email: `nettoyage-${s}@example.test`,
          phone: "+2250700000000",
          countryOfResidence: "CI",
        },
      });
      await dossier(enBoucle, "A");
      await dossier(uneSeule, "B");
      await prisma.caseTimelineEvent.createMany({
        data: [
          {
            caseId: enBoucle,
            status: CaseStatus.submitted,
            title: "Dossier créé",
            description: "Création depuis l’app.",
            createdAt: T0,
          },
          reattribue(enBoucle, h(10), "Jojo"),
          reattribue(enBoucle, h(20), "Richard"),
          reattribue(enBoucle, h(30), "Jojo"),
          reattribue(enBoucle, h(40), "Richard"),
          reattribue(uneSeule, h(12), "Jojo"),
        ],
      });
    });

    afterAll(async () => {
      await prisma.caseTimelineEvent.deleteMany({
        where: { caseId: { in: [enBoucle, uneSeule] } },
      });
      await prisma.case.deleteMany({
        where: { id: { in: [enBoucle, uneSeule] } },
      });
      await prisma.userProfile.deleteMany({ where: { id: userId } });
      await prisma.$disconnect();
    });

    const evenements = (caseId: string) =>
      prisma.caseTimelineEvent.findMany({
        where: { caseId },
        orderBy: { createdAt: "asc" },
        select: { title: true, description: true, createdAt: true },
      });

    it("garde la plus récente par dossier, ne touche à rien d’autre, et se rejoue à 0", async () => {
      const avant = await relever(prisma);
      expect(avant.enTrop).toBeGreaterThanOrEqual(3);

      const supprimees = await nettoyer(prisma);
      expect(supprimees).toBe(avant.enTrop);

      expect(await evenements(enBoucle)).toEqual([
        expect.objectContaining({ title: "Dossier créé", createdAt: T0 }),
        expect.objectContaining({
          title: REASSIGNED_EVENT_TITLE,
          description: "Votre dossier a été réattribué à Richard.",
          createdAt: h(40),
        }),
      ]);
      expect(await evenements(uneSeule)).toEqual([
        expect.objectContaining({
          title: REASSIGNED_EVENT_TITLE,
          createdAt: h(12),
        }),
      ]);

      const apres = await relever(prisma);
      expect(apres.dossiers).toBe(avant.dossiers);
      expect(apres.enTrop).toBe(0);
      expect(await nettoyer(prisma)).toBe(0);
    });
  },
);
