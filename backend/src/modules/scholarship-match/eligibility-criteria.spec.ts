import {
  parseEligibilityCriteria,
  validateEligibilityCriteria,
} from './eligibility-criteria';
import {
  age,
  experience,
  financialNeed,
  grade,
  language,
  nationality,
  other,
} from './testing/match-fixtures';

const VALID = [
  nationality('pas-francais', 'exclude', ['fra']),
  nationality('residents', 'include', ['ken', 'tza'], 'nationality_or_residence', 'soft'),
  age('age-licence', { level: 'bachelor', max: 21, maxInclusive: false }),
  age('age-date', { min: 16, max: 18, asOf: { kind: 'date', date: '2027-09-01' } }),
  age('age-cloture', { max: 29, asOf: { kind: 'cycle_close' } }),
  age('age-ouverture', { min: 16, asOf: { kind: 'cycle_open' } }),
  experience('xp', 24, 'hard', 'master'),
  language('ielts', { minCefr: 'b2', tests: [{ type: 'ielts', min: 6.5 }], waivable: true }),
  grade('moyenne', 12),
  grade('moyenne-70', undefined, 'informational'),
  financialNeed('besoin'),
  other('lettre'),
];

describe('validateEligibilityCriteria', () => {
  it('accepte chaque forme v1', () => {
    expect(validateEligibilityCriteria(VALID)).toEqual([]);
    expect(validateEligibilityCriteria([])).toEqual([]);
  });

  it('refuse ce qui n’est pas un tableau', () => {
    for (const value of [null, undefined, {}, 'x', 3]) {
      expect(validateEligibilityCriteria(value)).toEqual([
        expect.objectContaining({ code: 'not_array' }),
      ]);
    }
  });

  it.each([
    ['type inconnu', { ...other('x'), type: 'religion' }, 'unknown_type'],
    ['clé non slug', { ...other('x'), key: 'Pas Un Slug' }, 'invalid_key'],
    ['impact inconnu', { ...other('x'), impact: 'blocking' }, 'invalid_impact'],
    ['citation FR absente', { ...other('x'), officialTextFr: ' ' }, 'missing_official_text'],
    ['citation EN absente', { ...other('x'), officialTextEn: undefined }, 'missing_official_text'],
    ['source non http', { ...other('x'), sourceUrl: 'javascript:alert(1)' }, 'invalid_source_url'],
    ['source absente', { ...other('x'), sourceUrl: '' }, 'invalid_source_url'],
    ['appliesTo inconnu', { ...nationality('n', 'include', ['ner']), appliesTo: 'birthplace' }, 'invalid_applies_to'],
    ['mode inconnu', { ...nationality('n', 'include', ['ner']), mode: 'only' }, 'invalid_mode'],
    ['liste de pays vide', { ...nationality('n', 'include', ['ner']), countries: [] }, 'invalid_countries'],
    ['pays alpha-2', { ...nationality('n', 'include', ['ner']), countries: ['NE'] }, 'unknown_country'],
    ['pays en majuscules', { ...nationality('n', 'include', ['ner']), countries: ['NER'] }, 'unknown_country'],
    ['âge sans borne', age('a', {}), 'missing_age_bound'],
    ['bornes inversées', age('a', { min: 30, max: 18 }), 'inverted_age_bounds'],
    ['âge non entier', { ...age('a', { max: 29 }), max: 29.5 }, 'invalid_age'],
    ['maxInclusive absent', { ...age('a', { max: 29 }), maxInclusive: undefined }, 'invalid_max_inclusive'],
    ['asOf inconnu', { ...age('a', { max: 29 }), asOf: { kind: 'birthday' } }, 'invalid_as_of'],
    ['asOf date invalide', { ...age('a', { max: 29 }), asOf: { kind: 'date', date: '2027-02-30' } }, 'invalid_as_of'],
    ['niveau inconnu', { ...age('a', { max: 29 }), level: 'phd' }, 'invalid_level'],
    ['minMonths nul', { ...experience('x', 12), minMonths: 0 }, 'invalid_min_months'],
    ['langue sur 3 lettres', { ...language('l', { minCefr: 'b2' }), lang: 'eng' }, 'invalid_lang'],
    ['CECRL inconnu', { ...language('l', { minCefr: 'b2' }), minCefr: 'b3' }, 'invalid_cefr'],
    ['test inconnu', { ...language('l', { minCefr: 'b2' }), tests: [{ type: 'cambridge', min: 180 }] }, 'invalid_test_type'],
    ['score hors échelle', { ...language('l', { minCefr: 'b2' }), tests: [{ type: 'ielts', min: 10 }] }, 'invalid_test_score'],
    ['langue sans exigence', { ...language('l', {}), minCefr: undefined }, 'missing_language_requirement'],
    ['waivable absent', { ...language('l', { minCefr: 'b2' }), waivable: 'yes' }, 'invalid_waivable'],
    ['moyenne hors échelle', { ...grade('g', 12), minOn20: 25 }, 'invalid_min_on_20'],
    ['moyenne sans texte', { ...grade('g', 12), rawText: '' }, 'missing_raw_text'],
    ['besoin financier excluant', { ...financialNeed('b'), impact: 'hard' }, 'financial_need_not_informational'],
    ['pas un objet', 'nationality', 'not_object'],
  ])('%s → %s', (_name, criterion, code) => {
    const issues = validateEligibilityCriteria([criterion]);
    expect(issues.map((issue) => issue.code)).toContain(code);
    expect(issues.every((issue) => issue.path.startsWith('[0]'))).toBe(true);
  });

  it('refuse une clé en double', () => {
    const issues = validateEligibilityCriteria([other('lettre'), other('lettre')]);
    expect(issues).toEqual([expect.objectContaining({ path: '[1].key', code: 'duplicate_key' })]);
  });
});

