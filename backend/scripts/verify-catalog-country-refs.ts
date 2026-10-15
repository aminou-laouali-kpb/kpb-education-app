import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  evaluateCatalogConsistency,
  parseVerifyCatalogArgs,
  publicCatalogProgramWhere,
  publicPartnerInstitutionWhere,
  renderCatalogConsistencyReport,
} from '../src/modules/catalog/catalog-consistency-checks';
import { publicScholarshipWhere } from '../src/common/public-scholarship-where';
import { SCHOLARSHIP_CATALOG_V1 } from '../src/modules/scholarships-index/data/scholarship-catalog.v1';
import { eligibilityCoverage } from '../src/modules/scholarships-index/data/scholarship-catalog.validator';
import {
  renderEligibilityCoverage,
  summariseServedEligibility,
} from '../src/modules/scholarships-index/data/scholarship-eligibility-coverage';

// Compose supplies DATABASE_URL to the production verification container. Keep
// local CLI convenience without requiring a .env file in the runtime image.
if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

/**
 * Data-integrity check: every country reference that designates a KPB
 * *destination* must point to an *active* Country (these are plain indexed
 * columns, not FKs, so nothing enforces this at the DB level):
 *   - Institution.countryId
 *   - Program.countryId
 *   - SupportDestination.countryId
 *   - ServiceOffer.destinationIds[]
 *
 * Scholarships are intentionally excluded: a scholarship may legitimately point
 * to a country KPB does not actively place students in (e.g. Japan), so its
 * countryId is treated as a display label rather than a destination reference.
 *
 * Exits non-zero when any orphan is found, so it can be used as a CI gate.
 */
async function verifyCountryRefs() {
  const activeCountries = await prisma.country.findMany({
    where: { isActive: true },
    select: { id: true },
  });
  const activeIds = new Set(activeCountries.map((c) => c.id));

  const [institutions, programs, supportDestinations, serviceOffers] = await Promise.all([
    prisma.institution.groupBy({ by: ['countryId'], _count: { _all: true } }),
    prisma.program.groupBy({ by: ['countryId'], _count: { _all: true } }),
    prisma.supportDestination.groupBy({ by: ['countryId'], _count: { _all: true } }),
    prisma.serviceOffer.findMany({ select: { id: true, destinationIds: true } }),
  ]);

  const orphans: { table: string; countryId: string; count: number }[] = [];
  for (const row of institutions) {
    if (!activeIds.has(row.countryId)) {
      orphans.push({ table: 'Institution', countryId: row.countryId, count: row._count._all });
    }
  }
  for (const row of programs) {
    if (!activeIds.has(row.countryId)) {
      orphans.push({ table: 'Program', countryId: row.countryId, count: row._count._all });
    }
  }
  for (const row of supportDestinations) {
    if (!activeIds.has(row.countryId)) {
      orphans.push({ table: 'SupportDestination', countryId: row.countryId, count: row._count._all });
    }
  }
  const offerDestCounts = new Map<string, number>();
  for (const offer of serviceOffers) {
    for (const id of offer.destinationIds) {
      if (!activeIds.has(id)) offerDestCounts.set(id, (offerDestCounts.get(id) ?? 0) + 1);
    }
  }
  for (const [countryId, count] of offerDestCounts) {
    orphans.push({ table: 'ServiceOffer.destinationIds', countryId, count });
  }

  // eslint-disable-next-line no-console
  console.log(`Active countries (${activeIds.size}): ${[...activeIds].sort().join(', ')}`);

  if (orphans.length === 0) {
    // eslint-disable-next-line no-console
    console.log('OK — every Institution/Program countryId references an active Country.');
    return;
  }

  // eslint-disable-next-line no-console
  console.error('FAIL — found rows referencing inactive/unknown countries:');
  for (const o of orphans) {
    // eslint-disable-next-line no-console
    console.error(`  ${o.table}: countryId="${o.countryId}" (${o.count} row(s))`);
  }
  process.exitCode = 1;
}

