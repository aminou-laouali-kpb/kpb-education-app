import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';
import { buildVerifiedScholarshipRecord as record } from './scholarship-catalog.record-builder';

/**
 * Pan-African bachelor opportunities hosted on the continent, verified against
 * the institutions' own sites on 10 August 2026.
 *
 * Calendar caveat shared by the three records: none of the three institutions
 * publishes a dated 2027–2028 campaign yet. All three run rolling or
 * multi-round admissions and only publish the deadline of the cycle currently
 * being processed (Ashesi: 16 November 2026 for the January 2027 intake — ALU:
 * 30 November 2026 for the January 2027 intake — AUC: 1 November for Spring
 * 2027). The 2027–2028 windows below are therefore `estimated`, deduced from
 * the round/intake pattern the institutions do publish, and every deadline
 * label says so in both languages.
 */
export const VERIFIED_AFRICA_BACHELOR_RECORDS_V1: VerifiedScholarshipCatalogRecord[] =
  [
    record({
      id: 'ashesi_scholarship_2027',
      levels: ['bachelor'],
      name: [
        'Bourse Ashesi University 2027–2028',
        'Ashesi University Scholarship 2027–2028',
      ],
      country: ['gha', 'Ghana', 'Ghana'],
      levelLabel: [
        'Licence de quatre ans à Berekuso',
        'Four-year Bachelor at Berekuso',
      ],
      fundingLabel: [
        'Aide au besoin, partielle à complète',
        'Need-based aid, partial to full',
      ],
      fundingType: 'partially_funded',
      deadlineLabel: [
        'Ouverture estimée — admissions continues en quatre tours ; dernier dépôt estimé mi-août 2027 pour la rentrée de septembre 2027',
        'Estimated opening — rolling admissions in four rounds; final submission estimated mid-August 2027 for the September 2027 entry',
      ],
      description: [
        'Aide financière propre à Ashesi University, entièrement fondée sur le besoin : l’université précise qu’elle n’accorde aucune bourse au mérite en Licence. Le portail officiel n’affiche pas encore de date pour 2027–2028 ; il publie une échéance datée du 16 novembre 2026 pour l’entrée de janvier 2027 (année 2026/27), les tours du cycle 2027–2028 restent donc estimés.',
        'Ashesi University’s own financial aid, entirely need-based: the university states it grants no merit scholarships for undergraduate programmes. The official portal does not yet publish a 2027–2028 date; it publishes a dated 16 November 2026 deadline for the January 2027 entry (2026/27 year), so the 2027–2028 rounds remain estimated.',
      ],
      advantages: [
        [
          'Prise en charge d’une partie des frais de scolarité, ou de la totalité du coût des études, selon le besoin démontré',
          'Coverage of part of the tuition fees, or of the entire cost of studying, depending on demonstrated need',
        ],
        [
          'Certaines catégories couvrent en plus le logement, les repas sur le campus et le matériel pédagogique',
          'Some categories also cover housing, meals on campus and learning materials',
        ],
        [
          'Soutien aux dépenses de vie de base dans les catégories les plus complètes',
          'Support for basic living expenses in the most comprehensive categories',
        ],
        [
          'Conditions de la bourse notifiées dans le dossier d’admission de l’étudiant',
          'Scholarship conditions notified in the student’s admissions package',
        ],
        [
          'Environ 50 % des étudiants reçoivent une aide et 25 % ne paient aucun frais',
          'About 50% of students receive some form of aid and 25% pay zero fees',
        ],
        [
          'Bourses d’urgence pour les étudiants confrontés à un obstacle financier imprévu',
          'Emergency scholarships for students facing an unexpected financial barrier',
        ],
      ],
      eligibility: [
        [
          'Être d’abord admissible à Ashesi : la première étape de sélection est need-blind et repose sur le profil global',
          'First be admissible to Ashesi: the initial selection stage is need-blind and based on the overall profile',
        ],
        [
          'Démontrer un besoin financier prouvé ; les dossiers sont classés en besoin extrême, élevé, moyen ou faible',
          'Demonstrate proven financial need; files are placed in extreme, high, medium or low need categories',
        ],
        [
          'Comprendre qu’aucune bourse au mérite n’existe en Licence : toutes les aides de premier cycle sont fondées sur le besoin',
          'Understand that no merit scholarship exists at undergraduate level: all first-degree aid is need-based',
        ],
        [
          'Satisfaire les exigences d’examen : WASSCE avec au moins C6 dans chacune des six matières, ou IGCSE et A-Level, IB, diplôme américain/canadien, baccalauréat français, ou équivalent approuvé par la GTEC',
          'Meet the examination requirements: WASSCE with at least C6 in each of the six subjects, or IGCSE and A-Levels, IB, American/Canadian diploma, French Baccalauréat, or an equivalent approved by the GTEC',
        ],
        [
          'Candidats internationaux : fournir une traduction certifiée des relevés et une preuve de maîtrise de l’anglais (TOEFL, IELTS) si l’anglais n’était pas la langue d’enseignement',
          'International applicants: provide certified translations of transcripts and evidence of English proficiency (TOEFL, IELTS) if English was not the language of instruction',
        ],
        [
          'Déposer dans un tour normal : le portail indique que les candidatures avec bourse ne sont pas acceptées pendant la période « Late Admissions »',
          'Apply within a normal round: the portal states that scholarship applications are not accepted during the Late Admissions period',
        ],
      ],
      requirements: [
        [
          'Formulaire de candidature en ligne complété puis soumis sur le portail officiel',
          'Online application form completed and then submitted on the official portal',
        ],
        [
          'Formulaire d’aide financière rempli avec le dossier d’admission, indiquant le montant d’aide demandé',
          'Financial aid form completed with the admissions file, stating the amount of assistance required',
        ],
        [
          'Relevés du lycée sur au moins six trimestres et résultats de l’examen de fin d’études',
          'High-school transcripts covering at least six terms and the final examination results',
        ],
        [
          'Traduction certifiée en anglais des documents rédigés dans une autre langue',
          'Certified English translation of documents issued in another language',
        ],
        [
          'Preuve de maîtrise de l’anglais lorsque le lycée n’était pas anglophone',
          'Evidence of English proficiency when the high school was not English-medium',
        ],
        [
          'Frais de dossier de 25 US$ pour les candidats internationaux (150 GHs pour les Ghanéens), avec exonération possible sur demande motivée',
          'Application fee of US$25 for international applicants (GHs150 for Ghanaians), with a waiver possible on a justified request',
        ],
      ],
      steps: [
        [
          'Choisir son tour et sa rentrée',
          'Choose your round and intake',
          'Comparer les quatre tours de dépôt (juin, août, octobre, décembre) et les deux rentrées, septembre ou janvier ; l’université encourage les candidats à une bourse à postuler tôt.',
          'Compare the four application rounds (June, August, October, December) and the two intakes, September or January; the university encourages scholarship applicants to apply sooner.',
        ],
        [
          'Déposer la candidature en ligne',
          'Submit the online application',
          'Créer un compte sur le portail d’admission, téléverser toutes les pièces demandées puis appuyer sur « submit » : le comité n’évalue aucun dossier avant cette soumission.',
          'Create an account on the admissions portal, upload every requested document then press “submit”: the committee evaluates no file before that submission.',
        ],
        [
          'Compléter le formulaire d’aide financière',
          'Complete the financial aid form',
          'Joindre le formulaire d’aide au dossier d’admission et indiquer le montant nécessaire ; l’université demande de remplir ce formulaire pour pouvoir recevoir une aide.',
          'Attach the financial aid form to the admissions file and state the amount required; the university asks applicants to complete this form in order to receive assistance.',
        ],
        [
          'Passer l’entretien et attendre la décision',
          'Interview and await the decision',
          'Les candidats présélectionnés sont convoqués en entretien, où des questions sur le besoin financier peuvent être posées ; l’aide est attribuée selon les preuves fournies et les fonds disponibles.',
          'Shortlisted applicants are invited to an interview, where questions on financial need may be asked; aid is awarded on the basis of the evidence provided and the funds available.',
        ],
      ],
      cycle: {
        academicYear: '2027-2028',
        status: 'forecast',
        dateConfidence: 'estimated',
        estimatedOpenAt: '2026-09-01T00:00:00.000Z',
        estimatedCloseAt: '2027-08-15T00:00:00.000Z',
        sourceUrl: 'https://ashesi.edu.gh/our-two-intake-cycle/',
      },
      sources: {
        overview: 'https://ashesi.edu.gh/scholarships/',
        eligibility:
          'https://admissions.ashesi.edu.gh/courses/course/257-first-year-student',
        benefits: 'https://ashesi.edu.gh/scholarships/',
        application: 'https://ashesi.edu.gh/how-to-apply/',
        cycle: 'https://ashesi.edu.gh/our-two-intake-cycle/',
      },
      tags: [
        'bachelor',
        'ghana',
        'ashesi',
        'university',
        'need-based',
        'rolling-admissions',
        'estimated-open-date',
      ],
      relatedFieldIds: ['d01', 'd02', 'd03', 'd07'],
      baseMatch: 80,
      checkedAt: '2026-10-24T07:11:00.000Z',
    }),
    record({
      id: 'alu_scholarship_2027',
      levels: ['bachelor'],
      name: [
        'Bourses et subventions ALU 2027–2028',
        'ALU Scholarships and Grants 2027–2028',
      ],
      country: ['rwa', 'Rwanda', 'Rwanda'],
      levelLabel: [
        'Licence de trois ans à Kigali',
        'Three-year Bachelor in Kigali',
      ],
      fundingLabel: [
        'Exonération des frais de scolarité, jusqu’au financement complet',
        'Tuition fee waiver, up to full funding',
      ],
      fundingType: 'partially_funded',
      applicationRequirement: 'separate_application',
      deadlineLabel: [
        'Rentrée de septembre 2027 — échéance non publiée, estimée vers la mi-juin 2027 ; dépôt en continu',
        'September 2027 intake — deadline not yet published, estimated around mid-June 2027; rolling applications',
      ],
      description: [
        'Aide financière propre à l’African Leadership University : les ALU Grants exonèrent les frais de scolarité, et des bourses complètes financées avec des partenaires couvrent la scolarité et un soutien complémentaire. Les candidatures sont examinées en continu, avec une échéance par rentrée ; la seule échéance publiée à ce jour est le 30 novembre 2026 pour la rentrée de janvier 2027. Les rentrées et échéances publiées concernent le campus de Kigali ; ALC Maurice n’accueille pas de nouvelle cohorte de Licence pour l’instant.',
        'The African Leadership University’s own financial aid: ALU Grants waive tuition fees, and full-ride scholarships funded with partners cover tuition plus additional support. Applications are reviewed on a rolling basis with one deadline per intake; the only deadline currently published is 30 November 2026 for the January 2027 intake. The published intakes and deadlines concern the Kigali campus; ALC Mauritius is not welcoming a new undergraduate cohort for now.',
      ],
      advantages: [
        [
          'ALU Grant : exonération des frais de scolarité appliquée directement comme remise sur la facture',
          'ALU Grant: tuition fee waiver applied directly as a reduction on the bill',
        ],
        [
          'Exonération maintenue pendant la durée minimale d’obtention du diplôme',
          'Waiver held for the minimum degree completion time',
        ],
        [
          'Bourses complètes couvrant la totalité de la scolarité et un soutien financier complémentaire pendant le parcours',
          'Full-ride scholarships covering full tuition and additional financial support throughout the journey',
        ],
        [
          'Éligibilité à l’aide vérifiée dans la même candidature, à l’étape « Finances », qui indique si l’on peut demander une aide financière ALU',
          'Aid eligibility checked inside the same application, at the Finances stage, which shows whether you qualify to apply for ALU financial aid',
        ],
        [
          'Frais de scolarité de référence bas : environ 3 000 US$ par an, 4 000 US$ pour International Business & Trade',
          'Low reference tuition: about US$3,000 per year, US$4,000 for International Business & Trade',
        ],
        [
          'Aucun frais d’intermédiaire : ALU ne facture pas de service de candidature et ne mandate aucun agent payant',
          'No intermediary fee: ALU charges nothing for application services and authorises no paid agent',
        ],
      ],
      eligibility: [
        [
          'Satisfaire d’abord les critères d’admission d’ALU pour l’un des cursus de Licence',
          'First meet ALU’s admission criteria for one of the Bachelor programmes',
        ],
        [
          'Ne pas pouvoir financer la scolarité autrement, et le démontrer par des justificatifs recevables',
          'Be otherwise unable to afford ALU tuition, and demonstrate it with acceptable supporting documents',
        ],
        [
          'Justifier d’un besoin financier et d’un désavantage socio-économique vérifiables',
          'Evidence verifiable financial need and socio-economic disadvantage',
        ],
        [
          'Pour les bourses complètes : présenter des résultats aux examens nationaux d’au moins « B »',
          'For full-ride scholarships: show national exam results of at least a B',
        ],
        [
          'Pour les bourses complètes : condition d’âge publiée à 23 ans ou moins par le centre d’aide, et à 26 ans ou moins sur la page Financial Aid — vérifier auprès de l’université avant de postuler',
          'For full-ride scholarships: the age condition is published as 23 and under on the help centre and as 26 and under on the Financial Aid page — check with the university before applying',
        ],
        [
          'Démontrer un potentiel de leadership et un engagement communautaire actif ; les femmes, réfugiés, personnes déplacées et personnes en situation de handicap sont particulièrement encouragés',
          'Show leadership potential and active community involvement; women, refugees, displaced persons and people with disabilities are particularly encouraged',
        ],
      ],
      requirements: [
        [
          'Candidature unique en ligne en trois étapes : Introduction, informations complémentaires, Finances',
          'Single online application in three stages: Introduction, additional information, Finances',
        ],
        [
          'Relevés scolaires et résultats des examens nationaux de fin d’études',
          'School transcripts and national school-leaving examination results',
        ],
        [
          'Justificatifs de revenus et de situation socio-économique de la famille',
          'Evidence of family income and socio-economic situation',
        ],
        [
          'Informations financières renseignées à l’étape « Finances », qui détermine l’éligibilité à l’aide',
          'Financial information filled in at the Finances stage, which determines aid eligibility',
        ],
        [
          'Documents téléversés dans le portail officiel de candidature',
          'Documents uploaded in the official application portal',
        ],
        [
          'Choix du cursus (Software Engineering, Entrepreneurial Leadership ou International Business & Trade) et de la rentrée visée',
          'Choice of programme (Software Engineering, Entrepreneurial Leadership or International Business & Trade) and of the target intake',
        ],
      ],
      steps: [
        [
          'Vérifier son admissibilité',
          'Check admissibility',
          'Confirmer que le profil scolaire satisfait les critères d’admission d’ALU, condition préalable à toute demande d’aide financière.',
          'Confirm that the academic profile meets ALU’s admission criteria, a precondition for any financial aid request.',
        ],
        [
          'Déposer la candidature en trois étapes',
          'Submit the three-stage application',
          'Compléter l’introduction, puis les informations complémentaires et les téléversements de documents dans le portail officiel.',
          'Complete the introduction, then the additional information and document uploads in the official portal.',
        ],
        [
          'Renseigner l’étape Finances',
          'Complete the Finances stage',
          'Détailler la situation financière de la famille : c’est cette étape qui évalue le coût supportable et l’éligibilité aux ALU Grants et aux bourses complètes.',
          'Detail the family’s financial situation: this is the stage that assesses the affordable cost and the eligibility for ALU Grants and full-ride scholarships.',
        ],
        [
          'Suivre la décision et sécuriser sa place',
          'Track the decision and secure a seat',
          'Les décisions sont rendues en général sous deux semaines ; le dépôt est continu mais les places et les aides sont limitées par rentrée, un dossier tardif peut être reporté à la rentrée suivante.',
          'Decisions are usually issued within two weeks; applications are rolling but seats and aid slots are limited per intake, and a late file may be moved to the next intake.',
        ],
      ],
      cycle: {
        academicYear: '2027-2028',
        status: 'forecast',
        dateConfidence: 'estimated',
        estimatedOpenAt: '2026-12-01T00:00:00.000Z',
        estimatedCloseAt: '2027-06-18T00:00:00.000Z',
        sourceUrl: 'https://www.alueducation.com/apply-now/',
      },
      sources: {
        overview: 'https://www.alueducation.com/financial-aid-at-alu/',
        eligibility:
          'https://help.alueducation.com/support/solutions/articles/204000012922-who-is-eligible-for-financial-aid-',
        benefits: 'https://www.alueducation.com/financial-aid-at-alu/',
        application: 'https://www.alueducation.com/apply-now/',
        cycle: 'https://www.alueducation.com/apply-now/',
      },
      tags: [
        'bachelor',
        'rwanda',
        'alu',
        'university',
        'need-based',
        'rolling-admissions',
        'estimated-open-date',
      ],
      relatedFieldIds: ['d01', 'd02', 'd07'],
      baseMatch: 80,
      checkedAt: '2026-10-24T07:14:00.000Z',
    }),
    record({
      id: 'auc_excellence_2027',
      levels: ['bachelor'],
      name: [
        'Bourse d’excellence AUC 2027–2028',
        'AUC Excellence Scholarship 2027–2028',
      ],
      country: ['egy', 'Égypte', 'Egypt'],
      levelLabel: [
        'Licence au Caire, candidats internationaux inclus',
        'Undergraduate degree in Cairo, international applicants included',
      ],
      fundingLabel: [
        '20 % à 100 % des frais de scolarité',
        '20% to 100% of tuition fees',
      ],
      fundingType: 'partially_funded',
      deadlineLabel: [
        'Ouvert — rentrée Fall 2027 : priorité pour les bourses les plus élevées en déposant admission, bourse et dossier de besoin financier avant le 1er février 2027 (admission anticipée) ; admission régulière jusqu’au 1er juin 2027',
        'Open — Fall 2027 intake: priority for the highest scholarship percentages when admission, scholarship and financial need applications are submitted by 1 February 2027 (early admission); regular admission until 1 June 2027',
      ],
      description: [
        'Programme de bourses d’excellence de l’American University in Cairo, ouvert aux candidats internationaux avec une catégorie « diversité internationale » dédiée. Les bourses reposent à la fois sur l’excellence et sur le besoin financier, et se cumulent jusqu’à 100 % des frais de scolarité. La page du programme, mise à jour le 15 octobre 2026, publie désormais les échéances de bourse Spring 2027 et Fall 2027, et la page des exigences de Licence publie le 1er novembre pour Spring 2027, le 1er février pour l’admission anticipée Fall 2027 et le 1er juin pour l’admission régulière Fall 2027.',
        'Excellence scholarship programme of the American University in Cairo, open to international applicants through a dedicated international diversity category. The scholarships are based on both excellence and financial need and combine up to 100% of tuition. The programme page, updated on 15 October 2026, now publishes the Spring 2027 and Fall 2027 scholarship deadlines, and the undergraduate requirements page publishes 1 November for Spring 2027, 1 February for Fall 2027 early admission and 1 June for Fall 2027 regular admission.',
      ],
      advantages: [
        [
          'Jusqu’à 100 % des frais de scolarité en cumulant plusieurs catégories de bourse',
          'Up to 100% of tuition fees by combining several scholarship categories',
        ],
        [
          'Catégorie réussite académique : couverture à partir de 20 %, jusqu’à 100 % pour les meilleurs résultats de chaque type de certificat',
          'Academic Achievement category: coverage from 20%, up to 100% for the highest-scoring top achievers in each certificate type',
        ],
        [
          'Catégorie diversité internationale : couverture jusqu’à 30 %, réservée aux candidats déposant comme étudiants internationaux',
          'International Diversity category: coverage up to 30%, reserved for applicants applying as international students',
        ],
        [
          'Catégorie talents : jusqu’à 30 % pour le sport, la musique, les arts de la scène et les arts',
          'Talents category: up to 30% for athletics, music, performing arts and arts',
        ],
        [
          'Catégorie leadership et service communautaire : jusqu’à 30 %',
          'Leadership and Community Service category: up to 30%',
        ],
        [
          'Catégorie majeures d’arts libéraux sélectionnées : jusqu’à 30 % (anthropologie, études arabes, égyptologie, littérature anglaise et comparée, cinéma, histoire, études du Moyen-Orient, musique, philosophie, sociologie, théâtre, arts visuels)',
          'Selected liberal arts majors category: up to 30% (Anthropology, Arabic Studies, Egyptology, English and Comparative Literature, Film, History, Middle East Studies, Music, Philosophy, Sociology, Theatre, Visual Arts)',
        ],
      ],
      eligibility: [
        [
          'Candidater à un cursus de Licence de l’AUC et cocher la case bourse dans la candidature d’admission en ligne',
          'Apply to an AUC undergraduate programme and check the scholarship box in the online admission application',
        ],
        [
          'Figurer parmi les meilleurs résultats de son type de certificat de fin d’études, la comparaison se faisant entre pairs du même certificat',
          'Rank among the top results for your school-leaving certificate type, the comparison being made against peers holding the same certificate',
        ],
        [
          'Pour la catégorie diversité internationale : déposer sa candidature à l’AUC en tant qu’étudiant international',
          'For the International Diversity category: apply to AUC as an international student',
        ],
        [
          'Répondre au double critère du programme : excellence et besoin financier, ces bourses étant décrites comme fondées sur le mérite et le besoin',
          'Meet the programme’s dual criterion: excellence and financial need, these scholarships being described as based on merit and need',
        ],
        [
          'Candidats en transfert : avoir validé moins de 60 crédits, soit moins de deux ans dans une université accréditée',
          'Transfer applicants: have completed fewer than 60 credit hours, that is less than two years in an accredited university',
        ],
        [
          'Satisfaire les exigences d’anglais académique par TOEFL international, IELTS académique ou Duolingo de moins de deux ans, sans exemption liée à la nationalité ou à un lycée anglophone',
          'Meet the academic English requirement with an International TOEFL, Academic IELTS or Duolingo test taken less than two years earlier, with no exemption based on citizenship or an English-medium high school',
        ],
      ],
      requirements: [
        [
          'Formulaire d’admission en ligne, avec la case bourse cochée dans la section dédiée',
          'Online admission form, with the scholarship box checked in the dedicated section',
        ],
        [
          'Formulaire de bourse distinct, dont le lien est envoyé par courriel après la soumission du dossier d’admission',
          'Separate scholarship form, whose link is emailed after the admission file is submitted',
        ],
        [
          'Relevés et résultats officiels du certificat de fin d’études, téléversés dans le portail et non par courriel',
          'Official transcripts and school-leaving certificate results, uploaded in the portal and not sent by email',
        ],
        [
          'Déclaration personnelle rédigée par le candidat lui-même, soumise à un contrôle anti-plagiat',
          'Personal statement written by the applicant themselves, checked for plagiarism',
        ],
        [
          'Deux lettres de recommandation obligatoires, rédigées par des enseignants ou conseillers du lycée et envoyées directement à l’AUC',
          'Two mandatory recommendation letters, written by high-school teachers or counsellors and sent directly to AUC',
        ],
        [
          'Preuve officielle d’anglais académique : TOEFL envoyé au code AUC 0903, IELTS avec numéro TRF, ou Duolingo transmis directement',
          'Official academic English evidence: TOEFL sent to AUC code 0903, IELTS including the TRF number, or Duolingo sent directly',
        ],
      ],
      steps: [
        [
          'Préparer les preuves d’excellence',
          'Prepare the evidence of excellence',
          'Rassembler relevés, résultats de certificat, test d’anglais, déclaration personnelle, référents et pièces justifiant talents, leadership ou service communautaire.',
          'Gather transcripts, certificate results, English test, personal statement, referees and evidence of talents, leadership or community service.',
        ],
        [
          'Déposer la candidature d’admission',
          'Submit the admission application',
          'Remplir le formulaire d’admission en ligne et cocher impérativement la case bourse : sans cette case, aucune bourse AUC ne pourra être examinée ensuite.',
          'Complete the online admission form and make sure to check the scholarship box: without it, no AUC scholarship can be considered later.',
        ],
        [
          'Compléter le formulaire de bourse',
          'Complete the scholarship form',
          'Ouvrir le lien reçu par courriel, cocher la case de candidature aux bourses AUC et téléverser les documents demandés par catégorie.',
          'Open the link received by email, check the AUC scholarships application box and upload the documents requested for each category.',
        ],
        [
          'Viser l’échéance anticipée',
          'Target the early deadline',
          'Déposer avant l’échéance d’admission anticipée pour concourir aux pourcentages les plus élevés ; les dossiers reçus après l’échéance régulière passent en liste d’attente selon les places disponibles.',
          'Apply before the early admission deadline to compete for the highest coverage percentages; files received after the regular deadline go on a waiting list depending on available slots.',
        ],
      ],
      cycle: {
        academicYear: '2027-2028',
        // Ouvert : la page Excellence (mise à jour le 06/10/2026) publie les
        // échéances bourse Fall 2027 et le portail de candidature est actif.
        // Aucune date d'ouverture publiée — omise plutôt qu'inventée.
        status: 'open',
        dateConfidence: 'confirmed',
        closesAt: '2027-06-01T00:00:00.000Z',
        sourceUrl: 'https://www.aucegypt.edu/admissions/undergraduate',
      },
      sources: {
        overview: 'https://www.aucegypt.edu/admissions/scholarships',
        eligibility: 'https://www.aucegypt.edu/admissions/undergraduate',
        benefits:
          'https://www.aucegypt.edu/admissions/tuition-and-financial-assistance',
        application:
          'https://www.aucegypt.edu/admissions/scholarships/excellence-program',
        cycle: 'https://www.aucegypt.edu/admissions/undergraduate',
      },
      tags: [
        'bachelor',
        'egypt',
        'auc',
        'university',
        'merit-and-need',
        'tuition',
        'open',
      ],
      relatedFieldIds: [
        'd01',
        'd02',
        'd03',
        'd05',
        'd06',
        'd07',
        'd09',
        'd11',
      ],
      baseMatch: 79,
      checkedAt: '2026-10-24T07:14:00.000Z',
    }),
  ];
