// KPB Intelligence au texte agrandi (audit build 57, T7-08) : les réponses
// suivent la taille du texte du téléphone, et le champ de question ne rogne plus
// ce que l'élève tape. Avant : `RichText` sans échelle (les réponses restaient en
// 13 pt) et un champ de 46 pt fixes sur une seule ligne.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/ai_advisor/ai_chat_screen.dart';

import '../support/screen_harness.dart';
import '../widget_test_helpers.dart';

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  testWidgets(
      'texte à 1,5 : la réponse est mise à l\'échelle, le champ '
      'grandit avec plusieurs lignes', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await seedKpbController();
    await tester.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: kpbClampedScaler(kpbMaxTextScale)),
        child: child!,
      ),
      home: const AiChatScreen(),
    ));
    await tester.pumpAndSettle();

    // La bulle de bienvenue (« Bonjour <prénom> ! ») : son paragraphe suit
    // l'échelle du téléphone.
    final bubble = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Bonjour'));
    expect(bubble, findsWidgets);
    final paragraph = tester.renderObject<RenderParagraph>(bubble.first);
    expect(paragraph.textScaler, isNot(TextScaler.noScaling));
    expect(paragraph.textScaler.scale(13), closeTo(13 * kpbMaxTextScale, 0.1));

    // Le champ : plusieurs lignes, et sa boîte n'est plus figée à 46 pt.
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    await tester.enterText(
        field, List.filled(12, 'Une longue question').join(' '));
    await tester.pumpAndSettle();
    final box =
        find.ancestor(of: field, matching: find.byType(Container)).first;
    expect(tester.getSize(box).height, greaterThan(46),
        reason: 'le champ doit grandir avec le texte agrandi, pas rogner');
    expect(tester.widget<TextField>(field).maxLines, 4);
    expect(tester.takeException(), isNull);
  });
}
