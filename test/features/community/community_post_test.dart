// Le détail d'une discussion : entités citées cliquables, réponse vérifiée
// épinglée en tête, « utile », suivre, répondre, signaler, bloquer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/services/community_store.dart';
import 'package:karatou/app/features/community/hub/community_post_screen.dart';

import 'community_test_support.dart';

Future<void> _settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetCommunityWorld);
  tearDown(tearDownCommunityWorld);

  testWidgets('publication, entités citées, réponse vérifiée en tête',
      (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    expect(find.text('Délai de réponse Campus France ?'), findsOneWidget);
    expect(find.text('Cité dans cette discussion'), findsOneWidget);
    expect(find.byKey(const ValueKey('comm-entity-scholarship-eiffel')),
        findsOneWidget);
    // La carte d'entité se lit d'un libellé complet.
    expect(
      tester
          .getSemantics(
              find.byKey(const ValueKey('comm-entity-scholarship-eiffel')))
          .label,
      contains('Bourse : Bourse Eiffel. Ouvrir la fiche'),
    );

    // La réponse vérifiée (servie en 2e) est rendue AVANT l'autre.
    final verified =
        tester.getTopLeft(find.byKey(const ValueKey('comm-reply-cr_2')));
    final other =
        tester.getTopLeft(find.byKey(const ValueKey('comm-reply-cr_1')));
    expect(verified.dy, lessThan(other.dy));
    expect(find.text('Réponse vérifiée par KPB'), findsOneWidget);
    expect(find.text('Équipe KPB'), findsWidgets);
  });

  testWidgets('« utile » et « suivre » partent au serveur', (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    await tester.tap(find.text('Utile · 2').first);
    await tester.pumpAndSettle();
    expect(api.helpfulCalls.first,
        {'isReply': false, 'id': 'cp_1', 'helpful': true});
    expect(find.text('Utile · 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('comm-post-follow')));
    await tester.pumpAndSettle();
    expect(api.followCalls.single, {'postId': 'cp_1', 'follow': true});
    await _settleToasts(tester);
  });

  testWidgets('répondre : la réponse s’ajoute et suit la discussion',
      (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    await tester.enterText(
        find.byKey(const ValueKey('comm-reply-field')), 'Merci pour l’info !');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comm-reply-send')));
    await tester.pumpAndSettle();
    expect(api.createdReplies, ['Merci pour l’info !']);
    expect(find.byKey(const ValueKey('comm-reply-cr_new')), findsOneWidget);
    expect(find.text('5 réponses'), findsOneWidget);
    await _settleToasts(tester);
  });

  testWidgets('menu ⋯ → signaler (motif « arnaque »)', (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    await tester.tap(find.byKey(const ValueKey('comm-post-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comm-menu-report')));
    await tester.pumpAndSettle();

    expect(find.text('Signaler la publication'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comm-report-scam')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comm-report-send')));
    await tester.pumpAndSettle();

    expect(api.reports.single['target'], 'post');
    expect(api.reports.single['targetId'], 'cp_1');
    expect(api.reports.single['reason'], 'scam');
    expect(find.text('Merci. L\'équipe KPB va regarder sous 24 h.'),
        findsOneWidget);
    await _settleToasts(tester);
  });

  testWidgets('bloquer l’auteur d’une réponse : ses réponses disparaissent',
      (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    final menu = find.descendant(
      of: find.byKey(const ValueKey('comm-reply-cr_1')),
      matching: find.byIcon(Icons.more_horiz_rounded),
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comm-menu-block')));
    await tester.pumpAndSettle();
    expect(find.text('Bloquer Moussa D. ?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comm-block-confirm')));
    await tester.pumpAndSettle();

    expect(api.blocks.single, {'memberId': 'cm_moussa', 'blocked': true});
    expect(CommunityStore.instance.isBlockedLocally('cm_moussa'), isTrue);
    expect(find.byKey(const ValueKey('comm-reply-cr_1')), findsNothing);
    // La réponse de l'équipe reste (on ne bloque jamais l'équipe).
    expect(find.byKey(const ValueKey('comm-reply-cr_2')), findsOneWidget);
    await _settleToasts(tester);
  });

  testWidgets('l’équipe KPB ne se bloque pas : pas d’entrée « Bloquer »',
      (tester) async {
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));
    final menu = find.descendant(
      of: find.byKey(const ValueKey('comm-reply-cr_2')),
      matching: find.byIcon(Icons.more_horiz_rounded),
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comm-menu-report')), findsOneWidget);
    expect(find.byKey(const ValueKey('comm-menu-block')), findsNothing);
  });

  testWidgets('ma publication : modifier (dans les 15 min) et supprimer',
      (tester) async {
    final api = FakeCommunityApi();
    api.detail = <String, dynamic>{
      'post': detailPostJson(
        viewer: viewerJson(
          isAuthor: true,
          canEdit: true,
          canDelete: true,
          editableUntil: DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
        ),
      ),
      'replies': {'items': <dynamic>[], 'nextCursor': null},
    };
    useTallPhone(tester);
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));
    await tester.tap(find.byKey(const ValueKey('comm-post-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comm-menu-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('comm-menu-delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('comm-menu-report')), findsNothing);
    expect(find.byKey(const ValueKey('comm-menu-block')), findsNothing);
  });

  testWidgets('drapeau fermé : la route de notification ne montre rien',
      (tester) async {
    resetCommunityWorld(flag: false);
    useTallPhone(tester);
    final api = FakeCommunityApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));
    expect(find.text('La communauté arrive bientôt'), findsOneWidget);
    expect(find.text('Délai de réponse Campus France ?'), findsNothing);
  });

  test('le type de rapport suit le contrat', () {
    expect(CommunityReportReason.values.map((r) => r.wire), [
      'scam',
      'harassment',
      'inappropriate',
      'spam',
      'personal_info',
      'misinformation',
      'other',
    ]);
  });
}
