import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../navigation/shell_tabs.dart';
import '../services/analytics_service.dart';
import '../navigation/app_boot_screen.dart';
import '../ui/app_tokens.dart';
import '../ui/kpb_haptics.dart';
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
import '../services/push_service.dart';
import '../services/sync_conflict_merge.dart';
import '../services/sync_telemetry.dart';
import '../services/transient_retry.dart';
import '../services/auth_service.dart';
import '../services/success_lab_cache_service.dart';
import '../services/success_lab_outbox.dart';
import '../ui/components/kpb_toast.dart';

part 'app_controller/search.dart';
part 'app_controller/roadmap.dart';
part 'app_controller/commercial.dart';
part 'app_controller/parcours.dart';
part 'app_controller/academy.dart';
part 'app_controller/referral_credits.dart';
part 'app_controller/session.dart';
part 'app_controller/preferences.dart';
part 'app_controller/saved_items.dart';
part 'app_controller/orientation.dart';
part 'app_controller/cases.dart';
part 'app_controller/catalog_sync.dart';

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
        _ReferralCreditsMixin,
        _SessionMixin,
        _PreferencesMixin,
        _SavedItemsMixin,
        _OrientationMixin,
        _CasesMixin,
        _CatalogSyncMixin {
  AppController({required super.repository, super.apiClient}) {
    // Le « Mode données réduites » coupe aussi les animations
    // (KpbMotion.of) : les tokens lisent ce réglage par cette sonde.
    KpbMotion.dataSaverProbe = () => dataSaverEnabled;
  }

  static const int shellTabCount = StudentShellTab.count;

  /// Every state change goes through `update()`: drop the memoized search
  /// scorer so the next read sees the new catalogue / profile.
  @override
  void update([List<Object>? ids, bool condition = true]) {
    _invalidateSearchCache();
    super.update(ids, condition);
  }

  /// Mutations persist before (or without) notifying: invalidate there too,
  /// so a read between a mutation and its `update()` is never stale.
  @override
  void _persist() {
    _invalidateSearchCache();
    super._persist();
  }
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

  // ── Implemented by the mixins, used across them ─────────────────────────
  void _applyLocaleToUi();
  void _applyMvpCountryLock();
  void _clampShippedLocale();
  Future<void> _createRemoteCase(StudentCase localCase);
  Future<void> _createRemoteSavedItem(SavedItem item);
  Future<void> _deleteRemoteSavedItem(SavedItem item);
  Future<void> _pushProfileUpdate();
  String _savedItemKey(SavedItemType type, String itemId);
  Map<String, dynamic> _userProfilePayload(UserProfile profile);
  Future<void> flushPendingCaseMessages();
  bool isSaved(SavedItemType type, String itemId);
  Future<void> syncPushIdentity();
  Future<void> syncRemoteData({bool silent = false, bool force = false});

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

  /// The sync currently running, so [finishAuthSession] can wait for it
  /// instead of being silently skipped by the `isSyncing` guard.
  Future<void>? _inFlightSync;
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

  // ── Roadmap Management ───────────────────────────────────────────────────

  // ── Orientation progress persistence ──────────────────────────

  // ── Profile update ──────────────────────────────────────────

  // ── Search ──────────────────────────────────────────────────

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
}

/// Decoded catalogue snapshot, built in a background isolate.
typedef DecodedCatalog = ({
  List<FieldModel> fields,
  List<CountryModel> countries,
  List<InstitutionModel> institutions,
  List<ProgramModel> programs,
  List<ScholarshipModel> scholarships,
});

/// Pure function (no plugin, no Get) so it can run in `Isolate.run`. A corrupt
/// or missing resource decodes to an empty list — the caller then falls back
/// to the bundled sample catalogue, as before.
DecodedCatalog decodeCachedCatalog(Map<String, String?> raws) {
  List<T> decode<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = raws[key];
    if (raw == null) return <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      return decoded.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return <T>[];
    }
  }

  return (
    fields: decode('fields', FieldModel.fromJson),
    countries: decode('countries', CountryModel.fromJson),
    institutions: decode('institutions', InstitutionModel.fromJson),
    programs: decode('programs', ProgramModel.fromJson),
    scholarships: decode('scholarships', ScholarshipModel.fromJson),
  );
}
