import * as fs from 'node:fs';
import * as path from 'node:path';

import { M5_COUNTRY_SEEDS } from '../countries/data/m5-countries.seed';
import {
  NA_COUNTRIES,
  NA_INSTITUTION_TYPES,
  NA_LEVELS,
  type NaExistingInstitution,
  type NaExistingProgram,
  type NaSource,
  naPlanWriteCount,
  naProgramCreateData,
  naProgramId,
  naToEur,
  planNaCorrections,
  planNorthAmerica,
  tuitionLabelProblems,
  validateNaSource,
} from './north-america-import';
import { normalizeDegreeLevel } from './omnes-conventions';
import { detectCurrencies } from './tuition-eur';

/// Seconde passe Canada (17/10/2026) : réseau UQ et écoles du Québec,
/// Nouveau-Brunswick, collèges de l'Ontario avec programme de langue en amont.
const SECOND_PASS = {
  quebec: ['na-ca-uqtr', 'na-ca-uqar', 'na-ca-uqo', 'na-ca-uqat', 'na-ca-ets', 'na-ca-polytechnique', 'na-ca-hec', 'na-ca-bishops'],
  newBrunswick: ['na-ca-unb', 'na-ca-ccnb'],
  ontarioColleges: ['na-ca-humber', 'na-ca-seneca', 'na-ca-conestoga', 'na-ca-centennial', 'na-ca-fanshawe', 'na-ca-sheridan'],
};
const SECOND_PASS_IDS = Object.values(SECOND_PASS).flat();

/// Troisième passe (12/11/2026) : francophones hors Québec (PPECFSM), trois
/// universités américaines accessibles, formations et prix ajoutés aux
/// universités québécoises les plus demandées.
const THIRD = '2026-11-12';
const THIRD_PASS_IDS = [
  'na-ca-saint-boniface', 'na-ca-uof', 'na-ca-sainte-anne', 'na-ca-la-cite', 'na-ca-boreal',
  'na-us-southeast-missouri-state', 'na-us-fort-hays-state', 'na-us-missouri-state',
];
const THIRD_PASS_GROWN = ['na-ca-montreal', 'na-ca-sherbrooke', 'na-ca-laval', 'na-ca-uqam', 'na-ca-uqtr', 'na-ca-uqo', 'na-ca-uqac'];

/// La source telle qu'elle était avant la troisième passe (ni établissements,
/// ni formations, ni corrections du 12/11/2026).
function beforeThirdPass(doc: NaSource): NaSource {
  return {
    ...doc,
    corrections: undefined,
    institutions: doc.institutions
      .filter((i) => i.consultedAt !== THIRD)
      .map((i) => ({ ...i, programs: i.programs.filter((p) => p.consultedAt !== THIRD) })),
  };
}
const EUROPE = path.join(__dirname, '..', '..', '..', 'scripts', 'data', 'europe-2027.json');

const SOURCE = path.join(__dirname, '..', '..', '..', 'scripts', 'data', 'amerique-du-nord-2027.json');
const load = (): NaSource => JSON.parse(fs.readFileSync(SOURCE, 'utf8')) as NaSource;

/** Applique un plan en mémoire, comme le ferait `--apply`. */
function applyInMemory(
  plan: ReturnType<typeof planNorthAmerica>,
  institutions: NaExistingInstitution[],
  programs: NaExistingProgram[],
) {
  for (const { institution, programs: rows } of plan.newInstitutions) {
    institutions.push({ id: institution.id, nameFr: institution.nameFr, nameEn: institution.nameEn, programIds: [...institution.programIds] });
    programs.push(...rows.map((p) => ({ id: p.id, institutionId: p.institutionId, nameFr: p.nameFr, levelFr: p.levelFr })));
  }
  for (const add of plan.programAdditions) {
    programs.push(...add.programs.map((p) => ({ id: p.id, institutionId: p.institutionId, nameFr: p.nameFr, levelFr: p.levelFr })));
    const inst = institutions.find((i) => i.id === add.institutionId)!;
    inst.programIds.push(...add.addProgramIds);
  }
}

