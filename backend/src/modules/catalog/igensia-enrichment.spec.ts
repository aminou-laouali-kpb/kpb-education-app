import * as fs from 'node:fs';
import * as path from 'node:path';

import { IGENSIA_FORMATION_FACTS, recognitionWithFacts } from './igensia-enrichment';
import {
  IGENSIA_SCHOOLS,
  type IgensiaExistingInstitution,
  type IgensiaExistingProgram,
  INSTITUTION_FILLABLE,
  PROGRAM_FILLABLE,
  factsFor,
  firstVersionOf,
  igensiaInstitutionCreateData,
  igensiaPlanWriteCount,
  igensiaProgramCreateData,
  parseIgensiaSources,
  planIgensia,
} from './igensia-import';

/**
 * Les faits relevés sur les sites officiels (16/10/2026) : chacun a sa source,
 * aucun ne touche aux prix ni aux rentrées des sources du propriétaire, et une
 * fiche déjà en base n'est comblée que là où l'admin n'a rien écrit.
 */
const DATA = path.join(__dirname, '..', '..', '..', 'scripts', 'data');
const IGENSIA_CSV = fs.readFileSync(path.join(DATA, 'igensia_2027.csv'), 'utf8');
const ABC_CSV = fs.readFileSync(path.join(DATA, 'abc_2027.csv'), 'utf8');
const PROVENANCE = fs.readFileSync(path.join(DATA, 'igensia_2027.sources.md'), 'utf8');
const { formations } = parseIgensiaSources(IGENSIA_CSV, ABC_CSV);
const schoolOf = (id: string) => IGENSIA_SCHOOLS.find((s) => s.id === id)!;

/** La base telle que la PREMIÈRE version de l'import l'a laissée. */
function firstVersionState() {
  const programs = new Map<string, IgensiaExistingProgram>();
  const institutions = new Map<string, IgensiaExistingInstitution>();
  const at = new Date('2026-10-16T10:00:00Z');
  for (const school of IGENSIA_SCHOOLS) {
    const own = formations.filter((f) => f.schoolId === school.id);
    const inst = igensiaInstitutionCreateData(firstVersionOf(school), own);
    institutions.set(school.id, { ...inst, updatedAt: at });
    for (const f of own) {
      const p = igensiaProgramCreateData(f, school, { withWebFacts: false });
      programs.set(p.id, { ...p, campusOfferings: JSON.parse(JSON.stringify(p.campusOfferings)), updatedAt: at });
    }
  }
  return { programs, institutions };
}

