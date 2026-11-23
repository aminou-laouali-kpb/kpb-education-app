import {
  audienceFilterInvalid,
  countryVariants,
  EEF_SUSPENDED_COUNTRIES_TOKEN,
  escapeLike,
  resolveExcludedCountries,
} from './campaign-audience';

describe('resolveExcludedCountries', () => {
  it('lit une liste, dédoublonnée et sans blancs', () => {
    expect(
      resolveExcludedCountries([' Niger ', 'NE', 'Niger', '', '  ']),
    ).toEqual(['Niger', 'NE']);
  });

  it('lit une chaîne séparée par des virgules', () => {
    expect(resolveExcludedCountries('Niger, NE ,Mali')).toEqual([
      'Niger',
      'NE',
      'Mali',
    ]);
  });

  it("ignore ce qui n'est pas du texte", () => {
    expect(resolveExcludedCountries([1, null, {}, 'Niger'])).toEqual(['Niger']);
    expect(resolveExcludedCountries(undefined)).toEqual([]);
    expect(resolveExcludedCountries(42)).toEqual([]);
    expect(resolveExcludedCountries({})).toEqual([]);
  });

  describe('le jeton « eef_suspended »', () => {
    it("suit la liste de l'exploitation — celle que /config/app sert", () => {
      const env = { KPB_EEF_SUSPENDED_COUNTRIES: 'Niger, NE' };
      expect(
        resolveExcludedCountries([EEF_SUSPENDED_COUNTRIES_TOKEN], env),
      ).toEqual(['Niger', 'NE']);
    });

    it("se combine avec d'autres pays, sans doublon", () => {
      const env = { KPB_EEF_SUSPENDED_COUNTRIES: 'Niger' };
      expect(
        resolveExcludedCountries(
          ['Mali', 'ÉEF_SUSPENDED', 'eef_suspended', 'Niger'],
          env,
        ),
      ).toEqual(['Mali', 'ÉEF_SUSPENDED', 'Niger']);
    });

    it('accepté en chaîne et quelle que soit la casse', () => {
      const env = { KPB_EEF_SUSPENDED_COUNTRIES: 'Niger' };
      expect(resolveExcludedCountries('EEF_Suspended', env)).toEqual(['Niger']);
    });

    // Liste de l'exploitation vide : le jeton n'exclut personne. Les audiences
    // qui l'exigent (`all_students_except_countries`) tombent alors à zéro
    // destinataire plutôt qu'à « tous » — voir l'exécuteur.
    it('ne produit rien quand la liste est vide', () => {
      expect(
        resolveExcludedCountries([EEF_SUSPENDED_COUNTRIES_TOKEN], {}),
      ).toEqual([]);
    });
  });
});

