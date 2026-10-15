// Chantier H2 — libellés honnêtes : jamais de « % » de compatibilité, jamais
// de « chance(s) » dans un texte KPB.
//
// ## Ce que ce fichier interdit, et pourquoi sur la MAP compilée
//
// Les défauts corrigés vivaient sous une suite verte : « Très bon match » issu
// d'un `baseMatch` à 78 sur l'accueil, « Réponds à 12 questions » sur le
// premier écran (l'onboarding en compte 3), « En 1 minute, découvre tes
// chances », et une clé morte qui annonçait « le seuil de sécurité est de
// 85 % ». `translations_parity_test.dart` vérifie que FR et EN ont les mêmes
// clés, pas que leurs valeurs disent la vérité.
//
// On lit `AppTranslations().keys` — jamais le source — parce que le source
// porte des commentaires qui CITENT les mots interdits pour expliquer les
// défauts : un test sur le texte brut se satisferait de la prose.
//
// ## Les exceptions sont nommées, une par une
//
// Un « % » n'est pas toujours une compatibilité : une progression de profil
// ou une remise tarifaire en sont. Et « chances » peut figurer dans une
// phrase qui dit justement qu'on NE LES CALCULE PAS. Chaque exception est une
// clé précise avec sa raison ; une exception devenue inutile fait rougir le
// tiroir, pour qu'elle ne survive pas à son texte.
//
// Citations officielles : les conditions officielles des bourses (« 70 % »
// pour Türkiye, par exemple) arrivent du SERVEUR (`officialText`), jamais des
// traductions. Aucune clé n'en porte aujourd'hui ; si l'une devait en porter
// une, elle se déclare ici, dans [_officialQuoteKeys], et nulle part ailleurs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/translations/app_translations.dart';

/// Clés où un « % » n'est PAS une compatibilité ni une probabilité.
const _percentAllowed = <String, String>{
  'home_profile_pct_notice': 'progression du remplissage du profil',
  'kpb_offer_partner_discount': 'remise tarifaire (−30 %)',
};

/// Clés où « chance(s) » / « odds » figure dans une NÉGATION explicite.
const _chanceAllowed = <String, String>{
  'success_lab_progress_disclaimer': 'dit que la progression n\'est PAS '
      'une chance d\'admission',
  'success_lab_diagnostic_disclaimer': 'dit que le diagnostic ne calcule PAS '
      'de chances',
};

/// Citations OFFICIELLES (texte d'un organisme, cité tel quel), exemptées des
/// deux règles. Vide : ces citations viennent du serveur.
const _officialQuoteKeys = <String>{};

final _chanceWord = RegExp(
  r'\b(?:chances?|odds|likelihood|probabilit[ée]s?)\b',
  caseSensitive: false,
);

String _codeWithoutComments(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final keys = AppTranslations().keys;

  group('traductions KPB : ni « % » de compatibilité ni « chances »', () {
    test('tiroir : les deux langues sont bien lues', () {
      expect(keys['fr'], isNotNull);
      expect(keys['en'], isNotNull);
      expect(keys['fr']!.length, greaterThan(1000));
      expect(keys['en']!.length, greaterThan(1000));
    });

    for (final lang in const ['fr', 'en']) {
      test('$lang : aucun « % » hors exceptions nommées', () {
        final offenders = <String>[];
        keys[lang]!.forEach((key, value) {
          if (_officialQuoteKeys.contains(key)) return;
          if (_percentAllowed.containsKey(key)) return;
          if (value.contains('%')) offenders.add('$key: $value');
        });
        expect(offenders, isEmpty,
            reason: 'Un « % » dans un libellé KPB se lit comme une '
                'compatibilité ou une probabilité. Reformule, ou déclare '
                'l\'exception dans _percentAllowed avec sa raison.');
      });

      test('$lang : aucune « chance(s) » hors négations nommées', () {
        final offenders = <String>[];
        keys[lang]!.forEach((key, value) {
          if (_officialQuoteKeys.contains(key)) return;
          if (_chanceAllowed.containsKey(key)) return;
          if (_chanceWord.hasMatch(value)) offenders.add('$key: $value');
        });
        expect(offenders, isEmpty,
            reason: 'KPB ne calcule pas de chances : aucun libellé ne doit '
                'en promettre.');
      });
    }

    test('chaque exception existe encore et porte encore son motif', () {
      for (final lang in const ['fr', 'en']) {
        for (final key in _percentAllowed.keys) {
          expect(keys[lang]![key], isNotNull, reason: '$lang/$key a disparu');
          expect(keys[lang]![key], contains('%'),
              reason: '$lang/$key ne porte plus de « % » : retire '
                  'l\'exception');
        }
        for (final key in _chanceAllowed.keys) {
          final value = keys[lang]![key];
          expect(value, isNotNull, reason: '$lang/$key a disparu');
          expect(_chanceWord.hasMatch(value!), isTrue,
              reason: '$lang/$key ne parle plus de chances : retire '
                  'l\'exception');
        }
      }
    });

    test('la règle sait rougir (auto-test du motif)', () {
      expect(_chanceWord.hasMatch('En 1 minute, découvre tes chances'), isTrue);
      expect(_chanceWord.hasMatch('discover your chances'), isTrue);
      expect(_chanceWord.hasMatch('Chancellerie'), isFalse);
    });
  });

  group('copies couplées au code qui les tient', () {
    test('« N étapes » sur le premier écran = pages de l\'onboarding étudiant',
        () {
      final source = _codeWithoutComments(
          'lib/app/features/onboarding/onboarding_screen.dart');
      final match = RegExp(
        r'int get _totalPages\s*=>\s*_accountType == AccountType\.partner'
        r'\s*\?\s*\d+\s*:\s*(\d+);',
      ).firstMatch(source);
      expect(match, isNotNull,
          reason: 'tiroir : le nombre de pages n\'est plus lisible ici');
      final studentPages = match!.group(1)!;
      expect(keys['fr']!['auth_intelligence_body'],
          contains('$studentPages étapes'));
      expect(keys['en']!['auth_intelligence_body'],
          contains('$studentPages steps'));
    });

    test('aucune bourse ne reçoit plus de palier de compatibilité client', () {
      // `scholarshipFit` et `_matchScholarship` sont supprimés : ils partaient
      // du `baseMatch` éditorial et ne lisaient aucune condition.
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty, reason: 'tiroir : lib/ introuvable');
      final offenders = <String>[];
      for (final file in files) {
        final code = _codeWithoutComments(file.path);
        if (RegExp(r'\bscholarshipFit\b|_matchScholarship\b').hasMatch(code)) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
