// Écran d'entrée : les trois actions restent visibles sans défiler, sur petit
// téléphone et au texte agrandi (audit build 57, T1-04 et T7-13). Avant, tout
// défilait ensemble : « Explorer sans compte » descendait sous la ligne de
// flottaison, et au texte maximal aucune action n'était visible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/auth/auth_welcome_screen.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  // Le plus petit appareil supporté (iPhone SE, 375×667) et un Android 360×640,
  // aux crans de texte courants et au plafond de l'app.
  const sizes = <Size>[Size(375, 667), Size(360, 640)];
  const scales = <double>[1.0, 1.3, kpbMaxTextScale];

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()} @ $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final auth = _MockAuthService();
        when(() => auth.onAuthStateChange)
            .thenAnswer((_) => const Stream.empty());
        when(() => auth.isLoggedIn).thenReturn(false);
        Get.put<AuthService>(auth, permanent: true);

        await tester.pumpWidget(GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('fr'),
          fallbackLocale: const Locale('fr'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: kpbClampedScaler(scale)),
            child: child!,
          ),
          home: const AuthWelcomeScreen(),
        ));
        await tester.pumpAndSettle();

        final fr = AppTranslations().keys['fr']!;
        for (final key in const [
          'auth_continue_google',
          'auth_receive_email_link',
          'auth_explore_guest',
        ]) {
          final rect = tester.getRect(find.text(fr[key]!));
          expect(rect.top, greaterThanOrEqualTo(0), reason: key);
          expect(rect.bottom, lessThanOrEqualTo(size.height),
              reason: '$key est sous la ligne de flottaison (${rect.bottom})');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
