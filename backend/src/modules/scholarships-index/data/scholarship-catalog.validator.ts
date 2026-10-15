import { STRUCTURED_FRESHNESS_DAYS } from '../../scholarship-match/assess';
import {
  parseEligibilityCriteria,
  validateEligibilityCriteria,
} from '../../scholarship-match/eligibility-criteria';
import {
  DRAFT_STRUCTURED_BY,
  REQUIRED_OFFICIAL_SOURCE_KINDS,
  SCHOLARSHIP_FIELDS_SCOPES,
  SCHOLARSHIP_STUDY_LEVELS,
  type ScholarshipStudyLevel,
  type VerifiedScholarshipCatalogRecord,
  type VersionedScholarshipCatalog,
} from './scholarship-catalog.types';

const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_VERIFICATION_AGE_DAYS = 30;

/**
 * La porte éditoriale de l'éligibilité structurée : `warning` ou `error`.
 *
 * `missing_structured_eligibility` signale une fiche dont l'éligibilité n'a
 * pas été relue par un humain (aucun bloc, ou un brouillon sans tampon). La
 * spécification du chantier D la voulait BLOQUANTE dès 1.5.0 (porte « tout ou
 * rien »). Elle est livrée en AVERTISSEMENT : les 36 fiches portent des
 * brouillons honnêtement non tamponnés, et une erreur rendrait la CI rouge sur
 * toute PR jusqu'à la fin de la relecture — ce qui pousserait à tamponner sans
 * relire, exactement ce que la règle doit empêcher.
 *
 * Passage en `error` prévu, en UNE ligne ici, le jour où la couverture
 * (`eligibilityCoverage.stamped`) atteint le nombre de fiches : à partir de là,
 * toute fiche ajoutée sans éligibilité relue casse la CI. Procédure :
 * `docs/catalog-verification-sop.md`, « Structurer l'éligibilité ».
 */
export const STRUCTURED_ELIGIBILITY_GATE: 'warning' | 'error' = 'warning';

/** Le vocabulaire des tags qui reprennent `levels` (voir scholarship-level.ts). */
const LEVEL_TAGS: ReadonlySet<string> = new Set(SCHOLARSHIP_STUDY_LEVELS);

/**
 * L'horizon d'alerte AVANT clôture.
 *
 * Le 20/08/2026, la date limite de McCall MacBain est passée pendant la nuit et
 * la CI backend est devenue rouge sur toute PR ouverte ce jour-là. Personne
 * n'avait touché au dépôt. Le contrôle planifié a bien fait son travail — mais
 * il l'a fait APRÈS, et un constat qui arrive après le basculement ne laisse
 * plus le choix du moment.
 *
 * Quatorze jours parce que c'est le délai qui sépare une action planifiée d'une
 * urgence : il faut relire la page officielle, y trouver ou non les dates du
 * cycle suivant, et parfois attendre que l'institution les publie.
 */
const CLOSING_SOON_HORIZON_DAYS = 14;

export interface ScholarshipCatalogValidationIssue {
  code: string;
  path: string;
  message: string;
}

export interface ScholarshipCatalogValidationReport {
  valid: boolean;
  catalogVersion: string;
  uniqueRecordCount: number;
  uniqueRecordDeficit: number;
  verifiedCounts: Record<ScholarshipStudyLevel, number>;
  backlogCounts: Record<ScholarshipStudyLevel, number>;
  volumeDeficits: Record<ScholarshipStudyLevel, number>;
  backlogDeficits: Record<ScholarshipStudyLevel, number>;
  issues: ScholarshipCatalogValidationIssue[];
  /**
   * Vrai quand le catalogue ne porte AUCUNE anomalie due au seul passage du
   * temps — donc quand il reste valide même en ignorant l'horloge.
   *
   * Deux verdicts au lieu d'un, parce que deux consommateurs ont deux besoins
   * qui ne se recouvrent pas. Le portail de fusion ne doit pas bloquer une PR
   * d'authentification parce qu'une bourse a clos hier ; le contrôle planifié,
   * lui, existe précisément pour crier ce jour-là. L'en-tête de
   * `catalog-freshness.yml` promettait déjà cette séparation ; elle n'était pas
   * implémentée, et `CATALOG_EXPIRED_CYCLE_CODES` n'était branché à rien.
   *
   * Rien n'est CACHÉ : les anomalies datées restent dans `issues`, elles ne
   * pèsent simplement pas sur ce verdict-ci.
   */
  validIgnoringClock: boolean;
  /**
   * Les cycles ouverts qui closent dans les {@link CLOSING_SOON_HORIZON_DAYS}
   * jours. Ce ne sont PAS des anomalies : ce sont des rendez-vous.
   */
  closingSoon: ScholarshipCatalogClosingSoon[];
  /**
   * Avertissements : ils ne pèsent sur AUCUN verdict. Aujourd'hui,
   * l'éligibilité non relue (`missing_structured_eligibility`, tant que
   * {@link STRUCTURED_ELIGIBILITY_GATE} vaut `warning`) et un tampon de
   * structuration de plus de 400 jours (`stale_structured_eligibility`).
   */
  warnings: ScholarshipCatalogValidationIssue[];
  /** Où en est la structuration de l'éligibilité, fiche par fiche. */
  eligibilityCoverage: ScholarshipEligibilityCoverage;
}

