import type { CountryQuizDefinition, QuizQuestion } from '../country-quiz.types';

export interface M5CountrySeed {
  id: string;
  code: string;
  flagEmoji: string;
  displayOrder: number;
  nameFr: string;
  nameEn: string;
  taglineFr: string;
  taglineEn: string;
  nextIntakeLabelFr: string;
  nextIntakeLabelEn: string;
  mainLanguageFr: string;
  mainLanguageEn: string;
  whyStudyFr: string;
  whyStudyEn: string;
  marketingDescriptionFr: string;
  marketingDescriptionEn: string;
  whyStudyBulletsFr: string[];
  whyStudyBulletsEn: string[];
  howItWorksFr: string;
  howItWorksEn: string;
  costsOverviewFr: string;
  costsOverviewEn: string;
  languageSectionFr: string;
  languageSectionEn: string;
  partnerSchoolsFr: string;
  partnerSchoolsEn: string;
  scholarshipsSectionFr: string;
  scholarshipsSectionEn: string;
  whatsAppPrefillFr: string;
  whatsAppPrefillEn: string;
  mvpNoteFr: string;
  mvpNoteEn: string;
  tuitionRangeFr: string;
  tuitionRangeEn: string;
  livingCostRangeFr: string;
  livingCostRangeEn: string;
  visaOverviewFr: string;
  visaOverviewEn: string;
  admissionDifficultyFr: string;
  admissionDifficultyEn: string;
  popularFieldIds: string[];
  /// Data-trust signal: ISO date these country facts were last verified, and
  /// the official source they were checked against (drives the VerifiedBadge +
  /// "official source" link). Optional so non-verified rows stay "À confirmer".
  lastVerifiedAt?: string;
  sourceUrl?: string;
  quiz: CountryQuizDefinition;
}

function q(
  id: string,
  textFr: string,
  textEn: string,
  options: [string, string, string][],
): QuizQuestion {
  return {
    id,
    textFr,
    textEn,
    type: 'single_select',
    options: options.map(([value, labelFr, labelEn]) => ({
      value,
      labelFr,
      labelEn,
    })),
  };
}

const levelQuestion = q(
  'q1_level',
  "Quel est ton niveau d'études actuel ?",
  'What is your current level of study?',
  [
    ['terminale', 'Terminale (lycée)', 'Final year of high school'],
    ['bachelor', 'Bachelor / Licence', 'Bachelor / undergraduate'],
    ['master', 'Master', 'Master / graduate'],
  ],
);

const diplomaQuestion = q(
  'q2_diploma',
  'As-tu (ou auras-tu cette année) le baccalauréat ?',
  'Do you have (or will you get this year) a high-school diploma?',
  [
    ['yes_obtained', "Oui, je l'ai déjà", 'Yes, I already have it'],
    ['yes_this_year', 'Je le passe cette année', 'I am taking it this year'],
    ['no', 'Non / autre diplôme', 'No / other qualification'],
  ],
);

const englishQuestion = q(
  'q3_english_level',
  "Quel est ton niveau d'anglais ?",
  'What is your English level?',
  [
    ['advanced', 'B2 ou plus (certifié)', 'B2 or above (certified)'],
    ['intermediate', 'B1 / scolaire', 'B1 / school level'],
    ['basic', 'Faible', 'Basic'],
  ],
);

const budgetQuestion = q(
  'q4_budget',
  'Quel budget annuel peux-tu mobiliser (scolarité) ?',
  'What annual tuition budget can you mobilize?',
  [
    ['low', 'Moins de 5 000 €', 'Less than €5,000'],
    ['medium', '5 000 à 10 000 €', '€5,000 to €10,000'],
    ['high', '10 000 à 20 000 €', '€10,000 to €20,000'],
    ['very_high', 'Plus de 20 000 €', 'More than €20,000'],
  ],
);

