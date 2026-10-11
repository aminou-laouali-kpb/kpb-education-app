import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../navigation/shell_tabs.dart';
import '../services/analytics_service.dart';
import '../services/case_message_outbox.dart';
import '../services/case_socket_service.dart';
import '../services/safe_crashlytics.dart';
import '../services/connectivity_service.dart';

import '../observability/crashlytics_observability.dart';
import '../config/app_config.dart';
import '../config/app_routes.dart';
import '../data/mock_catalog.dart';
import '../data/notification_opt_out.dart';
import '../data/orientation_engine.dart';
import '../data/orientation_questions_m4.dart';
import '../data/roadmap_engine.dart';
import '../models/app_models.dart';
import '../repositories/app_api_client.dart';
import '../repositories/app_repository.dart';
import '../repositories/app_snapshot.dart';
import '../utils/country_utils.dart';
import '../utils/user_facing_sync_error.dart';
import '../data/case_api_codec.dart';
import '../data/profile_api_codec.dart';
import '../i18n/app_locale.dart';
import '../data/saved_item_api_codec.dart';
import '../services/app_search_service.dart';
import '../data/content_api_codec.dart';
import '../services/catalog_remote_sync.dart';
import '../services/catalog_cache_service.dart';
import '../services/onesignal_service.dart';
import '../services/onesignal_tags.dart';
import '../services/sync_conflict_merge.dart';
import '../services/sync_telemetry.dart';
import '../services/auth_service.dart';
import '../services/success_lab_cache_service.dart';
import '../services/success_lab_outbox.dart';

part 'app_controller/search.dart';
part 'app_controller/roadmap.dart';
part 'app_controller/commercial.dart';
part 'app_controller/parcours.dart';
part 'app_controller/academy.dart';
part 'app_controller/referral_credits.dart';

/// What the catalog on screen actually **is** right now.
///
/// The client used to know a single boolean (`catalogIsSampleData`), which
/// collapsed two very different situations into one alarming message. The sync
/// layer already distinguishes them ([CatalogSyncOutcome]); this is the
/// consumer side of that contract:
///
///  * [live] — real rows from the backend. No banner. An authoritative *empty*
///    catalog also lands here: "the server has zero rows" is a fact about the
///    data, not a degradation, and the lists were emptied to match it.
///  * [sample] — the bundled `MockCatalog` seed is on screen: plausible but
///    **fake** rows (never synced, or the service is unavailable and no real
///    snapshot exists). Loud banner — the product promises verifiable data.
///  * [offline] — the service is unavailable but the last **real** snapshot was
///    replayed from Hive. The rows are true, merely dated, so the banner is
///    discreet and says so instead of crying "sample data".
enum CatalogDataState { live, sample, offline }

/// How bad each state is, for the aggregation rule below. Not exposed: callers
/// should compare through [aggregateCatalogDataState], not by ordering.
int _catalogStateSeverity(CatalogDataState state) => switch (state) {
      CatalogDataState.live => 0,
      CatalogDataState.offline => 1,
      CatalogDataState.sample => 2,
    };

/// Folds the per-resource [CatalogSyncOutcome]s of one sync into the single
/// state the shell shows.
///
/// **Aggregation rule: the worst situation wins — `sample` > `offline` > `live`.**
/// Resources are synced independently, so they can disagree (countries served
/// live while scholarships fell back to yesterday's snapshot). The banner must
/// describe the weakest data the user can reach, otherwise a "live" claim would
/// cover dated rows one tap away. An empty [outcomes] means nothing was
/// resolved at all, which is exactly the bundled-seed situation → [sample].
///
/// Only the five `/catalog/*` resources feed this. Editorial `/content/*`
/// resources are deliberately excluded: their endpoint has no `source`
/// envelope and no 503 contract yet, so an empty response there is a no-op
/// that keeps the bundled seed — feeding that into the fold would pin the app
/// to a permanent "sample data" banner because a content table is unpopulated.
CatalogDataState aggregateCatalogDataState(
  Iterable<CatalogSyncOutcome> outcomes,
) {
  var worst = CatalogDataState.live;
  var sawAny = false;
  for (final outcome in outcomes) {
    sawAny = true;
    final state = switch (outcome) {
      CatalogSyncOutcome.live => CatalogDataState.live,
      CatalogSyncOutcome.empty => CatalogDataState.live,
      CatalogSyncOutcome.offlineCache => CatalogDataState.offline,
    };
    if (_catalogStateSeverity(state) > _catalogStateSeverity(worst)) {
      worst = state;
    }
  }
  return sawAny ? worst : CatalogDataState.sample;
}

class AppController extends _AppControllerBase
    with
        _SearchMixin,
        _RoadmapMixin,
        _CommercialMixin,
        _ParcoursMixin,
        _AcademyMixin,
        _ReferralCreditsMixin {
  AppController({required super.repository, super.apiClient});

  static const int shellTabCount = StudentShellTab.count;
}

abstract class _AppControllerBase extends GetxController {
  static const int shellTabCount = StudentShellTab.count;

  _AppControllerBase({
    required AppRepository repository,
    AppApiClient? apiClient,
  })  : _repository = repository,
        _apiClient = apiClient ?? AppApiClient();

  final AppRepository _repository;
  final AppApiClient _apiClient;

  /// Expose the API client for feature screens that need direct calls.
  AppApiClient get apiClient => _apiClient;

  String localeCode = 'fr';
  bool hasSeenIntro = false;
  bool isGuestMode = false;
  bool isAppLockEnabled = false;

  /// Data-saver mode — when on, the UI skips non-essential network images.
  bool dataSaverEnabled = false;

