/**
 * Groupe IGENSIA Education — CLI autour de src/modules/catalog/igensia-import.ts.
 *
 * Crée les écoles IGENSIA School of Business, IGENSIA Tech, IGENSIA RH et
 * American Business College (France, partenaires) avec leurs formations. Une
 * formation = un Program ; ses campus et rentrées (mars / septembre 2027,
 * automne 2027 pour ABC) sont ses `campusOfferings`.
 *
 * ADDITIF et rejouable, comme `import:omnes-spring` : une école déjà en base
 * n'est jamais réécrite (seules ses dates de rentrée et ses formations
 * manquantes sont AJOUTÉES), une formation déjà en base ne reçoit que ses offres
 * manquantes. Relancé après application : 0 écriture.
 *
 * Sources : scripts/data/igensia_2027.csv et scripts/data/abc_2027.csv,
 * extraits par scripts/extract-catalog-sources.py.
 *
 *   npm run import:igensia                 # simulation, n'écrit rien
 *   npm run import:igensia -- --apply      # écrit
 *
 * Garde de production (src/common/seed-safety.ts), à l'application seulement :
 * autorisée tant qu'aucune ligne `igensia-*` n'est en base, refusée ensuite
 * sauf KPB_ALLOW_PRODUCTION_SEED=1.
 */
import { existsSync, readFileSync } from 'node:fs';
import * as path from 'node:path';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';

import { checkProductionSeed, linkedProgramIds } from '../src/common/seed-safety';
import {
  IGENSIA_INSTITUTION_ID_PREFIX,
  IGENSIA_PROGRAM_ID_PREFIX,
  IGENSIA_SCHOOLS,
  INSTITUTION_FILLABLE,
  PROGRAM_FILLABLE,
  type IgensiaExistingInstitution,
  type IgensiaExistingProgram,
  igensiaPlanWriteCount,
  parseIgensiaSources,
  planIgensia,
} from '../src/modules/catalog/igensia-import';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
const DATA = path.join(__dirname, 'data');
const SEED_NAME = 'import:igensia';

type ProgramData = ReturnType<typeof planIgensia>['schoolAdditions'][number]['programs'][number];

