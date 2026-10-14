// Outils partagés des tests « ratchet » qui lisent le code de lib/ (couleurs,
// bandeaux, tailles de police, durées, vibrations).

import 'dart:io';

/// Fichiers dart de lib/ SUIVIS par git : le ratchet mesure le dépôt, pas les
/// brouillons locaux non commités. Repli sur le système de fichiers si git est
/// indisponible.
List<String> libDartFiles() {
  try {
    final result = Process.runSync('git', ['ls-files', '--', 'lib']);
    if (result.exitCode == 0) {
      return (result.stdout as String)
          .split('\n')
          .where((p) => p.endsWith('.dart'))
          .toList();
    }
  } catch (_) {
    // git absent : repli ci-dessous.
  }
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.replaceAll('\\', '/'))
      .toList();
}

/// Lignes de code d'un fichier, sans les lignes de commentaire pur (`//`,
/// `///`, ` * `) : citer un motif interdit dans un commentaire reste permis.
Iterable<String> codeLines(String path) sync* {
  final file = File(path);
  if (!file.existsSync()) return;
  for (final line in file.readAsLinesSync()) {
    final t = line.trimLeft();
    if (t.startsWith('//') || t.startsWith('* ') || t.startsWith('/*')) {
      continue;
    }
    yield line;
  }
}

/// Compte, fichier par fichier, les occurrences de [pattern] dans le code de
/// lib/ (hors lignes portant [allowMarker] et hors fichiers [exempt]).
Map<String, int> countInLib(
  RegExp pattern, {
  String? allowMarker,
  Set<String> exempt = const {},
  bool Function(String path)? include,
}) {
  final counts = <String, int>{};
  for (final rel in libDartFiles()) {
    if (exempt.contains(rel)) continue;
    if (include != null && !include(rel)) continue;
    var count = 0;
    for (final line in codeLines(rel)) {
      if (allowMarker != null && line.contains(allowMarker)) continue;
      count += pattern.allMatches(line).length;
    }
    if (count > 0) counts[rel] = count;
  }
  return counts;
}
