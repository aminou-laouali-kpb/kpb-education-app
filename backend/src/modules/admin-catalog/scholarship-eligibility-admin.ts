import { BadRequestException } from '@nestjs/common';

import type { AdminSessionUser } from '../auth/auth.service';
import { isStructuredFresh, STRUCTURED_FRESHNESS_DAYS } from '../scholarship-match/assess';
import {
  ELIGIBLE_LEVELS,
  parseEligibilityCriteria,
  validateEligibilityCriteria,
  type CriterionIssue,
  type EligibilityCriterion,
  type EligibleLevel,
} from '../scholarship-match/eligibility-criteria';
import { stableStringify } from '../scholarship-match/match-inputs';

/**
 * Éligibilité structurée côté back-office (« Mes 10 bourses », chantier D4).
 *
 * Fonctions PURES, sans Prisma : lecture stricte des champs envoyés par
 * l'éditeur, plan d'écriture (tampon « Conditions vérifiées » et audit) et
 * couverture du catalogue public — la porte de lancement.
 *
 * Contrairement aux autres champs de `updateScholarship` (tolérants : ce qui
 * n'est pas reconnu est ignoré), une valeur d'éligibilité présente mais
 * invalide est REFUSÉE par une 400 qui liste les erreurs : un critère abandonné
 * en silence serait une règle que l'éditeur croit avoir posée.
 */

export const FIELDS_SCOPES = ['unknown', 'all', 'listed'] as const;
export type FieldsScope = (typeof FIELDS_SCOPES)[number];

/** Part minimale (en %) de bourses publiques structurées et fraîches pour lancer. */
export const LAUNCH_GATE_PERCENT = 90;

/** Au plus N bourses listées « à structurer » dans la réponse de couverture. */
export const COVERAGE_LIST_LIMIT = 500;

export const ELIGIBILITY_AUDIT_PURPOSE = 'scholarship_eligibility';
export const ELIGIBILITY_AUDIT_ENTITY_TYPE = 'Scholarship';
export const ELIGIBILITY_AUDIT_ACTIONS = [
  'scholarship.eligibility_updated',
  'scholarship.eligibility_structured',
  'scholarship.eligibility_unstamped',
] as const;
export type EligibilityAuditAction = (typeof ELIGIBILITY_AUDIT_ACTIONS)[number];

/** Codes d'erreur des 400 (lus par l'admin). */
export const ELIGIBILITY_ERROR_CODES = [
  'INVALID_ELIGIBLE_LEVELS',
  'INVALID_FIELDS_SCOPE',
  'INVALID_ELIGIBILITY_CRITERIA',
  'INVALID_MARK_STRUCTURED',
  'ELIGIBILITY_LEVELS_REQUIRED',
] as const;
export type EligibilityErrorCode = (typeof ELIGIBILITY_ERROR_CODES)[number];

const ELIGIBILITY_KEYS = [
  'eligibleLevels',
  'fieldsScope',
  'eligibilityCriteria',
  'markStructured',
] as const;

/** Ce que l'éditeur a demandé d'écrire ; une clé absente = inchangée. */
export interface EligibilityWrite {
  eligibleLevels?: EligibleLevel[];
  fieldsScope?: FieldsScope;
  eligibilityCriteria?: EligibilityCriterion[];
  /** `true` : tamponner « Conditions vérifiées » ; `false` : retirer le tampon. */
  markStructured?: boolean;
}

/** L'état d'éligibilité d'une ligne, tel qu'il est en base. */
export interface EligibilityState {
  eligibleLevels: readonly string[];
  fieldsScope: string;
  eligibilityCriteria: unknown;
  eligibilityStructuredAt: Date | null;
  eligibilityStructuredBy: string | null;
}

export const EMPTY_ELIGIBILITY_STATE: EligibilityState = {
  eligibleLevels: [],
  fieldsScope: 'unknown',
  eligibilityCriteria: [],
  eligibilityStructuredAt: null,
  eligibilityStructuredBy: null,
};

function badRequest(
  code: EligibilityErrorCode,
  message: string | string[],
  issues?: CriterionIssue[],
): BadRequestException {
  return new BadRequestException({
    statusCode: 400,
    error: 'Bad Request',
    code,
    message,
    ...(issues ? { issues } : {}),
  });
}

