import * as fs from 'node:fs';
import * as path from 'node:path';

import * as XLSX from 'xlsx';

import { readCampusOfferings } from './campus-offerings';
import {
  type DedupeProgramState,
  omnesDedupeWriteCount,
  omnesFormationIdentity,
  planOmnesDedupe,
} from './catalog-dedupe';
import {
  type OmnesRow,
  formatLevel,
  normalizeFormationName,
  omnesInstitutionId,
  omnesProgramId,
} from './omnes-conventions';
import {
  type FallSourceIndex,
  type OmnesFallRollPlan,
  type RollWriter,
  applyOmnesFallRollPlan,
  buildFallSourceIndex,
  intakeParts,
  isFall2026Date,
  omnesFallRollWriteCount,
  omnesRowFromRecord,
  planOmnesFallRoll,
  rollFallDate,
  rollIntakeText,
  rollSeedIntakePeriod,
  rollSeedOffering,
} from './omnes-fall-roll';
import {
  OMNES_SCHOOLS,
  groupSpringFormations,
  parseOmnesSpringCsv,
  planOmnesSpring,
  planWriteCount,
} from './omnes-spring-import';

/**
 * La reconduction ne tourne pas ici (il lui faut une base) : sa moitié pure
 * est jouée contre les VRAIES grilles livrées (omnes_fall_26.xlsx,
 * omnes_spring_27.csv) sur une base en mémoire, qui enchaîne les trois
 * opérations de production (`dedupe:omnes`, `import:omnes-spring`,
 * `roll:omnes-fall-2027`) dans tous les ordres.
 */
const DATA = path.join(__dirname, '..', '..', '..', 'scripts', 'data');
const SPRING_CSV = fs.readFileSync(path.join(DATA, 'omnes_spring_27.csv'), 'utf8');

function fallRows(): OmnesRow[] {
  const sheet = XLSX.readFile(path.join(DATA, 'omnes_fall_26.xlsx'));
  const records: Record<string, unknown>[] = XLSX.utils.sheet_to_json(
    sheet.Sheets[sheet.SheetNames[0]],
    { defval: '' },
  );
  return records
    .map(omnesRowFromRecord)
    .filter((r): r is OmnesRow => r !== null && OMNES_SCHOOLS.includes(r.school));
}

const ROWS = fallRows();
const INDEX: FallSourceIndex = buildFallSourceIndex(ROWS);

// ── Une base en mémoire ─────────────────────────────────────────────────────

type DbProgram = {
  id: string;
  institutionId: string;
  nameFr: string;
  nameEn: string;
  levelFr: string;
  campusOfferings: unknown;
  isActive: boolean;
  updatedAt: Date;
};
type DbInstitution = { id: string; intakePeriods: string[]; programIds: string[]; updatedAt: Date };
type Db = { programs: Map<string, DbProgram>; institutions: Map<string, DbInstitution>; tick: number };

function touch(db: Db): Date {
  db.tick += 1;
  return new Date(Date.UTC(2026, 9, 16, 12, 0, db.tick));
}

/**
 * La base telle que la production l'a reçue du PREMIER seed d'automne : ids
 * historiques (alias compris, avant `dedupe:omnes`), une offre par campus
 * (premier prix, dates jointes par « · »). `fresh` : la base que le seed
 * ACTUEL produit sur une base vierge (alias rapprochés, rentrées reconduites).
 */