  /// Product analytics, Crashlytics, and session replay remain off until the
  /// user makes an explicit choice in the profile privacy setting.
  bool analyticsOptOut = true;
  bool analyticsConsentDecided = false;
  bool hasCompletedOnboarding = false;
  bool onboardingSkipped = false;
  int onboardingStep = 0;
  ThemeMode themeMode = ThemeMode.system;
  int shellIndex = 0;
  int commercialShellIndex = 0;
  int selectedOrientationQuestion = 0;
  bool isSyncing = false;
  DateTime? lastSyncedAt;
  String? syncError;

  /// What the catalog on screen actually is — see [CatalogDataState].
  ///
  /// Starts at [CatalogDataState.sample] because that is the truth before the
  /// first sync: the lists below are seeded from `MockCatalog`. Recomputed at
  /// the end of every catalog sync from the per-resource outcomes, so a later
  /// successful sync returns to [CatalogDataState.live] and the banner
  /// disappears without an app restart (the shell rebuilds on `update()`).
  CatalogDataState catalogDataState = CatalogDataState.sample;

  /// Historical boolean, now derived. Kept because "are we on fake rows?" is a
  /// genuinely different question from "is anything off?", and callers that
  /// only care about the fake-data case should not have to know the enum.
  bool get catalogIsSampleData => catalogDataState == CatalogDataState.sample;

  /// When the replayed snapshot was written, for the `offline` banner's
  /// freshness label. Non-null only while [catalogDataState] is
  /// [CatalogDataState.offline]. Read once per sync from the Hive cache's
  /// existing `lastSyncedAt` so the banner never touches Hive during a build.
  DateTime? catalogSnapshotAt;

  /// True once any sync put real rows (live or replayed snapshot) in the lists.
  /// Guards the failure path: a sync that dies before reaching the catalog must
  /// not relabel already-loaded real data as "sample".
  bool _catalogEverLoadedRealRows = false;
  UserProfile? profile;
  OrientationSession? latestOrientationSession;

  // Catalog data always initialized from MockCatalog (static content).
  // Operational data (cases, profile, savedItems) is synced from remote.
  final List<FieldModel> fields = <FieldModel>[];
  final List<CountryModel> countries = <CountryModel>[];
  final List<InstitutionModel> institutions = <InstitutionModel>[];
  final List<ProgramModel> programs = <ProgramModel>[];
  final List<ScholarshipModel> scholarships = <ScholarshipModel>[];
  final List<AcademyCourseModel> academyCourses = <AcademyCourseModel>[];
  final List<ServiceOffer> serviceOffers =
      List<ServiceOffer>.of(MockCatalog.serviceOffers);
  final List<SupportDestination> supportDestinations =
      List<SupportDestination>.of(MockCatalog.supportDestinations);
  final List<ArticleModel> articles =
      List<ArticleModel>.of(MockCatalog.articles);
  final List<ForumCategoryModel> forumCategories =
      List<ForumCategoryModel>.of(MockCatalog.forumCategories);
  final List<ForumTopicTagModel> forumTopicTags =
      List<ForumTopicTagModel>.of(MockCatalog.forumTopicTags);
  final List<OrientationQuestion> orientationQuestions = [
    ...MockCatalog.orientationQuestions,
    ...orientationQuestionsM4Extension,
  ];

  final List<SavedItem> _savedItems = <SavedItem>[];
  // Keys of saved items deleted locally but not yet confirmed by the server.
  final Set<String> _savedItemTombstones = <String>{};
  final List<StudentCase> _cases = <StudentCase>[];
  final Map<String, CountryModel> _countryDetailCache =
      <String, CountryModel>{};
  final CaseSocketService _caseSocket = CaseSocketService();
  final Map<String, DateTime> _caseLastReadAt = <String, DateTime>{};
  String? _activeCaseSocketId;
  // True while the remote participant is typing (shown in CaseDetailScreen).
  bool isCaseAdvisorTyping = false;
  final List<OrientationSession> _orientationHistory = <OrientationSession>[];
  final Map<String, String> _remoteSavedItemIds = <String, String>{};

  /// True after local profile edits until PATCH `/profiles/me` succeeds (offline sync conflict avoidance).
  bool _profileNeedsPush = false;
  DateTime? _lastSyncAttemptAt;
  DateTime? _syncBackoffUntil;
  static const Duration _minSyncInterval = Duration(seconds: 30);
  final List<String> _searchHistory = <String>[];
  Map<String, List<String>> _pendingOrientationAnswers = {};
  final List<String> _purchasedCourseIds = <String>[];
  // No-cash referral reward balance (KPB-77). Backend is the source of truth;
  // this is the last-synced value, persisted for cold-start display.
  int _reviewCredits = 0;
  // Cases the student has already been prompted to review at admission (KPB-75).
  final List<String> _reviewedCaseIds = <String>[];
  Map<String, List<String>> _completedRoadmapSteps = {};
  int pendingOrientationQuestionIndex = 0;
  bool isSubmittingOrientation = false;
  String? universitiesInitialFieldId;
  final List<CommercialLead> _commercialLeads = <CommercialLead>[];
  bool isLoadingCommercialLeads = false;
  String? commercialLeadsError;
  CommercialStats commercialStats = CommercialStats.empty;
  bool isLoadingCommercialStats = false;

  // ── Parcours & Témoignages (Chantier C) ───────────────────────────────────
  final List<ParcoursStory> _parcoursStories = <ParcoursStory>[];
  bool isLoadingParcours = false;
  String? parcoursError;
  // Discovery state (theme + search) — see _ParcoursMixin.
  String? parcoursFieldFilter; // null = "All"
  String parcoursQuery = '';

  List<SavedItem> get savedItems => List.unmodifiable(_savedItems);
  List<StudentCase> get cases => List.unmodifiable(_cases);
  List<OrientationSession> get orientationHistory =>
      List.unmodifiable(_orientationHistory);
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  List<String> get purchasedCourseIds => List.unmodifiable(_purchasedCourseIds);
  int get reviewCredits => _reviewCredits;

