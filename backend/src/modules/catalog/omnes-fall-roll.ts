// ─────────────────────────────────────────────────────────────────────────────
// Reconduction des rentrées d'automne OMNES 2026 → 2027 — la moitié pure de
// `roll:omnes-fall-2027`.
//
// Décision du propriétaire (16/10/2026) : toutes les rentrées d'automne 2026
// de la grille OMNES (omnes_fall_26.xlsx — août, septembre et octobre 2026)
// sont reconduites d'un an, même jour et même mois : « 01/10/2026 » devient
// « 01/10/2027 », « 14/09/2026 » devient « 14/09/2027 », « 31/08/2026 »
// devient « 31/08/2027 ». Les offres de rentrée décalée (janvier – mars 2027,
// grille SPRING 27) ne bougent pas : une formation qui a les deux garde son
// offre de printemps et voit son offre d'automne passer en 2027.
//
// OMNES n'a publié ni les dates ni les tarifs 2027-2028 : une offre reconduite
// garde son campus et ses prix (ceux de 2026-2027) et porte deux marques que
// l'app lit pour l'afficher « à confirmer » :
//
//   rolledFromIntake : la rentrée d'origine, telle qu'elle était écrite
//                      (« 01/10/2026 », ou « 14/09/2026 · 01/10/2026 ») ;
//   intakeEstimated  : true — la date n'est pas publiée par l'école.
//
// Seules les offres d'automne 2026 NON RETOUCHÉES sont reconduites : celles
// dont le campus, chaque date et les deux prix sont ceux de la grille
// d'automne pour cette formation (alias de catalog-dedupe.ts compris), et qui
// n'ont pas d'autre champ que ceux du seed. Une offre retouchée à la main est
// SIGNALÉE, jamais modifiée.
//
// Le script (scripts/roll-omnes-fall-2027.ts) lit la base et la grille,
// appelle `planOmnesFallRoll` et écrit le plan ; le seed d'une base vierge
// (scripts/seed-omnes-programs.ts) passe ses offres par `rollSeedOffering`.
// ─────────────────────────────────────────────────────────────────────────────
import {
  campusKey,
  intakeMonthYear,
  readCampusOfferings,
} from './campus-offerings';
import { omnesFormationIdentity } from './catalog-dedupe';
import {
  type OmnesRow,
  normalizeOmnesLanguage,
  normalizeFormationName,
  omnesProgramId,
  toNumberOrNull,
} from './omnes-conventions';

export const OMNES_FALL_ROLL_FROM_YEAR = 2026;
export const OMNES_FALL_ROLL_TO_YEAR = 2027;

/// Les champs qu'écrit le seed d'automne. Une offre d'automne 2026 qui en
/// porte un autre (session, rythme, marque…) a été retouchée : signalée.
const SEED_OFFERING_KEYS = new Set([
  'campus',
  'tuitionUpfront',
  'tuitionInstallments',
  'intake',
]);

const DAY_MONTH_YEAR = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;

/**
 * Une date « jj/mm/2026 » d'automne (juillet à décembre, comme
 * `sessionFromIntake`) : celles que la décision reconduit. La grille n'en a
 * que d'août, septembre et octobre.
 */
export function isFall2026Date(part: string): boolean {
  const m = DAY_MONTH_YEAR.exec(part.trim());
  if (!m) return false;
  const my = intakeMonthYear(part.trim());
  return my !== null && my.year === OMNES_FALL_ROLL_FROM_YEAR && my.month >= 7;
}

/** « 01/10/2026 » → « 01/10/2027 » ; nul pour toute autre valeur. */
export function rollFallDate(part: string): string | null {
  if (!isFall2026Date(part)) return null;
  const m = DAY_MONTH_YEAR.exec(part.trim())!;
  return `${m[1]}/${m[2]}/${OMNES_FALL_ROLL_TO_YEAR}`;
}

/// Les dates d'une rentrée écrite par le seed (« 14/09/2026 · 01/10/2026 »).
export function intakeParts(intake: unknown): string[] {
  if (typeof intake !== 'string') return [];
  return intake
    .split('·')
    .map((p) => p.trim())
    .filter(Boolean);
}

/**
 * Ce que la reconduction fait d'une rentrée :
 *  - `none`  : aucune date d'automne 2026 (printemps 2027, déjà reconduite,
 *              texte libre…) — rien à faire ;
 *  - `all`   : toutes ses dates sont d'automne 2026 — `rolled` est la rentrée
 *              reconduite, dates dans le même ordre ;
 *  - `mixed` : des dates d'automne 2026 ET d'autres — retouchée, signalée.
 */
