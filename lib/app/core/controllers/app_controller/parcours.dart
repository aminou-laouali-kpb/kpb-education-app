part of '../app_controller.dart';

mixin _ParcoursMixin on _AppControllerBase {
  List<ParcoursStory> get parcoursStories =>
      List.unmodifiable(_parcoursStories);

  static const _parcoursCacheKey = 'parcours_stories';

  /// Date de la dernière lecture réussie du serveur, gardée à côté de la
  /// liste. Absente d'un cache écrit avant la 59 : il compte alors comme vieux.
  static const _parcoursFetchedAtKey = 'parcours_stories__fetched_at';

  /// Au-delà, une liste relue du cache est redemandée au serveur.
  static const Duration parcoursCacheMaxAge = Duration(hours: 24);

  /// Le cache des parcours a-t-il plus d'un jour (ou pas de date du tout) ?
  bool _parcoursCacheIsOld() {
    if (!CatalogCacheService.isInitialized) return true;
    final stamp = CatalogCacheService.instance.read(_parcoursFetchedAtKey);
    final raw = stamp.isEmpty ? null : stamp.first;
    final at = raw is String ? DateTime.tryParse(raw) : null;
    if (at == null) return true;
    return DateTime.now().difference(at) > parcoursCacheMaxAge;
  }

  /// Distinct field domains (d01..d12) present in the loaded stories, in the
  /// catalog field order — used to render the theme filter chips. Only
  /// non-empty domains appear, so the filter never shows a dead chip.
  List<String> get parcoursFieldIds {
    final present =
        _parcoursStories.map((s) => s.fieldId).whereType<String>().toSet();
    return MockCatalog.fields
        .map((f) => f.id)
        .where(present.contains)
        .toList(growable: false);
  }

  /// The stories after applying the current theme filter + search query.
  List<ParcoursStory> get filteredParcoursStories {
    final q = foldForSearch(parcoursQuery);
    return _parcoursStories.where((s) {
      if (parcoursFieldFilter != null && s.fieldId != parcoursFieldFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      bool has(String v) => foldForSearch(v).contains(q);
      return has(s.title.fr) ||
          has(s.title.en) ||
          has(s.personName) ||
          has(s.role.fr) ||
          has(s.role.en) ||
          has(s.summary.fr) ||
          has(s.summary.en) ||
          s.tags.any(has);
    }).toList(growable: false);
  }

  void setParcoursFieldFilter(String? fieldId) {
    if (parcoursFieldFilter == fieldId) return;
    parcoursFieldFilter = fieldId;
    update();
  }

  void setParcoursQuery(String query) {
    if (parcoursQuery == query) return;
    parcoursQuery = query;
    update();
  }

  /// Hydrate the Parcours stories from the offline cache, then refresh from the
  /// backend catalog when online. Safe to call repeatedly.
  ///
  /// Returns true only when this call actually asked the backend (whatever the
  /// outcome), so a caller can tell a cache-only answer from a network one and
  /// avoid re-issuing a request that just failed.
  Future<bool> fetchParcoursStories({bool force = false}) async {
    // 1. Offline-first: hydrate from Hive cache if we have nothing yet.
    if (_parcoursStories.isEmpty && CatalogCacheService.isInitialized) {
      final cached = CatalogCacheService.instance.read(_parcoursCacheKey);
      if (cached.isNotEmpty) {
        _parcoursStories
          ..clear()
          ..addAll(cached
              .whereType<Map<String, dynamic>>()
              .map(ParcoursStory.fromApi));
        update();
      }
    }

    if (!AppConfig.enableRemoteSync) return false;
    if (isLoadingParcours) return false;
    if (!force && _parcoursStories.isNotEmpty) {
      // Liste déjà en mémoire. Avant la 59, on s'arrêtait là dès que le cache
      // avait rendu quelque chose : une fois la liste gardée sur le téléphone,
      // elle n'était PLUS JAMAIS redemandée (sauf en tirant l'écran), et une
      // histoire retirée ou corrigée n'arrivait jamais (audit avant la 59).
      // On la redemande donc une fois par session, si le cache a plus d'un
      // jour. Un échec compte aussi : on ne relance pas à chaque écran.
      if (_parcoursRefreshAttempted || !_parcoursCacheIsOld()) return false;
    }

    _parcoursRefreshAttempted = true;
    isLoadingParcours = true;
    parcoursError = null;
    update();

    try {
      final items = await _apiClient.listParcoursStories();
      if (items.isNotEmpty) {
        _parcoursStories
          ..clear()
          ..addAll(items);
        if (CatalogCacheService.isInitialized) {
          await CatalogCacheService.instance.write(
            _parcoursCacheKey,
            items.map((s) => s.toJson()).toList(),
          );
          await CatalogCacheService.instance.write(
            _parcoursFetchedAtKey,
            <dynamic>[DateTime.now().toIso8601String()],
          );
        }
      }
    } catch (e, s) {
      if (_parcoursStories.isEmpty) {
        parcoursError = userFacingSyncError(e, localeCode);
      }
      safeRecordError(
        e,
        s,
        reason: 'fetchParcoursStories',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_parcours_stories',
      );
    } finally {
      isLoadingParcours = false;
      update();
    }
    return true;
  }
}
