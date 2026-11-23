/**
 * Seeds the M5 countries (ISO ids) and their eligibility quizzes.
 *
 * Create-only pour les pays : une ligne existante n'est jamais réécrite ni
 * réactivée. Le quiz d'éligibilité, qui n'est pas éditable dans l'admin, reste
 * synchronisé sur le seed.
 *
 * Refused on a production database that already holds M5 countries, unless
 * KPB_ALLOW_PRODUCTION_SEED=1 (see src/common/seed-safety.ts).
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient, Prisma } from '@prisma/client';

import { checkProductionSeed } from '../src/common/seed-safety';
import { M5_COUNTRY_SEEDS } from '../src/modules/countries/data/m5-countries.seed';

// Le conteneur API n'embarque pas de `.env` (Compose fournit DATABASE_URL) :
// un chargement inconditionnel levait ENOENT avant même le garde-fou.
if (existsSync('.env')) loadEnvFile?.('.env');

type SeedClient = Pick<PrismaClient, 'country' | 'countryEligibilityQuiz'>;

export async function seedCountriesM5(prisma: SeedClient): Promise<boolean> {
  const guard = await checkProductionSeed({
    seed: 'seed:countries-m5',
    countExistingRows: () =>
      prisma.country.count({
        where: { id: { in: M5_COUNTRY_SEEDS.map((seed) => seed.id) } },
      }),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    return false;
  }
  if (guard.message) console.warn(guard.message);

  for (const seed of M5_COUNTRY_SEEDS) {
    await prisma.country.upsert({
      where: { id: seed.id },
      // Create-only : un `update` complet réécrivait le texte édité dans
      // l'admin et remettait `isActive: true` sur un pays retiré (l'admin
      // recommande justement de désactiver plutôt que supprimer).
      update: {},
      create: {
        id: seed.id,
        code: seed.code,
        flagEmoji: seed.flagEmoji,
        nameFr: seed.nameFr,
        nameEn: seed.nameEn,
        taglineFr: seed.taglineFr,
        taglineEn: seed.taglineEn,
        nextIntakeLabelFr: seed.nextIntakeLabelFr,
        nextIntakeLabelEn: seed.nextIntakeLabelEn,
        mainLanguageFr: seed.mainLanguageFr,
        mainLanguageEn: seed.mainLanguageEn,
        whyStudyFr: seed.whyStudyFr,
        whyStudyEn: seed.whyStudyEn,
        marketingDescriptionFr: seed.marketingDescriptionFr,
        marketingDescriptionEn: seed.marketingDescriptionEn,
        whyStudyBulletsFr: seed.whyStudyBulletsFr,
        whyStudyBulletsEn: seed.whyStudyBulletsEn,
        howItWorksFr: seed.howItWorksFr,
        howItWorksEn: seed.howItWorksEn,
        costsOverviewFr: seed.costsOverviewFr,
        costsOverviewEn: seed.costsOverviewEn,
        languageSectionFr: seed.languageSectionFr,
        languageSectionEn: seed.languageSectionEn,
        partnerSchoolsFr: seed.partnerSchoolsFr,
        partnerSchoolsEn: seed.partnerSchoolsEn,
        scholarshipsSectionFr: seed.scholarshipsSectionFr,
        scholarshipsSectionEn: seed.scholarshipsSectionEn,
        whatsAppPrefillFr: seed.whatsAppPrefillFr,
        whatsAppPrefillEn: seed.whatsAppPrefillEn,
        mvpNoteFr: seed.mvpNoteFr,
        mvpNoteEn: seed.mvpNoteEn,
        tuitionRangeFr: seed.tuitionRangeFr,
        tuitionRangeEn: seed.tuitionRangeEn,
        livingCostRangeFr: seed.livingCostRangeFr,
        livingCostRangeEn: seed.livingCostRangeEn,
        visaOverviewFr: seed.visaOverviewFr,
        visaOverviewEn: seed.visaOverviewEn,
        admissionDifficultyFr: seed.admissionDifficultyFr,
        admissionDifficultyEn: seed.admissionDifficultyEn,
        popularFieldIds: seed.popularFieldIds,
        displayOrder: seed.displayOrder,
        isActive: true,
        lastVerifiedAt: seed.lastVerifiedAt
          ? new Date(seed.lastVerifiedAt)
          : null,
        sourceUrl: seed.sourceUrl ?? null,
      },
    });

    await prisma.countryEligibilityQuiz.upsert({
      where: { countryId: seed.id },
      update: {
        questions: seed.quiz.questions as unknown as Prisma.InputJsonValue,
        verdicts: seed.quiz.verdicts as unknown as Prisma.InputJsonValue,
      },
      create: {
        countryId: seed.id,
        questions: seed.quiz.questions as unknown as Prisma.InputJsonValue,
        verdicts: seed.quiz.verdicts as unknown as Prisma.InputJsonValue,
      },
    });
  }

  // Deactivate legacy duplicate ids if present.
  await prisma.country.updateMany({
    where: { id: { in: ['france', 'canada', 'uk', 'germany', 'spain'] } },
    data: { isActive: false },
  });

  const count = await prisma.country.count({ where: { isActive: true } });
  // eslint-disable-next-line no-console
  console.log(
    `M5 countries seeded (create-only, existing rows untouched). Active countries: ${count}`,
  );
  return true;
}

async function main() {
  const prisma = new PrismaClient();
  try {
    if (!(await seedCountriesM5(prisma))) process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
