// Profil (chantier G) : les notifications et « Mes suivis » sont à deux taps —
// jusqu'ici, les préférences ne se trouvaient que par la cloche de l'accueil.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/notifications/notifications_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  testWidgets('l\'entrée « Notifications » du Profil ouvre le centre',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpTestApp(
      tester,
      child: const ProfileScreen(),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    );

    expect(find.text('followed_title'), findsOneWidget);
    final entry = find.text('notifications_title');
    await tester.scrollUntilVisible(entry, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  // Audit build 57, n° 4 : la tuile proposait le programme rémunéré, coupé
  // exprès, à tout élève (mineurs compris).
  testWidgets('pas de tuile « Espace ambassadeur » programme rémunéré fermé',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpTestApp(
      tester,
      child: const ProfileScreen(),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    );

    // Tiroir : les accès rapides sont bien rendus.
    expect(find.text('referral_title'), findsWidgets);
    expect(find.text('referral_become_ambassador'),
        AppConfig.ambassadorCashEnabled ? findsOneWidget : findsNothing);
  });
}
