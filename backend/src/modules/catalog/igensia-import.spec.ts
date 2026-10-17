import * as fs from 'node:fs';
import * as path from 'node:path';

import {
  FIELD_BY_DOMAIN,
  IGENSIA_SCHOOLS,
  type IgensiaExistingInstitution,
  type IgensiaExistingProgram,
  type IgensiaPlan,
  igensiaInstitutionCreateData,
  igensiaPlanWriteCount,
  igensiaProgramCreateData,
  parseChannels,
  parseIgensiaSources,
  planIgensia,
  procedureTypeFor,
  splitCampuses,
} from './igensia-import';

/**
 * Épingle la moitié pure de `import:igensia` contre les deux sources livrées
 * (scripts/data/igensia_2027.csv et abc_2027.csv, extraites du PDF et du XLSX
 * du propriétaire, 16/10/2026).
 */
const DATA = path.join(__dirname, '..', '..', '..', 'scripts', 'data');
const IGENSIA_CSV = fs.readFileSync(path.join(DATA, 'igensia_2027.csv'), 'utf8');
const ABC_CSV = fs.readFileSync(path.join(DATA, 'abc_2027.csv'), 'utf8');

const FIELD_IDS = new Set(
  Array.from({ length: 12 }, (_, i) => `d${String(i + 1).padStart(2, '0')}`),
);

function applyInMemory(
  plan: IgensiaPlan,
  programs: Map<string, IgensiaExistingProgram>,
  institutions: Map<string, IgensiaExistingInstitution>,
) {
  const created = [
    ...plan.newSchools.flatMap((s) => s.programs),
    ...plan.schoolAdditions.flatMap((s) => s.programs),
  ];
  for (const p of created) {
    programs.set(p.id, {
      id: p.id,
      campusOfferings: JSON.parse(JSON.stringify(p.campusOfferings)),
      updatedAt: new Date(),
    });
  }
  for (const { institution } of plan.newSchools) {
    institutions.set(institution.id, {
      id: institution.id,
      intakePeriods: [...institution.intakePeriods],
      programIds: [...institution.programIds],
    });
  }
  for (const a of plan.schoolAdditions) {
    const inst = institutions.get(a.id)!;
    institutions.set(a.id, {
      ...inst,
      intakePeriods: [...inst.intakePeriods, ...a.addIntakePeriods],
      programIds: [...inst.programIds, ...a.addProgramIds],
    });
  }
  for (const a of plan.offeringAdditions) {
    programs.set(a.id, { ...programs.get(a.id)!, campusOfferings: a.merged, updatedAt: new Date() });
  }
}

