// Le compositeur : type, titre, corps ; « @ » propose des entités du
// catalogue et insère une PUCE envoyée comme jeton structuré ; « # » des
// hashtags ; prévisualisation ; mise en attente de revue dite sans accuser ;
// erreurs du serveur traduites.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/services/community_store.dart';
import 'package:karatou/app/features/community/hub/community_composer_screen.dart';

import 'community_test_support.dart';

Future<void> _openComposer(
  WidgetTester tester,
  FakeCommunityApi api, {
  List<CommunityMention> prefill = const <CommunityMention>[],
}) async {
  await pumpCommunityApp(
    tester,
    api: api,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => openCommunityComposer(context,
                source: 'test', prefill: prefill),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetCommunityWorld);
  tearDown(tearDownCommunityWorld);

  testWidgets('@eif → suggestion → puce → jeton @[…](scholarship:id) envoyé',
      (tester) async {
    final api = FakeCommunityApi();
    await _openComposer(tester, api);
    expect(find.text('Nouvelle publication'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('comm-composer-title')),
        'Qui a eu la bourse en 2026 ?');
    final body = find.byKey(const ValueKey('comm-composer-body'));
    await tester.enterText(body, 'Bonjour, qui a eu @eif');
    // Pause de frappe, puis la requête d'autocomplétion.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.mentionQueries, contains('eif'));

    final suggestion =
        find.byKey(const ValueKey('comm-suggest-scholarship-eiffel'));
    expect(suggestion, findsOneWidget);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();

    // La puce est dans le texte affiché, sans jeton visible.
    final field = tester.widget<TextField>(body);
    expect(field.controller!.text, 'Bonjour, qui a eu @Bourse Eiffel ');
    expect(find.text('Citées dans ton message :'), findsOneWidget);

    await tester.enterText(
        body, '${field.controller!.text}en 2026 ? Merci #CampusFrance');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('comm-composer-send')));
    await tester.pumpAndSettle();

    expect(api.createdPosts, hasLength(1));
    expect(api.createdPosts.single['type'], 'question');
    expect(
      api.createdPosts.single['body'],
      'Bonjour, qui a eu @[Bourse Eiffel](scholarship:eiffel) en 2026 ? '
      'Merci #CampusFrance',
    );
    // Le bandeau de confirmation se referme.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('modifier l’intérieur d’une puce la retire entière',
      (tester) async {
    final api = FakeCommunityApi();
    await _openComposer(tester, api, prefill: const <CommunityMention>[
      CommunityMention(
          type: CommunityEntityType.country, id: 'can', label: 'Canada'),
    ]);
    final body = find.byKey(const ValueKey('comm-composer-body'));
    final controller = tester.widget<TextField>(body).controller!;
    expect(controller.text, '@Canada ');
    // L'élève efface une lettre de la puce : elle redevient du texte.
    controller.text = '@Canda ';
    await tester.pumpAndSettle();
    expect(find.text('Citées dans ton message :'), findsNothing);
  });

  testWidgets('prévisualisation : la puce s’affiche comme une carte de mention',
      (tester) async {
    final api = FakeCommunityApi();
    await _openComposer(tester, api, prefill: const <CommunityMention>[
      CommunityMention(
          type: CommunityEntityType.scholarship,
          id: 'eiffel',
          label: 'Bourse Eiffel'),
    ]);
    await tester.enterText(find.byKey(const ValueKey('comm-composer-title')),
        'Une question sur Eiffel');
    await tester.tap(find.byKey(const ValueKey('comm-composer-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comm-composer-preview-view')),
        findsOneWidget);
    expect(find.text('Une question sur Eiffel'), findsOneWidget);
    expect(find.text('Bourse Eiffel'), findsWidgets);
  });

  testWidgets('publication masquée par le filtre : message doux, sans accuser',
      (tester) async {
    final api = FakeCommunityApi()
      ..createModeration = <String, dynamic>{
        'status': 'pending_review',
        'reason': 'auto_filter',
        'since': DateTime.now().toUtc().toIso8601String(),
      };
    await _openComposer(tester, api);
    await tester.enterText(find.byKey(const ValueKey('comm-composer-title')),
        'Contact pour la bourse');
    await tester.enterText(find.byKey(const ValueKey('comm-composer-body')),
        'Écris-moi sur WhatsApp au 90 00 00 00 pour les infos.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comm-composer-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('comm-pending-sheet')), findsOneWidget);
    expect(find.text('Ta publication est en cours de vérification'),
        findsOneWidget);
    expect(find.textContaining('ton message n\'est pas perdu'), findsOneWidget);
  });

  testWidgets('quota dépassé : erreur du serveur traduite, rien de perdu',
      (tester) async {
    final api = FakeCommunityApi()
      ..createError = const CommunityException(
        CommunityFailure.rateLimited,
        statusCode: 429,
        code: 'community_rate_limited',
        details: <String, dynamic>{
          'scope': 'posts_per_day',
          'limit': 3,
          'retryAfterSeconds': 3600,
        },
      );
    await _openComposer(tester, api);
    await tester.enterText(find.byKey(const ValueKey('comm-composer-title')),
        'Encore une question ?');
    await tester.enterText(find.byKey(const ValueKey('comm-composer-body')),
        'Je voudrais savoir comment préparer mon dossier.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comm-composer-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('comm-composer-error')), findsOneWidget);
    expect(
        find.text('Tu as atteint la limite de 3 publications par jour. '
            'Réessaie demain.'),
        findsOneWidget);
    // Le texte reste dans le champ.
    expect(find.text('Encore une question ?'), findsOneWidget);
  });

  testWidgets('sous restriction (lecture seule) : pas de compositeur',
      (tester) async {
    final api = FakeCommunityApi()
      ..meResponse = meJson(restriction: <String, dynamic>{
        'kind': 'read_only',
        'until': '2026-10-24T00:00:00.000Z',
        'reason': 'Messages répétés.',
      });
    await _openComposer(tester, api);
    expect(find.text('Nouvelle publication'), findsNothing);
    expect(find.text('Lecture seule'), findsOneWidget);
    expect(find.text('Motif : Messages répétés.'), findsOneWidget);
    expect(CommunityStore.instance.me?.restriction, isNotNull);
  });
}
