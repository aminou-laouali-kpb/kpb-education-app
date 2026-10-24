/**
 * La garde du réalignement catalogue → base.
 *
 * ## Ce qu'elle défend
 *
 * Un défaut mesuré en production le 31/08/2026 : `york_pise_2027_forecast` et
 * `jj_wbgsp_2027_forecast` servaient `dateConfidence: "estimated"` alors que le
 * dépôt dit `confirmed` depuis la re-vérification du 24/08. Cause : `import`
 * saute les lignes existantes, et rien ne les réalignait ensuite.
 *
 * ## Vu rouge par mutation — le registre
 *
 * Un test qui n'a jamais été vu rouge ne prouve rien : sur ce projet, trois
 * fois, le défaut était caché par l'outil censé le détecter. Les onze mutations
 * ci-dessous ont été appliquées une par une au code de production, la suite
 * relancée, et le test nommé a bien échoué. Aucune n'est restée verte.
 *
 * | # | Mutation appliquée à `scholarship-catalog.reconcile.ts` (ou `.create-data.ts`) | Test qui tombe |
 * |---|---|---|
 * | 1 | La boucle de comparaison saute la relation `cycles` — le comportement exact d'`import` | « voit un cycle servi estimated » ; « n'annule jamais un cycle activé » |
 * | 2 | `isActive`/`moderationStatus` retirés de `NEVER_RECONCILED_FIELDS` | « ne touche jamais isActive ni moderationStatus » ; inventaire gelé |
 * | 3 | Un champ `shortPitchFr` ajouté à `buildScholarshipCreateData`, non classé | inventaire gelé |
 * | 4 | La garde `cycleIsAdminOwned` désactivée | « n'annule jamais un cycle activé » |
 * | 5 | `tags` remplacé au lieu d'être uni | « ajoute les tags sans effacer ceux de la base » |
 * | 6 | Une étape en trop supprimée au lieu d'être signalée | « signale une étape … sans la supprimer » |
 * | 7 | `deadlineAt` exclu du réalignement | « réaligne aussi la date limite servie » ; inventaire gelé |
 * | 8 | Comparaison de tableaux rendue insensible à l'ordre | « ne confond pas deux listes … d'ordre différent » |
 * | 9 | `sameValue` renvoie toujours `false` (tout diverge) | « ne signale rien quand la ligne est déjà alignée » + 3 autres |
 * | 10 | La garde du tampon de vérification désactivée | « ne remplace pas une vérification humaine plus récente » |
 * | 11 | Un cycle absent n'est plus créé | « crée un cycle absent … » |
 * | 12 | `sourceUrl` retiré de `VERIFICATION_PROVENANCE_FIELDS` | « garde la source consultée par le relecteur » |
 * | 13 | La règle de révocation rendue inopérante (`null` lu comme « jamais posé ») | « ne repose pas un tampon qu'un relecteur a révoqué » |
 * | 14 | `eligibilityKeptReason` toujours `undefined` (le dépôt écrase tout) | « n'écrase jamais une structuration relue plus récente » ; « un brouillon du dépôt ne remplace pas » |
 * | 15 | `sameValue` compare les objets par identité (`===`) | « ne voit aucun écart sur des critères rangés autrement » |
 * | 16 | Un champ d'éligibilité retiré de `ELIGIBILITY_PROVENANCE_FIELDS` | inventaire gelé ; « n'écrase jamais … » |
 *
 * La mutation n° 9 mérite un mot : elle vérifie la CONTRE-ÉPREUVE. Un détecteur
 * qui crie sur tout passerait les tests « il voit l'écart » et rendrait pourtant
 * le rapport inutilisable. Sans elle, la garde n'aurait qu'un sens sur deux.
 */
import {
  ELIGIBILITY_PROVENANCE_FIELDS,
  NEVER_RECONCILED_FIELDS,
  VERIFICATION_PROVENANCE_FIELDS,
  planIsEmpty,
  planScholarshipReconciliation,
  sameValue,
  type ReconcilableScholarshipRow,
} from './scholarship-catalog.reconcile';
import { buildScholarshipCreateData } from './scholarship-catalog.create-data';
import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';
import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';

