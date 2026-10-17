part of '../app_api_client.dart';

/// Classe un échec d'un appel `/community/*` (contrat §3).
///
/// Le `code` du filtre global tranche quand il est là ; sinon le statut HTTP.
/// Un 404 sans code (backend sans les routes) vaut « fonction coupée », comme
/// le 404 `community_disabled` : l'app masque, elle n'affiche pas d'erreur.
CommunityException classifyCommunityError(Object error) {
  if (error is CommunityException) return error;
  if (error is TimeoutException) {
    return const CommunityException(CommunityFailure.timeout);
  }
  if (error is FormatException || error is TypeError) {
    return const CommunityException(CommunityFailure.invalid);
  }
  if (error is! DioException) {
    return const CommunityException(CommunityFailure.server);
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const CommunityException(CommunityFailure.timeout);
    case DioExceptionType.connectionError:
      return const CommunityException(CommunityFailure.offline);
    default:
      break;
  }
  final response = error.response;
  final status = response?.statusCode;
  if (status == null) {
    return const CommunityException(CommunityFailure.offline);
  }
  final data = response?.data;
  final body = data is Map ? data : const <String, dynamic>{};
  final code = body['code'] is String ? body['code'] as String : null;
  final rawDetails = body['details'];
  final details = rawDetails is Map
      ? Map<String, dynamic>.from(rawDetails)
      : const <String, dynamic>{};
  int? retryAfter;
  final detailRetry = details['retryAfterSeconds'];
  if (detailRetry is num) retryAfter = detailRetry.toInt();
  retryAfter ??= int.tryParse(response?.headers.value('retry-after') ?? '');

  CommunityException make(CommunityFailure failure) => CommunityException(
        failure,
        statusCode: status,
        code: code,
        details: details,
        retryAfterSeconds: retryAfter,
      );

  switch (code) {
    case 'community_disabled':
      return make(CommunityFailure.disabled);
    case 'community_students_only':
      return make(CommunityFailure.studentsOnly);
    case 'community_charter_required':
      return make(CommunityFailure.charterRequired);
    case 'community_charter_outdated':
      return make(CommunityFailure.charterOutdated);
    case 'community_read_only':
      return make(CommunityFailure.readOnly);
    case 'community_rate_limited':
      return make(CommunityFailure.rateLimited);
    case 'community_post_not_found':
    case 'community_reply_not_found':
    case 'community_member_not_found':
    case 'community_entity_not_found':
      return make(CommunityFailure.notFound);
    case 'community_not_author':
      return make(CommunityFailure.notAuthor);
    case 'community_edit_window_closed':
      return make(CommunityFailure.editWindowClosed);
    case 'community_post_not_open':
      return make(CommunityFailure.postNotOpen);
    case 'community_invalid_mention':
      return make(CommunityFailure.invalidMention);
    case 'community_too_many_mentions':
      return make(CommunityFailure.tooManyMentions);
    case 'community_too_many_hashtags':
      return make(CommunityFailure.tooManyHashtags);
    case 'community_invalid_cursor':
      return make(CommunityFailure.invalidCursor);
    case 'community_cannot_react_own':
      return make(CommunityFailure.cannotReactOwn);
    case 'community_cannot_block_self':
      return make(CommunityFailure.cannotBlockSelf);
    case 'community_cannot_report_self':
      return make(CommunityFailure.cannotReportSelf);
    case 'community_cannot_block_team':
      return make(CommunityFailure.cannotBlockTeam);
  }
  if (body['disabled'] == true) return make(CommunityFailure.disabled);
  if (status == 404 || status == 405 || status == 501) {
    // Sans code connu : un backend plus ancien, sans les routes du contrat.
    // Le contrat donne un code à chaque « introuvable » métier.
    return make(CommunityFailure.disabled);
  }
  if (status == 401) return make(CommunityFailure.unauthorized);
  if (status == 403) return make(CommunityFailure.server);
  if (status == 429) return make(CommunityFailure.rateLimited);
  if (status == 408) return make(CommunityFailure.timeout);
  if (status == 400) return make(CommunityFailure.validation);
  return make(CommunityFailure.server);
}

