import { AppConfigController } from './app-config.controller';

describe('AppConfigController', () => {
  const previousEnv = {
    KPB_MIN_APP_VERSION: process.env.KPB_MIN_APP_VERSION,
    KPB_ANDROID_STORE_URL: process.env.KPB_ANDROID_STORE_URL,
    KPB_IOS_STORE_URL: process.env.KPB_IOS_STORE_URL,
    KPB_COMPETITION_READINESS_ENABLED:
      process.env.KPB_COMPETITION_READINESS_ENABLED,
    KPB_SUCCESS_LAB_ENABLED: process.env.KPB_SUCCESS_LAB_ENABLED,
    KPB_AI_DIAGNOSTIC_ENABLED: process.env.KPB_AI_DIAGNOSTIC_ENABLED,
    KPB_AI_DIAGNOSTIC_KILL_SWITCH: process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH,
    KPB_OUTCOME_EVIDENCE_ENABLED: process.env.KPB_OUTCOME_EVIDENCE_ENABLED,
    KPB_IMPACT_PUBLIC_STATS_ENABLED:
      process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED,
    KPB_SUCCESS_LAB_PILOT_COUNTRIES:
      process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES,
    KPB_SUCCESS_LAB_ROLLOUT_PERCENT:
      process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT,
    KPB_FEATURE_ROLLOUT_SECRET: process.env.KPB_FEATURE_ROLLOUT_SECRET,
    KPB_EEF_ENABLED: process.env.KPB_EEF_ENABLED,
    KPB_EEF_SPACE_ENABLED: process.env.KPB_EEF_SPACE_ENABLED,
    KPB_EEF_TEASER_ENABLED: process.env.KPB_EEF_TEASER_ENABLED,
    KPB_EEF_HELP_BUBBLE_ENABLED: process.env.KPB_EEF_HELP_BUBBLE_ENABLED,
    KPB_EEF_PRIVATE_SCHOOLS_ENABLED:
      process.env.KPB_EEF_PRIVATE_SCHOOLS_ENABLED,
    KPB_EEF_CAMPAIGN_OPENS_AT: process.env.KPB_EEF_CAMPAIGN_OPENS_AT,
    KPB_EEF_CAMPAIGN_CLOSES_AT: process.env.KPB_EEF_CAMPAIGN_CLOSES_AT,
    KPB_EEF_SUSPENDED_COUNTRIES: process.env.KPB_EEF_SUSPENDED_COUNTRIES,
    KPB_EEF_PLATFORM_URL: process.env.KPB_EEF_PLATFORM_URL,
    KPB_EEF_SUSPENDED_SOURCES: process.env.KPB_EEF_SUSPENDED_SOURCES,
    KPB_RECOMMENDED_APP_VERSION: process.env.KPB_RECOMMENDED_APP_VERSION,
    KPB_SCHOLARSHIP_MATCH_ENABLED: process.env.KPB_SCHOLARSHIP_MATCH_ENABLED,
    KPB_ONBOARDING_V2_ENABLED: process.env.KPB_ONBOARDING_V2_ENABLED,
    KPB_US_VISA_SUSPENDED_COUNTRIES: process.env.KPB_US_VISA_SUSPENDED_COUNTRIES,
    KPB_US_VISA_SUSPENSION_VERIFIED_AT:
      process.env.KPB_US_VISA_SUSPENSION_VERIFIED_AT,
    KPB_US_VISA_SUSPENSION_SOURCE_URL:
      process.env.KPB_US_VISA_SUSPENSION_SOURCE_URL,
  };

  beforeEach(() => {
    for (const key of Object.keys(previousEnv)) {
      delete process.env[key];
    }
  });

  afterEach(() => {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  });

  // The force-update screen is not dismissible and its only button is disabled
  // when the URL is empty or dead. So the fallback — what production serves
  // whenever KPB_ANDROID_STORE_URL / KPB_IOS_STORE_URL are unset — must point at
  // the listings that are actually published, not at a package that 404s.
  it('falls back to the store listings that are actually published', () => {
    const config = new AppConfigController().getAppConfig();
    expect(config.androidStoreUrl).toContain('id=com.karatou.android');
    expect(config.iosStoreUrl).toContain('id1128659292');
  });

  it('defaults to a non-blocking minVersion when unset', () => {
    delete process.env.KPB_MIN_APP_VERSION;
    const config = new AppConfigController().getAppConfig();
    expect(config.minVersion).toBe('0.0.0');
    expect(config.features).toEqual({
      competitionReadiness: false,
      successLab: false,
      aiDiagnostic: false,
      outcomeEvidence: false,
      publicImpactStats: false,
      eefTeaser: false,
      eef: false,
      eefSpace: false,
      eefHelpBubble: false,
      eefPrivateSchools: false,
      followPushPrimer: true,
      followOpeningAlert: true,
      openingAlertToggle: true,
      followedScholarships: true,
      notificationsUnreadCount: true,
      followedScholarshipOptOut: true,
      homeFollowedEntry: true,
      homeNextStep: true,
      homeScholarships: true,
      homeDeadlines: true,
      homePartners: true,
      homeIntelligence: true,
      homeParcours: true,
      homeCounselor: true,
      scholarshipMatch: false,
      onboardingV2: false,
    });
    expect(config.eefCampaign).toEqual({
      opensAt: null,
      closesAt: null,
      suspendedCountries: [],
      platformUrl: 'https://www.campusfrance.org/fr',
      suspendedSources: [],
    });
    expect(config.recommendedVersion).toBeNull();
    expect(config.successLabRollout).toEqual({
      countryCodes: [],
      percent: 0,
    });
  });

  it('returns the configured minVersion and store URLs, trimmed', () => {
    process.env.KPB_MIN_APP_VERSION = ' 1.2.0 ';
    process.env.KPB_ANDROID_STORE_URL = 'https://play.example/app ';
    process.env.KPB_IOS_STORE_URL = ' https://apps.example/app';
    const config = new AppConfigController().getAppConfig();
    expect(config).toMatchObject({
      minVersion: '1.2.0',
      androidStoreUrl: 'https://play.example/app',
      iosStoreUrl: 'https://apps.example/app',
    });
  });

  it('keeps nested capabilities fail-closed and never exposes rollout secrets', () => {
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH = 'false';
    process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES = ' ne, SN,ci ';
    process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT = '140';
    process.env.KPB_FEATURE_ROLLOUT_SECRET = 'must-not-leak';

    const config = new AppConfigController().getAppConfig();

    expect(config.features).toMatchObject({
      competitionReadiness: true,
      successLab: true,
      aiDiagnostic: true,
      outcomeEvidence: true,
    });
    expect(config.successLabRollout).toEqual({
      countryCodes: ['NE', 'SN', 'CI'],
      percent: 100,
    });
    expect(JSON.stringify(config)).not.toContain('must-not-leak');
  });

  // Le jour du lancement, l'exploitation ne bascule QU'UNE variable. Si le
  // teaser pouvait rester allumé à côté de l'espace réel, l'app afficherait
  // « en préparation » et l'espace vivant en même temps — et personne ne le
  // verrait depuis un tableau de bord.
  it('retires the EEF teaser as soon as the real space opens', () => {
    process.env.KPB_EEF_TEASER_ENABLED = 'true';
    process.env.KPB_EEF_ENABLED = 'true';

    const config = new AppConfigController().getAppConfig();

    expect(config.features.eef).toBe(true);
    expect(config.features.eefTeaser).toBe(false);
  });

  it('serves the EEF teaser while the real space is still closed', () => {
    process.env.KPB_EEF_TEASER_ENABLED = 'true';

    const config = new AppConfigController().getAppConfig();

    expect(config.features.eefTeaser).toBe(true);
    expect(config.features.eef).toBe(false);
  });

  // `eefSpace` ouvre l'espace réel pour la seule build 54. Il ne peut PAS
  // passer par `eef`, que les builds 49 à 53 lisent aussi : pour elles, `eef`
  // retire la vitrine et affiche un espace vide.
  describe("eefSpace — l'ouverture de l'espace pour la seule build 54", () => {
    it('est fermé par défaut', () => {
      expect(new AppConfigController().getAppConfig().features.eefSpace).toBe(
        false,
      );
    });

    it("s'ouvre SANS toucher à la vitrine ni à `eef` que lisent les builds ≤ 53", () => {
      process.env.KPB_EEF_TEASER_ENABLED = 'true';
      process.env.KPB_EEF_SPACE_ENABLED = 'true';

      const { features } = new AppConfigController().getAppConfig();

      expect(features.eefSpace).toBe(true);
      // Ce que voit une build 53 n'a pas bougé d'un octet.
      expect(features.eefTeaser).toBe(true);
      expect(features.eef).toBe(false);
    });

    it("ne s'ouvre pas sur une autre valeur que « true »", () => {
      for (const value of ['1', 'yes', 'on', 'false', '', 'TRUEISH']) {
        process.env.KPB_EEF_SPACE_ENABLED = value;
        expect(new AppConfigController().getAppConfig().features.eefSpace).toBe(
          false,
        );
      }
      process.env.KPB_EEF_SPACE_ENABLED = ' TRUE ';
      expect(new AppConfigController().getAppConfig().features.eefSpace).toBe(
        true,
      );
    });

    it("l'ancien commutateur `eef` ouvre aussi l'espace de la 54", () => {
      process.env.KPB_EEF_ENABLED = 'true';

      const { features } = new AppConfigController().getAppConfig();

      expect(features.eef).toBe(true);
      expect(features.eefSpace).toBe(true);
    });

    it("éteindre `eefSpace` ne rallume ni ne retire rien d'autre", () => {
      process.env.KPB_EEF_TEASER_ENABLED = 'true';
      process.env.KPB_EEF_SPACE_ENABLED = 'false';

      expect(new AppConfigController().getAppConfig().features).toMatchObject({
        eefTeaser: true,
        eef: false,
        eefSpace: false,
      });
    });
  });

  // `eefHelpBubble` et `eefPrivateSchools` : deux interrupteurs de build 56,
  // FERMÉS par défaut et INDÉPENDANTS de tout le reste. Ils ne suivent ni `eef`
  // (l'ancien commutateur, qui ouvre `eefSpace` partout), ni `eefSpace` : ouvrir
  // l'espace ne doit jamais allumer, par ricochet, une bulle de contact ou la
  // mention des écoles privées.
  describe.each([
    ['eefHelpBubble', 'KPB_EEF_HELP_BUBBLE_ENABLED', 'eefPrivateSchools'],
    ['eefPrivateSchools', 'KPB_EEF_PRIVATE_SCHOOLS_ENABLED', 'eefHelpBubble'],
  ] as const)(
    '%s — interrupteur serveur fermé par défaut',
    (key, envVar, other) => {
      it('est fermé quand la variable est absente (ancien .env, premier déploiement)', () => {
        const { features } = new AppConfigController().getAppConfig();
        expect(features[key]).toBe(false);
      });

      it('est SERVI comme booléen strict, jamais absent de la réponse', () => {
        const { features } = new AppConfigController().getAppConfig();
        expect(Object.keys(features)).toContain(key);
        expect(typeof features[key]).toBe('boolean');
      });

      it("ne s'ouvre pas sur une autre valeur que « true »", () => {
        for (const value of ['1', 'yes', 'on', 'false', '', 'TRUEISH']) {
          process.env[envVar] = value;
          expect(new AppConfigController().getAppConfig().features[key]).toBe(
            false,
          );
        }
        process.env[envVar] = ' TRUE ';
        expect(new AppConfigController().getAppConfig().features[key]).toBe(
          true,
        );
      });

      it("s'ouvre SANS toucher à l'espace, à la vitrine, à `eef` ni à l'autre interrupteur", () => {
        process.env.KPB_EEF_TEASER_ENABLED = 'true';
        process.env[envVar] = 'true';

        const { features } = new AppConfigController().getAppConfig();

        expect(features[key]).toBe(true);
        expect(features[other]).toBe(false);
        expect(features.eefSpace).toBe(false);
        expect(features.eef).toBe(false);
        expect(features.eefTeaser).toBe(true);
      });

      it("ne suit NI l'ancien commutateur `eef` NI `eefSpace`", () => {
        process.env.KPB_EEF_ENABLED = 'true';
        process.env.KPB_EEF_SPACE_ENABLED = 'true';

        const { features } = new AppConfigController().getAppConfig();

        expect(features.eef).toBe(true);
        expect(features.eefSpace).toBe(true);
        expect(features[key]).toBe(false);
      });

      it("l'éteindre ne rallume ni ne retire rien d'autre", () => {
        process.env.KPB_EEF_TEASER_ENABLED = 'true';
        process.env.KPB_EEF_SPACE_ENABLED = 'true';
        process.env[envVar] = 'false';

        expect(new AppConfigController().getAppConfig().features).toMatchObject(
          {
            eefTeaser: true,
            eef: false,
            eefSpace: true,
            [key]: false,
          },
        );
      });
    },
  );

  // Une faute de frappe dans une variable de déploiement ne doit pas faire
  // annoncer « Invalid Date », ni — pire — faire retomber sur maintenant, ce
  // qui annoncerait une campagne s'ouvrant à l'instant où l'écran s'ouvre.
  it('serves null rather than a guess for an unparseable campaign date', () => {
    process.env.KPB_EEF_CAMPAIGN_OPENS_AT = 'pas-une-date';
    process.env.KPB_EEF_CAMPAIGN_CLOSES_AT = '   ';

    const config = new AppConfigController().getAppConfig();

    expect(config.eefCampaign.opensAt).toBeNull();
    expect(config.eefCampaign.closesAt).toBeNull();
  });

  // Le Niger : la source officielle de l'ambassade dit que le traitement des
  // dossiers d'étudiants nigériens est impossible. Annoncer une ouverture leur
  // ferait engager une démarche que l'État français déclare inopérante. La
  // liste est SERVIE pour qu'une réouverture n'attende pas un passage au store.
  it('serves the suspended-country list, trimmed and de-duplicated', () => {
    process.env.KPB_EEF_SUSPENDED_COUNTRIES = ' Niger , NE ,, Niger ';

    const config = new AppConfigController().getAppConfig();

    expect(config.eefCampaign.suspendedCountries).toEqual(['Niger', 'NE']);
  });

  // PAS de mise en majuscules, contrairement aux codes pays du Success Lab : la
  // liste est comparée à un `countryOfResidence` qui porte un nom français. La
  // normalisation est le travail du client, qui sait ce qu'il compare.
  it('keeps the operator spelling on the wire', () => {
    process.env.KPB_EEF_SUSPENDED_COUNTRIES = "Côte d'Ivoire";

    const config = new AppConfigController().getAppConfig();

    expect(config.eefCampaign.suspendedCountries).toEqual(["Côte d'Ivoire"]);
  });

  // ## Le fil porte des JOURS, pas des instants
  //
  // Ce bloc remplace un test intitulé « normalizes configured campaign dates to
  // ISO instants », qui figeait exactement la faute : la normalisation en
  // instant était le défaut, et un test la déclarait contrat.
  //
  // Une date de campagne est une date d'HORLOGE MURALE. Servir un instant le
  // laisse reprojeter dans le fuseau du lecteur, et « le 1er octobre » devient
  // « le 30 septembre » pour une partie du public — ou pour la totalité, selon
  // ce que l'exploitation a tapé.
  describe("la fenêtre de campagne est servie en jours d'horloge murale", () => {
    // LE test. Ces quatre écritures désignent des instants différents et le
    // MÊME jour administratif ; le fil doit porter « 2026-10-01 » pour les
    // quatre. La troisième est le cas de production : l'heure de Paris, réflexe
    // naturel pour une procédure française, faisait servir
    // « 2026-09-30T22:00:00.000Z » — donc le 30 septembre pour TOUT LE MONDE,
    // Dakar, Bamako, Abidjan, Niamey et Douala compris.
    it.each([
      '2026-10-01',
      '2026-10-01T00:00:00Z',
      '2026-10-01T00:00:00+02:00',
      '2026-10-01T23:30:00-05:00',
    ])('« %s » est servi « 2026-10-01 »', (written) => {
      process.env.KPB_EEF_CAMPAIGN_OPENS_AT = ` ${written} `;

      const config = new AppConfigController().getAppConfig();

      expect(config.eefCampaign.opensAt).toBe('2026-10-01');
    });

    it('ne laisse aucune heure sur le fil', () => {
      // Une heure survivante réintroduirait la possibilité d'un décalage dès
      // qu'un lecteur — client mobile d'aujourd'hui ou d'ailleurs — la parserait
      // en instant.
      process.env.KPB_EEF_CAMPAIGN_OPENS_AT = '2026-10-01T00:00:00Z';
      process.env.KPB_EEF_CAMPAIGN_CLOSES_AT = '2026-12-15T23:59:00Z';

      const config = new AppConfigController().getAppConfig();

      expect(config.eefCampaign.opensAt).toBe('2026-10-01');
      expect(config.eefCampaign.closesAt).toBe('2026-12-15');
      for (const served of [
        config.eefCampaign.opensAt,
        config.eefCampaign.closesAt,
      ]) {
        expect(served).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      }
    });

    // `new Date(Date.UTC(2026, 12, 1))` vaut janvier 2027 et un 30 février
    // devient le 2 mars : servir une date normalisée, c'est servir une date que
    // personne n'a écrite, indistinguable d'une information pour qui la lit.
    it.each([
      '2026-13-01',
      '2026-02-30',
      '2026-00-10',
      '2026-10-32',
      '26-10-01',
      '2026-1-5',
      'demain',
    ])('« %s » ne produit aucune date', (written) => {
      process.env.KPB_EEF_CAMPAIGN_OPENS_AT = written;

      const config = new AppConfigController().getAppConfig();

      expect(config.eefCampaign.opensAt).toBeNull();
    });
  });

  // ── XC-09 — la version RECOMMANDÉE, par opposition à la version minimale ──
  describe('usVisaSuspension — avis des fiches États-Unis', () => {
    it('sert la liste vérifiée le 17/10/2026 quand rien n’est configuré', () => {
      const served = new AppConfigController().getAppConfig().usVisaSuspension;
      expect(served.countries.map((c) => c.code)).toEqual([
        'BF', 'ML', 'NE', 'TD', 'CG', 'BJ', 'CI', 'SN', 'GA', 'MR', 'BI', 'TG', 'NG',
      ]);
      expect(served.countries[3]).toEqual({ code: 'TD', nameFr: 'Tchad', nameEn: 'Chad' });
      expect(served.visaTypes).toEqual(['F', 'M', 'J']);
      expect(served.lastVerifiedAt).toBe('2026-10-17');
      expect(served.sourceUrl).toMatch(/^https:\/\/travel\.state\.gov\//);
    });

    it('suit la variable, sans nouvelle build', () => {
      process.env.KPB_US_VISA_SUSPENDED_COUNTRIES = ' ng, sl ,NG ';
      process.env.KPB_US_VISA_SUSPENSION_VERIFIED_AT = '2026-11-02';
      const served = new AppConfigController().getAppConfig().usVisaSuspension;
      expect(served.countries).toEqual([
        { code: 'NG', nameFr: 'Nigeria', nameEn: 'Nigeria' },
        { code: 'SL', nameFr: 'Sierra Leone', nameEn: 'Sierra Leone' },
      ]);
      expect(served.lastVerifiedAt).toBe('2026-11-02');
    });

    it('`none` retire l’avis ; une valeur illisible garde le défaut', () => {
      process.env.KPB_US_VISA_SUSPENDED_COUNTRIES = 'none';
      expect(new AppConfigController().getAppConfig().usVisaSuspension.countries).toEqual([]);
      process.env.KPB_US_VISA_SUSPENDED_COUNTRIES = 'Burkina;Mali';
      expect(
        new AppConfigController().getAppConfig().usVisaSuspension.countries,
      ).toHaveLength(13);
    });

    it('une liste personnalisée sans date ne prend pas la date du défaut', () => {
      process.env.KPB_US_VISA_SUSPENDED_COUNTRIES = 'BF';
      process.env.KPB_US_VISA_SUSPENSION_VERIFIED_AT = '2026-02-30';
      expect(new AppConfigController().getAppConfig().usVisaSuspension.lastVerifiedAt).toBeNull();
    });

    it('n’ouvre qu’une source https', () => {
      process.env.KPB_US_VISA_SUSPENSION_SOURCE_URL = 'javascript:alert(1)';
      expect(new AppConfigController().getAppConfig().usVisaSuspension.sourceUrl).toMatch(
        /^https:\/\/travel\.state\.gov\//,
      );
      process.env.KPB_US_VISA_SUSPENSION_SOURCE_URL = 'https://travel.state.gov/x.html';
      expect(new AppConfigController().getAppConfig().usVisaSuspension.sourceUrl).toBe(
        'https://travel.state.gov/x.html',
      );
    });
  });

  describe('recommendedVersion', () => {
    it("est absente tant que l'exploitation n'en pose pas", () => {
      expect(
        new AppConfigController().getAppConfig().recommendedVersion,
      ).toBeNull();
    });

    it('sert la version posée, sans toucher à minVersion', () => {
      process.env.KPB_RECOMMENDED_APP_VERSION = ' 2.3.0 ';

      const config = new AppConfigController().getAppConfig();

      expect(config.recommendedVersion).toBe('2.3.0');
      // Le bandeau doux ne doit jamais bloquer : l'écran bloquant a sa propre
      // clé, qui reste à son défaut.
      expect(config.minVersion).toBe('0.0.0');
    });

    // Une valeur illisible vaut « pas de bandeau », jamais « bandeau pour tous ».
    it.each(['latest', '2.3', '2.3.0+54', 'v2.3.0', '2.3.0-beta', '', '  '])(
      '« %s » ne produit aucune invitation',
      (written) => {
        process.env.KPB_RECOMMENDED_APP_VERSION = written;
        expect(
          new AppConfigController().getAppConfig().recommendedVersion,
        ).toBeNull();
      },
    );
  });

  // ── XC-05 — les sources officielles de ce que l'app affirme ──
  describe('liens officiels de la campagne', () => {
    it('sert la plateforme officielle par défaut', () => {
      expect(
        new AppConfigController().getAppConfig().eefCampaign.platformUrl,
      ).toBe('https://www.campusfrance.org/fr');
    });

    it("sert la plateforme désignée par l'exploitation", () => {
      process.env.KPB_EEF_PLATFORM_URL =
        'https://www.etudes-en-france.example/fr';
      expect(
        new AppConfigController().getAppConfig().eefCampaign.platformUrl,
      ).toBe('https://www.etudes-en-france.example/fr');
    });

    // Ces valeurs sont écrites à la main : aucune ne doit atteindre un bouton
    // « ouvrir », et une faute de frappe retombe sur le lien vérifié.
    it.each([
      'javascript:alert(1)',
      'http://www.campusfrance.org/fr',
      'ftp://exemple.test',
      'https://user:pass@exemple.test/',
      'campusfrance.org',
      'pas une url',
    ])('« %s » est refusée et retombe sur le repli', (written) => {
      process.env.KPB_EEF_PLATFORM_URL = written;
      expect(
        new AppConfigController().getAppConfig().eefCampaign.platformUrl,
      ).toBe('https://www.campusfrance.org/fr');
    });

    it('sert la source officielle du Niger sans rien configurer', () => {
      process.env.KPB_EEF_SUSPENDED_COUNTRIES = 'Niger';

      const { eefCampaign } = new AppConfigController().getAppConfig();

      expect(eefCampaign.suspendedSources).toEqual([
        {
          country: 'Niger',
          url: 'https://ne.diplomatie.gouv.fr/informations-visas',
        },
      ]);
    });

    // Le code que l'exploitation écrit à côté du nom (`Niger,NE`) : un profil
    // saisi « NE » doit voir la source, pas la suspension seule.
    it('sert aussi la source pour le code « NE »', () => {
      process.env.KPB_EEF_SUSPENDED_COUNTRIES = 'Niger,NE';

      const { eefCampaign } = new AppConfigController().getAppConfig();

      expect(eefCampaign.suspendedSources).toEqual([
        {
          country: 'Niger',
          url: 'https://ne.diplomatie.gouv.fr/informations-visas',
        },
        {
          country: 'NE',
          url: 'https://ne.diplomatie.gouv.fr/informations-visas',
        },
      ]);
    });

    // Une `Map` et pas un objet : ces noms existent sur tout objet JS.
    it.each(['__proto__', 'constructor', 'toString', 'hasOwnProperty'])(
      'un pays nommé « %s » ne lit pas la chaîne de prototypes',
      (name) => {
        process.env.KPB_EEF_SUSPENDED_COUNTRIES = name;
        const { eefCampaign } = new AppConfigController().getAppConfig();
        expect(eefCampaign.suspendedSources).toEqual([]);
      },
    );

    it('ne sert une source que pour un pays réellement suspendu', () => {
      // La source du Niger ne doit pas voyager quand personne n'est suspendu :
      // un lien « voici pourquoi » sans suspension serait une accusation sans objet.
      expect(
        new AppConfigController().getAppConfig().eefCampaign.suspendedSources,
      ).toEqual([]);

      process.env.KPB_EEF_SUSPENDED_COUNTRIES = 'Mali';
      expect(
        new AppConfigController().getAppConfig().eefCampaign.suspendedSources,
      ).toEqual([]);
    });

    it('reconnaît le pays quels que soient la casse et les accents', () => {
      process.env.KPB_EEF_SUSPENDED_COUNTRIES = 'NIGER';
      expect(
        new AppConfigController().getAppConfig().eefCampaign.suspendedSources,
      ).toHaveLength(1);
    });

    it("prend la source écrite par l'exploitation avant la source connue", () => {
      process.env.KPB_EEF_SUSPENDED_COUNTRIES = "Niger,Côte d'Ivoire";
      process.env.KPB_EEF_SUSPENDED_SOURCES =
        'Niger|https://ne.exemple.test/a?x=1,2;cote d\u2019ivoire|https://ci.exemple.test/b';

      const { eefCampaign } = new AppConfigController().getAppConfig();

      expect(eefCampaign.suspendedSources).toEqual([
        { country: 'Niger', url: 'https://ne.exemple.test/a?x=1,2' },
        { country: "Côte d'Ivoire", url: 'https://ci.exemple.test/b' },
      ]);
    });

    it('ignore une entrée de source illisible ou non https, sans perdre les autres', () => {
      process.env.KPB_EEF_SUSPENDED_COUNTRIES = 'Niger,Mali';
      process.env.KPB_EEF_SUSPENDED_SOURCES =
        'Niger|javascript:alert(1);sans-separateur;Mali|https://ml.exemple.test/';

      const { eefCampaign } = new AppConfigController().getAppConfig();

      expect(eefCampaign.suspendedSources).toEqual([
        {
          country: 'Niger',
          url: 'https://ne.diplomatie.gouv.fr/informations-visas',
        },
        { country: 'Mali', url: 'https://ml.exemple.test/' },
      ]);
    });
  });

  // ── CAT-M03 — la mention de paternité exigée par la Licence Ouverte 2.0 ──
  describe('eefCatalog', () => {
    it('sert la mention de source et la date de mise à jour', () => {
      const { eefCatalog } = new AppConfigController().getAppConfig();

      expect(eefCatalog.producer).toContain('Enseignement supérieur');
      expect(eefCatalog.licence).toBe('Licence Ouverte 2.0');
      expect(eefCatalog.updatedAt).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      expect(eefCatalog.sources.length).toBeGreaterThan(0);
    });

    it("est servie même quand l'espace est fermé", () => {
      // La mention ne dépend d'aucun drapeau : le pied de l'écran la lit dès
      // qu'il existe, et l'ouverture ne doit pas dépendre d'une variable de plus.
      const config = new AppConfigController().getAppConfig();
      expect(config.features.eefSpace).toBe(false);
      expect(config.eefCatalog).toBeDefined();
    });
  });

  it('cannot expose a child capability while the parent gate is disabled', () => {
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'false';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_ENABLED = 'true';
    process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH = 'false';
    process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';

    const config = new AppConfigController().getAppConfig();

    expect(config.features.successLab).toBe(false);
    expect(config.features.aiDiagnostic).toBe(false);
    expect(config.features.outcomeEvidence).toBe(false);
  });

  // Les liens de store alimentent un écran qu'on ne peut pas fermer : une
  // valeur d'exploitation mal écrite ne doit pas le verrouiller sur un lien mort.
  describe('liens de store', () => {
    it.each([
      'javascript:alert(1)',
      'http://play.example/app',
      'play.example/app',
      'https://user:pass@play.example/app',
      'pas une url',
    ])('« %s » retombe sur la fiche publiée', (written) => {
      process.env.KPB_ANDROID_STORE_URL = written;
      process.env.KPB_IOS_STORE_URL = written;

      const config = new AppConfigController().getAppConfig();

      expect(config.androidStoreUrl).toContain('id=com.karatou.android');
      expect(config.iosStoreUrl).toContain('id1128659292');
    });

    it('une valeur https bien formée est servie (espaces retirés)', () => {
      process.env.KPB_ANDROID_STORE_URL = ' https://play.example/app ';
      expect(new AppConfigController().getAppConfig().androidStoreUrl).toBe(
        'https://play.example/app',
      );
    });
  });

  // Chantiers G et K : interrupteurs OUVERTS par défaut. Ils servent à COUPER
  // une fonction sur les téléphones installés ; une variable absente, vide ou
  // mal tapée ne doit jamais l'éteindre — seul `false` le fait.
  const followSwitches = [
    ['followPushPrimer', 'KPB_FOLLOW_PUSH_PRIMER_ENABLED'],
    ['followOpeningAlert', 'KPB_FOLLOW_OPENING_ALERT_ENABLED'],
    ['openingAlertToggle', 'KPB_OPENING_ALERT_TOGGLE_ENABLED'],
    ['followedScholarships', 'KPB_FOLLOWED_SCHOLARSHIPS_ENABLED'],
    ['notificationsUnreadCount', 'KPB_NOTIFICATIONS_UNREAD_COUNT_ENABLED'],
    ['followedScholarshipOptOut', 'KPB_FOLLOWED_SCHOLARSHIP_OPT_OUT_ENABLED'],
    ['homeFollowedEntry', 'KPB_HOME_FOLLOWED_ENTRY_ENABLED'],
    ['homeNextStep', 'KPB_HOME_NEXT_STEP_ENABLED'],
    ['homeScholarships', 'KPB_HOME_SCHOLARSHIPS_ENABLED'],
    ['homeDeadlines', 'KPB_HOME_DEADLINES_ENABLED'],
    ['homePartners', 'KPB_HOME_PARTNERS_ENABLED'],
    ['homeIntelligence', 'KPB_HOME_INTELLIGENCE_ENABLED'],
    ['homeParcours', 'KPB_HOME_PARCOURS_ENABLED'],
    ['homeCounselor', 'KPB_HOME_COUNSELOR_ENABLED'],
  ] as const;

  describe.each(followSwitches)('%s — interrupteur ouvert par défaut', (key, envVar) => {
    afterEach(() => {
      delete process.env[envVar];
    });

    it('est ouvert quand la variable est absente', () => {
      delete process.env[envVar];
      expect(new AppConfigController().getAppConfig().features[key]).toBe(true);
    });

    it('reste ouvert sur toute valeur autre que « false »', () => {
      for (const value of ['', 'true', '0', 'no', 'off', 'flase']) {
        process.env[envVar] = value;
        expect(new AppConfigController().getAppConfig().features[key]).toBe(true);
      }
    });

    it('se ferme sur « false », sans toucher aux autres', () => {
      process.env[envVar] = ' FALSE ';
      const { features } = new AppConfigController().getAppConfig();
      expect(features[key]).toBe(false);
      for (const [other] of followSwitches) {
        if (other !== key) expect(features[other]).toBe(true);
      }
    });
  });

  // « Mes 10 bourses » (chantier D) : FERMÉ par défaut, seule `true` l'ouvre,
  // et il ne touche à aucun autre interrupteur.
  describe('scholarshipMatch — fermé par défaut', () => {
    it('est fermé quand la variable est absente, vide ou mal tapée', () => {
      for (const value of [undefined, '', 'false', '1', 'yes', 'on', 'ture']) {
        if (value === undefined) delete process.env.KPB_SCHOLARSHIP_MATCH_ENABLED;
        else process.env.KPB_SCHOLARSHIP_MATCH_ENABLED = value;
        expect(new AppConfigController().getAppConfig().features.scholarshipMatch).toBe(false);
      }
    });

    it('s’ouvre sur « true » (casse et espaces tolérés), sans rien ouvrir d’autre', () => {
      const closed = new AppConfigController().getAppConfig().features;
      process.env.KPB_SCHOLARSHIP_MATCH_ENABLED = ' TRUE ';
      const opened = new AppConfigController().getAppConfig().features;
      expect(opened.scholarshipMatch).toBe(true);
      expect({ ...opened, scholarshipMatch: false }).toEqual(closed);
    });
  });

  // Onboarding « la valeur d'abord » (chantier I3) : FERMÉ par défaut, seule
  // `true` l'ouvre, et il ne touche à aucun autre interrupteur.
  describe('onboardingV2 — fermé par défaut', () => {
    it('est fermé quand la variable est absente, vide ou mal tapée', () => {
      for (const value of [undefined, '', 'false', '1', 'yes', 'on', 'ture']) {
        if (value === undefined) delete process.env.KPB_ONBOARDING_V2_ENABLED;
        else process.env.KPB_ONBOARDING_V2_ENABLED = value;
        expect(new AppConfigController().getAppConfig().features.onboardingV2).toBe(false);
      }
    });

    it('s’ouvre sur « true » (casse et espaces tolérés), sans rien ouvrir d’autre', () => {
      delete process.env.KPB_ONBOARDING_V2_ENABLED;
      const closed = new AppConfigController().getAppConfig().features;
      process.env.KPB_ONBOARDING_V2_ENABLED = ' TRUE ';
      const opened = new AppConfigController().getAppConfig().features;
      expect(opened.onboardingV2).toBe(true);
      expect({ ...opened, onboardingV2: false }).toEqual(closed);
    });
  });
});