const VERSION = SCHOLARSHIP_CATALOG_V1.catalogVersion;

function recordById(id: string): VerifiedScholarshipCatalogRecord {
  const record = SCHOLARSHIP_CATALOG_V1.records.find(
    (entry) => entry.scholarship.id === id,
  );
  if (!record) throw new Error(`fiche ${id} absente du catalogue ${VERSION}`);
  return record;
}

/**
 * La ligne telle que `import` l'a créée à partir d'UNE version du catalogue.
 * On fabrique l'état de production en rejouant la création depuis la fiche
 * d'AVANT correction : c'est littéralement ce qui s'est passé, pas une maquette.
 */
function rowAsCreatedFrom(
  record: VerifiedScholarshipCatalogRecord,
  catalogVersion = VERSION,
): ReconcilableScholarshipRow {
  const data = buildScholarshipCreateData(record, catalogVersion) as Record<
    string,
    unknown
  >;
  const { applicationSteps, cycles, ...scalars } = data;
  return {
    ...scalars,
    applicationSteps: (
      applicationSteps as { create: Array<Record<string, unknown>> }
    ).create.map((step) => ({
      estimatedDurationDays: null,
      ...step,
    })),
    cycles: [
      {
        estimatedOpenAt: null,
        estimatedCloseAt: null,
        opensAt: null,
        closesAt: null,
        sourceUrl: null,
        verifiedAt: null,
        activatedAt: null,
        ...(cycles as { create: Record<string, unknown> }).create,
      },
    ],
  } as unknown as ReconcilableScholarshipRow;
}

/**
 * `york_pise_2027_forecast` telle que le dépôt la disait AVANT la
 * re-vérification du 24/08/2026.
 *
 * Ce n'est pas un décor inventé : c'est le littéral retiré par le commit
 * 1176f22 (« second acte du 24/08 — les 24 non publiées relues, 2 promues en
 * dates fermes »). La ligne de production a été créée depuis celui-ci, et
 * `import` ne l'a jamais relue depuis. Un décor approximatif — se contenter de
 * basculer `dateConfidence` — raterait le cas qui compte le plus : les
 * projections doivent DISPARAÎTRE quand la date ferme arrive, pas cohabiter
 * avec elle.
 */
function beforeReverification(
  current: VerifiedScholarshipCatalogRecord,
): VerifiedScholarshipCatalogRecord {
  return {
    ...current,
    cycle: {
      academicYear: '2027-2028',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-11-01T00:00:00.000Z',
      estimatedCloseAt: '2027-01-26T23:59:59.000Z',
      sourceUrl: current.cycle.sourceUrl,
    },
  };
}

