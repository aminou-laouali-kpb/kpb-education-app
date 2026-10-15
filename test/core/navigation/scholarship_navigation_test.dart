// Chantier I — les raccourcis « Bourses » de l'app ouvrent la fiche visée, ou
// basculent sur l'onglet Bourses de la coquille ; ils n'empilent plus une
// seconde liste par-dessus.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/navigation/scholarship_navigation.dart';
import 'package:karatou/app/core/navigation/shell_tabs.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';

import '../../widget_test_helpers.dart';

Future<AppController> _seed({
  AccountType accountType = AccountType.student,
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(accountType: accountType),
      ),
    ),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

Widget _app() => GetMaterialApp(
      home: const Scaffold(body: Text('shell')),
      getPages: [
        GetPage(
          name: '/scholarships',
          page: () => const Scaffold(body: Text('second list')),
        ),
        GetPage(
          name: '/scholarships/:id',
          page: () => Scaffold(body: Text('detail ${Get.parameters['id']}')),
        ),
      ],
    );

/// Un écran empilé sur la coquille (recherche, calculateur…) qui porte le
/// raccourci.
Future<void> _pushShortcut(
  WidgetTester tester,
  VoidCallback onTap,
) async {
  unawaited(
    Get.to<void>(
      () => Scaffold(
        body: TextButton(onPressed: onTap, child: const Text('shortcut')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('shortcut'), findsOneWidget);
}

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  group('resolveScholarshipNavigation', () {
    test('une bourse visée → sa fiche', () async {
      final controller = await _seed();
      controller.catalogDataState = CatalogDataState.live;
      expect(
        resolveScholarshipNavigation(
          scholarshipId: 'mext',
          fromCatalog: true,
          controller: controller,
        ),
        ScholarshipNavigationTarget.detail,
      );
    });

    test('aucune bourse visée → l\'onglet', () async {
      final controller = await _seed();
      expect(
        resolveScholarshipNavigation(controller: controller),
        ScholarshipNavigationTarget.tab,
      );
      expect(
        resolveScholarshipNavigation(
            scholarshipId: '  ', controller: controller),
        ScholarshipNavigationTarget.tab,
      );
    });

    test(
        'identifiant de l\'échantillon embarqué → l\'onglet, pas une fiche '
        '« introuvable »', () async {
      final controller = await _seed();
      controller.catalogDataState = CatalogDataState.sample;
      expect(
        resolveScholarshipNavigation(
          scholarshipId: 'sample-1',
          fromCatalog: true,
          controller: controller,
        ),
        ScholarshipNavigationTarget.tab,
      );
    });

    test('coquille commerciale (pas d\'onglet Bourses) → la route', () async {
      final controller = await _seed(accountType: AccountType.commercial);
      expect(
        resolveScholarshipNavigation(controller: controller),
        ScholarshipNavigationTarget.route,
      );
      expect(
        resolveScholarshipNavigation(),
        ScholarshipNavigationTarget.route,
      );
    });
  });

  group('openScholarshipOrTab', () {
    testWidgets('sans bourse : referme l\'écran empilé et bascule d\'onglet',
        (tester) async {
      final controller = await _seed();
      await tester.pumpWidget(_app());
      await _pushShortcut(tester, openScholarshipOrTab);

      await tester.tap(find.text('shortcut'));
      await tester.pumpAndSettle();

      expect(find.text('shortcut'), findsNothing);
      expect(find.text('second list'), findsNothing);
      expect(find.text('shell'), findsOneWidget);
      expect(controller.shellIndex, StudentShellTab.scholarships);
    });

    testWidgets('avec une bourse : ouvre sa fiche', (tester) async {
      final controller = await _seed();
      controller.catalogDataState = CatalogDataState.live;
      await tester.pumpWidget(_app());
      await _pushShortcut(
        tester,
        () => openScholarshipOrTab(scholarshipId: 'mext', fromCatalog: true),
      );

      await tester.tap(find.text('shortcut'));
      await tester.pumpAndSettle();

      expect(find.text('detail mext'), findsOneWidget);
      expect(find.text('second list'), findsNothing);
    });
  });
}
