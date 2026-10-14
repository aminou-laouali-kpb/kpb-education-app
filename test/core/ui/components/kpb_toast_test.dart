// KpbToast : quatre sortes, un titre facultatif (jamais « KPB Education »),
// une action facultative, et deux surfaces au même rendu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/ui/kpb_components.dart';

Future<void> _drain(WidgetTester tester) async {
  Get.closeAllSnackbars();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('surface GetX (sans contexte)', () {
    testWidgets('message, titre et icône de la sorte', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      KpbToast.error('Envoi impossible', title: 'Pièce jointe');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Envoi impossible'), findsOneWidget);
      expect(find.text('Pièce jointe'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('le titre « KPB Education » est ignoré', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      KpbToast.success('Demande envoyée', title: 'KPB Education');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.text('KPB Education'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('action : ferme le bandeau puis agit', (tester) async {
      var undone = 0;
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      KpbToast.info(
        'Élément supprimé',
        action: KpbToastAction(label: 'Annuler', onPressed: () => undone++),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Annuler'));
      await tester.pump();
      expect(undone, 1);
      await _drain(tester);
      expect(find.text('Élément supprimé'), findsNothing);
    });

    testWidgets('hors ligne : icône nuage barré', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      KpbToast.offlinePending('Gardé sur ton téléphone');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('disparaît seul après sa durée', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      KpbToast.success('Profil mis à jour');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Profil mis à jour'), findsOneWidget);
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Profil mis à jour'), findsNothing);
    });
  });

  group('surface Material (avec contexte)', () {
    testWidgets('SnackBar rattachée à l\'écran, même contenu', (tester) async {
      var retried = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => KpbToast.error(
                'Envoi impossible',
                context: context,
                action: KpbToastAction(
                  label: 'Réessayer',
                  onPressed: () => retried++,
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(KpbToastBody), findsOneWidget);
      expect(find.text('Envoi impossible'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });
  });

  test('durées par défaut', () {
    expect(KpbToast.defaultDuration(KpbToastKind.success),
        const Duration(seconds: 3));
    expect(KpbToast.defaultDuration(KpbToastKind.info),
        const Duration(seconds: 3));
    expect(KpbToast.defaultDuration(KpbToastKind.error),
        const Duration(seconds: 4));
    expect(KpbToast.defaultDuration(KpbToastKind.offlinePending),
        const Duration(seconds: 4));
    expect(
      KpbToast.defaultDuration(KpbToastKind.success, hasAction: true),
      const Duration(seconds: 6),
    );
  });
}
