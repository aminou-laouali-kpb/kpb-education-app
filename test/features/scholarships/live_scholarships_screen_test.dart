import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/live_scholarships_query.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/scholarships_offline_cache.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/skeleton.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';
import 'package:karatou/app/features/scholarships/scholarship_detail_screen.dart';

import '../../widget_test_helpers.dart';
import 'scholarships_test_support.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement restyle (PR4): the live scholarships list
// + detail sheet. Verify the restyled row binds to REAL model fields (name,
// funding, a J-<days> countdown computed from deadlineAt), that the "Deadline
// soon" chip fires for a near deadline, that the real per-scholarship alert
// action is rendered (backed by the alert-subscription API), and that opening
// the detail surfaces the external "Official application form" CTA.
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _scholarshipJson({bool withCycle = false}) =>
    <String, dynamic>{
      'id': 'mext-2027',
      'title': 'MEXT Japan Scholarship',
      'countryName': 'Japan',
      'countryId': 'jpn',
      'fundingType': 'fully_funded',
      'applicationRequirement': 'separate_application',
      'description':
          'Full Japanese government scholarship for international students.',
      'advantages': <String>['Full tuition waiver', 'Monthly stipend'],
      'eligibility': <String>['Under 35 years old', 'Strong academic record'],
      'level': 'Master',
      'deadlineLabel': 'May 2027',
      'deadlineAt': DateTime.now()
          .add(const Duration(days: 5, hours: 2))
          .toIso8601String(),
      'applicationUrl': 'https://example.org/mext/apply',
      'sourceUrl': 'https://example.org/mext',
      'tags': <String>['scholarship'],
      'matchScore': 82,
      'applicationSteps': <dynamic>[],
      if (withCycle)
        'currentCycle': <String, dynamic>{
          'id': 'mext-2027-cycle',
          'academicYear': '2027-2028',
          'status': 'open',
          'dateConfidence': 'confirmed',
          'opensAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'closesAt':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        },
    };

Map<String, dynamic> _access(bool enabled, {String? reason}) =>
    <String, dynamic>{
      'enabled': enabled,
      'reasons': <String>[if (reason != null) reason],
    };

Future<void> _seed(MockApiClient apiClient) async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    ),
    apiClient: apiClient,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
}

void _stubFetch(
  MockApiClient mock,
  List<dynamic> items, {
  Map<String, dynamic>? successLabAccess,
}) {
  whenScholarshipsPage(mock).thenAnswer((_) async => scholarshipsPage(items));
  when(() => mock.fetchScholarshipAlerts()).thenAnswer((_) async => <String>{});
  when(() => mock.getSuccessLabAccess()).thenAnswer(
    (_) async => successLabAccess ?? _access(false, reason: 'feature_disabled'),
  );
}