function seededDb(mode: 'production' | 'fresh'): Db {
  type Acc = {
    institutionId: string;
    name: string;
    level: string;
    offers: Map<string, { up: number | null; inst: number | null; intakes: string[] }>;
  };
  const formations = new Map<string, Acc>();
  const institutions = new Map<string, DbInstitution>();
  const seedDate = new Date('2026-06-25T12:00:00Z');
  for (const row of ROWS) {
    const campus = row.campus || '—';
    const identity = omnesFormationIdentity(row.school, row.programName, row.campus);
    const id =
      mode === 'production'
        ? omnesProgramId(row.school, normalizeFormationName(row.programName, campus))
        : identity.id;
    const instId = omnesInstitutionId(row.school);
    const acc = formations.get(id) ?? {
      institutionId: instId,
      name: mode === 'production' ? normalizeFormationName(row.programName, campus) : identity.name,
      level: formatLevel(row).fr,
      offers: new Map(),
    };
    const offer = acc.offers.get(campus) ?? { up: null, inst: null, intakes: [] };
    if (offer.up == null) offer.up = row.paymentUpfront;
    if (offer.inst == null) offer.inst = row.paymentInstallments;
    if (row.intakeDate && !offer.intakes.includes(row.intakeDate)) offer.intakes.push(row.intakeDate);
    acc.offers.set(campus, offer);
    formations.set(id, acc);
    const inst = institutions.get(instId) ?? {
      id: instId,
      intakePeriods: [],
      programIds: [],
      updatedAt: seedDate,
    };
    const period = row.intakeDate ?? 'Rentrée automne';
    const written = mode === 'fresh' ? rollSeedIntakePeriod(period) : period;
    if (!inst.intakePeriods.includes(written)) inst.intakePeriods.push(written);
    if (!inst.programIds.includes(id)) inst.programIds.push(id);
    institutions.set(instId, inst);
  }
  const programs = new Map<string, DbProgram>();
  for (const [id, acc] of formations) {
    const offers = [...acc.offers.entries()]
      .sort(([a], [b]) => a.localeCompare(b, 'fr'))
      .map(([campus, o]) => {
        const offer = {
          campus,
          tuitionUpfront: o.up,
          tuitionInstallments: o.inst,
          intake: o.intakes.join(' · ') || null,
        };
        return mode === 'fresh' ? rollSeedOffering(offer) : offer;
      });
    programs.set(id, {
      id,
      institutionId: acc.institutionId,
      nameFr: acc.name,
      nameEn: acc.name,
      levelFr: acc.level,
      campusOfferings: offers,
      isActive: true,
      updatedAt: seedDate,
    });
  }
  return { programs, institutions, tick: 0 };
}

function runDedupe(db: Db): number {
  const plan = planOmnesDedupe(new Map<string, DedupeProgramState>(db.programs));
  for (const u of plan.canonicalUpdates) {
    const p = db.programs.get(u.id)!;
    if (u.merged) p.campusOfferings = u.merged;
    if (u.rename) Object.assign(p, u.rename);
    p.updatedAt = touch(db);
  }
  for (const d of plan.deactivations) {
    const p = db.programs.get(d.id)!;
    p.isActive = false;
    p.updatedAt = touch(db);
  }
  return omnesDedupeWriteCount(plan);
}

function runSpring(db: Db): number {
  const { rows, errors } = parseOmnesSpringCsv(SPRING_CSV);
  expect(errors).toEqual([]);
  const formations = groupSpringFormations(rows);
  const plan = planOmnesSpring(
    formations,
    new Map([...db.programs].filter(([id]) => formations.some((f) => f.id === id))),
    new Map(db.institutions),
    [...db.programs.values()],
  );
  expect(plan.errors).toEqual([]);
  for (const a of plan.additions) {
    const p = db.programs.get(a.id)!;
    p.campusOfferings = a.merged;
    p.updatedAt = touch(db);
  }
  for (const c of plan.creations) {
    db.programs.set(c.id, {
      id: c.id,
      institutionId: c.institutionId,
      nameFr: c.nameFr,
      nameEn: c.nameEn,
      levelFr: c.levelFr,
      campusOfferings: JSON.parse(JSON.stringify(c.campusOfferings)),
      isActive: true,
      updatedAt: touch(db),
    });
  }
  for (const i of plan.institutions) {
    const inst = db.institutions.get(i.id)!;
    inst.intakePeriods = [...inst.intakePeriods, ...i.addIntakePeriods];
    inst.programIds = [...inst.programIds, ...i.addProgramIds];
    inst.updatedAt = touch(db);
  }
  return planWriteCount(plan);
}

