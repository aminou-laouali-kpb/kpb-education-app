/**
 * Réalignement des lignes DÉJÀ présentes en base sur le catalogue du dépôt.
 *
 * ## Le défaut que ce fichier ferme
 *
 * `catalog:import` est idempotent par identifiant : il crée les lignes
 * manquantes et saute celles qui existent (`createIfAbsent`). Cette propriété
 * est délibérée — elle protège les lignes éditées dans l'admin — mais elle a une
 * conséquence que rien ne rattrapait : **une correction apportée à une fiche du
 * dépôt n'atteint jamais la production une fois la ligne créée.**
 *
 * Mesuré en production le 31/08/2026, après `catalog:switch --apply` (30 fiches
 * publiées, catalogue 1.3.0) : `york_pise_2027_forecast` et
 * `jj_wbgsp_2027_forecast` servaient `dateConfidence: "estimated"` alors que le
 * dépôt dit `confirmed` depuis la re-vérification du 24/08. Le sens de l'écart
 * était conservateur (« À venir, généralement aux mois de … » au lieu d'une date
 * ferme), donc aucun étudiant n'a vu de fausse échéance — mais l'écart grandit à
 * chaque version du catalogue, et rien ne le disait : `skippedExisting: 34` se
 * lit « rien à faire » alors qu'il veut dire « 34 fiches potentiellement
 * périmées ».
 *
 * La mitigation qui existait déjà ne couvre que le STATUT de cycle
 * (`servedCycleStatus`, dérivé de l'horloge et non du littéral en base). Elle ne
 * dit rien de `dateConfidence`, du texte, des avantages, des étapes.
 *
 * ## Qui fait foi, et sur quoi
 *
 * Le dépôt fait foi sur le CONTENU. C'est le sens de la demande : une correction
 * relue en PR doit atteindre la production. Une modification faite dans l'admin
 * sur un champ éditorial sera donc écrasée — c'est pour cela que le `--dry-run`
 * liste chaque champ divergent AVANT d'écrire, et qu'il n'y a pas de mode par
 * défaut.
 *
 * Trois exceptions, où la base fait foi. Chacune ferme une régression concrète :
 *
 * 1. **La modération.** `isActive` et `moderationStatus` ne sont JAMAIS écrits.
 *    Réconcilier n'est pas publier. Onze fiches de démonstration sont devenues
 *    publiques sur ce projet parce qu'un chemin d'écriture posait ces deux
 *    champs sans le vouloir ; celui-ci ne les nomme même pas.
 *
 * 2. **Un cycle activé depuis l'admin** (`activatedAt != null`). `activate`
 *    écrit `status: 'open'`, `dateConfidence: 'confirmed'`, `opensAt`,
 *    `closesAt`, et répercute `deadlineAt`/`sourceUrl`/`lastVerifiedAt` sur la
 *    fiche. Le dépôt, lui, peut encore dire `forecast`/`estimated`. Réaligner
 *    aveuglément rétrograderait une date ferme confirmée par un humain en
 *    « À venir » — exactement le défaut d'aujourd'hui, dans l'autre sens. Un
 *    cycle activé est donc entièrement propriété de la base.
 *
 * 3. **Une vérification RÉVOQUÉE dans l'admin.** `setVerification(..., false)`
 *    met `lastVerifiedAt`, `verifiedById` et `verifiedByName` à `null` pour
 *    signifier « à confirmer » — et ne touche NI `isActive` NI
 *    `moderationStatus`. La fiche reste donc active et approuvée : elle n'est
 *    masquée que par la clause `lastVerifiedAt: { not: null }` de
 *    `publicScholarshipWhere`. Réécrire le tampon du catalogue par-dessus la
 *    republierait — sans nouvelle relecture, et sans qu'aucune assertion ne le
 *    voie, puisque le filet existant cherche l'inverse (une fiche active SANS
 *    tampon). Un `lastVerifiedAt` nul en base est donc un signal, pas un vide.
 *
 * 4. **Un tampon de vérification plus récent que celui du dépôt.** La file de
 *    vérification de l'admin horodate `lastVerifiedAt`, nomme le relecteur et
 *    enregistre le `sourceUrl` qu'il a réellement consulté (`verificationData`).
 *    Un contrôle humain du mois dernier ne doit pas être remplacé par un tampon
 *    de catalogue plus ancien — ni, surtout, garder le nom du relecteur en
 *    pointant vers une source qu'il n'a pas vue. Les quatre champs vont donc
 *    ensemble. La règle est monotone : on n'avance jamais dans le passé.
 *
 * 5. **Une éligibilité structurée relue en base** (chantier D, catalogue
 *    1.5.0). `eligibleLevels`, `fieldsScope`, `eligibilityCriteria`,
 *    `eligibilityStructuredAt` et `eligibilityStructuredBy` forment un bloc :
 *    l'admin les écrit ensemble et tamponne. Un tampon en base plus récent que
 *    celui du dépôt n'est JAMAIS écrasé, et un brouillon du dépôt (tampon nul)
 *    ne remplace jamais des critères tamponnés : seul un tampon de relecture du
 *    dépôt au moins aussi récent les remplace. Sans tampon en base (brouillon
 *    ou reprise des tags), le dépôt fait foi, comme pour le texte.
 *
 * ## Les étapes de candidature ne sont jamais supprimées
 *
 * `ScholarshipWorkspaceStep.sourceStepId` pointe vers `ScholarshipApplicationStep`
 * en `onDelete: SetNull`. Un « delete + recreate » des étapes détacherait donc
 * silencieusement la progression des étudiants de sa source. On met à jour par
 * `stepNumber`, on crée ce qui manque, et une étape présente en base mais absente
 * du catalogue est SIGNALÉE, jamais effacée.
 */
