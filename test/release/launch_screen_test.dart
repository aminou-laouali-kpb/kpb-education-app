// L'écran de lancement — la première chose que l'utilisateur voit, avant même
// le moteur Flutter. Jusqu'à la build 56, c'était le gabarit Flutter brut : un
// fond blanc sans logo en mode jour, et un fond NOIR en mode sombre
// (`values-night` héritait de `Theme.Black`) suivi d'un premier écran blanc —
// un flash noir → blanc à chaque démarrage, sur une app en thème clair seul.
// Android 12+ n'avait aucun réglage : le système prenait ses couleurs par
// défaut.
//
// Ce test affirme les fichiers SOURCE (pas de build Gradle ici, il échoue sans
// android/key.properties). Comme pour le manifeste, tout passe par
// `_withoutComments` : les commentaires citent « Theme.Black » pour expliquer
// pourquoi il est parti, et une assertion sur le texte brut se ferait leurrer.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// Le blanc de `KpbColors.surface` (lib/app/core/ui/app_tokens.dart) — aussi le
/// fond de assets/icon/icon.png et des LaunchImage iOS.
const _brandLaunchColor = '#FFFFFF';

String _withoutComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

String _read(String path) => _withoutComments(File(path).readAsStringSync());

/// Le corps du `<style name="…">` donné.
String _style(String xml, String name) {
  final match = RegExp('<style name="$name"[^>]*>.*?</style>', dotAll: true)
      .firstMatch(xml);
  expect(match, isNotNull, reason: 'style $name introuvable');
  return match!.group(0)!;
}

const _styleFiles = [
  '$_res/values/styles.xml',
  '$_res/values-night/styles.xml',
  '$_res/values-v31/styles.xml',
  '$_res/values-night-v31/styles.xml',
];

void main() {
  group('Android', () {
    test('la couleur de lancement est le blanc de marque', () {
      final colors = _read('$_res/values/colors.xml');
      final match = RegExp(
              r'<color name="kpb_launch_background">\s*(#[0-9A-Fa-f]{6,8})\s*</color>')
          .firstMatch(colors);
      expect(match, isNotNull);
      expect(match!.group(1)!.toUpperCase(), _brandLaunchColor);
    });

    test('aucun thème sombre (Theme.Black) ni clair/sombre divergent', () {
      for (final path in _styleFiles) {
        expect(File(path).existsSync(), isTrue, reason: '$path absent');
        final xml = _read(path);
        expect(xml, isNot(contains('Theme.Black')), reason: path);
        expect(xml, isNot(contains('Theme.Dark')), reason: path);
        for (final name in ['LaunchTheme', 'NormalTheme']) {
          final style = _style(xml, name);
          expect(style, contains('parent="@android:style/Theme.Light'),
              reason: '$path : $name doit hériter d\'un thème clair');
        }
        expect(
          _style(xml, 'NormalTheme'),
          contains('@color/kpb_launch_background'),
          reason: '$path : la fenêtre derrière Flutter doit être du blanc de '
              'marque, pas ?android:colorBackground',
        );
      }
    });

    test('Android 11 et moins : le logo KPB centré sur le fond de marque', () {
      for (final dir in ['drawable', 'drawable-v21']) {
        final xml = _read('$_res/$dir/launch_background.xml');
        expect(xml, contains('@color/kpb_launch_background'), reason: dir);
        expect(xml, contains('@drawable/launch_image'), reason: dir);
      }
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi']) {
        expect(
          File('$_res/drawable-$density/launch_image.png').existsSync(),
          isTrue,
          reason: 'launch_image.png absent en $density',
        );
      }
      for (final path in _styleFiles) {
        expect(_style(_read(path), 'LaunchTheme'),
            contains('@drawable/launch_background'),
            reason: path);
      }
    });

    test('Android 12+ : values-v31 ET values-night-v31 posent fond et icône',
        () {
      // values-night-v31 n'est pas un doublon décoratif : le qualificatif
      // « night » prime sur la version d'API, donc sans lui un téléphone
      // Android 12+ en mode sombre lirait values-night, sans ces attributs.
      for (final path in [
        '$_res/values-v31/styles.xml',
        '$_res/values-night-v31/styles.xml',
      ]) {
        final launch = _style(_read(path), 'LaunchTheme');
        expect(
          launch,
          contains('<item name="android:windowSplashScreenBackground">'
              '@color/kpb_launch_background</item>'),
          reason: path,
        );
        expect(
          launch,
          contains('<item name="android:windowSplashScreenAnimatedIcon">'
              '@drawable/splash_icon</item>'),
          reason: path,
        );
      }
      final icon = _read('$_res/drawable-v31/splash_icon.xml');
      expect(icon, contains('@drawable/launch_image'));
      expect(icon, contains('android:inset='),
          reason: 'sans rentrée, le cercle d\'Android 12 rogne le logo');
    });

    test('le manifeste lance bien LaunchTheme puis NormalTheme', () {
      final manifest = _withoutComments(
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync());
      expect(manifest, contains('android:theme="@style/LaunchTheme"'));
      expect(manifest, contains('android:resource="@style/NormalTheme"'));
    });
  });

  group('iOS', () {
    test('LaunchScreen.storyboard : fond blanc et logo KPB', () {
      // Les LaunchImage iOS sont des PNG RVB sans transparence, au fond blanc
      // incrusté : un autre fond de vue ferait apparaître un carré blanc
      // autour du logo. Le blanc est donc la couleur de marque ici aussi.
      final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
          .readAsStringSync();
      expect(
        storyboard,
        contains('<color key="backgroundColor" red="1" green="1" blue="1" '
            'alpha="1"'),
      );
      expect(storyboard, contains('image="LaunchImage"'));
      for (final name in [
        'LaunchImage.png',
        'LaunchImage@2x.png',
        'LaunchImage@3x.png',
      ]) {
        expect(
          File('ios/Runner/Assets.xcassets/LaunchImage.imageset/$name')
              .existsSync(),
          isTrue,
          reason: '$name absent',
        );
      }
    });
  });
}
