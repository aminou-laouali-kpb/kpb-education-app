// La visite guidée de l'application (build 59).
//
// ## Ce que le propriétaire a demandé
//
// Un tutoriel en direct, à la première connexion, qui montre à l'élève où se
// trouve chaque chose ; « quand il clique, c'est bon, j'ai compris, ça ne
// s'affiche plus » ; très détaillé, pour des élèves peu à l'aise avec un
// téléphone.
//
// ## Ce que ce fichier verrouille
//
// - elle s'ouvre seule la première fois, et plus jamais une fois fermée ;
// - une panne du stockage ne la fait jamais revenir en boucle ;
// - elle ne s'ouvre pas par-dessus un autre écran ;
// - elle éclaire le vrai bouton, montre l'onglet dont elle parle, et rend
//   l'élève là où il était ;
// - « Passer » lui dit où la retrouver ;
// - elle ne nomme que les outils présents, et chaque texte existe en français
//   et en anglais.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/navigation/shell_tabs.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/translations/app_translations_en.dart';
import 'package:karatou/app/core/translations/app_translations_fr.dart';
import 'package:karatou/app/features/app_tour/app_tour.dart';
import 'package:karatou/app/features/app_tour/app_tour_store.dart';

class _Store implements AppTourStore {
  _Store({this.seen = false, this.failRead = false, this.failWrite = false});

  bool seen;
  bool failRead;
  bool failWrite;
  int writes = 0;

  @override
  Future<bool> hasBeenSeen() async {
    if (failRead) throw StateError('lecture impossible');
    return seen;
  }

  @override
  Future<void> markSeen() async {
    writes++;
    if (failWrite) throw StateError('écriture impossible');
    seen = true;
  }
}

class _Analytics implements AppTourAnalytics {
  final shownTriggers = <String>[];
  final completedCalls = <({String exit, int seen, int total})>[];

  @override
  void shown({required String trigger}) => shownTriggers.add(trigger);

  @override
  void completed({
    required String exit,
    required int stepsSeen,
    required int stepsTotal,
  }) =>
      completedCalls.add((exit: exit, seen: stepsSeen, total: stepsTotal));
}

const _tools = <AppTourTool>[
  (labelKey: 'tools_doc_scanner', icon: Icons.scanner, color: Colors.blue),
  (labelKey: 'tools_budget', icon: Icons.savings, color: Colors.green),
];