export function rollIntakeText(
  intake: unknown,
): { kind: 'none' } | { kind: 'all'; rolled: string } | { kind: 'mixed' } {
  const parts = intakeParts(intake);
  const fall = parts.filter(isFall2026Date);
  if (fall.length === 0) return { kind: 'none' };
  if (fall.length !== parts.length) return { kind: 'mixed' };
  return { kind: 'all', rolled: parts.map((p) => rollFallDate(p)!).join(' · ') };
}

/** L'offre reconduite : même objet, rentrée +1 an, deux marques à la fin. */
export function rolledOffering<T extends Record<string, unknown>>(
  offer: T,
  rolledIntake: string,
): T & { intake: string; rolledFromIntake: string; intakeEstimated: true } {
  return {
    ...offer,
    intake: rolledIntake,
    rolledFromIntake: String(offer.intake),
    intakeEstimated: true,
  };
}

/**
 * Pour le seed d'une base vierge : une offre d'automne 2026 sort déjà
 * reconduite ; toute autre offre est rendue telle quelle.
 */
export function rollSeedOffering<T extends Record<string, unknown>>(offer: T): T {
  const r = rollIntakeText(offer.intake);
  return r.kind === 'all' ? rolledOffering(offer, r.rolled) : offer;
}

/// Une date de rentrée d'école (`intakePeriods`) : reconduite si c'est une
/// date d'automne 2026, rendue telle quelle sinon (« Rentrée automne »…).
export function rollSeedIntakePeriod(period: string): string {
  return rollFallDate(period) ?? period;
}

// ── La grille d'automne, référence des offres « non retouchées » ────────────

/** Une ligne de omnes_fall_26.xlsx (mêmes règles que import-omnes-template.ts). */
export function omnesRowFromRecord(r: Record<string, unknown>): OmnesRow | null {
  const school = String(r['Ecole / School'] ?? '').trim();
  const programName = String(r['NOM / NAME'] ?? '').trim();
  if (!school || !programName) return null;
  return {
    school,
    campus: String(r['Campus'] ?? '').trim(),
    programName,
    programFamily: String(r['Type_Programme / Type of program'] ?? '').trim(),
    degreeLevel: String(r['Niveau_Etude_ / Level of studies'] ?? '').trim(),
    admissionLevel: String(r['Niveau Admission / Admission Level'] ?? '').trim(),
    language: normalizeOmnesLanguage(r['Langue / Language']),
    paymentUpfront: toNumberOrNull(r['Payment Comptant / Payment Upfront']),
    paymentInstallments: toNumberOrNull(
      r['Paiement Echelonné / With installments (2)'],
    ),
    intakeDate: String(r['Date_de_Rentrée / Intake Date'] ?? '').trim() || null,
  };
}

type SourceCampus = {
  intakes: Set<string>;
  upfront: Set<number | null>;
  installments: Set<number | null>;
};

/// id de formation → campus (clé) → ce que la grille d'automne y publie.
export type FallSourceIndex = Map<string, Map<string, SourceCampus>>;

/**
 * Indexe la grille d'automne sous l'id HISTORIQUE de chaque ligne (celui que
 * le premier seed a écrit en production, alias compris) ET sous l'id
 * canonique (catalog-dedupe.ts) : une offre d'alias fusionnée sur sa fiche
 * canonique par `dedupe:omnes` y est reconnue comme venant de la grille.
 */
export function buildFallSourceIndex(rows: readonly OmnesRow[]): FallSourceIndex {
  const index: FallSourceIndex = new Map();
  for (const row of rows) {
    const campus = row.campus || '—';
    const legacy = omnesProgramId(row.school, normalizeFormationName(row.programName, campus));
    const { id: canonical } = omnesFormationIdentity(row.school, row.programName, row.campus);
    for (const id of new Set([legacy, canonical])) {
      const byCampus = index.get(id) ?? new Map<string, SourceCampus>();
      const key = campusKey(campus);
      const acc = byCampus.get(key) ?? {
        intakes: new Set<string>(),
        upfront: new Set<number | null>(),
        installments: new Set<number | null>(),
      };
      if (row.intakeDate) acc.intakes.add(row.intakeDate);
      acc.upfront.add(row.paymentUpfront);
      acc.installments.add(row.paymentInstallments);
      byCampus.set(key, acc);
      index.set(id, byCampus);
    }
  }
  return index;
}

/**
 * Pourquoi une offre d'automne 2026 n'est PAS reconduite (retouchée), ou nul
 * quand elle est telle que la grille l'a publiée.
 */