// ── Un filtre PRÉSENT mais mal formé vaut « personne », pas « sans exclusion » ──
//
// Le défaut que la relecture a trouvé : `["eef_suspendd"]` (faute de frappe sur
// le jeton) était lu comme un nom de pays que personne ne porte, donc l'envoi
// partait vers TOUS les étudiants, Niger compris — sans erreur, avec un aperçu
// qui affichait seulement un nombre plus grand.
describe('audienceFilterInvalid', () => {
  const env = { KPB_EEF_SUSPENDED_COUNTRIES: 'Niger,NE' };

  it('ne juge que les deux audiences à exclusion', () => {
    expect(audienceFilterInvalid('all_students', { n: 1 }, env)).toBeNull();
    expect(
      audienceFilterInvalid('country', { countryId: 'x' }, env),
    ).toBeNull();
  });

  it.each([
    ['all_students_except_countries', { exceptCountries: ['Niger'] }],
    ['all_students_except_countries', { exceptCountries: ['eef_suspended'] }],
    ['all_students_except_countries', { exceptCountries: 'Niger, NE' }],
    ['all_students_except_countries', { exceptCountries: ["Côte d'Ivoire"] }],
    ['eef_interest', {}],
    ['eef_interest', { exceptCountries: ['eef_suspended', 'Mali'] }],
  ])('accepte %s %j', (audience, filters) => {
    expect(
      audienceFilterInvalid(audience, filters as Record<string, unknown>, env),
    ).toBeNull();
  });

  it.each([
    ['jeton mal écrit', { exceptCountries: ['eef_suspendd'] }],
    ['jeton mal écrit en chaîne', { exceptCountries: 'eef_suspendd' }],
    ['pays collé en snake_case', { exceptCountries: ['cote_d_ivoire'] }],
    ['clé inconnue', { exceptCountry: ['Niger'] }],
    ['clé en plus', { exceptCountries: ['Niger'], autre: 1 }],
    ['null explicite', { exceptCountries: null }],
    ['entrée non textuelle', { exceptCountries: ['Niger', 7] }],
    ['valeur non textuelle', { exceptCountries: 7 }],
  ])('refuse : %s', (_label, filters) => {
    for (const audience of ['eef_interest', 'all_students_except_countries']) {
      expect(
        audienceFilterInvalid(
          audience,
          filters as Record<string, unknown>,
          env,
        ),
      ).not.toBeNull();
    }
  });

  it("refuse le jeton quand la liste de l'exploitation est vide", () => {
    const reason = audienceFilterInvalid(
      'eef_interest',
      { exceptCountries: ['eef_suspended'] },
      {},
    );
    expect(reason).toContain('vide');
  });

  it("un nom de pays avec espaces ou accents n'est pas pris pour un jeton", () => {
    expect(
      audienceFilterInvalid(
        'eef_interest',
        { exceptCountries: ["Côte d'Ivoire", 'Guinée Bissau', 'RD Congo'] },
        env,
      ),
    ).toBeNull();
  });
});

// ── `case_status` : le statut doit exister dans l'enum `CaseStatus` ────────
//
// Une valeur hors enum faisait échouer la requête Prisma ; l'erreur était
// avalée et la campagne se disait « terminée » à zéro destinataire.
describe('audienceFilterInvalid — case_status', () => {
  it.each(['documents_needed', 'awaiting_payment', 'submitted'])(
    'accepte %s',
    (status) => {
      expect(audienceFilterInvalid('case_status', { status })).toBeNull();
    },
  );

  it.each([
    ['traduction française', 'documents_requis'],
    ['casse différente', 'Documents_Needed'],
    ['espaces autour', ' submitted '],
    ['non textuel', 7],
    ['tableau', ['submitted']],
  ])('refuse : %s', (_label, status) => {
    const reason = audienceFilterInvalid('case_status', { status });
    expect(reason).toContain('statut de dossier inconnu');
    expect(reason).toContain('documents_needed');
  });

  it('laisse le filtre absent à audienceFilterMissing', () => {
    expect(audienceFilterInvalid('case_status', {})).toBeNull();
    expect(audienceFilterInvalid('case_status', { status: '  ' })).toBeNull();
  });
});

describe('countryVariants', () => {
  it("couvre l'apostrophe droite, la typographique, et les accents", () => {
    expect(countryVariants("Côte d'Ivoire").sort()).toEqual(
      [
        "Côte d'Ivoire",
        'Côte d\u2019Ivoire',
        "Cote d'Ivoire",
        'Cote d\u2019Ivoire',
      ].sort(),
    );
  });

  it('un nom simple reste seul', () => {
    expect(countryVariants('Niger')).toEqual(['Niger']);
  });

  it('réduit les espaces', () => {
    expect(countryVariants('  Guinée   Bissau ')).toContain('Guinée Bissau');
  });
});

describe('escapeLike', () => {
  it("échappe les jokers ILIKE et l'antislash", () => {
    expect(escapeLike('Mal_')).toBe('Mal\\_');
    expect(escapeLike('%')).toBe('\\%');
    expect(escapeLike('a\\b')).toBe('a\\\\b');
    expect(escapeLike('Niger')).toBe('Niger');
  });
});
