// Après « Soumettre » : UN bandeau, sans fausse référence, dont « Voir » ouvre
// le dossier (audit build 57, T4-16). Avant : « KPB-2026-001 » (nombre de
// dossiers + 1, calculé sur le téléphone) au lieu de la vraie référence, un
// second bandeau par-dessus, et « Voir » qui ne faisait que changer d'onglet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

import '../widget_test_helpers.dart';

void main() {
  setUp(() {
    resetGetxSingleton();
    AppConfig.enableRemoteSyncOverride = false;
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  testWidgets('un bandeau, sans référence locale, et « Voir » ouvre le dossier',
      (tester) async {
    // Le bandeau s'ancre en bas : la surface par défaut (800×600) le laisse
    // hors de portée du tap.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    setupPlatformChannelMocks();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      ),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);

    await tester.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: const Scaffold(body: SizedBox()),
      getPages: [
        GetPage(
          name: '/cases/:id',
          page: () => Text('detail:${Get.parameters['id']}'),
        ),
      ],
    ));

    final created = controller.submitCase(
      type: CaseType.consultation,
      title: 'Test',
      description: 'Desc',
      contextLabel: 'France',
      contactMethod: ContactMethod.inApp,
    );
    // Le bandeau entre en glissant par le bas : le laisser arriver.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    final fr = AppTranslations().keys['fr']!;
    expect(find.text(fr['case_created_body']!), findsOneWidget);
    // La référence calculée sur le téléphone n'est plus citée : elle n'est pas
    // celle du serveur.
    expect(find.textContaining('KPB-'), findsNothing);
    expect(created.referenceCode, startsWith('KPB-'));

    await tester.tap(find.text(fr['view']!));
    await tester.pumpAndSettle();
    expect(find.text('detail:${controller.cases.first.id}'), findsOneWidget);
  });
}