  /// Whether the admission-milestone review prompt has already been shown for
  /// this case (KPB-75) — so we ask at most once.
  bool hasReviewedCase(String caseId) => _reviewedCaseIds.contains(caseId);

  /// Mark a case's review prompt as handled (submitted or dismissed) + persist.
  void markCaseReviewed(String caseId) {
    if (_reviewedCaseIds.contains(caseId)) return;
    _reviewedCaseIds.add(caseId);
    _persist();
  }

  Map<String, List<String>> get pendingOrientationAnswers =>
      Map.unmodifiable(_pendingOrientationAnswers);

  bool get isStudent => profile?.accountType == AccountType.student;
  bool get isParent => profile?.accountType == AccountType.parent;
  bool get isPartner => profile?.accountType == AccountType.partner;
  bool get isCommercial => profile?.accountType == AccountType.commercial;
  List<ServiceOffer> get publishedServiceOffers => serviceOffers
      .where((item) => item.status == PublicationStatus.published)
      .toList();
  List<SupportDestination> get visibleSupportDestinations => supportDestinations
      .where(
        (item) => item.status == PublicationStatus.published && item.isVisible,
      )
      .toList();
  List<ArticleModel> get publishedArticles => articles
      .where((item) => item.status == PublicationStatus.published)
      .toList()
    ..sort(
      (left, right) =>
          (right.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                  left.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
  List<ForumCategoryModel> get visibleForumCategories => forumCategories
      .where((item) => item.status == PublicationStatus.published)
      .toList()
    ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
  List<ForumTopicTagModel> get visibleForumTopicTags => forumTopicTags
      .where((item) => item.status == PublicationStatus.published)
      .toList()
    ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));

  String resolve(LocalizedText text) => text.resolve(localeCode);

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

      final cachedFields = cache.read('fields');
      fields
        ..clear()
        ..addAll(cachedFields.isNotEmpty
            ? cachedFields
                .whereType<Map<String, dynamic>>()
                .map(FieldModel.fromJson)
            : MockCatalog.fields);

      final cachedCountries = cache.read('countries');
      countries
        ..clear()
        ..addAll(cachedCountries.isNotEmpty
            ? cachedCountries
                .whereType<Map<String, dynamic>>()
                .map(CountryModel.fromJson)
            : MockCatalog.countries);

      final cachedInstitutions = cache.read('institutions');
      institutions
        ..clear()
        ..addAll(cachedInstitutions.isNotEmpty
            ? cachedInstitutions
                .whereType<Map<String, dynamic>>()
                .map(InstitutionModel.fromJson)
            : MockCatalog.institutions);

      final cachedPrograms = cache.read('programs');
      programs
        ..clear()
        ..addAll(cachedPrograms.isNotEmpty
            ? cachedPrograms
                .whereType<Map<String, dynamic>>()
                .map(ProgramModel.fromJson)
            : MockCatalog.programs);