describe('import:igensia — lecture des sources', () => {
  const { formations, rowsBySchool, errors } = parseIgensiaSources(IGENSIA_CSV, ABC_CSV);
  const offersOf = (school: string) =>
    formations.filter((f) => f.schoolId === school).flatMap((f) => f.offerings).length;

  // Comptes relevés sur les sources : 20 lignes dans le PDF (ISB 14, IGENSIA
  // Tech 2, IGENSIA RH 4), 5 programmes dans le portefeuille ABC.
  it('lit 20 + 5 lignes, sans erreur, par école', () => {
    expect(errors).toEqual([]);
    expect(rowsBySchool).toEqual({
      'igensia-isb': 14,
      'igensia-tech': 2,
      'igensia-rh': 4,
      'igensia-abc': 5,
    });
  });

  it('fait UNE fiche par formation : 22 fiches, 34 offres (campus × rentrée)', () => {
    expect(formations).toHaveLength(22);
    const bySchool: Record<string, number> = {};
    for (const f of formations) bySchool[f.schoolId] = (bySchool[f.schoolId] ?? 0) + 1;
    expect(bySchool).toEqual({ 'igensia-isb': 12, 'igensia-tech': 2, 'igensia-rh': 3, 'igensia-abc': 5 });
    expect(offersOf('igensia-isb')).toBe(20);
    expect(offersOf('igensia-tech')).toBe(4);
    expect(offersOf('igensia-rh')).toBe(5);
    expect(offersOf('igensia-abc')).toBe(5);
  });

  it('réunit mars et septembre d’une même formation en une fiche à plusieurs offres', () => {
    const expert = formations.find((f) => f.name === 'Mastère pro Expert Financier')!;
    expect(expert.id).toBe('igensia-p-5bcf0a643784a585');
    expect(expert.offerings.map((o) => `${o.campus} ${o.intake} ${o.session}`)).toEqual([
      'Lyon 09/2027 fall',
      'Paris 03/2027 spring',
      'Paris 09/2027 fall',
    ]);
  });

  it('recopie les intitulés tels quels et ne corrige que le nom des écoles', () => {
    expect(formations.some((f) => f.name === 'Bachelor Business Development - Sales Stategy')).toBe(true);
    const names = IGENSIA_SCHOOLS.map((s) => s.nameFr).join(' ');
    expect(names).not.toMatch(/IGENISA/);
    expect(formations.filter((f) => f.schoolId === 'igensia-tech')).toHaveLength(2);
  });

  it('range chaque formation dans un domaine d01..d12, par une table fermée', () => {
    expect(formations.every((f) => FIELD_IDS.has(f.fieldId))).toBe(true);
    expect(Object.values(FIELD_BY_DOMAIN).every((id) => FIELD_IDS.has(id))).toBe(true);
    const broken = IGENSIA_CSV.replace('ISB,DROIT,Bachelor Droit', 'ISB,ARCHÉOLOGIE,Bachelor Droit');
    expect(parseIgensiaSources(broken, ABC_CSV).errors.join(' ')).toMatch(/domaine inconnu « ARCHÉOLOGIE »/);
  });

  it('refuse une école hors de la liste', () => {
    const broken = IGENSIA_CSV.replace('\nISB,DROIT,', '\nESA,DROIT,');
    expect(parseIgensiaSources(broken, ABC_CSV).errors.join(' ')).toMatch(/école inconnue « ESA »/);
  });

  it('découpe les campus et les modes de candidature', () => {
    expect(splitCampuses('Paris, Lyon et Toulouse')).toEqual(['Paris', 'Lyon', 'Toulouse']);
    expect(parseChannels('Concours école, Etudes en France et Parcoursup')).toEqual([
      'Parcoursup',
      'Études en France',
      'Concours école',
    ]);
    expect(parseChannels('Concours ecole et Parcoursup')).toEqual(['Parcoursup', 'Concours école']);
    expect(parseChannels('Dossier papier')).toBeNull();
  });

  it('dérive une procédure cohérente : EEF quand Études en France est ouvert', () => {
    expect(procedureTypeFor(['Parcoursup', 'Études en France', 'Concours école'])).toBe('eef');
    expect(procedureTypeFor(['Parcoursup', 'Concours école'])).toBe('hors_eef');
    expect(procedureTypeFor(['Concours école'])).toBe('hors_eef');
    expect(procedureTypeFor([])).toBeNull();
  });

  it('remplit la fiche sans rien inventer', () => {
    const school = IGENSIA_SCHOOLS.find((s) => s.id === 'igensia-isb')!;
    const event = formations.find((f) => f.name === 'Bachelor Business Development - Event Sales')!;
    const data = igensiaProgramCreateData(event, school);
    expect(data).toMatchObject({
      levelFr: 'Bachelor',
      durationFr: '3 ans, entrée en 1re année (B1)',
      tuitionMinEur: 9400,
      procedureType: 'eef',
      admissionModes: ['Parcoursup', 'Études en France', 'Concours école'],
      // La page officielle de la formation (igensia-enrichment.ts).
      sourceUrl:
        'https://www.igensia-school-of-business.fr/formations/commerce-vente-achats/bachelor-en-sciences-du-management-event-management',
      // Ni la source ni la page officielle ne disent la langue : rien n'est écrit.
      languageFr: '',
      teachingLanguages: [],
    });
    // Le libellé de la source, puis la fiche RNCP qui le porte.
    expect(data.recognitionFr).toMatch(/^Grade de licence — RNCP39556 « DipViGrL - Responsable du développement commercial et marketing », niveau 6/);
    // `toLocaleString('fr-FR')` sépare les milliers d'une espace fine insécable.
    expect(data.tuitionFr).toMatch(/^9\s400 €\/an$/);
    expect(data.requirementsFr).toHaveLength(data.requirementsEn.length);
    expect(data.requirementsFr.join(' ')).toMatch(/B2 minimum/);

    const abc = IGENSIA_SCHOOLS.find((s) => s.id === 'igensia-abc')!;
    const bba = formations.find((f) => f.schoolId === 'igensia-abc' && f.level === 'BBA')!;
    const abcData = igensiaProgramCreateData(bba, abc);
    expect(abcData).toMatchObject({
      id: 'igensia-p-c36088091e95f880',
      nameFr: 'BBA (Marketing, Int. Business, Finance)',
      tuitionMinEur: 12900,
      teachingLanguages: ['en'],
      languageFr: 'Anglais',
      // Le portefeuille ABC ne disait ni durée, ni reconnaissance, ni
      // admission : relevées sur le site officiel de l'école.
      durationFr: '4 ans (8 semestres + stage de fin d’études de 6 mois)',
      procedureType: 'hors_eef',
      admissionModes: ['Dossier', 'Entretien'],
      applicationFeeEur: 60,
      sourceUrl:
        'https://www.american-business-college-paris.com/programs/bachelor-degree/bachelor-of-business-administration',
    });
    expect(abcData.recognitionFr).toMatch(/IACBE.*RNCP41361 « Manager international », niveau 7/);
    expect(abcData.requirementsFr.join(' ')).toMatch(/IELTS 6\.0/);
    expect(abcData.requirementsFr).toHaveLength(abcData.requirementsEn.length);
    // Les prix restent ceux de la source du propriétaire.
    expect(abcData.campusOfferings.map((o) => o.tuitionUpfront)).toEqual([12900]);
  });

  it('écrit des textes d’école tutoyés, FR et EN, sans promesse d’admission', () => {
    for (const school of IGENSIA_SCHOOLS) {
      const inst = igensiaInstitutionCreateData(school, formations);
      expect(inst.isPartner).toBe(true);
      expect(inst.countryId).toBe('fra');
      expect(inst.overviewFr).not.toMatch(/\b(vous|votre|vos)\b/i);
      expect(inst.overviewFr).not.toMatch(/garanti|assuré/i);
      expect(inst.overviewFr).toMatch(/ESA Casablanca/);
      expect(inst.overviewEn).toMatch(/ESA Casablanca/);
      expect(inst.programIds).toEqual(formations.filter((f) => f.schoolId === school.id).map((f) => f.id));
    }
    const isb = igensiaInstitutionCreateData(IGENSIA_SCHOOLS[0], formations);
    expect(isb.locationFr).toBe('Lyon · Paris · Toulouse');
    expect(isb.intakePeriods).toEqual(['Mars 2027', 'Septembre 2027']);
    expect(isb.overviewFr).toMatch(/3 000 €/);
    expect(isb.overviewFr).toMatch(/390 €/);
  });
});

