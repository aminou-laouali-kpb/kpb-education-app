/**
 * Supprime les « Dossier réattribué » écrits en boucle avant la PR #397 : par
 * dossier, seule la ligne la plus récente reste. Règle et garanties :
 * src/modules/cases/reassigned-events-cleanup.ts.
 *
 * Tout se fait dans UNE transaction, revérifiée avant validation : après coup,
 * chaque dossier concerné doit avoir exactement une ligne, et le nombre de
 * dossiers ne doit pas avoir bougé. La simulation exécute la même transaction
 * et l'annule : elle montre l'état d'APRÈS, pas un pronostic.
 *
 *   npm run cleanup:reassigned-events                # simulation, n'écrit rien
 *   npm run cleanup:reassigned-events -- --apply     # supprime
 */
import { existsSync } from "node:fs";
import { loadEnvFile } from "node:process";

import { PrismaClient } from "@prisma/client";

import {
  nettoyer,
  relever,
  type Executeur,
  type Releve,
} from "../src/modules/cases/reassigned-events-cleanup";

if (existsSync(".env")) loadEnvFile?.(".env");

const prisma = new PrismaClient();

const ANNULE = Symbol("simulation");

const afficher = (titre: string, r: Releve) =>
  console.log(
    `${titre} : ${r.total} ligne(s) sur ${r.dossiers} dossier(s), ${r.enTrop} en trop, au plus ${r.maxParDossier} pour un même dossier`,
  );

const executer = async (db: Executeur, avant: Releve) => {
  const supprimees = await nettoyer(db);
  const apres = await relever(db);
  if (
    supprimees !== avant.enTrop ||
    apres.dossiers !== avant.dossiers ||
    apres.total !== avant.dossiers ||
    (apres.dossiers > 0 && apres.maxParDossier !== 1)
  ) {
    throw new Error(
      `Vérification échouée — ${supprimees} supprimée(s) pour ${avant.enTrop} attendue(s) ; après : ${JSON.stringify(apres)}. Transaction annulée.`,
    );
  }
  return { supprimees, apres };
};

async function main() {
  const apply = process.argv.includes("--apply");
  const avant = await relever(prisma);
  afficher("Avant", avant);

  const bornes = { maxWait: 30_000, timeout: 600_000 };
  if (apply) {
    const { supprimees, apres } = await prisma.$transaction(
      (tx) => executer(tx, avant),
      bornes,
    );
    afficher("Après", apres);
    console.log(`\n${supprimees} ligne(s) supprimée(s), et vérifiées.`);
    return;
  }

  let capture: Awaited<ReturnType<typeof executer>> | undefined;
  try {
    await prisma.$transaction(async (tx) => {
      capture = await executer(tx, avant);
      throw ANNULE;
    }, bornes);
  } catch (e) {
    if (e !== ANNULE) throw e;
  }
  afficher("Après (simulé)", capture!.apres);
  console.log(
    `\nSimulation — ${capture!.supprimees} ligne(s) seraient supprimées. Transaction annulée, rien n’a été écrit.`,
  );
  if (avant.enTrop > 0) console.log("Relancer avec --apply pour supprimer.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
