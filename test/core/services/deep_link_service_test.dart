import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/deep_link_service.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

/// Minimal screen that stamps a findable key so tests can assert which route is
/// on top without pulling in the real (controller-heavy) screens.
class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label, key: ValueKey<String>('probe_$label')),
      ),
    );
  }
}

Future<void> _pumpRoutingHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: AppRoutes.home,
      getPages: [
        GetPage(name: AppRoutes.home, page: () => const _RouteProbe('home')),
        GetPage(
          name: AppRoutes.scholarships,
          page: () => const _RouteProbe('scholarships'),
        ),
        GetPage(
          name: AppRoutes.scholarshipDetail,
          page: () => _RouteProbe('scholarship_${Get.parameters['id']}'),
        ),
        GetPage(
          name: AppRoutes.orientation,
          page: () => const _RouteProbe('orientation'),
        ),
        GetPage(
          name: AppRoutes.deadlines,
          page: () => const _RouteProbe('deadlines'),
        ),
        GetPage(
          name: AppRoutes.profile,
          page: () => const _RouteProbe('profile'),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DeepLinkService.resolveRoute', () {
    test('maps host-style kpb:// links to their static routes', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://scholarships')),
        AppRoutes.scholarships,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://orientation')),
        AppRoutes.orientation,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://deadlines')),
        AppRoutes.deadlines,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://profile')),
        AppRoutes.profile,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://saved')),
        AppRoutes.saved,
      );
    });

    test('maps parameterized links (host + path segments)', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://scholarships/sch-42')),
        '/scholarships/sch-42',
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://cases/c-7')),
        '/cases/c-7',
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://success-lab/w1')),
        '/success-lab/w1',
      );
      expect(
        DeepLinkService.resolveRoute(
          Uri.parse('kpb://success-lab/w1/diagnostic'),
        ),
        '/success-lab/w1/diagnostic',
      );
    });

    test('folds the triple-slash form (empty host) into the same route', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb:///scholarships')),
        AppRoutes.scholarships,
      );
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb:///scholarships/sch-42')),
        '/scholarships/sch-42',
      );
    });

    test('drops query strings and fragments', () {
      expect(
        DeepLinkService.resolveRoute(
          Uri.parse('kpb://scholarships/sch-42?ref=email#top'),
        ),
        '/scholarships/sch-42',
      );
    });

    test('resolves a bare kpb:// to home', () {
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://')),
        AppRoutes.home,
      );
    });

    test('returns null for unsupported or malformed links', () {
      // Unknown top-level target.
      expect(DeepLinkService.resolveRoute(Uri.parse('kpb://unknown')), isNull);
      // Nested scholarship id is rejected by the route normalizer.
      expect(
        DeepLinkService.resolveRoute(Uri.parse('kpb://scholarships/a/b')),
        isNull,
      );
      // supabase's OAuth redirect scheme stays out of app navigation.
      expect(
        DeepLinkService.resolveRoute(
          Uri.parse('io.supabase.kpbeducation://login-callback'),
        ),
        isNull,
      );
    });

    // The Supabase callback never arrives bare: PKCE appends `?code=…`, the
    // implicit flow a `#access_token=…` fragment, and the trailing slash of
    // `AppConfig.supabaseOAuthRedirect` is part of the registered URL. All of
    // those shapes must stay unroutable here so this listener never competes
    // with supabase_flutter's own deep link handling for the OAuth return.
    test('ignores every shape of the Supabase auth callback', () {
      const callbacks = <String>[
        'io.supabase.kpbeducation://login-callback/',
        'io.supabase.kpbeducation://login-callback/?code=abc123',
        'io.supabase.kpbeducation://login-callback/#access_token=abc&refresh_token=def',
        'io.supabase.kpbeducation://login-callback/?error_description=denied',
      ];
      for (final callback in callbacks) {
        expect(
          DeepLinkService.resolveRoute(Uri.parse(callback)),
          isNull,
          reason: 'Supabase callback must not resolve to a route: $callback',
        );
      }
    });
  });

  group('DeepLinkService.handleUri (end-to-end flow)', () {
    setUp(() {
      Get.testMode = true;
    });

    tearDown(() {
      Get.reset();
      Get.testMode = false;
    });

    testWidgets('navigates to the mapped screen for a supported link',
        (tester) async {
      await _pumpRoutingHarness(tester);
      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);

      DeepLinkService.instance.handleUri(Uri.parse('kpb://orientation'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_orientation')), findsOneWidget);
    });

    testWidgets('opens a parameterized detail route', (tester) async {
      await _pumpRoutingHarness(tester);

      DeepLinkService.instance
          .handleUri(Uri.parse('kpb://scholarships/sch-42'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('probe_scholarship_sch-42')),
        findsOneWidget,
      );
    });

    testWidgets('ignores an unsupported link and stays on home',
        (tester) async {
      await _pumpRoutingHarness(tester);

      DeepLinkService.instance.handleUri(Uri.parse('kpb://unknown'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);
      expect(find.byKey(const ValueKey('probe_orientation')), findsNothing);
    });

    testWidgets('a bare kpb:// stays on home without stacking a second shell',
        (tester) async {
      await _pumpRoutingHarness(tester);

      DeepLinkService.instance.handleUri(Uri.parse('kpb://'));
      await tester.pumpAndSettle();

      // Exactly one home route — a stacked duplicate would surface a second
      // probe_home in the (retained) route below.
      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);
    });
  });

  // Audit avant la 59 : un lien `kpb://` (comme un raccourci de l'icône)
  // poussait son écran même pour quelqu'un qui n'avait ni compte ni mode
  // invité — un écran vide ou en erreur, sans chemin vers la connexion. Le
  // routeur des notifications avait déjà cette garde.
  group('DeepLinkService.handleUri — le mur d\'entrée', () {
    setUp(() {
      Get.testMode = true;
    });

    tearDown(() {
      resetGetxSingleton();
      Get.testMode = false;
    });

    Future<void> seed(WidgetTester tester, AppSnapshot snapshot) async {
      await tester.runAsync(() => seedKpbController(snapshot: snapshot));
      await _pumpRoutingHarness(tester);
    }

    testWidgets('sans compte ni mode invité, le lien est ignoré',
        (tester) async {
      await seed(tester,
          const AppSnapshot(localeCode: 'fr', hasCompletedOnboarding: false));

      DeepLinkService.instance.handleUri(Uri.parse('kpb://orientation'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_home')), findsOneWidget);
      expect(find.byKey(const ValueKey('probe_orientation')), findsNothing);
    });

    testWidgets('en mode invité, le lien ouvre son écran', (tester) async {
      await seed(
        tester,
        const AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: false,
          isGuestMode: true,
        ),
      );

      DeepLinkService.instance.handleUri(Uri.parse('kpb://orientation'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_orientation')), findsOneWidget);
    });

    testWidgets('avec un compte, le lien ouvre son écran', (tester) async {
      await seed(
        tester,
        AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      DeepLinkService.instance.handleUri(Uri.parse('kpb://orientation'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('probe_orientation')), findsOneWidget);
    });
  });
}
