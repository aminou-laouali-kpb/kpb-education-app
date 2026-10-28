// Build 58 — audit UX de la 57, n° 4 et 5a : les TEXTES ne promettent que ce
// que le code tient. Même principe que `translations_build49_truth_test.dart` :
// chaque assertion part du code ou d'un drapeau, et lit la map compilée
// (`AppTranslations().keys`), jamais le source des traductions.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

Map<String, String> _fr() => AppTranslations().keys['fr']!;
Map<String, String> _en() => AppTranslations().keys['en']!;

String _codeWithoutComments(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('(5a) carte « Parler à un conseiller KPB »', () {
    test('aucun profil n\'est joint au message : le texte ne le promet pas',
        () {
      final code = _codeWithoutComments(
          'lib/app/features/home/home_screen/engagement.dart');
      final card = RegExp(
        r'class _CounselorWhatsAppCard[\s\S]*?prefill:\s*([^\n]+)',
      ).firstMatch(code);
      // Tiroir : sans la carte ni son préremplissage, rien à vérifier.
      expect(card, isNotNull, reason: 'carte conseiller introuvable');
      final prefill = card!.group(1)!;
      if (prefill.trim().startsWith('kpbWhatsAppPrefill()')) {
        expect(_fr()['home_counselor_cta_subtitle'], isNot(contains('profil')));
        expect(
            _en()['home_counselor_cta_subtitle'], isNot(contains('profile')));
      }
    });

    test('aucun délai de « ~2 h » sans source dans le code', () {
      for (final key in const [
        'home_counselor_cta_subtitle',
        'parent_advisor_sub',
      ]) {
        expect(_fr()[key], isNotNull, reason: key);
        expect(_fr()[key], isNot(contains('~2')), reason: key);
        expect(_en()[key], isNot(contains('~2')), reason: key);
      }
    });
  });

  group('(4) programme Ambassadeur', () {
    test('programme rémunéré fermé : la candidature ne promet pas de gain', () {
      if (AppConfig.ambassadorCashEnabled) return;
      expect(_fr()['amb_apply_body'], isNotNull);
      expect(_fr()['amb_apply_body'], isNot(contains('rémunéré')));
      expect(_en()['amb_apply_body'], isNot(contains('paid')));
    });
  });
}