void _stubDetail(
  MockApiClient mock,
  LiveScholarshipModel scholarship,
) {
  when(
    () => mock.fetchLiveScholarshipDetailWithFallback(
      scholarshipId: any(named: 'scholarshipId'),
      lang: any(named: 'lang'),
      initial: any(named: 'initial'),
    ),
  ).thenAnswer((_) async => scholarship);
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void main() {
  setUpAll(registerScholarshipListFallbacks);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(resetGetxSingleton);

  testWidgets(
      'restyled list renders a real scholarship row (name, funding, J-days, '
      'soon chip) and the real alert action', (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[_scholarshipJson()]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    // Real data bound from the model.
    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
    expect(find.text('Entièrement financée'), findsWidgets); // fundingType chip
    // Chantier I : la puce d'urgence de la FICHE, tirée de la date limite
    // CONFIRMÉE (~5 jours) : « Clôture proche · <date> » (texte foncé sur
    // ambre), jamais « Ouverte · clôture … » en même temps.
    expect(find.textContaining('Clôture proche · '), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('scholarship-urgency-chip')),
      findsOneWidget,
    );
    // Le drapeau vient de `countryId` (`jpn`), plus du nom du pays.
    expect(find.text('🇯🇵'), findsOneWidget);
    // Le total réel du serveur.
    expect(find.text('1 bourse(s) trouvée(s)'), findsOneWidget);
    // The trailing action is the single « Suivre » control (chantier G): the
    // bell « M'avertir » is gone — the bell now means notifications only.
    expect(find.text('Suivre'), findsOneWidget);
    expect(find.text('M\'avertir'), findsNothing);
    expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);
    // « Mes suivis » est joignable depuis l'en-tête de l'onglet Bourses.
    expect(find.byKey(const ValueKey<String>('scholarships-followed-entry')),
        findsOneWidget);
    // La recherche globale a sa loupe ici aussi (audit build 57, T6-04).
    expect(find.byKey(const ValueKey<String>('scholarships-search-entry')),
        findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  for (final reason in <String>[
    'feature_disabled',
    'rollout_excluded',
    'country_not_eligible',
  ]) {
    testWidgets('Success Lab list entry stays hidden for $reason',
        (tester) async {
      final mock = MockApiClient();
      _stubFetch(
        mock,
        <dynamic>[_scholarshipJson()],
        successLabAccess: _access(false, reason: reason),
      );
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('scholarships-success-lab-entry'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Success Lab list entry appears only after server approval',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(
      mock,
      <dynamic>[_scholarshipJson()],
      successLabAccess: _access(true),
    );
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarships-success-lab-entry')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list entry revalidates access before navigation',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[_scholarshipJson()]);
    var accessChecks = 0;
    when(() => mock.getSuccessLabAccess()).thenAnswer((_) async {
      accessChecks += 1;
      return accessChecks == 1
          ? _access(true)
          : _access(false, reason: 'rollout_excluded');
    });
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    final entry = find.byKey(
      const ValueKey<String>('scholarships-success-lab-entry'),
    );
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(accessChecks, 2);
    expect(entry, findsNothing);
    expect(find.byType(LiveScholarshipsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping a row opens the detail sheet with the external application CTA',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[_scholarshipJson()]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MEXT Japan Scholarship'));
    await tester.pumpAndSettle();

    // Real description + funding tile carried into the detail sheet (top-visible).
    expect(find.textContaining('Full Japanese government'), findsOneWidget);
    expect(find.text('FINANCEMENT'), findsOneWidget);

    // « Postuler » (ouvre le vrai applicationUrl) vit dans la barre fixe du
    // bas de la fiche (chantier I2).
    final ctaFinder = find.text('Site officiel pour postuler');
    await tester.scrollUntilVisible(
      ctaFinder,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(ctaFinder, findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  // With every filter already dropped, an empty list means the published
  // catalog is empty — the screen must say that, not "modifie tes critères",
  // which reads as a loading failure and sends the student hunting a bug in
  // their own profile.
  testWidgets('empty results render the honest catalog-empty state',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarships-empty-catalog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('scholarships-empty-filtered')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  // The funding filter is the one filter the student can see; when it empties
  // the list, the empty state must offer the way out.
  //
  // Rendered at REAL phone geometry (393×852, the iPhone the video review was
  // recorded on) instead of the 800×600 test default. That default is not a
  // device anyone owns, and it hid a genuine question: once the guide card grew
  // a second CTA, is the escape-hatch button still reachable without scrolling?
  // Tapping it here proves it is — on the default surface it fell below the
  // fold and the tap silently missed.
  testWidgets('a funding filter that empties the list offers a way out',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mock = MockApiClient();
    whenScholarshipsPage(mock, fundingType: 'partially_funded')
        .thenAnswer((_) async => scholarshipsPage(<dynamic>[]));
    whenScholarshipsPage(mock, fundingType: null).thenAnswer(
        (_) async => scholarshipsPage(<dynamic>[_scholarshipJson()]));
    when(() => mock.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});
    when(() => mock.getSuccessLabAccess())
        .thenAnswer((_) async => _access(false, reason: 'feature_disabled'));
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();
    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);

    // Chantier I : le financement se choisit dans la feuille « Filtrer », et
    // rien ne part avant « Voir les bourses ».
    await tester.tap(
      find.byKey(const ValueKey<String>('scholarships-filter-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const ValueKey<String>('scholarships-filter-funding-partially_funded'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('scholarships-filter-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarships-empty-filtered')),
      findsOneWidget,
    );
    // Le bouton dit qu'un filtre est actif.
    expect(find.text('Filtrer · 1'), findsOneWidget);

    // The escape hatch actually clears the filter and brings the list back.
    final showAll = find.byKey(const ValueKey<String>('scholarships-show-all'));
    await tester.ensureVisible(showAll);
    await tester.pumpAndSettle();
    await tester.tap(showAll);
    await tester.pumpAndSettle();

    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide CTA opens the store-safe informational page',
      (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('En savoir plus'));
    await tester.pumpAndSettle();

    expect(find.text('Ce que tu vas apprendre'), findsOneWidget);
    expect(find.textContaining('20.000'), findsNothing);
    expect(find.textContaining('10.000'), findsNothing);
    expect(find.textContaining('Chariow'), findsNothing);
    expect(find.text('Acheter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail CTA is hidden when country eligibility is denied',
      (tester) async {
    final mock = MockApiClient();
    final scholarship = LiveScholarshipModel.fromJson(
      _scholarshipJson(withCycle: true),
    );
    _stubFetch(
      mock,
      <dynamic>[],
      successLabAccess: _access(false, reason: 'country_not_eligible'),
    );
    _stubDetail(mock, scholarship);
    await _seed(mock);

    await tester.pumpWidget(
      _wrap(
        ScholarshipDetailScreen(
          scholarshipId: scholarship.id,
          initialScholarship: scholarship,
          apiClient: mock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarship-start-success-lab')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail CTA appears only after effective access is approved',
      (tester) async {
    final mock = MockApiClient();
    final scholarship = LiveScholarshipModel.fromJson(
      _scholarshipJson(withCycle: true),
    );
    _stubFetch(
      mock,
      <dynamic>[],
      successLabAccess: _access(true),
    );
    _stubDetail(mock, scholarship);
    await _seed(mock);

    await tester.pumpWidget(
      _wrap(
        ScholarshipDetailScreen(
          scholarshipId: scholarship.id,
          initialScholarship: scholarship,
          apiClient: mock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('scholarship-start-success-lab')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail CTA revalidates access before workspace creation',
      (tester) async {
    final mock = MockApiClient();
    final scholarship = LiveScholarshipModel.fromJson(
      _scholarshipJson(withCycle: true),
    );
    _stubFetch(mock, <dynamic>[]);
    _stubDetail(mock, scholarship);
    var accessChecks = 0;
    when(() => mock.getSuccessLabAccess()).thenAnswer((_) async {
      accessChecks += 1;
      return accessChecks == 1
          ? _access(true)
          : _access(false, reason: 'feature_disabled');
    });
    await _seed(mock);

    await tester.pumpWidget(
      _wrap(
        ScholarshipDetailScreen(
          scholarshipId: scholarship.id,
          initialScholarship: scholarship,
          apiClient: mock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.byKey(
      const ValueKey<String>('scholarship-start-success-lab'),
    );
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(accessChecks, 2);
    expect(cta, findsNothing);
    verifyNever(
      () => mock.createSuccessLabWorkspace(
        scholarshipId: any(named: 'scholarshipId'),
        cycleId: any(named: 'cycleId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // Le catalogue est majoritairement composé de cycles ESTIMÉS : la plupart des
  // institutions africaines fonctionnent en admissions continues, et ni le DAAD
  // ni les consortiums Erasmus ne publient de date pour la campagne suivante.
  // L'importeur remplit quand même `deadlineAt` depuis `estimatedCloseAt` pour
  // pouvoir classer les bourses par échéance — d'où le risque d'afficher une
  // projection comme une échéance ferme.
  testWidgets('un cycle estimé n\'affiche jamais de compte à rebours',
      (tester) async {
    final mock = MockApiClient();
    final estimatedClose = DateTime.now().add(const Duration(days: 6));
    _stubFetch(mock, <dynamic>[
      <String, dynamic>{
        ..._scholarshipJson(),
        // Volontairement proche : à 6 jours, le badge confirmé afficherait
        // « J-6 » en rouge « Deadline imminente ». Rien ne doit apparaître.
        'deadlineAt': estimatedClose.toIso8601String(),
        'currentCycle': <String, dynamic>{
          'id': 'mext-2027-cycle',
          'academicYear': '2027-2028',
          'status': 'forecast',
          'dateConfidence': 'estimated',
          'estimatedOpenAt': DateTime.now()
              .subtract(const Duration(days: 20))
              .toIso8601String(),
          'estimatedCloseAt': estimatedClose.toIso8601String(),
        },
      },
    ]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    // La bourse est bien rendue — le test ne passe pas à vide.
    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
    // Aucun compte à rebours au jour près, aucune urgence fabriquée.
    expect(find.textContaining('J-'), findsNothing);
    expect(find.textContaining('Clôture proche'), findsNothing);
    // Mais la fenêtre estimée, elle, est annoncée comme telle — au mois près.
    expect(find.textContaining('Clôture estimée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── Chantier I : hors ligne, tri, petit écran ────────────────────────────
  group('chantier I', () {
    late MemoryScholarshipsOfflineStore store;

    setUp(() {
      store = MemoryScholarshipsOfflineStore();
      ScholarshipsOfflineCache.debugUse(store);
    });
    tearDown(() => ScholarshipsOfflineCache.debugUse(
          MemoryScholarshipsOfflineStore(),
        ));

    testWidgets(
        'hors ligne : la dernière liste reçue, avec « Hors ligne — données '
        'du … », à la place de l\'écran d\'erreur', (tester) async {
      final mock = MockApiClient();
      var online = true;
      whenScholarshipsPage(mock).thenAnswer((_) async {
        if (!online) {
          throw DioException(
            requestOptions: RequestOptions(path: '/scholarships'),
            type: DioExceptionType.connectionError,
          );
        }
        return scholarshipsPage(<dynamic>[_scholarshipJson(withCycle: true)]);
      });
      when(() => mock.fetchScholarshipAlerts())
          .thenAnswer((_) async => <String>{});
      when(() => mock.getSuccessLabAccess())
          .thenAnswer((_) async => _access(false, reason: 'feature_disabled'));
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();
      expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('scholarships-offline-stamp')),
        findsNothing,
      );

      online = false;
      await tester.tap(find.byTooltip('a11y_refresh'.tr));
      await tester.pumpAndSettle();

      // La liste reste, datée ; pas d'écran « Erreur de connexion ».
      expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('scholarships-offline-stamp')),
        findsOneWidget,
      );
      expect(find.textContaining('Hors ligne — données du'), findsOneWidget);
      expect(
          find.text('1 bourse(s) gardée(s) sur ton téléphone'), findsOneWidget);
      expect(find.text('Erreur de connexion'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'premier lancement hors ligne (rien sur le disque) : l\'erreur '
        'reste, avec « Réessayer »', (tester) async {
      final mock = MockApiClient();
      whenScholarshipsPage(mock).thenThrow(Exception('offline'));
      when(() => mock.fetchScholarshipAlerts())
          .thenAnswer((_) async => <String>{});
      when(() => mock.getSuccessLabAccess())
          .thenAnswer((_) async => _access(false, reason: 'feature_disabled'));
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(find.text('Erreur de connexion'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('scholarships-offline-stamp')),
        findsNothing,
      );
    });

    testWidgets(
        'serveur sans le chantier I (pas d\'écho `query`) : la liste '
        's\'affiche, « Trier » est masqué, « Filtrer » reste', (tester) async {
      final mock = MockApiClient();
      _stubFetch(mock, <dynamic>[_scholarshipJson()]);
      whenScholarshipsPage(mock).thenAnswer(
        (_) async => LiveScholarshipsPage(
          items: <dynamic>[_scholarshipJson()],
          hasMore: false,
        ),
      );
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('scholarships-sort-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('scholarships-filter-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('le tri se choisit dans sa feuille et part au serveur',
        (tester) async {
      final mock = MockApiClient();
      _stubFetch(mock, <dynamic>[_scholarshipJson()]);
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();
      expect(find.text('Trier : Pertinence pour ton profil'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('scholarships-sort-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trier par'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('scholarships-sort-deadline')),
      );
      await tester.pumpAndSettle();

      verify(
        () => mock.fetchLiveScholarshipsPage(
          lang: any(named: 'lang'),
          level: any(named: 'level'),
          fieldIds: any(named: 'fieldIds'),
          fundingType: any(named: 'fundingType'),
          statuses: any(named: 'statuses'),
          sort: ScholarshipListSort.deadline,
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
      expect(find.text('Trier : Clôture la plus proche'), findsOneWidget);
    });

    testWidgets(
        '« Filtrer » : statut coché, une requête, fermer sans valider '
        'ne change rien', (tester) async {
      final mock = MockApiClient();
      _stubFetch(mock, <dynamic>[_scholarshipJson()]);
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();
      clearInteractions(mock);

      final filter =
          find.byKey(const ValueKey<String>('scholarships-filter-button'));
      // Fermée sans valider : rien ne part.
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(
        const ValueKey<String>('scholarships-filter-status-open'),
      ));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(
        find.byKey(const ValueKey<String>('scholarships-filter-sheet')),
      )).pop();
      await tester.pumpAndSettle();
      expect(find.text('Filtrer'), findsOneWidget);

      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(
        const ValueKey<String>('scholarships-filter-status-open'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('scholarships-filter-apply')),
      );
      await tester.pumpAndSettle();

      final captured = verify(
        () => mock.fetchLiveScholarshipsPage(
          lang: any(named: 'lang'),
          level: any(named: 'level'),
          fieldIds: any(named: 'fieldIds'),
          fundingType: any(named: 'fundingType'),
          statuses: captureAny(named: 'statuses'),
          sort: any(named: 'sort'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.single, <ScholarshipListStatus>{
        ScholarshipListStatus.open,
      });
      expect(find.text('Filtrer · 1'), findsOneWidget);
    });

    testWidgets('360×640 à l\'échelle de texte 1,3 : rien ne déborde',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final mock = MockApiClient();
      _stubFetch(mock, <dynamic>[
        _scholarshipJson(withCycle: true),
        <String, dynamic>{
          ..._scholarshipJson(),
          'id': 'uk',
          'title': 'Royaume-Uni — University of Cambridge Gates Scholarship '
              'for international students',
          'countryName': 'Royaume-Uni — University of Cambridge',
          'countryId': 'gbr',
          'fundingType': 'unknown',
          'currentCycle': <String, dynamic>{
            'id': 'uk-c',
            'academicYear': '2027-2028',
            'status': 'forecast',
            'dateConfidence': 'estimated',
            'estimatedOpenAt': DateTime.utc(2027, 2, 1).toIso8601String(),
          },
        },
      ]);
      await _seed(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('🇬🇧'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Ouverture estimée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // Audit build 57, n° 1 : après « Suivre » depuis une fiche ouverte par
  // l'onglet Bourses, `AppController.update()` reconstruit la coquille pendant
  // que la fiche est empilée ; `Navigator.canPop` valait alors vrai et la flèche
  // restait après le retour. La toucher dépilait la seule page : écran noir.
  group('flèche retour de l\'onglet Bourses', () {
    Widget shellLike(MockApiClient mock) => _wrap(
          GetBuilder<AppController>(
            builder: (_) => LiveScholarshipsScreen(
              apiClient: mock,
              embeddedInShell: true,
            ),
          ),
        );

    testWidgets(
        'jamais de flèche dans la coquille, même après un update() '
        'pendant qu\'une fiche est empilée', (tester) async {
      final mock = MockApiClient();
      _stubFetch(mock, <dynamic>[_scholarshipJson()]);
      await _seed(mock);

      await tester.pumpWidget(shellLike(mock));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retour'), findsNothing);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('fiche')),
      )));
      await tester.pumpAndSettle();
      // « Suivre » sur la fiche : la coquille se reconstruit sous la fiche.
      Get.find<AppController>().update();
      await tester.pump();
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('fiche'), findsNothing);
      expect(find.byTooltip('Retour'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la flèche reste quand la liste est ouverte par un lien',
        (tester) async {
      final mock = MockApiClient();
      _stubFetch(mock, <dynamic>[_scholarshipJson()]);
      await _seed(mock);

      await tester.pumpWidget(_wrap(const Scaffold(body: Text('accueil'))));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => LiveScholarshipsScreen(apiClient: mock),
      )));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Retour'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(find.text('accueil'), findsOneWidget);
    });
  });

  // Audit build 57, T8-06 : « tirer pour rafraîchir » remplaçait la liste par
  // cinq squelettes pendant le chargement ; la liste disparaissait sous les yeux.
  testWidgets(
      'tirer pour rafraîchir garde la liste affichée pendant le '
      'chargement', (tester) async {
    final mock = MockApiClient();
    _stubFetch(mock, <dynamic>[_scholarshipJson()]);
    await _seed(mock);

    await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
    await tester.pumpAndSettle();
    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);

    // Le second chargement reste en attente : on regarde l'écran PENDANT.
    final pending = Completer<dynamic>();
    whenScholarshipsPage(mock).thenAnswer((_) async {
      await pending.future;
      return scholarshipsPage(<dynamic>[_scholarshipJson()]);
    });

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(KpbSkeletonBox), findsNothing,
        reason: 'la liste ne cède pas la place à des squelettes');
    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('MEXT Japan Scholarship'), findsOneWidget);
  });
}
