import * as fs from 'node:fs';
import * as path from 'node:path';

import * as XLSX from 'xlsx';

import {
  catalogueUniqueInstitutions,
  catalogueUniquePrograms,
} from '../../common/data/catalogue-unique.seed';
import {
  type DedupeProgramState,
  type NamedRecord,
  OMNES_PROGRAM_ID_ALIASES,
  cleanOmnesFormationName,
  findHomonym,
  findProgramDuplicates,
  omnesDedupeWriteCount,
  omnesFormationIdentity,
  planOmnesDedupe,
  programNameKey,
  schoolNameKey,
} from './catalog-dedupe';
import { mockCatalog } from '../../common/data/mock-catalog';
import { PARTNER_INSTITUTION_SEEDS } from './data/partner-schools.seed';
import { IGENSIA_SCHOOLS, parseIgensiaSources } from './igensia-import';
import { type NaSource, naProgramId } from './north-america-import';
import {
  formatLevel,
  normalizeFormationName,
  omnesInstitutionId,
  omnesProgramId,
} from './omnes-conventions';
import { OMNES_SCHOOLS, parseOmnesSpringCsv } from './omnes-spring-import';
import {
  NON_SCHOOL_CSV_LABEL,
  TARGETS,
  assertTargetsAreSchools,
  normalizeLevel,
  parseCsv,
  stableId,
} from './partner-import';

/**
 * TEST-GARDE du catalogue : sur TOUS les seeds et imports (automne OMNES,
 * printemps OMNES, IGENSIA, Amérique du Nord, seed des écoles partenaires,
 * liste blanche d'import-partners, catalogue unique, catalogue de démo), aucune paire de formations d'une même
 * école n'a le même nom normalisé et le même niveau, et aucune école n'est en
 * double par son nom normalisé.
 *
 * Une nouvelle grille qui écrit une formation connue autrement (casse, accent,
 * campus dans le nom…) fait échouer ce test : ajouter la variante à
 * OMNES_PROGRAM_ID_ALIASES (catalog-dedupe.ts).
 */
const DATA = path.join(__dirname, '..', '..', '..', 'scripts', 'data');

type GridRow = { school: string; campus: string; programName: string; programFamily: string; degreeLevel: string };

function fallRows(): GridRow[] {
  const book = XLSX.readFile(path.join(DATA, 'omnes_fall_26.xlsx'));
  const rows: Record<string, unknown>[] = XLSX.utils.sheet_to_json(book.Sheets[book.SheetNames[0]], { defval: '' });
  return rows
    .map((r) => ({
      school: String(r['Ecole / School'] ?? '').trim(),
      campus: String(r['Campus'] ?? '').trim(),
      programName: String(r['NOM / NAME'] ?? '').trim(),
      programFamily: String(r['Type_Programme / Type of program'] ?? '').trim(),
      degreeLevel: String(r['Niveau_Etude_ / Level of studies'] ?? '').trim(),
    }))
    .filter((r) => r.school && r.programName);
}

const FALL = fallRows();
const NORTH_AMERICA = JSON.parse(
  fs.readFileSync(path.join(DATA, 'amerique-du-nord-2027.json'), 'utf8'),
) as NaSource;
const SPRING = parseOmnesSpringCsv(fs.readFileSync(path.join(DATA, 'omnes_spring_27.csv'), 'utf8')).rows;

function omnesRecords(rows: readonly GridRow[], source: string, resolve: boolean): NamedRecord[] {
  return rows.map((r) => {
    const legacyName = normalizeFormationName(r.programName, r.campus);
    const identity = omnesFormationIdentity(r.school, r.programName, r.campus);
    return {
      school: omnesInstitutionId(r.school),
      id: resolve ? identity.id : omnesProgramId(r.school, legacyName),
      name: r.programName,
      campus: r.campus,
      level: formatLevel(r).fr,
      source,
    };
  });
}

