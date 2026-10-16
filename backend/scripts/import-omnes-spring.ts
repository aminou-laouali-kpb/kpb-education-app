/**
 * Rentrée décalée OMNES (grille « SPRING 27 ») — CLI autour de
 * src/modules/catalog/omnes-spring-import.ts.
 *
 * ADDITIF et rejouable : une formation déjà connue reçoit ses offres de
 * printemps manquantes (campus + date, rythme, prix propre à l'offre) à la fin
 * de `campusOfferings` ; une formation inconnue est créée aux conventions du
 * seed d'automne ; l'école reçoit ses nouvelles dates et formations. Rien
 * d'existant n'est réécrit ni supprimé. Relancé après application : 0 écriture.
 *
 * Source : scripts/data/omnes_spring_27.csv, extrait du PDF du même nom par
 * scripts/extract-catalog-sources.py (lignes vérifiées une à une contre le PDF).
 *
 *   npm run import:omnes-spring                 # simulation, n'écrit rien
 *   npm run import:omnes-spring -- --apply      # écrit
 *
 * Garde de production (src/common/seed-safety.ts), à l'application seulement :
 * autorisée tant qu'aucune offre de printemps n'est en base (première
 * application), refusée ensuite sauf KPB_ALLOW_PRODUCTION_SEED=1. La simulation
 * ne lit que la base et tourne partout.
 */
import { existsSync, readFileSync } from 'node:fs';
import * as path from 'node:path';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';

import { checkProductionSeed } from '../src/common/seed-safety';
import {
  OMNES_INSTITUTION_ID_PREFIX,
  OMNES_PROGRAM_ID_PREFIX,
} from '../src/modules/catalog/omnes-conventions';
import {
  type ExistingInstitutionState,
  type ExistingProgramState,
  groupSpringFormations,
  parseOmnesSpringCsv,
  planOmnesSpring,
  planWriteCount,
} from '../src/modules/catalog/omnes-spring-import';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
const DEFAULT_CSV = path.join(__dirname, 'data', 'omnes_spring_27.csv');
const SEED_NAME = 'import:omnes-spring';

