import type {
  AcademicGradeCriterion,
  AgeAsOf,
  AgeCriterion,
  CefrLevel,
  CriterionImpact,
  EligibilityCriterion,
  EligibleLevel,
  FinancialNeedCriterion,
  LanguageCriterion,
  LanguageTestType,
  NationalityAppliesTo,
  NationalityCriterion,
  NationalityMode,
  OtherCriterion,
  WorkExperienceCriterion,
} from '../../scholarship-match/eligibility-criteria';
import {
  DRAFT_STRUCTURED_BY,
  type ScholarshipFieldsScope,
  type VerifiedScholarshipCatalogRecord,
} from './scholarship-catalog.types';

/**
 * Éligibilité structurée des fiches du catalogue vérifié (catalogue 1.5.0).
 *
 * ## Ce que ce fichier est, et ce qu'il n'est pas
 *
 * Des BROUILLONS. Chaque critère a été rédigé à partir du texte d'éligibilité
 * DÉJÀ présent dans la fiche (`scholarship.eligibilityFr/En`), lui-même relu
 * contre la source officielle « eligibility » de la fiche. Aucune condition
 * n'a été cherchée ailleurs ni ajoutée : quand le texte renvoie à une liste
 * qu'il ne reproduit pas (« pays figurant dans la liste officielle »), le
 * critère reste `other` et cite la phrase, au lieu d'inventer la liste.
 *
 * La citation n'est pas recopiée ici : chaque critère désigne la LIGNE
 * d'éligibilité qu'il structure (`line`, index dans `eligibilityFr/En`), et
 * {@link attachStructuredEligibility} y lit `officialTextFr/En` et la source
 * officielle « eligibility » de la fiche. Une citation ne peut donc pas
 * diverger du texte de la fiche, et le validateur le vérifie quand même
 * (`criterion_quote_not_in_record`).
 *
 * ## Pourquoi un brouillon n'exclut personne
 *
 * `structuredAt` reste nul et `structuredBy` vaut `draft` tant qu'un éditeur
 * n'a pas relu les critères d'une fiche contre sa source. Le moteur
 * (`scholarship-match/assess.ts`) n'exclut que sur un tampon posé et de moins
 * de 400 jours : un brouillon donne au pire « à vérifier ». Pour tamponner une
 * fiche après relecture, ajouter `reviewed: { at, by }` à son entrée (voir
 * `docs/catalog-verification-sop.md`).
 *
 * ## Règles de rédaction (à garder en relisant)
 *
 * - `hard` seulement pour une condition de nationalité, de résidence, d'âge ou
 *   d'expérience ÉNONCÉE comme condition, sans alternative ni « en principe ».
 *   Une limite assortie d'une exception (« voies d'âge particulières », « pays
 *   fragiles ») ou d'une ambiguïté (binationaux non tranchés) reste `soft`.
 * - `soft` pour toute autre condition qui peut écarter un candidat sans que le
 *   test la connaisse (inscription en cours, diplôme déjà détenu, nomination,
 *   bourse antérieure…) : elle donne « à vérifier », jamais une exclusion.
 * - `informational` pour les qualités appréciées à la sélection, la procédure
 *   et ce qui restate le niveau : cité, sans effet sur le statut.
 * - `financial_need` est toujours `informational`.
 * - Les seuils en pourcentage (« 70 % ») restent `academic_grade` souples sans
 *   `minOn20` : la conversion vers /20 n'est pas univoque. `minOn20` n'est posé
 *   que pour une note sur 10 (« 7/10 » = 14/20).
 * - Un âge sans date de référence publiée est `asOf: unspecified` (marge de
 *   12 mois dans le moteur), même quand la fiche dit « à l'inscription ».
 * - Chaque ligne d'éligibilité est représentée par au moins un critère, pour
 *   que la relecture se fasse ligne à ligne.
 */

type Quoted = 'officialTextFr' | 'officialTextEn' | 'sourceUrl';

/** Un critère tel qu'écrit ici : la citation est désignée par sa ligne. */
type Drafted<T extends EligibilityCriterion> = Omit<T, Quoted> & {
  /** Index de la ligne citée dans `eligibilityFr` / `eligibilityEn`. */
  line: number;
};

