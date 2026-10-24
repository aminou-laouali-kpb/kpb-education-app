import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';
import { buildVerifiedScholarshipRecord as record } from './scholarship-catalog.record-builder';

/**
 * European Master-only opportunities, verified against official sources on
 * 10 August 2026.
 *
 * The three records started with `dateConfidence: 'estimated'`. This is not
 * caution for its own sake — none of the three authorities published a single
 * dated calendar for the 2027-2028 intake when they were written (Eiffel has
 * since published one, see below):
 *
 *  - Eiffel: the Campus France pages still carry the 2026 session calendar
 *    (call opened 1 October 2025, institution deadline 8 January 2026, results
 *    from 30 March 2026). The programme brochure states the recurring pattern
 *    instead — call "end of September", institution deadline "1st week of
 *    January", results in March — which is what the estimated window follows.
 *  - DAAD EPOS: the official "List of Application Deadlines … for Intake
 *    2027/2028" (Stand 06/2026) prints "see website of the course" in the DAAD
 *    Scholarship column for every single course. DAAD publishes no date at all.
 *  - Erasmus Mundus: each consortium owns its calendar. The Commission only
 *    states that "in most cases, you should submit your application between
 *    October and January for courses starting the following academic year".
 *
 * `status` is therefore `'forecast'` until an official date is published:
 * the validator forbids `'open'` without confirmed dates, and claiming
 * confirmation here would be a fabrication. Eiffel became `'open'` on
 * 07/10/2026, once Campus France published the 2027 closing date.
 */
