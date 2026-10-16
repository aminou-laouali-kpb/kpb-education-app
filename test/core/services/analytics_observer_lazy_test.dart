// Garde : l'observateur d'écrans Firebase est PARESSEUX.
//
// Le défaut corrigé : `navigatorObservers` construisait
// `FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)` dès sa
// première lecture, au premier `build` de l'app. Si `Firebase.initializeApp`
// avait échoué (démarrage hors ligne, web non configuré), `instance` levait
// « no-app » et l'app plantait avant son premier écran — sur mobile aussi.
//
// Ici, aucun test n'initialise Firebase : c'est exactement ce cas-là.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/services/analytics_service.dart';

class _RecordingObserver extends NavigatorObserver {
  final events = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('push:${route.settings.name}');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('pop:${route.settings.name}');
}

class _ThrowingObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      throw StateError('analytics en panne');
}

Route<void> _route(String name) => MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => const SizedBox.shrink(),
    );

void main() {
  group('Firebase non initialisé', () {
    test('lire les observateurs ne lève pas', () {
      expect(
          () => AnalyticsService.instance.navigatorObservers, returnsNormally);
      expect(AnalyticsService.instance.observer,
          isA<LazyFirebaseAnalyticsObserver>());
    });

    test('un changement d\'écran est ignoré, sans exception', () {
      final observer = LazyFirebaseAnalyticsObserver();
      expect(() => observer.didPush(_route('/a'), null), returnsNormally);
      expect(
          () => observer.didReplace(newRoute: _route('/b')), returnsNormally);
      expect(
          () => observer.didPop(_route('/b'), _route('/a')), returnsNormally);
      expect(() => observer.didRemove(_route('/a'), null), returnsNormally);
      expect(observer.delegate, isNull);
    });

    testWidgets('l\'app navigue avec les observateurs installés',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        navigatorObservers: AnalyticsService.instance.navigatorObservers,
        home: const Text('accueil'),
      ));
      unawaited(key.currentState!.push(_route('/detail')));
      await tester.pumpAndSettle();
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('accueil'), findsOneWidget);
    });
  });

  group('création paresseuse', () {
    test('rien n\'est créé à la construction', () {
      var created = 0;
      final observer = LazyFirebaseAnalyticsObserver(
        isFirebaseReady: () => true,
        createDelegate: () {
          created++;
          return _RecordingObserver();
        },
      );
      expect(created, 0);
      expect(observer.delegate, isNull);
    });

    test('créé au premier écran, une seule fois, puis relayé', () {
      var created = 0;
      final recorder = _RecordingObserver();
      final observer = LazyFirebaseAnalyticsObserver(
        isFirebaseReady: () => true,
        createDelegate: () {
          created++;
          return recorder;
        },
      );
      observer.didPush(_route('/a'), null);
      observer.didPush(_route('/b'), _route('/a'));
      observer.didPop(_route('/b'), _route('/a'));
      expect(created, 1);
      expect(recorder.events, ['push:/a', 'push:/b', 'pop:/b']);
    });

    test('Firebase prêt plus tard : l\'observateur est créé à ce moment-là',
        () {
      var ready = false;
      final recorder = _RecordingObserver();
      final observer = LazyFirebaseAnalyticsObserver(
        isFirebaseReady: () => ready,
        createDelegate: () => recorder,
      );
      observer.didPush(_route('/a'), null);
      expect(observer.delegate, isNull);
      ready = true;
      observer.didPush(_route('/b'), null);
      expect(recorder.events, ['push:/b']);
    });

    test('une création ou un relais qui lève est avalé', () {
      final failingCreate = LazyFirebaseAnalyticsObserver(
        isFirebaseReady: () => true,
        createDelegate: () => throw StateError('no-app'),
      );
      expect(() => failingCreate.didPush(_route('/a'), null), returnsNormally);
      expect(failingCreate.delegate, isNull);

      final failingDelegate = LazyFirebaseAnalyticsObserver(
        isFirebaseReady: () => true,
        createDelegate: _ThrowingObserver.new,
      );
      expect(
          () => failingDelegate.didPush(_route('/a'), null), returnsNormally);

      final failingCheck = LazyFirebaseAnalyticsObserver(
        isFirebaseReady: () => throw StateError('plateforme absente'),
      );
      expect(() => failingCheck.didPush(_route('/a'), null), returnsNormally);
    });
  });
}
