/// Plie un texte pour la recherche : minuscules, sans accents, apostrophes et
/// tirets ramenés à leur forme simple, espaces resserrés.
///
/// ## Pourquoi
///
/// Beaucoup d'élèves écrivent sur un clavier sans accents, ou sans prendre la
/// peine de les taper. La recherche comparait les textes tels quels :
/// « senegal » ne trouvait pas « Sénégal », « ingenierie » ne trouvait pas
/// « Ingénierie », « cote d'ivoire » ne trouvait pas « Côte d’Ivoire »
/// (apostrophe typographique) — et l'écran disait « aucun résultat » (audit
/// avant la 59).
///
/// La requête ET le texte cherché passent par ici : ce qui compte, c'est que
/// les deux côtés soient pliés de la même façon.
String foldForSearch(String input) {
  if (input.isEmpty) return input;
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString().replaceAll(_spaces, ' ').trim();
}

final RegExp _spaces = RegExp(r'\s+');

const Map<String, String> _folds = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ç': 'c', 'ñ': 'n',
  'œ': 'oe', 'æ': 'ae',
  // Apostrophes typographiques → apostrophe droite.
  '’': "'", '‘': "'", 'ʼ': "'", '`': "'",
  // Tirets longs et insécable → tiret simple.
  '–': '-', '—': '-', '‑': '-',
  // Espace insécable → espace.
  ' ': ' ', ' ': ' ',
};
