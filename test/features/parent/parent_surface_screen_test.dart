import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/parent/parent_surface_screen.dart';

import '../../support/eef_help_fakes.dart';
import '../../widget_test_helpers.dart';

void main() {
  late UrlLauncherPlatform previousLauncher;
  late RecordingUrlLauncher launcher;

  setUp(() {
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });
  tearDown(() => UrlLauncherPlatform.instance = previousLauncher);
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  Future<void> pump(WidgetTester tester, MockApiClient mock) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTestApp(
      tester,
      child: const ParentSurfaceScreen(),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
      mockApiClient: mock,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the onboarding link step when no child is linked',
      (tester) async {
    final mock = MockApiClient();
    when(() => mock.listParentChildren()).thenAnswer((_) async => const []);
    when(() => mock.listParentVisibleCases()).thenAnswer((_) async => const []);

    await pump(tester, mock);

    // Keys render verbatim in the test env. The parent CREATES an invite code
    // (create → share), never enters one.
    expect(find.text('parent_onboarding_title'), findsOneWidget);
    expect(find.text('parent_create_cta'), findsOneWidget);
  });

  testWidgets('generating an invite calls createParentInvite (not accept)',
      (tester) async {
    final mock = MockApiClient();
    when(() => mock.listParentChildren()).thenAnswer((_) async => const []);
    when(() => mock.listParentVisibleCases()).thenAnswer((_) async => const []);
    when(() => mock.createParentInvite())
        .thenAnswer((_) async => {'inviteCode': 'KTOU-MD-9f21'});

    await pump(tester, mock);
    await tester.tap(find.text('parent_create_cta'));
    await tester.pumpAndSettle();

    verify(() => mock.createParentInvite()).called(1);
    // acceptParentInvite must never be called on a parent account (would 403).
    verifyNever(() => mock.acceptParentInvite(any()));
    expect(find.text('KTOU-MD-9f21'), findsOneWidget); // code shown to share
  });

  testWidgets('renders the 4-tab surface when a child is linked',
      (tester) async {
    final mock = MockApiClient();
    when(() => mock.listParentChildren()).thenAnswer((_) async => const [
          {
            'child': {'fullName': 'Aïcha Diallo', 'currentLevel': 'Licence 3'}
          }
        ]);
    when(() => mock.listParentVisibleCases()).thenAnswer((_) async => const [
          {
            'id': 'c1',
            'title': 'Université Grenoble Alpes',
            'status': 'in_progress'
          }
        ]);

    await pump(tester, mock);

    // Overview tab visible (read-only chip) + real case data + bottom nav.
    expect(find.text('parent_readonly_chip'), findsOneWidget);
    expect(find.text('Université Grenoble Alpes'), findsOneWidget);
    expect(find.text('parent_nav_pay'), findsOneWidget);

    // Switch to the Dossier tab (its title is rendered as the raw key here).
    await tester.tap(find.text('parent_nav_case'));
    await tester.pumpAndSettle();
    expect(find.text('parent_case_title'), findsOneWidget);
  });
  testWidgets(
      'onglet Paiements : le Pass est « Bientôt disponible », rien ne '
      's\'« active » (revue avant la 58)', (tester) async {
    final mock = MockApiClient();
    when(() => mock.listParentChildren()).thenAnswer((_) async => const [
          {
            'child': {'fullName': 'Aïcha Diallo', 'currentLevel': 'Licence 3'}
          }
        ]);
    when(() => mock.listParentVisibleCases()).thenAnswer((_) async => const []);

    await pump(tester, mock);
    await tester.tap(find.text('parent_nav_pay'));
    await tester.pumpAndSettle();

    // Le même badge que l'écran élève du Pass.
    expect(find.text('premium_badge_soon'), findsOneWidget);
    expect(find.text('parent_premium_cta'), findsOneWidget);

    // Les textes de la carte : ni « illimité », ni « live VIP », ni « Activer ».
    final keys = AppTranslations().keys;
    for (final lang in const ['fr', 'en']) {
      final sub = keys[lang]!['parent_premium_sub']!.toLowerCase();
      final cta = keys[lang]!['parent_premium_cta']!.toLowerCase();
      for (final banned in const ['illimit', 'unlimited', 'vip', 'live']) {
        expect(sub, isNot(contains(banned)), reason: '$lang sub: $banned');
      }
      expect(cta, isNot(contains('activ')), reason: '$lang cta');
      expect(keys[lang]!['parent_wa_pass'], isNotNull);
      expect(keys[lang]!['parent_wa_pass']!.toLowerCase(),
          isNot(contains('régler')));
    }

    // Le bouton du Pass ouvre WhatsApp avec une DEMANDE D'INFORMATION, pas
    // le message « je souhaite régler … » des prestations payantes.
    await tester.tap(find.text('parent_premium_cta'));
    await tester.pumpAndSettle();
    expect(launcher.launched, hasLength(1));
    expect(Uri.parse(launcher.launched.single).host, 'wa.me');
    expect(launcher.lastText, 'parent_wa_pass'.tr);

    // Témoin : une prestation, elle, part bien avec le message de règlement —
    // les deux chemins sont distincts.
    launcher.launched.clear();
    await tester.tap(find.text('parent_pay_cta').first);
    await tester.pumpAndSettle();
    expect(launcher.launched, hasLength(1));
    expect(launcher.lastText, isNot('parent_wa_pass'.tr));
    expect(launcher.lastText,
        'parent_wa_pay'.trParams({'item': 'parent_pack_review'.tr}));
  });
}
