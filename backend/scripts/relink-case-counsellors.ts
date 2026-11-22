/**
 * Corrige le lien `Case.counsellorId` des dossiers existants (audit
 * 2026-11-22, constat 2). Les dossiers réaffectés à la main AVANT le
 * correctif ont gardé l'ancien conseiller (nom = Awa, lien = Jojo) : Jojo
 * garde la portée, la messagerie, les pièces et reçoit les alertes e-mail.
 * Idem, un dossier sans lien dont la fiche conseiller a été créée depuis.
 *
 * Règle appliquée : celle du « même nom renvoyé » de `CasesService`
 * (`relinkedCounsellorIdForSameName`, src/modules/cases/counsellor-link.ts).
 * Le dossier n'est relié que si le conseiller lié ne porte pas le nom
 * d'affectation ET qu'une autre fiche y correspond sans ambiguïté ; sinon
 * rien ne change. Rejouable : une seconde exécution ne trouve plus rien.
 *
 *   npm run relink:case-counsellors               # simulation, n'écrit rien
 *   npm run relink:case-counsellors -- --apply    # écrit
 */
import { existsSync } from "node:fs";
import { loadEnvFile } from "node:process";

import { PrismaClient } from "@prisma/client";

import {
  linkedCounsellorBearsName,
  relinkedCounsellorIdForSameName,
} from "../src/modules/cases/counsellor-link";

if (existsSync(".env")) loadEnvFile?.(".env");

const prisma = new PrismaClient();

async function main() {
  const apply = process.argv.includes("--apply");
  const cut = process.argv.includes("--cut");
  const cases = await prisma.case.findMany({
    where: { assignedAdvisorName: { not: null } },
    select: {
      id: true,
      referenceCode: true,
      assignedAdvisorName: true,
      counsellorId: true,
    },
    orderBy: { createdAt: "asc" },
  });

  let changes = 0;
  const unresolved: string[] = [];
  for (const c of cases) {
    const name = c.assignedAdvisorName?.trim();
    if (!name) continue;
    const next = await relinkedCounsellorIdForSameName(
      prisma,
      c.counsellorId,
      name,
    );
    if (next === undefined) {
      // Lien vers quelqu'un qui ne porte pas le nom, sans fiche cible sûre :
      // l'ancien conseiller garde l'accès. On ne le tait pas.
      if (
        c.counsellorId &&
        !(await linkedCounsellorBearsName(prisma, c.counsellorId, name))
      ) {
        unresolved.push(
          `${c.referenceCode ?? c.id} « ${name} » : lié à ${c.counsellorId}`,
        );
        if (apply && cut) {
          const { count } = await prisma.case.updateMany({
            where: { id: c.id, counsellorId: c.counsellorId },
            data: { counsellorId: null },
          });
          if (count !== 1) console.warn(`  ignoré : lien modifié entre-temps.`);
        }
      }
      continue;
    }
    changes += 1;
    console.log(
      `${c.referenceCode ?? c.id} « ${name} » : ${c.counsellorId ?? "(aucun)"} -> ${next}`,
    );
    if (apply) {
      // Garde-fou : on n'écrit que si le lien n'a pas bougé entre-temps.
      const { count } = await prisma.case.updateMany({
        where: { id: c.id, counsellorId: c.counsellorId },
        data: { counsellorId: next },
      });
      if (count !== 1) console.warn(`  ignoré : lien modifié entre-temps.`);
    }
  }

  if (unresolved.length > 0) {
    console.log(
      `\nLiens incohérents NON résolus (l'ancien conseiller garde l'accès)${apply && cut ? " — coupés" : " — à vérifier"} :`,
    );
    for (const line of unresolved) console.log(`  ${line}`);
  }
  console.log(
    `\n${cases.length} dossier(s) avec un nom d'affectation, ${changes} lien(s) à corriger, ${unresolved.length} non résolu(s).`,
  );
  if (!apply) {
    console.log("Simulation : rien n'a été écrit.");
    if (changes > 0) console.log("Relancer avec --apply pour écrire.");
    if (unresolved.length > 0)
      console.log(
        "Ajouter --cut (avec --apply) pour couper les liens non résolus.",
      );
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
