// Accessibilité des primitives et de la navigation :
//  * KpbPressable, KpbCard (tappable) et QuickActionTile sont annoncés comme
//    des boutons ;
//  * un TextButton offre une cible d'au moins 48 × 48 dp ;
//  * les libellés de la barre de navigation font au moins 11 sp, et l'onglet
//    Bourses n'utilise plus la cloche (réservée aux notifications).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/shell/app_shell.dart';

import '../../widget_test_helpers.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.buildTheme(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('Semantics(button)', () {
    testWidgets('KpbPressable, KpbCard et QuickActionTile sont des boutons',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KpbPressable(onTap: () {}, child: const Text('presse')),
          KpbCard(onTap: () {}, child: const Text('carte')),
          KpbCard(
            variant: KpbCardVariant.interactive,
            onTap: () {},
            child: const Text('carte interactive'),
          ),
          SizedBox(
            width: 120,
            child: QuickActionTile(
              icon: Icons.school_rounded,
              label: 'action',
              color: KpbColors.actionPrimary,
              onTap: () {},
            ),
          ),
          const KpbCard(child: Text('statique')),
        ],
      )));
      for (final label in [
        'presse',
        'carte',
        'carte interactive',
        'action',
      ]) {
        expect(
          tester.getSemantics(find.text(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: label,
        );
      }
      expect(
        tester.getSemantics(find.text('statique')),
        matchesSemantics(label: 'statique'),
      );
      semantics.dispose();
    });
  });

  testWidgets('TextButton : cible d\'au moins 48 × 48 dp', (tester) async {
    await tester.pumpWidget(_host(
      TextButton(onPressed: () {}, child: const Text('OK')),
    ));
    final size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  group('barre de navigation', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    Future<void> pumpShell(WidgetTester tester) => pumpTestApp(
          tester,
          child: const AppShell(),
          initialSnapshot: AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(),
          ),
        );

    testWidgets('libellés d\'au moins 11 sp', (tester) async {
      await pumpShell(tester);
      final labels = find.descendant(
        of: find.byKey(const ValueKey('kpb_shell_nav_bar')),
        matching: find.byType(Text),
      );
      expect(labels, findsNWidgets(5));
      for (final element in labels.evaluate()) {
        final text = element.widget as Text;
        expect(text.style!.fontSize, greaterThanOrEqualTo(11));
      }
      await tester.pumpAndSettle();
    });

    testWidgets('Bourses : workspace_premium, pas la cloche', (tester) async {
      await pumpShell(tester);
      final tab = find.byKey(const ValueKey('kpb_nav_scholarships'));
      final icons = find
          .descendant(of: tab, matching: find.byType(Icon))
          .evaluate()
          .map((e) => (e.widget as Icon).icon)
          .toList();
      expect(
        icons.single,
        anyOf(
          Icons.workspace_premium_outlined,
          Icons.workspace_premium_rounded,
        ),
      );
      final bells = [
        Icons.notifications_none_rounded,
        Icons.notifications_active_rounded,
      ];
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kpb_shell_nav_bar')),
          matching: find.byWidgetPredicate(
            (w) => w is Icon && bells.contains(w.icon),
          ),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });
  });
}
