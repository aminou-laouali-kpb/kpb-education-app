part of 'app_models.dart';

enum AccountType { student, parent, partner, commercial }

enum InternalRole {
  admin,
  counselor,
  commercial,
  contentManager,
  moderator,
  superAdmin,
}

enum PublicationStatus { draft, published, archived }

class LocalizedText {
  const LocalizedText({
    required this.fr,
    required this.en,
  });

  final String fr;
  final String en;

  String resolve(String localeCode) => localeCode.startsWith('fr') ? fr : en;

  factory LocalizedText.fromJson(Map<String, dynamic> json) {
    return LocalizedText(
      fr: json['fr'] as String? ?? '',
      en: json['en'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fr': fr,
        'en': en,
      };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.accountType,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.whatsApp,
    required this.countryOfResidence,
    required this.preferredLanguage,
    this.currentLevel,
    this.targetLevel,
    this.languageLevel,
    this.fieldIds = const [],
    this.targetCountryIds = const [],
    this.gradeRange,
    this.bacSeries,
    this.annualTuitionBudgetEur,
    this.monthlyBudgetEur,
    this.preferredCurrency = 'XOF',
    this.wantsScholarshipSupport = false,
    this.wantsScholarshipNewsletter = false,
    this.disabledNotificationTypes = const [],
    this.availableDocuments = const [],
    this.consentedAt,
    this.aiConsentedAt,
    this.birthDate,
    this.guardianName,
    this.guardianContact,
    this.guardianConsentedAt,
    this.hasAvatar = false,
  });

  final String id;
  final AccountType accountType;
  final String fullName;
  final String email;
  final String phone;
  final String whatsApp;
  final String countryOfResidence;
  final String preferredLanguage;
  final String? currentLevel;
  final String? targetLevel;
  final String? languageLevel;
  final List<String> fieldIds;
  final List<String> targetCountryIds;
  final String? gradeRange;
  final String? bacSeries;

  /// Annual tuition budget, stored in EUR for matching and filtering.
  final int? annualTuitionBudgetEur;

  /// Legacy living-budget value retained only to read older snapshots/APIs.
  final int? monthlyBudgetEur;
  final String preferredCurrency;
  final bool wantsScholarshipSupport;

  /// Opt-in to the scholarship newsletter (Mautic). Unchecked by default —
  /// GDPR requires an explicit, freely given consent. The backend stamps the
  /// consent timestamp; the app only carries the desired boolean.
  final bool wantsScholarshipNewsletter;

  /// KPB-169: the recurring notification families this student has opted OUT
  /// of, as stable keys ([NotificationOptOutType]). One list rather than one
  /// boolean per family: adding a family costs a key, not a schema change.
  ///
  /// Opting out of one family never silences another, and never silences
  /// transactional notifications (deadlines, dossier, messages).
  final List<String> disabledNotificationTypes;

  bool isNotificationTypeDisabled(String type) =>
      disabledNotificationTypes.contains(type);
  final List<String> availableDocuments;
  final DateTime? consentedAt;

  /// Timestamp of explicit consent to third-party AI (Groq) processing. Null
  /// until the user opts into the AI coach. Distinct from [consentedAt].
  final DateTime? aiConsentedAt;

  /// Whether the user has granted explicit consent to AI processing.
  bool get hasAiConsent => aiConsentedAt != null;

  /// Declared birth date (onboarding age gate). Null until provided.
  final DateTime? birthDate;

  /// Self-attested guardian details + consent for users who declared an age
  /// under 18. [guardianConsentedAt] gates data sync and AI processing.
  final String? guardianName;
  final String? guardianContact;
  final DateTime? guardianConsentedAt;

