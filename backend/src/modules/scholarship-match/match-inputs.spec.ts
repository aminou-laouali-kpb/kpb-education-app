import {
  ageOn,
  diplomaFromCurrentLevel,
  legacyCompatibilityWrites,
  normaliseProfile,
  parseLanguageTests,
  prefill,
  profileHash,
  readiness,
  stableHash,
  targetFromLegacy,
  type MatchProfileSource,
} from './match-inputs';
import { date, NOW } from './testing/match-fixtures';

/** Un profil complet et confirmé, Licence. */
function completeSource(overrides: Partial<MatchProfileSource> = {}): MatchProfileSource {
  return {
    nationalityCode: 'ner',
    countryOfResidence: 'Niger',
    birthDate: date('2006-05-10'),
    highestDiploma: 'bac',
    scholarshipTargetLevel: 'bachelor',
    fieldIds: ['engineering'],
    gradeBandOn20: '12_14',
    englishLevel: 'b1',
    scholarshipProfileConfirmedAt: date('2026-10-01'),
    ...overrides,
  };
}

describe('normaliseProfile', () => {
  it('abandonne les jetons inconnus au lieu de les refuser', () => {
    const profile = normaliseProfile(
      completeSource({
        highestDiploma: 'bac_plus_7',
        scholarshipTargetLevel: 'Bachelor',
        gradeBandOn20: '15+/20',
        englishLevel: 'fluent',
        workExperienceBand: '10_years',
        nationalityCode: 'xx',
      }),
    );
    expect(profile).toMatchObject({
      highestDiploma: null,
      targetLevel: null,
      gradeBand: null,
      englishLevel: null,
      workExperienceBand: null,
      nationalities: [],
    });
  });

  it('normalise la résidence libre de l’onboarding et les nationalités', () => {
    const cases: Array<[string, string | null]> = [
      ['Sénégal', 'sen'],
      ["Cote d'Ivoire", 'civ'],
      ['Côte d’Ivoire', 'civ'],
      ['RDC', 'cod'],
      ['Congo-Brazzaville', 'cog'],
      ['Congo', 'cog'],
      ['Centrafrique', 'caf'],
      ['Tchad', 'tcd'],
      ['Comores', 'com'],
      ['Djibouti', 'dji'],
      ['Guinée-Bissau', 'gnb'],
      ['Cap-Vert', 'cpv'],
      ['  niger ', 'ner'],
      ['Nigeria', 'nga'],
      ['Autre', null],
      ['', null],
      ['Antarctique', null], // territoire inhabité : jamais une résidence
    ];
    for (const [residence, code] of cases) {
      expect([residence, normaliseProfile({ countryOfResidence: residence }).residenceCode]).toEqual([
        residence,
        code,
      ]);
    }
    expect(
      normaliseProfile({ nationalityCode: 'ken', secondNationalityCode: 'ken' }).nationalities,
    ).toEqual(['ken']);
    expect(
      normaliseProfile({ nationalityCode: 'cmr', secondNationalityCode: 'fra' }).nationalities,
    ).toEqual(['cmr', 'fra']);
  });

  it('lit languageTests par une garde (meilleur score par type, entrées invalides abandonnées)', () => {
    expect(
      parseLanguageTests([
        { type: 'ielts', score: 6 },
        { type: 'ielts', score: '6,5', takenAt: '2026-03-01' },
        { type: 'toefl_ibt', score: 200 },
        { type: 'cambridge', score: 180 },
        'ielts 7',
        null,
      ]),
    ).toEqual([{ type: 'ielts', score: 6.5, takenAt: '2026-03-01' }]);
    expect(parseLanguageTests({ type: 'ielts' })).toEqual([]);
  });
});

