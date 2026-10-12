part of '../app_api_client.dart';

/// Surface commerciale : leads, documents, statistiques.
mixin _CommercialApi on _ApiClientBase {
  // ── Commercial (M9) ───────────────────────────────────────────

  Future<List<CommercialLead>> listCommercialLeads({
    required String email,
    String filter = 'all',
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/commercial/leads',
      queryParameters: {'email': email, 'filter': filter},
    );
    final items = response.data ?? const [];
    return items
        .map((item) => CommercialLead.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> updateCommercialLead(
    String caseId, {
    String? leadTag,
    String? discussionMotive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/commercial/leads/$caseId',
      data: {
        if (leadTag != null) 'leadTag': leadTag,
        if (discussionMotive != null) 'discussionMotive': discussionMotive,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Records a counsellor's verdict on an uploaded case document.
  /// [status] must be 'validated', 'redo' or 'doubtful'. Returns the updated
  /// document payload (id, reviewStatus, reviewedByName, reviewedAt, …).
  Future<Map<String, dynamic>> reviewCommercialDocument(
    String documentId, {
    required String status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/commercial/documents/$documentId/review',
      data: {'status': status},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getCommercialStats({
    required String email,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/commercial/stats',
      queryParameters: {'email': email},
    );
    return response.data ?? <String, dynamic>{};
  }
}
