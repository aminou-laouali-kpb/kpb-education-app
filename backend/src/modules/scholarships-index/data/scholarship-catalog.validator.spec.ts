import { assessLegacyScholarshipSeed } from './legacy-scholarship-seed-safety';
import { mockCatalog } from '../../../common/data/mock-catalog';
import {
  importScholarshipCatalog,
  type ScholarshipCatalogWriter,
} from './scholarship-catalog.importer';
import type {
  VerifiedScholarshipCatalogRecord,
  VersionedScholarshipCatalog,
} from './scholarship-catalog.types';
import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';
import {
  CATALOG_EXPIRED_CYCLE_CODES,
  CATALOG_STALENESS_CODES,
  CATALOG_UP_TO_DATE,
  buildCatalogDiagnosis,
  eligibilityCoverage,
  validateScholarshipCatalog,
} from './scholarship-catalog.validator';

// Date de référence figée : elle rend les assertions structurelles
// déterministes. Elle est calée sur la vague de vérification la plus récente
// (10/08/2026, lot « Top 10 ») et doit avancer avec elle — sinon les nouvelles
// fiches se retrouvent dans le futur par rapport à NOW, ce que le validateur
// rejette au même titre qu'une source périmée.
//
// ⚠️ Figer le temps ici a un angle mort : aucun de ces tests ne peut détecter
// l'expiration réelle du catalogue. C'est le rôle du test « fenêtre de
// vérification réelle » en fin de fichier, qui interroge l'horloge du système.
const NOW = new Date('2026-08-10T12:00:00.000Z');

// Le catalogue REEL porte les vagues de vérification successives ; la plus
// récente est l'ajout de Gates Cambridge et CMU-Africa, lus aux sources le
// 07/10/2026, puis la relecture mensuelle complète du 24/10/2026. Les tests qui
// valident SCHOLARSHIP_CATALOG_V1 entier ont besoin d'une horloge postérieure
// à la vague la plus récente — sous [NOW], elle serait « dans le futur » et le
// validateur la signalerait. [NOW] reste l'horloge des fixtures synthétiques,
// qui datent du 10/08.
const CATALOG_NOW = new Date('2026-10-31T19:00:00.000Z');

function validRecord(): VerifiedScholarshipCatalogRecord {
  const checkedAt = '2026-07-15T12:00:00.000Z';
  return {
    catalogId: 'verified-test-record',
    levels: ['secondary', 'bachelor', 'master'],
    scholarship: {
      id: 'verified_test_record',
      nameFr: 'Bourse de test vérifiée',
      nameEn: 'Verified test scholarship',
      countryId: 'can',
      countryNameFr: 'Canada',
      countryNameEn: 'Canada',
      levelEligibleFr: 'Lycée / Licence / Master',
      levelEligibleEn: 'Secondary / Bachelor / Master',
      typeOfFundingFr: 'Complète',
      typeOfFundingEn: 'Full',
      fundingType: 'fully_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr: 'Dates de test',
      deadlineLabelEn: 'Test dates',
      descriptionFr: 'Description française de test.',
      descriptionEn: 'English test description.',
      advantagesFr: ['Avantage vérifié'],
      advantagesEn: ['Verified benefit'],
      eligibilityFr: ['Critère vérifié'],
      eligibilityEn: ['Verified criterion'],
      keyRequirementsFr: ['Document vérifié'],
      keyRequirementsEn: ['Verified document'],
      relatedFieldIds: [],
      baseMatch: 30,
      applicationUrl: 'https://official.example/application',
      sourceUrl: 'https://official.example/overview',
      // Les tags de niveau reprennent `levels` (règle `level_tags_mismatch`).
      tags: ['secondary', 'bachelor', 'master', 'test-only'],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Postuler',
        titleEn: 'Apply',
        descriptionFr: 'Utiliser le formulaire officiel.',
        descriptionEn: 'Use the official form.',
      },
    ],
    cycle: {
      academicYear: '2026-2027',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-08-01T00:00:00.000Z',
      estimatedCloseAt: '2026-10-01T00:00:00.000Z',
      sourceUrl: 'https://official.example/cycle',
    },
    officialSources: [
      'overview',
      'eligibility',
      'benefits',
      'application',
      'cycle',
    ].map((kind) => ({
      kind: kind as
        | 'overview'
        | 'eligibility'
        | 'benefits'
        | 'application'
        | 'cycle',
      url: `https://official.example/${kind}`,
      isOfficial: true,
      checkedAt,
      label: `Official ${kind}`,
    })),
    verifiedAt: checkedAt,
    verifiedBy: 'Test reviewer',
  };
}