import { buildScholarshipCreateData } from './scholarship-catalog.create-data';
import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';

/**
 * Champs de `buildScholarshipCreateData` que la réconciliation n'écrit JAMAIS
 * sur une ligne existante.
 *
 * Tout le reste est réaligné. La liste est explicite et non déduite : un futur
 * champ ajouté à la création doit être classé d'un côté ou de l'autre, et le
 * spec associé échoue tant qu'il ne l'est pas.
 */
export const NEVER_RECONCILED_FIELDS = [
  'id',
  'isActive',
  'moderationStatus',
  'applicationSteps',
  'cycles',
] as const;

/**
 * Champs de la FICHE que `activate` (scholarship-lifecycle.service.ts) écrit en
 * même temps qu'il active le cycle. Quand le cycle correspondant porte un
 * `activatedAt`, ces champs appartiennent à la base et sont signalés sans être
 * réécrits.
 *
 * `isActive` et `moderationStatus` sont écrits par `activate` eux aussi, mais ils
 * n'ont pas leur place ici : ils ne sont réconciliés dans AUCUN cas.
 */
export const CYCLE_ACTIVATION_OWNED_FIELDS = [
  'deadlineAt',
  'sourceUrl',
  'lastVerifiedAt',
] as const;

/**
 * La provenance de vérification, qui n'avance jamais dans le passé et se déplace
 * d'un bloc.
 *
 * `sourceUrl` en fait partie parce que `AdminCatalogService.verificationData`
 * l'écrit AVEC le tampon : c'est la source que le relecteur a réellement
 * consultée. Garder le nom du relecteur en réécrivant sa source par celle,
 * plus ancienne, du dépôt produirait une ligne qui attribue une vérification
 * humaine à un lien que cette personne n'a pas ouvert.
 */
export const VERIFICATION_PROVENANCE_FIELDS = [
  'lastVerifiedAt',
  'verifiedById',
  'verifiedByName',
  'sourceUrl',
] as const;

/**
 * L'éligibilité structurée, qui se déplace d'un bloc et dont le tampon
 * (`eligibilityStructuredAt`) n'avance jamais dans le passé. Voir la règle 5
 * de l'en-tête.
 *
 * `eligibleLevels` en fait partie : un éditeur qui corrige les niveaux dans
 * l'admin tamponne la même relecture, et le moteur n'exclut sur le niveau que
 * sous ce tampon.
 */
export const ELIGIBILITY_PROVENANCE_FIELDS = [
  'eligibleLevels',
  'fieldsScope',
  'eligibilityCriteria',
  'eligibilityStructuredAt',
  'eligibilityStructuredBy',
] as const;