describe('import:igensia — plan', () => {
  const { formations } = parseIgensiaSources(IGENSIA_CSV, ABC_CSV);

  it('sur une base vide : 4 écoles et 22 formations à créer', () => {
    const plan = planIgensia(formations, new Map(), new Map());
    expect(plan.newSchools.map((s) => s.institution.id)).toEqual([
      'igensia-isb',
      'igensia-tech',
      'igensia-rh',
      'igensia-abc',
    ]);
    expect(plan.newSchools.flatMap((s) => s.programs)).toHaveLength(22);
    // ESA Casablanca n'est jamais touchée : elle reste la fiche de seed:partners.
    expect(JSON.stringify(plan)).not.toMatch(/partner-esa-casa/);
  });

  it('rejouer après application n’écrit rien (idempotence)', () => {
    const programs = new Map<string, IgensiaExistingProgram>();
    const institutions = new Map<string, IgensiaExistingInstitution>();
    applyInMemory(planIgensia(formations, programs, institutions), programs, institutions);
    const replay = planIgensia(formations, programs, institutions);
    expect(igensiaPlanWriteCount(replay)).toBe(0);
    expect(replay.unchanged).toHaveLength(22);
  });

  it('ne réécrit ni une école existante ni une offre retouchée (additivité)', () => {
    const programs = new Map<string, IgensiaExistingProgram>();
    const institutions = new Map<string, IgensiaExistingInstitution>();
    applyInMemory(planIgensia(formations, programs, institutions), programs, institutions);

    // Une offre retouchée à la main et une rentrée retirée de la fiche :
    // la première reste telle quelle, la seconde revient À LA FIN.
    const expert = 'igensia-p-5bcf0a643784a585';
    const edited = { campus: 'Lyon', tuitionUpfront: 11000, intake: '09/2027', session: 'fall', note: 'admin' };
    programs.set(expert, { ...programs.get(expert)!, campusOfferings: [edited] });
    // Une formation supprimée à la main : recréée, et ajoutée à programIds.
    const droit = formations.find((f) => f.name === 'Bachelor Droit')!.id;
    programs.delete(droit);
    const isb = institutions.get('igensia-isb')!;
    institutions.set('igensia-isb', { ...isb, programIds: isb.programIds.filter((id) => id !== droit) });

    const plan = planIgensia(formations, programs, institutions);
    expect(plan.newSchools).toEqual([]);
    const addition = plan.offeringAdditions.find((a) => a.id === expert)!;
    expect(addition.merged[0]).toBe(edited);
    expect(addition.added.map((o) => `${o.campus} ${o.intake}`)).toEqual(['Paris 03/2027', 'Paris 09/2027']);
    expect(plan.schoolAdditions).toEqual([
      expect.objectContaining({ id: 'igensia-isb', addIntakePeriods: [], addProgramIds: [droit] }),
    ]);
    expect(plan.schoolAdditions[0].programs.map((p) => p.id)).toEqual([droit]);
  });
});
