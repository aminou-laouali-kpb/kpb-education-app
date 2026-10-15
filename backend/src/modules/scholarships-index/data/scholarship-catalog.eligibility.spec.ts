import type { EligibilityCriterion } from '../../scholarship-match/eligibility-criteria';
import {
  AFRICAN_COUNTRY_CODES,
  STRUCTURED_ELIGIBILITY_V1,
  attachStructuredEligibility,
  resolveEligibilityDraft,
} from './scholarship-catalog.eligibility.v1';
import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';
import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';
import { validateScholarshipCatalog } from './scholarship-catalog.validator';

/**
 * Les règles de rédaction des brouillons d'éligibilité (catalogue 1.5.0),
 * vérifiées sur les 36 fiches, puis les cas que la spécification du chantier D
 * nomme explicitement.
 */

function record(id: string): VerifiedScholarshipCatalogRecord {
  const found = SCHOLARSHIP_CATALOG_V1.records.find((item) => item.scholarship.id === id);
  if (!found) throw new Error(`fiche ${id} absente`);
  return found;
}

function criteria(id: string): EligibilityCriterion[] {
  return record(id).eligibility!.criteria;
}

function criterion(id: string, key: string): EligibilityCriterion {
  const found = criteria(id).find((item) => item.key === key);
  if (!found) throw new Error(`critère ${key} absent de ${id}`);
  return found;
}

describe('brouillons d’éligibilité — règles de rédaction', () => {
  it('chaque fiche a un brouillon, et chaque brouillon une fiche', () => {
    const ids = SCHOLARSHIP_CATALOG_V1.records.map((item) => item.scholarship.id).sort();
    expect(Object.keys(STRUCTURED_ELIGIBILITY_V1).sort()).toEqual(ids);
    for (const item of SCHOLARSHIP_CATALOG_V1.records) {
      expect(item.eligibility?.criteria.length).toBeGreaterThan(0);
    }
  });

  it('chaque ligne d’éligibilité est citée par au moins un critère', () => {
    // La relecture se fait ligne à ligne : une ligne sans critère serait une
    // condition que le moteur ignore sans le dire.
    for (const item of SCHOLARSHIP_CATALOG_V1.records) {
      const quoted = new Set(item.eligibility!.criteria.map((entry) => entry.officialTextFr));
      const uncovered = item.scholarship.eligibilityFr.filter((line) => !quoted.has(line));
      expect({ id: item.scholarship.id, uncovered }).toEqual({
        id: item.scholarship.id,
        uncovered: [],
      });
    }
  });

  it('cite la source officielle « eligibility » de la fiche', () => {
    for (const item of SCHOLARSHIP_CATALOG_V1.records) {
      const source = item.officialSources.find((entry) => entry.kind === 'eligibility')!.url;
      for (const entry of item.eligibility!.criteria) expect(entry.sourceUrl).toBe(source);
    }
  });

  it('« hard » seulement pour la nationalité, la résidence, l’âge ou l’expérience', () => {
    for (const item of SCHOLARSHIP_CATALOG_V1.records) {
      for (const entry of item.eligibility!.criteria) {
        if (entry.impact === 'hard') {
          expect(['nationality', 'age', 'work_experience']).toContain(entry.type);
        }
        if (entry.type === 'financial_need') expect(entry.impact).toBe('informational');
        // Pourcentages, GPA, « tiers supérieur » : jamais convertis en /20.
        if (entry.type === 'academic_grade' && entry.minOn20 !== undefined) {
          expect(entry.officialTextFr).toMatch(/7\/10/);
        }
      }
    }
  });

  it('ce sont des brouillons : aucun tampon, signés « draft », n’excluent personne', () => {
    for (const item of SCHOLARSHIP_CATALOG_V1.records) {
      expect(item.eligibility!.structuredAt).toBeNull();
      expect(item.eligibility!.structuredBy).toBe('draft');
    }
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      now: new Date('2026-10-07T18:00:00.000Z'),
      includeVolumeTargets: false,
    });
    expect(report.issues).toEqual([]);
  });
});

