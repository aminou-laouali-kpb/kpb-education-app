// Confidentialité, conditions et contact : lisibles AVANT de créer un compte
// (audit build 57, T1-20). Ils n'existaient que dans le Profil d'un élève
// connecté ; l'invité n'avait aucun moyen de lire à quoi il consent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/auth/auth_welcome_screen.dart';
import 'package:karatou/app/features/legal/legal_links.dart';
import 'package:karatou/app/features/legal/legal_pages.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../widget_test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

Widget _app(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  testWidgets('Profil invité : confidentialité, conditions et contact',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpTestApp(
      tester,
      child: const ProfileScreen(),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        isGuestMode: true,
      ),
    );

    expect(find.byKey(const ValueKey<String>('legal-link-privacy')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('legal-link-terms')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('legal-link-contact')),
        findsOneWidget);
  });

  testWidgets('les liens ouvrent bien les pages légales', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: LegalLinksRow())));
    await tester.tap(find.byKey(const ValueKey<String>('legal-link-privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

    Get.back<void>();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('legal-link-terms')));
    await tester.pumpAndSettle();
    expect(find.byType(TermsOfServiceScreen), findsOneWidget);
  });

  testWidgets('écran d\'entrée : la mention et les liens sont lisibles',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final auth = _MockAuthService();
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => auth.isLoggedIn).thenReturn(false);
    Get.put<AuthService>(auth, permanent: true);

    await tester.pumpWidget(_app(const AuthWelcomeScreen()));
    await tester.pumpAndSettle();

    final fr = AppTranslations().keys['fr']!;
    // La zone de présentation défile : on y descend jusqu'à la mention.
    await tester.scrollUntilVisible(find.text(fr['auth_terms_notice']!), 80,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(fr['auth_terms_notice']!), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('legal-link-privacy')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('legal-link-terms')), findsOneWidget);
  });
}
