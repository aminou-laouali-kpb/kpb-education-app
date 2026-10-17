// L'accueil de la communauté : fils, badges de rôle, « Réponse vérifiée » dès
// la liste, puces de type, hashtags tendance, hors ligne lisible, et la
// charte avant la première publication.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/services/community_store.dart';
import 'package:karatou/app/features/community/hub/community_hub_screen.dart';

import 'community_test_support.dart';

void main() {
  late MemoryCommunityCacheStore cache;

  setUp(() => cache = resetCommunityWorld());
  tearDown(tearDownCommunityWorld);

  testWidgets('« Pour toi » : cartes, badges de rôle, réponse vérifiée',
      (tester) async {
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: api);

    expect(find.text('Communauté'), findsOneWidget);
    expect(find.text('Pour toi'), findsOneWidget);
    expect(find.text('Récents'), findsOneWidget);
    expect(find.text('Sans réponse'), findsOneWidget);
    expect(api.feedCalls.first['tab'], 'for_you');

    expect(find.text('Délai de réponse Campus France ?'), findsOneWidget);
    expect(find.text('Réponse vérifiée'), findsOneWidget);
    expect(find.text('Alumni vérifié'), findsOneWidget);
    expect(find.text('Conseiller KPB'), findsOneWidget);
    expect(find.text('4 réponses'), findsOneWidget);
    expect(find.text('2 utiles'), findsOneWidget);
    expect(find.text('#CampusFrance'), findsOneWidget); // tendance
    expect(find.byKey(const ValueKey('comm-hub-ask')), findsOneWidget);

    // TalkBack : une carte se lit d'un seul libellé complet.
    final semantics =
        tester.getSemantics(find.byKey(const ValueKey('comm-post-cp_1')).first);
    expect(semantics.label, contains('Question : Délai de réponse'));
    expect(semantics.label, contains('Alumni vérifié'));
    expect(semantics.label, contains('Réponse vérifiée par KPB'));
  });

  testWidgets('les puces de type et les hashtags filtrent le fil',
      (tester) async {
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: api);

    await tester.tap(find.byKey(const ValueKey('comm-type-advice')));
    await tester.pumpAndSettle();
    expect(api.feedCalls.last['type'], 'advice');

    await tester.tap(find.byKey(const ValueKey('comm-tag-campusfrance')));
    await tester.pumpAndSettle();
    expect(api.feedCalls.last['hashtag'], 'campusfrance');
    expect(api.feedCalls.last['type'], 'advice');
  });

  testWidgets('« Sans réponse » charge son propre fil, sans filtre de type',
      (tester) async {
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: api);

    await tester.tap(find.text('Sans réponse'));
    await tester.pumpAndSettle();
    expect(api.feedCalls.last['tab'], 'unanswered');
    expect(find.byKey(const ValueKey('comm-type-all')), findsNothing);
  });

  testWidgets('hors ligne sans cache : message clair et « Réessayer »',
      (tester) async {
    final api = FakeCommunityApi()
      ..feedError = const CommunityException(CommunityFailure.offline);
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: api);

    expect(find.text('Tu es hors ligne'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    api.feedError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Délai de réponse Campus France ?'), findsOneWidget);
  });

  testWidgets('hors ligne avec cache : le fil relu du disque, daté',
      (tester) async {
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: api);
    // La première page est partie au disque.
    expect(cache.entries.keys.where((k) => k.startsWith('feed::')), isNotEmpty);

    // Nouvel écran, réseau coupé : le cache s'affiche, avec son bandeau.
    resetFlagsKeepingCache(cache);
    final offline = FakeCommunityApi()
      ..feedError = const CommunityException(CommunityFailure.offline);
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: offline);
    expect(find.text('Délai de réponse Campus France ?'), findsOneWidget);
    expect(find.byKey(const ValueKey('kpb-cache-stamp')), findsOneWidget);
  });

  testWidgets('« Poser une question » montre la charte avant la 1re fois',
      (tester) async {
    final api = FakeCommunityApi()..meResponse = meJson(charterRequired: true);
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: api);

    await tester.tap(find.byKey(const ValueKey('comm-hub-ask')));
    await tester.pumpAndSettle();

    expect(find.text('Charte de la communauté'), findsOneWidget);
    expect(find.text('Jamais d’argent'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comm-charter-accept')));
    await tester.pumpAndSettle();

    expect(api.acceptedVersions, ['2026-10-v1']);
    expect(CommunityStore.instance.charterRequired, isFalse);
    // Puis le compositeur.
    expect(find.text('Nouvelle publication'), findsOneWidget);
  });

  testWidgets('un 404 community_disabled referme la communauté',
      (tester) async {
    // Le client réel classe le 404 `community_disabled` (voir
    // community_api_test.dart) ; ici, le chemin du magasin et de l'écran.
    final api = FakeCommunityApi()
      ..feedError = const CommunityException(CommunityFailure.disabled);
    await pumpCommunityApp(tester,
        child: const CommunityHubScreen(source: 'test'), api: api);

    expect(CommunityStore.instance.serverDisabled, isTrue);
    expect(find.text('La communauté arrive bientôt'), findsOneWidget);
  });
}

/// Garde le cache disque, remet le reste à zéro (nouvelle ouverture d'app).
void resetFlagsKeepingCache(MemoryCommunityCacheStore cache) {
  final kept = Map<String, String>.of(cache.entries);
  final fresh = resetCommunityWorld();
  fresh.entries.addAll(kept);
}