export type DraftCriterion =
  | Drafted<NationalityCriterion>
  | Drafted<AgeCriterion>
  | Drafted<WorkExperienceCriterion>
  | Drafted<LanguageCriterion>
  | (Omit<Drafted<AcademicGradeCriterion>, 'rawText'> & { rawText?: string })
  | Drafted<FinancialNeedCriterion>
  | Drafted<OtherCriterion>;

export interface EligibilityDraft {
  fieldsScope: ScholarshipFieldsScope;
  criteria: DraftCriterion[];
  /**
   * Posé par l'éditeur qui a relu CES critères contre la source officielle.
   * Absent = brouillon (`structuredAt: null`, `structuredBy: 'draft'`).
   */
  reviewed?: { at: string; by: string };
}

// ── Fabriques ───────────────────────────────────────────────────────────────

function nationality(
  key: string,
  line: number,
  mode: NationalityMode,
  countries: string[],
  appliesTo: NationalityAppliesTo = 'nationality',
  impact: CriterionImpact = 'hard',
): DraftCriterion {
  return { type: 'nationality', key, line, impact, appliesTo, mode, countries };
}

function age(
  key: string,
  line: number,
  bounds: {
    level?: EligibleLevel;
    min?: number;
    max?: number;
    maxInclusive: boolean;
    asOf: AgeAsOf;
  },
  impact: CriterionImpact = 'hard',
): DraftCriterion {
  return { type: 'age', key, line, impact, ...bounds };
}

function experience(
  key: string,
  line: number,
  minMonths: number,
  impact: CriterionImpact = 'hard',
): DraftCriterion {
  return { type: 'work_experience', key, line, impact, minMonths };
}

function language(
  key: string,
  line: number,
  spec: {
    lang: string;
    minCefr?: CefrLevel;
    tests?: Array<{ type: LanguageTestType; min: number }>;
    waivable: boolean;
  },
  impact: CriterionImpact = 'soft',
): DraftCriterion {
  return { type: 'language', key, line, impact, ...spec };
}

function grade(
  key: string,
  line: number,
  options: { minOn20?: number; impact?: CriterionImpact } = {},
): DraftCriterion {
  return {
    type: 'academic_grade',
    key,
    line,
    impact: options.impact ?? 'soft',
    ...(options.minOn20 !== undefined ? { minOn20: options.minOn20 } : {}),
  };
}

function need(key: string, line: number): DraftCriterion {
  return { type: 'financial_need', key, line, impact: 'informational' };
}

/** Condition que le test ne sait pas évaluer : « à vérifier ». */
function condition(key: string, line: number): DraftCriterion {
  return { type: 'other', key, line, impact: 'soft' };
}

/** Qualité de sélection, procédure ou rappel du niveau : citée seulement. */
function note(key: string, line: number): DraftCriterion {
  return { type: 'other', key, line, impact: 'informational' };
}

const UNSPECIFIED: AgeAsOf = { kind: 'unspecified' };

function on(date: string): AgeAsOf {
  return { kind: 'date', date };
}

// ── Listes définitionnelles ─────────────────────────────────────────────────

/**
 * « Africain », « de nationalité africaine » : les 54 États africains membres
 * de l'ONU, plus le Sahara occidental (lecture la plus inclusive). C'est la
 * DÉFINITION du mot employé par la fiche, pas une liste tirée d'ailleurs.
 */
export const AFRICAN_COUNTRY_CODES: readonly string[] = [
  'dza', 'ago', 'ben', 'bwa', 'bfa', 'bdi', 'cpv', 'cmr', 'caf', 'tcd',
  'com', 'cog', 'cod', 'civ', 'dji', 'egy', 'gnq', 'eri', 'swz', 'eth',
  'gab', 'gmb', 'gha', 'gin', 'gnb', 'ken', 'lso', 'lbr', 'lby', 'mdg',
  'mwi', 'mli', 'mrt', 'mus', 'mar', 'moz', 'nam', 'ner', 'nga', 'rwa',
  'stp', 'sen', 'syc', 'sle', 'som', 'zaf', 'ssd', 'sdn', 'tza', 'tgo',
  'tun', 'uga', 'zmb', 'zwe', 'esh',
];

