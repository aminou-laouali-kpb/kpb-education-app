part of '../app_api_client.dart';

/// Dossiers, messages, documents, rendez-vous, favoris, liens parent.
mixin _CasesApi on _ApiClientBase {
  Future<List<dynamic>> listCases() async {
    final response = await _dio.get<List<dynamic>>('/cases');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> getCase(String caseId) async {
    final response = await _dio.get<Map<String, dynamic>>('/cases/$caseId');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listCaseMessages(String caseId) async {
    final response = await _dio.get<List<dynamic>>('/cases/$caseId/messages');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createCaseMessage(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/messages',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadCaseDocument(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/documents',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Multipart upload to `/cases/:id/documents/upload`. The file should
  /// already be compressed client-side via [DocumentUploadService] before
  /// calling this — students pay by the megabyte.
  Future<Map<String, dynamic>> uploadCaseDocumentFile({
    required String caseId,
    required String filePath,
    required String title,
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap(<String, dynamic>{
      'title': title,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/documents/upload',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const {'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listAppointments() async {
    final response = await _dio.get<List<dynamic>>('/appointments');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/appointments',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listSavedItems() async {
    final response = await _dio.get<List<dynamic>>('/saved-items');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createSavedItem(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/saved-items',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteSavedItem(String savedItemId) async {
    await _dio.delete<void>('/saved-items/$savedItemId');
  }

  Future<Map<String, dynamic>> createPartnerLead(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/partner-leads',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Parent links (Track C1) ───────────────────────────────────────────────

  Future<Map<String, dynamic>> createParentInvite() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/parent-links/invites',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> acceptParentInvite(String inviteCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/parent-links/accept',
      data: {'inviteCode': inviteCode},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listParentChildren() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/children',
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listParentVisibleCases() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/cases',
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getParentVisibleCase(String caseId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/cases/$caseId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setCaseParentVisibility({
    required String caseId,
    required bool parentCanView,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/parent-links/cases/$caseId/visibility',
      data: {'parentCanView': parentCanView},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Payments ──────────────────────────────────────────────────────────────
  // Intentionally not called from the app. Our (largely African) audience
  // settles fees directly with a KPB advisor over WhatsApp rather than through
  // an in-app checkout. The backend `payments` module + endpoints remain for
  // admin/manual reconciliation; the client just no longer initiates them.
}
