import 'package:collection/collection.dart';

import '../models/app_models.dart';
import '../utils/currency_utils.dart';
import 'json_parse_utils.dart';
import 'notification_opt_out.dart';

/// Maps `/profiles/me` JSON to [UserProfile].
abstract final class ProfileApiCodec {
  static UserProfile userProfileFromApi(
    Map<String, dynamic> json, {
    required String fallbackLocale,
  }) {
    final id = json['id'] as String?;
    // A profile without an id would silently impersonate a placeholder user
    // and poison the local store; the sync call-site catches and reports.
    if (id == null || id.isEmpty) {
      throw const FormatException('Profile payload is missing "id".');
    }
    return UserProfile(
      id: id,
      accountType: AccountType.values
              .firstWhereOrNull((item) => item.name == json['accountType']) ??
          AccountType.student,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsApp: json['whatsApp'] as String? ?? '',
      countryOfResidence: json['countryOfResidence'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? fallbackLocale,
      // Indice POSITIF seulement : évite une requête d'image inutile quand
      // l'utilisateur n'a pas de photo. `false` ne prouve rien (le profil peut
      // être plus ancien que le dernier envoi), donc le widget sonde quand même
      // et laisse le 404 trancher.
      hasAvatar: json['hasAvatar'] as bool? ?? false,
      currentLevel: json['currentLevel'] as String?,
      targetLevel: json['targetLevel'] as String?,
      languageLevel: json['languageLevel'] as String?,
      fieldIds: stringListFromJson(json['fieldIds']),
      targetCountryIds: stringListFromJson(json['targetCountryIds']),
      gradeRange: json['gradeRange'] as String?,
      bacSeries: json['bacSeries'] as String?,
      annualTuitionBudgetEur: json['annualTuitionBudgetEur'] as int? ??
          ((json['monthlyBudgetEur'] as int?) != null
              ? (json['monthlyBudgetEur'] as int) * 12
              : null),
      monthlyBudgetEur: json['monthlyBudgetEur'] as int?,
      preferredCurrency: DisplayCurrency.tryParse(
            json['preferredCurrency'] as String?,
          )?.code ??
          'XOF',
      wantsScholarshipSupport: json['wantsScholarshipSupport'] as bool? ??
          json['wantsScholarship'] as bool? ??
          false,
      wantsScholarshipNewsletter:
          json['scholarshipNewsletterOptIn'] as bool? ?? false,
      // Absent d'un serveur antérieur aux correctifs 57 : reste `null`.
      promotionsEmailOptIn: json['promotionsEmailOptIn'] as bool?,
      disabledNotificationTypes: _optOutTypes(json),
      availableDocuments: stringListFromJson(json['availableDocuments']),
      consentedAt: DateTime.tryParse(json['consentedAt'] as String? ?? ''),
      aiConsentedAt: DateTime.tryParse(json['aiConsentedAt'] as String? ?? ''),
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      guardianName: json['guardianName'] as String?,
      guardianContact: json['guardianContact'] as String?,
      guardianConsentedAt:
          DateTime.tryParse(json['guardianConsentedAt'] as String? ?? ''),
    );
  }

  /// KPB-169: the canonical list, with a fallback to the legacy per-type
  /// booleans so a server that has not shipped the array yet still yields the
  /// right switch state. Unknown keys are kept — see [applyOptOut].
  static List<String> _optOutTypes(Map<String, dynamic> json) {
    final raw = json['disabledNotificationTypes'];
    if (raw is List) {
      final types = raw.whereType<String>().where((t) => t.isNotEmpty).toList()
        ..sort();
      return List.unmodifiable(types);
    }
    return List.unmodifiable([
      if (json['dailyScholarshipOptOut'] == true)
        NotificationOptOutType.dailyScholarship,
      if (json['weeklyDigestOptOut'] == true)
        NotificationOptOutType.weeklyDigest,
    ]);
  }
}