      final cachedScholarships = cache.read('scholarships');
      scholarships
        ..clear()
        ..addAll(cachedScholarships.isNotEmpty
            ? cachedScholarships
                .whereType<Map<String, dynamic>>()
                .map(ScholarshipModel.fromJson)
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
      await syncRemoteData(silent: true);
    }
    update();
  }

  /// Build 49 : toute préférence `en` (snapshot ou profil distant) redevient
  /// `fr`. `switchLanguage` n'est pas touché — le test de parité s'en sert.
  void _clampShippedLocale() {
    localeCode = canonicalAppLocale(localeCode);
    final p = profile;
    if (p == null) return;
    final shipped = canonicalAppLocale(p.preferredLanguage);
    if (p.preferredLanguage != shipped) {
      profile = p.copyWith(preferredLanguage: shipped);
    }
    localeCode = shipped;
  }

  /// Re-render every `.tr` string in [localeCode]. Guarded so it is a no-op in
  /// pure unit tests (no live GetMaterialApp), where forcing a frame asserts.
  void _applyLocaleToUi() {
    if (Get.context == null) return;
    // Ne RIEN faire quand la langue n'a pas changé.
    //
    // `Get.updateLocale` déclenche un `forceAppUpdate`, c'est-à-dire un
    // réassemblage complet de l'application. L'appeler à la fin de l'onboarding
    // — où l'immense majorité des utilisateurs garde le français — reconstruisait
    // tout l'arbre pour rien, en plein milieu de l'envoi du profil.
    //
    // C'est aussi ce qui rendait l'état occupé de « Créer mon compte »
    // intestable : le réassemblage laisse l'ordonnanceur hors de son état de
    // repos, et la frame suivante du test échoue sur
    // `schedulerPhase == SchedulerPhase.idle`. Un correctif qu'on ne peut pas
    // mesurer n'est pas un correctif.
    if (Get.locale?.toString() == Locale(localeCode).toString()) return;
    Get.updateLocale(Locale(localeCode));
  }

  void switchLanguage(String newLocaleCode) {
    localeCode = newLocaleCode;
    _applyLocaleToUi();
    final p = profile;
    if (p != null) {
      profile = p.copyWith(preferredLanguage: newLocaleCode);
    }
    _profileNeedsPush = true;
    unawaited(_pushProfileUpdate());
    _persist();
    update();
  }

  void toggleAppLock(bool enable) {
    isAppLockEnabled = enable;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  void toggleDataSaver(bool enable) {
    dataSaverEnabled = enable;
    _repository.saveSnapshot(_snapshot);
    update();
  }

  /// Profile switch: [allowed] true = analytics + session replay ON. Persists
  /// the inverse ([analyticsOptOut]) and flips Firebase + PostHog collection at
  /// runtime immediately (no restart needed). Applied again on every boot from
  /// the persisted flag ([applyAnalyticsConsent]).
  void setAnalyticsAllowed(bool allowed) {
    analyticsConsentDecided = true;
    analyticsOptOut = !allowed;
    _repository.saveSnapshot(_snapshot);
    unawaited(AnalyticsService.instance.setCollectionEnabled(allowed));
    update();
  }

  /// Re-applies the persisted analytics consent to the SDKs. Called at boot,
  /// after [hydrate], so a prior opt-out survives restarts.
  void applyAnalyticsConsent() {
    unawaited(AnalyticsService.instance.setCollectionEnabled(!analyticsOptOut));
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
      await syncRemoteData(silent: true);
    }
    maybeRestoreOnboardingFromProfile();
    unawaited(syncOneSignalIdentity());
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
    unawaited(syncOneSignalIdentity());
    if (AppConfig.enableRemoteSync) {
      unawaited(syncRemoteData(silent: true));
    }
    await _pushProfileUpdate();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persist();
    update();
    AnalyticsService.instance.logThemeToggled(mode == ThemeMode.dark);
  }

  Future<void> logout() async {
    AnalyticsService.instance.logLogout();
    unawaited(OneSignalService.instance.logout());
    // Keep the historical logout contract: callers that do not await this
    // Future must still observe an anonymous in-memory state immediately.
    // Session/cache cleanup remains awaited below before the Future completes.
    profile = null;
    _profileNeedsPush = false;
    hasCompletedOnboarding = false;
    isGuestMode = false;
    latestOrientationSession = null;
    _savedItems.clear();
    _savedItemTombstones.clear();
    _cases.clear();
    _orientationHistory.clear();
    _searchHistory.clear();
    _pendingOrientationAnswers = {};
    pendingOrientationQuestionIndex = 0;
    _persist();
    update();
    if (Get.isRegistered<AuthService>()) {
      await Get.find<AuthService>().clearSession();
    }
    await _clearSuccessLabLocalData();
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
    unawaited(OneSignalService.instance.logout());
    if (Get.isRegistered<AuthService>()) {
      await Get.find<AuthService>().clearSession();
    }
    await _wipeLocalData();
    profile = null;
    _profileNeedsPush = false;
    hasCompletedOnboarding = false;
    isGuestMode = false;
    latestOrientationSession = null;
    _savedItems.clear();
    _savedItemTombstones.clear();
    _cases.clear();
    _orientationHistory.clear();
    _searchHistory.clear();
    _pendingOrientationAnswers = {};
    pendingOrientationQuestionIndex = 0;
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

  void goToTab(int index) {
    final safeIndex = index.clamp(0, shellTabCount - 1);
    shellIndex = safeIndex;
    update();
  }

  void goToUniversitiesForField(String? fieldId) {
    universitiesInitialFieldId = fieldId;
    goToTab(StudentShellTab.universities);
  }

  void goToCommercialTab(int index) {
    commercialShellIndex = index.clamp(0, CommercialShellTab.count - 1);
    update();
  }

  void resetShell() {
    shellIndex = 0;
    commercialShellIndex = 0;
    update();
  }

  bool isSaved(SavedItemType type, String itemId) {
    return _savedItems
        .any((item) => item.type == type && item.itemId == itemId);
  }

  void toggleSaved(SavedItemType type, String itemId) {
    final index = _savedItems.indexWhere(
      (item) => item.type == type && item.itemId == itemId,
    );
    if (index >= 0) {
      final existing = _savedItems[index];
      _savedItems.removeAt(index);
      _savedItemTombstones.add(_savedItemKey(type, itemId));
      unawaited(_deleteRemoteSavedItem(existing));
      AnalyticsService.instance
          .logUnsaveItem(itemId: itemId, itemType: type.name);
      HapticFeedback.lightImpact();
    } else {
      final savedItem = SavedItem(type: type, itemId: itemId);
      _savedItems.add(savedItem);
      // If the user is re-saving an item they just un-saved (the delete may
      // still be in-flight), purge the tombstone — otherwise a sync running
      // before the server confirms the delete would filter this re-save out
      // of mergeSavedItemsUnion and silently drop it.
      _savedItemTombstones.remove(_savedItemKey(type, itemId));
      unawaited(_createRemoteSavedItem(savedItem));
      AnalyticsService.instance
          .logSaveItem(itemId: itemId, itemType: type.name);
      HapticFeedback.mediumImpact();
    }
    _persist();
    update();
  }

  // ── Roadmap Management ───────────────────────────────────────────────────

  /// Public pull-to-refresh — calls syncRemoteData and returns when done.
  ///
  /// IMPORTANT: do NOT name this `refresh()` — that would shadow
  /// `GetxController.refresh()`, which GetX calls internally to notify
  /// listeners. Naming this `pullToRefresh()` avoids triggering a full sync
  /// every time any widget rebuilds.
  Future<void> pullToRefresh() => syncRemoteData(silent: false, force: true);

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
    HapticFeedback.heavyImpact();
    AnalyticsService.instance.logOrientationComplete(
      totalQuestions: orientationQuestions.length,
      matchCount: session.recommendations.length,
    );
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

  // ── Orientation progress persistence ──────────────────────────

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

  // ── Profile update ──────────────────────────────────────────

  Future<void> updateProfile(UserProfile newProfile) async {
    profile = newProfile;
    _profileNeedsPush = true;
    _persist();
    update();
    // Niveau ou pays visé modifié → les segments OneSignal doivent suivre
    // maintenant, pas au prochain lancement.
    unawaited(syncOneSignalIdentity());
    await _pushProfileUpdate();
  }

  /// Profile switch: opt in/out of the scholarship newsletter. The backend
  /// stamps the consent timestamp on the opt-in transition and syncs Mautic.
  void setNewsletterOptIn(bool optIn) {
    final current = profile;
    if (current == null) return;
    unawaited(
        updateProfile(current.copyWith(wantsScholarshipNewsletter: optIn)));
  }

  /// KPB-169: opt out of (or back into) ONE recurring notification family.
  /// Persisted via the profile PATCH; the other families are untouched, and a
  /// key this build doesn't know about is preserved rather than cleared.
  void setNotificationTypeOptOut(String type, bool optOut) {
    final current = profile;
    if (current == null) return;
    final next = applyOptOut(
      current.disabledNotificationTypes,
      type,
      optOut: optOut,
    );
    unawaited(updateProfile(current.copyWith(disabledNotificationTypes: next)));
  }

  // ── Search ──────────────────────────────────────────────────

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
      id: 'case-${now.millisecondsSinceEpoch}',
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
    HapticFeedback.heavyImpact();
    AnalyticsService.instance.logCaseCreated(caseType: type.name);
    Get.snackbar(
      'case_created_title'.tr,
      'case_created_body'.trParams({'code': created.referenceCode}),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
      mainButton: TextButton(
        onPressed: () {
          shellIndex = StudentShellTab.cases;
          update();
          Get.closeCurrentSnackbar();
        },
        child: Text('view'.tr),
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
      Get.snackbar(
        'KPB Education',
        'parent_visibility_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
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
    _cases[index] = caseItem.copyWith(
      updatedAt: now,
      status: CaseStatus.awaitingStudent,
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
          status: CaseStatus.awaitingStudent,
        ),
      ],
    );
    _persist();
    update();

    if (ConnectivityService.instance.isOnline) {
      if (_caseSocket.isConnected && _activeCaseSocketId == caseId) {
        _caseSocket.sendMessage(caseId, text.trim());
      } else {
        unawaited(_createRemoteCaseMessage(caseId, text));
      }
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

    _activeCaseSocketId = caseId;
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
    _activeCaseSocketId = null;
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

  Future<void> syncRemoteData({bool silent = false, bool force = false}) async {
    if (!AppConfig.enableRemoteSync) return;
    if (isSyncing) return;

    final now = DateTime.now();
    if (!force &&
        _syncBackoffUntil != null &&
        now.isBefore(_syncBackoffUntil!)) {
      return;
    }
    if (!force &&
        _lastSyncAttemptAt != null &&
        now.difference(_lastSyncAttemptAt!) < _minSyncInterval) {
      return;
    }

    isSyncing = true;
    _lastSyncAttemptAt = now;
    if (!silent) {
      syncError = null;
      update();
    }

    final syncStarted = DateTime.now();
    var catalogHiveFallbackCount = 0;
    var authSyncFailed = false;
    // One entry per `/catalog/*` resource that resolved in this run. Declared
    // outside the try so the failure path can tell "nothing resolved" from
    // "some resources resolved before the sync blew up".
    final catalogOutcomes = <CatalogSyncOutcome>[];
    void onCatalogHiveFallback(String resource, int attempts) {
      catalogHiveFallbackCount++;
      SyncTelemetry.catalogHiveFallback(resource: resource, attempts: attempts);
    }

    SyncTelemetry.fullSyncStarted();

    try {
      final hasAuth = await _apiClient.hasAuthSession();

      if (hasAuth) {
        try {
          // Flush any messages typed while offline
          await flushPendingCaseMessages();

          await _pushProfileUpdate();

          if (!_profileNeedsPush) {
            final profileJson = await _apiClient.getProfile();
            profile = ProfileApiCodec.userProfileFromApi(
              profileJson,
              fallbackLocale: localeCode,
            );
            localeCode = profile?.preferredLanguage ?? localeCode;
            _clampShippedLocale();
          } else {
            SyncTelemetry.profileSkippedRemotePull(
              reason: 'pending_local_patch',
            );
          }

          final remoteCasesRaw = await _apiClient.listCases();
          final remoteCases =
              remoteCasesRaw.map(CaseApiCodec.studentCaseFromApi).toList();
          final (mergedCases, caseStats) = mergeCasesRemoteWithLocal(
              remoteCases, List<StudentCase>.of(_cases));
          SyncTelemetry.casesMerged(
            remoteCount: caseStats.remoteCount,
            localWinCount: caseStats.localWinCount,
            keptLocalOnlyCount: caseStats.keptLocalOnlyCount,
          );
          _cases
            ..clear()
            ..addAll(mergedCases);

          final remoteSavedItems = await _apiClient.listSavedItems();
          final remoteSavedParsed =
              remoteSavedItems.map(SavedItemApiCodec.fromApi).toList();
          final (mergedSaved, unionExtraLocals) = mergeSavedItemsUnion(
            remoteSavedParsed,
            List<SavedItem>.of(_savedItems),
            tombstones: Set<String>.of(_savedItemTombstones),
          );
          SyncTelemetry.savedItemsMerged(unionExtraLocals: unionExtraLocals);
          _savedItems
            ..clear()
            ..addAll(mergedSaved);

          _remoteSavedItemIds
            ..clear()
            ..addEntries(
              remoteSavedItems.whereType<Map<String, dynamic>>().map(
                    (item) => MapEntry(
                      _savedItemKey(
                        SavedItemApiCodec.parseType(item['type'] as String?) ??
                            SavedItemType.field,
                        item['itemId'] as String? ?? '',
                      ),
                      item['id'] as String? ?? '',
                    ),
                  ),
            );

          for (final item in _savedItems) {
            final key = _savedItemKey(item.type, item.itemId);
            final id = _remoteSavedItemIds[key];
            if (id == null || id.isEmpty) {
              unawaited(_createRemoteSavedItem(item));
            }
          }
        } catch (error, stack) {
          authSyncFailed = true;
          if (error is DioException && error.response?.statusCode == 429) {
            _syncBackoffUntil = DateTime.now().add(const Duration(seconds: 60));
            syncError = userFacingSyncError(error, localeCode);
          } else {
            syncError = userFacingSyncError(error, localeCode);
            safeRecordError(
              error,
              stack,
              reason: 'syncRemoteData.auth',
              domain: CrashlyticsObsDomain.sync,
              operation: 'sync_remote_data_auth',
            );
          }
        }
      } else {
        SyncTelemetry.profileSkippedRemotePull(reason: 'guest_no_auth_token');
      }

      catalogOutcomes.add(await syncCatalogResource<FieldModel>(
        _apiClient,
        'fields',
        fields,
        FieldModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      ));
      catalogOutcomes.add(await syncCatalogResource<CountryModel>(
        _apiClient,
        'countries',
        countries,
        CountryModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      ));
      catalogOutcomes.add(await syncCatalogResource<InstitutionModel>(
        _apiClient,
        'institutions',
        institutions,
        InstitutionModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      ));
      catalogOutcomes.add(await syncCatalogResource<ProgramModel>(
        _apiClient,
        'programs',
        programs,
        ProgramModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      ));
      catalogOutcomes.add(await syncCatalogResource<ScholarshipModel>(
        _apiClient,
        'scholarships',
        scholarships,
        ScholarshipModel.fromJson,
        onHiveFallback: onCatalogHiveFallback,
      ));
      _applyMvpCountryLock();

      // KPB-166: editorial content that used to be frozen in the app bundle.
      // Service offers carry their PRICES, so leaving them bundled meant a store
      // release (7–14 days) to fix a price. Same generic path as the catalog:
      // retries, Hive cache, offline fallback, and an empty response is a no-op.
      // Non-fatal on purpose — a content outage must not fail the whole sync and
      // strand the user on a "sample data" banner; the bundled seed still shows.
      try {
        await syncCatalogResource<ServiceOffer>(
          _apiClient,
          'service-offers',
          serviceOffers,
          ContentApiCodec.serviceOfferFromApi,
          fetch: _apiClient.listContent,
          cacheKey: 'content:service-offers',
          onHiveFallback: onCatalogHiveFallback,
        );
      } catch (_) {
        // Keep whatever we already had (cache or bundled seed).
      }
      try {
        await syncCatalogResource<SupportDestination>(
          _apiClient,
          'support-destinations',
          supportDestinations,
          ContentApiCodec.supportDestinationFromApi,
          fetch: _apiClient.listContent,
          cacheKey: 'content:support-destinations',
          onHiveFallback: onCatalogHiveFallback,
        );
      } catch (_) {
        // Keep whatever we already had (cache or bundled seed).
      }

      // We only reach here if every catalog resource resolved from the API or
      // the offline cache (a failed fetch with no cache throws out of this
      // block). So we are no longer showing the bundled sample catalog — but
      // "resolved" covers two different truths, and the fold tells them apart:
      // all-live → no banner, any resource replayed from Hive → the discreet
      // "offline, data from the last load" banner.
      _setCatalogDataState(aggregateCatalogDataState(catalogOutcomes));

      lastSyncedAt = DateTime.now();
      if (!authSyncFailed) {
        syncError = null;
      }
      _persist();
      SyncTelemetry.fullSyncFinished(
        success: !authSyncFailed,
        elapsed: DateTime.now().difference(syncStarted),
        catalogHiveFallbackCount: catalogHiveFallbackCount,
      );
    } catch (error, stack) {
      if (error is DioException && error.response?.statusCode == 429) {
        _syncBackoffUntil = DateTime.now().add(const Duration(seconds: 60));
      }
      // The sync died — typically a catalog resource that could be fetched
      // neither from the service nor from a snapshot. A failed run can never
      // upgrade the state; it degrades it to the worst thing that is still
      // *true*: fake bundled rows if no sync ever landed real ones, otherwise
      // real-but-dated rows still held in memory.
      _setCatalogDataState(
        _catalogEverLoadedRealRows
            ? CatalogDataState.offline
            : CatalogDataState.sample,
      );
      syncError = userFacingSyncError(error, localeCode);
      if (error is! DioException || error.response?.statusCode != 429) {
        safeRecordError(
          error,
          stack,
          reason: 'syncRemoteData',
          domain: CrashlyticsObsDomain.sync,
          operation: 'sync_remote_data',
        );
      }
      SyncTelemetry.fullSyncFinished(
        success: false,
        elapsed: DateTime.now().difference(syncStarted),
        catalogHiveFallbackCount: catalogHiveFallbackCount,
      );
    } finally {
      isSyncing = false;
      update();
    }
  }

  /// Commits a freshly computed [CatalogDataState] and the data the banner
  /// needs with it. No `update()` here: every caller sits inside
  /// [syncRemoteData], whose `finally` already notifies the shell — which is
  /// what makes the banner appear and disappear without a restart.
  void _setCatalogDataState(CatalogDataState state) {
    catalogDataState = state;
    if (state != CatalogDataState.sample) {
      _catalogEverLoadedRealRows = true;
    }
    // Only the offline banner shows an age, and the cache's own `lastSyncedAt`
    // is exactly the write time of the snapshot we just replayed (a fallback
    // writes nothing, so the stamp is still the last real sync's).
    catalogSnapshotAt =
        state == CatalogDataState.offline && CatalogCacheService.isInitialized
            ? CatalogCacheService.instance.lastSyncedAt
            : null;
  }

  /// Restricts the catalog to the MVP destination countries. Drops any
  /// country/institution/program outside the launch scope so a stale Hive cache
  /// or a broader remote payload can't surface V1.1+ data.
  ///
  /// LES BOURSES SONT EXEMPTÉES, délibérément. Une bourse est une information,
  /// pas une offre de service : masquer un financement vérifié parce que KPB n'a
  /// pas encore de formations dans ce pays prive l'étudiant sans rien protéger.
  ///
  /// Mesuré le 14/08/2026 sur les 11 fiches vérifiées publiées en production :
  /// le filtre en cachait 6, dont l'Université de Pretoria (clôture au 30/09) et
  /// les deux UWC africaines. L'échappatoire « countryId vide », censée garder
  /// les bourses transfrontalières, ne se déclenchait jamais — le catalogue
  /// vérifié attribue un pays à chaque fiche.
  void _applyMvpCountryLock() {
    if (!AppConfig.mvpOnly) return;
    countries.retainWhere((c) => isMvpCountryId(c.id));
    institutions.retainWhere((i) => isMvpCountryId(i.countryId));
    programs.retainWhere((p) => isMvpCountryId(p.countryId));
  }

  /// Couture de test pour [_applyMvpCountryLock].
  ///
  /// La garantie qui compte — les BOURSES survivent au verrou — est vérifiée
  /// sur les identifiants pays RÉELS du catalogue publié
  /// (test/core/data/mvp_lock_scholarships_test.dart), et non sur une liste
  /// recopiée : une version antérieure du verrou supprimait 23 fiches sur 34,
  /// dont toutes les bourses africaines, et aucun test ne le voyait.
  @visibleForTesting
  void applyMvpCountryLockForTest() => _applyMvpCountryLock();

  List<StudentCase> casesByType(CaseType? filter) {
    if (filter == null) return cases;
    return cases.where((item) => item.type == filter).toList();
  }

  FieldModel? fieldByIdOrNull(String id) =>
      fields.firstWhereOrNull((item) => item.id == id);
  CountryModel? countryByIdOrNull(String id) {
    final normalized = normalizeCountryId(id);
    return countries.firstWhereOrNull(
      (item) => item.id == id || item.id == normalized,
    );
  }

  InstitutionModel? institutionByIdOrNull(String id) =>
      institutions.firstWhereOrNull((item) => item.id == id);
  ProgramModel? programByIdOrNull(String id) =>
      programs.firstWhereOrNull((item) => item.id == id);
  ScholarshipModel? scholarshipByIdOrNull(String id) =>
      scholarships.firstWhereOrNull((item) => item.id == id);

  /// Non-null convenience accessors — prefer the OrNull variants for new code.
  FieldModel fieldById(String id) => fields.firstWhere((item) => item.id == id);
  CountryModel countryById(String id) {
    final match = countryByIdOrNull(id);
    if (match != null) return match;
    throw StateError('Country not found: $id');
  }

  Future<CountryModel> loadCountryDetail(String countryKey) async {
    final normalized = normalizeCountryId(countryKey);
    final cached = _countryDetailCache[normalized];
    if (cached?.eligibilityQuiz != null) return cached!;

    final base = countryByIdOrNull(normalized) ?? countryByIdOrNull(countryKey);

    if (AppConfig.enableRemoteSync) {
      try {
        final json = await _apiClient.getCountryDetail(normalized);
        final detail = CountryModel.fromJson(json);
        _countryDetailCache[normalized] = detail;
        final idx = countries.indexWhere(
          (c) => c.id == detail.id || c.id == normalized,
        );
        if (idx >= 0) {
          countries[idx] = detail;
        }
        update();
        return detail;
      } catch (_) {
        if (base != null) return base;
        rethrow;
      }
    }

    if (base != null) return base;
    throw StateError('Country not found: $countryKey');
  }

  // submitCountryQuiz removed (KPB-62): the explore quiz now scores via the
  // single client-side EligibilityEngine (see EligibilityQuizScreen), so there
  // is no backend round-trip or second scorer.
  InstitutionModel institutionById(String id) =>
      institutions.firstWhere((item) => item.id == id);
  ProgramModel programById(String id) =>
      programs.firstWhere((item) => item.id == id);
  ScholarshipModel scholarshipById(String id) =>
      scholarships.firstWhere((item) => item.id == id);

  AppSnapshot get _snapshot => AppSnapshot(
        localeCode: localeCode,
        hasSeenIntro: hasSeenIntro,
        isGuestMode: isGuestMode,
        isAppLockEnabled: isAppLockEnabled,
        dataSaverEnabled: dataSaverEnabled,
        analyticsOptOut: analyticsOptOut,
        analyticsConsentDecided: analyticsConsentDecided,
        hasCompletedOnboarding: hasCompletedOnboarding,
        themeMode: themeMode,
        profile: profile,
        savedItems: _savedItems,
        savedItemTombstones: _savedItemTombstones,
        cases: _cases,
        orientationHistory: _orientationHistory,
        searchHistory: _searchHistory,
        pendingOrientationAnswers: _pendingOrientationAnswers,
        pendingOrientationQuestionIndex: pendingOrientationQuestionIndex,
        fields: const [],
        countries: const [],
        institutions: const [],
        programs: const [],
        scholarships: const [],
        purchasedCourseIds: _purchasedCourseIds,
        reviewCredits: _reviewCredits,
        completedRoadmapSteps: _completedRoadmapSteps,
        profileNeedsPush: _profileNeedsPush,
        onboardingStep: onboardingStep,
        onboardingSkipped: onboardingSkipped,
        caseLastReadAt: _caseLastReadAt.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
        reviewedCaseIds: _reviewedCaseIds,
      );

  void _persist() {
    unawaited(_repository.saveSnapshot(_snapshot));
  }

  Future<void> _pushProfileUpdate() async {
    if (!AppConfig.enableRemoteSync) {
      _profileNeedsPush = false;
      return;
    }
    if (profile == null) return;
    if (!await _apiClient.hasAuthSession()) {
      _profileNeedsPush = false;
      _persist();
      return;
    }
    if (!ConnectivityService.instance.isOnline) {
      _profileNeedsPush = true;
      _persist();
      return;
    }
    try {
      await _apiClient.updateProfile(_userProfilePayload(profile!));
      _profileNeedsPush = false;
      _persist();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'pushProfileUpdate',
        domain: CrashlyticsObsDomain.profile,
        operation: 'push_profile_update',
      );
      _profileNeedsPush = true;
      _persist();
    }
  }

  Future<void> _createRemoteCase(StudentCase localCase) async {
    if (!AppConfig.enableRemoteSync) return;
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
      // Network blip — queue it. The connectivity listener will retry.
      await CaseMessageOutbox.instance.enqueue(
        caseId: caseId,
        body: text,
        senderName: senderName,
      );
    }
  }

  /// Flush the offline message queue. Called on connectivity-restored events.
  Future<void> flushPendingCaseMessages() async {
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

  /// Link the current profile to OneSignal (external id + targeting tags).
  /// Safe to call repeatedly; a no-op when OneSignal isn't configured.
  Future<void> syncOneSignalIdentity() async {
    final current = profile;
    if (current == null) return;
    await OneSignalService.instance.login(
      // Pas d'`email:` — OneSignal ne recevait cette adresse que pour ses
      // propres campagnes courriel, que nous n'utilisons pas (Resend et Mautic
      // s'en chargent). Le service l'ignore désormais ; ne pas la lui donner
      // non plus, sinon la prochaine lecture croira qu'elle part.
      userId: current.id,
      tags: oneSignalTargetingTags(current, localeCode: localeCode),
    );
  }

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

  Future<void> _createRemoteSavedItem(SavedItem item) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final response = await _apiClient.createSavedItem(<String, dynamic>{
        'type': item.type.name,
        'itemId': item.itemId,
      });
      final savedId = response['id'] as String?;
      if (savedId != null && savedId.isNotEmpty) {
        _remoteSavedItemIds[_savedItemKey(item.type, item.itemId)] = savedId;
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'createRemoteSavedItem',
        domain: CrashlyticsObsDomain.savedItems,
        operation: 'create_remote_saved_item',
      );
    }
  }

  Future<void> _deleteRemoteSavedItem(SavedItem item) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final key = _savedItemKey(item.type, item.itemId);
      final savedId = _remoteSavedItemIds[key];
      if (savedId != null && savedId.isNotEmpty) {
        await _apiClient.deleteSavedItem(savedId);
        _remoteSavedItemIds.remove(key);
        // Server confirmed the delete — tombstone no longer needed.
        _savedItemTombstones.remove(key);
        _persist();
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'deleteRemoteSavedItem',
        domain: CrashlyticsObsDomain.savedItems,
        operation: 'delete_remote_saved_item',
      );
    }
  }

  String _savedItemKey(SavedItemType type, String itemId) =>
      '${type.name}:$itemId';

  Map<String, dynamic> _userProfilePayload(UserProfile profile) {
    return <String, dynamic>{
      'fullName': profile.fullName,
      // Pas d'`email` : c'est l'identité d'authentification, le serveur ne
      // l'écrit jamais. L'envoyer ne servait à rien et, validé `@IsEmail()`
      // côté serveur, un email vide (profil créé par « Passer ») ou mal tapé
      // faisait échouer le PATCH ENTIER en 400 — le patch restait en attente
      // et `syncRemoteData` sautait à jamais le rapatriement du profil, donc
      // l'email du compte n'était jamais restauré.
      // Téléphone et WhatsApp ne sont PAS persistés localement (RGPD) : après
      // un redémarrage à froid ils valent '' jusqu'au premier GET du profil.
      // Les envoyer vides effaçait le numéro côté serveur.
      if (profile.phone.isNotEmpty) 'phone': profile.phone,
      if (profile.whatsApp.isNotEmpty) 'whatsApp': profile.whatsApp,
      'countryOfResidence': profile.countryOfResidence,
      'preferredLanguage': profile.preferredLanguage,
      'currentLevel': profile.currentLevel,
      'targetLevel': profile.targetLevel,
      'languageLevel': profile.languageLevel,
      'fieldIds': profile.fieldIds,
      'targetCountryIds': profile.targetCountryIds,
      // Deux champs, deux clés. Cette ligne valait
      // `profile.bacSeries ?? profile.gradeRange` : faute de colonne
      // `bacSeries` côté serveur, la série du bac voyageait DANS la moyenne
      // académique. Choisir « D » écrivait donc `gradeRange = 'D'`, et la
      // synchronisation suivante rapatriait « D » comme moyenne — la vraie
      // valeur était perdue sans que rien ne le signale. La colonne existe
      // depuis la migration 20260829140000_profile_bac_series.
      'gradeRange': profile.gradeRange,
      'bacSeries': profile.bacSeries,
      'annualTuitionBudgetEur': profile.annualTuitionBudgetEur,
      'preferredCurrency': profile.preferredCurrency,
      'wantsScholarshipSupport': profile.wantsScholarshipSupport,
      'scholarshipNewsletterOptIn': profile.wantsScholarshipNewsletter,
      'disabledNotificationTypes': profile.disabledNotificationTypes,
      'availableDocuments': profile.availableDocuments,
      if (profile.monthlyBudgetEur != null)
        'monthlyBudgetEur': profile.monthlyBudgetEur,
      if (profile.aiConsentedAt != null)
        'aiConsentedAt': profile.aiConsentedAt!.toIso8601String(),
      if (profile.birthDate != null)
        'birthDate': profile.birthDate!.toIso8601String(),
      if (profile.guardianName != null) 'guardianName': profile.guardianName,
      if (profile.guardianContact != null)
        'guardianContact': profile.guardianContact,
      if (profile.guardianConsentedAt != null)
        'guardianConsentedAt': profile.guardianConsentedAt!.toIso8601String(),
    };
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