describe('import:north-america — source versionnée', () => {
  const doc = load();

  it('est valide, datée du 16/10/2026, avec les taux BCE du jour', () => {
    expect(validateNaSource(doc)).toEqual([]);
    expect(doc.consultedAt).toBe('2026-10-16');
    expect(doc.exchangeRates).toEqual(
      expect.objectContaining({ date: '2026-10-16', perEur: { USD: 1.1253, CAD: 1.5935 } }),
    );
  });

  it('compte 31 établissements au Canada (10 + 16 + 5), 13 aux États-Unis (10 + 3), 4 à 9 formations chacun', () => {
    const by = (c: string) => doc.institutions.filter((i) => i.countryId === c);
    expect(by('can')).toHaveLength(31);
    expect(by('usa')).toHaveLength(13);
    for (const inst of doc.institutions) {
      expect(inst.programs.length).toBeGreaterThanOrEqual(4);
      expect(inst.programs.length).toBeLessThanOrEqual(9);
      expect(inst.id.startsWith(NA_COUNTRIES[inst.countryId].prefix)).toBe(true);
    }
    expect(doc.institutions.reduce((n, i) => n + i.programs.length, 0)).toBe(238);
  });

  it('troisième passe : 8 établissements, 28 formations ajoutées à 7 universités québécoises, chaque formation chiffrée', () => {
    expect(doc.institutions.filter((i) => i.consultedAt === THIRD).map((i) => i.id).sort()).toEqual([...THIRD_PASS_IDS].sort());
    const grown = doc.institutions.filter((i) => i.programs.some((p) => p.consultedAt === THIRD));
    expect(grown.map((i) => i.id).sort()).toEqual([...THIRD_PASS_GROWN].sort());
    expect(grown.reduce((n, i) => n + i.programs.filter((p) => p.consultedAt === THIRD).length, 0)).toBe(28);
    // Plus aucune formation sans montant annuel (UQAM, UQAC, HEC… complétés).
    expect(doc.institutions.flatMap((i) => i.programs).filter((p) => !p.tuitionAnnual)).toEqual([]);
    expect(doc.corrections!.programs.filter((c) => c.previousTuitionFr)).toHaveLength(15);
    expect(doc.corrections!.institutions.map((c) => c.institutionId).sort()).toEqual(['na-ca-uqac', 'na-ca-uqam']);
  });

  it('seconde passe : 8 au Québec, 2 au Nouveau-Brunswick, 6 collèges de l’Ontario, 75 formations, relevés du 17/10/2026', () => {
    const second = doc.institutions.filter((i) => i.consultedAt === '2026-10-17');
    expect(second.map((i) => i.id).sort()).toEqual([...SECOND_PASS_IDS].sort());
    expect(new Set(second.map((i) => i.consultedAt))).toEqual(new Set(['2026-10-17']));
    expect(second.reduce((n, i) => n + i.programs.filter((p) => !p.consultedAt).length, 0)).toBe(75);
    const province = (id: string) => doc.institutions.find((i) => i.id === id)!.locationFr.split(', ')[1];
    expect(SECOND_PASS.quebec.map(province)).toEqual(Array(8).fill('Québec'));
    expect(SECOND_PASS.newBrunswick.map(province)).toEqual(['Nouveau-Brunswick', 'Nouveau-Brunswick']);
    expect(SECOND_PASS.ontarioColleges.map(province)).toEqual(Array(6).fill('Ontario'));
  });

  it('chaque collège de l’Ontario publie un programme d’anglais en amont et au moins une rentrée de janvier ou mai', () => {
    for (const id of SECOND_PASS.ontarioColleges) {
      const inst = doc.institutions.find((i) => i.id === id)!;
      expect(inst.institutionType).toBe('college_public');
      expect(inst.languagePathway?.sourceUrl).toMatch(/^https:\/\//);
      expect(inst.languageRequirementsFr).toContain(inst.languagePathway!.nameFr);
      const intakes = inst.programs.flatMap((p) => (p.offerings ?? []).map((o) => o.intake));
      expect(intakes.some((i) => i === '01/2027' || i === '05/2027')).toBe(true);
    }
  });

  it('les niveaux de collège sont à la convention `normalizeDegreeLevel`', () => {
    const levels = new Set(doc.institutions.flatMap((i) => i.programs.map((p) => p.level)));
    expect(levels).toEqual(new Set(NA_LEVELS));
    for (const level of NA_LEVELS) expect(normalizeDegreeLevel(level)).toBe(level);
    expect(normalizeDegreeLevel('Ontario College Graduate Certificate')).toBe('Graduate certificate');
    expect(normalizeDegreeLevel('Ontario College Advanced Diploma')).toBe('Diplôme collégial');
    expect(normalizeDegreeLevel('Ontario College Diploma')).toBe('Diplôme collégial');
    expect(normalizeDegreeLevel("Diplôme d'études collégiales (DEC)")).toBe('Diplôme collégial');
    // Les niveaux existants ne bougent pas.
    expect(normalizeDegreeLevel('MSc · Bac+5')).toBe('Master');
    expect(normalizeDegreeLevel('Bac+2')).toBe('Bac+2');
  });

  it('l’Université d’Ottawa (déjà au catalogue sous `uottawa`) n’est pas dans la source', () => {
    expect(doc.institutions.map((i) => i.nameEn)).not.toContain('University of Ottawa');
  });

  it('chaque libellé de frais est lisible par l’app : une seule devise, écrite en code', () => {
    for (const inst of doc.institutions) {
      for (const p of inst.programs) {
        for (const label of [p.tuitionFr, p.tuitionEn].filter(Boolean)) {
          expect(label).not.toContain('$');
          // Sans montant annuel (M. Sc. de HEC : coût du programme complet),
          // le libellé garde une seule devise lisible.
          expect(detectCurrencies(label)).toEqual(p.tuitionAnnual ? [p.tuitionAnnual.currency] : ['CAD']);
        }
      }
    }
  });
});

describe('import:north-america — lignes écrites', () => {
  const doc = load();
  const plan = planNorthAmerica(doc, [], []);

  it('crée des établissements NON partenaires, actifs, sourcés et datés', () => {
    expect(plan.newInstitutions).toHaveLength(44);
    for (const { institution, programs } of plan.newInstitutions) {
      expect(institution.isPartner).toBe(false);
      expect(institution.isActive).toBe(true);
      const day = THIRD_PASS_IDS.includes(institution.id) ? THIRD : SECOND_PASS_IDS.includes(institution.id) ? '2026-10-17' : '2026-10-16';
      expect(institution.lastVerifiedAt.toISOString()).toBe(`${day}T00:00:00.000Z`);
      const src = doc.institutions.find((i) => i.id === institution.id)!;
      for (const p of programs) {
        const own = src.programs.find((x) => naProgramId(src.id, x.slug) === p.id)!.consultedAt;
        expect(p.lastVerifiedAt.toISOString()).toBe(`${own ?? day}T00:00:00.000Z`);
      }
      expect(institution.institutionType === null || NA_INSTITUTION_TYPES[institution.institutionType]).toBeTruthy();
      expect(institution.sourceUrl).toMatch(/^https:\/\//);
      expect(institution.overviewFr).toContain("KPB n'est pas partenaire");
      expect(institution.overviewFr).not.toMatch(/admission (garantie|assurée) par KPB|partenaire officiel/i);
      expect(institution.programIds).toEqual(programs.map((p) => p.id));
      expect(['can', 'usa']).toContain(institution.countryId);
    }
  });

  it('les formations portent leur source, leur domaine d01..d12 et un niveau normalisé', () => {
    for (const { programs } of plan.newInstitutions) {
      for (const p of programs) {
        expect(p.fieldId).toMatch(/^d(0[1-9]|1[0-2])$/);
        expect(NA_LEVELS as readonly string[]).toContain(p.levelFr);
        expect(p.sourceUrl).toMatch(/^https:\/\//);
        expect(p.procedureType).toBe('hors_eef');
        expect(p.searchText).toBe(p.searchText.toLowerCase());
        expect(p.teachingLanguages.length).toBeGreaterThan(0);
      }
    }
  });

  it('convertit le plancher annuel au taux BCE versionné, arrondi à l’euro', () => {
    const uh = doc.institutions.find((i) => i.id === 'na-us-houston')!;
    const cs = naProgramCreateData(uh.programs[0], uh, doc);
    // 2 × 14 032,64 USD / 1,1253
    expect(cs.tuitionMinEur).toBe(Math.round(28065 / 1.1253));
    expect(cs.applicationFeeEur).toBe(Math.round(90 / 1.1253));
    const laval = doc.institutions.find((i) => i.id === 'na-ca-laval')!;
    expect(naProgramCreateData(laval.programs[0], laval, doc).tuitionMinEur).toBe(Math.round(28233 / 1.5935));
    // Seconde passe : le prix d'un collège (2 semestres) au même taux du 16/10.
    const humber = doc.institutions.find((i) => i.id === 'na-ca-humber')!;
    expect(naProgramCreateData(humber.programs[0], humber, doc).tuitionMinEur).toBe(Math.round(21736 / 1.5935));
    expect(naProgramCreateData(humber.programs[0], humber, doc).applicationFeeEur).toBe(Math.round(100 / 1.5935));
    expect(naToEur(null, doc.exchangeRates.perEur)).toBeNull();
    expect(naToEur({ amount: 100, currency: 'GBP' }, doc.exchangeRates.perEur)).toBeNull();
  });

  it('sans montant publié, `tuitionMinEur` reste nul et le libellé de l’école est repris', () => {
    const uqac = structuredClone(doc.institutions.find((i) => i.id === 'na-ca-uqac')!);
    Object.assign(uqac.programs[0], { tuitionFr: '', tuitionEn: '', tuitionAnnual: null });
    const row = naProgramCreateData(uqac.programs[0], uqac, doc);
    expect(row.tuitionMinEur).toBeNull();
    expect(row.tuitionFr).toBe(uqac.tuitionLabelFr);
  });

  it('les offres datées n’ont pas de prix en euros (les frais sont en USD / CAD)', () => {
    const offered = plan.newInstitutions.flatMap((n) => n.programs).filter((p) => p.campusOfferings);
    expect(offered.length).toBeGreaterThan(0);
    for (const p of offered) {
      expect(p.campusOfferings!.length).toBeGreaterThanOrEqual(2);
      for (const o of p.campusOfferings!) {
        expect(o.tuitionUpfront).toBeNull();
        expect(['fall', 'spring']).toContain(o.session);
      }
    }
  });
});

describe('import:north-america — création seule, rejouable', () => {
  it('rejouer après application : 0 écriture', () => {
    const doc = load();
    const institutions: NaExistingInstitution[] = [];
    const programs: NaExistingProgram[] = [];
    const first = planNorthAmerica(doc, institutions, programs);
    expect(naPlanWriteCount(first)).toBe(44);
    applyInMemory(first, institutions, programs);
    const second = planNorthAmerica(doc, institutions, programs);
    expect(naPlanWriteCount(second)).toBe(0);
    expect(second.unchanged).toHaveLength(44);
  });

  it('première passe déjà en base : la seconde ne crée que les 16 nouveaux établissements', () => {
    const doc = beforeThirdPass(load());
    const firstPass = { ...doc, institutions: doc.institutions.filter((i) => !i.consultedAt) };
    const institutions: NaExistingInstitution[] = [];
    const programs: NaExistingProgram[] = [];
    applyInMemory(planNorthAmerica(firstPass, institutions, programs), institutions, programs);
    const plan = planNorthAmerica(doc, institutions, programs);
    expect(plan.newInstitutions.map((n) => n.institution.id).sort()).toEqual([...SECOND_PASS_IDS].sort());
    expect(plan.programAdditions).toEqual([]);
    expect(plan.unchanged).toHaveLength(20);
    expect(plan.skipped).toEqual([]);
  });

  it('un établissement déjà là ne reçoit que ses formations manquantes', () => {
    const doc = load();
    const uh = doc.institutions.find((i) => i.id === 'na-us-houston')!;
    const kept = naProgramId(uh.id, uh.programs[0].slug);
    const plan = planNorthAmerica(
      doc,
      [{ id: uh.id, nameFr: 'University of Houston', nameEn: 'University of Houston', programIds: [kept] }],
      [{ id: kept, institutionId: uh.id, nameFr: 'Intitulé retouché dans l’admin', levelFr: 'Bachelor' }],
    );
    expect(plan.newInstitutions.find((n) => n.institution.id === uh.id)).toBeUndefined();
    const add = plan.programAdditions.find((a) => a.institutionId === uh.id)!;
    expect(add.programs.map((p) => p.id)).not.toContain(kept);
    expect(add.programs).toHaveLength(uh.programs.length - 1);
    expect(add.addProgramIds).not.toContain(kept);
  });

  it('refuse un homonyme déjà en base sous un autre id (établissement ou formation)', () => {
    const doc = load();
    const plan = planNorthAmerica(
      doc,
      [
        { id: 'cl-mcgill', nameFr: 'McGill University', nameEn: 'McGill University', programIds: [] },
        // Le sigle ajouté au nom affiché n'empêche pas de reconnaître la fiche.
        { id: 'cl-uqam', nameFr: 'Université du Québec à Montréal', nameEn: 'UQAM', programIds: [] },
        { id: 'na-ca-laval', nameFr: 'Université Laval', nameEn: 'Université Laval', programIds: [] },
      ],
      [{ id: 'cl-laval-info', institutionId: 'na-ca-laval', nameFr: 'Baccalauréat en Informatique', levelFr: 'Bachelor' }],
    );
    expect(plan.skipped.find((s) => s.id === 'na-ca-mcgill')?.reason).toContain('cl-mcgill');
    expect(plan.newInstitutions.find((n) => n.institution.id === 'na-ca-mcgill')).toBeUndefined();
    expect(plan.skipped.find((s) => s.id === 'na-ca-uqam')?.reason).toContain('cl-uqam');
    const laval = plan.programAdditions.find((a) => a.institutionId === 'na-ca-laval')!;
    expect(laval.programs.map((p) => p.nameFr)).not.toContain('Baccalauréat en informatique');
    expect(plan.skipped.some((s) => s.reason.includes('cl-laval-info'))).toBe(true);
  });
});

describe('import:north-america — troisième passe sur une base qui a les deux premières', () => {
  /** Base telle qu'en production après les deux premières passes. */
  function seeded() {
    const doc = load();
    const old = beforeThirdPass(doc);
    const institutions: NaExistingInstitution[] = [];
    const programs: NaExistingProgram[] = [];
    applyInMemory(planNorthAmerica(old, institutions, programs), institutions, programs);
    // Les lignes telles que les deux premières passes les ont écrites : la
    // source garde, pour chaque correction, la valeur d'avant.
    const fix = new Map(doc.corrections!.programs.map((c) => [c.programId, c]));
    const rows = old.institutions.flatMap((i) =>
      i.programs.map((p) => {
        const r = naProgramCreateData(p, i, old);
        const c = fix.get(r.id);
        return {
          ...r,
          tuitionFr: c?.previousTuitionFr ?? r.tuitionFr,
          durationFr: c?.fillDuration ? '' : r.durationFr,
          applicationFeeEur: c ? null : r.applicationFeeEur,
        };
      }),
    );
    const labels = new Map(doc.corrections!.institutions.map((c) => [c.institutionId, c.previousTuitionLabelFr]));
    const instRows = old.institutions.map((i) => ({ id: i.id, tuitionLabelFr: labels.get(i.id) ?? i.tuitionLabelFr }));
    return { doc, old, institutions, programs, rows, instRows };
  }

  it('crée les 8 établissements, ajoute les 28 formations aux 7 universités québécoises, rien d’autre', () => {
    const { doc, institutions, programs } = seeded();
    const plan = planNorthAmerica(doc, institutions, programs);
    expect(plan.newInstitutions.map((n) => n.institution.id).sort()).toEqual([...THIRD_PASS_IDS].sort());
    expect(plan.programAdditions.map((a) => a.institutionId).sort()).toEqual([...THIRD_PASS_GROWN].sort());
    expect(plan.programAdditions.reduce((n, a) => n + a.programs.length, 0)).toBe(28);
    for (const a of plan.programAdditions) {
      for (const p of a.programs) expect(p.lastVerifiedAt.toISOString()).toBe(`${THIRD}T00:00:00.000Z`);
      expect(a.addProgramIds).toEqual(a.programs.map((p) => p.id));
    }
    expect(plan.skipped).toEqual([]);
  });

  it('complète les prix et durées des lignes publiées qui portent encore la valeur précédente, et seulement elles', () => {
    const { doc, rows, instRows } = seeded();
    const progRows = rows.map((r) => ({ id: r.id, tuitionFr: r.tuitionFr, applicationFeeEur: r.applicationFeeEur, durationFr: r.durationFr }));
    const plan = planNaCorrections(doc, progRows, instRows);
    const priced = plan.programs.filter((c) => c.data.tuitionFr);
    expect(priced).toHaveLength(15);
    for (const c of priced) {
      expect(c.whereTuitionFr).toBe(progRows.find((r) => r.id === c.id)!.tuitionFr);
      expect(c.data.tuitionMinEur).toBeGreaterThan(0);
      expect(c.data.lastVerifiedAt.toISOString()).toBe(`${THIRD}T00:00:00.000Z`);
    }
    for (const c of plan.programs.filter((x) => x.data.durationFr)) {
      expect(progRows.find((r) => r.id === c.id)!.durationFr).toBe('');
    }
    expect(plan.institutions.map((c) => c.id).sort()).toEqual(['na-ca-uqac', 'na-ca-uqam']);
    expect(plan.skipped).toEqual([]);

    // Une retouche faite dans l'admin n'est jamais écrasée.
    const edited = progRows.map((r) => (r.id === priced[0].id ? { ...r, tuitionFr: 'Retouché dans l’admin' } : r));
    const again = planNaCorrections(doc, edited, instRows.map((r) => (r.id === 'na-ca-uqam' ? { ...r, tuitionLabelFr: 'Retouché' } : r)));
    expect(again.programs.find((c) => c.id === priced[0].id)?.data.tuitionFr).toBeUndefined();
    expect(again.skipped.map((s) => s.id)).toEqual(expect.arrayContaining([priced[0].id, 'na-ca-uqam']));
  });

  it('rejouée après application : plus aucune correction', () => {
    const { doc } = seeded();
    const fresh = doc.institutions.flatMap((i) => i.programs.map((p) => naProgramCreateData(p, i, doc)));
    const plan = planNaCorrections(
      doc,
      fresh.map((r) => ({ id: r.id, tuitionFr: r.tuitionFr, applicationFeeEur: r.applicationFeeEur, durationFr: r.durationFr })),
      doc.institutions.map((i) => ({ id: i.id, tuitionLabelFr: i.tuitionLabelFr })),
    );
    expect(plan).toEqual({ programs: [], institutions: [], skipped: [] });
  });
});

describe('import:europe — Belgique et Allemagne', () => {
  const doc = JSON.parse(fs.readFileSync(EUROPE, 'utf8')) as NaSource;

  it('est valide : 4 universités belges, 2 allemandes, 5 formations chacune, en EUR', () => {
    expect(validateNaSource(doc)).toEqual([]);
    expect(doc.institutions.filter((i) => i.countryId === 'bel').map((i) => i.id).sort()).toEqual(
      ['eu-be-uclouvain', 'eu-be-ulb', 'eu-be-uliege', 'eu-be-unamur'],
    );
    expect(doc.institutions.filter((i) => i.countryId === 'deu')).toHaveLength(2);
    for (const inst of doc.institutions) {
      expect(inst.programs).toHaveLength(5);
      for (const p of inst.programs) expect(p.tuitionAnnual?.currency).toBe('EUR');
    }
  });

  it('les frais belges 2026-2027 : 5 369 EUR hors UE, 1 194 EUR pour les pays des annexes ARES', () => {
    for (const inst of doc.institutions.filter((i) => i.countryId === 'bel')) {
      for (const p of inst.programs) expect(p.tuitionAnnual).toEqual({ amount: 5369, currency: 'EUR' });
      expect(inst.tuitionLabelFr).toContain('1 194 EUR');
    }
  });

  it('écrit des lignes non partenaires en euros, sans conversion', () => {
    const plan = planNorthAmerica(doc, [], []);
    expect(plan.newInstitutions).toHaveLength(6);
    const ulb = plan.newInstitutions.find((n) => n.institution.id === 'eu-be-ulb')!;
    expect(ulb.institution.isPartner).toBe(false);
    expect(ulb.institution.countryId).toBe('bel');
    expect(ulb.programs[0].tuitionMinEur).toBe(5369);
  });

  it('chaque pays de la source a sa fiche M5 (la Belgique est créée par l’import si elle manque)', () => {
    for (const c of new Set(doc.institutions.map((i) => i.countryId))) {
      expect(M5_COUNTRY_SEEDS.some((s) => s.id === c)).toBe(true);
    }
  });
});

describe('import:north-america — le validateur refuse', () => {
  const mutate = (fn: (doc: NaSource) => void): string[] => {
    const doc = load();
    fn(doc);
    return validateNaSource(doc);
  };

  it('un « $ » ou une décimale à virgule dans un libellé de frais', () => {
    expect(tuitionLabelProblems('$1,200/year', 'USD').join()).toContain('$');
    expect(tuitionLabelProblems('1 464,73 USD par crédit', 'USD').join()).toContain('virgule');
    expect(tuitionLabelProblems('28 065 USD/an', 'CAD').join()).toContain('≠');
    expect(tuitionLabelProblems('28 065 USD/an', 'USD')).toEqual([]);
  });

  it('un domaine, un niveau, un id ou un pays hors convention', () => {
    expect(mutate((d) => (d.institutions[0].programs[0].fieldId = 'informatique')).join()).toContain('domaine inconnu');
    expect(mutate((d) => (d.institutions[0].programs[0].level = 'Licence')).join()).toContain('niveau hors convention');
    expect(mutate((d) => (d.institutions[0].id = 'na-ca-houston')).join()).toContain('préfixe');
    expect(mutate((d) => (d.institutions[0].countryId = 'mex')).join()).toContain('pays inconnu');
  });

  it('un type d’établissement, une date de relevé ou un programme de langue mal renseignés', () => {
    const humber = (d: NaSource) => d.institutions.find((i) => i.id === 'na-ca-humber')!;
    expect(mutate((d) => (humber(d).institutionType = 'cegep')).join()).toContain("type d'établissement inconnu");
    expect(mutate((d) => (humber(d).consultedAt = '17/10/2026')).join()).toContain('consultedAt illisible');
    expect(mutate((d) => (humber(d).consultedAt = '2026-10-01')).join()).toContain('antérieur au document');
    expect(mutate((d) => (humber(d).languagePathway!.sourceUrl = 'http://humber.ca')).join()).toContain('sourceUrl non https');
    expect(
      mutate((d) => (humber(d).languageRequirementsFr = 'Anglais : IELTS 6.0')).join(),
    ).toContain('absent des exigences linguistiques');
    expect(mutate((d) => (humber(d).programs[0].level = 'Ontario College Diploma')).join()).toContain('niveau hors convention');
  });

  it('une présentation qui ne dit pas « non partenaire »', () => {
    expect(
      mutate((d) => (d.institutions[0].overviewFr = 'Grande université.')).join(),
    ).toContain("KPB n'est pas partenaire");
  });

  it('une offre isolée ou une rentrée illisible', () => {
    expect(
      mutate((d) => (d.institutions[0].programs[0].offerings = [{ campus: 'Houston', intake: '01/2027', session: 'spring' }])).join(),
    ).toContain('une seule rentrée');
    expect(
      mutate((d) => (d.institutions[0].programs[0].offerings![0].intake = 'janvier 2027')).join(),
    ).toContain('rentrée illisible');
  });
});
