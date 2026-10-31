// Chantier K — l'accueil « Ta prochaine étape » :
//   · UNE carte « prochaine étape » (anneau + action) en tête pour l'élève ;
//   · les blocs dans l'ordre : bourses, échéances, partenaires, KPB
//     Intelligence, Parcours, conseiller ; chacun derrière un interrupteur ;
//   · les raccourcis qui doublaient les onglets ont disparu ;
//   · un bloc dont l'appel réseau échoue se replie (hauteur nulle) —
//     `/impact/stats` en 404 compris ;
//   · parents et invités : pas de carte élève ; drapeau `scholarshipMatch`
//     ouvert / fermé ;
//   · boutons d'en-tête à 48 dp, texte ≥ 12 sp, 360×640 à 1,3 sans
//     débordement, pas d'animation en cascade.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/navigation/shell_tabs.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/home/home_impact_proof.dart';
import 'package:karatou/app/features/home/home_screen.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';
import 'package:karatou/app/features/partners/partners_strip.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_flow_screen.dart';

import '../../widget_test_helpers.dart';
import '../scholarship_match/match_test_support.dart';

DioException _http(String path, int status) => DioException(
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
      ),
      type: DioExceptionType.badResponse,
    );

/// Le serveur de l'accueil : par défaut, TOUT échoue (`/impact/stats` en
/// 404, partenaires en 500, aucun parcours).
class _HomeApi extends FakeMatchApi {
  _HomeApi({this.impact, this.partners, this.stories = const []})
      : super(state: matchStateJson());

  final Map<String, dynamic>? impact;
  final List<dynamic>? partners;
  final List<ParcoursStory> stories;
  final List<String> paths = <String>[];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    paths.add(path);
    final data = impact;
    if (path == '/impact/stats' && data != null) return data;
    throw _http(path, 404);
  }

  @override
  Future<List<dynamic>> listFeaturedPartners({int limit = 12}) async {
    paths.add('/partners/featured');
    final items = partners;
    if (items == null) throw _http('/partners/featured', 500);
    return items;
  }

  @override
  Future<List<ParcoursStory>> listParcoursStories() async => stories;

  @override
  Future<int> fetchUnreadNotificationCount() async => 0;
}

AppSnapshot _student({List<StudentCase> cases = const []}) => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(),
      cases: cases,
    );

AppSnapshot _parent({List<StudentCase> cases = const []}) => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(accountType: AccountType.parent),
      cases: cases,
    );

AppSnapshot _partner() => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(accountType: AccountType.partner),
    );

const AppSnapshot _guest = AppSnapshot(
  localeCode: 'fr',
  hasCompletedOnboarding: false,
  isGuestMode: true,
);

