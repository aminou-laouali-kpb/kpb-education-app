// Budget des ACTIFS EMBARQUÉS — ce que le bloc `flutter:` de pubspec.yaml met
// dans chaque APK/IPA.
//
// POURQUOI CE TEST EXISTE. Jusqu'à la build 56, pubspec déclarait neuf dossiers
// d'actifs, dont `assets/services/` (4,2 Mo de visuels de l'ancienne app
// Karatou), `assets/gifs/`, `assets/svgs/`, `assets/images/bg_imgs/` et
// `assets/images/on_boarding_img/`. AUCUN de ces fichiers n'était lu : pas un
// `Image.asset`, pas un `AssetImage`, pas un chemin construit, ni dans lib/, ni
// dans le natif, ni dans une fiche store. Avec `assets/icon/icon.png` (lu
// seulement par flutter_launcher_icons) et trois logos en double, 5 391 749
// octets partaient dans le binaire pour rien — sur un public qui télécharge
// souvent avec des forfaits de données comptés.
//
// Un dossier déclaré embarque TOUT ce qu'on y dépose, sans que personne le
// voie. D'où trois gardes :
//   1. chaque entrée déclarée existe (une entrée orpheline casse `flutter build`
//      seulement au moment du build de release, trop tard) ;
//   2. chaque fichier embarqué est référencé par son chemin dans lib/, ou figure
//      dans [kEmbeddedWithoutLibReference] avec sa raison ;
//   3. le total embarqué (actifs + polices) reste sous [kEmbeddedAssetCeiling].
// Et une quatrième, pour que le disque ne redevienne pas une décharge : tout
// fichier de assets/ hors bundle figure dans [kOnDiskOnly] avec sa raison.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/lib_scan.dart';

/// Fichiers embarqués que lib/ ne nomme pas en toutes lettres. Chacun porte sa
/// raison. Vide aujourd'hui : le seul actif embarqué (le logo complet) est lu
/// par `auth_welcome_screen.dart`.
const kEmbeddedWithoutLibReference = <String, String>{};

/// Fichiers présents sous assets/ mais volontairement HORS du bundle.
const kOnDiskOnly = <String, String>{
  'assets/icon/icon.png': 'source de flutter_launcher_icons (pubspec.yaml et '
      'flutter_launcher_icons.yaml) — jamais lue par l\'app',
  'assets/fonts/README.md': 'licence SIL OFL 1.1 des polices embarquées',
};

/// Plafond du total embarqué, en octets.
///
/// MESURÉ le 16/10/2026 : 899 999 octets (logo 31 687 + 8 polices 868 312).
/// Plafond posé à 1,2 Mo : de quoi ajouter une illustration raisonnable, pas
/// de quoi réembarquer un dossier de photos sans que la CI le dise.
const kEmbeddedAssetCeiling = 1200000;

/// Les entrées de `flutter: assets:` de pubspec.yaml, dans l'ordre.
List<String> declaredAssetEntries(String pubspec) {
  final lines = pubspec.split('\n');
  final out = <String>[];
  var inFlutter = false;
  var inAssets = false;
  for (final line in lines) {
    if (RegExp(r'^\S').hasMatch(line)) {
      inFlutter = line.startsWith('flutter:');
      inAssets = false;
      continue;
    }
    if (!inFlutter) continue;
    if (RegExp(r'^  assets:\s*$').hasMatch(line)) {
      inAssets = true;
      continue;
    }
    if (inAssets) {
      final entry = RegExp(r'^    - (\S+)\s*$').firstMatch(line);
      if (entry != null) {
        out.add(entry.group(1)!.replaceAll('"', ''));
      } else if (RegExp(r'^  \S').hasMatch(line)) {
        inAssets = false;
      }
    }
  }
  return out;
}

/// Les fichiers de police (`- asset: …`) du bloc `flutter: fonts:`.
List<String> declaredFontFiles(String pubspec) => RegExp(
      r'^\s+- asset: (\S+)\s*$',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)!).toList();