describe('planScholarshipReconciliation', () => {
  describe("l'écart mesuré en production le 31/08/2026", () => {
    // Mutation n° 1 : faire ignorer la relation `cycles` à la boucle de
    // comparaison — c'est-à-dire le comportement d'`import`, qui ne relit jamais
    // une ligne existante. C'est le défaut lui-même, remis en place.
    it('voit un cycle servi « estimated » là où le dépôt dit « confirmed »', () => {
      const current = recordById('york_pise_2027_forecast');
      expect(current.cycle.dateConfidence).toBe('confirmed');

      const row = rowAsCreatedFrom(beforeReverification(current));

      const plan = planScholarshipReconciliation(current, VERSION, row);

      expect(plan.presentInDatabase).toBe(true);
      expect(
        plan.drifts.map((drift) => `${drift.scope}.${drift.field}`),
      ).toContain('cycle.dateConfidence');
      const drift = plan.drifts.find(
        (item) => item.scope === 'cycle' && item.field === 'dateConfidence',
      )!;
      expect(drift.inDatabase).toBe('estimated');
      expect(drift.inCatalog).toBe('confirmed');
      expect(drift.reconciled).toBe(true);
      expect(plan.cycle.action).toBe('update');
      expect(plan.cycle.data.dateConfidence).toBe('confirmed');
      expect(plan.cycle.data.closesAt).toEqual(
        new Date('2027-01-28T04:59:00.000Z'),
      );
      expect(plan.cycle.data.estimatedCloseAt).toBeNull();
    });

    // `deadlineAt` est DÉRIVÉ de `dateConfidence` dans `buildScholarshipCreateData` :
    // une fiche estimée sert `estimatedCloseAt`, une fiche confirmée sert
    // `closesAt`. C'est le champ que l'étudiant voit. Sans cette assertion, on
    // pourrait corriger le cycle en laissant la fiche afficher l'ancienne date.
    it('réaligne aussi la date limite servie, dérivée de la confiance', () => {
      const current = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(beforeReverification(current));

      const plan = planScholarshipReconciliation(current, VERSION, row);

      // La date SERVIE était la projection du 26/01 ; le dépôt dit 28/01.
      expect(row.deadlineAt).toEqual(new Date('2027-01-26T23:59:59.000Z'));
      expect(Object.keys(plan.scholarshipUpdate)).toContain('deadlineAt');
      expect(plan.scholarshipUpdate.deadlineAt).toEqual(
        new Date(current.cycle.closesAt!),
      );
    });

    it("ne signale rien quand la ligne est déjà alignée sur le dépôt", () => {
      // La contre-épreuve. Sans elle, un détecteur qui crierait sur TOUT
      // passerait les tests précédents et rendrait le rapport inutilisable.
      const record = recordById('jj_wbgsp_2027_forecast');
      const plan = planScholarshipReconciliation(
        record,
        VERSION,
        rowAsCreatedFrom(record),
      );

      expect(plan.drifts).toEqual([]);
      expect(planIsEmpty(plan)).toBe(true);
    });
  });

  describe('la modération reste fail-closed', () => {
    // Mutation n° 2 : retirer `isActive` et `moderationStatus` de
    // NEVER_RECONCILED_FIELDS fait apparaître les deux clés dans le plan.
    //
    // Le décor est celui qui compte : une fiche PUBLIÉE (isActive/approved) et
    // divergente. C'est là qu'un réalignement naïf republierait — ou
    // dépublierait — sans qu'on l'ait demandé, puisque le catalogue pose
    // toujours `false`/`pending` à la création.
    it('ne touche jamais isActive ni moderationStatus, même sur une fiche publiée', () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(beforeReverification(record));
      row.isActive = true;
      row.moderationStatus = 'approved';

      const plan = planScholarshipReconciliation(record, VERSION, row);

      // Il y a bien du travail : sinon l'absence des deux clés ne prouve rien.
      expect(planIsEmpty(plan)).toBe(false);
      expect(Object.keys(plan.scholarshipUpdate)).not.toContain('isActive');
      expect(Object.keys(plan.scholarshipUpdate)).not.toContain(
        'moderationStatus',
      );
      expect(
        plan.drifts.some((drift) =>
          ['isActive', 'moderationStatus'].includes(drift.field),
        ),
      ).toBe(false);
    });
  });

  describe('inventaire gelé des champs réalignés', () => {
    /**
     * LA garde contre le PROCHAIN champ qui dérivera en silence.
     *
     * Cette liste est écrite à la main, ici, et n'est PAS dérivée du code
     * qu'elle contrôle — sinon elle serait une tautologie, et une tautologie ne
     * tombe jamais rouge. Ajouter un champ à `buildScholarshipCreateData` sans
     * décider s'il doit être réaligné casse ce test.
     *
     * Mutation n° 3 : ajouter `shortPitchFr` à la création (et rien d'autre)
     * fait échouer ce test en nommant le champ resté non classé.
     */
    const RECONCILED_SCHOLARSHIP_FIELDS = [
      'advantagesEn',
      'advantagesFr',
      'applicationRequirement',
      'applicationUrl',
      'baseMatch',
      'countryId',
      'countryNameEn',
      'countryNameFr',
      'deadlineAt',
      'deadlineLabelEn',
      'deadlineLabelFr',
      'descriptionEn',
      'descriptionFr',
      'eligibilityEn',
      'eligibilityFr',
      'fundingType',
      'keyRequirementsEn',
      'keyRequirementsFr',
      'lastVerifiedAt',
      'levelEligibleEn',
      'levelEligibleFr',
      'nameEn',
      'nameFr',
      'relatedFieldIds',
      'sourceUrl',
      'tags',
      'typeOfFundingEn',
      'typeOfFundingFr',
      'verifiedById',
      'verifiedByName',
    ] as const;

    /** Rend chaque valeur différente de celle du catalogue, quel que soit son type. */
    function divergent(value: unknown): unknown {
      if (value instanceof Date) return new Date(value.getTime() - 86_400_000);
      // `['DIVERGENT']` et non `[]` : plusieurs fiches ont déjà des listes vides
      // (`relatedFieldIds`), et un vide face à un vide n'est pas une divergence.
      if (Array.isArray(value)) return ['DIVERGENT'];
      if (typeof value === 'number') return value + 1;
      if (typeof value === 'boolean') return !value;
      if (typeof value === 'string') return `${value}-DIVERGENT`;
      return 'DIVERGENT';
    }

    it('classe chaque champ de la création : réaligné, ou explicitement jamais', () => {
      const record = recordById('york_pise_2027_forecast');
      const produced = Object.keys(
        buildScholarshipCreateData(record, VERSION) as Record<string, unknown>,
      );

      expect([...produced].sort()).toEqual(
        [
          ...RECONCILED_SCHOLARSHIP_FIELDS,
          ...NEVER_RECONCILED_FIELDS,
          ...ELIGIBILITY_PROVENANCE_FIELDS,
        ].sort(),
      );
      // Écrite à la main, elle aussi : la liste du code ne se contrôle pas
      // elle-même.
      expect([...ELIGIBILITY_PROVENANCE_FIELDS].sort()).toEqual([
        'eligibilityCriteria',
        'eligibilityStructuredAt',
        'eligibilityStructuredBy',
        'eligibleLevels',
        'fieldsScope',
      ]);
    });

    it('réaligne effectivement TOUS les champs de cette liste', () => {
      // Le pendant du test précédent : une liste juste mais que le plan
      // n'honorerait pas serait une garde de papier.
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      for (const field of RECONCILED_SCHOLARSHIP_FIELDS) {
        row[field] = divergent(row[field]);
      }

      const plan = planScholarshipReconciliation(record, VERSION, row);

      expect(Object.keys(plan.scholarshipUpdate).sort()).toEqual(
        [...RECONCILED_SCHOLARSHIP_FIELDS].sort(),
      );
    });
  });

  describe('ce que la BASE possède, et que le dépôt ne doit pas reprendre', () => {
    // Mutation n° 4 : désactiver la garde `cycleIsAdminOwned` réécrit le cycle
    // en `forecast`/`estimated` et rétrograde `deadlineAt` sur la date estimée —
    // soit exactement le défaut d'aujourd'hui, dans l'autre sens.
    it("n'annule jamais un cycle activé depuis l'admin", () => {
      const record = recordById('york_pise_2027_forecast');
      const forecastRecord: VerifiedScholarshipCatalogRecord = {
        ...record,
        cycle: {
          ...record.cycle,
          status: 'forecast',
          dateConfidence: 'estimated',
        },
      };
      // La base : un relecteur a activé le cycle (status open, dates fermes).
      const row = rowAsCreatedFrom(record);
      row.cycles[0].status = 'open';
      row.cycles[0].dateConfidence = 'confirmed';
      row.cycles[0].activatedAt = new Date('2026-08-28T09:00:00.000Z');

      const plan = planScholarshipReconciliation(forecastRecord, VERSION, row);

      expect(plan.cycle.action).toBe('none');
      expect(Object.keys(plan.scholarshipUpdate)).not.toContain('deadlineAt');
      const kept = plan.drifts.filter((drift) => !drift.reconciled);
      expect(kept.length).toBeGreaterThan(0);
      // Conservé n'est pas tu : l'écart doit rester lisible dans le rapport.
      expect(kept.map((drift) => drift.field)).toContain('dateConfidence');
      expect(kept[0].keptReason).toContain('activé en base');
    });

    it('ne remplace pas une vérification humaine plus récente par un tampon plus ancien', () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      row.lastVerifiedAt = new Date('2026-10-30T10:00:00.000Z');
      row.verifiedById = 'admin-42';
      row.verifiedByName = 'Relecteur KPB';
      row.sourceUrl = 'https://futurestudents.yorku.ca/corrigee-par-le-relecteur';

      const plan = planScholarshipReconciliation(record, VERSION, row);

      for (const field of VERIFICATION_PROVENANCE_FIELDS) {
        expect(Object.keys(plan.scholarshipUpdate)).not.toContain(field);
      }
      expect(
        plan.drifts.find((drift) => drift.field === 'verifiedByName')?.keptReason,
      ).toContain('plus récente');
    });

    // Mutation n° 12 : retirer `sourceUrl` de VERIFICATION_PROVENANCE_FIELDS.
    //
    // `AdminCatalogService.verificationData` écrit `sourceUrl` AVEC le tampon :
    // c'est la source que le relecteur a réellement ouverte. Garder son nom en
    // réécrivant sa source par celle, plus ancienne, du dépôt produit une ligne
    // qui attribue une vérification humaine à un lien que cette personne n'a
    // jamais consulté. La provenance se déplace d'un bloc ou pas du tout.
    it("garde la source consultée par le relecteur, pas celle du dépôt", () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      row.lastVerifiedAt = new Date('2026-10-30T10:00:00.000Z');
      row.verifiedByName = 'Relecteur KPB';
      row.sourceUrl = 'https://futurestudents.yorku.ca/corrigee-par-le-relecteur';

      const plan = planScholarshipReconciliation(record, VERSION, row);

      expect(Object.keys(plan.scholarshipUpdate)).not.toContain('sourceUrl');
      expect(
        plan.drifts.find((drift) => drift.field === 'sourceUrl')?.reconciled,
      ).toBe(false);
    });

    /**
     * Mutation n° 13 : rendre la règle de révocation inopérante (traiter un
     * `lastVerifiedAt` nul comme « jamais posé »). Le plan réécrit alors le
     * tampon du catalogue et la fiche redevient publique.
     *
     * C'est le cas le plus grave couvert par ce fichier, et le moins visible.
     * `AdminCatalogService.setVerification(..., false)` met `lastVerifiedAt`,
     * `verifiedById` et `verifiedByName` à `null` pour dire « à confirmer », et
     * ne touche NI `isActive` NI `moderationStatus`. La fiche reste donc active
     * et approuvée : seule la clause `lastVerifiedAt: { not: null }` de
     * `publicScholarshipWhere` la masque. Reposer le tampon la republie — sans
     * relecture, et sans qu'aucune assertion ne parle, puisque le filet existant
     * cherche l'inverse (une fiche active SANS tampon).
     */
    it("ne repose pas un tampon qu'un relecteur a révoqué", () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      // L'état exact laissé par `setVerification(..., false)`.
      row.lastVerifiedAt = null;
      row.verifiedById = null;
      row.verifiedByName = null;
      // …sur une fiche restée publiée, ce que la révocation ne change pas.
      row.isActive = true;
      row.moderationStatus = 'approved';

      const plan = planScholarshipReconciliation(record, VERSION, row);

      expect(Object.keys(plan.scholarshipUpdate)).not.toContain('lastVerifiedAt');
      expect(Object.keys(plan.scholarshipUpdate)).not.toContain('verifiedById');
      expect(Object.keys(plan.scholarshipUpdate)).not.toContain('verifiedByName');
      const drift = plan.drifts.find(
        (item) => item.field === 'lastVerifiedAt',
      )!;
      expect(drift.reconciled).toBe(false);
      expect(drift.keptReason).toContain('révoquée');
    });

    it('repose bien le tampon quand la base ne le contredit pas', () => {
      // La contre-épreuve de la révocation : sans elle, une règle qui refuserait
      // TOUJOURS d'écrire la provenance passerait les deux tests ci-dessus et
      // laisserait les tampons dériver en silence.
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      row.lastVerifiedAt = new Date('2026-01-01T00:00:00.000Z');
      row.verifiedByName = 'Relecteur d’il y a longtemps';

      const plan = planScholarshipReconciliation(record, VERSION, row);

      expect(plan.scholarshipUpdate.verifiedByName).toBe(record.verifiedBy);
      expect(plan.scholarshipUpdate.lastVerifiedAt).toEqual(
        new Date(record.verifiedAt),
      );
    });

    // Mutation n° 5 : remplacer l'union par un remplacement pur
    // (`scholarshipUpdate.tags = wanted`) fait disparaître `curated-2026` et le
    // tag `catalog:1.2.0` — or c'est par ce tag que `publish` retrouve les
    // lignes d'une version antérieure.
    it('ajoute les tags du catalogue sans effacer ceux de la base', () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record, '1.2.0');
      row.tags = [...(row.tags as string[]), 'curated-2026'];

      const plan = planScholarshipReconciliation(record, VERSION, row);

      const tags = plan.scholarshipUpdate.tags as string[];
      expect(tags).toContain(`catalog:${VERSION}`);
      expect(tags).toContain('catalog:1.2.0');
      expect(tags).toContain('curated-2026');
    });
  });

  describe('les étapes de candidature', () => {
    it('met à jour une étape par son numéro, sans jamais rien supprimer', () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      row.applicationSteps[0].titleFr = 'Ancien libellé';

      const plan = planScholarshipReconciliation(record, VERSION, row);

      expect(plan.steps.update).toHaveLength(1);
      expect(plan.steps.update[0].stepNumber).toBe(
        row.applicationSteps[0].stepNumber,
      );
      expect(plan.steps.update[0].data.titleFr).toBe(
        record.applicationSteps[0].titleFr,
      );
    });

    // Mutation n° 6 : remplacer le signalement par une suppression — ce que
    // ferait un « delete + recreate » naïf — détache la progression des
    // étudiants via `sourceStepId` (onDelete: SetNull).
    it('signale une étape présente en base et absente du catalogue, sans la supprimer', () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      row.applicationSteps.push({
        stepNumber: 99,
        titleFr: 'Étape ajoutée dans l’admin',
        titleEn: 'Step added in the admin',
        descriptionFr: '',
        descriptionEn: '',
        estimatedDurationDays: null,
      });

      const plan = planScholarshipReconciliation(record, VERSION, row);

      expect(plan.steps.extraInDatabase).toEqual([99]);
      expect(Object.keys(plan.steps)).not.toContain('delete');
      const drift = plan.drifts.find((item) => item.field.includes('[99]'))!;
      expect(drift.reconciled).toBe(false);
      expect(drift.keptReason).toContain('progression des étudiants');
    });

    it('crée un cycle absent plutôt que de laisser la fiche sans fenêtre', () => {
      const record = recordById('york_pise_2027_forecast');
      const row = rowAsCreatedFrom(record);
      row.cycles = [];

      const plan = planScholarshipReconciliation(record, VERSION, row);

      expect(plan.cycle.action).toBe('create');
      expect(plan.cycle.data.academicYear).toBe(record.cycle.academicYear);
    });
  });

  describe('une fiche absente de la base', () => {
    it("relève d'`import`, pas de `reconcile`", () => {
      const record = recordById('york_pise_2027_forecast');
      const plan = planScholarshipReconciliation(record, VERSION, null);

      expect(plan.presentInDatabase).toBe(false);
      expect(planIsEmpty(plan)).toBe(true);
      expect(plan.drifts).toEqual([]);
    });
  });
});