function criteriaError(issues: CriterionIssue[]): BadRequestException {
  return badRequest(
    'INVALID_ELIGIBILITY_CRITERIA',
    issues.map((issue) => `eligibilityCriteria${issue.path} : ${issue.message}`),
    issues,
  );
}

/** Vrai si le corps touche à l'éligibilité structurée. */
export function hasEligibilityInput(input: Record<string, unknown>): boolean {
  return ELIGIBILITY_KEYS.some((key) => Object.prototype.hasOwnProperty.call(input, key));
}

/**
 * Lit les champs d'éligibilité du corps, strictement. `null` vaut « vider »
 * (niveaux et critères vides, domaines `unknown`) ; une valeur invalide lève
 * une 400 dont `issues` liste chaque erreur de forme des critères.
 */
export function pickEligibilityWrite(input: Record<string, unknown>): EligibilityWrite {
  const write: EligibilityWrite = {};
  const has = (key: string) => Object.prototype.hasOwnProperty.call(input, key);

  if (has('eligibleLevels')) {
    const raw = input.eligibleLevels;
    if (raw === null) {
      write.eligibleLevels = [];
    } else if (!Array.isArray(raw)) {
      throw badRequest('INVALID_ELIGIBLE_LEVELS', 'eligibleLevels : tableau attendu.');
    } else {
      const unknown = raw.filter(
        (level) => !(ELIGIBLE_LEVELS as readonly unknown[]).includes(level),
      );
      if (unknown.length > 0) {
        throw badRequest(
          'INVALID_ELIGIBLE_LEVELS',
          `eligibleLevels : niveau inconnu (${unknown.map(String).join(', ')}). Attendus : ${ELIGIBLE_LEVELS.join(', ')}.`,
        );
      }
      // Ordre canonique, sans doublon : deux saisies équivalentes sont égales.
      write.eligibleLevels = ELIGIBLE_LEVELS.filter((level) => raw.includes(level));
    }
  }

  if (has('fieldsScope')) {
    const raw = input.fieldsScope;
    if (raw === null) {
      write.fieldsScope = 'unknown';
    } else if (typeof raw !== 'string' || !(FIELDS_SCOPES as readonly string[]).includes(raw)) {
      throw badRequest(
        'INVALID_FIELDS_SCOPE',
        `fieldsScope : attendu ${FIELDS_SCOPES.join(', ')}.`,
      );
    } else {
      write.fieldsScope = raw as FieldsScope;
    }
  }

  if (has('eligibilityCriteria')) {
    const raw = input.eligibilityCriteria === null ? [] : input.eligibilityCriteria;
    const issues = validateEligibilityCriteria(raw);
    if (issues.length > 0) throw criteriaError(issues);
    // La copie normalisée de la garde : aucun champ superflu n'est stocké.
    write.eligibilityCriteria = parseEligibilityCriteria(raw).criteria;
  }

  if (has('markStructured')) {
    if (typeof input.markStructured !== 'boolean') {
      throw badRequest('INVALID_MARK_STRUCTURED', 'markStructured : booléen attendu.');
    }
    write.markStructured = input.markStructured;
  }

  return write;
}

/** Qui a tamponné, tel qu'on l'affiche (« Conditions vérifiées par … »). */
export function structuredByLabel(actor: AdminSessionUser | undefined): string {
  return actor?.fullName?.trim() || actor?.email?.trim() || actor?.id || 'unknown-admin';
}

export interface EligibilityAuditPlan {
  action: EligibilityAuditAction;
  changes: {
    changedFields: string[];
    eligibleLevels: string[];
    fieldsScope: string;
    criteriaCount: number;
    criteriaKeys: string[];
    stamped: boolean;
    stampCleared: boolean;
    previousStructuredAt: string | null;
  };
}

export interface EligibilityPlan {
  /** Colonnes à écrire (vide : rien ne change). */
  data: {
    eligibleLevels?: EligibleLevel[];
    fieldsScope?: FieldsScope;
    eligibilityCriteria?: EligibilityCriterion[];
    eligibilityStructuredAt?: Date | null;
    eligibilityStructuredBy?: string | null;
  };
  audit: EligibilityAuditPlan | null;
}