/// La communauté (C1 + C2) — `docs/community-api-contract.md`.
///
/// Toutes les méthodes lèvent [CommunityException] (jamais une
/// `DioException` brute) : les écrans n'ont qu'un type d'erreur à lire.
mixin _CommunityApi on _ApiClientBase {
  static String _lang(String? lang) => lang == 'en' ? 'en' : 'fr';

  Future<T> _community<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (error) {
      throw classifyCommunityError(error);
    }
  }

  Map<String, dynamic> _page(String? cursor, int? limit, [String? lang]) =>
      <String, dynamic>{
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (limit != null) 'limit': limit,
        if (lang != null) 'lang': _lang(lang),
      };

  static Map<String, dynamic> _body(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const CommunityException(CommunityFailure.invalid);
  }

  static String _seg(String value) => Uri.encodeComponent(value);

  // ── Membre, charte ──────────────────────────────────────────────────────

  /// `GET /community/me`.
  Future<CommunityMe> fetchCommunityMe({String? lang}) => _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/me',
          queryParameters: <String, dynamic>{'lang': _lang(lang)},
        );
        final me = CommunityMe.fromJson(_body(response));
        if (me == null) {
          throw const CommunityException(CommunityFailure.invalid);
        }
        return me;
      });

  /// `POST /community/charter/accept` `{version}` — idempotent.
  Future<({String version, DateTime? acceptedAt})> acceptCommunityCharter(
    String version,
  ) =>
      _community(() async {
        final response = await _dio.post<dynamic>(
          '/community/charter/accept',
          data: <String, dynamic>{'version': version},
        );
        final body = _body(response);
        final accepted = body['acceptedVersion'];
        return (
          version:
              accepted is String && accepted.isNotEmpty ? accepted : version,
          acceptedAt: DateTime.tryParse('${body['acceptedAt']}'),
        );
      });

  /// `GET /community/me/posts`.
  Future<CommunityPage<CommunityPost>> fetchCommunityMyPosts({
    String? cursor,
    int? limit,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/me/posts',
          queryParameters: _page(cursor, limit, lang),
        );
        return CommunityPage.fromJson(_body(response), CommunityPost.fromJson);
      });

  /// `GET /community/me/following`.
  Future<CommunityPage<CommunityPost>> fetchCommunityFollowing({
    String? cursor,
    int? limit,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/me/following',
          queryParameters: _page(cursor, limit, lang),
        );
        return CommunityPage.fromJson(_body(response), CommunityPost.fromJson);
      });

  /// `GET /community/blocks`.
  Future<CommunityPage<CommunityBlockedMember>> fetchCommunityBlocks({
    String? cursor,
    int? limit,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/blocks',
          queryParameters: _page(cursor, limit),
        );
        return CommunityPage.fromJson(
            _body(response), CommunityBlockedMember.fromJson);
      });

  // ── Fils, recherche ─────────────────────────────────────────────────────

  /// `GET /community/feed` — rend aussi la charge brute (cache disque).
  Future<({CommunityPage<CommunityPost> page, Map<String, dynamic> raw})>
      fetchCommunityFeed({
    required CommunityFeedTab tab,
    CommunityPostType? type,
    String? hashtag,
    String? cursor,
    int? limit,
    String? lang,
  }) =>
          _community(() async {
            final response = await _dio.get<dynamic>(
              '/community/feed',
              queryParameters: <String, dynamic>{
                'tab': tab.wire,
                if (type != null && tab != CommunityFeedTab.unanswered)
                  'type': type.wire,
                if (hashtag != null && hashtag.isNotEmpty)
                  'hashtag': normalizeHashtagKey(hashtag),
                ..._page(cursor, limit, lang),
              },
            );
            final raw = _body(response);
            return (
              page: CommunityPage.fromJson(raw, CommunityPost.fromJson),
              raw: raw,
            );
          });

  /// `GET /community/search` — `q` de 2 à 100 caractères.
  Future<CommunityPage<CommunityPost>> searchCommunity({
    required String query,
    CommunityPostType? type,
    String? cursor,
    int? limit,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/search',
          queryParameters: <String, dynamic>{
            'q': query.trim(),
            if (type != null) 'type': type.wire,
            ..._page(cursor, limit, lang),
          },
        );
        return CommunityPage.fromJson(_body(response), CommunityPost.fromJson);
      });

  // ── Espaces et compteurs ────────────────────────────────────────────────

  /// `GET /community/entities/:type/:id`.
  Future<CommunityEntitySpace> fetchCommunityEntitySpace({
    required CommunityEntityType type,
    required String id,
    bool unanswered = false,
    String? cursor,
    int? limit,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/entities/${type.wire}/${_seg(id)}',
          queryParameters: <String, dynamic>{
            'sort': unanswered ? 'unanswered' : 'recent',
            ..._page(cursor, limit, lang),
          },
        );
        final space = CommunityEntitySpace.fromJson(_body(response));
        if (space == null) {
          throw const CommunityException(CommunityFailure.invalid);
        }
        return space;
      });

  /// `GET /community/entities/:type/:id/count` — léger, pour les fiches.
  Future<int> fetchCommunityEntityCount({
    required CommunityEntityType type,
    required String id,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/entities/${type.wire}/${_seg(id)}/count',
        );
        final count = _body(response)['discussionCount'];
        return count is num && count > 0 ? count.toInt() : 0;
      });

  /// `GET /community/entities/counts?refs=` — 50 références au plus.
  Future<List<CommunityEntityCount>> fetchCommunityEntityCounts(
    List<({CommunityEntityType type, String id})> refs,
  ) =>
      _community(() async {
        final unique = <String>[];
        for (final ref in refs) {
          final key = '${ref.type.wire}:${ref.id}';
          if (!unique.contains(key)) unique.add(key);
          if (unique.length == 50) break;
        }
        if (unique.isEmpty) return const <CommunityEntityCount>[];
        final response = await _dio.get<dynamic>(
          '/community/entities/counts',
          queryParameters: <String, dynamic>{'refs': unique.join(',')},
        );
        return CommunityPage.fromJson(
          _body(response),
          CommunityEntityCount.fromJson,
        ).items;
      });

  // ── Autocomplétion ──────────────────────────────────────────────────────

  /// `GET /community/mentions/suggest`.
  Future<List<CommunityMentionSuggestion>> suggestCommunityMentions({
    required String query,
    Set<CommunityEntityType>? types,
    int limit = 8,
    String? lang,
  }) =>
      _community(() async {
        final q = query.trim();
        if (q.isEmpty) return const <CommunityMentionSuggestion>[];
        final response = await _dio.get<dynamic>(
          '/community/mentions/suggest',
          queryParameters: <String, dynamic>{
            'q': q.length > 60 ? q.substring(0, 60) : q,
            if (types != null && types.isNotEmpty)
              'types': types.map((t) => t.wire).join(','),
            'limit': limit.clamp(1, 20),
            'lang': _lang(lang),
          },
        );
        return CommunityPage.fromJson(
          _body(response),
          CommunityMentionSuggestion.fromJson,
        ).items;
      });

  /// `GET /community/hashtags/suggest` — `q` vide : les plus utilisés.
  Future<List<CommunityHashtagSuggestion>> suggestCommunityHashtags({
    String query = '',
    int limit = 10,
  }) =>
      _community(() async {
        final q = normalizeHashtagKey(query.trim());
        final response = await _dio.get<dynamic>(
          '/community/hashtags/suggest',
          queryParameters: <String, dynamic>{
            'q': q.length > 40 ? q.substring(0, 40) : q,
            'limit': limit.clamp(1, 20),
          },
        );
        return CommunityPage.fromJson(
          _body(response),
          CommunityHashtagSuggestion.fromJson,
        ).items;
      });

  // ── Publications et réponses ────────────────────────────────────────────

  /// `POST /community/posts` → 201 `Post` (peut naître « en attente »).
  Future<CommunityPost> createCommunityPost({
    required CommunityPostType type,
    required String title,
    required String body,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.post<dynamic>(
          '/community/posts',
          queryParameters: <String, dynamic>{'lang': _lang(lang)},
          data: <String, dynamic>{
            'type': type.wire,
            'title': title.trim(),
            'body': body.trim(),
          },
        );
        final post = CommunityPost.fromJson(_body(response));
        if (post == null) {
          throw const CommunityException(CommunityFailure.invalid);
        }
        return post;
      });

  /// `PATCH /community/posts/:id`.
  Future<CommunityPost> updateCommunityPost({
    required String postId,
    CommunityPostType? type,
    String? title,
    String? body,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.patch<dynamic>(
          '/community/posts/${_seg(postId)}',
          queryParameters: <String, dynamic>{'lang': _lang(lang)},
          data: <String, dynamic>{
            if (type != null) 'type': type.wire,
            if (title != null) 'title': title.trim(),
            if (body != null) 'body': body.trim(),
          },
        );
        final post = CommunityPost.fromJson(_body(response));
        if (post == null) {
          throw const CommunityException(CommunityFailure.invalid);
        }
        return post;
      });

  /// `DELETE /community/posts/:id` → 204.
  Future<void> deleteCommunityPost(String postId) => _community(() async {
        await _dio.delete<dynamic>('/community/posts/${_seg(postId)}');
      });

  /// `GET /community/posts/:id` — rend aussi la charge brute (cache disque).
  Future<({CommunityPostDetail detail, Map<String, dynamic> raw})>
      fetchCommunityPost(String postId, {String? lang}) => _community(() async {
            final response = await _dio.get<dynamic>(
              '/community/posts/${_seg(postId)}',
              queryParameters: <String, dynamic>{'lang': _lang(lang)},
            );
            final raw = _body(response);
            final detail = CommunityPostDetail.fromJson(raw);
            if (detail == null) {
              throw const CommunityException(CommunityFailure.invalid);
            }
            return (detail: detail, raw: raw);
          });

  /// `GET /community/posts/:id/replies`.
  Future<CommunityPage<CommunityReply>> fetchCommunityReplies(
    String postId, {
    String? cursor,
    int? limit,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/posts/${_seg(postId)}/replies',
          queryParameters: _page(cursor, limit, lang),
        );
        return CommunityPage.fromJson(_body(response), CommunityReply.fromJson);
      });

  /// `POST /community/posts/:id/replies` → 201 `Reply`.
  Future<CommunityReply> createCommunityReply({
    required String postId,
    required String body,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.post<dynamic>(
          '/community/posts/${_seg(postId)}/replies',
          queryParameters: <String, dynamic>{'lang': _lang(lang)},
          data: <String, dynamic>{'body': body.trim()},
        );
        final reply = CommunityReply.fromJson(_body(response));
        if (reply == null) {
          throw const CommunityException(CommunityFailure.invalid);
        }
        return reply;
      });

  /// `PATCH /community/replies/:id`.
  Future<CommunityReply> updateCommunityReply({
    required String replyId,
    required String body,
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.patch<dynamic>(
          '/community/replies/${_seg(replyId)}',
          queryParameters: <String, dynamic>{'lang': _lang(lang)},
          data: <String, dynamic>{'body': body.trim()},
        );
        final reply = CommunityReply.fromJson(_body(response));
        if (reply == null) {
          throw const CommunityException(CommunityFailure.invalid);
        }
        return reply;
      });

  /// `DELETE /community/replies/:id` → 204.
  Future<void> deleteCommunityReply(String replyId) => _community(() async {
        await _dio.delete<dynamic>('/community/replies/${_seg(replyId)}');
      });

  // ── « Utile », suivre ───────────────────────────────────────────────────

  /// `PUT|DELETE /community/{posts|replies}/:id/helpful` — idempotents.
  Future<({int helpfulCount, bool hasMarkedHelpful})> setCommunityHelpful({
    required bool isReply,
    required String id,
    required bool helpful,
  }) =>
      _community(() async {
        final path =
            '/community/${isReply ? 'replies' : 'posts'}/${_seg(id)}/helpful';
        final response = helpful
            ? await _dio.put<dynamic>(path)
            : await _dio.delete<dynamic>(path);
        final body = _body(response);
        final count = body['helpfulCount'];
        final marked = body['hasMarkedHelpful'];
        return (
          helpfulCount: count is num && count > 0 ? count.toInt() : 0,
          hasMarkedHelpful: marked is bool ? marked : helpful,
        );
      });

  /// `PUT|DELETE /community/posts/:id/follow` → `{isFollowing}`.
  Future<bool> setCommunityFollow({
    required String postId,
    required bool follow,
  }) =>
      _community(() async {
        final path = '/community/posts/${_seg(postId)}/follow';
        final response = follow
            ? await _dio.put<dynamic>(path)
            : await _dio.delete<dynamic>(path);
        final value = _body(response)['isFollowing'];
        return value is bool ? value : follow;
      });

  // ── Signaler, bloquer, profils ──────────────────────────────────────────

  /// `POST /community/reports` → 201 (ou 200 : déjà signalé, sans doublon).
  Future<void> reportCommunity({
    required CommunityReportTarget target,
    required String targetId,
    required CommunityReportReason reason,
    String? details,
  }) =>
      _community(() async {
        final trimmed = details?.trim();
        await _dio.post<dynamic>(
          '/community/reports',
          data: <String, dynamic>{
            'targetType': target.wire,
            'targetId': targetId,
            'reason': reason.wire,
            if (trimmed != null && trimmed.isNotEmpty)
              'details': trimmed.length > CommunityLimitsSpec.reportDetailsMax
                  ? trimmed.substring(0, CommunityLimitsSpec.reportDetailsMax)
                  : trimmed,
          },
        );
      });

  /// `POST|DELETE /community/members/:memberId/block` → `{isBlocked}`.
  Future<bool> setCommunityBlock({
    required String memberId,
    required bool blocked,
  }) =>
      _community(() async {
        final path = '/community/members/${_seg(memberId)}/block';
        final response = blocked
            ? await _dio.post<dynamic>(path)
            : await _dio.delete<dynamic>(path);
        final value = _body(response)['isBlocked'];
        return value is bool ? value : blocked;
      });

  /// `GET /community/members/:memberId`.
  Future<CommunityMemberProfile> fetchCommunityMember(
    String memberId, {
    String? lang,
  }) =>
      _community(() async {
        final response = await _dio.get<dynamic>(
          '/community/members/${_seg(memberId)}',
          queryParameters: <String, dynamic>{'lang': _lang(lang)},
        );
        final profile = CommunityMemberProfile.fromJson(_body(response));
        if (profile == null) {
          throw const CommunityException(CommunityFailure.invalid);
        }
        return profile;
      });
}
