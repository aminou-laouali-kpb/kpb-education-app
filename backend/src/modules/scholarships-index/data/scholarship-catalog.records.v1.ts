import type {
  ScholarshipOfficialSource,
  VerifiedScholarshipCatalogRecord,
} from './scholarship-catalog.types';

/**
 * Date on which the three UWC national-route records below had all five of
 * their official sources re-opened and read page by page (bf.uwc.org,
 * ke.uwc.org, tz.uwc.org and apply.uwc.org). It replaces the initial
 * 2026-07-16 review wave, which the validator's 30-day ceiling retires on
 * 15 August 2026.
 *
 * `checkedAt` is passed explicitly to every source rather than defaulted, so a
 * later wave that re-reads only one committee's pages cannot silently claim a
 * fresh check for the other two.
 */
// Re-vérification aux sources officielles du 29/09/2026 : bf.uwc.org,
// ke.uwc.org et tz.uwc.org relues le même jour (instantanés datés, preuves
// citées page par page). Burkina Faso et Tanzanie inchangés ; Kenya corrigé
// (niveau CBE Grade 10, relevés de tous les semestres, Applicant Information
// Form, dépôt des pièces du 1er au 31 décembre uniquement).
// Relues de nouveau le 24/10/2026 (vague mensuelle) : les trois pages de
// chaque comité sont inchangées, aucune correction.
const CHECKED_AT_UWC_2026_10_24 = '2026-10-24T07:10:00.000Z';
const VERIFIED_BY = 'KPB Education official-source review';

function officialSource(
  kind: ScholarshipOfficialSource['kind'],
  url: string,
  label: string,
  checkedAt: string,
): ScholarshipOfficialSource {
  return {
    kind,
    url,
    isOfficial: true,
    checkedAt,
    label,
  };
}

/**
 * Records are intentionally inactive/pending after import. Source verification
 * makes them eligible for editorial review; it never publishes them.
 */