/**
 * Catalogue consistency checks (logic and rationale in
 * src/modules/catalog/catalog-consistency-checks.ts): orphan Program.fieldId,
 * active partner institutions with no active program, and a public catalogue
 * larger than the 1000-program snapshot installed app builds load.
 *
 * They only WARN by default — deploy.yml and vps-ops.sh run without flags, and
 * a degraded catalogue must not block a release. `--strict` (Backend CI only)
 * turns them into a failure. Only aggregates are read: vps-ops.sh runs this
 * inside the live API container, under its memory cap.
 */
async function verifyCatalogConsistency(strict: boolean) {
  const [fields, programsByField, partnerInstitutions, programsByInstitution, publicProgramCount] =
    await Promise.all([
      prisma.field.findMany({ select: { id: true } }),
      prisma.program.groupBy({ by: ['fieldId', 'isActive'], _count: { _all: true } }),
      prisma.institution.findMany({
        where: publicPartnerInstitutionWhere(),
        select: { id: true, nameFr: true },
      }),
      prisma.program.groupBy({
        by: ['institutionId'],
        where: publicCatalogProgramWhere(),
        _count: { _all: true },
      }),
      prisma.program.count({ where: publicCatalogProgramWhere() }),
    ]);

  const findings = evaluateCatalogConsistency({
    fieldIds: fields.map((f) => f.id),
    programsByField: programsByField.map((row) => ({
      fieldId: row.fieldId,
      isActive: row.isActive,
      count: row._count._all,
    })),
    partnerInstitutions,
    publicProgramsByInstitution: programsByInstitution.map((row) => ({
      institutionId: row.institutionId,
      count: row._count._all,
    })),
    publicProgramCount,
  });
  const report = renderCatalogConsistencyReport(findings, { strict, publicProgramCount });
  for (const line of report.lines) {
    // eslint-disable-next-line no-console
    (report.ok ? console.log : console.error)(line);
  }
  if (report.exitCode !== 0) process.exitCode = report.exitCode;
}

/**
 * Couverture de l'éligibilité structurée (chantier D, catalogue 1.5.0) : le
 * catalogue du dépôt (fiches structurées / brouillons / tamponnées) et les
 * fiches servies au public. Un RAPPORT, jamais une porte, même avec
 * `--strict` : des brouillons honnêtement non tamponnés n'excluent aucun élève
 * et ne doivent bloquer ni la CI ni un déploiement. La porte éditoriale est
 * `STRUCTURED_ELIGIBILITY_GATE` (validateur du catalogue).
 */
async function reportEligibilityCoverage() {
  const now = new Date();
  const rows = await prisma.scholarship.findMany({
    where: publicScholarshipWhere(now),
    select: {
      id: true,
      eligibleLevels: true,
      eligibilityCriteria: true,
      eligibilityStructuredAt: true,
    },
  });
  const report = renderEligibilityCoverage(
    eligibilityCoverage(SCHOLARSHIP_CATALOG_V1, now),
    summariseServedEligibility(rows, now),
    SCHOLARSHIP_CATALOG_V1.catalogVersion,
  );
  for (const line of report.lines) {
    // eslint-disable-next-line no-console
    (line.startsWith('::warning::') ? console.error : console.log)(line);
  }
}

async function main() {
  // Parsed first: a mistyped flag must fail before any database work.
  const { strict } = parseVerifyCatalogArgs(process.argv.slice(2));
  await verifyCountryRefs();
  try {
    await verifyCatalogConsistency(strict);
  } catch (error) {
    // A warn-only check must not block a deploy by crashing either: only the
    // country refs above decide that. CI (`--strict`) still fails on it.
    if (strict) throw error;
    // eslint-disable-next-line no-console
    console.error(
      '::warning::Catalog consistency checks could not run (not blocking without --strict):',
    );
    // eslint-disable-next-line no-console
    console.error(error);
  }
  try {
    await reportEligibilityCoverage();
  } catch (error) {
    // Un rapport : son échec avertit, ne bloque rien (même avec --strict).
    // eslint-disable-next-line no-console
    console.error('::warning::Eligibility coverage report could not run:', error);
  }
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
