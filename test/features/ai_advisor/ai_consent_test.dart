import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/ai_advisor/ai_consent.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  Future<AppController> pumpHost(
    WidgetTester tester, {
    required UserProfile profile,
  }) async {
    final controller = await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ensureAiConsent(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('already-consented profile skips the dialog', (tester) async {
    await pumpHost(tester, profile: createTestProfile());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('missing consent shows the dialog and decline keeps it unset',
      (tester) async {
    final controller = await pumpHost(
      tester,
      profile: createTestProfile(withAiConsent: false),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('ai_consent_decline'.tr));
    await tester.pumpAndSettle();
    expect(controller.profile?.hasAiConsent, isFalse);
  });

  // Revue avant la 58 : le corps du consentement (~520 caractères) était dans
  // un AlertDialog NON défilable. Au texte agrandi ou sur 320 pt, il était
  // rogné en bas — « part tel quel », « Tu peux refuser » — et l'élève
  // acceptait un transfert de données sans avoir pu le lire. Un paragraphe
  // rogné ne lève pas d'exception : on mesure donc la hauteur que le texte
  // DEMANDE contre celle qu'il a reçue, puis on vérifie qu'on atteint la fin.
  group('le consentement se lit en entier', () {
    const se1 = KpbViewport(
      id: 'se1',
      name: 'iPhone SE 1 320×568',
      size: Size(320, 568),
      padding: EdgeInsets.only(top: 20),
    );
    final cases = <(KpbViewport, double)>[
      (se1, 1.0),
      (se1, 1.5),
      (compactAndroid, 1.5),
      (iphone14, 1.5),
    ];
    for (final (viewport, scale) in cases) {
      testWidgets('$viewport ×$scale', (tester) async {
        await seedKpbController();
        await pumpKpbScreen(
          tester,
          viewport: viewport,
          textScale: scale,
          routesShareMediaQuery: true,
          screen: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => askAiConsent(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final body = find.text('ai_consent_body'.tr);
        final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
          of: body,
          matching: find.byType(RichText),
        ));
        final needed = paragraph.getMinIntrinsicHeight(paragraph.size.width);
        expect(
          paragraph.size.height,
          moreOrLessEquals(needed, epsilon: 1),
          reason: 'Le corps est rogné : il demande ${needed.round()} px et '
              'n\'en reçoit que ${paragraph.size.height.round()}.',
        );

        // On fait défiler jusqu'au bout : la fin du texte est à l'écran.
        await tester.drag(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          ),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        final screenBottom = viewport.size.height;
        expect(
          tester.getBottomLeft(body).dy,
          lessThanOrEqualTo(screenBottom),
        );
        // Les deux boutons restent à l'écran.
        for (final key in ['ai_consent_decline', 'ai_consent_accept']) {
          final button = find.text(key.tr);
          expect(button, findsOneWidget);
          expect(
              tester.getBottomLeft(button).dy, lessThanOrEqualTo(screenBottom));
          expect(tester.getTopLeft(button).dy, greaterThanOrEqualTo(0));
        }
      });
    }
  });
}
