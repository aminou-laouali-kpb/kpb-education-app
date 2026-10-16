/**
 * Seeds OMNES France private-school programs from normalized JSON.
 *
 * The same formation is often delivered on several campuses (e.g. the INSEEC
 * "Bachelor Marketing" runs in Bordeaux, Lyon, Paris…). Rather than create one
 * near-identical Program per campus, we group by (school, campus-agnostic
 * formation name) and store the per-campus price/intake in `campusOfferings`.
 *
 *   Institution = the SCHOOL (INSEEC, ECE, ESCE, HEIP, Sup de Pub) — 5 total.
 *   Program     = one campus-agnostic formation, carrying campusOfferings[].
 *
 * Create-only: a school that already exists is left exactly as it is, together
 * with its formations, and nothing is ever deleted. This script used to
 * `deleteMany` every `omnes-*` row before recreating them, wiping every edit
 * made in the admin. A missing school is created with its missing formations
 * in one transaction, and its `programIds` lists the formations actually
 * attached to it.
 *
 * Refused on a production database that already holds `omnes-*` rows, unless
 * KPB_ALLOW_PRODUCTION_SEED=1 (see src/common/seed-safety.ts).
 *
 * Usage:
 *   npm run import:omnes:bundled && npm run seed:omnes
 *   ts-node scripts/seed-omnes-programs.ts [path-to-json]
 */
import { loadEnvFile } from 'node:process';
import * as fs from 'node:fs';
import * as path from 'node:path';

import { Prisma, PrismaClient } from '@prisma/client';

import { checkProductionSeed, linkedProgramIds } from '../src/common/seed-safety';
import {
  OMNES_INSTITUTION_ID_PREFIX as INSTITUTION_ID_PREFIX,
  OMNES_PROGRAM_ID_PREFIX as PROGRAM_ID_PREFIX,
  type OmnesRow,
  formatDuration,
  formatLevel,
  formatTuitionSummary,
  inferFieldId,
  intakeLabel,
  omnesInstitutionId as institutionId,
  studyLevelsFor,
} from '../src/modules/catalog/omnes-conventions';
import { omnesFormationIdentity } from '../src/modules/catalog/catalog-dedupe';
import { M5_COUNTRY_SEEDS } from '../src/modules/countries/data/m5-countries.seed';

// Compose supplies DATABASE_URL (and NODE_ENV) to the API container, whose
// image ships no .env: an unconditional load threw ENOENT there before the
// production guard could even run.
if (fs.existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

const FRANCE_COUNTRY_ID = 'fra';

/** One campus on which a formation is available, with its own price/intake. */
type CampusOffering = {
  campus: string;
  tuitionUpfront: number | null;
  tuitionInstallments: number | null;
  intake: string | null;
};

async function ensureFranceCountry() {
  const seed = M5_COUNTRY_SEEDS.find((item) => item.id === FRANCE_COUNTRY_ID);
  if (!seed) {
    throw new Error(`M5 seed missing for country ${FRANCE_COUNTRY_ID}`);
  }

  await prisma.country.upsert({
    where: { id: seed.id },
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
    },
  });
}

// --- Grouping accumulators -------------------------------------------------

type InstitutionAcc = {
  school: string;
  campuses: Set<string>;
  levels: Set<string>;
  intakes: Set<string>;
  programIds: Set<string>;
  prices: number[];
};

type OfferingAcc = {
  tuitionUpfront: number | null;
  tuitionInstallments: number | null;
  intakes: Set<string>;
};

type FormationAcc = {
  progId: string;
  instId: string;
  fieldId: string;
  name: string;
  level: { fr: string; en: string };
  duration: { fr: string; en: string };
  languages: Set<string>;
  requirements: Set<string>;
  // Keyed by campus so each campus contributes exactly one offering.
  offerings: Map<string, OfferingAcc>;
};

