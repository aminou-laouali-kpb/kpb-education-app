import { assess, isStructuredFresh, type Assessment } from './assess';
import {
  age,
  date,
  daysBefore,
  eiffel,
  experience,
  financialNeed,
  grade,
  language,
  makeCycle,
  makeProfile,
  makeScholarship,
  nationality,
  NOW,
  other,
  turkiye,
  uwcBurkina,
  uwcKenya,
} from './testing/match-fixtures';

function codes(points: Assessment['toVerify'] | Assessment['reasons'] | Assessment['exclusions']) {
  return points.map((point) => point.code);
}

describe('assess — nationalité et résidence (sémantique « n’importe laquelle »)', () => {
  const master = { targetLevel: 'master' as const, birthDate: date('2000-03-01') };

  it.each([
    {
      name: 'Eiffel : un binational français est exclu',
      scholarship: eiffel(),
      profile: makeProfile({ ...master, nationalities: ['cmr', 'fra'], residenceCode: 'cmr' }),
      status: 'not_eligible',
      exclusion: 'nationality_excluded',
    },
    {
      name: 'Eiffel : un Camerounais seul passe la règle',
      scholarship: eiffel(),
      profile: makeProfile({ ...master, nationalities: ['cmr'], residenceCode: 'cmr' }),
      status: 'eligible',
    },
    {
      name: 'Türkiye : un binational turc est exclu',
      scholarship: turkiye(),
      profile: makeProfile({ nationalities: ['ner', 'tur'], birthDate: date('2008-01-15') }),
      status: 'not_eligible',
      exclusion: 'nationality_excluded',
    },
    {
      name: 'UWC Kenya : un binational kényan résidant ailleurs est inclus',
      scholarship: uwcKenya(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['tza', 'ken'],
        residenceCode: 'tza',
        birthDate: date('2009-06-01'),
      }),
      status: 'eligible',
      reason: 'nationality_accepted',
    },
    {
      name: 'UWC Kenya : un résident du Kenya d’une autre nationalité est inclus (« ou »)',
      scholarship: uwcKenya(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['uga'],
        residenceCode: 'ken',
        birthDate: date('2009-06-01'),
      }),
      status: 'eligible',
      reason: 'residence_accepted',
    },
    {
      name: 'UWC Kenya : un Burkinabè résidant au Burkina est exclu',
      scholarship: uwcKenya(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['bfa'],
        residenceCode: 'bfa',
        birthDate: date('2009-06-01'),
      }),
      status: 'not_eligible',
      exclusion: 'nationality_not_listed',
    },
    {
      name: 'UWC Burkina : citoyen ET résident passe',
      scholarship: uwcBurkina(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['bfa'],
        residenceCode: 'bfa',
        birthDate: date('2009-06-01'),
      }),
      status: 'eligible',
    },
    {
      name: 'UWC Burkina : un Burkinabè résidant en Côte d’Ivoire est exclu (« et »)',
      scholarship: uwcBurkina(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['bfa'],
        residenceCode: 'civ',
        birthDate: date('2009-06-01'),
      }),
      status: 'not_eligible',
      exclusion: 'nationality_not_listed',
    },
    {
      name: 'UWC Burkina : un Ivoirien résidant au Burkina est exclu (« et »)',
      scholarship: uwcBurkina(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['civ'],
        residenceCode: 'bfa',
        birthDate: date('2009-06-01'),
      }),
      status: 'not_eligible',
      exclusion: 'nationality_not_listed',
    },
    {
      name: '« et » : nationalité non listée, résidence inconnue — la nationalité suffit à trancher',
      scholarship: uwcBurkina(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['civ'],
        residenceCode: null,
        birthDate: date('2009-06-01'),
      }),
      status: 'not_eligible',
      exclusion: 'nationality_not_listed',
    },
    {
      name: '« ou » : nationalité non listée, résidence inconnue — à vérifier',
      scholarship: uwcKenya(),
      profile: makeProfile({
        targetLevel: 'secondary',
        nationalities: ['bfa'],
        residenceCode: null,
        birthDate: date('2009-06-01'),
      }),
      status: 'to_verify',
      toVerify: 'residence_missing',
    },
    {
      name: 'nationalité absente : à vérifier, jamais exclue',
      scholarship: makeScholarship({
        eligibilityCriteria: [nationality('afrique', 'include', ['ner', 'sen'])],
      }),
      profile: makeProfile({ nationalities: [] }),
      status: 'to_verify',
      toVerify: 'nationality_missing',
    },
    {
      name: 'résidence seule, absente : à vérifier',
      scholarship: makeScholarship({
        eligibilityCriteria: [nationality('residents', 'include', ['ner'], 'residence')],
      }),
      profile: makeProfile({ residenceCode: null }),
      status: 'to_verify',
      toVerify: 'residence_missing',
    },
    {
      name: 'résidence seule, non listée : exclue',
      scholarship: makeScholarship({
        eligibilityCriteria: [nationality('residents', 'include', ['sen'], 'residence')],
      }),
      profile: makeProfile({ residenceCode: 'ner' }),
      status: 'not_eligible',
      exclusion: 'residence_not_listed',
    },
    {
      name: 'règle de nationalité « soft » non satisfaite : à vérifier',
      scholarship: makeScholarship({
        eligibilityCriteria: [nationality('pays-cibles', 'include', ['sen'], 'nationality', 'soft')],
      }),
      profile: makeProfile(),
      status: 'to_verify',
      toVerify: 'nationality_check',
    },
  ])('$name', ({ scholarship, profile, status, exclusion, reason, toVerify }) => {
    const result = assess(profile, scholarship, NOW);
    expect(result.status).toBe(status);
    if (exclusion) expect(codes(result.exclusions)).toContain(exclusion);
    if (reason) expect(codes(result.reasons)).toContain(reason);
    if (toVerify) expect(codes(result.toVerify)).toContain(toVerify);
    if (status !== 'not_eligible') expect(result.exclusions).toEqual([]);
  });

  it('la raison cite le pays qui fait passer la règle, pas toute la liste', () => {
    const result = assess(
      makeProfile({ nationalities: ['ner'] }),
      makeScholarship({
        eligibilityCriteria: [nationality('afrique', 'include', ['sen', 'ner', 'mli', 'bfa'])],
      }),
      NOW,
    );
    expect(result.reasons).toContainEqual({
      code: 'nationality_accepted',
      criterionKey: 'afrique',
      params: { countries: ['ner'] },
    });
  });
});

