part of '../app_controller.dart';

/// Un texte de dossier dans les DEUX langues, lu dans les traductions : le
/// dossier est enregistré avec son `fr` et son `en`, et s'affiche ensuite dans
/// la langue courante. Une clé absente retombe sur la clé elle-même (visible
/// en test, jamais un texte vide).
LocalizedText _caseText(String key) => LocalizedText(
      fr: appTranslationsFr[key] ?? key,
      en: appTranslationsEn[key] ?? key,
    );

/// Dossiers : création, messagerie (socket + file d’envoi), documents.
mixin _CasesMixin on _AppControllerBase {
  StudentCase submitCase({
    required CaseType type,
    required String title,
    required String description,
    required String contextLabel,
    required ContactMethod contactMethod,
    String? scholarshipId,
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
      nextStepTitle: _caseText('case_local_next_step_title'),
      nextStepDescription: _caseText('case_local_next_step_body'),
      timeline: [
        CaseTimelineEvent(
          id: 'submitted-${now.millisecondsSinceEpoch}',
          title: _caseText('case_local_submitted_title'),
          description: _caseText('case_local_submitted_body'),
          createdAt: now,
          status: CaseStatus.submitted,
        ),
      ],
      messages: [
        CaseMessage(
          id: 'welcome-${now.millisecondsSinceEpoch}',
          senderName: 'case_local_welcome_sender'.tr,
          senderRole: 'system',
          body: _caseText('case_local_welcome_body'),
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
          ? [
              DocumentRequest(
                id: 'doc-profile',
                title: _caseText('case_local_doc_profile_title'),
                isProvided: false,
              ),
            ]
          : const <DocumentRequest>[],
      scholarshipId: (scholarshipId?.trim().isEmpty ?? true)
          ? null
          : scholarshipId!.trim(),
    );
    _cases.insert(0, created);
    _persist();
    update();
    KpbHaptics.success();
    AnalyticsService.instance.logCaseCreated(caseType: type.name);
    // Pas de référence dans le bandeau : celle-ci est calculée sur le téléphone
    // (nombre de dossiers + 1) et n'est pas celle du serveur (« KPB-2026-001 »
    // au lieu de 1134, audit build 57, T4-16). Le serveur la rend ensuite, et
    // l'écran du dossier l'affiche.
    KpbToast.success(
      'case_created_body'.tr,
      title: 'case_created_title'.tr,
      duration: const Duration(seconds: 4),
      action: KpbToastAction(
        label: 'view'.tr,
        onPressed: () {
          shellIndex = StudentShellTab.cases;
          update();
          // L'identifiant local est retiré au retour du serveur : on résout le
          // dossier au moment du tap (le plus récent), jamais celui capturé ici.
          if (_cases.isNotEmpty) {
            unawaited(Get.toNamed<void>(
                '/cases/${Uri.encodeComponent(_cases.first.id)}'));
          }
        },
      ),
    );
    unawaited(_createRemoteCase(created));
    return created;
  }

  /// Le dossier d'accompagnement OUVERT déjà lié à [scholarshipId] : d'abord
  /// parmi les dossiers locaux, puis `GET /cases?scholarshipId=` (un dossier
  /// créé sur un autre appareil). `null` : aucun, on peut en créer un.
  ///
  /// Ne lève jamais : hors ligne, seul le local fait foi.
  Future<StudentCase?> findOpenScholarshipCase(String scholarshipId) async {
    final id = scholarshipId.trim();
    if (id.isEmpty) return null;
    for (final item in _cases) {
      if (item.scholarshipId == id &&
          item.type == CaseType.scholarshipSupport &&
          item.isOpen) {
        return item;
      }
    }
    if (!AppConfig.enableRemoteSync || isGuestMode || profile == null) {
      return null;
    }
    try {
      final raw = await _apiClient.listCasesForScholarship(id);
      for (final entry in raw) {
        final remote = CaseApiCodec.studentCaseFromApi(entry);
        // Un serveur plus ancien ignore le filtre et rend TOUTE la liste :
        // seule une ligne qui porte le bon lien compte.
        if (remote.id.isEmpty ||
            remote.scholarshipId != id ||
            remote.type != CaseType.scholarshipSupport ||
            !remote.isOpen) {
          continue;
        }
        _upsertCase(remote);
        _persist();
        update();
        return remote;
      }
    } catch (_) {
      // Hors ligne ou route absente : on n'invente pas de doublon pour autant,
      // le serveur dédoublonnera à la synchronisation suivante.
    }
    return null;
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
    final resolvedId = resolveCaseId(caseId);
    final index = _cases.indexWhere((item) => item.id == resolvedId);
    if (index < 0 || text.trim().isEmpty) return;
    final caseItem = _cases[index];
    final now = DateTime.now();
    // Microsecondes : deux messages envoyés dans la même milliseconde
    // (dictée) gardaient le même id, donc le même état d'envoi.
    final messageId = 'user-${now.microsecondsSinceEpoch}';
    final senderName = profile?.fullName ?? 'Student';
    final updatedMessages = [
      ...caseItem.messages,
      CaseMessage(
        id: messageId,
        senderName: senderName,
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
          title: _caseText('case_local_student_reply_title'),
          description: _caseText('case_local_student_reply_body'),
          createdAt: now,
          status: caseItem.status,
        ),
      ],
    );
    if (!AppConfig.enableRemoteSync) {
      _persist();
      update();
      return;
    }
    final isLocalCase = _localCaseId.hasMatch(resolvedId);
    if (!isLocalCase && ConnectivityService.instance.isOnline) {
      _caseMessagesInFlight.add(messageId);
      _persist();
      update();
      // Toujours par REST, même socket ouvert : l'envoi socket n'avait ni
      // accusé de réception ni repli, et un message refusé (limite, longueur)
      // restait affiché comme envoyé. Le serveur diffuse ensuite le message
      // dans la room, donc le temps réel du conseiller est inchangé.
      unawaited(_createRemoteCaseMessage(resolvedId, text, messageId));
      return;
    }
    _persist();
    update();
    // Hors ligne, ou dossier pas encore connu du serveur (id local
    // `case-<ms>`) : le poster maintenant rendait un 404 et le message était
    // perdu (revue avant la 58, n° 18). Il attend en file ; la création
    // distante du dossier réécrit son id puis vide la file.
    unawaited(_enqueueCaseMessage(
      caseId: resolvedId,
      body: text,
      senderName: senderName,
      localMessageId: messageId,
    ));
    if (isLocalCase && ConnectivityService.instance.isOnline) {
      // Sans effet si la création est déjà en cours.
      unawaited(_createRemoteCase(caseItem));
    }
  }

  Future<void> _enqueueCaseMessage({
    required String caseId,
    required String body,
    required String senderName,
    required String localMessageId,
  }) async {
    final outbox = CaseMessageOutbox.maybeInstance;
    if (outbox == null) return;
    await outbox.enqueue(
      caseId: caseId,
      body: body,
      senderName: senderName,
      localMessageId: localMessageId,
    );
    update();
  }

  /// L'id sous lequel le dossier [caseId] est connu MAINTENANT : un id local
  /// `case-<ms>` est remplacé par l'id serveur au retour de la création
  /// distante, alors que l'écran du dossier, ouvert par le bandeau « Voir »,
  /// garde l'ancien.
  String resolveCaseId(String caseId) => _caseIdAliases[caseId] ?? caseId;

  /// Le dossier [caseId], à travers [resolveCaseId]. `null` s'il a disparu.
  StudentCase? caseById(String caseId) {
    final id = resolveCaseId(caseId);
    return _cases.firstWhereOrNull((item) => item.id == id);
  }

  /// Où en est l'envoi d'un message de l'élève : seules les bulles
  /// optimistes (`user-…`) peuvent être en attente ou en échec ; tout ce qui
  /// vient du serveur est envoyé.
  CaseMessageDelivery caseMessageDelivery(CaseMessage message) {
    if (message.senderRole != 'student' || !message.id.startsWith('user-')) {
      return CaseMessageDelivery.sent;
    }
    if (_rejectedCaseMessageIds.contains(message.id)) {
      return CaseMessageDelivery.failed;
    }
    if (_caseMessagesInFlight.contains(message.id)) {
      return CaseMessageDelivery.pending;
    }
    final outbox = CaseMessageOutbox.maybeInstance;
    if (outbox == null) return CaseMessageDelivery.sent;
    final entry = outbox.entryForMessage(message.id, body: message.body.fr);
    if (entry == null) return CaseMessageDelivery.sent;
    return outbox.isPermanentlyFailed(entry)
        ? CaseMessageDelivery.failed
        : CaseMessageDelivery.pending;
  }

  /// « Réessayer » sur une bulle « Non envoyé ».
  Future<void> retryCaseMessage(String messageId) async {
    final caseItem = _cases.firstWhereOrNull(
        (item) => item.messages.any((message) => message.id == messageId));
    if (caseItem == null) return;
    final message =
        caseItem.messages.firstWhere((message) => message.id == messageId);
    final text = message.body.fr;
    if (_rejectedCaseMessageIds.remove(messageId)) {
      if (_localCaseId.hasMatch(caseItem.id) ||
          !ConnectivityService.instance.isOnline) {
        await _enqueueCaseMessage(
          caseId: caseItem.id,
          body: text,
          senderName: message.senderName,
          localMessageId: messageId,
        );
        return;
      }
      _caseMessagesInFlight.add(messageId);
      update();
      await _createRemoteCaseMessage(caseItem.id, text, messageId);
      return;
    }
    final outbox = CaseMessageOutbox.maybeInstance;
    final entry =
        outbox?.entryForMessage(messageId, body: text, caseId: caseItem.id);
    if (outbox == null || entry == null) return;
    await outbox.resetRetries(entry);
    update();
    await flushPendingCaseMessages();
  }

  /// Retour au premier plan : la file ne se vidait qu'au passage hors ligne →
  /// en ligne, qu'une 3G lente mais « en ligne » ne déclenche jamais.
  void onAppResumed() {
    if (!ConnectivityService.instance.isOnline) return;
    unawaited(flushPendingCaseMessages());
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
    _caseLastReadAt[resolveCaseId(caseId)] = DateTime.now();
    _persist();
    update();
  }

  Future<void> connectCaseDetailSocket(String caseId) async {
    if (!AppConfig.enableRemoteSync) return;
    // Ouvrir un dossier relance aussi la file d'envoi : sans transition de
    // réseau, rien d'autre ne la vidait avant la prochaine synchro.
    if (ConnectivityService.instance.isOnline) {
      unawaited(flushPendingCaseMessages());
    }
    caseId = resolveCaseId(caseId);
    // Un dossier encore local n'a pas de room côté serveur.
    if (_localCaseId.hasMatch(caseId)) return;
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

  /// Id local `case-<ms>` → id serveur, rempli au retour de la création
  /// distante. En mémoire seulement : la file d'envoi, elle, est réécrite sur
  /// disque, et aucun écran ne survit à un redémarrage.
  final Map<String, String> _caseIdAliases = <String, String>{};

  /// Bulles optimistes dont le POST est en cours.
  final Set<String> _caseMessagesInFlight = <String>{};

  /// Bulles refusées par le serveur (4xx) : « Non envoyé », sans file.
  final Set<String> _rejectedCaseMessageIds = <String>{};

  Timer? _outboxRetryTimer;

  /// Délai de la relance après un échec réseau, sans attendre une transition
  /// de connectivité. Réglable en test.
  @visibleForTesting
  Duration outboxRetryDelay = const Duration(seconds: 20);

  void _scheduleOutboxRetry() {
    if (_outboxRetryTimer?.isActive ?? false) return;
    _outboxRetryTimer = Timer(outboxRetryDelay, () {
      _outboxRetryTimer = null;
      if (ConnectivityService.instance.isOnline) {
        unawaited(flushPendingCaseMessages());
      }
    });
  }

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
        // Gardé par le serveur seulement si la fiche existe (jamais un 400).
        if (localCase.scholarshipId != null)
          'scholarshipId': localCase.scholarshipId,
      });
      final remote = CaseApiCodec.studentCaseFromApi(response);
      final outbox = CaseMessageOutbox.maybeInstance;
      if (remote.id.isNotEmpty && remote.id != localCase.id) {
        // L'écran ouvert par « Voir » et les messages écrits pendant la
        // création suivent le dossier sous son nouvel id (revue avant la 58,
        // n° 18) : avant, l'écran passait à « Dossier introuvable » et la
        // file gardait un id que le serveur ne connaît pas.
        _caseIdAliases[localCase.id] = remote.id;
        await outbox?.reassignCase(localCase.id, remote.id);
        final lastRead = _caseLastReadAt.remove(localCase.id);
        if (lastRead != null) _caseLastReadAt[remote.id] = lastRead;
      }
      // Relu APRÈS l'attente : un message a pu être ajouté entre-temps.
      final previous =
          _cases.firstWhereOrNull((item) => item.id == localCase.id);
      _cases.removeWhere((item) => item.id == localCase.id);
      _upsertCase(_carryUndeliveredBubbles(remote, previous));
      _persist();
      update();
      if (outbox != null && outbox.hasPendingFor(remote.id)) {
        unawaited(flushPendingCaseMessages());
      }
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

  /// Un refus définitif : le reposter échouerait à chaque fois.
  static bool _isPermanentRejection(Object e) {
    final status = e is DioException ? e.response?.statusCode : null;
    return status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 429;
  }

  Future<void> _createRemoteCaseMessage(
    String caseId,
    String text,
    String messageId,
  ) async {
    final senderName = profile?.fullName ?? 'Student';
    try {
      try {
        await _apiClient.createCaseMessage(caseId, <String, dynamic>{
          'senderName': senderName,
          'senderRole': 'student',
          'body': text,
        });
      } catch (e, s) {
        safeRecordError(
          e,
          s,
          reason: 'createRemoteCaseMessage',
          domain: CrashlyticsObsDomain.cases,
          operation: 'create_remote_case_message',
        );
        if (_isPermanentRejection(e)) {
          // Refus définitif (message trop long, dossier introuvable…) : le
          // remettre en file le ferait échouer à chaque reconnexion. La bulle
          // passe en « Non envoyé », avec « Réessayer ».
          _rejectedCaseMessageIds.add(messageId);
          KpbToast.error('case_message_send_failed'.tr);
          return;
        }
        // Coupure réseau : en file, et relance dans quelques secondes.
        await _enqueueCaseMessage(
          caseId: caseId,
          body: text,
          senderName: senderName,
          localMessageId: messageId,
        );
        _scheduleOutboxRetry();
        return;
      }
      // Le message EST parti. Si la relecture du dossier échoue ensuite, on
      // ne le remet surtout pas en file : le backend ne dédoublonne pas, et le
      // conseiller le recevait deux fois (revue avant la 58, n° 19). La
      // prochaine synchro (ou le socket) rafraîchira le dossier.
      // Plus « en cours » AVANT la relecture : sinon la bulle optimiste était
      // gardée à côté de la copie serveur, et le message s'affichait deux fois.
      _caseMessagesInFlight.remove(messageId);
      try {
        final response = await _apiClient.getCase(caseId);
        _upsertCase(CaseApiCodec.studentCaseFromApi(response));
        _persist();
      } catch (e, s) {
        safeRecordError(
          e,
          s,
          reason: 'createRemoteCaseMessage.getCase',
          domain: CrashlyticsObsDomain.cases,
          operation: 'create_remote_case_message_get_case',
        );
      }
    } finally {
      _caseMessagesInFlight.remove(messageId);
      update();
    }
  }

  Future<void>? _flushInFlight;

  /// Flush the offline message queue. Called on connectivity-restored events,
  /// sync, case opening, app resume, and after a remote case create.
  /// Two callers could run it concurrently and send the same queued entries
  /// twice: a second call joins the running flush.
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
    final outbox = CaseMessageOutbox.maybeInstance;
    if (outbox == null || outbox.pendingCount == 0) return;
    if (!await _apiClient.hasAuthSession()) return;
    final touched = <String>{};
    var changed = false;
    var networkFailure = false;
    for (final entry in outbox.pending.toList()) {
      var caseId = entry.caseId;
      final alias = _caseIdAliases[caseId];
      if (alias != null) {
        caseId = alias;
        await outbox.reassignCase(entry.caseId, alias);
      }
      // Dossier pas encore créé côté serveur : le poster rendait un 404 qui
      // brûlait un essai à chaque fois. Il partira après la création.
      if (_localCaseId.hasMatch(caseId)) continue;
      try {
        await _apiClient.createCaseMessage(caseId, <String, dynamic>{
          'senderName': entry.senderName,
          'senderRole': 'student',
          'body': entry.body,
        });
        await outbox.remove(entry.key);
        touched.add(caseId);
        changed = true;
      } catch (e, s) {
        safeRecordError(
          e,
          s,
          reason: 'flushPendingCaseMessages',
          domain: CrashlyticsObsDomain.cases,
          operation: 'flush_pending_case_messages',
        );
        changed = true;
        if (_isPermanentRejection(e)) {
          await outbox.markPermanentFailure(entry.key, entry);
          continue;
        }
        await outbox.markFailure(entry.key, entry);
        // Le réseau est tombé : inutile de brûler un essai sur chacun des
        // suivants, ni de les envoyer dans le désordre.
        networkFailure = true;
        break;
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
    if (changed) {
      _persist();
      update();
    }
    if (networkFailure && outbox.pending.isNotEmpty) _scheduleOutboxRetry();
  }

  int get pendingOutboundMessageCount =>
      CaseMessageOutbox.maybeInstance?.pendingCount ?? 0;

  bool caseHasQueuedMessages(String caseId) =>
      CaseMessageOutbox.maybeInstance?.hasPendingFor(resolveCaseId(caseId)) ??
      false;

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
      _cases[index] = _carryUndeliveredBubbles(caseItem, _cases[index]);
    } else {
      _cases.insert(0, caseItem);
    }
  }

  /// La copie serveur d'un dossier ne connaît pas les messages encore en
  /// attente ou en échec : la substituer telle quelle effaçait leur bulle,
  /// alors que le message dormait dans la file. On les garde à la fin du fil.
  @override
  StudentCase _carryUndeliveredBubbles(
    StudentCase incoming,
    StudentCase? previous,
  ) {
    if (previous == null) return incoming;
    final known = incoming.messages.map((message) => message.id).toSet();
    final undelivered = previous.messages
        .where((message) =>
            !known.contains(message.id) &&
            caseMessageDelivery(message) != CaseMessageDelivery.sent)
        .toList();
    if (undelivered.isEmpty) return incoming;
    return incoming.copyWith(messages: [...incoming.messages, ...undelivered]);
  }
}

/// État d'envoi d'un message de l'élève, affiché sous sa bulle.
enum CaseMessageDelivery { sent, pending, failed }