function toCreate(p: ProgramData): Prisma.ProgramCreateManyInput {
  return {
    ...p,
    campusOfferings: p.campusOfferings as unknown as Prisma.InputJsonValue,
  };
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const igensiaCsv = path.join(DATA, 'igensia_2027.csv');
  const abcCsv = path.join(DATA, 'abc_2027.csv');
  for (const file of [igensiaCsv, abcCsv]) {
    if (!existsSync(file)) {
      console.error(`Source introuvable : ${file}`);
      process.exit(1);
    }
  }

  const { formations, rowsBySchool, errors } = parseIgensiaSources(
    readFileSync(igensiaCsv, 'utf8'),
    readFileSync(abcCsv, 'utf8'),
  );
  console.log(`Sources : ${igensiaCsv}, ${abcCsv}`);
  for (const [school, n] of Object.entries(rowsBySchool)) {
    console.log(`   ${school} : ${n} ligne(s)`);
  }
  if (errors.length) {
    console.error('\nERREURS — rien ne sera écrit :');
    for (const e of errors) console.error(`  ✗ ${e}`);
    process.exit(1);
  }

  const programs = new Map<string, IgensiaExistingProgram>(
    (
      await prisma.program.findMany({
        where: { id: { in: formations.map((f) => f.id) } },
        select: {
          id: true,
          campusOfferings: true,
          updatedAt: true,
          // Les colonnes que l'import sait combler (vides ou encore telles que
          // la première version les avait écrites).
          ...Object.fromEntries(PROGRAM_FILLABLE.map((k) => [k, true])),
        },
      })
    ).map((p) => [p.id, p as IgensiaExistingProgram]),
  );
  const institutions = new Map<string, IgensiaExistingInstitution>(
    (
      await prisma.institution.findMany({
        where: { id: { in: IGENSIA_SCHOOLS.map((s) => s.id) } },
        select: {
          id: true,
          intakePeriods: true,
          programIds: true,
          updatedAt: true,
          ...Object.fromEntries(INSTITUTION_FILLABLE.map((k) => [k, true])),
        },
      })
    ).map((i) => [i.id, i as IgensiaExistingInstitution]),
  );
  // Toutes les fiches des écoles visées : une formation à créer qui a une
  // homonyme sous un autre id (fiche saisie à la main) n'est pas créée.
  const siblings = await prisma.program.findMany({
    where: { institutionId: { in: IGENSIA_SCHOOLS.map((s) => s.id) } },
    select: { id: true, institutionId: true, nameFr: true, levelFr: true },
  });
  const plan = planIgensia(formations, programs, institutions, siblings);

  console.log(`\n${formations.length} formation(s) dans les sources.\n`);
  for (const school of IGENSIA_SCHOOLS) {
    const own = formations.filter((f) => f.schoolId === school.id);
    const fresh = plan.newSchools.find((n) => n.institution.id === school.id);
    const extra = plan.schoolAdditions.find((a) => a.id === school.id);
    const created = [...(fresh?.programs ?? []), ...(extra?.programs ?? [])];
    const completed = plan.offeringAdditions.filter((a) => own.some((f) => f.id === a.id));
    const filled = [
      ...plan.programFills.filter((a) => own.some((f) => f.id === a.id)).map((a) => ({ id: a.id, data: a.data })),
      ...completed.filter((a) => a.fills).map((a) => ({ id: a.id, data: a.fills! })),
    ];
    const offers =
      created.reduce((n, p) => n + p.campusOfferings.length, 0) +
      completed.reduce((n, a) => n + a.added.length, 0);
    console.log(`── ${school.id}  [${fresh ? 'À CRÉER' : 'école existante'}]  ${school.nameFr}`);
    console.log(`   formations à créer     : ${created.length}`);
    console.log(`   formations complétées  : ${completed.length}`);
    console.log(
      `   formations inchangées  : ${plan.unchanged.filter((id) => own.some((f) => f.id === id)).length}`,
    );
    console.log(`   offres ajoutées        : ${offers}`);
    console.log(`   fiches comblées        : ${filled.length}`);
    for (const f of filled) console.log(`     ~ ${f.id} : ${Object.keys(f.data).join(', ')}`);
    const instFill = plan.institutionFills.find((f) => f.id === school.id);
    if (instFill) console.log(`   école comblée          : ${Object.keys(instFill.data).join(', ')}`);
    for (const p of created) {
      console.log(
        `     + ${p.levelFr.padEnd(9)} ${p.nameFr.slice(0, 64)} — ${p.campusOfferings
          .map((o) => `${o.campus} ${o.intake}`)
          .join(', ')}`,
      );
    }
    if (extra && (extra.addIntakePeriods.length || extra.addProgramIds.length)) {
      console.log(
        `   école : +${extra.addIntakePeriods.length} rentrée(s), +${extra.addProgramIds.length} formation(s) dans programIds`,
      );
    }
  }
  for (const s of plan.skipped) console.log(`  ⚠ ${s.id} (${s.name}) : ${s.reason}`);

  const writes = igensiaPlanWriteCount(plan);
  console.log(`\nTOTAL : ${writes} écriture(s) prévue(s).`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }
  if (writes === 0) {
    console.log('\n── Rien à écrire : les sources sont déjà appliquées. ──');
    return;
  }

  const guard = await checkProductionSeed({
    seed: SEED_NAME,
    countExistingRows: async () =>
      (await prisma.institution.count({
        where: { id: { startsWith: IGENSIA_INSTITUTION_ID_PREFIX } },
      })) +
      (await prisma.program.count({
        where: { id: { startsWith: IGENSIA_PROGRAM_ID_PREFIX } },
      })),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  let written = 0;
  for (const { institution, programs: rows } of plan.newSchools) {
    const done = await prisma.$transaction(
      async (tx) => {
        // Revérifiée DANS la transaction : une école créée entre la lecture et
        // l'écriture (autre import, admin) est laissée telle quelle.
        if (await tx.institution.findUnique({ where: { id: institution.id }, select: { id: true } })) {
          return false;
        }
        await tx.program.createMany({ data: rows.map(toCreate), skipDuplicates: true });
        const attached = await tx.program.findMany({
          where: { institutionId: institution.id },
          select: { id: true },
        });
        await tx.institution.create({
          data: {
            ...institution,
            programIds: linkedProgramIds(institution.programIds, attached.map((p) => p.id)),
          },
        });
        return true;
      },
      { timeout: 60_000 },
    );
    console.log(done ? `   créée : ${institution.id}` : `   ${institution.id} : créée entre-temps, laissée intacte`);
    if (done) written += 1;
  }

  // Comblements d'école AVANT les ajouts (`push` rafraîchit updatedAt).
  for (const f of plan.institutionFills) {
    const { count } = await prisma.institution.updateMany({
      where: { id: f.id, updatedAt: f.expectedUpdatedAt },
      data: f.data as Prisma.InstitutionUpdateManyMutationInput,
    });
    if (count) written += 1;
    else console.log(`   ${f.id} : modifiée entre-temps, laissée intacte — relancer`);
  }

  for (const add of plan.schoolAdditions) {
    await prisma.$transaction(
      async (tx) => {
        if (add.programs.length) {
          await tx.program.createMany({ data: add.programs.map(toCreate), skipDuplicates: true });
        }
        if (add.addIntakePeriods.length || add.addProgramIds.length) {
          // `push` ajoute sans relire ni réécrire ce qui est déjà dans le tableau.
          await tx.institution.update({
            where: { id: add.id },
            data: {
              ...(add.addIntakePeriods.length ? { intakePeriods: { push: add.addIntakePeriods } } : {}),
              ...(add.addProgramIds.length ? { programIds: { push: add.addProgramIds } } : {}),
            },
          });
        }
      },
      { timeout: 60_000 },
    );
    written += 1;
  }

  for (const a of plan.offeringAdditions) {
    const { count } = await prisma.program.updateMany({
      where: { id: a.id, updatedAt: a.expectedUpdatedAt },
      data: {
        ...((a.fills ?? {}) as Prisma.ProgramUpdateManyMutationInput),
        campusOfferings: a.merged as Prisma.InputJsonValue,
      },
    });
    if (count) written += 1;
    else console.log(`   ${a.id} : modifiée entre-temps, laissée intacte — relancer`);
  }

  for (const f of plan.programFills) {
    const { count } = await prisma.program.updateMany({
      where: { id: f.id, updatedAt: f.expectedUpdatedAt },
      data: f.data as Prisma.ProgramUpdateManyMutationInput,
    });
    if (count) written += 1;
    else console.log(`   ${f.id} : modifiée entre-temps, laissée intacte — relancer`);
  }

  console.log(`\n── ÉCRIT : ${written} écriture(s). ──`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
