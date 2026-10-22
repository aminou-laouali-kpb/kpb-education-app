// Audit 57, F14 : l'interrupteur « Nouvelles et offres de KPB par e-mail » du
// Profil se lit, au lecteur d'écran, avec son libellé et son état — comme
// tout interrupteur de réglage. Le choix de langue (deux boutons) garde ses
// propres nœuds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  testWidgets('consentement e-mail : libellé, explication et état ensemble',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpTestApp(
      tester,
      child: const ProfileScreen(),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile().copyWith(promotionsEmailOptIn: false),
      ),
    );

    final toggle =
        find.byKey(const ValueKey<String>('profile-promotions-email'));
    await tester.scrollUntilVisible(toggle, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    final node = tester.getSemantics(toggle);
    expect(node.label, contains('profile_promotions_email'));
    expect(node.label, contains('profile_promotions_email_desc'));
    expect(node, isSemantics(hasToggledState: true, isToggled: false));

    // Lettre d'information : même lecture.
    final newsletter = tester.getSemantics(find.text('profile_newsletter'));
    expect(newsletter, isSemantics(hasToggledState: true));
    semantics.dispose();
  });
}
