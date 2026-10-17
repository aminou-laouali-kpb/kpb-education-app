// Modèles de la communauté : lecture du contrat (§5) et tolérance (champ
// nouveau ignoré, énumération inconnue tolérée, élément illisible écarté).

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/community.dart';

void main() {
  test('Author : badges dans l’ordre stable, valeur inconnue ignorée', () {
    final author = CommunityAuthor.fromJson(<String, dynamic>{
      'kind': 'member',
      'memberId': 'cm_1',
      'displayName': 'Aïcha K.',
      'countryName': 'Niger',
      'badges': ['ambassador', 'future_badge', 'verified_alumni'],
    });
    expect(author.orderedBadges,
        [CommunityBadge.verifiedAlumni, CommunityBadge.ambassador]);
    expect(author.initials, 'AK');
    expect(author.isTeam, isFalse);

    final team = CommunityAuthor.fromJson(<String, dynamic>{
      'kind': 'kpb_team',
      'memberId': null,
      'displayName': 'Équipe KPB',
      'badges': <String>[],
    });
    expect(team.isTeam, isTrue);
    expect(team.orderedBadges, [CommunityBadge.kpbTeam]);
  });

  test('PostSummary : champs du contrat, `forYouReasons`, type inconnu', () {
    final post = CommunityPost.fromJson(<String, dynamic>{
      'id': 'cp_1',
      'type': 'poll', // valeur future
      'title': 'Titre',
      'excerpt': 'Extrait',
      'author': {'kind': 'member', 'displayName': 'A. B.'},
      'createdAt': '2026-10-17T09:30:00.000Z',
      'replyCount': 4,
      'helpfulCount': -3,
      'hasVerifiedAnswer': true,
      'isPinned': false,
      'mentions': [
        {'type': 'scholarship', 'id': 'e1', 'label': 'Eiffel'},
        {'type': 'future_type', 'id': 'x'},
        {'type': 'country'},
      ],
      'hashtags': [
        {'tag': 'cv', 'display': 'CV'},
      ],
      'viewer': {'isFollowing': true},
      'moderation': {
        'status': 'pending_review',
        'reason': 'auto_filter',
        'since': '2026-10-17T09:30:00.000Z',
      },
      'forYouReasons': ['followed_scholarship', 'verified_answer'],
      'newFieldFromV2': {'ignored': true},
    })!;
    expect(post.type, CommunityPostType.question);
    expect(post.helpfulCount, 0);
    expect(post.mentions.single.ref, 'scholarship:e1');
    expect(post.hashtags.single.display, 'CV');
    expect(post.viewer.isFollowing, isTrue);
    expect(post.moderation!.pending, isTrue);
    expect(post.moderation!.reason, CommunityModerationReason.autoFilter);
    expect(post.forYouReasons, hasLength(2));
    expect(post.isDetail, isFalse);
  });

  test(
      'segments : `kind` inconnu rendu comme texte ou ignoré ; lien non '
      'http(s) laissé en texte', () {
    final post = CommunityPost.fromJson(<String, dynamic>{
      'id': 'cp_1',
      'type': 'advice',
      'title': 'T',
      'author': {'displayName': 'X'},
      'body': 'brut',
      'segments': [
        {'kind': 'text', 'text': 'a'},
        {'kind': 'emoji', 'text': '🙂'},
        {'kind': 'emoji'},
        {'kind': 'link', 'url': 'javascript:alert(1)', 'text': 'piège'},
        {
          'kind': 'link',
          'url': 'https://www.campusfrance.org/fr',
          'text': 'CF'
        },
        {'kind': 'mention', 'type': 'program', 'id': 'p1', 'label': 'Master'},
      ],
    })!;
    final segments = post.segments!;
    expect(segments, hasLength(5));
    expect((segments[1] as CommunityTextSegment).text, '🙂');
    expect(segments[2], isA<CommunityTextSegment>());
    expect(segments[3], isA<CommunityLinkSegment>());
    expect(segments[4], isA<CommunityMentionSegment>());
    expect(post.isDetail, isTrue);
  });

  test('Me : charte requise déduite des versions si `required` absent', () {
    final me = CommunityMe.fromJson(<String, dynamic>{
      'member': {'displayName': 'Moi'},
      'charter': {
        'currentVersion': '2026-10-v2',
        'acceptedVersion': '2026-10-v1',
        'rules': [
          {'id': 'kind', 'title': 'Bienveillance', 'body': '…'},
        ],
      },
      'restriction': {'kind': 'read_only', 'until': null, 'reason': 'Spam'},
      'limits': {'postsPerDay': 3, 'postsToday': 3},
    })!;
    expect(me.charterRequired, isTrue);
    expect(me.restriction!.isBan, isFalse);
    expect(me.limits.postsExhausted, isTrue);
    final accepted =
        me.withCharter(me.charter!.accepted('2026-10-v2', DateTime.now()));
    expect(accepted.charterRequired, isFalse);
  });

  test('MemberProfile : `memberSince` AAAA-MM seulement', () {
    final p = CommunityMemberProfile.fromJson(<String, dynamic>{
      'member': {'displayName': 'A.'},
      'stats': {'helpfulAnswersCount': 2},
      'memberSince': '2026-10-17',
      'viewer': {'isMe': false, 'isBlocked': true},
    })!;
    expect(p.memberSince, isNull); // une date exacte n'est jamais affichée
    expect(p.isBlocked, isTrue);
    expect(p.stats.helpfulAnswersCount, 2);
  });

  test('Page : curseur opaque, épinglées, éléments illisibles écartés', () {
    final page = CommunityPage.fromJson(<String, dynamic>{
      'items': [
        {'id': 'cp_1', 'type': 'question', 'title': 'A', 'author': {}},
        {'title': 'sans id'},
        'pas un objet',
      ],
      'nextCursor': 'eyJhc09mIjoiMjAyNi0xMC0xNyJ9',
      'pinned': [
        {'id': 'cp_9', 'type': 'advice', 'title': 'P', 'author': {}},
      ],
    }, CommunityPost.fromJson);
    expect(page.items.single.id, 'cp_1');
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'eyJhc09mIjoiMjAyNi0xMC0xNyJ9');
    expect(page.pinned.single.id, 'cp_9');
  });

  test('Reply : corps brut rendu en texte si le serveur n’a pas découpé', () {
    final reply = CommunityReply.fromJson(<String, dynamic>{
      'id': 'cr_1',
      'postId': 'cp_1',
      'body': 'Bonjour',
      'author': {'displayName': 'X'},
      'isVerified': true,
    })!;
    expect((reply.segments.single as CommunityTextSegment).text, 'Bonjour');
    expect(reply.isVerified, isTrue);
  });

  test('Viewer : fenêtre de modification de 15 min', () {
    final now = DateTime.utc(2026, 10, 17, 10);
    final open = CommunityViewer(
        canEdit: true, editableUntil: now.add(const Duration(minutes: 5)));
    final closed = CommunityViewer(
        canEdit: true, editableUntil: now.subtract(const Duration(minutes: 1)));
    expect(open.canEditAt(now), isTrue);
    expect(closed.canEditAt(now), isFalse);
    expect(const CommunityViewer().canEditAt(now), isFalse);
  });
}
