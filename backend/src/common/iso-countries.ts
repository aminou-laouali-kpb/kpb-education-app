// ─────────────────────────────────────────────────────────────────────────────
// Table des pays ISO 3166-1, partagée.
//
// Code canonique : alpha-3 en MINUSCULES, le même que `Scholarship.countryId`
// (scholarship-catalog.validator.ts). Noms FR et EN pour les listes servies
// et les libellés ; alias pour normaliser le texte libre de
// `UserProfile.countryOfResidence` (« Sénégal », « Cote d'Ivoire », « RDC »,
// « Congo-Brazzaville »…).
//
// Une seule table pour tout le serveur : `country-timezone.ts` y résout
// désormais la résidence avant d'en lire le fuseau, au lieu de tenir sa
// propre liste d'alias groupée par fuseau.
// ─────────────────────────────────────────────────────────────────────────────

export interface IsoCountry {
  /** ISO 3166-1 alpha-3, minuscules. */
  code: string;
  /** ISO 3166-1 alpha-2, majuscules. */
  alpha2: string;
  nameFr: string;
  nameEn: string;
  /** Autres graphies acceptées en entrée (jamais affichées). */
  aliases: readonly string[];
}

type Row = readonly [
  code: string,
  alpha2: string,
  nameFr: string,
  nameEn: string,
  ...aliases: string[],
];

