// `kpb_screen` : l'écran Flutter courant, en super propriété PostHog, pour
// les événements natifs (`$rageclick`) dont le `$screen_name` vaut sinon
// « Flutter » partout.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/observability/posthog_screen_context_observer.dart';

void main() {
  late List<(String, Object)> registered;
  late PosthogScreenContextObserver observer;

  setUp(() {
    registered = [];
    observer = PosthogScreenContextObserver(
      register: (key, value) async => registered.add((key, value)),
    );
  });

  Route<dynamic> page(String? name) => MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => const SizedBox(),
      );

  test('même nommage que PosthogObserver : `/` devient root (\'/\')', () {
    expect(PosthogScreenContextObserver.screenNameFor(page('/')), "root ('/')");
    expect(
        PosthogScreenContextObserver.screenNameFor(page('/OnboardingScreen')),
        '/OnboardingScreen');
    expect(PosthogScreenContextObserver.screenNameFor(page(null)), isNull);
    expect(PosthogScreenContextObserver.screenNameFor(page('  ')), isNull);
  });

  test('seules les PageRoute comptent : une feuille ne remplace pas l\'écran',
      () {
    final sheet = ModalBottomSheetRoute<void>(
      settings: const RouteSettings(name: 'sheet'),
      builder: (_) => const SizedBox(),
      isScrollControlled: false,
    );
    expect(PosthogScreenContextObserver.screenNameFor(sheet), isNull);
  });

  test('push, replace et pop publient l\'écran affiché, sans doublon', () {
    final home = page('/');
    final onboarding = page('/OnboardingScreen');
    final aha = page('/AhaMomentScreen');

    observer.didPush(home, null);
    observer.didPush(onboarding, home);
    observer.didPush(onboarding, home); // même écran : rien de plus
    observer.didReplace(newRoute: aha, oldRoute: onboarding);
    observer.didPop(aha, home);

    expect(registered, [
      (kPosthogScreenProperty, "root ('/')"),
      (kPosthogScreenProperty, '/OnboardingScreen'),
      (kPosthogScreenProperty, '/AhaMomentScreen'),
      (kPosthogScreenProperty, "root ('/')"),
    ]);
  });

  test('un retrait (offAll) ne réécrit pas l\'écran qui vient d\'être poussé',
      () {
    final old = page('/OnboardingScreen');
    final fresh = page('/AhaMomentScreen');
    observer.didPush(fresh, old);
    observer.didRemove(old, null);
    expect(registered.last, (kPosthogScreenProperty, '/AhaMomentScreen'));
  });

  test('un échec du SDK ne remonte pas dans la navigation', () {
    final failing = PosthogScreenContextObserver(
      register: (key, value) => Future.error(StateError('channel down')),
    );
    expect(() => failing.didPush(page('/x'), null), returnsNormally);
  });
}
