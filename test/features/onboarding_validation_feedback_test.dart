// L'étape 1 de l'onboarding DIT pourquoi elle refuse, et le mesure.
//
// Octobre 2026, PostHog : l'étape 1 était l'écran le plus rage-cliqué de l'app
// (253 comptes, 13 % de ceux qui la voyaient). « Continuer » échouait sans rien
// montrer : l'erreur était hors de l'écran, ou dans un bandeau posé sur le
// bouton lui-même, et la case de consentement (24 px) était la seule cible de
// la carte. Ces tests verrouillent les trois corrections : l'erreur est écrite
// EN PLACE, la carte entière coche la case, et chaque refus part dans
// `onboarding_validation_failed` avec sa raison fermée.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/observability/analytics_event_contract.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';

import '../support/screen_harness.dart';
import '../widget_test_helpers.dart';

const _phoneViewport = KpbViewport(
  id: 'phone390',
  name: 'phone 390×844',
  size: Size(390, 844),
  padding: EdgeInsets.only(top: 47, bottom: 34),
);

void main() {
  final events = <(String, Map<String, Object>)>[];

  setUp(() {
    events.clear();
    AnalyticsService.instance.logEventSink = (name, params) async {
      events.add((name, params));
    };
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    Get.reset();
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    required bool consented,
  }) async {
    tester.view.physicalSize = _phoneViewport.size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: false,
        profile: createTestProfile().copyWith(
          birthDate: DateTime(now.year - 20, now.month, now.day),
          consentedAt: consented ? now : null,
          countryOfResidence: 'Niger',
        ),
      ),
    );
    await pumpKpbScreen(
      tester,
      screen: const OnboardingScreen(),
      viewport: _phoneViewport,
    );
  }

  List<Map<String, Object>> validationFailures() => [
        for (final (name, params) in events)
          if (name == AnalyticsEventName.onboardingValidationFailed) params,
      ];

  Future<void> tapContinue(WidgetTester tester) async {
    final next = find.widgetWithText(FilledButton, 'continue'.tr);
    await tester.tap(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder phoneField() => find.byWidgetPredicate(
        (w) => w is TextField && w.keyboardType == TextInputType.phone,
      );

  testWidgets(
      'un champ obligatoire vide : erreur en place, raison `required_fields`',
      (tester) async {
    await pumpOnboarding(tester, consented: true);

    await tapContinue(tester);

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('field_required'.tr), findsWidgets);
    expect(validationFailures(), [
      {AnalyticsParamKey.step: 1, AnalyticsParamKey.reason: 'required_fields'},
    ]);
    // Aucun bandeau posé sur le bouton.
    expect(find.byType(GetSnackBar), findsNothing);
  });

  testWidgets(
      'consentement manquant : la page défile jusqu\'à la carte, qui dit '
      'pourquoi, et la carte ENTIÈRE coche la case', (tester) async {
    await pumpOnboarding(tester, consented: false);
    await tester.enterText(phoneField(), '07000000');
    await tester.pump();

    await tapContinue(tester);

    expect(find.text('1 / 3'), findsOneWidget);
    expect(validationFailures(), [
      {AnalyticsParamKey.step: 1, AnalyticsParamKey.reason: 'consent_missing'},
    ]);
    final consentError = find.text('onboarding_consent_required_body'.tr);
    expect(consentError, findsOneWidget);
    // Défilée jusqu'à elle : l'erreur est DANS l'écran, au-dessus de la barre
    // du bas.
    final errorRect = tester.getRect(consentError);
    final barTop =
        tester.getRect(find.widgetWithText(FilledButton, 'continue'.tr)).top;
    expect(errorRect.bottom, lessThan(barTop));
    expect(errorRect.top, greaterThan(0));
    expect(find.byType(GetSnackBar), findsNothing);

    // Un appui dans la carte, loin de la case : elle se coche.
    final card = find.ancestor(of: consentError, matching: find.byType(Ink));
    final rect = tester.getRect(card);
    await tester.tapAt(rect.bottomRight - const Offset(10, 6));
    await tester.pump();

    // L'erreur a disparu : on retrouve la carte par son lien.
    final consentCard = find.ancestor(
      of: find.text('privacy_policy_inline'.tr),
      matching: find.byType(Ink),
    );
    final box = tester.widget<Checkbox>(find.descendant(
      of: consentCard,
      matching: find.byType(Checkbox),
    ));
    expect(box.value, isTrue);
    expect(find.text('onboarding_consent_required_body'.tr), findsNothing);
  });

  test('les raisons publiées sont fermées et en snake_case', () {
    final snake = RegExp(r'^[a-z]+(_[a-z]+)*$');
    for (final r in AnalyticsService.onboardingValidationReasons) {
      expect(r, matches(snake));
    }
    // Toute raison que l'écran peut émettre est déclarée — une raison
    // ajoutée dans l'écran sans passer par la liste fait rougir ce test.
    final source = File('lib/app/features/onboarding/onboarding_screen.dart')
        .readAsStringSync();
    final emitted = {
      for (final m in RegExp(
              r"(?:return|_logValidationFailed\(\d,|_onPageInvalid\(\d,)\s*'([a-z_]+)'")
          .allMatches(source))
        m.group(1)!,
    };
    expect(emitted, isNotEmpty);
    expect(AnalyticsService.onboardingValidationReasons, containsAll(emitted));
  });
}
