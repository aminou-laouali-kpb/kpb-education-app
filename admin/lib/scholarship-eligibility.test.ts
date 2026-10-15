import { describe, expect, it } from 'vitest';

import {
  criterionToDraft,
  draftToCriterion,
  eligibilityDraftFrom,
  eligibilityPatchBody,
  eligibilityStateOf,
  emptyCriterionDraft,
  EMPTY_PREVIEW_FORM,
  formatPercent,
  isCatalogManaged,
  needsStructuring,
  previewBody,
  readEligibilityError,
  sameEligibility,
  scholarshipAdminHref,
  suggestKey,
  validateCriterionDraft,
  validateEligibilityDraft,
  type CriterionDraft,
  type EligibilityDraft,
} from './scholarship-eligibility';
import type { EligibilityCriterion } from './scholarship-eligibility-types';

const NOW = new Date('2026-10-15T12:00:00.000Z');
const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (days: number) => new Date(NOW.getTime() - days * DAY_MS).toISOString();

const QUOTE = {
  officialTextFr: 'Texte officiel.',
  officialTextEn: 'Official text.',
  sourceUrl: 'https://example.org/eligibility',
};

/** Un critère valide par type, au format stocké par le serveur. */
const CRITERIA: EligibilityCriterion[] = [
  {
    type: 'nationality',
    key: 'pas-francais',
    impact: 'hard',
    appliesTo: 'nationality',
    mode: 'exclude',
    countries: ['fra'],
    ...QUOTE,
  },
  {
    type: 'age',
    key: 'age-max',
    impact: 'hard',
    level: 'master',
    max: 29,
    maxInclusive: true,
    asOf: { kind: 'date', date: '2027-01-10' },
    ...QUOTE,
  },
  { type: 'work_experience', key: 'experience', impact: 'hard', minMonths: 24, ...QUOTE },
  {
    type: 'language',
    key: 'anglais',
    impact: 'soft',
    lang: 'en',
    minCefr: 'b2',
    tests: [{ type: 'ielts', min: 6.5 }],
    waivable: true,
    ...QUOTE,
  },
  {
    type: 'academic_grade',
    key: 'moyenne',
    impact: 'soft',
    minOn20: 12,
    rawText: '70 % en Licence',
    ...QUOTE,
  },
  { type: 'financial_need', key: 'besoin', impact: 'informational', ...QUOTE },
  { type: 'other', key: 'autre', impact: 'soft', ...QUOTE },
];

function draftOf(criterion: EligibilityCriterion): CriterionDraft {
  return criterionToDraft(criterion);
}

describe('état d’éligibilité d’une fiche (colonne « Éligibilité »)', () => {
  it('classe comme le serveur : ✓ / périmée / brouillon / ✗', () => {
    expect(eligibilityStateOf({ eligibleLevels: ['master'], eligibilityStructuredAt: daysAgo(10) }, NOW)).toBe('fresh');
    expect(eligibilityStateOf({ eligibleLevels: ['master'], eligibilityStructuredAt: daysAgo(399) }, NOW)).toBe('fresh');
    expect(eligibilityStateOf({ eligibleLevels: ['master'], eligibilityStructuredAt: daysAgo(400) }, NOW)).toBe('stale');
    expect(eligibilityStateOf({ eligibleLevels: ['master'], eligibilityStructuredAt: null }, NOW)).toBe('unstructured');
    expect(eligibilityStateOf({ eligibleLevels: [], eligibilityStructuredAt: daysAgo(1) }, NOW)).toBe('not_analyzed');
    // Backend antérieur : champs absents → non analysée.
    expect(eligibilityStateOf({}, NOW)).toBe('not_analyzed');
  });

  it('suit la fraîcheur servie par le serveur', () => {
    expect(eligibilityStateOf({ eligibleLevels: ['master'], eligibilityStructuredAt: daysAgo(40) }, NOW, 30)).toBe('stale');
  });

  it('« À structurer » : tout sauf frais', () => {
    expect(needsStructuring({ eligibleLevels: ['master'], eligibilityStructuredAt: daysAgo(1) }, NOW)).toBe(false);
    expect(needsStructuring({ eligibleLevels: ['master'], eligibilityStructuredAt: null }, NOW)).toBe(true);
  });

  it('reconnaît une fiche issue du catalogue du dépôt', () => {
    expect(isCatalogManaged(['catalog:v1', 'level:master'])).toBe(true);
    expect(isCatalogManaged(['level:master'])).toBe(false);
    expect(isCatalogManaged(undefined)).toBe(false);
  });

  it('affiche le pourcentage sans jamais arrondir vers le haut', () => {
    expect(formatPercent(89.96, 'fr')).toBe('89,9 %');
    expect(formatPercent(90, 'fr')).toBe('90 %');
    expect(formatPercent(86.1, 'en')).toBe('86.1%');
  });
});

