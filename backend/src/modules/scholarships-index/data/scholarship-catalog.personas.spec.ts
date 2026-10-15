import { publicScholarshipWhere } from '../../../common/public-scholarship-where';
import type { MatchScholarship } from '../../scholarship-match/assess';
import type { MatchProfile } from '../../scholarship-match/match-inputs';
import { matchScholarships } from '../../scholarship-match/rank';
import { buildScholarshipCreateData } from './scholarship-catalog.create-data';
import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';
import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';

/**
 * Instantanés dorés : le moteur « Mes 10 bourses » sur le VRAI catalogue
 * 1.5.0, à une horloge FIXE (13/10/2026), pour les personas de la
 * spécification du chantier D.
 *
 * ## Revue éditoriale obligatoire quand un instantané change
 *
 * Ces attentes sont écrites à la main et relues : elles disent ce qu'un élève
 * réel verra. Un changement du catalogue ou du moteur qui les fait tomber doit
 * être RELU (la nouvelle liste est-elle juste pour cet élève ?), jamais
 * recopié depuis la sortie du test.
 *
 * ## Classement : la certitude ne compte que ce qui tient au profil
 *
 * Depuis le réglage de `rank.ts` (`PROFILE_DEPENDENT_TO_VERIFY`), seuls les
 * points « à vérifier » qui tiennent à l'élève (réponse manquante, valeur à la
 * limite, règle non excluante qu'il ne remplit pas) entament la composante
 * « certitude ». Les conditions que le test ne pose pas (`condition_other`),
 * les exigences de notes non chiffrées (`grade_check`) et l'état de la fiche
 * ne classent plus : une fiche que KPB a détaillée en quatre conditions
 * « autres » ne passe plus derrière une fiche moins pertinente transcrite en
 * une seule. Entre fiches de même pertinence, la clôture la plus proche passe
 * devant. Les statuts, les exclusions et les comptes sont inchangés.
 *
 * ## Deux hypothèses de décor, explicites
 *
 * 1. Les critères sont considérés TAMPONNÉS (relus il y a 30 jours). Dans le
 *    dépôt ce sont des brouillons (`structuredAt: null`) : sans cette
 *    hypothèse tout serait « à vérifier » et le test ne prouverait rien des
 *    règles. Le dernier bloc vérifie justement ce que donnent les brouillons
 *    tels quels : aucune exclusion.
 * 2. Toutes les fiches sont supposées publiées (approuvées, vérifiées) ; la
 *    clause de date de `publicScholarshipWhere` est appliquée telle quelle, ce
 *    qui écarte les 7 fiches closes au 13/10/2026 (Chevening, McCall MacBain,
 *    Schwarzman, DAAD Helmut-Schmidt, Knight-Hennessy, Rhodes, UP Mastercard).
 */

const NOW = new Date('2026-10-13T12:00:00.000Z');
const STAMPED_30_DAYS_AGO = new Date('2026-09-13T12:00:00.000Z');
const VERSION = SCHOLARSHIP_CATALOG_V1.catalogVersion;

/** La ligne telle qu'`import` l'écrit, lue comme le ferait le moteur. */
function asCandidate(
  record: VerifiedScholarshipCatalogRecord,
  stampedAt: Date | null,
): MatchScholarship {
  const data = buildScholarshipCreateData(record, VERSION);
  const cycle = data.cycles.create;
  return {
    id: data.id,
    countryId: data.countryId,
    fundingType: data.fundingType,
    eligibleLevels: data.eligibleLevels,
    fieldsScope: data.fieldsScope,
    relatedFieldIds: data.relatedFieldIds,
    // Aller-retour JSON : ce que rend une colonne `jsonb`.
    eligibilityCriteria: JSON.parse(JSON.stringify(data.eligibilityCriteria)),
    eligibilityStructuredAt: stampedAt,
    deadlineAt: data.deadlineAt,
    cycle: {
      id: `${data.id}:${cycle.academicYear}`,
      status: cycle.status,
      dateConfidence: cycle.dateConfidence,
      opensAt: cycle.opensAt,
      closesAt: cycle.closesAt,
      estimatedOpenAt: cycle.estimatedOpenAt,
      estimatedCloseAt: cycle.estimatedCloseAt,
    },
  };
}

