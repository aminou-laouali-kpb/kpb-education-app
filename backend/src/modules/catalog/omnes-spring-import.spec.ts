import * as fs from 'node:fs';
import * as path from 'node:path';

import * as XLSX from 'xlsx';

import {
  normalizeFormationName,
  omnesInstitutionId,
  omnesProgramId,
  toNumberOrNull,
} from './omnes-conventions';
import {
  type ExistingInstitutionState,
  type ExistingProgramState,
  type OmnesSpringPlan,
  OMNES_SCHOOLS,
  groupSpringFormations,
  parseOmnesSpringCsv,
  planOmnesSpring,
  planWriteCount,
} from './omnes-spring-import';

/**
 * Le script d'import ne tourne pas ici (il lui faut une base) : sa moitié pure
 * est épinglée contre la VRAIE grille livrée (scripts/data/omnes_spring_27.csv,
 * extraite du PDF) et contre l'état que le seed d'automne laisse en base,
 * reconstruit depuis scripts/data/omnes_fall_26.xlsx avec les mêmes règles.
 */
const DATA = path.join(__dirname, '..', '..', '..', 'scripts', 'data');
const SPRING_CSV = fs.readFileSync(path.join(DATA, 'omnes_spring_27.csv'), 'utf8');

const FIELD_IDS = new Set(
  Array.from({ length: 12 }, (_, i) => `d${String(i + 1).padStart(2, '0')}`),
);

/// L'état de la base après `seed:omnes` : une fiche par formation, une offre
/// par campus (premier prix connu, dates jointes par « · »), comme le seed.
function fallState(): {
  programs: Map<string, ExistingProgramState>;
  institutions: Map<string, ExistingInstitutionState>;
} {
  const sheet = XLSX.readFile(path.join(DATA, 'omnes_fall_26.xlsx'));
  const rows: Record<string, unknown>[] = XLSX.utils.sheet_to_json(
    sheet.Sheets[sheet.SheetNames[0]],
    { defval: '' },
  );
  type Acc = { institutionId: string; offerings: Map<string, { price: number | null; inst: number | null; intakes: string[] }> };
  const formations = new Map<string, Acc>();
  const institutions = new Map<string, ExistingInstitutionState>();
  for (const r of rows) {
    const school = String(r['Ecole / School'] ?? '').trim();
    const name = String(r['NOM / NAME'] ?? '').trim();
    if (!OMNES_SCHOOLS.includes(school) || !name) continue;
    const campus = String(r['Campus'] ?? '').trim() || '—';
    const id = omnesProgramId(school, normalizeFormationName(name, campus));
    const instId = omnesInstitutionId(school);
    const intake = String(r['Date_de_Rentrée / Intake Date'] ?? '').trim();
    const acc = formations.get(id) ?? { institutionId: instId, offerings: new Map() };
    const offer = acc.offerings.get(campus) ?? { price: null, inst: null, intakes: [] };
    if (offer.price == null) offer.price = toNumberOrNull(r['Payment Comptant / Payment Upfront']);
    if (offer.inst == null) offer.inst = toNumberOrNull(r['Paiement Echelonné / With installments (2)']);
    if (intake && !offer.intakes.includes(intake)) offer.intakes.push(intake);
    acc.offerings.set(campus, offer);
    formations.set(id, acc);
    const inst = institutions.get(instId) ?? { id: instId, intakePeriods: [], programIds: [] };
    if (intake && !inst.intakePeriods.includes(intake)) inst.intakePeriods.push(intake);
    if (!inst.programIds.includes(id)) inst.programIds.push(id);
    institutions.set(instId, inst);
  }
  const programs = new Map<string, ExistingProgramState>();
  for (const [id, acc] of formations) {
    programs.set(id, {
      id,
      institutionId: acc.institutionId,
      updatedAt: new Date('2026-06-25T12:00:00Z'),
      campusOfferings: [...acc.offerings.entries()].map(([campus, o]) => ({
        campus,
        tuitionUpfront: o.price,
        tuitionInstallments: o.inst,
        intake: o.intakes.join(' · ') || null,
      })),
    });
  }
  return { programs, institutions };
}

/// Ce que le script écrirait, joué sur une copie en mémoire de l'état.
function applyInMemory(
  plan: OmnesSpringPlan,
  programs: Map<string, ExistingProgramState>,
  institutions: Map<string, ExistingInstitutionState>,
) {
  for (const a of plan.additions) {
    const p = programs.get(a.id)!;
    programs.set(a.id, { ...p, campusOfferings: a.merged, updatedAt: new Date() });
  }
  for (const c of plan.creations) {
    programs.set(c.id, {
      id: c.id,
      institutionId: c.institutionId,
      campusOfferings: JSON.parse(JSON.stringify(c.campusOfferings)),
      updatedAt: new Date(),
    });
  }
  for (const i of plan.institutions) {
    const inst = institutions.get(i.id)!;
    institutions.set(i.id, {
      ...inst,
      intakePeriods: [...inst.intakePeriods, ...i.addIntakePeriods],
      programIds: [...inst.programIds, ...i.addProgramIds],
    });
  }
}

