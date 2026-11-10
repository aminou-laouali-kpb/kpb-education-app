// La garde de mise à jour forcée (audit avant la 59).
//
// ## Ce qui n'allait pas
//
// Elle ne tournait qu'une fois, au démarrage à froid, avec son propre appel
// réseau : sautée sur réseau instable, jamais repassée sur un téléphone qui
// garde l'app en mémoire.
//
// ## Ce que ce fichier verrouille
//
// Elle échoue ouverte (une valeur absente ou illisible ne bloque personne),
// elle ouvre l'écran quand il le faut, et rejouée, elle ne l'empile pas.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/navigation/force_update_screen.dart';
import 'package:karatou/app/core/services/app_version_gate.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

void main() {
  group('minVersionOf — échoue ouvert', () {
    test('lit la version minimale servie, sans espaces', () {
      expect(AppVersionGate.minVersionOf({'minVersion': ' 2.3.1 '}), '2.3.1');
    });

    test('charge vide : aucun minimum', () {
      expect(AppVersionGate.minVersionOf(<String, dynamic>{}), isEmpty);
    });

    test('une valeur qui n\'est pas un texte ne vaut aucun minimum', () {
      expect(AppVersionGate.minVersionOf({'minVersion': 3}), isEmpty);
      expect(AppVersionGate.minVersionOf({'minVersion': null}), isEmpty);
    });
  });

  group('evaluate — l\'écran', () {
    setUp(AppVersionGate.resetForTest);

    tearDown(() {
      AppVersionGate.resetForTest();
      Get.reset();
    });

    // `evaluate` ne rend jamais la main quand il ouvre l'écran : il attend la
    // fermeture d'une route qui ne se ferme pas. On le lance donc sans
    // l'attendre, comme `main.dart`.
    Future<void> fire(WidgetTester tester, Map<String, dynamic> config) async {
      await tester.runAsync(() async {
        unawaited(AppVersionGate.evaluate(config));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      // Une image pour monter la route, une seconde pour finir sa transition
      // et retirer l'ancienne pile.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: const Scaffold(body: Text('Accueil')),
      ));
    }

    testWidgets('une build trop ancienne voit l\'écran de mise à jour',
        (tester) async {
      AppVersionGate.installed = () async => (version: '2.3.0');
      await pumpApp(tester);

      await fire(tester, {
        'minVersion': '2.3.1',
        'androidStoreUrl': 'https://play.google.com/store/apps/details?id=x',
        'iosStoreUrl': 'https://apps.apple.com/app/id1',
      });

      expect(find.byType(ForceUpdateScreen), findsOneWidget);
    });

    testWidgets('une build à jour reste sur l\'accueil', (tester) async {
      AppVersionGate.installed = () async => (version: '2.3.1');
      await pumpApp(tester);

      await fire(tester, {'minVersion': '2.3.1'});

      expect(find.byType(ForceUpdateScreen), findsNothing);
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgets('rejouée au retour dans l\'app, elle n\'empile pas l\'écran',
        (tester) async {
      AppVersionGate.installed = () async => (version: '2.3.0');
      await pumpApp(tester);
      final config = <String, dynamic>{'minVersion': '2.3.1'};

      await fire(tester, config);
      await fire(tester, config);

      expect(find.byType(ForceUpdateScreen), findsOneWidget);
    });

    testWidgets('une version installée illisible ne bloque pas',
        (tester) async {
      AppVersionGate.installed = () async => throw StateError('pas de plugin');
      await pumpApp(tester);

      await fire(tester, {'minVersion': '9.9.9'});

      expect(find.byType(ForceUpdateScreen), findsNothing);
    });
  });
}
