// L'écran « Compétition ambassadeurs » (build 57, `features.referralLeaderboard`)
// et ses deux points d'entrée : l'espace ambassadeur sans programme rémunéré, et
// l'écran Parrainage.

import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio show Response;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/referral_attribution.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/referral/ambassador_competition_screen.dart';
import 'package:karatou/app/features/referral/ambassador_screen.dart';
import 'package:karatou/app/features/referral/referral_screen.dart';

import '../../widget_test_helpers.dart';

Map<String, dynamic> standing({
  String phase = 'running',
  String status = 'live',
  bool provisional = true,
  Object? rank = 2,
  bool rankable = true,
  String serverTime = '2026-11-05T12:00:00.000Z',
}) =>
    {
      'participating': true,
      'campaign': {
        'slug': 'ambassadeurs-novembre-2026',
        'nameFr': 'Ambassadeurs — novembre 2026',
        'nameEn': 'Ambassadors — November 2026',
        'status': status,
        'phase': phase,
        'startsAt': '2026-10-31T23:00:00.000Z',
        'endsAt': '2026-11-10T23:00:00.000Z',
        'provisional': provisional,
      },
      'me': {
        'publicName': 'Aïcha K.',
        'city': 'Niamey',
        'code': 'KTOU-AK-1a2b3c',
        'rank': rank,
        'qualified': 12,
        'toReview': 2,
        'pending': 4,
        'rankable': rankable,
      },
      'serverTime': serverTime,
    };

DioException _status(int code) => DioException(
      requestOptions: RequestOptions(path: '/referrals/campaigns/current'),
      type: DioExceptionType.badResponse,
      response: dio.Response<dynamic>(
        requestOptions: RequestOptions(path: '/referrals/campaigns/current'),
        statusCode: code,
      ),
    );

Map<String, dynamic> sampleDashboard() => {
      'activated': false,
      'isSample': true,
      'ambassador': {
        'displayName': 'Aïcha Konaté',
        'campus': '',
        'city': 'Niamey',
        'initials': 'AK',
        'code': 'KTOU-AK-1a2b3c',
        'rankLabel': '',
        'payoutMethod': 'wave',
        'payoutAccountMasked': '',
      },
      'stats': {'activeReferrals': 0, 'placed': 0, 'earnedFCFA': 0},
      'objective': {'target': 15, 'current': 0, 'bonusFCFA': 0},
      'rewards': <dynamic>[],
      'leaderboard': <dynamic>[],
      'referrals': <dynamic>[],
      'balanceFCFA': 0,
      'withdrawableFCFA': 0,
      'minWithdrawalFCFA': 20000,
      'history': <dynamic>[],
    };