export function offeringTouchedReason(
  programId: string,
  offer: Record<string, unknown>,
  index: FallSourceIndex,
): string | null {
  const extra = Object.keys(offer).filter((k) => !SEED_OFFERING_KEYS.has(k));
  if (extra.length) return `champ(s) ajouté(s) à la main : ${extra.join(', ')}`;
  const source = index.get(programId);
  if (!source) return 'formation absente de la grille d’automne (fiche créée à la main ?)';
  if (typeof offer.campus !== 'string') return 'offre sans campus';
  const campus = source.get(campusKey(offer.campus));
  if (!campus) return `campus « ${offer.campus} » absent de la grille d’automne pour cette formation`;
  const unknownDates = intakeParts(offer.intake).filter((d) => !campus.intakes.has(d));
  if (unknownDates.length) return `date(s) ${unknownDates.join(', ')} absente(s) de la grille`;
  const upfront = offer.tuitionUpfront ?? null;
  const installments = offer.tuitionInstallments ?? null;
  if (!campus.upfront.has(upfront as number | null)) {
    return `prix comptant ${String(upfront)} différent de la grille`;
  }
  if (!campus.installments.has(installments as number | null)) {
    return `prix échelonné ${String(installments)} différent de la grille`;
  }
  return null;
}

// ── Le plan ─────────────────────────────────────────────────────────────────

export type RollProgramState = {
  id: string;
  institutionId: string;
  nameFr: string;
  campusOfferings: unknown;
  updatedAt: Date;
  /// Un alias mis hors ligne par `dedupe:omnes` est reconduit aussi : ses
  /// offres sont déjà sur la fiche canonique, et la base reste la même quel
  /// que soit l'ordre des opérations. Le rapport le compte à part.
  isActive?: boolean;
};

export type RollInstitutionState = {
  id: string;
  intakePeriods: string[];
  updatedAt: Date;
};

export type RolledOfferNote = { campus: string; from: string; to: string };

export type OmnesFallRollPlan = {
  /// Fiches dont au moins une offre est reconduite. `merged` = toutes les
  /// offres, dans leur ordre, les reconduites remplacées sur place.
  programUpdates: {
    id: string;
    institutionId: string;
    name: string;
    isActive: boolean;
    /// L'écriture est conditionnée à cette valeur (voir le script).
    expectedUpdatedAt: Date;
    merged: unknown[];
    rolled: RolledOfferNote[];
  }[];
  /// Offres d'automne 2026 retouchées à la main : laissées telles quelles.
  flagged: { id: string; name: string; institutionId: string; campus: string; intake: string; reason: string }[];
  /// Écoles : chaque date d'automne 2026 que plus aucune offre ne porte est
  /// remplacée, à sa place, par la date reconduite ; les dates reconduites
  /// des offres qui manquent sont ajoutées à la fin. Rien d'autre ne bouge.
  institutionUpdates: {
    id: string;
    expectedUpdatedAt: Date;
    intakePeriods: string[];
    removed: string[];
    added: string[];
  }[];
  /// Fiches lues sans aucune offre d'automne 2026 (déjà reconduites, printemps…).
  unchanged: number;
};

/** Ordre chronologique de dates « jj/mm/aaaa ». */
function compareDates(a: string, b: string): number {
  const key = (d: string) => d.split('/').reverse().map((p) => p.padStart(2, '0')).join('');
  return key(a).localeCompare(key(b));
}

/**
 * Ce que la reconduction doit écrire, et seulement cela. Pur : la base et la
 * grille sont passées en argument. Rejoué sur son propre résultat : vide.
 */