describe('brouillons d’éligibilité — cas nommés par la spécification', () => {
  it('Eiffel : exclut les binationaux français, « 29 ans au plus » sans date', () => {
    expect(criterion('eiffel_excellence_master_2027', 'pas-de-nationalite-francaise')).toMatchObject({
      type: 'nationality',
      impact: 'hard',
      appliesTo: 'nationality',
      mode: 'exclude',
      countries: ['fra'],
    });
    expect(criterion('eiffel_excellence_master_2027', 'age-29-au-plus')).toMatchObject({
      type: 'age',
      impact: 'hard',
      max: 29,
      maxInclusive: true,
      asOf: { kind: 'unspecified' },
    });
    expect(record('eiffel_excellence_master_2027').eligibility!.fieldsScope).toBe('listed');
  });

  it('Türkiye : exclut les citoyens turcs, âge par niveau, 70 % souple', () => {
    const id = 'turkiye_scholarships_2027_forecast';
    expect(criterion(id, 'pas-citoyen-turc')).toMatchObject({
      impact: 'hard',
      mode: 'exclude',
      countries: ['tur'],
    });
    expect(criterion(id, 'age-licence-moins-21')).toMatchObject({
      level: 'bachelor',
      max: 21,
      maxInclusive: false,
    });
    expect(criterion(id, 'age-master-moins-30')).toMatchObject({
      level: 'master',
      max: 30,
      maxInclusive: false,
    });
    const grade = criterion(id, 'moyenne-70-75-90');
    expect(grade).toMatchObject({ type: 'academic_grade', impact: 'soft' });
    expect(grade).not.toHaveProperty('minOn20');
    // La citation officielle garde le « % » : elle est exemptée de l'invariant.
    expect(grade.officialTextFr).toContain('70 %');
  });

  it('UWC : Kenya « citoyen ou résident », Tanzanie « ou résident permanent », Burkina « et résident permanent »', () => {
    expect(criterion('uwc_kenya_entry_2027', 'citoyen-ou-resident-ke')).toMatchObject({
      appliesTo: 'nationality_or_residence',
      mode: 'include',
      countries: ['ken'],
      impact: 'hard',
    });
    expect(criterion('uwc_tanzania_2027_forecast', 'citoyen-ou-resident-tz')).toMatchObject({
      appliesTo: 'nationality_or_residence',
      countries: ['tza'],
    });
    expect(criterion('uwc_burkina_faso_2027_forecast', 'citoyen-et-resident-bf')).toMatchObject({
      appliesTo: 'nationality_and_residence',
      countries: ['bfa'],
    });
    // Kenya date ses bornes (année d'entrée 2027, 19 ans après le 1er septembre).
    expect(criterion('uwc_kenya_entry_2027', 'age-19-apres-1er-septembre')).toMatchObject({
      max: 19,
      maxInclusive: false,
      asOf: { kind: 'date', date: '2027-09-01' },
    });
  });

  it('Taiwan ICDF : les « alliés diplomatiques » restent une condition citée, pas une liste inventée', () => {
    const rule = criterion('taiwan_icdf_2027', 'licence-allies-diplomatiques');
    expect(rule).toMatchObject({ type: 'other', impact: 'soft' });
    expect(rule.officialTextFr).toContain('allié diplomatique');
    expect(criterion('taiwan_icdf_2027', 'pas-ressortissant-taiwanais')).toMatchObject({
      mode: 'exclude',
      countries: ['twn'],
      impact: 'hard',
    });
  });

  it('une limite assortie d’une exception reste souple (Rhodes, JJ/WBGSP, Gates)', () => {
    expect(criterion('rhodes_southern_africa_2027', 'age-19-24-voies-particulieres').impact).toBe('soft');
    expect(criterion('jj_wbgsp_2027_forecast', 'experience-trois-ans').impact).toBe('soft');
    // Gates : les binationaux britanniques sont éligibles — une exclusion
    // « n'importe laquelle » les écarterait à tort.
    expect(criterion('gates_cambridge_2027', 'hors-royaume-uni').impact).toBe('soft');
  });

  it('« Africain » : les 54 États de l’ONU et le Sahara occidental, sans doublon', () => {
    expect(new Set(AFRICAN_COUNTRY_CODES).size).toBe(55);
    expect(criterion('cmu_africa_mastercard_2027', 'nationalite-africaine')).toMatchObject({
      impact: 'hard',
      mode: 'include',
    });
  });
});

describe('resolveEligibilityDraft / attachStructuredEligibility', () => {
  const eiffel = record('eiffel_excellence_master_2027');
  const bare: VerifiedScholarshipCatalogRecord = { ...eiffel, eligibility: undefined };

  it('cite la ligne désignée, mot pour mot, en FR et en EN', () => {
    const resolved = resolveEligibilityDraft(bare, {
      fieldsScope: 'unknown',
      criteria: [{ type: 'other', key: 'ligne-2', line: 2, impact: 'soft' }],
    });
    expect(resolved.criteria[0]).toMatchObject({
      officialTextFr: eiffel.scholarship.eligibilityFr[2],
      officialTextEn: eiffel.scholarship.eligibilityEn[2],
    });
    expect(resolved).toMatchObject({ structuredAt: null, structuredBy: 'draft' });
  });

  it('une ligne hors limites donne une citation vide, que le validateur refuse', () => {
    const resolved = resolveEligibilityDraft(bare, {
      fieldsScope: 'unknown',
      criteria: [{ type: 'other', key: 'hors-limites', line: 99, impact: 'soft' }],
    });
    const report = validateScholarshipCatalog(
      { ...SCHOLARSHIP_CATALOG_V1, records: [{ ...bare, eligibility: resolved }] },
      { now: new Date('2026-10-07T18:00:00.000Z'), includeVolumeTargets: false },
    );
    expect(report.issues.map((issue) => issue.code)).toEqual(
      expect.arrayContaining(['invalid_eligibility_criterion', 'criterion_quote_not_in_record']),
    );
  });

  it('une relecture tamponne la fiche avec la date et le nom de l’éditeur', () => {
    const resolved = resolveEligibilityDraft(bare, {
      fieldsScope: 'listed',
      criteria: [],
      reviewed: { at: '2026-10-20T09:00:00.000Z', by: 'Éditrice KPB' },
    });
    expect(resolved).toMatchObject({
      structuredAt: '2026-10-20T09:00:00.000Z',
      structuredBy: 'Éditrice KPB',
    });
  });

  it('garde un bloc déjà présent et laisse sans bloc une fiche sans brouillon', () => {
    const [kept, untouched] = attachStructuredEligibility(
      [eiffel, { ...bare, scholarship: { ...bare.scholarship, id: 'sans-brouillon' } }],
    );
    expect(kept.eligibility).toBe(eiffel.eligibility);
    expect(untouched.eligibility).toBeUndefined();
  });
});