/** La clause de date de `publicScholarshipWhere`, appliquée en mémoire. */
function isServedAt(candidate: MatchScholarship, now: Date): boolean {
  const where = publicScholarshipWhere(now);
  const gte = (where.OR as Array<{ deadlineAt: null | { gte: Date } }>)[1]
    .deadlineAt as { gte: Date };
  return candidate.deadlineAt === null || candidate.deadlineAt >= gte.gte;
}

function candidates(stampedAt: Date | null = STAMPED_30_DAYS_AGO): MatchScholarship[] {
  return SCHOLARSHIP_CATALOG_V1.records
    .map((record) => asCandidate(record, stampedAt))
    .filter((candidate) => isServedAt(candidate, NOW));
}

const date = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

function persona(overrides: Partial<MatchProfile>): MatchProfile {
  return {
    nationalities: [],
    residenceCode: null,
    birthDate: null,
    guardianConsented: true,
    highestDiploma: null,
    targetLevel: null,
    fieldIds: [],
    targetCountryIds: [],
    gradeBand: '14_16',
    englishLevel: 'b1',
    frenchLevel: 'c1_c2',
    languageTests: [],
    workExperienceBand: 'none',
    confirmed: true,
    ...overrides,
  };
}

interface Snapshot {
  /** Les « jusqu'à 10 » montrées, dans l'ordre : `id statut`. */
  items: string[];
  /** Les autres candidates montrables, au-delà de 10. */
  beyondTen: string[];
  /** Fiche écartée → ses motifs (`code` ou `code:clé du critère`). */
  excluded: Record<string, string[]>;
}

function snapshot(profile: MatchProfile, pool = candidates()): Snapshot {
  const run = matchScholarships(profile, pool, NOW);
  const shown = new Set(run.items.map((item) => item.scholarshipId));
  const excluded: Record<string, string[]> = {};
  for (const entry of run.entries) {
    const { status, exclusions } = entry.assessment;
    if (status !== 'not_eligible' && status !== 'suspended') continue;
    excluded[entry.scholarship.id] = exclusions.map((exclusion) =>
      exclusion.criterionKey ? `${exclusion.code}:${exclusion.criterionKey}` : exclusion.code,
    );
  }
  return {
    items: run.items.map((item) => `${item.scholarshipId} ${item.status}`),
    beyondTen: run.entries
      .filter(
        (entry) =>
          (entry.assessment.status === 'eligible' || entry.assessment.status === 'to_verify') &&
          !shown.has(entry.scholarship.id),
      )
      .map((entry) => entry.scholarship.id)
      .sort(),
    excluded,
  };
}