export const VERIFIED_SCHOLARSHIP_RECORDS_V1: VerifiedScholarshipCatalogRecord[] = [
  {
    catalogId: 'uwc_burkina_faso_2027_forecast',
    levels: ['secondary'],
    scholarship: {
      id: 'uwc_burkina_faso_2027_forecast',
      nameFr: 'UWC — voie nationale Burkina Faso',
      nameEn: 'UWC — Burkina Faso national route',
      countryId: 'bfa',
      countryNameFr: 'Burkina Faso (placements UWC internationaux)',
      countryNameEn: 'Burkina Faso (international UWC placements)',
      levelEligibleFr: 'Lycée — Seconde à Terminale',
      levelEligibleEn: 'Secondary school — Seconde to Terminale equivalent',
      typeOfFundingFr: 'Aide complète ou partielle selon la place et le besoin financier',
      typeOfFundingEn: 'Full or partial aid depending on placement and financial need',
      fundingType: 'partially_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr:
        'Pas encore ouvert — ouverture le 1er novembre 2026, clôture le 3 janvier 2027',
      deadlineLabelEn:
        'Not yet open — opens 1 November 2026, closes 3 January 2027',
      descriptionFr:
        'Sélection nationale pour une place dans un établissement UWC et le programme de deux ans du Baccalauréat International. Le financement attribué peut être complet ou partiel après évaluation du besoin financier. Le comité national publie désormais les dates officielles de l’entrée 2027 : dépôt du 1er novembre 2026 au 3 janvier 2027, activités de sélection en février 2027 et décisions finales en mars 2027.',
      descriptionEn:
        'National selection for a place at a UWC school and the two-year International Baccalaureate programme. Awarded funding may be full or partial after a financial-needs assessment. The national committee now publishes the official 2027-entry dates: applications from 1 November 2026 to 3 January 2027, selection activities in February 2027 and final decisions in March 2027.',
      advantagesFr: [
        'Placement dans un établissement du réseau international UWC',
        'Cursus résidentiel de deux ans préparant au Baccalauréat International',
        'Aide financière complète ou partielle possible selon le placement et le besoin démontré',
      ],
      advantagesEn: [
        'Placement at a school in the international UWC network',
        'Two-year residential International Baccalaureate curriculum',
        'Possible full or partial financial aid depending on placement and demonstrated need',
      ],
      eligibilityFr: [
        'Avoir entre 16 et 18 ans au moment de l’inscription',
        'Être scolarisé en Seconde, Première ou Terminale, ou avoir récemment achevé ce niveau',
        'Être citoyen burkinabè et résident permanent au Burkina Faso selon la page officielle de la voie nationale',
        'Présenter un bon dossier scolaire et un engagement d’apprentissage au-delà de la classe',
        'Démontrer les valeurs UWC, un impact positif dans sa communauté, de la résilience et de l’adaptabilité',
        'Avoir au moins une base en anglais et la volonté de progresser ; la maîtrise courante n’est pas exigée à la candidature',
        'Ne déposer qu’une seule candidature UWC par année académique',
      ],
      eligibilityEn: [
        'Be between 16 and 18 years old at enrolment',
        'Be enrolled in Seconde, Première or Terminale equivalent, or have recently completed that stage',
        'Be a Burkinabe citizen and permanent resident in Burkina Faso according to the official national-route page',
        'Show a strong academic record and commitment to learning beyond the classroom',
        'Demonstrate UWC values, positive community impact, resilience and adaptability',
        'Have at least basic English and willingness to improve; fluency is not required when applying',
        'Submit only one UWC application per academic year',
      ],
      keyRequirementsFr: [
        'Formulaire en ligne avec informations personnelles, parcours scolaire, activités et motivations',
        'Essais ou réponses courtes',
        'Références d’enseignants, mentors ou responsables communautaires',
        'Relevés scolaires et autres justificatifs demandés',
        'Autorisation signée du parent ou tuteur légal',
        'Informations financières demandées à tous les candidats, pour déterminer l’aide en cas de nomination',
      ],
      keyRequirementsEn: [
        'Online form with personal details, academic history, activities and motivations',
        'Essays or short responses',
        'References from teachers, mentors or community leaders',
        'Academic transcripts and other requested evidence',
        'Signed permission from a parent or legal guardian',
        'Financial information requested from all applicants, to determine aid if nominated',
      ],
      relatedFieldIds: [],
      baseMatch: 80,
      applicationUrl: 'https://apply.uwc.org/',
      sourceUrl: 'https://bf.uwc.org/',
      tags: [
        'secondary',
        'uwc',
        'ib',
        'route-burkina-faso',
        'needs-based',
        'forecast',
      ],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Vérifier la voie nationale',
        titleEn: 'Check the national route',
        descriptionFr:
          'Confirmer l’âge, le niveau scolaire, la citoyenneté/résidence et l’unicité de la candidature UWC.',
        descriptionEn:
          'Confirm age, school stage, citizenship/residency and that this is the only UWC application for the year.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 2,
        titleFr: 'Préparer le dossier',
        titleEn: 'Prepare the application',
        descriptionFr:
          'Rassembler les relevés, les références, les essais, les justificatifs et l’autorisation parentale.',
        descriptionEn:
          'Gather transcripts, references, essays, supporting evidence and parental permission.',
        estimatedDurationDays: 21,
      },
      {
        stepNumber: 3,
        titleFr: 'Déposer en ligne',
        titleEn: 'Submit online',
        descriptionFr:
          'Créer son dossier sur la plateforme UWC dès l’ouverture le 1er novembre 2026 et le soumettre au plus tard le 3 janvier 2027.',
        descriptionEn:
          'Create the application on the UWC platform once it opens on 1 November 2026 and submit it by 3 January 2027 at the latest.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 4,
        titleFr: 'Participer à la sélection',
        titleEn: 'Complete selection',
        descriptionFr:
          'Si présélectionné, participer à l’entretien de panel lors des activités de sélection de février 2027, puis attendre les décisions finales de mars 2027. Les informations financières sont demandées à tous les candidats, pour déterminer l’aide en cas de nomination.',
        descriptionEn:
          'If shortlisted, attend the panel interview during the February 2027 selection activities, then await the final decisions in March 2027. Financial information is requested from all applicants, to determine aid if nominated.',
        estimatedDurationDays: 45,
      },
    ],
    cycle: {
      academicYear: '2027-2028',
      // Statut « forecast » avec dates confirmées : le comité national publie
      // les dates exactes de l'entrée 2027, mais la fenêtre n'ouvre que le
      // 1er novembre 2026 et le site affiche « Applications are currently
      // closed » au 10 août 2026.
      status: 'forecast',
      dateConfidence: 'confirmed',
      opensAt: '2026-11-01T00:00:00.000Z',
      closesAt: '2027-01-03T23:59:59.000Z',
      sourceUrl: 'https://bf.uwc.org/how-to-apply/',
    },
    officialSources: [
      officialSource(
        'overview',
        'https://bf.uwc.org/',
        'UWC Burkina Faso — official home page',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'eligibility',
        'https://bf.uwc.org/eligibility-criteria/',
        'UWC Burkina Faso — official eligibility criteria',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'benefits',
        'https://bf.uwc.org/how-to-apply/',
        'UWC Burkina Faso — official nomination and funding description',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'application',
        'https://apply.uwc.org/',
        'UWC official application platform',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'cycle',
        'https://bf.uwc.org/how-to-apply/',
        'UWC Burkina Faso — official 2027-entry application dates (1 Nov 2026 – 3 Jan 2027)',
        CHECKED_AT_UWC_2026_10_24,
      ),
    ],
    verifiedAt: CHECKED_AT_UWC_2026_10_24,
    verifiedBy: VERIFIED_BY,
  },
  {
    catalogId: 'uwc_kenya_entry_2027',
    levels: ['secondary'],
    scholarship: {
      id: 'uwc_kenya_entry_2027',
      nameFr: 'UWC — voie nationale Kenya',
      nameEn: 'UWC — Kenya national route',
      countryId: 'ken',
      countryNameFr: 'Kenya (placements UWC internationaux)',
      countryNameEn: 'Kenya (international UWC placements)',
      levelEligibleFr: 'Fin du secondaire — entrée UWC 2027',
      levelEligibleEn: 'Final secondary stage — UWC entry 2027',
      typeOfFundingFr: 'Aide complète ou partielle selon la place et le besoin financier',
      typeOfFundingEn: 'Full or partial aid depending on placement and financial need',
      fundingType: 'partially_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr: 'Ouvert — pièces acceptées uniquement du 1er au 31 décembre 2026 (clôture le 31 décembre 2026)',
      deadlineLabelEn: 'Open — documents accepted only 1–31 December 2026 (closes 31 December 2026)',
      descriptionFr:
        'Voie de sélection du comité national UWC Kenya pour une entrée en 2027 dans un établissement UWC. Une nomination peut être entièrement ou partiellement financée selon le besoin démontré.',
      descriptionEn:
        'UWC Kenya national committee selection route for 2027 entry at a UWC school. A nomination may be fully or partially funded according to demonstrated need.',
      advantagesFr: [
        'Placement dans un établissement du réseau international UWC',
        'Cursus UWC de deux ans centré sur le Baccalauréat International',
        'Aide financière complète ou partielle possible après évaluation du besoin',
      ],
      advantagesEn: [
        'Placement at a school in the international UWC network',
        'Two-year UWC curriculum centred on the International Baccalaureate',
        'Possible full or partial financial aid following needs assessment',
      ],
      eligibilityFr: [
        'Avoir entre 16 et 19 ans durant l’année d’entrée ; toute personne ayant 19 ans en 2027 doit les avoir après le 1er septembre 2027',
        'Être citoyen ou résident du Kenya, y compris avec une double nationalité',
        'Pour les résidents au Kenya, étudier et achever actuellement le secondaire dans le pays',
        'Les candidats résidant et étudiant hors du Kenya ne peuvent postuler que via le comité national UWC Kenya, sans utiliser en parallèle un autre canal de candidature',
        'Atteindre d’ici décembre 2026 le niveau officiel correspondant à son cursus : 8-4-4 Form 4 (obtenu), CBE Grade 10 (achevé), ou cursus en cours en Cambridge IGCSE Year 11, Pearson Edexcel GCSE Year 11, American Grade 10, IB MYP 5, German Grade 10 ou équivalent homeschool',
        'Démontrer les valeurs UWC, notamment intégrité, service, respect, responsabilité, ouverture interculturelle et action personnelle',
        'Avoir une base en anglais et la volonté de progresser ; la maîtrise courante n’est pas exigée à la candidature',
        'Ne déposer qu’une seule candidature UWC par année académique',
      ],
      eligibilityEn: [
        'Be between 16 and 19 in the entry year; applicants turning 19 in 2027 must do so after 1 September 2027',
        'Hold Kenyan citizenship or residency, including dual citizenship',
        'Kenyan residents must be studying and currently completing secondary school in Kenya',
        'Applicants residing and studying outside Kenya may apply through the UWC Kenya national committee only, and not concurrently through another application channel',
        'Reach by December 2026 the published stage for the relevant curriculum: 8-4-4 Form 4 (graduated), CBE Grade 10 (completed), or ongoing Cambridge IGCSE Year 11, Pearson Edexcel GCSE Year 11, American Grade 10, IB MYP 5, German Grade 10, or homeschool equivalent',
        'Demonstrate UWC values including integrity, service, respect, responsibility, intercultural openness and personal action',
        'Have basic English and willingness to improve; fluency is not required when applying',
        'Submit only one UWC application per academic year',
      ],
      keyRequirementsFr: [
        'Relevés ou bulletins officiels sur papier à en-tête de l’établissement couvrant tous les semestres/trimestres de 2025 et 2026 jusqu’au dernier trimestre de 2026',
        'Formulaire « Applicant Information Form » d’UWC Kenya, téléchargeable sur la page How to Apply, intégré au PDF unique',
        'Deux lettres de recommandation : une co-curriculaire et une académique',
        'Certificats de réussite, leadership ou distinctions pertinents, si disponibles',
        'Un seul fichier PDF regroupant les pièces demandées',
        'Présence physique à Nairobi pour la journée de sélection en cas de présélection',
        'Frais de journée d’entretien de 3 000 KES, avec exonération possible au cas par cas',
        'Informations financières pour déterminer l’aide en cas de nomination',
      ],
      keyRequirementsEn: [
        'Official transcripts or report cards on school letterhead covering all semesters/terms of 2025 and 2026 up to the last term of 2026',
        'Completed UWC Kenya Applicant Information Form (downloadable on the How to Apply page), included in the combined PDF',
        'Two recommendation letters: one co-curricular and one academic',
        'Relevant achievement, leadership or award certificates, if available',
        'One combined PDF containing the requested documents',
        'Physical attendance in Nairobi for selection day if shortlisted',
        'KES 3,000 interview-day fee, with case-by-case fee waivers',
        'Financial information to determine aid if nominated',
      ],
      relatedFieldIds: [],
      baseMatch: 80,
      applicationUrl: 'https://ke.uwc.org/how-to-apply/',
      sourceUrl: 'https://ke.uwc.org/',
      tags: ['secondary', 'uwc', 'ib', 'route-kenya', 'needs-based', 'open'],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Vérifier le cursus et l’âge',
        titleEn: 'Check curriculum and age',
        descriptionFr:
          'Comparer son âge et son niveau prévu en décembre 2026 aux équivalences publiées par UWC Kenya.',
        descriptionEn:
          'Compare age and expected December 2026 school stage with the equivalents published by UWC Kenya.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 2,
        titleFr: 'Constituer le PDF',
        titleEn: 'Build the PDF file',
        descriptionFr:
          'Télécharger le formulaire d’information du candidat sur la page officielle, obtenir les relevés de notes officiels et les deux recommandations, ajouter les certificats éventuels, puis fusionner les documents demandés en un seul PDF.',
        descriptionEn:
          'Download the Applicant Information Form from the official page, obtain the official transcripts and both recommendations, add any certificates, then merge the requested documents into one PDF.',
        estimatedDurationDays: 21,
      },
      {
        stepNumber: 3,
        titleFr: 'Envoyer le dossier',
        titleEn: 'Submit the application',
        descriptionFr:
          'Envoyer le PDF unique à l’adresse de dépôt indiquée sur la page officielle pendant l’étape 1, du 1er au 31 décembre 2026, période durant laquelle le comité examine les dossiers.',
        descriptionEn:
          'Send the single PDF to the submission address given on the official page during stage 1, from 1 to 31 December 2026, the window in which the committee reviews applications.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 4,
        titleFr: 'Préparer la sélection à Nairobi',
        titleEn: 'Prepare for Nairobi selection',
        descriptionFr:
          'En cas de présélection, préparer la journée d’entretiens de janvier 2027 à Nairobi : activités de groupe, entretien de panel et présentation éventuelle d’un projet personnel. Les offres sont annoncées en février 2027 ; les informations financières sont demandées à tous les candidats pour déterminer l’aide.',
        descriptionEn:
          'If shortlisted, prepare for the January 2027 interview day in Nairobi: group activities, panel interview and a possible personal-project presentation. Offers are announced in February 2027; financial information is requested from all applicants to determine aid.',
        estimatedDurationDays: 31,
      },
    ],
    cycle: {
      academicYear: '2027-2028',
      status: 'open',
      dateConfidence: 'confirmed',
      opensAt: '2026-07-01T00:00:00.000Z',
      closesAt: '2026-12-31T23:59:59.000Z',
      sourceUrl: 'https://ke.uwc.org/how-to-apply/',
    },
    officialSources: [
      officialSource(
        'overview',
        'https://ke.uwc.org/',
        'UWC Kenya — official home page',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'eligibility',
        'https://ke.uwc.org/eligibility-criteria/',
        'UWC Kenya — official entry 2027 eligibility criteria',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'benefits',
        'https://ke.uwc.org/how-to-apply/',
        'UWC Kenya — official nomination and needs-based funding description',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'application',
        'https://ke.uwc.org/how-to-apply/',
        'UWC Kenya — official application instructions',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'cycle',
        'https://ke.uwc.org/how-to-apply/',
        'UWC Kenya — confirmed entry 2027 application window (1 Jul – 31 Dec 2026)',
        CHECKED_AT_UWC_2026_10_24,
      ),
    ],
    verifiedAt: CHECKED_AT_UWC_2026_10_24,
    verifiedBy: VERIFIED_BY,
  },
  {
    catalogId: 'uwc_tanzania_2027_forecast',
    levels: ['secondary'],
    scholarship: {
      id: 'uwc_tanzania_2027_forecast',
      nameFr: 'UWC — voie nationale Tanzanie',
      nameEn: 'UWC — Tanzania national route',
      countryId: 'tza',
      countryNameFr: 'Tanzanie (placements UWC internationaux)',
      countryNameEn: 'Tanzania (international UWC placements)',
      levelEligibleFr: 'Fin du secondaire — Form Four ou équivalent',
      levelEligibleEn: 'Final secondary stage — Form Four or equivalent',
      typeOfFundingFr: 'Aide complète ou partielle selon la place et le besoin financier',
      typeOfFundingEn: 'Full or partial aid depending on placement and financial need',
      fundingType: 'partially_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr:
        'Candidatures closes — réouverture estimée en décembre 2026, clôture estimée en janvier 2027',
      deadlineLabelEn:
        'Applications closed — reopening estimated December 2026, closing estimated January 2027',
      descriptionFr:
        'Sélection du comité national UWC Tanzanie pour un placement dans le réseau UWC. La nomination peut être entièrement ou partiellement financée après évaluation du besoin. Au 29 septembre 2026, le site officiel affiche « Applications are currently closed » et propose de s’inscrire pour être notifié de la réouverture : aucune date d’entrée 2027 n’est publiée. Les seules dates affichées restent celles du cycle précédent (8 décembre 2025 au 16 janvier 2026), d’où une fenêtre 2027 estimée au mois près.',
      descriptionEn:
        'Tanzania UWC national committee selection for a placement in the UWC network. A nomination may be fully or partially funded following a needs assessment. As of 29 September 2026 the official site states "Applications are currently closed" and offers a form to be notified when they reopen: no 2027-entry date is published. The only dates still shown are those of the previous cycle (8 December 2025 to 16 January 2026), so the 2027 window is estimated to the month only.',
      advantagesFr: [
        'Placement dans un établissement du réseau international UWC',
        'Cursus résidentiel de deux ans préparant au Baccalauréat International',
        'Aide complète ou partielle possible selon la place et le besoin démontré',
      ],
      advantagesEn: [
        'Placement at a school in the international UWC network',
        'Two-year residential International Baccalaureate curriculum',
        'Possible full or partial aid depending on placement and demonstrated need',
      ],
      eligibilityFr: [
        'Avoir entre 16 et 18 ans au moment de l’inscription',
        'Avoir terminé le Form Four CSEE ou prévoir de terminer IGCSE/GCSE ou MYP',
        'Être citoyen tanzanien ou résident permanent en Tanzanie',
        'Pouvoir participer physiquement à tous les entretiens et évaluations financières à Dar es Salaam en cas de sélection, entretiens qui ont généralement lieu autour de février',
        'Présenter un bon dossier scolaire et un engagement d’apprentissage au-delà de la classe',
        'Démontrer les valeurs UWC, un impact communautaire positif, de la résilience et de l’adaptabilité',
        'Avoir une base en anglais et la volonté de progresser ; la maîtrise courante n’est pas exigée à la candidature',
        'Ne déposer qu’une seule candidature UWC par année académique',
      ],
      eligibilityEn: [
        'Be between 16 and 18 years old at enrolment',
        'Have completed Form Four CSEE or expect to complete IGCSE/GCSE or MYP',
        'Be a Tanzanian citizen or permanent resident in Tanzania',
        'Be able to attend all interviews and financial assessments physically in Dar es Salaam if selected, interviews usually taking place around February',
        'Show a strong academic record and commitment to learning beyond the classroom',
        'Demonstrate UWC values, positive community impact, resilience and adaptability',
        'Have basic English and willingness to improve; fluency is not required when applying',
        'Submit only one UWC application per academic year',
      ],
      keyRequirementsFr: [
        'Formulaire en ligne avec informations personnelles, parcours, activités et motivations',
        'Essais ou réponses courtes',
        'Références d’enseignants, mentors ou responsables communautaires',
        'Relevés scolaires et autres justificatifs demandés',
        'Autorisation signée du parent ou tuteur légal',
        'Présence à Dar es Salaam pour la sélection en cas de présélection',
        'Informations financières pour l’évaluation du besoin',
      ],
      keyRequirementsEn: [
        'Online form with personal details, academic history, activities and motivations',
        'Essays or short responses',
        'References from teachers, mentors or community leaders',
        'Academic transcripts and other requested evidence',
        'Signed permission from a parent or legal guardian',
        'Attendance in Dar es Salaam for selection if shortlisted',
        'Financial information for needs assessment',
      ],
      relatedFieldIds: [],
      baseMatch: 80,
      applicationUrl: 'https://tz.uwc.org/how-to-apply/',
      sourceUrl: 'https://tz.uwc.org/',
      tags: [
        'secondary',
        'uwc',
        'ib',
        'route-tanzania',
        'needs-based',
        'forecast',
      ],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Vérifier son admissibilité',
        titleEn: 'Check eligibility',
        descriptionFr:
          'Confirmer l’âge, le niveau scolaire, la citoyenneté ou résidence et la disponibilité pour la sélection à Dar es Salaam.',
        descriptionEn:
          'Confirm age, school stage, citizenship or residency and availability for selection in Dar es Salaam.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 2,
        titleFr: 'Préparer les pièces',
        titleEn: 'Prepare documents',
        descriptionFr:
          'Rassembler les relevés, références, essais, justificatifs et l’autorisation parentale.',
        descriptionEn:
          'Gather transcripts, references, essays, supporting evidence and parental permission.',
        estimatedDurationDays: 21,
      },
      {
        stepNumber: 3,
        titleFr: 'Soumettre la candidature',
        titleEn: 'Submit the application',
        descriptionFr:
          'S’inscrire au formulaire de notification du site officiel pour être averti de la réouverture, puis utiliser le lien de candidature publié par le comité national avant la date limite annoncée.',
        descriptionEn:
          'Register on the official site’s notification form to be told when applications reopen, then use the application link published by the national committee before the announced deadline.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 4,
        titleFr: 'Passer la sélection',
        titleEn: 'Complete selection',
        descriptionFr:
          'En cas de présélection, participer à Dar es Salaam aux tests écrits (raisonnement, résolution de problèmes et anglais), aux activités de groupe, à l’entretien de panel, à une présentation éventuelle de projet et à l’évaluation financière.',
        descriptionEn:
          'If shortlisted, attend in Dar es Salaam the written assessments (logical reasoning, problem-solving and English), group activities, panel interview, a possible project presentation and the financial assessment.',
        estimatedDurationDays: 42,
      },
    ],
    cycle: {
      academicYear: '2027-2028',
      // Le comité national n'a publié AUCUNE date pour l'entrée 2027 : la page
      // « How to Apply » affiche encore les dates du cycle précédent (8 déc.
      // 2025 – 16 janv. 2026) et l'accueil indique « Applications are
      // currently closed ». Les bornes ci-dessous sont donc ce cycle décalé
      // d'un an, gardées au niveau du mois dans le deadlineLabel. Statut
      // « forecast » et non « suspended » : le site annonce explicitement une
      // réouverture et propose de s'y inscrire.
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-12-08T00:00:00.000Z',
      estimatedCloseAt: '2027-01-16T23:59:59.000Z',
      sourceUrl: 'https://tz.uwc.org/how-to-apply/',
    },
    officialSources: [
      officialSource(
        'overview',
        'https://tz.uwc.org/',
        'Tanzania UWC National Committee — official home page (states applications are currently closed)',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'eligibility',
        'https://tz.uwc.org/eligibility-criteria/',
        'Tanzania UWC National Committee — official eligibility criteria',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'benefits',
        'https://tz.uwc.org/how-to-apply/',
        'Tanzania UWC National Committee — nomination and funding description',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'application',
        'https://tz.uwc.org/how-to-apply/',
        'Tanzania UWC National Committee — official application instructions',
        CHECKED_AT_UWC_2026_10_24,
      ),
      officialSource(
        'cycle',
        'https://tz.uwc.org/how-to-apply/',
        'Tanzania UWC National Committee — previous-cycle dates only (8 Dec 2025 – 16 Jan 2026); no 2027-entry dates published',
        CHECKED_AT_UWC_2026_10_24,
      ),
    ],
    verifiedAt: CHECKED_AT_UWC_2026_10_24,
    verifiedBy: VERIFIED_BY,
  },
];