describe('assess — âge', () => {
  const withAge = (criterion: ReturnType<typeof age>, cycle = makeCycle()) =>
    makeScholarship({ eligibilityCriteria: [criterion], cycle });

  it.each([
    // Date de référence exacte : pas de marge, on tranche au jour près.
    ['date exacte, 29 ans la veille des 30 ans', '1997-08-02', { max: 29, asOf: { kind: 'date' as const, date: '2027-08-01' } }, 'eligible'],
    ['date exacte, 30 ans le jour même', '1997-08-01', { max: 29, asOf: { kind: 'date' as const, date: '2027-08-01' } }, 'not_eligible'],
    ['date exacte, trop jeune', '2011-01-01', { min: 16, asOf: { kind: 'date' as const, date: '2026-12-31' } }, 'not_eligible'],
    // Non précisée : marge de 12 mois autour de la clôture du cycle (2027-01-15).
    ['non précisée, loin de la limite', '2001-01-01', { max: 29 }, 'eligible'],
    ['non précisée, à moins de 12 mois de la limite', '1997-06-01', { max: 29 }, 'to_verify'],
    ['non précisée, nettement au-delà', '1994-01-01', { max: 29 }, 'not_eligible'],
    ['non précisée, minimum proche', '2010-06-01', { min: 16 }, 'to_verify'],
  ])('%s', (_name, birth, bounds, status) => {
    const result = assess(
      makeProfile({ birthDate: date(birth) }),
      withAge(age('age', bounds)),
      NOW,
    );
    expect(result.status).toBe(status);
    if (status === 'to_verify') expect(codes(result.toVerify)).toContain('age_borderline');
  });

  it('clôture du cycle CONFIRMÉE : date exacte, aucune marge', () => {
    const cycle = makeCycle({ dateConfidence: 'confirmed', closesAt: date('2027-01-15') });
    const criterion = age('age', { max: 29, asOf: { kind: 'cycle_close' } });
    // 29 ans jusqu'au 14/01/2027 inclus, 30 ans le 15.
    expect(assess(makeProfile({ birthDate: date('1997-01-16') }), withAge(criterion, cycle), NOW).status).toBe('eligible');
    expect(assess(makeProfile({ birthDate: date('1997-01-15') }), withAge(criterion, cycle), NOW).status).toBe('not_eligible');
  });

  it('clôture du cycle ESTIMÉE : marge de 12 mois, donc « à vérifier » près de la limite', () => {
    const cycle = makeCycle({
      dateConfidence: 'estimated',
      closesAt: null,
      estimatedCloseAt: date('2027-01-15'),
    });
    const criterion = age('age', { max: 29, asOf: { kind: 'cycle_close' } });
    const near = assess(makeProfile({ birthDate: date('1997-01-16') }), withAge(criterion, cycle), NOW);
    expect(near.status).toBe('to_verify');
    expect(codes(near.toVerify)).toContain('age_borderline');
    const far = assess(makeProfile({ birthDate: date('1990-01-01') }), withAge(criterion, cycle), NOW);
    expect(far.status).toBe('not_eligible');
    expect(codes(far.exclusions)).toEqual(['age_too_old']);
  });

  it('ouverture du cycle confirmée comme date de référence', () => {
    const cycle = makeCycle({ dateConfidence: 'confirmed', opensAt: date('2026-09-01') });
    const criterion = age('age', { min: 16, asOf: { kind: 'cycle_open' } });
    expect(assess(makeProfile({ birthDate: date('2010-09-01') }), withAge(criterion, cycle), NOW).status).toBe('eligible');
    expect(assess(makeProfile({ birthDate: date('2010-09-02') }), withAge(criterion, cycle), NOW).status).toBe('not_eligible');
  });

  it('29 février : l’anniversaire tombe le 1er mars les années non bissextiles', () => {
    const criterion = (asOf: string) => age('age', { min: 18, asOf: { kind: 'date', date: asOf } });
    const profile = makeProfile({ birthDate: date('2008-02-29') });
    expect(assess(profile, withAge(criterion('2026-02-28')), NOW).status).toBe('not_eligible');
    expect(assess(profile, withAge(criterion('2026-03-01')), NOW).status).toBe('eligible');
  });

  it('limites par niveau (Türkiye : moins de 21 ans en Licence, moins de 30 ans en Master)', () => {
    // Licence à 18 ans : passe ; la limite Master ne s'applique pas.
    const bachelor18 = assess(makeProfile({ birthDate: date('2008-06-01') }), turkiye(), NOW);
    expect(bachelor18.status).toBe('eligible');
    expect(bachelor18.reasons.filter((r) => r.code === 'age_within_limit')).toHaveLength(1);
    // Master à 25 ans : la limite Licence (21) ne s'applique pas.
    const master25 = assess(
      makeProfile({ targetLevel: 'master', birthDate: date('2001-06-01'), workExperienceBand: 'none' }),
      turkiye(),
      NOW,
    );
    expect(master25.status).toBe('eligible');
    // Master à 31 ans : exclu (moins de 30 ans, même avec la marge de 12 mois).
    const master31 = assess(
      makeProfile({ targetLevel: 'master', birthDate: date('1995-06-01') }),
      turkiye(),
      NOW,
    );
    expect(master31.status).toBe('not_eligible');
    expect(master31.exclusions).toEqual([
      expect.objectContaining({ code: 'age_too_old', criterionKey: 'age-master' }),
    ]);
    // Licence à 20 ans et demi : la clôture estimée tombe à moins de 12 mois des 21 ans.
    const bachelor20 = assess(makeProfile({ birthDate: date('2006-05-10') }), turkiye(), NOW);
    expect(bachelor20.status).toBe('to_verify');
    expect(codes(bachelor20.toVerify)).toContain('age_borderline');
  });

  it('date de naissance absente : à vérifier', () => {
    const result = assess(makeProfile({ birthDate: null }), withAge(age('age', { max: 29 })), NOW);
    expect(result.status).toBe('to_verify');
    expect(codes(result.toVerify)).toContain('age_missing');
  });
});