/// Un écrivain qui respecte, comme Postgres, le `WHERE updatedAt`.
function fakeClient(db: Db): RollWriter {
  return {
    writeProgramOfferings: async (id, updatedAt, campusOfferings) => {
      const p = db.programs.get(id);
      if (!p || p.updatedAt.getTime() !== updatedAt.getTime()) return false;
      p.campusOfferings = campusOfferings;
      p.updatedAt = touch(db);
      return true;
    },
    writeInstitutionIntakes: async (id, updatedAt, intakePeriods) => {
      const i = db.institutions.get(id);
      if (!i || i.updatedAt.getTime() !== updatedAt.getTime()) return false;
      i.intakePeriods = intakePeriods;
      i.updatedAt = touch(db);
      return true;
    },
  };
}

function planRoll(db: Db): OmnesFallRollPlan {
  return planOmnesFallRoll([...db.programs.values()], [...db.institutions.values()], INDEX);
}

async function runRoll(db: Db): Promise<number> {
  const plan = planRoll(db);
  await applyOmnesFallRollPlan(fakeClient(db), plan);
  return omnesFallRollWriteCount(plan);
}

function offersOf(p: DbProgram): Record<string, unknown>[] {
  return readCampusOfferings(p.campusOfferings) ?? [];
}

function allIntakeDates(db: Db): string[] {
  return [...db.programs.values()].flatMap((p) => offersOf(p).flatMap((o) => intakeParts(o.intake)));
}

/// L'état comparable d'une base : offres, statut, intitulé, dates d'école.
function snapshot(db: Db, sortOffers = false) {
  const offers = (p: DbProgram) =>
    sortOffers
      ? offersOf(p)
          .map((o) => JSON.stringify(o))
          .sort()
      : p.campusOfferings;
  return JSON.stringify({
    programs: [...db.programs.values()]
      .sort((a, b) => a.id.localeCompare(b.id))
      .map((p) => [p.id, p.nameFr, p.isActive, offers(p)]),
    institutions: [...db.institutions.values()]
      .sort((a, b) => a.id.localeCompare(b.id))
      .map((i) => [i.id, i.intakePeriods, [...i.programIds].sort()]),
  });
}

// ── La règle ────────────────────────────────────────────────────────────────

describe('reconduction — la règle des dates', () => {
  it('même jour et même mois, année + 1, pour août, septembre et octobre 2026', () => {
    expect(rollFallDate('01/10/2026')).toBe('01/10/2027');
    expect(rollFallDate('14/09/2026')).toBe('14/09/2027');
    expect(rollFallDate('31/08/2026')).toBe('31/08/2027');
    expect(rollFallDate('19/10/2026')).toBe('19/10/2027');
  });

  it('ne touche ni au printemps 2027, ni à une date déjà 2027, ni au texte libre', () => {
    for (const d of ['01/03/2027', '22/02/2027', '11/01/2027', '01/10/2027', '15/02/2026', 'Rentrée automne', '10/2026', '']) {
      expect(isFall2026Date(d)).toBe(false);
      expect(rollFallDate(d)).toBeNull();
    }
  });

  it('une rentrée jointe « · » est reconduite date par date ; mêlée, elle est signalée', () => {
    expect(rollIntakeText('14/09/2026 · 01/10/2026')).toEqual({
      kind: 'all',
      rolled: '14/09/2027 · 01/10/2027',
    });
    expect(rollIntakeText('01/03/2027')).toEqual({ kind: 'none' });
    expect(rollIntakeText(null)).toEqual({ kind: 'none' });
    expect(rollIntakeText('01/10/2026 · 01/03/2027')).toEqual({ kind: 'mixed' });
  });

  it('l’offre reconduite garde campus et prix et porte ses deux marques', () => {
    const offer = { campus: 'Paris', tuitionUpfront: 8850, tuitionInstallments: 9293, intake: '01/10/2026' };
    expect(rollSeedOffering(offer)).toEqual({
      campus: 'Paris',
      tuitionUpfront: 8850,
      tuitionInstallments: 9293,
      intake: '01/10/2027',
      rolledFromIntake: '01/10/2026',
      intakeEstimated: true,
    });
    const spring = { campus: 'Paris', tuitionUpfront: 6690, intake: '01/03/2027', session: 'spring' };
    expect(rollSeedOffering(spring)).toBe(spring);
  });

  it('la grille d’automne : 747 lignes, toutes datées d’août à octobre 2026', () => {
    expect(ROWS).toHaveLength(747);
    const months = new Map<string, number>();
    for (const r of ROWS) {
      const key = r.intakeDate ? r.intakeDate.slice(3) : '(sans date)';
      months.set(key, (months.get(key) ?? 0) + 1);
    }
    expect(Object.fromEntries(months)).toEqual({
      '08/2026': 19,
      '09/2026': 512,
      '10/2026': 216,
    });
  });
});