describe('import:omnes-spring — lecture de la grille SPRING 27', () => {
  const { rows, errors } = parseOmnesSpringCsv(SPRING_CSV);

  // Comptes relevés sur le PDF : 286 dates de rentrée, une par ligne (le texte
  // extrait par pdftotext en compte autant), réparties comme ci-dessous. HEIP
  // et Sup de Pub figurent dans le filtre du PDF mais n'ont aucune ligne.
  it('lit les 286 lignes, sans erreur : ECE 18, ESCE 17, INSEEC 251', () => {
    expect(errors).toEqual([]);
    expect(rows).toHaveLength(286);
    const bySchool: Record<string, number> = {};
    for (const r of rows) bySchool[r.school] = (bySchool[r.school] ?? 0) + 1;
    expect(bySchool).toEqual({ ECE: 18, ESCE: 17, INSEEC: 251 });
  });

  it('ne contient aucune ligne hors des écoles OMNES connues', () => {
    expect(rows.every((r) => OMNES_SCHOOLS.includes(r.school))).toBe(true);
  });

  it('refuse une école inconnue, un rythme ou une langue inconnus, une date illisible', () => {
    const header = SPRING_CSV.split('\n')[0];
    const bad = [
      header,
      'IUM,Bachelor,Bac+3,Bachelor 1ère année,FR,CLA,Paris,IUM - Paris - B1 - X,1,2,01/03/2027',
      'ECE,Bachelor,Bac+3,Bachelor 1ère année,FR,MIX,Paris,ECE - Paris - B1 - X,1,2,01/03/2027',
      'ECE,Bachelor,Bac+3,Bachelor 1ère année,DE,CLA,Paris,ECE - Paris - B1 - X,1,2,01/03/2027',
      'ECE,Bachelor,Bac+3,Bachelor 1ère année,FR,CLA,Paris,ECE - Paris - B1 - X,1,2,mars 2027',
    ].join('\n');
    const parsed = parseOmnesSpringCsv(bad);
    expect(parsed.rows).toEqual([]);
    expect(parsed.errors).toHaveLength(4);
    expect(parsed.errors[0]).toMatch(/école inconnue « IUM »/);
    expect(parsed.errors[1]).toMatch(/rythme inconnu/);
    expect(parsed.errors[2]).toMatch(/langue inconnue/);
    expect(parsed.errors[3]).toMatch(/date de rentrée illisible/);
  });

  it('refuse une grille à laquelle il manque une colonne', () => {
    const parsed = parseOmnesSpringCsv('Ecole / School,Campus\nECE,Paris\n');
    expect(parsed.errors[0]).toMatch(/Colonnes absentes/);
  });
});

describe('import:omnes-spring — regroupement et identifiants', () => {
  const formations = groupSpringFormations(parseOmnesSpringCsv(SPRING_CSV).rows);

  it('regroupe 286 lignes en 122 formations portant 286 offres de printemps', () => {
    // 127 avant la table de rapprochement : 5 variantes d'écriture (casse,
    // campus dans le nom) faisaient chacune une fiche de plus.
    expect(formations).toHaveLength(122);
    const offers = formations.flatMap((f) => f.offerings);
    expect(offers).toHaveLength(286);
    expect(offers.every((o) => o.session === 'spring')).toBe(true);
    expect(offers.every((o) => o.rhythm === 'initiale' || o.rhythm === 'alternance')).toBe(true);
  });

  it('garde des identifiants stables, ceux du seed d’automne', () => {
    // « ECE - Paris - B1 - Cybersécurité et réseaux » : même formation qu'à
    // l'automne, donc même fiche.
    const cyber = formations.find((f) => f.name === 'ECE - B1 - Cybersécurité et réseaux');
    expect(cyber?.id).toBe('omnes-p-dc41accace3b7cf8');
    expect(cyber?.institutionId).toBe('omnes-ece');
    expect(new Set(formations.map((f) => f.id)).size).toBe(formations.length);
  });

  it('fait retomber une variante d’écriture sur la fiche d’automne existante', () => {
    // Printemps : « Activités Commerciales » ; automne : « commerciales ».
    const ids = (needle: RegExp) => formations.filter((f) => needle.test(f.name)).map((f) => f.id);
    expect(ids(/^BCh - B1 - Activités commerciales à l'International$/i)).toEqual([
      'omnes-p-5b5225f2346bc062',
    ]);
    // « BCh- Bordeaux - B1 - Luxe… » : le campus ne reste pas dans le nom.
    const luxe = formations.filter((f) => /B1 - Luxe et services/.test(f.name));
    expect(luxe.map((f) => f.id)).toEqual(['omnes-p-c9a108240d695bd0']);
    expect(luxe[0].name).toBe('BCh - B1 - Luxe et services personnalisés – Resp. d’activités commerciales');
    expect(luxe[0].offerings.map((o) => o.campus)).toContain('Bordeaux');
  });

  it('range chaque formation dans un domaine d01..d12', () => {
    expect(formations.every((f) => FIELD_IDS.has(f.fieldId))).toBe(true);
  });

  it('garde le prix de printemps propre à chaque offre', () => {
    const cyber = formations.find((f) => f.name === 'ECE - B1 - Cybersécurité et réseaux')!;
    expect(cyber.offerings).toEqual([
      {
        campus: 'Paris',
        tuitionUpfront: 6690,
        tuitionInstallments: 7025,
        intake: '01/03/2027',
        session: 'spring',
        rhythm: 'initiale',
      },
    ]);
  });
});

