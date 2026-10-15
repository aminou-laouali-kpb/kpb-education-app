// Chantier H3 — le test « Mes 10 bourses » hors de ses propres écrans :
//   · l'accueil « Tes bourses » (3 cartes du run, compatibles d'abord, chacune
//     ouvre sa fiche), « Fais le test » sans run, la liste neutre sinon ;
//   · le héros invité « Trouve tes bourses (2 min) » derrière le drapeau ;
//   · le bloc d'évaluation de la fiche bourse ;
//   · la ligne « Nouvelles bourses compatibles » des notifications ;
//   · l'accès du Profil.
// Drapeau fermé, parent : rien de tout cela n'apparaît, aucun appel au test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/services/pending_intent_store.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/home/home_screen.dart';
import 'package:karatou/app/features/notifications/notifications_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_actions.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_results_screen.dart';
import 'package:karatou/app/features/scholarship_match/widgets/match_assessment_block.dart';

import '../../widget_test_helpers.dart';
import 'match_test_support.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Comme [pumpMatchApp], avec la route de la fiche bourse (le toucher d'une
/// carte de l'accueil y mène).
Future<AppController> _pump(
  WidgetTester tester, {
  required Widget child,
  required FakeMatchApi api,
  AppSnapshot? snapshot,
}) async {
  await tester.binding.setSurfaceSize(const Size(1080, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: snapshot ??
          AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(),
          ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = false;
  Get.put<AppController>(controller, permanent: true);
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      debugShowCheckedModeBanner: false,
      getPages: [
        GetPage(
          name: '/scholarships/:id',
          page: () => Scaffold(
            body: Text('FICHE ${Get.parameters['id']}'),
          ),
        ),
      ],
      home: child,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Un run où la première bourse est « à vérifier » : l'accueil doit pourtant
/// montrer les compatibles d'abord.
Map<String, dynamic> _runToVerifyFirst() => matchRunJson(
      items: [
        matchItemJson(
          id: 'mcf',
          name: 'Mastercard Foundation',
          section: 'to_verify',
          status: 'to_verify',
        ),
        matchItemJson(id: 'eiffel', rank: 2, name: 'Bourse Eiffel'),
        matchItemJson(
          id: 'turkiye',
          rank: 3,
          // Un nom long : deux lignes, même à 1,3×.
          name: 'Türkiye Burslari — bourses du gouvernement turc pour la '
              'licence et le master',
        ),
        matchItemJson(id: 'gone', rank: 4, name: 'Retirée', available: false),
        matchItemJson(id: 'chevening', rank: 5, name: 'Chevening'),
      ],
    );

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first);

void main() {
  tearDown(tearDownMatchWorld);

  group('accueil', () {
    testWidgets(
        'homeRunItems : compatibles d\'abord, jamais une bourse '
        'retirée, 3 au plus', (t) async {
      final run = MatchRun.fromJson(_runToVerifyFirst())!;
      expect(homeRunItems(run).map((i) => i.scholarshipId),
          ['eiffel', 'turkiye', 'chevening']);
      final few = MatchRun.fromJson(matchRunJson(items: [
        matchItemJson(id: 'a', section: 'to_verify', status: 'to_verify'),
      ]))!;
      expect(homeRunItems(few).map((i) => i.scholarshipId), ['a']);
    });

    testWidgets(
        'élève avec un run : « Tes bourses », 3 cartes, la fiche au '
        'toucher', (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: _runToVerifyFirst()));
      await _pump(t, child: const HomeScreen(), api: api);

      final section = find.byKey(const ValueKey<String>('home-match-section'));
      await _scrollTo(t, section);
      expect(find.text('Tes bourses'), findsOneWidget);
      expect(find.text('Bourses à suivre'), findsNothing);
      expect(find.text('Voir mes 5 bourses'), findsOneWidget);
      for (final id in ['eiffel', 'turkiye', 'chevening']) {
        expect(find.byKey(ValueKey<String>('home-match-card-$id')),
            findsOneWidget);
      }
      expect(find.byKey(const ValueKey<String>('home-match-card-mcf')),
          findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('home-match-status-eiffel')),
          matching: find.text('Compatible'),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: section, matching: find.textContaining('%')),
          findsNothing);

      await t.tap(find.byKey(const ValueKey<String>('home-match-card-eiffel')));
      await t.pumpAndSettle();
      expect(find.text('FICHE eiffel'), findsOneWidget);
    });

    testWidgets('texte à 1,3× : les cartes du run ne débordent pas', (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: _runToVerifyFirst()));
      await _pump(
        t,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const HomeScreen(),
          ),
        ),
        api: api,
      );
      final card =
          find.byKey(const ValueKey<String>('home-match-card-turkiye'));
      await _scrollTo(t, card);
      expect(card, findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('« Voir mes N bourses » ouvre les résultats', (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: _runToVerifyFirst()));
      await _pump(t, child: const HomeScreen(), api: api);
      final seeAll = find.byKey(const ValueKey<String>('home-match-see-all'));
      await _scrollTo(t, seeAll);
      await t.tap(seeAll);
      await t.pumpAndSettle();
      expect(find.text('Compatibles avec ton profil'), findsOneWidget);
    });

    testWidgets('élève sans run : la carte « Fais le test »', (t) async {
      resetMatchWorld();
      final api = FakeMatchApi();
      await _pump(t, child: const HomeScreen(), api: api);
      final card =
          find.byKey(const ValueKey<String>('scholarship-match-entry-noRun'));
      await _scrollTo(t, card);
      expect(card, findsOneWidget);
      expect(find.text('Faire le test'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('home-match-section')),
          findsNothing);
      expect(api.stateCalls, 1);
    });

    for (final (label, flag, snapshot) in <(String, bool, AppSnapshot?)>[
      ('drapeau fermé', false, null),
      ('parent', true, parentSnapshot()),
    ]) {
      testWidgets('$label : la liste neutre, aucun appel au test', (t) async {
        resetMatchWorld(flag: flag);
        final api =
            FakeMatchApi(state: matchStateJson(latestRun: _runToVerifyFirst()));
        final controller = await _pump(t,
            child: const HomeScreen(), api: api, snapshot: snapshot);
        // Le catalogue embarqué des tests ne porte aucune bourse : on en sème
        // une pour que la liste neutre existe.
        controller.scholarships.add(const ScholarshipModel(
          id: 'sch-neutral',
          name: LocalizedText(fr: 'Bourse neutre', en: 'Neutral'),
          countryId: 'canada',
          levelEligible: LocalizedText(fr: '', en: ''),
          typeOfFunding: LocalizedText(fr: 'Partielle', en: 'Partial'),
          deadlineLabel: LocalizedText(fr: '', en: ''),
          keyRequirements: [],
          relatedFieldIds: [],
          baseMatch: 78,
        ));
        controller.update();
        await t.pumpAndSettle();
        final neutral = find.text('Bourses à suivre');
        await _scrollTo(t, neutral);
        expect(neutral, findsOneWidget);
        expect(find.text('Bourse neutre'), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('home-match-section')),
            findsNothing);
        expect(find.textContaining('Faire le test'), findsNothing);
        expect(find.text('Tes bourses'), findsNothing);
        expect(find.text('Compatible'), findsNothing);
        expect(api.stateCalls, 0);
      });
    }
  });

  group('héros invité', () {
    testWidgets('drapeau fermé : « Trouve tes bourses » vers l\'onglet Bourses',
        (t) async {
      resetMatchWorld(flag: false);
      await _pump(t,
          child: const HomeScreen(),
          api: FakeMatchApi(),
          snapshot: guestSnapshot());
      final cta = find.byKey(const ValueKey<String>('home-hero-guest-cta'));
      expect(
          find.descendant(of: cta, matching: find.text('Trouve tes bourses')),
          findsOneWidget);
      expect(find.textContaining('(2 min)'), findsNothing);
    });

    testWidgets('drapeau ouvert : « (2 min) » et l\'intention vers le test',
        (t) async {
      resetMatchWorld();
      final controller = await _pump(t,
          child: const HomeScreen(),
          api: FakeMatchApi(),
          snapshot: guestSnapshot());
      final cta = find.byKey(const ValueKey<String>('home-hero-guest-cta'));
      expect(
          find.descendant(
              of: cta, matching: find.text('Trouve tes bourses (2 min)')),
          findsOneWidget);

      // L'inscription passe par l'écran de démarrage, qui lit AuthService.
      final auth = _MockAuthService();
      when(() => auth.onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());
      when(() => auth.isLoggedIn).thenReturn(false);
      Get.put<AuthService>(auth, permanent: true);

      await t.tap(cta);
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(controller.isGuestMode, isFalse);
      final intent = await PendingIntentStore.consume();
      expect(intent?.route, scholarshipMatchRoute);
      expect(intent?.source, 'home_hero_scholarship_match');
    });
  });

  group('fiche bourse : bloc d\'évaluation', () {
    Widget host(String id) => Scaffold(
          body: SingleChildScrollView(
            child: ScholarshipMatchAssessmentBlock(scholarshipId: id),
          ),
        );

    testWidgets(
        'bourse « à vérifier » du run : statut, point à vérifier, '
        'condition officielle', (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
      await _pump(t, child: host('mcf'), api: api);
      expect(find.text('Ton résultat au test'), findsOneWidget);
      expect(find.text('D\'après ton test du 13/10'), findsOneWidget);
      expect(find.text('À vérifier'), findsOneWidget);
      expect(find.text('IELTS 6.5 demandé — tu n’as pas indiqué de score'),
          findsOneWidget);
      // La citation officielle (« 70 % ») reste fermée tant qu'on ne l'ouvre
      // pas — c'est le seul « % » possible, et c'est celui de l'organisme.
      expect(find.textContaining('%'), findsNothing);
      await t.tap(find.text('Voir la condition officielle'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('match-official-text')),
          findsOneWidget);
    });

    testWidgets('bourse compatible du run : ses raisons', (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
      await _pump(t, child: host('eiffel'), api: api);
      expect(find.text('Compatible'), findsOneWidget);
      expect(find.text('Ouverte aux ressortissants du Niger'), findsOneWidget);
      expect(find.text('Niveau Master accepté'), findsOneWidget);
    });

    testWidgets('bourse absente du run : dit qu\'elle n\'y est pas, et le run',
        (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
      await _pump(t, child: host('autre'), api: api);
      expect(
          find.text('Cette bourse ne fait pas partie de tes résultats du '
              'test.'),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>('scholarship-match-entry-hasRun')),
          findsOneWidget);
      expect(find.text('Ton résultat au test'), findsNothing);
    });

    testWidgets('pas de run : l\'invitation à faire le test', (t) async {
      resetMatchWorld();
      await _pump(t, child: host('eiffel'), api: FakeMatchApi());
      expect(
          find.byKey(const ValueKey<String>('scholarship-match-entry-noRun')),
          findsOneWidget);
    });

    for (final (label, flag, snapshot) in <(String, bool, AppSnapshot?)>[
      ('drapeau fermé', false, null),
      ('parent', true, parentSnapshot()),
    ]) {
      testWidgets('$label : rien, aucun appel', (t) async {
        resetMatchWorld(flag: flag);
        final api =
            FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
        await _pump(t, child: host('eiffel'), api: api, snapshot: snapshot);
        expect(find.byType(Text), findsNothing);
        expect(api.stateCalls, 0);
      });
    }
  });

  group('notifications : « Nouvelles bourses compatibles »', () {
    const row = ValueKey<String>('notif-pref-scholarship-match');

    testWidgets('élève, test ouvert : opt-in explicite, PUT alerts', (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
      await _pump(t, child: const NotificationsScreen(), api: api);
      await _scrollTo(t, find.byKey(row));
      expect(
          find.text('Nouvelles bourses compatibles (hebdo)'), findsOneWidget);
      final toggle =
          find.descendant(of: find.byKey(row), matching: find.byType(Switch));
      expect(t.widget<Switch>(toggle).value, isFalse);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(api.alertCalls, [true]);
      expect(t.widget<Switch>(toggle).value, isTrue);
    });

    testWidgets('échec du PUT : l\'interrupteur revient', (t) async {
      resetMatchWorld();
      final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()))
        ..alertsError = const ScholarshipMatchException(
          ScholarshipMatchFailure.server,
        );
      await _pump(t, child: const NotificationsScreen(), api: api);
      await _scrollTo(t, find.byKey(row));
      final toggle =
          find.descendant(of: find.byKey(row), matching: find.byType(Switch));
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(t.widget<Switch>(toggle).value, isFalse);
      expect(find.text('Le réglage n\'a pas été enregistré. Réessaie.'),
          findsOneWidget);
    });

    for (final (label, flag, snapshot) in <(String, bool, AppSnapshot?)>[
      ('drapeau fermé', false, null),
      ('parent', true, parentSnapshot()),
    ]) {
      testWidgets('$label : pas de ligne, aucun appel', (t) async {
        resetMatchWorld(flag: flag);
        final api = FakeMatchApi();
        await _pump(t,
            child: const NotificationsScreen(), api: api, snapshot: snapshot);
        // Les préférences sont bien construites (la ligne qui précède).
        await _scrollTo(t, find.text('Récit de la semaine'));
        expect(find.byKey(row), findsNothing);
        expect(api.stateCalls, 0);
      });
    }
  });

  group('Profil : « Mes bourses compatibles »', () {
    Future<void> pumpProfile(WidgetTester t, FakeMatchApi api,
        {AppSnapshot? snapshot}) async {
      await _pump(t,
          child: const ProfileScreen(), api: api, snapshot: snapshot);
    }

    testWidgets('élève, test ouvert : la ligne ouvre les résultats', (t) async {
      resetMatchWorld();
      final api =
          FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
      await pumpProfile(t, api);
      final entry = find.text('Mes bourses compatibles');
      await _scrollTo(t, entry);
      await t.tap(entry);
      await t.pumpAndSettle();
      expect(find.byType(ScholarshipMatchResultsScreen), findsOneWidget);
    });

    for (final (label, flag, snapshot) in <(String, bool, AppSnapshot?)>[
      ('drapeau fermé', false, null),
      ('parent', true, parentSnapshot()),
    ]) {
      testWidgets('$label : pas de ligne', (t) async {
        resetMatchWorld(flag: flag);
        await pumpProfile(t, FakeMatchApi(), snapshot: snapshot);
        // Les accès rapides sont bien construits (la ligne qui suit toujours).
        await _scrollTo(t, find.text('Services KPB (Dossier prêt)'));
        expect(find.text('Mes bourses compatibles'), findsNothing);
      });
    }
  });
}