describe('assess — expérience professionnelle par tranches', () => {
  it.each([
    ['none', 24, 'not_eligible'],
    ['lt12', 12, 'not_eligible'],
    ['12_24', 24, 'to_verify'], // la tranche chevauche le minimum
    ['24_36', 24, 'eligible'],
    ['36_60', 48, 'to_verify'],
    ['60_plus', 48, 'eligible'],
    ['lt12', 6, 'to_verify'],
  ] as const)('%s pour %d mois demandés → %s', (band, minMonths, status) => {
    const result = assess(
      makeProfile({ targetLevel: 'master', workExperienceBand: band }),
      makeScholarship({ eligibleLevels: ['master'], eligibilityCriteria: [experience('xp', minMonths)] }),
      NOW,
    );
    expect(result.status).toBe(status);
    if (status === 'to_verify') expect(codes(result.toVerify)).toContain('experience_borderline');
  });

  it('une exigence propre au Master ne touche pas une cible Licence', () => {
    const result = assess(
      makeProfile({ targetLevel: 'bachelor', workExperienceBand: null }),
      makeScholarship({
        eligibleLevels: ['bachelor', 'master'],
        eligibilityCriteria: [experience('xp', 24, 'hard', 'master')],
      }),
      NOW,
    );
    expect(result.status).toBe('eligible');
  });

  it('tranche absente : à vérifier', () => {
    const result = assess(
      makeProfile({ targetLevel: 'master', workExperienceBand: null }),
      makeScholarship({ eligibleLevels: ['master'], eligibilityCriteria: [experience('xp', 24)] }),
      NOW,
    );
    expect(result.status).toBe('to_verify');
    expect(codes(result.toVerify)).toContain('experience_missing');
  });
});