describe('catalogue — aucune formation en double dans une école', () => {
  it('OMNES automne + printemps : chaque formation retombe sur UNE fiche', () => {
    const records = [...omnesRecords(FALL, 'automne', true), ...omnesRecords(SPRING, 'printemps', true)];
    expect(findProgramDuplicates(records)).toEqual([]);
  });

  it('compte les doublons avant / après la table de rapprochement', () => {
    const before = [...omnesRecords(FALL, 'automne', false), ...omnesRecords(SPRING, 'printemps', false)];
    const after = [...omnesRecords(FALL, 'automne', true), ...omnesRecords(SPRING, 'printemps', true)];
    const ids = (rs: NamedRecord[], source?: string) =>
      new Set(rs.filter((r) => !source || r.source === source).map((r) => r.id)).size;
    // Automne : 292 fiches dont 12 variantes ; printemps : 127 formations dont 5.
    expect([ids(before, 'automne'), ids(after, 'automne')]).toEqual([292, 280]);
    expect([ids(before, 'printemps'), ids(after, 'printemps')]).toEqual([127, 122]);
    expect([ids(before), ids(after)]).toEqual([329, 308]);
    // Tous les doublons détectés par la clé sont couverts par la table.
    const extra = findProgramDuplicates(before).reduce((n, g) => n + g.ids.length - 1, 0);
    expect(extra).toBe(18);
  });

  it('la table de rapprochement est explicite, sans chaîne, et ne déplace aucun id d’automne', () => {
    const fallIds = new Set(omnesRecords(FALL, 'automne', false).map((r) => r.id));
    const gridIds = new Set([...fallIds, ...omnesRecords(SPRING, 'printemps', false).map((r) => r.id)]);
    const springOnly = new Set(omnesRecords(SPRING, 'printemps', false).map((r) => r.id).filter((id) => !fallIds.has(id)));
    for (const [alias, { canonical, reason }] of Object.entries(OMNES_PROGRAM_ID_ALIASES)) {
      expect(gridIds.has(alias)).toBe(true);
      expect(gridIds.has(canonical)).toBe(true);
      expect(OMNES_PROGRAM_ID_ALIASES[canonical]).toBeUndefined();
      expect(reason.length).toBeGreaterThan(10);
      // L'id canonique est celui du seed d'automne, sauf formation inconnue
      // de l'automne (les deux ids viennent alors du printemps).
      if (!fallIds.has(canonical)) expect(springOnly.has(alias)).toBe(true);
    }
    // Une fiche d'automne qui n'est pas un alias garde son id : le seed
    // rejoué ne crée ni ne renomme rien d'autre.
    for (const r of FALL) {
      const legacy = omnesProgramId(r.school, normalizeFormationName(r.programName, r.campus));
      const { id } = omnesFormationIdentity(r.school, r.programName, r.campus);
      if (!OMNES_PROGRAM_ID_ALIASES[legacy]) expect(id).toBe(legacy);
    }
  });

  it('IGENSIA : aucune formation en double', () => {
    const { formations } = parseIgensiaSources(
      fs.readFileSync(path.join(DATA, 'igensia_2027.csv'), 'utf8'),
      fs.readFileSync(path.join(DATA, 'abc_2027.csv'), 'utf8'),
    );
    expect(
      findProgramDuplicates(formations.map((f) => ({ school: f.schoolId, id: f.id, name: f.name, level: f.level }))),
    ).toEqual([]);
  });

  it('Amérique du Nord : aucune formation en double', () => {
    const records = NORTH_AMERICA.institutions.flatMap((i) =>
      i.programs.map((p) => ({ school: i.id, id: naProgramId(i.id, p.slug), name: p.nameFr, level: p.level })),
    );
    expect(records.length).toBeGreaterThan(0);
    expect(findProgramDuplicates(records)).toEqual([]);
  });

  it('seed des écoles partenaires et catalogue unique : aucune formation en double', () => {
    const partner = PARTNER_INSTITUTION_SEEDS.flatMap((i) =>
      i.programs.map((p) => ({ school: i.id, id: p.id, name: p.nameFr, level: p.levelFr })),
    );
    expect(findProgramDuplicates(partner)).toEqual([]);
    const unique = catalogueUniquePrograms.map((p) => ({
      school: p.institutionId,
      id: p.id,
      name: p.nameFr,
      level: p.levelFr,
    }));
    expect(findProgramDuplicates(unique)).toEqual([]);
  });

  it('liste blanche d’import-partners : aucune formation en double', () => {
    const rows = parseCsv(fs.readFileSync(path.join(DATA, 'universites-partenaires.csv'), 'utf8'));
    const records = TARGETS.flatMap((t) =>
      rows
        .filter((r) => r.Institution === t.csvName)
        .map((r) => ({
          school: t.id,
          id: stableId('partner-p-', `${t.id}|${r.Programme.trim()}`),
          name: r.Programme,
          level: normalizeLevel(r.Niveau),
        })),
    );
    expect(records.length).toBeGreaterThan(0);
    expect(findProgramDuplicates(records)).toEqual([]);
  });
});