describe('import:omnes-spring — plan contre l’état laissé par le seed d’automne', () => {
  const formations = groupSpringFormations(parseOmnesSpringCsv(SPRING_CSV).rows);

  it('complète 94 formations connues (238 offres) et en crée 28 (48 offres)', () => {
    const { programs, institutions } = fallState();
    const plan = planOmnesSpring(formations, programs, institutions);
    expect(plan.errors).toEqual([]);
    expect(plan.additions).toHaveLength(94);
    expect(plan.additions.reduce((n, a) => n + a.added.length, 0)).toBe(238);
    expect(plan.creations).toHaveLength(28);
    expect(plan.creations.reduce((n, c) => n + c.campusOfferings.length, 0)).toBe(48);
    expect(plan.unchanged).toEqual([]);
    // Chaque nouvelle formation est rattachée à son école et listée chez elle.
    const listed = plan.institutions.flatMap((i) => i.addProgramIds);
    expect(listed.sort()).toEqual(plan.creations.map((c) => c.id).sort());
    expect(plan.creations.every((c) => c.tuitionMinEur != null && c.teachingLanguages.length > 0)).toBe(true);
  });

  it('n’écrit rien quand on le rejoue après application (idempotence)', () => {
    const { programs, institutions } = fallState();
    applyInMemory(planOmnesSpring(formations, programs, institutions), programs, institutions);
    const replay = planOmnesSpring(formations, programs, institutions);
    expect(planWriteCount(replay)).toBe(0);
    expect(replay.unchanged).toHaveLength(122);
  });

  it('ne modifie jamais une offre existante ni une fiche retouchée (additivité)', () => {
    const { programs, institutions } = fallState();
    const id = 'omnes-p-dc41accace3b7cf8';
    const touched = { campus: 'Paris', tuitionUpfront: 1234, tuitionInstallments: null, intake: '01/10/2026', note: 'retouché' };
    programs.set(id, { ...programs.get(id)!, campusOfferings: [touched] });
    const plan = planOmnesSpring(formations, programs, institutions);
    const addition = plan.additions.find((a) => a.id === id)!;
    expect(addition.merged[0]).toBe(touched);
    expect(addition.merged).toHaveLength(2);
    // Le plan ne porte QUE `campusOfferings` : aucun autre champ de la fiche.
    expect(Object.keys(addition).sort()).toEqual(
      ['added', 'expectedUpdatedAt', 'id', 'institutionId', 'merged', 'name'],
    );
    // Les dates d'école déjà présentes ne sont pas réécrites, seulement complétées.
    for (const inst of plan.institutions) {
      const before = institutions.get(inst.id)!;
      expect(inst.addIntakePeriods.some((d) => before.intakePeriods.includes(d))).toBe(false);
    }
  });

  it('écarte, sans l’écrire, une fiche connue dont les offres ont été vidées', () => {
    const { programs, institutions } = fallState();
    const id = 'omnes-p-dc41accace3b7cf8';
    programs.set(id, { ...programs.get(id)!, campusOfferings: null });
    const plan = planOmnesSpring(formations, programs, institutions);
    expect(plan.skipped.map((s) => s.id)).toEqual([id]);
    expect(plan.additions.some((a) => a.id === id)).toBe(false);
  });

  it('ne crée pas une formation dont une homonyme est déjà en base sous un autre id', () => {
    const { programs, institutions } = fallState();
    const plan0 = planOmnesSpring(formations, programs, institutions);
    const target = plan0.creations[0];
    // Fiche saisie à la main dans l'admin : autre id, même nom à la casse près.
    const manual = {
      id: 'cl-admin-123',
      institutionId: target.institutionId,
      nameFr: target.nameFr.toUpperCase(),
      levelFr: target.levelFr,
    };
    const plan = planOmnesSpring(formations, programs, institutions, [manual]);
    expect(plan.creations.map((c) => c.id)).not.toContain(target.id);
    expect(plan.skipped.find((s) => s.id === target.id)?.reason).toMatch(/homonyme.*cl-admin-123/);
    expect(plan.institutions.flatMap((i) => i.addProgramIds)).not.toContain(target.id);
  });

  it('refuse de travailler sans les écoles du seed d’automne', () => {
    const { programs } = fallState();
    const plan = planOmnesSpring(formations, programs, new Map());
    expect(plan.errors.join(' ')).toMatch(/omnes-ece.*seed:omnes/);
    expect(planWriteCount(plan)).toBe(0);
  });
});