/**
 * Le plan d'écriture d'une demande d'éligibilité sur une ligne existante.
 *
 * Le tampon certifie EXACTEMENT le contenu enregistré avec lui :
 * - `markStructured: true` tamponne (maintenant, par l'auteur) le contenu
 *   final — refusé sans niveau, ou si les critères en base sont illisibles ;
 * - `markStructured: false` retire le tampon ;
 * - un contenu modifié SANS nouveau tampon retire l'ancien (la fiche redevient
 *   un brouillon : ses règles n'excluent plus personne tant qu'un éditeur ne les
 *   a pas revues) ;
 * - rien de changé, rien de demandé : aucune écriture, aucun audit.
 */
export function planEligibilityUpdate(
  existing: EligibilityState,
  write: EligibilityWrite,
  actor: AdminSessionUser | undefined,
  now: Date,
): EligibilityPlan {
  const data: EligibilityPlan['data'] = {};
  const changedFields: string[] = [];

  const finalLevels = write.eligibleLevels ?? [...existing.eligibleLevels];
  const finalScope = write.fieldsScope ?? existing.fieldsScope;
  const finalCriteriaRaw = write.eligibilityCriteria ?? existing.eligibilityCriteria;

  if (
    write.eligibleLevels !== undefined &&
    stableStringify(write.eligibleLevels) !== stableStringify([...existing.eligibleLevels])
  ) {
    data.eligibleLevels = write.eligibleLevels;
    changedFields.push('eligibleLevels');
  }
  if (write.fieldsScope !== undefined && write.fieldsScope !== existing.fieldsScope) {
    data.fieldsScope = write.fieldsScope;
    changedFields.push('fieldsScope');
  }
  if (
    write.eligibilityCriteria !== undefined &&
    stableStringify(write.eligibilityCriteria) !== stableStringify(existing.eligibilityCriteria ?? [])
  ) {
    data.eligibilityCriteria = write.eligibilityCriteria;
    changedFields.push('eligibilityCriteria');
  }

  const wasStamped = existing.eligibilityStructuredAt !== null;
  let action: EligibilityAuditAction | null = null;
  let stamped = false;
  let stampCleared = false;

  if (write.markStructured === true) {
    if (finalLevels.length === 0) {
      throw badRequest(
        'ELIGIBILITY_LEVELS_REQUIRED',
        'Cochez au moins un niveau avant de marquer les conditions comme vérifiées.',
      );
    }
    // Le tampon porte sur le contenu FINAL : des critères stockés illisibles
    // (saisis avant ce contrôle) ne se certifient pas.
    const issues = validateEligibilityCriteria(finalCriteriaRaw ?? []);
    if (issues.length > 0) throw criteriaError(issues);
    data.eligibilityStructuredAt = now;
    data.eligibilityStructuredBy = structuredByLabel(actor);
    action = 'scholarship.eligibility_structured';
    stamped = true;
  } else if (write.markStructured === false) {
    if (wasStamped) {
      data.eligibilityStructuredAt = null;
      data.eligibilityStructuredBy = null;
      stampCleared = true;
    }
    action = 'scholarship.eligibility_unstamped';
  } else if (changedFields.length > 0) {
    if (wasStamped) {
      data.eligibilityStructuredAt = null;
      data.eligibilityStructuredBy = null;
      stampCleared = true;
    }
    action = 'scholarship.eligibility_updated';
  }

  if (action === null) return { data, audit: null };

  const finalCriteria = parseEligibilityCriteria(finalCriteriaRaw).criteria;
  return {
    data,
    audit: {
      action,
      changes: {
        changedFields,
        eligibleLevels: [...finalLevels],
        fieldsScope: finalScope,
        criteriaCount: finalCriteria.length,
        criteriaKeys: finalCriteria.map((criterion) => criterion.key),
        stamped,
        stampCleared,
        previousStructuredAt: existing.eligibilityStructuredAt?.toISOString() ?? null,
      },
    },
  };
}

// ── Couverture (porte de lancement) ─────────────────────────────────────────

/**
 * - `fresh`        — niveaux posés, tampon de moins de 400 jours : les règles
 *                    dures peuvent exclure ;
 * - `stale`        — tampon de 400 jours ou plus : plafonnée à « à vérifier » ;
 * - `unstructured` — niveaux posés (repris des tags ou saisis), jamais
 *                    tamponnés : un brouillon ;
 * - `not_analyzed` — aucun niveau : jamais montrée par le test.
 */
