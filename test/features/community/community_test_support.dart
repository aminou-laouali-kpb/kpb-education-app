// Fixtures et faux partagés par les tests de la communauté (C1 + C2).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/community_store.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

import '../../widget_test_helpers.dart';

Map<String, dynamic> authorJson({
  String kind = 'member',
  String? memberId = 'cm_aicha',
  String displayName = 'Aïcha K.',
  String? countryName = 'Niger',
  List<String> badges = const <String>[],
}) =>
    <String, dynamic>{
      'kind': kind,
      'memberId': memberId,
      'displayName': displayName,
      'countryName': countryName,
      'badges': badges,
    };

Map<String, dynamic> viewerJson({
  bool isAuthor = false,
  bool hasMarkedHelpful = false,
  bool isFollowing = false,
  bool canEdit = false,
  bool canDelete = false,
  String? editableUntil,
}) =>
    <String, dynamic>{
      'isAuthor': isAuthor,
      'hasMarkedHelpful': hasMarkedHelpful,
      'isFollowing': isFollowing,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'editableUntil': editableUntil,
    };

Map<String, dynamic> postJson({
  String id = 'cp_1',
  String type = 'question',
  String title = 'Délai de réponse Campus France ?',
  String excerpt = 'Bonjour, j’ai déposé mon dossier le 2 octobre…',
  Map<String, dynamic>? author,
  int replyCount = 4,
  int helpfulCount = 2,
  bool hasVerifiedAnswer = false,
  bool isPinned = false,
  List<Map<String, dynamic>>? mentions,
  Map<String, dynamic>? viewer,
  Map<String, dynamic>? moderation,
  String? body,
  List<Map<String, dynamic>>? segments,
}) =>
    <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'excerpt': excerpt,
      'author': author ?? authorJson(),
      'createdAt': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
      'editedAt': null,
      'lastActivityAt': DateTime.now().toUtc().toIso8601String(),
      'replyCount': replyCount,
      'helpfulCount': helpfulCount,
      'hasVerifiedAnswer': hasVerifiedAnswer,
      'isPinned': isPinned,
      'mentions': mentions ??
          <Map<String, dynamic>>[
            {
              'type': 'scholarship',
              'id': 'eiffel',
              'label': 'Bourse Eiffel',
              'countryId': 'fra',
            },
          ],
      'hashtags': [
        {'tag': 'campusfrance', 'display': 'CampusFrance'},
      ],
      'viewer': viewer ?? viewerJson(),
      'moderation': moderation,
      if (body != null) 'body': body,
      if (segments != null) 'segments': segments,
    };

Map<String, dynamic> detailPostJson({
  String id = 'cp_1',
  Map<String, dynamic>? author,
  Map<String, dynamic>? viewer,
  bool hasVerifiedAnswer = true,
}) =>
    postJson(
      id: id,
      author: author,
      viewer: viewer,
      hasVerifiedAnswer: hasVerifiedAnswer,
      body: 'Qui a eu @[Bourse Eiffel](scholarship:eiffel) en 2026 ? '
          '#CampusFrance',
      segments: <Map<String, dynamic>>[
        {'kind': 'text', 'text': 'Qui a eu '},
        {
          'kind': 'mention',
          'type': 'scholarship',
          'id': 'eiffel',
          'label': 'Bourse Eiffel',
        },
        {'kind': 'text', 'text': ' en 2026 ? '},
        {'kind': 'hashtag', 'tag': 'campusfrance', 'display': 'CampusFrance'},
      ],
    );

Map<String, dynamic> replyJson({
  String id = 'cr_1',
  String text = 'Moi, réponse reçue en 3 semaines.',
  Map<String, dynamic>? author,
  bool isVerified = false,
  int helpfulCount = 0,
  Map<String, dynamic>? viewer,
}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'cp_1',
      'body': text,
      'segments': [
        {'kind': 'text', 'text': text},
      ],
      'mentions': <dynamic>[],
      'author':
          author ?? authorJson(memberId: 'cm_moussa', displayName: 'Moussa D.'),
      'createdAt': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 30))
          .toIso8601String(),
      'editedAt': null,
      'helpfulCount': helpfulCount,
      'isVerified': isVerified,
      'verifiedAt':
          isVerified ? DateTime.now().toUtc().toIso8601String() : null,
      'viewer': viewer ?? viewerJson(),
      'moderation': null,
    };

