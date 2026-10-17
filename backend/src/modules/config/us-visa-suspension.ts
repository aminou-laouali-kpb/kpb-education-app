// ─────────────────────────────────────────────────────────────────────────────
// Suspension des visas étudiants américains (F, M, J), servie par `/config/app`.
//
// Décision du propriétaire du 17/10/2026 : on garde les États-Unis pour tout le
// monde, mais les fiches établissement, formation et pays des États-Unis portent
// un avis sobre — « Les demandes de visa étudiant sont actuellement suspendues
// pour les ressortissants de : … ».
//
// ## La source, vérifiée le 17/10/2026
//
// Proclamation présidentielle 10998 du 16/12/2025 (« Restricting and Limiting
// the Entry of Foreign Nationals to Protect the Security of the United States »),
// en vigueur le 1/1/2026 à 0 h 01 (heure de l'Est), texte officiel :
// www.govinfo.gov/content/pkg/DCPD-202501199/html/DCPD-202501199.htm (sans
// schéma ici : ce lien documente, l'app ne l'ouvre pas)
//   - sec. 2, suspension totale maintenue : Tchad, République du Congo (…) ;
//   - sec. 3, suspension partielle maintenue (dont visas F, M, J, héritée de la
//     proclamation 10949) : Burundi, Togo (…) ;
//   - sec. 4, suspension totale nouvelle : Burkina Faso, Mali, Niger (…) ;
//   - sec. 5, suspension partielle nouvelle « B-1, B-2, B-1/B-2, F, M, and J » :
//     Bénin, Côte d'Ivoire, Gabon, Mauritanie, Sénégal (…).
// La page du Département d'État que l'app ouvre (`DEFAULT_SOURCE_URL`) résume
// la même proclamation.
//
// La liste par défaut est celle du propriétaire (10 pays) plus le Burundi et le
// Togo, qu'il demandait de revérifier : tous deux sont confirmés par la sec. 3.
// La proclamation vise d'autres pays (dont le Nigeria, la Sierra Leone et la
// Gambie) que le propriétaire n'a pas retenus : À VALIDER, et ajoutables sans
// nouvelle build par `KPB_US_VISA_SUSPENDED_COUNTRIES`.
//
// ## Pilotable sans build
//
// `KPB_US_VISA_SUSPENDED_COUNTRIES` : codes ISO 3166-1 alpha-2 séparés par des
// virgules (`BF,ML,NE`). Vide ou absente : la liste par défaut ci-dessous.
// `none` : aucune suspension, l'app ne montre plus d'avis.
// `KPB_US_VISA_SUSPENSION_VERIFIED_AT` : le jour de la dernière vérification
// (`AAAA-MM-JJ`). `KPB_US_VISA_SUSPENSION_SOURCE_URL` : la page officielle
// (https). L'app embarque la même liste par défaut, pour un serveur plus ancien
// ou injoignable.
// ─────────────────────────────────────────────────────────────────────────────

/** Les pays de la décision du 17/10/2026, vérifiés le même jour. */
export const DEFAULT_US_VISA_SUSPENDED_COUNTRIES: readonly string[] = [
  'BF', // Burkina Faso — sec. 4 (totale)
  'ML', // Mali — sec. 4 (totale)
  'NE', // Niger — sec. 4 (totale)
  'TD', // Tchad — sec. 2 (totale)
  'CG', // Congo (République du Congo) — sec. 2 (totale)
  'BJ', // Bénin — sec. 5 (F, M, J)
  'CI', // Côte d'Ivoire — sec. 5 (F, M, J)
  'SN', // Sénégal — sec. 5 (F, M, J)
  'GA', // Gabon — sec. 5 (F, M, J)
  'MR', // Mauritanie — sec. 5 (F, M, J)
  'BI', // Burundi — sec. 3 (partielle maintenue, F, M, J)
  'TG', // Togo — sec. 3 (partielle maintenue, F, M, J)
];

export const DEFAULT_US_VISA_SUSPENSION_VERIFIED_AT = '2026-10-17';

export const DEFAULT_US_VISA_SUSPENSION_SOURCE_URL =
  'https://travel.state.gov/content/travel/en/News/visas-news/' +
  'suspension-of-visa-issuance-to-foreign-nationals-to-protect-the-security-of-the-united-states.html';

/**
 * Les noms affichés, par code. Un code absent de cette table reste servi, avec
 * le code pour nom : l'app compare aussi les codes, et l'exploitation voit le
 * code nu dans `curl /config/app` — signe qu'il faut compléter la table.
 */
