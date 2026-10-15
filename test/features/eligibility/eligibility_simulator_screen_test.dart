import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/eligibility/eligibility_simulator_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('EligibilitySimulatorScreen', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    Future<void> pump(WidgetTester tester) async {
      // Tall viewport so the scrollable form's button is laid out (ListView is
      // lazy — the CTA sits below an 800×600 default surface otherwise).
      tester.view.physicalSize = const Size(1400, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = createTestProfile(accountType: AccountType.student);
      await pumpTestApp(
        tester,
        child: const EligibilitySimulatorScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: profile,
        ),
      );
    }

    testWidgets('renders the form with the canonical level prefilled',
        (tester) async {
      await pump(tester);

      expect(find.text('eligibility_your_info'), findsOneWidget);
      // createTestProfile uses currentLevel "Licence" → normalised to "Bachelor 1".
      expect(find.text('Bachelor 1'), findsWidgets);
      // The CTA label is localized (.tr); the test harness doesn't load
      // translations, so the rendered text is the key.
      expect(find.text('evaluate_eligibility'), findsOneWidget);
    });

    testWidgets('evaluating shows the verdict summary and per-country results',
        (tester) async {
      await pump(tester);

      await tester.tap(find.text('evaluate_eligibility'));
      await tester.pumpAndSettle();

      // Verdict labels appear in the summary row and on result cards.
      expect(find.text('eligibility_summary_eligible'), findsWidgets);
      expect(find.text('eligibility_summary_to_prepare'), findsWidgets);

      // A known destination card + the (unique) PDF export CTA prove the
      // results section rendered.
      expect(find.textContaining('France'), findsWidgets);
      expect(find.text('eligibility_export_pdf'), findsOneWidget);

      // Chantier H2 : le verdict, jamais un pourcentage. Le score est une
      // somme de points budget/langue/niveau ; « 🟢 80 % » se lisait comme des
      // chances.
      expect(find.textContaining('%'), findsNothing);
    });
  });
}
