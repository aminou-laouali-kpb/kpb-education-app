// Écran Parrainage (build 57) : le code en attente — lien d'invitation, ou
// saisi à l'onboarding sans réseau — y est prérempli, jamais validé seul.

import 'dart:async';

import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio show Response;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/referral_attribution.dart';
import 'package:karatou/app/features/referral/referral_screen.dart';

import '../../widget_test_helpers.dart';

class _MemoryStore implements ReferralLocalStore {
  PendingReferralCode? pending;
  String? id = 'install-uuid-0002';

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

void main() {
  late MockApiClient api;
  late _MemoryStore store;

  setUp(() {
    resetGetxSingleton();
    api = MockApiClient();
    store = _MemoryStore();
    AnalyticsService.instance.logEventSink = (_, __) async {};
    when(() => api.getMyReferral()).thenAnswer((_) async =>
        {'code': 'K7PQ2MZA', 'signedUpCount': 0, 'caseCreatedCount': 0});
    when(() => api.getMyReferralCredits())
        .thenAnswer((_) async => {'balance': 0, 'history': <dynamic>[]});
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    resetGetxSingleton();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTestApp(
      tester,
      child: ReferralScreen(attribution: ReferralAttribution(store: store)),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
      mockApiClient: api,
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('code du lien prérempli, avec sa mention, rien n\'est envoyé',
      (tester) async {
    store.pending = const PendingReferralCode(
      code: 'KTOU-AB-1A2B3C',
      origin: PendingReferralOrigin.installReferrer,
    );
    await pump(tester);
    final field = tester
        .widget<TextField>(find.byKey(const ValueKey('referral-code-field')));
    expect(field.controller?.text, 'KTOU-AB-1A2B3C');
    expect(find.text('referral_pending_note'), findsOneWidget);
    verifyNever(
        () => api.redeemReferral(any(), deviceId: any(named: 'deviceId')));
  });

  testWidgets('code saisi à l\'onboarding sans réseau : mention dédiée',
      (tester) async {
    store.pending = const PendingReferralCode(
      code: 'K7PQ2MZB',
      origin: PendingReferralOrigin.typed,
    );
    await pump(tester);
    expect(find.text('referral_pending_typed_note'), findsOneWidget);
  });

  testWidgets('valider : identifiant d\'installation joint, code oublié',
      (tester) async {
    store.pending = const PendingReferralCode(
      code: 'KTOU-AB-1A2B3C',
      origin: PendingReferralOrigin.installReferrer,
    );
    when(() => api.redeemReferral(any(), deviceId: any(named: 'deviceId')))
        .thenAnswer(
            (_) async => {'attributed': true, 'alreadyReferred': false});
    await pump(tester);
    await tester.tap(find.text('referral_redeem_cta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    verify(() =>
            api.redeemReferral('KTOU-AB-1A2B3C', deviceId: 'install-uuid-0002'))
        .called(1);
    expect(store.pending, isNull);
    expect(find.text('referral_pending_note'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('limite horaire : message clair, le code reste proposé',
      (tester) async {
    when(() => api.redeemReferral(any(), deviceId: any(named: 'deviceId')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/referrals/redeem'),
      type: DioExceptionType.badResponse,
      response: dio.Response<dynamic>(
        requestOptions: RequestOptions(path: '/referrals/redeem'),
        statusCode: 429,
        data: {'code': 'referral_code_rate_limited'},
      ),
    ));
    await pump(tester);
    await tester.enterText(
        find.byKey(const ValueKey('referral-code-field')), 'k7pq2mza');
    await tester.pump();
    await tester.tap(find.text('referral_redeem_cta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('referral_err_rate_limited_here'), findsOneWidget);
    expect(store.pending?.code, 'K7PQ2MZA');
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
  testWidgets(
      'chargement en échec : message et « Réessayer », puis le code '
      '(revue avant la 58)', (tester) async {
    // Avant : le catch avalait l'erreur ; l'écran montrait « — » et un bouton
    // d'invitation grisé, sans explication ni moyen de réessayer.
    var calls = 0;
    when(() => api.getMyReferral()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('hors ligne');
      return {'code': 'K7PQ2MZA', 'signedUpCount': 0, 'caseCreatedCount': 0};
    });

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('error_state_default_title'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);
    expect(find.text('—'), findsNothing);

    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('error_state_default_title'), findsNothing);
    expect(find.text('K7PQ2MZA'), findsOneWidget);
  });

  testWidgets('tirer pour rafraîchir recharge le code', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    verify(() => api.getMyReferral()).called(1);

    // Le geste lui-même relève du framework ; on vérifie que l'écran est bien
    // enveloppé et que le rafraîchissement rappelle l'API.
    expect(find.byType(RefreshIndicator), findsOneWidget);
    // `show()` ne se termine qu'avec le rafraîchissement : on ne l'attend pas,
    // on fait avancer les images.
    unawaited(tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show());
    await tester.pumpAndSettle();

    verify(() => api.getMyReferral()).called(1);
    expect(find.text('K7PQ2MZA'), findsOneWidget);
  });
}