  /// Age in whole years from [birthDate], or null if no birth date is set.
  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years;
  }

  /// Whether the user declared an age under 18. False when no birth date is
  /// set (we never assume someone is a minor without a declaration).
  bool get isMinor => (age ?? 99) < 18;

  /// Whether a declared minor has recorded guardian consent.
  bool get hasGuardianConsent => guardianConsentedAt != null;

  /// Whether the user has a profile photo stored server-side.
  ///
  /// The avatar itself is a PRIVATE object served by the authenticated
  /// `GET /profiles/me/avatar`; the profile never carries a storage path, only
  /// this boolean. It is a display *hint*: when true the UI can fetch straight
  /// away; when false it may still probe (the fetch 404s and falls back to the
  /// initials) because this flag is only as fresh as the last profile pull.
  final bool hasAvatar;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? whatsApp,
    String? countryOfResidence,
    String? preferredLanguage,
    String? currentLevel,
    String? targetLevel,
    String? languageLevel,
    List<String>? fieldIds,
    List<String>? targetCountryIds,
    String? gradeRange,
    String? bacSeries,

    /// `copyWith(bacSeries: null)` ne peut PAS effacer : `null` y signifie
    /// « ne change rien », c'est la sémantique de tout ce constructeur. Or la
    /// feuille de profil met bien `_bacSeries` à `null` quand l'étudiant passe
    /// à un niveau qui n'a pas de série de bac — et sans ce drapeau la série
    /// obsolète survivait, en continuant de satisfaire l'item « moyenne » du
    /// score de complétion.
    bool clearBacSeries = false,
    int? annualTuitionBudgetEur,
    int? monthlyBudgetEur,
    String? preferredCurrency,
    bool? wantsScholarshipSupport,
    bool? wantsScholarshipNewsletter,
    List<String>? disabledNotificationTypes,
    List<String>? availableDocuments,
    DateTime? consentedAt,
    DateTime? aiConsentedAt,
    DateTime? birthDate,
    String? guardianName,
    String? guardianContact,
    DateTime? guardianConsentedAt,
    bool? hasAvatar,
  }) {
    return UserProfile(
      id: id,
      accountType: accountType,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsApp: whatsApp ?? this.whatsApp,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      currentLevel: currentLevel ?? this.currentLevel,
      targetLevel: targetLevel ?? this.targetLevel,
      languageLevel: languageLevel ?? this.languageLevel,
      fieldIds: fieldIds ?? this.fieldIds,
      targetCountryIds: targetCountryIds ?? this.targetCountryIds,
      gradeRange: gradeRange ?? this.gradeRange,
      bacSeries: clearBacSeries ? null : (bacSeries ?? this.bacSeries),
      annualTuitionBudgetEur:
          annualTuitionBudgetEur ?? this.annualTuitionBudgetEur,
      monthlyBudgetEur: monthlyBudgetEur ?? this.monthlyBudgetEur,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      wantsScholarshipSupport:
          wantsScholarshipSupport ?? this.wantsScholarshipSupport,
      wantsScholarshipNewsletter:
          wantsScholarshipNewsletter ?? this.wantsScholarshipNewsletter,
      disabledNotificationTypes:
          disabledNotificationTypes ?? this.disabledNotificationTypes,
      availableDocuments: availableDocuments ?? this.availableDocuments,
      consentedAt: consentedAt ?? this.consentedAt,
      aiConsentedAt: aiConsentedAt ?? this.aiConsentedAt,
      birthDate: birthDate ?? this.birthDate,
      guardianName: guardianName ?? this.guardianName,
      guardianContact: guardianContact ?? this.guardianContact,
      guardianConsentedAt: guardianConsentedAt ?? this.guardianConsentedAt,
      hasAvatar: hasAvatar ?? this.hasAvatar,
    );
  }

  /// Ce que le score de complétion mesure, item par item.
  ///
  /// ## Pourquoi cette carte existe alors que le score suffisait
  ///
  /// Le score et la liste « ce qu'il te manque » sont la MÊME information vue
  /// de deux côtés, et tant qu'ils ont été calculés à deux endroits ils ont
  /// divergé. L'écran de profil énumérait cinq manques ; le score en comptait
  /// treize. Un étudiant à qui il ne manquait que le budget lisait donc
  /// « 92 % » au-dessus d'une carte vide : le score savait ce qui manquait, la
  /// liste ne savait pas le dire, et aucun des deux ne mentait tout seul.
  ///
  /// [completionScore] dérive maintenant d'ici. Ajouter un item au score sans
  /// lui donner de libellé devient impossible : la liste le réclamera.
  Map<ProfileCompletionItem, bool> get completionBreakdown => {
        ProfileCompletionItem.fullName: fullName.trim().isNotEmpty,
        ProfileCompletionItem.email: email.trim().isNotEmpty,
        ProfileCompletionItem.phone: phone.trim().isNotEmpty,
        ProfileCompletionItem.countryOfResidence:
            countryOfResidence.trim().isNotEmpty,
        ProfileCompletionItem.preferredLanguage:
            preferredLanguage.trim().isNotEmpty,
        ProfileCompletionItem.currentLevel:
            (currentLevel ?? '').trim().isNotEmpty,
        ProfileCompletionItem.targetLevel:
            (targetLevel ?? '').trim().isNotEmpty,
        ProfileCompletionItem.languageLevel:
            (languageLevel ?? '').trim().isNotEmpty,
        ProfileCompletionItem.fields: fieldIds.isNotEmpty,
        ProfileCompletionItem.targetCountries: targetCountryIds.isNotEmpty,
        ProfileCompletionItem.grade: (gradeRange ?? '').trim().isNotEmpty ||
            (bacSeries ?? '').trim().isNotEmpty,
        ProfileCompletionItem.budget:
            (annualTuitionBudgetEur ?? 0) > 0 || (monthlyBudgetEur ?? 0) > 0,
        ProfileCompletionItem.documents: availableDocuments.isNotEmpty,
      };

  /// Ce qui manque pour atteindre 100 %, dans l'ordre de [completionBreakdown].
  ///
  /// Vide si et seulement si [completionScore] vaut 1.0 — c'est la même source.
  List<ProfileCompletionItem> get missingCompletionItems =>
      completionBreakdown.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .toList(growable: false);

  double get completionScore {
    final items = completionBreakdown.values;
    final completed = items.where((item) => item).length;
    return completed / items.length;
  }
}

/// Les treize items qui composent [UserProfile.completionScore].
///
/// L'ordre est celui de l'affichage : identité d'abord (ce que l'étudiant sait
/// remplir sans réfléchir), projet ensuite, budget et pièces à la fin.
enum ProfileCompletionItem {
  fullName,
  email,
  phone,
  countryOfResidence,
  preferredLanguage,
  currentLevel,
  targetLevel,
  languageLevel,
  fields,
  targetCountries,
  grade,
  budget,
  documents,
}

/// Ce qu'un élève a déclaré de son âge avant de « Passer » l'onboarding V2 :
/// la date de naissance et, pour un mineur, l'accord du représentant légal.
///
/// [guardianConsented] ne vaut que si la case a été cochée ; le nom et le
/// contact du représentant ne voyagent qu'avec cet accord (tout ou rien, comme
/// l'étape tuteur de « Mes 10 bourses »).
class OnboardingAgeDeclaration {
  const OnboardingAgeDeclaration({
    required this.birthDate,
    this.guardianName,
    this.guardianContact,
    this.guardianConsented = false,
  });

  final DateTime? birthDate;
  final String? guardianName;
  final String? guardianContact;
  final bool guardianConsented;
}
