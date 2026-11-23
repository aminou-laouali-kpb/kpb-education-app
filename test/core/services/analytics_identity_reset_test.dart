// Audit du 22/11/2026, n° 17 : l'identité PostHog doit être remise à zéro
// à la déconnexion MÊME sans Firebase, et à la suppression du compte.
//
// Avant : `logLogout` appelait la remise à zéro dans le même `try` que
// `FirebaseAnalytics.instance.logEvent` ; sans app Firebase (démarrage hors
// ligne, PostHog démarré quand même), `logEvent` levait et `Posthog().reset()`
// n'était jamais appelé. `deleteAccount` ne l'appelait pas du tout. Dans les
// deux cas, la session suivante sur le téléphone restait attribuée au
// distinct_id du compte parti.
//
// Ces tests tournent justement SANS app Firebase par défaut : c'est le
// démarrage hors ligne du constat.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/services/analytics_service.dart';

import '../../widget_test_helpers.dart';

void main() {
  final service = AnalyticsService.instance;
  final defaultReset = service.posthogReset;
  final defaultWired = service.posthogWired;

  late int resets;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resets = 0;
    service.posthogReset = () async => resets++;
    service.posthogWired = true;
  });

  tearDown(() {
    // Singleton : les substitutions ne doivent pas fuir vers d'autres tests.
    service.posthogReset = defaultReset;
    service.posthogWired = defaultWired;
  });

  test('logLogout remet l’identité PostHog à zéro même sans Firebase',
      () async {
    await service.logLogout();

    expect(resets, 1,
        reason: 'sans app Firebase, logEvent lève : la remise à zéro de '
            'PostHog ne doit pas en dépendre');
  });

  test('sans PostHog branché, aucune remise à zéro', () async {
    service.posthogWired = false;
    await service.logLogout();
    expect(resets, 0);
  });

  test('un échec du SDK PostHog ne fait pas lever logLogout', () async {
    service.posthogReset = () async => throw StateError('posthog down');
    await expectLater(service.logLogout(), completes);
  });

  group('suppression du compte', () {
    setUp(() {
      resetGetxSingleton();
      setupPlatformChannelMocks();
      AppConfig.enableRemoteSyncOverride = false;
    });
    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      resetGetxSingleton();
    });

    test('deleteAccount remet l’identité PostHog à zéro', () async {
      final controller = AppController(
        repository: FakeRepository(),
        apiClient: MockApiClient(),
      );
      await controller.hydrate();
      Get.put<AppController>(controller, permanent: true);

      await controller.deleteAccount();

      expect(resets, 1,
          reason: 'le distinct_id du compte supprimé ne doit pas rester '
              'attaché au téléphone (RGPD)');
    });
  });
}