export type EligibilityCoverageState = 'fresh' | 'stale' | 'unstructured' | 'not_analyzed';

export function eligibilityCoverageState(
  row: Pick<EligibilityState, 'eligibleLevels' | 'eligibilityStructuredAt'>,
  now: Date,
): EligibilityCoverageState {
  if (row.eligibleLevels.length === 0) return 'not_analyzed';
  if (!row.eligibilityStructuredAt) return 'unstructured';
  return isStructuredFresh(row.eligibilityStructuredAt, now) ? 'fresh' : 'stale';
}

export interface CoverageRow extends Pick<
  EligibilityState,
  'eligibleLevels' | 'eligibilityStructuredAt' | 'eligibilityStructuredBy' | 'eligibilityCriteria'
> {
  id: string;
  nameFr: string;
  nameEn: string;
}

export interface CoverageItem {
  id: string;
  nameFr: string;
  nameEn: string;
  state: Exclude<EligibilityCoverageState, 'fresh'>;
  structuredAt: string | null;
  structuredBy: string | null;
}

export interface EligibilityCoverage {
  generatedAt: string;
  freshnessDays: number;
  launchGatePercent: number;
  /** Bourses publiques (publicScholarshipWhere). */
  total: number;
  structuredFresh: number;
  stale: number;
  unstructured: number;
  notAnalyzed: number;
  /** Bourses fraîches dont un critère stocké est illisible (ignoré par le moteur). */
  invalidCriteria: number;
  /** Part des bourses publiques structurées et fraîches, arrondie à 0,1 par défaut. */
  coveragePercent: number;
  /** Vrai quand la part atteint la porte de lancement (90 %). */
  launchReady: boolean;
  /** À structurer : non analysées, puis brouillons, puis périmées ; par nom. */
  toStructure: CoverageItem[];
  toStructureIds: string[];
  truncated: boolean;
}

const STATE_ORDER: Record<CoverageItem['state'], number> = {
  not_analyzed: 0,
  unstructured: 1,
  stale: 2,
};

export function summarizeCoverage(
  rows: readonly CoverageRow[],
  now: Date,
  limit = COVERAGE_LIST_LIMIT,
): EligibilityCoverage {
  const counts: Record<EligibilityCoverageState, number> = {
    fresh: 0,
    stale: 0,
    unstructured: 0,
    not_analyzed: 0,
  };
  let invalidCriteria = 0;
  const pending: CoverageItem[] = [];
  for (const row of rows) {
    const state = eligibilityCoverageState(row, now);
    counts[state] += 1;
    if (state === 'fresh') {
      if (parseEligibilityCriteria(row.eligibilityCriteria).issues.length > 0) {
        invalidCriteria += 1;
      }
      continue;
    }
    pending.push({
      id: row.id,
      nameFr: row.nameFr,
      nameEn: row.nameEn,
      state,
      structuredAt: row.eligibilityStructuredAt?.toISOString() ?? null,
      structuredBy: row.eligibilityStructuredBy ?? null,
    });
  }
  pending.sort(
    (a, b) =>
      STATE_ORDER[a.state] - STATE_ORDER[b.state] ||
      a.nameFr.localeCompare(b.nameFr, 'fr') ||
      (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
  const total = rows.length;
  // Arrondi PAR DÉFAUT : 89,96 % ne doit jamais s'afficher « 90 % ».
  const coveragePercent = total === 0 ? 0 : Math.floor((counts.fresh * 1000) / total) / 10;
  const shown = pending.slice(0, limit);
  return {
    generatedAt: now.toISOString(),
    freshnessDays: STRUCTURED_FRESHNESS_DAYS,
    launchGatePercent: LAUNCH_GATE_PERCENT,
    total,
    structuredFresh: counts.fresh,
    stale: counts.stale,
    unstructured: counts.unstructured,
    notAnalyzed: counts.not_analyzed,
    invalidCriteria,
    coveragePercent,
    launchReady: total > 0 && counts.fresh * 100 >= LAUNCH_GATE_PERCENT * total,
    toStructure: shown,
    toStructureIds: shown.map((item) => item.id),
    truncated: pending.length > shown.length,
  };
}