Map<String, dynamic> meJson({
  bool charterRequired = false,
  Map<String, dynamic>? restriction,
}) =>
    <String, dynamic>{
      'member': authorJson(memberId: 'cm_me', displayName: 'Test U.'),
      'charter': {
        'currentVersion': '2026-10-v1',
        'acceptedVersion': charterRequired ? null : '2026-10-v1',
        'acceptedAt': null,
        'required': charterRequired,
        'title': 'Charte de la communauté',
        'rules': [
          {'id': 'kind', 'title': 'Bienveillance', 'body': 'Respecte chacun.'},
          {
            'id': 'no_money',
            'title': 'Jamais d’argent',
            'body': 'Ne demande jamais d’argent.'
          },
          {
            'id': 'no_contact',
            'title': 'Pas de coordonnées',
            'body': 'Pas de numéro.'
          },
          {
            'id': 'truth',
            'title': 'Des infos vérifiables',
            'body': 'Cite tes sources.'
          },
        ],
      },
      'restriction': restriction,
      'limits': {
        'newAccount': true,
        'postsPerDay': 3,
        'postsToday': 0,
        'repliesPerHour': 10,
        'repliesThisHour': 0,
      },
      'stats': {'helpfulAnswersCount': 0, 'postsCount': 0, 'repliesCount': 0},
      'notificationsOptedOut': false,
    };

/// Client de test : les routes de la communauté, programmables et comptées.
class FakeCommunityApi extends MockApiClient {
  Map<String, dynamic> meResponse = meJson();
  final List<String> acceptedVersions = <String>[];

  final List<Map<String, Object?>> feedCalls = <Map<String, Object?>>[];
  List<Map<String, dynamic>> feedItems = <Map<String, dynamic>>[
    postJson(
      id: 'cp_1',
      hasVerifiedAnswer: true,
      author: authorJson(badges: const ['verified_alumni']),
    ),
    postJson(
      id: 'cp_2',
      type: 'advice',
      title: 'Mon conseil pour la lettre de motivation',
      author: authorJson(
        kind: 'kpb_advisor',
        memberId: null,
        displayName: 'Fatou S.',
        countryName: null,
        badges: const ['kpb_advisor'],
      ),
      replyCount: 0,
      helpfulCount: 0,
    ),
  ];
  List<Map<String, dynamic>> pinnedItems = <Map<String, dynamic>>[];
  Object? feedError;

  Map<String, dynamic> detail = <String, dynamic>{
    'post': detailPostJson(),
    'replies': {
      'items': [
        replyJson(id: 'cr_1'),
        replyJson(
          id: 'cr_2',
          text: 'Réponse officielle : 4 à 6 semaines.',
          isVerified: true,
          author: authorJson(
            kind: 'kpb_team',
            memberId: null,
            displayName: 'Équipe KPB',
            countryName: null,
            badges: const ['kpb_team'],
          ),
        ),
      ],
      'nextCursor': null,
    },
  };

  List<Map<String, dynamic>> mentionSuggestions = <Map<String, dynamic>>[
    {
      'type': 'scholarship',
      'id': 'eiffel',
      'label': 'Bourse Eiffel',
      'subtitle': 'France',
      'countryId': 'fra',
    },
  ];
  final List<String> mentionQueries = <String>[];
  List<Map<String, dynamic>> hashtagSuggestions = <Map<String, dynamic>>[
    {'tag': 'campusfrance', 'display': 'CampusFrance', 'postCount': 12},
  ];

  final List<Map<String, Object?>> createdPosts = <Map<String, Object?>>[];
  Map<String, dynamic>? createModeration;
  Object? createError;

  final List<Map<String, Object?>> reports = <Map<String, Object?>>[];
  final List<Map<String, Object?>> blocks = <Map<String, Object?>>[];
  final List<Map<String, Object?>> helpfulCalls = <Map<String, Object?>>[];
  final List<Map<String, Object?>> followCalls = <Map<String, Object?>>[];
  final List<String> createdReplies = <String>[];

