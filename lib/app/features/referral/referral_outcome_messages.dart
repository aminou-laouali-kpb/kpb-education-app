import '../../core/services/referral_attribution.dart';

/// La clé de traduction du message à montrer pour [outcome].
///
/// [onReferralScreen] : depuis l'écran Parrainage lui-même, les pannes
/// passagères ne renvoient pas « plus tard depuis Profil → Parrainer un ami »
/// — l'élève y est déjà.
String referralOutcomeMessageKey(
  ReferralRedeemOutcome outcome, {
  bool onReferralScreen = false,
}) =>
    switch (outcome) {
      ReferralRedeemOutcome.attributed => 'referral_redeemed_ok',
      ReferralRedeemOutcome.alreadyReferred => 'referral_redeemed_already',
      ReferralRedeemOutcome.unknownCode => 'referral_err_unknown',
      ReferralRedeemOutcome.selfReferral => 'referral_err_self',
      ReferralRedeemOutcome.notAllowed => 'referral_err_not_allowed',
      ReferralRedeemOutcome.rateLimited => onReferralScreen
          ? 'referral_err_rate_limited_here'
          : 'referral_err_rate_limited',
      ReferralRedeemOutcome.offline =>
        onReferralScreen ? 'referral_err_offline_here' : 'referral_err_offline',
      ReferralRedeemOutcome.error =>
        onReferralScreen ? 'referral_err_generic_here' : 'referral_err_generic',
    };

/// La valeur `prefill` de la mesure d'audience pour un code en attente.
String referralPrefillWire(PendingReferralCode? pending) =>
    pending?.origin.wireName ?? 'none';
