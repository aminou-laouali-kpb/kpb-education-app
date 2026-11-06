import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/premium/premium_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement Profil restyle + honest Premium (PR8):
//   • Premium is NOT a paywall — value props bind the REAL AI-coach weekly quota
//     (5), the lone CTA hands off to the KPB advisor, and there is NO price,
//     checkout, external pay landing, or "Karatou ID payment" block anywhere.
//   • Profil restyle binds real data and omits the design's fabricated elements
//     (no streak, no in-app price).
// ─────────────────────────────────────────────────────────────────────────────

Future<AppController> _seed({
  AccountType accountType = AccountType.student,
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();

  final snapshot = AppSnapshot(
    localeCode: 'en',
    hasCompletedOnboarding: true,
    profile: createTestProfile(
      fullName: 'Awa Diallo',
      accountType: accountType,
    ),
  );

  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();

  Get.put<AppController>(controller, permanent: true);
  return controller;
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: home,
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(resetGetxSingleton);

  testWidgets(
      'PremiumScreen: honest value props + real quota + advisor CTA, '
      'and NO price / checkout / billing', (tester) async {
    await _seed();
    await tester.pumpWidget(_wrap(const PremiumScreen()));
    await tester.pumpAndSettle();

    // Value proposition (coming soon).
    expect(find.text('premium_hero_title'.tr), findsOneWidget);
    expect(find.text('premium_value_advisors'.tr), findsOneWidget);

    // Single advisor-routed CTA, in the pinned bottom bar (always visible).
    // Audit build 57, T5-14 : pas de bouton « Activer » pour un produit qui
    // n'existe pas encore ; le seul canal réel est l'échange avec un conseiller.
    expect(find.text('premium_advisor_cta'.tr), findsOneWidget);
    // Lu dans la table de traduction : le harnais n'applique pas la locale.
    final fr = AppTranslations().keys['fr']!;
    for (final key in const [
      'premium_advisor_cta',
      'premium_hero_title',
      'premium_how_title',
      'premium_how_body',
    ]) {
      expect(fr[key], isNot(contains('ctiv')), reason: key);
    }
    expect(fr['premium_hero_title'], 'Passe au Pass Karatou');
    expect(fr['premium_screen_title'], fr['profile_premium_card_title']);

    // Waiting list: a FREE interest registration, not a purchase. Scrolled into
    // view rather than assumed — the 800x600 test viewport is shorter than any
    // real phone, and a ListView does not build what it does not show.
    await tester.dragUntilVisible(
      find.text('premium_waitlist_cta'.tr),
      find.byType(ListView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(find.text('premium_waitlist_cta'.tr), findsOneWidget);
    // Le texte de consentement est affiché AVEC le bouton : une mention lue
    // après le tap n'aurait rien prouvé.
    expect(find.text('premium_waitlist_notice'.tr), findsOneWidget);

    // The REAL free AI-coach quota row, likewise scrolled into view: asserting
    // it without scrolling would pass on an empty screen for the wrong reason.
    await tester.dragUntilVisible(
      find.text('premium_free_ai_coach'.trParams({'count': '5'})),
      find.byType(ListView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(find.text('premium_free_ai_coach'.trParams({'count': '5'})),
        findsOneWidget);
    expect(find.text('premium_unlimited_soon'.tr), findsOneWidget);

    // NO price, subscription, external checkout, or Karatou-ID payment block —
    // checked ALL THE WAY DOWN the list, not just on the first screenful. The
    // cards are lazily built, so a negative assertion made without scrolling
    // would only ever have proven that the hidden cards were hidden.
    Future<void> assertNoBilling() async {
      for (final needle in const [
        'FCFA',
        '4 900',
        '4,900',
        'karatou.app/premium',
        '/month',
        '/mois',
        'KARATOU ID',
        'Subscribe',
        'Pay ',
      ]) {
        expect(find.textContaining(needle), findsNothing, reason: needle);
      }
    }

    await tester.scrollUntilVisible(
      find.text('premium_how_title'.tr),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await assertNoBilling();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ProfileScreen: binds real name + honest Premium entry, '
      'omits fabricated streak/price', (tester) async {
    await _seed();
    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pumpAndSettle();

    // Real profile name is bound.
    expect(find.textContaining('Awa'), findsWidgets);
    // Fabricated design elements are omitted.
    expect(find.textContaining('🔥'), findsNothing);
    expect(find.textContaining('FCFA'), findsNothing);

    // The honest Premium entry card is present (scroll it into view).
    final vScroll = find.byWidgetPredicate(
      (w) =>
          w is Scrollable &&
          (w.axisDirection == AxisDirection.down ||
              w.axisDirection == AxisDirection.up),
    );
    await tester.scrollUntilVisible(
      find.text('profile_premium_card_title'.tr),
      300,
      scrollable: vScroll,
    );
    expect(find.text('profile_premium_card_title'.tr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
