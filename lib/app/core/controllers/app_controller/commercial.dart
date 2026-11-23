part of '../app_controller.dart';

mixin _CommercialMixin on _AppControllerBase {
  List<CommercialLead> get commercialLeads =>
      List.unmodifiable(_commercialLeads);

  Future<void> fetchCommercialLeads({String filter = 'all'}) async {
    if (!isCommercial || !AppConfig.enableRemoteSync) return;
    final email = profile?.email;
    if (email == null || email.isEmpty) return;
    // Dedup the simultaneous startup fetch from the Leads + Conversations tabs.
    if (isLoadingCommercialLeads) return;

    isLoadingCommercialLeads = true;
    commercialLeadsError = null;
    update();

    // Les leads lus appartiennent au conseiller qui les a demandés : arrivés
    // après sa déconnexion, ils n'entrent pas dans l'état du compte suivant
    // (audit du 22/11/2026, n° 3).
    final generation = _sessionGeneration;
    try {
      final items = await _apiClient.listCommercialLeads(
        email: email,
        filter: filter,
      );
      if (_isStaleSession(generation)) return;
      _commercialLeads
        ..clear()
        ..addAll(items);
    } catch (e, s) {
      if (_isStaleSession(generation)) return;
      commercialLeadsError = userFacingSyncError(e, localeCode);
      safeRecordError(
        e,
        s,
        reason: 'fetchCommercialLeads',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_commercial_leads',
      );
    } finally {
      // Session périmée : la remise à zéro a déjà rendu le verrou, et un
      // chargement du conseiller suivant peut le tenir à présent.
      if (!_isStaleSession(generation)) isLoadingCommercialLeads = false;
      update();
    }
  }

  Future<void> updateCommercialLeadTag(
    String caseId, {
    required String leadTag,
    String? discussionMotive,
  }) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.updateCommercialLead(
        caseId,
        leadTag: leadTag,
        discussionMotive: discussionMotive,
      );
      await fetchCommercialLeads();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'updateCommercialLeadTag',
        domain: CrashlyticsObsDomain.sync,
        operation: 'update_commercial_lead',
      );
      rethrow;
    }
  }

  /// Records a counsellor verdict ('validated' | 'redo' | 'doubtful') on an
  /// uploaded case document (Feature D). Patches the in-memory lead so the
  /// Dossiers list stays consistent, and returns the updated document.
  Future<CommercialLeadDocument> reviewCommercialDocument(
    String caseId,
    String documentId, {
    required String status,
  }) async {
    final generation = _sessionGeneration;
    try {
      final data = await _apiClient.reviewCommercialDocument(
        documentId,
        status: status,
      );
      final updatedDoc = CommercialLeadDocument.fromApi(data);
      // Déconnexion pendant l'appel : la liste du compte parti est vidée,
      // on ne la réécrit pas.
      if (_isStaleSession(generation)) return updatedDoc;
      final idx = _commercialLeads.indexWhere((l) => l.id == caseId);
      if (idx != -1) {
        final lead = _commercialLeads[idx];
        final docs = lead.documents
            .map((d) => d.id == updatedDoc.id ? updatedDoc : d)
            .toList(growable: false);
        _commercialLeads[idx] = lead.copyWith(documents: docs);
        update();
      }
      return updatedDoc;
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'reviewCommercialDocument',
        domain: CrashlyticsObsDomain.sync,
        operation: 'review_commercial_document',
      );
      rethrow;
    }
  }

  Future<void> fetchCommercialStats() async {
    if (!isCommercial || !AppConfig.enableRemoteSync) return;
    final email = profile?.email;
    if (email == null || email.isEmpty) return;

    isLoadingCommercialStats = true;
    update();

    final generation = _sessionGeneration;
    try {
      final data = await _apiClient.getCommercialStats(email: email);
      // Statistiques du conseiller parti : pas affichées au compte suivant.
      if (_isStaleSession(generation)) return;
      commercialStats = CommercialStats.fromApi(data);
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'fetchCommercialStats',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_commercial_stats',
      );
    } finally {
      // Même règle que pour les leads : ne pas couper le chargement du
      // conseiller suivant.
      if (!_isStaleSession(generation)) isLoadingCommercialStats = false;
      update();
    }
  }
}
