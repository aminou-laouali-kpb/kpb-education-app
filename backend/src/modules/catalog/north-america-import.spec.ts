import * as fs from 'node:fs';
import * as path from 'node:path';

import {
  NA_COUNTRIES,
  type NaExistingInstitution,
  type NaExistingProgram,
  type NaSource,
  naPlanWriteCount,
  naProgramCreateData,
  naProgramId,
  naToEur,
  planNorthAmerica,
  tuitionLabelProblems,
  validateNaSource,
} from './north-america-import';
import { detectCurrencies } from './tuition-eur';

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

  it('compte 10 établissements au Canada, 10 aux États-Unis, 4 à 7 formations chacun', () => {
    const by = (c: string) => doc.institutions.filter((i) => i.countryId === c);
    expect(by('can')).toHaveLength(10);
    expect(by('usa')).toHaveLength(10);
    for (const inst of doc.institutions) {
      expect(inst.programs.length).toBeGreaterThanOrEqual(4);
      expect(inst.programs.length).toBeLessThanOrEqual(8);
      expect(inst.id.startsWith(NA_COUNTRIES[inst.countryId].prefix)).toBe(true);
    }
    expect(doc.institutions.reduce((n, i) => n + i.programs.length, 0)).toBe(97);
  });

  it('l’Université d’Ottawa (déjà au catalogue sous `uottawa`) n’est pas dans la source', () => {
    expect(doc.institutions.map((i) => i.nameEn)).not.toContain('University of Ottawa');
  });

  it('chaque libellé de frais est lisible par l’app : une seule devise, écrite en code', () => {
    for (const inst of doc.institutions) {
      for (const p of inst.programs) {
        for (const label of [p.tuitionFr, p.tuitionEn].filter(Boolean)) {
          expect(label).not.toContain('$');
          expect(detectCurrencies(label)).toEqual([p.tuitionAnnual!.currency]);
        }
      }
    }
  });
});

describe('import:north-america — lignes écrites', () => {
  const doc = load();
  const plan = planNorthAmerica(doc, [], []);

  it('crée des établissements NON partenaires, actifs, sourcés et datés', () => {
    expect(plan.newInstitutions).toHaveLength(20);
    for (const { institution, programs } of plan.newInstitutions) {
      expect(institution.isPartner).toBe(false);
      expect(institution.isActive).toBe(true);
      expect(institution.lastVerifiedAt.toISOString()).toBe('2026-10-16T00:00:00.000Z');
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
        expect(['Bachelor', 'BBA', 'Master']).toContain(p.levelFr);
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
    expect(naToEur(null, doc.exchangeRates.perEur)).toBeNull();
    expect(naToEur({ amount: 100, currency: 'GBP' }, doc.exchangeRates.perEur)).toBeNull();
  });

  it('sans montant publié, `tuitionMinEur` reste nul et le libellé de l’école est repris', () => {
    const uqac = doc.institutions.find((i) => i.id === 'na-ca-uqac')!;
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
    expect(naPlanWriteCount(first)).toBe(20);
    applyInMemory(first, institutions, programs);
    const second = planNorthAmerica(doc, institutions, programs);
    expect(naPlanWriteCount(second)).toBe(0);
    expect(second.unchanged).toHaveLength(20);
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