export type DriftScope = 'scholarship' | 'cycle' | 'step';

export interface CatalogDrift {
  scholarshipId: string;
  scope: DriftScope;
  /** `dateConfidence`, `descriptionFr`, `steps[3].titleFr`, … */
  field: string;
  inDatabase: string;
  inCatalog: string;
  /** `false` = divergence signalée mais délibérément NON réalignée. */
  reconciled: boolean;
  /** Pourquoi elle ne l'est pas. Absent quand elle l'est. */
  keptReason?: string;
}

export interface ReconcilableCycleRow {
  academicYear: string;
  status: string;
  dateConfidence: string;
  estimatedOpenAt: Date | null;
  estimatedCloseAt: Date | null;
  opensAt: Date | null;
  closesAt: Date | null;
  sourceUrl: string | null;
  verifiedAt: Date | null;
  activatedAt: Date | null;
}

export interface ReconcilableStepRow {
  stepNumber: number;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  estimatedDurationDays: number | null;
}

export type ReconcilableScholarshipRow = Record<string, unknown> & {
  id: string;
  cycles: ReconcilableCycleRow[];
  applicationSteps: ReconcilableStepRow[];
};

export interface ReconciliationPlan {
  scholarshipId: string;
  /** `false` : la ligne n'existe pas — c'est le travail d'`import`, pas le nôtre. */
  presentInDatabase: boolean;
  drifts: CatalogDrift[];
  /** Champs scalaires à écrire. Vide = rien à faire sur la fiche. */
  scholarshipUpdate: Record<string, unknown>;
  cycle: {
    academicYear: string;
    action: 'none' | 'create' | 'update';
    data: Record<string, unknown>;
  };
  steps: {
    create: Array<Record<string, unknown>>;
    update: Array<{ stepNumber: number; data: Record<string, unknown> }>;
    /** Présentes en base, absentes du catalogue. Signalées, jamais supprimées. */
    extraInDatabase: number[];
  };
}

/** Une réconciliation qui n'écrirait rien. */
export function planIsEmpty(plan: ReconciliationPlan): boolean {
  return (
    Object.keys(plan.scholarshipUpdate).length === 0 &&
    plan.cycle.action === 'none' &&
    plan.steps.create.length === 0 &&
    plan.steps.update.length === 0
  );
}

function toComparable(value: unknown): unknown {
  if (value === undefined) return null;
  if (value instanceof Date) return value.getTime();
  if (Array.isArray(value)) return value.map(toComparable);
  return value;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    !(value instanceof Date)
  );
}

/**
 * `undefined` et `null` sont le même vide, une `Date` et son ISO le même
 * instant, et deux tableaux sont égaux à l'ordre près de rien du tout : l'ordre
 * des avantages ou des prérequis est éditorial, donc significatif.
 *
 * Deux objets JSON (les critères d'éligibilité) sont égaux clé par clé, à
 * l'ordre des CLÉS près : PostgreSQL range les clés d'un `jsonb` à sa façon, et
 * une clé absente vaut une clé `undefined`. Sans cela, chaque passage verrait
 * les 36 fiches « divergentes » et les réécrirait.
 */
export function sameValue(a: unknown, b: unknown): boolean {
  const left = toComparable(a);
  const right = toComparable(b);
  if (Array.isArray(left) || Array.isArray(right)) {
    if (!Array.isArray(left) || !Array.isArray(right)) return false;
    return (
      left.length === right.length &&
      left.every((item, index) => sameValue(item, right[index]))
    );
  }
  if (isPlainObject(left) || isPlainObject(right)) {
    if (!isPlainObject(left) || !isPlainObject(right)) return false;
    const keys = new Set([...Object.keys(left), ...Object.keys(right)]);
    return [...keys].every((key) => sameValue(left[key], right[key]));
  }
  return left === right;
}

/** Rendu court et lisible dans un rapport JSON, jamais tronqué au milieu d'un mot. */
export function renderValue(value: unknown): string {
  if (value === undefined || value === null) return '∅';
  if (value instanceof Date) return value.toISOString();
  const text = Array.isArray(value)
    ? `[${value.map((item) => renderValue(item)).join(', ')}]`
    : isPlainObject(value)
      ? JSON.stringify(value)
      : String(value);
  return text.length > 120 ? `${text.slice(0, 117)}…` : text;
}

