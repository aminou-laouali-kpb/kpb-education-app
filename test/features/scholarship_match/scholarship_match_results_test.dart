// Les résultats : tous les états honnêtes, aucun « % » hors citation
// officielle, le run hors ligne daté, « Clôturée » seulement pour une date
// limite confirmée passée, « Plus disponible », la relance d'un run périmé à
// l'ouverture (avec le toast des différences), « Suivre les N » (un déjà suivi
// reste suivi, « Annuler » ne retire que les nouveaux).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/core/services/scholarship_match_store.dart';
import 'package:karatou/app/features/cases/case_composer_sheet.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_results_screen.dart';

import 'match_test_support.dart';

Key _k(String value) => ValueKey<String>(value);

Future<void> _open(
  WidgetTester t,
  FakeMatchApi api, {
  DateTime? now,
}) =>
    pumpMatchApp(
      t,
      child: ScholarshipMatchResultsScreen(
        source: 'test',
        now: now ?? DateTime.utc(2026, 10, 15),
      ),
      api: api,
    );

Future<void> _scrollTo(WidgetTester t, Key key) async {
  await t.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.ensureVisible(find.byKey(key));
  await t.pumpAndSettle();
}

void main() {
  tearDown(tearDownMatchWorld);

  testWidgets('en-tête daté, comptes honnêtes, deux sections', (t) async {
    resetMatchWorld();
    await _open(
        t, FakeMatchApi(state: matchStateJson(latestRun: matchRunJson())));
    expect(find.text('Tes bourses — 13/10/2026'), findsOneWidget);
    expect(find.text('2 compatibles · 1 à vérifier'), findsOneWidget);
    expect(find.text('Compatibles avec ton profil'), findsOneWidget);
    expect(find.byKey(_k('match-fewer-than-ten')), findsOneWidget);
    expect(find.text('3 bourses trouvées pour ton profil.'), findsOneWidget);
    expect(find.text('Ouverte aux ressortissants du Niger'), findsWidgets);
    await _scrollTo(t, _k('match-section-to-verify'));
    expect(find.text('À vérifier avant de postuler'), findsOneWidget);
  });

  testWidgets('aucun « % » à l\'écran, sauf dans la citation officielle',
      (t) async {
    resetMatchWorld();
    await _open(
        t, FakeMatchApi(state: matchStateJson(latestRun: matchRunJson())));
    await _scrollTo(t, _k('match-official-toggle'));
    await t.tap(find.byKey(_k('match-official-toggle')));
    await t.pumpAndSettle();
    expect(find.byKey(_k('match-official-text')), findsOneWidget);
    expect(find.byKey(_k('match-official-source')), findsOneWidget);
    final quote = t.widget<Text>(find.byKey(_k('match-official-text'))).data!;
    for (final text in renderedTexts(t)) {
      if (text == quote) continue;
      expect(text.contains('%'), isFalse, reason: text);
      expect(text.toLowerCase().contains('chance'), isFalse, reason: text);
    }
    expect(quote, contains('70 %'));
  });

  testWidgets('texte de niveau tiré des données (doctorat)', (t) async {
    resetMatchWorld();
    await _open(
      t,
      FakeMatchApi(
        state: matchStateJson(
          latestRun: matchRunJson(
            items: [matchItemJson(id: 'gates', name: 'Gates Cambridge')],
            levelCatalog: {
              'level': 'doctorate',
              'count': 1,
              'label': '1 bourse doctorale dans notre catalogue pour l’instant',
            },
          ),
        ),
      ),
    );
    expect(
      find.text('1 bourse doctorale dans notre catalogue pour l’instant'),
      findsOneWidget,
    );
    expect(find.text('1 bourse trouvée pour ton profil.'), findsOneWidget);
  });

  testWidgets('0 compatible mais des « à vérifier »', (t) async {
    resetMatchWorld();
    await _open(
      t,
      FakeMatchApi(
        state: matchStateJson(
          latestRun: matchRunJson(
            items: [
              matchItemJson(id: 'a', section: 'to_verify', status: 'to_verify'),
              matchItemJson(
                  id: 'b', rank: 2, section: 'to_verify', status: 'to_verify'),
            ],
            precisionLimitedBy: 'kpb',
          ),
        ),
      ),
    );
    expect(
      find.text('Aucune bourse n\'est clairement compatible aujourd\'hui, '
          '2 sont à vérifier.'),
      findsOneWidget,
    );
    expect(find.byKey(_k('match-precision')), findsOneWidget);
    expect(find.byKey(_k('match-follow-all')), findsNothing);
  });

  testWidgets(
      '0 de chaque : catalogue sans bourse compatible, résumé, '
      'interrupteur et conseiller', (t) async {
    resetMatchWorld();
    await _open(
      t,
      FakeMatchApi(
        state: matchStateJson(latestRun: matchRunJson(items: const [])),
      ),
    );
    expect(
      find.text('Pas encore de bourse compatible dans notre catalogue.'),
      findsOneWidget,
    );
    expect(find.byKey(_k('match-excluded-summary')), findsOneWidget);
    expect(
      find.text('Pourquoi certaines bourses n\'apparaissent pas (12)'),
      findsOneWidget,
    );
    await _scrollTo(t, _k('match-alerts'));
    expect(find.byKey(_k('match-advisor')), findsOneWidget);
    expect(find.byKey(_k('match-share')), findsNothing);
  });

  testWidgets('bourse retirée depuis le run : « Plus disponible »', (t) async {
    resetMatchWorld();
    await _open(
      t,
      FakeMatchApi(
        state: matchStateJson(
          latestRun: matchRunJson(items: [
            matchItemJson(id: 'gone', name: 'Bourse fermée', available: false),
          ]),
        ),
      ),
    );
    expect(find.text('Plus disponible'), findsOneWidget);
    expect(find.byKey(_k('match-case-gone')), findsNothing);
  });

  testWidgets('hors ligne : run daté ; « Clôturée » seulement si confirmée',
      (t) async {
    resetMatchWorld();
    final run = MatchRun.fromJson(matchRunJson(items: [
      matchItemJson(id: 'confirmed', name: 'Confirmée'),
      matchItemJson(
        id: 'estimated',
        rank: 2,
        name: 'Estimée',
        window: {
          'status': 'open',
          'dateConfidence': 'estimated',
          'closesAt': '2026-11-15T23:59:59.000Z',
        },
      ),
    ]))!;
    ScholarshipMatchStore.instance.debugSeed(
      userId: 'test-user-1',
      run: run,
      syncedAt: DateTime(2026, 10, 12, 10),
      fromCache: true,
      failure: ScholarshipMatchFailure.offline,
    );
    final api = FakeMatchApi()
      ..stateError =
          const ScholarshipMatchException(ScholarshipMatchFailure.offline);
    await _open(t, api, now: DateTime.utc(2026, 12, 1));
    expect(find.text('Hors ligne — résultats du 12/10'), findsOneWidget);
    expect(find.text('Clôturée'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_k('match-item-confirmed')),
        matching: find.text('Clôturée'),
      ),
      findsOneWidget,
    );
    // Actions réseau désactivées, et elles le disent.
    expect(find.text('Connexion nécessaire'), findsWidgets);
  });

  testWidgets(
      'run périmé : relancé UNE fois à l\'ouverture, toast des '
      'différences, puce « Nouveau »', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(
      state: matchStateJson(latestRun: matchRunJson(), isStale: true),
    )..runResponse = {
        'status': 'ok',
        'run': matchRunJson(
          id: 'run-2',
          items: [
            matchItemJson(id: 'eiffel', name: 'Bourse Eiffel'),
            matchItemJson(
                id: 'chevening', rank: 2, name: 'Chevening', isNew: true),
            matchItemJson(id: 'daad', rank: 3, name: 'DAAD', isNew: true),
          ],
        ),
        'diff': {
          'addedIds': ['chevening', 'daad'],
          'removedIds': ['turkiye'],
        },
      };
    await _open(t, api);
    expect(api.runCalls, hasLength(1));
    expect(api.runCalls.single['trigger'], 'stale_refresh');
    expect(api.runCalls.single['answers'], isNull);
    expect(find.text('2 nouvelles · 1 retirée'), findsOneWidget);
    expect(find.byKey(_k('match-new-chevening')), findsOneWidget);
    // Un nouveau rendu ne relance rien.
    await t.pump();
    expect(api.runCalls, hasLength(1));
  });

  testWidgets(
      '« Suivre les N » : déjà suivie reste suivie ; « Annuler » ne '
      'retire que les nouvelles', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await _open(t, api);
    final controller = Get.find<AppController>();
    await controller.ensureSaved(SavedItemType.scholarship, 'eiffel');
    expect(controller.isSaved(SavedItemType.scholarship, 'eiffel'), isTrue);

    await _scrollTo(t, _k('match-follow-all'));
    expect(find.text('Suivre les 2 compatibles'), findsOneWidget);
    await t.tap(find.byKey(_k('match-follow-all')));
    await t.pumpAndSettle();

    expect(controller.isSaved(SavedItemType.scholarship, 'eiffel'), isTrue);
    expect(controller.isSaved(SavedItemType.scholarship, 'turkiye'), isTrue);
    // L'élément « à vérifier » n'est pas suivi d'office.
    expect(controller.isSaved(SavedItemType.scholarship, 'mcf'), isFalse);

    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(controller.isSaved(SavedItemType.scholarship, 'turkiye'), isFalse);
    expect(controller.isSaved(SavedItemType.scholarship, 'eiffel'), isTrue);
  });

  testWidgets('« Être accompagné » : compositeur prérempli avec scholarshipId',
      (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await _open(t, api);
    await _scrollTo(t, _k('match-case-eiffel'));
    await t.tap(find.byKey(_k('match-case-eiffel')));
    await t.pumpAndSettle();
    final sheet = t.widget<CaseComposerSheet>(find.byType(CaseComposerSheet));
    expect(sheet.scholarshipId, 'eiffel');
    expect(sheet.caseType, CaseType.scholarshipSupport);
    expect(sheet.title, 'Candidature — Bourse Eiffel');
  });

  testWidgets('interrupteur d\'alertes : opt-in explicite (PUT alerts)',
      (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await _open(t, api);
    await _scrollTo(t, _k('match-alerts'));
    expect(t.widget<SwitchListTile>(find.byKey(_k('match-alerts'))).value,
        isFalse);
    await t.tap(find.byKey(_k('match-alerts')));
    await t.pumpAndSettle();
    expect(api.alertCalls, [true]);
    expect(
        t.widget<SwitchListTile>(find.byKey(_k('match-alerts'))).value, isTrue);
  });

  testWidgets('drapeau fermé : le lien profond retombe sur l\'onglet Bourses',
      (t) async {
    resetMatchWorld(flag: false);
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchResultsScreen(source: 'test'),
      api: api,
    );
    expect(find.byKey(_k('match-results-list')), findsNothing);
    expect(api.stateCalls, 0);
  });

  // Correctifs 57 — « Effacer ma nationalité » : confirmation, effacement
  // serveur et local, l'écran retombe sur « faire le test ».
  testWidgets('« Effacer ma nationalité » : annuler ne fait rien', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await _open(t, api);
    await _scrollTo(t, _k('match-erase-nationality'));
    await t.tap(find.byKey(_k('match-erase-nationality')));
    await t.pumpAndSettle();
    expect(find.text('Effacer ta nationalité ?'), findsOneWidget);
    await t.tap(find.byKey(_k('match-erase-nationality-cancel')));
    await t.pumpAndSettle();
    expect(api.eraseCalls, 0);
    expect(ScholarshipMatchStore.instance.latestRun, isNotNull);
  });

  testWidgets('« Effacer ma nationalité » : confirmer efface tout', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await _open(t, api);
    await _scrollTo(t, _k('match-erase-nationality'));
    await t.tap(find.byKey(_k('match-erase-nationality')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(_k('match-erase-nationality-confirm')));
    await t.pumpAndSettle();
    expect(api.eraseCalls, 1);
    expect(ScholarshipMatchStore.instance.latestRun, isNull);
    expect(find.text('Ta nationalité et tes résultats ont été effacés.'),
        findsOneWidget);
    // Les résultats calculés avec la nationalité ne s'affichent plus.
    expect(find.byKey(_k('match-erase-nationality')), findsNothing);
    await t.pump(const Duration(seconds: 6));
  });
}