  int entityCount = 2;
  final List<String> countCalls = <String>[];
  final List<String> spaceCalls = <String>[];

  List<Map<String, dynamic>> blockedMembers = <Map<String, dynamic>>[];

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<CommunityMe> fetchCommunityMe({String? lang}) async =>
      CommunityMe.fromJson(meResponse)!;

  @override
  Future<({String version, DateTime? acceptedAt})> acceptCommunityCharter(
    String version,
  ) async {
    acceptedVersions.add(version);
    return (version: version, acceptedAt: DateTime.now());
  }

  @override
  Future<({CommunityPage<CommunityPost> page, Map<String, dynamic> raw})>
      fetchCommunityFeed({
    required CommunityFeedTab tab,
    CommunityPostType? type,
    String? hashtag,
    String? cursor,
    int? limit,
    String? lang,
  }) async {
    feedCalls.add(<String, Object?>{
      'tab': tab.wire,
      'type': type?.wire,
      'hashtag': hashtag,
      'cursor': cursor,
    });
    final error = feedError;
    if (error != null) throw error;
    final raw = <String, dynamic>{
      'tab': tab.wire,
      'items': feedItems,
      'nextCursor': null,
      'pinned': cursor == null ? pinnedItems : <dynamic>[],
    };
    return (
      page: CommunityPage.fromJson(raw, CommunityPost.fromJson),
      raw: raw,
    );
  }

  @override
  Future<List<CommunityHashtagSuggestion>> suggestCommunityHashtags({
    String query = '',
    int limit = 10,
  }) async =>
      CommunityPage.fromJson(
        <String, dynamic>{'items': hashtagSuggestions},
        CommunityHashtagSuggestion.fromJson,
      ).items;

  @override
  Future<List<CommunityMentionSuggestion>> suggestCommunityMentions({
    required String query,
    Set<CommunityEntityType>? types,
    int limit = 8,
    String? lang,
  }) async {
    mentionQueries.add(query);
    return CommunityPage.fromJson(
      <String, dynamic>{'items': mentionSuggestions},
      CommunityMentionSuggestion.fromJson,
    ).items;
  }

  @override
  Future<CommunityPost> createCommunityPost({
    required CommunityPostType type,
    required String title,
    required String body,
    String? lang,
  }) async {
    createdPosts.add(<String, Object?>{
      'type': type.wire,
      'title': title,
      'body': body,
    });
    final error = createError;
    if (error != null) throw error;
    return CommunityPost.fromJson(postJson(
      id: 'cp_new',
      type: type.wire,
      title: title,
      body: body,
      replyCount: 0,
      helpfulCount: 0,
      viewer: viewerJson(isAuthor: true, isFollowing: true, canDelete: true),
      moderation: createModeration,
      segments: const <Map<String, dynamic>>[],
    ))!;
  }

  /// Non nul : `fetchCommunityPost` lève cette erreur (hors ligne…).
  Object? detailError;
  int detailCalls = 0;

  @override
  Future<({CommunityPostDetail detail, Map<String, dynamic> raw})>
      fetchCommunityPost(String postId, {String? lang}) async {
    detailCalls++;
    final error = detailError;
    if (error != null) throw error;
    return (
      detail: CommunityPostDetail.fromJson(detail)!,
      raw: detail,
    );
  }

  @override
  Future<CommunityReply> createCommunityReply({
    required String postId,
    required String body,
    String? lang,
  }) async {
    createdReplies.add(body);
    return CommunityReply.fromJson(replyJson(
      id: 'cr_new',
      text: body,
      author: authorJson(memberId: 'cm_me', displayName: 'Test U.'),
      viewer: viewerJson(isAuthor: true),
    ))!;
  }

  @override
  Future<({int helpfulCount, bool hasMarkedHelpful})> setCommunityHelpful({
    required bool isReply,
    required String id,
    required bool helpful,
  }) async {
    helpfulCalls.add(<String, Object?>{
      'isReply': isReply,
      'id': id,
      'helpful': helpful,
    });
    return (helpfulCount: helpful ? 3 : 2, hasMarkedHelpful: helpful);
  }

