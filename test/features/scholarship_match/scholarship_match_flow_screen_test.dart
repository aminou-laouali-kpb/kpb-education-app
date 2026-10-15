// L'assistant à l'écran : seulement les questions manquantes et connues,
// l'étape tuteur d'un mineur, le récapitulatif avec la résidence, UNE requête,
// et un échec qui garde le brouillon et propose « Réessayer ».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/core/services/scholarship_match_store.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_flow_controller.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_flow_screen.dart';

import 'match_test_support.dart';

/// Un profil complet, jamais confirmé (premier passage au récapitulatif).
Map<String, dynamic> _fullAnswers({String birthDate = '2000-01-01'}) =>
    <String, dynamic>{
      'nationalityCode': 'ner',
      'residence': 'ner',
      'birthDate': birthDate,
      'guardianConsented': false,
      'highestDiploma': 'licence',
      'scholarshipTargetLevel': 'master',
      'fieldIds': ['d01'],
      'targetCountryIds': <String>[],
      'gradeBandOn20': '12_14',
      'englishLevel': 'b1',
      'languageTests': <dynamic>[],
      'workExperienceBand': 'none',
      'confirmedAt': null,
    };

Key _k(String value) => ValueKey<String>(value);

void main() {
  tearDown(tearDownMatchWorld);

  testWidgets('seules les clés manquantes connues deviennent une question',
      (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(
      state: matchStateJson(
        required: ['englishLevel', 'futureUnknownKey'],
        answers: {..._fullAnswers(), 'englishLevel': null},
        latestRun: matchRunJson(),
      ),
    );
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchFlowScreen(source: 'test'),
      api: api,
    );

    // Pas d'accueil (un run existe), directement la seule question.
    expect(find.byKey(_k('match-step-englishLevel')), findsOneWidget);
    expect(find.byKey(_k('match-progress')), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Ton niveau d\'anglais'), findsOneWidget);

    await t.tap(find.byKey(_k('match-lang-b2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(_k('match-continue')));
    await t.pumpAndSettle();

    // Clé inconnue ignorée : on arrive au récapitulatif.
    expect(find.text('Vérifie tes infos'), findsOneWidget);
  });

  testWidgets('mineur sans accord : l\'étape du représentant légal', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(
      state: matchStateJson(
        required: ['guardianConsent'],
        answers: _fullAnswers(birthDate: '2009-05-10'),
        latestRun: matchRunJson(),
      ),
    );
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchFlowScreen(source: 'test'),
      api: api,
    );
    expect(find.byKey(_k('match-guardian-name')), findsOneWidget);
    expect(find.byKey(_k('match-guardian-consent')), findsOneWidget);
    final continueButton =
        t.widget<FilledButton>(find.byKey(_k('match-continue')));
    expect(continueButton.onPressed, isNull);

    await t.enterText(find.byKey(_k('match-guardian-name')), 'Awa');
    await t.enterText(
        find.byKey(_k('match-guardian-contact')), '+227 90 00 00 00');
    await t.tap(find.byKey(_k('match-guardian-consent')));
    await t.pumpAndSettle();
    expect(
      t.widget<FilledButton>(find.byKey(_k('match-continue'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('récapitulatif « Vérifie tes infos » : la résidence y est',
      (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(
      state: matchStateJson(required: [], answers: _fullAnswers()),
    );
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchFlowScreen(
        mode: MatchFlowMode.recap,
        source: 'test',
      ),
      api: api,
    );
    expect(find.text('Vérifie tes infos'), findsOneWidget);
    expect(find.byKey(_k('match-recap-residence')), findsOneWidget);
    expect(find.text('Pays de résidence'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_k('match-recap-residence')),
        matching: find.text('Niger'),
      ),
      findsOneWidget,
    );
    // Expérience : cible Master.
    await t.scrollUntilVisible(
      find.byKey(_k('match-recap-experience')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(_k('match-recap-experience')), findsOneWidget);
  });

  testWidgets(
      'échec du calcul : brouillon gardé, « Réessayer », puis UNE '
      'requête qui aboutit', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(
      state: matchStateJson(required: [], answers: _fullAnswers()),
    )..runError =
        const ScholarshipMatchException(ScholarshipMatchFailure.timeout);
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchFlowScreen(
        mode: MatchFlowMode.recap,
        source: 'test',
      ),
      api: api,
    );

    await t.tap(find.byKey(_k('match-submit')));
    await t.pumpAndSettle();

    expect(api.runCalls, hasLength(1));
    expect(api.runCalls.single['confirm'], isTrue);
    expect(find.byKey(_k('match-submit-error')), findsOneWidget);
    expect(find.byKey(_k('match-submit-retry')), findsOneWidget);
    expect(
      await ScholarshipMatchStore.instance.readDraft('test-user-1'),
      isNotNull,
    );
    // Les réponses ne passent JAMAIS par le PATCH du profil.
    expect(api.runCalls.single['answers'], containsPair('residence', 'ner'));

    api.runError = null;
    await t.tap(find.byKey(_k('match-submit-retry')));
    await t.pumpAndSettle();
    expect(api.runCalls, hasLength(2));
    expect(
      await ScholarshipMatchStore.instance.readDraft('test-user-1'),
      isNull,
    );
    // Résultats affichés.
    expect(find.byKey(_k('match-results-counts')), findsOneWidget);
  });

  testWidgets('le brouillon reprend au même écran après un redémarrage',
      (t) async {
    final cache = resetMatchWorld();
    final api = FakeMatchApi();
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchFlowScreen(source: 'test'),
      api: api,
    );
    // Accueil → nationalité.
    expect(find.textContaining('(7 questions)'), findsOneWidget);
    await t.tap(find.byKey(_k('match-continue')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(_k('match-country-tcd')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(_k('match-continue')));
    await t.pumpAndSettle();
    expect(find.byKey(_k('match-step-birthDate')), findsOneWidget);

    // « Redémarrage » : l'écran disparaît, la mémoire du magasin aussi ; le
    // cache (Hive en production) reste.
    await t.pumpWidget(const SizedBox.shrink());
    ScholarshipMatchStore.instance.debugReset(cache: cache);
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchFlowScreen(source: 'test'),
      api: api,
    );
    expect(find.byKey(_k('match-step-birthDate')), findsOneWidget);
    await t.tap(find.byKey(_k('match-back')));
    await t.pumpAndSettle();
    final tchad = t.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(_k('match-country-tcd')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(tchad.properties.selected, isTrue);
  });

  testWidgets('pays : la liste SERVIE, avec la recherche', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(
      state: matchStateJson(
        required: ['nationalityCode'],
        answers: {..._fullAnswers(), 'nationalityCode': null},
        latestRun: matchRunJson(),
      ),
    );
    await pumpMatchApp(
      t,
      child: const ScholarshipMatchFlowScreen(source: 'test'),
      api: api,
    );
    expect(find.byKey(_k('match-country-tcd')), findsOneWidget);
    await t.enterText(find.byKey(_k('match-nationality-search')), 'sene');
    await t.pumpAndSettle();
    expect(find.byKey(_k('match-country-sen')), findsOneWidget);
    expect(find.byKey(_k('match-country-tcd')), findsNothing);
  });
}