void main() {
  late MockApiClient api;
  late List<(String, Map<String, Object>)> events;

  setUp(() {
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
    api = MockApiClient();
    events = [];
    AnalyticsService.instance.logEventSink = (name, params) async {
      events.add((name, params));
    };
    when(() => api.getPublicCampaignLeaderboard(any()))
        .thenAnswer((_) async => {
              'campaign': {'rulesUrl': 'https://kpbeducation.cloud/reglement'},
            });
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    RemoteFeatureFlags.resetForTest();
    ReferralAttribution.instanceForTest = null;
    resetGetxSingleton();
  });

  Future<void> pumpScreen(WidgetTester tester, {DateTime? now}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clockNow = now ?? DateTime.utc(2026, 11, 5, 12);
    await tester.pumpWidget(GetMaterialApp(
      home: AmbassadorCompetitionScreen(apiClient: api, clock: () => clockNow),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Démonte l'écran : son minuteur de compte à rebours s'arrête avec lui.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  group('participant', () {
    testWidgets('en cours : compte à rebours, rang, compteurs, code, liens',
        (tester) async {
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => standing());
      await pumpScreen(tester);

      expect(find.byKey(const ValueKey('comp-phase-running')), findsOneWidget);
      expect(find.text('comp_ends_in'), findsOneWidget);
      expect(find.text('Ambassadeurs — novembre 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-rank')), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('comp_rule_explainer'), findsOneWidget);
      expect(find.text('KTOU-AK-1a2b3c'), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-share')), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-public-link')), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-rules-link')), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-provisional')), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-unrankable')), findsNothing);
      // Aucun montant : ni prix, ni commission.
      expect(find.textContaining('FCFA'), findsNothing);

      final viewed =
          events.singleWhere((e) => e.$1 == 'referral_competition_viewed');
      expect(viewed.$2, {'campaign_phase': 'running'});
      await unmount(tester);
    });

    testWidgets('à venir : « Début dans », à l\'heure du serveur',
        (tester) async {
      when(() => api.getCurrentReferralCampaign()).thenAnswer((_) async =>
          standing(phase: 'upcoming', serverTime: '2026-10-30T12:00:00.000Z'));
      // Le téléphone avance de 3 jours : l'horloge du serveur fait foi.
      await pumpScreen(tester, now: DateTime.utc(2026, 11, 2, 12));
      expect(find.byKey(const ValueKey('comp-phase-upcoming')), findsOneWidget);
      expect(find.text('comp_starts_in'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
        'terminée et close : plus de compte à rebours ni « provisoire »',
        (tester) async {
      when(() => api.getCurrentReferralCampaign()).thenAnswer((_) async =>
          standing(phase: 'ended', status: 'closed', provisional: false));
      await pumpScreen(tester);
      expect(find.byKey(const ValueKey('comp-phase-ended')), findsOneWidget);
      expect(find.text('comp_ended_body'), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-provisional')), findsNothing);
      await unmount(tester);
    });

    testWidgets('terminée mais pas close : toujours « provisoire »',
        (tester) async {
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => standing(phase: 'ended', status: 'frozen'));
      await pumpScreen(tester);
      expect(find.byKey(const ValueKey('comp-phase-ended')), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-provisional')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('pas encore classé et non classable : dit pourquoi',
        (tester) async {
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => standing(rank: null, rankable: false));
      await pumpScreen(tester);
      expect(find.text('comp_rank_none'), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-unrankable')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('règlement non https : pas de bouton', (tester) async {
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => standing());
      when(() => api.getPublicCampaignLeaderboard(any()))
          .thenAnswer((_) async => {
                'campaign': {'rulesUrl': 'http://exemple.test'},
              });
      await pumpScreen(tester);
      expect(find.byKey(const ValueKey('comp-rules-link')), findsNothing);
      expect(find.byKey(const ValueKey('comp-public-link')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('le compte à rebours avance sans rechargement', (tester) async {
      var now = DateTime.utc(2026, 11, 10, 22, 59, 50);
      when(() => api.getCurrentReferralCampaign()).thenAnswer(
          (_) async => standing(serverTime: '2026-11-10T22:59:50.000Z'));
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(GetMaterialApp(
        home: AmbassadorCompetitionScreen(apiClient: api, clock: () => now),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('comp-phase-running')), findsOneWidget);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 31));
      expect(find.byKey(const ValueKey('comp-phase-ended')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('non-participant et pannes', () {
    testWidgets('non-participant : rien de promis, aucun lien public',
        (tester) async {
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => {'participating': false});
      await pumpScreen(tester);
      expect(find.text('comp_not_participating_title'), findsOneWidget);
      expect(find.byKey(const ValueKey('comp-public-link')), findsNothing);
      verifyNever(() => api.getPublicCampaignLeaderboard(any()));
      expect(
          events.singleWhere((e) => e.$1 == 'referral_competition_viewed').$2,
          {'campaign_phase': 'none'});
      await unmount(tester);
    });

    testWidgets('route absente (backend plus ancien) = non-participant',
        (tester) async {
      when(() => api.getCurrentReferralCampaign()).thenThrow(_status(404));
      await pumpScreen(tester);
      expect(find.text('comp_not_participating_title'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hors ligne : état d\'erreur dédié, « Réessayer » recharge',
        (tester) async {
      var calls = 0;
      when(() => api.getCurrentReferralCampaign()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          );
        }
        return standing();
      });
      await pumpScreen(tester);
      expect(find.text('comp_offline_title'), findsOneWidget);
      await tester.tap(find.text('retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, 2);
      expect(find.byKey(const ValueKey('comp-rank')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('panne serveur : état d\'erreur générique', (tester) async {
      when(() => api.getCurrentReferralCampaign()).thenThrow(_status(500));
      await pumpScreen(tester);
      expect(find.text('comp_error_title'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('points d\'entrée', () {
    Future<void> pumpAmbassador(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      when(() => api.getAmbassadorDashboard())
          .thenAnswer((_) async => sampleDashboard());
      await pumpTestApp(
        tester,
        child: const AmbassadorScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
        mockApiClient: api,
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets(
        'espace ambassadeur sans cash, drapeau ouvert, participant : '
        'le classement remplace la candidature', (tester) async {
      RemoteFeatureFlags.instance
          .debugSetFeaturesForTest({'referralLeaderboard': true});
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => standing());
      await pumpAmbassador(tester);
      expect(find.byKey(const ValueKey('comp-rank')), findsOneWidget);
      expect(find.text('amb_apply_cta_advisor'), findsNothing);
      await unmount(tester);
    });

    testWidgets('drapeau ouvert, non-participant : la candidature, inchangée',
        (tester) async {
      RemoteFeatureFlags.instance
          .debugSetFeaturesForTest({'referralLeaderboard': true});
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => {'participating': false});
      await pumpAmbassador(tester);
      expect(find.text('amb_apply_cta_advisor'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('drapeau fermé : la candidature, sans appel à la compétition',
        (tester) async {
      await pumpAmbassador(tester);
      expect(find.text('amb_apply_cta_advisor'), findsOneWidget);
      verifyNever(() => api.getCurrentReferralCampaign());
    });

    Future<void> pumpReferral(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      when(() => api.getMyReferral()).thenAnswer((_) async =>
          {'code': 'K7PQ2MZA', 'signedUpCount': 1, 'caseCreatedCount': 0});
      when(() => api.getMyReferralCredits())
          .thenAnswer((_) async => {'balance': 0, 'history': <dynamic>[]});
      await pumpTestApp(
        tester,
        child: const ReferralScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
        mockApiClient: api,
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('écran Parrainage : l\'entrée n\'apparaît qu\'au participant',
        (tester) async {
      RemoteFeatureFlags.instance
          .debugSetFeaturesForTest({'referralLeaderboard': true});
      when(() => api.getCurrentReferralCampaign())
          .thenAnswer((_) async => standing());
      await pumpReferral(tester);
      expect(find.byKey(const ValueKey('referral-competition-entry')),
          findsOneWidget);
    });

    testWidgets('écran Parrainage, drapeau fermé : ni entrée ni appel',
        (tester) async {
      await pumpReferral(tester);
      expect(find.byKey(const ValueKey('referral-competition-entry')),
          findsNothing);
      verifyNever(() => api.getCurrentReferralCampaign());
    });
  });
}
