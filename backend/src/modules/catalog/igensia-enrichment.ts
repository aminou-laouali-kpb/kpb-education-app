// ─────────────────────────────────────────────────────────────────────────────
// Groupe IGENSIA Education — ce que les sources du propriétaire ne disaient pas,
// relevé sur les SITES OFFICIELS des écoles et sur les fiches RNCP de France
// Compétences, le 16/10/2026.
//
// Chaque fait porte son URL ; la liste lisible (et les écarts avec les sources
// du propriétaire) est dans scripts/data/igensia_2027.sources.md. Les TARIFS et
// les RENTRÉES restent ceux des sources du propriétaire (PDF / XLSX) : quand le
// site dit autre chose, rien n'est remplacé, l'écart est signalé dans le
// fichier de provenance. Ce qui est introuvable reste vide.
//
// Clé : « id de l'école|intitulé de la formation », tel que l'import le lit.
// ─────────────────────────────────────────────────────────────────────────────

/** Date de consultation des sites (identique à la date des sources). */
export const IGENSIA_WEB_CONSULTED_AT = '2026-10-16';

export type RncpFact = {
  /// « RNCP38808 »
  code: string;
  /// Intitulé EXACT de la fiche France Compétences.
  title: string;
  level: 6 | 7;
  /// Nom légal des certificateurs, tel que la fiche les liste.
  certifiers: string[];
  url: string;
};

export type IgensiaFormationFacts = {
  /// Page officielle de la formation : devient le `sourceUrl` de la fiche.
  pageUrl: string;
  rncp?: RncpFact;
  /// Accréditation hors RNCP (ABC : IACBE).
  accreditation?: { fr: string; en: string };
  /// Langue d'enseignement, citée par la page de la formation.
  language?: { fr: string; en: string; codes: string[]; evidence: string };
  /// ABC : durée, conditions, modes de candidature, frais de candidature.
  duration?: { fr: string; en: string };
  requirements?: { fr: string[]; en: string[] };
  admissionModes?: string[];
  procedureType?: string;
  applicationFeeEur?: number;
};

const IGS = 'INSTITUT DE GESTION SOCIALE (IGS)';
const MESR = "MINISTERE DE L'ENSEIGNEMENT SUPERIEUR ET DE LA RECHERCHE";
const FC = (n: number) => `https://www.francecompetences.fr/recherche/rncp/${n}/`;
const ISB = 'https://www.igensia-school-of-business.fr/formations';
const ABC = 'https://www.american-business-college-paris.com';

const FRENCH_B2 = {
  fr: 'Français',
  en: 'French',
  codes: ['fr'],
  evidence: '« Candidats hors UE : Diplôme équivalent à un niveau Bac et niveau Français minimum B2 »',
};

/// ABC — étapes et pièces publiées sur chaque page de programme.
const ABC_PROCESS = {
  fr: [
    'Dossier en ligne : formulaire, passeport ou pièce d’identité, relevés de notes et diplômes, lettre de motivation et un test d’anglais (TOEFL, IELTS, TOEIC, Cambridge…) ; une lettre de recommandation est facultative',
    'Après l’étude de ton dossier : un court échange (Teams ou téléphone), puis un entretien d’admission en anglais',
    'Candidats hors UE : dépose ton dossier avant le 1er juillet pour la rentrée d’automne',
    'Frais de candidature : 60 €',
  ],
  en: [
    'Online application: form, passport or ID, transcripts and diplomas, cover letter and an English test (TOEFL, IELTS, TOEIC, Cambridge…); a recommendation letter is optional',
    'Once your file is reviewed: a short call (Teams or phone), then an admission interview in English',
    'Non-EU applicants: apply before 1 July for the fall intake',
    'Application fee: €60',
  ],
};

const ABC_BACHELOR_ENTRY = {
  fr: [
    'Entrée en 1re année après le bac (ou un diplôme de niveau 4 équivalent) : tu peux candidater avant d’avoir ton bac',
    'Anglais : IELTS 6.0, TOEFL iBT 70, PTE Academic 54, Duolingo 100 ou Cambridge B2 First',
    'Résultats minimum : bac avec mention assez bien (12/20), IB 28 points ou GPA 2.7/4',
  ],
  en: [
    'Year 1 entry after secondary school (French bac or an equivalent level 4 diploma): you can apply before you get it',
    'English: IELTS 6.0, TOEFL iBT 70, PTE Academic 54, Duolingo 100 or Cambridge B2 First',
    'Minimum grades: bac with « mention assez bien » (12/20), IB 28 points or a 2.7/4 GPA',
  ],
};

