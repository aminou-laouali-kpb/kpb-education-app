// KpbAsyncView : squelette → contenu / vide / erreur avec « Réessayer », et
// le bandeau « Mis à jour il y a X » quand le contenu vient du cache.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/core/ui/skeleton.dart';

Widget _app(Widget body, {bool disableAnimations = false}) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: body),
      ),
    );

KpbAsyncView _view(
  KpbAsyncPhase phase, {
  VoidCallback? onRetry,
  DateTime? updatedAt,
  bool refreshable = false,
}) =>
    KpbAsyncView(
      phase: phase,
      onRetry: onRetry,
      updatedAt: updatedAt,
      refreshable: refreshable,
      builder: (_) => const Text('contenu'),
    );

void main() {
  group('phaseOf', () {
    test('des données non vides gagnent, même pendant un rafraîchissement', () {
      expect(
        KpbAsyncView.phaseOf(loading: true, hasData: true, failed: true),
        KpbAsyncPhase.content,
      );
    });
    test('sans données : chargement, puis erreur, puis vide', () {
      expect(KpbAsyncView.phaseOf(loading: true, hasData: false),
          KpbAsyncPhase.loading);
      expect(KpbAsyncView.phaseOf(loading: false, hasData: false, failed: true),
          KpbAsyncPhase.error);
      expect(KpbAsyncView.phaseOf(loading: false, hasData: false),
          KpbAsyncPhase.empty);
      expect(
        KpbAsyncView.phaseOf(loading: false, hasData: true, isEmpty: true),
        KpbAsyncPhase.empty,
      );
    });
  });

  testWidgets('chargement : un squelette, pas un spinner', (tester) async {
    await tester.pumpWidget(_app(_view(KpbAsyncPhase.loading)));
    expect(find.byType(KpbSkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('contenu'), findsNothing);
    expect(find.bySemanticsLabel('Chargement…'), findsOneWidget);
  });

  testWidgets('squelette figé quand le mouvement est coupé', (tester) async {
    await tester.pumpWidget(
      _app(_view(KpbAsyncPhase.loading), disableAnimations: true),
    );
    // Aucune animation en boucle : pumpAndSettle aboutit.
    await tester.pumpAndSettle();
    expect(find.byType(KpbSkeletonList), findsOneWidget);
  });

  testWidgets('contenu', (tester) async {
    await tester.pumpWidget(_app(_view(KpbAsyncPhase.content)));
    expect(find.text('contenu'), findsOneWidget);
    expect(find.byType(KpbCacheStamp), findsNothing);
  });

  testWidgets('vide : état par défaut', (tester) async {
    await tester.pumpWidget(_app(_view(KpbAsyncPhase.empty)));
    await tester.pumpAndSettle();
    expect(find.byType(KpbEmptyState), findsOneWidget);
    expect(find.text('Rien à afficher pour l\'instant'), findsOneWidget);
  });

  testWidgets('erreur : « Réessayer » relance', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(_view(KpbAsyncPhase.error, onRetry: () => retries++)),
    );
    expect(find.byType(KpbErrorState), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retries, 1);
  });

  testWidgets('cache : « Mis à jour il y a X » au-dessus du contenu',
      (tester) async {
    await tester.pumpWidget(_app(_view(
      KpbAsyncPhase.content,
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      onRetry: () {},
    )));
    expect(find.text('contenu'), findsOneWidget);
    expect(find.text('Mis à jour il y a 3 h'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('refreshable : les états hors contenu restent défilables',
      (tester) async {
    await tester.pumpWidget(_app(RefreshIndicator(
      onRefresh: () async {},
      child: _view(KpbAsyncPhase.empty, refreshable: true),
    )));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.byType(KpbEmptyState),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
  });

  group('kpbUpdatedAgoLabel', () {
    setUp(() {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
    });
    final now = DateTime(2026, 10, 14, 12);
    test('à l\'instant, minutes, heures, jours', () {
      expect(kpbUpdatedAgoLabel(now, now: now), 'Mis à jour à l\'instant');
      expect(
        kpbUpdatedAgoLabel(now.subtract(const Duration(minutes: 5)), now: now),
        'Mis à jour il y a 5 min',
      );
      expect(
        kpbUpdatedAgoLabel(now.subtract(const Duration(hours: 2)), now: now),
        'Mis à jour il y a 2 h',
      );
      expect(
        kpbUpdatedAgoLabel(now.subtract(const Duration(days: 3)), now: now),
        'Mis à jour il y a 3 j',
      );
    });
    test('une horloge en retard ne dit pas « il y a -2 min »', () {
      expect(
        kpbUpdatedAgoLabel(now.add(const Duration(minutes: 2)), now: now),
        'Mis à jour à l\'instant',
      );
    });
  });
}