// ── Sur la vraie grille ─────────────────────────────────────────────────────

describe('roll:omnes-fall-2027 — après dedupe:omnes et import:omnes-spring', () => {
  let db: Db;
  let springBefore: string;
  let plan: OmnesFallRollPlan;

  beforeAll(() => {
    db = seededDb('production');
    runDedupe(db);
    runSpring(db);
    springBefore = JSON.stringify(
      [...db.programs.values()].map((p) => offersOf(p).filter((o) => o.session === 'spring')),
    );
    plan = planRoll(db);
  });

  it('reconduit toutes les offres d’automne 2026, sans en signaler aucune', () => {
    expect(plan.flagged).toEqual([]);
    const bySchool: Record<string, { formations: number; offres: number }> = {};
    for (const u of plan.programUpdates.filter((x) => x.isActive)) {
      const s = (bySchool[u.institutionId] ??= { formations: 0, offres: 0 });
      s.formations += 1;
      s.offres += u.rolled.length;
    }
    // Épinglé : une nouvelle grille d'automne fait échouer ce test, c'est voulu.
    expect(bySchool).toEqual({
      'omnes-ece': { formations: 54, offres: 70 },
      'omnes-esce': { formations: 46, offres: 55 },
      'omnes-heip': { formations: 10, offres: 20 },
      'omnes-inseec': { formations: 144, offres: 529 },
      'omnes-sup-de-pub': { formations: 26, offres: 73 },
    });
    // Les alias mis hors ligne par dedupe:omnes suivent (convergence des ordres).
    const offline = plan.programUpdates.filter((x) => !x.isActive);
    expect([offline.length, offline.reduce((n, u) => n + u.rolled.length, 0)]).toEqual([12, 12]);
    expect(plan.institutionUpdates.map((i) => i.id)).toEqual([
      'omnes-ece',
      'omnes-esce',
      'omnes-heip',
      'omnes-inseec',
      'omnes-sup-de-pub',
    ]);
  });

  it('après application : plus aucune rentrée d’automne 2026, printemps intact, écoles à jour', async () => {
    await applyOmnesFallRollPlan(fakeClient(db), plan);
    expect(allIntakeDates(db).filter(isFall2026Date)).toEqual([]);
    expect(
      JSON.stringify(
        [...db.programs.values()].map((p) => offersOf(p).filter((o) => o.session === 'spring')),
      ),
    ).toBe(springBefore);
    for (const inst of db.institutions.values()) {
      expect(inst.intakePeriods.filter(isFall2026Date)).toEqual([]);
      // Les dates de printemps de l'école sont toujours là.
      if (inst.id !== 'omnes-heip' && inst.id !== 'omnes-sup-de-pub') {
        expect(inst.intakePeriods.some((d) => d.endsWith('/2027') && Number(d.slice(3, 5)) <= 3)).toBe(true);
      }
    }
    // Chaque offre reconduite dit d'où elle vient.
    const rolled = [...db.programs.values()].flatMap((p) =>
      offersOf(p).filter((o) => o.intakeEstimated === true),
    );
    // 747 offres des fiches en ligne (une par ligne de la grille) + 12 des
    // alias hors ligne.
    expect(rolled.length).toBe(759);
    for (const o of rolled) {
      expect(rollIntakeText(o.rolledFromIntake)).toEqual({ kind: 'all', rolled: o.intake });
    }
  });

  it('rejouable : la seconde passe n’écrit rien, et dedupe / printemps non plus', async () => {
    expect(await runRoll(db)).toBe(0);
    expect(runSpring(db)).toBe(0);
    expect(runDedupe(db)).toBe(0);
    expect(await runRoll(db)).toBe(0);
  });
});