Future<AppController> _pump(
  WidgetTester tester, {
  required AppSnapshot snapshot,
  _HomeApi? api,
  Size size = const Size(393, 4000),
  double textScale = 1.0,
  bool remoteSync = false,
  bool translated = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: api ?? _HomeApi(),
  );
  await controller.hydrate();
  // Après l'hydratation : sinon `hydrate()` lancerait une synchro complète.
  AppConfig.enableRemoteSyncOverride = remoteSync;
  Get.put<AppController>(controller, permanent: true);
  await tester.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: translated ? AppTranslations() : null,
      locale: translated ? const Locale('fr') : null,
      getPages: [
        GetPage(name: '/saved', page: () => const Text('page-mes-suivis')),
        GetPage(name: '/search', page: () => const Text('page-recherche')),
        GetPage(name: '/deadlines', page: () => const Text('page-echeances')),
        GetPage(
          name: '/scholarships/:id',
          page: () => Text('FICHE ${Get.parameters['id']}'),
        ),
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const Scaffold(drawer: Drawer(), body: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

ScholarshipModel _scholarship(String id, {int? inDays}) => ScholarshipModel(
      id: id,
      name: LocalizedText(fr: 'Bourse $id', en: 'Scholarship $id'),
      countryId: 'france',
      levelEligible: const LocalizedText(fr: '', en: ''),
      typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: const LocalizedText(fr: '', en: ''),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 0,
      deadlineAt:
          inDays == null ? null : DateTime.now().add(Duration(days: inDays)),
    );

StudentCase _case(String id, CaseStatus status) {
  final now = DateTime.now();
  return StudentCase(
    id: id,
    referenceCode: 'KPB-$id',
    title: LocalizedText(fr: 'Dossier $id', en: 'Case $id'),
    description: const LocalizedText(fr: '', en: ''),
    contextLabel: const LocalizedText(fr: '', en: ''),
    status: status,
    type: CaseType.applicationSupport,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: now,
    updatedAt: now,
    nextStepTitle: LocalizedText(fr: 'Étape $id', en: 'Step $id'),
    nextStepDescription: const LocalizedText(fr: '', en: ''),
    timeline: const [],
    messages: const [],
    documentRequests: const [],
  );
}

ParcoursStory _story(String id) => ParcoursStory(
      id: id,
      slug: id,
      kind: ParcoursKind.text,
      personName: 'Awa',
      title: LocalizedText(fr: 'Parcours $id', en: 'Story $id'),
    );

final List<StudentCase> _twoCases = [
  _case('c1', CaseStatus.documentsNeeded),
  _case('c2', CaseStatus.inProgress),
];

Finder _block(HomeBlock block) => find.byKey(block.key);

/// Les blocs RENDUS, de haut en bas.
List<HomeBlock> _renderedOrder(WidgetTester tester) {
  // Un bloc replié (hauteur nulle) n'est pas « rendu ».
  final present = HomeBlock.values
      .where((b) =>
          _block(b).evaluate().isNotEmpty &&
          tester.getSize(_block(b)).height > 0)
      .toList()
    ..sort((a, b) => tester
        .getTopLeft(_block(a))
        .dy
        .compareTo(tester.getTopLeft(_block(b)).dy));
  return present;
}

double _height(WidgetTester tester, Finder finder) =>
    tester.getSize(finder).height;

void main() {
  setUp(() {
    resetMatchWorld(flag: false);
  });
  tearDown(tearDownMatchWorld);

  group('ordre des blocs', () {
    testWidgets(
        'élève : prochaine étape, bourses, échéances, partenaires, '
        'Intelligence, Parcours, conseiller', (tester) async {
      final api = _HomeApi(
        impact: const {'studentsGuided': 120, 'admissionsSecured': 14},
        partners: const [
          {'nameFr': 'Campus France', 'logoUrl': '', 'websiteUrl': ''},
        ],
        stories: [_story('awa')],
      );
      final controller = await _pump(
        tester,
        snapshot: _student(cases: [_case('c1', CaseStatus.inProgress)]),
        api: api,
        size: const Size(393, 6000),
        remoteSync: true,
      );
      controller.scholarships.add(_scholarship('soon', inDays: 5));
      controller.update();
      await tester.pumpAndSettle();

      expect(_renderedOrder(tester), [
        HomeBlock.nextStep,
        HomeBlock.scholarships,
        HomeBlock.deadlines,
        HomeBlock.partners,
        HomeBlock.intelligence,
        HomeBlock.parcours,
        HomeBlock.counselor,
      ]);
      // Un seul de chaque, et sept blocs au plus.
      for (final b in HomeBlock.values) {
        expect(_block(b).evaluate().length, lessThanOrEqualTo(1));
      }
      // Les blocs réseau ont bien rendu leur contenu.
      expect(find.text('Campus France'), findsOneWidget);
      expect(find.text('impact_proof_title'), findsOneWidget);
      expect(find.text('Parcours awa'), findsOneWidget);
      // « Tes échéances » : la date urgente (calcul unique) et le dossier.
      expect(find.byKey(const ValueKey('home-deadline-scholarship-soon')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('home-deadline-case-c1')), findsOneWidget);
    });

    test('homeBlocksFor : rôle par rôle', () async {
      Future<List<HomeBlock>> blocksOf(AppSnapshot snapshot) async {
        final controller = AppController(
          repository: FakeRepository(snapshot: snapshot),
          apiClient: _HomeApi(),
        );
        await controller.hydrate();
        return homeBlocksFor(controller);
      }

      expect(await blocksOf(_student()), [
        HomeBlock.nextStep,
        HomeBlock.eef,
        HomeBlock.scholarships,
        HomeBlock.deadlines,
        HomeBlock.partners,
        HomeBlock.intelligence,
        HomeBlock.parcours,
        HomeBlock.counselor,
      ]);
      expect(await blocksOf(_parent()), [
        HomeBlock.roleHero,
        HomeBlock.eef,
        HomeBlock.scholarships,
        HomeBlock.partners,
        HomeBlock.intelligence,
        HomeBlock.parcours,
        HomeBlock.counselor,
      ]);
      expect(await blocksOf(_guest), [
        HomeBlock.roleHero,
        HomeBlock.eef,
        HomeBlock.partners,
        HomeBlock.intelligence,
        HomeBlock.parcours,
        HomeBlock.counselor,
      ]);
      expect(await blocksOf(_partner()), [
        HomeBlock.roleHero,
        HomeBlock.eef,
        HomeBlock.partners,
        HomeBlock.intelligence,
        HomeBlock.counselor,
      ]);
    });

    test('chaque bloc tombe avec son interrupteur', () async {
      final controller = AppController(
        repository: FakeRepository(snapshot: _student()),
        apiClient: _HomeApi(),
      );
      await controller.hydrate();
      for (final block in HomeBlock.values) {
        final key = block.flagKey;
        if (key == null) continue;
        RemoteFeatureFlags.instance.debugSetFeaturesForTest({key: false});
        expect(homeBlocksFor(controller), isNot(contains(block)),
            reason: '$key: false doit retirer $block');
      }
      RemoteFeatureFlags.resetForTest();
    });
  });

  group('replis : un appel en échec ne laisse ni trou ni erreur', () {
    testWidgets(
        '/impact/stats en 404, partenaires en 500, aucun parcours : '
        'les blocs ont une hauteur nulle', (tester) async {
      final api = _HomeApi();
      await _pump(tester, snapshot: _student(), api: api, remoteSync: true);

      expect(api.paths, contains('/impact/stats'));
      expect(api.paths, contains('/partners/featured'));
      expect(find.byType(HomeImpactProof), findsOneWidget);
      expect(_height(tester, find.byType(HomeImpactProof)), 0);
      expect(_height(tester, find.byType(PartnersStrip)), 0);
      expect(_height(tester, _block(HomeBlock.partners)), 0);
      expect(_height(tester, _block(HomeBlock.parcours)), 0);
      expect(find.text('impact_proof_title'), findsNothing);
      expect(
          find.byWidgetPredicate(
              (w) => w is CircularProgressIndicator && w.value == null),
          findsNothing,
          reason: 'jamais un spinner seul pendant le chargement');
      expect(find.byType(KpbErrorState), findsNothing);
      expect(tester.takeException(), isNull);

      // Pas de trou : Intelligence suit directement la fin de la section
      // précédente (les blocs repliés ne portent aucun espace).
      final intelligenceTop = tester.getTopLeft(_block(HomeBlock.intelligence));
      final partnersTop = tester.getTopLeft(_block(HomeBlock.partners));
      expect(intelligenceTop.dy, partnersTop.dy);
    });

    testWidgets('« Tes échéances » sans rien à dire : pas de section',
        (tester) async {
      await _pump(tester, snapshot: _student());
      expect(_block(HomeBlock.deadlines), findsNothing);
      expect(find.text('home_deadlines_title'), findsNothing);
    });
  });

  group('raccourcis supprimés et en-tête', () {
    testWidgets(
        'plus de tuiles qui doublent les onglets, plus de cascade, une '
        'seule entrée KPB Intelligence', (tester) async {
      await _pump(tester, snapshot: _student());

      expect(find.byType(QuickActionTile), findsNothing);
      expect(find.text('home_design_tools_title'), findsNothing);
      expect(find.text('home_quick_action_scholarships'), findsNothing);
      expect(find.text('home_quick_action_cases'), findsNothing);
      expect(find.text('home_recommended_universities_title'), findsNothing);
      expect(find.text('home_student_tools_title'), findsNothing);
      expect(find.text('register_abroad_title'), findsNothing);
      expect(find.text('my_plan_title'), findsNothing);
      expect(find.text('home_gauge_eyebrow'), findsNothing);
      expect(find.byType(StaggeredSlide), findsNothing);
      // L'assistant : une seule entrée, dans le corps (plus dans l'en-tête).
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey('home-intelligence-entry')),
          findsOneWidget);
    });

    testWidgets('les boutons de l\'en-tête font 48 dp', (tester) async {
      await _pump(tester, snapshot: _student());
      final bar = find.byType(SliverAppBar);
      final bell = find.descendant(
          of: bar, matching: find.byKey(const ValueKey('home-bell')));
      final followed = find.byKey(const ValueKey('home-followed-entry'));
      final search = find.byKey(const ValueKey('home-search-entry'));
      expect(bell, findsOneWidget);
      for (final button in [bell, followed, search]) {
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    // Audit build 57, T6-04 : la recherche globale n'avait aucune porte visible.
    testWidgets('une loupe dans l\'en-tête ouvre la recherche', (tester) async {
      await _pump(tester, snapshot: _student());
      await tester.tap(find.byKey(const ValueKey('home-search-entry')));
      await tester.pumpAndSettle();
      expect(find.text('page-recherche'), findsOneWidget);
    });

    testWidgets(
        'iPhone SE, texte 1,5 : trois boutons et la salutation, sans '
        'débordement', (tester) async {
      await _pump(tester,
          snapshot: _student(), size: const Size(375, 4000), textScale: 1.5);
      expect(find.byKey(const ValueKey('home-search-entry')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-bell')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('carte « prochaine étape »', () {
    testWidgets('une seule carte, une seule action', (tester) async {
      await _pump(tester, snapshot: _student());
      expect(find.byKey(const ValueKey('home-next-step-cta')), findsOneWidget);
      // Profil rempli, pas d'orientation : le test d'orientation.
      expect(find.byKey(const ValueKey('home-next-step-orientation')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('home_next_step_plan_a11y')),
          findsOneWidget);
      final cta =
          tester.getSize(find.byKey(const ValueKey('home-next-step-cta')));
      expect(cta.height, greaterThanOrEqualTo(48));
    });

    testWidgets('un dossier qui attend l\'élève prend la place',
        (tester) async {
      await _pump(tester,
          snapshot: _student(cases: [
            _case('busy', CaseStatus.inProgress),
            _case('wait', CaseStatus.documentsNeeded),
          ]));
      expect(find.byKey(const ValueKey('home-next-step-caseAction')),
          findsOneWidget);
      expect(find.text('Étape wait'), findsOneWidget,
          reason: 'l\'étape n\'est pas répétée dans « Tes échéances »');
      expect(find.byKey(const ValueKey('home-deadline-case-busy')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('home-deadline-case-wait')), findsNothing);
    });

    testWidgets('une bourse suivie qui clôture bientôt : sa fiche',
        (tester) async {
      final controller = await _pump(tester, snapshot: _student());
      controller.scholarships.add(_scholarship('eiffel', inDays: 6));
      controller.rememberServerFollowedScholarships(['eiffel']);
      controller.update();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-next-step-followedClosingSoon')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('home-deadline-scholarship-eiffel')),
          findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-next-step-cta')));
      await tester.pumpAndSettle();
      // La fiche ; l'onglet Bourses quand le catalogue est l'échantillon
      // embarqué (ses identifiants n'existent pas côté serveur).
      if (controller.catalogIsSampleData) {
        expect(controller.shellIndex, StudentShellTab.scholarships);
      } else {
        expect(find.text('FICHE eiffel'), findsOneWidget);
      }
    });

    for (final open in [true, false]) {
      testWidgets(
          '« Complète ton profil », drapeau scholarshipMatch '
          '${open ? 'ouvert : le test' : 'fermé : l\'onboarding'}',
          (tester) async {
        resetMatchWorld(flag: open);
        final api = _HomeApi();
        final controller = await _pump(tester,
            snapshot: AppSnapshot(
              localeCode: 'fr',
              hasCompletedOnboarding: true,
              onboardingSkipped: true,
              profile: createTestProfile(),
            ),
            api: api,
            // L'onboarding s'ouvre dans ce test : sa ligne téléphone
            // demande plus que 393 pt avec la police des tests.
            size: const Size(1080, 4000),
            translated: true);
        expect(controller.needsProfileCompletionBanner, isTrue);
        final kind = open ? 'completeProfileTest' : 'completeProfileOnboarding';
        expect(find.byKey(ValueKey('home-next-step-$kind')), findsOneWidget);
        if (open) {
          // Pas de seconde carte « Fais le test » juste en dessous.
          expect(find.byKey(const ValueKey('scholarship-match-entry-noRun')),
              findsNothing);
        }
        await tester.tap(find.byKey(const ValueKey('home-next-step-cta')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ScholarshipMatchFlowScreen),
            open ? findsOneWidget : findsNothing);
        expect(find.byType(OnboardingScreen),
            open ? findsNothing : findsOneWidget);
      });
    }
  });

  group('parents, invités, partenaires', () {
    testWidgets('parent : son héros, aucune carte élève', (tester) async {
      await _pump(tester, snapshot: _parent());
      expect(find.text('home_hero_cta_consultation'), findsOneWidget);
      expect(_block(HomeBlock.nextStep), findsNothing);
      expect(_block(HomeBlock.deadlines), findsNothing);
      expect(find.byKey(const ValueKey('home-next-step-cta')), findsNothing);
      expect(_block(HomeBlock.counselor), findsOneWidget);
    });

    testWidgets('invité : son héros, ni prochaine étape ni échéances',
        (tester) async {
      await _pump(tester, snapshot: _guest);
      expect(find.byKey(const ValueKey('home-hero-guest-cta')), findsOneWidget);
      expect(_block(HomeBlock.nextStep), findsNothing);
      expect(_block(HomeBlock.deadlines), findsNothing);
      expect(_block(HomeBlock.scholarships), findsNothing);
      expect(_block(HomeBlock.intelligence), findsOneWidget);
    });

    testWidgets('partenaire : son héros inchangé', (tester) async {
      await _pump(tester, snapshot: _partner());
      expect(find.text('home_hero_title_partner'), findsOneWidget);
      expect(find.text('home_hero_cta_become_partner'), findsOneWidget);
      expect(_block(HomeBlock.nextStep), findsNothing);
    });
  });

  group('lisibilité', () {
    for (final (label, snapshot) in <(String, AppSnapshot)>[
      ('élève', _student(cases: _twoCases)),
      ('parent', _parent(cases: _twoCases)),
      ('invité', _guest),
    ]) {
      testWidgets('$label : 360×640 à 1,3 sans débordement, texte ≥ 12 sp',
          (tester) async {
        final api = _HomeApi(
          impact: const {'studentsGuided': 120, 'admissionsSecured': 14},
          partners: const [
            {'nameFr': 'Université très longue de Dakar', 'logoUrl': ''},
          ],
          stories: [_story('awa'), _story('moussa')],
        );
        final controller = await _pump(
          tester,
          snapshot: snapshot,
          api: api,
          size: const Size(360, 640),
          textScale: 1.3,
          remoteSync: true,
        );
        controller.scholarships.add(_scholarship('soon', inDays: 3));
        controller.update();
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 30; i++) {
          _expectReadableText(tester);
          await tester.drag(scrollable, const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Tout texte VISIBLE de l'accueil fait au moins 12 sp (avant mise à
/// l'échelle).
void _expectReadableText(WidgetTester tester) {
  for (final element in find
      .descendant(of: find.byType(HomeScreen), matching: find.byType(Text))
      .evaluate()) {
    final text = element.widget as Text;
    final style = DefaultTextStyle.of(element).style.merge(text.style);
    final size = style.fontSize ?? 14;
    expect(size, greaterThanOrEqualTo(12),
        reason: '« ${text.data} » en $size sp');
  }
}
