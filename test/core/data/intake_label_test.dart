// La campagne de rentrée — calculée, jamais figée dans le binaire.
//
// « Rentrée septembre 2026 » vivait en dur dans quatre clés de traduction
// (huit chaînes avec l'anglais), rendues sur l'en-tête France et la fiche pays.
// La build 49 doit vivre environ quatre-vingt-dix jours : le 1er octobre 2026,
// chacune devenait un mensonge — l'app aurait proposé un accompagnement vers
// une rentrée déjà passée, et AUCUNE mise à jour de contenu ne pouvait la
// corriger, puisque le texte vit dans le binaire.
//
// Le point structurant : l'horloge d'IntakeCalendar est INJECTABLE. Un
// `DateTime.now()` en dur aurait rendu l'expiration invérifiable — aucun test
// ne peut attendre le 1er octobre — et c'est précisément l'erreur qu'un spec de
// ce projet a déjà faite une fois.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/data/intake_calendar.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

void main() {
  setUp(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
    Get.fallbackLocale = const Locale('fr');
  });
  tearDown(() {
    IntakeCalendar.clock = DateTime.now;
    Get.reset();
  });

  group('l\'horloge décide de la campagne', () {
    test('au 13/08/2026 — la vérité d\'aujourd\'hui est préservée', () {
      IntakeCalendar.clock = () => DateTime(2026, 8, 13);

      expect(IntakeCalendar.intakeYear(), 2026);
      expect(
        'france_sept_intake'.trParams({'intake': IntakeCalendar.label()}),
        'Rentrée septembre 2026',
      );
    });

    test('pendant septembre, la rentrée en cours reste la campagne courante',
        () {
      IntakeCalendar.clock = () => DateTime(2026, 9, 15);
      expect(IntakeCalendar.intakeYear(), 2026);
    });

    test('au 01/10/2026 — la campagne SUIVANTE prend le relais', () {
      IntakeCalendar.clock = () => DateTime(2026, 10, 1);

      expect(IntakeCalendar.intakeYear(), 2027);
      final fr =
          'france_sept_intake'.trParams({'intake': IntakeCalendar.label()});
      // L'assertion qui échouait avant correctif : le binaire disait encore
      // « septembre 2026 » alors que cette rentrée était passée.
      expect(fr.toLowerCase(), isNot(contains('septembre 2026')));
      expect(fr, 'Rentrée septembre 2027');

      Get.locale = const Locale('en');
      final en =
          'france_sept_intake'.trParams({'intake': IntakeCalendar.label()});
      expect(en, isNot(contains('September 2026')));
      expect(en, 'September 2027 intake');
    });

    test('les positions de titre reçoivent la majuscule, l\'anglais toujours',
        () {
      IntakeCalendar.clock = () => DateTime(2026, 8, 13);

      expect(IntakeCalendar.label(capitalized: true), 'Septembre 2026');
      expect(IntakeCalendar.label(), 'septembre 2026');

      Get.locale = const Locale('en');
      expect(IntakeCalendar.label(), 'September 2026');
      expect(IntakeCalendar.label(capitalized: true), 'September 2026');
    });
  });

  group('le littéral ne peut pas revenir', () {
    test('aucune VALEUR de app_translations.dart ne fige un mois de rentrée',
        () {
      // On lit le FICHIER et non la table en mémoire : la table résoudrait les
      // @intake déjà remplacés, alors que le défaut est précisément un littéral
      // écrit dans la source. La regex attrape « septembre 2026 » mais aussi
      // « September 2027 » ajouté demain par une nouvelle clé.
      final source = [
        'lib/app/core/translations/app_translations_fr.dart',
        'lib/app/core/translations/app_translations_en.dart',
      ]
          .expand((path) => File(path).readAsLinesSync())
          .where((line) => !line.trimLeft().startsWith('//'))
          // Les dates de MISE À JOUR des textes légaux (`last_updated_*`) sont
          // des dates fixes par nature — « Dernière mise à jour : septembre
          // 2026 » dit quand le texte a changé, pas quand commence une rentrée.
          // Ce garde existe pour les mois de RENTRÉE ; l'exempter ici, par la
          // clé, évite de forcer ces dates à passer par `IntakeCalendar`.
          .join('\n')
          // Le formateur peut couper la valeur sur la ligne suivante : on retire
          // donc l'ENTRÉE entière, clé et valeur, et pas la seule ligne de la clé.
          .replaceAll(RegExp(r"'last_updated_\w+':\s*'[^']*'"), '');

      // Pas de `(?i)` inline : le moteur de RegExp de Dart ne le connaît pas
      // et lève `FormatException: Invalid group` — mesuré ici même.
      final matches = RegExp(
        r'(septembre|september)\s+20\d\d',
        caseSensitive: false,
      ).allMatches(source).map((match) => match.group(0)!).toList();

      expect(
        matches,
        isEmpty,
        reason: 'Un mois de rentrée est écrit en dur dans une traduction. Il '
            'vivra dans le binaire pendant toute la durée de vie de la build '
            'et deviendra faux tout seul : passez par IntakeCalendar.label() '
            'et un paramètre @intake.\nTrouvé : ${matches.join(', ')}',
      );
    });

    test('les quatre clés paramétrées existent dans les deux langues', () {
      final keys = AppTranslations().keys;
      for (final key in const [
        'france_case_context_label',
        'france_sept_intake',
        'france_public_unis_soon',
        'dedicated_path_intake',
      ]) {
        for (final locale in const ['fr', 'en']) {
          expect(keys[locale]![key], isNotNull,
              reason: '$key manque en $locale');
          expect(keys[locale]![key], contains('@intake'),
              reason: '$key en $locale a perdu son paramètre @intake — le '
                  'libellé redeviendrait une chaîne figée.');
        }
      }
    });
  });
}