describe('versioned scholarship catalog', () => {
  it('meets every target with official-source records while keeping unverified legacy rows in backlog', () => {
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      now: CATALOG_NOW,
    });

    expect(report.valid).toBe(true);
    expect(report.uniqueRecordCount).toBe(36);
    expect(report.uniqueRecordDeficit).toBe(0);
    // Doctorat (1.5.0) : Gates Cambridge et UCT, dont les textes le disent.
    expect(report.verifiedCounts).toEqual({
      secondary: 4,
      bachelor: 17,
      master: 27,
      doctorate: 2,
    });
    expect(report.backlogCounts).toEqual({
      secondary: 0,
      bachelor: 4,
      master: 11,
      doctorate: 0,
    });
    expect(report.volumeDeficits).toEqual({
      secondary: 0,
      bachelor: 0,
      master: 0,
      doctorate: 0,
    });
    expect(report.backlogDeficits).toEqual({
      secondary: 3,
      bachelor: 11,
      master: 4,
      doctorate: 0,
    });
    expect(report.issues.filter((issue) => issue.code === 'volume_target_not_met')).toHaveLength(0);
  });

  it('keeps the versioned backlog aligned with every legacy mock id', () => {
    const legacyIds = mockCatalog.scholarships
      .map((item) => item.id)
      .sort();
    const backlogIds = SCHOLARSHIP_CATALOG_V1.backlog
      .map((item) => item.legacyId)
      .sort();
    expect(backlogIds).toEqual(legacyIds);
  });

  it('passes structure-only validation for the progressive verified catalog', () => {
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      includeVolumeTargets: false,
      now: CATALOG_NOW,
    });
    expect(report.valid).toBe(true);
  });

  // Deux fiches annonçaient « Ouvert » pour une campagne terminée au 10/08/2026
  // (Rhodes Afrique australe, close le 3 août ; DAAD Helmut-Schmidt, le
  // 31 juillet) et le catalogue restait `valid: true`. Seule une relecture
  // humaine les a attrapées — d'où cette règle.
  it('refuse un cycle « ouvert » dont la clôture est déjà passée', () => {
    const record = validRecord();
    record.cycle.status = 'open';
    record.cycle.dateConfidence = 'confirmed';
    record.cycle.opensAt = '2026-06-01T00:00:00.000Z';
    record.cycle.closesAt = '2026-08-03T21:59:00.000Z'; // avant NOW
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [record],
      backlog: [],
    };

    const report = validateScholarshipCatalog(catalog, { now: NOW });
    const issue = report.issues.find(
      (i) => i.code === 'open_cycle_already_closed',
    );
    expect(issue).toBeDefined();
    // Le message doit nommer la date fautive : sans elle, on ignore laquelle
    // des deux dates du cycle est en cause.
    expect(issue?.message).toContain('2026-08-03');
    expect(report.valid).toBe(false);

    // La même fiche passée en `closed` redevient valide : la règle vise le
    // mensonge, pas la présence d'une date passée.
    record.cycle.status = 'closed';
    expect(
      validateScholarshipCatalog(catalog, { now: NOW }).issues.filter(
        (i) => i.code === 'open_cycle_already_closed',
      ),
    ).toEqual([]);
  });

  it('accepts a complete bilingual record with fresh official HTTPS evidence', () => {
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [validRecord()],
      backlog: [],
    };
    expect(validateScholarshipCatalog(catalog, { now: NOW })).toMatchObject({
      valid: true,
      verifiedCounts: { secondary: 1, bachelor: 1, master: 1 },
    });
  });

  it('enforces the minimum number of distinct catalog records independently of level counts', () => {
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 2,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [validRecord()],
      backlog: [],
    };

    const report = validateScholarshipCatalog(catalog, { now: NOW });
    expect(report.uniqueRecordCount).toBe(1);
    expect(report.uniqueRecordDeficit).toBe(1);
    expect(report.issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: 'unique_record_target_not_met' }),
      ]),
    );
  });

  it('rejects unofficial HTTP evidence, missing translations, steps and cycle dates', () => {
    const record = validRecord();
    record.scholarship.descriptionEn = '';
    record.applicationSteps = [];
    record.cycle.estimatedCloseAt = undefined;
    record.officialSources[0] = {
      ...record.officialSources[0],
      url: 'http://aggregator.example/item',
      isOfficial: false as never,
    };
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [record],
      backlog: [],
    };
    const codes = validateScholarshipCatalog(catalog, { now: NOW }).issues.map(
      (issue) => issue.code,
    );
    expect(codes).toEqual(
      expect.arrayContaining([
        'missing_text',
        'missing_application_steps',
        'missing_cycle_dates',
        'unofficial_source',
        'invalid_https_url',
      ]),
    );
  });

  it('rejects payload URLs that are not the URLs declared by their official source kinds', () => {
    const record = validRecord();
    record.scholarship.applicationUrl = 'https://official.example/different-application';
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [record],
      backlog: [],
    };

    expect(validateScholarshipCatalog(catalog, { now: NOW }).issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: 'source_payload_url_mismatch',
          path: 'records[0].scholarship.applicationUrl',
        }),
      ]),
    );
  });

  it('uses a create-if-absent writer so a second import cannot overwrite an edited row', async () => {
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [validRecord()],
      backlog: [],
    };
    const stored = new Set<string>();
    const writer: ScholarshipCatalogWriter = {
      async createIfAbsent(record) {
        if (stored.has(record.scholarship.id)) return 'existing';
        stored.add(record.scholarship.id);
        return 'created';
      },
    };

    await expect(importScholarshipCatalog(catalog, writer)).resolves.toMatchObject({
      created: 1,
      existingNotUpdated: 0,
    });
    await expect(importScholarshipCatalog(catalog, writer)).resolves.toMatchObject({
      created: 0,
      existingNotUpdated: 1,
    });
  });

  it('identifies the sparse legacy placeholders without treating structure as verification', () => {
    const assessment = assessLegacyScholarshipSeed({
      name: { fr: 'Canada Future Leaders', en: 'Canada Future Leaders' },
      countryId: 'can',
      levelEligible: { fr: 'Licence / Master', en: 'Bachelor / Master' },
      typeOfFunding: { fr: 'Partielle', en: 'Partial' },
      deadlineLabel: { fr: 'Mai', en: 'May' },
    });
    expect(assessment.complete).toBe(false);
    expect(assessment.missing).toEqual(
      expect.arrayContaining([
        'description.fr/en',
        'advantages.fr/en',
        'eligibility.fr/en',
        'applicationUrl.https',
        'sourceUrl.https',
      ]),
    );
  });

  // Le seul test du fichier qui utilise l'horloge RÉELLE, et c'est délibéré.
  //
  // Tous les autres épinglent `now` pour être déterministes — au prix d'un angle
  // mort : ils resteraient verts indéfiniment alors que le catalogue est devenu
  // non-importable. Le validateur refuse toute source contrôlée il y a plus de
  // 30 jours, donc les fiches expirent en silence et `import-scholarship-catalog`
  // échouerait sans que rien ne l'ait annoncé. Plus aucune bourse ne pourrait
  // être publiée.
  //
  // Ce test est donc conçu pour CASSER quand la vérification vieillit. Ce n'est
  // pas une fragilité, c'est le rappel : rouvrir les sources officielles des
  // fiches signalées, puis porter leur nouvelle date dans `checkedAt`. Ne le
  // neutralisez pas en repoussant `CHECKED_AT` sans avoir relu les pages : le
  // catalogue affirmerait une vérification qui n'a pas eu lieu.
  // Ce test garde l'horloge du système et reste dans le portail de fusion : une
  // vérification périmée demande de rouvrir les pages officielles, c'est un
  // travail humain qui se planifie, et rien d'autre dans ce dépôt ne sait le
  // réclamer.
  //
  // La campagne close, elle, a été SORTIE d'ici : c'est une ligne de littéral à
  // rafraîchir, et la laisser bloquer une PR d'authentification était une
  // punition sans rapport. Elle fait désormais rougir
  // `.github/workflows/catalog-freshness.yml`, qui tourne chaque jour.
  it('reste importable à la date du jour (fraîcheur des vérifications)', () => {
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      includeVolumeTargets: false,
    });

    // Jest n'accepte pas de message en second argument : on le fait porter par
    // la valeur comparée, pour qu'il s'affiche dans le diff de l'échec.
    expect(
      buildCatalogDiagnosis(report, {
        catalog: SCHOLARSHIP_CATALOG_V1,
        codes: CATALOG_STALENESS_CODES,
      }),
    ).toBe(CATALOG_UP_TO_DATE);
  });

  it('nomme la fiche et la règle quand une campagne annoncée ouverte est close', () => {
    const diagnosis = buildCatalogDiagnosis(
      {
        valid: false,
        validIgnoringClock: false,
        closingSoon: [],
        catalogVersion: '1.3.0',
        uniqueRecordCount: 0,
        uniqueRecordDeficit: 0,
        verifiedCounts: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        backlogCounts: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        volumeDeficits: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        backlogDeficits: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        warnings: [],
        eligibilityCoverage: eligibilityCoverage({
          ...SCHOLARSHIP_CATALOG_V1,
          records: [],
        }),
        issues: [
          {
            code: 'open_cycle_already_closed',
            path: 'records[16].cycle',
            message: 'An open cycle cannot have a closing date in the past.',
          },
        ],
      },
      { catalog: SCHOLARSHIP_CATALOG_V1, codes: CATALOG_EXPIRED_CYCLE_CODES },
    );

    expect(diagnosis).toContain('mccall_macbain_2027');
    expect(diagnosis).toContain('open_cycle_already_closed');
    expect(diagnosis).not.toBe(CATALOG_UP_TO_DATE);
  });

  // Preuve que la règle de fraîcheur peut encore échouer : si quelqu'un la
  // neutralise, ce compte tombe à zéro et ce test rougit.
  it('expire en entier une fois le plafond de 30 jours dépassé', () => {
    // 30 jours après la vague la PLUS RÉCENTE (24/08, re-vérification des 10
    // publiées), pas après la première : au 11/09 les 10 re-vérifiées étaient
    // encore fraîches et ce compte serait 24, pas 34.
    // Depuis le 24/10 (relecture mensuelle), l'horloge est placée plus
    // de 30 jours après la vague la plus récente : toutes les fiches, 36,
    // sont alors périmées par l'âge et non parce qu'elles seraient « dans le
    // futur ».
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      includeVolumeTargets: false,
      now: new Date('2026-12-05T00:00:00.000Z'),
    });

    expect(report.valid).toBe(false);
    expect(
      report.issues.filter((issue) => issue.code === 'stale_verification'),
    ).toHaveLength(36);
    expect(
      buildCatalogDiagnosis(report, {
        catalog: SCHOLARSHIP_CATALOG_V1,
        codes: CATALOG_STALENESS_CODES,
      }),
    ).toContain('mccall_macbain_2027');
  });
});

