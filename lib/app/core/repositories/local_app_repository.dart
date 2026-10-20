import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/notification_opt_out.dart';
import '../models/app_models.dart';
import 'app_repository.dart';
import 'app_snapshot.dart';
import 'app_snapshot_format.dart';

class LocalAppRepository implements AppRepository {
  LocalAppRepository._(this._preferences);

  final SharedPreferences _preferences;

  static Future<LocalAppRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalAppRepository._(preferences);
  }

  String get _storageKey => '${AppConfig.storageNamespace}.snapshot';

  @override
  Future<AppSnapshot> loadSnapshot() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return AppSnapshot.initial();
    }
    try {
      return _decodeSnapshot(raw);
    } catch (_) {
      // Un instantané illisible (JSON tronqué, champ d'un type inattendu)
      // faisait échouer le démarrage À CHAQUE lancement (BootstrapErrorApp),
      // sans autre issue que réinstaller. On repart d'un état vierge en
      // gardant une copie pour diagnostic ; le serveur restaure le reste.
      await _preferences.setString('$_storageKey.corrupt', raw);
      await _preferences.remove(_storageKey);
      return AppSnapshot.initial();
    }
  }

  AppSnapshot _decodeSnapshot(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      return AppSnapshot.initial();
    }

    migrateAppSnapshotJson(json);

    return AppSnapshot(
      localeCode: json['localeCode'] as String? ?? 'fr',
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      hasSeenIntro: json['hasSeenIntro'] as bool? ?? false,
      isGuestMode: json['isGuestMode'] as bool? ?? false,
      isAppLockEnabled: json['isAppLockEnabled'] as bool? ?? false,
      dataSaverEnabled: json['dataSaverEnabled'] as bool? ?? false,
      analyticsOptOut: json['analyticsOptOut'] as bool? ?? true,
      analyticsConsentDecided:
          json['analyticsConsentDecided'] as bool? ?? false,
      themeMode: _themeModeFromString(json['themeMode'] as String?),
      profile: _userProfileFromJson(json['profile'] as Map<String, dynamic>?),
      savedItems: ((json['savedItems'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_savedItemFromJson)
          .toList(),
      savedItemTombstones: ((json['savedItemTombstones'] as List<dynamic>?)
              ?.whereType<String>()
              .toSet()) ??
          const {},
      cases: ((json['cases'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_caseFromJson)
          .toList(),
      orientationHistory:
          ((json['orientationHistory'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_orientationSessionFromJson)
              .toList(),
      searchHistory: _stringList(json['searchHistory']),
      pendingOrientationAnswers:
          _stringListMap(json['pendingOrientationAnswers']),
      fields: const [],
      countries: const [],
      institutions: const [],
      programs: const [],
      scholarships: const [],
      pendingOrientationQuestionIndex:
          json['pendingOrientationQuestionIndex'] as int? ?? 0,
      purchasedCourseIds: _stringList(json['purchasedCourseIds']),
      reviewCredits: (json['reviewCredits'] as num?)?.toInt() ?? 0,
      completedRoadmapSteps: _stringListMap(json['completedRoadmapSteps']),
      profileNeedsPush: json['profileNeedsPush'] as bool? ?? false,
      pendingConsentKeys: _stringList(json['pendingConsentKeys']).toSet(),
      onboardingStep: json['onboardingStep'] as int? ?? 0,
      onboardingSkipped: json['onboardingSkipped'] as bool? ?? false,
      caseLastReadAt: _stringMap(json['caseLastReadAt']),
      reviewedCaseIds: _stringList(json['reviewedCaseIds']),
    );
  }

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    final json = <String, dynamic>{
      'snapshotFormatVersion': kAppSnapshotFormatVersion,
      'localeCode': snapshot.localeCode,
      'hasCompletedOnboarding': snapshot.hasCompletedOnboarding,
      'hasSeenIntro': snapshot.hasSeenIntro,
      'isGuestMode': snapshot.isGuestMode,
      'isAppLockEnabled': snapshot.isAppLockEnabled,
      'dataSaverEnabled': snapshot.dataSaverEnabled,
      'analyticsOptOut': snapshot.analyticsOptOut,
      'analyticsConsentDecided': snapshot.analyticsConsentDecided,
      'themeMode': snapshot.themeMode.name,
      'profile': _userProfileToJson(snapshot.profile),
      'savedItems': snapshot.savedItems.map(_savedItemToJson).toList(),
      'savedItemTombstones': snapshot.savedItemTombstones.toList(),
      'cases': snapshot.cases.map(_caseToJson).toList(),
      'orientationHistory':
          snapshot.orientationHistory.map(_orientationSessionToJson).toList(),
      'searchHistory': snapshot.searchHistory,
      'pendingOrientationAnswers': snapshot.pendingOrientationAnswers,
      'fields': const [],
      'countries': const [],
      'institutions': const [],
      'programs': const [],
      'scholarships': const [],
      'pendingOrientationQuestionIndex':
          snapshot.pendingOrientationQuestionIndex,
      'purchasedCourseIds': snapshot.purchasedCourseIds,
      'reviewCredits': snapshot.reviewCredits,
      'completedRoadmapSteps': snapshot.completedRoadmapSteps,
      'profileNeedsPush': snapshot.profileNeedsPush,
      'pendingConsentKeys': snapshot.pendingConsentKeys.toList(),
      'onboardingStep': snapshot.onboardingStep,
      'onboardingSkipped': snapshot.onboardingSkipped,
      'caseLastReadAt': snapshot.caseLastReadAt,
      'reviewedCaseIds': snapshot.reviewedCaseIds,
    };
    await _preferences.setString(_storageKey, jsonEncode(json));
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_storageKey);
  }

  Map<String, dynamic>? _userProfileToJson(UserProfile? profile) {
    if (profile == null) return null;
    // GDPR: Do NOT persist email, phone, or whatsApp to SharedPreferences.
    // These sensitive fields are loaded from the API on each sync cycle.
    return <String, dynamic>{
      'id': profile.id,
      'accountType': profile.accountType.name,
      'fullName': profile.fullName,
      'countryOfResidence': profile.countryOfResidence,
      'preferredLanguage': profile.preferredLanguage,
      'currentLevel': profile.currentLevel,
      'targetLevel': profile.targetLevel,
      'languageLevel': profile.languageLevel,
      'fieldIds': profile.fieldIds,
      'targetCountryIds': profile.targetCountryIds,
      'gradeRange': profile.gradeRange,
      'bacSeries': profile.bacSeries,
      'annualTuitionBudgetEur': profile.annualTuitionBudgetEur,
      'monthlyBudgetEur': profile.monthlyBudgetEur,
      'preferredCurrency': profile.preferredCurrency,
      'wantsScholarshipSupport': profile.wantsScholarshipSupport,
      'wantsScholarshipNewsletter': profile.wantsScholarshipNewsletter,
      'promotionsEmailOptIn': profile.promotionsEmailOptIn,
      'promotionsPushOptIn': profile.promotionsPushOptIn,
      'disabledNotificationTypes': profile.disabledNotificationTypes,
      'availableDocuments': profile.availableDocuments,
      // Consent timestamps + age gate must survive a cold start so we don't
      // re-prompt. Guardian *contact* is PII (like the user's own contact
      // above) — it is reloaded from the API, not persisted locally.
      'consentedAt': profile.consentedAt?.toIso8601String(),
      'aiConsentedAt': profile.aiConsentedAt?.toIso8601String(),
      'birthDate': profile.birthDate?.toIso8601String(),
      'guardianName': profile.guardianName,
      'guardianConsentedAt': profile.guardianConsentedAt?.toIso8601String(),
    };
  }

  UserProfile? _userProfileFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return UserProfile(
      id: json['id'] as String? ?? 'local-profile',
      accountType: _parseAccountType(json['accountType'] as String?) ??
          AccountType.student,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsApp: json['whatsApp'] as String? ?? '',
      countryOfResidence: json['countryOfResidence'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? 'fr',
      currentLevel: json['currentLevel'] as String?,
      targetLevel: json['targetLevel'] as String?,
      languageLevel: json['languageLevel'] as String?,
      fieldIds: _stringList(json['fieldIds']),
      targetCountryIds: _stringList(json['targetCountryIds']),
      gradeRange: json['gradeRange'] as String?,
      bacSeries: json['bacSeries'] as String? ?? json['gradeRange'] as String?,
      annualTuitionBudgetEur: json['annualTuitionBudgetEur'] as int? ??
          ((json['monthlyBudgetEur'] as int?) != null
              ? (json['monthlyBudgetEur'] as int) * 12
              : null),
      monthlyBudgetEur: json['monthlyBudgetEur'] as int?,
      preferredCurrency: json['preferredCurrency'] as String? ?? 'XOF',
      wantsScholarshipSupport:
          json['wantsScholarshipSupport'] as bool? ?? false,
      wantsScholarshipNewsletter:
          json['wantsScholarshipNewsletter'] as bool? ?? false,
      promotionsEmailOptIn: json['promotionsEmailOptIn'] as bool?,
      promotionsPushOptIn: json['promotionsPushOptIn'] as bool?,
      // A snapshot written before KPB-169 carries the two booleans instead of
      // the list; read either shape so a cold start never loses a preference.
      disabledNotificationTypes: _optOutTypesFromSnapshot(json),
      availableDocuments: _stringList(json['availableDocuments']),
      consentedAt: DateTime.tryParse(json['consentedAt'] as String? ?? ''),
      aiConsentedAt: DateTime.tryParse(json['aiConsentedAt'] as String? ?? ''),
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      guardianName: json['guardianName'] as String?,
      guardianConsentedAt:
          DateTime.tryParse(json['guardianConsentedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> _savedItemToJson(SavedItem item) {
    return <String, dynamic>{
      'type': item.type.name,
      'itemId': item.itemId,
    };
  }

  SavedItem _savedItemFromJson(Map<String, dynamic> json) {
    return SavedItem(
      type: _parseSavedItemType(json['type'] as String?) ?? SavedItemType.field,
      itemId: json['itemId'] as String? ?? '',
    );
  }

  Map<String, dynamic> _localizedTextToJson(LocalizedText text) {
    return <String, dynamic>{
      'fr': text.fr,
      'en': text.en,
    };
  }

  LocalizedText _localizedTextFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LocalizedText(fr: '', en: '');
    }
    return LocalizedText(
      fr: json['fr'] as String? ?? '',
      en: json['en'] as String? ?? '',
    );
  }

  Map<String, dynamic> _timelineEventToJson(CaseTimelineEvent event) {
    return <String, dynamic>{
      'id': event.id,
      'title': _localizedTextToJson(event.title),
      'description': _localizedTextToJson(event.description),
      'createdAt': event.createdAt.toIso8601String(),
      'status': event.status.name,
    };
  }

  CaseTimelineEvent _timelineEventFromJson(Map<String, dynamic> json) {
    return CaseTimelineEvent(
      id: json['id'] as String? ?? '',
      title: _localizedTextFromJson(json['title'] as Map<String, dynamic>?),
      description:
          _localizedTextFromJson(json['description'] as Map<String, dynamic>?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status:
          _parseCaseStatus(json['status'] as String?) ?? CaseStatus.submitted,
    );
  }

  Map<String, dynamic> _caseMessageToJson(CaseMessage message) {
    return <String, dynamic>{
      'id': message.id,
      'senderName': message.senderName,
      'senderRole': message.senderRole,
      'body': _localizedTextToJson(message.body),
      'createdAt': message.createdAt.toIso8601String(),
    };
  }

  CaseMessage _caseMessageFromJson(Map<String, dynamic> json) {
    return CaseMessage(
      id: json['id'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? 'system',
      body: _localizedTextFromJson(json['body'] as Map<String, dynamic>?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> _documentRequestToJson(DocumentRequest request) {
    return <String, dynamic>{
      'id': request.id,
      'title': _localizedTextToJson(request.title),
      'isProvided': request.isProvided,
    };
  }

  DocumentRequest _documentRequestFromJson(Map<String, dynamic> json) {
    return DocumentRequest(
      id: json['id'] as String? ?? '',
      title: _localizedTextFromJson(json['title'] as Map<String, dynamic>?),
      isProvided: json['isProvided'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _caseToJson(StudentCase caseItem) {
    return <String, dynamic>{
      'id': caseItem.id,
      'referenceCode': caseItem.referenceCode,
      'type': caseItem.type.name,
      'title': _localizedTextToJson(caseItem.title),
      'description': _localizedTextToJson(caseItem.description),
      'contextLabel': _localizedTextToJson(caseItem.contextLabel),
      'status': caseItem.status.name,
      'preferredContactMethod': caseItem.preferredContactMethod.name,
      'createdAt': caseItem.createdAt.toIso8601String(),
      'updatedAt': caseItem.updatedAt.toIso8601String(),
      'nextStepTitle': _localizedTextToJson(caseItem.nextStepTitle),
      'nextStepDescription': _localizedTextToJson(caseItem.nextStepDescription),
      'timeline': caseItem.timeline.map(_timelineEventToJson).toList(),
      'messages': caseItem.messages.map(_caseMessageToJson).toList(),
      'documentRequests':
          caseItem.documentRequests.map(_documentRequestToJson).toList(),
      'assignedAdvisorName': caseItem.assignedAdvisorName,
      'counsellorId': caseItem.counsellorId,
      'scheduledAt': caseItem.scheduledAt?.toIso8601String(),
      'parentCanView': caseItem.parentCanView,
      if (caseItem.scholarshipId != null)
        'scholarshipId': caseItem.scholarshipId,
    };
  }

  StudentCase _caseFromJson(Map<String, dynamic> json) {
    return StudentCase(
      id: json['id'] as String? ?? '',
      referenceCode: json['referenceCode'] as String? ?? '',
      type: _parseCaseType(json['type'] as String?) ?? CaseType.consultation,
      title: _localizedTextFromJson(json['title'] as Map<String, dynamic>?),
      description:
          _localizedTextFromJson(json['description'] as Map<String, dynamic>?),
      contextLabel:
          _localizedTextFromJson(json['contextLabel'] as Map<String, dynamic>?),
      status:
          _parseCaseStatus(json['status'] as String?) ?? CaseStatus.submitted,
      preferredContactMethod: _parseContactMethod(
            json['preferredContactMethod'] as String?,
          ) ??
          ContactMethod.inApp,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      nextStepTitle: _localizedTextFromJson(
          json['nextStepTitle'] as Map<String, dynamic>?),
      nextStepDescription: _localizedTextFromJson(
        json['nextStepDescription'] as Map<String, dynamic>?,
      ),
      timeline: ((json['timeline'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_timelineEventFromJson)
          .toList(),
      messages: ((json['messages'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_caseMessageFromJson)
          .toList(),
      documentRequests:
          ((json['documentRequests'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_documentRequestFromJson)
              .toList(),
      assignedAdvisorName: json['assignedAdvisorName'] as String?,
      counsellorId: json['counsellorId'] as String?,
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
      parentCanView: json['parentCanView'] as bool? ?? false,
      scholarshipId: _optionalId(json['scholarshipId']),
    );
  }

  static String? _optionalId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> _orientationRecommendationToJson(
    OrientationRecommendation recommendation,
  ) {
    return <String, dynamic>{
      'fieldId': recommendation.fieldId,
      'score': recommendation.score,
      'explanation': _localizedTextToJson(recommendation.explanation),
      'relatedCountryIds': recommendation.relatedCountryIds,
      'relatedScholarshipIds': recommendation.relatedScholarshipIds,
      'jobs': recommendation.jobs,
      'iaResilience': recommendation.iaResilience,
    };
  }

  OrientationRecommendation _orientationRecommendationFromJson(
    Map<String, dynamic> json,
  ) {
    return OrientationRecommendation(
      fieldId: json['fieldId'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      explanation:
          _localizedTextFromJson(json['explanation'] as Map<String, dynamic>?),
      relatedCountryIds: _stringList(json['relatedCountryIds']),
      relatedScholarshipIds: _stringList(json['relatedScholarshipIds']),
      jobs: _stringList(json['jobs']),
      iaResilience: json['iaResilience'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> _orientationSessionToJson(OrientationSession session) {
    return <String, dynamic>{
      'id': session.id,
      'completedAt': session.completedAt.toIso8601String(),
      'answers': session.answers.map(
        (key, value) => MapEntry(key, value),
      ),
      'recommendations': session.recommendations
          .map(_orientationRecommendationToJson)
          .toList(),
    };
  }

  OrientationSession _orientationSessionFromJson(Map<String, dynamic> json) {
    final answersRaw = json['answers'] as Map<String, dynamic>? ?? {};
    return OrientationSession(
      id: json['id'] as String? ?? '',
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      answers: answersRaw.map(
        (key, value) => MapEntry(key, _stringList(value)),
      ),
      recommendations:
          ((json['recommendations'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(_orientationRecommendationFromJson)
              .toList(),
    );
  }

  List<String> _stringList(Object? raw) {
    if (raw is List<dynamic>) {
      return raw.whereType<String>().toList();
    }
    return const <String>[];
  }

  Map<String, List<String>> _stringListMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw.map(
        (key, value) => MapEntry(key, _stringList(value)),
      );
    }
    return const <String, List<String>>{};
  }

  Map<String, String> _stringMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    }
    return const <String, String>{};
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  AccountType? _parseAccountType(String? value) {
    return _firstWhereOrNull(
      AccountType.values,
      (item) => item.name == value,
    );
  }

  SavedItemType? _parseSavedItemType(String? value) {
    return _firstWhereOrNull(
      SavedItemType.values,
      (item) => item.name == value,
    );
  }

  CaseType? _parseCaseType(String? value) {
    return _firstWhereOrNull(
      CaseType.values,
      (item) => item.name == value,
    );
  }

  CaseStatus? _parseCaseStatus(String? value) {
    return _firstWhereOrNull(
      CaseStatus.values,
      (item) => item.name == value,
    );
  }

  ContactMethod? _parseContactMethod(String? value) {
    return _firstWhereOrNull(
      ContactMethod.values,
      (item) => item.name == value,
    );
  }

  T? _firstWhereOrNull<T>(
    Iterable<T> values,
    bool Function(T item) predicate,
  ) {
    for (final value in values) {
      if (predicate(value)) return value;
    }
    return null;
  }

  /// Reads either shape: the KPB-169 list, or the two booleans a snapshot
  /// written by an earlier build carries. A cold start must never silently
  /// re-enable a notification family the student turned off.
  static List<String> _optOutTypesFromSnapshot(Map<String, dynamic> json) {
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
