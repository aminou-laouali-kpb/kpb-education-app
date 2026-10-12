part of '../app_api_client.dart';

/// Success Lab : espaces, diagnostic, relecture, dépôts, décisions.
mixin _SuccessLabApi on _ApiClientBase {
  // ── Success Lab / competition readiness ────────────────────────────────

  /// Effective server-owned access decision for the authenticated student.
  Future<Map<String, dynamic>> getSuccessLabAccess() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/access',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabWorkspaces({
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces',
      queryParameters: <String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Creates or returns the unique workspace for one scholarship cycle.
  /// Retrying with the same [idempotencyKey] is safe by backend contract.
  Future<Map<String, dynamic>> createSuccessLabWorkspace({
    required String scholarshipId,
    required String cycleId,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces',
      data: <String, dynamic>{
        'scholarshipId': scholarshipId,
        'cycleId': cycleId,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabWorkspace(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Applies one idempotent step transition. [clientMutationId] must remain
  /// unchanged across transport retries.
  Future<Map<String, dynamic>> updateSuccessLabWorkspaceStep({
    required String workspaceId,
    required String stepId,
    required String status,
    required String clientMutationId,
    required int expectedVersion,
    String? notApplicableReason,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/steps/'
      '${Uri.encodeComponent(stepId)}',
      data: <String, dynamic>{
        'status': status,
        'clientMutationId': clientMutationId,
        'expectedVersion': expectedVersion,
        if (notApplicableReason != null)
          'notApplicableReason': notApplicableReason,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateSuccessLabWorkspaceLifecycle({
    required String workspaceId,
    required String action,
    required int expectedVersion,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}',
      data: <String, dynamic>{
        'action': action,
        'expectedVersion': expectedVersion,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabAiNotice({
    required String language,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/consents/ai/notice',
      queryParameters: <String, dynamic>{'language': language},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> grantSuccessLabAiConsent({
    required String languageCode,
    required String noticeVersion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/consents/ai',
      data: <String, dynamic>{
        'languageCode': languageCode,
        'noticeVersion': noticeVersion,
        'accepted': true,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabDiagnostic(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/diagnostic',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabDiagnostic({
    required String workspaceId,
    required String language,
    required String idempotencyKey,
    String? applicationExcerpt,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/diagnostic',
      data: <String, dynamic>{
        'language': language,
        if (applicationExcerpt?.trim().isNotEmpty == true)
          'applicationExcerpt': applicationExcerpt!.trim(),
      },
      options: _aiOptions.copyWith(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabStudyReviewNotice({
    required String language,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/consents/study-review/notice',
      queryParameters: <String, dynamic>{'language': language},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> grantSuccessLabStudyReviewConsent({
    required String languageCode,
    required String noticeVersion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/consents/study-review',
      data: <String, dynamic>{
        'languageCode': languageCode,
        'noticeVersion': noticeVersion,
        'accepted': true,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabArtifacts(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/artifacts',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabArtifactUploadIntent({
    required String workspaceId,
    required String kind,
    required String title,
    required String originalFileName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/artifacts/upload-intents',
      data: <String, dynamic>{
        'kind': kind,
        'title': title,
        'originalFileName': originalFileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> completeSuccessLabArtifactUpload({
    required String versionId,
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/artifact-versions/'
      '${Uri.encodeComponent(versionId)}/complete',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteSuccessLabArtifactVersion({
    required String versionId,
    required String reason,
  }) async {
    await _dio.delete<void>(
      '/competition-readiness/artifact-versions/'
      '${Uri.encodeComponent(versionId)}',
      data: <String, dynamic>{'reason': reason},
    );
  }

  Future<Map<String, dynamic>> createSuccessLabStudyReview({
    required String workspaceId,
    required List<String> artifactVersionIds,
    required String consentReceiptId,
    required String idempotencyKey,
    String? studentMessage,
    String preferredContact = 'in_app',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/review-requests',
      data: <String, dynamic>{
        'artifactVersionIds': artifactVersionIds,
        'consentReceiptId': consentReceiptId,
        if (studentMessage?.trim().isNotEmpty == true)
          'studentMessage': studentMessage!.trim(),
        'preferredContact': preferredContact,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getActiveSuccessLabStudyReview(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/review-requests/active',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabStudyReview(
    String reviewRequestId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateSuccessLabStudyReview({
    required String reviewRequestId,
    required int expectedVersion,
    String? studentMessage,
    String? preferredContact,
    String? timezone,
    Map<String, Object?>? availability,
    List<String>? artifactVersionIds,
    String? consentReceiptId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}',
      data: <String, dynamic>{
        'expectedVersion': expectedVersion,
        if (studentMessage?.trim().isNotEmpty == true)
          'studentMessage': studentMessage!.trim(),
        if (preferredContact?.trim().isNotEmpty == true)
          'preferredContact': preferredContact!.trim(),
        if (timezone?.trim().isNotEmpty == true) 'timezone': timezone!.trim(),
        if (availability != null) 'availability': availability,
        if (artifactVersionIds?.isNotEmpty == true)
          'artifactVersionIds': artifactVersionIds,
        if (consentReceiptId?.trim().isNotEmpty == true)
          'consentReceiptId': consentReceiptId!.trim(),
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabStudyReviewSlotOffers(
    String reviewRequestId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}/slot-offers',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> bookSuccessLabStudyReviewAppointment({
    required String reviewRequestId,
    required int expectedVersion,
    required String slotOfferId,
    required String bookingKey,
    required String timezone,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}/appointments',
      data: <String, dynamic>{
        'expectedVersion': expectedVersion,
        'slotOfferId': slotOfferId,
        'bookingKey': bookingKey,
        'timezone': timezone,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabSubmissions(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/submissions',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabDecisions(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/decisions',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabOutcomeConsentNotice({
    required String workspaceId,
    required String language,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/consents/outcome-evidence/notice',
      queryParameters: <String, dynamic>{'language': language},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> grantSuccessLabOutcomeConsent({
    required String workspaceId,
    required String languageCode,
    required String noticeVersion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/consents',
      data: <String, dynamic>{
        'purpose': 'outcome_evidence',
        'languageCode': languageCode,
        'noticeVersion': noticeVersion,
        'accepted': true,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabOutcomeEvidenceUploadIntent({
    required String workspaceId,
    required String kind,
    required String originalFileName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required String consentReceiptId,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/outcome-evidence/upload-intents',
      data: <String, dynamic>{
        'kind': kind,
        'originalFileName': originalFileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'consentReceiptId': consentReceiptId,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> completeSuccessLabOutcomeEvidenceUpload({
    required String evidenceId,
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/outcome-evidence/'
      '${Uri.encodeComponent(evidenceId)}/complete',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabSubmission({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required DateTime submittedAt,
    required String idempotencyKey,
    String? submissionChannel,
    String? applicationReference,
    String? evidenceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/submissions',
      data: <String, dynamic>{
        'expectedWorkspaceVersion': expectedWorkspaceVersion,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
        if (submissionChannel?.trim().isNotEmpty == true)
          'submissionChannel': submissionChannel!.trim(),
        if (applicationReference?.trim().isNotEmpty == true)
          'applicationReference': applicationReference!.trim(),
        if (evidenceId?.trim().isNotEmpty == true)
          'evidenceId': evidenceId!.trim(),
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabAdmissionDecision({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required String issuedByName,
    required String admissionDecision,
    required DateTime receivedAt,
    required String idempotencyKey,
    DateTime? issuedAt,
    String? evidenceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/admission-decisions',
      data: <String, dynamic>{
        'expectedWorkspaceVersion': expectedWorkspaceVersion,
        'issuedByName': issuedByName.trim(),
        'admissionDecision': admissionDecision,
        'receivedAt': receivedAt.toUtc().toIso8601String(),
        if (issuedAt != null) 'issuedAt': issuedAt.toUtc().toIso8601String(),
        if (evidenceId?.trim().isNotEmpty == true)
          'evidenceId': evidenceId!.trim(),
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabFundingDecision({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required String issuedByName,
    required String fundingDecision,
    required DateTime receivedAt,
    required String idempotencyKey,
    DateTime? issuedAt,
    String? evidenceId,
    String? admissionDecisionId,
    String? fundingAmountMinor,
    String? fundingCurrency,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/funding-decisions',
      data: <String, dynamic>{
        'expectedWorkspaceVersion': expectedWorkspaceVersion,
        'issuedByName': issuedByName.trim(),
        'fundingDecision': fundingDecision,
        'receivedAt': receivedAt.toUtc().toIso8601String(),
        if (issuedAt != null) 'issuedAt': issuedAt.toUtc().toIso8601String(),
        if (evidenceId?.trim().isNotEmpty == true)
          'evidenceId': evidenceId!.trim(),
        if (admissionDecisionId?.trim().isNotEmpty == true)
          'admissionDecisionId': admissionDecisionId!.trim(),
        if (fundingAmountMinor != null)
          'fundingAmountMinor': fundingAmountMinor,
        if (fundingCurrency?.trim().isNotEmpty == true)
          'fundingCurrency': fundingCurrency!.trim().toUpperCase(),
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> attachSuccessLabOutcomeEvidence({
    required String outcomeType,
    required String outcomeId,
    required int expectedVersion,
    required String evidenceId,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/outcomes/'
      '${Uri.encodeComponent(outcomeType)}/'
      '${Uri.encodeComponent(outcomeId)}/evidence',
      data: <String, dynamic>{
        'expectedVersion': expectedVersion,
        'evidenceId': evidenceId,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }
}