describe("l'éligibilité structurée (catalogue 1.5.0)", () => {
  const STAMP_IN_DB = new Date('2026-10-01T09:00:00.000Z');

  /** Ce qu'un éditeur écrit dans l'admin : un bloc relu et tamponné. */
  function stampedInAdmin(row: ReconcilableScholarshipRow, at = STAMP_IN_DB) {
    // Chaque champ du bloc diffère de la fiche Eiffel du dépôt (master seul).
    row.eligibleLevels = ['master', 'doctorate'];
    row.fieldsScope = 'all';
    row.eligibilityCriteria = [
      {
        key: 'relu-dans-l-admin',
        type: 'other',
        impact: 'soft',
        officialTextFr: 'x',
        officialTextEn: 'x',
        sourceUrl: 'https://example.org',
      },
    ];
    row.eligibilityStructuredAt = at;
    row.eligibilityStructuredBy = 'Éditrice KPB';
  }

  /** La même fiche, mais relue et tamponnée DANS LE DÉPÔT à `at`. */
  function stampedInRepo(
    record: VerifiedScholarshipCatalogRecord,
    at: string,
  ): VerifiedScholarshipCatalogRecord {
    return {
      ...record,
      eligibility: { ...record.eligibility!, structuredAt: at, structuredBy: 'Relecteur dépôt' },
    };
  }

  it('écrit les champs du chantier D sur une ligne importée avant eux', () => {
    // L'état laissé par la migration : niveaux repris des tags 1.4.0 (Gates
    // n'avait que `master`), aucun critère, aucun tampon.
    const record = recordById('gates_cambridge_2027');
    const row = rowAsCreatedFrom(record);
    row.eligibleLevels = ['master'];
    row.fieldsScope = 'unknown';
    row.eligibilityCriteria = [];
    row.eligibilityStructuredAt = null;
    row.eligibilityStructuredBy = null;
    row.tags = (row.tags as string[]).filter(
      (tag) => tag !== 'doctorate' && tag !== `catalog:${VERSION}`,
    );

    const plan = planScholarshipReconciliation(record, VERSION, row);

    expect(plan.scholarshipUpdate.eligibleLevels).toEqual(['master', 'doctorate']);
    expect(plan.scholarshipUpdate.eligibilityCriteria).toEqual(record.eligibility!.criteria);
    expect(plan.scholarshipUpdate.eligibilityStructuredBy).toBe('draft');
    // Un brouillon reste un brouillon : aucun tampon n'est inventé.
    expect(Object.keys(plan.scholarshipUpdate)).not.toContain('eligibilityStructuredAt');
    expect(plan.scholarshipUpdate.tags).toEqual(
      expect.arrayContaining(['doctorate', `catalog:${VERSION}`]),
    );
  });

  it("n'écrase jamais une structuration relue en base plus récente que celle du dépôt", () => {
    const record = stampedInRepo(recordById('eiffel_excellence_master_2027'), '2026-09-15T00:00:00.000Z');
    const row = rowAsCreatedFrom(record);
    stampedInAdmin(row);

    const plan = planScholarshipReconciliation(record, VERSION, row);

    for (const field of ELIGIBILITY_PROVENANCE_FIELDS) {
      expect(Object.keys(plan.scholarshipUpdate)).not.toContain(field);
    }
    const kept = plan.drifts.filter((drift) =>
      (ELIGIBILITY_PROVENANCE_FIELDS as readonly string[]).includes(drift.field),
    );
    // Conservé n'est pas tu : chaque champ divergent reste dans le rapport.
    expect(kept.map((drift) => drift.field).sort()).toEqual(
      [...ELIGIBILITY_PROVENANCE_FIELDS].sort(),
    );
    expect(kept.every((drift) => !drift.reconciled)).toBe(true);
    expect(kept[0].keptReason).toContain('plus récente');
  });

  it('un brouillon du dépôt ne remplace pas des critères tamponnés, même anciens', () => {
    const record = recordById('eiffel_excellence_master_2027');
    expect(record.eligibility!.structuredAt).toBeNull();
    const row = rowAsCreatedFrom(record);
    stampedInAdmin(row, new Date('2025-01-01T00:00:00.000Z'));

    const plan = planScholarshipReconciliation(record, VERSION, row);

    for (const field of ELIGIBILITY_PROVENANCE_FIELDS) {
      expect(Object.keys(plan.scholarshipUpdate)).not.toContain(field);
    }
    expect(
      plan.drifts.find((drift) => drift.field === 'eligibilityCriteria')?.keptReason,
    ).toContain('un brouillon du dépôt ne les remplace pas');
  });

  it('une relecture du dépôt plus récente remplace le bloc entier', () => {
    // La contre-épreuve : une règle qui refuserait toujours d'écrire passerait
    // les deux tests précédents.
    const record = stampedInRepo(recordById('eiffel_excellence_master_2027'), '2026-10-10T00:00:00.000Z');
    const row = rowAsCreatedFrom(record);
    stampedInAdmin(row);

    const plan = planScholarshipReconciliation(record, VERSION, row);

    expect(Object.keys(plan.scholarshipUpdate).sort()).toEqual(
      [...ELIGIBILITY_PROVENANCE_FIELDS].sort(),
    );
    expect(plan.scholarshipUpdate.eligibilityStructuredAt).toEqual(
      new Date('2026-10-10T00:00:00.000Z'),
    );
    expect(plan.scholarshipUpdate.eligibilityStructuredBy).toBe('Relecteur dépôt');
  });

  it('ne voit aucun écart sur des critères rangés autrement par PostgreSQL', () => {
    // `jsonb` réordonne les clés ; une clé `undefined` n'existe pas en JSON.
    const record = recordById('turkiye_scholarships_2027_forecast');
    const row = rowAsCreatedFrom(record);
    row.eligibilityCriteria = record.eligibility!.criteria.map((criterion) =>
      Object.fromEntries(Object.entries(criterion).reverse()),
    );

    const plan = planScholarshipReconciliation(record, VERSION, row);

    expect(plan.drifts).toEqual([]);
    expect(planIsEmpty(plan)).toBe(true);
  });
});

