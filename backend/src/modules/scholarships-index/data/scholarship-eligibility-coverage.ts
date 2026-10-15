// ─────────────────────────────────────────────────────────────────────────────
// Couverture de l'éligibilité structurée, imprimée par `npm run verify:catalog`.
//
// Deux mesures, parce qu'elles répondent à deux questions :
//  - le DÉPÔT (catalogue versionné) : combien de fiches ont des critères, et
//    combien ont été relus par un humain (tamponnés) ;
//  - la BASE (fiches servies au public) : ce que le moteur « Mes 10 bourses »
//    peut réellement analyser aujourd'hui — une fiche sans niveaux n'est
//    jamais montrée, une fiche non tamponnée n'exclut personne.
//
// Un rapport, jamais une porte : `--strict` ne change rien ici. La porte
// éditoriale vit dans le validateur du catalogue
// (`STRUCTURED_ELIGIBILITY_GATE`), et un catalogue honnêtement en brouillon ne
// doit pas bloquer un déploiement.
// ─────────────────────────────────────────────────────────────────────────────
import { isStructuredFresh } from '../../scholarship-match/assess';
import { parseEligibilityCriteria } from '../../scholarship-match/eligibility-criteria';
import type { ScholarshipEligibilityCoverage } from './scholarship-catalog.validator';

/** Les colonnes lues en base, rien de plus (le script tourne sous plafond mémoire). */
export interface ServedEligibilityRow {
  id: string;
  eligibleLevels: readonly string[];
  eligibilityCriteria: unknown;
  eligibilityStructuredAt: Date | null;
}

export interface ServedEligibilityCoverage {
  served: number;
  /** Aucun niveau structuré : jamais montrée, seulement comptée. */
  notAnalyzed: number;
  /** Des niveaux, aucun critère valide, pas de tampon (reprise des tags). */
  levelsOnly: number;
  /** Des critères, mais aucun tampon humain : n'excluent personne. */
  drafts: number;
  /** Tamponnées depuis moins de 400 jours : les règles dures s'appliquent. */
  stampedFresh: number;
  /** Tamponnées il y a plus de 400 jours : « à vérifier », plus d'exclusion. */
  stampedStale: number;
  /** Au moins un critère illisible (ignoré par le moteur). */
  withUnreadableCriteria: number;
}

export function summariseServedEligibility(
  rows: readonly ServedEligibilityRow[],
  now: Date,
): ServedEligibilityCoverage {
  const coverage: ServedEligibilityCoverage = {
    served: rows.length,
    notAnalyzed: 0,
    levelsOnly: 0,
    drafts: 0,
    stampedFresh: 0,
    stampedStale: 0,
    withUnreadableCriteria: 0,
  };
  for (const row of rows) {
    const parsed = parseEligibilityCriteria(row.eligibilityCriteria);
    if (parsed.ignoredKeys.length > 0) coverage.withUnreadableCriteria += 1;
    if (row.eligibleLevels.length === 0) {
      coverage.notAnalyzed += 1;
    } else if (row.eligibilityStructuredAt) {
      if (isStructuredFresh(row.eligibilityStructuredAt, now)) coverage.stampedFresh += 1;
      else coverage.stampedStale += 1;
    } else if (parsed.criteria.length > 0) {
      coverage.drafts += 1;
    } else {
      coverage.levelsOnly += 1;
    }
  }
  return coverage;
}

/** Le rapport lisible. `warn` dit s'il reste du travail éditorial. */
export function renderEligibilityCoverage(
  repo: ScholarshipEligibilityCoverage,
  served: ServedEligibilityCoverage | null,
  catalogVersion: string,
): { lines: string[]; warn: boolean } {
  const lines = [
    `Eligibility coverage — repository catalog ${catalogVersion}: ` +
      `${repo.stamped}/${repo.records} reviewed and stamped (${repo.stale} older than 400 days), ` +
      `${repo.drafts} draft(s), ${repo.missing} without criteria; ` +
      `${repo.criteria} criteria (${repo.byImpact.hard} hard, ${repo.byImpact.soft} soft, ` +
      `${repo.byImpact.informational} informational).`,
  ];
  if (served) {
    lines.push(
      `Eligibility coverage — served scholarships (${served.served}): ` +
        `${served.stampedFresh} stamped (rules apply), ${served.stampedStale} stamped but stale, ` +
        `${served.drafts} draft(s), ${served.levelsOnly} levels only, ` +
        `${served.notAnalyzed} not analysed (never shown by the match), ` +
        `${served.withUnreadableCriteria} with unreadable criteria.`,
    );
  }
  const repoPending = repo.missing + repo.drafts + repo.stale;
  const servedPending = served
    ? served.served - served.stampedFresh + served.withUnreadableCriteria
    : 0;
  const warn = repoPending > 0 || servedPending > 0;
  if (warn) {
    lines.push(
      '::warning::Structured eligibility is not fully reviewed: drafts and unstamped rows exclude ' +
        'no student (they show as « à vérifier »). Review procedure: docs/catalog-verification-sop.md.',
    );
  }
  return { lines, warn };
}