describe('readiness', () => {
  it('profil complet et confirmé : prêt', () => {
    const result = readiness(normaliseProfile(completeSource()), NOW);
    expect(result).toMatchObject({ ready: true, required: [], toConfirm: [] });
  });

  it('profil vide : toutes les clés obligatoires de base manquent', () => {
    const result = readiness(normaliseProfile({}), NOW);
    expect(result.ready).toBe(false);
    expect(result.required).toEqual([
      'nationalityCode',
      'residence',
      'birthDate',
      'highestDiploma',
      'scholarshipTargetLevel',
      'fields',
      'gradeBandOn20',
      'englishLevel',
    ]);
    expect(result.optional).toEqual([
      'targetCountryIds',
      'frenchLevel',
      'languageTests',
      'secondNationalityCode',
    ]);
  });

  it('un mineur sans accord parental doit passer par l’étape du représentant légal', () => {
    const minor = completeSource({ birthDate: date('2010-01-01') });
    expect(readiness(normaliseProfile(minor), NOW).required).toEqual(['guardianConsent']);
    expect(
      readiness(normaliseProfile({ ...minor, guardianConsentedAt: date('2026-01-01') }), NOW).required,
    ).toEqual([]);
    // Majeur : la clé est sans objet.
    expect(readiness(normaliseProfile(completeSource()), NOW).required).toEqual([]);
  });

  it.each([
    ['bachelor', []],
    ['master', ['workExperienceBand']],
    ['doctorate', ['workExperienceBand']],
  ])('cible %s : expérience exigée seulement en Master et Doctorat', (target, required) => {
    expect(
      readiness(normaliseProfile(completeSource({ scholarshipTargetLevel: target })), NOW).required,
    ).toEqual(required);
  });

  it.each([
    ['17 ans', '2009-01-01', true],
    ['19 ans', '2007-01-01', true],
    ['20 ans', '2006-01-01', false],
  ])('lycée (UWC) proposé jusqu’à 19 ans : %s', (_name, birth, offered) => {
    const result = readiness(normaliseProfile({ birthDate: date(birth) }), NOW);
    expect(result.targetLevelOptions.includes('secondary')).toBe(offered);
  });

  it('lycée jamais proposé sans bourse de lycée au catalogue, ni sans date de naissance', () => {
    const young = normaliseProfile({ birthDate: date('2009-01-01') });
    expect(
      readiness(young, NOW, { hasSecondaryCandidates: false }).targetLevelOptions,
    ).toEqual(['bachelor', 'master', 'doctorate']);
    expect(readiness(normaliseProfile({}), NOW).targetLevelOptions).not.toContain('secondary');
  });

  it('non confirmé : chaque valeur utilisée est à confirmer, l’accord parental non', () => {
    const source = completeSource({
      scholarshipProfileConfirmedAt: null,
      birthDate: date('2010-01-01'),
      guardianConsentedAt: date('2026-01-01'),
      frenchLevel: 'c1_c2',
    });
    const result = readiness(normaliseProfile(source), NOW);
    expect(result.ready).toBe(false);
    expect(result.toConfirm).toEqual([
      'nationalityCode',
      'residence',
      'birthDate',
      'highestDiploma',
      'scholarshipTargetLevel',
      'fields',
      'gradeBandOn20',
      'englishLevel',
      'frenchLevel',
    ]);
  });

  it('« pas encore décidé » (aucun domaine) n’est accepté qu’une fois confirmé', () => {
    expect(
      readiness(normaliseProfile(completeSource({ fieldIds: [] })), NOW).required,
    ).toEqual([]);
    expect(
      readiness(
        normaliseProfile(completeSource({ fieldIds: [], scholarshipProfileConfirmedAt: null })),
        NOW,
      ).required,
    ).toEqual(['fields']);
  });
});

describe('prefill', () => {
  function suggestions(source: MatchProfileSource) {
    return prefill(source, normaliseProfile(source));
  }

  it.each([
    ['High school', 'none'],
    ['Terminale', 'none'],
    ['Bachelor 1', 'bac'],
    ['L2', 'bac'],
    ['Bachelor 3', 'bac_plus_2'],
    ['Master 1', 'licence'],
    ['M2', 'licence'],
    ['Doctorat', 'master'],
    ['Bachelor', 'bac'],
    ['???', null],
  ])('currentLevel « %s » → diplôme %s', (currentLevel, diploma) => {
    expect(diplomaFromCurrentLevel(currentLevel)).toBe(diploma);
  });

  it.each([
    ['Bachelor', 'bachelor'],
    ['Licence', 'bachelor'],
    ['Master', 'master'],
    ['PhD', 'doctorate'],
    ['', null],
  ])('targetLevel « %s » → %s', (legacy, target) => {
    expect(targetFromLegacy(legacy)).toBe(target);
  });

  it('les valeurs par défaut de l’onboarding deviennent des suggestions, jamais des réponses', () => {
    const source: MatchProfileSource = {
      countryOfResidence: 'Niger',
      currentLevel: 'High school',
      targetLevel: 'Bachelor',
      languageLevel: 'Intermediate',
      gradeRange: '12 - 14/20',
    };
    expect(suggestions(source)).toEqual([
      { key: 'nationalityCode', value: 'ner', source: 'countryOfResidence', ambiguous: true },
      { key: 'residence', value: 'ner', source: 'countryOfResidence', ambiguous: false },
      { key: 'highestDiploma', value: 'none', source: 'currentLevel', ambiguous: true },
      { key: 'scholarshipTargetLevel', value: 'bachelor', source: 'targetLevel', ambiguous: false },
      { key: 'englishLevel', value: 'b1', source: 'languageLevel', ambiguous: false },
      { key: 'gradeBandOn20', value: '12_14', source: 'gradeRange', ambiguous: false },
    ]);
    // Rien n'est confirmé par un pré-remplissage.
    expect(readiness(normaliseProfile(source), NOW).ready).toBe(false);
  });

  it('« 15+/20 » est TOUJOURS une suggestion ambiguë, à reposer', () => {
    for (const gradeRange of ['15+/20', '15+ /20', ' 15+/20 ']) {
      expect(suggestions({ gradeRange })).toEqual([
        { key: 'gradeBandOn20', value: '14_16', source: 'gradeRange', ambiguous: true },
      ]);
    }
  });

  it('« Advanced » est ambigu (B2 ou C1-C2) ; « Débutant » ne l’est pas', () => {
    expect(suggestions({ languageLevel: 'Advanced' })).toEqual([
      { key: 'englishLevel', value: 'b2', source: 'languageLevel', ambiguous: true },
    ]);
    expect(suggestions({ languageLevel: 'Débutant' })).toEqual([
      { key: 'englishLevel', value: 'a1_a2', source: 'languageLevel', ambiguous: false },
    ]);
  });

  it('ne suggère rien pour une clé déjà renseignée', () => {
    const source = completeSource({ currentLevel: 'Master 1', languageLevel: 'Advanced', gradeRange: '15+/20' });
    expect(suggestions(source).map((s) => s.key)).toEqual(['residence']);
  });
});