describe('personas — catalogue 1.5.0 au 13/10/2026 (critères tamponnés pour le test)', () => {
  it('sert 29 fiches : les 7 campagnes closes sont absentes par construction', () => {
    const served = candidates().map((candidate) => candidate.id);
    expect(served).toHaveLength(29);
    for (const closed of [
      'chevening_2027',
      'mccall_macbain_2027',
      'schwarzman_scholars_2027',
      'daad_helmut_schmidt_2027',
      'knight_hennessy_2027',
      'rhodes_southern_africa_2027',
      'up_mastercard_scholars_2027',
    ]) {
      expect(served).not.toContain(closed);
    }
  });

  it('Burkinabè, 16 ans, lycée, résidant au Burkina Faso', () => {
    const result = snapshot(
      persona({
        nationalities: ['bfa'],
        residenceCode: 'bfa',
        birthDate: date('2010-03-01'),
        highestDiploma: 'none',
        targetLevel: 'secondary',
        englishLevel: 'a1_a2',
      }),
    );

    // UWC Burkina Faso incluse — « à vérifier » : 16 ans au 13/10/2026, la
    // borne de 16 ans « à l'inscription » n'a pas de date publiée (marge de
    // 12 mois), et la classe (Seconde à Terminale) reste à confirmer.
    // Mastercard Foundation : « à vérifier » (critères du partenaire).
    expect(result.items).toEqual([
      'mastercard_foundation_scholars_2027 to_verify',
      'uwc_burkina_faso_2027_forecast to_verify',
    ]);
    expect(result.beyondTen).toEqual([]);
    // UWC Kenya et UWC Tanzanie : citoyen OU résident du pays — ni l'un ni
    // l'autre pour cet élève.
    expect(result.excluded.uwc_kenya_entry_2027).toEqual([
      'nationality_not_listed:citoyen-ou-resident-ke',
    ]);
    expect(result.excluded.uwc_tanzania_2027_forecast).toEqual([
      'nationality_not_listed:citoyen-ou-resident-tz',
    ]);
    // Tout le reste vise un autre niveau ; UCT est suspendue.
    expect(result.excluded.uct_international_refugee_2027).toEqual(['suspended']);
    expect(Object.keys(result.excluded)).toHaveLength(27);
  });

  it('Nigérien, 18 ans, vise une Licence, anglais B1', () => {
    const result = snapshot(
      persona({
        nationalities: ['ner'],
        residenceCode: 'ner',
        birthDate: date('2008-02-15'),
        highestDiploma: 'bac',
        targetLevel: 'bachelor',
        gradeBand: '12_14',
      }),
    );

    expect(result.items).toEqual([
      // Pearson : financement complet, campagne ouverte aux dates confirmées.
      'uoft_lester_b_pearson_2027 to_verify',
      // Türkiye : moins de 21 ans en Licence (18 ans, marge comprise) et pas
      // turc ; la moyenne de 70 % reste souple → « à vérifier ». Ses conditions
      // non chiffrées ne la font plus reculer (5e → 2e).
      'turkiye_scholarships_2027_forecast to_verify',
      // Taiwan ICDF : la règle « alliés diplomatiques » de la Licence est
      // citée et reste « à vérifier » — la fiche ne reproduit pas la liste.
      // Quatre conditions « autres » la reléguaient au 8e rang (→ 3e).
      'taiwan_icdf_2027 to_verify',
      'qatar_university_international_2027_forecast to_verify',
      // Mastercard Foundation : complète mais prévision à clôture lointaine ;
      // elle ne tirait sa 1re place que de sa fiche peu détaillée (→ 5e).
      'mastercard_foundation_scholars_2027 to_verify',
      'open_doors_russia_2027 to_verify',
      'auc_excellence_2027 to_verify',
      // Brunei : un score IELTS demandé et non indiqué — incertitude qui tient
      // à l'élève, elle compte toujours (3e → 8e).
      'brunei_government_scholarship_2027_forecast to_verify',
      // Heydar Aliyev : 70/100 demandés, tranche 12-14 sur 20 en dessous —
      // tient à l'élève aussi (6e → 9e).
      'heydar_aliyev_grant_2027_forecast to_verify',
      // Six fiches partielles ex æquo : la clôture la plus proche (15/01/2027)
      // passe devant ; ALU (18/06/2027) sort des 10.
      'stipendium_hungaricum_2027_forecast to_verify',
    ]);
    expect(result.beyondTen).toEqual([
      'alu_scholarship_2027',
      'ashesi_scholarship_2027',
      'kazakhstan_foreign_students_2027_forecast',
      'romania_mfa_scholarship_2027_forecast',
      'turkiye_isdb_joint_2027_forecast',
      'york_pise_2027_forecast',
    ]);
    expect(result.excluded.uwc_kenya_entry_2027).toEqual([
      'level_other',
      'age_too_old:age-19-apres-1er-septembre',
      'nationality_not_listed:citoyen-ou-resident-ke',
    ]);
    expect(Object.keys(result.excluded).sort()).toEqual([
      'australia_awards_africa_2028_forecast',
      'cmu_africa_mastercard_2027',
      'daad_epos_2027',
      'eiffel_excellence_master_2027',
      'erasmus_mundus_joint_masters_2027',
      'eth_zurich_esop_2027',
      'gates_cambridge_2027',
      'jj_wbgsp_2027_forecast',
      'si_global_professionals_2027_forecast',
      'uct_international_refugee_2027',
      'uwc_burkina_faso_2027_forecast',
      'uwc_kenya_entry_2027',
      'uwc_tanzania_2027_forecast',
    ]);
  });

  it('Sénégalais, 26 ans, Licence, 24 à 36 mois d’expérience, vise un Master', () => {
    const result = snapshot(
      persona({
        nationalities: ['sen'],
        residenceCode: 'sen',
        birthDate: date('2000-04-20'),
        highestDiploma: 'licence',
        targetLevel: 'master',
        englishLevel: 'b2',
        workExperienceBand: '24_36',
      }),
    );

    expect(result.items).toEqual([
      // Gates et CMU-Africa : complètes, campagnes ouvertes aux dates confirmées.
      'gates_cambridge_2027 to_verify',
      'cmu_africa_mastercard_2027 to_verify',
      // Puis les complètes en prévision, sans incertitude propre à l'élève,
      // par clôture la plus proche : ETH (30/11/2026) …
      'eth_zurich_esop_2027 to_verify',
      // Deux ans d'expérience demandés : la tranche 24-36 mois suffit.
      'daad_epos_2027 to_verify',
      'erasmus_mundus_joint_masters_2027 to_verify',
      'turkiye_scholarships_2027_forecast to_verify',
      // SI Global Professionals ENTRE dans les 10 (au-delà avant) : ses quatre
      // conditions que le test ne pose pas (liste des 34 pays, 3 000 heures,
      // leadership, exclusions) restent affichées « à vérifier » mais ne la
      // classent plus derrière des fiches partielles.
      'si_global_professionals_2027_forecast to_verify',
      // Taiwan ICDF entre aussi, pour la même raison (liste de pays non
      // reproduite) ; la condition reste à vérifier sur la page officielle.
      'taiwan_icdf_2027 to_verify',
      'heydar_aliyev_grant_2027_forecast to_verify',
      // … jusqu'à Mastercard Foundation (30/06/2027), 3e avant.
      'mastercard_foundation_scholars_2027 to_verify',
    ]);
    // Sortent des 10 : Open Doors (financement partiel, 7e avant) et Brunei
    // (score IELTS demandé, non indiqué : une incertitude qui tient à l'élève).
    // JJ/WBG : trois ans d'expérience pour une tranche 24-36 mois, à la limite.
    expect(result.beyondTen).toEqual([
      'brunei_government_scholarship_2027_forecast',
      'eiffel_excellence_master_2027',
      'jj_wbgsp_2027_forecast',
      'kazakhstan_foreign_students_2027_forecast',
      'open_doors_russia_2027',
      'romania_mfa_scholarship_2027_forecast',
      'stipendium_hungaricum_2027_forecast',
      'turkiye_isdb_joint_2027_forecast',
    ]);
    // Australia Awards : cinq ans d'expérience exigés, 36 mois au plus ici.
    expect(result.excluded.australia_awards_africa_2028_forecast).toEqual([
      'experience_insufficient:experience-cinq-ans',
    ]);
    // Chevening ABSENTE (clôture du 06/10/2026), pas « exclue ».
    expect(result.excluded).not.toHaveProperty('chevening_2027');
    expect(Object.keys(result.excluded)).toHaveLength(11);
  });

  it('Camerounais, 31 ans, vise un Master', () => {
    const result = snapshot(
      persona({
        nationalities: ['cmr'],
        residenceCode: 'cmr',
        birthDate: date('1995-05-15'),
        highestDiploma: 'licence',
        targetLevel: 'master',
        englishLevel: 'b2',
        workExperienceBand: '36_60',
      }),
    );

    expect(result.items).toEqual([
      'gates_cambridge_2027 to_verify',
      'cmu_africa_mastercard_2027 to_verify',
      // Mêmes déplacements que pour le Sénégalais (complètes en prévision, par
      // clôture), plus JJ/WBG : 36-60 mois couvrent les trois ans demandés,
      // ses huit conditions « autres » ne la relèguent plus.
      'eth_zurich_esop_2027 to_verify',
      'daad_epos_2027 to_verify',
      'erasmus_mundus_joint_masters_2027 to_verify',
      'si_global_professionals_2027_forecast to_verify',
      'jj_wbgsp_2027_forecast to_verify',
      'taiwan_icdf_2027 to_verify',
      'heydar_aliyev_grant_2027_forecast to_verify',
      'mastercard_foundation_scholars_2027 to_verify',
    ]);
    // Open Doors (partielle) et Brunei (score IELTS non indiqué) passent
    // au-delà des 10.
    expect(result.beyondTen).toEqual(
      expect.arrayContaining(['brunei_government_scholarship_2027_forecast', 'open_doors_russia_2027']),
    );
    // Eiffel (« 29 ans au plus ») et Türkiye (« moins de 30 ans » en Master) :
    // 30 ans déjà un an avant la clôture, la marge ne change rien.
    expect(result.excluded.eiffel_excellence_master_2027).toEqual([
      'age_too_old:age-29-au-plus',
    ]);
    expect(result.excluded.turkiye_scholarships_2027_forecast).toEqual([
      'age_too_old:age-master-moins-30',
    ]);
    // Schwarzman ABSENTE (campagne close le 09/09/2026).
    expect(result.excluded).not.toHaveProperty('schwarzman_scholars_2027');
    // Australia Awards n'est PAS exclue : 36-60 mois chevauche les 60 exigés.
    expect(result.beyondTen).toContain('australia_awards_africa_2028_forecast');
    expect(Object.keys(result.excluded)).toHaveLength(12);
  });

  it('Cible doctorat : Gates Cambridge seule', () => {
    const result = snapshot(
      persona({
        nationalities: ['civ'],
        residenceCode: 'civ',
        birthDate: date('1999-01-10'),
        highestDiploma: 'master',
        targetLevel: 'doctorate',
        englishLevel: 'c1_c2',
        workExperienceBand: '12_24',
      }),
    );

    expect(result.items).toEqual(['gates_cambridge_2027 to_verify']);
    expect(result.beyondTen).toEqual([]);
    // UCT finance aussi le doctorat (« Honours, Master ou Doctorat »), mais
    // son cycle est suspendu : elle est écartée à ce titre, pas sur le niveau.
    expect(result.excluded.uct_international_refugee_2027).toEqual(['suspended']);
    expect(Object.keys(result.excluded)).toHaveLength(28);
  });

  it('Les brouillons tels qu’ils sont dans le dépôt n’excluent personne', () => {
    // Même élève camerounais, critères NON tamponnés (`structuredAt: null`) :
    // ni l'âge ni le niveau n'excluent. Seul le cycle suspendu écarte.
    const result = snapshot(
      persona({
        nationalities: ['cmr'],
        residenceCode: 'cmr',
        birthDate: date('1995-05-15'),
        highestDiploma: 'licence',
        targetLevel: 'master',
        workExperienceBand: '36_60',
      }),
      candidates(null),
    );

    expect(result.excluded).toEqual({ uct_international_refugee_2027: ['suspended'] });
    expect(result.items).toHaveLength(10);
    expect(result.items.every((item) => item.endsWith(' to_verify'))).toBe(true);
  });
});