describe('roll:omnes-fall-2027 — ordre des opérations', () => {
  const ORDERS: [string, ('dedupe' | 'spring' | 'roll')[]][] = [
    ['dedupe → spring → roll (runbook)', ['dedupe', 'spring', 'roll']],
    ['dedupe → roll → spring', ['dedupe', 'roll', 'spring']],
    ['roll → dedupe → spring', ['roll', 'dedupe', 'spring']],
  ];

  async function play(order: ('dedupe' | 'spring' | 'roll')[]): Promise<Db> {
    const db = seededDb('production');
    for (const step of order) {
      if (step === 'dedupe') runDedupe(db);
      else if (step === 'spring') runSpring(db);
      else await runRoll(db);
    }
    return db;
  }

  it('tous les ordres convergent vers la même base, sans 2026 ni offre 2027 en double', async () => {
    const reference = snapshot(await play(ORDERS[0][1]));
    for (const [, order] of ORDERS.slice(1)) {
      const db = await play(order);
      expect(snapshot(db)).toBe(reference);
    }
    // Printemps AVANT dédoublonnage (hors runbook) : mêmes offres, seul leur
    // rang dans la liste change (les offres d'alias arrivent après celles de
    // printemps).
    const late = await play(['roll', 'spring', 'dedupe']);
    expect(snapshot(late, true)).toBe(snapshot(await play(ORDERS[0][1]), true));
    const db = await play(ORDERS[0][1]);
    expect(allIntakeDates(db).filter(isFall2026Date)).toEqual([]);
    for (const p of db.programs.values()) {
      const keys = offersOf(p).map((o) => `${String(o.campus)}#${String(o.intake)}`);
      expect(new Set(keys).size).toBe(keys.length);
    }
  });

  it('rejouer printemps puis reconduction (et l’inverse) après coup : 0 écriture', async () => {
    const db = await play(['dedupe', 'spring', 'roll']);
    expect(runSpring(db)).toBe(0);
    expect(await runRoll(db)).toBe(0);
    expect(await runRoll(db)).toBe(0);
    expect(runSpring(db)).toBe(0);
  });
});