/** « Union européenne » : les 27 États membres. Définitionnel, comme ci-dessus. */
export const EU_COUNTRY_CODES: readonly string[] = [
  'aut', 'bel', 'bgr', 'hrv', 'cyp', 'cze', 'dnk', 'est', 'fin', 'fra',
  'deu', 'grc', 'hun', 'irl', 'ita', 'lva', 'ltu', 'lux', 'mlt', 'nld',
  'pol', 'prt', 'rou', 'svk', 'svn', 'esp', 'swe',
];

// ── Brouillons, fiche par fiche ─────────────────────────────────────────────

export const STRUCTURED_ELIGIBILITY_V1: Readonly<Record<string, EligibilityDraft>> = {
  // L0 âge à l'inscription (date non publiée) · L2 citoyen ET résident permanent.
  uwc_burkina_faso_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      age('age-16-18', 0, { min: 16, max: 18, maxInclusive: true, asOf: UNSPECIFIED }),
      condition('classe-seconde-terminale', 1),
      nationality('citoyen-et-resident-bf', 2, 'include', ['bfa'], 'nationality_and_residence'),
      note('dossier-scolaire', 3),
      note('valeurs-uwc', 4),
      // « Basic User » du CECRL = A1-A2 : la base demandée, sans plus.
      language('anglais-base', 5, { lang: 'en', minCefr: 'a1', waivable: false }),
      note('une-candidature-par-an', 6),
    ],
  },
  // L0 : la seule fiche UWC qui date ses bornes (année d'entrée 2027,
  // 19 ans APRÈS le 1er septembre 2027). L1 : citoyen OU résident, double
  // nationalité comprise.
  uwc_kenya_entry_2027: {
    fieldsScope: 'unknown',
    criteria: [
      age('age-16-annee-entree', 0, { min: 16, maxInclusive: true, asOf: on('2027-12-31') }),
      age('age-19-apres-1er-septembre', 0, { max: 19, maxInclusive: false, asOf: on('2027-09-01') }),
      nationality('citoyen-ou-resident-ke', 1, 'include', ['ken'], 'nationality_or_residence'),
      condition('residents-scolarises-au-kenya', 2),
      note('candidats-hors-kenya-voie-unique', 3),
      condition('niveau-scolaire-decembre-2026', 4),
      note('valeurs-uwc', 5),
      language('anglais-base', 6, { lang: 'en', minCefr: 'a1', waivable: false }),
      note('une-candidature-par-an', 7),
    ],
  },
  // L2 : citoyen OU résident permanent (la résidence du profil n'est pas
  // « permanente » : l'écart joue dans le sens de l'inclusion).
  uwc_tanzania_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      age('age-16-18', 0, { min: 16, max: 18, maxInclusive: true, asOf: UNSPECIFIED }),
      condition('form-four-igcse-myp', 1),
      nationality('citoyen-ou-resident-tz', 2, 'include', ['tza'], 'nationality_or_residence'),
      condition('presence-dar-es-salaam', 3),
      note('dossier-scolaire', 4),
      note('valeurs-uwc', 5),
      language('anglais-base', 6, { lang: 'en', minCefr: 'a1', waivable: false }),
      note('une-candidature-par-an', 7),
    ],
  },
  // L0 exclut tout citoyen turc (binational compris : « ne pas être citoyen
  // turc »). L1 en pourcentage : souple, sans conversion. L2 : âge par niveau,
  // sans date de référence.
  turkiye_scholarships_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('pas-citoyen-turc', 0, 'exclude', ['tur']),
      grade('moyenne-70-75-90', 1),
      age('age-licence-moins-21', 2, { level: 'bachelor', max: 21, maxInclusive: false, asOf: UNSPECIFIED }),
      age('age-master-moins-30', 2, { level: 'master', max: 30, maxInclusive: false, asOf: UNSPECIFIED }),
      condition('diplome-avant-aout-2027', 3),
      condition('pas-deja-inscrit-en-turquie', 4),
    ],
  },
  // L0 renvoie à la liste des pays membres de la BID, que la fiche ne
  // reproduit pas. L1 renvoie aux critères Türkiye sans les chiffrer : non
  // structuré ici (voir la fiche Türkiye).
  turkiye_isdb_joint_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('pays-membre-bid', 0),
      condition('criteres-age-et-academiques-turkiye', 1),
      condition('diplome-avant-aout-2027', 2),
      nationality('pas-citoyen-turc', 3, 'exclude', ['tur']),
      condition('pas-deja-inscrit-en-turquie', 3),
    ],
  },
  stipendium_hungaricum_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('partenaire-d-envoi', 0),
      note('diplome-requis-par-niveau', 1),
      condition('exigences-etablissement', 2),
      note('nomination-partenaire', 3),
      condition('examen-entree-56-sur-100', 4),
    ],
  },
  // L0 « hors Union européenne » : la règle « n'importe laquelle » exclurait
  // un binational dont l'une des nationalités est européenne, ce que le texte
  // ne tranche pas — souple. L1 « 7/10 » = 14/20.
  romania_mfa_scholarship_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('hors-union-europeenne', 0, 'exclude', [...EU_COUNTRY_CODES], 'nationality', 'soft'),
      condition('categories-exclues', 0),
      grade('moyenne-7-sur-10', 1, { minOn20: 14 }),
      note('documents-reconnus', 2),
      condition('hors-medecine-dentaire-pharmacie', 3),
      condition('cursus-en-roumain', 4),
    ],
  },
  // L1 : seule la citoyenneté est structurée ; « résident permanent » ne se
  // confond pas avec la résidence du profil. L2 : au 1er juillet de l'année
  // de rentrée 2027 (cycle 2027-2028).
  brunei_government_scholarship_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('premiere-candidature-au-brunei', 0),
      nationality('pas-citoyen-brunei', 1, 'exclude', ['brn']),
      age('age-licence-25-au-plus', 2, { level: 'bachelor', max: 25, maxInclusive: true, asOf: on('2027-07-01') }),
      age('age-master-35-au-plus', 2, { level: 'master', max: 35, maxInclusive: true, asOf: on('2027-07-01') }),
      // TOEFL 550 est un score papier, hors de l'échelle iBT : seul l'IELTS est
      // structuré ; les autres preuves rendent l'exigence contournable.
      language('anglais-ielts-6', 3, { lang: 'en', tests: [{ type: 'ielts', min: 6 }], waivable: true }),
      note('conditions-cursus', 4),
    ],
  },
  // L3 : seuils de langue du Master seulement, et au choix entre cinq langues
  // (DELF B2 compris) — non structurable en un critère de langue.
  kazakhstan_foreign_students_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('pas-citoyen-kazakh', 0, 'exclude', ['kaz']),
      grade('licence-secondaire-bon', 1),
      grade('master-moyenne-3-sur-4', 2),
      condition('master-seuil-linguistique', 3),
      condition('premiere-fois-a-ce-niveau', 4),
    ],
  },
  // L0 renvoie à des listes (OCI, Non-alignés, PEID…) que la fiche ne
  // reproduit pas. L2 : 15 septembre de la rentrée 2027. L3 : 7/10 = 14/20.
  heydar_aliyev_grant_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('pays-oci-non-alignes-peid', 0),
      nationality('pas-citoyen-azerbaidjan', 1, 'exclude', ['aze']),
      age('age-licence-moins-35', 2, { level: 'bachelor', max: 35, maxInclusive: false, asOf: on('2027-09-15') }),
      age('age-master-moins-40', 2, { level: 'master', max: 40, maxInclusive: false, asOf: on('2027-09-15') }),
      grade('moyenne-70-sur-100', 3, { minOn20: 14 }),
      condition('seuils-de-langue', 4),
    ],
  },
  // L0 et L1 renvoient à la liste officielle et aux « alliés diplomatiques »,
  // que la fiche ne reproduit pas : ces règles restent « à vérifier », citées.
  taiwan_icdf_2027: {
    fieldsScope: 'unknown',
    criteria: [
      condition('pays-liste-officielle', 0),
      condition('licence-allies-diplomatiques', 1),
      nationality('pas-ressortissant-taiwanais', 2, 'exclude', ['twn']),
      note('conditions-universite-visa', 3),
      condition('pas-d-autre-bourse-taiwanaise', 4),
      condition('jamais-de-bourse-retiree', 5),
    ],
  },
  // L1 et L2 : âge par niveau, à la date publiée du 20 août 2026.
  open_doors_russia_2027: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('etranger-ou-apatride', 0, 'exclude', ['rus']),
      age('age-licence-16-23', 1, { level: 'bachelor', min: 16, max: 23, maxInclusive: true, asOf: on('2026-08-20') }),
      age('age-master-20-33', 2, { level: 'master', min: 20, max: 33, maxInclusive: true, asOf: on('2026-08-20') }),
      condition('pas-de-diplome-du-niveau', 3),
      condition('russe-ou-anglais', 4),
    ],
  },
  // L2 en pourcentage : souple, sans conversion.
  qatar_university_international_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('premiere-licence-candidat-externe', 0),
      note('certificat-fin-secondaire', 1),
      grade('moyenne-95', 2),
      note('admission-finale', 3),
      condition('pas-de-cumul', 4),
      condition('pas-transfert-ni-seconde-licence', 5),
      note('maintien-moyenne-ensuite', 6),
    ],
  },
  // L1 : le statut international écarte tout citoyen canadien (binational
  // compris). Le cas du résident permanent reste dans la citation.
  york_pise_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('lyceen-entrant-premiere-annee', 0),
      nationality('statut-international', 1, 'exclude', ['can']),
      grade('moyenne-80', 2),
      note('profil-recherche', 3),
      condition('nomination-du-lycee', 4),
      note('deux-nominations-par-lycee', 5),
      note('numero-de-reference-york', 6),
    ],
  },
  uoft_lester_b_pearson_2027: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('non-canadien', 0, 'exclude', ['can']),
      condition('derniere-annee-ou-diplome-juin-2026', 1),
      note('rentree-septembre-2027', 2),
      condition('pas-deja-dans-le-postsecondaire', 3),
      condition('nomination-du-lycee', 4),
      note('profil-recherche', 5),
      note('premiere-entree-licence', 6),
    ],
  },
  // L0 renvoie à la liste des pays Chevening et APD. L3 : 2 ans
  // (2 800 heures). L5 : citoyenneté et résidence britanniques structurées,
  // les autres exclusions restent citées.
  chevening_2027: {
    fieldsScope: 'unknown',
    criteria: [
      condition('pays-chevening-et-apd', 0),
      condition('retour-deux-ans', 1),
      condition('licence-deux-ans-avant', 2),
      experience('experience-deux-ans', 3, 24),
      condition('trois-cursus-offre-inconditionnelle', 4),
      nationality('pas-citoyen-britannique', 5, 'exclude', ['gbr']),
      nationality('pas-resident-royaume-uni', 5, 'exclude', ['gbr'], 'residence'),
      condition('autres-exclusions', 5),
    ],
  },
  // L0 à L2 sont des alternatives (diplôme récent OU âge) : aucune ne peut
  // exclure seule.
  mccall_macbain_2027: {
    fieldsScope: 'unknown',
    criteria: [
      condition('premier-diplome-avant-aout-2027', 0),
      condition('ou-diplome-depuis-janvier-2021', 1),
      condition('ou-30-ans-au-1er-janvier-2026', 2),
      note('exigences-programme-mcgill', 3),
      note('profil-recherche', 4),
    ],
  },
  schwarzman_scholars_2027: {
    fieldsScope: 'unknown',
    criteria: [
      age('age-18-moins-29', 0, { min: 18, max: 29, maxInclusive: false, asOf: on('2027-08-01') }),
      condition('premier-diplome-avant-aout-2027', 1),
      condition('preuve-d-anglais', 2),
      note('dossier-en-anglais', 3),
      note('profil-recherche', 4),
    ],
  },
  // L0 : la liste des 34 pays n'est pas reproduite (seuls le Sénégal et le
  // Maroc sont cités) — une liste incomplète exclurait à tort. L3 : « de
  // nombreux pays », pas tous — souple.
  si_global_professionals_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('pays-eligibles-si', 0),
      note('master-admissible-si', 1),
      note('frais-et-admission', 2),
      condition('experience-3000-heures', 3),
      condition('experience-de-leadership', 4),
      condition('exclusions-publiees', 5),
    ],
  },
  // L2 : domaines exigés, d'où `listed` (sans identifiants de domaine sur la
  // fiche : le moteur n'en déduit rien de plus).
  daad_helmut_schmidt_2027: {
    fieldsScope: 'listed',
    criteria: [
      condition('pays-en-developpement', 0),
      grade('tiers-superieur', 1),
      condition('domaines-exiges', 2),
      condition('experience-pratique', 3),
      condition('diplome-depuis-2020', 4),
      condition('pas-plus-de-15-mois-hors-cad', 5),
      note('second-master-argumente', 6),
      note('criteres-du-master', 7),
    ],
  },
  // L0 renvoie à la liste des 25 pays. L2 : « année de rentrée de référence »
  // ambiguë pour un cycle 2028 — date non structurée. L4 : 5 ans = 60 mois.
  australia_awards_africa_2028_forecast: {
    fieldsScope: 'listed',
    criteria: [
      condition('pays-listes-residence', 0),
      condition('domaine-prioritaire', 1),
      age('age-25-au-moins', 2, { min: 25, maxInclusive: true, asOf: UNSPECIFIED }),
      note('licence-equivalente', 3),
      experience('experience-cinq-ans', 4, 60),
      condition('employe-a-la-candidature', 5),
      condition('pas-de-master-ni-award', 6),
      language('anglais-ielts-toefl', 7, {
        lang: 'en',
        tests: [
          { type: 'ielts', min: 6.5 },
          { type: 'toefl_ibt', min: 84 },
        ],
        waivable: true,
      }),
    ],
  },
  // L0 : les binationaux britanniques SONT éligibles, ce que la règle
  // « n'importe laquelle » d'une exclusion ne sait pas dire — souple.
  gates_cambridge_2027: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('hors-royaume-uni', 0, 'exclude', ['gbr'], 'nationality', 'soft'),
      condition('formations-admissibles', 1),
      note('capacite-intellectuelle', 2),
      note('engagement-et-leadership', 3),
      note('admission-et-anglais', 4),
      condition('pas-de-formation-deja-commencee', 5),
    ],
  },
  // L0 : « de nationalité africaine », condition explicite. L4 : base en
  // informatique ou ingénierie, d'où `listed`. L5 : niveau « recommandé ».
  cmu_africa_mastercard_2027: {
    fieldsScope: 'listed',
    criteria: [
      nationality('nationalite-africaine', 0, 'include', [...AFRICAN_COUNTRY_CODES]),
      note('admission-prealable', 1),
      need('besoin-financier', 2),
      note('profil-recherche', 3),
      condition('licence-informatique-ingenierie', 4),
      language('anglais-recommande', 5, {
        lang: 'en',
        tests: [
          { type: 'toefl_ibt', min: 81 },
          { type: 'ielts', min: 6.5 },
          { type: 'duolingo', min: 120 },
        ],
        waivable: true,
      }),
    ],
  },
  // L5 : nationalité, âge, domaine non restreints, d'où `all`.
  knight_hennessy_2027: {
    fieldsScope: 'all',
    criteria: [
      note('admission-stanford', 0),
      condition('licence-depuis-janvier-2020', 1),
      note('service-militaire-janvier-2018', 2),
      condition('cursus-exclus', 3),
      note('profil-recherche', 4),
      note('pas-d-autre-restriction', 5),
    ],
  },
  // L0 : citoyen OU résident permanent des six pays (réfugiés en Afrique du
  // Sud couverts par la résidence). L2 : 19-24 ans au 1er octobre 2027, MAIS
  // des « voies d'âge particulières » existent — souple.
  rhodes_southern_africa_2027: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('citoyen-ou-resident-afrique-australe', 0, 'include', ['zaf', 'bwa', 'lso', 'mwi', 'nam', 'swz'], 'nationality_or_residence'),
      condition('cinq-ans-sur-dix-dans-la-region', 1),
      age('age-19-24-voies-particulieres', 2, { min: 19, max: 24, maxInclusive: true, asOf: on('2027-10-01') }, 'soft'),
      condition('licence-avant-juillet-2027', 3),
      grade('first-class-idealement', 4, { impact: 'informational' }),
      condition('anglais-oxford', 5),
      note('profil-recherche', 6),
    ],
  },
  eth_zurich_esop_2027: {
    fieldsScope: 'unknown',
    criteria: [
      note('master-regulier', 0),
      grade('top-10-pour-cent', 1),
      condition('pas-deja-inscrit-en-master-eth', 2),
      condition('pas-de-master-deja', 3),
      note('premiere-fenetre', 4),
      note('entretien-en-fevrier', 5),
    ],
  },
  // L0 et L1 renvoient à des listes (pays en développement membres, pays
  // développés) que la fiche ne reproduit qu'en partie. L4 : trois ans, avec
  // une prise en compte particulière des pays fragiles — souple.
  jj_wbgsp_2027_forecast: {
    fieldsScope: 'unknown',
    criteria: [
      condition('pays-en-developpement-liste-2027', 0),
      condition('pas-de-double-nationalite-pays-developpe', 1),
      condition('bonne-sante', 2),
      condition('licence-trois-ans-avant', 3),
      experience('experience-trois-ans', 4, 36, 'soft'),
      condition('emploi-temps-plein-developpement', 4),
      condition('admission-hors-pays', 5),
      condition('pas-lie-a-la-banque-mondiale', 6),
    ],
  },
  ashesi_scholarship_2027: {
    fieldsScope: 'unknown',
    criteria: [
      note('admission-need-blind', 0),
      need('besoin-financier', 1),
      note('pas-de-bourse-au-merite', 2),
      grade('examens-wassce-ou-equivalent', 3),
      condition('anglais-et-traductions', 4),
      note('tour-normal', 5),
    ],
  },
  // L4 : âge publié à 23 OU 26 ans selon la page, pour les seules bourses
  // complètes — la fiche demande de vérifier, donc non structuré en âge.
  alu_scholarship_2027: {
    fieldsScope: 'unknown',
    criteria: [
      note('admission-alu', 0),
      need('ne-peut-pas-financer', 1),
      need('besoin-et-desavantage', 2),
      grade('bourse-complete-examens-b', 3),
      condition('bourse-complete-age-23-ou-26', 4),
      note('leadership-et-communaute', 5),
    ],
  },
  auc_excellence_2027: {
    fieldsScope: 'unknown',
    criteria: [
      note('case-bourse', 0),
      grade('meilleurs-resultats-du-certificat', 1),
      note('categorie-diversite-internationale', 2),
      need('merite-et-besoin', 3),
      condition('transfert-moins-de-60-credits', 4),
      condition('anglais-academique', 5),
    ],
  },
  // L0 : binationaux français explicitement exclus. L1 : « 29 ans au plus »
  // sans date de référence. L2 : sept domaines prioritaires, d'où `listed`.
  eiffel_excellence_master_2027: {
    fieldsScope: 'listed',
    criteria: [
      nationality('pas-de-nationalite-francaise', 0, 'exclude', ['fra']),
      age('age-29-au-plus', 1, { max: 29, maxInclusive: true, asOf: UNSPECIFIED }),
      condition('domaines-prioritaires', 2),
      note('formation-accreditee', 3),
      condition('pas-deja-en-france', 4),
      condition('presente-par-un-etablissement', 5),
    ],
  },
  // L0 renvoie à la liste CAD. L1 : deux ans à la date de candidature.
  daad_epos_2027: {
    fieldsScope: 'unknown',
    criteria: [
      condition('pays-liste-cad', 0),
      experience('experience-deux-ans', 1, 24),
      grade('tiers-superieur', 2),
      condition('diplome-de-six-ans-au-plus', 3),
      condition('pas-plus-de-15-mois-en-allemagne', 4),
      condition('langue-du-cursus', 5),
    ],
  },
  erasmus_mundus_joint_masters_2027: {
    fieldsScope: 'unknown',
    criteria: [
      note('premier-diplome', 0),
      note('derniere-annee-acceptee', 1),
      note('sans-condition-de-nationalite', 2),
      condition('pas-de-bourse-erasmus-mundus-anterieure', 3),
      note('criteres-du-consortium', 4),
      condition('master-encore-finance', 5),
    ],
  },
  // L0 : « cible EN PRIORITÉ les jeunes Africains » — souple. L1 : âge par
  // niveau « au moment de la candidature », sans date publiée.
  mastercard_foundation_scholars_2027: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('jeunes-africains-en-priorite', 0, 'include', [...AFRICAN_COUNTRY_CODES], 'nationality', 'soft'),
      age('age-licence-29-au-plus', 1, { level: 'bachelor', max: 29, maxInclusive: true, asOf: UNSPECIFIED }),
      age('age-master-35-au-plus', 1, { level: 'master', max: 35, maxInclusive: true, asOf: UNSPECIFIED }),
      note('pas-de-doctorat', 2),
      need('ressources-insuffisantes', 3),
      note('publics-prioritaires', 4),
      condition('criteres-du-partenaire', 5),
    ],
  },
  // L0 : « étudiant international » — binationaux sud-africains non tranchés,
  // souple. L5 : exclusions (années d'études, emploi > 20 h).
  uct_international_refugee_2027: {
    fieldsScope: 'unknown',
    criteria: [
      nationality('etudiant-international', 0, 'exclude', ['zaf'], 'nationality', 'soft'),
      note('admission-temps-plein', 1),
      note('preference-candidats-avances', 2),
      note('preuve-statut-refugie', 3),
      condition('moyens-de-financement-complementaires', 4),
      condition('exclusions-publiees', 5),
    ],
  },
  // L2 : « jeune Africain » sans autre précision — souple. L5 : facultés
  // limitées en postgrade seulement — le domaine reste `unknown`.
  up_mastercard_scholars_2027: {
    fieldsScope: 'unknown',
    criteria: [
      note('admis-a-temps-plein', 0),
      note('niveaux-ouverts', 1),
      nationality('jeune-africain', 2, 'include', [...AFRICAN_COUNTRY_CODES], 'nationality', 'soft'),
      need('ne-peut-pas-payer', 3),
      note('leadership-et-service', 4),
      condition('postgrade-facultes-limitees', 5),
    ],
  },
};

