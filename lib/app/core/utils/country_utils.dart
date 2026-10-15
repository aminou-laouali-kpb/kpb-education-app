const countryFlagById = <String, String>{
  'usa': '🇺🇸',
  'canada': '🇨🇦',
  'can': '🇨🇦',
  'france': '🇫🇷',
  'fra': '🇫🇷',
  'uk': '🇬🇧',
  'gbr': '🇬🇧',
  'morocco': '🇲🇦',
  'mar': '🇲🇦',
  'turkey': '🇹🇷',
  'tur': '🇹🇷',
  'germany': '🇩🇪',
  'deu': '🇩🇪',
  'spain': '🇪🇸',
  'esp': '🇪🇸',
  'are': '🇦🇪',
  'uae': '🇦🇪',
  'china': '🇨🇳',
  'chn': '🇨🇳',
  'belgium': '🇧🇪',
  'bel': '🇧🇪',
  'italy': '🇮🇹',
  'ita': '🇮🇹',
  'portugal': '🇵🇹',
  'prt': '🇵🇹',
};

const _legacyCountryIdAliases = <String, String>{
  'france': 'fra',
  'canada': 'can',
  'uk': 'gbr',
  'united kingdom': 'gbr',
  'germany': 'deu',
  'spain': 'esp',
  'morocco': 'mar',
  'turkey': 'tur',
  'uae': 'are',
  'united arab emirates': 'are',
  'united states': 'usa',
  'china': 'chn',
};

/// Destination countries available at launch (ISO-3 ids, matching the backend
/// `m5-countries` seed). Used to filter the offline mock catalog and any remote
/// payload down to the launch scope.
const kMvpCountryIds = <String>{
  'fra',
  'deu',
  'usa',
  'can',
  'mar',
  'tur',
  'are',
  'gbr',
  'esp',
  'chn',
};

String normalizeCountryId(String id) =>
    _legacyCountryIdAliases[id.trim().toLowerCase()] ?? id.trim().toLowerCase();

/// True when [id] (full-word or ISO-3) resolves to one of the nine MVP
/// destination countries.
bool isMvpCountryId(String id) =>
    kMvpCountryIds.contains(normalizeCountryId(id));

/// ISO 3166-1 alpha-3 → alpha-2, pour les pays que le catalogue de bourses et
/// les collecteurs servent (et leurs voisins probables). Le drapeau se calcule
/// ensuite à partir des deux lettres : pas d'emoji recopié à la main, donc pas
/// de drapeau faux.
///
/// Les identifiants du serveur sont des alpha-3 (`Country.id`) ; une entrée
/// absente retombe sur 🌍 — jamais sur un drapeau deviné. `int` (programmes
/// multi-pays) n'a délibérément pas d'entrée.
const _iso3ToIso2 = <String, String>{
  // Afrique
  'bfa': 'BF', 'ben': 'BJ', 'civ': 'CI', 'cmr': 'CM', 'cod': 'CD', 'cog': 'CG',
  'dza': 'DZ', 'egy': 'EG', 'eth': 'ET', 'gab': 'GA', 'gha': 'GH', 'gin': 'GN',
  'ken': 'KE', 'mar': 'MA', 'mdg': 'MG', 'mli': 'ML', 'mrt': 'MR', 'mus': 'MU',
  'ner': 'NE', 'nga': 'NG', 'rwa': 'RW', 'sen': 'SN', 'tcd': 'TD', 'tgo': 'TG',
  'tun': 'TN', 'tza': 'TZ', 'uga': 'UG', 'zaf': 'ZA', 'zmb': 'ZM', 'zwe': 'ZW',
  'bdi': 'BI', 'caf': 'CF', 'dji': 'DJ', 'com': 'KM', 'cpv': 'CV', 'gnb': 'GW',
  'gnq': 'GQ', 'lbr': 'LR', 'sle': 'SL', 'gmb': 'GM', 'moz': 'MZ', 'nam': 'NA',
  'bwa': 'BW', 'mwi': 'MW', 'sdn': 'SD', 'lby': 'LY', 'ago': 'AO',
  // Europe
  'aut': 'AT', 'bel': 'BE', 'bgr': 'BG', 'che': 'CH', 'cze': 'CZ', 'deu': 'DE',
  'dnk': 'DK', 'esp': 'ES', 'est': 'EE', 'fin': 'FI', 'fra': 'FR', 'gbr': 'GB',
  'grc': 'GR', 'hrv': 'HR', 'hun': 'HU', 'irl': 'IE', 'isl': 'IS', 'ita': 'IT',
  'ltu': 'LT', 'lux': 'LU', 'lva': 'LV', 'mlt': 'MT', 'nld': 'NL', 'nor': 'NO',
  'pol': 'PL', 'prt': 'PT', 'rou': 'RO', 'rus': 'RU', 'srb': 'RS', 'svk': 'SK',
  'svn': 'SI', 'swe': 'SE', 'ukr': 'UA', 'cyp': 'CY', 'mco': 'MC',
  // Amériques
  'arg': 'AR', 'bra': 'BR', 'can': 'CA', 'chl': 'CL', 'col': 'CO', 'cub': 'CU',
  'hti': 'HT', 'mex': 'MX', 'per': 'PE', 'usa': 'US',
  // Asie, Moyen-Orient, Océanie
  'are': 'AE', 'aus': 'AU', 'aze': 'AZ', 'brn': 'BN', 'chn': 'CN', 'hkg': 'HK',
  'idn': 'ID', 'ind': 'IN', 'irn': 'IR', 'isr': 'IL', 'jor': 'JO', 'jpn': 'JP',
  'kaz': 'KZ', 'kor': 'KR', 'kwt': 'KW', 'lbn': 'LB', 'mys': 'MY', 'nzl': 'NZ',
  'omn': 'OM', 'pak': 'PK', 'phl': 'PH', 'qat': 'QA', 'sau': 'SA', 'sgp': 'SG',
  'tha': 'TH', 'tur': 'TR', 'twn': 'TW', 'uzb': 'UZ', 'vnm': 'VN', 'bgd': 'BD',
  'lka': 'LK', 'npl': 'NP', 'kgz': 'KG', 'geo': 'GE', 'arm': 'AM', 'bhr': 'BH',
};

