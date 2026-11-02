import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';
import { buildVerifiedScholarshipRecord as record } from './scholarship-catalog.record-builder';

/**
 * Mastercard Foundation Scholars Program and Southern-African university
 * routes, verified against the institutions' own sites on 10 August 2026.
 *
 * Two caveats shared by the three records:
 *
 * 1. Southern-hemisphere calendar. The South African academic year IS a
 *    calendar year starting in January/February, so the campaign that a student
 *    must catch in mid-2026 leads to the January 2027 intake. The schema forces
 *    `academicYear` into a YYYY-YYYY shape, so the January–December 2027 South
 *    African year is encoded as '2027-2028'; every deadline label and
 *    description names the January 2027 intake explicitly so no reader
 *    transposes a European September calendar onto it.
 *
 * 2. No confirmed opening date anywhere in this wave. UP publishes dated
 *    closing dates but no 2027 opening date (and two UP pages disagree on when
 *    the MCFSP window opens); the Mastercard Foundation states in its own FAQ
 *    that each partner sets its own deadline; UCT's latest published notice on
 *    its international scholarship is that the call "will not open". All three
 *    cycles are therefore `estimated`, none is `open`, and each deadline label
 *    separates what is officially published from what is projected.
 */
export const VERIFIED_MASTERCARD_SOUTHERN_AFRICA_RECORDS_V1: VerifiedScholarshipCatalogRecord[] = [
  record({
    id: 'mastercard_foundation_scholars_2027',
    levels: ['secondary', 'bachelor', 'master'],
    name: ['Mastercard Foundation Scholars Program 2027–2028', 'Mastercard Foundation Scholars Program 2027–2028'],
    country: ['int', 'Réseau international d’universités partenaires', 'International network of partner universities'],
    levelLabel: ['Secondaire, Licence ou Master selon le partenaire — pas de doctorat', 'Secondary, Bachelor or Master depending on the partner — no doctorate'],
    fundingLabel: ['Financement complet et accompagnement, barème fixé par le partenaire', 'Comprehensive funding and support, terms set by the partner'],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'Aucune date limite unique : la FAQ officielle indique que chaque partenaire fixe la sienne ; la fenêtre affichée ici est purement indicative',
      'No single deadline: the official FAQ states each partner sets its own; the window shown here is indicative only',
    ],
    description: [
      'Ce n’est pas une bourse à laquelle on postule directement : la Fondation écrit que le programme « est géré par nos universités partenaires et organisations non gouvernementales » et que « le processus de candidature et la décision sont gérés par nos partenaires ». Il n’existe donc ni formulaire central, ni date limite unique, ni comité Mastercard auquel écrire. On postule à un établissement partenaire, qui publie seul ses critères, ses pièces et ses dates. Pour un cas concret et daté, voir la fiche University of Pretoria — Mastercard Foundation Scholars Program.',
      'This is not a scholarship you apply to directly: the Foundation states the program is “managed through our partner universities and non-governmental organizations” and that “the application process and decision-making are managed by our partners”. There is no central form, no single deadline and no Mastercard committee to write to. You apply to a partner institution, which alone publishes its criteria, documents and dates. For a concrete, dated case, see the University of Pretoria — Mastercard Foundation Scholars Program record.',
    ],
    advantages: [
      ['Frais de scolarité pris en charge par l’établissement partenaire', 'Tuition fees covered through the partner institution'],
      ['Logement, livres et autres fournitures scolaires', 'Accommodation, books and other scholastic materials'],
      ['Billet d’avion retour vers le pays d’origine lorsque nécessaire', 'Return air ticket to the country of origin where necessary'],
      ['Soutien psychosocial, mentorat et accompagnement académique', 'Psychosocial support, mentoring and academic support'],
      ['Développement du leadership et accès au réseau des Scholars et Alumni', 'Leadership development and access to the Scholars and Alumni network'],
      ['Remboursement des frais de dossier exigés par certaines universités si le candidat est sélectionné', 'Reimbursement of admission application fees charged by some universities if the candidate is selected'],
    ],
    eligibility: [
      ['Être un jeune Africain — le programme cible en priorité les jeunes Africains — porteur d’un engagement éthique et communautaire', 'Be a young African — the program primarily targets young Africans — with a commitment to ethical leadership and community building'],
      ['Licence : avoir 29 ans ou moins au moment de la candidature ; Master : 35 ans ou moins', 'Bachelor: be 29 years old or under when applying; Master: 35 years old or under'],
      ['Aucun financement de doctorat : le programme couvre le secondaire, la Licence et le Master', 'No doctoral funding: the program covers the secondary, undergraduate and Master levels'],
      ['Avoir des ambitions académiques qui dépassent ses ressources financières', 'Have academic ambitions that exceed your financial resources'],
      ['Priorité affichée aux femmes, réfugiés, personnes déplacées de force, personnes en situation de handicap et autres communautés sous-représentées', 'Stated priority for women, refugees, forcibly displaced persons, persons with a disability and other underrepresented communities'],
      ['Satisfaire en plus les critères propres au partenaire : l’admission dans un établissement partenaire ne garantit pas la bourse', 'Also meet the partner’s own criteria: admission to a partner institution does not guarantee the scholarship'],
    ],
    requirements: [
      ['Dossier d’admission complet de l’établissement partenaire choisi, chaque partenaire exigeant des pièces différentes', 'Complete admission file for the chosen partner institution, as each partner requires different documents'],
      ['Lettres de recommandation demandées par la plupart des universités, à solliciter tôt et parfois déposées en ligne par le référent', 'Recommendation letters required by most universities, to be requested early and sometimes submitted online by the referee'],
      ['SAT et/ou TOEFL ou IELTS pour les partenaires nord-américains ; certains partenaires basés en Afrique ne les exigent pas', 'SAT and/or TOEFL or IELTS for North American partners; some Africa-based partners do not require them'],
      ['Le dossier propre au programme chez le partenaire, selon les instructions publiées sur sa page MCFSP', 'The partner’s own program file, following the instructions published on its MCFSP page'],
      ['Éléments montrant que les ressources financières ne suffisent pas, selon ce que demande le partenaire', 'Evidence that financial resources are insufficient, as required by the partner'],
      ['Respect strict de l’échéance du partenaire : un dossier tardif ou incomplet n’est pas examiné', 'Strict compliance with the partner’s deadline: a late or incomplete application is not considered'],
    ],
    steps: [
      ['Choisir un établissement partenaire', 'Choose a partner institution', 'Utiliser l’annuaire officiel « Where to apply » et ses filtres pays, niveau d’étude et fenêtre de candidature ouverte ou fermée.', 'Use the official “Where to apply” directory and its country, level-of-study and open/closed application-window filters.'],
      ['Lire la page MCFSP du partenaire', 'Read the partner’s MCFSP page', 'Chaque partenaire publie sur son propre site ses critères, pièces, échéances et instructions : c’est la seule source de dates fiable.', 'Each partner publishes its criteria, documents, deadlines and instructions on its own site: that is the only reliable source of dates.'],
      ['Obtenir d’abord l’admission', 'Secure admission first', 'Tout candidat doit satisfaire les exigences d’admission de l’université avant d’être considéré ; passer les tests requis plusieurs mois avant l’échéance.', 'Every applicant must meet the university admission requirements before being considered; sit any required tests several months before the deadline.'],
      ['Déposer le dossier chez le partenaire', 'Submit the file to the partner', 'Suivre les instructions du partenaire, mobiliser les référents tôt et respecter son échéance ; postuler à plusieurs partenaires est permis mais coûteux en travail.', 'Follow the partner’s instructions, engage referees early and meet its deadline; applying to several partners is allowed but takes a great deal of effort.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-08-10T00:00:00.000Z',
      estimatedCloseAt: '2027-06-30T23:59:59.000Z',
      sourceUrl: 'https://mastercardfdn.org/en/frequently-asked-questions/',
    },
    sources: {
      overview: 'https://mastercardfdn.org/en/what-we-do/our-programs/mastercard-foundation-scholars-program/',
      eligibility: 'https://mastercardfdn.org/en/articles/becoming-a-mastercard-foundation-scholar/',
      benefits: 'https://mastercardfdn.org/en/frequently-asked-questions/',
      application: 'https://mastercardfdn.org/en/what-we-do/our-programs/mastercard-foundation-scholars-program/where-to-apply/',
      cycle: 'https://mastercardfdn.org/en/frequently-asked-questions/',
    },
    tags: ['secondary', 'bachelor', 'master', 'africa', 'mastercard-foundation', 'partner-managed', 'no-central-deadline', 'fully-funded'],
    relatedFieldIds: ['d01', 'd02', 'd03', 'd04', 'd05', 'd06', 'd07', 'd08', 'd09', 'd10', 'd11', 'd12'],
    baseMatch: 76,
    checkedAt: '2026-10-24T07:13:00.000Z',
  }),
  record({
    id: 'uct_international_refugee_2027',
    // Catalogue 1.5.0 : le libellé dit « Honours, Master ou Doctorat » et
    // l'éligibilité cite la « 4e année de Doctorat » — le niveau doctoral
    // manquait à la liste structurée.
    levels: ['master', 'doctorate'],
    name: ['Bourses UCT pour étudiants internationaux et réfugiés 2027', 'UCT International and Refugee Scholarships 2027'],
    country: ['zaf', 'Afrique du Sud — University of Cape Town', 'South Africa — University of Cape Town'],
    levelLabel: ['Postgrade uniquement : Honours, Master ou Doctorat', 'Postgraduate only: Honours, Master’s or Doctoral'],
    fundingLabel: ['Complément partiel au coût des études', 'Partial contribution towards the cost of attendance'],
    fundingType: 'partially_funded',
    deadlineLabel: [
      'Aucun appel 2027 publié au 29 septembre 2026 — le dernier avis officiel indique que l’appel 2026 « n’ouvrira pas » faute de financement ; la fenêtre affichée est une projection',
      'No 2027 call published as of 29 September 2026 — the latest official notice states the call for 2026 “will not open, due to funding constraints”; the window shown is a projection',
    ],
    description: [
      'Nombre limité de bourses annuelles pour étudiants internationaux et réfugiés, en postgrade et dans toute discipline à UCT, avec un seul appel par an. Deux avertissements figurent noir sur blanc sur la page officielle : ces bourses sont un simple complément au coût des études, et le candidat doit déjà avoir les moyens de financer ses études. Au 29 septembre 2026 la page n’annonce toujours aucun appel 2027 : le dernier avis publié est que l’appel 2026 n’ouvrira pas faute de financement. À traiter comme une piste secondaire, derrière le NRF et les financements de département.',
      'A limited number of scholarships is available annually to international and refugee students for postgraduate study in any discipline at UCT, with only one call each year. Two warnings appear plainly on the official page: these awards are merely supplementary as a contribution towards the cost of attendance, and applicants must already have the means to fund their studies. As of 29 September 2026 the page still announces no 2027 call: the latest published notice is that the 2026 call will not open due to funding constraints. Treat this as a secondary route, behind NRF and departmental funding.',
    ],
    advantages: [
      ['Complément financier annuel vers le coût des études, attribué sur une base concurrentielle', 'Annual financial contribution towards the cost of attendance, awarded on a competitive basis'],
      ['Ouvert à toute discipline en postgrade à UCT', 'Open to postgraduate study in any discipline at UCT'],
      ['Renouvelable pour la durée du cursus sous réserve de progrès satisfaisants et de fonds disponibles', 'Renewable for the duration of the programme subject to satisfactory progress and availability of funds'],
      ['Durée d’attribution : un an en Honours, les deux premières années de Master, les trois premières de Doctorat', 'Tenure: one year at Honours level, the first two years of a Master’s, the first three of a Doctoral degree'],
      ['Le pays d’origine du candidat n’a aucune incidence sur l’attribution', 'The applicant’s country of origin has no bearing on the award'],
      ['Accompagnement du Postgraduate Funding Office, avec rendez-vous individuel possible et tableau d’affichage des financements externes', 'Support from the Postgraduate Funding Office, including one-on-one sessions and a noticeboard of external funding'],
    ],
    eligibility: [
      ['Être étudiant international ou réfugié candidat à un cursus postgrade à UCT : ces bourses ne financent pas la Licence', 'Be an international or refugee applicant to a postgraduate programme at UCT: these awards do not fund undergraduate study'],
      ['Avoir postulé à une admission à temps plein via l’Admissions Office ou le bureau de faculté, sinon la demande de financement n’est pas examinée', 'Have applied for full-time admission through the UCT Admissions Office or the Faculty Office, otherwise the funding application cannot be considered'],
      ['La préférence est donnée aux candidats les plus avancés dans leur parcours', 'Preference is given to senior candidates'],
      ['Fournir une preuve du statut de réfugié lorsque ce statut est invoqué', 'Provide proof of refugee status when that status is claimed'],
      ['Disposer par ailleurs des moyens de financer ses études : la bourse ne couvre pas le coût total', 'Otherwise have the means to fund your studies: the award does not cover the full cost'],
      ['Exclusions publiées : pas de soutien en 3e année de Master ou au-delà ni en 4e année de Doctorat ou au-delà, et emploi à temps plein de plus de 20 heures par semaine rendant inéligible', 'Published exclusions: no support from the 3rd year of a Master’s or the 4th year of a Doctoral degree onwards, and full-time employment of more than 20 hours a week makes an applicant ineligible'],
    ],
    requirements: [
      ['Le formulaire spécifique aux candidats internationaux : le formulaire de financement postgrade en ligne est réservé aux Sud-Africains et résidents permanents', 'The application form specific to international applicants: the online postgraduate funding form is reserved for South African citizens and permanent residents'],
      ['Candidature d’admission à temps plein déposée auprès d’UCT', 'A full-time admission application lodged with UCT'],
      ['Preuve du statut de réfugié le cas échéant', 'Proof of refugee status where applicable'],
      ['Relevés et pièces justificatives exigés par l’appel et le manuel de financement', 'Transcripts and supporting documents required by the call and the funding handbook'],
      ['Pour un Master ou Doctorat de recherche, un superviseur et un projet identifiés, idéalement au moins sept mois avant le début des études', 'For a research Master’s or Doctoral degree, an identified supervisor and project, ideally at least seven months before the degree starts'],
      ['Un dossier complet déposé à la date exacte : les dossiers tardifs ou incomplets ne sont pas examinés', 'A complete file submitted by the exact closing date: late or incomplete applications are not considered'],
    ],
    steps: [
      ['Vérifier l’état de l’appel', 'Check the state of the call', 'La page officielle porte encore l’avis selon lequel l’appel 2026 n’ouvrira pas faute de financement : ne rien préparer avant d’y voir un appel 2027 publié.', 'The official page still carries the notice that the 2026 call will not open due to funding constraints: prepare nothing until a published 2027 call appears there.'],
      ['Postuler à l’admission UCT', 'Apply for UCT admission', 'Déposer une candidature d’admission à temps plein : aucun comité de financement n’examine un dossier sans candidature d’admission, et le calendrier officiel des admissions clôt le postgrade au 30 septembre 2026 pour 2027.', 'Lodge a full-time admission application: no funding committee considers a file without one, and the official admissions calendar closes postgraduate applications on 30 September 2026 for 2027.'],
      ['Mobiliser le département et le PGFO', 'Engage the department and the PGFO', 'Contacter le chef de département et un superviseur pour les financements liés à un projet, puis le Postgraduate Funding Office et son tableau d’affichage.', 'Contact the head of department and a prospective supervisor about project-linked funding, then the Postgraduate Funding Office and its noticeboard.'],
      ['Viser d’abord les alternatives datées', 'Target the dated alternatives first', 'Le NRF ferme normalement en juin/juillet pour le Master et en octobre pour l’Honours, et la plupart des financements UCT avant la mi-novembre, échéance habituelle du 10 novembre.', 'The NRF normally closes in June/July for Master’s and in October for Honours, and most UCT awards before mid-November, the usual deadline being 10 November.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      status: 'suspended',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-09-01T00:00:00.000Z',
      estimatedCloseAt: '2026-11-10T21:59:00.000Z',
      sourceUrl: 'https://uct.ac.za/students/fees-funding-postgraduate-degree-funding-bursaries-scholarships/international-and-refugee-scholarships',
    },
    sources: {
      overview: 'https://uct.ac.za/students/fees-funding-postgraduate-degree-funding-bursaries-scholarships/international-and-refugee-scholarships',
      eligibility: 'https://www.uct.ac.za/sites/default/files/media/documents/uct-handbook-14-2027-final.pdf',
      benefits: 'https://uct.ac.za/students/fees-funding-postgraduate-degree-funding-bursaries-scholarships/international-and-refugee-scholarships',
      application: 'https://uct.ac.za/students/fees-funding-postgraduate-degree-funding/applications-and-requirements',
      cycle: 'https://uct.ac.za/students/fees-funding-postgraduate-degree-funding-bursaries-scholarships/international-and-refugee-scholarships',
    },
    tags: ['master', 'doctorate', 'south-africa', 'uct', 'international-students', 'refugees', 'no-published-call', 'partially-funded'],
    relatedFieldIds: ['d01', 'd02', 'd03', 'd04', 'd05', 'd06', 'd07', 'd08', 'd09', 'd10', 'd11', 'd12'],
    baseMatch: 70,
    checkedAt: '2026-10-24T07:13:00.000Z',
  }),
  record({
    id: 'up_mastercard_scholars_2027',
    levels: ['bachelor', 'master'],
    name: ['University of Pretoria — Mastercard Foundation Scholars Program 2027', 'University of Pretoria — Mastercard Foundation Scholars Program 2027'],
    country: ['zaf', 'Afrique du Sud — University of Pretoria', 'South Africa — University of Pretoria'],
    levelLabel: ['Licence et première année de Master à temps plein à UP', 'Full-time Bachelor and first-year Master at UP'],
    fundingLabel: ['Financement complet avec accompagnement global', 'Comprehensive funding with wraparound support'],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'Clôturé — les candidatures pour la rentrée de janvier 2027 ont fermé (31 août 2026 en Licence, 30 septembre 2026 en postgrade) ; prochain cycle non publié',
      'Closed — applications for the January 2027 intake closed (31 August 2026 for undergraduate, 30 September 2026 for postgraduate); next cycle not published',
    ],
    description: [
      'Déclinaison concrète et actionnable du Mastercard Foundation Scholars Program, à UP depuis janvier 2014 et en phase 2 depuis décembre 2023. Le calendrier est sud-africain : la rentrée a lieu en janvier, donc les échéances tombent au milieu de l’année civile précédente, pas en septembre. L’ordre est imposé : il faut d’abord être admis à un diplôme UP — la page officielle indique une candidature jusqu’au 30 juin 2026 — puis envoyer le formulaire MCFSP 2027 à mcfsp@up.ac.za avant le 31 août 2026 en Licence ou le 30 septembre 2026 en postgrade. Un entretien précède toute admission au programme.',
      'The concrete, actionable route into the Mastercard Foundation Scholars Program, running at UP since January 2014 and in phase 2 since December 2023. The calendar is South African: the academic year starts in January, so deadlines fall in the middle of the preceding calendar year, not in September. The order is fixed: you must first be admitted to a UP degree — the official page states applications run until 30 June 2026 — then email the 2027 MCFSP form to mcfsp@up.ac.za by 31 August 2026 for undergraduate or 30 September 2026 for postgraduate. An interview precedes admission to the Program.',
    ],
    advantages: [
      ['Frais de scolarité intégraux', 'Full tuition fees'],
      ['Logement et repas en résidence UP ou en logement agréé par UP', 'Accommodation and meals in a UP residence or UP-accredited accommodation'],
      ['Allocation mensuelle modeste, fonds de démarrage la première année et frais de visa', 'A modest monthly stipend, first-year start-up funds and visa fees'],
      ['Manuels et fournitures scolaires, et couverture santé étudiante pendant toute la durée des études', 'Textbooks and school supplies, plus student medical aid cover for the duration of the studies'],
      ['Frais de voyage raisonnables, billet d’avion compris, entre le pays d’origine et Pretoria', 'Reasonable travel costs, flight ticket included, to and from the home country'],
      ['Un stage d’été en Afrique avec vol et allocation, cours et séminaires de leadership, conseil psychologique, tutorat, mentorat et conseiller étudiant dédié', 'One Africa-based summer internship with flight and stipend, leadership courses and seminars, counselling, tutoring, mentoring and a dedicated student services advisor'],
    ],
    eligibility: [
      ['Avoir postulé et été admis à un diplôme UP : seuls les étudiants admis en études à temps plein sont considérés', 'Have applied and been accepted to a UP degree: only students admitted to full-time study are considered'],
      ['Licence, ou première année de Master, à temps plein, pour une première année d’études en 2027, avec une moyenne (GPA) d’au moins 70 %, sans diplôme déjà obtenu au même niveau', 'Undergraduate, or first-year Master, full-time, starting a first year of study in 2027, with a grade point average (GPA) of at least 70% and no qualification already obtained at the same level'],
      ['Être un jeune Africain confronté à des barrières socio-économiques importantes, réfugiés, personnes déplacées internes et personnes en situation de handicap inclus', 'Be a young African facing significant socio-economic barriers, including refugees, internally displaced persons and persons with disabilities'],
      ['Ne pas pouvoir payer les frais complets, ni le candidat ni ses parents, tuteurs ou famille d’accueil', 'Be unable to pay the full fees, whether by the applicant or their parents, guardian or foster parents'],
      ['Démontrer des qualités de leadership et un engagement de service communautaire par des projets, activités scolaires ou organisations religieuses', 'Demonstrate leadership qualities and a commitment to community service through projects, school activities or religious organisations'],
      ['Facultés financées d’après les formulaires 2027 : Economic and Management Sciences, Natural and Agricultural Sciences, Engineering Built Environment and IT, Humanities (hors Psychologie en postgrade), Law (Licence : candidats de la SADC seulement) et Education', 'Faculties funded according to the 2027 forms: Economic and Management Sciences, Natural and Agricultural Sciences, Engineering Built Environment and IT, Humanities (excluding Psychology at postgraduate level), Law (undergraduate: SADC applicants only) and Education'],
    ],
    requirements: [
      ['Preuve d’admission à UP, au moins provisoire, et numéro d’étudiant UP', 'Evidence of UP admission, at least provisional, and the UP student number'],
      ['Le formulaire MCFSP 2027 correspondant, undergraduate ou postgraduate, téléchargé sur la page officielle de candidature', 'The matching 2027 MCFSP form, undergraduate or postgraduate, downloaded from the official application page'],
      ['Relevés et résultats académiques', 'Academic records and results'],
      ['Pièces attestant ce que la famille, les tuteurs ou la famille d’accueil peuvent payer : relevés bancaires, bulletins de salaire, documents de prêt', 'Documents supporting what the family, guardian or foster parents can afford to pay: bank statements, pay slips, loan documents'],
      ['Postgrade : vérification du diplôme par la South African Qualifications Authority', 'Postgraduate: verification of the qualification by the South African Qualifications Authority'],
      ['Passeport permettant une demande de visa sans délai, et toutes les pièces listées en première page du formulaire', 'A passport enabling a prompt visa application, and every document listed on the first page of the form'],
    ],
    steps: [
      ['Postuler d’abord à UP', 'Apply to UP first', 'Déposer la candidature d’admission en ligne ou en version papier ; la page officielle indique que les candidats éligibles peuvent postuler jusqu’au 30 juin 2026 pour la rentrée 2027.', 'Lodge the admission application online or on paper; the official page states eligible candidates can apply until 30 June 2026 for the 2027 intake.'],
      ['Télécharger le bon formulaire 2027', 'Download the right 2027 form', 'Sur la page officielle de candidature, prendre le formulaire undergraduate 2027 ou postgraduate 2027 selon le niveau visé.', 'On the official application page, take either the 2027 undergraduate or the 2027 postgraduate form, depending on the level.'],
      ['Envoyer le dossier à mcfsp@up.ac.za', 'Email the file to mcfsp@up.ac.za', 'Transmettre le formulaire et toutes les pièces avant le 31 août 2026 en Licence ou le 30 septembre 2026 en postgrade ; renseignements au +27 (0)12 420 4297.', 'Send the form and all supporting documents by 31 August 2026 for undergraduate or 30 September 2026 for postgraduate; enquiries on +27 (0)12 420 4297.'],
      ['Passer l’entretien et suivre la décision', 'Interview and track the decision', 'Tout candidat éligible passe un entretien avant l’admission au programme ; sans réponse d’UP, la candidature doit être considérée comme non retenue.', 'Every eligible candidate is interviewed before admission to the Program; with no reply from UP, the application should be considered unsuccessful.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      // CONFIRMÉ, et c'est la seule fiche du lot dans ce cas : UP publie ses
      // dates limites en clair sur /how-to-apply — « Undergraduate: 31 August
      // 2026, Postgraduate: 30 September 2026 » — et met en ligne les
      // formulaires nommés 2027. La campagne est réellement ouverte.
      //
      // Aucune date d'OUVERTURE n'est publiée (et deux pages UP se contredisent
      // à ce sujet, dont une périmée qui parle encore de la rentrée 2023) : on
      // ne l'invente pas, on l'omet. Le validateur l'autorise depuis que la
      // règle « confirmé ⇒ ouverture + clôture » a été relâchée à la seule
      // clôture — c'est la clôture qui est le fait actionnable.
      //
      // `closesAt` porte le 30 septembre (postgrade), échéance la plus tardive
      // des deux, pour ne pas retirer la bourse des listes des candidats en
      // postgrade dès le 31 août. Les deux dates sont dans le deadlineLabel.
      //
      // Passé `closed` le 30/09/2026 après 21:59 UTC, heure de la clôture
      // postgrade. Aucune source relue pour ce geste : c'est la date publiée
      // qui est échue, `checkedAt` ne bouge donc pas.
      status: 'closed',
      dateConfidence: 'confirmed',
      closesAt: '2026-09-30T21:59:00.000Z',
      sourceUrl: 'https://www.up.ac.za/mastercard-foundation-scholars-program/how-apply',
    },
    sources: {
      overview: 'https://www.up.ac.za/mastercard-foundation-scholars-program',
      eligibility: 'https://www.up.ac.za/mastercard-foundation-scholars-program/application-instructions',
      benefits: 'https://www.up.ac.za/mastercard-foundation-scholars-program/what-program-covers',
      application: 'https://www.up.ac.za/mastercard-foundation-scholars-program/how-apply',
      cycle: 'https://www.up.ac.za/mastercard-foundation-scholars-program/how-apply',
    },
    tags: ['bachelor', 'master', 'south-africa', 'university-of-pretoria', 'mastercard-foundation', 'january-intake', 'fully-funded'],
    relatedFieldIds: ['d02', 'd03', 'd07', 'd08', 'd09'],
    baseMatch: 80,
    // Relue au navigateur le 31/10/2026 (quatre pages up.ac.za et les deux
    // formulaires 2027, PDF de drupalwebprod-files.up.ac.za). Les pages up.ac.za
    // renvoient 403 (Cloudflare) à tout fetch automatisé : seule la lecture au
    // navigateur est possible. Les formulaires 2027 ont corrigé l'éligibilité
    // (moyenne de 70 %, première année de Master, liste de facultés, Droit
    // réservé à la SADC) ; voir docs/catalog-verification-2026-10-31.md.
    checkedAt: '2026-10-31T18:46:00.000Z',
  }),
];
