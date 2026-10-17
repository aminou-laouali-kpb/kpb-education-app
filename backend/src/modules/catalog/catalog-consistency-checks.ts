// ─────────────────────────────────────────────────────────────────────────────
// Contrôles de cohérence du catalogue, joués par `npm run verify:catalog`.
//
// Le script relit la base au déploiement (`deploy.yml`, avant la release), après
// les imports de `vps-ops.sh`, et en CI (`backend-ci.yml`, sur la base amorcée).
// Il vérifiait jusqu'ici les seules références pays — un orphelin y fait échouer
// le déploiement. Les trois contrôles de ce fichier sont d'une autre nature : ils
// signalent un catalogue DÉGRADÉ, pas cassé, et un déploiement n'a pas à rester
// bloqué dessus pendant que l'exploitation corrige une fiche. Ils AVERTISSENT
// donc par défaut, et n'échouent qu'avec `--strict`, que seule la CI passe.
//
//  1. `Program.fieldId` sans ligne `Field` : une colonne indexée, pas une clé
//     étrangère. La formation ne s'affiche sous aucun domaine dans l'app et
//     échappe à tout filtre par domaine.
//  2. Établissement partenaire publié sans aucune formation publiée : une carte
//     « partenaire » vide dans Explore, la vitrine même de l'offre KPB.
//  3. Des formations PARTENAIRES hors de la première page : les builds
//     installées chargent `/catalog/programs?limit=1000` d'un seul appel, sans
//     savoir paginer. Depuis le 17/10/2026 (aucun plafond de formations, décision
//     du propriétaire), le catalogue peut dépasser 1 000 lignes : les builds
//     récentes paginent et voient tout, et le serveur sert les partenaires EN
//     TÊTE (`program-snapshot-order.ts`). Qu'une formation non partenaire
//     manque aux builds installées est donc le compromis assumé et documenté —
//     le rapport l'imprime, sans constat. Le constat n'est levé que si les
//     formations partenaires, à elles seules, dépassent la première page : la
//     vitrine KPB amputée sur des téléphones qui ne peuvent pas être mis à jour.
//
// Tout ce qui décide est ici, en fonctions pures ; le script ne fait que lire
// des agrégats en base et imprimer le rapport.
// ─────────────────────────────────────────────────────────────────────────────
import type { Prisma } from '@prisma/client';

import { notEefInstitution, notEefProgram } from '../../common/eef-provenance';

/**
 * La taille de l'instantané de formations que chargent les builds installées :
 * `limit=1000` sans `offset`, c'est-à-dire la première page de
 * `CatalogService.getPrograms` (`PROGRAM_PAGE_MAX`). Les builds récentes, elles,
 * paginent jusqu'à épuisement.
 */
export const INSTALLED_APP_PROGRAM_SNAPSHOT_LIMIT = 1000;

/** Au-delà, les détails d'un constat sont résumés en « … and N more ». */
export const MAX_DETAIL_LINES = 20;

/** Le seul argument accepté par `verify:catalog`. */
export const STRICT_FLAG = '--strict';

/**
 * Les formations que `/catalog/programs` sert SANS filtre — exactement ce que
 * chaque build installée charge. Même clause que `CatalogService.getPrograms` :
 * `catalog-consistency-checks.spec.ts` échoue si les deux divergent, pour que
 * le compte du contrôle 3 reste celui de l'app.
 *
 * Fonction et non constante, pour la même raison que `notEefProgram`.
 */
export function publicCatalogProgramWhere(): Prisma.ProgramWhereInput {
  return { isActive: true, ...notEefProgram() };
}

/**
 * Les établissements que `/catalog/institutions?partnerOnly=true` sert : publiés,
 * hors import « Études en France », et marqués partenaires (`isPartner`, le
 * drapeau que l'app affiche — les `PartnerAgreement` relèvent d'autre chose).
 */
export function publicPartnerInstitutionWhere(): Prisma.InstitutionWhereInput {
  return { isActive: true, ...notEefInstitution(), isPartner: true };
}

/**
 * Lit les arguments du script. Un argument inconnu est une erreur, pas un
 * oubli silencieux : `--strcit` en CI rendrait la porte non bloquante sans que
 * personne ne le voie.
 */
export function parseVerifyCatalogArgs(args: readonly string[]): { strict: boolean } {
  let strict = false;
  for (const arg of args) {
    if (arg === STRICT_FLAG) {
      strict = true;
      continue;
    }
    throw new Error(
      `verify:catalog: unknown argument "${arg}" (only ${STRICT_FLAG} is accepted)`,
    );
  }
  return { strict };
}

// ── Contrôle 1 : `Program.fieldId` orphelin ──────────────────────────────────

/** Une ligne de `program.groupBy({ by: ['fieldId', 'isActive'] })`. */
export type ProgramFieldCount = {
  fieldId: string;
  isActive: boolean;
  count: number;
};

