// Revue avant la 58 : la ligne « Résumé généré par l'IA » + puces FR/EN du
// générateur de CV.
//
// Avant : `Row(Text, Spacer, ChoiceChip FR, ChoiceChip EN)`, sans Expanded. Le
// titre gardait sa largeur naturelle ; au texte agrandi ou sur un écran de
// 320 pt, la ligne débordait et la puce « EN » sortait de l'écran — la version
// anglaise du résumé, celle d'une candidature à l'étranger, devenait
// inaccessible. Cet état (après génération) n'était monté par aucun test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/features/tools/cv_generator_screen.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

const _se1 = KpbViewport(
  id: 'se1',
  name: 'iPhone SE 1 320×568',
  size: Size(320, 568),
  padding: EdgeInsets.only(top: 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  final cases = <(KpbViewport, double)>[
    (_se1, 1.0),
    (_se1, 1.3),
    (compactAndroid, 1.0),
    (compactAndroid, 1.3),
    (compactAndroid, 1.5),
  ];

  for (final (viewport, scale) in cases) {
    testWidgets('$viewport ×$scale : la puce EN reste touchable',
        (tester) async {
      final api = MockApiClient();
      when(() => api.postAi(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'fr': 'Étudiante motivée en informatique.',
          'en': 'Motivated computer science student.',
        },
      );
      await seedKpbController(apiClient: api);

      final report = await pumpKpbScreen(
        tester,
        screen: const CvGeneratorScreen(),
        viewport: viewport,
        textScale: scale,
      );
      expect(report.overflows, isEmpty, reason: '$report');

      final generate = find.text('cv_enhance_with_ai'.tr);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(generate, 200, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(generate);
      await tester.pumpAndSettle();

      final heading = find.text('cv_ai_summary_heading'.tr);
      await tester.scrollUntilVisible(heading, 200, scrollable: list);
      await tester.pumpAndSettle();
      expect(heading, findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'La ligne titre + FR/EN ne doit pas déborder.',
      );

      final en = find.widgetWithText(ChoiceChip, 'EN');
      await tester.ensureVisible(en);
      await tester.pumpAndSettle();
      expect(
        tester.getTopRight(en).dx,
        lessThanOrEqualTo(viewport.size.width),
        reason: "La puce EN sort de l'écran.",
      );
      await tester.tap(en);
      await tester.pumpAndSettle();
      expect(find.text('Motivated computer science student.'), findsOneWidget);
    });
  }
}
