/**
 * Corrige le texte du pays France en base (audit de la 57, T5-10). Règle :
 * src/modules/countries/france-copy-fix.ts.
 *
 *   npm run fix:france-copy                # simulation, n'écrit rien
 *   npm run fix:france-copy -- --apply     # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  corrigerFrance,
  FRANCE_COPY_FIXES,
} from '../src/modules/countries/france-copy-fix';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
const ANNULE = Symbol('simulation');

async function main() {
  const apply = process.argv.includes('--apply');
  let detail: { colonne: string; n: number }[] = [];
  if (apply) {
    detail = await prisma.$transaction((tx) => corrigerFrance(tx));
  } else {
    try {
      await prisma.$transaction(async (tx) => {
        detail = await corrigerFrance(tx);
        throw ANNULE;
      });
    } catch (e) {
      if (e !== ANNULE) throw e;
    }
  }
  for (const d of detail) {
    const f = FRANCE_COPY_FIXES.find((x) => x.colonne === d.colonne)!;
    console.log(
      `${d.n ? 'réécrit ' : 'inchangé'}  ${d.colonne.padEnd(24)} → ${JSON.stringify(f.nouveau)}`,
    );
  }
  const total = detail.reduce((s, d) => s + d.n, 0);
  console.log(
    apply
      ? `\n${total} champ(s) réécrit(s).`
      : `\nSimulation — ${total} champ(s) seraient réécrits. Transaction annulée.${total ? ' Relancer avec --apply.' : ''}`,
  );
  console.log(
    'Un champ « inchangé » porte déjà le nouveau texte, ou une retouche faite dans l’admin (gardée).',
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