/// Ce que Flutter embarque pour une entrée : un fichier, ou les fichiers
/// DIRECTEMENT contenus par un dossier (Flutter ne descend pas récursivement).
List<String> embeddedFilesFor(String entry) {
  if (!entry.endsWith('/')) return [entry];
  return Directory(entry)
      .listSync()
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/'))
      .toList()
    ..sort();
}

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final entries = declaredAssetEntries(pubspec);
  final fonts = declaredFontFiles(pubspec);

  group('le parseur lui-même', () {
    test('trouve les entrées d\'actifs et les polices', () {
      // Anti-vert-silencieux : un parseur qui ne trouve rien rendrait tous
      // les tests ci-dessous verts et muets.
      expect(entries, isNotEmpty);
      expect(entries, contains('assets/images/logo/'));
      expect(fonts, hasLength(8));
      expect(
        declaredAssetEntries('flutter:\n  assets:\n    - a/\n    - b.png\n'
            '  fonts:\n    - family: X\n'),
        ['a/', 'b.png'],
      );
    });
  });

  test('chaque entrée déclarée existe sur le disque', () {
    final missing = [
      for (final e in entries)
        if (e.endsWith('/')
            ? !Directory(e).existsSync()
            : !File(e).existsSync())
          e,
      for (final f in fonts)
        if (!File(f).existsSync()) f,
    ];
    expect(missing, isEmpty,
        reason: 'Entrées de pubspec.yaml sans fichier : $missing');
  });

  test('aucun dossier déclaré n\'est vide', () {
    // Un dossier vide déclaré ne coûte rien aujourd'hui, mais c'est
    // l'invitation à y déposer un fichier qui partira dans le binaire sans
    // qu'aucune ligne de code ne le lise (le cas de `assets/svgs/`).
    final empty = [
      for (final e in entries)
        if (e.endsWith('/') && embeddedFilesFor(e).isEmpty) e,
    ];
    expect(empty, isEmpty);
  });

  test('chaque fichier embarqué est référencé dans lib/', () {
    final libSource = [
      for (final path in libDartFiles()) ...codeLines(path),
    ].join('\n');

    final unreferenced = <String>[];
    for (final entry in entries) {
      for (final file in embeddedFilesFor(entry)) {
        if (kEmbeddedWithoutLibReference.containsKey(file)) continue;
        if (!libSource.contains(file)) unreferenced.add(file);
      }
    }
    expect(
      unreferenced,
      isEmpty,
      reason: 'Ces fichiers partent dans chaque APK/IPA sans qu\'aucune ligne '
          'de lib/ ne les nomme : $unreferenced. Retirez-les (ou leur '
          'dossier) du bloc `flutter: assets:`, ou inscrivez-les dans '
          'kEmbeddedWithoutLibReference avec leur raison.',
    );
  });

  test('la liste blanche ne survit pas à son motif', () {
    final embedded = {for (final e in entries) ...embeddedFilesFor(e)};
    final fossils = kEmbeddedWithoutLibReference.keys
        .where((f) => !embedded.contains(f))
        .toList();
    expect(fossils, isEmpty,
        reason: 'Exceptions qui ne sont plus embarquées : $fossils');
  });

  test('tout fichier de assets/ hors bundle a une raison d\'être là', () {
    final embedded = {
      for (final e in entries) ...embeddedFilesFor(e),
      ...fonts,
    };
    final stray = Directory('assets')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll('\\', '/'))
        .where((p) => !embedded.contains(p) && !kOnDiskOnly.containsKey(p))
        .toList()
      ..sort();
    expect(
      stray,
      isEmpty,
      reason: 'Fichiers de assets/ ni embarqués ni justifiés : $stray. '
          'Supprimez-les, ou inscrivez-les dans kOnDiskOnly avec leur raison.',
    );
    for (final path in kOnDiskOnly.keys) {
      expect(File(path).existsSync(), isTrue,
          reason: '$path est justifié dans kOnDiskOnly mais n\'existe plus.');
    }
  });

  test('le total embarqué reste sous le plafond', () {
    final files = {
      for (final e in entries) ...embeddedFilesFor(e),
      ...fonts,
    };
    final total =
        files.fold<int>(0, (sum, path) => sum + File(path).lengthSync());
    // Plancher : si le total s'effondre, c'est le parseur qui a perdu des
    // entrées, pas l'app qui a maigri.
    expect(total, greaterThan(800000),
        reason: 'Total de $total octets : le logo et les polices pèsent à eux '
            'seuls ~900 Ko. Le parseur a probablement perdu des entrées.');
    expect(
      total,
      lessThanOrEqualTo(kEmbeddedAssetCeiling),
      reason: 'Les actifs embarqués pèsent $total octets, au-dessus du '
          'plafond de $kEmbeddedAssetCeiling. Si l\'ajout est voulu, '
          'compressez d\'abord (WebP, dimensions réelles d\'affichage) ; '
          'relevez le plafond seulement ensuite, avec la mesure en commentaire.',
    );
  });
}
