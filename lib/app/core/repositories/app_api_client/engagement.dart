part of '../app_api_client.dart';

/// Matches, parrainage, ambassadeur, avis publiés, orientation.
mixin _EngagementApi on _ApiClientBase {
  // ── Matches (Phase 0 / P0-D — kit US-003/US-004) ──────────────

  /// Top-N server-scored matches for the post-onboarding AHA moment.
  /// Returns `{items: [SchoolMatch JSON], isEstimate: bool}`.
  Future<Map<String, dynamic>> getAhaMatches({int limit = 3}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/matches/aha-moment',
      queryParameters: {'limit': limit},
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Best-scoring program of one institution for the caller.
  Future<Map<String, dynamic>> getSchoolMatch(String institutionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/matches/school/$institutionId',
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Referrals (KPB-69) ────────────────────────────────────────

  /// The caller's stable referral code + attribution stats.
  Future<Map<String, dynamic>> getMyReferral() async {
    final response = await _dio.get<Map<String, dynamic>>('/referrals/me');
    return response.data ?? <String, dynamic>{};
  }

  // ── Ambassadeur program (App-engagement · US-032→035) ─────────────────────

  /// The ambassador dashboard (real data once activated, else a sample
  /// preview). Shape parsed by [AmbassadorDashboard.fromApi].
  Future<Map<String, dynamic>> getAmbassadorDashboard() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/referrals/dashboard');
    return response.data ?? <String, dynamic>{};
  }

  /// Activate ambassador mode for the caller (mints a referral code).
  Future<Map<String, dynamic>> activateAmbassador(
    Map<String, dynamic> input,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/referrals/ambassador/activate',
      data: input,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Request a Wave payout of the FULL available balance (recorded, paid ≤48h).
  /// Returns `{id, amountFCFA, status, etaHours}`.
  Future<Map<String, dynamic>> requestAmbassadorWithdrawal() async {
    final response =
        await _dio.post<Map<String, dynamic>>('/referrals/withdraw');
    return response.data ?? <String, dynamic>{};
  }

  /// Top published counsellor reviews for the Home social-proof carousel.
  /// Returns `{reviews: [{id, counsellorId, reviewerName, rating, body,
  /// createdAt}, ...], count}`. Public endpoint — no auth required.
  Future<Map<String, dynamic>> getPublishedReviews() async {
    final response = await _dio.get<Map<String, dynamic>>('/impact/reviews');
    return response.data ?? <String, dynamic>{};
  }

  /// Attribute the caller to the owner of [code]. Returns
  /// `{attributed, alreadyReferred}`.
  Future<Map<String, dynamic>> redeemReferral(String code) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/referrals/redeem',
      data: {'code': code},
    );
    return response.data ?? <String, dynamic>{};
  }

  /// The caller's no-cash reward balance + recent ledger (KPB-77). Returns
  /// `{balance, history}`.
  Future<Map<String, dynamic>> getMyReferralCredits() async {
    final response = await _dio.get<Map<String, dynamic>>('/referrals/credits');
    return response.data ?? <String, dynamic>{};
  }

  /// Spend credits to mint a WhatsApp advisor review voucher. [clientRef] is a
  /// per-tap idempotency key so a retried call never double-spends. Returns
  /// `{ok, balance, voucherCode}` or `{ok:false, reason}`.
  Future<Map<String, dynamic>> redeemReviewVoucher(String clientRef) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/referrals/credits/redeem-voucher',
      data: {'clientRef': clientRef},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitOrientation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orientation/submit',
      data: payload,
      // Ranking is local, but the explanations come from the LLM.
      options: _aiOptions,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createOrientationSession(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orientation/sessions',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getOrientationResult(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/orientation/results/$sessionId',
    );
    return response.data ?? <String, dynamic>{};
  }
}