describe('assess — niveau, tampon de structuration, statuts spéciaux', () => {
  it('niveau repris des tags (tampon nul) : n’exclut JAMAIS', () => {
    const result = assess(
      makeProfile({ targetLevel: 'bachelor' }),
      makeScholarship({ eligibleLevels: ['master'], eligibilityStructuredAt: null }),
      NOW,
    );
    expect(result.status).toBe('to_verify');
    expect(codes(result.toVerify)).toEqual(
      expect.arrayContaining(['eligibility_not_structured', 'level_check']),
    );
    expect(result.exclusions).toEqual([]);
  });

  it('niveau tamponné et frais : exclut un autre niveau', () => {
    const result = assess(
      makeProfile({ targetLevel: 'bachelor' }),
      makeScholarship({ eligibleLevels: ['master'] }),
      NOW,
    );
    expect(result.status).toBe('not_eligible');
    expect(result.exclusions).toEqual([{ code: 'level_other', params: { levels: ['master'] } }]);
  });

  it('eligibleLevels vide : non analysée', () => {
    const result = assess(makeProfile(), makeScholarship({ eligibleLevels: [] }), NOW);
    expect(result.status).toBe('not_analyzed');
  });

  it('cycle suspendu : exclue, même sans niveaux', () => {
    for (const eligibleLevels of [['bachelor'] as const, [] as const]) {
      const result = assess(
        makeProfile(),
        makeScholarship({ eligibleLevels: [...eligibleLevels], cycle: makeCycle({ status: 'suspended' }) }),
        NOW,
      );
      expect(result.status).toBe('suspended');
      expect(codes(result.exclusions)).toEqual(['suspended']);
    }
  });

  it('tampon de plus de 400 jours : plafonne à « à vérifier », aucune exclusion', () => {
    const stale = eiffel({ eligibilityStructuredAt: daysBefore(401) });
    const profile = makeProfile({
      targetLevel: 'master',
      nationalities: ['cmr', 'fra'],
      birthDate: date('2000-03-01'),
    });
    const result = assess(profile, stale, NOW);
    expect(result.status).toBe('to_verify');
    expect(result.structuredFresh).toBe(false);
    expect(codes(result.toVerify)).toEqual(
      expect.arrayContaining(['eligibility_stale', 'nationality_check']),
    );
    // Le même profil, tampon de 399 jours : exclu.
    expect(assess(profile, eiffel({ eligibilityStructuredAt: daysBefore(399) }), NOW).status).toBe(
      'not_eligible',
    );
  });

  it('tampon de plus de 400 jours : même une fiche sans écart reste « à vérifier »', () => {
    const result = assess(
      makeProfile(),
      makeScholarship({ eligibilityStructuredAt: daysBefore(500) }),
      NOW,
    );
    expect(result.status).toBe('to_verify');
    expect(isStructuredFresh(daysBefore(400), NOW)).toBe(false);
    expect(isStructuredFresh(daysBefore(399), NOW)).toBe(true);
  });

  it('valeur non confirmée : n’exclut jamais (niveau, nationalité, âge, expérience)', () => {
    const profile = makeProfile({
      confirmed: false,
      targetLevel: 'master',
      nationalities: ['fra'],
      birthDate: date('1980-01-01'),
      workExperienceBand: 'none',
    });
    const scholarship = makeScholarship({
      eligibleLevels: ['bachelor'],
      eligibilityCriteria: [
        nationality('pas-francais', 'exclude', ['fra']),
        age('age', { max: 29 }),
        experience('xp', 24),
      ],
    });
    const result = assess(profile, scholarship, NOW);
    expect(result.status).toBe('to_verify');
    expect(result.exclusions).toEqual([]);
    expect(codes(result.toVerify)).toEqual(
      expect.arrayContaining([
        'level_check',
        'nationality_check',
        'age_check',
        'experience_check',
        'profile_unconfirmed',
      ]),
    );
  });

  it('aucun critère structuré (tableau vide) : plafonne à « à vérifier »', () => {
    const result = assess(makeProfile(), makeScholarship({ eligibilityCriteria: [] }), NOW);
    expect(result.status).toBe('to_verify');
    expect(codes(result.toVerify)).toEqual(['criteria_not_structured']);
  });

  it.each([
    ['une chaîne', 'not json'],
    ['un objet', { type: 'nationality' }],
    ['null', null],
  ])('JSON invalide (%s) : ignoré, jamais excluant', (_name, json) => {
    const result = assess(makeProfile(), makeScholarship({ eligibilityCriteria: json }), NOW);
    expect(result.status).toBe('to_verify');
    expect(result.exclusions).toEqual([]);
  });

  it('critère invalide ou de type inconnu : ignoré, signalé, jamais excluant', () => {
    const result = assess(
      makeProfile({ nationalities: ['fra'] }),
      makeScholarship({
        eligibilityCriteria: [
          // Code pays invalide : le critère entier est ignoré.
          { ...nationality('pas-francais', 'exclude', ['fra']), countries: ['FR'] },
          { key: 'inconnu', type: 'religion', impact: 'hard' },
          other('autre', 'informational'),
        ],
      }),
      NOW,
    );
    expect(result.status).toBe('to_verify');
    expect(result.exclusions).toEqual([]);
    expect(result.ignoredCriteria).toEqual(['pas-francais', 'inconnu']);
    expect(codes(result.toVerify)).toContain('criterion_unreadable');
  });
});