export type OrphanFieldRef = {
  fieldId: string;
  programs: number;
  activePrograms: number;
};

/**
 * Les `fieldId` qu'aucune ligne `Field` ne porte, avec le nombre de formations
 * concernées — toutes, publiées ou non, comme le contrôle des pays : une fiche
 * en attente sera publiée un jour avec la même référence.
 */
export function findOrphanProgramFieldIds(
  knownFieldIds: Iterable<string>,
  programsByField: readonly ProgramFieldCount[],
): OrphanFieldRef[] {
  const known = new Set(knownFieldIds);
  const orphans = new Map<string, OrphanFieldRef>();
  for (const row of programsByField) {
    if (known.has(row.fieldId) || row.count <= 0) continue;
    const entry = orphans.get(row.fieldId) ?? {
      fieldId: row.fieldId,
      programs: 0,
      activePrograms: 0,
    };
    entry.programs += row.count;
    if (row.isActive) entry.activePrograms += row.count;
    orphans.set(row.fieldId, entry);
  }
  return [...orphans.values()].sort((a, b) => compareStrings(a.fieldId, b.fieldId));
}

// ── Contrôle 2 : partenaire sans formation ───────────────────────────────────

export type PartnerInstitutionRef = { id: string; nameFr: string };

/** Une ligne de `program.groupBy({ by: ['institutionId'] })` sur le catalogue public. */
export type InstitutionProgramCount = { institutionId: string; count: number };

/**
 * Les partenaires publiés dont aucune formation n'est servie par le catalogue
 * général. `publicProgramsByInstitution` doit être compté sur
 * [publicCatalogProgramWhere] : une formation en attente de relecture ne
 * remplit pas la carte.
 */
export function findPartnersWithoutPrograms(
  partners: readonly PartnerInstitutionRef[],
  publicProgramsByInstitution: readonly InstitutionProgramCount[],
): PartnerInstitutionRef[] {
  const withPrograms = new Set(
    publicProgramsByInstitution
      .filter((row) => row.count > 0)
      .map((row) => row.institutionId),
  );
  return partners
    .filter((partner) => !withPrograms.has(partner.id))
    .sort((a, b) => compareStrings(a.nameFr, b.nameFr) || compareStrings(a.id, b.id));
}

// ── Contrôle 3 : la première page des builds installées ──────────────────────

export type ProgramSnapshotOverflow = {
  publicPrograms: number;
  /** Formations publiques des établissements partenaires publiés. */
  partnerPrograms: number;
  limit: number;
  /** Ce que les builds installées ne voient pas (non partenaires d'abord). */
  hiddenFromInstalledApps: number;
  /** Dont formations partenaires : le seul cas qui lève un constat. */
  hiddenPartnerPrograms: number;
};

/**
 * Le nombre de formations publiques des partenaires publiés — celles que
 * `CatalogService.getPrograms` sert en tête de liste.
 */
export function countPartnerPrograms(
  partners: readonly PartnerInstitutionRef[],
  publicProgramsByInstitution: readonly InstitutionProgramCount[],
): number {
  const partnerIds = new Set(partners.map((partner) => partner.id));
  return publicProgramsByInstitution
    .filter((row) => partnerIds.has(row.institutionId))
    .reduce((sum, row) => sum + Math.max(row.count, 0), 0);
}

/** `null` tant que le catalogue général tient dans la première page. */
export function findProgramSnapshotOverflow(
  publicPrograms: number,
  limit: number = INSTALLED_APP_PROGRAM_SNAPSHOT_LIMIT,
  partnerPrograms = 0,
): ProgramSnapshotOverflow | null {
  if (publicPrograms <= limit) return null;
  return {
    publicPrograms,
    partnerPrograms,
    limit,
    hiddenFromInstalledApps: publicPrograms - limit,
    hiddenPartnerPrograms: Math.max(partnerPrograms - limit, 0),
  };
}

// ── Assemblage et rapport ────────────────────────────────────────────────────

/** Les agrégats que le script lit en base, et rien d'autre. */
export type CatalogConsistencyInput = {
  fieldIds: readonly string[];
  programsByField: readonly ProgramFieldCount[];
  partnerInstitutions: readonly PartnerInstitutionRef[];
  publicProgramsByInstitution: readonly InstitutionProgramCount[];
  publicProgramCount: number;
};

export type CatalogConsistencyCheck =
  | 'orphan-field-id'
  | 'partner-without-programs'
  | 'program-snapshot-overflow';

export type CatalogConsistencyFinding = {
  check: CatalogConsistencyCheck;
  summary: string;
  details: string[];
};

