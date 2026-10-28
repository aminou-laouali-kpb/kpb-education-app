import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/profile_fit_badge.dart';
import 'package:karatou/app/features/matches/aha_moment_screen.dart';

import '../widget_test_helpers.dart';

Map<String, dynamic> matchJson({
  String institutionId = 'inst-1',
  String programId = 'prog-1',
  double probability = 0.74,
  String zone = 'green',
  bool isEstimate = false,
}) {
  return {
    'institutionId': institutionId,
    'institutionName': {'fr': 'Université Test', 'en': 'Test University'},
    'programId': programId,
    'programName': {'fr': 'Master Informatique', 'en': 'MSc Computer Science'},
    'probability': probability,
    'zone': zone,
    'isEstimate': isEstimate,
    'algorithmVersion': 'v1',
    'factors': [
      {'name': 'academic', 'weight': 0.3, 'score': 1, 'isEstimate': false},
    ],
    'narrative': {
      'fr': 'Ton profil correspond très bien.',
      'en': 'Your profile is a strong match.',
    },
  };
}

void main() {
  setUp(() {
    // Labels are localized via `.tr`; register translations + a FR locale so
    // assertions read the real strings, not raw keys.
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
  });
  tearDown(resetGetxSingleton);

  testWidgets('renders server matches with a qualitative fit and narrative',
      (tester) async {
    final api = MockApiClient();
    when(() => api.getAhaMatches()).thenAnswer(
      (_) async => {
        'items': [matchJson()],
        'isEstimate': false,
      },
    );

    await pumpTestApp(tester,
        child: const AhaMomentScreen(), mockApiClient: api);

    expect(find.text('Université Test'), findsOneWidget);
    expect(find.text('Master Informatique'), findsOneWidget);
    // Zone serveur rendue en palier qualitatif — la probabilité (0,74) ne
    // s'affiche jamais (conformité : aucun pourcentage d'admission).
    expect(find.text('74%'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(ProfileFitBadge), findsOneWidget);
    expect(find.text('Ton profil correspond très bien.'), findsOneWidget);
    // Not an estimate → no precision note.
    expect(
      find.textContaining('complète ton profil', findRichText: true),
      findsNothing,
    );
    verify(() => api.getAhaMatches()).called(1);
  });

  testWidgets('shows the estimate note when a match is flagged isEstimate',
      (tester) async {
    final api = MockApiClient();
    when(() => api.getAhaMatches()).thenAnswer(
      (_) async => {
        'items': [matchJson(isEstimate: true, zone: 'yellow')],
        'isEstimate': true,
      },
    );

    await pumpTestApp(tester,
        child: const AhaMomentScreen(), mockApiClient: api);

    expect(find.textContaining('Estimation'), findsOneWidget);
  });

  testWidgets('falls back to local scoring when the API call fails',
      (tester) async {
    final api = MockApiClient();
    when(() => api.getAhaMatches()).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/matches/aha-moment')),
    );

    await pumpTestApp(tester,
        child: const AhaMomentScreen(), mockApiClient: api);

    // The initial snapshot still carries the bundled mock catalog, so the
    // local AppSearchService fallback produces scored cards (flagged as
    // estimates) instead of a dead end.
    expect(find.byType(ProfileFitBadge), findsWidgets);
    // Conformité : aucun pourcentage affiché sur les cartes d'écoles.
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('Estimation'), findsOneWidget);
    // CTA is always present.
    expect(find.text('Découvrir mon espace'), findsOneWidget);
  });

  testWidgets('shows the primary "see all universities" CTA alongside home',
      (tester) async {
    final api = MockApiClient();
    when(() => api.getAhaMatches()).thenAnswer(
      (_) async => {
        'items': [matchJson()],
        'isEstimate': false,
      },
    );

    await pumpTestApp(tester,
        child: const AhaMomentScreen(), mockApiClient: api);

    // Primary CTA (App-engagement handoff: "See all universities") is new;
    // the original "Découvrir mon espace" home link stays as the secondary
    // action so the existing navigation test below keeps working.
    expect(find.text('Voir toutes les universités'), findsOneWidget);
    expect(find.text('Découvrir mon espace'), findsOneWidget);
  });

  testWidgets('CTA navigates home', (tester) async {
    final api = MockApiClient();
    when(() => api.getAhaMatches()).thenAnswer(
      (_) async => {
        'items': [matchJson()],
        'isEstimate': false,
      },
    );

    await pumpTestApp(tester,
        child: const AhaMomentScreen(), mockApiClient: api);

    await tester.tap(find.text('Découvrir mon espace'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, '/');
  });

  // Audit build 57, n° 8 (volet app) : deux étiquettes de compatibilité sur la
  // même carte (« Bon match » et « Correspond en partie »), et des frais en
  // euros seulement pour un élève qui pense son budget en FCFA.
  testWidgets('une seule étiquette de compatibilité, et les frais en FCFA',
      (tester) async {
    final inEuros = MockCatalog.institutions.firstWhere(
      (i) => i.tuitionLabel.fr.contains('€'),
    );
    final api = MockApiClient();
    when(() => api.getAhaMatches()).thenAnswer(
      (_) async => {
        'items': [matchJson(institutionId: inEuros.id, zone: 'yellow')],
        'isEstimate': false,
      },
    );

    await pumpTestApp(tester,
        child: const AhaMomentScreen(), mockApiClient: api);
    // Tiroir : la carte est rendue et l'établissement résolu.
    expect(
        Get.find<AppController>().institutionByIdOrNull(inEuros.id), isNotNull);
    expect(find.byType(ProfileFitBadge), findsOneWidget);

    expect(find.textContaining('Correspond'), findsNothing);
    expect(find.textContaining('FCFA'), findsOneWidget);
  });
}