/// Noms en toutes lettres encore servis par des fiches anciennes (`japan`,
/// `niger`…), en plus des alias historiques de [normalizeCountryId].
const _legacyCountryNameToIso3 = <String, String>{
  'japan': 'jpn',
  'japon': 'jpn',
  'niger': 'ner',
  'senegal': 'sen',
  'sénégal': 'sen',
  'switzerland': 'che',
  'suisse': 'che',
  'netherlands': 'nld',
  'sweden': 'swe',
  'australia': 'aus',
  'south korea': 'kor',
  'korea': 'kor',
  'italy': 'ita',
  'belgium': 'bel',
  'portugal': 'prt',
  'tunisia': 'tun',
  'egypt': 'egy',
  'ghana': 'gha',
  'rwanda': 'rwa',
  'kenya': 'ken',
  'south africa': 'zaf',
  'hungary': 'hun',
  'russia': 'rus',
  'romania': 'rou',
  'qatar': 'qat',
  'taiwan': 'twn',
  'ireland': 'irl',
  'new zealand': 'nzl',
  'india': 'ind',
  'brazil': 'bra',
  'mexico': 'mex',
};

/// Le drapeau d'un code ISO alpha-2 (`FR` → 🇫🇷), ou null s'il n'en est pas un.
String? _flagFromIso2(String code) {
  final upper = code.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(upper)) return null;
  const base = 0x1F1E6; // 🇦
  return String.fromCharCodes(
    upper.codeUnits.map((unit) => base + unit - 0x41),
  );
}

/// Le drapeau d'un pays à partir de son identifiant : alpha-3 du serveur
/// (`fra`, `zaf`), alpha-2 (`fr`, `gb`), ou nom historique (`france`, `japan`).
/// Repli : [fallbackEmoji] (🌍), jamais un drapeau deviné.
String countryFlag(String id, {String fallbackEmoji = '🌍'}) {
  final known = countryFlagById[id] ?? countryFlagById[normalizeCountryId(id)];
  if (known != null) return known;
  final key = normalizeCountryId(id);
  final iso3 = _legacyCountryNameToIso3[key] ?? key;
  // Un alpha-2 n'est accepté que s'il est CONNU : deux lettres quelconques
  // donneraient une paire d'indicateurs régionaux sans drapeau.
  final iso2 = _iso3ToIso2[iso3] ??
      (_knownIso2.contains(iso3.toUpperCase()) ? iso3 : null);
  return (iso2 == null ? null : _flagFromIso2(iso2)) ?? fallbackEmoji;
}

final Set<String> _knownIso2 = _iso3ToIso2.values.toSet();

String displayCountryFlag({required String id, String flagEmoji = ''}) =>
    flagEmoji.isNotEmpty ? flagEmoji : countryFlag(id);
