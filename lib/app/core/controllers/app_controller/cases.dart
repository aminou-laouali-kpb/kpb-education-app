part of '../app_controller.dart';

/// Dossiers : création, messagerie (socket + file d’envoi), documents.
mixin _CasesMixin on _AppControllerBase {
  StudentCase submitCase({
    required CaseType type,
    required String title,
    required String description,
    required String contextLabel,
    required ContactMethod contactMethod,
  }) {
    if (!hasCompletedOnboarding || profile == null) {
      throw StateError(
        'Onboarding must be completed before creating a transactional case.',
      );
    }

    final now = DateTime.now();
    final referenceId = (_cases.length + 1).toString().padLeft(3, '0');
    final created = StudentCase(
      id: '$_localCaseIdPrefix${now.millisecondsSinceEpoch}',
      referenceCode: 'KPB-${now.year}-$referenceId',
      type: type,
      title: LocalizedText(fr: title, en: title),
      description: LocalizedText(fr: description, en: description),
      contextLabel: LocalizedText(fr: contextLabel, en: contextLabel),
      status: CaseStatus.submitted,
      preferredContactMethod: contactMethod,
      createdAt: now,
      updatedAt: now,
      nextStepTitle: const LocalizedText(
        fr: 'Votre dossier est en revue',
        en: 'Your case is under review',
      ),
      nextStepDescription: const LocalizedText(
        fr: 'L’équipe KPB va qualifier votre demande, vérifier vos informations et vous attribuer un conseiller.',
        en: 'The KPB team will review your request, verify your information, and assign a counselor.',
      ),
      timeline: [
        CaseTimelineEvent(
          id: 'submitted-${now.millisecondsSinceEpoch}',
          title: const LocalizedText(
              fr: 'Demande envoyée', en: 'Request submitted'),
          description: const LocalizedText(
            fr: 'Votre demande est visible dans My Cases et a été transmise à l’équipe KPB.',
            en: 'Your request now appears in My Cases and has been sent to the KPB team.',
          ),
          createdAt: now,
          status: CaseStatus.submitted,
        ),
      ],
      messages: [
        CaseMessage(
          id: 'welcome-${now.millisecondsSinceEpoch}',
          senderName: 'KPB Operations',
          senderRole: 'system',
          body: const LocalizedText(
            fr: 'Merci pour votre demande. Nous revenons vers vous avec la prochaine étape.',
            en: 'Thanks for your request. We will come back to you with the next step.',
          ),
          createdAt: now,
        ),
      ],
      // Cette demande de document est FABRIQUÉE par le client : aucun
      // conseiller ne l'a formulée, elle naît à la création du dossier. Tant que
      // l'envoi en app est masqué (M2), la produire créerait une impasse à deux
      // endroits — un jalon « document manquant » dans le calendrier
      // d'échéances et un bloc « Documents » bloqué à 0 % dans « Mon plan » —
      // pour une action que l'app n'offre plus. Demander un document qu'on ne
      // sait pas recevoir, c'est le motif que ce lot est censé supprimer.
      //
      // Les demandes VENUES DU SERVEUR, elles, continuent d'arriver et de
      // s'afficher : celles-là, un conseiller les a réellement formulées, et les
      // masquer serait le mensonge inverse. L'écran de dossier leur offre
      // désormais l'envoi par WhatsApp.
      documentRequests: AppConfig.documentUploadEnabled
          ? const [
              DocumentRequest(
                id: 'doc-profile',
                title: LocalizedText(
                  fr: 'Profil académique complet',
                  en: 'Complete academic profile',
                ),
                isProvided: false,
              ),
            ]
          : const <DocumentRequest>[],
    );
    _cases.insert(0, created);
    _persist();
    update();
    KpbHaptics.success();
    AnalyticsService.instance.logCaseCreated(caseType: type.name);
    KpbToast.success(
      'case_created_body'.trParams({'code': created.referenceCode}),
      title: 'case_created_title'.tr,
      duration: const Duration(seconds: 4),
      action: KpbToastAction(
        label: 'view'.tr,
        onPressed: () {
          shellIndex = StudentShellTab.cases;
          update();
        },
      ),
    );
    unawaited(_createRemoteCase(created));
    return created;
  }

  /// Toggle whether a linked parent can view a given case. Optimistically flips
  /// the local flag (so the switch reacts instantly) then persists to the
  /// backend; reverts and surfaces an error if the call fails. This is what
  /// makes a linked parent actually able to see the case — `parentCanView`
  /// defaults to false server-side.
  Future<void> setCaseParentVisibility(String caseId, bool canView) async {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0) return;
    final previous = _cases[index];
    if (previous.parentCanView == canView) return;

    _cases[index] = previous.copyWith(parentCanView: canView);
    _persist();
    update();

    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.setCaseParentVisibility(
        caseId: caseId,
        parentCanView: canView,
      );
    } catch (e, s) {
      // Revert the optimistic flip so the UI reflects the real backend state.
      final i = _cases.indexWhere((item) => item.id == caseId);
      if (i >= 0) {
        _cases[i] = _cases[i].copyWith(parentCanView: previous.parentCanView);
        _persist();
        update();
      }
      safeRecordError(
        e,
        s,
        reason: 'setCaseParentVisibility',
        domain: CrashlyticsObsDomain.cases,
        operation: 'set_parent_visibility',
      );
      KpbToast.error('parent_visibility_error'.tr);
    }
  }

  void addCaseMessage(String caseId, String text) {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0 || text.trim().isEmpty) return;
    final caseItem = _cases[index];
    final now = DateTime.now();
    final updatedMessages = [
      ...caseItem.messages,
      CaseMessage(
        id: 'user-${now.millisecondsSinceEpoch}',
        senderName: profile?.fullName ?? 'Student',
        senderRole: 'student',
        body: LocalizedText(fr: text, en: text),
        createdAt: now,
      ),
    ];
    // Le statut ne change PAS localement : passer à « En attente de ta
    // réponse » juste après la réponse de l'étudiant affichait une action
    // urgente à faire sur l'accueil. Le serveur reste maître du statut.
    _cases[index] = caseItem.copyWith(
      updatedAt: now,
      messages: updatedMessages,
      timeline: [
        ...caseItem.timeline,
        CaseTimelineEvent(
          id: 'timeline-${now.millisecondsSinceEpoch}',
          title: const LocalizedText(
            fr: 'Réponse de l’étudiant',
            en: 'Student reply',
          ),
          description: const LocalizedText(
            fr: 'Le dossier a été mis à jour avec un nouveau message.',
            en: 'The case has been updated with a new message.',
          ),
          createdAt: now,
          status: caseItem.status,
        ),
      ],
    );
    _persist();
    update();

    if (ConnectivityService.instance.isOnline) {
      // Toujours par REST, même socket ouvert : l'envoi socket n'avait ni
      // accusé de réception ni repli, et un message refusé (limite, longueur)
      // restait affiché comme envoyé. Le serveur diffuse ensuite le message
      // dans la room, donc le temps réel du conseiller est inchangé.
      unawaited(_createRemoteCaseMessage(caseId, text));
    } else {
      unawaited(CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: profile?.fullName ?? 'Student',
      ));
    }
  }

  int unreadMessagesForCase(String caseId) {
    final caseItem = _cases.firstWhereOrNull((item) => item.id == caseId);
    if (caseItem == null) return 0;
    final lastRead = _caseLastReadAt[caseId] ?? caseItem.createdAt;
    return caseItem.messages
        .where(
          (message) =>
              message.senderRole != 'student' &&
              message.createdAt.isAfter(lastRead),
        )
        .length;
  }

  int get totalUnreadCaseMessages =>
      _cases.fold(0, (sum, item) => sum + unreadMessagesForCase(item.id));

  void markCaseMessagesRead(String caseId) {
    _caseLastReadAt[caseId] = DateTime.now();
    _persist();
    update();
  }

  Future<void> connectCaseDetailSocket(String caseId) async {
    if (!AppConfig.enableRemoteSync) return;
    if (!await _apiClient.hasAuthSession()) return;

    await _caseSocket.connect(caseId);

    _caseSocket.onMessage((data) => ingestRemoteCaseMessage(caseId, data));
    _caseSocket.onCaseUpdated((data) {
      try {
        _upsertCase(CaseApiCodec.studentCaseFromApi(data));
        _persist();
        update();
      } catch (_) {}
    });
    _caseSocket.onTyping((data) {
      final isTyping = data['isTyping'] as bool? ?? false;
      if (isCaseAdvisorTyping == isTyping) return;
      isCaseAdvisorTyping = isTyping;
      update();
      if (isTyping) {
        // Auto-reset after 4 s in case the stop event is missed.
        Future.delayed(const Duration(seconds: 4), () {
          if (isCaseAdvisorTyping) {
            isCaseAdvisorTyping = false;
            update();
          }
        });
      }
    });
  }

  Future<void> disconnectCaseDetailSocket() async {
    await _caseSocket.disconnect();
    isCaseAdvisorTyping = false;
    update();
  }

  void sendCaseTyping(String caseId, bool isTyping) {
    if (_caseSocket.isConnected) {
      _caseSocket.sendTyping(caseId, isTyping);
    }
  }

  void ingestRemoteCaseMessage(String caseId, Map<String, dynamic> data) {
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0) return;

    final messageId = data['id'] as String? ?? '';
    final caseItem = _cases[index];
    if (messageId.isNotEmpty &&
        caseItem.messages.any((message) => message.id == messageId)) {
      return;
    }

    final body = data['body'] as String? ?? '';
    final senderRole = data['senderRole'] as String? ?? 'counselor';
    final message = CaseMessage(
      id: messageId.isNotEmpty
          ? messageId
          : 'remote-${DateTime.now().millisecondsSinceEpoch}',
      senderName: data['senderName'] as String? ?? 'KPB',
      senderRole: senderRole,
      body: LocalizedText(fr: body, en: body),
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );

    final withoutOptimistic = senderRole == 'student'
        ? caseItem.messages
            .where(
              (existing) => !(existing.id.startsWith('user-') &&
                  existing.body.fr == body),
            )
            .toList()
        : caseItem.messages;

    _cases[index] = caseItem.copyWith(
      messages: [...withoutOptimistic, message],
      updatedAt: DateTime.now(),
    );
    _persist();
    update();
  }

  void uploadDocument(String caseId, String documentId, String filePath) {
    // Le point d'étranglement du masquage M2, et pas seulement l'interface.
    // Cette méthode fait DEUX choses : cocher « fourni » localement, puis tenter
    // l'envoi. La première réussit toujours, la seconde échoue en silence — le
    // conteneur d'analyse antivirale est mort côté serveur. Laisser cette
    // méthode faire son travail pendant que l'interface est masquée, c'est
    // laisser un futur appelant remettre la coche mensongère sans le savoir ;
    // la leçon PARC-05 de ce dépôt est qu'une garde posée sur l'écran seul ne
    // tient pas.
    if (!AppConfig.documentUploadEnabled) return;
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0) return;
    final caseItem = _cases[index];
    final updatedDocs = caseItem.documentRequests
        .map((doc) =>
            doc.id == documentId ? doc.copyWith(isProvided: true) : doc)
        .toList();
    _cases[index] = caseItem.copyWith(
      updatedAt: DateTime.now(),
      documentRequests: updatedDocs,
    );
    _persist();
    update();
    final document =
        updatedDocs.firstWhereOrNull((item) => item.id == documentId);
    if (document != null) {
      unawaited(_uploadRemoteCaseDocument(caseId, document, filePath));
    }
  }

  List<StudentCase> casesByType(CaseType? filter) {
    if (filter == null) return cases;
    return cases.where((item) => item.type == filter).toList();
  }

  /// Prefix of the temporary id a case carries until the server has it.
  static const String _localCaseIdPrefix = 'case-';

  static final RegExp _localCaseId = RegExp(r'^case-\d{10,}$');

  /// Local case ids whose remote create is in flight — a sync retry must not
  /// create the same case twice.
  final Set<String> _caseCreatesInFlight = <String>{};

  @override
  Future<void> _createRemoteCase(StudentCase localCase) async {
    if (!AppConfig.enableRemoteSync) return;
    if (!_caseCreatesInFlight.add(localCase.id)) return;
    try {
      final response = await _apiClient.createCase(<String, dynamic>{
        'type': CaseApiCodec.encodeCaseType(localCase.type),
        'title': resolve(localCase.title),
        'description': resolve(localCase.description),
        'contextLabel': resolve(localCase.contextLabel),
        'preferredContactMethod': CaseApiCodec.encodeContactMethod(
          localCase.preferredContactMethod,
        ),
      });
      _cases.removeWhere((item) => item.id == localCase.id);
      _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'createRemoteCase',
        domain: CrashlyticsObsDomain.cases,
        operation: 'create_remote_case',
      );
    } finally {
      _caseCreatesInFlight.remove(localCase.id);
    }
  }

  Future<void> _createRemoteCaseMessage(String caseId, String text) async {
    if (!AppConfig.enableRemoteSync) return;
    final senderName = profile?.fullName ?? 'Student';

    // If we already know we're offline, go straight to the outbox — no need
    // to burn a DNS lookup and block the UI on a 5-second timeout.
    if (!ConnectivityService.instance.isOnline) {
      await CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: senderName,
      );
      return;
    }

    try {
      await _apiClient.createCaseMessage(caseId, <String, dynamic>{
        'senderName': senderName,
        'senderRole': 'student',
        'body': text,
      });
      final response = await _apiClient.getCase(caseId);
      _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'createRemoteCaseMessage',
        domain: CrashlyticsObsDomain.cases,
        operation: 'create_remote_case_message',
      );
      final status = e is DioException ? e.response?.statusCode : null;
      if (status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429) {
        // Refus définitif (message trop long, dossier introuvable…) : le
        // remettre en file le ferait échouer à chaque reconnexion, en silence.
        KpbToast.error('case_message_send_failed'.tr);
        return;
      }
      // Network blip — queue it. The connectivity listener will retry.
      await CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: senderName,
      );
    }
  }

  Future<void>? _flushInFlight;

  /// Flush the offline message queue. Called on connectivity-restored events.
  /// Two callers (reconnect listener, sync) could run it concurrently and send
  /// the same queued entries twice: a second call joins the running flush.
  @override
  Future<void> flushPendingCaseMessages() {
    final running = _flushInFlight;
    if (running != null) return running;
    final flush = _flushPendingCaseMessages();
    _flushInFlight = flush;
    return flush.whenComplete(() => _flushInFlight = null);
  }

  Future<void> _flushPendingCaseMessages() async {
    if (!AppConfig.enableRemoteSync) return;
    if (!await _apiClient.hasAuthSession()) return;
    final outbox = CaseMessageOutbox.instance;
    final touched = <String>{};
    for (final entry in outbox.pending.toList()) {
      try {
        await _apiClient.createCaseMessage(entry.caseId, <String, dynamic>{
          'senderName': entry.senderName,
          'senderRole': 'student',
          'body': entry.body,
        });
        await outbox.remove(entry.key);
        touched.add(entry.caseId);
      } catch (e, s) {
        safeRecordError(
          e,
          s,
          reason: 'flushPendingCaseMessages',
          domain: CrashlyticsObsDomain.cases,
          operation: 'flush_pending_case_messages',
        );
        await outbox.markFailure(entry.key, entry);
      }
    }
    for (final caseId in touched) {
      try {
        final response = await _apiClient.getCase(caseId);
        _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      } catch (e, s) {
        safeRecordError(
          e,
          s,
          reason: 'flushPendingCaseMessages.getCase',
          domain: CrashlyticsObsDomain.cases,
          operation: 'flush_pending_case_messages_get_case',
        );
      }
    }
    if (touched.isNotEmpty) {
      _persist();
      update();
    }
  }

  int get pendingOutboundMessageCount =>
      CaseMessageOutbox.instance.pendingCount;

  bool caseHasQueuedMessages(String caseId) =>
      CaseMessageOutbox.instance.hasPendingFor(caseId);

  Future<void> _uploadRemoteCaseDocument(
    String caseId,
    DocumentRequest document,
    String filePath,
  ) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.uploadCaseDocumentFile(
        caseId: caseId,
        filePath: filePath,
        title: resolve(document.title),
      );
      final response = await _apiClient.getCase(caseId);
      _upsertCase(CaseApiCodec.studentCaseFromApi(response));
      _persist();
      update();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'uploadRemoteCaseDocument',
        domain: CrashlyticsObsDomain.cases,
        operation: 'upload_remote_case_document',
      );
    }
  }

  void _upsertCase(StudentCase caseItem) {
    final index = _cases.indexWhere((item) => item.id == caseItem.id);
    if (index >= 0) {
      _cases[index] = caseItem;
    } else {
      _cases.insert(0, caseItem);
    }
  }
}
