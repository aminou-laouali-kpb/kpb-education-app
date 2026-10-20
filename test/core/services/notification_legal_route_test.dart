// Audit 57, F11 — la campagne « Notre politique évolue » doit ouvrir la
// politique de confidentialité, pas l'accueil.
//
// Aucune route nommée ne menait à la politique : la charge `route` de la
// campagne était rejetée par `normalizeExternalRoute`, et le tap tombait sur
// `Get.offAllNamed(home)`. La route `/legal/privacy` (nom figé, partagé avec la
// console) ouvre maintenant `PrivacyPolicyScreen`, démarrage à froid compris.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/notification_router.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/features/legal/legal_pages.dart';

import '../../support/screen_harness.dart';

/// La charge d'une campagne admin : `campaignId` et la route posée par
/// l'opérateur, rien d'autre.
const _campaign = <String, dynamic>{
  'campaignId': 'cmp_privacy_2026_10',
  'route': '/legal/privacy',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final router = NotificationRouter.instance;

  setUp(() {
    Get.reset();
    router.debugReset();
    AnalyticsService.instance.logEventSink = (_, __) async {};
  });

  tearDown(() {
    router.debugReset();
    AnalyticsService.instance.logEventSink = null;
    AppConfig.enableRemoteSyncOverride = null;
    Get.reset();
  });

  test('le nom de la route est figé', () {
    expect(AppRoutes.legalPrivacy, '/legal/privacy');
  });

  test('normalizeExternalRoute accepte /legal/privacy', () {
    expect(AppRoutes.normalizeExternalRoute('/legal/privacy'),
        AppRoutes.legalPrivacy);
    expect(AppRoutes.normalizeExternalRoute(' /legal/privacy '),
        AppRoutes.legalPrivacy);
    // Rien d'autre sous /legal/ n'est ouvert par une charge externe.
    expect(AppRoutes.normalizeExternalRoute('/legal/terms'), isNull);
  });

  test('la route a sa page, et c\'est la politique', () {
    final page =
        AppRoutes.pages.singleWhere((p) => p.name == AppRoutes.legalPrivacy);
    expect(page.page(), isA<PrivacyPolicyScreen>());
  });

  test('le tap de la campagne vise la politique, pas l\'accueil', () {
    expect(resolveNotificationRoute(_campaign), AppRoutes.legalPrivacy);
    expect(pushOpenedPayload(_campaign), {'campaignId': 'cmp_privacy_2026_10'});
  });

  testWidgets(
      'démarrage à froid : le tap ouvre la politique par-dessus le démarrage',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedKpbController();

    // Le tap arrive AVANT que l'app soit montée : il est mis en file.
    await router.open(_campaign);
    expect(router.pendingCount, 1);

    await tester.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      theme: AppTheme.buildTheme(),
      home: const Scaffold(body: Text('écran de démarrage')),
      getPages: AppRoutes.pages,
    ));
    router.markReady();
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    // Poussée PAR-DESSUS l'écran de démarrage : pas de passage par l'accueil
    // (`offAllNamed(home)` aurait vidé la pile).
    expect(Get.currentRoute, AppRoutes.legalPrivacy);
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text('écran de démarrage'), findsOneWidget);
  });
}
