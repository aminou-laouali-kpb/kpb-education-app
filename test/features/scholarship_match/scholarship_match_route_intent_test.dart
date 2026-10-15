// La route du test et l'intention en attente d'un invité :
//   · `/scholarship-match` est acceptée par normalizeExternalRoute ;
//   · `/scholarships/match` n'est PAS le test (c'est une fiche « match ») ;
//   · l'intention est lue au premier accueil d'un élève connecté, jamais pour
//     un invité, et expire après 24 h.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/deep_link_service.dart';
import 'package:karatou/app/core/services/pending_intent_store.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_actions.dart';

import '../../widget_test_helpers.dart';
import 'match_test_support.dart';

Future<AppController> _controller(AppSnapshot snapshot) async {
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: FakeMatchApi(),
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = false;
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

AppSnapshot _student() => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetMatchWorld());
  tearDown(tearDownMatchWorld);

  group('route', () {
    test('/scholarship-match est une route externe acceptée', () {
      expect(AppRoutes.normalizeExternalRoute('/scholarship-match'),
          '/scholarship-match');
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://scholarship-match')),
        '/scholarship-match',
      );
    });

    test('/scholarships/match n\'est PAS traité comme le test', () {
      final normalized =
          AppRoutes.normalizeExternalRoute('/scholarships/match');
      expect(normalized, isNot('/scholarship-match'));
      expect(AppRoutes.normalizeExternalRoute('/scholarship-match/x'), isNull);
    });

    test('la page est enregistrée même drapeau fermé', () {
      expect(
        AppRoutes.pages.map((p) => p.name),
        contains(AppRoutes.scholarshipMatch),
      );
    });
  });

  group('intention en attente', () {
    final t0 = DateTime(2026, 10, 15, 9);

    test('consommée au premier accueil d\'un élève connecté, une seule fois',
        () async {
      await PendingIntentStore.save(
        route: scholarshipMatchRoute,
        source: scholarshipMatchGuestSource,
        now: t0,
      );
      final controller = await _controller(_student());
      final opened = <String>[];
      final route = await consumeScholarshipMatchPendingIntent(
        controller,
        now: t0.add(const Duration(hours: 2)),
        navigate: opened.add,
      );
      expect(route, '/scholarship-match');
      expect(opened, ['/scholarship-match']);
      // Une seule fois.
      expect(
        await consumeScholarshipMatchPendingIntent(
          controller,
          now: t0.add(const Duration(hours: 3)),
          navigate: opened.add,
        ),
        isNull,
      );
      expect(opened, hasLength(1));
    });

    test('expirée après 24 h : effacée, rien n\'est ouvert', () async {
      await PendingIntentStore.save(
        route: scholarshipMatchRoute,
        source: scholarshipMatchGuestSource,
        now: t0,
      );
      final controller = await _controller(_student());
      final opened = <String>[];
      final route = await consumeScholarshipMatchPendingIntent(
        controller,
        now: t0.add(const Duration(hours: 24, minutes: 1)),
        navigate: opened.add,
      );
      expect(route, isNull);
      expect(opened, isEmpty);
      expect(await PendingIntentStore.peek(now: t0), isNull);
    });

    test(
        'pas consommée tant que l\'invité n\'a pas de compte (ni pendant '
        'l\'onboarding)', () async {
      await PendingIntentStore.save(
        route: scholarshipMatchRoute,
        source: scholarshipMatchGuestSource,
        now: t0,
      );
      final guest = await _controller(AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        isGuestMode: true,
      ));
      expect(
        await consumeScholarshipMatchPendingIntent(guest, now: t0),
        isNull,
      );
      Get.reset();
      final onboarding = await _controller(AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: false,
        profile: createTestProfile(),
      ));
      expect(
        await consumeScholarshipMatchPendingIntent(onboarding, now: t0),
        isNull,
      );
      expect(await PendingIntentStore.peek(now: t0), isNotNull);
    });

    test('compte « Passer » (onboarding marqué fait) : consommée', () async {
      await PendingIntentStore.save(
        route: scholarshipMatchRoute,
        source: scholarshipMatchGuestSource,
        now: t0,
      );
      final controller = await _controller(_student());
      controller.onboardingSkipped = true;
      final opened = <String>[];
      await consumeScholarshipMatchPendingIntent(
        controller,
        now: t0,
        navigate: opened.add,
      );
      expect(opened, ['/scholarship-match']);
    });
  });
}
