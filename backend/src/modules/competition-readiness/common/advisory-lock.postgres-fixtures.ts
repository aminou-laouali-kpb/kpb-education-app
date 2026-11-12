import { AccountType, PrismaClient } from "@prisma/client";

import type { PrismaService } from "../../prisma/prisma.service";
import type { FeatureAccessService } from "./feature-access.service";

/**
 * Outils partagés par les specs Postgres des verrous consultatifs
 * (`pg_advisory_xact_lock`) du module Competition Readiness.
 *
 * Ces specs existent parce que `tx.$queryRaw` sur `SELECT pg_advisory_xact_lock(…)`
 * lève « Failed to deserialize column of type 'void' » sur un vrai Postgres,
 * alors que les tests unitaires (doubles) passaient. Seul un vrai Postgres le
 * voit : elles ne tournent qu'avec `KPB_RUN_POSTGRES_INTEGRATION=true`.
 */
export const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === "true"
    ? describe
    : describe.skip;

/** Un PrismaService réel (pas un double) branché sur le client de la spec. */
export function realPrismaService(prisma: PrismaClient): PrismaService {
  return {
    isEnabled: true,
    execute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
    tryExecute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
  } as unknown as PrismaService;
}

/** Ouvre la porte « success_lab » par utilisateur (déploiement progressif). */
export const allowAllFeatures = {
  evaluate: async () => ({ allowed: true }),
} as unknown as FeatureAccessService;

/** Pose des variables d'environnement et rend une fonction qui les restaure. */
export function withEnv(values: Record<string, string>): () => void {
  const previous = Object.fromEntries(
    Object.keys(values).map((key) => [key, process.env[key]]),
  );
  Object.assign(process.env, values);
  return () => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
}

/** Élève majeur (pas d'autorisation parentale requise). */
export function createAdultStudent(prisma: PrismaClient, userId: string) {
  return prisma.userProfile.create({
    data: {
      id: userId,
      accountType: AccountType.student,
      preferredLanguage: "fr",
      fullName: "Awa Test",
      email: `${userId}@example.test`,
      phone: "+2250700000000",
      countryOfResidence: "CI",
      birthDate: new Date("2000-01-15T00:00:00.000Z"),
    },
  });
}

/** Bourse + cycle + espace de candidature de l'élève. */
export async function createWorkspace(
  prisma: PrismaClient,
  ids: {
    userId: string;
    scholarship: string;
    cycle: string;
    workspace: string;
  },
) {
  await prisma.scholarship.create({
    data: {
      id: ids.scholarship,
      nameFr: "Bourse test verrou",
      nameEn: "Lock test scholarship",
      countryId: "test",
      levelEligibleFr: "Master",
      levelEligibleEn: "Master",
      typeOfFundingFr: "Complète",
      typeOfFundingEn: "Full",
      deadlineLabelFr: "Test",
      deadlineLabelEn: "Test",
      keyRequirementsFr: [],
      keyRequirementsEn: [],
      relatedFieldIds: [],
      sourceKey: `lock-${ids.scholarship}`,
    },
  });
  await prisma.scholarshipCycle.create({
    data: {
      id: ids.cycle,
      scholarshipId: ids.scholarship,
      academicYear: `lock-${ids.cycle}`,
    },
  });
  return prisma.scholarshipWorkspace.create({
    data: {
      id: ids.workspace,
      userId: ids.userId,
      scholarshipId: ids.scholarship,
      scholarshipCycleId: ids.cycle,
    },
  });
}

/** Supprime ce que les fixtures ont créé (reçus de consentement compris). */
export async function cleanupFixtures(
  prisma: PrismaClient,
  ids: { userId: string; scholarship?: string; cycle?: string },
) {
  await prisma.consentReceipt.deleteMany({ where: { userId: ids.userId } });
  await prisma.userProfile.deleteMany({ where: { id: ids.userId } });
  if (ids.cycle) {
    await prisma.scholarshipCycle.deleteMany({ where: { id: ids.cycle } });
  }
  if (ids.scholarship) {
    await prisma.scholarship.deleteMany({ where: { id: ids.scholarship } });
  }
}
