export type PartnerProgramSeed = {
  id: string;
  fieldId: string;
  nameFr: string;
  nameEn: string;
  levelFr: string;
  levelEn: string;
  durationFr: string;
  durationEn: string;
  tuitionFr: string;
  tuitionEn: string;
  languageFr: string;
  languageEn: string;
  requirementsFr: string[];
  requirementsEn: string[];
};

export type PartnerInstitutionSeed = {
  id: string;
  countryId: string;
  nameFr: string;
  nameEn: string;
  locationFr: string;
  locationEn: string;
  overviewFr: string;
  overviewEn: string;
  studyLevels: string[];
  programs: PartnerProgramSeed[];
};

// `Program.fieldId` is a plain indexed column, not a foreign key: these must be
// ids of the d01..d12 taxonomy (src/modules/orientation/orientation-fields.data.ts),
// the one the app filters on and the catalog scores against. The former
// 'business' / 'computer_science' / 'engineering' are the three demo fields of
// prisma/seed.ts, so these programs never surfaced under any real field.
const COMPUTER_SCIENCE = 'd01'; // Informatique & Intelligence Artificielle
const BUSINESS = 'd02'; // Commerce & Management
const ENGINEERING = 'd03'; // Ingénierie & Sciences
const HEALTH = 'd04'; // Santé & Sciences de la Vie
const ARCHITECTURE = 'd05'; // Architecture & BTP
const DESIGN = 'd06'; // Design, Médias & Communication

function p(
  id: string,
  name: string,
  level: string,
  duration: string,
  tuitionFr: string,
  tuitionEn: string,
  language: string,
  fieldId: string,
  requirements: string[] = [],
): PartnerProgramSeed {
  return {
    id,
    fieldId,
    nameFr: name,
    nameEn: name,
    levelFr: level,
    levelEn: level,
    durationFr: duration,
    durationEn: duration,
    tuitionFr,
    tuitionEn,
    languageFr: language,
    languageEn: language,
    requirementsFr: requirements,
    requirementsEn: requirements,
  };
}

const icnRequirements = [
  'Bac ou équivalent',
  'Entretien + oral d\'anglais',
  'Relevés de notes, CV, lettre de motivation',
];

const schillerRequirements = [
  'Diplôme secondaire (Bachelor) ou Bachelor (Master)',
  'TOEFL iBT 51 / IELTS 5.5 ou équivalent',
  'Transcripts + contrat d\'inscription',
];

const ismagiRequirements = [
  'Bac selon filière',
  'Dossier de candidature + test écrit/oral',
];

function schillerBachelors(prefix: string, tuition: string): PartnerProgramSeed[] {
  const names = [
    'BA in International Relations and Diplomacy',
    'BS in International Business',
    'BS in International Hospitality and Tourism Management',
    'BS in International Marketing',
    'BS in Computer Science',
    'BS in Applied Mathematics and Artificial Intelligence',
    'BS in Business Analytics',
  ];
  return names.map((name, index) =>
    p(
      `${prefix}-bach-${index + 1}`,
      name,
      'Bachelor',
      '4 ans',
      tuition,
      tuition,
      'Anglais',
      name.includes('Computer') || name.includes('Mathematics')
        ? COMPUTER_SCIENCE
        : BUSINESS,
      schillerRequirements,
    ),
  );
}

function schillerMastersEurope(prefix: string): PartnerProgramSeed[] {
  const rows: [string, string][] = [
    ['MA in International Relations and Diplomacy', '16 560 €/an'],
    ['MS in Digital Marketing and E-commerce', '16 560 €/an'],
    ['MS in Global Finance', '16 560 €/an'],
    ['MS in Sustainability Management', '16 500 €/an'],
    ['MS in Data Science', '16 500 €/an'],
    ['MBA', '16 560 €/an'],
    ['MBA in International Business', '20 700 €/an'],
  ];
  return rows.map(([name, tuition], index) =>
    p(
      `${prefix}-msc-${index + 1}`,
      name,
      name.startsWith('MBA') ? 'MBA' : 'Master',
      '2 ans',
      tuition,
      tuition,
      'Anglais',
      name.includes('Data') ? COMPUTER_SCIENCE : BUSINESS,
      schillerRequirements,
    ),
  );
}

