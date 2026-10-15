import { writeFileSync } from 'node:fs';

import { SCHOLARSHIP_CATALOG_V1 } from '../src/modules/scholarships-index/data/scholarship-catalog.v1';
import { validateScholarshipCatalog } from '../src/modules/scholarships-index/data/scholarship-catalog.validator';

const structureOnly = process.argv.includes('--structure-only');

/**
 * `--ignore-clock` : sortir sur le verdict qui ne dépend PAS du passage du
 * temps.
 *
 * Pourquoi ce drapeau existe. L'en-tête de `catalog-freshness.yml` promet, noir
 * sur blanc, que le pourrissement daté du catalogue est « délibérément SÉPARÉ de
 * la CI backend », parce qu'« une campagne close est une ligne de littéral à
 * rafraîchir, ce n'est pas une raison de bloquer une PR d'authentification ».
 * Cette séparation n'était pas implémentée : le même script servait les deux
 * consommateurs avec le même verdict, et `CATALOG_EXPIRED_CYCLE_CODES` — la
 * constante qui nomme précisément ces codes — n'était branchée à rien.
 *
 * Le 20/08/2026 la promesse a été démentie en production : la date limite de
 * McCall MacBain est passée pendant la nuit et la CI backend est devenue rouge
 * sur TOUTE PR ouverte ce jour-là, dont un correctif de fuite de données
 * personnelles. Personne n'avait touché au dépôt.
 *
 * Le drapeau ne CACHE rien : le rapport complet est imprimé, anomalies datées
 * comprises, et le contrôle planifié quotidien continue de sortir sur le verdict
 * strict. Il déplace seulement la responsabilité là où le geste correctif se
 * trouve.
 */
const ignoreClock = process.argv.includes('--ignore-clock');

/** Valeur qui suit un drapeau `--nom <valeur>`, ou undefined s'il est absent. */
function argValue(flag: string): string | undefined {
  const index = process.argv.indexOf(flag);
  if (index < 0 || index + 1 >= process.argv.length) return undefined;
  return process.argv[index + 1];
}

/**
 * `--now <ISO>` : valider à une horloge choisie plutôt qu'à celle du système.
 *
 * Sans ce drapeau, le comportement « une échéance vient d'entrer dans l'horizon
 * de 14 jours » n'est observable qu'UN jour précis par échéance : impossible à
 * rejouer dans un test, impossible à voir rouge par mutation. Le validateur
 * acceptait déjà `options.now` ; ceci ne fait que l'exposer au shell.
 */
const nowArg = argValue('--now');
const now = nowArg === undefined ? undefined : new Date(nowArg);
if (now !== undefined && Number.isNaN(now.getTime())) {
  console.error(`--now : date invalide « ${nowArg} » (attendu : ISO 8601).`);
  process.exit(2);
}

/**
 * `--report <chemin>` : écrire le rapport JSON dans un fichier qui ne contient
 * QUE lui.
 *
 * Le consommateur planifié (`catalog-freshness.yml`) lisait le rapport en
 * capturant stdout (`2>&1 | tee`) puis en découpant depuis la première
 * accolade. Or ce script imprime aussi des annotations `::warning::` de
 * clôture proche — APRÈS le JSON. Le découpage les gardait donc en queue, et
 * `JSON.parse` aurait explosé le jour précis où la première échéance entrait
 * dans l'horizon : le 27/08/2026 (Schwarzman, clôture le 09/09), à la première
 * exécution du cron. L'étape mourait avant d'écrire ses sorties — ni issue, ni
 * annotation : l'alarme s'éteignait au moment exact où elle avait quelque
 * chose à dire. Un fichier dédié rend cette classe d'accident impossible,
 * quel que soit ce que ce script imprimera demain.
 */
const reportPath = argValue('--report');

const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
  includeVolumeTargets: !structureOnly,
  ...(now === undefined ? {} : { now }),
});

console.log(JSON.stringify(report, null, 2));
if (reportPath !== undefined) {
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
}

// Les échéances proches ne sont pas des anomalies, elles ne pèsent sur aucun
// verdict — mais elles doivent être LUES. Les écrire en annotation GitHub les
// fait remonter dans le résumé du run, y compris quand tout est vert : c'est le
// seul moment où quelqu'un peut encore choisir QUAND agir.
//
// Sur STDERR, jamais sur stdout : stdout porte le rapport JSON, et tout ce qui
// s'y ajoute finit un jour dans un `JSON.parse` ou un `| jq` — c'est
// littéralement l'accident du 27/08 décrit sur `--report`. GitHub lit ses
// commandes de workflow dans le journal complet, stderr compris : l'annotation
// fonctionne pareil.
for (const soon of report.closingSoon) {
  console.error(
    `::warning::${soon.scholarshipId} clôt dans ${soon.daysLeft} jour(s) ` +
      `(${soon.closesAt.slice(0, 10)}). Passez le cycle en « closed » ce jour-là, ` +
      `ou publiez les dates du cycle suivant si la source les donne. ` +
      `Sans geste, la validation datée deviendra rouge.`,
  );
}

// L'éligibilité structurée non relue AVERTIT sans bloquer (voir
// STRUCTURED_ELIGIBILITY_GATE dans le validateur) : une annotation unique, pas
// une par fiche, pour qu'elle reste lisible dans le résumé du run. Le détail
// fiche par fiche est dans `warnings` du rapport JSON.
const coverage = report.eligibilityCoverage;
if (coverage.missing + coverage.drafts + coverage.stale > 0) {
  console.error(
    `::warning::Éligibilité structurée : ${coverage.stamped}/${coverage.records} fiche(s) ` +
      `relue(s) et tamponnée(s) (${coverage.stale} périmée(s)), ${coverage.drafts} brouillon(s), ` +
      `${coverage.missing} sans critères. Un brouillon n'exclut aucun élève : ` +
      'relire chaque fiche contre sa source puis la tamponner (docs/catalog-verification-sop.md).',
  );
}

const passed = ignoreClock ? report.validIgnoringClock : report.valid;
if (!passed) {
  process.exitCode = 1;
}