describe('écritures de compatibilité vers les anciens champs', () => {
  it.each([
    [{ englishLevel: 'a1_a2' }, { languageLevel: 'Beginner' }],
    [{ englishLevel: 'b1' }, { languageLevel: 'Intermediate' }],
    [{ englishLevel: 'b2' }, {}], // entre Intermediate et Advanced
    [{ englishLevel: 'c1_c2' }, { languageLevel: 'Advanced' }],
    [{ englishLevel: 'none' }, {}],
    [{ gradeBandOn20: 'lt10' }, {}],
    [{ gradeBandOn20: '10_12' }, { gradeRange: '10 - 12/20' }],
    [{ gradeBandOn20: '12_14' }, { gradeRange: '12 - 14/20' }],
    [{ gradeBandOn20: '14_16' }, {}], // ni « 12 - 14 » ni « 15+ »
    [{ gradeBandOn20: '16_plus' }, { gradeRange: '15+/20' }],
    [{ englishLevel: 'fluent', gradeBandOn20: '20/20' }, {}],
  ])('%j → %j', (answers, expected) => {
    expect(legacyCompatibilityWrites(answers)).toEqual(expected);
  });

  it('les jetons écrits sont exactement ceux de l’onboarding (onboarding_m2_constants.dart)', () => {
    const legacyGradeRanges = ['10 - 12/20', '12 - 14/20', '15+/20'];
    const legacyLanguageLevels = ['Beginner', 'Intermediate', 'Advanced'];
    for (const band of ['lt10', '10_12', '12_14', '14_16', '16_plus']) {
      const { gradeRange } = legacyCompatibilityWrites({ gradeBandOn20: band });
      if (gradeRange) expect(legacyGradeRanges).toContain(gradeRange);
    }
    for (const level of ['none', 'a1_a2', 'b1', 'b2', 'c1_c2']) {
      const { languageLevel } = legacyCompatibilityWrites({ englishLevel: level });
      if (languageLevel) expect(legacyLanguageLevels).toContain(languageLevel);
    }
  });
});

describe('profileHash', () => {
  it('ne dépend ni de l’ordre des clés ni de l’ordre des listes sans ordre', () => {
    const a = normaliseProfile(
      completeSource({ fieldIds: ['law', 'engineering'], targetCountryIds: ['fra', 'can'] }),
    );
    const reordered = Object.fromEntries(Object.entries(a).reverse()) as typeof a;
    const b = { ...reordered, fieldIds: ['engineering', 'law'], targetCountryIds: ['can', 'fra'] };
    expect(profileHash(b)).toBe(profileHash(a));
    expect(stableHash({ x: 1, y: { b: 2, a: [3, 1] } })).toBe(stableHash({ y: { a: [3, 1], b: 2 }, x: 1 }));
  });

  it('change quand une valeur lue change, ou à la confirmation', () => {
    const base = normaliseProfile(completeSource());
    expect(profileHash({ ...base, gradeBand: '14_16' })).not.toBe(profileHash(base));
    expect(profileHash({ ...base, confirmed: false })).not.toBe(profileHash(base));
    // L'heure de naissance n'est pas une donnée.
    expect(profileHash({ ...base, birthDate: new Date('2006-05-10T11:00:00Z') })).toBe(profileHash(base));
  });

  it('l’ordre des nationalités reste significatif (principale d’abord)', () => {
    const base = normaliseProfile(completeSource({ secondNationalityCode: 'fra' }));
    expect(profileHash({ ...base, nationalities: ['fra', 'ner'] })).not.toBe(profileHash(base));
  });
});

describe('ageOn', () => {
  it('âge révolu, 29 février compris', () => {
    expect(ageOn(date('2008-02-29'), date('2026-02-28'))).toBe(17);
    expect(ageOn(date('2008-02-29'), date('2026-03-01'))).toBe(18);
    expect(ageOn(date('2008-02-29'), date('2028-02-29'))).toBe(20);
    expect(ageOn(date('2000-10-13'), NOW)).toBe(26);
    expect(ageOn(date('2000-10-14'), NOW)).toBe(25);
  });
});
