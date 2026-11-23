part of '../app_controller.dart';

/// No-cash referral rewards (KPB-77). The balance lives on the backend; this
/// mixin keeps a last-synced copy for display and routes redemptions through
/// the server (which is the source of truth — no local credit arithmetic).
mixin _ReferralCreditsMixin on _AppControllerBase {
  /// Refresh the referral reward balance from the backend. No-ops (keeping the
  /// last known value) when offline or on a transient failure.
  ///
  /// Le solde lu appartient au compte qui l'a demandé : arrivé après une
  /// déconnexion, il n'est ni affiché ni écrit sur disque pour le compte
  /// suivant (audit du 22/11/2026, n° 3).
  Future<void> refreshReviewCredits() async {
    final generation = _sessionGeneration;
    if (!await _apiClient.hasAuthSession()) return;
    if (_isStaleSession(generation)) return;
    try {
      final data = await _apiClient.getMyReferralCredits();
      if (_isStaleSession(generation)) return;
      _reviewCredits = (data['balance'] as num?)?.toInt() ?? _reviewCredits;
      _persist();
      update();
    } catch (_) {
      // Keep the last known balance.
    }
  }

  /// Spend a credit for a WhatsApp advisor review voucher. Returns the backend
  /// result (`{ok, balance, voucherCode}` or `{ok:false, reason}`) and re-syncs
  /// the balance from the authoritative response on success.
  ///
  /// Après une déconnexion pendant l'appel, la réponse est rendue telle quelle
  /// mais le solde du compte parti n'entre pas dans l'état.
  Future<Map<String, dynamic>> redeemReviewVoucher(String clientRef) async {
    final generation = _sessionGeneration;
    final res = await _apiClient.redeemReviewVoucher(clientRef);
    if (_isStaleSession(generation)) return res;
    if (res['ok'] == true) {
      _reviewCredits = (res['balance'] as num?)?.toInt() ?? _reviewCredits;
      _persist();
      update();
    }
    return res;
  }
}