describe('roll:omnes-fall-2027 — offres retouchées et garde updatedAt', () => {
  function firstWith(db: Db, pred: (p: DbProgram) => boolean): DbProgram {
    const hit = [...db.programs.values()].sort((a, b) => a.id.localeCompare(b.id)).find(pred);
    if (!hit) throw new Error('aucune fiche');
    return hit;
  }

  it('une offre retouchée à la main est signalée, jamais modifiée ; sa date reste à l’école', async () => {
    const db = seededDb('production');
    runDedupe(db);
    const ece = firstWith(db, (p) => p.institutionId === 'omnes-ece' && p.isActive);
    const [first, ...rest] = offersOf(ece);
    const edited: Record<string, unknown> = { ...first, tuitionUpfront: 1 };
    ece.campusOfferings = [edited, ...rest];
    // Une date corrigée à la main, inconnue de la grille.
    const esce = firstWith(db, (p) => p.institutionId === 'omnes-esce' && p.isActive);
    const [e0, ...eRest] = offersOf(esce);
    esce.campusOfferings = [{ ...e0, intake: '03/10/2026' }, ...eRest];
    // Un champ ajouté.
    const heip = firstWith(db, (p) => p.institutionId === 'omnes-heip');
    const [h0, ...hRest] = offersOf(heip);
    heip.campusOfferings = [{ ...h0, rhythm: 'alternance' }, ...hRest];

    const plan = planRoll(db);
    expect(plan.flagged.map((f) => [f.id, f.reason.split(' ')[0]])).toEqual(
      [
        [ece.id, 'prix'],
        [esce.id, 'date(s)'],
        [heip.id, 'champ(s)'],
      ].sort((a, b) => a[0].localeCompare(b[0])),
    );
    await applyOmnesFallRollPlan(fakeClient(db), plan);
    expect(offersOf(db.programs.get(ece.id)!)[0]).toEqual(edited);
    expect(offersOf(db.programs.get(esce.id)!)[0].intake).toBe('03/10/2026');
    // Le reste de la fiche est reconduit.
    expect(offersOf(db.programs.get(ece.id)!).slice(1).every((o) => !isFall2026Date(String(o.intake).split(' · ')[0]))).toBe(true);
    // L'école garde la date 2026 que l'offre signalée porte encore.
    const keptDate = String(edited.intake).split(' · ')[0];
    expect(db.institutions.get('omnes-ece')!.intakePeriods).toContain(keptDate);
    // Relancer : 0 écriture, les mêmes signalements.
    const again = planRoll(db);
    expect(omnesFallRollWriteCount(again)).toBe(0);
    expect(again.flagged).toHaveLength(3);
  });

  it('une formation inconnue de la grille (créée dans l’admin) est signalée', () => {
    const plan = planOmnesFallRoll(
      [
        {
          id: 'omnes-p-admin',
          institutionId: 'omnes-ece',
          nameFr: 'Fiche admin',
          campusOfferings: [{ campus: 'Paris', tuitionUpfront: 9000, tuitionInstallments: null, intake: '01/10/2026' }],
          updatedAt: new Date(0),
        },
      ],
      [],
      INDEX,
    );
    expect(plan.programUpdates).toEqual([]);
    expect(plan.flagged[0].reason).toMatch(/absente de la grille/);
  });

  it('une fiche retouchée entre la lecture et l’écriture est laissée intacte, son école aussi', async () => {
    const db = seededDb('production');
    const plan = planRoll(db);
    const target = plan.programUpdates.find((u) => u.institutionId === 'omnes-heip')!;
    // L'admin écrit la fiche après la lecture.
    const p = db.programs.get(target.id)!;
    const adminOffers = JSON.parse(JSON.stringify(p.campusOfferings));
    p.updatedAt = touch(db);
    const result = await applyOmnesFallRollPlan(fakeClient(db), plan);
    expect(result.raced).toEqual([target.id]);
    expect(result.skippedSchools).toEqual(['omnes-heip']);
    expect(p.campusOfferings).toEqual(adminOffers);
    expect(db.institutions.get('omnes-heip')!.intakePeriods.some(isFall2026Date)).toBe(true);
    // La relance reprend la fiche et l'école.
    const next = planRoll(db);
    expect(next.programUpdates.map((u) => u.id)).toEqual([target.id]);
    expect(next.institutionUpdates.map((i) => i.id)).toEqual(['omnes-heip']);
    await applyOmnesFallRollPlan(fakeClient(db), next);
    expect(omnesFallRollWriteCount(planRoll(db))).toBe(0);
  });
});

describe('seed:omnes — une base vierge naît reconduite', () => {
  it('aucune rentrée d’automne 2026, et la reconduction n’a rien à faire', async () => {
    const db = seededDb('fresh');
    expect(allIntakeDates(db).filter(isFall2026Date)).toEqual([]);
    for (const inst of db.institutions.values()) {
      expect(inst.intakePeriods.filter(isFall2026Date)).toEqual([]);
    }
    expect(omnesFallRollWriteCount(planRoll(db))).toBe(0);
    // Le printemps s'ajoute ensuite, et la reconduction reste à 0.
    expect(runSpring(db)).toBeGreaterThan(0);
    expect(await runRoll(db)).toBe(0);
    expect(runDedupe(db)).toBe(0);
  });
});