describe('import:igensia — faits des sites officiels', () => {
  it('rattache chaque fait à une formation des sources, et seule « Data Digital Business » reste sans page', () => {
    const keys = new Set(formations.map((f) => `${f.schoolId}|${f.name}`));
    expect(Object.keys(IGENSIA_FORMATION_FACTS).filter((k) => !keys.has(k))).toEqual([]);
    expect(formations.filter((f) => !factsFor(f)).map((f) => f.name)).toEqual([
      'Bachelor Data Digital Business',
    ]);
  });

  it('porte une source pour chaque fait, consignée dans le fichier de provenance', () => {
    for (const facts of Object.values(IGENSIA_FORMATION_FACTS)) {
      expect(facts.pageUrl).toMatch(/^https:\/\/www\.(igensia-school-of-business\.fr|igensiatech\.fr|igensia-rh\.com|american-business-college-paris\.com)\//);
      expect(PROVENANCE).toContain(facts.pageUrl);
      if (facts.rncp) {
        expect(facts.rncp.code).toMatch(/^RNCP\d{5}$/);
        expect(facts.rncp.url).toBe(`https://www.francecompetences.fr/recherche/rncp/${facts.rncp.code.slice(4)}/`);
        expect(PROVENANCE).toContain(facts.rncp.url);
        expect(PROVENANCE).toContain(facts.rncp.title);
      }
      if (facts.language) expect(facts.language.evidence).toMatch(/^« .+ »$/);
    }
    for (const school of IGENSIA_SCHOOLS) {
      if (school.applicationUrl && school.id === 'igensia-abc') expect(PROVENANCE).toContain(school.applicationUrl);
    }
  });

  it('ne touche ni aux prix ni aux rentrées des sources du propriétaire', () => {
    for (const f of formations) {
      const school = schoolOf(f.schoolId);
      const before = igensiaProgramCreateData(f, school, { withWebFacts: false });
      const after = igensiaProgramCreateData(f, school);
      expect(after.campusOfferings).toEqual(before.campusOfferings);
      expect(after.tuitionMinEur).toBe(before.tuitionMinEur);
      expect(after.tuitionFr).toBe(before.tuitionFr);
      expect(after.nameFr).toBe(before.nameFr);
      expect(after.levelFr).toBe(before.levelFr);
    }
  });

  it('ne déclare une langue que là où la page officielle la cite', () => {
    const withLanguage = formations
      .filter((f) => igensiaProgramCreateData(f, schoolOf(f.schoolId)).teachingLanguages.length)
      .map((f) => `${f.schoolId}|${f.name}`)
      .sort();
    expect(withLanguage).toEqual(
      [
        // ABC : « ANG » dans le portefeuille du propriétaire.
        ...formations.filter((f) => f.schoolId === 'igensia-abc').map((f) => `${f.schoolId}|${f.name}`),
        'igensia-isb|Bachelor Business Development - Sales Stategy',
        'igensia-isb|Bachelor Droit',
        "igensia-isb|Bachelor Gestion et Finance d'entreprise",
        'igensia-isb|Mastère Parcours International business développement',
        'igensia-rh|MBA International Human Resource Management',
      ].sort(),
    );
  });

  it('écrit la reconnaissance FR / EN à partir de la fiche RNCP', () => {
    const r = recognitionWithFacts(
      { fr: 'Titre RNCP (certifié par l’État)', en: 'RNCP title (state-certified)' },
      IGENSIA_FORMATION_FACTS['igensia-tech|Mastère pro IT Project Manager : Chef de projet informatique'],
    )!;
    expect(r.fr).toBe(
      'Titre RNCP (certifié par l’État) — RNCP40239 « Directeur de projets informatiques », niveau 7, certificateur : Institut de Gestion Sociale (IGS)',
    );
    expect(r.en).toBe(
      'RNCP title (state-certified) — RNCP40239 “Directeur de projets informatiques”, level 7, certified by Institut de Gestion Sociale (IGS)',
    );
    expect(recognitionWithFacts(null, undefined)).toBeNull();
  });

  it('écrit les textes ABC tutoyés, FR et EN, sans promesse d’admission', () => {
    const abc = schoolOf('igensia-abc');
    const inst = igensiaInstitutionCreateData(abc, formations);
    expect(inst.websiteUrl).toBe('https://www.american-business-college-paris.com/');
    expect(inst.overviewFr).toMatch(/admission-abc-paris@igensia\.com/);
    expect(inst.overviewFr).not.toMatch(/\b(vous|votre|vos)\b/i);
    expect(inst.overviewFr).toMatch(/L’admission reste la décision de l’école/);
    expect(inst.overviewEn).toMatch(/Admission remains the school’s decision/);
    for (const f of formations.filter((x) => x.schoolId === 'igensia-abc')) {
      const p = igensiaProgramCreateData(f, abc);
      expect(p.requirementsFr.join(' ')).not.toMatch(/\b(vous|votre|vos)\b/i);
      expect(p.requirementsFr).toHaveLength(p.requirementsEn.length);
      expect(p.durationFr).not.toBe('');
    }
  });
});

describe('import:igensia — comblement des fiches déjà en base', () => {
  it('comble les colonnes laissées par la première version, puis n’écrit plus rien', () => {
    const { programs, institutions } = firstVersionState();
    const plan = planIgensia(formations, programs, institutions);
    expect(plan.newSchools).toEqual([]);
    expect(plan.offeringAdditions).toEqual([]);
    // 21 formations ont des faits ; « Data Digital Business » n'en a pas.
    expect(plan.programFills).toHaveLength(21);
    expect(plan.unchanged).toEqual([formations.find((f) => f.name === 'Bachelor Data Digital Business')!.id]);
    const bba = plan.programFills.find((f) => f.name === 'BBA (Marketing, Int. Business, Finance)')!;
    expect(Object.keys(bba.data).sort()).toEqual(
      [
        'admissionModes',
        'applicationFeeEur',
        'durationEn',
        'durationFr',
        'procedureType',
        'recognitionEn',
        'recognitionFr',
        'requirementsEn',
        'requirementsFr',
        'sourceUrl',
      ].sort(),
    );
    expect(plan.institutionFills.map((f) => f.id)).toEqual(['igensia-abc']);
    expect(Object.keys(plan.institutionFills[0].data).sort()).toEqual(
      ['languageRequirementsEn', 'languageRequirementsFr', 'overviewEn', 'overviewFr', 'sourceUrl', 'websiteUrl'].sort(),
    );
    // Toutes les colonnes écrites sont dans la liste fermée.
    for (const f of plan.programFills) {
      expect(Object.keys(f.data).every((k) => (PROGRAM_FILLABLE as readonly string[]).includes(k))).toBe(true);
    }
    for (const f of plan.institutionFills) {
      expect(Object.keys(f.data).every((k) => (INSTITUTION_FILLABLE as readonly string[]).includes(k))).toBe(true);
    }

    // Application en mémoire, puis relance : 0 écriture.
    for (const f of plan.programFills) programs.set(f.id, { ...programs.get(f.id)!, ...f.data });
    for (const f of plan.institutionFills) institutions.set(f.id, { ...institutions.get(f.id)!, ...f.data });
    expect(igensiaPlanWriteCount(planIgensia(formations, programs, institutions))).toBe(0);
  });

  it('ne remplace jamais une colonne retouchée dans l’admin', () => {
    const { programs, institutions } = firstVersionState();
    const droit = formations.find((f) => f.name === 'Bachelor Droit')!.id;
    programs.set(droit, {
      ...programs.get(droit)!,
      languageFr: 'Français et anglais (saisi par l’admin)',
      recognitionFr: 'Texte de l’admin',
    });
    const abc = institutions.get('igensia-abc')!;
    institutions.set('igensia-abc', { ...abc, overviewFr: 'Texte de l’admin' });
    const plan = planIgensia(formations, programs, institutions);
    const fill = plan.programFills.find((f) => f.id === droit)!;
    expect(fill.data).not.toHaveProperty('languageFr');
    expect(fill.data).not.toHaveProperty('recognitionFr');
    expect(fill.data).toHaveProperty('recognitionEn');
    expect(plan.institutionFills[0].data).not.toHaveProperty('overviewFr');
  });

  it('ne comble pas une colonne que le script n’a pas lue', () => {
    const { programs, institutions } = firstVersionState();
    for (const [id, p] of programs) {
      programs.set(id, { id, campusOfferings: p.campusOfferings, updatedAt: p.updatedAt });
    }
    for (const [id, i] of institutions) {
      institutions.set(id, { id, intakePeriods: i.intakePeriods, programIds: i.programIds });
    }
    expect(igensiaPlanWriteCount(planIgensia(formations, programs, institutions))).toBe(0);
  });

  it('ne crée pas une formation dont une homonyme est déjà en base sous un autre id', () => {
    const { programs, institutions } = firstVersionState();
    const droit = formations.find((f) => f.name === 'Bachelor Droit')!;
    programs.delete(droit.id);
    const manual = { id: 'cl-admin-droit', institutionId: 'igensia-isb', nameFr: 'bachelor  DROIT', levelFr: 'Bachelor' };
    const plan = planIgensia(formations, programs, institutions, [manual]);
    expect(plan.schoolAdditions.flatMap((s) => s.programs).map((p) => p.id)).not.toContain(droit.id);
    expect(plan.skipped.find((s) => s.id === droit.id)?.reason).toMatch(/homonyme.*cl-admin-droit/);
  });
});
