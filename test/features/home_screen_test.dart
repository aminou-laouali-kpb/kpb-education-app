import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/navigation/shell_tabs.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/home/home_screen.dart';

import '../widget_test_helpers.dart';

/// Pumps Home the way PRODUCTION mounts it: inside a Scaffold that owns a
/// drawer, on a real iPhone logical width.
///
/// Both matter. `AppShell` puts the hamburger in its Stack as an overlay and
/// gives its Scaffold a `drawer:`, which makes `AppBar.automaticallyImplyLeading`
/// mint a *second*, invisible DrawerButton inside Home's own SliverAppBar. The
/// default `pumpTestApp` wrapper has no drawer, so it could never reproduce the
/// "Salut, …" truncation reported from TestFlight — which is exactly why the
/// first attempt at this bug was mis-diagnosed as "the header is too busy".
Future<void> pumpHomeInDrawerShell(
  WidgetTester tester, {
  required AppSnapshot snapshot,
  Size size = const Size(393, 852),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();

  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);

  await tester.pumpWidget(
    const GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        drawer: Drawer(),
        body: HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('HomeScreen Widget Tests', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('renders home screen and top actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      final profile = createTestProfile(fullName: 'Aminou Diallo');
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: snapshot,
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
      // Chantier G : « Mes suivis » prend la place du raccourci Profil (déjà
      // dans la barre d'onglets).
      expect(find.byKey(const ValueKey<String>('home-followed-entry')),
          findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets(
        'profile action jumps to profile tab (drapeau homeFollowedEntry '
        'coupé : repli sur le raccourci Profil)', (tester) async {
      RemoteFeatureFlags.instance
          .debugSetFeaturesForTest(const {'homeFollowedEntry': false});
      addTearDown(RemoteFeatureFlags.resetForTest);
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(0));

      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();

      expect(controller.shellIndex, equals(4));

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders the progress gauge card and the WhatsApp CTA',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: snapshot,
      );

      // Profile isn't 100% complete (no monthly budget) → the readiness ring
      // + its "progress gauge" eyebrow render (App-engagement handoff).
      // `.tr` resolves to the raw key in this harness (no translations
      // loaded), matching the convention used across this test suite.
      expect(find.text('home_gauge_eyebrow'), findsOneWidget);

      // The "Talk to a KPB counselor" WhatsApp hand-off card is always on
      // Home now — real WhatsApp routing, no in-app checkout.
      expect(find.text('home_counselor_cta_title'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Chantier H2 — héros invité et bourses sans palier de compatibilité.
  // ───────────────────────────────────────────────────────────────────────────
  group('HomeScreen — libellés honnêtes (chantier H2)', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    testWidgets(
        'invité : « Trouve tes bourses » remplace « Devenir partenaire » et '
        'ouvre l\'onglet Bourses', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: const AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: false,
          isGuestMode: true,
        ),
      );

      final controller = Get.find<AppController>();
      expect(controller.isGuestMode, isTrue);
      expect(find.text('home_hero_cta_become_partner'), findsNothing);
      final cta = find.byKey(const ValueKey<String>('home-hero-guest-cta'));
      expect(cta, findsOneWidget);
      expect(
        find.descendant(
            of: cta, matching: find.text('home_hero_cta_find_scholarships')),
        findsOneWidget,
      );

      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, StudentShellTab.scholarships);
    });

    testWidgets('parent : le héros garde « Consultation »', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(accountType: AccountType.parent),
        ),
      );

      expect(find.text('home_hero_cta_consultation'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('home-hero-guest-cta')),
          findsNothing);
    });

    testWidgets(
        'étudiant : les bourses de l\'accueil n\'affichent aucun palier de '
        'compatibilité ni pourcentage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      // Le catalogue embarqué ne porte aucune bourse : on en sème deux, dont
      // une à `baseMatch` 78 — l'ancienne formule l'affichait « Très bon
      // match » sans lire aucune condition.
      final controller = Get.find<AppController>();
      final soon = DateTime.now().add(const Duration(days: 40));
      controller.scholarships.addAll([
        ScholarshipModel(
          id: 'sch-flagship',
          name: const LocalizedText(fr: 'Bourse vitrine', en: 'Flagship'),
          countryId: 'france',
          levelEligible: const LocalizedText(fr: 'Master', en: 'Master'),
          typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
          deadlineLabel: const LocalizedText(fr: '', en: ''),
          keyRequirements: const [],
          relatedFieldIds: const ['d01'],
          baseMatch: 78,
          deadlineAt: soon,
        ),
        const ScholarshipModel(
          id: 'sch-rolling',
          name: LocalizedText(fr: 'Bourse continue', en: 'Rolling'),
          countryId: 'canada',
          levelEligible: LocalizedText(fr: '', en: ''),
          typeOfFunding: LocalizedText(fr: 'Partielle', en: 'Partial'),
          deadlineLabel: LocalizedText(fr: '', en: ''),
          keyRequirements: [],
          relatedFieldIds: [],
          baseMatch: 0,
        ),
      ]);
      controller.update();
      await tester.pumpAndSettle();
      expect(controller.scholarshipsByDeadline.map((s) => s.id),
          ['sch-flagship', 'sch-rolling']);
      final section = find.text('home_scholarships_title');
      await tester.scrollUntilVisible(section, 400,
          scrollable: find.byType(Scrollable).first);
      expect(section, findsOneWidget);
      expect(find.text('scholarships_for_you'), findsNothing);

      // Aucun palier sur les cartes de bourses : `ProfileFitBadge` n'apparaît
      // plus que pour les écoles (section universités), donc on cherche sous
      // la section des bourses.
      final hScroll = find.ancestor(
        of: section,
        matching: find.byType(HScrollSection),
      );
      expect(hScroll, findsOneWidget);
      expect(
        find.descendant(of: hScroll, matching: find.byType(ProfileFitBadge)),
        findsNothing,
      );
      expect(
        find.descendant(of: hScroll, matching: find.textContaining('%')),
        findsNothing,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // App-bar header — regressions from the TestFlight video review.
  // ───────────────────────────────────────────────────────────────────────────
  group('HomeScreen app bar', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    AppSnapshot snapshotFor(String fullName) => AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(fullName: fullName),
        );

    testWidgets(
        'greeting slot keeps a usable width budget on a 393 pt screen '
        '(bug: "Salut, …")', (tester) async {
      // Long West-African first name — the public this app serves.
      await pumpHomeInDrawerShell(tester,
          snapshot: snapshotFor('Mouhamadou Diallo'));

      final slot = find.byKey(homeGreetingSlotKey);
      expect(slot, findsOneWidget);

      // Geometry, not typography — deterministic whatever the font does.
      //
      // Before the fix the title slot got 393 − 56 (phantom DrawerButton)
      // − 136 (3 action chips) − 120 (titleSpacing counted TWICE by
      // NavigationToolbar) = 81 pt, so the salutation ellipsised straight
      // after "Salut,". The reserved gutter for AppShell's overlay hamburger
      // is now charged once, leaving ~201 pt.
      expect(
        tester.getSize(slot).width,
        greaterThanOrEqualTo(190),
        reason: 'the greeting must keep room for "Salut, <prénom> 👋"',
      );
    });

    testWidgets('greeting is never ellipsised', (tester) async {
      await pumpHomeInDrawerShell(tester,
          snapshot: snapshotFor('Mouhamadou Diallo'));

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(homeGreetingSlotKey),
          matching: find.byType(Text),
        ),
      );

      // The greeting scales down rather than truncating: cutting a user's own
      // first name is the defect we are guarding against. This fails the moment
      // someone puts the salutation back on a bounded ellipsis Text.
      expect(paragraph.didExceedMaxLines, isFalse);
    });

    testWidgets('no phantom DrawerButton is implied inside the app bar',
        (tester) async {
      await pumpHomeInDrawerShell(tester,
          snapshot: snapshotFor('Aminou Diallo'));

      // AppShell already surfaces the hamburger as an overlay. A DrawerButton
      // here means `automaticallyImplyLeading` is back and is silently eating
      // 56 pt of the greeting.
      expect(find.byType(DrawerButton), findsNothing);
    });

    testWidgets(
        'pinned/floating header is opaque so content cannot bleed '
        'through it', (tester) async {
      await pumpHomeInDrawerShell(tester,
          snapshot: snapshotFor('Aminou Diallo'));

      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));

      // The bar is `floating`, so it re-enters over already-scrolled content.
      // Transparent meant "Tes meilleures chances" / "Voir tout" scrolled
      // straight through the greeting. It must match the page canvas exactly
      // (invisible at rest) AND be fully opaque.
      expect(bar.backgroundColor, KpbColors.canvas);
      expect(bar.backgroundColor!.a, 1.0);
    });
  });
}
