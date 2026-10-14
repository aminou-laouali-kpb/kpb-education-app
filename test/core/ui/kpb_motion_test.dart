// KpbMotion.of et StaggeredSlide : le mouvement se coupe quand l'utilisateur
// l'a demandé (système ou mode données réduites), et les listes n'animent que
// leurs premiers éléments.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/kpb_components.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}

/// Les FadeTransition posées PAR StaggeredSlide (la route en a aussi).
Finder _fadeInside(Finder text) => find.descendant(
      of: find.ancestor(of: text, matching: find.byType(StaggeredSlide)),
      matching: find.byType(FadeTransition),
    );

void main() {
  tearDown(() => KpbMotion.dataSaverProbe = null);

  group('KpbMotion.of', () {
    testWidgets('durées nominales par défaut', (tester) async {
      late KpbMotionSpec spec;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        spec = KpbMotion.of(context);
        return const SizedBox();
      })));
      expect(spec.enabled, isTrue);
      expect(spec.fast, KpbMotion.fast);
      expect(spec.base, KpbMotion.base);
      expect(spec.page, KpbMotion.page);
    });

    testWidgets('durées nulles si le système coupe les animations',
        (tester) async {
      late KpbMotionSpec spec;
      await tester.pumpWidget(_host(
        Builder(builder: (context) {
          spec = KpbMotion.of(context);
          return const SizedBox();
        }),
        disableAnimations: true,
      ));
      expect(spec.enabled, isFalse);
      expect(spec.fast, Duration.zero);
      expect(spec.reveal, Duration.zero);
      expect(spec.scale(const Duration(seconds: 1)), Duration.zero);
    });

    testWidgets('durées nulles en mode données réduites', (tester) async {
      KpbMotion.dataSaverProbe = () => true;
      late KpbMotionSpec spec;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        spec = KpbMotion.of(context);
        return const SizedBox();
      })));
      expect(spec.enabled, isFalse);
      expect(spec.base, Duration.zero);
      expect(KpbMotion.resolve().enabled, isFalse);
    });

    test('une sonde qui lève ne coupe rien', () {
      KpbMotion.dataSaverProbe = () => throw StateError('pas de contrôleur');
      expect(KpbMotion.resolve().enabled, isTrue);
    });
  });

  group('StaggeredSlide', () {
    testWidgets('anime les 6 premiers éléments, pas les suivants',
        (tester) async {
      await tester.pumpWidget(_host(ListView(
        children: [
          for (var i = 0; i < 9; i++)
            StaggeredSlide(index: i, child: Text('item $i')),
        ],
      )));
      for (var i = 0; i < 9; i++) {
        final animated = _fadeInside(find.text('item $i'));
        expect(animated,
            i < KpbMotion.staggerMaxItems ? findsWidgets : findsNothing,
            reason: 'élément $i');
      }
      await tester.pumpAndSettle();
    });

    testWidgets('aucune animation quand le mouvement est coupé',
        (tester) async {
      await tester.pumpWidget(_host(
        const StaggeredSlide(index: 0, child: Text('seul')),
        disableAnimations: true,
      ));
      expect(_fadeInside(find.text('seul')), findsNothing);
      // Ni minuteur ni contrôleur : le test se termine sans rien faire
      // avancer (le framework échouerait sur un minuteur en attente).
    });
  });
}
