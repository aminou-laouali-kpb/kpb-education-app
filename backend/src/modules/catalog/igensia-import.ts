// ─────────────────────────────────────────────────────────────────────────────
// Groupe IGENSIA Education — la moitié pure de `import:igensia`.
//
// Deux sources du propriétaire (16/10/2026), extraites en CSV par
// scripts/extract-catalog-sources.py :
//
//   igensia_2027.csv  — « Listing des programmes accessibles aux étudiants
//                       internationaux » : ISB, IGENSIA Tech, IGENSIA RH ;
//   abc_2027.csv      — « Portefeuille ABC » : American Business College.
//
// Une formation = un Program ; ses campus et rentrées sont ses
// `campusOfferings`. Une formation ouverte en mars ET en septembre est UNE
// fiche avec deux offres (ou plus, une par campus), pas deux fiches.
//
// Tout ce qui n'est pas dans les sources reste vide : langue d'enseignement
// des programmes ISB / Tech / RH, durée et modalités d'admission d'ABC (voir
// les « À VALIDER » ci-dessous). Les intitulés de formation sont recopiés tels
// quels, fautes comprises (« Sales Stategy ») ; seule la coquille « IGENISA »
// du NOM des écoles est corrigée, dans la table `SCHOOL_BY_LABEL`.
// ─────────────────────────────────────────────────────────────────────────────
import {
  type CampusOffering,
  type OfferingSession,
  compareOfferings,
  mergeCampusOfferings,
  readCampusOfferings,
} from './campus-offerings';
import { euro, formatTuitionSummary, normalizeDegreeLevel } from './omnes-conventions';
import { parseCsv, stableId } from './partner-import';

export const IGENSIA_INSTITUTION_ID_PREFIX = 'igensia-';
export const IGENSIA_PROGRAM_ID_PREFIX = 'igensia-p-';
export const FRANCE_COUNTRY_ID = 'fra';

/** Date des deux sources : 16 octobre 2026. */
export const IGENSIA_SOURCE_DATE = new Date('2026-10-16T00:00:00.000Z');

export const IGENSIA_CONTACT_EMAIL = 'admissions-internationales@igensia.com';

export type IgensiaSchool = {
  id: string;
  nameFr: string;
  nameEn: string;
  /// Lien de candidature en ligne publié dans la source ; nul s'il n'y en a pas.
  applicationUrl: string | null;
  /// Les écoles ISB / Tech / RH partagent le processus d'admission du groupe
  /// (PDF IGENSIA). ABC n'y figure pas : on ne le lui prête pas.
  groupAdmissionProcess: boolean;
  introFr: string;
  introEn: string;
};

export const IGENSIA_SCHOOLS: IgensiaSchool[] = [
  {
    id: 'igensia-isb',
    nameFr: 'IGENSIA School of Business',
    nameEn: 'IGENSIA School of Business',
    applicationUrl: 'https://www.igensia-school-of-business.fr/candidature-en-ligne',
    groupAdmissionProcess: true,
    introFr:
      'IGENSIA School of Business (ISB) est l’école de commerce du groupe IGENSIA Education : commerce, finance, management, droit, marketing digital et santé.',
    introEn:
      'IGENSIA School of Business (ISB) is the business school of the IGENSIA Education group: business, finance, management, law, digital marketing and health management.',
  },
  {
    id: 'igensia-tech',
    nameFr: 'IGENSIA Tech',
    nameEn: 'IGENSIA Tech',
    applicationUrl: 'https://www.igensiatech.fr/candidature-en-ligne',
    groupAdmissionProcess: true,
    introFr:
      'IGENSIA Tech est l’école d’informatique du groupe IGENSIA Education : réseaux, cloud, cybersécurité et gestion de projet informatique.',
    introEn:
      'IGENSIA Tech is the IT school of the IGENSIA Education group: networks, cloud, cybersecurity and IT project management.',
  },
  {
    id: 'igensia-rh',
    nameFr: 'IGENSIA RH',
    nameEn: 'IGENSIA RH',
    applicationUrl: 'https://www.igensia-rh.com/candidature-en-ligne',
    groupAdmissionProcess: true,
    introFr:
      'IGENSIA RH est l’école des ressources humaines du groupe IGENSIA Education.',
    introEn:
      'IGENSIA RH is the human resources school of the IGENSIA Education group.',
  },
  {
    id: 'igensia-abc',
    // « (ABC) » dans le nom : c'est le sigle que l'élève tape dans la recherche,
    // qui ne lit que le nom et la ville de l'établissement.
    nameFr: 'American Business College (ABC)',
    nameEn: 'American Business College (ABC)',
    // À VALIDER (propriétaire) : aucun lien de candidature dans le portefeuille ABC.
    applicationUrl: null,
    groupAdmissionProcess: false,
    introFr:
      'American Business College (ABC) est une école du groupe IGENSIA Education, à Paris. Ses programmes sont enseignés en anglais.',
    introEn:
      'American Business College (ABC) is a school of the IGENSIA Education group, in Paris. Its programmes are taught in English.',
  },
];

