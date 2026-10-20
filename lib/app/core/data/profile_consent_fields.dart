import '../models/app_models.dart';

/// Les clés du PATCH `/profiles/me` qui portent un CONSENTEMENT ou un REFUS
/// (audit 57, F24).
///
/// Avant ce correctif, chaque synchro renvoyait la copie LOCALE de ces champs.
/// Un désabonnement fait ailleurs — lien « Se désabonner » de l'e-mail,
/// désabonnement en un clic de Gmail, autre téléphone, console — était donc
/// annulé au lancement suivant, et le serveur horodatait en plus un
/// consentement que l'élève n'avait jamais redonné.
///
/// Règle : ces clés ne partent QUE quand l'élève a changé la valeur sur CET
/// appareil (changement « en attente », persisté jusqu'à l'accusé du serveur).
/// Le reste du temps, c'est la valeur du serveur qui fait foi.
abstract final class ProfileConsentFields {
  /// Lettre d'information bourses (Mautic).
  static const newsletter = 'scholarshipNewsletterOptIn';

  /// Nouvelles et offres de KPB par e-mail (XC-06).
  static const promotionsEmail = 'promotionsEmailOptIn';

  /// Nouvelles et offres de KPB par notification (App Store 4.5.4).
  static const promotionsPush = 'promotionsPushOptIn';

  /// Familles de notifications coupées (dont `kpb_promotions`).
  static const notificationOptOuts = 'disabledNotificationTypes';

  /// Accord pour le traitement par l'IA.
  static const aiConsent = 'aiConsentedAt';

  /// Accord du représentant légal (mineur).
  static const guardianConsent = 'guardianConsentedAt';

  static const all = <String>{
    newsletter,
    promotionsEmail,
    promotionsPush,
    notificationOptOuts,
    aiConsent,
    guardianConsent,
  };

  /// Les seuls consentements que l'onboarding montre (et donc qu'il peut
  /// changer). Le profil qu'il reconstruit de zéro ne connaît pas les autres :
  /// les compter comme « changés » renverrait une liste de coupures vide ou un
  /// opt-in absent à la place des vrais choix de l'élève.
  static const onboardingOwned = <String>{newsletter, guardianConsent};

  /// Valeur comparable d'un consentement ; [profile] nul = valeurs par défaut
  /// d'un profil neuf (non, aucune coupure, aucun accord).
  static Object? valueOf(UserProfile? profile, String key) {
    switch (key) {
      case newsletter:
        return profile?.wantsScholarshipNewsletter ?? false;
      case promotionsEmail:
        return profile?.promotionsEmailOptIn;
      case promotionsPush:
        return profile?.promotionsPushOptIn;
      case notificationOptOuts:
        final types = [...?profile?.disabledNotificationTypes]..sort();
        return types;
      case aiConsent:
        return profile?.aiConsentedAt?.toIso8601String();
      case guardianConsent:
        return profile?.guardianConsentedAt?.toIso8601String();
    }
    throw ArgumentError.value(key, 'key', 'clé de consentement inconnue');
  }

  static bool same(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Les consentements de [keys] dont la valeur diffère entre [before] et
  /// [after] : ce sont les gestes de l'élève à envoyer au serveur.
  static Set<String> changed(
    UserProfile? before,
    UserProfile after, {
    Set<String> keys = all,
  }) =>
      {
        for (final key in keys)
          if (!same(valueOf(before, key), valueOf(after, key))) key,
      };

  /// [target] avec les valeurs de [source] pour les consentements de [keys].
  ///
  /// Sert dans les deux sens : garder un geste en attente quand on applique le
  /// profil du serveur, et garder les choix connus quand l'onboarding
  /// reconstruit un profil qui ne les porte pas.
  static UserProfile carryOver(
    UserProfile target,
    UserProfile? source,
    Iterable<String> keys,
  ) {
    if (source == null) return target;
    var out = target;
    for (final key in keys) {
      switch (key) {
        case newsletter:
          out = out.copyWith(
              wantsScholarshipNewsletter: source.wantsScholarshipNewsletter);
        case promotionsEmail:
          out = out.copyWith(promotionsEmailOptIn: source.promotionsEmailOptIn);
        case promotionsPush:
          out = out.copyWith(promotionsPushOptIn: source.promotionsPushOptIn);
        case notificationOptOuts:
          out = out.copyWith(
              disabledNotificationTypes: source.disabledNotificationTypes);
        case aiConsent:
          out = out.copyWith(aiConsentedAt: source.aiConsentedAt);
        case guardianConsent:
          out = out.copyWith(guardianConsentedAt: source.guardianConsentedAt);
      }
    }
    return out;
  }
}
