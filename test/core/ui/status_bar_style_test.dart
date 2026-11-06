// Barre d'état lisible (audit build 57, T6-16). L'AppBarTheme du thème clair
// est transparente : sans `systemOverlayStyle`, l'heure et la batterie
// restaient blanches sur blanc après tout écran à barre de titre standard, et le
// restaient au retour. Le thème clair pose donc des icônes SOMBRES ; chaque
// barre à fond sombre pose des icônes CLAIRES elle-même, sinon elles deviennent
// noires sur fond nuit.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/app_theme.dart';

void main() {
  test('thème clair : icônes de barre d\'état sombres', () {
    expect(AppTheme.buildTheme().appBarTheme.systemOverlayStyle,
        SystemUiOverlayStyle.dark);
  });

  test('thème sombre : icônes claires (inchangé)', () {
    final style = AppTheme.buildDarkTheme().appBarTheme.systemOverlayStyle;
    // Soit explicite, soit laissé au calcul du thème sombre : jamais « dark ».
    expect(style == null || style == SystemUiOverlayStyle.light, isTrue);
  });

  // Les six barres à fond sombre : chacune doit nommer son propre style, sinon
  // elle hérite du style sombre du thème clair.
  const darkBars = <String, String>{
    'lib/app/features/orientation/orientation_screen.dart':
        'backgroundColor: KpbColors.navy',
    'lib/app/features/france/france_private_admission_screen.dart':
        'backgroundColor: KpbColors.navy',
    'lib/app/features/parcours/parcours_feed_screen.dart': 'appBar: AppBar(',
    'lib/app/features/parcours/parcours_screen.dart':
        'backgroundColor: Colors.black',
    'lib/app/features/scholarships/scholarship_video_player_screen.dart':
        'backgroundColor: Colors.black',
    'lib/app/features/community/forum_category_screen.dart':
        'backgroundColor: KpbColors.brandNavy',
  };

  darkBars.forEach((path, anchor) {
    test('barre sombre avec icônes claires : $path', () {
      final source = File(path).readAsStringSync();
      final at = source.indexOf(anchor);
      // Tiroir : l'ancre existe, sinon le test ne prouverait rien.
      expect(at, greaterThanOrEqualTo(0), reason: 'ancre introuvable');
      final window = source.substring(at, (at + 400).clamp(0, source.length));
      expect(window, contains('SystemUiOverlayStyle.light'));
    });
  });
}
