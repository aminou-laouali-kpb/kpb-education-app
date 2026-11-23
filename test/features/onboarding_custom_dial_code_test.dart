// L'indicatif et le pays à l'inscription, à travers le vrai formulaire.
//
// Le menu déroulant de 37 indicatifs et la liste de 34 pays sont remplacés
// par une feuille qui propose TOUS les pays, avec une recherche : des élèves
// ne trouvaient ni leur pays ni leur indicatif pour créer leur compte.
// « Autre indicatif » (audit build 57, T1-10) reste, en fin de liste : il
// fait apparaître un champ où l'élève tape le sien.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
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
  tearDown(Get.reset);

  const customField = ValueKey('onboarding-custom-dial-code');
  const dialButton = ValueKey('onboarding-phone-dial-code');
  const countryField = ValueKey('onboarding-country');
  const search = ValueKey('country-picker-search');

  Future<void> pumpOnboarding(WidgetTester tester) async {
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
          phone: '',
        ),
      ),
    );
    await pumpKpbScreen(
      tester,
      screen: const OnboardingScreen(),
      viewport: _phoneViewport,
    );
  }

  /// Ce que le bouton d'indicatif affiche (drapeau + indicatif).
  Finder dialShows(String text) => find.descendant(
        of: find.byKey(dialButton),
        matching: find.text(text),
      );

  testWidgets('« Autre indicatif » ouvre le champ de saisie de l’indicatif',
      (tester) async {
    await pumpOnboarding(tester);
    expect(find.byKey(customField), findsNothing);
    // L'indicatif par défaut n'a pas changé : le Niger.
    expect(dialShows('🇳🇪 +227'), findsOneWidget);

    await tester.tap(find.byKey(dialButton));
    await tester.pumpAndSettle();
    // « Autre indicatif » est la dernière ligne : la liste ne construit que
    // les lignes visibles, on la fait défiler jusqu'au bout.
    final other = find.byKey(const ValueKey('country-picker-other'));
    await tester.scrollUntilVisible(
      other,
      900,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('country-picker-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(other);
    await tester.pumpAndSettle();

    expect(find.byKey(customField), findsOneWidget);
    expect(find.text('dial_code_custom_label'.tr), findsOneWidget);
    expect(dialShows('🌍 ${'dial_code_other'.tr}'), findsOneWidget);
  });

  testWidgets(
      'un indicatif que l’ancienne liste n’avait pas se trouve par la '
      'recherche (Haïti, +509)', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byKey(dialButton));
    await tester.pumpAndSettle();
    // La feuille montre les indicatifs, et le public de l'app en tête.
    expect(find.text('dial_code_picker_title'.tr), findsOneWidget);
    expect(find.byKey(const ValueKey('country-picker-NE')), findsOneWidget);

    await tester.enterText(find.byKey(search), '509');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('country-picker-NE')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('country-picker-HT')));
    await tester.pumpAndSettle();

    expect(dialShows('🇭🇹 +509'), findsOneWidget);
    expect(find.byKey(customField), findsNothing);
  });

  testWidgets(
      'une recherche sans résultat laisse « Autre indicatif » à portée de '
      'doigt', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byKey(dialButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(search), 'zzzz');
    await tester.pumpAndSettle();

    expect(
      find.text('country_picker_none_other'
          .trParams({'other': 'dial_code_other'.tr})),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('country-picker-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(customField), findsOneWidget);
  });

  testWidgets(
      'choisir un pays que l’ancienne liste n’avait pas (Kenya) l’affiche '
      'et règle l’indicatif', (tester) async {
    await pumpOnboarding(tester);

    await tester.ensureVisible(find.byKey(countryField));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(countryField));
    await tester.pumpAndSettle();
    expect(find.text('country_picker_title'.tr), findsOneWidget);
    // Sans accent ni majuscule.
    await tester.enterText(find.byKey(search), 'keny');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('country-picker-KE')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(countryField),
        matching: find.text('🇰🇪 Kenya'),
      ),
      findsOneWidget,
    );
    expect(
      tester.state<FormFieldState<String>>(find.byKey(countryField)).value,
      'Kenya',
    );
    // Le numéro n'était pas encore tapé : l'indicatif suit le pays.
    expect(dialShows('🇰🇪 +254'), findsOneWidget);
  });
}