// Ordre : celui du code alpha-3 anglais (liste ISO), sans importance ici.
// Les listes d'options ont leur propre ordre (voir scholarship-match/countries.ts).
const ROWS: readonly Row[] = [
  ['afg', 'AF', 'Afghanistan', 'Afghanistan'],
  ['ala', 'AX', 'Îles Åland', 'Åland Islands', 'Aland'],
  ['alb', 'AL', 'Albanie', 'Albania'],
  ['dza', 'DZ', 'Algérie', 'Algeria'],
  ['asm', 'AS', 'Samoa américaines', 'American Samoa'],
  ['and', 'AD', 'Andorre', 'Andorra'],
  ['ago', 'AO', 'Angola', 'Angola'],
  ['aia', 'AI', 'Anguilla', 'Anguilla'],
  ['ata', 'AQ', 'Antarctique', 'Antarctica'],
  ['atg', 'AG', 'Antigua-et-Barbuda', 'Antigua and Barbuda'],
  ['arg', 'AR', 'Argentine', 'Argentina'],
  ['arm', 'AM', 'Arménie', 'Armenia'],
  ['abw', 'AW', 'Aruba', 'Aruba'],
  ['aus', 'AU', 'Australie', 'Australia'],
  ['aut', 'AT', 'Autriche', 'Austria'],
  ['aze', 'AZ', 'Azerbaïdjan', 'Azerbaijan'],
  ['bhs', 'BS', 'Bahamas', 'Bahamas'],
  ['bhr', 'BH', 'Bahreïn', 'Bahrain'],
  ['bgd', 'BD', 'Bangladesh', 'Bangladesh'],
  ['brb', 'BB', 'Barbade', 'Barbados'],
  ['blr', 'BY', 'Biélorussie', 'Belarus', 'Bélarus'],
  ['bel', 'BE', 'Belgique', 'Belgium'],
  ['blz', 'BZ', 'Belize', 'Belize'],
  ['ben', 'BJ', 'Bénin', 'Benin'],
  ['bmu', 'BM', 'Bermudes', 'Bermuda'],
  ['btn', 'BT', 'Bhoutan', 'Bhutan'],
  ['bol', 'BO', 'Bolivie', 'Bolivia'],
  ['bes', 'BQ', 'Pays-Bas caribéens', 'Caribbean Netherlands', 'Bonaire'],
  ['bih', 'BA', 'Bosnie-Herzégovine', 'Bosnia and Herzegovina', 'Bosnie'],
  ['bwa', 'BW', 'Botswana', 'Botswana'],
  ['bvt', 'BV', 'Île Bouvet', 'Bouvet Island'],
  ['bra', 'BR', 'Brésil', 'Brazil'],
  ['iot', 'IO', 'Territoire britannique de l’océan Indien', 'British Indian Ocean Territory'],
  ['brn', 'BN', 'Brunei', 'Brunei', 'Brunei Darussalam'],
  ['bgr', 'BG', 'Bulgarie', 'Bulgaria'],
  ['bfa', 'BF', 'Burkina Faso', 'Burkina Faso', 'Burkina'],
  ['bdi', 'BI', 'Burundi', 'Burundi'],
  ['cpv', 'CV', 'Cap-Vert', 'Cabo Verde', 'Cape Verde', 'Cabo Verde'],
  ['khm', 'KH', 'Cambodge', 'Cambodia'],
  ['cmr', 'CM', 'Cameroun', 'Cameroon'],
  ['can', 'CA', 'Canada', 'Canada'],
  ['cym', 'KY', 'Îles Caïmans', 'Cayman Islands'],
  ['caf', 'CF', 'Centrafrique', 'Central African Republic', 'République centrafricaine', 'RCA', 'CAR'],
  ['tcd', 'TD', 'Tchad', 'Chad'],
  ['chl', 'CL', 'Chili', 'Chile'],
  ['chn', 'CN', 'Chine', 'China'],
  ['cxr', 'CX', 'Île Christmas', 'Christmas Island'],
  ['cck', 'CC', 'Îles Cocos', 'Cocos (Keeling) Islands', 'Cocos Islands'],
  ['col', 'CO', 'Colombie', 'Colombia'],
  ['com', 'KM', 'Comores', 'Comoros', 'Union des Comores'],
  [
    'cog', 'CG', 'Congo', 'Republic of the Congo',
    'Congo-Brazzaville', 'Congo Brazza', 'République du Congo', 'Republic of Congo',
    'Congo Republic',
  ],
  [
    'cod', 'CD', 'République démocratique du Congo', 'Democratic Republic of the Congo',
    'RDC', 'RD Congo', 'DR Congo', 'DRC', 'Congo-Kinshasa', 'Congo RDC',
    'République Démocratique du Congo', 'Democratic Republic of Congo', 'Zaïre',
  ],
  ['cok', 'CK', 'Îles Cook', 'Cook Islands'],
  ['cri', 'CR', 'Costa Rica', 'Costa Rica'],
  ['civ', 'CI', 'Côte d’Ivoire', 'Côte d’Ivoire', 'Ivory Coast', 'Cote dIvoire', 'RCI'],
  ['hrv', 'HR', 'Croatie', 'Croatia'],
  ['cub', 'CU', 'Cuba', 'Cuba'],
  ['cuw', 'CW', 'Curaçao', 'Curaçao'],
  ['cyp', 'CY', 'Chypre', 'Cyprus'],
  ['cze', 'CZ', 'Tchéquie', 'Czechia', 'République tchèque', 'Czech Republic'],
  ['dnk', 'DK', 'Danemark', 'Denmark'],
  ['dji', 'DJ', 'Djibouti', 'Djibouti'],
  ['dma', 'DM', 'Dominique', 'Dominica'],
  ['dom', 'DO', 'République dominicaine', 'Dominican Republic'],
  ['ecu', 'EC', 'Équateur', 'Ecuador'],
  ['egy', 'EG', 'Égypte', 'Egypt'],
  ['slv', 'SV', 'Salvador', 'El Salvador'],
  ['gnq', 'GQ', 'Guinée équatoriale', 'Equatorial Guinea'],
  ['eri', 'ER', 'Érythrée', 'Eritrea'],
  ['est', 'EE', 'Estonie', 'Estonia'],
  ['swz', 'SZ', 'Eswatini', 'Eswatini', 'Swaziland'],
  ['eth', 'ET', 'Éthiopie', 'Ethiopia'],
  ['flk', 'FK', 'Îles Malouines', 'Falkland Islands', 'Malouines'],
  ['fro', 'FO', 'Îles Féroé', 'Faroe Islands'],
  ['fji', 'FJ', 'Fidji', 'Fiji'],
  ['fin', 'FI', 'Finlande', 'Finland'],
  ['fra', 'FR', 'France', 'France'],
  ['guf', 'GF', 'Guyane', 'French Guiana', 'Guyane française'],
  ['pyf', 'PF', 'Polynésie française', 'French Polynesia'],
  ['atf', 'TF', 'Terres australes françaises', 'French Southern Territories'],
  ['gab', 'GA', 'Gabon', 'Gabon'],
  ['gmb', 'GM', 'Gambie', 'Gambia', 'The Gambia'],
  ['geo', 'GE', 'Géorgie', 'Georgia'],
  ['deu', 'DE', 'Allemagne', 'Germany'],
  ['gha', 'GH', 'Ghana', 'Ghana'],
  ['gib', 'GI', 'Gibraltar', 'Gibraltar'],
  ['grc', 'GR', 'Grèce', 'Greece'],
  ['grl', 'GL', 'Groenland', 'Greenland'],
  ['grd', 'GD', 'Grenade', 'Grenada'],
  ['glp', 'GP', 'Guadeloupe', 'Guadeloupe'],
  ['gum', 'GU', 'Guam', 'Guam'],
  ['gtm', 'GT', 'Guatemala', 'Guatemala'],
  ['ggy', 'GG', 'Guernesey', 'Guernsey'],
  ['gin', 'GN', 'Guinée', 'Guinea', 'Guinée-Conakry', 'Guinea-Conakry'],
  ['gnb', 'GW', 'Guinée-Bissau', 'Guinea-Bissau'],
  ['guy', 'GY', 'Guyana', 'Guyana'],
  ['hti', 'HT', 'Haïti', 'Haiti'],
  ['hmd', 'HM', 'Îles Heard-et-MacDonald', 'Heard Island and McDonald Islands'],
  ['vat', 'VA', 'Vatican', 'Holy See', 'Saint-Siège', 'Vatican City'],
  ['hnd', 'HN', 'Honduras', 'Honduras'],
  ['hkg', 'HK', 'Hong Kong', 'Hong Kong'],
  ['hun', 'HU', 'Hongrie', 'Hungary'],
  ['isl', 'IS', 'Islande', 'Iceland'],
  ['ind', 'IN', 'Inde', 'India'],
  ['idn', 'ID', 'Indonésie', 'Indonesia'],
  ['irn', 'IR', 'Iran', 'Iran'],
  ['irq', 'IQ', 'Irak', 'Iraq'],
  ['irl', 'IE', 'Irlande', 'Ireland'],
  ['imn', 'IM', 'Île de Man', 'Isle of Man'],
  ['isr', 'IL', 'Israël', 'Israel'],
  ['ita', 'IT', 'Italie', 'Italy'],
  ['jam', 'JM', 'Jamaïque', 'Jamaica'],
  ['jpn', 'JP', 'Japon', 'Japan'],
  ['jey', 'JE', 'Jersey', 'Jersey'],
  ['jor', 'JO', 'Jordanie', 'Jordan'],
  ['kaz', 'KZ', 'Kazakhstan', 'Kazakhstan'],
  ['ken', 'KE', 'Kenya', 'Kenya'],
  ['kir', 'KI', 'Kiribati', 'Kiribati'],
  ['prk', 'KP', 'Corée du Nord', 'North Korea'],
  ['kor', 'KR', 'Corée du Sud', 'South Korea', 'Corée', 'Korea'],
  ['kwt', 'KW', 'Koweït', 'Kuwait'],
  ['kgz', 'KG', 'Kirghizistan', 'Kyrgyzstan'],
  ['lao', 'LA', 'Laos', 'Laos'],
  ['lva', 'LV', 'Lettonie', 'Latvia'],
  ['lbn', 'LB', 'Liban', 'Lebanon'],
  ['lso', 'LS', 'Lesotho', 'Lesotho'],
  ['lbr', 'LR', 'Liberia', 'Liberia', 'Libéria'],
  ['lby', 'LY', 'Libye', 'Libya'],
  ['lie', 'LI', 'Liechtenstein', 'Liechtenstein'],
  ['ltu', 'LT', 'Lituanie', 'Lithuania'],
  ['lux', 'LU', 'Luxembourg', 'Luxembourg'],
  ['mac', 'MO', 'Macao', 'Macao', 'Macau'],
  ['mdg', 'MG', 'Madagascar', 'Madagascar'],
  ['mwi', 'MW', 'Malawi', 'Malawi'],
  ['mys', 'MY', 'Malaisie', 'Malaysia'],
  ['mdv', 'MV', 'Maldives', 'Maldives'],
  ['mli', 'ML', 'Mali', 'Mali'],
  ['mlt', 'MT', 'Malte', 'Malta'],
  ['mhl', 'MH', 'Îles Marshall', 'Marshall Islands'],
  ['mtq', 'MQ', 'Martinique', 'Martinique'],
  ['mrt', 'MR', 'Mauritanie', 'Mauritania'],
  ['mus', 'MU', 'Maurice', 'Mauritius', 'Île Maurice'],
  ['myt', 'YT', 'Mayotte', 'Mayotte'],
  ['mex', 'MX', 'Mexique', 'Mexico'],
  ['fsm', 'FM', 'Micronésie', 'Micronesia'],
  ['mda', 'MD', 'Moldavie', 'Moldova'],
  ['mco', 'MC', 'Monaco', 'Monaco'],
  ['mng', 'MN', 'Mongolie', 'Mongolia'],
  ['mne', 'ME', 'Monténégro', 'Montenegro'],
  ['msr', 'MS', 'Montserrat', 'Montserrat'],
  ['mar', 'MA', 'Maroc', 'Morocco'],
  ['moz', 'MZ', 'Mozambique', 'Mozambique'],
  ['mmr', 'MM', 'Birmanie', 'Myanmar', 'Burma'],
  ['nam', 'NA', 'Namibie', 'Namibia'],
  ['nru', 'NR', 'Nauru', 'Nauru'],
  ['npl', 'NP', 'Népal', 'Nepal'],
  ['nld', 'NL', 'Pays-Bas', 'Netherlands', 'Hollande', 'Holland'],
  ['ncl', 'NC', 'Nouvelle-Calédonie', 'New Caledonia'],
  ['nzl', 'NZ', 'Nouvelle-Zélande', 'New Zealand'],
  ['nic', 'NI', 'Nicaragua', 'Nicaragua'],
  ['ner', 'NE', 'Niger', 'Niger', 'République du Niger'],
  ['nga', 'NG', 'Nigeria', 'Nigeria', 'Nigéria'],
  ['niu', 'NU', 'Niue', 'Niue'],
  ['nfk', 'NF', 'Île Norfolk', 'Norfolk Island'],
  ['mkd', 'MK', 'Macédoine du Nord', 'North Macedonia', 'Macédoine'],
  ['mnp', 'MP', 'Îles Mariannes du Nord', 'Northern Mariana Islands'],
  ['nor', 'NO', 'Norvège', 'Norway'],
  ['omn', 'OM', 'Oman', 'Oman'],
  ['pak', 'PK', 'Pakistan', 'Pakistan'],
  ['plw', 'PW', 'Palaos', 'Palau'],
  ['pse', 'PS', 'Palestine', 'Palestine'],
  ['pan', 'PA', 'Panama', 'Panama'],
  ['png', 'PG', 'Papouasie-Nouvelle-Guinée', 'Papua New Guinea'],
  ['pry', 'PY', 'Paraguay', 'Paraguay'],
  ['per', 'PE', 'Pérou', 'Peru'],
  ['phl', 'PH', 'Philippines', 'Philippines'],
  ['pcn', 'PN', 'Îles Pitcairn', 'Pitcairn Islands'],
  ['pol', 'PL', 'Pologne', 'Poland'],
  ['prt', 'PT', 'Portugal', 'Portugal'],
  ['pri', 'PR', 'Porto Rico', 'Puerto Rico'],
  ['qat', 'QA', 'Qatar', 'Qatar'],
  ['reu', 'RE', 'La Réunion', 'Réunion', 'Réunion', 'Ile de la Réunion'],
  ['rou', 'RO', 'Roumanie', 'Romania'],
  ['rus', 'RU', 'Russie', 'Russia', 'Fédération de Russie', 'Russian Federation'],
  ['rwa', 'RW', 'Rwanda', 'Rwanda'],
  ['blm', 'BL', 'Saint-Barthélemy', 'Saint Barthélemy'],
  ['shn', 'SH', 'Sainte-Hélène', 'Saint Helena'],
  ['kna', 'KN', 'Saint-Christophe-et-Niévès', 'Saint Kitts and Nevis'],
  ['lca', 'LC', 'Sainte-Lucie', 'Saint Lucia'],
  ['maf', 'MF', 'Saint-Martin', 'Saint Martin'],
  ['spm', 'PM', 'Saint-Pierre-et-Miquelon', 'Saint Pierre and Miquelon'],
  ['vct', 'VC', 'Saint-Vincent-et-les-Grenadines', 'Saint Vincent and the Grenadines'],
  ['wsm', 'WS', 'Samoa', 'Samoa'],
  ['smr', 'SM', 'Saint-Marin', 'San Marino'],
  ['stp', 'ST', 'Sao Tomé-et-Principe', 'São Tomé and Príncipe', 'Sao Tome'],
  ['sau', 'SA', 'Arabie saoudite', 'Saudi Arabia'],
  ['sen', 'SN', 'Sénégal', 'Senegal'],
  ['srb', 'RS', 'Serbie', 'Serbia'],
  ['syc', 'SC', 'Seychelles', 'Seychelles'],
  ['sle', 'SL', 'Sierra Leone', 'Sierra Leone'],
  ['sgp', 'SG', 'Singapour', 'Singapore'],
  ['sxm', 'SX', 'Saint-Martin (partie néerlandaise)', 'Sint Maarten'],
  ['svk', 'SK', 'Slovaquie', 'Slovakia'],
  ['svn', 'SI', 'Slovénie', 'Slovenia'],
  ['slb', 'SB', 'Îles Salomon', 'Solomon Islands'],
  ['som', 'SO', 'Somalie', 'Somalia'],
  ['zaf', 'ZA', 'Afrique du Sud', 'South Africa'],
  ['sgs', 'GS', 'Géorgie du Sud-et-les îles Sandwich du Sud', 'South Georgia and the South Sandwich Islands'],
  ['ssd', 'SS', 'Soudan du Sud', 'South Sudan'],
  ['esp', 'ES', 'Espagne', 'Spain'],
  ['lka', 'LK', 'Sri Lanka', 'Sri Lanka'],
  ['sdn', 'SD', 'Soudan', 'Sudan'],
  ['sur', 'SR', 'Suriname', 'Suriname'],
  ['sjm', 'SJ', 'Svalbard et Jan Mayen', 'Svalbard and Jan Mayen'],
  ['swe', 'SE', 'Suède', 'Sweden'],
  ['che', 'CH', 'Suisse', 'Switzerland'],
  ['syr', 'SY', 'Syrie', 'Syria'],
  ['twn', 'TW', 'Taïwan', 'Taiwan'],
  ['tjk', 'TJ', 'Tadjikistan', 'Tajikistan'],
  ['tza', 'TZ', 'Tanzanie', 'Tanzania'],
  ['tha', 'TH', 'Thaïlande', 'Thailand'],
  ['tls', 'TL', 'Timor oriental', 'Timor-Leste', 'East Timor'],
  ['tgo', 'TG', 'Togo', 'Togo'],
  ['tkl', 'TK', 'Tokelau', 'Tokelau'],
  ['ton', 'TO', 'Tonga', 'Tonga'],
  ['tto', 'TT', 'Trinité-et-Tobago', 'Trinidad and Tobago'],
  ['tun', 'TN', 'Tunisie', 'Tunisia'],
  ['tur', 'TR', 'Turquie', 'Türkiye', 'Turkey'],
  ['tkm', 'TM', 'Turkménistan', 'Turkmenistan'],
  ['tca', 'TC', 'Îles Turques-et-Caïques', 'Turks and Caicos Islands'],
  ['tuv', 'TV', 'Tuvalu', 'Tuvalu'],
  ['uga', 'UG', 'Ouganda', 'Uganda'],
  ['ukr', 'UA', 'Ukraine', 'Ukraine'],
  [
    'are', 'AE', 'Émirats arabes unis', 'United Arab Emirates',
    'UAE', 'EAU', 'Emirats', 'Émirats',
  ],
  [
    'gbr', 'GB', 'Royaume-Uni', 'United Kingdom',
    'UK', 'Angleterre', 'England', 'Grande-Bretagne', 'Great Britain',
  ],
  [
    'usa', 'US', 'États-Unis', 'United States',
    'USA', 'Etats Unis', 'United States of America', 'US of America', 'Amérique',
  ],
  ['umi', 'UM', 'Îles mineures éloignées des États-Unis', 'United States Minor Outlying Islands'],
  ['ury', 'UY', 'Uruguay', 'Uruguay'],
  ['uzb', 'UZ', 'Ouzbékistan', 'Uzbekistan'],
  ['vut', 'VU', 'Vanuatu', 'Vanuatu'],
  ['ven', 'VE', 'Venezuela', 'Venezuela'],
  ['vnm', 'VN', 'Viêt Nam', 'Vietnam', 'Viet Nam'],
  ['vgb', 'VG', 'Îles Vierges britanniques', 'British Virgin Islands'],
  ['vir', 'VI', 'Îles Vierges des États-Unis', 'U.S. Virgin Islands'],
  ['wlf', 'WF', 'Wallis-et-Futuna', 'Wallis and Futuna'],
  ['esh', 'EH', 'Sahara occidental', 'Western Sahara'],
  ['yem', 'YE', 'Yémen', 'Yemen'],
  ['zmb', 'ZM', 'Zambie', 'Zambia'],
  ['zwe', 'ZW', 'Zimbabwe', 'Zimbabwe'],
];