describe('sérialisation des critères', () => {
  it.each(CRITERIA.map((criterion) => [criterion.type, criterion] as const))(
    'aller-retour sans perte : %s',
    (_type, criterion) => {
      expect(draftToCriterion(draftOf(criterion))).toEqual(criterion);
    },
  );

  it('ne garde que les champs du type choisi', () => {
    const draft = { ...emptyCriterionDraft('other'), countries: ['ner'], min: '18', rawText: 'x', ...QUOTE };
    expect(Object.keys(draftToCriterion(draft)).sort()).toEqual(
      ['impact', 'key', 'officialTextEn', 'officialTextFr', 'sourceUrl', 'type'].sort(),
    );
  });

  it('force « Information » pour le besoin financier', () => {
    const draft = { ...emptyCriterionDraft('financial_need'), impact: 'hard' as const, ...QUOTE };
    expect(draftToCriterion(draft).impact).toBe('informational');
  });

  it('lit une virgule décimale et un âge sans date de référence', () => {
    const age = { ...emptyCriterionDraft('age'), max: '30', maxInclusive: false, asOfKind: 'cycle_close' as const, ...QUOTE };
    expect(draftToCriterion(age)).toMatchObject({ max: 30, maxInclusive: false, asOf: { kind: 'cycle_close' } });
    const language = { ...emptyCriterionDraft('language'), tests: [{ type: 'ielts' as const, min: '6,5' }], ...QUOTE };
    expect(draftToCriterion(language)).toMatchObject({ tests: [{ type: 'ielts', min: 6.5 }] });
  });

  it('dédoublonne les pays', () => {
    const draft = { ...emptyCriterionDraft('nationality'), countries: ['ner', 'ner', 'sen'], ...QUOTE };
    expect(draftToCriterion(draft)).toMatchObject({ countries: ['ner', 'sen'] });
  });

  it('lit un critère stocké illisible sans planter', () => {
    const draft = criterionToDraft({ type: 'inconnu', countries: 'fra', min: '18' });
    expect(draft.type).toBe('other');
    expect(draft.countries).toEqual([]);
    expect(draft.min).toBe('');
    expect(criterionToDraft(null).type).toBe('other');
  });

  it('propose une clé libre par type', () => {
    expect(suggestKey('work_experience', [])).toBe('work-experience');
    expect(suggestKey('age', ['age', 'age-2'])).toBe('age-3');
    const keys = ['nationality'];
    expect(emptyCriterionDraft('nationality', keys).key).toBe('nationality-2');
  });

  it('niveaux dans l’ordre canonique, domaines par défaut « non précisé »', () => {
    const draft = eligibilityDraftFrom({ eligibleLevels: ['doctorate', 'master', 'xx'], fieldsScope: 'bogus', eligibilityCriteria: 'nope' });
    expect(draft).toMatchObject({ eligibleLevels: ['master', 'doctorate'], fieldsScope: 'unknown', criteria: [] });
  });
});

describe('validation côté client', () => {
  const codes = (draft: CriterionDraft, known?: ReadonlySet<string>) =>
    validateCriterionDraft(draft, 0, known).map((issue) => issue.code);

  it('accepte chaque critère valide', () => {
    for (const criterion of CRITERIA) expect(codes(draftOf(criterion))).toEqual([]);
  });

  it('exige les citations FR/EN et une URL source http(s)', () => {
    const draft = { ...draftOf(CRITERIA[6]), officialTextFr: '  ', officialTextEn: '', sourceUrl: 'ftp://x' };
    expect(codes(draft)).toEqual([
      'missing_official_text_fr',
      'missing_official_text_en',
      'invalid_source_url',
    ]);
  });

  it('refuse une clé qui n’est pas un slug', () => {
    expect(codes({ ...draftOf(CRITERIA[6]), key: 'Âge Max' })).toContain('invalid_key');
  });

  it('nationalité : au moins un pays, connus de la table servie', () => {
    expect(codes({ ...draftOf(CRITERIA[0]), countries: [] })).toContain('invalid_countries');
    expect(codes({ ...draftOf(CRITERIA[0]), countries: ['xxx'] }, new Set(['fra']))).toContain('unknown_country');
    // Sans table chargée, le serveur reste seul juge.
    expect(codes({ ...draftOf(CRITERIA[0]), countries: ['xxx'] })).toEqual([]);
  });

  it('âge : une borne, entiers 0-120, min ≤ max, date valide', () => {
    const age = draftOf(CRITERIA[1]);
    expect(codes({ ...age, min: '', max: '' })).toContain('missing_age_bound');
    expect(codes({ ...age, max: '29.5' })).toContain('invalid_age');
    expect(codes({ ...age, min: '30', max: '20' })).toContain('inverted_age_bounds');
    expect(codes({ ...age, asOfDate: '2027-02-30' })).toContain('invalid_as_of_date');
    expect(codes({ ...age, asOfKind: 'unspecified', asOfDate: '' })).toEqual([]);
  });

  it('expérience, langue, moyenne', () => {
    expect(codes({ ...draftOf(CRITERIA[2]), minMonths: '0' })).toContain('invalid_min_months');
    const language = draftOf(CRITERIA[3]);
    expect(codes({ ...language, lang: 'eng' })).toContain('invalid_lang');
    expect(codes({ ...language, minCefr: '', tests: [] })).toContain('missing_language_requirement');
    expect(codes({ ...language, tests: [{ type: 'ielts', min: '10' }] })).toContain('invalid_test_score');
    const grade = draftOf(CRITERIA[4]);
    expect(codes({ ...grade, minOn20: '21' })).toContain('invalid_min_on_20');
    expect(codes({ ...grade, rawText: '' })).toContain('missing_raw_text');
  });

  it('fiche : clés uniques, niveau exigé pour le tampon seulement', () => {
    const draft: EligibilityDraft = {
      eligibleLevels: [],
      fieldsScope: 'all',
      criteria: [draftOf(CRITERIA[6]), draftOf(CRITERIA[6])],
    };
    expect(validateEligibilityDraft(draft).map((issue) => [issue.index, issue.code])).toEqual([
      [1, 'duplicate_key'],
    ]);
    expect(validateEligibilityDraft(draft, { forStamp: true })[0]).toEqual({
      index: null,
      field: 'eligibleLevels',
      code: 'levels_required',
    });
  });
});