function countBy<T>(items: readonly T[], key: (item: T) => string) {
  const out = new Map<string, number>();
  for (const item of items) out.set(key(item), (out.get(key(item)) ?? 0) + 1);
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const csvPath = args.find((a) => !a.startsWith('--')) ?? DEFAULT_CSV;
  if (!existsSync(csvPath)) {
    console.error(`CSV introuvable : ${csvPath}`);
    process.exit(1);
  }

  const { rows, errors } = parseOmnesSpringCsv(readFileSync(csvPath, 'utf8'));
  console.log(`Source : ${csvPath} (${rows.length} lignes lues)`);
  for (const [school, n] of countBy(rows, (r) => r.school)) {
    console.log(`   ${school} : ${n} ligne(s)`);
  }
  if (errors.length) {
    console.error('\nERREURS — rien ne sera écrit :');
    for (const e of errors) console.error(`  ✗ ${e}`);
    process.exit(1);
  }

  const formations = groupSpringFormations(rows);
  const programs = new Map<string, ExistingProgramState>(
    (
      await prisma.program.findMany({
        where: { id: { in: formations.map((f) => f.id) } },
        select: { id: true, institutionId: true, campusOfferings: true, updatedAt: true },
      })
    ).map((p) => [p.id, p]),
  );
  const institutions = new Map<string, ExistingInstitutionState>(
    (
      await prisma.institution.findMany({
        where: { id: { startsWith: OMNES_INSTITUTION_ID_PREFIX } },
        select: { id: true, intakePeriods: true, programIds: true },
      })
    ).map((i) => [i.id, i]),
  );

  // Toutes les fiches des écoles visées : une formation à créer qui a déjà une
  // homonyme sous un autre id (fiche créée à la main) n'est pas créée.
  const siblings = await prisma.program.findMany({
    where: { institutionId: { in: [...new Set(formations.map((f) => f.institutionId))] } },
    select: { id: true, institutionId: true, nameFr: true, levelFr: true },
  });
  const plan = planOmnesSpring(formations, programs, institutions, siblings);
  if (plan.errors.length) {
    console.error('\nERREURS — rien ne sera écrit :');
    for (const e of plan.errors) console.error(`  ✗ ${e}`);
    process.exit(1);
  }

  console.log(`\n${formations.length} formation(s) dans la grille.\n`);
  const schools = [...new Set(formations.map((f) => f.institutionId))].sort();
  for (const school of schools) {
    const created = plan.creations.filter((c) => c.institutionId === school);
    const additions = plan.additions.filter((a) =>
      formations.find((f) => f.id === a.id)?.institutionId === school,
    );
    const unchanged = plan.unchanged.filter((id) =>
      formations.find((f) => f.id === id)?.institutionId === school,
    );
    const offers =
      created.reduce((n, c) => n + c.campusOfferings.length, 0) +
      additions.reduce((n, a) => n + a.added.length, 0);
    console.log(`── ${school}`);
    console.log(`   formations à créer          : ${created.length}`);
    console.log(`   formations complétées       : ${additions.length}`);
    console.log(`   formations inchangées       : ${unchanged.length}`);
    console.log(`   offres de printemps ajoutées : ${offers}`);
    for (const c of created.slice(0, 3)) console.log(`     + ${c.nameFr.slice(0, 70)}`);
    if (created.length > 3) console.log(`     + … ${created.length - 3} de plus`);
    const inst = plan.institutions.find((i) => i.id === school);
    if (inst) {
      console.log(
        `   école : +${inst.addIntakePeriods.length} date(s) de rentrée, +${inst.addProgramIds.length} formation(s) dans programIds`,
      );
    }
  }
  for (const s of plan.skipped) {
    console.log(`  ⚠ ${s.id} (${s.name}) : ${s.reason}`);
  }

  const writes = planWriteCount(plan);
  console.log(`\nTOTAL : ${writes} écriture(s) prévue(s).`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }
  if (writes === 0) {
    console.log('\n── Rien à écrire : la grille est déjà appliquée. ──');
    return;
  }

  const guard = await checkProductionSeed({
    seed: SEED_NAME,
    // « Les lignes de cet import » : les formations OMNES qui portent déjà une
    // offre de printemps. Zéro avant la première application.
    countExistingRows: () =>
      prisma.program.count({
        where: {
          id: { startsWith: OMNES_PROGRAM_ID_PREFIX },
          campusOfferings: { array_contains: [{ session: 'spring' }] },
        },
      }),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  let written = 0;
  let raced = 0;
  for (const a of plan.additions) {
    // `updatedAt` est rafraîchi à chaque écriture (`@updatedAt`) : si la fiche
    // a été retouchée depuis la lecture, le `WHERE` ne trouve rien et la fiche
    // reste telle que l'admin l'a laissée. Relancer reprendra l'ajout sur la
    // version à jour.
    const { count } = await prisma.program.updateMany({
      where: { id: a.id, updatedAt: a.expectedUpdatedAt },
      data: { campusOfferings: a.merged as Prisma.InputJsonValue },
    });
    if (count) written += 1;
    else {
      raced += 1;
      console.log(`   ${a.id} : modifiée entre-temps, laissée intacte — relancer`);
    }
  }

  for (const school of schools) {
    const creations = plan.creations.filter((c) => c.institutionId === school);
    const inst = plan.institutions.find((i) => i.id === school);
    if (!creations.length && !inst) continue;
    await prisma.$transaction(
      async (tx) => {
        if (creations.length) {
          await tx.program.createMany({
            data: creations.map((c) => ({
              ...c,
              campusOfferings: c.campusOfferings as unknown as Prisma.InputJsonValue,
            })),
            skipDuplicates: true,
          });
        }
        if (inst) {
          // `push` ajoute au tableau en base, sans relire ni réécrire ce qui y
          // est déjà : une date ou une formation ajoutée à la main est gardée.
          await tx.institution.update({
            where: { id: school },
            data: {
              ...(inst.addIntakePeriods.length
                ? { intakePeriods: { push: inst.addIntakePeriods } }
                : {}),
              ...(inst.addProgramIds.length
                ? { programIds: { push: inst.addProgramIds } }
                : {}),
            },
          });
        }
      },
      { timeout: 60_000 },
    );
    written += creations.length + (inst ? 1 : 0);
  }

  console.log(
    `\n── ÉCRIT : ${written} écriture(s)${raced ? `, ${raced} fiche(s) laissée(s) intacte(s)` : ''}. ──`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