  @override
  Future<bool> setCommunityFollow({
    required String postId,
    required bool follow,
  }) async {
    followCalls.add(<String, Object?>{'postId': postId, 'follow': follow});
    return follow;
  }

  @override
  Future<void> reportCommunity({
    required CommunityReportTarget target,
    required String targetId,
    required CommunityReportReason reason,
    String? details,
  }) async {
    reports.add(<String, Object?>{
      'target': target.wire,
      'targetId': targetId,
      'reason': reason.wire,
      'details': details,
    });
  }

  @override
  Future<bool> setCommunityBlock({
    required String memberId,
    required bool blocked,
  }) async {
    blocks.add(<String, Object?>{'memberId': memberId, 'blocked': blocked});
    return blocked;
  }

  Object? countsError;

  @override
  Future<List<CommunityEntityCount>> fetchCommunityEntityCounts(
    List<({CommunityEntityType type, String id})> refs,
  ) async {
    countCalls.add(refs.map((r) => '${r.type.wire}:${r.id}').join(','));
    final error = countsError;
    if (error != null) throw error;
    return [
      for (final r in refs)
        CommunityEntityCount(
            type: r.type, id: r.id, discussionCount: entityCount),
    ];
  }

  @override
  Future<CommunityEntitySpace> fetchCommunityEntitySpace({
    required CommunityEntityType type,
    required String id,
    bool unanswered = false,
    String? cursor,
    int? limit,
    String? lang,
  }) async {
    spaceCalls.add('${type.wire}:$id');
    return CommunityEntitySpace.fromJson(<String, dynamic>{
      'entity': {'type': type.wire, 'id': id, 'label': 'Bourse Eiffel'},
      'discussionCount': entityCount,
      'items': feedItems.take(entityCount).toList(),
      'nextCursor': null,
    })!;
  }

  @override
  Future<CommunityPage<CommunityBlockedMember>> fetchCommunityBlocks({
    String? cursor,
    int? limit,
  }) async =>
      CommunityPage.fromJson(
        <String, dynamic>{'items': blockedMembers, 'nextCursor': null},
        CommunityBlockedMember.fromJson,
      );

  @override
  Future<CommunityMemberProfile> fetchCommunityMember(
    String memberId, {
    String? lang,
  }) async =>
      CommunityMemberProfile.fromJson(<String, dynamic>{
        'member': authorJson(memberId: memberId, badges: ['ambassador']),
        'stats': {
          'helpfulAnswersCount': 12,
          'postsCount': 3,
          'repliesCount': 27
        },
        'memberSince': '2026-10',
        'viewer': {'isMe': false, 'isBlocked': false},
      })!;
}

/// Remet à zéro le monde des tests ; [flag] ouvre `features.community`.
MemoryCommunityCacheStore resetCommunityWorld({bool flag = true}) {
  Get.reset();
  RemoteFeatureFlags.resetForTest();
  if (flag) {
    RemoteFeatureFlags.instance
        .debugSetFeaturesForTest(const <String, bool>{'community': true});
  }
  final cache = MemoryCommunityCacheStore();
  CommunityStore.instance.debugReset();
  CommunityStore.instance.debugConfigure(cache: cache);
  return cache;
}

void tearDownCommunityWorld() {
  AppConfig.enableRemoteSyncOverride = null;
  RemoteFeatureFlags.resetForTest();
  CommunityStore.instance.debugReset();
  Get.reset();
}

/// Un snapshot d'élève connecté.
AppSnapshot studentSnapshot() => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(),
    );

/// Monte [child] dans une app traduite (français), avec un AppController
/// hydraté depuis [snapshot] et [api] comme client.
Future<AppController> pumpCommunityApp(
  WidgetTester tester, {
  required Widget child,
  required FakeCommunityApi api,
  AppSnapshot? snapshot,
  bool settle = true,
}) async {
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot ?? studentSnapshot()),
    apiClient: api,
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = false;
  Get.put<AppController>(controller, permanent: true);
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return controller;
}

/// Un snapshot de parent.
AppSnapshot parentCommunitySnapshot() => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(accountType: AccountType.parent),
    );

/// Un téléphone haut (432 × 2000 dp) : toute la discussion tient à l'écran.
void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}
