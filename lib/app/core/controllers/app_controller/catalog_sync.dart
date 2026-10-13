part of '../app_controller.dart';

/// Synchronisation du catalogue et accès par identifiant.
mixin _CatalogSyncMixin on _AppControllerBase {
  /// Public pull-to-refresh — calls syncRemoteData and returns when done.
  ///
  /// IMPORTANT: do NOT name this `refresh()` — that would shadow
  /// `GetxController.refresh()`, which GetX calls internally to notify
  /// listeners. Naming this `pullToRefresh()` avoids triggering a full sync
  /// every time any widget rebuilds.
  Future<void> pullToRefresh() => syncRemoteData(silent: false, force: true);

  @override
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
        now.difference(_lastSyncAttemptAt!) <
            _AppControllerBase._minSyncInterval) {
      return;
    }

    isSyncing = true;
    final syncDone = Completer<void>();
    _inFlightSync = syncDone.future;
    _lastSyncAttemptAt = now;
    if (!silent) {
      syncError = null;
      update();
    }

    final syncStarted = DateTime.now();
    var catalogHiveFallbackCount = 0;
    var authSyncFailed = false;
    // Où et comment la synchro a échoué, pour `sync_full_complete` : sans ça,
    // un téléphone hors réseau et un serveur en panne se confondaient.
    String? failureStage;
    SyncErrorKind? failureKind;
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
            final profileJson = await retryTransient(_apiClient.getProfile);
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

          final remoteCasesRaw = await retryTransient(_apiClient.listCases);
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
          // Un dossier dont la création distante a échoué gardait son id local
          // (`case-<ms>`) pour toujours, avec le texte « transmise à l'équipe
          // KPB ». On retente à chaque synchro.
          for (final localOnly in mergedCases
              .where((c) => _CasesMixin._localCaseId.hasMatch(c.id))
              .toList()) {
            unawaited(_createRemoteCase(localOnly));
          }

          final remoteSavedItems =
              await retryTransient(_apiClient.listSavedItems);
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
          // Rejoue les suppressions qui n'ont pas atteint le serveur (id
          // distant inconnu au moment du retrait, ou erreur réseau) : le
          // tombstone masquait l'élément ici, mais le serveur le gardait et il
          // réapparaissait après un logout ou sur un autre appareil.
          for (final item in remoteSavedParsed) {
            final key = _savedItemKey(item.type, item.itemId);
            if (_savedItemTombstones.contains(key)) {
              unawaited(_deleteRemoteSavedItem(item));
            }
          }
        } catch (error, stack) {
          authSyncFailed = true;
          failureStage = 'account';
          failureKind = classifySyncError(error);
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
        failureStage: failureStage,
        errorKind: failureKind,
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
        failureStage: 'catalog',
        errorKind: classifySyncError(error),
      );
    } finally {
      isSyncing = false;
      if (!syncDone.isCompleted) syncDone.complete();
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
  @override
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
}