const ABC_MASTER_ENTRY = {
  fr: [
    'Entrée en 1re année : un diplôme en 3 ans (licence, bachelor), avec un GPA de 2.7/4 ou une mention assez bien (12/20)',
    'Entrée directe en 2e année : un diplôme en 4 ans en commerce ou gestion, avec un GPA de 3.0/4 ou une mention bien (14/20)',
  ],
  en: [
    'Year 1 entry: a three-year degree (bachelor), with a 2.7/4 GPA or a French « mention assez bien » (12/20)',
    'Direct year 2 entry: a four-year business degree, with a 3.0/4 GPA or a French « mention bien » (14/20)',
  ],
};

const IACBE = { fr: 'Accrédité aux États-Unis (IACBE)', en: 'Accredited in the US (IACBE)' };

const MANAGER_INTERNATIONAL: RncpFact = {
  code: 'RNCP41361',
  title: 'Manager international',
  level: 7,
  certifiers: [IGS],
  url: FC(41361),
};

const ABC_COMMON = {
  admissionModes: ['Dossier', 'Entretien'],
  // Candidature directe auprès de l'école, en ligne.
  procedureType: 'hors_eef',
  applicationFeeEur: 60,
  accreditation: IACBE,
};

export const IGENSIA_FORMATION_FACTS: Record<string, IgensiaFormationFacts> = {
  // ── IGENSIA School of Business ────────────────────────────────────────────
  'igensia-isb|Bachelor Business & Marketing - Parcours 360': {
    pageUrl: `${ISB}/marketing-digital-intelligence-artificielle/bachelor-business-et-marketing-parcours-360`,
    rncp: { code: 'RNCP38808', title: "Responsable d'activité commerciale et marketing", level: 6, certifiers: [IGS], url: FC(38808) },
  },
  'igensia-isb|Mastère pro Expert Financier': {
    pageUrl: `${ISB}/finance-gestion-audit/mastere-pro-expert-financier`,
    rncp: { code: 'RNCP36596', title: 'Expert financier', level: 7, certifiers: [IGS], url: FC(36596) },
  },
  'igensia-isb|Mastère pro Management des organisations': {
    pageUrl: `${ISB}/marketing-digital-intelligence-artificielle/mastere-pro-management-des-organisations`,
    rncp: { code: 'RNCP38825', title: 'Manager des organisations', level: 7, certifiers: [IGS], url: FC(38825) },
  },
  'igensia-isb|Bachelor Business Development - Event Sales': {
    pageUrl: `${ISB}/commerce-vente-achats/bachelor-en-sciences-du-management-event-management`,
    rncp: {
      code: 'RNCP39556',
      title: 'DipViGrL - Responsable du développement commercial et marketing',
      level: 6,
      certifiers: [IGS, MESR],
      url: FC(39556),
    },
  },
  'igensia-isb|Bachelor Business Development - Sales Stategy': {
    pageUrl: `${ISB}/commerce-vente-achats/bachelor-en-sciences-du-management-business-development`,
    rncp: {
      code: 'RNCP39556',
      title: 'DipViGrL - Responsable du développement commercial et marketing',
      level: 6,
      certifiers: [IGS, MESR],
      url: FC(39556),
    },
    language: FRENCH_B2,
  },
  'igensia-isb|Mastère Parcours International business développement': {
    pageUrl: `${ISB}/commerce-vente-achats/mastere-international-business-development`,
    rncp: {
      code: 'RNCP42780',
      title: 'DIPLOVIS - Management stratégique et commerce international',
      level: 7,
      certifiers: [IGS, MESR],
      url: FC(42780),
    },
    language: { fr: 'Anglais', en: 'English', codes: ['en'], evidence: '« Dispensé 100 % en anglais »' },
  },
  'igensia-isb|Bachelor Droit': {
    pageUrl: `${ISB}/droit-des-affaires/bachelor-droit`,
    rncp: {
      code: 'RNCP41496',
      title: 'Attaché juridique',
      level: 6,
      certifiers: [
        "ASSOCIATION PARITAIRE POUR LE DEVELOPPEMENT DU DIALOGUE SOCIAL DANS LA BRANCHE DU PERSONNEL DES CABINETS D'AVOCATS",
      ],
      url: FC(41496),
    },
    language: FRENCH_B2,
  },
  'igensia-isb|Mastère pro Juriste d\'Affaires': {
    pageUrl: `${ISB}/droit-des-affaires/mastere-pro-juriste-d-affaires`,
    rncp: { code: 'RNCP40682', title: "Juriste d'affaires", level: 7, certifiers: [IGS], url: FC(40682) },
  },
  'igensia-isb|Bachelor Gestion et Finance d\'entreprise': {
    pageUrl: `${ISB}/finance-gestion-audit/bachelor-gestion-et-finance-d-entreprise`,
    rncp: { code: 'RNCP42510', title: "Responsable en gestion d'activité", level: 6, certifiers: [IGS], url: FC(42510) },
    language: FRENCH_B2,
  },
  'igensia-isb|Mastère Stratégie Digitale & Business': {
    pageUrl: `${ISB}/commerce-vente-achats/mastere-strategies-digitales-des-entreprises`,
    rncp: {
      code: 'RNCP42781',
      title: 'DIPLOVIS - Marketing stratégique et développement d’affaires',
      level: 7,
      certifiers: [IGS, MESR],
      url: FC(42781),
    },
  },
  'igensia-isb|Mastère Pro Manager international des industries et services en santé': {
    pageUrl: `${ISB}/management-entrepreneuriat/mastere-pro-manager-international-des-industries-et-services-en-sante`,
    rncp: {
      code: 'RNCP42197',
      title: 'Manager international des industries et services en santé',
      level: 7,
      certifiers: [IGS],
      url: FC(42197),
    },
  },
  // ── IGENSIA Tech ──────────────────────────────────────────────────────────
  'igensia-tech|Bachelor Réseaux Cloud & Cyber : Administrateur Systèmes Réseaux et Base de données': {
    pageUrl: 'https://www.igensiatech.fr/formations/bachelors/bachelor-reseaux-cloud-cybersecurite',
    rncp: {
      code: 'RNCP41996',
      title: 'Administrateur systèmes, réseaux et bases de données',
      level: 6,
      certifiers: [IGS],
      url: FC(41996),
    },
  },
  'igensia-tech|Mastère pro IT Project Manager : Chef de projet informatique': {
    pageUrl: 'https://www.igensiatech.fr/formations/masteres-pro/chef-de-projet-informatique',
    rncp: { code: 'RNCP40239', title: 'Directeur de projets informatiques', level: 7, certifiers: [IGS], url: FC(40239) },
  },
  // ── IGENSIA RH ────────────────────────────────────────────────────────────
  'igensia-rh|MBA International Human Resource Management': {
    pageUrl: 'https://www.igensia-rh.com/formations/post-bac-4/mba-international-human-resource-management',
    rncp: {
      code: 'RNCP41092',
      title: 'Manager international des ressources humaines',
      level: 7,
      certifiers: [IGS],
      url: FC(41092),
    },
    language: { fr: 'Anglais', en: 'English', codes: ['en'], evidence: '« 100 % taught in English »' },
  },
  'igensia-rh|Bachelor RH & transfo digitale': {
    pageUrl: 'https://www.igensia-rh.com/formations/post-bac/bachelor-vise-rh-et-transformation-digitale',
    rncp: {
      code: 'RNCP41181',
      title: 'DIPLOVIS - RH et transformation digitale',
      level: 6,
      certifiers: [IGS, MESR],
      url: FC(41181),
    },
  },
  'igensia-rh|Mastère pro Manager des Ressources Humaines': {
    pageUrl: 'https://www.igensia-rh.com/formations/post-bac-3/master-professionnel-manager-rh-filiere-rh',
    rncp: { code: 'RNCP38833', title: 'Manager des ressources humaines', level: 7, certifiers: [IGS], url: FC(38833) },
  },
  // ── American Business College ─────────────────────────────────────────────
  'igensia-abc|BBA (Marketing, Int. Business, Finance)': {
    ...ABC_COMMON,
    pageUrl: `${ABC}/programs/bachelor-degree/bachelor-of-business-administration`,
    rncp: MANAGER_INTERNATIONAL,
    duration: {
      fr: '4 ans (8 semestres + stage de fin d’études de 6 mois)',
      en: '4 years (8 semesters + 6-month final internship)',
    },
    requirements: {
      fr: [
        ...ABC_BACHELOR_ENTRY.fr,
        'Admission en cours de cursus possible après 1, 2 ou 3 ans d’études supérieures (transfert)',
        ...ABC_PROCESS.fr,
      ],
      en: [
        ...ABC_BACHELOR_ENTRY.en,
        'Transfer admission possible after 1, 2 or 3 years of higher education',
        ...ABC_PROCESS.en,
      ],
    },
  },
  'igensia-abc|Bachelor in Fashion & Luxury Retail Management': {
    ...ABC_COMMON,
    pageUrl: `${ABC}/programs/bachelor-degree/bachelor-luxury-in-paris`,
    duration: {
      fr: '3 ans (5 semestres et stages à l’étranger)',
      en: '3 years (5 semesters and internships abroad)',
    },
    requirements: {
      fr: [
        ...ABC_BACHELOR_ENTRY.fr,
        'Admission en cours de cursus possible après 1 ou 2 ans d’études supérieures (transfert)',
        ...ABC_PROCESS.fr,
      ],
      en: [
        ...ABC_BACHELOR_ENTRY.en,
        'Transfer admission possible after 1 or 2 years of higher education',
        ...ABC_PROCESS.en,
      ],
    },
  },
  'igensia-abc|Master of Science in Luxury Brand Management': {
    ...ABC_COMMON,
    pageUrl: `${ABC}/programs/master-degree/master-of-science-luxury-brand-management`,
    rncp: MANAGER_INTERNATIONAL,
    duration: {
      fr: '2 ans (4 semestres + stage de fin d’études de 6 mois)',
      en: '2 years (4 semesters + 6-month final internship)',
    },
    requirements: {
      fr: [...ABC_MASTER_ENTRY.fr, ...ABC_PROCESS.fr],
      en: [...ABC_MASTER_ENTRY.en, ...ABC_PROCESS.en],
    },
  },
  'igensia-abc|Master of Science in Digital Marketing': {
    ...ABC_COMMON,
    pageUrl: `${ABC}/programs/master-degree/master-of-science-digital-marketing`,
    rncp: MANAGER_INTERNATIONAL,
    duration: {
      fr: '2 ans (4 semestres + stage de fin d’études de 6 mois)',
      en: '2 years (4 semesters + 6-month final internship)',
    },
    requirements: {
      fr: [...ABC_MASTER_ENTRY.fr, ...ABC_PROCESS.fr],
      en: [...ABC_MASTER_ENTRY.en, ...ABC_PROCESS.en],
    },
  },
  'igensia-abc|American MBA in Entrepreneurship & International Business Development': {
    ...ABC_COMMON,
    pageUrl: `${ABC}/programs/master-degree/american-mba`,
    rncp: { code: 'RNCP38825', title: 'Manager des organisations', level: 7, certifiers: [IGS], url: FC(38825) },
    duration: {
      fr: '1 ou 2 ans, + stage de fin d’études de 6 mois',
      en: '1 or 2 years, + 6-month final internship',
    },
    requirements: {
      fr: [
        ...ABC_MASTER_ENTRY.fr,
        'Au moins 2 ans d’expérience professionnelle',
        ...ABC_PROCESS.fr,
      ],
      en: [
        ...ABC_MASTER_ENTRY.en,
        'At least 2 years of work experience',
        ...ABC_PROCESS.en,
      ],
    },
  },
};

