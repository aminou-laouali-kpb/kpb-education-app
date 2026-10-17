/**
 * Doublons OMNES déjà en base — CLI autour de planOmnesDedupe
 * (src/modules/catalog/catalog-dedupe.ts).
 *
 * La grille d'automne 2026 écrivait parfois la même formation de deux façons
 * (casse, accent, campus resté dans l'intitulé : « BCh- Rennes - B1 - Banque
 * Assurance »). Le seed en a tiré deux fiches. Les ids sont en production, on
 * ne les déplace pas : la table EXPLICITE `OMNES_PROGRAM_ID_ALIASES` dit, pour
 * chaque variante, la fiche qui fait foi. Ce script :
 *
 *  - ajoute à la fiche canonique les offres (campus + rentrée) de ses alias
 *    qu'elle n'a pas, à la FIN de `campusOfferings` — rien d'existant n'est
 *    réécrit ;
 *  - retire le campus resté collé dans l'intitulé de la fiche canonique ;
 *  - met chaque alias hors ligne (`isActive = false`) : il reste dans l'admin,
 *    rien n'est supprimé.
 *
 * Chaque écriture est conditionnée à `updatedAt` (fiche retouchée entre la
 * lecture et l'écriture = laissée intacte, relancer). Rejouable : 0 écriture.
 *
 *   npm run dedupe:omnes                 # simulation, n'écrit rien
 *   npm run dedupe:omnes -- --apply      # écrit
 *
 * Garde de production (src/common/seed-safety.ts) : la première application
 * passe (aucun alias encore hors ligne) ; une relance qui aurait encore
 * quelque chose à écrire demande KPB_ALLOW_PRODUCTION_SEED=1.
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';

import { checkProductionSeed } from '../src/common/seed-safety';
import {
  type DedupeProgramState,
  OMNES_PROGRAM_ID_ALIASES,
  omnesDedupeWriteCount,
  planOmnesDedupe,
} from '../src/modules/catalog/catalog-dedupe';
import { OMNES_PROGRAM_ID_PREFIX } from '../src/modules/catalog/omnes-conventions';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

async function main() {
  const apply = process.argv.slice(2).includes('--apply');
  const rows = await prisma.program.findMany({
    where: { id: { startsWith: OMNES_PROGRAM_ID_PREFIX } },
    select: {
      id: true,
      nameFr: true,
      nameEn: true,
      campusOfferings: true,
      isActive: true,
      updatedAt: true,
    },
  });
  const programs = new Map<string, DedupeProgramState>(rows.map((r) => [r.id, r]));
  const plan = planOmnesDedupe(programs);

  console.log(`${rows.length} formation(s) OMNES en base, ${Object.keys(OMNES_PROGRAM_ID_ALIASES).length} alias connus.\n`);
  for (const u of plan.canonicalUpdates) {
    const parts = [
      u.added ? `+${u.added} offre(s)` : null,
      u.rename ? `intitulé → « ${u.rename.nameFr} »` : null,
    ].filter(Boolean);
    console.log(`  = ${u.id} : ${parts.join(', ')}`);
  }
  for (const d of plan.deactivations) {
    console.log(`  − ${d.id} → ${d.canonical} (hors ligne) — ${d.reason}`);
  }
  for (const o of plan.orphans) {
    console.log(`  ⚠ ${o.id} : fiche canonique ${o.canonical} absente — laissé tel quel`);
  }

  const writes = omnesDedupeWriteCount(plan);
  console.log(
    `\nTOTAL : ${plan.canonicalUpdates.length} fiche(s) canonique(s) à compléter, ${plan.deactivations.length} alias à mettre hors ligne (${writes} écriture(s)).`,
  );
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }
  if (writes === 0) {
    console.log('\n── Rien à écrire : aucun doublon actif. ──');
    return;
  }

  const guard = await checkProductionSeed({
    seed: 'dedupe:omnes',
    // « Les lignes de cette opération » : les alias déjà mis hors ligne.
    countExistingRows: () =>
      prisma.program.count({
        where: { id: { in: Object.keys(OMNES_PROGRAM_ID_ALIASES) }, isActive: false },
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
  // Un alias n'est mis hors ligne que si ses offres sont bien arrivées sur la
  // fiche canonique.
  const failed = new Set<string>();
  for (const u of plan.canonicalUpdates) {
    const { count } = await prisma.program.updateMany({
      where: { id: u.id, updatedAt: u.expectedUpdatedAt },
      data: {
        ...(u.merged ? { campusOfferings: u.merged as Prisma.InputJsonValue } : {}),
        ...(u.rename ?? {}),
      },
    });
    if (count) written += 1;
    else {
      raced += 1;
      failed.add(u.id);
      console.log(`   ${u.id} : modifiée entre-temps, laissée intacte — relancer`);
    }
  }
  for (const d of plan.deactivations) {
    if (failed.has(d.canonical)) continue;
    const { count } = await prisma.program.updateMany({
      where: { id: d.id, updatedAt: d.expectedUpdatedAt, isActive: true },
      data: { isActive: false },
    });
    if (count) written += 1;
    else {
      raced += 1;
      console.log(`   ${d.id} : modifiée entre-temps, laissée intacte — relancer`);
    }
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
