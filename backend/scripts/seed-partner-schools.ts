/**
 * Seeds non-OMNES partner schools and programs (Annexe 05).
 *
 * Create-only: an institution that already exists is left exactly as it is,
 * together with its programs, and nothing is ever deleted. This script used to
 * `deleteMany` every `partner-*` row before recreating them, which also wiped
 * Mundiapolis/Universiapolis (imported under the same prefix) and every edit
 * made in the admin.
 *
 * A missing institution is created with its missing programs in one
 * transaction, and its `programIds` lists the programs actually attached to it.
 *
 * Refused on a production database that already holds `partner-*` rows,
 * unless KPB_ALLOW_PRODUCTION_SEED=1 (see src/common/seed-safety.ts).
 *
 * Usage:
 *   npm run seed:partners
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { checkProductionSeed, linkedProgramIds } from '../src/common/seed-safety';
import {
  PARTNER_INSTITUTION_SEEDS,
  countPartnerPrograms,
} from '../src/modules/catalog/data/partner-schools.seed';

// Compose supplies DATABASE_URL (and NODE_ENV) to the API container, whose
// image ships no .env: an unconditional load threw ENOENT there before the
// production guard could even run.
if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

const INSTITUTION_PREFIX = 'partner-';
const PROGRAM_PREFIX = 'partner-p-';

async function main() {
  // The whole `partner-*` namespace counts, not only this seed's ids: a
  // production database holding Mundiapolis alone is not a first install.
  const guard = await checkProductionSeed({
    seed: 'seed:partners',
    countExistingRows: async () =>
      (await prisma.institution.count({
        where: { id: { startsWith: INSTITUTION_PREFIX } },
      })) +
      (await prisma.program.count({
        where: { id: { startsWith: PROGRAM_PREFIX } },
      })),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  let createdInstitutions = 0;
  let createdPrograms = 0;
  const keptInstitutions: string[] = [];

  for (const school of PARTNER_INSTITUTION_SEEDS) {
    const created = await prisma.$transaction(async (tx) => {
      const existing = await tx.institution.findUnique({
        where: { id: school.id },
        select: { id: true },
      });
      if (existing) return null;

      const programs = await tx.program.createMany({
        data: school.programs.map((program) => ({
          id: program.id,
          institutionId: school.id,
          countryId: school.countryId,
          fieldId: program.fieldId,
          nameFr: program.nameFr,
          nameEn: program.nameEn,
          levelFr: program.levelFr,
          levelEn: program.levelEn,
          durationFr: program.durationFr,
          durationEn: program.durationEn,
          tuitionFr: program.tuitionFr,
          tuitionEn: program.tuitionEn,
          languageFr: program.languageFr,
          languageEn: program.languageEn,
          requirementsFr: program.requirementsFr,
          requirementsEn: program.requirementsEn,
        })),
        skipDuplicates: true,
      });

      const attached = await tx.program.findMany({
        where: { institutionId: school.id },
        select: { id: true },
      });

      await tx.institution.create({
        data: {
          id: school.id,
          nameFr: school.nameFr,
          nameEn: school.nameEn,
          countryId: school.countryId,
          locationFr: school.locationFr,
          locationEn: school.locationEn,
          overviewFr: school.overviewFr,
          overviewEn: school.overviewEn,
          studyLevels: school.studyLevels,
          tuitionLabelFr: 'Voir programme',
          tuitionLabelEn: 'See program',
          languageRequirementsFr: 'Selon programme',
          languageRequirementsEn: 'Depending on program',
          intakePeriods: ['Septembre'],
          programIds: linkedProgramIds(
            school.programs.map((program) => program.id),
            attached.map((program) => program.id),
          ),
          isPartner: true,
        },
      });

      return programs.count;
    });

    if (created === null) {
      keptInstitutions.push(school.id);
    } else {
      createdInstitutions += 1;
      createdPrograms += created;
    }
  }

  const programCount = await prisma.program.count({
    where: { id: { startsWith: PROGRAM_PREFIX } },
  });
  const institutionCount = await prisma.institution.count({
    where: { id: { startsWith: INSTITUTION_PREFIX } },
  });
  const omnesCount = await prisma.program.count({
    where: { id: { startsWith: 'omnes-p-' } },
  });
  const totalPrograms = await prisma.program.count();

  // eslint-disable-next-line no-console
  console.log(
    `Partner seed complete: ${createdInstitutions} institution(s) and ${createdPrograms} program(s) created ` +
      `(seed holds ${PARTNER_INSTITUTION_SEEDS.length} institutions, ${countPartnerPrograms()} programs).`,
  );
  if (keptInstitutions.length > 0) {
    // eslint-disable-next-line no-console
    console.log(
      `Already present, left untouched with their programs: ${keptInstitutions.join(', ')}.`,
    );
  }
  // eslint-disable-next-line no-console
  console.log(
    `Catalog totals: ${totalPrograms} programs (${omnesCount} OMNES + ${programCount} partners), ${institutionCount} partner institutions.`,
  );
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