async function main() {
  const guard = await checkProductionSeed({
    seed: 'seed:omnes',
    countExistingRows: async () =>
      (await prisma.institution.count({
        where: { id: { startsWith: INSTITUTION_ID_PREFIX } },
      })) +
      (await prisma.program.count({
        where: { id: { startsWith: PROGRAM_ID_PREFIX } },
      })),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  const jsonPath =
    process.argv[2] ??
    path.resolve(__dirname, 'output', 'omnes-programs-normalized.json');

  if (!fs.existsSync(jsonPath)) {
    throw new Error(
      `OMNES JSON not found at ${jsonPath}. Run npm run import:omnes first.`,
    );
  }

  const rows = JSON.parse(fs.readFileSync(jsonPath, 'utf-8')) as OmnesRow[];
  if (!rows.length) throw new Error('OMNES JSON is empty.');

  await ensureFranceCountry();

  const institutions = new Map<string, InstitutionAcc>();
  const formations = new Map<string, FormationAcc>();

  for (const row of rows) {
    const instId = institutionId(row.school);
    // Id historique (production), rapproché par la table de catalog-dedupe.ts :
    // une variante d'écriture de la grille (casse, accent, campus resté dans
    // l'intitulé) retombe sur la fiche canonique au lieu d'en créer une
    // seconde. Le nom affiché est l'intitulé sans campus.
    const { id: progId, name: formationName, isAlias } = omnesFormationIdentity(
      row.school,
      row.programName,
      row.campus,
    );
    const campus = row.campus || '—';

    // --- institution-level aggregation ---
    const inst = institutions.get(instId) ?? {
      school: row.school,
      campuses: new Set<string>(),
      levels: new Set<string>(),
      intakes: new Set<string>(),
      programIds: new Set<string>(),
      prices: [],
    };
    inst.campuses.add(campus);
    studyLevelsFor(row).forEach((l) => inst.levels.add(l));
    intakeLabel(row.intakeDate).forEach((i) => inst.intakes.add(i));
    inst.programIds.add(progId);
    if (row.paymentUpfront != null) inst.prices.push(row.paymentUpfront);
    institutions.set(instId, inst);

    // --- formation-level aggregation ---
    const formation = formations.get(progId) ?? {
      progId,
      instId,
      fieldId: inferFieldId(row),
      name: formationName,
      level: formatLevel(row),
      duration: formatDuration(row),
      languages: new Set<string>(),
      requirements: new Set<string>(),
      offerings: new Map<string, OfferingAcc>(),
    };
    // Le nom d'une ligne canonique l'emporte sur celui d'une variante.
    if (!isAlias) formation.name = formationName;
    if (row.language) formation.languages.add(row.language);
    if (row.admissionLevel) formation.requirements.add(row.admissionLevel);

    const offering = formation.offerings.get(campus) ?? {
      tuitionUpfront: null,
      tuitionInstallments: null,
      intakes: new Set<string>(),
    };
    // Keep the first known price for a campus; never overwrite a value with null.
    if (offering.tuitionUpfront == null) offering.tuitionUpfront = row.paymentUpfront;
    if (offering.tuitionInstallments == null) {
      offering.tuitionInstallments = row.paymentInstallments;
    }
    if (row.intakeDate) offering.intakes.add(row.intakeDate);
    formation.offerings.set(campus, offering);

    formations.set(progId, formation);
  }

  // --- write schools that do not exist yet, each with its formations ---
  const formationList = [...formations.values()];
  let createdInstitutions = 0;
  let createdPrograms = 0;
  const keptInstitutions: string[] = [];

  for (const [instId, inst] of institutions.entries()) {
    const cities = [...inst.campuses].sort((a, b) => a.localeCompare(b, 'fr'));
    const tuitionLabel = inst.prices.length
      ? formatTuitionSummary(
          inst.prices.map((p) => ({
            campus: '',
            tuitionUpfront: p,
            tuitionInstallments: null,
            intake: null,
          })),
        )
      : { fr: 'Voir programmes', en: 'See programs' };

    const created = await prisma.$transaction(
      async (tx) => {
        const existing = await tx.institution.findUnique({
          where: { id: instId },
          select: { id: true },
        });
        if (existing) return null;

        // --- programs (one per campus-agnostic formation) ---
        const programs = await tx.program.createMany({
          data: formationList
            .filter((formation) => formation.instId === instId)
            .map((formation) => {
              const offerings: CampusOffering[] = [
                ...formation.offerings.entries(),
              ]
                .sort(([a], [b]) => a.localeCompare(b, 'fr'))
                .map(([campus, acc]) => ({
                  campus,
                  tuitionUpfront: acc.tuitionUpfront,
                  tuitionInstallments: acc.tuitionInstallments,
                  intake: [...acc.intakes].join(' · ') || null,
                }));
              const tuition = formatTuitionSummary(offerings);
              const requirements = [...formation.requirements];
              const language = [...formation.languages].join(' / ');

              return {
                id: formation.progId,
                institutionId: formation.instId,
                countryId: FRANCE_COUNTRY_ID,
                fieldId: formation.fieldId,
                nameFr: formation.name,
                nameEn: formation.name,
                levelFr: formation.level.fr,
                levelEn: formation.level.en,
                durationFr: formation.duration.fr,
                durationEn: formation.duration.en,
                tuitionFr: tuition.fr,
                tuitionEn: tuition.en,
                languageFr: language,
                languageEn: language,
                requirementsFr: requirements,
                requirementsEn: requirements,
                campusOfferings: offerings as unknown as Prisma.InputJsonValue,
              };
            }),
          skipDuplicates: true,
        });

        const attached = await tx.program.findMany({
          where: { institutionId: instId },
          select: { id: true },
        });

        await tx.institution.create({
          data: {
            id: instId,
            nameFr: inst.school,
            nameEn: inst.school,
            countryId: FRANCE_COUNTRY_ID,
            locationFr: cities.join(' · '),
            locationEn: cities.join(' · '),
            overviewFr: `Réseau ${inst.school} (OMNES Education) — présent sur ${cities.length} campus en France : ${cities.join(', ')}. Partenaire KPB.`,
            overviewEn: `${inst.school} network (OMNES Education) — ${cities.length} campuses in France: ${cities.join(', ')}. KPB partner.`,
            studyLevels: [...inst.levels],
            tuitionLabelFr: tuitionLabel.fr,
            tuitionLabelEn: tuitionLabel.en,
            languageRequirementsFr: 'Français ou Anglais selon programme',
            languageRequirementsEn: 'French or English depending on program',
            intakePeriods: [...inst.intakes],
            programIds: linkedProgramIds(
              [...inst.programIds],
              attached.map((program) => program.id),
            ),
            isPartner: true,
          },
        });

        return programs.count;
      },
      // Up to ~150 formations per school in one statement: leave a slow remote
      // database more room than the 5 s interactive-transaction default.
      { timeout: 60_000 },
    );

    if (created === null) {
      keptInstitutions.push(instId);
    } else {
      createdInstitutions += 1;
      createdPrograms += created;
    }
  }

  const programCount = await prisma.program.count({
    where: { id: { startsWith: PROGRAM_ID_PREFIX } },
  });
  const institutionCount = await prisma.institution.count({
    where: { id: { startsWith: INSTITUTION_ID_PREFIX } },
  });

  // eslint-disable-next-line no-console
  console.log(
    `OMNES seed complete: ${createdInstitutions} school(s) and ${createdPrograms} formation(s) created; ` +
      `${programCount} formations across ${institutionCount} schools in base (France / ${FRANCE_COUNTRY_ID}), from ${rows.length} source rows.`,
  );
  if (keptInstitutions.length > 0) {
    // eslint-disable-next-line no-console
    console.log(
      `Already present, left untouched with their formations: ${keptInstitutions.join(', ')}.`,
    );
  }
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
