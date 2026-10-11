part of '../app_api_client.dart';

/// Conseillers, offres, achats, alumni, partenaires, relecture IA, salon.
mixin _MarketplaceApi on _ApiClientBase {
  // ── Counsellor marketplace (Track B) ──────────────────────────────────────

  Future<List<dynamic>> listCounsellors({
    String? country,
    String? specialty,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/counsellors',
      queryParameters: {
        if (country != null) 'country': country,
        if (specialty != null) 'specialty': specialty,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getCounsellor(String counsellorId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/counsellors/$counsellorId',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Submit an admission-milestone review for a counsellor (KPB-75). Enters
  /// moderation (isPublished=false) until an admin publishes it.
  Future<void> submitCounsellorReview({
    required String counsellorId,
    required int rating,
    required String body,
    required String reviewerName,
    String? caseId,
  }) async {
    await _dio.post<void>(
      '/counsellors/${Uri.encodeComponent(counsellorId)}/reviews',
      data: {
        'rating': rating,
        'body': body,
        'reviewerName': reviewerName,
        if (caseId != null) 'caseId': caseId,
      },
    );
  }

  // ── Phase 3 — Service packages ("Dossier prêt" + kits) ────────────────────

  Future<List<dynamic>> listServicePackages({String? category}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/service-packages',
      queryParameters: {
        if (category != null) 'category': category,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getServicePackage(String code) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/service-packages/$code',
    );
    return response.data ?? <String, dynamic>{};
  }

  // purchaseServicePackage() removed: the app no longer initiates in-app
  // checkout. Students arrange payment with an advisor on WhatsApp (see
  // service_packages_screen). The backend purchase endpoint remains available.

  Future<Map<String, dynamic>> createWhatsAppServicePurchase({
    required String packageCode,
    String? caseId,
    String source = 'service_packages',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/purchases/whatsapp',
      data: {
        'packageCode': packageCode,
        if (caseId != null) 'caseId': caseId,
        'source': source,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listMyPurchases() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/purchases');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  // ── Phase 3 — Alumni mentor directory ─────────────────────────────────────

  Future<List<dynamic>> listAlumni({
    String? country,
    String? university,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/alumni',
      queryParameters: {
        if (country != null) 'country': country,
        if (university != null) 'university': university,
        if (limit != null) 'limit': limit.toString(),
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getMyAlumniStatus() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/alumni');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> applyAsAlumni({
    required String university,
    required String programme,
    required int graduationYear,
    required String proofUrl,
    String? countryCode,
    String? bioFr,
    String? bioEn,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/alumni/apply',
      data: {
        'alumniUniversity': university,
        'alumniProgramme': programme,
        'alumniGraduationYear': graduationYear,
        'alumniProofUrl': proofUrl,
        if (countryCode != null) 'alumniCountryCode': countryCode,
        if (bioFr != null) 'alumniBioFr': bioFr,
        if (bioEn != null) 'alumniBioEn': bioEn,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setAlumniBadgeVisible(bool visible) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/me/alumni/badge-visible',
      data: {'visible': visible},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Phase 3 — Partners (credibility layer) ────────────────────────────────

  Future<List<dynamic>> listPartners(
      {String? category, String? country}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/partners',
      queryParameters: {
        if (category != null) 'category': category,
        if (country != null) 'country': country,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listFeaturedPartners({int limit = 12}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/partners/featured',
      queryParameters: {'limit': limit.toString()},
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  // ── AI document review (Sprint 9 — Document Studio) ───────────────────────

  /// Sends a draft (motivation letter or CV) to the backend for structured
  /// AI feedback. [kind] is `'motivation'` or `'cv'`. Student-authenticated;
  /// the auth token is attached by the interceptor like other student calls.
  Future<Map<String, dynamic>> reviewDocument({
    required String kind,
    required String text,
    String language = 'fr',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/document-review',
      data: {'kind': kind, 'text': text, 'language': language},
      options: _aiOptions,
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Phase 3 — Salon KPB Virtuel ───────────────────────────────────────────

  Future<List<dynamic>> listSalonEvents() async {
    final response = await _dio.get<Map<String, dynamic>>('/salon/events');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getSalonEvent(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/salon/events/$slug',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> registerForSalonSession(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/salon/sessions/$sessionId/register',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> cancelSalonRegistration(String sessionId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/me/salon/sessions/$sessionId/register',
    );
  }

  Future<List<dynamic>> listMySalonRegistrations() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/me/salon/registrations');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }
}