/// Colonne « ECOLES » → école. Table FERMÉE. La source écrit « IGENISA » :
/// coquille corrigée ici, pour le nom de l'école seulement.
export const SCHOOL_BY_LABEL: Record<string, string> = {
  ISB: 'igensia-isb',
  'IGENISA TECH': 'igensia-tech',
  'IGENSIA TECH': 'igensia-tech',
  'IGENISA RH': 'igensia-rh',
  'IGENSIA RH': 'igensia-rh',
  ABC: 'igensia-abc',
};

/// Domaine de la source → taxonomie d01..d12 (orientation-fields.data.ts).
/// Table FERMÉE : un domaine inconnu arrête l'import.
export const FIELD_BY_DOMAIN: Record<string, string> = {
  COMMERCE: 'd02',
  FINANCE: 'd02',
  MANAGEMENT: 'd02',
  'RESSOURCES HUMAINES': 'd02',
  'MARKETING DIGITAL': 'd02',
  DROIT: 'd07',
  INFORMATIQUE: 'd01',
  // « Manager international des industries et services en santé » : un
  // master de MANAGEMENT appliqué à la santé, pas une formation de santé.
  // À VALIDER (propriétaire) si l'on préfère d04 (Santé & Sciences de la Vie).
  SANTE: 'd02',
  // Portefeuille ABC
  'MARKETING, INT BUSINESS, FINANCE': 'd02',
  'FASHION & LUXURY': 'd02',
  'DIGITAL MARKETING': 'd02',
  ENTREPRENEURIAT: 'd02',
};

/// Reconnaissance → libellé affiché. Table FERMÉE.
export const RECOGNITION_BY_LABEL: Record<string, { fr: string; en: string }> = {
  'TITRE RNCP': {
    fr: 'Titre RNCP (certifié par l’État)',
    en: 'RNCP title (state-certified)',
  },
  'GRADE DE LICENCE': {
    fr: 'Grade de licence',
    en: 'Bachelor’s degree status (grade de licence)',
  },
  VISA: {
    fr: 'Diplôme visé par l’État (VISA)',
    en: 'State-endorsed degree (VISA)',
  },
  'VISA (EN COURS DE VALIDATION)': {
    fr: 'Diplôme visé par l’État (VISA) — en cours de validation',
    en: 'State-endorsed degree (VISA) — validation in progress',
  },
};

/// Rentrée → date « mm/aaaa » (format lu par l'app) + session + libellé
/// d'établissement. Table FERMÉE.
export const INTAKE_BY_LABEL: Record<
  string,
  { intake: string; session: OfferingSession; periodFr: string }
> = {
  'MARS 2027': { intake: '03/2027', session: 'spring', periodFr: 'Mars 2027' },
  'SEPTEMBRE 2027': { intake: '09/2027', session: 'fall', periodFr: 'Septembre 2027' },
  // ABC : la source dit « FALL 2027 », sans mois.
  'FALL 2027': { intake: 'FALL 2027', session: 'fall', periodFr: 'Automne 2027' },
};

export type AdmissionChannel = 'Concours école' | 'Études en France' | 'Parcoursup';

/// Jeton de « MODE DE CANDIDATURE » (sans accents, minuscules) → canal.
const CHANNEL_BY_TOKEN: Record<string, AdmissionChannel> = {
  'concours ecole': 'Concours école',
  'etudes en france': 'Études en France',
  parcoursup: 'Parcoursup',
};

