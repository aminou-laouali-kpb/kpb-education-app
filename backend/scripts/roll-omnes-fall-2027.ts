/**
 * Reconduction des rentrées d'automne OMNES 2026 → 2027 — CLI autour de
 * src/modules/catalog/omnes-fall-roll.ts.
 *
 * Décision du propriétaire (16/10/2026) : chaque offre d'automne 2026 (août,
 * septembre, octobre) passe au même jour et au même mois de 2027, garde son
 * campus et ses prix (tarifs 2026-2027 : OMNES n'a pas publié 2027-2028) et
 * porte `rolledFromIntake` (la date d'origine) et `intakeEstimated: true` —
 * l'app l'affiche « Date reconduite de 2026, à confirmer ». Les offres de
 * rentrée décalée (janvier – mars 2027) ne bougent pas. Les `intakePeriods`
 * des écoles OMNES suivent : chaque date d'automne 2026 que plus aucune offre
 * ne porte est remplacée, à sa place, par la date reconduite.
 *
 * Seules les offres NON RETOUCHÉES sont reconduites : campus, dates et prix
 * identiques à la grille d'automne (scripts/data/omnes_fall_26.xlsx) pour la
 * formation, et aucun champ ajouté. Une offre retouchée est signalée (« ⚠ »),
 * jamais modifiée. Chaque fiche n'est réécrite que si son `updatedAt` n'a pas
 * bougé depuis la lecture. Rejouable : la relance annonce « 0 écriture ».
 *
 *   npm run roll:omnes-fall-2027                 # simulation, n'écrit rien
 *   npm run roll:omnes-fall-2027 -- --apply      # écrit
 *
 * Ordre en production : après `dedupe:omnes` et `import:omnes-spring`
 * (docs/runbook-rentrees-partenaires.md). Garde de production
 * (src/common/seed-safety.ts), à l'application seulement : autorisée tant
 * qu'aucune offre reconduite n'est en base (première application), refusée
 * ensuite sauf KPB_ALLOW_PRODUCTION_SEED=1.
 */
import { existsSync } from 'node:fs';
import * as path from 'node:path';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';
import * as XLSX from 'xlsx';