export function evaluateCatalogConsistency(
  input: CatalogConsistencyInput,
  snapshotLimit: number = INSTALLED_APP_PROGRAM_SNAPSHOT_LIMIT,
): CatalogConsistencyFinding[] {
  const findings: CatalogConsistencyFinding[] = [];

  const orphans = findOrphanProgramFieldIds(input.fieldIds, input.programsByField);
  if (orphans.length > 0) {
    const programs = orphans.reduce((sum, o) => sum + o.programs, 0);
    findings.push({
      check: 'orphan-field-id',
      summary:
        `${programs} Program row(s) reference ${orphans.length} fieldId value(s) ` +
        'with no Field row: the app shows them under no field and no field filter reaches them.',
      details: orphans.map(
        (o) => `fieldId="${o.fieldId}" (${o.programs} row(s), ${o.activePrograms} active)`,
      ),
    });
  }

  const emptyPartners = findPartnersWithoutPrograms(
    input.partnerInstitutions,
    input.publicProgramsByInstitution,
  );
  if (emptyPartners.length > 0) {
    findings.push({
      check: 'partner-without-programs',
      summary:
        `${emptyPartners.length} active partner institution(s) have zero active programs ` +
        'in the public catalog: an empty partner card in Explore.',
      details: emptyPartners.map((p) => `"${p.nameFr}" (id=${p.id})`),
    });
  }

  const overflow = findProgramSnapshotOverflow(
    input.publicProgramCount,
    snapshotLimit,
    countPartnerPrograms(input.partnerInstitutions, input.publicProgramsByInstitution),
  );
  if (overflow && overflow.hiddenPartnerPrograms > 0) {
    findings.push({
      check: 'program-snapshot-overflow',
      summary:
        `${overflow.partnerPrograms} active partner programs, but installed app builds ` +
        `load only the first ${overflow.limit} programs (partners first): ` +
        `${overflow.hiddenPartnerPrograms} partner programs are invisible to them.`,
      details: [],
    });
  }

  return findings;
}

export type CatalogConsistencyReport = {
  /** Faux dès qu'un constat existe : le script écrit alors sur stderr. */
  ok: boolean;
  lines: string[];
  /** 1 seulement en mode strict avec au moins un constat. */
  exitCode: 0 | 1;
};

/**
 * Met en forme les constats. Chacun ouvre sur une annotation GitHub
 * (`::warning::` sans `--strict`, `::error::` avec) : le déploiement comme la CI
 * tournent dans Actions, et l'annotation remonte dans le résumé du run même
 * quand l'étape reste verte — c'est le seul endroit où un avertissement non
 * bloquant a une chance d'être lu.
 */
export function renderCatalogConsistencyReport(
  findings: readonly CatalogConsistencyFinding[],
  options: {
    strict: boolean;
    publicProgramCount: number;
    snapshotLimit?: number;
    partnerProgramCount?: number;
  },
): CatalogConsistencyReport {
  const limit = options.snapshotLimit ?? INSTALLED_APP_PROGRAM_SNAPSHOT_LIMIT;
  // Le compromis assumé pour les builds installées, imprimé à chaque passage :
  // ce n'est pas un constat, mais l'exploitation doit le voir grossir.
  const beyond = options.publicProgramCount - limit;
  const snapshotNote =
    beyond > 0
      ? `Note — ${options.publicProgramCount} public programs: recent app builds page through ` +
        `all of them; installed builds (limit=1000, no paging) load the first ${limit}, ` +
        'partners first' +
        (options.partnerProgramCount !== undefined
          ? ` (${options.partnerProgramCount} partner programs)`
          : '') +
        `, and miss the last ${beyond} program(s).`
      : null;
  if (findings.length === 0) {
    return {
      ok: true,
      exitCode: 0,
      lines: [
        'OK — every Program.fieldId references a Field, every active partner institution ' +
          'has an active program, and every partner program is in the installed-app first page ' +
          `(${options.publicProgramCount}/${limit} programs).`,
        ...(snapshotNote ? [snapshotNote] : []),
      ],
    };
  }

  const annotation = options.strict ? '::error::' : '::warning::';
  const lines: string[] = [];
  if (snapshotNote) lines.push(snapshotNote);
  for (const finding of findings) {
    lines.push(`${annotation}Catalog check [${finding.check}]: ${finding.summary}`);
    const shown = finding.details.slice(0, MAX_DETAIL_LINES);
    for (const detail of shown) lines.push(`  ${detail}`);
    const rest = finding.details.length - shown.length;
    if (rest > 0) lines.push(`  … and ${rest} more`);
  }
  lines.push(
    options.strict
      ? `FAIL — ${findings.length} catalog consistency check(s) flagged (${STRICT_FLAG}).`
      : `WARN — ${findings.length} catalog consistency check(s) flagged. Not blocking ` +
          `without ${STRICT_FLAG}; Backend CI runs with ${STRICT_FLAG} and fails on them.`,
  );
  return { ok: false, lines, exitCode: options.strict ? 1 : 0 };
}

/** Ordre stable et indépendant de la locale de la machine qui exécute. */
function compareStrings(a: string, b: string): number {
  if (a === b) return 0;
  return a < b ? -1 : 1;
}