function asDate(value: unknown): Date | null {
  if (value == null) return null;
  return value instanceof Date ? value : new Date(String(value));
}

/**
 * Le tampon du dépôt est-il au moins aussi récent que celui de la base ?
 * Un `null` en base n'est pas « plus récent » : il n'a jamais été posé.
 */
function catalogStampIsNotOlder(
  rowStamp: unknown,
  catalogStamp: unknown,
): boolean {
  const inDb = asDate(rowStamp);
  if (!inDb) return true;
  const inCatalog = asDate(catalogStamp);
  if (!inCatalog) return false;
  return inCatalog.getTime() >= inDb.getTime();
}

/**
 * Construit le plan de réalignement d'UNE fiche. Aucune écriture, aucun accès
 * base : la décision est calculée à part pour être testable sans Postgres, et
 * appliquée telle quelle par la CLI.
 */
export function planScholarshipReconciliation(
  record: VerifiedScholarshipCatalogRecord,
  catalogVersion: string,
  row: ReconcilableScholarshipRow | null,
): ReconciliationPlan {
  const scholarshipId = record.scholarship.id;
  const empty: ReconciliationPlan = {
    scholarshipId,
    presentInDatabase: row !== null,
    drifts: [],
    scholarshipUpdate: {},
    cycle: { academicYear: record.cycle.academicYear, action: 'none', data: {} },
    steps: { create: [], update: [], extraInDatabase: [] },
  };
  if (!row) return empty;

  const created = buildScholarshipCreateData(record, catalogVersion) as Record<
    string,
    unknown
  >;
  const drifts: CatalogDrift[] = [];
  const scholarshipUpdate: Record<string, unknown> = {};

  const dbCycle =
    row.cycles.find(
      (cycle) => cycle.academicYear === record.cycle.academicYear,
    ) ?? null;
  const cycleIsAdminOwned = dbCycle?.activatedAt != null;

  // Le bloc d'éligibilité : décidé UNE fois, appliqué à ses cinq champs.
  const eligibilityKeptReason = (() => {
    const inDb = asDate(row.eligibilityStructuredAt);
    if (!inDb) return undefined;
    if (created.eligibilityStructuredAt == null) {
      return `critères relus en base le ${renderValue(inDb)} — un brouillon du dépôt ne les remplace pas`;
    }
    if (!catalogStampIsNotOlder(inDb, created.eligibilityStructuredAt)) {
      return 'structuration relue en base plus récente que celle du catalogue';
    }
    return undefined;
  })();

  const push = (
    scope: DriftScope,
    field: string,
    inDatabase: unknown,
    inCatalog: unknown,
    keptReason?: string,
  ) => {
    drifts.push({
      scholarshipId,
      scope,
      field,
      inDatabase: renderValue(inDatabase),
      inCatalog: renderValue(inCatalog),
      reconciled: keptReason === undefined,
      ...(keptReason === undefined ? {} : { keptReason }),
    });
  };

  // ── La fiche ────────────────────────────────────────────────────────────
  for (const [field, wanted] of Object.entries(created)) {
    if ((NEVER_RECONCILED_FIELDS as readonly string[]).includes(field)) continue;

    // `tags` s'AJOUTE, ne se remplace pas : le tag d'une version antérieure du
    // catalogue est ce par quoi `publish` retrouve la ligne, et un tag posé
    // dans l'admin n'appartient pas au dépôt.
    if (field === 'tags') {
      const inDb = Array.isArray(row.tags) ? (row.tags as string[]) : [];
      const missing = (wanted as string[]).filter((tag) => !inDb.includes(tag));
      if (missing.length > 0) {
        push('scholarship', 'tags', inDb, [...inDb, ...missing]);
        scholarshipUpdate.tags = [...inDb, ...missing];
      }
      continue;
    }

    if (sameValue(row[field], wanted)) continue;

    if (
      eligibilityKeptReason !== undefined &&
      (ELIGIBILITY_PROVENANCE_FIELDS as readonly string[]).includes(field)
    ) {
      push('scholarship', field, row[field], wanted, eligibilityKeptReason);
      continue;
    }

    if (
      cycleIsAdminOwned &&
      (CYCLE_ACTIVATION_OWNED_FIELDS as readonly string[]).includes(field)
    ) {
      push(
        'scholarship',
        field,
        row[field],
        wanted,
        `cycle ${record.cycle.academicYear} activé en base — la base fait foi`,
      );
      continue;
    }

    if ((VERIFICATION_PROVENANCE_FIELDS as readonly string[]).includes(field)) {
      // Révocation explicite. Elle prime sur la comparaison de dates : il n'y a
      // pas de date à comparer, et c'est justement là que « pas de tampon » se
      // confondrait avec « tampon jamais posé ».
      if (row.lastVerifiedAt == null) {
        push(
          'scholarship',
          field,
          row[field],
          wanted,
          "vérification révoquée dans l'admin — seule une nouvelle relecture humaine la repose",
        );
        continue;
      }
      if (!catalogStampIsNotOlder(row.lastVerifiedAt, created.lastVerifiedAt)) {
        push(
          'scholarship',
          field,
          row[field],
          wanted,
          'vérification en base plus récente que celle du catalogue',
        );
        continue;
      }
    }

    push('scholarship', field, row[field], wanted);
    scholarshipUpdate[field] = wanted;
  }

  // ── Le cycle ────────────────────────────────────────────────────────────
  const wantedCycle = (
    created.cycles as { create: Record<string, unknown> }
  ).create;
  const cycleData: Record<string, unknown> = {};
  if (!dbCycle) {
    push('cycle', `${record.cycle.academicYear} (absent)`, null, 'à créer');
  } else {
    for (const [field, wanted] of Object.entries(wantedCycle)) {
      const current = (dbCycle as unknown as Record<string, unknown>)[field];
      if (sameValue(current, wanted)) continue;
      if (cycleIsAdminOwned) {
        push(
          'cycle',
          field,
          current,
          wanted,
          `cycle activé en base le ${renderValue(dbCycle.activatedAt)} — la base fait foi`,
        );
        continue;
      }
      push('cycle', field, current, wanted);
      cycleData[field] = wanted;
    }
  }

  // ── Les étapes ──────────────────────────────────────────────────────────
  const stepCreate: Array<Record<string, unknown>> = [];
  const stepUpdate: Array<{ stepNumber: number; data: Record<string, unknown> }> =
    [];
  const wantedSteps = (
    created.applicationSteps as { create: Array<Record<string, unknown>> }
  ).create;
  for (const wanted of wantedSteps) {
    const stepNumber = wanted.stepNumber as number;
    const current = row.applicationSteps.find(
      (step) => step.stepNumber === stepNumber,
    );
    if (!current) {
      push('step', `steps[${stepNumber}] (absente)`, null, wanted.titleFr);
      stepCreate.push(wanted);
      continue;
    }
    const data: Record<string, unknown> = {};
    for (const [field, value] of Object.entries(wanted)) {
      if (field === 'stepNumber') continue;
      const inDb = (current as unknown as Record<string, unknown>)[field];
      if (sameValue(inDb, value)) continue;
      push('step', `steps[${stepNumber}].${field}`, inDb, value);
      data[field] = value;
    }
    if (Object.keys(data).length > 0) stepUpdate.push({ stepNumber, data });
  }
  const wantedNumbers = new Set(wantedSteps.map((step) => step.stepNumber));
  const extraInDatabase = row.applicationSteps
    .map((step) => step.stepNumber)
    .filter((number) => !wantedNumbers.has(number))
    .sort((a, b) => a - b);
  for (const number of extraInDatabase) {
    push(
      'step',
      `steps[${number}] (en base uniquement)`,
      'présente',
      '∅',
      'une étape supprimée détacherait la progression des étudiants (sourceStepId → SetNull)',
    );
  }

  return {
    scholarshipId,
    presentInDatabase: true,
    drifts,
    scholarshipUpdate,
    cycle: {
      academicYear: record.cycle.academicYear,
      action: !dbCycle
        ? 'create'
        : Object.keys(cycleData).length > 0
          ? 'update'
          : 'none',
      data: !dbCycle ? wantedCycle : cycleData,
    },
    steps: { create: stepCreate, update: stepUpdate, extraInDatabase },
  };
}