import { checkProductionSeed } from '../src/common/seed-safety';
import {
  OMNES_INSTITUTION_ID_PREFIX,
  OMNES_PROGRAM_ID_PREFIX,
  type OmnesRow,
} from '../src/modules/catalog/omnes-conventions';
import {
  applyOmnesFallRollPlan,
  buildFallSourceIndex,
  omnesFallRollWriteCount,
  omnesRowFromRecord,
  planOmnesFallRoll,
} from '../src/modules/catalog/omnes-fall-roll';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
const DEFAULT_XLSX = path.join(__dirname, 'data', 'omnes_fall_26.xlsx');
const SEED_NAME = 'roll:omnes-fall-2027';

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const xlsxPath = args.find((a) => !a.startsWith('--')) ?? DEFAULT_XLSX;
  if (!existsSync(xlsxPath)) {
    console.error(`Grille d'automne introuvable : ${xlsxPath}`);
    process.exit(1);
  }
  const workbook = XLSX.readFile(xlsxPath);
  const records: Record<string, unknown>[] = XLSX.utils.sheet_to_json(
    workbook.Sheets[workbook.SheetNames[0]],
    { defval: '' },
  );
  const rows = records.map(omnesRowFromRecord).filter((r): r is OmnesRow => r !== null);
  console.log(`Grille d'automne : ${xlsxPath} (${rows.length} lignes)`);
  const index = buildFallSourceIndex(rows);

  const programs = await prisma.program.findMany({
    where: {
      OR: [
        { id: { startsWith: OMNES_PROGRAM_ID_PREFIX } },
        { institutionId: { startsWith: OMNES_INSTITUTION_ID_PREFIX } },
      ],
    },
    select: {
      id: true,
      institutionId: true,
      nameFr: true,
      campusOfferings: true,
      updatedAt: true,
      isActive: true,
    },
  });
  const institutions = await prisma.institution.findMany({
    where: { id: { startsWith: OMNES_INSTITUTION_ID_PREFIX } },
    select: { id: true, intakePeriods: true, updatedAt: true },
  });
  const plan = planOmnesFallRoll(programs, institutions, index);

  console.log(`${programs.length} formation(s) OMNES en base, ${institutions.length} école(s).\n`);
  const schools = [
    ...new Set([...programs.map((p) => p.institutionId), ...institutions.map((i) => i.id)]),
  ].sort();
  for (const school of schools) {
    const all = plan.programUpdates.filter((u) => u.institutionId === school);
    const updates = all.filter((u) => u.isActive);
    const offline = all.filter((u) => !u.isActive);
    const flagged = plan.flagged.filter((f) => f.institutionId === school);
    const offers = updates.reduce((n, u) => n + u.rolled.length, 0);
    const inst = plan.institutionUpdates.find((i) => i.id === school);
    if (!all.length && !flagged.length && !inst) continue;
    console.log(`── ${school}`);
    console.log(`   formations reconduites      : ${updates.length}`);
    console.log(`   offres reconduites (→ 2027) : ${offers}`);
    if (offline.length) {
      console.log(
        `   + ${offline.length} fiche(s) hors ligne (alias de dedupe:omnes), ${offline.reduce((n, u) => n + u.rolled.length, 0)} offre(s)`,
      );
    }
    console.log(`   offres retouchées, signalées : ${flagged.length}`);
    if (inst) {
      console.log(
        `   école : ${inst.removed.length} date(s) 2026 remplacée(s), +${inst.added.length} date(s) 2027`,
      );
    }
  }
  const byMonth = new Map<string, number>();
  for (const u of plan.programUpdates) {
    for (const r of u.rolled) {
      for (const d of r.from.split('·')) {
        const month = d.trim().slice(3);
        byMonth.set(month, (byMonth.get(month) ?? 0) + 1);
      }
    }
  }
  if (byMonth.size) {
    console.log(
      `\nDates reconduites par mois : ${[...byMonth.entries()]
        .sort()
        .map(([m, n]) => `${m} → ${m.slice(0, 2)}/2027 : ${n}`)
        .join(' ; ')}`,
    );
  }
  for (const f of plan.flagged) {
    console.log(`  ⚠ ${f.id} (${f.name}) — ${f.campus} ${f.intake} : ${f.reason} — laissée telle quelle`);
  }

  const writes = omnesFallRollWriteCount(plan);
  console.log(`\nTOTAL : ${writes} écriture(s) prévue(s), ${plan.flagged.length} offre(s) signalée(s).`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }
  if (writes === 0) {
    console.log('\n── Rien à écrire : les rentrées d’automne sont déjà reconduites. ──');
    return;
  }

  const guard = await checkProductionSeed({
    seed: SEED_NAME,
    // « Les lignes de cette opération » : les fiches qui portent déjà une
    // offre reconduite. Zéro avant la première application.
    countExistingRows: () =>
      prisma.program.count({
        where: {
          OR: [
            { id: { startsWith: OMNES_PROGRAM_ID_PREFIX } },
            { institutionId: { startsWith: OMNES_INSTITUTION_ID_PREFIX } },
          ],
          campusOfferings: { array_contains: [{ intakeEstimated: true }] },
        },
      }),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  const { written, raced, skippedSchools } = await applyOmnesFallRollPlan(
    {
      // `updatedAt` est rafraîchi à chaque écriture (`@updatedAt`) : une fiche
      // retouchée depuis la lecture ne correspond plus au `WHERE`.
      writeProgramOfferings: async (id, updatedAt, campusOfferings) =>
        (
          await prisma.program.updateMany({
            where: { id, updatedAt },
            data: { campusOfferings: campusOfferings as Prisma.InputJsonValue },
          })
        ).count > 0,
      writeInstitutionIntakes: async (id, updatedAt, intakePeriods) =>
        (
          await prisma.institution.updateMany({
            where: { id, updatedAt },
            data: { intakePeriods: { set: intakePeriods } },
          })
        ).count > 0,
    },
    plan,
  );
  for (const id of raced) console.log(`   ${id} : modifiée entre-temps, laissée intacte — relancer`);
  for (const id of skippedSchools) {
    console.log(`   ${id} : dates de l'école laissées telles quelles (une fiche est à relancer)`);
  }
  console.log(
    `\n── ÉCRIT : ${written} écriture(s)${raced.length ? `, ${raced.length} fiche(s) laissée(s) intacte(s)` : ''}. ──`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