function certifierLabel(name: string): string {
  if (name === IGS) return 'Institut de Gestion Sociale (IGS)';
  if (name === MESR) return 'ministère de l’Enseignement supérieur et de la Recherche';
  if (name.endsWith("CABINETS D'AVOCATS")) return 'ADDSA (branche du personnel des cabinets d’avocats)';
  return name;
}

function certifierLabelEn(name: string): string {
  if (name === MESR) return 'French Ministry of Higher Education and Research';
  return certifierLabel(name);
}

/**
 * Reconnaissance affichée : le libellé de la source du propriétaire (« Titre
 * RNCP », « Grade de licence », « VISA »), puis la fiche RNCP qui le porte.
 */
export function recognitionWithFacts(
  base: { fr: string; en: string } | null,
  facts: IgensiaFormationFacts | undefined,
): { fr: string; en: string } | null {
  if (!facts?.rncp && !facts?.accreditation) return base;
  const fr: string[] = [];
  const en: string[] = [];
  if (base) {
    fr.push(base.fr);
    en.push(base.en);
  }
  if (facts.accreditation) {
    fr.push(facts.accreditation.fr);
    en.push(facts.accreditation.en);
  }
  if (facts.rncp) {
    const r = facts.rncp;
    fr.push(
      `${r.code} « ${r.title} », niveau ${r.level}, certificateur${r.certifiers.length > 1 ? 's' : ''} : ${r.certifiers.map(certifierLabel).join(' et ')}`,
    );
    en.push(
      `${r.code} “${r.title}”, level ${r.level}, certified by ${r.certifiers.map(certifierLabelEn).join(' and ')}`,
    );
  }
  return { fr: fr.join(' — '), en: en.join(' — ') };
}
