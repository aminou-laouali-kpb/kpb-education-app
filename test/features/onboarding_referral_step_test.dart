// L'étape « Tu as un code de parrain ? » (build 57) : facultative, préremplie
// par le lien d'invitation, et elle ne bloque JAMAIS la fin de l'onboarding.

import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio show Response;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/referral_attribution.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/matches/aha_moment_screen.dart';
import 'package:karatou/app/features/onboarding/onboarding_referral_step.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';

import '../widget_test_helpers.dart';

class _MemoryStore implements ReferralLocalStore {
  PendingReferralCode? pending;
  String? id = 'install-uuid-0001';

  @override
  Future<bool> installReferrerChecked() async => true;
  @override
  Future<void> markInstallReferrerChecked() async {}
  @override
  Future<PendingReferralCode?> readPendingCode() async => pending;
  @override
  Future<void> writePendingCode(PendingReferralCode code) async =>
      pending = code;
  @override
  Future<void> clearPendingCode() async => pending = null;
  @override
  Future<String?> readInstallId() async => id;
  @override
  Future<void> writeInstallId(String value) async => id = value;
}

DioException _status(int code, {Object? data}) => DioException(
      requestOptions: RequestOptions(path: '/referrals/redeem'),
      type: DioExceptionType.badResponse,
      response: dio.Response<dynamic>(
        requestOptions: RequestOptions(path: '/referrals/redeem'),
        statusCode: code,
        data: data,
      ),
    );