/// Un shell minimal : les cinq onglets, le ☰ et le bouton KPB Intelligence,
/// chacun porteur de la clé que la visite éclaire.
class _Shell extends StatefulWidget {
  const _Shell({this.coach = true});
  final bool coach;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> implements AppTourHost {
  final AppTourTargets _targets = AppTourTargets();
  int tab = StudentShellTab.home;
  final List<int> visited = <int>[];

  @override
  AppTourTargets get targets => _targets;

  @override
  int get currentTab => tab;

  @override
  void goToTab(int t) {
    visited.add(t);
    setState(() => tab = t);
  }

  @override
  bool get coachVisible => widget.coach;

  @override
  List<AppTourTool> get tools => _tools;

  @override
  String get firstName => 'Awa';

  @override
  Widget build(BuildContext context) {
    Widget nav(GlobalKey key, String label) => Expanded(
          child: SizedBox(key: key, height: 60, child: Text(label)),
        );
    return Scaffold(
      body: Stack(
        children: [
          Center(child: Text('onglet $tab')),
          if (tab == StudentShellTab.home)
            Positioned(
              top: 40,
              left: 8,
              child: SizedBox(key: _targets.tools, width: 48, height: 48),
            ),
          if (tab != StudentShellTab.home && widget.coach)
            Positioned(
              right: 16,
              bottom: 90,
              child: SizedBox(key: _targets.coach, width: 160, height: 48),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: [
                nav(_targets.home, 'A'),
                nav(_targets.universities, 'U'),
                nav(_targets.scholarships, 'B'),
                nav(_targets.cases, 'D'),
                nav(_targets.profile, 'P'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  late _Store store;
  late _Analytics analytics;

  setUp(() {
    AppTour.resetForTest();
    store = _Store();
    analytics = _Analytics();
    AppTour.store = store;
    AppTour.analytics = analytics;
    AppTour.autoStartEnabled = true;
    AppTour.autoStartDelay = Duration.zero;
  });

  tearDown(() {
    AppTour.resetForTest();
    Get.reset();
  });

  Future<_ShellState> pumpShell(WidgetTester tester,
      {bool coach = true}) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      // L'anneau pulse sans fin : « réduire les animations » l'arrête, sinon
      // `pumpAndSettle` n'aboutirait jamais.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: _Shell(coach: coach),
    ));
    return tester.state<_ShellState>(find.byType(_Shell));
  }

  Future<void> autoStart(WidgetTester tester, _ShellState shell) async {
    unawaited(AppTour.autoStart(shell));
    await tester.pumpAndSettle();
  }

  Finder card(String id) => find.byKey(ValueKey('app-tour-card-$id'));

  testWidgets('première arrivée : la visite s\'ouvre sur la bienvenue',
      (tester) async {
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);

    expect(card('welcome'), findsOneWidget);
    expect(find.text('Bienvenue, Awa !'), findsOneWidget);
    expect(find.text('Étape 1 sur 9'), findsOneWidget);
    expect(analytics.shownTriggers, ['first_open']);
    // Rien n'est écrit tant que l'élève n'a pas fermé la visite.
    expect(store.writes, 0);
  });

  testWidgets(
      'jusqu\'au bout : chaque onglet est montré, « J\'ai compris » ferme, '
      'le drapeau est écrit et l\'élève revient sur l\'accueil',
      (tester) async {
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);

    final order = <String>[];
    for (var i = 0; i < 9; i++) {
      final step = AppTour.stepsFor(coachVisible: true)[i];
      expect(card(step.id), findsOneWidget, reason: step.id);
      order.add(step.id);
      expect(shell.tab, step.tab, reason: 'onglet de ${step.id}');
      await tester.tap(find.byKey(const ValueKey('app-tour-next')));
      await tester.pumpAndSettle();
    }

    expect(order, [
      'welcome',
      'home',
      'tools',
      'universities',
      'scholarships',
      'coach',
      'cases',
      'profile',
      'done',
    ]);
    expect(find.byKey(const ValueKey('app-tour')), findsNothing);
    expect(store.seen, isTrue);
    expect(
        analytics.completedCalls.single, (exit: 'finished', seen: 9, total: 9));
    expect(shell.tab, StudentShellTab.home);
    // Pas de rappel « Passer » quand l'élève est allé au bout.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('déjà fermée sur cet appareil : elle ne revient pas',
      (tester) async {
    store.seen = true;
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);

    expect(find.byKey(const ValueKey('app-tour')), findsNothing);
    expect(analytics.shownTriggers, isEmpty);
  });

  testWidgets('stockage illisible : elle ne s\'ouvre pas', (tester) async {
    store.failRead = true;
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);

    expect(find.byKey(const ValueKey('app-tour')), findsNothing);
  });

  testWidgets(
      'écriture en panne : la visite ne revient pas une 2e fois dans la '
      'même session', (tester) async {
    store.failWrite = true;
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);
    await tester.tap(find.byKey(const ValueKey('app-tour-skip')));
    await tester.pumpAndSettle();

    await autoStart(tester, shell);
    expect(find.byKey(const ValueKey('app-tour')), findsNothing);
    expect(analytics.shownTriggers, hasLength(1));
  });

  testWidgets('un autre écran est ouvert : elle attend', (tester) async {
    final shell = await pumpShell(tester);
    unawaited(Navigator.of(shell.context).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('autre écran')),
    )));
    await tester.pumpAndSettle();
    await autoStart(tester, shell);

