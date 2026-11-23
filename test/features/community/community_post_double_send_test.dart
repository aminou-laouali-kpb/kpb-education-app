// Audit du 22/11/2026, n° 18 : double envoi d'une réponse communauté.
//
// Le verrou `_sendingReply` n'était posé qu'APRÈS l'attente de
// `ensureCommunityCanWrite`, qui charge la fiche membre en réseau quand elle
// n'est pas encore connue (discussion ouverte depuis une notification). Un
// second appui pendant cette attente passait la garde, et la réponse était
// publiée deux fois. Même défaut sur les bascules « utile » : deux appuis
// rapides envoyaient helpful=true puis helpful=false en parallèle.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/features/community/hub/community_post_screen.dart';

import 'community_test_support.dart';

/// `GET /community/me` retenu tant que [meGate] n'est pas complété : le
/// réseau lent de l'élève.
class _SlowMeApi extends FakeCommunityApi {
  final Completer<void> meGate = Completer<void>();
  int meCalls = 0;

  /// Non nul : le prochain appel lève cette erreur (une seule fois).
  Object? meErrorOnce;

  @override
  Future<CommunityMe> fetchCommunityMe({String? lang}) async {
    meCalls++;
    await meGate.future;
    final error = meErrorOnce;
    if (error != null) {
      meErrorOnce = null;
      throw error;
    }
    return super.fetchCommunityMe(lang: lang);
  }
}

/// `setCommunityHelpful` retenu tant que [helpfulGate] n'est pas complété.
class _SlowHelpfulApi extends FakeCommunityApi {
  final Completer<void> helpfulGate = Completer<void>();

  @override
  Future<({int helpfulCount, bool hasMarkedHelpful})> setCommunityHelpful({
    required bool isReply,
    required String id,
    required bool helpful,
  }) async {
    final result = super.setCommunityHelpful(
      isReply: isReply,
      id: id,
      helpful: helpful,
    );
    await helpfulGate.future;
    return result;
  }
}

Future<void> _settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

void main() {
  setUp(resetCommunityWorld);
  tearDown(tearDownCommunityWorld);

  testWidgets(
      'deux appuis sur « envoyer » pendant le chargement de la fiche membre : '
      'une seule réponse publiée', (tester) async {
    useTallPhone(tester);
    final api = _SlowMeApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    await tester.enterText(
        find.byKey(const ValueKey('comm-reply-field')), 'Merci pour l’info !');
    await tester.pump();

    final send = find.byKey(const ValueKey('comm-reply-send'));
    await tester.tap(send);
    await tester.pump();
    // Rien n'est encore parti : la fiche membre est en cours de chargement.
    expect(api.meCalls, 1);
    expect(api.createdReplies, isEmpty);

    // L'élève, ne voyant rien bouger, appuie une seconde fois.
    await tester.tap(send, warnIfMissed: false);
    await tester.pump();

    api.meGate.complete();
    await tester.pumpAndSettle();

    expect(api.createdReplies, ['Merci pour l’info !'],
        reason: 'le second appui pendant le chargement de la fiche membre ne '
            'doit pas publier la réponse une deuxième fois');
    await _settleToasts(tester);
  });

  testWidgets(
      'fiche membre en échec : le verrou est relâché, l’élève peut '
      'réessayer', (tester) async {
    useTallPhone(tester);
    final api = _SlowMeApi()
      ..meErrorOnce = const CommunityException(CommunityFailure.offline);
    api.meGate.complete();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    await tester.enterText(
        find.byKey(const ValueKey('comm-reply-field')), 'Merci pour l’info !');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('comm-reply-send')));
    await tester.pumpAndSettle();
    expect(api.createdReplies, isEmpty);
    await _settleToasts(tester);

    // Le verrou posé avant l'attente a été relâché : le second essai part.
    await tester.tap(find.byKey(const ValueKey('comm-reply-send')));
    await tester.pumpAndSettle();
    expect(api.createdReplies, ['Merci pour l’info !']);
    await _settleToasts(tester);
  });

  testWidgets('deux appuis rapides sur « utile » : un seul envoi',
      (tester) async {
    useTallPhone(tester);
    final api = _SlowHelpfulApi();
    await pumpCommunityApp(tester,
        api: api, child: const CommunityPostScreen(postId: 'cp_1'));

    await tester.tap(find.text('Utile · 2').first);
    await tester.pump();
    // Optimiste : le compteur passe à 3, la requête est en vol.
    await tester.tap(find.text('Utile · 3').first);
    await tester.pump();

    api.helpfulGate.complete();
    await tester.pumpAndSettle();

    expect(api.helpfulCalls, [
      {'isReply': false, 'id': 'cp_1', 'helpful': true},
    ]);
    expect(find.text('Utile · 3'), findsOneWidget);
  });
}