void main() {
  late _MemoryStore store;
  late MockApiClient api;
  late int finished;
  late List<(String, Map<String, Object>)> events;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    setupPlatformChannelMocks();
    store = _MemoryStore();
    api = MockApiClient();
    finished = 0;
    events = [];
    AnalyticsService.instance.logEventSink = (name, params) async {
      events.add((name, params));
    };
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    resetGetxSingleton();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: OnboardingReferralStep(
        apiClient: api,
        attribution: ReferralAttribution(store: store),
        onFinished: () => finished++,
      ),
    ));
    await tester.pumpAndSettle();
  }

  void answer(Future<Map<String, dynamic>> Function() reply) {
    when(() => api.redeemReferral(any(), deviceId: any(named: 'deviceId')))
        .thenAnswer((_) => reply());
  }

  Future<void> validate(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onb-ref-validate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  String? fieldError(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('onb-ref-code')))
      .decoration
      ?.errorText;

  testWidgets('prérempli par le lien d\'invitation, avec la mention à vérifier',
      (tester) async {
    store.pending = const PendingReferralCode(
      code: 'KTOU-AB-1A2B3C',
      origin: PendingReferralOrigin.installReferrer,
    );
    await pump(tester);
    expect(find.text('KTOU-AB-1A2B3C'), findsOneWidget);
    expect(find.text('onb_ref_prefilled_note'), findsOneWidget);
    // Jamais de rattachement silencieux : rien n'est parti.
    verifyNever(
        () => api.redeemReferral(any(), deviceId: any(named: 'deviceId')));
    final viewed =
        events.singleWhere((e) => e.$1 == 'referral_code_prompt_viewed');
    expect(viewed.$2, {'surface': 'onboarding', 'prefill': 'install_referrer'});
  });

  testWidgets('sans code : champ vide, « Valider » inactif, « Passer » actif',
      (tester) async {
    await pump(tester);
    final validateButton = tester
        .widget<FilledButton>(find.byKey(const ValueKey('onb-ref-validate')));
    expect(validateButton.onPressed, isNull);
    expect(find.text('onb_ref_prefilled_note'), findsNothing);
  });

  testWidgets('« Passer » termine sans appel réseau et garde le code du lien',
      (tester) async {
    store.pending = const PendingReferralCode(
      code: 'K7PQ2MZA',
      origin: PendingReferralOrigin.installReferrer,
    );
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('onb-ref-skip')));
    await tester.pump();
    expect(finished, 1);
    verifyNever(
        () => api.redeemReferral(any(), deviceId: any(named: 'deviceId')));
    expect(store.pending?.code, 'K7PQ2MZA',
        reason: 'l\'écran Parrainage doit encore le proposer');
    expect(events.map((e) => e.$1), contains('referral_code_skipped'));
  });

  testWidgets('succès : code envoyé avec l\'identifiant, étape terminée',
      (tester) async {
    answer(() async => {'attributed': true, 'alreadyReferred': false});
    await pump(tester);
    await tester.enterText(
        find.byKey(const ValueKey('onb-ref-code')), 'k7pq2mza');
    await validate(tester);
    verify(() => api.redeemReferral('K7PQ2MZA', deviceId: 'install-uuid-0001'))
        .called(1);
    expect(finished, 1);
    final submitted =
        events.singleWhere((e) => e.$1 == 'referral_code_submitted');
    expect(submitted.$2['result'], 'attributed');
    expect(submitted.$2.keys.toSet(), {'surface', 'prefill', 'result'});
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('déjà parrainé : succès silencieux', (tester) async {
    answer(() async => {'attributed': false, 'alreadyReferred': true});
    await pump(tester);
    await tester.enterText(
        find.byKey(const ValueKey('onb-ref-code')), 'K7PQ2MZA');
    await validate(tester);
    expect(finished, 1);
  });

  for (final (name, error, key) in [
    ('code inconnu', _status(404), 'referral_err_unknown'),
    (
      'auto-parrainage',
      _status(403, data: {'message': 'You cannot use your own referral code.'}),
      'referral_err_self'
    ),
    (
      'parrainage refusé',
      _status(403, data: {'message': 'Mutual referrals are not allowed.'}),
      'referral_err_not_allowed'
    ),
  ]) {
    testWidgets('$name : message dans le champ, l\'élève corrige ou passe',
        (tester) async {
      answer(() async => throw error);
      await pump(tester);
      await tester.enterText(
          find.byKey(const ValueKey('onb-ref-code')), 'K7PQ2MZA');
      await validate(tester);
      expect(finished, 0);
      expect(fieldError(tester), key);
      // « Passer » reste disponible : l'étape ne retient personne.
      await tester.tap(find.byKey(const ValueKey('onb-ref-skip')));
      await tester.pump();
      expect(finished, 1);
    });
  }

  for (final (name, error, key) in [
    (
      'limite horaire (429)',
      _status(429, data: {'code': 'referral_code_rate_limited'}),
      'referral_err_rate_limited'
    ),
    (
      'hors ligne',
      DioException(
        requestOptions: RequestOptions(path: '/referrals/redeem'),
        type: DioExceptionType.connectionError,
      ),
      'referral_err_offline'
    ),
    ('panne serveur', _status(500), 'referral_err_generic'),
  ]) {
    testWidgets('$name : code gardé pour plus tard, l\'onboarding continue',
        (tester) async {
      answer(() async => throw error);
      await pump(tester);
      await tester.enterText(
          find.byKey(const ValueKey('onb-ref-code')), 'K7PQ2MZA');
      await validate(tester);
      expect(finished, 1, reason: 'ne bloque jamais la fin de l\'onboarding');
      expect(store.pending?.code, 'K7PQ2MZA');
      expect(find.text(key), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  }

  group('dans l\'onboarding', () {
    Future<void> seedOnLastPage(MockApiClient api) async {
      AppConfig.enableRemoteSyncOverride = false;
      final controller = AppController(
        repository: FakeRepository(
          snapshot: AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: false,
            onboardingStep: 2,
            profile: createTestProfile(),
          ),
        ),
        apiClient: api,
      );
      await controller.hydrate();
      Get.put<AppController>(controller, permanent: true);
    }

    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      RemoteFeatureFlags.resetForTest();
      ReferralAttribution.instanceForTest = null;
    });

    Future<void> submit(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        home: const OnboardingScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('create_account'.tr));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
        'drapeau ouvert : l\'étape suit la synchro du profil, '
        '« Passer » mène à l\'écran « aha »', (tester) async {
      RemoteFeatureFlags.instance
          .debugSetFeaturesForTest({'referralOnboardingCode': true});
      ReferralAttribution.instanceForTest = ReferralAttribution(store: store);
      await seedOnLastPage(api);
      await submit(tester);

      expect(find.byType(OnboardingReferralStep), findsOneWidget);
      expect(Get.find<AppController>().hasCompletedOnboarding, isTrue,
          reason: 'le profil est synchronisé AVANT l\'étape');

      await tester.tap(find.byKey(const ValueKey('onb-ref-skip')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AhaMomentScreen), findsOneWidget);
      verifyNever(
          () => api.redeemReferral(any(), deviceId: any(named: 'deviceId')));
    });

    testWidgets('drapeau fermé : directement l\'écran « aha »', (tester) async {
      await seedOnLastPage(api);
      await submit(tester);
      expect(find.byType(OnboardingReferralStep), findsNothing);
      expect(find.byType(AhaMomentScreen), findsOneWidget);
    });
  });
}
