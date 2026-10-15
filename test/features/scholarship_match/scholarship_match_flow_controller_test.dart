// La logique de l'assistant, sans widget : seulement les clés manquantes et
// connues, l'étape tuteur d'un mineur, l'expérience seulement pour un Master
// ou un Doctorat, le récapitulatif (résidence comprise), la requête unique, et
// la reprise du brouillon au même écran.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_flow_controller.dart';

import 'match_test_support.dart';

ScholarshipMatchState _state(Map<String, dynamic> json) =>
    ScholarshipMatchState.fromJson(json);

void main() {
  final now = DateTime(2026, 10, 15);

  test(
      'seulement les clés manquantes CONNUES, dans l\'ordre ; la résidence '
      'pré-remplie va au récapitulatif', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    );
    expect(flow.steps, [
      'nationalityCode',
      'birthDate',
      'highestDiploma',
      'scholarshipTargetLevel',
      'fields',
      'gradeBandOn20',
      'englishLevel',
    ]);
    expect(flow.screens.first, MatchFlowScreen.intro);
    expect(flow.screens.last, MatchFlowScreen.recap);
    expect(flow.values['residence'], 'ner');
    expect(flow.steps.length, lessThanOrEqualTo(8));
  });

  test(
      'suggestion non ambiguë → pas de question, valeur au récapitulatif ; '
      'ambiguë → la question est posée', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson(
        required: ['englishLevel', 'gradeBandOn20'],
        prefill: [
          {'key': 'englishLevel', 'value': 'b1', 'ambiguous': false},
          {'key': 'gradeBandOn20', 'value': '14_16', 'ambiguous': true},
        ],
        latestRun: matchRunJson(),
      )),
      now: () => now,
    );
    expect(flow.steps, ['gradeBandOn20']);
    expect(flow.values['englishLevel'], 'b1');
    // Pré-coché, mais la question est posée.
    expect(flow.values['gradeBandOn20'], '14_16');
    expect(flow.showIntro, isFalse);
  });

  test(
      'mineur sans accord (compte « Passer ») : l\'étape tuteur apparaît '
      'après la date de naissance', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    );
    expect(flow.steps, isNot(contains('guardianConsent')));
    flow.set(MatchDraftKey.birthDate, '2009-05-10'); // 17 ans
    expect(flow.needsGuardian, isTrue);
    expect(flow.steps.indexOf('guardianConsent'),
        flow.steps.indexOf('birthDate') + 1);
    expect(flow.isAnswered('guardianConsent'), isFalse);
    flow
      ..set(MatchDraftKey.guardianName, 'Awa')
      ..set(MatchDraftKey.guardianContact, '+227 90 00 00 00')
      ..set(MatchDraftKey.guardianConsent, true);
    expect(flow.isAnswered('guardianConsent'), isTrue);
    expect(flow.buildAnswers()['guardianConsent'], isTrue);
    expect(flow.buildAnswers()['guardianName'], 'Awa');
  });

  test('majeur : jamais d\'étape tuteur', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    );
    flow.set(MatchDraftKey.birthDate, '2000-01-01');
    expect(flow.steps, isNot(contains('guardianConsent')));
    expect(flow.buildAnswers(), isNot(contains('guardianConsent')));
  });

  test('expérience SEULEMENT pour une cible Master ou Doctorat', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    );
    flow.set(MatchDraftKey.scholarshipTargetLevel, 'bachelor');
    expect(flow.steps, isNot(contains('workExperienceBand')));
    flow.set(MatchDraftKey.scholarshipTargetLevel, 'master');
    expect(flow.steps.last, 'workExperienceBand');
    flow.set(MatchDraftKey.workExperienceBand, '24_36');
    expect(flow.buildAnswers()['workExperienceBand'], '24_36');
    flow.set(MatchDraftKey.scholarshipTargetLevel, 'bachelor');
    expect(flow.buildAnswers(), isNot(contains('workExperienceBand')));
  });

  test('le lycée n\'est proposé que si le serveur le sert ET jusqu\'à 19 ans',
      () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson(
        targetLevelOptions: ['secondary', 'bachelor', 'master'],
      )),
      now: () => now,
    );
    flow.set(MatchDraftKey.birthDate, '2009-01-01');
    expect(flow.targetLevelOptions, contains('secondary'));
    flow.set(MatchDraftKey.birthDate, '2000-01-01');
    expect(flow.targetLevelOptions, isNot(contains('secondary')));
  });

  test('récapitulatif : la résidence manquante bloque l\'envoi', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson(prefill: const [], answers: {})),
      mode: MatchFlowMode.recap,
      now: () => now,
    );
    expect(flow.onRecap, isTrue);
    expect(flow.recapMissing, contains('residence'));
    expect(flow.canContinue, isFalse);
  });

  test('« Pas encore décidé » est une réponse (liste vide envoyée)', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    );
    expect(flow.isAnswered('fields'), isFalse);
    flow
      ..set(MatchDraftKey.fieldIds, const <String>[])
      ..set(MatchDraftKey.fieldsDecided, true);
    expect(flow.isAnswered('fields'), isTrue);
    expect(flow.buildAnswers()['fieldIds'], isEmpty);
  });

  test('la requête ne porte que des clés comprises par le serveur', () {
    const serverKeys = <String>{
      'nationalityCode',
      'secondNationalityCode',
      'residence',
      'birthDate',
      'guardianName',
      'guardianContact',
      'guardianConsent',
      'highestDiploma',
      'scholarshipTargetLevel',
      'fieldIds',
      'targetCountryIds',
      'gradeBandOn20',
      'englishLevel',
      'frenchLevel',
      'languageTests',
      'workExperienceBand',
    };
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    )
      ..set(MatchDraftKey.nationalityCode, 'ner')
      ..set(MatchDraftKey.birthDate, '2001-03-03')
      ..set(MatchDraftKey.highestDiploma, 'licence')
      ..set(MatchDraftKey.scholarshipTargetLevel, 'master')
      ..set(MatchDraftKey.fieldIds, ['d01'])
      ..set(MatchDraftKey.fieldsDecided, true)
      ..set(MatchDraftKey.gradeBandOn20, '12_14')
      ..set(MatchDraftKey.englishLevel, 'b1')
      ..set(MatchDraftKey.workExperienceBand, 'none')
      ..putLanguageTest(const MatchLanguageTest(type: 'ielts', score: 6.5));
    final answers = flow.buildAnswers();
    expect(serverKeys.containsAll(answers.keys), isTrue,
        reason: '${answers.keys.toSet().difference(serverKeys)}');
    expect(answers['residence'], 'ner');
    expect(flow.recapMissing, isEmpty);
    expect(answers['languageTests'], [
      {'type': 'ielts', 'score': 6.5},
    ]);
  });

  test('le brouillon reprend AU MÊME ÉCRAN après un redémarrage', () {
    final state = _state(matchStateJson());
    final first = ScholarshipMatchFlowController(state: state, now: () => now)
      ..next() // accueil → nationalité
      ..set(MatchDraftKey.nationalityCode, 'tcd')
      ..next(); // → date de naissance
    expect(first.current, 'birthDate');
    final persisted = jsonDecode(jsonEncode(first.toDraft().toJson()))
        as Map<String, dynamic>;

    final resumed = ScholarshipMatchFlowController(
      state: state,
      draft: ScholarshipMatchDraft.fromJson(persisted),
      now: () => now,
    );
    expect(resumed.resumed, isTrue);
    expect(resumed.current, 'birthDate');
    expect(resumed.values['nationalityCode'], 'tcd');
  });

  test('le contact du représentant légal n\'est jamais écrit sur l\'appareil',
      () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    )
      ..set(MatchDraftKey.birthDate, '2009-05-10')
      ..set(MatchDraftKey.guardianName, 'Awa')
      ..set(MatchDraftKey.guardianContact, '+227 90 00 00 00');
    final persisted = jsonEncode(flow.toDraft().toJson());
    expect(persisted, isNot(contains('Awa')));
    expect(persisted, isNot(contains('+227')));
    expect(persisted, contains('2009-05-10'));
  });

  test('un brouillon d\'une autre version est ignoré', () {
    expect(
        ScholarshipMatchDraft.fromJson({'v': 99, 'screen': 'recap'}), isNull);
  });

  test('conversion des notes hors /20', () {
    expect(matchGradeBandFromScale(3.2, 4), '16_plus');
    expect(matchGradeBandFromScale(6.5, 10), '12_14');
    expect(matchGradeBandFromScale(45, 100), 'lt10');
    expect(matchGradeBandFromScale(12, 10), isNull);
  });

  test('progression « i/N » : les questions seulement', () {
    final flow = ScholarshipMatchFlowController(
      state: _state(matchStateJson()),
      now: () => now,
    );
    expect(flow.progress, isNull); // accueil
    flow.next();
    expect(flow.progress, (1, 7));
  });
}