export const VERIFIED_EUROPE_MASTER_RECORDS_V1: VerifiedScholarshipCatalogRecord[] =
  [
    record({
      id: 'eiffel_excellence_master_2027',
      levels: ['master'],
      name: [
        'Bourse France Excellence Eiffel 2027–2028 — volet Master',
        'France Excellence Eiffel Scholarship 2027–2028 — Master strand',
      ],
      country: ['fra', 'France', 'France'],
      levelLabel: [
        'Master accrédité par l’État ou diplôme d’ingénieur, 12 à 36 mois de bourse',
        'State-accredited Master or engineering diploma, 12 to 36 months of funding',
      ],
      fundingLabel: [
        'Allocation mensuelle et services ; frais de scolarité non couverts par le programme, exonération possible en établissement public',
        'Monthly allowance and services; tuition not covered by the programme, with possible exemption at public institutions',
      ],
      fundingType: 'partially_funded',
      deadlineLabel: [
        'Ouvert — on postule auprès d’un établissement français, dont la date limite interne tombe dès fin octobre (UTBM : 28 octobre 2026) et le plus souvent en novembre ; l’établissement dépose ensuite le dossier à Campus France au plus tard le 6 janvier 2027 (la page officielle cite aussi le 8 janvier : retenir le 6)',
        'Open — you apply through a French institution, whose internal deadline falls as early as late October (UTBM: 28 October 2026) and most often in November; the institution then submits the file to Campus France by 6 January 2027 at the latest (the official page also mentions 8 January: rely on 6 January)',
      ],
      description: [
        'Bourse du ministère de l’Europe et des Affaires étrangères, gérée par Campus France, destinée à attirer les meilleurs étudiants étrangers dans les masters et diplômes d’ingénieur français. Point décisif : la candidature est déposée uniquement par l’établissement français qui présente l’étudiant, jamais par l’étudiant lui-même — l’étudiant doit donc se faire présélectionner par un établissement, plusieurs mois avant la date limite nationale. Un volet doctorat existe mais n’est pas couvert par cette fiche.',
        'Scholarship of the French Ministry for Europe and Foreign Affairs, managed by Campus France, designed to attract the best international students to French Master and engineering programmes. Decisive point: the application is submitted only by the French institution presenting the student, never by the student — so the student must be pre-selected by an institution months before the national deadline. A doctorate strand exists but is not covered by this record.',
      ],
      advantages: [
        [
          'Allocation mensuelle de 1 200 EUR au niveau Master, montant en vigueur depuis janvier 2026',
          'EUR 1,200 monthly allowance at Master level, the amount applicable since January 2026',
        ],
        [
          'Bourse versée de 12 à 36 mois selon le diplôme et l’année d’inscription : au maximum 12 mois en Master 2, 24 mois en Master 1 et 36 mois pour un diplôme d’ingénieur',
          'Funding paid for 12 to 36 months depending on the degree and year of enrolment: a maximum of 12 months in Master 2, 24 months in Master 1 and 36 months for an engineering degree',
        ],
        [
          'Billets d’avion aller et retour (classe la moins chère) remboursés sur justificatifs dans la limite de 50 % du tarif maximal fixé par le ministère de l’Europe et des Affaires étrangères, ainsi que le transport national jusqu’au lieu d’études',
          'Outbound and return airfare (least-expensive class) reimbursed on receipts up to 50% of the maximum rate set by the Ministry for Europe and Foreign Affairs, plus national transport to the place of study',
        ],
        [
          'Couverture santé assurée par Campus France jusqu’à l’activation de la sécurité sociale étudiante, puis affiliation obligatoire et gratuite',
          'Health cover arranged by Campus France until student social security is active, then mandatory free affiliation',
        ],
        [
          'Frais de visa non facturés lorsque applicable, et exonération des droits d’inscription des diplômes nationaux et diplômes d’ingénieur accrédités en établissement public au titre du statut de boursier du gouvernement français',
          'No visa fees where applicable, and exemption from tuition for national diplomas and accredited engineering degrees at public institutions by virtue of French government scholarship status',
        ],
        [
          'Aide à la recherche de logement, en résidence CROUS ou dans le parc privé, et activités culturelles organisées par Campus France',
          'Housing search support, in CROUS residences or private housing, and cultural activities organised by Campus France',
        ],
      ],
      eligibility: [
        [
          'Être de nationalité étrangère : les candidats binationaux dont l’une des nationalités est française ne sont pas éligibles',
          'Hold a foreign nationality: dual nationals with French among their nationalities are not eligible',
        ],
        [
          'Avoir 29 ans au plus au niveau Master ; le volet doctorat, qui va jusqu’à 35 ans, n’est pas couvert par cette fiche',
          'Be no older than 29 at Master level; the doctorate strand, open up to 35, is not covered by this record',
        ],
        [
          'Relever de l’un des sept domaines prioritaires : biologie et santé ; transition écologique ; mathématiques et numérique ; sciences de l’ingénieur ; histoire, langue et civilisation françaises ; droit et science politique ; économie et gestion',
          'Fall within one of the seven priority fields: biology and health; ecological transition; mathematics and digital; engineering sciences; French history, language and civilisation; law and political science; economics and management',
        ],
        [
          'Viser une formation accréditée par l’État français délivrant un diplôme national de master ou un diplôme d’ingénieur ; formation continue, contrat d’apprentissage ou de professionnalisation et programmes français délocalisés à l’étranger sont exclus',
          'Target a French state-accredited programme awarding a national Master or engineering diploma; continuing education, apprenticeship or professionalisation contracts and French programmes located abroad are excluded',
        ],
        [
          'Ne pas déjà étudier en France : au volet Master, les candidats actuellement en études en France ne sont pas éligibles, et les boursiers actuels du gouvernement français non plus',
          'Not already be studying in France: at Master level, candidates currently studying in France are ineligible, as are current French government scholarship holders',
        ],
        [
          'Être présenté par un établissement français : seules les candidatures déposées par les établissements sont acceptées, et chaque établissement ne peut présenter plus de 40 candidatures par domaine et par volet',
          'Be presented by a French institution: only applications submitted by institutions are accepted, and each institution may present no more than 40 applications per field and per strand',
        ],
      ],
      requirements: [
        [
          'Dossier constitué avec le service des relations internationales de l’établissement français, à sa date limite interne, largement antérieure à la date nationale',
          'File prepared with the French institution’s international relations office, by its internal deadline, well before the national one',
        ],
        [
          'Passeport en cours de validité ; une carte d’identité peut être acceptée à titre provisoire',
          'Valid passport; an identity card may be temporarily accepted',
        ],
        [
          'Diplômes obtenus et relevés de notes du parcours antérieur',
          'Degrees obtained and transcripts of previous studies',
        ],
        [
          'CV et lettre de motivation situant le projet dans l’un des sept domaines prioritaires',
          'CV and motivation letter placing the project within one of the seven priority fields',
        ],
        [
          'Justificatifs de niveau de langue, facultatifs au dossier Eiffel mais généralement exigés par la formation visée',
          'Language level evidence, optional in the Eiffel file but generally required by the target programme',
        ],
        [
          'Engagement de l’établissement d’accueil à inscrire le lauréat dans le programme pour lequel il a été sélectionné',
          'Commitment by the host institution to enrol the awardee in the programme for which they were selected',
        ],
      ],
      steps: [
        [
          'Identifier une formation et un établissement participants',
          'Identify a participating programme and institution',
          'Vérifier que le master ou diplôme d’ingénieur visé est accrédité par l’État et relève d’un des sept domaines prioritaires, puis repérer les établissements qui participent à la campagne Eiffel.',
          'Check that the target Master or engineering diploma is state-accredited and falls within one of the seven priority fields, then identify the institutions taking part in the Eiffel campaign.',
        ],
        [
          'Contacter le service des relations internationales',
          'Contact the international relations office',
          'La candidature est portée par l’établissement, jamais par l’étudiant : prendre contact dès l’été ou la rentrée pour connaître la procédure interne et la date limite de présélection.',
          'The application is carried by the institution, never by the student: make contact from the summer or the start of the academic year to learn the internal procedure and pre-selection deadline.',
        ],
        [
          'Constituer le dossier avec l’établissement',
          'Build the file with the institution',
          'Fournir passeport, diplômes, relevés, CV, lettre de motivation et preuves de langue ; l’établissement classe ses candidats et dépose lui-même le dossier sur la plateforme Campus France.',
          'Provide passport, degrees, transcripts, CV, motivation letter and language evidence; the institution ranks its candidates and submits the file itself on the Campus France platform.',
        ],
        [
          'Suivre la sélection nationale',
          'Follow the national selection',
          'Campus France instruit les dossiers reçus avant la date limite de janvier ; sept commissions d’experts, une par domaine, évaluent les candidatures et les résultats sont publiés au printemps.',
          'Campus France processes the files received before the January deadline; seven expert panels, one per field, assess the applications and results are published in the spring.',
        ],
      ],
      cycle: {
        academicYear: '2027-2028',
        // Ouvert : actualité Campus France mise à jour le 06/10/2026 (« open
        // until January 6, 2027 »). La même page dit aussi « until January 8,
        // 2027 » au paragraphe précédent : la date la plus tôt est retenue,
        // une clôture trop tôt coûte moins qu'une clôture manquée. Aucune date
        // d'ouverture n'est publiée — on ne l'invente pas.
        status: 'open',
        dateConfidence: 'confirmed',
        closesAt: '2027-01-06T23:59:59.000Z',
        sourceUrl:
          'https://www.campusfrance.org/en/actu/call-for-france-excellence-eiffel-applications-2027',
      },
      sources: {
        overview:
          'https://www.campusfrance.org/en/france-excellence-eiffel-scholarship-program',
        eligibility:
          'https://www.campusfrance.org/en/the-france-excellence-eiffel-scholarship-program',
        benefits:
          'https://www.campusfrance.org/en/france-excellence-eiffel-scholarship-implementation',
        application:
          'https://www.campusfrance.org/fr/faq-appel-a-candidature-a-la-bourse-eiffel',
        cycle:
          'https://www.campusfrance.org/en/actu/call-for-france-excellence-eiffel-applications-2027',
      },
      tags: [
        'master',
        'france',
        'government',
        'campus-france',
        'nomination',
        'open',
      ],
      relatedFieldIds: ['d01', 'd02', 'd03', 'd04', 'd07', 'd08', 'd09'],
      checkedAt: '2026-10-24T07:14:00.000Z',
    }),
    record({
      id: 'daad_epos_2027',
      levels: ['master'],
      name: [
        'Bourses DAAD EPOS — Masters liés au développement 2027–2028',
        'DAAD EPOS Development-Related Postgraduate Courses 2027–2028',
      ],
      country: ['deu', 'Allemagne', 'Germany'],
      levelLabel: [
        'Masters de la liste officielle EPOS pour l’admission 2027/2028',
        'Master courses from the official EPOS list for the 2027/2028 intake',
      ],
      fundingLabel: [
        'Bourse individuelle complète du DAAD',
        'Full individual DAAD scholarship',
      ],
      fundingType: 'fully_funded',
      deadlineLabel: [
        'Ouverture estimée — une date limite par cursus, du printemps 2026 à fin janvier 2027 selon le programme choisi',
        'Estimated opening — one deadline per course, from spring 2026 to late January 2027 depending on the chosen programme',
      ],
      description: [
        'Bourses individuelles du DAAD pour des diplômés de pays en développement et émergents qui suivent un Master lié au développement dans une liste de cursus sélectionnés en Allemagne. Programme distinct du Helmut-Schmidt-Programme. Il n’existe aucune date limite unique : chaque cursus fixe la sienne, et la liste officielle du DAAD pour l’admission 2027/2028 inscrit littéralement « see website of the course » en face de chaque programme. Le dossier part directement à l’université, jamais au DAAD.',
        'DAAD individual scholarships for graduates from developing and emerging countries taking a development-related Master among a selected list of courses in Germany. A distinct programme from the Helmut-Schmidt-Programme. There is no single deadline: each course sets its own, and the official DAAD list for the 2027/2028 intake literally prints “see website of the course” against every programme. The file goes directly to the university, never to DAAD.',
      ],
      advantages: [
        [
          'Allocation mensuelle de 992 EUR au niveau Master',
          'EUR 992 monthly stipend at Master level',
        ],
        [
          'Assurance maladie, accident et responsabilité civile prises en charge',
          'Health, accident and personal liability insurance covered',
        ],
        [
          'Forfait voyage vers l’Allemagne et retour, sauf si ces frais sont pris en charge par le pays d’origine ou un autre financeur',
          'Travel allowance to Germany and back, unless these costs are covered by the home country or another funder',
        ],
        [
          'Subvention de loyer et allocations familiales possibles selon la situation personnelle',
          'Possible rent subsidy and family allowances depending on personal circumstances',
        ],
        [
          'Financement de toute la durée du cursus, de 12 à 42 mois selon le programme choisi',
          'Funding for the whole course duration, 12 to 42 months depending on the chosen programme',
        ],
        [
          'Aucune admission préalable au Master n’est exigée pour candidater à la bourse',
          'No prior admission to the Master is required to apply for the scholarship',
        ],
      ],
      eligibility: [
        [
          'Être diplômé d’un pays figurant sur la liste CAD des pays en développement et émergents retenue par le DAAD',
          'Be a graduate from a country on the DAC list of developing and emerging countries used by DAAD',
        ],
        [
          'Justifier au moins deux ans d’expérience professionnelle pertinente, appréciée à la date de la candidature',
          'Have at least two years of relevant professional experience, assessed at the date of application',
        ],
        [
          'Détenir une Licence, en règle générale de quatre ans, avec des résultats supérieurs à la moyenne situés dans le tiers supérieur',
          'Hold a Bachelor degree, normally of four years, with above-average results in the upper third',
        ],
        [
          'Avoir un dernier diplôme qui, en principe, n’a pas plus de six ans',
          'Hold a latest degree that should normally not be more than six years old',
        ],
        [
          'Ne pas avoir séjourné en Allemagne plus de quinze mois à la date limite de candidature',
          'Not have resided in Germany for more than fifteen months at the application deadline',
        ],
        [
          'Satisfaire les exigences de langue du cursus visé, selon le règlement de chaque cursus ; pour les cursus en allemand, niveau B1 à la candidature puis DSH 2 ou TestDaF 4 pour l’inscription',
          'Meet the language requirements of the target course, according to the regulations of each course; for German-taught courses, level B1 at application then DSH 2 or TestDaF 4 for matriculation',
        ],
      ],
      requirements: [
        [
          'Formulaire de candidature DAAD du programme EPOS',
          'DAAD application form for the EPOS programme',
        ],
        [
          'CV au format Europass',
          'Europass-format CV',
        ],
        [
          'Lettre de motivation rattachée à l’emploi actuel ; une seule lettre pour un maximum de trois cursus, expliquant l’ordre de priorité retenu',
          'Motivation letter linked to current employment; a single letter for up to three courses, explaining the chosen priority order',
        ],
        [
          'Lettre de recommandation professionnelle de l’employeur, sur papier à en-tête, signée, tamponnée et de date récente',
          'Professional letter of recommendation from the employer, on letterhead, signed, stamped and of recent date',
        ],
        [
          'Attestation d’emploi dans le pays d’origine et, si possible, garantie de réembauche',
          'Confirmation of employment in the home country and, where possible, a guarantee of reemployment',
        ],
        [
          'Copies certifiées des diplômes et des relevés de notes, avec traductions certifiées si nécessaire, et preuve du niveau de langue',
          'Certified copies of degrees and transcripts, with certified translations where needed, and proof of language level',
        ],
      ],
      steps: [
        [
          'Choisir jusqu’à trois cursus de la liste EPOS',
          'Pick up to three courses from the EPOS list',
          'Ouvrir la liste officielle 2027/2028 du DAAD et retenir au maximum trois cursus : la bourse ne couvre que les programmes qui y figurent, un master allemand hors liste n’est pas finançable.',
          'Open the official DAAD 2027/2028 list and shortlist at most three courses: the scholarship only covers programmes on that list, a German Master outside it cannot be funded.',
        ],
        [
          'Relever la date limite propre à chaque cursus',
          'Read each course’s own deadline',
          'Le DAAD n’annonce aucune date commune et renvoie au site de chaque programme : noter la date de chacun des cursus visés, car une date dépassée est définitive.',
          'DAAD announces no common date and refers to each programme website: record the date of every shortlisted course, as a missed deadline is final.',
        ],
        [
          'Déposer directement auprès de chaque université',
          'Apply directly to each university',
          'Envoyer le dossier complet, en anglais ou en allemand, à l’université concernée ; un dossier adressé au DAAD n’est pas transmis aux cursus et l’université peut réclamer des pièces supplémentaires.',
          'Send the complete file, in English or German, to the university concerned; a file sent to DAAD is not forwarded to the courses and the university may require additional documents.',
        ],
        [
          'Attendre la décision du cursus',
          'Wait for the course decision',
          'C’est le cursus, et non le DAAD, qui informe du résultat ; l’essentiel de la procédure de sélection est achevé en mars.',
          'The course, not DAAD, communicates the result; the bulk of the selection process is completed in March.',
        ],
      ],
      cycle: {
        academicYear: '2027-2028',
        status: 'forecast',
        dateConfidence: 'estimated',
        estimatedOpenAt: '2026-05-15T00:00:00.000Z',
        estimatedCloseAt: '2027-01-31T23:59:59.000Z',
        sourceUrl:
          'https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_epos_deadlines.pdf',
      },
      sources: {
        overview:
          'https://www.daad.de/en/information-services-for-higher-education-institutions/further-information-on-daad-programmes/epos/',
        eligibility:
          'https://www2.daad.de/deutschland/stipendium/datenbank/en/21148-scholarship-database/?detail=50076777',
        benefits:
          'https://www2.daad.de/deutschland/stipendium/datenbank/en/21148-scholarship-database/?detail=50076777',
        application:
          'https://www2.daad.de/deutschland/stipendium/datenbank/en/21148-scholarship-database/?detail=50076777',
        cycle:
          'https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_epos_deadlines.pdf',
      },
      tags: [
        'master',
        'germany',
        'daad',
        'development',
        'forecast',
        'fully-funded',
        'estimated-open-date',
      ],
      relatedFieldIds: ['d02', 'd03', 'd04', 'd05', 'd08', 'd09'],
      checkedAt: '2026-10-24T07:14:00.000Z',
    }),
    record({
      id: 'erasmus_mundus_joint_masters_2027',
      levels: ['master'],
      name: [
        'Masters conjoints Erasmus Mundus 2027–2028',
        'Erasmus Mundus Joint Masters 2027–2028',
      ],
      country: [
        'int',
        'Europe — consortiums de plusieurs pays',
        'Europe — multi-country consortia',
      ],
      levelLabel: [
        'Masters conjoints de 12, 18 ou 24 mois (60, 90 ou 120 ECTS)',
        'Joint Masters of 12, 18 or 24 months (60, 90 or 120 ECTS)',
      ],
      fundingLabel: [
        'Bourse complète calculée sur un coût unitaire de 1 400 EUR par mois',
        'Full scholarship based on a unit cost of EUR 1,400 per month',
      ],
      fundingType: 'fully_funded',
      deadlineLabel: [
        'Ouverture estimée — un calendrier par consortium, généralement d’octobre 2026 à janvier 2027',
        'Estimated opening — one calendar per consortium, generally October 2026 to January 2027',
      ],
      description: [
        'Masters internationaux conçus et délivrés conjointement par au moins trois établissements de trois pays différents, avec des bourses complètes financées par la Commission européenne. Il n’existe ni candidature centralisée ni date limite commune : l’étudiant postule directement au consortium qui pilote le master choisi, chaque consortium publiant son propre calendrier et ses propres critères d’admission. Le catalogue officiel des masters est mis à jour chaque année, une nouvelle série de masters sélectionnés y étant ajoutée.',
        'International Masters jointly designed and delivered by at least three institutions from three different countries, with full scholarships funded by the European Commission. There is neither a central application nor a common deadline: students apply directly to the consortium running their chosen Master, each consortium publishing its own calendar and its own admission criteria. The official catalogue of Masters is updated every year, with a new batch of selected Masters added annually.',
      ],
      advantages: [
        [
          'Bourse calculée sur un coût unitaire de 1 400 EUR par mois pour toute la durée du master',
          'Scholarship based on a EUR 1,400 monthly unit cost for the whole Master duration',
        ],
        [
          'Couverture des frais de participation, du voyage, du visa, de l’installation et des frais de subsistance',
          'Covers participation costs, travel, visa, installation and subsistence costs',
        ],
        [
          'Financement de 12, 18 ou 24 mois selon la durée du master, avec réduction possible en cas de reconnaissance d’acquis, sans descendre sous une année académique',
          'Funding for 12, 18 or 24 months depending on the Master duration, reducible where prior learning is recognised, never below one academic year',
        ],
        [
          'Diplôme conjoint unique délivré au nom de plusieurs établissements, ou diplômes multiples délivrés par les établissements du consortium',
          'A single joint degree issued on behalf of several institutions, or multiple degrees issued by the consortium institutions',
        ],
        [
          'Bourses supplémentaires ciblées : jusqu’à 18 bourses régionales financées par l’instrument Global Europe et jusqu’à 3 au titre de l’IAP III',
          'Targeted top-up scholarships: up to 18 regional scholarships funded by the Global Europe instrument and up to 3 under IPA III',
        ],
        [
          'Équilibre géographique imposé : au maximum 10 % des bourses d’un projet peuvent aller à une même nationalité, hors bourses régionales ciblées',
          'Enforced geographic balance: at most 10% of a project’s scholarships may go to one nationality, excluding targeted regional scholarships',
        ],
      ],
      eligibility: [
        [
          'Détenir un premier diplôme d’enseignement supérieur ou justifier d’un niveau d’apprentissage reconnu équivalent',
          'Hold a first higher education degree or demonstrate a recognised equivalent level of learning',
        ],
        [
          'Être en dernière année de Licence est accepté, à condition d’être diplômé avant le début du master',
          'Being in the final year of a Bachelor is accepted, provided the degree is obtained before the Master starts',
        ],
        [
          'Les bourses sont ouvertes aux étudiants du monde entier, sans condition de nationalité',
          'Scholarships are open to students from all over the world, with no nationality condition',
        ],
        [
          'Ne pas avoir déjà obtenu une bourse de master conjoint Erasmus Mundus',
          'Not have previously obtained an Erasmus Mundus Joint Master scholarship',
        ],
        [
          'Satisfaire les critères d’admission propres au consortium, publiés sur le site du master : langue, relevés, prérequis disciplinaires',
          'Meet the consortium’s own admission criteria published on the Master website: language, transcripts, subject prerequisites',
        ],
        [
          'Postuler à un master figurant au catalogue Erasmus Mundus et vérifier sur son site qu’il propose encore des bourses de l’UE pour la rentrée 2027 : certains masters listés n’en offrent plus (fin de financement)',
          'Apply to a Master listed in the Erasmus Mundus catalogue and check on its website that it still offers EU scholarships for the 2027 intake: some listed Masters no longer do (end of funding)',
        ],
      ],
      requirements: [
        [
          'Liste exacte des pièces publiée par le consortium : chaque master fixe ses propres exigences et sa propre procédure',
          'Exact document list published by the consortium: each Master sets its own requirements and its own procedure',
        ],
        [
          'Diplôme de Licence ou attestation d’inscription en dernière année, avec relevés de notes',
          'Bachelor diploma or proof of final-year enrolment, with transcripts',
        ],
        [
          'Preuve du niveau de langue exigé par le consortium pour la langue d’enseignement',
          'Proof of the language level required by the consortium for the language of instruction',
        ],
        [
          'CV et lettre de motivation présentant le projet d’études et la mobilité envisagée',
          'CV and motivation letter presenting the study project and planned mobility',
        ],
        [
          'Lettres de recommandation lorsque le consortium en demande',
          'Letters of recommendation where the consortium requires them',
        ],
        [
          'Passeport ou pièce d’identité, puis demande de visa pour le premier pays de mobilité une fois l’admission obtenue',
          'Passport or identity document, then a visa application for the first mobility country once admission is secured',
        ],
      ],
      steps: [
        [
          'Explorer le catalogue Erasmus Mundus',
          'Search the Erasmus Mundus catalogue',
          'Filtrer le catalogue officiel de l’EACEA par domaine pour repérer les masters conjoints soutenus par l’Union européenne ; il est mis à jour chaque année avec une nouvelle série de masters.',
          'Filter the official EACEA catalogue by subject to find the joint Masters supported by the European Union; it is updated annually with a new batch of Masters.',
        ],
        [
          'Relever le calendrier de chaque master retenu',
          'Read the calendar of each shortlisted Master',
          'Aucune date commune n’existe : ouvrir le site de chaque consortium et noter sa date limite, la plupart se situant entre octobre et janvier pour une rentrée l’année académique suivante.',
          'There is no common date: open each consortium website and record its deadline, most falling between October and January for entry the following academic year.',
        ],
        [
          'Postuler directement au consortium',
          'Apply directly to the consortium',
          'La candidature se dépose auprès de l’établissement qui pilote le programme, jamais auprès de la Commission européenne ni d’un portail central, et la sélection relève du seul consortium.',
          'The application is submitted to the institution running the programme, never to the European Commission or a central portal, and selection is the sole responsibility of the consortium.',
        ],
        [
          'Préparer la mobilité après sélection',
          'Prepare mobility after selection',
          'Le consortium notifie lui-même le résultat ; organiser ensuite visa, logement et arrivée dans le premier pays d’études, puis les étapes de mobilité suivantes.',
          'The consortium notifies the result itself; then arrange visa, housing and arrival in the first study country, followed by the subsequent mobility steps.',
        ],
      ],
      cycle: {
        academicYear: '2027-2028',
        status: 'forecast',
        dateConfidence: 'estimated',
        estimatedOpenAt: '2026-10-01T00:00:00.000Z',
        estimatedCloseAt: '2027-01-31T23:59:59.000Z',
        sourceUrl:
          'https://www.eacea.ec.europa.eu/scholarships/erasmus-mundus-catalogue_en',
      },
      sources: {
        overview:
          'https://erasmus-plus.ec.europa.eu/opportunities/individuals/students/erasmus-mundus-joint-masters',
        eligibility:
          'https://erasmus-plus.ec.europa.eu/programme-guide/part-b/key-action-2/erasmus-mundus-action',
        benefits:
          'https://erasmus-plus.ec.europa.eu/programme-guide/part-b/key-action-2/erasmus-mundus-action',
        application:
          'https://www.eacea.ec.europa.eu/scholarships/erasmus-mundus-catalogue_en',
        cycle:
          'https://www.eacea.ec.europa.eu/scholarships/erasmus-mundus-catalogue_en',
      },
      tags: [
        'master',
        'europe',
        'erasmus-mundus',
        'european-commission',
        'forecast',
        'fully-funded',
        'estimated-open-date',
      ],
      relatedFieldIds: [
        'd01',
        'd02',
        'd03',
        'd04',
        'd05',
        'd06',
        'd07',
        'd08',
        'd09',
        'd11',
      ],
      checkedAt: '2026-10-24T07:13:00.000Z',
    }),
  ];