describe('catalogue — aucune école en double', () => {
  const schools = new Map<string, string>();
  for (const s of OMNES_SCHOOLS) schools.set(omnesInstitutionId(s), s);
  for (const s of IGENSIA_SCHOOLS) schools.set(s.id, s.nameFr);
  for (const s of PARTNER_INSTITUTION_SEEDS) schools.set(s.id, s.nameFr);
  for (const s of TARGETS) schools.set(s.id, s.nameFr);
  for (const s of catalogueUniqueInstitutions) schools.set(s.id, s.nameFr);
  // Les deux noms d'un établissement (« Université McGill » / « McGill
  // University ») : aucun ne doit rejoindre une école déjà connue. Le nom
  // anglais n'est compté que s'il diffère du français.
  const both = (id: string, fr: string, en: string) => {
    schools.set(id, fr);
    if (schoolNameKey(en) !== schoolNameKey(fr)) schools.set(`${id}#en`, en);
  };
  for (const s of mockCatalog.institutions) both(s.id, s.name.fr, s.name.en);
  // Sans le sigle final (« … (UQAM) ») : c'est la clé d'homonymie de l'import.
  const bare = (n: string) => n.replace(/\s*\([^()]*\)\s*$/, '');
  for (const s of NORTH_AMERICA.institutions) both(s.id, bare(s.nameFr), bare(s.nameEn));

  it('pas deux ids pour un même nom normalisé', () => {
    const byKey = new Map<string, string[]>();
    for (const [id, name] of schools) {
      const key = schoolNameKey(name);
      byKey.set(key, [...(byKey.get(key) ?? []), id]);
    }
    expect([...byKey.entries()].filter(([, ids]) => ids.length > 1)).toEqual([]);
  });

  it('Amérique du Nord : l’Université d’Ottawa reste la seule fiche `uottawa`', () => {
    const keys = [...schools.entries()].filter(([, n]) => schoolNameKey(n).includes('ottawa'));
    expect(keys.map(([id]) => id.replace(/#en$/, ''))).toEqual(['uottawa', 'uottawa']);
  });

  it('IGENSIA : quatre écoles distinctes d’ESA Casablanca, pas d’école « IGENSIA » seule', () => {
    const keys = [...schools.values()].map(schoolNameKey);
    expect(keys).not.toContain('igensia');
    expect(keys).not.toContain('igensiaeducation');
    expect(schools.get('partner-esa-casa')).toBe('ESA Casablanca (IGENSIA Education)');
    expect(IGENSIA_SCHOOLS.map((s) => s.id)).not.toContain('partner-esa-casa');
  });

  it('les blocs « — Rentrée décalée 2027 » du CSV ne deviennent jamais des écoles', () => {
    const labels = new Set(
      parseCsv(fs.readFileSync(path.join(DATA, 'universites-partenaires.csv'), 'utf8')).map((r) => r.Institution),
    );
    const blocks = [...labels].filter((l) => NON_SCHOOL_CSV_LABEL.test(l));
    expect(blocks.sort()).toEqual([
      'ECE — Rentrée décalée 2027',
      'ESCE — Rentrée décalée 2027',
      'INSEEC — Rentrée décalée 2027',
    ]);
    expect([...schools.values()].some((n) => NON_SCHOOL_CSV_LABEL.test(n))).toBe(false);
    expect(assertTargetsAreSchools(TARGETS)).toEqual([]);
    expect(
      assertTargetsAreSchools([
        { ...TARGETS[0], id: 'x', csvName: 'INSEEC — Rentrée décalée 2027', nameFr: 'INSEEC — Rentrée décalée 2027' },
      ]),
    ).toHaveLength(1);
  });
});

describe('catalog-dedupe — clés et homonymes', () => {
  it('ignore casse, accents, espaces, tirets, campus collé et segment répété', () => {
    const k = (n: string, c?: string) => programNameKey(n, c);
    expect(k('BCh - B1 - Activités Commerciales')).toBe(k('BCh - B1 - Activités commerciales'));
    expect(k('BCh- Bordeaux - B1 - Luxe', 'Bordeaux')).toBe(k('BCh - B1 - Luxe'));
    expect(k('Business Developpement')).toBe(k('Business Development'));
    expect(k('IMSc - M1 - M1 - Chef de projet')).toBe(k('IMSc - M1 - Chef de projet'));
    expect(k('ECE - MSc CGE Paris - M1 - AI (100% English)', 'Paris')).toBe(k('ECE - MSc CGE - M1 - AI - 100% English'));
    // Mais un autre niveau d'année reste une autre formation, et « Start-up »
    // n'est pas coupé.
    expect(k('BCh - B1 - Luxe')).not.toBe(k('BCh - B2 - Luxe'));
    expect(k('Business & Start-up')).toBe('businessstartup');
  });

  it('nettoie l’intitulé affiché sans toucher à l’id', () => {
    expect(cleanOmnesFormationName('BCh- Rennes - B1 - Banque Assurance', 'Rennes')).toBe('BCh - B1 - Banque Assurance');
    expect(cleanOmnesFormationName('SDP - SP5 -Stratégie digitale', 'Paris')).toBe('SDP - SP5 - Stratégie digitale');
    expect(omnesFormationIdentity('INSEEC', 'BCh- Rennes - B1 - Banque Assurance', 'Rennes')).toEqual({
      id: 'omnes-p-bf33379880d7cebf',
      name: 'BCh - B1 - Banque Assurance',
      isAlias: true,
    });
  });

  it('repère une fiche homonyme saisie à la main sous un autre id', () => {
    const existing = [{ id: 'cl-1', institutionId: 'omnes-ece', nameFr: 'ECE - B1 - Cybersecurite et Reseaux', levelFr: 'Bachelor' }];
    const candidate = { id: 'omnes-p-x', institutionId: 'omnes-ece', nameFr: 'ECE - B1 - Cybersécurité et réseaux', levelFr: 'Bachelor' };
    expect(findHomonym(candidate, existing)).toBe('cl-1');
    expect(findHomonym({ ...candidate, levelFr: 'Master' }, existing)).toBeNull();
    expect(findHomonym({ ...candidate, institutionId: 'omnes-esce' }, existing)).toBeNull();
  });
});

describe('dedupe:omnes — fusion des doublons déjà en base', () => {
  const at = new Date('2026-09-01T00:00:00Z');
  const row = (id: string, nameFr: string, offerings: unknown[], isActive = true): DedupeProgramState => ({
    id,
    nameFr,
    nameEn: nameFr,
    campusOfferings: offerings,
    isActive,
    updatedAt: at,
  });

  it('complète la fiche canonique, nettoie son nom, met l’alias hors ligne — puis 0 écriture', () => {
    const canonical = 'omnes-p-bf33379880d7cebf';
    const programs = new Map<string, DedupeProgramState>([
      [canonical, row(canonical, 'BCh - B1 - Banque Assurance', [{ campus: 'Paris', tuitionUpfront: 1, tuitionInstallments: null, intake: '16/09/2026' }])],
      ['omnes-p-6e6b2568f651ba68', row('omnes-p-6e6b2568f651ba68', 'BCh - Chambéry- B1 - Banque Assurance', [{ campus: 'Chambéry', tuitionUpfront: 2, tuitionInstallments: null, intake: '01/09/2026' }])],
      ['omnes-p-4f9563b0a1a1358f', row('omnes-p-4f9563b0a1a1358f', 'BCh- Rennes - B1 - Banque Assurance', [{ campus: 'Rennes', tuitionUpfront: 3, tuitionInstallments: null, intake: '16/09/2026' }])],
      // Fiche canonique au nom pollué par son campus, sans alias.
      ['omnes-p-ece', row('omnes-p-ece', 'ECE - PGE - Paris- ING4 - Data & AI', [{ campus: 'Paris', intake: '01/10/2026' }])],
    ]);
    const plan = planOmnesDedupe(programs);
    const update = plan.canonicalUpdates.find((u) => u.id === canonical)!;
    expect(update.added).toBe(2);
    expect((update.merged as { campus: string }[]).map((o) => o.campus)).toEqual(['Paris', 'Chambéry', 'Rennes']);
    // L'offre existante est recopiée telle quelle, en tête.
    expect(update.merged![0]).toBe((programs.get(canonical)!.campusOfferings as unknown[])[0]);
    expect(update.rename).toBeNull();
    expect(plan.deactivations.map((d) => d.id).sort()).toEqual(['omnes-p-4f9563b0a1a1358f', 'omnes-p-6e6b2568f651ba68']);
    expect(plan.canonicalUpdates.find((u) => u.id === 'omnes-p-ece')?.rename).toEqual({
      nameFr: 'ECE - PGE - ING4 - Data & AI',
      nameEn: 'ECE - PGE - ING4 - Data & AI',
    });

    // Application en mémoire, puis relance.
    for (const u of plan.canonicalUpdates) {
      const p = programs.get(u.id)!;
      programs.set(u.id, { ...p, ...(u.merged ? { campusOfferings: u.merged } : {}), ...(u.rename ?? {}) });
    }
    for (const d of plan.deactivations) programs.set(d.id, { ...programs.get(d.id)!, isActive: false });
    expect(omnesDedupeWriteCount(planOmnesDedupe(programs))).toBe(0);
  });

  it('laisse tel quel un alias dont la fiche canonique est absente', () => {
    const programs = new Map([['omnes-p-6e6b2568f651ba68', row('omnes-p-6e6b2568f651ba68', 'BCh - Chambéry- B1 - Banque Assurance', [])]]);
    const plan = planOmnesDedupe(programs);
    expect(plan.orphans).toEqual([{ id: 'omnes-p-6e6b2568f651ba68', canonical: 'omnes-p-bf33379880d7cebf' }]);
    expect(plan.deactivations).toEqual([]);
  });

  it('sur l’état du seed d’automne : 12 alias hors ligne, aucun id d’automne déplacé', () => {
    const programs = new Map<string, DedupeProgramState>();
    for (const r of FALL) {
      const name = normalizeFormationName(r.programName, r.campus);
      const id = omnesProgramId(r.school, name);
      const p = programs.get(id) ?? row(id, name, []);
      (p.campusOfferings as unknown[]).push({ campus: r.campus, tuitionUpfront: null, tuitionInstallments: null, intake: null });
      programs.set(id, p);
    }
    const plan = planOmnesDedupe(programs);
    expect(plan.deactivations).toHaveLength(12);
    expect(plan.orphans).toEqual([]);
    for (const d of plan.deactivations) expect(programs.has(d.canonical)).toBe(true);
  });
});