function defaultVerdicts(
  countryNameFr: string,
  countryNameEn: string,
  alternatives: string[] = ['mar', 'tur'],
): CountryQuizDefinition['verdicts'] {
  return {
    eligible: {
      titleFr: '🎉 Tu es éligible !',
      titleEn: '🎉 You are eligible!',
      messageFr: `Excellent profil pour étudier en ${countryNameFr}. Lance ta demande d'accompagnement avec KPB.`,
      messageEn: `Strong profile to study in ${countryNameEn}. Start your support request with KPB.`,
      ctaFr: `Demander un accompagnement ${countryNameFr}`,
      ctaEn: `Request ${countryNameEn} support`,
    },
    eligible_with_conditions: {
      titleFr: '🟡 Éligible sous conditions',
      titleEn: '🟡 Eligible with conditions',
      messageFr:
        'Tu peux avancer vers ce pays mais quelques points sont à optimiser. Un conseiller KPB t\'explique comment.',
      messageEn:
        'You can pursue this destination but a few points need work. A KPB advisor will guide you.',
      ctaFr: 'Discuter avec un conseiller',
      ctaEn: 'Talk to an advisor',
    },
    not_eligible: {
      titleFr: '💡 Pas le bon moment, mais on a des alternatives',
      titleEn: '💡 Not the right fit yet — alternatives available',
      messageFr:
        'Le profil exigé n\'est pas encore là, mais d\'autres destinations KPB pourraient te convenir.',
      messageEn:
        'The required profile is not there yet, but other KPB destinations may suit you.',
      ctaFr: 'Voir d\'autres destinations',
      ctaEn: 'See other destinations',
      alternativeCountryIds: alternatives,
    },
  };
}

