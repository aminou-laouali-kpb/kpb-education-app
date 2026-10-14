part of '../app_controller.dart';

/// Démarrage, session d’authentification, onboarding, déconnexion et suppression du compte.
mixin _SessionMixin on _AppControllerBase {
  Future<void> hydrate() async {
    final snapshot = await _repository.loadSnapshot();
    localeCode = snapshot.localeCode;
    hasSeenIntro = snapshot.hasSeenIntro;
    isGuestMode = snapshot.isGuestMode;
    isAppLockEnabled = snapshot.isAppLockEnabled;
    dataSaverEnabled = snapshot.dataSaverEnabled;
    analyticsConsentDecided = snapshot.analyticsConsentDecided;
    // ── Mesure d'audience : ACTIVE par défaut, refus explicite préservé ──────
    //
    // Revue du build 49 : l'analyse d'usage doit être active par défaut, et
    // les CGU l'annoncent (section « Mesure d'audience », `terms_analytics_body`,
    // et politique §9 `privacy_s9_body`).
    //
    // TOUT tient dans le ternaire, et c'est pour cela qu'il ne faut pas le
    // remplacer par un simple `snapshot.analyticsOptOut`. Deux populations
    // vivent dans ce champ et elles n'ont pas les mêmes droits :
    //
    //   • `decided == true` — l'utilisateur a TOUCHÉ l'interrupteur
    //     (Profil → « Analyse d'usage »). Son choix est rendu tel quel, y
    //     compris quand c'est un refus. Basculer le défaut ne doit JAMAIS
    //     retourner un refus explicite en acceptation : ce serait révoquer une
    //     décision prise, et sur ce terrain c'est exactement ce qu'un
    //     régulateur regarde.
    //
    //   • `decided == false` — l'utilisateur n'a jamais rien dit. C'est LA
    //     seule population que ce défaut concerne, et c'est elle qui passe de
    //     « éteint » à « allumé ».
    //
    // La valeur persistée d'un indécis est donc ignorée des deux côtés du
    // changement : avant elle était écrasée par `true`, elle l'est maintenant
    // par `false`. Rien à migrer, aucune écriture de rattrapage.
    analyticsOptOut =
        analyticsConsentDecided ? snapshot.analyticsOptOut : false;
    hasCompletedOnboarding = snapshot.hasCompletedOnboarding;
    onboardingSkipped = snapshot.onboardingSkipped;
    onboardingStep = snapshot.onboardingStep;
    profile = snapshot.profile;
    _savedItems
      ..clear()
      ..addAll(snapshot.savedItems);
    _savedItemTombstones
      ..clear()
      ..addAll(snapshot.savedItemTombstones);
    _cases
      ..clear()
      ..addAll(snapshot.cases);
    _orientationHistory
      ..clear()
      ..addAll(snapshot.orientationHistory);
    _searchHistory
      ..clear()
      ..addAll(snapshot.searchHistory);
    _purchasedCourseIds
      ..clear()
      ..addAll(snapshot.purchasedCourseIds);
    _reviewCredits = snapshot.reviewCredits;
    _reviewedCaseIds
      ..clear()
      ..addAll(snapshot.reviewedCaseIds);
    _completedRoadmapSteps = Map.from(snapshot.completedRoadmapSteps);
    _caseLastReadAt
      ..clear()
      ..addEntries(
        snapshot.caseLastReadAt.entries.map(
          (e) => MapEntry(
            e.key,
            DateTime.tryParse(e.value) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );
    themeMode = snapshot.themeMode;
    latestOrientationSession =
        _orientationHistory.isNotEmpty ? _orientationHistory.first : null;
    _pendingOrientationAnswers = Map.of(snapshot.pendingOrientationAnswers);
    pendingOrientationQuestionIndex = snapshot.pendingOrientationQuestionIndex;
    _profileNeedsPush = snapshot.profileNeedsPush;
    _clampShippedLocale();
    if (snapshot.localeCode != localeCode ||
        snapshot.profile?.preferredLanguage != profile?.preferredLanguage) {
      _persist();
    }
    if (CatalogCacheService.isInitialized) {
      final cache = CatalogCacheService.instance;
      final raws = <String, String?>{
        for (final r in const [
          'fields',
          'countries',
          'institutions',
          'programs',
          'scholarships',
        ])
          r: cache.readRaw(r),
      };

      // Décodage JSON + fromJson d'environ un millier d'objets HORS du thread
      // principal : fait ici, il figeait l'interface au démarrage.
      final decoded = await Isolate.run(
        () => decodeCachedCatalog(<String, String?>{
          'fields': raws['fields'],
          'countries': raws['countries'],
          'institutions': raws['institutions'],
          'programs': raws['programs'],
          'scholarships': raws['scholarships'],
        }),
      );
      fields
        ..clear()
        ..addAll(
            decoded.fields.isNotEmpty ? decoded.fields : MockCatalog.fields);
      countries
        ..clear()
        ..addAll(decoded.countries.isNotEmpty
            ? decoded.countries
            : MockCatalog.countries);
      institutions
        ..clear()
        ..addAll(decoded.institutions.isNotEmpty
            ? decoded.institutions
            : MockCatalog.institutions);
      programs
        ..clear()
        ..addAll(decoded.programs.isNotEmpty
            ? decoded.programs
            : MockCatalog.programs);
      scholarships
        ..clear()
        ..addAll(decoded.scholarships.isNotEmpty
            ? decoded.scholarships
            : MockCatalog.scholarships);
    } else {
      fields
        ..clear()
        ..addAll(MockCatalog.fields);
      countries
        ..clear()
        ..addAll(MockCatalog.countries);
      institutions
        ..clear()
        ..addAll(MockCatalog.institutions);
      programs
        ..clear()
        ..addAll(MockCatalog.programs);
      scholarships
        ..clear()
        ..addAll(MockCatalog.scholarships);
    }
    academyCourses
      ..clear()
      ..addAll(MockCatalog.academyCourses);
    _applyMvpCountryLock();
    if (AppConfig.enableRemoteSync) {
      // Local d'abord : la synchro part en arrière-plan au lieu de bloquer
      // `runApp` (environ 10 requêtes, 3 tentatives, 15 s de timeout — sur
      // un réseau 2G l'écran de démarrage restait affiché plusieurs minutes).
      // Le cache local s'affiche tout de suite ; la synchro met à jour
      // l'écran à la fin. Un compte connecté SANS profil local est géré par
      // `finishAuthSession`, qui attend cette synchro (voir `_inFlightSync`).
      unawaited(
        syncRemoteData(silent: true).catchError((Object e, StackTrace s) {
          safeRecordError(
            e,
            s,
            reason: 'hydrate.backgroundSync',
            domain: CrashlyticsObsDomain.sync,
            operation: 'hydrate_background_sync',
          );
        }),
      );
    }
    update();
  }

  void completeIntro() {
    hasSeenIntro = true;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void enterGuestMode() {
    isGuestMode = true;
    hasCompletedOnboarding = true;
    profile = null;
    _profileNeedsPush = false;
    _persist();
    update();
  }

  /// Guest → sign-up conversion (KPB-156). Clears guest state so the boot
  /// router lands on the auth welcome screen, and resets onboarding so a
  /// converting visitor still personalizes their profile after signing in.
  /// [source] identifies the gate that triggered it (e.g. 'cases_gate',
  /// 'profile') for funnel attribution. No-op if not currently a guest.
  /// Callers navigate to AppBootScreen afterwards.
  void leaveGuestForSignup({String source = 'unknown'}) {
    if (!isGuestMode) return;
    AnalyticsService.instance.logGuestToSignup(source: source);
    isGuestMode = false;
    hasCompletedOnboarding = false;
    profile = null;
    _profileNeedsPush = false;
    _persist();
    update();
  }

  Future<void> finishAuthSession() async {
    isGuestMode = false;
    if (AppConfig.enableRemoteSync) {
      // Un simple `syncRemoteData` était sauté si une synchro tournait déjà
      // (catalogue lent au démarrage), datait de moins de 30 s ou était en
      // backoff : le profil restait null, un compte existant atterrissait sur
      // l'onboarding et finissait par écraser son profil serveur. On attend la
      // synchro en cours, puis on force si le profil n'est toujours pas là.
      final running = _inFlightSync;
      if (isSyncing && running != null) await running;
      await syncRemoteData(silent: true, force: profile == null);
    }
    maybeRestoreOnboardingFromProfile();
    unawaited(syncPushIdentity());
    // Tie the PostHog session (and any replay) to the backend user id — a UUID,
    // not PII. No-op when PostHog is not configured. Runs on login and on
    // cold-start-while-signed-in (both call this).
    final userId = profile?.id;
    if (userId != null) {
      unawaited(AnalyticsService.instance.identifyUser(userId));
    }
    _persist();
    update();
  }

  void maybeRestoreOnboardingFromProfile() {
    final current = profile;
    if (current == null || hasCompletedOnboarding) return;
    if (current.completionScore >= 0.5 ||
        ((current.currentLevel ?? '').trim().isNotEmpty &&
            current.fieldIds.isNotEmpty)) {
      hasCompletedOnboarding = true;
    }
  }

  void saveOnboardingProgress(int step, UserProfile partialProfile) {
    onboardingStep = step;
    profile = partialProfile;
    _profileNeedsPush = true;
    _persist();
    unawaited(_pushProfileUpdate());
  }

  void skipOnboarding() {
    onboardingSkipped = true;
    onboardingStep = 0;
    hasCompletedOnboarding = true;
    isGuestMode = false;
    profile ??= UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountType: AccountType.student,
      fullName: '',
      email: _sessionEmail ?? '',
      phone: '',
      whatsApp: '',
      countryOfResidence: '',
      preferredLanguage: localeCode,
    );
    _persist();
    update();
    Get.offAllNamed(AppRoutes.home);
  }

  /// Email du compte connecté (Supabase), ou `null` hors session.
  String? get _sessionEmail => Get.isRegistered<AuthService>()
      ? Get.find<AuthService>().sessionEmail
      : null;

  bool get needsProfileCompletionBanner =>
      onboardingSkipped || (profile?.completionScore ?? 0) < 0.5;

  void completeOnboarding(UserProfile newProfile) {
    unawaited(completeOnboardingSynced(newProfile));
  }

  /// Same as [completeOnboarding], but the returned future resolves once the
  /// profile PATCH has been attempted. The AHA moment (P0-D) awaits this so
  /// `GET /matches/aha-moment` scores the profile the user just submitted
  /// instead of a stale/empty server copy. Push failures still resolve (the
  /// screen falls back to local scoring); `_profileNeedsPush` keeps the retry.
  Future<void> completeOnboardingSynced(UserProfile newProfile) async {
    profile = newProfile;
    localeCode = newProfile.preferredLanguage;
    // Apply the language chosen during onboarding to all `.tr` strings.
    _applyLocaleToUi();
    hasCompletedOnboarding = true;
    onboardingSkipped = false;
    onboardingStep = 0;
    isGuestMode = false;
    // Note: don't clear _cases here. Onboarding sets the profile; it doesn't
    // imply the user has no cases (e.g. they could be completing a missing
    // profile to unblock submitCase, which would discard the case they just
    // built). The next syncRemoteData will reconcile from the server.
    _profileNeedsPush = true;
    _persist();
    update();
    unawaited(syncPushIdentity());
    if (AppConfig.enableRemoteSync) {
      unawaited(syncRemoteData(silent: true));
    }
    await _pushProfileUpdate();
  }

  Future<void> logout() async {
    unawaited(AnalyticsService.instance.logLogout());
    unawaited(PushService.instance.logout());
    // Keep the historical logout contract: callers that do not await this
    // Future must still observe an anonymous in-memory state immediately.
    // Session/cache cleanup remains awaited below before the Future completes.
    _resetUserState();
    _persist();
    update();
    if (Get.isRegistered<AuthService>()) {
      await Get.find<AuthService>().clearSession();
    }
    // Les messages en attente appartiennent au compte qui se déconnecte : sans
    // ce vidage, ils étaient rejoués sous le compte suivant (téléphone partagé).
    try {
      await CaseMessageOutbox.instance.clear();
    } catch (_) {
      // Outbox not initialized in this session — nothing to clear.
    }
    await _clearSuccessLabLocalData();
  }

  bool _sessionLossInProgress = false;

  /// The Supabase session is gone for good (revoked refresh token, signed out
  /// by the SDK). Single entry point for the API client's permanent-failure
  /// path, the `signedOut` auth listener and the cold-start check, so the
  /// user is logged out and routed to the auth screen exactly once — instead
  /// of staying in the shell with no session while local edits silently stop
  /// syncing.
  Future<void> handleSessionLost() async {
    if (_sessionLossInProgress || profile == null || isGuestMode) return;
    _sessionLossInProgress = true;
    try {
      await logout();
      unawaited(Get.offAll(() => const AppBootScreen()));
      KpbToast.error(
        'api_client_session_expired_message'.tr,
        title: 'api_client_session_expired_title'.tr,
      );
    } finally {
      _sessionLossInProgress = false;
    }
  }

  /// Everything that belongs to the signed-in user, in ONE place. Logout and
  /// account deletion each kept their own partial list: credits, purchases,
  /// roadmap steps, read markers and remote ids survived a logout and were
  /// re-persisted for the next account on a shared phone.
  void _resetUserState() {
    profile = null;
    _profileNeedsPush = false;
    hasCompletedOnboarding = false;
    isGuestMode = false;
    latestOrientationSession = null;
    _savedItems.clear();
    _savedItemTombstones.clear();
    _remoteSavedItemIds.clear();
    _cases.clear();
    _caseLastReadAt.clear();
    _orientationHistory.clear();
    _searchHistory.clear();
    _pendingOrientationAnswers = {};
    pendingOrientationQuestionIndex = 0;
    _purchasedCourseIds.clear();
    _reviewCredits = 0;
    _reviewedCaseIds.clear();
    _completedRoadmapSteps = {};
    _commercialLeads.clear();
    _lastSyncAttemptAt = null;
    _syncBackoffUntil = null;
    _resetScholarshipFollowState();
  }

  /// GDPR / store-required account deletion (KPB-67). When remote sync is on we
  /// require the server delete to succeed first — a local-only wipe would
  /// orphan the backend + Supabase records — so a failure throws and nothing is
  /// erased, letting the UI ask the user to retry online. On success we erase
  /// every local store (snapshot, offline outbox, catalog cache), drop the push
  /// identity + session, and reset in-memory state.
  Future<void> deleteAccount() async {
    if (AppConfig.enableRemoteSync) {
      await _apiClient.deleteAccount();
    }
    unawaited(PushService.instance.logout());
    if (Get.isRegistered<AuthService>()) {
      await Get.find<AuthService>().clearSession();
    }
    await _wipeLocalData();
    _resetUserState();
    update();
  }

  Future<void> _wipeLocalData() async {
    await _repository.clear();
    try {
      await CaseMessageOutbox.instance.clear();
    } catch (_) {
      // Outbox not initialized in this session — nothing to clear.
    }
    if (CatalogCacheService.isInitialized) {
      await CatalogCacheService.instance.clear();
    }
    await _clearSuccessLabLocalData();
  }

  Future<void> _clearSuccessLabLocalData() async {
    // `main.dart` initializes Hive through the catalog service before creating
    // the controller. Lightweight unit tests intentionally skip that boot
    // sequence, so they must not try to open disk-backed boxes without a path.
    if (!CatalogCacheService.isInitialized) return;
    try {
      await SuccessLabCacheService.clearAll();
    } catch (_) {
      // Hive may not have been initialized in this session.
    }
    try {
      await SuccessLabOutbox.clearAll();
    } catch (_) {
      // Hive may not have been initialized in this session.
    }
  }

  /// GDPR data export (portability). Prefers the backend's authoritative
  /// aggregate of all user-owned records; falls back to the local profile when
  /// remote sync is off.
  Future<Map<String, dynamic>> exportData() async {
    if (AppConfig.enableRemoteSync) {
      return _apiClient.getAccountExport();
    }
    final current = profile;
    return <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': current == null ? null : _userProfilePayload(current),
    };
  }

  /// Rattache le jeton push de cet appareil au compte connecté. Seul
  /// l'identifiant part, vers notre backend : le ciblage (niveau, pays visé)
  /// se calcule côté serveur à partir du profil qu'il détient déjà. Sans effet
  /// tant que le push n'est pas initialisé.
  @override
  Future<void> syncPushIdentity() async {
    final current = profile;
    if (current == null) return;
    await PushService.instance.login(userId: current.id);
  }
}
