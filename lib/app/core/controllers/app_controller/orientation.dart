part of '../app_controller.dart';

/// Test d’orientation : soumission et progression sauvegardée.
mixin _OrientationMixin on _AppControllerBase {
  Future<OrientationSession> submitOrientation(
    Map<String, List<String>> answers,
  ) async {
    final activeProfile = profile;
    if (activeProfile == null) {
      throw StateError('Profile must exist before starting orientation.');
    }

    isSubmittingOrientation = true;
    update();

    OrientationSession session;
    try {
      if (AppConfig.enableRemoteSync) {
        final response = await _apiClient.submitOrientation(<String, dynamic>{
          'answers': answers,
          'profile': <String, dynamic>{
            'fullName': activeProfile.fullName,
            'currentLevel': activeProfile.currentLevel,
            'targetCountryIds': activeProfile.targetCountryIds,
            'fieldIds': activeProfile.fieldIds,
            'preferredLanguage': activeProfile.preferredLanguage,
          },
        });
        session = _orientationSessionFromApi(response, answers);
      } else {
        session = OrientationEngine.evaluate(
          profile: activeProfile,
          answers: answers,
          questions: orientationQuestions,
          fields: fields,
          scholarships: scholarships,
        );
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'submitOrientation',
        domain: CrashlyticsObsDomain.sync,
        operation: 'submit_orientation',
      );
      session = OrientationEngine.evaluate(
        profile: activeProfile,
        answers: answers,
        questions: orientationQuestions,
        fields: fields,
        scholarships: scholarships,
      );
    } finally {
      isSubmittingOrientation = false;
    }

    latestOrientationSession = session;
    _orientationHistory.insert(0, session);

    if (session.recommendations.isNotEmpty) {
      final enrichedFieldIds = <String>{
        ...activeProfile.fieldIds,
        ...session.recommendations.map((item) => item.fieldId),
      }.toList();
      profile = activeProfile.copyWith(fieldIds: enrichedFieldIds);
    }

    clearOrientationProgress();
    _persist();
    update();
    unawaited(HapticFeedback.heavyImpact());
    unawaited(AnalyticsService.instance.logOrientationComplete(
      totalQuestions: orientationQuestions.length,
      matchCount: session.recommendations.length,
    ));
    return session;
  }

  OrientationSession _orientationSessionFromApi(
    Map<String, dynamic> json,
    Map<String, List<String>> answers,
  ) {
    final locale = profile?.preferredLanguage ?? localeCode;
    final recommendations = (json['recommendations'] as List<dynamic>? ?? [])
        .map((item) {
          final map = item as Map<String, dynamic>;
          final explanation = map['explanation'];
          final jobsPayload = map['jobs'];
          final jobs = <String>[];
          if (jobsPayload is Map<String, dynamic>) {
            final localized = (locale.startsWith('en')
                ? jobsPayload['en']
                : jobsPayload['fr']) as List<dynamic>?;
            jobs.addAll(localized?.cast<String>() ?? const []);
          }
          final partnerCountries =
              (map['partnerCountryIds'] as List<dynamic>? ?? const [])
                  .cast<String>();
          return OrientationRecommendation(
            fieldId: map['fieldId'] as String? ?? '',
            score: map['score'] as int? ?? 55,
            explanation: explanation is Map<String, dynamic>
                ? LocalizedText(
                    fr: explanation['fr'] as String? ?? '',
                    en: explanation['en'] as String? ?? '',
                  )
                : const LocalizedText(fr: '', en: ''),
            relatedCountryIds: partnerCountries,
            relatedScholarshipIds: scholarships
                .where(
                  (s) => s.relatedFieldIds.contains(map['fieldId']),
                )
                .map((s) => s.id)
                .take(3)
                .toList(),
            jobs: jobs,
            iaResilience: map['iaResilience'] as String? ?? 'medium',
          );
        })
        .where((item) => item.fieldId.isNotEmpty)
        .toList();

    return OrientationSession(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
      answers: answers,
      recommendations: recommendations,
    );
  }

  void saveOrientationProgress(
    Map<String, List<String>> answers,
    int questionIndex,
  ) {
    _pendingOrientationAnswers = Map.of(answers);
    pendingOrientationQuestionIndex = questionIndex;
    _persist();
  }

  void clearOrientationProgress() {
    _pendingOrientationAnswers = {};
    pendingOrientationQuestionIndex = 0;
    _persist();
  }
}