describe('corps d’écriture et erreurs du serveur', () => {
  const draft: EligibilityDraft = {
    eligibleLevels: ['doctorate', 'master'],
    fieldsScope: 'listed',
    criteria: CRITERIA.map(draftOf),
  };

  it('envoie niveaux ordonnés, domaines, critères et, sur demande, le tampon', () => {
    expect(eligibilityPatchBody(draft)).toEqual({
      eligibleLevels: ['master', 'doctorate'],
      fieldsScope: 'listed',
      eligibilityCriteria: CRITERIA,
    });
    expect(eligibilityPatchBody(draft, true).markStructured).toBe(true);
  });

  it('compare deux brouillons sur ce qui est envoyé, pas sur les uid', () => {
    const again = { ...draft, criteria: CRITERIA.map(draftOf) };
    expect(sameEligibility(draft, again)).toBe(true);
    expect(sameEligibility(draft, { ...draft, fieldsScope: 'all' })).toBe(false);
  });

  it('lit la liste d’erreurs d’une 400 et la rattache au critère', () => {
    const error = Object.assign(new Error('x'), {
      status: 400,
      body: JSON.stringify({
        code: 'INVALID_ELIGIBILITY_CRITERIA',
        message: ['…'],
        issues: [
          { path: '[2].countries[0]', code: 'unknown_country', message: 'Code pays inconnu' },
          { path: '', code: 'not_array', message: 'tableau attendu' },
        ],
      }),
    });
    expect(readEligibilityError(error)).toEqual({
      code: 'INVALID_ELIGIBILITY_CRITERIA',
      issues: [
        { index: 2, path: '[2].countries[0]', message: 'Code pays inconnu' },
        { index: null, path: '', message: 'tableau attendu' },
      ],
    });
    expect(readEligibilityError(new Error('réseau'))).toBeNull();
    expect(readEligibilityError({ body: 'pas du JSON' })).toBeNull();
  });
});

describe('aperçu « Tester un profil »', () => {
  it('n’envoie que les champs remplis, confirmé par défaut', () => {
    expect(previewBody(EMPTY_PREVIEW_FORM)).toEqual({ lang: 'fr', confirmed: true });
  });

  it('découpe domaines et destinations, garde un test de langue lisible', () => {
    expect(
      previewBody(
        {
          ...EMPTY_PREVIEW_FORM,
          nationalityCode: 'ner',
          birthDate: '2000-05-10',
          fieldIds: 'engineering, health;  law',
          targetCountryIds: 'FRA can',
          languageTestType: 'ielts',
          languageTestScore: '6,5',
          guardianConsented: true,
          confirmed: false,
        },
        'sch-1',
      ),
    ).toEqual({
      lang: 'fr',
      confirmed: false,
      nationalityCode: 'ner',
      birthDate: '2000-05-10',
      guardianConsented: true,
      fieldIds: ['engineering', 'health', 'law'],
      targetCountryIds: ['fra', 'can'],
      languageTests: [{ type: 'ielts', score: 6.5 }],
      focusScholarshipId: 'sch-1',
    });
  });

  it('lien profond vers la fiche', () => {
    expect(scholarshipAdminHref('sch 1')).toBe('/scholarships?scholarshipId=sch%201');
  });
});
