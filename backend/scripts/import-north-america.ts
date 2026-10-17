/**
 * Catalogue Amérique du Nord — CLI autour de
 * src/modules/catalog/north-america-import.ts.
 *
 * Crée des universités NON partenaires (`isPartner: false`) du Canada et des
 * États-Unis et leurs formations phares, depuis
 * scripts/data/amerique-du-nord-2027.json (provenance fait par fait :
 * scripts/data/amerique-du-nord-2027.sources.md ; sélection et critères :
 * docs/catalogue-amerique-du-nord.md).
 *
 * CRÉATION SEULE et rejouable : un établissement déjà en base n'est jamais
 * réécrit (seuls les ids de ses formations manquantes sont AJOUTÉS à
 * `programIds`), une formation déjà en base n'est pas touchée, un homonyme
 * déjà en base sous un autre id (l'Université d'Ottawa, `uottawa`) bloque la
 * création. Relancé après application : 0 écriture.
 *
 *   npm run import:north-america                 # simulation, n'écrit rien
 *   npm run import:north-america -- --apply      # écrit
 *
 * Garde de production (src/common/seed-safety.ts), à l'application seulement :
 * autorisée tant qu'aucune ligne `na-*` n'est en base, refusée ensuite sauf
 * KPB_ALLOW_PRODUCTION_SEED=1 — nécessaire pour la seconde passe Canada
 * (17/10/2026) si la première est déjà appliquée : seuls les établissements et
 * formations absents sont créés.
 */
import { existsSync, readFileSync } from 'node:fs';
import * as path from 'node:path';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';

import { checkProductionSeed, linkedProgramIds } from '../src/common/seed-safety';
import {
  NA_ID_PREFIX,
  NA_SEED_NAME,
  type NaSource,
  naPlanWriteCount,
  planNorthAmerica,
  validateNaSource,
} from '../src/modules/catalog/north-america-import';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
const SOURCE = path.join(__dirname, 'data', 'amerique-du-nord-2027.json');

type ProgramData = ReturnType<typeof planNorthAmerica>['newInstitutions'][number]['programs'][number];

function toCreate(p: ProgramData): Prisma.ProgramCreateManyInput {
  return {
    ...p,
    campusOfferings: p.campusOfferings
      ? (p.campusOfferings as unknown as Prisma.InputJsonValue)
      : Prisma.DbNull,
  };
}

async function main() {
  const apply = process.argv.slice(2).includes('--apply');
  if (!existsSync(SOURCE)) {
    console.error(`Source introuvable : ${SOURCE}`);
    process.exit(1);
  }
  const doc = JSON.parse(readFileSync(SOURCE, 'utf8')) as NaSource;
  const errors = validateNaSource(doc);
  const dates = [...new Set(doc.institutions.map((i) => i.consultedAt ?? doc.consultedAt))].sort();
  console.log(`Source : ${SOURCE} (consultée le ${dates.join(' et le ')}, taux BCE du ${doc.exchangeRates.date})`);
  if (errors.length) {
    console.error('\nERREURS — rien ne sera écrit :');
    for (const e of errors) console.error(`  ✗ ${e}`);
    process.exit(1);
  }

  const institutions = await prisma.institution.findMany({
    select: { id: true, nameFr: true, nameEn: true, programIds: true },
  });
  const ids = doc.institutions.map((i) => i.id);
  const programs = await prisma.program.findMany({
    where: { institutionId: { in: ids } },
    select: { id: true, institutionId: true, nameFr: true, levelFr: true },
  });
  const plan = planNorthAmerica(doc, institutions, programs);

  for (const country of ['can', 'usa']) {
    const own = doc.institutions.filter((i) => i.countryId === country);
    console.log(`\n══ ${country === 'can' ? 'Canada' : 'États-Unis'} : ${own.length} établissement(s) dans la source`);
    for (const inst of own) {
      const fresh = plan.newInstitutions.find((n) => n.institution.id === inst.id);
      const extra = plan.programAdditions.find((a) => a.institutionId === inst.id);
      const skip = plan.skipped.find((s) => s.id === inst.id);
      const state = fresh ? 'À CRÉER' : skip ? 'IGNORÉ' : extra ? 'à compléter' : 'inchangé';
      const created = fresh?.programs ?? extra?.programs ?? [];
      console.log(`── ${inst.id}  [${state}]  ${inst.nameFr} — non partenaire (relevé du ${inst.consultedAt ?? doc.consultedAt})`);
      console.log(`   formations à créer : ${created.length} / ${inst.programs.length}`);
      for (const p of created) {
        console.log(
          `     + ${p.levelFr.padEnd(20)} ${p.nameFr.slice(0, 70)}${p.tuitionMinEur ? ` — ${p.tuitionMinEur} €/an (plancher)` : ''}`,
        );
      }
      if (extra?.addProgramIds.length) console.log(`   + ${extra.addProgramIds.length} id(s) ajouté(s) à programIds`);
    }
  }
  for (const s of plan.skipped) console.log(`  ⚠ ${s.id} (${s.name}) : ${s.reason}`);

  const writes = naPlanWriteCount(plan);
  console.log(`\nTOTAL : ${writes} écriture(s) prévue(s).`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }
  if (writes === 0) {
    console.log('\n── Rien à écrire : la source est déjà appliquée. ──');
    return;
  }

  const guard = await checkProductionSeed({
    seed: NA_SEED_NAME,
    countExistingRows: async () =>
      (await prisma.institution.count({ where: { id: { startsWith: NA_ID_PREFIX } } })) +
      (await prisma.program.count({ where: { id: { startsWith: NA_ID_PREFIX } } })),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  let written = 0;
  for (const { institution, programs: rows } of plan.newInstitutions) {
    const done = await prisma.$transaction(
      async (tx) => {
        // Revérifiée DANS la transaction : un établissement créé entre la
        // lecture et l'écriture (autre import, admin) est laissé tel quel.
        if (await tx.institution.findUnique({ where: { id: institution.id }, select: { id: true } })) {
          return false;
        }
        if (rows.length) await tx.program.createMany({ data: rows.map(toCreate), skipDuplicates: true });
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
    console.log(done ? `   créé : ${institution.id}` : `   ${institution.id} : créé entre-temps, laissé intact`);
    if (done) written += 1;
  }

  for (const add of plan.programAdditions) {
    await prisma.$transaction(
      async (tx) => {
        if (add.programs.length) {
          await tx.program.createMany({ data: add.programs.map(toCreate), skipDuplicates: true });
        }
        if (add.addProgramIds.length) {
          // `push` ajoute sans relire ni réécrire ce qui est déjà dans la liste.
          await tx.institution.update({
            where: { id: add.institutionId },
            data: { programIds: { push: add.addProgramIds } },
          });
        }
      },
      { timeout: 60_000 },
    );
    written += 1;
  }

  console.log(`\n── ÉCRIT : ${written} écriture(s). ──`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