describe('parseEligibilityCriteria (moteur)', () => {
  it('garde les critères valides, ignore et signale les autres, ne lève jamais', () => {
    const parsed = parseEligibilityCriteria([
      VALID[0],
      { ...VALID[1], countries: ['XX'] },
      42,
      VALID[2],
    ]);
    expect(parsed.criteria.map((criterion) => criterion.key)).toEqual(['pas-francais', 'age-licence']);
    expect(parsed.ignoredKeys).toEqual(['residents', '#2']);
    expect(parsed.issues.length).toBeGreaterThan(0);
  });

  it('JSON qui n’est pas un tableau : aucun critère, signalé', () => {
    expect(parseEligibilityCriteria({ type: 'nationality' })).toMatchObject({
      criteria: [],
      ignoredKeys: ['*'],
    });
    expect(parseEligibilityCriteria(null)).toEqual({ criteria: [], issues: [], ignoredKeys: [] });
  });

  it('ne recopie aucun champ inconnu et dédoublonne les pays', () => {
    const [criterion] = parseEligibilityCriteria([
      { ...nationality('n', 'include', ['ner', 'ner', 'sen']), extra: 'x', __proto__: { y: 1 } },
    ]).criteria;
    expect(criterion).toEqual({
      key: 'n',
      type: 'nationality',
      impact: 'hard',
      appliesTo: 'nationality',
      mode: 'include',
      countries: ['ner', 'sen'],
      officialTextFr: 'Texte officiel.',
      officialTextEn: 'Official text.',
      sourceUrl: 'https://example.org/eligibility',
    });
  });

  it('au plus 40 critères ; les suivants sont ignorés', () => {
    const many = Array.from({ length: 45 }, (_, i) => other(`c${i}`));
    const parsed = parseEligibilityCriteria(many);
    expect(parsed.criteria).toHaveLength(40);
    expect(parsed.ignoredKeys).toHaveLength(5);
    expect(parsed.issues).toContainEqual(expect.objectContaining({ code: 'too_many_criteria' }));
  });
});
