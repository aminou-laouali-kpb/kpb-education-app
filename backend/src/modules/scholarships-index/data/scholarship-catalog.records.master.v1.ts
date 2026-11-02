import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';
import { buildVerifiedScholarshipRecord as record } from './scholarship-catalog.record-builder';

/** Master-only opportunities verified against current official sources. */
export const VERIFIED_MASTER_RECORDS_V1: VerifiedScholarshipCatalogRecord[] = [
  record({
    id: 'chevening_2027',
    levels: ['master'],
    name: ['Bourse Chevening 2027–2028', 'Chevening Scholarship 2027–2028'],
    country: ['gbr', 'Royaume-Uni', 'United Kingdom'],
    levelLabel: ['Master d’un an', 'One-year Master'],
    fundingLabel: ['Financement complet', 'Fully funded'],
    fundingType: 'fully_funded',
    deadlineLabel: ['Clôturé — la campagne 2027–2028 a fermé le 6 octobre 2026 à 11 h UTC ; prochain cycle non annoncé', 'Closed — the 2027–2028 window closed on 6 October 2026 at 11:00 UTC; next cycle not yet announced'],
    description: [
      'Bourse internationale du gouvernement britannique pour futurs leaders admis à un Master éligible d’un an au Royaume-Uni. La campagne 2027-2028 est ouverte depuis le 4 août 2026 et la source officielle publie la clôture au 6 octobre 2026 à 11 h UTC.',
      'UK government international scholarship for future leaders admitted to an eligible one-year Master programme in the United Kingdom. The 2027-2028 campaign opened on 4 August 2026 and the official source publishes the 6 October 2026, 11:00 UTC closing time.',
    ],
    advantages: [
      ['Paiement des frais de scolarité', 'Payment of tuition fees'],
      ['Voyage aller-retour en classe économique depuis le pays de résidence, pour le boursier uniquement', 'Economy travel to and from the country of residence, for the scholar only'],
      ['Allocation mensuelle de vie, à un taux différent selon des études à Londres ou hors de Londres', 'Monthly personal living allowance, at a different rate inside or outside London'],
      ['Allocations d’arrivée et de départ et allocation complémentaire de voyage', 'Arrival and departure allowances plus a travel top-up allowance'],
      ['Coût d’une demande de visa et contribution jusqu’à 75 £ au test tuberculose lorsqu’il est requis', 'Cost of one visa application and a contribution of up to £75 for TB testing where required'],
      ['Programme d’engagement et réseau international Chevening', 'Chevening engagement programme and global network'],
    ],
    eligibility: [
      ['Être citoyen d’un pays ou territoire Chevening éligible et, pour une bourse d’un pays éligible à l’APD, résider dans un pays éligible à l’APD', 'Be a citizen of a Chevening-eligible country or territory and, for an award from an ODA-eligible country, be resident in an ODA-eligible country'],
      ['S’engager à retourner dans son pays pendant au moins deux ans après la bourse', 'Commit to return home for at least two years after the award'],
      ['Détenir une Licence permettant l’admission en Master au Royaume-Uni, achevée au moins deux ans avant la date limite, le certificat étant exigé au plus tard à l’entretien', 'Hold a Bachelor degree enabling UK Master admission, completed at least two years before the deadline, with the certificate required by the interview'],
      ['Avoir au moins deux ans d’expérience professionnelle après la Licence, équivalant à 2 800 heures', 'Have at least two years of post-Bachelor work experience, equivalent to 2,800 hours'],
      ['Postuler à trois cursus britanniques différents et éligibles et obtenir une offre inconditionnelle avant l’échéance du calendrier officiel', 'Apply to three different eligible UK courses and secure one unconditional offer by the official timeline deadline'],
      ['Ne relever d’aucune exclusion publiée : citoyenneté britannique, résidence au Royaume-Uni lors de la candidature, emploi public ou universitaire partenaire lié, bourse britannique antérieure', 'Not fall under published exclusions: British citizenship, UK residence at the time of application, linked government or partner-university employment, or a prior UK-government scholarship'],
    ],
    requirements: [
      ['Formulaire Chevening en ligne', 'Online Chevening application form'],
      ['Trois choix de cours éligibles', 'Three eligible course choices'],
      ['Parcours professionnel détaillé et réponses aux essais', 'Detailed work history and essay responses'],
      ['Deux référents ; lettres demandées selon le calendrier de sélection', 'Two referees; letters requested according to the selection timeline'],
      ['Passeport/pièce d’identité et diplômes/relevés selon les étapes', 'Passport/identity and degree/transcript evidence at the required stages'],
      ['Offre universitaire inconditionnelle avant l’échéance officielle finale', 'Unconditional university offer by the final official deadline'],
    ],
    steps: [
      ['Vérifier son éligibilité', 'Check eligibility', 'Confirmer pays, diplôme, expérience après Licence et engagement de retour.', 'Confirm country, degree, post-Bachelor experience and return commitment.'],
      ['Choisir trois Masters', 'Choose three Master courses', 'Rechercher trois cursus Chevening éligibles et préparer aussi leurs candidatures universitaires.', 'Research three eligible Chevening courses and prepare their separate university applications.'],
      ['Déposer Chevening', 'Submit Chevening', 'Compléter les expériences, essais, cours et référents avant le 6 octobre.', 'Complete work history, essays, course choices and referees before 6 October.'],
      ['Suivre les étapes', 'Follow later stages', 'Si présélectionné, téléverser références et documents au moins sept jours ouvrés avant l’entretien de mars-avril 2027, puis soumettre l’offre inconditionnelle avant le 8 juillet 2027 à 17 h BST.', 'If shortlisted, upload references and documents at least seven working days before the March–April 2027 interview, then submit the unconditional offer by 8 July 2027 at 17:00 BST.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      // Passé `closed` le 06/10/2026 après la clôture de 11:00 UTC ; aucune
      // relecture de source pour ce geste, `checkedAt` ne bouge pas.
      status: 'closed',
      dateConfidence: 'confirmed',
      opensAt: '2026-08-04T11:00:00.000Z',
      closesAt: '2026-10-06T11:00:00.000Z',
      sourceUrl: 'https://www.chevening.org/scholarships/application-timeline/',
    },
    sources: {
      overview: 'https://www.chevening.org/scholarships/',
      eligibility: 'https://www.chevening.org/resource-hub/guidance/eligibility/',
      benefits: 'https://www.chevening.org/faqs/what-does-a-chevening-scholarship-cover/',
      application: 'https://www.chevening.org/apply/',
      cycle: 'https://www.chevening.org/scholarships/application-timeline/',
    },
    tags: ['master', 'uk', 'government', 'closed', 'fully-funded'],
    checkedAt: '2026-10-24T07:17:00.000Z',
  }),
  record({
    id: 'mccall_macbain_2027',
    levels: ['master'],
    name: ['Bourse McCall MacBain 2027', 'McCall MacBain Scholarship 2027'],
    country: ['can', 'Canada', 'Canada'],
    levelLabel: ['Master ou diplôme professionnel admissible', 'Eligible Master or professional degree'],
    fundingLabel: ['Financement complet', 'Fully funded'],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'Clôturé — les candidatures de la cohorte 2027 ont fermé (candidats internationaux le 19 août 2026, Canada/États-Unis le 23 septembre 2026, à 16 h heure de l’Est) ; prochain cycle attendu vers juin 2027, date non publiée',
      'Closed — 2027 cohort applications closed (international deadline 19 August 2026, Canada/US 23 September 2026, 4:00 PM ET); next cycle expected around June 2027, date not published',
    ],
    description: [
      'Bourse de leadership de McGill pour un Master ou diplôme professionnel admissible, pour une entrée à l’été ou à l’automne 2027. Les candidatures 2027 sont closes : la source officielle avait fixé deux dates limites, le 19 août 2026 pour les candidats des universités hors Canada et États-Unis et le 23 septembre 2026 pour le Canada et les États-Unis. Jusqu’à 30 bourses complètes et 100 prix d’admission sont offerts chaque année.',
      'McGill leadership scholarship for an eligible Master or professional degree, for Summer/Fall 2027 entry. 2027 applications are closed: the official source set two deadlines, 19 August 2026 for applicants from universities outside Canada and the United States and 23 September 2026 for Canada and the United States. Up to 30 full scholarships and 100 entrance awards are offered each year.',
    ],
    advantages: [
      ['Frais de scolarité et droits du programme admissible', 'Tuition and fees for the eligible programme'],
      ['Allocation de vie de 2 300 CAD par mois pendant les trimestres académiques', 'CAD 2,300 monthly living stipend during academic terms'],
      ['Subvention unique de déménagement à Montréal', 'One-time relocation grant for moving to Montreal'],
      ['Financement d’été jusqu’à 5 000 $ pour un travail de recherche ou d’impact, pour les boursiers non inscrits à temps plein l’été', 'Summer funding of up to $5,000 for research or impact work, for scholars not enrolled full-time over the summer'],
      ['Programme de développement du leadership, mentors et conseillers, ateliers et conférences', 'Leadership development programme, mentors and advisors, workshops and talks'],
    ],
    eligibility: [
      ['Être en voie d’obtenir son premier diplôme universitaire avant août 2027', 'Be on track to earn a first Bachelor degree by August 2027'],
      ['Ou avoir obtenu ce premier diplôme en janvier 2021 ou après', 'Or have earned that first degree in January 2021 or later'],
      ['Ou, si le diplôme est antérieur, avoir 30 ans ou moins au 1er janvier 2026', 'Or, if the degree is older, have been 30 or younger on 1 January 2026'],
      ['Satisfaire les exigences minimales de diplôme et de langue d’un programme McGill admissible', 'Meet the minimum degree and language requirements of an eligible McGill programme'],
      ['Démontrer caractère, engagement communautaire, potentiel de leadership, esprit entrepreneurial et force académique', 'Demonstrate character, community engagement, leadership potential, entrepreneurial spirit and academic strength'],
    ],
    requirements: [
      ['Formulaire de bourse distinct de l’admission McGill', 'Scholarship form separate from McGill admission'],
      ['Informations personnelles, parcours d’études et activités de leadership', 'Personal information, academic record and leadership activities'],
      ['Réponses courtes, essais, CV et relevés', 'Short answers, essays, CV and transcripts'],
      ['Deux formulaires de référence', 'Two reference forms'],
      ['Endossement universitaire lorsque la procédure l’exige', 'University endorsement where the process requires it'],
      ['Candidature séparée au programme McGill après le dossier de bourse', 'Separate McGill programme application after the scholarship file'],
    ],
    steps: [
      ['Vérifier le diplôme', 'Check degree eligibility', 'Confirmer l’une des trois voies liées à la date du premier diplôme et l’admissibilité du Master McGill.', 'Confirm one of the three first-degree timing routes and the McGill Master eligibility.'],
      ['Préparer le dossier leadership', 'Prepare the leadership file', 'Rassembler activités, expériences, essais, CV, relevés et deux référents.', 'Gather activities, work, essays, CV, transcripts and two referees.'],
      ['Soumettre la bourse', 'Submit the scholarship', 'Pour un candidat international hors Canada/États-Unis, soumettre avant le 19 août à 16 h ET.', 'For an international applicant outside Canada/US, submit by 19 August at 4 PM ET.'],
      ['Postuler à McGill', 'Apply to McGill', 'Déposer séparément les candidatures aux programmes compatibles selon leurs propres dates.', 'Apply separately to compatible McGill programmes by their own deadlines.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      // La source officielle publie la date limite internationale à la minute
      // (19 août 2026, 16 h ET) mais n'annonce aucune date d'ouverture : le
      // portail est simplement déclaré ouvert. `opensAt` est donc omis plutôt
      // que deviné, ce que le validateur autorise pour un cycle confirmé.
      //
      // CETTE FENÊTRE EST PASSÉE. 16 h ET le 19/08/2026 = 20 h UTC, donc le
      // cycle est clos depuis le 19/08 au soir et `status: 'open'` devenait faux
      // sans que personne ne touche au dépôt. C'est le contrôle de fraîcheur
      // planifié qui l'a dit le 20/08 à 06h40 — il passait la veille.
      // La date de clôture est INCHANGÉE : c'est un fait daté, pas une
      // estimation. Aucune date du cycle suivant n'est inventée ici ; quand la
      // source publiera 2028-2029, ce sera une vérification, pas une déduction.
      status: 'closed',
      dateConfidence: 'confirmed',
      closesAt: '2026-08-19T20:00:00.000Z',
      sourceUrl: 'https://mccallmacbainscholars.org/apply/',
    },
    sources: {
      overview: 'https://mccallmacbainscholars.org/',
      eligibility: 'https://mccallmacbainscholars.org/apply/',
      benefits: 'https://mccallmacbainscholars.org/faq/',
      application: 'https://apply.mccallmacbainscholars.org/apply/',
      cycle: 'https://mccallmacbainscholars.org/apply/',
    },
    tags: ['master', 'canada', 'mcgill', 'closed', 'fully-funded'],
    checkedAt: '2026-10-24T07:13:00.000Z',
  }),
  record({
    id: 'schwarzman_scholars_2027',
    levels: ['master'],
    name: ['Schwarzman Scholars 2027–2028', 'Schwarzman Scholars 2027–2028'],
    country: ['chn', 'Chine', 'China'],
    levelLabel: ['Master en affaires mondiales', 'Master in Global Affairs'],
    fundingLabel: ['Financement complet', 'Fully funded'],
    fundingType: 'fully_funded',
    deadlineLabel: ['Clôturé — la campagne 2027–2028 a fermé le 9 septembre 2026 ; la campagne 2028–2029 est annoncée d’avril à septembre 2027', 'Closed — the 2027–2028 window closed on 9 September 2026; the 2028–2029 U.S./Global application is announced for April–September 2027'],
    description: [
      'Programme résidentiel d’un an à Tsinghua University formant une cohorte internationale au leadership et aux affaires mondiales.',
      'One-year residential programme at Tsinghua University bringing an international cohort together around leadership and global affairs.',
    ],
    advantages: [
      ['Frais de scolarité et autres droits', 'Tuition and fees'],
      ['Chambre et pension', 'Room and board'],
      ['Voyage d’étude en Chine', 'In-country study tour'],
      ['Voyage vers et depuis Pékin', 'Travel to and from Beijing'],
      ['Assurance santé', 'Health insurance'],
      ['Allocation pour dépenses personnelles', 'Stipend for personal expenses'],
    ],
    eligibility: [
      ['Avoir au moins 18 ans et moins de 29 ans au 1er août 2027', 'Be at least 18 and under 29 on 1 August 2027'],
      ['Détenir un premier diplôme universitaire avant le 1er août 2027', 'Hold an undergraduate degree by 1 August 2027'],
      ['Prouver l’anglais sauf dispense pour langue maternelle ou diplôme d’au moins deux ans enseigné en anglais', 'Prove English unless exempt through native language or a degree taught in English for at least two years'],
      ['Présenter toute la candidature en anglais et en ligne', 'Submit the entire application online in English'],
      ['Démontrer leadership, caractère, aptitude intellectuelle, empathie interculturelle et ouverture', 'Demonstrate leadership, character, intellectual ability, intercultural empathy and open-mindedness'],
    ],
    requirements: [
      ['Formulaire en ligne, profil biographique de 100 mots et CV de deux pages maximum', 'Online form, 100-word biographical profile and CV of no more than two pages'],
      ['Essai de leadership de 750 mots, déclaration d’intention de 500 mots et deux réponses courtes de 100 mots', '750-word leadership essay, 500-word statement of purpose and two 100-word short answers'],
      ['Relevés de chaque diplôme, avec traduction anglaise si nécessaire', 'Transcripts for every degree, with English translation where needed'],
      ['Trois lettres de recommandation, hors membres de la famille', 'Three letters of recommendation, excluding family members'],
      ['Présentation vidéo d’une minute — fortement recommandée mais non obligatoire', 'One-minute video introduction — highly recommended but not required'],
      ['Résultat d’anglais lorsque la dispense ne s’applique pas', 'English test result when no exemption applies'],
    ],
    steps: [
      ['Créer le dossier', 'Create the application', 'S’inscrire dans le portail global et vérifier la voie de candidature applicable.', 'Register in the global portal and check the applicable application route.'],
      ['Préparer les écrits', 'Prepare written materials', 'Rédiger les essais, le CV et réunir tous les relevés.', 'Write essays, prepare the CV and gather all transcripts.'],
      ['Mobiliser les référents', 'Engage referees', 'Inviter trois référents suffisamment tôt et enregistrer la vidéo.', 'Invite three referees early and record the video.'],
      ['Soumettre avant l’heure limite', 'Submit before the timed deadline', 'Finaliser au plus tard le 9 septembre à 15 h EDT et se préparer à un entretien éventuel.', 'Finish by 9 September at 3 PM EDT and prepare for a possible interview.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      status: 'closed',
      dateConfidence: 'confirmed',
      opensAt: '2026-04-08T00:00:00.000Z',
      closesAt: '2026-09-09T19:00:00.000Z',
      sourceUrl: 'https://www.schwarzmanscholars.org/admissions/application-instructions/',
    },
    sources: {
      overview: 'https://www.schwarzmanscholars.org/program-experience/',
      eligibility: 'https://www.schwarzmanscholars.org/admissions/application-instructions/',
      benefits: 'https://www.schwarzmanscholars.org/program-experience/',
      application: 'https://www.schwarzmanscholars.org/admissions/application-instructions/',
      cycle: 'https://www.schwarzmanscholars.org/admissions/application-instructions/',
    },
    tags: ['master', 'china', 'tsinghua', 'closed', 'leadership', 'fully-funded'],
    checkedAt: '2026-10-24T07:13:00.000Z',
  }),
  record({
    id: 'si_global_professionals_2027_forecast',
    levels: ['master'],
    name: ['Bourse SI pour professionnels mondiaux — appel 2027', 'SI Scholarship for Global Professionals — 2027 call'],
    country: ['swe', 'Suède', 'Sweden'],
    levelLabel: ['Master', 'Master'],
    fundingLabel: ['Financement complet publié, hors certains coûts', 'Published full funding, with specified exclusions'],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'À venir — dépôt de la bourse du 8 au 24 février 2027 (clôture à 14 h 59, heure d’Europe centrale) ; candidature aux Masters sur UniversityAdmissions.se du 16 octobre 2026 au 15 janvier 2027',
      'Upcoming — scholarship portal open 8–24 February 2027 (closes 14:59 CET); Master applications on UniversityAdmissions.se from 16 October 2026 to 15 January 2027',
    ],
    description: [
      'Bourse du Swedish Institute pour professionnels de 34 pays éligibles admis à un Master en anglais, dans les domaines gouvernance, santé publique, entrepreneuriat et innovation, et STEM. L’appel 2027-2028 est publié (relevé le 24/10/2026) : candidature aux Masters sur University Admissions du 16 octobre 2026 au 15 janvier 2027, modèles de documents SI publiés le 13 novembre 2026, dépôt de la bourse du 8 au 24 février 2027 (14 h 59, heure d’Europe centrale), résultats le 22 avril 2027.',
      'Swedish Institute scholarship for professionals from 34 eligible countries admitted to an English-taught Master, in governance, public health, entrepreneurship and innovation, and STEM. The 2027-2028 call is published (checked 24/10/2026): Master applications on University Admissions from 16 October 2026 to 15 January 2027, SI document templates published on 13 November 2026, scholarship portal open 8–24 February 2027 (14:59 CET), results on 22 April 2027.',
    ],
    advantages: [
      ['Prise en charge complète des frais de scolarité', 'Full tuition fee coverage'],
      ['Allocation mensuelle de 12 000 SEK pour les dépenses de vie', 'SEK 12,000 monthly living allowance'],
      ['Subvention de voyage unique de 15 000 SEK pour la plupart des pays éligibles', 'One-time SEK 15,000 travel grant for most eligible countries'],
      ['Adhésion au SI Network for Global Professionals et au réseau alumni', 'Membership in the SI Network for Global Professionals and alumni network'],
      ['L’assurance, les frais de candidature universitaire et les membres de famille ne sont pas couverts', 'Insurance, university application fee and family members are not covered'],
    ],
    eligibility: [
      ['Être citoyen d’un des 34 pays éligibles publiés par SI, sans obligation d’y résider ; côté Afrique francophone, l’appel 2027 liste le Sénégal et le Maroc', 'Be a citizen of one of SI’s 34 published eligible countries, with no residence requirement; on the francophone-Africa side, the 2027 call lists Senegal and Morocco'],
      ['Postuler à un Master en anglais déclaré admissible par SI', 'Apply to an English-taught Master listed as SI-eligible'],
      ['Être redevable des frais de scolarité et être admis selon le calendrier University Admissions', 'Be liable for tuition and admitted under the University Admissions timeline'],
      ['Démontrer une expérience professionnelle suffisante ; de nombreux pays africains exigent au moins 3 000 heures, cumulées chez trois employeurs au maximum', 'Demonstrate sufficient work experience; many African countries require at least 3,000 hours, accumulated with at most three employers'],
      ['Démontrer une expérience de leadership professionnel ou dans la société civile', 'Demonstrate leadership through employment or civil-society engagement'],
      ['Ne relever d’aucune exclusion publiée liée à la résidence/étude en Suède, à une bourse SI antérieure ou à la citoyenneté suédoise/UE', 'Not fall under published exclusions related to Swedish residence/study, a prior SI award or Swedish/EU citizenship'],
    ],
    requirements: [
      ['Candidature préalable aux Masters via UniversityAdmissions.se', 'Prior Master applications through UniversityAdmissions.se'],
      ['CV selon le modèle SI 2027-2028, trois pages au maximum', 'CV on the SI 2027–2028 template, at most three pages'],
      ['Preuves d’emploi et de leadership selon les formulaires SI', 'Work and leadership evidence using SI forms'],
      ['Copie du passeport ou de la pièce d’identité', 'Passport or identity copy'],
      ['Deux lettres de recommandation (modèle SI), signées et tamponnées', 'Two letters of reference (SI template), signed and stamped'],
      ['Motivation rédigée dans le portail de candidature SI ; modèles des pièces publiés le 13 novembre 2026', 'Motivation written in the SI application portal; document templates published on 13 November 2026'],
    ],
    steps: [
      ['Choisir des Masters SI', 'Choose SI-eligible Masters', 'À publication de la liste, identifier les programmes compatibles avec son impact de développement.', 'When the list is published, identify programmes aligned with the applicant’s development impact.'],
      ['Postuler aux universités', 'Apply to universities', 'Déposer les Masters via University Admissions entre le 16 octobre 2026 et le 15 janvier 2027.', 'Submit Master applications through University Admissions between 16 October 2026 and 15 January 2027.'],
      ['Préparer les modèles SI', 'Prepare SI templates', 'Faire signer et valider CV, emplois, leadership, identité et motivation.', 'Complete and validate the CV, work, leadership, identity and motivation documents.'],
      ['Déposer dans la courte fenêtre SI', 'Submit in the short SI window', 'Téléverser la bourse entre le 8 et le 24 février 2027, avant 14 h 59 (heure d’Europe centrale) le dernier jour.', 'Upload the scholarship between 8 and 24 February 2027, before 14:59 CET on the final day.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      // Appel 2027 publié (relu le 24/10/2026) : « Submit your SI Scholarship
      // application here between 8-24 February 2027 », portail fermé à
      // 14:59 CET le dernier jour. Aucune heure d'ouverture : minuit CET.
      status: 'forecast',
      dateConfidence: 'confirmed',
      opensAt: '2027-02-07T23:00:00.000Z',
      closesAt: '2027-02-24T13:59:00.000Z',
      sourceUrl: 'https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/',
    },
    sources: {
      overview: 'https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/',
      eligibility: 'https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/',
      benefits: 'https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/',
      application: 'https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/',
      cycle: 'https://si.se/en/apply/scholarships/swedish-institute-scholarships-for-global-professionals/',
    },
    tags: ['master', 'sweden', 'government', 'leadership', 'forecast', 'fully-funded'],
    checkedAt: '2026-10-24T07:13:00.000Z',
  }),
  record({
    id: 'daad_helmut_schmidt_2027',
    levels: ['master'],
    name: ['Programme DAAD Helmut-Schmidt 2027', 'DAAD Helmut-Schmidt Programme 2027'],
    country: ['deu', 'Allemagne', 'Germany'],
    levelLabel: ['Masters sélectionnés en politiques publiques et bonne gouvernance', 'Selected Master programmes in public policy and good governance'],
    fundingLabel: ['Financement complet du programme', 'Comprehensive programme funding'],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'Clôturé — la période 2027 s’est achevée le 31 juillet 2026 ; prochain appel attendu vers juin 2027',
      'Closed — the 2027 call ended on 31 July 2026; next call expected around June 2027',
    ],
    description: [
      'Bourses DAAD pour futurs leaders de pays en développement et émergents dans sept Masters anglophones liés aux politiques publiques, à la gouvernance, au développement et à la paix, pour des études débutant en septembre-octobre 2027. L’appel officiel 2027 fixait la période de candidature du 1er juin au 31 juillet 2026 : elle est close, la sélection étant prévue en octobre-novembre 2026 et les réponses en décembre 2026-janvier 2027.',
      'DAAD scholarships for future leaders from developing and emerging countries in seven English-taught Master programmes related to public policy, governance, development and peace, for studies starting in September–October 2027. The official 2027 call set the application period from 1 June to 31 July 2026: it has closed, with selection due in October–November 2026 and decisions in December 2026–January 2027.',
    ],
    advantages: [
      ['Exonération des frais de scolarité pour les boursiers DAAD', 'Exemption from tuition fees for DAAD scholarship holders'],
      ['Allocation actuelle de 992 EUR par mois', 'Current EUR 992 monthly stipend'],
      ['Couverture d’assurance maladie en Allemagne', 'Health insurance cover in Germany'],
      ['Forfaits de voyage entre l’Allemagne et le pays d’origine, et subvention d’études et de recherche', 'Travel lump sums between Germany and the home country, and a study and research grant'],
      ['Subvention de loyer et compléments familiaux lorsque applicables', 'Rent subsidy and family supplements where applicable'],
      ['Cours obligatoire d’allemand en Allemagne, jusqu’à quatre mois avant le Master', 'Mandatory German course in Germany, up to four months before the Master'],
      ['Pour le Master « Social Protection » uniquement, un taux sur place de 500 EUR par mois remplace l’allocation habituelle au 4e semestre en ligne', 'For the “Social Protection” Master only, a EUR 500 monthly sur place rate replaces the usual stipend during the online 4th semester'],
    ],
    eligibility: [
      ['Être diplômé d’un pays en développement ou émergent avec une première Licence pertinente', 'Be a graduate from a developing or emerging country with a relevant first degree'],
      ['Avoir des résultats supérieurs à la moyenne, dans le tiers supérieur', 'Have above-average results in the upper third'],
      ['Avoir une formation en sciences sociales/politiques, droit, économie, politiques publiques ou administration selon le cursus', 'Have a background in social/political sciences, law, economics, public policy or administration as required by the course'],
      ['Démontrer une expérience pratique pertinente : emploi, stage, engagement politique/social, bénévolat ou ONG', 'Demonstrate relevant practical experience through work, internships, political/social engagement, volunteering or NGOs'],
      ['Avoir obtenu le dernier diplôme universitaire depuis six ans au plus, soit une date de délivrance au plus tôt le 1er janvier 2020', 'Have obtained the latest university degree no more than six years ago, i.e. issued no earlier than 1 January 2020'],
      ['Ne pas avoir passé plus des 15 derniers mois dans un pays hors liste CAD', 'Not have spent more than the past 15 months in a country outside the DAC list'],
      ['Si l’on détient déjà un Master, argumenter solidement le financement d’un second diplôme de troisième cycle', 'If already holding a Master, make a well-argued case for funding a second postgraduate degree'],
      ['Satisfaire les critères propres du ou des Masters, notamment la langue', 'Meet the selected Master programme’s own criteria, including language'],
    ],
    requirements: [
      ['Checklist DAAD signée à la main et formulaire Helmut-Schmidt', 'Hand-signed DAAD checklist and Helmut-Schmidt form'],
      ['Lettre de motivation unique, deux pages maximum, classant jusqu’à deux Masters', 'Single motivation letter, maximum two pages, ranking up to two Master programmes'],
      ['CV Europass en ordre chronologique inverse avec explication des interruptions', 'Reverse-chronological Europass CV explaining gaps'],
      ['Diplômes, relevés complets et traductions certifiées si nécessaires', 'Degrees, complete transcripts and certified translations where needed'],
      ['Preuves signées et tamponnées d’expérience/engagement', 'Signed and stamped evidence of experience/engagement'],
      ['Preuve d’anglais et référence actuelle employeur ou enseignant selon le statut', 'English proof and current employer or lecturer reference as applicable'],
    ],
    steps: [
      ['Choisir un ou deux Masters', 'Choose one or two Master programmes', 'Comparer les sept cursus et leurs exigences spécifiques.', 'Compare the seven programmes and their specific requirements.'],
      ['Préparer un dossier identique', 'Prepare one consistent file', 'Classer les choix de façon cohérente dans le formulaire et la lettre de motivation.', 'Rank choices consistently in the form and motivation letter.'],
      ['Envoyer aux universités', 'Send to universities', 'Déposer directement auprès de chaque Master choisi, jamais au DAAD.', 'Apply directly to each selected Master programme, never to DAAD.'],
      ['Conserver les PDF', 'Keep PDF copies', 'Garder un dossier complet pour le téléversement DAAD uniquement en cas de nomination.', 'Keep a complete file for DAAD portal upload only if nominated.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      // L'appel officiel 2027 (ST42, édition 05/2026) écrit noir sur blanc :
      // « The application period for all seven higher education institutions is
      // from 1 June until 31 July 2026. » Cette fenêtre est passée, donc
      // 'closed' et non 'open' — la fiche annonçait l'inverse.
      status: 'closed',
      dateConfidence: 'confirmed',
      opensAt: '2026-06-01T00:00:00.000Z',
      closesAt: '2026-07-31T23:59:59.000Z',
      sourceUrl: 'https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_helmut_schmidt_programme_current_announcement.pdf',
    },
    sources: {
      overview: 'https://www.daad.de/en/information-services-for-higher-education-institutions/further-information-on-daad-programmes/ppgg/',
      eligibility: 'https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_helmut_schmidt_programme_current_announcement.pdf',
      benefits: 'https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_helmut_schmidt_programme_current_announcement.pdf',
      application: 'https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_helmut_schmidt_programme_current_announcement.pdf',
      cycle: 'https://static.daad.de/media/daad_de/pdfs_nicht_barrierefrei/in-deutschland-studieren-forschen-lehren/daad_helmut_schmidt_programme_current_announcement.pdf',
    },
    tags: ['master', 'germany', 'daad', 'closed', 'governance', 'fully-funded'],
    // Relue le 31/10/2026 : page de présentation et appel officiel ST42
    // (édition 05/2026), lus sans blocage (daad.de répond 200 depuis ce jour) ;
    // voir docs/catalog-verification-2026-10-31.md.
    checkedAt: '2026-10-31T18:44:50.000Z',
  }),
  record({
    id: 'australia_awards_africa_2028_forecast',
    levels: ['master'],
    name: ['Australia Awards Africa — prévision 2028', 'Australia Awards Africa — 2028 forecast'],
    country: ['aus', 'Australie', 'Australia'],
    levelLabel: ['Master', 'Master'],
    fundingLabel: ['Financement complet', 'Fully funded'],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'Prochain cycle (rentrée 2028) — ouverture officiellement annoncée le 1er février 2027 ; clôture estimée vers le 30 avril 2027, à reconfirmer',
      'Next cycle (2028 intake) — opening officially announced for 1 February 2027; closing estimated around 30 April 2027, to be reconfirmed',
    ],
    description: [
      'Bourses du gouvernement australien pour professionnels africains de niveau intermédiaire à senior. Le portail OASIS confirme que la rentrée 2027 est close et aucune suspension ni coupe budgétaire n’est annoncée sur les pages officielles. Les dates et critères affichés comme prévision sont dérivés du document officiel pour les études débutant en 2027, dont l’appel courait du 1er février au 30 avril 2026, et doivent être reconfirmés pour l’appel suivant.',
      'Australian Government scholarships for mid- to senior-level African professionals. The OASIS portal confirms the 2027 intake has closed and no suspension or budget cut is announced on the official pages. Forecast dates and criteria are derived from the official 2027-intake document, whose call ran from 1 February to 30 April 2026, and must be reconfirmed for the next call.',
    ],
    advantages: [
      ['Frais de scolarité complets', 'Full tuition fees'],
      ['Voyage aérien aller-retour', 'Return air travel'],
      ['Allocation d’installation unique et contribution aux frais de vie', 'One-off establishment allowance and contribution to living expenses'],
      ['Couverture santé des étudiants étrangers pendant la bourse', 'Overseas student health cover for the award duration'],
      ['Programme académique d’introduction et soutien académique supplémentaire', 'Introductory academic programme and supplementary academic support'],
      ['Allocation de terrain pour les cursus comportant un terrain obligatoire', 'Fieldwork allowance for programmes with compulsory fieldwork'],
    ],
    eligibility: [
      ['Pour l’appel de référence, être citoyen d’un des 25 pays africains listés, y résider et y candidater, sauf pour un agent d’une organisation régionale africaine ou en mission diplomatique pour son pays', 'For the reference call, be a citizen of one of the 25 listed African countries, reside there and apply from there, except when working for an African regional organisation or on diplomatic mission for the home country'],
      ['Viser un domaine prioritaire publié : agriculture et sécurité alimentaire, changement climatique, politique étrangère et sécurité internationale, genre, handicap et inclusion sociale, mines et énergie', 'Target a published priority field: agriculture and food security, climate change, foreign policy and international security, gender, disability and social inclusion, mining and energy'],
      ['Avoir au moins 25 ans au 1er février de l’année de rentrée de référence', 'Be at least 25 on 1 February of the reference intake year'],
      ['Détenir une Licence équivalente à une Licence australienne', 'Hold an undergraduate degree equivalent to an Australian Bachelor'],
      ['Avoir au moins cinq ans d’expérience professionnelle après le diplôme, pertinente pour le domaine choisi', 'Have at least five years of post-graduate work experience relevant to the proposed study field'],
      ['Être employé au moment de la candidature', 'Be employed when applying'],
      ['Ne pas déjà détenir ou suivre un Master et ne pas avoir reçu une précédente Australia Award longue durée', 'Not already hold or pursue a Master and not have received a previous long-term Australia Award'],
      ['Atteindre le seuil de langue publié : IELTS 6,5 sans bande sous 6,0, TOEFL iBT 84 avec 21 par section, ou PTE 58 avec 50 par compétence, sauf dispense', 'Meet the published language threshold: IELTS 6.5 with no band below 6.0, TOEFL iBT 84 with 21 in each section, or PTE 58 with 50 per skill, unless exempt'],
    ],
    requirements: [
      ['Passeport certifié', 'Certified passport'],
      ['Diplôme de Licence et relevé certifiés', 'Certified Bachelor degree and transcript'],
      ['Curriculum vitae', 'Curriculum vitae'],
      ['Rapport de référence de l’employeur', 'Employer referee report'],
      ['Rapport de référence académique', 'Academic referee report'],
      ['Certificat IELTS, TOEFL ou PTE applicable', 'Applicable IELTS, TOEFL or PTE certificate'],
      ['Documents complémentaires du profil pays et du manuel de politique', 'Additional country-profile and policy-handbook documents'],
    ],
    steps: [
      ['Attendre le profil actualisé', 'Wait for the updated profile', 'Activer l’alerte et reconfirmer pays, âge, secteurs prioritaires, langue et dates au prochain appel.', 'Enable the alert and reconfirm country, age, priority sectors, language and dates in the next call.'],
      ['Préparer les certifications', 'Prepare certifications', 'Faire certifier passeport, diplôme et relevé et solliciter deux rapports de référence.', 'Certify passport, degree and transcript and request two referee reports.'],
      ['Créer le dossier OASIS', 'Create the OASIS file', 'S’inscrire, établir son éligibilité et choisir ses préférences de Master.', 'Register, establish eligibility and choose Master preferences.'],
      ['Soumettre avant l’heure australienne', 'Submit by Australian time', 'Téléverser des PDF couleur lisibles et tenir compte du fuseau horaire officiel.', 'Upload readable colour PDFs and account for the official Australian time zone.'],
    ],
    cycle: {
      academicYear: '2028-2029',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2027-02-01T00:00:00.000Z',
      estimatedCloseAt: '2027-04-30T23:59:59.000Z',
      sourceUrl: 'https://australiaawardsafrica.org/awards/apply/',
    },
    sources: {
      overview: 'https://australiaawardsafrica.org/awards/types-of-awards/',
      // Depuis le 24/10/2026, la page « apply » n'affiche plus les critères
      // (ils sont passés en commentaire HTML) : l'éligibilité se lit dans le
      // profil Afrique 2027, inchangé.
      eligibility: 'https://australiaawardsafrica.org/resources/Africa-Profile-2027-Intake.pdf',
      benefits: 'https://australiaawardsafrica.org/resources/Africa-Profile-2027-Intake.pdf',
      application: 'https://oasis.dfat.gov.au/',
      cycle: 'https://australiaawardsafrica.org/awards/apply/',
    },
    tags: ['master', 'australia', 'africa', 'government', 'forecast', 'fully-funded'],
    checkedAt: '2026-10-24T07:15:00.000Z',
  }),
  record({
    id: 'gates_cambridge_2027',
    // Catalogue 1.5.0 : le texte de la fiche dit « … ou doctorat » (libellé),
    // « environ deux tiers pour des doctorants » (description) et « Postuler à
    // un doctorat, un MLitt ou une formation d'un an » (éligibilité). Limité au
    // master, un élève visant un doctorat en était écarté à tort.
    levels: ['master', 'doctorate'],
    name: ['Bourse Gates Cambridge 2027–2028', 'Gates Cambridge Scholarship 2027–2028'],
    country: ['gbr', 'Royaume-Uni — University of Cambridge', 'United Kingdom — University of Cambridge'],
    levelLabel: [
      'Master de recherche ou d’un an à temps plein (MPhil, MRes, LLM, MLitt) ou doctorat — pas de MASt, MBA ni second BA',
      'Full-time research or one-year Master (MPhil, MRes, LLM, MLitt) or PhD — no MASt, MBA or second BA',
    ],
    fundingLabel: ['Financement complet', 'Fully funded'],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'Ouvert — tour international : 8 décembre 2026 ou 6 janvier 2027 à 23 h 59 (heure du Royaume-Uni) selon la formation, références comprises ; vérifier la date de sa formation dans le Course Directory de Cambridge',
      'Open — international round: 8 December 2026 or 6 January 2027 at 11:59pm UK time depending on the course, references included; check your course’s date in the Cambridge Course Directory',
    ],
    description: [
      'Bourse complète de la Fondation Bill & Melinda Gates pour des étudiants de tout pays hors Royaume-Uni admis en troisième cycle à l’université de Cambridge. Environ 70 bourses par an, dont deux tiers environ pour des doctorants. Il n’y a pas de formulaire séparé : on postule à la formation et à la bourse dans le même dossier du portail de candidature de Cambridge, en remplissant la partie Gates de la section financement. La date limite dépend de la formation : celle à retenir est la « Course Funding Deadline » indiquée dans le Course Directory.',
      'Full-cost scholarship from the Bill & Melinda Gates Foundation for students from any country outside the United Kingdom admitted to a postgraduate course at the University of Cambridge. Around 70 awards a year, about two-thirds for PhD students. There is no separate form: you apply for the course and the scholarship in the same application on the Cambridge Graduate Application Portal, completing the Gates part of the funding section. The deadline depends on the course: the one that counts is the “Course Funding Deadline” shown in the Course Directory.',
    ],
    advantages: [
      ['Frais universitaires de Cambridge (University Composition Fee) au tarif applicable', 'University Composition Fee at the appropriate rate'],
      ['Allocation de vie de 23 152 £ pour 12 mois au taux 2026-2027, au prorata pour les formations plus courtes ; jusqu’à 4 ans pour un doctorat', 'Maintenance allowance of £23,152 for 12 months at the 2026-27 rate, pro rata for shorter courses; up to 4 years for a PhD'],
      ['Un billet d’avion simple en classe économique au début et à la fin de la formation', 'One economy single airfare at both the beginning and end of the course'],
      ['Frais de visa d’entrée et surtaxe santé (Immigration Health Surcharge)', 'Inbound visa costs and the Immigration Health Surcharge'],
      ['Sur demande : fonds de développement académique (750 £ à 4 000 £), allocation pour enfants à charge (jusqu’à 12 793 £ par an pour un enfant), terrain, parentalité et difficultés financières — rien pour un conjoint', 'On application: academic development funding (£750 to £4,000), dependent children allowance (up to £12,793 a year for one child), fieldwork, parental leave and hardship funding — nothing for a partner'],
      ['Réseau des boursiers Gates Cambridge ; matériel scientifique et « bench fees » non couverts', 'Gates Cambridge scholar community; scientific equipment and bench fees are not covered'],
    ],
    eligibility: [
      ['Être citoyen d’un pays hors du Royaume-Uni ; les binationaux britanniques sont éligibles', 'Be a citizen of a country outside the United Kingdom; dual UK nationals are eligible'],
      ['Postuler à un doctorat, un MLitt ou une formation d’un an à temps plein (MPhil, MRes, LLM…) ; les MASt, MBA, PGCE, PGDip, second BA et masters à temps partiel sont exclus', 'Apply for a PhD, an MLitt or a full-time one-year course (MPhil, MRes, LLM…); MASt, MBA, PGCE, PGDip, a second BA and part-time Master courses are excluded'],
      ['Démontrer une capacité intellectuelle exceptionnelle et des raisons solides de choisir la formation', 'Show outstanding intellectual ability and strong reasons for the choice of course'],
      ['Démontrer un engagement à améliorer la vie des autres et un potentiel de leadership', 'Show a commitment to improving the lives of others and leadership potential'],
      ['Obtenir l’admission à la formation de Cambridge et satisfaire ses exigences d’anglais : la bourse n’exige pas de test, mais l’université oui', 'Secure admission to the Cambridge course and meet its English requirements: the scholarship sets no test, but the University does'],
      ['Pas de moyenne minimale ; sélection sans examen des ressources (« needs-blind ») ; un second master est possible, mais on ne peut pas financer la suite d’une formation déjà commencée', 'No minimum GPA; needs-blind selection; a second Master is possible, but the remainder of a course already started cannot be funded'],
    ],
    requirements: [
      ['Dossier sur le portail de candidature de Cambridge : admission à la formation, choix de college et partie Gates de la section financement', 'Application on the Cambridge Graduate Application Portal: course admission, college choice and the Gates part of the funding section'],
      ['Quatre textes Gates : excellence académique et choix de la formation (environ 200 mots chacun), engagement envers les autres et leadership (environ 300 mots chacun)', 'Four Gates statements: academic excellence and choice of course (about 200 words each), commitment to others and leadership (about 300 words each)'],
      ['Deux références académiques pour l’admission, plus une référence Gates sur les critères de la bourse', 'Two academic references for admission, plus a Gates reference on the scholarship criteria'],
      ['Projet de recherche pour les candidats au doctorat uniquement', 'Research proposal for PhD applicants only'],
      ['Test d’anglais exigé par l’université selon la formation ; les frais de dossier ne sont pas pris en charge par Gates', 'English test as required by the University for the course; the application fee is not covered by Gates'],
      ['Dossier complet, références comprises, avant la date limite de financement de la formation', 'Complete application, references included, by the course’s funding deadline'],
    ],
    steps: [
      ['Choisir la formation', 'Choose the course', 'Vérifier dans le Course Directory que la formation est éligible et relever sa « Course Funding Deadline » : 8 décembre 2026 ou 6 janvier 2027.', 'Check in the Course Directory that the course is eligible and note its Course Funding Deadline: 8 December 2026 or 6 January 2027.'],
      ['Déposer un seul dossier', 'Submit a single application', 'Sur le portail de Cambridge, remplir l’admission, le college et la partie Gates de la section financement, avec les quatre textes et les trois référents.', 'On the Cambridge portal, complete admission, college and the Gates part of the funding section, with the four statements and three referees.'],
      ['Nomination par le département', 'Departmental nomination', 'De décembre à février, les départements classent les candidats ; tous les candidats du tour international sont informés au plus tard le 8 mars 2027.', 'From December to February, departments rank applicants; all international-round applicants are notified by 8 March 2027.'],
      ['Entretien et résultat', 'Interview and result', 'Entretien de 25 à 30 minutes, en personne ou à distance, devant un jury les 22 et 23 mars 2027 ; offres début avril 2027, à accepter sous 72 heures.', '25–30 minute interview, in person or online, before a panel on 22–23 March 2027; offers by early April 2027, to accept within 72 hours.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      // Tour international ouvert le 11/09/2026 (page « Timeline » de Gates
      // Cambridge ; le Course Directory indique le 9/09 pour l'ouverture des
      // candidatures à l'université). Deux dates limites selon la formation :
      // 08/12/2026 ou 06/01/2027, 23:59 heure du Royaume-Uni (GMT en hiver).
      // `closesAt` retient la plus tardive ; le libellé dit de vérifier celle
      // de sa formation. Le tour réservé aux citoyens américains résidant aux
      // États-Unis (14/10/2026) ne concerne pas le public de l'app.
      status: 'open',
      dateConfidence: 'confirmed',
      opensAt: '2026-09-10T23:00:00.000Z',
      closesAt: '2027-01-06T23:59:00.000Z',
      sourceUrl: 'https://www.gatescambridge.org/apply/timeline/',
    },
    sources: {
      overview: 'https://www.gatescambridge.org/programme/the-scholarship/',
      eligibility: 'https://www.gatescambridge.org/apply/eligibility/',
      benefits: 'https://www.gatescambridge.org/programme/the-scholarship/',
      application: 'https://www.gatescambridge.org/apply/how-to-apply/',
      cycle: 'https://www.gatescambridge.org/apply/timeline/',
    },
    tags: ['master', 'doctorate', 'uk', 'cambridge', 'university', 'open', 'fully-funded'],
    checkedAt: '2026-10-24T07:15:00.000Z',
  }),
  record({
    id: 'cmu_africa_mastercard_2027',
    levels: ['master'],
    name: [
      'Carnegie Mellon University Africa — Mastercard Foundation Scholars Program, rentrée 2027',
      'Carnegie Mellon University Africa — Mastercard Foundation Scholars Program, Fall 2027',
    ],
    country: ['rwa', 'Rwanda — Carnegie Mellon University Africa (Kigali)', 'Rwanda — Carnegie Mellon University Africa (Kigali)'],
    levelLabel: [
      'Master of Science en technologies de l’information, génie électrique et informatique, ou ingénierie de l’intelligence artificielle',
      'Master of Science in Information Technology, Electrical and Computer Engineering, or Engineering Artificial Intelligence',
    ],
    fundingLabel: [
      'Financement complet sur critères sociaux, réservé aux candidats africains admis',
      'Full need-based funding, for admitted African applicants',
    ],
    fundingType: 'fully_funded',
    deadlineLabel: [
      'Ouvert — échéance anticipée le 15 décembre 2026 (tests de compétence pris en charge par CMU-Africa), échéance finale le 15 janvier 2027 ; aucune heure publiée. Après le 15 décembre, un score DET, IELTS ou TOEFL valide est exigé',
      'Open — early deadline 15 December 2026 (competency test fees covered by CMU-Africa), final deadline 15 January 2027; no time published. After 15 December, a valid DET, IELTS or TOEFL score is required',
    ],
    description: [
      'Carnegie Mellon University Africa, campus de Kigali de l’université américaine, est partenaire du Mastercard Foundation Scholars Program pour ses trois Masters d’ingénierie. Il n’existe ni formulaire ni date limite séparés pour la bourse : on postule d’abord à l’admission (un seul programme), puis on remplit le formulaire d’évaluation de l’aide financière qui apparaît dans le suivi du dossier. Seuls les candidats admis de nationalité africaine sont considérés. La candidature est gratuite.',
      'Carnegie Mellon University Africa, the Kigali campus of the US university, is a Mastercard Foundation Scholars Program partner for its three engineering Master programmes. There is no separate scholarship form or deadline: you first apply for admission (one programme only), then complete the financial aid assessment form shown on your application status page. Only admitted applicants of African nationality are considered. There is no application fee.',
    ],
    advantages: [
      ['Frais de scolarité entièrement couverts', 'Full tuition coverage'],
      ['Assurance santé, voyage et frais de vie de base', 'Health insurance, travel and basic living expenses'],
      ['Aide à la préparation de la candidature et orientation à l’arrivée', 'Application preparation support and orientation'],
      ['Soutien aux projets et à l’entrepreneuriat', 'Project and entrepreneurship support'],
      ['Préparation à l’emploi : salons de stages et de recrutement, coaching de carrière individuel', 'Career preparation: internship and career fairs, one-on-one career coaching'],
      ['Formation au leadership et engagement communautaire, au sein du réseau des Mastercard Foundation Scholars', 'Leadership training and community service, within the Mastercard Foundation Scholars network'],
    ],
    eligibility: [
      ['Être de nationalité africaine : seuls les admis africains sont éligibles à l’aide financière', 'Be of African nationality: only admitted African applicants are eligible for financial aid'],
      ['Être d’abord admis à l’un des trois Masters de CMU-Africa', 'First be admitted to one of CMU-Africa’s three Master programmes'],
      ['Démontrer un besoin financier et faire face à de fortes barrières sociales et économiques', 'Demonstrate financial need and face significant social and economic barriers'],
      ['Montrer talent académique, engagement envers sa communauté et potentiel de leadership', 'Show academic talent, commitment to giving back to the community and leadership potential'],
      ['Détenir une Licence, ou être en dernière année avec au moins les trois quarts du cursus validés, avec une solide base en informatique ou en ingénierie — pas de moyenne plancher, la plupart des admis ont 3,0/4 ou plus', 'Hold a Bachelor degree, or be in the final year with at least three-quarters completed, with a strong computer science or engineering background — no GPA cut-off, most admitted students have 3.0/4 or above'],
      ['Niveau d’anglais recommandé : TOEFL 81, IELTS 6,5 ou Duolingo 120 ; GRE non exigé', 'Recommended English level: TOEFL 81, IELTS 6.5 or Duolingo 120; GRE not required'],
    ],
    requirements: [
      ['Formulaire en ligne sur le portail d’admission de Carnegie Mellon, pour un seul programme', 'Online application on the Carnegie Mellon admissions portal, for one programme only'],
      ['Essais écrits (lettre de motivation pour MS ECE ; trois essais de 300 mots au plus pour MSIT et MS EAI) et un essai vidéo', 'Written essays (statement of purpose for MS ECE; three essays of up to 300 words for MSIT and MS EAI) and a video essay'],
      ['CV de deux pages au plus, relevés de notes non officiels avec le barème, pièce d’identité ou passeport', 'CV of up to two pages, unofficial transcripts with the grading scale, national ID or passport'],
      ['Coordonnées de trois référents', 'Contact details of three recommenders'],
      ['Score DET, IELTS ou TOEFL, puis test technique en ligne d’une heure envoyé sur invitation', 'DET, IELTS or TOEFL score, then a one-hour online technical test sent by invitation'],
      ['Formulaire d’évaluation de l’aide financière, à remplir après le dépôt du dossier', 'Financial aid assessment form, to complete after submitting the application'],
    ],
    steps: [
      ['Choisir un seul Master', 'Choose one Master', 'MSIT (16 à 20 mois), MS ECE (10 à 16 mois) ou MS EAI (16 à 20 mois), à temps plein à Kigali, rentrée d’automne uniquement.', 'MSIT (16–20 months), MS ECE (10–16 months) or MS EAI (16–20 months), full-time in Kigali, fall entry only.'],
      ['Déposer avant le 15 décembre', 'Apply by 15 December', 'Soumettre le dossier complet avant l’échéance anticipée pour que CMU-Africa prenne en charge les tests ; l’échéance finale du 15 janvier 2027 exige un score d’anglais valide.', 'Submit the complete application by the early deadline so that CMU-Africa covers the test fees; the 15 January 2027 final deadline requires a valid English score.'],
      ['Tests et aide financière', 'Tests and financial aid', 'Passer le test d’anglais et le test technique, puis remplir le formulaire d’évaluation de l’aide financière depuis la page de suivi.', 'Take the English and technical tests, then complete the financial aid assessment form from the status page.'],
      ['Décision', 'Decision', 'Examen des dossiers de janvier à avril, décisions d’admission en avril-mai 2027, programme d’intégration de mai à août et rentrée en septembre.', 'Applications reviewed January to April, admission decisions in April–May 2027, induction programme May to August and classes from September.'],
    ],
    cycle: {
      academicYear: '2027-2028',
      // La FAQ « Updated for fall 2027 application » publie « October 1:
      // Applications for all programs open / December 15: Early admission
      // deadline / January 15: Final application deadline », sans année ni
      // heure : la rentrée visée fixe 15/12/2026 et 15/01/2027. Aucune heure
      // n'étant publiée, `closesAt` prend la fin de journée UTC ; `opensAt`
      // est omis, l'année de l'ouverture n'étant pas écrite.
      status: 'open',
      dateConfidence: 'confirmed',
      closesAt: '2027-01-15T23:59:59.000Z',
      sourceUrl: 'https://www.africa.engineering.cmu.edu/admissions/how-to-apply/index.html',
    },
    sources: {
      overview: 'https://www.africa.engineering.cmu.edu/impact/mastercard-foundation-scholars.html',
      eligibility: 'https://www.africa.engineering.cmu.edu/admissions/faq.html',
      benefits: 'https://www.africa.engineering.cmu.edu/impact/mastercard-foundation-scholars.html',
      application: 'https://www.africa.engineering.cmu.edu/admissions/how-to-apply/index.html',
      cycle: 'https://www.africa.engineering.cmu.edu/admissions/how-to-apply/index.html',
    },
    tags: ['master', 'africa', 'rwanda', 'mastercard-foundation', 'engineering', 'open', 'fully-funded'],
    checkedAt: '2026-10-07T11:40:00.000Z',
  }),
];