/// Ordre de priorité publié par le groupe : Parcoursup > Études en France >
/// Concours école. Les canaux d'une formation sont rangés dans cet ordre.
export const CHANNEL_PRIORITY: AdmissionChannel[] = [
  'Parcoursup',
  'Études en France',
  'Concours école',
];

/// Niveau d'entrée → libellés + nombre d'années jusqu'au diplôme. Table FERMÉE.
export const ENTRY_BY_LABEL: Record<
  string,
  { fr: string; en: string; yearsLeft: number }
> = {
  'B1 - 1E ANNÉE': { fr: 'Entrée en 1re année (B1)', en: 'Entry into year 1 (B1)', yearsLeft: 3 },
  'M1 - 4E ANNÉE': { fr: 'Entrée en 4e année (M1)', en: 'Entry into year 4 (M1)', yearsLeft: 2 },
};

export const PREREQUISITE_BY_LABEL: Record<string, { fr: string; en: string }> = {
  BAC: { fr: 'Diplôme demandé : Bac', en: 'Required diploma: Bac (secondary-school diploma)' },
  'BAC+3': { fr: 'Diplôme demandé : Bac+3', en: 'Required diploma: Bac+3 (three years of higher education)' },
};

/// Intitulé ABC quand la colonne PROGRAMMES ne donne que le niveau (« BBA ») :
/// on y joint les spécialités de la colonne DOMAINE, sans rien inventer.
export const ABC_NAME_WHEN_BARE: Record<string, string> = {
  'BBA|MARKETING, INT BUSINESS, FINANCE': 'BBA (Marketing, Int. Business, Finance)',
};

export const LANGUAGE_BY_LABEL: Record<string, { fr: string; en: string; codes: string[] }> = {
  ANG: { fr: 'Anglais', en: 'English', codes: ['en'] },
};

