// Les formes servies par `/scholarships/match/*`, lues avec tolérance : une
// clé inconnue est ignorée, une valeur inconnue retombe sur le repli qui
// promet le MOINS (jamais « compatible » sur un jeton incompris).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/scholarship_match.dart';

import 'match_test_support.dart';

void main() {
  group('état servi', () {
    test('lit le contrat et ignore les clés de préparation inconnues', () {
      final state = ScholarshipMatchState.fromJson(<String, dynamic>{
        ...matchStateJson(),
        'champFutur': {'x': 1},
      });
      expect(state.readiness.required, isNot(contains('futureUnknownKey')));
      expect(state.readiness.required, contains('nationalityCode'));
      expect(state.catalogSize, 29);
      expect(state.options.countries.first.code, 'ner');
      expect(state.options.countryName('tcd'), 'Tchad');
      expect(state.options.fields.map((f) => f.id), ['d01', 'd02']);
      expect(state.latestRun, isNull);
    });

    test('une charge illisible donne un état vide, jamais une exception', () {
      for (final raw in <Object?>[null, 'texte', 42, <dynamic>[]]) {
        final state = ScholarshipMatchState.fromJson(raw);
        expect(state.readiness.ready, isFalse);
        expect(state.options.countries, isEmpty);
        expect(state.latestRun, isNull);
      }
    });

    test('jetons inconnus des réponses → null (la question sera posée)', () {
      final answers = MatchAnswers.fromJson(<String, dynamic>{
        'nationalityCode': 'NER',
        'residence': 'Niger', // pas un alpha-3
        'birthDate': '2006-05-10',
        'highestDiploma': 'bac_plus_7',
        'scholarshipTargetLevel': 'postdoc',
        'gradeBandOn20': '12_14',
        'englishLevel': 'native',
        'languageTests': [
          {'type': 'ielts', 'score': 6.5},
          {'type': 'ielts', 'score': 12}, // hors échelle
          {'type': 'cambridge', 'score': 180},
        ],
      });
      expect(answers.nationalityCode, 'ner');
      expect(answers.residence, isNull);
      expect(answers.birthDate, '2006-05-10');
      expect(answers.highestDiploma, isNull);
      expect(answers.scholarshipTargetLevel, isNull);
      expect(answers.gradeBandOn20, '12_14');
      expect(answers.englishLevel, isNull);
      expect(answers.languageTests.single.score, 6.5);
    });

    test('niveaux visés : seulement ceux que cette build sait poser', () {
      final readiness = MatchReadiness.fromJson(<String, dynamic>{
        'targetLevelOptions': ['secondary', 'bachelor', 'postdoc'],
      });
      expect(readiness.targetLevelOptions, ['secondary', 'bachelor']);
    });

    test('une suggestion sans « ambiguous » est traitée comme ambiguë', () {
      final p = MatchPrefill.fromJson(<String, dynamic>{
        'key': 'gradeBandOn20',
        'value': '14_16',
      });
      expect(p!.ambiguous, isTrue);
      expect(
        MatchPrefill.fromJson(
            <String, dynamic>{'key': 'inconnue', 'value': 'x'}),
        isNull,
      );
    });
  });

  group('run', () {
    test('statut inconnu → « à vérifier », jamais « compatible »', () {
      final item = MatchItem.fromJson(matchItemJson(
        id: 'x',
        section: 'compatible',
        status: 'probably_ok',
      ))!;
      expect(item.status, MatchItemStatus.toVerify);
      expect(item.section, MatchSection.toVerify);
    });

    test('une bourse not_eligible ou sans identifiant n\'est jamais rendue',
        () {
      expect(
        MatchItem.fromJson(matchItemJson(id: 'x', status: 'not_eligible')),
        isNull,
      );
      expect(
        MatchItem.fromJson(<String, dynamic>{'name': 'Sans id'}),
        isNull,
      );
    });

    test('au plus 10 éléments, compatibles d\'abord, au plus 3 raisons', () {
      final items = <Map<String, dynamic>>[
        for (var i = 0; i < 6; i++)
          matchItemJson(
            id: 'v$i',
            rank: i + 1,
            section: 'to_verify',
            status: 'to_verify',
          ),
        for (var i = 0; i < 6; i++)
          matchItemJson(
            id: 'c$i',
            rank: i + 1,
            reasons: [
              for (var r = 0; r < 5; r++) {'code': 'r$r', 'label': 'Raison $r'},
            ],
          ),
      ];
      final run = MatchRun.fromJson(matchRunJson(items: items))!;
      expect(run.items, hasLength(10));
      expect(run.items.first.isCompatible, isTrue);
      expect(run.items.first.reasons, hasLength(3));
    });

    test('confiance de date inconnue → estimée ; source non https ignorée', () {
      final item = MatchItem.fromJson(matchItemJson(
        id: 'x',
        window: {
          'status': 'open',
          'dateConfidence': 'probable',
          'closesAt': '2026-11-15T23:59:59.000Z',
        },
        toVerify: [
          {
            'code': 'age_missing',
            'label': 'Âge à vérifier',
            'official': {'text': 'Under 30', 'sourceUrl': 'http://exemple.org'},
          },
        ],
      ))!;
      expect(item.window!.dateConfirmed, isFalse);
      expect(item.window!.status, MatchWindowStatus.open);
      expect(item.toVerify.single.official!.sourceUrl, isNull);
    });

    test('statut de fenêtre inconnu → unknown (aucune pastille inventée)', () {
      final window = MatchWindow.fromJson({'status': 'paused'})!;
      expect(window.status, MatchWindowStatus.unknown);
    });

    test('« Clôturée » seulement pour une date limite CONFIRMÉE passée', () {
      final now = DateTime.utc(2026, 12, 1);
      final confirmed = MatchWindow.fromJson({
        'status': 'open',
        'dateConfidence': 'confirmed',
        'closesAt': '2026-11-15T23:59:59.000Z',
      })!;
      final estimated = MatchWindow.fromJson({
        'status': 'open',
        'dateConfidence': 'estimated',
        'closesAt': '2026-11-15T23:59:59.000Z',
      })!;
      expect(confirmed.isConfirmedClosed(now), isTrue);
      expect(estimated.isConfirmedClosed(now), isFalse);
    });

    test('précision et résumé : valeurs inconnues → repli', () {
      final run = MatchRun.fromJson(<String, dynamic>{
        ...matchRunJson(),
        'precisionLimitedBy': 'nobody',
        'excludedSummary': {
          'groups': [
            {
              'group': 'mystery',
              'count': 2,
              'label': '2 pour une autre raison'
            },
            {'group': 'level', 'count': 0, 'label': 'zéro'},
            {'group': 'age', 'count': 3},
          ],
        },
      })!;
      expect(run.precisionLimitedBy, isNull);
      expect(run.excludedSummary.groups.single.group, 'mystery');
      expect(run.excludedSummary.notAnalyzedLabel, isNull);
    });

    test('aller-retour JSON (cache) sans perte', () {
      final run = MatchRun.fromJson(matchRunJson(
        levelCatalog: {
          'level': 'doctorate',
          'count': 1,
          'label': '1 bourse doctorale dans notre catalogue pour l’instant',
        },
        precisionLimitedBy: 'answers',
      ))!;
      final again = MatchRun.fromJson(jsonDecode(jsonEncode(run.toJson())))!;
      expect(again.id, run.id);
      expect(again.items.map((i) => i.scholarshipId),
          run.items.map((i) => i.scholarshipId));
      expect(again.items.last.toVerify.single.official!.text, contains('70 %'));
      expect(again.levelCatalog!.label, run.levelCatalog!.label);
      expect(again.precisionLimitedBy, MatchPrecisionLimit.answers);
      expect(again.items.first.window!.dateConfirmed, isTrue);
      expect(again.excludedSummary.groups.single.count, 12);
    });

    test('réponse de run : statut inconnu → null (un échec, pas un run vide)',
        () {
      expect(MatchRunResponse.fromJson({'status': 'queued'}), isNull);
      expect(MatchRunResponse.fromJson({'status': 'ok'}), isNull);
      expect(
        MatchRunResponse.fromJson({
          'status': 'profile_incomplete',
          'readiness': {
            'required': ['birthDate', 'unknown'],
          },
        }),
        isA<MatchRunIncomplete>().having(
          (r) => r.readiness.required,
          'required',
          ['birthDate'],
        ),
      );
      final ok = MatchRunResponse.fromJson({
        'status': 'ok',
        'run': matchRunJson(),
        'diff': {
          'addedIds': ['a', 'b'],
          'removedIds': ['c'],
        },
      });
      expect(ok, isA<MatchRunOk>());
      expect((ok as MatchRunOk).diff.addedIds, ['a', 'b']);
    });
  });
}