export function planOmnesFallRoll(
  programs: readonly RollProgramState[],
  institutions: readonly RollInstitutionState[],
  index: FallSourceIndex,
): OmnesFallRollPlan {
  const plan: OmnesFallRollPlan = {
    programUpdates: [],
    flagged: [],
    institutionUpdates: [],
    unchanged: 0,
  };
  /// Les offres de chaque école APRÈS le plan, pour ses `intakePeriods`.
  const offersBySchool = new Map<string, Record<string, unknown>[]>();

  for (const program of [...programs].sort((a, b) => a.id.localeCompare(b.id))) {
    const current = readCampusOfferings(program.campusOfferings) ?? [];
    const merged: Record<string, unknown>[] = [];
    const rolled: RolledOfferNote[] = [];
    for (const offer of current) {
      const r = rollIntakeText(offer.intake);
      if (r.kind === 'none') {
        merged.push(offer);
        continue;
      }
      const flag = (reason: string) => {
        plan.flagged.push({
          id: program.id,
          name: program.nameFr,
          institutionId: program.institutionId,
          campus: String(offer.campus ?? '—'),
          intake: String(offer.intake),
          reason,
        });
        merged.push(offer);
      };
      if (r.kind === 'mixed') {
        flag('rentrées 2026 et autres dates mêlées dans une même offre');
        continue;
      }
      const touched = offeringTouchedReason(program.id, offer, index);
      if (touched) {
        flag(touched);
        continue;
      }
      // Une offre identique (même campus, même rentrée) est déjà là : la
      // reconduire ferait un doublon. On la signale plutôt que de l'effacer.
      const clash = current.some(
        (o) =>
          o !== offer &&
          typeof o.campus === 'string' &&
          campusKey(o.campus) === campusKey(String(offer.campus)) &&
          o.intake === r.rolled,
      );
      if (clash) {
        flag(`une offre ${String(offer.campus)} au ${r.rolled} existe déjà — doublon à fusionner dans l’admin`);
        continue;
      }
      merged.push(rolledOffering(offer, r.rolled));
      rolled.push({ campus: String(offer.campus), from: String(offer.intake), to: r.rolled });
    }
    const list = offersBySchool.get(program.institutionId) ?? [];
    list.push(...merged);
    offersBySchool.set(program.institutionId, list);
    if (rolled.length === 0) {
      plan.unchanged += 1;
      continue;
    }
    plan.programUpdates.push({
      id: program.id,
      institutionId: program.institutionId,
      name: program.nameFr,
      isActive: program.isActive ?? true,
      expectedUpdatedAt: program.updatedAt,
      merged,
      rolled,
    });
  }

  for (const inst of [...institutions].sort((a, b) => a.id.localeCompare(b.id))) {
    const offers = offersBySchool.get(inst.id) ?? [];
    const stillFall2026 = new Set(
      offers.flatMap((o) => intakeParts(o.intake)).filter(isFall2026Date),
    );
    const next: string[] = [];
    const removed: string[] = [];
    for (const period of inst.intakePeriods) {
      const to = rollFallDate(period);
      if (to === null || stillFall2026.has(period)) {
        next.push(period);
        continue;
      }
      removed.push(period);
      if (!inst.intakePeriods.includes(to) && !next.includes(to)) next.push(to);
    }
    const rolledDates = [
      ...new Set(
        offers
          .filter((o) => o.intakeEstimated === true)
          .flatMap((o) => intakeParts(o.intake)),
      ),
    ]
      .filter((d) => !next.includes(d))
      .sort(compareDates);
    next.push(...rolledDates);
    const added = next.filter((p) => !inst.intakePeriods.includes(p));
    if (removed.length || added.length) {
      plan.institutionUpdates.push({
        id: inst.id,
        expectedUpdatedAt: inst.updatedAt,
        intakePeriods: next,
        removed,
        added,
      });
    }
  }
  return plan;
}

/** Nombre d'écritures d'un plan : zéro quand la reconduction est déjà faite. */
export function omnesFallRollWriteCount(plan: OmnesFallRollPlan): number {
  return plan.programUpdates.length + plan.institutionUpdates.length;
}

// ── L'écriture ──────────────────────────────────────────────────────────────

/// Les deux écritures conditionnelles, fournies par le script (Prisma,
/// `updateMany … WHERE id AND updatedAt`) ou par un faux en test. Chacune
/// rend vrai quand la ligne a été écrite, faux quand elle avait bougé.
export type RollWriter = {
  writeProgramOfferings(
    id: string,
    expectedUpdatedAt: Date,
    campusOfferings: unknown[],
  ): Promise<boolean>;
  writeInstitutionIntakes(
    id: string,
    expectedUpdatedAt: Date,
    intakePeriods: string[],
  ): Promise<boolean>;
};

/**
 * Écrit le plan. Chaque fiche n'est réécrite que si son `updatedAt` n'a pas
 * bougé depuis la lecture (`@updatedAt` le rafraîchit à chaque écriture) :
 * une retouche faite dans l'admin pendant l'opération est gardée. Une école
 * dont une fiche n'a pas pu être écrite garde ses dates 2026 : la relance les
 * remplacera avec la fiche.
 */
export async function applyOmnesFallRollPlan(
  writer: RollWriter,
  plan: OmnesFallRollPlan,
): Promise<{ written: number; raced: string[]; skippedSchools: string[] }> {
  let written = 0;
  const raced: string[] = [];
  const racedSchools = new Set<string>();
  for (const u of plan.programUpdates) {
    if (await writer.writeProgramOfferings(u.id, u.expectedUpdatedAt, u.merged)) written += 1;
    else {
      raced.push(u.id);
      racedSchools.add(u.institutionId);
    }
  }
  const skippedSchools: string[] = [];
  for (const inst of plan.institutionUpdates) {
    if (racedSchools.has(inst.id)) {
      skippedSchools.push(inst.id);
      continue;
    }
    const ok = await writer.writeInstitutionIntakes(inst.id, inst.expectedUpdatedAt, inst.intakePeriods);
    if (ok) written += 1;
    else raced.push(inst.id);
  }
  return { written, raced, skippedSchools };
}