export const M5_COUNTRY_SEEDS: M5CountrySeed[] = [
  {
    id: 'fra',
    code: 'FRA',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://www.campusfrance.org/en',
    flagEmoji: '🇫🇷',
    displayOrder: 1,
    nameFr: 'France',
    nameEn: 'France',
    taglineFr: "Étudier au cœur de l'Europe, dans des écoles privées d'excellence",
    taglineEn: 'Study in Europe through excellent private schools',
    nextIntakeLabelFr: 'Septembre 2026',
    nextIntakeLabelEn: 'September 2026',
    mainLanguageFr: 'Français',
    mainLanguageEn: 'French',
    whyStudyFr:
      'La France combine excellence académique, coût maîtrisé et diaspora africaine forte.',
    whyStudyEn:
      'France combines academic excellence, manageable costs and a strong African diaspora.',
    marketingDescriptionFr:
      "Au lancement, KPB se concentre sur l'admission dans les écoles privées françaises (OMNES, ICN, Schiller, IGENSIA). Campus France pour le public arrive en septembre 2026.",
    marketingDescriptionEn:
      'At launch, KPB focuses on private French schools (OMNES, ICN, Schiller, IGENSIA). Public Campus France path opens September 2026.',
    whyStudyBulletsFr: [
      'Plus de 250 ans d\'excellence académique',
      'Frais privés accessibles (5 000 à 18 000 € / an)',
      'Coût de la vie ~ 1 000 € / mois',
      'Visa post-études Talent / APS jusqu\'à 12 mois',
    ],
    whyStudyBulletsEn: [
      '250+ years of academic excellence',
      'Accessible private fees (€5,000–18,000/year)',
      'Living costs ~ €1,000/month',
      'Post-study Talent visa up to 12 months',
    ],
    howItWorksFr:
      '1. Quiz d\'éligibilité · 2. Choix école privée partenaire · 3. Dossier admission · 4. Visa long séjour · 5. Logement & arrivée avec KPB.',
    howItWorksEn:
      '1. Eligibility quiz · 2. Pick a partner school · 3. Admission file · 4. Long-stay visa · 5. Housing & arrival with KPB.',
    costsOverviewFr:
      'Scolarité : 5 000–18 000 €/an selon école. Vie : 800–1 200 €/mois. Preuve de fonds visa : minimum 7 380 €/an.',
    costsOverviewEn:
      'Tuition: €5,000–18,000/year. Living: €800–1,200/month. Visa funds: min €7,380/year.',
    languageSectionFr:
      'DELF/DALF/TCF B2 pour programmes francophones. IELTS 6.5+ ou TOEFL iBT 85+ pour programmes anglophones.',
    languageSectionEn:
      'DELF/DALF/TCF B2 for French tracks. IELTS 6.5+ or TOEFL iBT 85+ for English tracks.',
    partnerSchoolsFr:
      'OMNES Education (ECE, ESCE, INSEEC, Sup de Pub, HEIP), ICN, Schiller Paris, IGENSIA Education (IGENSIA School of Business, IGENSIA Tech, IGENSIA RH, American Business College). Certaines formations ouvrent aussi en rentrée décalée, de janvier à mars.',
    partnerSchoolsEn:
      'OMNES Education (ECE, ESCE, INSEEC, Sup de Pub, HEIP), ICN, Schiller Paris, IGENSIA Education (IGENSIA School of Business, IGENSIA Tech, IGENSIA RH, American Business College). Some programmes also offer a January–March intake.',
    scholarshipsSectionFr:
      'Bourses partielles possibles via partenaires et dispositifs locaux. KPB t\'aide à identifier les options.',
    scholarshipsSectionEn:
      'Partial scholarships may be available via partners. KPB helps you identify options.',
    whatsAppPrefillFr:
      'Bonjour KPB, je souhaite étudier en France (écoles privées). Pouvez-vous m\'accompagner ?',
    whatsAppPrefillEn:
      'Hello KPB, I want to study in France (private schools). Can you support me?',
    mvpNoteFr:
      'Campus France (universités publiques) — Bientôt disponible · Septembre 2026',
    mvpNoteEn:
      'Campus France (public universities) — Coming soon · September 2026',
    tuitionRangeFr: '5 000 – 18 000 € / an',
    tuitionRangeEn: '€5,000 – 18,000 / year',
    livingCostRangeFr: '800 – 1 200 € / mois',
    livingCostRangeEn: '€800 – 1,200 / month',
    visaOverviewFr: 'Visa long séjour étudiant après admission confirmée.',
    visaOverviewEn: 'Long-stay student visa after confirmed admission.',
    admissionDifficultyFr: 'Moyenne',
    admissionDifficultyEn: 'Medium',
    popularFieldIds: ['business', 'computer_science', 'engineering'],
    quiz: {
      questions: [
        levelQuestion,
        diplomaQuestion,
        q(
          'q3_grades',
          'Quelle est ta moyenne générale estimée ?',
          'What is your estimated GPA?',
          [
            ['excellent', 'Plus de 14/20', 'Above 14/20'],
            ['good', 'Entre 12 et 14/20', '12 to 14/20'],
            ['average', 'Entre 10 et 12/20', '10 to 12/20'],
            ['below', 'Moins de 10/20', 'Below 10/20'],
          ],
        ),
        budgetQuestion,
        q(
          'q5_french_level',
          'Quel est ton niveau de français ?',
          'What is your French level?',
          [
            ['native', 'Natif / langue maternelle', 'Native'],
            ['fluent', 'Courant (B2/C1)', 'Fluent (B2/C1)'],
            ['intermediate', 'Intermédiaire (B1)', 'Intermediate (B1)'],
            ['basic', 'Scolaire / faible', 'Basic'],
          ],
        ),
        q(
          'q6_visa_history',
          'As-tu déjà eu un refus de visa Schengen ?',
          'Have you had a Schengen visa refusal?',
          [
            ['no', 'Non', 'No'],
            ['yes_recent', 'Oui, il y a moins de 2 ans', 'Yes, less than 2 years ago'],
            ['yes_old', 'Oui, il y a plus de 2 ans', 'Yes, more than 2 years ago'],
          ],
        ),
        q(
          'q7_financial_proof',
          "Peux-tu prouver des fonds d'au moins 7 380 € ?",
          'Can you prove funds of at least €7,380?',
          [
            ['yes_self', "Oui, j'ai les fonds", 'Yes, I have the funds'],
            ['yes_family', 'Oui, via ma famille', 'Yes, via my family'],
            ['yes_garant_france', 'Oui, garant en France', 'Yes, sponsor in France'],
            ['no', 'Non, c\'est compliqué', 'No, it is difficult'],
          ],
        ),
      ],
      verdicts: defaultVerdicts('France', 'France', ['mar', 'tur']),
    },
  },
  {
    id: 'deu',
    code: 'DEU',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://www.daad.de/en/studying-in-germany/',
    flagEmoji: '🇩🇪',
    displayOrder: 2,
    nameFr: 'Allemagne',
    nameEn: 'Germany',
    taglineFr: 'Universités publiques quasi gratuites + parcours langue KPB',
    taglineEn: 'Near-free public universities + KPB language track',
    nextIntakeLabelFr: 'Septembre 2026',
    nextIntakeLabelEn: 'September 2026',
    mainLanguageFr: 'Allemand (+ anglais pour certains programmes)',
    mainLanguageEn: 'German (+ English for some programs)',
    whyStudyFr: 'Excellence en ingénierie et frais de scolarité très bas.',
    whyStudyEn: 'Engineering excellence and very low tuition.',
    marketingDescriptionFr:
      'KPB propose un parcours langue 40 semaines (A1→C1) + admission universitaire + visa + logement.',
    marketingDescriptionEn:
      'KPB offers a 40-week language track (A1→C1) + university admission + visa + housing.',
    whyStudyBulletsFr: [
      'Études quasi gratuites (0–1 500 €/an)',
      'Excellence ingénierie & informatique',
      'Visa recherche d\'emploi 18 mois',
    ],
    whyStudyBulletsEn: [
      'Near-free tuition (€0–1,500/year)',
      'Engineering & IT excellence',
      '18-month job-search visa',
    ],
    howItWorksFr:
      'Parcours langue → Admission université → Compte bloqué → Visa → Arrivée.',
    howItWorksEn: 'Language track → University admission → Blocked account → Visa → Arrival.',
    costsOverviewFr:
      'Scolarité publique : 0–1 500 €/an. Compte bloqué ~ 11 904 €. Parcours langue KPB : 9 500 €.',
    costsOverviewEn:
      'Public tuition: €0–1,500/year. Blocked account ~€11,904. KPB language track: €9,500.',
    languageSectionFr: 'B2/C1 allemand ou programmes 100 % anglais selon filière.',
    languageSectionEn: 'German B2/C1 or 100% English programs depending on track.',
    partnerSchoolsFr: 'ICN Berlin, Schiller Heidelberg, universités publiques partenaires.',
    partnerSchoolsEn: 'ICN Berlin, Schiller Heidelberg, partner public universities.',
    scholarshipsSectionFr: 'Bourses DAAD et programmes régionaux possibles.',
    scholarshipsSectionEn: 'DAAD and regional programs may apply.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier en Allemagne. Pouvez-vous m\'aider ?',
    whatsAppPrefillEn: 'Hello KPB, I want to study in Germany. Can you help?',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '0 – 1 500 € / an',
    tuitionRangeEn: '€0 – 1,500 / year',
    livingCostRangeFr: '900 – 1 100 € / mois',
    livingCostRangeEn: '€900 – 1,100 / month',
    visaOverviewFr: 'Compte bloqué + visa national requis.',
    visaOverviewEn: 'Blocked account + national visa required.',
    admissionDifficultyFr: 'Moyenne',
    admissionDifficultyEn: 'Medium',
    popularFieldIds: ['engineering', 'computer_science'],
    quiz: {
      questions: [
        levelQuestion,
        q(
          'q2_german_level',
          "Quel est ton niveau d'allemand ?",
          'What is your German level?',
          [
            ['advanced', 'B2 ou plus', 'B2 or above'],
            ['intermediate', 'B1 / scolaire', 'B1 / school'],
            ['beginner', 'Débutant', 'Beginner'],
            ['none', 'Aucune notion', 'None'],
          ],
        ),
        englishQuestion,
        q(
          'q4_language_track',
          'Es-tu prêt(e) à suivre un programme intensif de langue allemande ?',
          'Are you ready for an intensive German language program?',
          [
            ['yes_full', 'Oui, 40 semaines', 'Yes, 40 weeks'],
            ['yes_partial', 'Oui, version courte', 'Yes, shorter track'],
            ['no_only_english', 'Non, anglais uniquement', 'No, English only'],
          ],
        ),
        q(
          'q5_blocked_account',
          'Peux-tu mobiliser ~12 000 € pour un compte bloqué visa ?',
          'Can you mobilize ~€12,000 for a blocked account?',
          [
            ['yes_easily', 'Oui, sans problème', 'Yes, easily'],
            ['yes_difficult', 'Oui, mais tendu', 'Yes, but tight'],
            ['no', 'Non', 'No'],
          ],
        ),
        q(
          'q6_field',
          'Quel domaine veux-tu étudier ?',
          'Which field do you want to study?',
          [
            ['engineering', 'Ingénierie / Informatique', 'Engineering / IT'],
            ['sciences', 'Sciences', 'Sciences'],
            ['business', 'Business', 'Business'],
            ['other', 'Autre', 'Other'],
          ],
        ),
      ],
      verdicts: defaultVerdicts('Allemagne', 'Germany'),
    },
  },
  {
    id: 'usa',
    code: 'USA',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://educationusa.state.gov/',
    flagEmoji: '🇺🇸',
    displayOrder: 3,
    nameFr: 'USA',
    nameEn: 'USA',
    taglineFr: 'Le plus grand écosystème universitaire anglophone',
    taglineEn: 'The largest English-speaking university ecosystem',
    nextIntakeLabelFr: 'Septembre 2026',
    nextIntakeLabelEn: 'September 2026',
    mainLanguageFr: 'Anglais',
    mainLanguageEn: 'English',
    whyStudyFr: 'Flexibilité académique et réseau professionnel mondial.',
    whyStudyEn: 'Academic flexibility and global professional network.',
    marketingDescriptionFr: 'Programmes Schiller Tampa et universités partenaires KPB.',
    marketingDescriptionEn: 'Schiller Tampa programs and KPB partner universities.',
    whyStudyBulletsFr: ['OPT 12–36 mois', 'Campus modernes', 'Programmes STEM'],
    whyStudyBulletsEn: ['OPT 12–36 months', 'Modern campuses', 'STEM programs'],
    howItWorksFr: 'Admission → I-20 → Visa F-1 → Arrivée campus.',
    howItWorksEn: 'Admission → I-20 → F-1 visa → Campus arrival.',
    costsOverviewFr: 'Scolarité : 15 000–50 000 €/an. Vie : 1 000–1 400 €/mois.',
    costsOverviewEn: 'Tuition: €15,000–50,000/year. Living: €1,000–1,400/month.',
    languageSectionFr: 'TOEFL iBT 80+ ou IELTS 6.5+ recommandés.',
    languageSectionEn: 'TOEFL iBT 80+ or IELTS 6.5+ recommended.',
    partnerSchoolsFr: 'Schiller Tampa et réseau partenaires KPB.',
    partnerSchoolsEn: 'Schiller Tampa and KPB partner network.',
    scholarshipsSectionFr: 'Merit-based scholarships selon établissement.',
    scholarshipsSectionEn: 'Merit-based scholarships per institution.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier aux USA.',
    whatsAppPrefillEn: 'Hello KPB, I want to study in the USA.',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '15 000 – 50 000 € / an',
    tuitionRangeEn: '€15,000 – 50,000 / year',
    livingCostRangeFr: '1 000 – 1 400 € / mois',
    livingCostRangeEn: '€1,000 – 1,400 / month',
    visaOverviewFr: 'Visa F-1 après I-20.',
    visaOverviewEn: 'F-1 visa after I-20.',
    admissionDifficultyFr: 'Haute',
    admissionDifficultyEn: 'High',
    popularFieldIds: ['business', 'computer_science'],
    quiz: {
      questions: [levelQuestion, diplomaQuestion, englishQuestion, budgetQuestion],
      verdicts: defaultVerdicts('USA', 'USA', ['can', 'mar']),
    },
  },
  {
    id: 'can',
    code: 'CAN',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://www.educanada.ca/index.aspx?lang=eng',
    flagEmoji: '🇨🇦',
    displayOrder: 4,
    nameFr: 'Canada',
    nameEn: 'Canada',
    taglineFr: 'Qualité de vie et voies post-études',
    taglineEn: 'Quality of life and post-study pathways',
    nextIntakeLabelFr: 'Janvier 2027',
    nextIntakeLabelEn: 'January 2027',
    mainLanguageFr: 'Anglais / Français',
    mainLanguageEn: 'English / French',
    whyStudyFr: 'Permis post-diplôme et écosystème accueillant.',
    whyStudyEn: 'Post-graduation work permit and welcoming ecosystem.',
    marketingDescriptionFr: 'Bourse McCall MacBain en avant-plan au lancement.',
    marketingDescriptionEn: 'McCall MacBain scholarship highlighted at launch.',
    whyStudyBulletsFr: ['PGWP jusqu\'à 3 ans', 'Sécurité & qualité de vie'],
    whyStudyBulletsEn: ['PGWP up to 3 years', 'Safety & quality of life'],
    howItWorksFr: 'Admission → Permis d\'études → Arrivée.',
    howItWorksEn: 'Admission → Study permit → Arrival.',
    costsOverviewFr: 'Scolarité : 7 000–25 000 €/an.',
    costsOverviewEn: 'Tuition: €7,000–25,000/year.',
    languageSectionFr: 'IELTS 6.5+ ou équivalent selon province.',
    languageSectionEn: 'IELTS 6.5+ or equivalent depending on province.',
    partnerSchoolsFr: 'Réseau en expansion — KPB complète les partenaires.',
    partnerSchoolsEn: 'Expanding network — KPB adds partners.',
    scholarshipsSectionFr: 'McCall MacBain Scholarship (McGill) — voir module Bourses.',
    scholarshipsSectionEn: 'McCall MacBain Scholarship (McGill) — see Scholarships.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier au Canada.',
    whatsAppPrefillEn: 'Hello KPB, I want to study in Canada.',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '7 000 – 25 000 € / an',
    tuitionRangeEn: '€7,000 – 25,000 / year',
    livingCostRangeFr: '900 – 1 300 € / mois',
    livingCostRangeEn: '€900 – 1,300 / month',
    visaOverviewFr: 'Permis d\'études + options post-diplôme.',
    visaOverviewEn: 'Study permit + post-graduation options.',
    admissionDifficultyFr: 'Moyenne',
    admissionDifficultyEn: 'Medium',
    popularFieldIds: ['business', 'computer_science'],
    quiz: {
      questions: [levelQuestion, diplomaQuestion, englishQuestion, budgetQuestion],
      verdicts: defaultVerdicts('Canada', 'Canada'),
    },
  },
  {
    id: 'mar',
    code: 'MAR',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://www.amci.ma/cooperation-academique',
    flagEmoji: '🇲🇦',
    displayOrder: 5,
    nameFr: 'Maroc',
    nameEn: 'Morocco',
    taglineFr: 'Option francophone accessible depuis l\'Afrique de l\'Ouest',
    taglineEn: 'Accessible French-speaking option from West Africa',
    nextIntakeLabelFr: 'Septembre 2026',
    nextIntakeLabelEn: 'September 2026',
    mainLanguageFr: 'Français',
    mainLanguageEn: 'French',
    whyStudyFr: 'Coût maîtrisé et proximité culturelle.',
    whyStudyEn: 'Controlled costs and cultural proximity.',
    marketingDescriptionFr: 'ISMAGI et ESA Casablanca — partenaires KPB.',
    marketingDescriptionEn: 'ISMAGI and ESA Casablanca — KPB partners.',
    whyStudyBulletsFr: ['Frais abordables', 'Francophone', 'Stages locaux'],
    whyStudyBulletsEn: ['Affordable fees', 'French-speaking', 'Local internships'],
    howItWorksFr: 'Quiz → Choix école → Dossier → Inscription.',
    howItWorksEn: 'Quiz → School choice → File → Enrollment.',
    costsOverviewFr: 'Scolarité : 2 500–6 000 €/an. Vie : 300–550 €/mois.',
    costsOverviewEn: 'Tuition: €2,500–6,000/year. Living: €300–550/month.',
    languageSectionFr: 'Français B2 ou anglais selon programme.',
    languageSectionEn: 'French B2 or English depending on program.',
    partnerSchoolsFr: 'ISMAGI, ESA Casablanca.',
    partnerSchoolsEn: 'ISMAGI, ESA Casablanca.',
    scholarshipsSectionFr: 'Aides locales possibles selon établissement.',
    scholarshipsSectionEn: 'Local aid may apply per institution.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier au Maroc.',
    whatsAppPrefillEn: 'Hello KPB, I want to study in Morocco.',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '2 500 – 6 000 € / an',
    tuitionRangeEn: '€2,500 – 6,000 / year',
    livingCostRangeFr: '300 – 550 € / mois',
    livingCostRangeEn: '€300 – 550 / month',
    visaOverviewFr: 'Visa étudiant selon nationalité.',
    visaOverviewEn: 'Student visa depending on nationality.',
    admissionDifficultyFr: 'Faible',
    admissionDifficultyEn: 'Low',
    popularFieldIds: ['business', 'computer_science'],
    quiz: {
      questions: [
        levelQuestion,
        diplomaQuestion,
        q(
          'q3_french_level',
          'Quel est ton niveau de français ?',
          'What is your French level?',
          [
            ['native', 'Natif', 'Native'],
            ['fluent', 'Courant', 'Fluent'],
            ['intermediate', 'Intermédiaire', 'Intermediate'],
            ['basic', 'Faible', 'Basic'],
          ],
        ),
        budgetQuestion,
      ],
      verdicts: defaultVerdicts('Maroc', 'Morocco', ['tur', 'fra']),
    },
  },
  {
    id: 'tur',
    code: 'TUR',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://www.turkiyeburslari.gov.tr/',
    flagEmoji: '🇹🇷',
    displayOrder: 6,
    nameFr: 'Turquie',
    nameEn: 'Turkey',
    taglineFr: 'Campus modernes et coût maîtrisé',
    taglineEn: 'Modern campuses and controlled costs',
    nextIntakeLabelFr: 'Septembre 2026',
    nextIntakeLabelEn: 'September 2026',
    mainLanguageFr: 'Anglais / Turc',
    mainLanguageEn: 'English / Turkish',
    whyStudyFr: 'Programmes anglophones abordables.',
    whyStudyEn: 'Affordable English-taught programs.',
    marketingDescriptionFr: 'BAU Istanbul — partenaire KPB.',
    marketingDescriptionEn: 'BAU Istanbul — KPB partner.',
    whyStudyBulletsFr: ['Frais compétitifs', 'Ville dynamique', 'Programmes IT & business'],
    whyStudyBulletsEn: ['Competitive fees', 'Dynamic city', 'IT & business programs'],
    howItWorksFr: 'Admission → Visa étudiant → Logement.',
    howItWorksEn: 'Admission → Student visa → Housing.',
    costsOverviewFr: 'Scolarité : 4 000–12 000 €/an.',
    costsOverviewEn: 'Tuition: €4,000–12,000/year.',
    languageSectionFr: 'Programmes anglophones disponibles (IELTS recommandé).',
    languageSectionEn: 'English programs available (IELTS recommended).',
    partnerSchoolsFr: 'BAU Istanbul.',
    partnerSchoolsEn: 'BAU Istanbul.',
    scholarshipsSectionFr: 'Bourses partielles BAU possibles.',
    scholarshipsSectionEn: 'Partial BAU scholarships possible.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier en Turquie.',
    whatsAppPrefillEn: 'Hello KPB, I want to study in Turkey.',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '4 000 – 12 000 € / an',
    tuitionRangeEn: '€4,000 – 12,000 / year',
    livingCostRangeFr: '400 – 700 € / mois',
    livingCostRangeEn: '€400 – 700 / month',
    visaOverviewFr: 'Visa étudiant standard.',
    visaOverviewEn: 'Standard student visa.',
    admissionDifficultyFr: 'Moyenne',
    admissionDifficultyEn: 'Medium',
    popularFieldIds: ['business', 'engineering'],
    quiz: {
      questions: [levelQuestion, diplomaQuestion, englishQuestion, budgetQuestion],
      verdicts: defaultVerdicts('Turquie', 'Turkey', ['mar', 'are']),
    },
  },
  {
    id: 'are',
    code: 'ARE',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://u.ae/en/information-and-services/education/higher-education',
    flagEmoji: '🇦🇪',
    displayOrder: 7,
    nameFr: 'EAU (Dubaï)',
    nameEn: 'UAE (Dubai)',
    taglineFr: 'Programmes anglophones professionnalisants',
    taglineEn: 'Career-oriented English programs',
    nextIntakeLabelFr: 'Septembre 2026',
    nextIntakeLabelEn: 'September 2026',
    mainLanguageFr: 'Anglais',
    mainLanguageEn: 'English',
    whyStudyFr: 'Hub business international.',
    whyStudyEn: 'International business hub.',
    marketingDescriptionFr: 'GBS Dubai — partenaire KPB.',
    marketingDescriptionEn: 'GBS Dubai — KPB partner.',
    whyStudyBulletsFr: ['100 % anglais', 'Réseau pro GCC', 'Campus moderne'],
    whyStudyBulletsEn: ['100% English', 'GCC professional network', 'Modern campus'],
    howItWorksFr: 'Admission → Visa sponsorisé école → Arrivée.',
    howItWorksEn: 'Admission → School-sponsored visa → Arrival.',
    costsOverviewFr: 'Scolarité : 6 000–12 000 €/an.',
    costsOverviewEn: 'Tuition: €6,000–12,000/year.',
    languageSectionFr: 'Anglais B2 minimum.',
    languageSectionEn: 'English B2 minimum.',
    partnerSchoolsFr: 'GBS Dubai.',
    partnerSchoolsEn: 'GBS Dubai.',
    scholarshipsSectionFr: 'Facilités de paiement selon programme.',
    scholarshipsSectionEn: 'Payment plans per program.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier à Dubaï.',
    whatsAppPrefillEn: 'Hello KPB, I want to study in Dubai.',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '6 000 – 12 000 € / an',
    tuitionRangeEn: '€6,000 – 12,000 / year',
    livingCostRangeFr: '900 – 1 400 € / mois',
    livingCostRangeEn: '€900 – 1,400 / month',
    visaOverviewFr: 'Visa étudiant sponsorisé par l\'établissement.',
    visaOverviewEn: 'Institution-sponsored student visa.',
    admissionDifficultyFr: 'Moyenne',
    admissionDifficultyEn: 'Medium',
    popularFieldIds: ['business'],
    quiz: {
      questions: [levelQuestion, englishQuestion, budgetQuestion],
      verdicts: defaultVerdicts('EAU', 'UAE', ['tur', 'mar']),
    },
  },
  {
    id: 'gbr',
    code: 'GBR',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://www.gov.uk/student-visa',
    flagEmoji: '🇬🇧',
    displayOrder: 8,
    nameFr: 'Royaume-Uni',
    nameEn: 'United Kingdom',
    taglineFr: 'Universités prestigieuses en anglais natif',
    taglineEn: 'Prestigious universities in native English',
    nextIntakeLabelFr: 'Janvier 2027',
    nextIntakeLabelEn: 'January 2027',
    mainLanguageFr: 'Anglais',
    mainLanguageEn: 'English',
    whyStudyFr: 'Diplômes reconnus mondialement.',
    whyStudyEn: 'Globally recognized degrees.',
    marketingDescriptionFr: 'Fiche propre UK — réseau partenaires en expansion.',
    marketingDescriptionEn: 'Dedicated UK profile — expanding partner network.',
    whyStudyBulletsFr: ['Graduate Route 2 ans', 'Excellence recherche'],
    whyStudyBulletsEn: ['2-year Graduate Route', 'Research excellence'],
    howItWorksFr: 'Admission → CAS → Student visa → Arrivée.',
    howItWorksEn: 'Admission → CAS → Student visa → Arrival.',
    costsOverviewFr: 'Scolarité : 13 000–35 000 €/an.',
    costsOverviewEn: 'Tuition: €13,000–35,000/year.',
    languageSectionFr: 'IELTS 6.5+ ou équivalent.',
    languageSectionEn: 'IELTS 6.5+ or equivalent.',
    partnerSchoolsFr: 'Réseau en cours d\'intégration KPB.',
    partnerSchoolsEn: 'KPB network expanding.',
    scholarshipsSectionFr: 'Chevening et bourses universitaires possibles.',
    scholarshipsSectionEn: 'Chevening and university scholarships possible.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier au Royaume-Uni.',
    whatsAppPrefillEn: 'Hello KPB, I want to study in the UK.',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '13 000 – 35 000 € / an',
    tuitionRangeEn: '€13,000 – 35,000 / year',
    livingCostRangeFr: '1 000 – 1 600 € / mois',
    livingCostRangeEn: '€1,000 – 1,600 / month',
    visaOverviewFr: 'Student visa UK (CAS).',
    visaOverviewEn: 'UK student visa (CAS).',
    admissionDifficultyFr: 'Haute',
    admissionDifficultyEn: 'High',
    popularFieldIds: ['business', 'computer_science'],
    quiz: {
      questions: [levelQuestion, diplomaQuestion, englishQuestion, budgetQuestion],
      verdicts: defaultVerdicts('Royaume-Uni', 'UK', ['can', 'esp']),
    },
  },
  {
    id: 'esp',
    code: 'ESP',
    lastVerifiedAt: '2026-06-26',
    sourceUrl: 'https://www.studyinspain.info/en',
    flagEmoji: '🇪🇸',
    displayOrder: 9,
    nameFr: 'Espagne',
    nameEn: 'Spain',
    taglineFr: 'Programmes internationaux à Madrid',
    taglineEn: 'International programs in Madrid',
    nextIntakeLabelFr: 'Septembre 2026',
    nextIntakeLabelEn: 'September 2026',
    mainLanguageFr: 'Anglais / Espagnol',
    mainLanguageEn: 'English / Spanish',
    whyStudyFr: 'Qualité de vie méditerranéenne.',
    whyStudyEn: 'Mediterranean quality of life.',
    marketingDescriptionFr: 'Schiller Madrid — partenaire KPB.',
    marketingDescriptionEn: 'Schiller Madrid — KPB partner.',
    whyStudyBulletsFr: ['Programmes anglophones', 'Vie étudiante dynamique'],
    whyStudyBulletsEn: ['English programs', 'Vibrant student life'],
    howItWorksFr: 'Admission → Visa Schengen → Logement.',
    howItWorksEn: 'Admission → Schengen visa → Housing.',
    costsOverviewFr: 'Scolarité : 15 000–20 000 €/an.',
    costsOverviewEn: 'Tuition: €15,000–20,000/year.',
    languageSectionFr: 'Programmes anglophones Schiller — IELTS recommandé.',
    languageSectionEn: 'Schiller English programs — IELTS recommended.',
    partnerSchoolsFr: 'Schiller Madrid.',
    partnerSchoolsEn: 'Schiller Madrid.',
    scholarshipsSectionFr: 'Aides partenaires selon dossier.',
    scholarshipsSectionEn: 'Partner aid depending on file.',
    whatsAppPrefillFr: 'Bonjour KPB, je veux étudier en Espagne.',
    whatsAppPrefillEn: 'Hello KPB, I want to study in Spain.',
    mvpNoteFr: '',
    mvpNoteEn: '',
    tuitionRangeFr: '15 000 – 20 000 € / an',
    tuitionRangeEn: '€15,000 – 20,000 / year',
    livingCostRangeFr: '700 – 1 100 € / mois',
    livingCostRangeEn: '€700 – 1,100 / month',
    visaOverviewFr: 'Visa étudiant Schengen.',
    visaOverviewEn: 'Schengen student visa.',
    admissionDifficultyFr: 'Moyenne',
    admissionDifficultyEn: 'Medium',
    popularFieldIds: ['business'],
    quiz: {
      questions: [levelQuestion, diplomaQuestion, englishQuestion, budgetQuestion],
      verdicts: defaultVerdicts('Espagne', 'Spain', ['fra', 'mar']),
    },
  },
];