    expect(find.byKey(const ValueKey('app-tour')), findsNothing);
    expect(analytics.shownTriggers, isEmpty);
  });

  testWidgets(
      '« Passer » ferme, écrit le drapeau et dit où retrouver la visite',
      (tester) async {
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);
    await tester.tap(find.byKey(const ValueKey('app-tour-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-tour-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-tour')), findsNothing);
    expect(store.seen, isTrue);
    expect(
        analytics.completedCalls.single, (exit: 'skipped', seen: 2, total: 9));
    expect(find.textContaining('Revoir la visite'), findsOneWidget);
  });

  testWidgets('« Retour » et le retour du téléphone reviennent d\'une étape',
      (tester) async {
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);
    await tester.tap(find.byKey(const ValueKey('app-tour-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-tour-next')));
    await tester.pumpAndSettle();
    expect(card('tools'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-tour-back')));
    await tester.pumpAndSettle();
    expect(card('home'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(card('welcome'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tour-back')), findsNothing);
  });

  testWidgets('un tap sur le voile ne ferme pas la visite', (tester) async {
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(card('welcome'), findsOneWidget);
  });

  testWidgets('le menu ☰ ne cite que les outils affichés, avec leur rôle',
      (tester) async {
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('app-tour-next')));
      await tester.pumpAndSettle();
    }

    expect(card('tools'), findsOneWidget);
    expect(find.textContaining('Scanner de documents'), findsOneWidget);
    expect(find.textContaining('Calculateur de budget'), findsOneWidget);
    expect(find.textContaining('CV'), findsNothing);
  });

  testWidgets('sans bouton KPB Intelligence, l\'étape disparaît',
      (tester) async {
    final shell = await pumpShell(tester, coach: false);
    await autoStart(tester, shell);

    expect(find.text('Étape 1 sur 8'), findsOneWidget);
    expect(AppTour.stepsFor(coachVisible: false),
        isNot(contains(AppTourStep.coach)));
  });

  testWidgets('« Revoir la visite » la rejoue et rend l\'élève au Profil',
      (tester) async {
    store.seen = true;
    final shell = await pumpShell(tester);
    shell.goToTab(StudentShellTab.profile);
    AppTour.registerHost(shell);
    await tester.pumpAndSettle();

    unawaited(AppTour.replay());
    await tester.pumpAndSettle();
    expect(card('welcome'), findsOneWidget);
    expect(analytics.shownTriggers, ['replay']);

    await tester.tap(find.byKey(const ValueKey('app-tour-skip')));
    await tester.pumpAndSettle();
    expect(shell.tab, StudentShellTab.profile);
  });

  testWidgets('le bouton expliqué est bien éclairé (bulle au-dessus de lui)',
      (tester) async {
    final shell = await pumpShell(tester);
    await autoStart(tester, shell);
    await tester.tap(find.byKey(const ValueKey('app-tour-next')));
    await tester.pumpAndSettle();

    // Étape « Accueil » : l'onglet est en bas, la bulle doit être au-dessus.
    final tab = tester.getRect(find.byKey(shell.targets.home));
    final bubble = tester.getRect(card('home'));
    expect(bubble.bottom, lessThanOrEqualTo(tab.top));
  });

  group('textes', () {
    const toolKeys = [
      'eef_title',
      'tools_cv',
      'tools_motivation_letter',
      'tools_interview',
      'tools_doc_scanner',
      'tools_doc_review',
      'tools_budget',
      'tools_flight',
      'tools_housing',
      'tools_impact',
    ];

    final keys = <String>[
      for (final s in AppTourStep.values) ...[s.titleKey, s.bodyKey],
      for (final t in toolKeys) appTourToolDescriptionKey(t),
      'app_tour_title',
      'app_tour_step_counter',
      'app_tour_skip',
      'app_tour_back',
      'app_tour_next',
      'app_tour_start',
      'app_tour_finish',
      'app_tour_skipped_hint',
      'app_tour_welcome_title_named',
      'app_tour_profile_card_title',
      'app_tour_profile_card_body',
      'app_tour_replay',
    ];

    test('chaque texte existe en français et en anglais', () {
      for (final k in keys) {
        expect(appTranslationsFr[k], isNotNull, reason: 'FR $k');
        expect(appTranslationsEn[k], isNotNull, reason: 'EN $k');
      }
    });

    test('la visite renvoie à « Revoir la visite » sous ce nom exact', () {
      expect(appTranslationsFr['app_tour_done_body'],
          contains('« ${appTranslationsFr['app_tour_replay']} »'));
      expect(appTranslationsEn['app_tour_done_body'],
          contains('“${appTranslationsEn['app_tour_replay']}”'));
    });
  });
}
