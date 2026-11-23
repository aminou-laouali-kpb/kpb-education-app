import '../utils/search_text.dart';

part 'world_countries_table.dart';

/// Un pays, son indicatif téléphonique et ses deux noms.
///
/// ## Pourquoi cette table existe
///
/// L'inscription proposait 34 pays et 37 indicatifs écrits à la main. Un élève
/// du Kenya, d'Égypte, d'Haïti ou du Liban ne trouvait ni son pays ni son
/// indicatif — et c'était la première chose que l'app lui demandait. La table
/// porte maintenant tous les pays habités de la norme ISO 3166-1, générée
/// depuis les mêmes noms que le serveur et depuis les indicatifs de
/// libphonenumber (`scripts/generate-world-countries.js`).
///
/// Deux absences sont VOULUES (décision du propriétaire, 17/11/2026) : le
/// Sahara occidental, écarté par le générateur, et le Kosovo, hors norme et
/// jamais ajouté. Un test les garde hors de la liste.
class WorldCountry {
  const WorldCountry(
    this.iso2,
    this.nameFr,
    this.nameEn,
    this.dialCode, {
    this.minDigits = defaultMinDigits,
    this.maxDigits = defaultMaxDigits,
  });

  /// Bornes du nombre de chiffres d'un numéro, sans l'indicatif, quand le
  /// pays n'en demande pas d'autres.
  static const int defaultMinDigits = 7;
  static const int defaultMaxDigits = 12;

  /// Code ISO 3166-1 alpha-2, en majuscules.
  final String iso2;

  /// Le nom français. C'est LA valeur enregistrée dans
  /// `UserProfile.countryOfResidence` : le serveur la résout
  /// (`backend/src/common/iso-countries.ts`), quelle que soit la langue de
  /// l'app.
  final String nameFr;

  /// Le nom anglais : affichage seulement, jamais enregistré.
  final String nameEn;

  /// L'indicatif, « + » et chiffres, rien d'autre : il est concaténé tel quel
  /// dans `profile.phone` et `profile.whatsApp`.
  final String dialCode;

  /// Nombre de chiffres accepté pour un numéro de ce pays (sans l'indicatif).
  final int minDigits, maxDigits;

  /// Le drapeau, calculé depuis le code ISO (deux « indicateurs régionaux »).
  String get flag => String.fromCharCodes(
        iso2.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41),
      );

  /// Le nom à AFFICHER dans la langue de l'app.
  String nameFor(String? languageCode) =>
      languageCode == 'en' ? nameEn : nameFr;
}

/// Tous les pays, triés par nom français.
const List<WorldCountry> worldCountries = _worldCountriesTable;

/// En tête des listes, dans cet ordre : le public de l'app (Afrique de
/// l'Ouest, centrale, de l'Est et du Nord), puis la France, la Belgique, la
/// Suisse et le Canada. C'est l'ordre de l'ancienne liste d'inscription : le
/// Niger reste premier, donc l'indicatif par défaut ne change pas.
const List<String> priorityCountryIso2 = <String>[
  'NE', 'NG', 'SN', 'CI', 'ML', 'GN', 'BF', 'TG', 'BJ', 'MR', 'GH', 'CM', //
  'SL', 'GM', 'LR', 'GW', 'CV', 'CD', 'CG', 'GA', 'TD', 'CF', 'MG', 'RW', //
  'BI', 'DJ', 'KM', 'MA', 'TN', 'DZ', 'FR', 'BE', 'CH', 'CA',
];

final Map<String, WorldCountry> _byIso2 = <String, WorldCountry>{
  for (final country in worldCountries) country.iso2: country,
};

final Map<String, WorldCountry> _byName = <String, WorldCountry>{
  for (final country in worldCountries) ...<String, WorldCountry>{
    foldForSearch(country.nameEn): country,
    // Le nom français en dernier : à forme égale, c'est lui qui fait foi.
    foldForSearch(country.nameFr): country,
  },
};

/// Le pays d'un code ISO alpha-2 (« NE »), ou `null`.
WorldCountry? worldCountryByIso2(String? iso2) =>
    iso2 == null ? null : _byIso2[iso2.toUpperCase()];

/// Le pays d'un nom enregistré ou tapé (« Niger », « niger », « Senegal »),
/// ou `null`. « Autre », vide ou inconnu → `null` : on ne devine jamais.
WorldCountry? worldCountryByName(String? name) {
  if (name == null) return null;
  final folded = foldForSearch(name);
  return folded.isEmpty ? null : _byName[folded];
}

/// Les pays dans l'ordre des listes : [priorityCountryIso2] d'abord, puis
/// tous les autres par ordre alphabétique du nom affiché.
List<WorldCountry> worldCountriesInListOrder(String? languageCode) {
  final priority = <WorldCountry>[
    for (final iso2 in priorityCountryIso2) _byIso2[iso2]!,
  ];
  final first = priorityCountryIso2.toSet();
  final rest = worldCountries.where((c) => !first.contains(c.iso2)).toList()
    ..sort((a, b) => foldForSearch(a.nameFor(languageCode))
        .compareTo(foldForSearch(b.nameFor(languageCode))));
  return <WorldCountry>[...priority, ...rest];
}

/// Les pays qui répondent à une recherche : par nom (français ou anglais,
/// sans accents : « cote » trouve « Côte d'Ivoire »), par indicatif (« 254 »
/// ou « +254 ») ou par code ISO (« ke »). Requête vide : toute la liste.
List<WorldCountry> filterWorldCountries(
  List<WorldCountry> countries,
  String query,
) {
  final needle = foldForSearch(query);
  if (needle.isEmpty) return countries;
  final digits = needle.replaceAll(RegExp(r'[^0-9]'), '');
  final byDialCode =
      digits.isNotEmpty && digits.length == needle.replaceAll('+', '').length;
  return countries.where((country) {
    if (byDialCode) return country.dialCode.substring(1).startsWith(digits);
    return foldForSearch(country.nameFr).contains(needle) ||
        foldForSearch(country.nameEn).contains(needle) ||
        country.iso2.toLowerCase() == needle;
  }).toList(growable: false);
}