function schillerMastersTampa(prefix: string): PartnerProgramSeed[] {
  const rows: [string, string][] = [
    ['MA in International Relations and Diplomacy', '19 620 USD/an'],
    ['MS in Digital Marketing and E-commerce', '19 620 USD/an'],
    ['MS in Global Finance', '19 620 USD/an'],
    ['MS in Sustainability Management', '19 410 USD/an'],
    ['MS in Data Science', '19 410 USD/an'],
    ['MBA', '19 620 USD/an'],
    ['MBA in International Business', '24 525 USD/an'],
  ];
  return rows.map(([name, tuition], index) =>
    p(
      `${prefix}-msc-${index + 1}`,
      name,
      name.startsWith('MBA') ? 'MBA' : 'Master',
      '2 ans',
      tuition,
      tuition,
      'Anglais',
      name.includes('Data') ? COMPUTER_SCIENCE : BUSINESS,
      schillerRequirements,
    ),
  );
}

export const PARTNER_INSTITUTION_SEEDS: PartnerInstitutionSeed[] = [
  {
    id: 'partner-icn',
    countryId: 'fra',
    nameFr: 'ICN Business School',
    nameEn: 'ICN Business School',
    locationFr: 'Paris La Défense · Berlin',
    locationEn: 'Paris La Défense · Berlin',
    overviewFr:
      'Grande école de management triple accréditation (AACSB, EQUIS, AMBA).',
    overviewEn:
      'Triple-accredited business school (AACSB, EQUIS, AMBA).',
    studyLevels: ['Bachelor', 'Master', 'Doctorat', 'DBA'],
    programs: [
      p('partner-p-icn-1', 'International BBA — Paris', 'Bachelor', '4 ans', '9 900 €/an', '9 900 EUR/year', 'Bilingue EN/FR', BUSINESS, icnRequirements),
      p('partner-p-icn-2', 'International BBA — Berlin', 'Bachelor', '4 ans', '9 900 €/an', '9 900 EUR/year', 'Anglais', BUSINESS, icnRequirements),
      p('partner-p-icn-3', 'Bachelor in Management', 'Bachelor', '3 ans', '9 200 €/an', '9 200 EUR/year', 'FR/EN', BUSINESS, icnRequirements),
      p('partner-p-icn-4', 'Bachelor Tech & Innovation Management', 'Bachelor', '3 ans', '8 000 €/an', '8 000 EUR/year', 'FR/EN', BUSINESS, icnRequirements),
      p('partner-p-icn-5', 'Master in Management (Grande École)', 'Master', '2 ans', '14 500 €/an', '14 500 EUR/year', 'FR/EN', BUSINESS, icnRequirements),
      p('partner-p-icn-6', 'MSc International Management MIEX', 'Master', '2 ans', '10 000 €/an', '10 000 EUR/year', 'Anglais', BUSINESS, icnRequirements),
      p('partner-p-icn-7', 'MSc (DESSMI)', 'Master', '2 ans', '9 500 €/an', '9 500 EUR/year', 'EN/FR', BUSINESS, icnRequirements),
      p('partner-p-icn-8', 'PhD', 'Doctorat', 'Variable', '9 000 €/an', '9 000 EUR/year', 'EN/FR', BUSINESS, icnRequirements),
      p('partner-p-icn-9', 'DBA', 'DBA', 'Variable', '30 000 € (programme)', '30 000 EUR (program)', 'EN/FR', BUSINESS, icnRequirements),
    ],
  },
  {
    id: 'partner-schiller-europe',
    countryId: 'esp',
    nameFr: 'Schiller International University — Europe',
    nameEn: 'Schiller International University — Europe',
    locationFr: 'Madrid · Paris · Heidelberg',
    locationEn: 'Madrid · Paris · Heidelberg',
    overviewFr:
      'Université américaine accréditée, campus européens, programmes 100 % anglais.',
    overviewEn:
      'Accredited American university with European campuses, English-only programs.',
    studyLevels: ['Bachelor', 'Master', 'MBA'],
    programs: [
      ...schillerBachelors('partner-p-sch-eu', '15 420 €/an'),
      ...schillerMastersEurope('partner-p-sch-eu'),
    ],
  },
  {
    id: 'partner-schiller-tampa',
    countryId: 'usa',
    nameFr: 'Schiller International University — Tampa',
    nameEn: 'Schiller International University — Tampa',
    locationFr: 'Tampa, Floride',
    locationEn: 'Tampa, Florida',
    overviewFr: 'Campus américain Schiller — programmes Bachelor et MBA en anglais.',
    overviewEn: 'Schiller US campus — Bachelor and MBA programs in English.',
    studyLevels: ['Bachelor', 'Master', 'MBA'],
    programs: [
      ...schillerBachelors('partner-p-sch-us', '17 610 USD/an'),
      ...schillerMastersTampa('partner-p-sch-us'),
    ],
  },
  {
    id: 'partner-ismagi',
    countryId: 'mar',
    nameFr: 'ISMAGI',
    nameEn: 'ISMAGI',
    locationFr: 'Rabat',
    locationEn: 'Rabat',
    overviewFr:
      'Institut Supérieur de Management et d\'Administration des Affaires — Licences, Masters et Ingénieur.',
    overviewEn:
      'Higher institute of management and business administration — Bachelor, Master and Engineering.',
    studyLevels: ['Licence', 'Master', 'Ingénieur'],
    programs: [
      ...[
        'Comptabilité, Contrôle et Audit',
        'Marketing Digital & Développement Commercial',
        'Logistique, Transport et Commerce International',
        'Gestion des Ressources Humaines',
      ].map((name, i) =>
        p(`partner-p-ismagi-lic-mgt-${i + 1}`, name, 'Licence', '3 ans', '40 000 MAD/an', '40 000 MAD/year', 'Français', BUSINESS, ismagiRequirements),
      ),
      ...[
        'Développement Multimédia et Animation 3D',
        'Blockchain et Cryptographie',
        'Développement Web et Mobile',
        'IoT et Systèmes Intelligents',
      ].map((name, i) =>
        p(`partner-p-ismagi-lic-it-${i + 1}`, name, 'Licence', '3 ans', '40 000 MAD/an', '40 000 MAD/year', 'Français', COMPUTER_SCIENCE, ismagiRequirements),
      ),
      p('partner-p-ismagi-prep-1', 'Classes préparatoires intégrées', 'Prépa', '2 ans', '40 000 MAD/an', '40 000 MAD/year', 'Français', ENGINEERING, ismagiRequirements),
      p('partner-p-ismagi-eng-1', 'Ingénierie Informatique', 'Ingénieur', '5 ans', '45 000 MAD/an', '45 000 MAD/year', 'Français', COMPUTER_SCIENCE, ismagiRequirements),
      p('partner-p-ismagi-eng-2', 'Ingénierie Data Science et Biotech', 'Ingénieur', '5 ans', '45 000 MAD/an', '45 000 MAD/year', 'Français', COMPUTER_SCIENCE, ismagiRequirements),
      ...[
        'Master en Gestion Opérationnelle et Stratégies des Entreprises',
        'Master en Qualité, Hygiène, Sécurité, Environnement',
        'Master en Comptabilité, Contrôle et Audit',
        'Master en IoT et Data Science',
        'Master Fintech and Risk Management',
        'Master Développement Logiciel, Mobile et IoT',
        'Master Digital Marketing and Communication',
      ].map((name, i) =>
        p(`partner-p-ismagi-msc-${i + 1}`, name, 'Master', '2 ans', '45 000 MAD/an', '45 000 MAD/year', 'Français', name.toLowerCase().includes('iot') || name.toLowerCase().includes('logiciel') ? COMPUTER_SCIENCE : BUSINESS, ismagiRequirements),
      ),
    ],
  },
  {
    id: 'partner-esa-casa',
    countryId: 'mar',
    nameFr: 'ESA Casablanca (IGENSIA Education)',
    nameEn: 'ESA Casablanca (IGENSIA Education)',
    locationFr: 'Casablanca',
    locationEn: 'Casablanca',
    overviewFr: 'École de management IGENSIA — Bachelor Management et Finance.',
    overviewEn: 'IGENSIA management school — Management and Finance Bachelor.',
    studyLevels: ['Bachelor'],
    programs: [
      p('partner-p-esa-1', 'Bac+3 Gestion des entreprises — Option Management', 'Bachelor', '3 ans', '5 500 €/an (B1)', '5 500 EUR/year (Y1)', 'Français', BUSINESS, ['Bac validé', 'Test écrit + entretien']),
      p('partner-p-esa-2', 'Bac+3 Gestion des entreprises — Option Finance', 'Bachelor', '3 ans', '5 500 €/an (B1)', '5 500 EUR/year (Y1)', 'Français', BUSINESS, ['Bac validé', 'Test écrit + entretien']),
    ],
  },
  {
    id: 'partner-bau-istanbul',
    countryId: 'tur',
    nameFr: 'Bahçeşehir University (BAU) Istanbul',
    nameEn: 'Bahçeşehir University (BAU) Istanbul',
    locationFr: 'Istanbul',
    locationEn: 'Istanbul',
    overviewFr: 'Université privée turque — catalogue phare en anglais.',
    overviewEn: 'Leading Turkish private university — flagship English catalog.',
    studyLevels: ['Bachelor'],
    programs: [
      ...[
        ['Business Administration', '8 500 USD/an', BUSINESS],
        ['International Trade and Business', '8 500 USD/an', BUSINESS],
        ['International Finance', '8 500 USD/an', BUSINESS],
        ['Computer Engineering', '9 000 USD/an', COMPUTER_SCIENCE],
        ['Software Engineering', '9 000 USD/an', COMPUTER_SCIENCE],
        ['Artificial Intelligence Engineering', '12 000 USD/an', COMPUTER_SCIENCE],
        ['Medicine', '28 000 USD/an', HEALTH],
        ['Architecture', '8 500 USD/an', ARCHITECTURE],
        ['Textile and Fashion Design', '8 500 USD/an', DESIGN],
      ].map(([name, tuition, field], i) =>
        p(`partner-p-bau-${i + 1}`, name as string, 'Bachelor', name === 'Medicine' ? '6 ans' : '4 ans', tuition as string, tuition as string, 'Anglais', field as string, ['Candidature en ligne', 'Relevés secondaires']),
      ),
    ],
  },
  {
    id: 'partner-gbs-dubai',
    countryId: 'are',
    nameFr: 'GBS Dubai',
    nameEn: 'GBS Dubai',
    locationFr: 'Dubaï',
    locationEn: 'Dubai',
    overviewFr: 'Global Banking School — diplômes professionnels et HND, 4 rentrées/an.',
    overviewEn: 'Global Banking School — professional diplomas and HND, 4 intakes/year.',
    studyLevels: ['Diploma', 'HND', 'Professional'],
    programs: [
      p('partner-p-gbs-1', 'International Diploma in Business', 'Diploma Level 2', '1 an', '25 000 AED/an', '25 000 AED/year', 'Anglais', BUSINESS, ['Grade 12 minimum']),
      p('partner-p-gbs-2', 'International Extended Diploma in Business', 'Diploma Level 3', '1 an', '40 000 AED/an', '40 000 AED/year', 'Anglais', BUSINESS, ['Grade 12 minimum']),
      p('partner-p-gbs-3', 'International Extended Diploma in IT', 'Diploma Level 3', '1 an', '40 000 AED/an', '40 000 AED/year', 'Anglais', COMPUTER_SCIENCE, ['Grade 12 minimum']),
      ...[
        'HND International in Business',
        'HND in Digital Technologies (Cyber Security)',
        'HND in Digital Technologies (Artificial Intelligence)',
        'HND in Healthcare Practices (Healthcare Management)',
        'HND in Construction Management',
      ].map((name, i) =>
        p(`partner-p-gbs-hnd-${i + 1}`, name, 'HND Level 5', '2 ans', '40 000 AED/an', '40 000 AED/year', 'Anglais', name.includes('Digital') ? COMPUTER_SCIENCE : BUSINESS, ['IELTS 5.5 ou équivalent']),
      ),
      p('partner-p-gbs-9', 'ACCA (Association of Chartered Certified Accountants)', 'Professional', 'Variable', '8 000 - 18 500 AED', '8 000 - 18 500 AED', 'Anglais', BUSINESS, ['Admission selon level ACCA']),
      p('partner-p-gbs-10', 'Global Investment Banking Analyst Programme', 'Certificate', '4 semaines', '10 000 AED (programme)', '10 000 AED (program)', 'Anglais', BUSINESS, ['Dossier candidature']),
    ],
  },
];

export function countPartnerPrograms(): number {
  return PARTNER_INSTITUTION_SEEDS.reduce(
    (sum, school) => sum + school.programs.length,
    0,
  );
}
