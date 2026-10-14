// Accueil (chantier G) :
//   · la cloche s'allume aussi pour les non-lus du fil SERVEUR (une « bourse
//     ouverte » pas encore vue), pas seulement pour l'activité des dossiers ;
//   · « Mes suivis » est joignable depuis l'en-tête.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/home/home_screen.dart';

import '../../widget_test_helpers.dart';

Future<AppController> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 2560));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
    home: const Scaffold(body: HomeScreen()),
    getPages: [
      GetPage(name: '/saved', page: () => const Text('page-mes-suivis')),
    ],
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUp(() {
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    RemoteFeatureFlags.resetForTest();
    resetGetxSingleton();
  });

  final dot = find.byKey(const ValueKey('home-bell-unread-dot'));

  testWidgets('la cloche s\'allume pour un non-lu du serveur', (tester) async {
    final controller = await _pump(tester);
    expect(dot, findsNothing);

    controller.setServerUnreadNotifications(1);
    await tester.pumpAndSettle();
    expect(dot, findsOneWidget);

    controller.setServerUnreadNotifications(0);
    await tester.pumpAndSettle();
    expect(dot, findsNothing);
  });

  testWidgets('« Mes suivis » s\'ouvre depuis l\'en-tête', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('home-followed-entry')));
    await tester.pumpAndSettle();
    expect(find.text('page-mes-suivis'), findsOneWidget);
  });
}
