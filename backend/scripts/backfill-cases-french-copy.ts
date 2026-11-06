/**
 * Reprise des dossiers existants : repasse en français le texte anglais écrit
 * en base avant le correctif « l'app parle français, le serveur écrivait en
 * anglais ».
 *
 * Le correctif ne valait que pour les dossiers à venir. Les lignes déjà en base
 * gardent leur texte anglais et l'app l'affiche tel quel — il ressort même à
 * l'intérieur des notifications push françaises, `milestone-reminder.service.ts`
 * recopiant `nextStepTitle` dans `bodyFr`.
 *
 * Trois garanties, dans cet ordre d'importance :
 *
 *  1. On ne réécrit QUE ce que nos propres services ont écrit. Chaque règle de
 *     `REPRISES` est la trace exacte d'une écriture d'avant le correctif ; une
 *     phrase saisie à la main par un conseiller ne correspond à aucune et reste
 *     intacte.
 *  2. La condition est portée par l'UPDATE lui-même (`WHERE colonne = …`), pas
 *     par une lecture préalable : une valeur modifiée entre le relevé et
 *     l'écriture n'est jamais écrasée — leçon de #272.
 *  3. Rejouable. Les motifs sont ancrés en entier et aucune sortie française ne
 *     correspond à son propre motif : une seconde exécution ne touche rien.
 *
 * Tout se fait dans UNE transaction : ou bien tous les dossiers basculent en
 * français, ou bien rien ne bouge. La simulation exécute la même transaction et
 * l'annule — elle montre donc l'état d'APRÈS, pas un pronostic.
 *
 *   npm run backfill:cases-fr                # simulation, n'écrit rien
 *   npm run backfill:cases-fr -- --apply     # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  COLONNES_ETUDIANT,
  REPRISES,
  compterLignes,
  compterPiecesDOffice,
  reprendre,
  type Executeur,
  type Reprise,
} from '../src/modules/cases/legacy-english-copy';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

/** `"CaseTimelineEvent"."description"` — Prisma nomme en casse mixte. */
const cible = (r: Reprise | { table: string; colonne: string }) =>
  `"${r.table}"."${r.colonne}"`;

/**
 * Ce qui reste et ressemble à de l'anglais. Un indice à l'œil, pas un verdict :
 * la reprise ne touche rien ici, elle le montre pour que rien ne reste
 * silencieusement en production dans la mauvaise langue.
 */
const INDICES_ANGLAIS =
  '(^|[^[:alpha:]])(the|your|you|was|were|has been|have been|will|please|thank|counselor|uploaded|assigned|request|case)([^[:alpha:]]|$)';

const reliquat = async (db: Executeur) => {
  const trouve: { cible: string; valeur: string; n: number }[] = [];
  for (const c of COLONNES_ETUDIANT) {
    const rows = await db.$queryRawUnsafe<{ v: string; n: bigint }[]>(
      `SELECT "${c.colonne}" AS v, count(*)::bigint AS n FROM "${c.table}"
        WHERE "${c.colonne}" ~* '${INDICES_ANGLAIS}'
        GROUP BY 1 ORDER BY 2 DESC LIMIT 20`,
    );
    for (const r of rows) {
      trouve.push({ cible: cible(c), valeur: r.v, n: Number(r.n) });
    }
  }
  return trouve;
};

/** Sentinelle d'annulation : la simulation écrit puis défait. */
const ANNULE = Symbol('simulation');

const executer = async (db: Executeur) => {
  const reecrites = await reprendre(db);
  // On revérifie plutôt que de croire le compte : après coup, plus AUCUNE règle
  // ne doit correspondre.
  const restant =
    (await Promise.all(REPRISES.map((r) => compterLignes(db, r)))).reduce(
      (s, n) => s + n,
      0,
    ) + (await compterPiecesDOffice(db));
  if (restant !== 0) {
    throw new Error(
      `${restant} ligne(s) correspondent encore à une règle après la reprise`,
    );
  }
  return { reecrites, reste: await reliquat(db) };
};

async function main() {
  const apply = process.argv.includes('--apply');

  const releve = await Promise.all(
    REPRISES.map(async (r) => ({ r, n: await compterLignes(prisma, r) })),
  );
  const aReprendre = releve.filter((x) => x.n > 0);
  const total = releve.reduce((s, x) => s + x.n, 0);

  console.log(
    `${REPRISES.length} règles — ${aReprendre.length} avec des lignes à reprendre, ${total} ligne(s) au total\n`,
  );
  console.log(
    `${await compterPiecesDOffice(prisma)} pièce(s) « Profil académique » créée(s) d'office, vide(s), à supprimer\n`,
  );
  for (const { r, n } of aReprendre) {
    console.log(`  ${String(n).padStart(6)}  ${cible(r).padEnd(42)} ${r.anglais}`);
    console.log(`          ${' '.repeat(42)} → ${r.francais}`);
  }

  // Une reprise de production peut porter sur beaucoup de lignes : les 5 s par
  // défaut de Prisma suffiraient à faire échouer un travail par ailleurs sain.
  const bornes = { maxWait: 30_000, timeout: 600_000 };
  let resultat: { reecrites: number; reste: Awaited<ReturnType<typeof reliquat>> };

  if (apply) {
    resultat = await prisma.$transaction((tx) => executer(tx), bornes);
    console.log(`\n${resultat.reecrites} ligne(s) réécrite(s), et vérifiées.`);
  } else {
    let capture: typeof resultat | undefined;
    try {
      await prisma.$transaction(async (tx) => {
        capture = await executer(tx);
        throw ANNULE;
      }, bornes);
    } catch (e) {
      if (e !== ANNULE) throw e;
    }
    resultat = capture!;
    console.log(
      `\nSimulation — ${resultat.reecrites} ligne(s) seraient réécrites. Transaction annulée, rien n’a été écrit.`,
    );
    if (total > 0) console.log('Relancer avec --apply pour écrire.');
  }

  if (resultat.reste.length > 0) {
    console.log(
      `\nÀ l’œil — ${resultat.reste.length} valeur(s) restent et contiennent un mot anglais courant.`,
    );
    console.log('Aucune règle ne les couvre : à relire avant de conclure.\n');
    for (const x of resultat.reste) {
      console.log(
        `  ${String(x.n).padStart(6)}  ${x.cible.padEnd(42)} ${JSON.stringify(x.valeur).slice(0, 110)}`,
      );
    }
  } else {
    console.log('\nAucun reliquat anglais dans les colonnes reprises.');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