const COUNTRY_NAMES: Readonly<Record<string, { fr: string; en: string }>> = {
  AO: { fr: 'Angola', en: 'Angola' },
  BF: { fr: 'Burkina Faso', en: 'Burkina Faso' },
  BI: { fr: 'Burundi', en: 'Burundi' },
  BJ: { fr: 'Bénin', en: 'Benin' },
  CD: { fr: 'République démocratique du Congo', en: 'Democratic Republic of the Congo' },
  CF: { fr: 'République centrafricaine', en: 'Central African Republic' },
  CG: { fr: 'Congo', en: 'Republic of the Congo' },
  CI: { fr: 'Côte d\'Ivoire', en: 'Côte d\'Ivoire' },
  CM: { fr: 'Cameroun', en: 'Cameroon' },
  CV: { fr: 'Cap-Vert', en: 'Cabo Verde' },
  DJ: { fr: 'Djibouti', en: 'Djibouti' },
  GA: { fr: 'Gabon', en: 'Gabon' },
  GH: { fr: 'Ghana', en: 'Ghana' },
  GM: { fr: 'Gambie', en: 'The Gambia' },
  GN: { fr: 'Guinée', en: 'Guinea' },
  GQ: { fr: 'Guinée équatoriale', en: 'Equatorial Guinea' },
  GW: { fr: 'Guinée-Bissau', en: 'Guinea-Bissau' },
  HT: { fr: 'Haïti', en: 'Haiti' },
  KM: { fr: 'Comores', en: 'Comoros' },
  LR: { fr: 'Liberia', en: 'Liberia' },
  MA: { fr: 'Maroc', en: 'Morocco' },
  MG: { fr: 'Madagascar', en: 'Madagascar' },
  ML: { fr: 'Mali', en: 'Mali' },
  MR: { fr: 'Mauritanie', en: 'Mauritania' },
  MW: { fr: 'Malawi', en: 'Malawi' },
  NE: { fr: 'Niger', en: 'Niger' },
  NG: { fr: 'Nigeria', en: 'Nigeria' },
  RW: { fr: 'Rwanda', en: 'Rwanda' },
  SL: { fr: 'Sierra Leone', en: 'Sierra Leone' },
  SN: { fr: 'Sénégal', en: 'Senegal' },
  SS: { fr: 'Soudan du Sud', en: 'South Sudan' },
  TD: { fr: 'Tchad', en: 'Chad' },
  TG: { fr: 'Togo', en: 'Togo' },
  TN: { fr: 'Tunisie', en: 'Tunisia' },
  TZ: { fr: 'Tanzanie', en: 'Tanzania' },
  ZM: { fr: 'Zambie', en: 'Zambia' },
  ZW: { fr: 'Zimbabwe', en: 'Zimbabwe' },
};

export type UsVisaSuspensionCountry = { code: string; nameFr: string; nameEn: string };

export type UsVisaSuspension = {
  /** Vide = aucune suspension : l'app ne montre aucun avis. */
  countries: UsVisaSuspensionCountry[];
  /** Les catégories de visa concernées, pour le texte de l'avis. */
  visaTypes: string[];
  /** Jour nu `AAAA-MM-JJ`, ou `null` quand la liste personnalisée n'en donne pas. */
  lastVerifiedAt: string | null;
  sourceUrl: string;
};

/**
 * Lit la configuration. Toute valeur illisible retombe sur le défaut vérifié,
 * jamais sur « aucune suspension » : une faute de frappe dans une variable ne
 * doit pas retirer l'avis à des élèves concernés. Seul `none` le retire.
 */
export function usVisaSuspensionConfig(env: {
  countries?: string;
  verifiedAt?: string;
  sourceUrl?: string;
}): UsVisaSuspension {
  const raw = env.countries?.trim() ?? '';
  let codes: string[];
  let custom = false;
  if (raw.toLowerCase() === 'none') {
    codes = [];
    custom = true;
  } else {
    const parsed = parseCountryCodes(raw);
    custom = parsed.length > 0;
    codes = custom ? parsed : [...DEFAULT_US_VISA_SUSPENDED_COUNTRIES];
  }
  const verifiedAt = isoDay(env.verifiedAt);
  return {
    countries: codes.map((code) => ({
      code,
      nameFr: COUNTRY_NAMES[code]?.fr ?? code,
      nameEn: COUNTRY_NAMES[code]?.en ?? code,
    })),
    visaTypes: ['F', 'M', 'J'],
    // Une liste personnalisée sans date n'hérite PAS de la date du défaut :
    // personne n'a vérifié cette liste-là ce jour-là.
    lastVerifiedAt: verifiedAt ?? (custom ? null : DEFAULT_US_VISA_SUSPENSION_VERIFIED_AT),
    sourceUrl: httpsUrl(env.sourceUrl) ?? DEFAULT_US_VISA_SUSPENSION_SOURCE_URL,
  };
}

/** `bf, ML ,ne,xx1` → `['BF','ML','NE']` : deux lettres, dédoublonnées. */
function parseCountryCodes(raw: string): string[] {
  const seen = new Set<string>();
  for (const entry of raw.split(',')) {
    const code = entry.trim().toUpperCase();
    if (/^[A-Z]{2}$/.test(code)) seen.add(code);
  }
  return [...seen];
}

function isoDay(value: string | undefined): string | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value?.trim() ?? '');
  if (!match) return null;
  const [year, month, day] = match.slice(1).map(Number);
  const probe = new Date(Date.UTC(year, month - 1, day));
  return probe.getUTCFullYear() === year &&
    probe.getUTCMonth() === month - 1 &&
    probe.getUTCDate() === day
    ? match[0]
    : null;
}

function httpsUrl(value: string | undefined): string | null {
  const raw = value?.trim();
  if (!raw) return null;
  try {
    const url = new URL(raw);
    if (url.protocol !== 'https:' || url.username || url.password) return null;
    return url.toString();
  } catch {
    return null;
  }
}