describe('sameValue', () => {
  it('traite ∅ et absent comme le même vide, et une Date comme son instant', () => {
    expect(sameValue(null, undefined)).toBe(true);
    const instant = new Date('2027-01-15T00:00:00.000Z');
    expect(sameValue(instant, new Date(instant.getTime()))).toBe(true);
    expect(sameValue(instant, new Date(instant.getTime() + 1))).toBe(false);
  });

  // L'ordre d'une liste d'avantages est éditorial : deux mêmes éléments dans un
  // autre ordre sont une vraie divergence, pas un faux positif à absorber.
  it("ne confond pas deux listes de même contenu et d'ordre différent", () => {
    expect(sameValue(['a', 'b'], ['b', 'a'])).toBe(false);
    expect(sameValue(['a', 'b'], ['a', 'b'])).toBe(true);
  });

  it('compare deux objets JSON clé par clé, sans tenir compte de leur ordre', () => {
    expect(sameValue({ a: 1, b: ['x'] }, { b: ['x'], a: 1 })).toBe(true);
    expect(sameValue({ a: 1, b: undefined }, { a: 1 })).toBe(true);
    expect(sameValue({ a: 1 }, { a: 2 })).toBe(false);
    expect(sameValue({ a: 1 }, ['a'])).toBe(false);
    expect(sameValue([{ a: 1 }], [{ a: 1 }])).toBe(true);
  });
});
