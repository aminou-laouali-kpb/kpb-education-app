import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/premium/premium_screen.dart';

import '../../widget_test_helpers.dart';

class _PassApi extends MockApiClient {
  _PassApi({required this.active});
  final bool active;
  int waitlistReads = 0;

  @override
  Future<Map<String, dynamic>> getMyPass() async => active
      ? {'active': true, 'activeUntil': '2026-12-22T10:00:00.000Z'}
      : {'active': false, 'activeUntil': null};

  @override
  Future<Map<String, dynamic>> getPremiumWaitlist() async {
    waitlistReads++;
    return {'registered': false};
  }
}

Future<void> _pump(WidgetTester tester, _PassApi api) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(fullName: 'Awa Diallo'),
      ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  await tester.pumpWidget(GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr'),
    fallbackLocale: const Locale('fr'),
    home: const PremiumScreen(),
  ));
  await tester.pumpAndSettle();
}

void _expectStoreSafe() {
  for (final forbidden in ['FCFA', 'Acheter', 'acheter', 'Payer', 'prix', '€', "s'abonner"]) {
    expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
  });
  tearDown(() {
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
  });

  testWidgets('drapeau fermé : l’écran de la 59 ne change pas (liste d’attente)',
      (tester) async {
    final api = _PassApi(active: false);
    await _pump(tester, api);
    expect(find.text('BIENTÔT DISPONIBLE'), findsOneWidget);
    expect(find.text('Le Pass Karatou'), findsNothing);
    expect(api.waitlistReads, 1);
  });

  testWidgets(
      'drapeau ouvert : l’offre réelle, sans « bientôt », sans liste '
      'd’attente, sans prix', (tester) async {
    RemoteFeatureFlags.instance.debugSetFeaturesForTest({'academy': true});
    final api = _PassApi(active: false);
    await _pump(tester, api);

    expect(find.text('Le Pass Karatou'), findsOneWidget);
    expect(find.text('BIENTÔT DISPONIBLE'), findsNothing);
    expect(find.textContaining('liste d\'attente'), findsNothing);
    expect(api.waitlistReads, 0);
    expect(find.byKey(const ValueKey('premium_pass_active')), findsNothing);
    await tester.scrollUntilVisible(find.text('Tous les cours'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Introduction et 1re leçon'), findsOneWidget);
    expect(find.text('Illimité'), findsOneWidget);
    expect(find.text('Parler à un conseiller KPB'), findsOneWidget);
    _expectStoreSafe();
  });

  testWidgets('Pass actif : la date de fin est affichée en tête',
      (tester) async {
    RemoteFeatureFlags.instance.debugSetFeaturesForTest({'academy': true});
    await _pump(tester, _PassApi(active: true));
    expect(find.byKey(const ValueKey('premium_pass_active')), findsOneWidget);
    expect(find.textContaining('actif jusqu\'au'), findsOneWidget);
    _expectStoreSafe();
  });
}