/** La source officielle « eligibility » de la fiche, celle que citent ses critères. */
function eligibilitySourceUrl(record: VerifiedScholarshipCatalogRecord): string {
  return (
    record.officialSources.find((source) => source.kind === 'eligibility')?.url ??
    record.scholarship.sourceUrl
  );
}

/**
 * Résout un brouillon contre SA fiche : la citation est la ligne
 * d'éligibilité désignée, la source est la source officielle « eligibility ».
 * Une ligne hors limites donne une citation vide, que le validateur refuse.
 */
export function resolveEligibilityDraft(
  record: VerifiedScholarshipCatalogRecord,
  draft: EligibilityDraft,
): NonNullable<VerifiedScholarshipCatalogRecord['eligibility']> {
  const sourceUrl = eligibilitySourceUrl(record);
  const criteria = draft.criteria.map(({ line, ...rest }) => {
    const officialTextFr = record.scholarship.eligibilityFr[line] ?? '';
    const officialTextEn = record.scholarship.eligibilityEn[line] ?? '';
    const quoted = { ...rest, officialTextFr, officialTextEn, sourceUrl };
    if (quoted.type === 'academic_grade' && !quoted.rawText) {
      return { ...quoted, rawText: officialTextFr } as EligibilityCriterion;
    }
    return quoted as EligibilityCriterion;
  });
  return {
    fieldsScope: draft.fieldsScope,
    criteria,
    structuredAt: draft.reviewed?.at ?? null,
    structuredBy: draft.reviewed?.by ?? DRAFT_STRUCTURED_BY,
  };
}

/**
 * Attache à chaque fiche son éligibilité structurée. Une fiche qui porte déjà
 * un bloc le garde ; une fiche sans brouillon reste sans bloc (le validateur
 * le signale : `missing_structured_eligibility`).
 */
export function attachStructuredEligibility(
  records: readonly VerifiedScholarshipCatalogRecord[],
  drafts: Readonly<Record<string, EligibilityDraft>> = STRUCTURED_ELIGIBILITY_V1,
): VerifiedScholarshipCatalogRecord[] {
  return records.map((record) => {
    const draft = drafts[record.scholarship.id];
    if (record.eligibility || !draft) return record;
    return { ...record, eligibility: resolveEligibilityDraft(record, draft) };
  });
}