/**
 * Territoires sans population permanente : présents pour normaliser, jamais
 * proposés comme nationalité ou résidence.
 */
const UNINHABITED = new Set(['ata', 'bvt', 'hmd', 'sgs', 'umi', 'atf', 'iot']);

export const ISO_COUNTRIES: readonly IsoCountry[] = ROWS.map(
  ([code, alpha2, nameFr, nameEn, ...aliases]) => ({
    code,
    alpha2,
    nameFr,
    nameEn,
    aliases,
  }),
);

const BY_CODE: ReadonlyMap<string, IsoCountry> = new Map(
  ISO_COUNTRIES.map((country) => [country.code, country]),
);

/**
 * Minuscules, sans accents, apostrophes typographiques comprises, chaque suite
 * de caractères non alphanumériques réduite à une espace.
 */
export function foldCountryText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** Articles et formules en tête qu'on retire avant un second essai. */
const LEADING_NOISE = /^(?:le|la|les|l|the|republique du|republique de|republic of)\s+/;

const BY_KEY: ReadonlyMap<string, string> = (() => {
  const map = new Map<string, string>();
  const add = (key: string, code: string) => {
    const folded = foldCountryText(key);
    if (!folded) return;
    const existing = map.get(folded);
    if (existing && existing !== code) {
      // Un alias ambigu est une erreur de table, pas une donnée : on l'arrête
      // au chargement plutôt que de résoudre au hasard.
      throw new Error(`Alias de pays ambigu : « ${key} » (${existing} / ${code})`);
    }
    map.set(folded, code);
  };
  for (const country of ISO_COUNTRIES) {
    add(country.code, country.code);
    add(country.alpha2, country.code);
    add(country.nameFr, country.code);
    add(country.nameEn, country.code);
    for (const alias of country.aliases) add(alias, country.code);
  }
  return map;
})();