function fold(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function upper(value: string): string {
  return value.replace(/\s+/g, ' ').trim().toUpperCase();
}

/** « Paris, Lyon et Toulouse » → ['Paris', 'Lyon', 'Toulouse']. */
export function splitCampuses(raw: string): string[] {
  return raw
    .split(/,|\bet\b/)
    .map((c) => c.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

/** « Concours école, Etudes en France et Parcoursup » → canaux, ou nul si inconnu. */
export function parseChannels(raw: string): AdmissionChannel[] | null {
  const tokens = raw
    .split(/,|\bet\b/)
    .map((t) => fold(t))
    .filter(Boolean);
  const out: AdmissionChannel[] = [];
  for (const token of tokens) {
    const channel = CHANNEL_BY_TOKEN[token];
    if (!channel) return null;
    if (!out.includes(channel)) out.push(channel);
  }
  return CHANNEL_PRIORITY.filter((c) => out.includes(c));
}

/** « 11 650 € » ou « 12900 » → 11650 / 12900. */
export function parseEuroAmount(raw: string): number | null {
  const digits = raw.replace(/[\s  €.]/g, '');
  if (!/^\d+$/.test(digits)) return null;
  const n = Number(digits);
  return n > 0 ? n : null;
}

export type IgensiaFormation = {
  id: string;
  schoolId: string;
  name: string;
  fieldId: string;
  level: string;
  duration: { fr: string; en: string };
  recognition: { fr: string; en: string } | null;
  language: { fr: string; en: string; codes: string[] } | null;
  entry: { fr: string; en: string } | null;
  prerequisite: { fr: string; en: string } | null;
  channels: AdmissionChannel[];
  offerings: CampusOffering[];
};

type Draft = IgensiaFormation & { signature: string };

function addFormation(
  byId: Map<string, Draft>,
  draft: Omit<Draft, 'id' | 'offerings'>,
  offerings: CampusOffering[],
  errors: string[],
  where: string,
) {
  const id = stableId(IGENSIA_PROGRAM_ID_PREFIX, `${draft.schoolId}|${draft.name}`);
  const existing = byId.get(id);
  if (!existing) {
    byId.set(id, { ...draft, id, offerings: [...offerings] });
    return;
  }
  // La même formation sur deux lignes (mars, septembre) : tout ce qui n'est
  // pas propre à l'offre doit concorder, sinon c'est une incohérence de la
  // source, et on refuse de choisir à sa place.
  if (existing.signature !== draft.signature) {
    errors.push(`${where} : « ${draft.name} » diffère d'une ligne précédente de la même formation.`);
    return;
  }
  for (const channel of draft.channels) {
    if (!existing.channels.includes(channel)) existing.channels.push(channel);
  }
  existing.channels = CHANNEL_PRIORITY.filter((c) => existing.channels.includes(c));
  for (const offer of offerings) {
    const dup = existing.offerings.some(
      (o) => o.campus === offer.campus && o.intake === offer.intake,
    );
    if (dup) {
      errors.push(`${where} : « ${draft.name} » listé deux fois pour ${offer.campus} / ${offer.intake}.`);
      continue;
    }
    existing.offerings.push(offer);
  }
}

/** Lit les deux CSV et regroupe les formations. Toute anomalie est une erreur. */
export function parseIgensiaSources(
  igensiaCsv: string,
  abcCsv: string,
): { formations: IgensiaFormation[]; rowsBySchool: Record<string, number>; errors: string[] } {
  const errors: string[] = [];
  const rowsBySchool: Record<string, number> = {};
  const byId = new Map<string, Draft>();

  parseCsv(igensiaCsv).forEach((r, index) => {
    const where = `igensia_2027.csv ligne ${index + 2}`;
    const schoolId = SCHOOL_BY_LABEL[upper(r['Ecole'] ?? '')];
    const fieldId = FIELD_BY_DOMAIN[upper(r['Domaine'] ?? '')];
    const recognition = RECOGNITION_BY_LABEL[upper(r['Reconnaissance'] ?? '')];
    const intake = INTAKE_BY_LABEL[upper(r['Rentree'] ?? '')];
    const entry = ENTRY_BY_LABEL[upper(r['Niveau entree'] ?? '')];
    const prerequisite = PREREQUISITE_BY_LABEL[upper(r['Prerequis'] ?? '')];
    const channels = parseChannels(r['Mode de candidature'] ?? '');
    const price = parseEuroAmount(r['Tarif'] ?? '');
    const campuses = splitCampuses(r['Campus'] ?? '');
    const name = (r['Programme'] ?? '').replace(/\s+/g, ' ').trim();
    const diploma = upper(r['Diplome'] ?? '');
    const problems = [
      !schoolId && `école inconnue « ${r['Ecole']} »`,
      !fieldId && `domaine inconnu « ${r['Domaine']} »`,
      !recognition && `reconnaissance inconnue « ${r['Reconnaissance']} »`,
      !intake && `rentrée inconnue « ${r['Rentree']} »`,
      !entry && `niveau d'entrée inconnu « ${r['Niveau entree']} »`,
      !prerequisite && `prérequis inconnu « ${r['Prerequis']} »`,
      !channels?.length && `mode de candidature inconnu « ${r['Mode de candidature']} »`,
      price == null && `tarif illisible « ${r['Tarif']} »`,
      !campuses.length && 'campus vide',
      !name && 'programme sans nom',
      !['BAC+3', 'BAC+5'].includes(diploma) && `diplôme inconnu « ${r['Diplome']} »`,
    ].filter(Boolean);
    if (problems.length) {
      errors.push(`${where} : ${problems.join(', ')}`);
      return;
    }
    // Années restantes = diplôme visé − niveau d'entrée. Une combinaison que
    // la source ne contient pas (Bac+3 en entrée M1…) est refusée.
    const total = diploma === 'BAC+3' ? 3 : 5;
    const yearsLeft = entry!.yearsLeft;
    if ((total === 3 && yearsLeft !== 3) || (total === 5 && yearsLeft !== 2)) {
      errors.push(`${where} : diplôme ${diploma} incompatible avec l'entrée « ${r['Niveau entree']} »`);
      return;
    }
    rowsBySchool[schoolId!] = (rowsBySchool[schoolId!] ?? 0) + 1;
    const level = normalizeDegreeLevel(`${name} ${diploma}`);
    const lowerFirst = (v: string) => v.charAt(0).toLowerCase() + v.slice(1);
    const duration = {
      fr: `${yearsLeft} ans, ${lowerFirst(entry!.fr)}`,
      en: `${yearsLeft} years, ${lowerFirst(entry!.en)}`,
    };
    addFormation(
      byId,
      {
        schoolId: schoolId!,
        name,
        fieldId: fieldId!,
        level,
        duration,
        recognition: recognition!,
        language: null, // À VALIDER : la source ne dit pas la langue d'enseignement.
        entry: { fr: entry!.fr, en: entry!.en },
        prerequisite: prerequisite!,
        channels: channels!,
        signature: [fieldId, level, diploma, r['Reconnaissance'], r['Niveau entree'], r['Prerequis']]
          .map((v) => upper(String(v)))
          .join('|'),
      },
      campuses.map((campus) => ({
        campus,
        tuitionUpfront: price,
        tuitionInstallments: null,
        intake: intake!.intake,
        session: intake!.session,
      })),
      errors,
      where,
    );
  });

  parseCsv(abcCsv).forEach((r, index) => {
    const where = `abc_2027.csv ligne ${index + 2}`;
    const schoolId = SCHOOL_BY_LABEL[upper(r['Ecole'] ?? '')];
    const domain = upper(r['Domaine'] ?? '');
    const fieldId = FIELD_BY_DOMAIN[domain];
    const intake = INTAKE_BY_LABEL[upper(r['Rentree'] ?? '')];
    const language = LANGUAGE_BY_LABEL[upper(r['Langue'] ?? '')];
    const price = parseEuroAmount(r['Tarif'] ?? '');
    const campuses = splitCampuses(r['Campus'] ?? '');
    const niveau = (r['Niveau'] ?? '').trim();
    const programme = (r['Programme'] ?? '').replace(/\s+/g, ' ').trim();
    const bare = programme.toUpperCase() === niveau.toUpperCase();
    const name = bare ? ABC_NAME_WHEN_BARE[`${upper(niveau)}|${domain}`] : programme;
    const problems = [
      schoolId !== 'igensia-abc' && `école inattendue « ${r['Ecole']} »`,
      !fieldId && `domaine inconnu « ${r['Domaine']} »`,
      !intake && `rentrée inconnue « ${r['Rentree']} »`,
      !language && `langue inconnue « ${r['Langue']} »`,
      price == null && `tarif illisible « ${r['Tarif']} »`,
      !campuses.length && 'campus vide',
      !name && `intitulé réduit au niveau « ${programme} », sans libellé prévu`,
    ].filter(Boolean);
    if (problems.length) {
      errors.push(`${where} : ${problems.join(', ')}`);
      return;
    }
    rowsBySchool[schoolId!] = (rowsBySchool[schoolId!] ?? 0) + 1;
    addFormation(
      byId,
      {
        schoolId: schoolId!,
        name: name!,
        fieldId: fieldId!,
        level: normalizeDegreeLevel(niveau),
        // À VALIDER : le portefeuille ABC ne donne ni durée, ni reconnaissance,
        // ni niveau d'entrée, ni prérequis, ni mode de candidature.
        duration: { fr: '', en: '' },
        recognition: null,
        language: language!,
        entry: null,
        prerequisite: null,
        channels: [],
        signature: [fieldId, niveau].map(upper).join('|'),
      },
      campuses.map((campus) => ({
        campus,
        tuitionUpfront: price,
        tuitionInstallments: null,
        intake: intake!.intake,
        session: intake!.session,
      })),
      errors,
      where,
    );
  });

  const formations = [...byId.values()].map(({ signature: _signature, ...f }) => ({
    ...f,
    offerings: [...f.offerings].sort(compareOfferings),
  }));
  return { formations, rowsBySchool, errors };
}

/// `procedureType` : « eef » quand Études en France est ouvert (la voie des
/// candidats internationaux hors de France), sinon « hors_eef » (candidature
/// directe auprès de l'école). Parcoursup, réservé aux élèves de lycée français
/// ou titulaires d'un bac français, reste dans `admissionModes` et les
/// conditions. Nul quand la source ne dit rien (ABC).
export function procedureTypeFor(channels: readonly AdmissionChannel[]): string | null {
  if (channels.includes('Études en France')) return 'eef';
  if (channels.length) return 'hors_eef';
  return null;
}

/** Conditions affichées sur la fiche, FR et EN, dans le même ordre. */
export function requirementsFor(formation: IgensiaFormation): { fr: string[]; en: string[] } {
  const fr: string[] = [];
  const en: string[] = [];
  if (formation.entry) {
    fr.push(formation.entry.fr);
    en.push(formation.entry.en);
  }
  if (formation.prerequisite) {
    fr.push(formation.prerequisite.fr);
    en.push(formation.prerequisite.en);
  }
  if (formation.channels.length) {
    // Exigence du groupe, publiée pour TOUS les candidats ISB / Tech / RH.
    fr.push('Niveau B2 minimum dans la langue du programme (français ou anglais), avec un justificatif');
    en.push('B2 level minimum in the programme language (French or English), with proof');
  }
  if (formation.channels.includes('Études en France')) {
    fr.push('Candidature sur Études en France conseillée : ta demande de visa sera plus simple');
    en.push('Applying through Études en France is recommended: your visa application will be simpler');
  }
  if (formation.channels.includes('Concours école')) {
    fr.push(
      'Concours de l’école : candidature en ligne avec CV, lettre de motivation, pièce d’identité, diplômes, 3 derniers bulletins et test de langue, puis entretien en visio',
    );
    en.push(
      'School entrance process: apply online with your CV, cover letter, ID, diplomas, last 3 transcripts and a language test, then a video interview',
    );
  }
  if (formation.channels.includes('Parcoursup')) {
    fr.push('Tu es en lycée français ou tu as un bac français ? Candidate sur Parcoursup');
    en.push('At a French lycée or holding a French bac? Apply through Parcoursup');
  }
  return { fr, en };
}

export function igensiaProgramCreateData(formation: IgensiaFormation, school: IgensiaSchool) {
  const tuition = formatTuitionSummary(formation.offerings);
  const prices = formation.offerings
    .map((o) => o.tuitionUpfront)
    .filter((p): p is number => typeof p === 'number');
  const requirements = requirementsFor(formation);
  return {
    id: formation.id,
    institutionId: formation.schoolId,
    countryId: FRANCE_COUNTRY_ID,
    fieldId: formation.fieldId,
    nameFr: formation.name,
    nameEn: formation.name,
    levelFr: formation.level,
    levelEn: formation.level,
    durationFr: formation.duration.fr,
    durationEn: formation.duration.en,
    tuitionFr: tuition.fr,
    tuitionEn: tuition.en,
    languageFr: formation.language?.fr ?? '',
    languageEn: formation.language?.en ?? '',
    teachingLanguages: formation.language?.codes ?? [],
    requirementsFr: requirements.fr,
    requirementsEn: requirements.en,
    recognitionFr: formation.recognition?.fr ?? null,
    recognitionEn: formation.recognition?.en ?? null,
    admissionModes: [...formation.channels],
    procedureType: procedureTypeFor(formation.channels),
    tuitionMinEur: prices.length ? Math.round(Math.min(...prices)) : null,
    campusOfferings: formation.offerings,
    sourceUrl: school.applicationUrl,
    lastVerifiedAt: IGENSIA_SOURCE_DATE,
    isActive: true,
  };
}

/** Texte de l'école : présentation, puis processus du groupe s'il s'applique. */
export function schoolOverview(
  school: IgensiaSchool,
  campuses: readonly string[],
  periodsFr: readonly string[],
): { fr: string; en: string } {
  const periodsEn = periodsFr.map((p) =>
    p.replace('Mars', 'March').replace('Septembre', 'September').replace('Automne', 'Fall'),
  );
  const fr: string[] = [school.introFr];
  const en: string[] = [school.introEn];
  fr.push(`Campus : ${campuses.join(', ')}. Rentrées : ${periodsFr.join(', ').toLowerCase()}.`);
  en.push(`Campuses: ${campuses.join(', ')}. Intakes: ${periodsEn.join(', ')}.`);
  fr.push(
    'Le groupe IGENSIA Education réunit IGENSIA School of Business, IGENSIA Tech, IGENSIA RH et American Business College en France, et ESA Casablanca au Maroc.',
  );
  en.push(
    'The IGENSIA Education group brings together IGENSIA School of Business, IGENSIA Tech, IGENSIA RH and American Business College in France, and ESA Casablanca in Morocco.',
  );
  if (school.groupAdmissionProcess) {
    fr.push(
      'Comment candidater. Si ton programme est sur Études en France, passe par cette plateforme : ta demande de visa sera plus simple. Tu es en lycée français ou tu as un bac français ? Pour une 1re année, passe par Parcoursup. Sinon, candidate en ligne sur le site de l’école (concours école). Quand plusieurs voies sont ouvertes, l’ordre est : Parcoursup, puis Études en France, puis concours école.',
      'Concours école : envoie ton CV, ta lettre de motivation, ta pièce d’identité, tes diplômes, tes 3 derniers bulletins au moins et un test de langue valide. L’école étudie ton dossier, puis tu passes un entretien en visio. Elle te répond par e-mail sous 48 h.',
      'Langue : il te faut un niveau B2 minimum dans la langue du programme (français ou anglais), avec un justificatif dès la candidature.',
      'Inscription : tu choisis de payer ta scolarité en une fois ou en 3 fois, puis tu verses un acompte de 3 000 €. Attention : 390 € de frais de dossier sont gardés, même si l’acompte est remboursé. Tu signes ensuite ton contrat d’études en ligne (DocuSign). L’équipe Admissions Internationales suit ta demande de visa avec son partenaire.',
      `Une question ? Écris à ${IGENSIA_CONTACT_EMAIL}. L’admission reste la décision de l’école.`,
    );
    en.push(
      'How to apply. If your programme is on Études en France, use that platform: your visa application will be simpler. At a French lycée or holding a French bac? For a first year, use Parcoursup. Otherwise, apply online on the school website (school entrance process). When several routes are open, the order is: Parcoursup, then Études en France, then the school process.',
      'School entrance process: send your CV, cover letter, ID, diplomas, at least your last 3 transcripts and a valid language test. The school reviews your file, then you have a video interview. It replies by email within 48 hours.',
      'Language: you need a B2 level minimum in the programme language (French or English), with proof when you apply.',
      'Enrolment: you choose to pay your tuition in one go or in 3 instalments, then you pay a €3,000 deposit. Note: €390 of application fees are kept, even if the deposit is refunded. You then sign your study contract online (DocuSign). The International Admissions team follows your visa application with its partner.',
      `Questions? Write to ${IGENSIA_CONTACT_EMAIL}. Admission remains the school’s decision.`,
    );
  } else {
    fr.push('L’admission reste la décision de l’école.');
    en.push('Admission remains the school’s decision.');
  }
  return { fr: fr.join('\n\n'), en: en.join('\n\n') };
}

function tuitionRange(prices: number[]): { fr: string; en: string } {
  if (!prices.length) return { fr: 'Voir programmes', en: 'See programs' };
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  if (min === max) return { fr: `${euro(min)}/an`, en: `${euro(min)}/year` };
  return {
    fr: `${euro(min)} – ${euro(max)}/an selon le programme`,
    en: `${euro(min)} – ${euro(max)}/year by programme`,
  };
}

export function igensiaInstitutionCreateData(
  school: IgensiaSchool,
  formations: readonly IgensiaFormation[],
) {
  const own = formations.filter((f) => f.schoolId === school.id);
  const campuses = [...new Set(own.flatMap((f) => f.offerings.map((o) => o.campus)))].sort(
    (a, b) => a.localeCompare(b, 'fr'),
  );
  const periods = intakePeriodsFor(own);
  const prices = own.flatMap((f) =>
    f.offerings.map((o) => o.tuitionUpfront).filter((p): p is number => p != null),
  );
  const overview = schoolOverview(school, campuses, periods);
  const tuition = tuitionRange(prices);
  return {
    id: school.id,
    nameFr: school.nameFr,
    nameEn: school.nameEn,
    countryId: FRANCE_COUNTRY_ID,
    locationFr: campuses.join(' · '),
    locationEn: campuses.join(' · '),
    overviewFr: overview.fr,
    overviewEn: overview.en,
    studyLevels: [...new Set(own.map((f) => f.level))],
    tuitionLabelFr: tuition.fr,
    tuitionLabelEn: tuition.en,
    languageRequirementsFr: school.groupAdmissionProcess
      ? 'B2 minimum dans la langue du programme (français ou anglais)'
      : '',
    languageRequirementsEn: school.groupAdmissionProcess
      ? 'B2 minimum in the programme language (French or English)'
      : '',
    intakePeriods: periods,
    programIds: own.map((f) => f.id),
    isPartner: true,
    websiteUrl: school.applicationUrl,
    sourceUrl: school.applicationUrl,
    lastVerifiedAt: IGENSIA_SOURCE_DATE,
    isActive: true,
  };
}

/** Libellés de rentrée d'une école, dans l'ordre du calendrier. */
export function intakePeriodsFor(formations: readonly IgensiaFormation[]): string[] {
  const order = Object.values(INTAKE_BY_LABEL);
  const used = new Set(formations.flatMap((f) => f.offerings.map((o) => o.intake)));
  return order.filter((i) => used.has(i.intake)).map((i) => i.periodFr);
}

export type IgensiaExistingProgram = {
  id: string;
  campusOfferings: unknown;
  updatedAt: Date;
};

export type IgensiaExistingInstitution = {
  id: string;
  intakePeriods: string[];
  programIds: string[];
};

export type IgensiaPlan = {
  /// Écoles absentes : créées avec toutes leurs formations.
  newSchools: {
    institution: ReturnType<typeof igensiaInstitutionCreateData>;
    programs: ReturnType<typeof igensiaProgramCreateData>[];
  }[];
  /// École déjà là : formations manquantes créées, dates et ids AJOUTÉS.
  schoolAdditions: {
    id: string;
    programs: ReturnType<typeof igensiaProgramCreateData>[];
    addIntakePeriods: string[];
    addProgramIds: string[];
  }[];
  /// Formation déjà là : offres manquantes ajoutées à la fin.
  offeringAdditions: {
    id: string;
    name: string;
    expectedUpdatedAt: Date;
    merged: unknown[];
    added: CampusOffering[];
  }[];
  unchanged: string[];
  skipped: { id: string; name: string; reason: string }[];
};

export function planIgensia(
  formations: readonly IgensiaFormation[],
  programs: ReadonlyMap<string, IgensiaExistingProgram>,
  institutions: ReadonlyMap<string, IgensiaExistingInstitution>,
): IgensiaPlan {
  const plan: IgensiaPlan = {
    newSchools: [],
    schoolAdditions: [],
    offeringAdditions: [],
    unchanged: [],
    skipped: [],
  };
  for (const school of IGENSIA_SCHOOLS) {
    const own = formations.filter((f) => f.schoolId === school.id);
    if (!own.length) continue;
    const existingSchool = institutions.get(school.id);
    if (!existingSchool) {
      plan.newSchools.push({
        institution: igensiaInstitutionCreateData(school, own),
        programs: own
          .filter((f) => !programs.has(f.id))
          .map((f) => igensiaProgramCreateData(f, school)),
      });
      // Une formation déjà en base sous une école absente (cas d'école) est
      // traitée comme les autres formations existantes, plus bas.
    }
    const missing = own.filter((f) => !programs.has(f.id));
    if (existingSchool) {
      const periods = intakePeriodsFor(own).filter(
        (p) => !existingSchool.intakePeriods.includes(p),
      );
      const ids = missing.map((f) => f.id).filter((id) => !existingSchool.programIds.includes(id));
      if (missing.length || periods.length || ids.length) {
        plan.schoolAdditions.push({
          id: school.id,
          programs: missing.map((f) => igensiaProgramCreateData(f, school)),
          addIntakePeriods: periods,
          addProgramIds: ids,
        });
      }
    }
    for (const formation of own) {
      const existing = programs.get(formation.id);
      if (!existing) continue;
      const current = readCampusOfferings(existing.campusOfferings);
      if (current === null) {
        plan.skipped.push({
          id: formation.id,
          name: formation.name,
          reason: 'campusOfferings vide (fiche retouchée ?) — à vérifier dans l’admin',
        });
        continue;
      }
      const { merged, added } = mergeCampusOfferings(current, formation.offerings);
      if (!added.length) {
        plan.unchanged.push(formation.id);
        continue;
      }
      plan.offeringAdditions.push({
        id: formation.id,
        name: formation.name,
        expectedUpdatedAt: existing.updatedAt,
        merged,
        added,
      });
    }
  }
  return plan;
}

export function igensiaPlanWriteCount(plan: IgensiaPlan): number {
  return (
    plan.newSchools.length +
    plan.schoolAdditions.length +
    plan.offeringAdditions.length
  );
}