/**
 * La couverture de l'éligibilité structurée.
 *
 * - `missing` : aucun bloc `eligibility` (ou aucun critère) ;
 * - `drafts` : des critères, mais aucun tampon humain (`structuredAt` nul) —
 *   ils n'excluent personne ;
 * - `stamped` : relus et tamponnés ; parmi eux, `stale` a plus de 400 jours
 *   et n'exclut plus personne non plus.
 */
export interface ScholarshipEligibilityCoverage {
  records: number;
  missing: number;
  drafts: number;
  stamped: number;
  stale: number;
  criteria: number;
  byImpact: { hard: number; soft: number; informational: number };
  missingIds: string[];
  draftIds: string[];
}

export interface ScholarshipCatalogClosingSoon {
  path: string;
  scholarshipId: string;
  closesAt: string;
  daysLeft: number;
}

export interface ScholarshipCatalogValidationOptions {
  includeVolumeTargets?: boolean;
  now?: Date;
  /** Horizon de l'alerte avant clôture, en jours. Défaut : 14. */
  closingSoonHorizonDays?: number;
  /** Défaut : {@link STRUCTURED_ELIGIBILITY_GATE}. Exposé pour les tests. */
  structuredEligibilityGate?: 'warning' | 'error';
}

function isNonBlank(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isHttpsUrl(value: unknown): value is string {
  if (!isNonBlank(value)) return false;
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
}

function parseDate(value: unknown): Date | null {
  if (!isNonBlank(value)) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function push(
  issues: ScholarshipCatalogValidationIssue[],
  code: string,
  path: string,
  message: string,
) {
  issues.push({ code, path, message });
}

function requireBilingualList(
  issues: ScholarshipCatalogValidationIssue[],
  path: string,
  fr: string[],
  en: string[],
) {
  if (!Array.isArray(fr) || fr.length === 0 || fr.some((item) => !isNonBlank(item))) {
    push(issues, 'missing_fr_list', `${path}Fr`, 'A non-empty French list is required.');
  }
  if (!Array.isArray(en) || en.length === 0 || en.some((item) => !isNonBlank(item))) {
    push(issues, 'missing_en_list', `${path}En`, 'A non-empty English list is required.');
  }
  if (Array.isArray(fr) && Array.isArray(en) && fr.length !== en.length) {
    push(
      issues,
      'bilingual_list_length_mismatch',
      path,
      'French and English lists must describe the same number of items.',
    );
  }
}

function validateRecord(
  record: VerifiedScholarshipCatalogRecord,
  index: number,
  issues: ScholarshipCatalogValidationIssue[],
  now: Date,
  closingSoon: ScholarshipCatalogClosingSoon[],
  horizonDays: number,
) {
  const root = `records[${index}]`;
  const scholarship = record.scholarship;
  const requiredText: Array<[string, unknown]> = [
    ['catalogId', record.catalogId],
    ['scholarship.id', scholarship.id],
    ['scholarship.nameFr', scholarship.nameFr],
    ['scholarship.nameEn', scholarship.nameEn],
    ['scholarship.countryNameFr', scholarship.countryNameFr],
    ['scholarship.countryNameEn', scholarship.countryNameEn],
    ['scholarship.levelEligibleFr', scholarship.levelEligibleFr],
    ['scholarship.levelEligibleEn', scholarship.levelEligibleEn],
    ['scholarship.typeOfFundingFr', scholarship.typeOfFundingFr],
    ['scholarship.typeOfFundingEn', scholarship.typeOfFundingEn],
    ['scholarship.deadlineLabelFr', scholarship.deadlineLabelFr],
    ['scholarship.deadlineLabelEn', scholarship.deadlineLabelEn],
    ['scholarship.descriptionFr', scholarship.descriptionFr],
    ['scholarship.descriptionEn', scholarship.descriptionEn],
    ['verifiedBy', record.verifiedBy],
  ];
  for (const [path, value] of requiredText) {
    if (!isNonBlank(value)) {
      push(issues, 'missing_text', `${root}.${path}`, 'A non-empty value is required.');
    }
  }

  if (!/^[a-z0-9]+(?:[_-][a-z0-9]+)*$/.test(scholarship.id)) {
    push(issues, 'invalid_id', `${root}.scholarship.id`, 'Use a stable lowercase slug-like id.');
  }
  if (!/^[a-z]{3}$/.test(scholarship.countryId)) {
    push(
      issues,
      'invalid_country_id',
      `${root}.scholarship.countryId`,
      'Use the canonical three-letter lowercase country id.',
    );
  }

  if (!Array.isArray(record.levels) || record.levels.length === 0) {
    push(issues, 'missing_levels', `${root}.levels`, 'At least one structured study level is required.');
  } else if (record.levels.some((level) => !SCHOLARSHIP_STUDY_LEVELS.includes(level))) {
    push(issues, 'invalid_level', `${root}.levels`, 'An unsupported study level was provided.');
  } else {
    // La reprise SQL de `eligibleLevels` (migration scholarship_match_v1) et
    // `scholarshipLevels` lisent les niveaux dans les TAGS : ils doivent dire
    // exactement `levels`, sinon une ligne servirait d'autres niveaux que ceux
    // que le dépôt affirme.
    const tagged = new Set(
      (scholarship.tags ?? [])
        .map((tag) => tag.trim().toLowerCase())
        .filter((tag) => LEVEL_TAGS.has(tag)),
    );
    const declared = new Set<string>(record.levels);
    if (
      tagged.size !== declared.size ||
      [...declared].some((level) => !tagged.has(level))
    ) {
      push(
        issues,
        'level_tags_mismatch',
        `${root}.scholarship.tags`,
        `Level tags (${[...tagged].sort().join(', ') || '∅'}) must equal levels (${[...declared].sort().join(', ')}).`,
      );
    }
  }

  requireBilingualList(
    issues,
    `${root}.scholarship.advantages`,
    scholarship.advantagesFr,
    scholarship.advantagesEn,
  );
  requireBilingualList(
    issues,
    `${root}.scholarship.eligibility`,
    scholarship.eligibilityFr,
    scholarship.eligibilityEn,
  );
  requireBilingualList(
    issues,
    `${root}.scholarship.keyRequirements`,
    scholarship.keyRequirementsFr,
    scholarship.keyRequirementsEn,
  );

  for (const [path, url] of [
    ['scholarship.applicationUrl', scholarship.applicationUrl],
    ['scholarship.sourceUrl', scholarship.sourceUrl],
    ['cycle.sourceUrl', record.cycle.sourceUrl],
  ] as const) {
    if (!isHttpsUrl(url)) {
      push(issues, 'invalid_https_url', `${root}.${path}`, 'An HTTPS URL is required.');
    }
  }

  if (!Array.isArray(record.applicationSteps) || record.applicationSteps.length === 0) {
    push(
      issues,
      'missing_application_steps',
      `${root}.applicationSteps`,
      'At least one complete application step is required.',
    );
  } else {
    const seenStepNumbers = new Set<number>();
    for (const [stepIndex, step] of record.applicationSteps.entries()) {
      const stepPath = `${root}.applicationSteps[${stepIndex}]`;
      if (!Number.isInteger(step.stepNumber) || step.stepNumber < 1) {
        push(issues, 'invalid_step_number', `${stepPath}.stepNumber`, 'Step numbers start at 1.');
      } else if (seenStepNumbers.has(step.stepNumber)) {
        push(issues, 'duplicate_step_number', `${stepPath}.stepNumber`, 'Step numbers must be unique.');
      }
      seenStepNumbers.add(step.stepNumber);
      for (const [field, value] of [
        ['titleFr', step.titleFr],
        ['titleEn', step.titleEn],
        ['descriptionFr', step.descriptionFr],
        ['descriptionEn', step.descriptionEn],
      ]) {
        if (!isNonBlank(value)) {
          push(issues, 'missing_step_translation', `${stepPath}.${field}`, 'FR and EN step copy is required.');
        }
      }
    }
  }

  const sourceKinds = new Set<string>();
  for (const [sourceIndex, source] of record.officialSources.entries()) {
    const sourcePath = `${root}.officialSources[${sourceIndex}]`;
    sourceKinds.add(source.kind);
    if (source.isOfficial !== true) {
      push(issues, 'unofficial_source', `${sourcePath}.isOfficial`, 'Only declared official sources are importable.');
    }
    if (!isHttpsUrl(source.url)) {
      push(issues, 'invalid_https_url', `${sourcePath}.url`, 'Official sources must use HTTPS.');
    }
    if (!isNonBlank(source.label)) {
      push(issues, 'missing_source_label', `${sourcePath}.label`, 'Describe the official authority/page.');
    }
    const checkedAt = parseDate(source.checkedAt);
    if (!checkedAt) {
      push(issues, 'invalid_source_check_date', `${sourcePath}.checkedAt`, 'A valid check timestamp is required.');
    } else {
      const ageDays = Math.floor((now.getTime() - checkedAt.getTime()) / DAY_MS);
      if (ageDays < 0 || ageDays > MAX_VERIFICATION_AGE_DAYS) {
        push(
          issues,
          'stale_source_check',
          `${sourcePath}.checkedAt`,
          `Official sources must have been checked within ${MAX_VERIFICATION_AGE_DAYS} days.`,
        );
      }
    }
  }
  for (const kind of REQUIRED_OFFICIAL_SOURCE_KINDS) {
    if (!sourceKinds.has(kind)) {
      push(
        issues,
        'missing_official_source_kind',
        `${root}.officialSources`,
        `Missing official source evidence for "${kind}".`,
      );
    }
  }

  const sourceUrlsByKind = new Map(
    record.officialSources.map((source) => [source.kind, source.url]),
  );
  for (const [kind, payloadPath, payloadUrl] of [
    ['overview', 'scholarship.sourceUrl', scholarship.sourceUrl],
    ['application', 'scholarship.applicationUrl', scholarship.applicationUrl],
    ['cycle', 'cycle.sourceUrl', record.cycle.sourceUrl],
  ] as const) {
    const evidenceUrl = sourceUrlsByKind.get(kind);
    if (evidenceUrl && evidenceUrl !== payloadUrl) {
      push(
        issues,
        'source_payload_url_mismatch',
        `${root}.${payloadPath}`,
        `The payload URL must exactly match the declared official ${kind} source.`,
      );
    }
  }

  const verifiedAt = parseDate(record.verifiedAt);
  if (!verifiedAt) {
    push(issues, 'invalid_verification_date', `${root}.verifiedAt`, 'A valid verification timestamp is required.');
  } else {
    const ageDays = Math.floor((now.getTime() - verifiedAt.getTime()) / DAY_MS);
    if (ageDays < 0 || ageDays > MAX_VERIFICATION_AGE_DAYS) {
      push(
        issues,
        'stale_verification',
        `${root}.verifiedAt`,
        `The record must have been verified within ${MAX_VERIFICATION_AGE_DAYS} days.`,
      );
    }
  }

  const cycle = record.cycle;
  if (!/^\d{4}-\d{4}$/.test(cycle.academicYear)) {
    push(issues, 'invalid_academic_year', `${root}.cycle.academicYear`, 'Use YYYY-YYYY.');
  }
  const isConfirmed = cycle.dateConfidence === 'confirmed';
  const startRaw = isConfirmed ? cycle.opensAt : cycle.estimatedOpenAt;
  const closeRaw = isConfirmed ? cycle.closesAt : cycle.estimatedCloseAt;
  const start = parseDate(startRaw);
  const close = parseDate(closeRaw);
  // Une date de clôture confirmée SANS date d'ouverture est le cas courant, pas
  // une anomalie : beaucoup d'institutions publient « date limite : 31 août »
  // sans jamais annoncer d'ouverture (University of Pretoria, par exemple).
  // Exiger les deux forçait un choix entre inventer une ouverture et déclasser
  // toute la fiche en « estimée » — or c'est la clôture qui est le fait
  // actionnable pour l'étudiant. On exige donc la clôture, et l'ouverture reste
  // facultative. Un cycle estimé garde ses deux bornes : une fenêtre sans début
  // n'a pas de sens.
  const missingDates = isConfirmed ? !close : !start || !close;
  if (missingDates) {
    push(
      issues,
      'missing_cycle_dates',
      `${root}.cycle`,
      isConfirmed
        ? 'Confirmed cycles require closesAt (opensAt is optional).'
        : 'Estimated cycles require estimatedOpenAt and estimatedCloseAt.',
    );
  } else if (start && close && close <= start) {
    push(issues, 'invalid_cycle_order', `${root}.cycle`, 'The closing date must be after the opening date.');
  }
  if (cycle.status === 'open' && cycle.dateConfidence !== 'confirmed') {
    push(issues, 'open_cycle_not_confirmed', `${root}.cycle`, 'An open cycle must use confirmed dates.');
  }
  // Une campagne annoncée « ouverte » dont la clôture est passée est un mensonge
  // à date. Deux fiches en circulaient au 10/08/2026 : Rhodes Afrique australe
  // (fermée le 3 août) et DAAD Helmut-Schmidt (fermée le 31 juillet), toutes
  // deux avec un `deadlineLabel` commençant par « Ouvert ». Le catalogue restait
  // `valid: true`, et seule une relecture humaine les a attrapées.
  //
  // La pastille de cycle côté Flutter dégrade déjà correctement (elle affiche
  // « Deadline closed » si la clôture est passée), mais le `deadlineLabel` est
  // une chaîne figée : lui, il continue d'affirmer « Ouvert ». C'est ce texte
  // que cette règle protège.
  //
  // Elle est volontairement adossée à l'horloge : ce test DOIT casser quand une
  // campagne se termine. Le correctif est d'une ligne (`status: 'closed'`), et
  // c'est le prix d'un catalogue qui ne périme pas en silence.
  // Le RENDEZ-VOUS, distinct de l'anomalie. Un cycle qui clôt bientôt n'a rien
  // de fautif ; il devient fautif tout seul, le jour venu. Le signaler avant
  // laisse le choix du moment, ce qu'un constat après le basculement ne laisse
  // plus.
  if (cycle.status === 'open' && close && close > now) {
    const daysLeft = Math.ceil((close.getTime() - now.getTime()) / DAY_MS);
    if (daysLeft <= horizonDays) {
      closingSoon.push({
        path: `${root}.cycle`,
        scholarshipId: record.scholarship.id,
        closesAt: close.toISOString(),
        daysLeft,
      });
    }
  }
  if (cycle.status === 'open' && close && close <= now) {
    push(
      issues,
      'open_cycle_already_closed',
      `${root}.cycle`,
      `An open cycle cannot have a closing date in the past (${close.toISOString().slice(0, 10)}). ` +
        'Set status to "closed" and refresh the deadline label.',
    );
  }
}

/** Les lignes citables d'une fiche, en paires FR/EN de même index. */
function quotablePairs(record: VerifiedScholarshipCatalogRecord): Set<string> {
  const pairs = new Set<string>();
  const scholarship = record.scholarship;
  for (const [fr, en] of [
    [scholarship.eligibilityFr, scholarship.eligibilityEn],
    [scholarship.keyRequirementsFr, scholarship.keyRequirementsEn],
  ] as const) {
    (fr ?? []).forEach((line, index) => pairs.add(`${line}\u0000${en?.[index] ?? ''}`));
  }
  return pairs;
}

/**
 * La forme de l'éligibilité structurée (erreurs) et sa relecture
 * (avertissement ou erreur selon {@link STRUCTURED_ELIGIBILITY_GATE}).
 */
function validateEligibility(
  record: VerifiedScholarshipCatalogRecord,
  index: number,
  issues: ScholarshipCatalogValidationIssue[],
  warnings: ScholarshipCatalogValidationIssue[],
  now: Date,
  gate: 'warning' | 'error',
) {
  const root = `records[${index}].eligibility`;
  const eligibility = record.eligibility;
  const gateList = gate === 'error' ? issues : warnings;

  if (!eligibility) {
    push(
      gateList,
      'missing_structured_eligibility',
      root,
      'No structured eligibility: the matching engine cannot analyse this record.',
    );
    return;
  }

  if (!(SCHOLARSHIP_FIELDS_SCOPES as readonly string[]).includes(eligibility.fieldsScope)) {
    push(issues, 'invalid_fields_scope', `${root}.fieldsScope`, "Use 'unknown', 'all' or 'listed'.");
  }

  // La forme : le validateur du moteur, sans repli. Un critère invalide serait
  // ignoré en production ; ici il refuse la fiche.
  for (const issue of validateEligibilityCriteria(eligibility.criteria)) {
    push(
      issues,
      'invalid_eligibility_criterion',
      `${root}.criteria${issue.path}`,
      `${issue.code}: ${issue.message}`,
    );
  }

  // L'honnêteté : chaque critère cite le texte de SA fiche, mot pour mot, et
  // la source officielle qu'elle déclare. Une condition sans citation
  // vérifiable serait une condition inventée.
  const pairs = quotablePairs(record);
  const officialUrls = new Set(record.officialSources.map((source) => source.url));
  const levels = new Set<string>(record.levels);
  (Array.isArray(eligibility.criteria) ? eligibility.criteria : []).forEach((criterion, at) => {
    const path = `${root}.criteria[${at}]`;
    if (!pairs.has(`${criterion.officialTextFr}\u0000${criterion.officialTextEn}`)) {
      push(
        issues,
        'criterion_quote_not_in_record',
        path,
        'officialTextFr/En must quote the same eligibility (or requirement) line of this record, verbatim.',
      );
    }
    if (!officialUrls.has(criterion.sourceUrl)) {
      push(
        issues,
        'criterion_source_not_official',
        `${path}.sourceUrl`,
        "sourceUrl must be one of this record's declared official sources.",
      );
    }
    if (
      (criterion.type === 'age' || criterion.type === 'work_experience') &&
      criterion.level !== undefined &&
      !levels.has(criterion.level)
    ) {
      push(
        issues,
        'criterion_level_not_in_record',
        `${path}.level`,
        `Level ${criterion.level} is not one of this record's levels.`,
      );
    }
  });

  const criteriaCount = Array.isArray(eligibility.criteria) ? eligibility.criteria.length : 0;
  if (eligibility.structuredAt === null) {
    if (eligibility.structuredBy !== DRAFT_STRUCTURED_BY) {
      push(
        issues,
        'invalid_structured_by',
        `${root}.structuredBy`,
        `An unstamped block is a draft: structuredBy must be "${DRAFT_STRUCTURED_BY}".`,
      );
    }
    push(
      gateList,
      'missing_structured_eligibility',
      root,
      criteriaCount === 0
        ? 'No structured criteria: the matching engine cannot analyse this record.'
        : `Draft criteria (${criteriaCount}) awaiting human review: they exclude no one until structuredAt is set.`,
    );
    return;
  }

  const stampedAt = parseDate(eligibility.structuredAt);
  if (!stampedAt) {
    push(issues, 'invalid_structured_at', `${root}.structuredAt`, 'A valid ISO timestamp (or null for a draft) is required.');
  } else if (stampedAt.getTime() > now.getTime()) {
    push(issues, 'invalid_structured_at', `${root}.structuredAt`, 'A review cannot be stamped in the future.');
  } else if (now.getTime() - stampedAt.getTime() >= STRUCTURED_FRESHNESS_DAYS * DAY_MS) {
    push(
      warnings,
      'stale_structured_eligibility',
      `${root}.structuredAt`,
      `Reviewed more than ${STRUCTURED_FRESHNESS_DAYS} days ago: hard criteria no longer exclude anyone.`,
    );
  }
  if (!isNonBlank(eligibility.structuredBy) || eligibility.structuredBy === DRAFT_STRUCTURED_BY) {
    push(issues, 'invalid_structured_by', `${root}.structuredBy`, 'A stamped block names its human reviewer.');
  }
  if (criteriaCount === 0) {
    push(
      gateList,
      'missing_structured_eligibility',
      `${root}.criteria`,
      'A stamped block without criteria analyses nothing beyond the level.',
    );
  }
}

/** Le décompte de la couverture, sur le catalogue tel qu'il est. */
export function eligibilityCoverage(
  catalog: VersionedScholarshipCatalog,
  now: Date = new Date(),
): ScholarshipEligibilityCoverage {
  const coverage: ScholarshipEligibilityCoverage = {
    records: catalog.records.length,
    missing: 0,
    drafts: 0,
    stamped: 0,
    stale: 0,
    criteria: 0,
    byImpact: { hard: 0, soft: 0, informational: 0 },
    missingIds: [],
    draftIds: [],
  };
  for (const record of catalog.records) {
    const id = record.scholarship.id;
    const criteria = parseEligibilityCriteria(record.eligibility?.criteria).criteria;
    coverage.criteria += criteria.length;
    for (const criterion of criteria) coverage.byImpact[criterion.impact] += 1;
    if (!record.eligibility || criteria.length === 0) {
      coverage.missing += 1;
      coverage.missingIds.push(id);
      continue;
    }
    const stampedAt = parseDate(record.eligibility.structuredAt);
    if (!stampedAt) {
      coverage.drafts += 1;
      coverage.draftIds.push(id);
      continue;
    }
    coverage.stamped += 1;
    if (now.getTime() - stampedAt.getTime() >= STRUCTURED_FRESHNESS_DAYS * DAY_MS) {
      coverage.stale += 1;
    }
  }
  return coverage;
}

export function validateScholarshipCatalog(
  catalog: VersionedScholarshipCatalog,
  options: ScholarshipCatalogValidationOptions = {},
): ScholarshipCatalogValidationReport {
  const issues: ScholarshipCatalogValidationIssue[] = [];
  const now = options.now ?? new Date();
  const includeVolumeTargets = options.includeVolumeTargets ?? true;
  const horizonDays =
    options.closingSoonHorizonDays ?? CLOSING_SOON_HORIZON_DAYS;
  const closingSoon: ScholarshipCatalogClosingSoon[] = [];
  const warnings: ScholarshipCatalogValidationIssue[] = [];
  const gate = options.structuredEligibilityGate ?? STRUCTURED_ELIGIBILITY_GATE;
  const verifiedCounts = { secondary: 0, bachelor: 0, master: 0, doctorate: 0 };
  const backlogCounts = { secondary: 0, bachelor: 0, master: 0, doctorate: 0 };

  if (catalog.schemaVersion !== 1) {
    push(issues, 'unsupported_schema_version', 'schemaVersion', 'Only catalog schema version 1 is supported.');
  }
  if (!/^\d+\.\d+\.\d+$/.test(catalog.catalogVersion)) {
    push(issues, 'invalid_catalog_version', 'catalogVersion', 'Use a semantic version such as 1.0.0.');
  }
  if (!Number.isInteger(catalog.volumeTargets.uniqueRecords) || catalog.volumeTargets.uniqueRecords < 1) {
    push(
      issues,
      'invalid_unique_record_target',
      'volumeTargets.uniqueRecords',
      'The unique-record target must be a positive integer.',
    );
  }

  const recordIds = new Set<string>();
  for (const [index, record] of catalog.records.entries()) {
    if (recordIds.has(record.catalogId) || recordIds.has(record.scholarship.id)) {
      push(issues, 'duplicate_record_id', `records[${index}]`, 'Catalog and scholarship ids must be unique.');
    }
    recordIds.add(record.catalogId);
    recordIds.add(record.scholarship.id);
    for (const level of new Set(record.levels)) verifiedCounts[level] += 1;
    validateRecord(record, index, issues, now, closingSoon, horizonDays);
    validateEligibility(record, index, issues, warnings, now, gate);
  }

  const backlogIds = new Set<string>();
  for (const [index, item] of catalog.backlog.entries()) {
    if (!isNonBlank(item.legacyId) || backlogIds.has(item.legacyId)) {
      push(issues, 'invalid_backlog_id', `backlog[${index}].legacyId`, 'Backlog ids must be non-empty and unique.');
    }
    backlogIds.add(item.legacyId);
    if (!item.reasons.length) {
      push(issues, 'missing_backlog_reason', `backlog[${index}].reasons`, 'At least one visible deficit is required.');
    }
    for (const level of new Set(item.intendedLevels)) backlogCounts[level] += 1;
  }

  const volumeDeficits = {
    secondary: Math.max(0, catalog.volumeTargets.secondary - verifiedCounts.secondary),
    bachelor: Math.max(0, catalog.volumeTargets.bachelor - verifiedCounts.bachelor),
    master: Math.max(0, catalog.volumeTargets.master - verifiedCounts.master),
    doctorate: Math.max(0, (catalog.volumeTargets.doctorate ?? 0) - verifiedCounts.doctorate),
  };
  const uniqueRecordCount = catalog.records.length;
  const uniqueRecordDeficit = Math.max(
    0,
    catalog.volumeTargets.uniqueRecords - uniqueRecordCount,
  );
  const backlogDeficits = {
    secondary: Math.max(0, catalog.volumeTargets.secondary - backlogCounts.secondary),
    bachelor: Math.max(0, catalog.volumeTargets.bachelor - backlogCounts.bachelor),
    master: Math.max(0, catalog.volumeTargets.master - backlogCounts.master),
    doctorate: Math.max(0, (catalog.volumeTargets.doctorate ?? 0) - backlogCounts.doctorate),
  };
  if (includeVolumeTargets) {
    if (uniqueRecordDeficit > 0) {
      push(
        issues,
        'unique_record_target_not_met',
        'volumeTargets.uniqueRecords',
        `Missing ${uniqueRecordDeficit} unique scholarship record(s).`,
      );
    }
    for (const level of SCHOLARSHIP_STUDY_LEVELS) {
      if (volumeDeficits[level] > 0) {
        push(
          issues,
          'volume_target_not_met',
          `volumeTargets.${level}`,
          `Missing ${volumeDeficits[level]} verified ${level} scholarship record(s).`,
        );
      }
    }
  }

  // Deux verdicts, et le second n'est pas un assouplissement du premier : il
  // répond à une autre question. « Ce catalogue est-il parfait ? » n'est pas
  // « ce catalogue doit-il bloquer une PR d'authentification ? ».
  // LES DEUX familles datées, pas seulement les cycles clos. `stale_verification`
  // est aussi purement horloge : aucun commit ne provoque le fait que des pages
  // officielles n'ont pas été relues depuis trente jours. Le `checkedAt` du
  // catalogue vaut 2026-08-10 et le plafond est de 30 jours — donc au
  // 09/09/2026 ce code aurait rougi le portail de fusion pour CHAQUE fiche,
  // exactement comme la clôture de McCall MacBain l'a fait le 20/08. Une seconde
  // mine, à trois semaines de la première.
  //
  // C'est mon propre test qui l'a trouvé : ma première définition ne tolérait
  // que les cycles clos, et la contre-épreuve à horizon 2028 est tombée. Le
  // découpage en deux constantes existait pour nommer deux MÉTIERS de correction
  // (relire des pages / éditer un littéral), pas pour dire lequel bloque une PR.
  const clockOnlyCodes = new Set<string>([
    ...CATALOG_EXPIRED_CYCLE_CODES,
    ...CATALOG_STALENESS_CODES,
  ]);
  return {
    valid: issues.length === 0,
    validIgnoringClock: issues.every((issue) => clockOnlyCodes.has(issue.code))
      ? true
      : issues.length === 0,
    closingSoon: closingSoon.sort((a, b) => a.daysLeft - b.daysLeft),
    warnings,
    eligibilityCoverage: eligibilityCoverage(catalog, now),
    catalogVersion: catalog.catalogVersion,
    uniqueRecordCount,
    uniqueRecordDeficit,
    verifiedCounts,
    backlogCounts,
    volumeDeficits,
    backlogDeficits,
    issues,
  };
}

/** Ce que renvoie [buildCatalogDiagnosis] quand il n'y a rien à signaler. */
export const CATALOG_UP_TO_DATE = 'catalogue à jour';

/**
 * Les anomalies dues au seul passage du temps, et le métier qui les corrige.
 *
 * La distinction n'est pas cosmétique : rouvrir 102 pages officielles est un
 * travail humain qui se planifie, tandis que passer un cycle en `closed` est une
 * ligne de littéral. Les confondre dans un seul message a produit exactement ce
 * qu'on voulait éviter — un échec qui ne dit pas quoi faire.
 */
export const CATALOG_STALENESS_CODES = [
  'stale_verification',
  'stale_source_check',
] as const;

export const CATALOG_EXPIRED_CYCLE_CODES = [
  'open_cycle_already_closed',
] as const;

/**
 * Décrit les anomalies d'un rapport en nommant la fiche concernée.
 *
 * Sans cette fonction, l'échec du test à horloge réelle se présentait en
 * `expect(false).toBe(true)` : ni la fiche, ni la règle, ni le geste correctif.
 * Le diagnostic ne portait d'ailleurs que `stale_verification`, donc une
 * campagne close passée en cours de route laissait le message affirmer
 * « catalogue à jour » pendant que le catalogue était refusé.
 */
export function buildCatalogDiagnosis(
  report: ScholarshipCatalogValidationReport,
  options: {
    catalog?: VersionedScholarshipCatalog;
    codes?: readonly string[];
  } = {},
): string {
  const matching = options.codes
    ? report.issues.filter((issue) => options.codes!.includes(issue.code))
    : report.issues;
  if (matching.length === 0) return CATALOG_UP_TO_DATE;

  const nameRecord = (path: string): string => {
    const index = /^records\[(\d+)\]/.exec(path)?.[1];
    if (index == null) return path;
    const record = options.catalog?.records[Number(index)];
    return record ? `${record.scholarship.id} (${path})` : path;
  };

  return matching
    .map((issue) => `${issue.code} — ${nameRecord(issue.path)} : ${issue.message}`)
    .join('\n');
}
