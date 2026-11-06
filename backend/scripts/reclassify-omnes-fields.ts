/**
 * Reprise : reclasse par filière les formations OMNES déjà en base (audit build
 * 57, n° 8).
 *
 * « digital », « data » ou « ia » suffisaient à ranger une formation en
 * Informatique & IA : « Marketing Comm en Digital » et « Communication,
 * Marketing Digital » étaient proposées comme écoles « compatibles » à un élève
 * qui vise l'informatique. La règle est corrigée (`inferFieldId`), mais les
 * imports ne posent la filière qu'à la création d'une fiche : les lignes
 * existantes gardent l'ancienne.
 *
 * Chaque écriture est conditionnée par la filière LUE (`WHERE fieldId = ancienne`)
 * et par `updatedAt` : une fiche modifiée entre le relevé et l'écriture, par
 * exemple reclassée à la main dans l'admin, n'est jamais écrasée.
 *
 *   npm run reclassify:omnes-fields               # simulation, n'écrit rien
 *   npm run reclassify:omnes-fields -- --apply    # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  OMNES_PROGRAM_ID_PREFIX,
  planFieldReclassification,
} from '../src/modules/catalog/omnes-conventions';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

async function main() {
  const apply = process.argv.slice(2).includes('--apply');
  const rows = await prisma.program.findMany({
    where: { id: { startsWith: OMNES_PROGRAM_ID_PREFIX } },
    select: { id: true, nameFr: true, levelFr: true, fieldId: true, updatedAt: true },
  });
  const updatedAt = new Map(rows.map((r) => [r.id, r.updatedAt]));
  const plan = planFieldReclassification(rows);

  console.log(`${rows.length} formation(s) OMNES en base, ${plan.length} à reclasser.\n`);
  for (const c of plan) console.log(`  ${c.from} → ${c.to}  ${c.id}  « ${c.nameFr} »`);

  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }
  let written = 0;
  let raced = 0;
  for (const c of plan) {
    const { count } = await prisma.program.updateMany({
      where: { id: c.id, fieldId: c.from, updatedAt: updatedAt.get(c.id) },
      data: { fieldId: c.to },
    });
    if (count) written += 1;
    else {
      raced += 1;
      console.log(`   ${c.id} : modifiée entre-temps, laissée intacte — relancer`);
    }
  }
  console.log(
    `\n── ÉCRIT : ${written} formation(s) reclassée(s)${raced ? `, ${raced} laissée(s) intacte(s)` : ''}. ──`,
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
