/**
 * Ramène les dates de naissance au minuit UTC du jour saisi (audit de la 57,
 * T4-06). Règle : src/modules/profiles/birthdate-backfill.ts.
 *
 * Une transaction, revérifiée : après coup, plus aucune date hors minuit. La
 * simulation exécute la même transaction et l'annule.
 *
 *   npm run backfill:birthdates                # simulation, n'écrit rien
 *   npm run backfill:birthdates -- --apply     # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  ramenerAMinuit,
  releverHeures,
  type Executeur,
} from '../src/modules/profiles/birthdate-backfill';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
const ANNULE = Symbol('simulation');

const executer = async (db: Executeur) => {
  const corrigees = await ramenerAMinuit(db);
  const reste = await releverHeures(db);
  if (reste.length > 0) {
    throw new Error(
      `${reste.length} heure(s) restent hors minuit après correction. Transaction annulée.`,
    );
  }
  return corrigees;
};

async function main() {
  const apply = process.argv.includes('--apply');
  const heures = await releverHeures(prisma);
  const total = heures.reduce((s, h) => s + h.n, 0);
  console.log(`${total} date(s) de naissance hors minuit UTC`);
  for (const h of heures) {
    console.log(`  ${String(h.n).padStart(6)}  à ${h.heure} UTC`);
  }

  const bornes = { maxWait: 30_000, timeout: 600_000 };
  if (apply) {
    const n = await prisma.$transaction((tx) => executer(tx), bornes);
    console.log(`\n${n} date(s) ramenée(s) à minuit UTC, et vérifiées.`);
    return;
  }
  let n = 0;
  try {
    await prisma.$transaction(async (tx) => {
      n = await executer(tx);
      throw ANNULE;
    }, bornes);
  } catch (e) {
    if (e !== ANNULE) throw e;
  }
  console.log(
    `\nSimulation — ${n} date(s) seraient ramenées à minuit UTC. Transaction annulée, rien n’a été écrit.`,
  );
  if (total > 0) console.log('Relancer avec --apply pour écrire.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
