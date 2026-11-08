// Revue avant la 58 : la feuille « Pourquoi ce match ».
//
// Avant : `showModalBottomSheet` sans `isScrollControlled`, donc plafonnée à
// 9/16 de l'écran, avec une Column non défilable. Sur un iPhone SE ou au texte
// agrandi, la colonne débordait et le seul bouton d'action, « Améliorer mon
// profil » (le dernier), était rogné sans moyen de l'atteindre.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/features/search/match_explanation_sheet.dart';

import '../../support/screen_harness.dart';

const _se1 = KpbViewport(
  id: 'se1',
  name: 'iPhone SE 1 320×568',
  size: Size(320, 568),
  padding: EdgeInsets.only(top: 20),
);

const _se2 = KpbViewport(
  id: 'se2',
  name: 'iPhone SE 2/3 375×667',
  size: Size(375, 667),
  padding: EdgeInsets.only(top: 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  final cases = <(KpbViewport, double)>[
    (_se1, 1.0),
    (_se1, 1.5),
    (_se2, 1.3),
    (iphone14, 1.5),
  ];

  for (final (viewport, scale) in cases) {
    testWidgets('$viewport ×$scale : « Améliorer mon profil » est atteignable',
        (tester) async {
      final AppController controller = await seedKpbController();
      await pumpKpbScreen(
        tester,
        viewport: viewport,
        textScale: scale,
        routesShareMediaQuery: true,
        screen: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showMatchExplanation(
                  context,
                  'Master Informatique — Université Paris-Saclay, '
                  'parcours Intelligence artificielle',
                  ProfileFit.strong,
                  const <String>[
                    'Ton niveau d\'études correspond au niveau d\'entrée '
                        'du programme.',
                    'Le domaine du programme fait partie de tes domaines '
                        'd\'intérêt.',
                    'Les frais de scolarité restent dans ta tranche de '
                        'budget déclarée.',
                  ],
                  controller,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'La feuille ne doit pas déborder.',
      );

      final cta = find.text('improve_profile'.tr);
      expect(cta, findsOneWidget);
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(cta).dy,
        lessThanOrEqualTo(viewport.size.height),
        reason: 'Le bouton reste sous le bas de l\'écran.',
      );
      // Touchable : le hit-test atteint bien le bouton.
      await tester.tap(cta, warnIfMissed: true);
      expect(tester.takeException(), isNull);
    });
  }
}
