// Audit build 57, T1-10 (suite) : « Autre indicatif » dans le menu du
// téléphone fait apparaître un champ où l'élève tape le sien.

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

  testWidgets('« Autre indicatif » ouvre le champ de saisie de l’indicatif',
      (tester) async {
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

    const customField = ValueKey('onboarding-custom-dial-code');
    expect(find.byKey(customField), findsNothing);

    await tester.tap(find.text('🇳🇪 +227 · Niger').first);
    await tester.pumpAndSettle();
    final other = find.text('🌍 ${'dial_code_other'.tr}');
    // Le menu ne construit que les lignes visibles : on le fait défiler.
    final menu = find
        .ancestor(
          of: find.text('🇳🇪 +227 · Niger').last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(other, 300, scrollable: menu);
    await tester.pumpAndSettle();
    await tester.tap(other.last);
    await tester.pumpAndSettle();

    expect(find.byKey(customField), findsOneWidget);
    expect(find.text('dial_code_custom_label'.tr), findsOneWidget);
  });
}