/** Vrai pour un code alpha-3 minuscule connu de la table. */
export function isIsoCountryCode(code: unknown): code is string {
  return typeof code === 'string' && BY_CODE.has(code);
}

/** Vrai pour un pays habité, donc proposable comme nationalité ou résidence. */
export function isSelectableCountryCode(code: unknown): code is string {
  return isIsoCountryCode(code) && !UNINHABITED.has(code);
}

export function isoCountry(code: string): IsoCountry | undefined {
  return BY_CODE.get(code);
}

/** Nom d'un pays dans la langue demandée ; le code tel quel s'il est inconnu. */
export function countryName(code: string, lang: 'fr' | 'en'): string {
  const country = BY_CODE.get(code);
  if (!country) return code.toUpperCase();
  return lang === 'en' ? country.nameEn : country.nameFr;
}

/**
 * Code alpha-3 d'un texte libre (nom FR/EN, alias, alpha-2, alpha-3), ou null.
 * « Autre », vide ou inconnu → null : on ne devine jamais.
 */
export function resolveCountryCode(input: string | null | undefined): string | null {
  if (typeof input !== 'string') return null;
  const folded = foldCountryText(input);
  if (!folded) return null;
  const direct = BY_KEY.get(folded);
  if (direct) return direct;
  const stripped = folded.replace(LEADING_NOISE, '');
  if (stripped !== folded) return BY_KEY.get(stripped) ?? null;
  return null;
}
