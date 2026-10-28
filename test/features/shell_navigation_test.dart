import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/navigation/shell_tabs.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/ui/components/kpb_sample_data_banner.dart';
import 'package:karatou/app/features/shell/app_shell.dart';

import '../widget_test_helpers.dart';

void main() {
  group('AppShell Widget Tests', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('displays bottom navigation bar with 5 tabs', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      expect(find.byKey(const ValueKey('kpb_shell_nav_bar')), findsOneWidget);
      // One icon per tab in the floating bar (5 tabs).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kpb_shell_nav_bar')),
          matching: find.byType(Icon),
        ),
        findsNWidgets(5),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('keeps every tab label visible in the source-design order',
        (tester) async {
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      for (final tabKey in const [
        'kpb_nav_home',
        'kpb_nav_universities',
        'kpb_nav_scholarships',
        'kpb_nav_cases',
        'kpb_nav_profile',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(tabKey)),
            matching: find.byType(Text),
          ),
          findsOneWidget,
        );
      }

      expect(
        tester.getCenter(find.byKey(const ValueKey('kpb_nav_home'))).dx,
        lessThan(
          tester
              .getCenter(find.byKey(const ValueKey('kpb_nav_universities')))
              .dx,
        ),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('kpb_nav_universities'))).dx,
        lessThan(
          tester
              .getCenter(find.byKey(const ValueKey('kpb_nav_scholarships')))
              .dx,
        ),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('kpb_nav_scholarships'))).dx,
        lessThan(
          tester.getCenter(find.byKey(const ValueKey('kpb_nav_cases'))).dx,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    // Audit build 57, n° 2 : pas de « connexion au serveur impossible »
    // pendant que la 1re synchro avance ; seulement si elle a échoué.
    testWidgets('bandeau « Données d\'exemple » seulement après la 1re synchro',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );
      final controller = Get.find<AppController>()
        ..catalogDataState = CatalogDataState.sample
        ..catalogFirstSyncSettled = false;
      controller.update();
      await tester.pump();
      expect(find.byType(KpbSampleDataBanner), findsNothing);

      controller.catalogFirstSyncSettled = true;
      controller.update();
      await tester.pump();
      expect(find.byType(KpbSampleDataBanner), findsOneWidget);

      controller.catalogDataState = CatalogDataState.live;
      controller.update();
      await tester.pump();
      expect(find.byType(KpbSampleDataBanner), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('starts on Home tab (index 0)', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Get the AppController to check shellIndex
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(0));

      await tester.pumpAndSettle();
    });

    testWidgets('navigates to Scholarships tab when tapped (index 1)',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Tap Scholarships — scope to nav bar so page icons don't match.
      final bar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      await tester.tap(
        find.descendant(
          of: bar,
          matching: find.byIcon(Icons.workspace_premium_outlined),
        ),
      );
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(1));
    });

    testWidgets('navigates to Cases tab when tapped (index 3)', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final bar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      await tester.tap(
        find.descendant(
            of: bar, matching: find.byIcon(Icons.folder_copy_outlined)),
      );
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(3));
    });

    testWidgets('navigates to Profile tab when tapped (index 4)',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final bar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      await tester.tap(
        find.descendant(
            of: bar, matching: find.byIcon(Icons.person_outline_rounded)),
      );
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(4));
    });

    testWidgets('preserves state when switching tabs', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();

      // Switch to Scholarships (index 1)
      controller.goToTab(1);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(1));

      // Switch back to Home (index 0)
      controller.goToTab(0);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(0));

      // Switch to Cases (index 3)
      controller.goToTab(3);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(3));
    });

    testWidgets('rapid tab switching does not cause errors', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();

      // Rapidly switch tabs
      for (int i = 0; i < 5; i++) {
        controller.goToTab(i % 5);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();
      // Should end up at tab 4
      expect(controller.shellIndex, equals(4));
    });

    testWidgets('displays selected icon for active tab', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      expect(find.byType(Icon), findsWidgets);

      // Verify tab switching updates controller
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(0));
      controller.goToTab(1);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(1));
    });

    testWidgets('uses IndexedStack to preserve tab state', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Verify IndexedStack is used (all pages are in the widget tree)
      expect(find.byType(IndexedStack), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('navigation works with AppController.goToTab method',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();

      // Use goToTab to navigate
      expect(controller.shellIndex, equals(0));

      controller.goToTab(4);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(4));

      controller.goToTab(0);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(0));
    });

    testWidgets('SafeArea is applied to prevent system UI overlap',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Verify SafeArea is used
      expect(find.byType(SafeArea), findsWidgets);

      await tester.pumpAndSettle();
    });

    testWidgets('navigation bar height is set correctly', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final navBar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      expect(navBar, findsOneWidget);
      final container = tester.widget<Container>(navBar);
      expect(container.constraints!.maxHeight, equals(62));
    });

    testWidgets('two overlapping shells do not collide on the drawer GlobalKey',
        (tester) async {
      // Regression: AppShell's Scaffold used a single *static* GlobalKey, so any
      // moment two shells were mounted at once — e.g. `Get.offAllNamed('/')`
      // firing while the boot shell was a frame from teardown, as happened when
      // the app was foregrounded via a `kpb://` URL — threw "Duplicate GlobalKey
      // [LabeledGlobalKey<ScaffoldState>]". Each shell now owns its key, so
      // mounting two at once is harmless.
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      );

      await pumpTestApp(
        tester,
        child: const Stack(
          textDirection: TextDirection.ltr,
          children: [
            AppShell(key: ValueKey('shell_a')),
            AppShell(key: ValueKey('shell_b')),
          ],
        ),
        initialSnapshot: snapshot,
      );

      expect(tester.takeException(), isNull);
      // Both shells mounted independently → two nav bars, no key collision.
      expect(
        find.byKey(const ValueKey('kpb_shell_nav_bar')),
        findsNWidgets(2),
      );
    });

    testWidgets(
        'the tools button shows on Home only, and the edge-swipe follows it',
        (tester) async {
      // Revue du build 49 : la boîte à outils (« estimateur de coûts… ») est
      // une extension de l'accueil. Deux moitiés d'une même règle, et le test
      // tient les deux : le BOUTON disparaît hors accueil, et le GLISSÉ depuis
      // le bord gauche aussi. Sans la seconde assertion, une régression
      // pourrait masquer le bouton en laissant le tiroir ouvrable au doigt —
      // c'est-à-dire invisible mais toujours atteignable, le pire des deux.
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      const toolsButton = ValueKey('kpb_shell_tools_button');

      // On démarre sur l'accueil : bouton présent, glissé armé.
      expect(find.byKey(toolsButton), findsOneWidget);
      expect(
        tester
            .widget<Scaffold>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('kpb_shell_nav_bar')),
                    matching: find.byType(Scaffold),
                  )
                  .first,
            )
            .drawerEnableOpenDragGesture,
        isTrue,
      );

      // Les quatre autres onglets : ni bouton, ni glissé.
      for (final tab in const [
        StudentShellTab.universities,
        StudentShellTab.scholarships,
        StudentShellTab.cases,
        StudentShellTab.profile,
      ]) {
        Get.find<AppController>().goToTab(tab);
        await tester.pumpAndSettle();

        expect(
          find.byKey(toolsButton),
          findsNothing,
          reason: 'le bouton outils ne doit pas être rendu sur l\'onglet $tab',
        );
        expect(
          tester
              .widget<Scaffold>(
                find
                    .ancestor(
                      of: find.byKey(const ValueKey('kpb_shell_nav_bar')),
                      matching: find.byType(Scaffold),
                    )
                    .first,
              )
              .drawerEnableOpenDragGesture,
          isFalse,
          reason: 'le tiroir doit rester inatteignable au glissé sur $tab',
        );
      }

      // Retour à l'accueil : la règle est réversible, pas un aller simple.
      Get.find<AppController>().goToTab(StudentShellTab.home);
      await tester.pumpAndSettle();
      expect(find.byKey(toolsButton), findsOneWidget);
    });
  });
}