describe('assess — jamais d’exclusion : domaine, moyenne, langue, destination, besoin financier', () => {
  it('une règle de langue « hard » non satisfaite reste « à vérifier »', () => {
    const result = assess(
      makeProfile({ englishLevel: 'a1_a2' }),
      makeScholarship({ eligibilityCriteria: [language('ielts', { minCefr: 'c1' }, 'hard')] }),
      NOW,
    );
    expect(result.status).toBe('to_verify');
    expect(codes(result.toVerify)).toContain('language_below');
  });

  it.each([
    ['score IELTS suffisant', { tests: [{ type: 'ielts' as const, min: 6.5 }] }, { languageTests: [{ type: 'ielts' as const, score: 7 }] }, 'eligible', 'language_sufficient'],
    ['score IELTS insuffisant', { tests: [{ type: 'ielts' as const, min: 6.5 }] }, { languageTests: [{ type: 'ielts' as const, score: 6 }] }, 'to_verify', 'language_below'],
    ['aucun score indiqué', { tests: [{ type: 'ielts' as const, min: 6.5 }] }, {}, 'to_verify', 'language_missing'],
    ['niveau CECRL suffisant', { minCefr: 'b1' as const }, { englishLevel: 'b2' as const }, 'eligible', 'language_sufficient'],
    ['niveau CECRL non renseigné', { minCefr: 'b1' as const }, { englishLevel: null }, 'to_verify', 'language_missing'],
    ['français C1 demandé, élève C1-C2', { lang: 'fr', minCefr: 'c1' as const }, {}, 'eligible', 'language_sufficient'],
    ['allemand demandé', { lang: 'de', minCefr: 'b2' as const }, {}, 'to_verify', 'language_other'],
  ])('langue : %s', (_name, spec, profileOverrides, status, code) => {
    const result = assess(
      makeProfile(profileOverrides),
      makeScholarship({ eligibilityCriteria: [language('langue', spec)] }),
      NOW,
    );
    expect(result.status).toBe(status);
    expect([...codes(result.reasons), ...codes(result.toVerify)]).toContain(code);
  });

  it.each([
    ['moyenne suffisante', 12, '12_14', 'eligible', 'grade_sufficient'],
    ['moyenne peut-être trop basse', 14, '12_14', 'to_verify', 'grade_below'],
    ['moyenne absente', 12, null, 'to_verify', 'grade_missing'],
    ['règle non ramenable sur 20 (« 70 % »)', undefined, '12_14', 'to_verify', 'grade_check'],
  ] as const)('moyenne : %s', (_name, minOn20, gradeBand, status, code) => {
    const result = assess(
      makeProfile({ gradeBand }),
      makeScholarship({ eligibilityCriteria: [grade('moyenne', minOn20, 'hard')] }),
      NOW,
    );
    expect(result.status).toBe(status);
    expect([...codes(result.reasons), ...codes(result.toVerify)]).toContain(code);
  });

  it.each([
    ['domaine listé', ['engineering'], 'eligible', 'field_listed'],
    ['domaine hors liste', ['law'], 'to_verify', 'field_not_listed'],
    ['pas encore décidé', [], 'to_verify', 'field_undecided'],
  ])('domaines : %s', (_name, fieldIds, status, code) => {
    const result = assess(
      makeProfile({ fieldIds }),
      makeScholarship({ fieldsScope: 'listed', relatedFieldIds: ['engineering', 'health'] }),
      NOW,
    );
    expect(result.status).toBe(status);
    expect([...codes(result.reasons), ...codes(result.toVerify)]).toContain(code);
  });

  it('destination : une préférence, jamais une condition', () => {
    const elsewhere = assess(makeProfile({ targetCountryIds: ['can'] }), makeScholarship(), NOW);
    expect(elsewhere.status).toBe('eligible');
    const wanted = assess(makeProfile({ targetCountryIds: ['fra'] }), makeScholarship(), NOW);
    expect(codes(wanted.reasons)).toContain('destination_wanted');
  });

  it('besoin financier : informatif, sans effet', () => {
    const result = assess(
      makeProfile(),
      makeScholarship({ eligibilityCriteria: [financialNeed('besoin')] }),
      NOW,
    );
    expect(result.status).toBe('eligible');
    expect(result.informationalKeys).toEqual(['besoin']);
  });

  it('condition « autre » non informative : à vérifier', () => {
    const result = assess(makeProfile(), makeScholarship({ eligibilityCriteria: [other('lettre', 'hard')] }), NOW);
    expect(result.status).toBe('to_verify');
    expect(result.toVerify).toEqual([{ code: 'condition_other', criterionKey: 'lettre' }]);
  });
});

describe('assess — pureté', () => {
  it('même entrée, même sortie ; l’entrée n’est pas modifiée', () => {
    const profile = makeProfile();
    const scholarship = turkiye();
    const before = JSON.stringify({ profile, scholarship });
    const first = assess(profile, scholarship, NOW);
    const second = assess(profile, scholarship, new Date(NOW.getTime()));
    expect(second).toEqual(first);
    expect(JSON.stringify({ profile, scholarship })).toBe(before);
  });
});
