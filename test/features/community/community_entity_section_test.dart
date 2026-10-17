// « Discussions (N) » sur les fiches : compteur léger, trois dernières
// discussions, « Voir tout », « Poser une question sur X » (mention
// préremplie) ; repli silencieux quand le serveur ne répond pas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/services/community_store.dart';
import 'package:karatou/app/features/community/hub/community_entity_section.dart';
import 'package:karatou/app/features/community/hub/community_entity_space_screen.dart';
import 'package:karatou/app/features/community/hub/community_member_screen.dart';

import 'community_test_support.dart';

const _eiffel = CommunityMention(
  type: CommunityEntityType.scholarship,
  id: 'eiffel',
  label: 'Bourse Eiffel',
);

Widget _host() => const Scaffold(
      body: SingleChildScrollView(
        child: CommunityEntitySection(entity: _eiffel),
      ),
    );

void main() {
  setUp(resetCommunityWorld);
  tearDown(tearDownCommunityWorld);

  testWidgets('compteur, trois dernières, « Voir tout »', (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester, api: api, child: _host());

    // Un seul appel groupé `/entities/counts?refs=`.
    expect(api.countCalls, ['scholarship:eiffel']);
    expect(find.text('Discussions (2)'), findsOneWidget);
    expect(find.text('Délai de réponse Campus France ?'), findsOneWidget);
    expect(
        find.text('Mon conseil pour la lettre de motivation'), findsOneWidget);
    // Le compteur est mémorisé : pas de second appel à la réouverture.
    expect(
        CommunityStore.instance
            .cachedCount(CommunityEntityType.scholarship, 'eiffel'),
        2);

    await tester.tap(find.byKey(const ValueKey('comm-section-see-all')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityEntitySpaceScreen), findsOneWidget);
  });

  testWidgets('plusieurs sections dans une image : UN appel groupé',
      (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(
      tester,
      api: api,
      child: const Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              CommunityEntitySection(entity: _eiffel),
              CommunityEntitySection(
                entity: CommunityMention(
                    type: CommunityEntityType.country,
                    id: 'fra',
                    label: 'France'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(api.countCalls, ['scholarship:eiffel,country:fra']);
  });

  testWidgets('aucune discussion : invitation à poser la première question',
      (tester) async {
    final api = FakeCommunityApi()..entityCount = 0;
    await pumpCommunityApp(tester, api: api, child: _host());
    expect(find.text('Discussions (0)'), findsOneWidget);
    expect(
        find.text('Aucune discussion sur Bourse Eiffel pour l\'instant. '
            'Pose la première question.'),
        findsOneWidget);
    expect(api.spaceCalls, isEmpty); // pas de liste à charger
    expect(find.byKey(const ValueKey('comm-section-see-all')), findsNothing);
  });

  testWidgets('« Poser une question sur X » préremplit la mention',
      (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester, api: api, child: _host());
    await tester.tap(find.byKey(const ValueKey('comm-section-ask')));
    await tester.pumpAndSettle();

    final body = tester
        .widget<TextField>(find.byKey(const ValueKey('comm-composer-body')));
    expect(body.controller!.text, '@Bourse Eiffel ');
    expect(find.text('Citées dans ton message :'), findsOneWidget);
  });

  testWidgets('serveur muet : la section se replie, sans erreur',
      (tester) async {
    final api = FakeCommunityApi()
      ..countsError = const CommunityException(CommunityFailure.offline);
    await pumpCommunityApp(tester, api: api, child: _host());
    expect(find.byKey(const ValueKey('comm-entity-section')), findsNothing);
    expect(find.textContaining('Discussions'), findsNothing);
  });

  testWidgets('profil public minimal : badges, réponses utiles, mois',
      (tester) async {
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityMemberScreen(memberId: 'cm_aicha'));
    expect(find.text('Aïcha K.'), findsOneWidget);
    expect(find.text('Niger'), findsOneWidget);
    expect(find.text('Ambassadeur'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Réponses utiles'), findsOneWidget);
    expect(find.text('Membre depuis octobre 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('comm-member-block')), findsOneWidget);
  });

  testWidgets('utilisateurs bloqués : liste et « Débloquer »', (tester) async {
    final api = FakeCommunityApi()
      ..blockedMembers = <Map<String, dynamic>>[
        {
          'member': authorJson(memberId: 'cm_bad', displayName: 'Koffi A.'),
          'blockedAt': '2026-10-16T10:00:00.000Z',
        },
      ];
    await pumpCommunityApp(tester,
        api: api, child: const CommunityBlockedMembersScreen());
    expect(find.text('Koffi A.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comm-unblock-cm_bad')));
    await tester.pumpAndSettle();
    expect(api.blocks.single, {'memberId': 'cm_bad', 'blocked': false});
    expect(find.text('Koffi A.'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
