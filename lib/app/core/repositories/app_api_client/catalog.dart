part of '../app_api_client.dart';

/// Catalogue, bourses, notifications, vols, contenus publics.
mixin _CatalogApi on _ApiClientBase {
  // ── Parcours & Témoignages (Chantier C) ────────────────────────────────────

  /// Returns the curated Parcours stories (videos + written interviews) from
  /// the DB-backed `/content/parcours` endpoint. Works without a YouTube API
  /// key: the content is served from the backend catalog (or its seed).
  Future<List<ParcoursStory>> listParcoursStories() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/content/parcours',
    );
    final data = response.data ?? <String, dynamic>{};
    final rawItems = (data['items'] as List<dynamic>? ?? const []);
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(ParcoursStory.fromApi)
        .where((s) => s.slug.isNotEmpty)
        .toList();
  }

  /// "Récit de la semaine" (KPB-169). Returns null when no story is featured —
  /// the caller renders nothing rather than promoting an arbitrary story.
  Future<ParcoursStory?> fetchStoryOfWeek() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/content/parcours/featured',
    );
    final story = response.data?['story'];
    if (story is! Map<String, dynamic>) return null;
    final parsed = ParcoursStory.fromApi(story);
    return parsed.slug.isEmpty ? null : parsed;
  }

  Future<List<dynamic>> listCatalog(String resource) async =>
      (await listCatalogEnvelope(resource)).items;

  /// Same call as [listCatalog], keeping the envelope's `source` field.
  ///
  /// The backend tags degraded answers with `source: "mock"` (bundled demo
  /// fixtures served when it cannot reach Postgres). Callers that persist rows
  /// — the offline cache — must check [CatalogListPayload.isTrustworthy] before
  /// storing them, otherwise fake catalog entries get pinned on the device.
  Future<CatalogListPayload> listCatalogEnvelope(String resource) async {
    final queryParameters =
        (resource == 'programs' || resource == 'institutions')
            ? <String, dynamic>{'limit': 1000}
            : null;
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/$resource',
      queryParameters: queryParameters,
    );
    final data = response.data ?? <String, dynamic>{};
    return CatalogListPayload(
      items: data['items'] as List<dynamic>? ?? <dynamic>[],
      source: CatalogDataSource.parse(data['source']),
    );
  }

  Future<Map<String, dynamic>> getCountryDetail(String countryKey) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/countries/${Uri.encodeComponent(countryKey)}',
    );
    return response.data ?? <String, dynamic>{};
  }

  // Country quiz submit endpoint removed (KPB-62): eligibility is scored
  // client-side by the single EligibilityEngine.

  /// Fetch live scraped scholarships, filtered and scored by the user's profile.
  Future<List<dynamic>> fetchLiveScholarships({
    required String lang,
    String? level,
    List<String>? fieldIds,
    String? countryId,
    String? fundingType,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'lang': lang,
      'limit': limit,
      'offset': offset,
      if (level != null) 'level': level,
      if (fieldIds != null && fieldIds.isNotEmpty) 'fields': fieldIds.join(','),
      if (countryId != null) 'countryId': countryId,
      if (fundingType != null) 'fundingType': fundingType,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/scholarships',
      queryParameters: queryParams,
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  /// Fetch one full scholarship when the detail endpoint is available, with a
  /// bounded list-scan fallback for deployments that still expose only
  /// `GET /scholarships`.
  ///
  /// [initial] is returned when a refresh fails after the student already
  /// opened the item from a populated list, so staged backend rollouts do not
  /// turn a useful cached detail into an error screen.
  Future<LiveScholarshipModel?> fetchLiveScholarshipDetailWithFallback({
    required String scholarshipId,
    required String lang,
    LiveScholarshipModel? initial,
  }) async {
    DioException? detailError;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/scholarships/${Uri.encodeComponent(scholarshipId)}',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      final raw = data['item'] is Map
          ? Map<String, dynamic>.from(data['item'] as Map)
          : data;
      if ((raw['id'] as String? ?? '').isNotEmpty) {
        return LiveScholarshipModel.fromJson(raw);
      }
    } on DioException catch (error) {
      detailError = error;
      final status = error.response?.statusCode;
      // Only an unavailable/not-yet-deployed endpoint should trigger the list
      // scan. Connectivity and authentication errors retain any initial item.
      if (status != 404 && status != 405 && status != 501) {
        if (initial != null) return initial;
        rethrow;
      }
    }

    const pageSize = 100;
    const maxPages = 5;
    try {
      for (var page = 0; page < maxPages; page++) {
        final raw = await fetchLiveScholarships(
          lang: lang,
          limit: pageSize,
          offset: page * pageSize,
        );
        for (final entry in raw.whereType<Map>()) {
          final json = Map<String, dynamic>.from(entry);
          if (json['id'] == scholarshipId) {
            return LiveScholarshipModel.fromJson(json);
          }
        }
        if (raw.length < pageSize) break;
      }
    } catch (_) {
      if (initial != null) return initial;
      if (detailError != null) throw detailError;
      rethrow;
    }
    return initial;
  }

  /// Today's featured scholarship (`GET /scholarships/daily`), or null when
  /// none is eligible. Same DTO shape as the detail endpoint; best-effort — the
  /// Home card self-hides on any error.
  Future<LiveScholarshipModel?> fetchDailyScholarship({
    required String lang,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/scholarships/daily',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      final raw = data['scholarship'];
      if (raw is Map && ((raw['id'] as String?) ?? '').isNotEmpty) {
        return LiveScholarshipModel.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Best-effort: the daily card degrades to hidden.
    }
    return null;
  }

  /// Scholarships for which the current student explicitly requested alerts.
  Future<Set<String>> fetchScholarshipAlerts() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/scholarship-alerts',
    );
    final items = response.data?['items'] as List<dynamic>? ?? <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => item['scholarshipId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> subscribeScholarshipAlert(String scholarshipId) async {
    await _dio.post<void>(
      '/me/scholarship-alerts/${Uri.encodeComponent(scholarshipId)}',
    );
  }

  Future<void> unsubscribeScholarshipAlert(String scholarshipId) async {
    await _dio.delete<void>(
      '/me/scholarship-alerts/${Uri.encodeComponent(scholarshipId)}',
    );
  }

  /// Durable in-app notifications created by scholarship activation events.
  Future<Map<String, dynamic>> fetchUserNotifications(String lang) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/notifications',
      queryParameters: {'lang': lang},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> markUserNotificationRead(String id) async {
    await _dio.patch<void>(
      '/me/notifications/${Uri.encodeComponent(id)}/read',
    );
  }

  Future<void> markAllUserNotificationsRead() async {
    await _dio.post<void>('/me/notifications/read-all');
  }

  // ── Suivre une bourse (chantier C — routes des builds récentes) ──────────
  //
  // Chacune de ces routes peut répondre 404 sur un backend pas encore
  // déployé : les appelants lisent [isEndpointUnavailable] et se dégradent
  // (section masquée, interrupteur caché) au lieu d'afficher une erreur.

  /// `PATCH /me/scholarship-alerts/:id` `{notifyOpening}` — met l'annonce
  /// d'ouverture en sourdine (`false`) ou la rallume (`true`), sans toucher au
  /// favori. Rend `{scholarshipId, following, notifyOpening}`.
  Future<Map<String, dynamic>> updateScholarshipOpeningAlert(
    String scholarshipId, {
    required bool notifyOpening,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/me/scholarship-alerts/${Uri.encodeComponent(scholarshipId)}',
      data: <String, dynamic>{'notifyOpening': notifyOpening},
    );
    return response.data ?? <String, dynamic>{};
  }

  /// `GET /me/followed-scholarships` — les bourses suivies, closes comprises.
  Future<FollowedScholarshipsPage> fetchFollowedScholarships(
      String lang) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/followed-scholarships',
      queryParameters: <String, dynamic>{'lang': lang == 'en' ? 'en' : 'fr'},
    );
    return FollowedScholarshipsPage.fromJson(
      response.data ?? <String, dynamic>{},
    ).withFetchedAt(DateTime.now());
  }

  /// `GET /me/notifications/unread-count` — le badge de la cloche, sans
  /// rapatrier le fil.
  Future<int> fetchUnreadNotificationCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/notifications/unread-count',
    );
    final raw = response.data?['unreadCount'];
    return raw is num && raw > 0 ? raw.toInt() : 0;
  }

  /// `POST /me/notifications/read-by-ref` — marque lues les entrées d'inbox
  /// d'un push (ex. le push groupé). Au plus 20 références par appel, filtrées
  /// ici sur le motif du contrat pour ne jamais déclencher un 400.
  Future<int> markNotificationsReadByRef(List<String> refs) async {
    final valid = sanitizeNotificationRefs(refs);
    if (valid.isEmpty) return 0;
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/notifications/read-by-ref',
      data: <String, dynamic>{'refs': valid},
    );
    final updated = response.data?['updated'];
    return updated is num ? updated.toInt() : 0;
  }

  /// Cheapest flight price for a route/date, proxied from Kayak Price-Insights.
  /// Returns the flat contract map `{configured, cached, currency, results:[]}`.
  Future<Map<String, dynamic>> flightRoutes({
    required String origin,
    required String destination,
    required String departDate,
    String? returnDate,
    String currency = 'EUR',
    String? userTrackId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/flights/routes',
      queryParameters: <String, dynamic>{
        'origin': origin,
        'destination': destination,
        'departDate': departDate,
        'currency': currency,
        if (returnDate != null) 'returnDate': returnDate,
        if (userTrackId != null) 'userTrackId': userTrackId,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Cheapest price per day (or month) across a date range, from Kayak
  /// Price-Insights. Returns `{configured, cached, currency, aggregation, days:[]}`.
  Future<Map<String, dynamic>> flightCalendar({
    required String origin,
    required String destination,
    required String dateFrom,
    required String dateTo,
    String aggregation = 'day',
    String currency = 'EUR',
    String? userTrackId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/flights/calendar',
      queryParameters: <String, dynamic>{
        'origin': origin,
        'destination': destination,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'aggregation': aggregation,
        'currency': currency,
        if (userTrackId != null) 'userTrackId': userTrackId,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listContent(String resource) async {
    final response = await _dio.get<Map<String, dynamic>>('/content/$resource');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listCommunity(String resource) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/community/$resource');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }
}