/**
 * Éligibilité structurée (catalogue 1.5.0).
 *
 * | Mutation appliquée au validateur | Test qui tombe |
 * |---|---|
 * | `validateEligibility` n'est plus appelé | « refuse un critère mal formé » et suivants |
 * | La porte passe en `error` sans relecture des 36 fiches | « avertit sans bloquer » (et la CI) |
 * | Le contrôle de citation est retiré | « refuse une citation absente de la fiche » |
 * | `level_tags_mismatch` retiré | « exige que les tags de niveau disent levels » |
 */
describe('éligibilité structurée (1.5.0)', () => {
  const quote = {
    officialTextFr: 'Critère vérifié',
    officialTextEn: 'Verified criterion',
    sourceUrl: 'https://official.example/eligibility',
  };

  function catalogOf(record: VerifiedScholarshipCatalogRecord): VersionedScholarshipCatalog {
    return {
      schemaVersion: 1,
      catalogVersion: '1.5.0',
      volumeTargets: { uniqueRecords: 1, secondary: 0, bachelor: 0, master: 0 },
      records: [record],
      backlog: [],
    };
  }

  function structured(
    overrides: Partial<NonNullable<VerifiedScholarshipCatalogRecord['eligibility']>> = {},
  ): VerifiedScholarshipCatalogRecord {
    return {
      ...validRecord(),
      eligibility: {
        fieldsScope: 'unknown',
        criteria: [
          {
            key: 'pas-canadien',
            type: 'nationality',
            impact: 'hard',
            appliesTo: 'nationality',
            mode: 'exclude',
            countries: ['can'],
            ...quote,
          },
        ],
        structuredAt: null,
        structuredBy: 'draft',
        ...overrides,
      },
    };
  }

  function codes(record: VerifiedScholarshipCatalogRecord, gate?: 'warning' | 'error') {
    const report = validateScholarshipCatalog(catalogOf(record), {
      now: NOW,
      includeVolumeTargets: false,
      ...(gate ? { structuredEligibilityGate: gate } : {}),
    });
    return {
      report,
      issues: report.issues.map((issue) => issue.code),
      warnings: report.warnings.map((issue) => issue.code),
    };
  }

  it('le catalogue réel : 36 brouillons bien formés, qui avertissent sans bloquer', () => {
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, { now: CATALOG_NOW });

    expect(report.valid).toBe(true);
    expect(report.validIgnoringClock).toBe(true);
    expect(report.issues).toEqual([]);
    expect(report.warnings).toHaveLength(36);
    expect(new Set(report.warnings.map((warning) => warning.code))).toEqual(
      new Set(['missing_structured_eligibility']),
    );
    expect(report.eligibilityCoverage).toMatchObject({
      records: 36,
      missing: 0,
      drafts: 36,
      stamped: 0,
      stale: 0,
    });
    expect(report.eligibilityCoverage.criteria).toBeGreaterThanOrEqual(
      SCHOLARSHIP_CATALOG_V1.records.length,
    );
  });

  it('avertit sans bloquer tant que la porte est en avertissement, bloque en erreur', () => {
    const draft = codes(structured());
    expect(draft.report.valid).toBe(true);
    expect(draft.warnings).toEqual(['missing_structured_eligibility']);
    expect(draft.report.warnings[0].message).toContain('awaiting human review');

    const gated = codes(structured(), 'error');
    expect(gated.report.valid).toBe(false);
    expect(gated.report.validIgnoringClock).toBe(false);
    expect(gated.issues).toEqual(['missing_structured_eligibility']);

    // Une fiche SANS bloc est signalée de la même façon.
    const bare = codes(validRecord(), 'error');
    expect(bare.issues).toEqual(['missing_structured_eligibility']);
    expect(bare.report.eligibilityCoverage.missing).toBe(1);
  });

  it('une fiche relue et tamponnée ne signale plus rien, et compte comme tamponnée', () => {
    const stamped = codes(
      structured({ structuredAt: '2026-08-01T10:00:00.000Z', structuredBy: 'Éditrice KPB' }),
      'error',
    );
    expect(stamped.issues).toEqual([]);
    expect(stamped.warnings).toEqual([]);
    expect(stamped.report.eligibilityCoverage).toMatchObject({ stamped: 1, drafts: 0 });
  });

  it('signale un tampon de plus de 400 jours, sans bloquer', () => {
    const stale = codes(
      structured({ structuredAt: '2025-06-01T10:00:00.000Z', structuredBy: 'Éditrice KPB' }),
      'error',
    );
    expect(stale.issues).toEqual([]);
    expect(stale.warnings).toEqual(['stale_structured_eligibility']);
    expect(stale.report.eligibilityCoverage.stale).toBe(1);
  });

  it('refuse un tampon incohérent : brouillon signé, tampon sans éditeur ou dans le futur', () => {
    expect(codes(structured({ structuredBy: 'Quelqu’un' })).issues).toContain(
      'invalid_structured_by',
    );
    expect(
      codes(structured({ structuredAt: '2026-08-01T10:00:00.000Z', structuredBy: 'draft' })).issues,
    ).toContain('invalid_structured_by');
    expect(
      codes(structured({ structuredAt: '2027-01-01T00:00:00.000Z', structuredBy: 'Éditrice' }))
        .issues,
    ).toContain('invalid_structured_at');
  });

  it('refuse un critère mal formé (validateur du moteur, sans repli)', () => {
    const record = structured();
    record.eligibility!.criteria = [
      {
        key: 'pays-inconnu',
        type: 'nationality',
        impact: 'hard',
        appliesTo: 'nationality',
        mode: 'exclude',
        countries: ['xxx'],
        ...quote,
      },
      { key: 'besoin', type: 'financial_need', impact: 'soft', ...quote } as never,
    ];
    const result = codes(record);
    expect(result.issues).toEqual(['invalid_eligibility_criterion', 'invalid_eligibility_criterion']);
    expect(result.report.issues[0].path).toBe('records[0].eligibility.criteria[0].countries[0]');
    expect(result.report.valid).toBe(false);
  });

  it('refuse une citation absente de la fiche, ou une source non déclarée', () => {
    const record = structured();
    record.eligibility!.criteria = [
      {
        key: 'invente',
        type: 'other',
        impact: 'soft',
        officialTextFr: 'Une condition que la fiche ne dit pas',
        officialTextEn: 'A condition the record does not state',
        sourceUrl: 'https://ailleurs.example/blog',
      },
      // FR et EN de deux lignes différentes : pas une citation.
      {
        key: 'paire-melangee',
        type: 'other',
        impact: 'soft',
        officialTextFr: 'Critère vérifié',
        officialTextEn: 'Verified document',
        sourceUrl: 'https://official.example/eligibility',
      },
    ];
    expect(codes(record).issues).toEqual([
      'criterion_quote_not_in_record',
      'criterion_source_not_official',
      'criterion_quote_not_in_record',
    ]);
  });

  it('accepte une citation tirée des pièces demandées', () => {
    const record = structured();
    record.eligibility!.criteria = [
      {
        key: 'piece',
        type: 'other',
        impact: 'informational',
        officialTextFr: 'Document vérifié',
        officialTextEn: 'Verified document',
        sourceUrl: 'https://official.example/application',
      },
    ];
    expect(codes(record).issues).toEqual([]);
  });

  it('refuse un portée de domaines inconnue et un critère d’un niveau absent de la fiche', () => {
    const record = structured({ fieldsScope: 'some' as never });
    record.levels = ['master'];
    record.scholarship.tags = ['master'];
    record.eligibility!.criteria = [
      {
        key: 'age-licence',
        type: 'age',
        impact: 'hard',
        level: 'bachelor',
        max: 21,
        maxInclusive: false,
        asOf: { kind: 'unspecified' },
        ...quote,
      },
    ];
    expect(codes(record).issues).toEqual(['invalid_fields_scope', 'criterion_level_not_in_record']);
  });

  it('accepte le niveau doctorate', () => {
    const record = structured();
    record.levels = ['master', 'doctorate'];
    record.scholarship.tags = ['master', 'doctorate'];
    const result = codes(record);
    expect(result.issues).toEqual([]);
    expect(result.report.verifiedCounts.doctorate).toBe(1);
  });

  it('exige que les tags de niveau disent exactement levels', () => {
    // La reprise SQL de `eligibleLevels` lit les tags : Gates Cambridge en
    // 1.4.0 (tag `master` seul) aurait été reprise sans le doctorat.
    const gates = SCHOLARSHIP_CATALOG_V1.records.find(
      (record) => record.scholarship.id === 'gates_cambridge_2027',
    )!;
    expect(gates.levels).toEqual(['master', 'doctorate']);
    const regressed: VerifiedScholarshipCatalogRecord = {
      ...gates,
      scholarship: {
        ...gates.scholarship,
        tags: gates.scholarship.tags.filter((tag) => tag !== 'doctorate'),
      },
    };
    const report = validateScholarshipCatalog(
      { ...SCHOLARSHIP_CATALOG_V1, records: [regressed] },
      { now: CATALOG_NOW, includeVolumeTargets: false },
    );
    expect(report.issues.map((issue) => issue.code)).toEqual(['level_tags_mismatch']);
  });
});
