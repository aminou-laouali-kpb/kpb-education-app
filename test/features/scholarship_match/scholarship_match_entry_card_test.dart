// La carte d'entrée de l'onglet Bourses : derrière `features.scholarshipMatch`,
// cachée pour les parents, et ses quatre variantes (pas de run, run, périmé,
// invité). Cachée, le guide reprend sa place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_entry_card.dart';

import 'match_test_support.dart';

const _guide = Text('GUIDE', key: ValueKey<String>('guide-fallback'));

Widget _host() => const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ScholarshipMatchEntryCard(fallback: _guide),
      ),
    );

void main() {
  tearDown(tearDownMatchWorld);

  testWidgets('drapeau fermé (clé absente) : le guide, aucun appel', (t) async {
    resetMatchWorld(flag: false);
    final api = FakeMatchApi();
    await pumpMatchApp(t, child: _host(), api: api);
    expect(
        find.byKey(const ValueKey<String>('guide-fallback')), findsOneWidget);
    expect(find.textContaining('Faire le test'), findsNothing);
    expect(api.stateCalls, 0);
  });

  testWidgets('compte parent : jamais le test', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi();
    await pumpMatchApp(t, child: _host(), api: api, snapshot: parentSnapshot());
    expect(
        find.byKey(const ValueKey<String>('guide-fallback')), findsOneWidget);
    expect(api.stateCalls, 0);
  });

  testWidgets('invité : la carte invite à créer un compte', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi();
    await pumpMatchApp(t, child: _host(), api: api, snapshot: guestSnapshot());
    expect(find.byKey(const ValueKey<String>('scholarship-match-entry-guest')),
        findsOneWidget);
    expect(
        find.text('Avec un compte, fais le test : jusqu\'à 10 bourses pour '
            'ton profil.'),
        findsOneWidget);
    expect(api.stateCalls, 0);
  });

  testWidgets('élève sans run : « Faire le test »', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi();
    await pumpMatchApp(t, child: _host(), api: api);
    expect(find.byKey(const ValueKey<String>('scholarship-match-entry-noRun')),
        findsOneWidget);
    expect(find.text('Faire le test'), findsOneWidget);
    expect(find.text('2 min · jusqu\'à 10 bourses · on t\'explique pourquoi'),
        findsOneWidget);
    expect(api.stateCalls, 1);
    expect(find.byKey(const ValueKey<String>('guide-fallback')), findsNothing);
  });

  testWidgets('élève avec un run : résumé honnête et « Voir »', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await pumpMatchApp(t, child: _host(), api: api);
    expect(find.byKey(const ValueKey<String>('scholarship-match-entry-hasRun')),
        findsOneWidget);
    expect(find.text('Tes bourses : 2 compatibles · 1 à vérifier'),
        findsOneWidget);
    expect(find.text('Mis à jour le 13/10'), findsOneWidget);
    expect(find.text('Voir'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsNothing);
  });

  testWidgets('run périmé : « Mettre à jour » en plus', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi(
      state: matchStateJson(latestRun: matchRunJson(), isStale: true),
    );
    await pumpMatchApp(t, child: _host(), api: api);
    expect(find.byKey(const ValueKey<String>('scholarship-match-entry-stale')),
        findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget);
  });

  testWidgets('serveur coupé (404 disabled) : la carte se masque', (t) async {
    resetMatchWorld();
    final api = FakeMatchApi()
      ..stateError = const ScholarshipMatchException(
        ScholarshipMatchFailure.disabled,
      );
    await pumpMatchApp(t, child: _host(), api: api);
    expect(
        find.byKey(const ValueKey<String>('guide-fallback')), findsOneWidget);
  });
}
