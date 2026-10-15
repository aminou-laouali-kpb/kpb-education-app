import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../../core/models/live_scholarships_query.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/scholarships_offline_cache.dart';

/// Pourquoi la liste de bourses est vide, quand elle l'est.
///
/// Avant, il n'y avait qu'un `String? error` rempli par `exception.toString()`,
/// et l'écran en déduisait « problème de connexion » quelle que soit la cause.
/// Sur l'onglet du MILIEU — celui que l'app met en avant — un visiteur en mode
/// invité recevait donc un 401 (l'index des bourses exige une session) affiché
/// comme une panne de réseau, avec un unique bouton « Réessayer » qui ne pouvait
/// par construction jamais aboutir. Message faux ET impasse, sur la surface la
/// plus commerciale du produit.
///
/// Distinguer les deux causes est tout l'objet de ce type. Il n'en existe
/// délibérément que deux : « il faut un compte » et « autre chose a échoué ».
/// Tout le reste — 500, timeout, DNS, JSON illisible — relève honnêtement du
/// second, parce que l'app ne peut rien en dire de plus utile à l'utilisateur.
enum ScholarshipsFailure {
  /// Le serveur a répondu 401 : l'index des bourses est réservé aux comptes.
  /// Le seul remède est de créer un compte, pas de réessayer.
  authRequired,

  /// Panne réseau, erreur serveur, réponse illisible. « Réessayer » a un sens.
  connection,
}

/// Feature-scoped state for the live scholarship acquisition surface.
///
/// The current API uses offset pagination. The controller intentionally keeps
/// that contract while treating a short page as the fallback end-of-list
/// signal, so it also works with deployments that do not yet expose `total` or
/// cursor metadata.
class ScholarshipsController extends ChangeNotifier {
  ScholarshipsController({
    required AppApiClient apiClient,
    required this.lang,
    this.level,
    this.fieldIds,
    this.pageSize = 20,
    ScholarshipsOfflineCache? offlineCache,
    DateTime Function()? clock,
  })  : _apiClient = apiClient,
        _offlineCache = offlineCache,
        _clock = clock ?? DateTime.now;

  final AppApiClient _apiClient;

  /// Null : l'instance partagée (Hive). Lue à l'usage, pour qu'un test puisse
  /// la remplacer après la construction de l'écran.
  final ScholarshipsOfflineCache? _offlineCache;
  final DateTime Function() _clock;

  ScholarshipsOfflineCache get _cache =>
      _offlineCache ?? ScholarshipsOfflineCache.instance;
  final String lang;
  final String? level;
  final List<String>? fieldIds;
  final int pageSize;

  final List<LiveScholarshipModel> _items = <LiveScholarshipModel>[];
  final Set<String> _alertedScholarshipIds = <String>{};

  List<LiveScholarshipModel> get items => List.unmodifiable(_items);
  Set<String> get alertedScholarshipIds =>
      Set.unmodifiable(_alertedScholarshipIds);

  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String? error;

  /// La CAUSE de [error], quand il y en a une. Toujours posée en même temps que
  /// [error] et remise à null en même temps qu'elle — les deux champs décrivent
  /// le même événement, l'un pour la journalisation, l'autre pour l'écran.
  ScholarshipsFailure? failure;

  String fundingFilter = 'all';

  /// Statuts retenus par la feuille « Filtrer » ; vide = tous.
  Set<ScholarshipListStatus> statusFilter = <ScholarshipListStatus>{};

  /// Tri choisi (« Pertinence » par défaut : l'ordre d'avant).
  ScholarshipListSort sort = ScholarshipListSort.relevance;

  /// Le total RÉEL servi par le serveur (`total` de l'enveloppe), ou null
  /// quand on ne le connaît pas (backend ancien, données hors ligne).
  int? total;

  /// Non nul : la liste affichée vient du disque, faute de réseau, et date de
  /// cet instant (« Hors ligne — données du … »).
  DateTime? offlineSince;

  /// Nombre de filtres actifs choisis par l'élève (badge du bouton « Filtrer »).
  int get activeFilterCount =>
      statusFilter.length + (fundingFilter == 'all' ? 0 : 1);

  /// Vrai quand le serveur ignore `status` (backend antérieur au chantier I) :
  /// le filtre est alors appliqué ici, page par page.
  bool _filterStatusLocally = false;

  /// True once the profile-derived criteria ([level], [fieldIds]) have been
  /// dropped from the query because they matched nothing. The screen must
  /// disclose it: the visible list is then the whole catalog, not a
  /// profile-matched selection.
  bool profileFiltersRelaxed = false;

  /// Sticky counterpart of [profileFiltersRelaxed], set only by
  /// [clearAllFilters]. An automatic relaxation is re-evaluated on every reload
  /// (the catalog may have been curated since); an explicit user choice is not.
  bool _userDroppedProfileFilters = false;

  int _offset = 0;
  int _requestGeneration = 0;

  /// Whether this controller has profile-derived criteria that could hide
  /// results. They come from the saved profile, not from a visible control, so
  /// the student cannot clear them from the filter row.
  bool get hasProfileFilters =>
      (level ?? '').trim().isNotEmpty || (fieldIds?.isNotEmpty ?? false);

  /// Criteria actually sent to the API, honouring [profileFiltersRelaxed].
  String? get _effectiveLevel => profileFiltersRelaxed ? null : level;
  List<String>? get _effectiveFieldIds =>
      profileFiltersRelaxed ? null : fieldIds;

  Future<void> loadInitial() async {
    final generation = ++_requestGeneration;
    loading = true;
    loadingMore = false;
    error = null;
    failure = null;
    hasMore = true;
    _offset = 0;
    // Re-attempt the profile criteria on every reload so a pull-to-refresh
    // picks up newly curated scholarships instead of staying unfiltered forever.
    profileFiltersRelaxed = _userDroppedProfileFilters;
    notifyListeners();

    try {
      var page = await _fetch(offset: 0);
      if (generation != _requestGeneration) return;

      // Graceful degradation: the profile criteria are a ranking preference, not
      // a reason to show nothing. `relatedFieldIds` is empty on every
      // server-side write path until an admin curates it, so a profile with a
      // field of interest can filter the whole published catalog out. Retry once
      // without those criteria rather than claiming there is no scholarship.
      // Server-side relaxation covers up-to-date deployments; this keeps the
      // screen working against a backend that still filters strictly.
      if (page.items.isEmpty && !profileFiltersRelaxed && hasProfileFilters) {
        profileFiltersRelaxed = true;
        page = await _fetch(offset: 0);
        if (generation != _requestGeneration) return;
      }

      _filterStatusLocally =
          statusFilter.isNotEmpty && !page.serverAppliedQuery;
      final parsed = _visible(_parse(page.items));
      _items
        ..clear()
        ..addAll(parsed);
      _rememberAlerts(parsed, replace: true);
      _offset = page.items.length;
      hasMore = page.hasMore ?? page.items.length >= pageSize;
      // Un total que le serveur n'a pas calculé pour CE filtre (statut ignoré
      // par un backend ancien) serait faux : on ne l'affiche pas.
      total = _filterStatusLocally ? null : page.total;
      offlineSince = null;
      unawaited(
        _cache.writeFirstPage(
          _cacheSignature,
          page.items,
          total: total,
          fetchedAt: _clock(),
        ),
      );

      try {
        final alerts = await _apiClient.fetchScholarshipAlerts();
        if (generation == _requestGeneration) {
          _alertedScholarshipIds
            ..clear()
            ..addAll(alerts);
        }
      } catch (_) {
        // The scholarship catalog remains useful if alert state is temporarily
        // unavailable during a staged backend rollout.
      }
    } catch (exception) {
      if (generation == _requestGeneration) {
        final cause = _classify(exception);
        // Hors ligne : la dernière première page reçue pour ces filtres, datée,
        // plutôt qu'un écran d'erreur. Jamais sur un 401 — l'invité doit voir
        // la porte d'inscription, pas les bourses d'un compte précédent.
        final cached = cause == ScholarshipsFailure.connection
            ? await _cache.readFirstPage(_cacheSignature)
            : null;
        if (generation != _requestGeneration) return;
        final fromDisk = cached == null ? null : _visible(_parse(cached.items));
        if (cached != null && fromDisk != null && fromDisk.isNotEmpty) {
          _items
            ..clear()
            ..addAll(fromDisk);
          _rememberAlerts(fromDisk, replace: true);
          offlineSince = cached.fetchedAt;
          total = null;
          hasMore = false;
        } else {
          error = exception.toString();
          failure = cause;
        }
      }
    } finally {
      if (generation == _requestGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Une page de `GET /scholarships` avec TOUS les critères courants.
  Future<LiveScholarshipsPage> _fetch({required int offset}) =>
      _apiClient.fetchLiveScholarshipsPage(
        lang: lang,
        level: _effectiveLevel,
        fieldIds: _effectiveFieldIds,
        fundingType: fundingFilter == 'all' ? null : fundingFilter,
        statuses: statusFilter.isEmpty ? null : statusFilter,
        sort: sort,
        limit: pageSize,
        offset: offset,
      );

  /// Ce que la liste montre de [items] : jamais une fiche dont la date limite
  /// CONFIRMÉE est passée (le cache peut dater de plusieurs jours), et le
  /// filtre de statut quand le serveur ne l'a pas appliqué.
  List<LiveScholarshipModel> _visible(List<LiveScholarshipModel> items) {
    final now = _clock();
    return items.where((item) {
      if (isScholarshipExpired(item, now: now)) return false;
      if (!_filterStatusLocally) return true;
      final status = scholarshipListStatusOf(item, now: now);
      return status != null && statusFilter.contains(status);
    }).toList(growable: false);
  }

  void _rememberAlerts(
    List<LiveScholarshipModel> items, {
    bool replace = false,
  }) {
    if (replace) _alertedScholarshipIds.clear();
    _alertedScholarshipIds.addAll(
      items.where((item) => item.isAlertEnabled == true).map((item) => item.id),
    );
  }

  /// La clé disque de la première page : une par combinaison de critères, pour
  /// ne jamais montrer hors ligne une liste filtrée autrement que l'écran ne
  /// l'annonce.
  String get _cacheSignature => <String>[
        lang,
        fundingFilter,
        (statusFilter.map((status) => status.wire).toList()..sort()).join(','),
        sort.wire,
        if (_userDroppedProfileFilters || !hasProfileFilters)
          'profile:none'
        else
          'profile:${level ?? ''}:${(fieldIds ?? const <String>[]).join(',')}',
      ].join('|');

  /// 401 ⇒ il faut un compte. Tout le reste ⇒ « réessayez ».
  ///
  /// La borne est étroite EXPRÈS. Ranger le 403 ici serait tentant — il ressemble
  /// à un problème de compte — mais un 403 signifie « connecté et refusé »,
  /// c'est-à-dire un compte existant, et proposer d'en créer un serait le
  /// remplacement d'un mensonge par un autre. On ne classe donc que ce que le
  /// serveur affirme sans ambiguïté.
  static ScholarshipsFailure _classify(Object exception) {
    if (exception is DioException && exception.response?.statusCode == 401) {
      return ScholarshipsFailure.authRequired;
    }
    return ScholarshipsFailure.connection;
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || error != null) return;
    if (offlineSince != null) return;
    final generation = _requestGeneration;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await _fetch(offset: _offset);
      if (generation != _requestGeneration) return;
      final knownIds = _items.map((item) => item.id).toSet();
      final parsed = _visible(
        _parse(page.items),
      ).where((item) => knownIds.add(item.id)).toList(growable: false);
      _items.addAll(parsed);
      _rememberAlerts(parsed);
      // Advance by the server page size rather than only unique rows; otherwise
      // a duplicate page can cause a loop against a drifting result set.
      _offset += page.items.length;
      hasMore = page.items.isNotEmpty &&
          (page.hasMore ?? page.items.length >= pageSize);
    } catch (_) {
      // A failed incremental page must not replace already useful results with
      // the full-page connection error. A later scroll/refresh can retry.
      hasMore = false;
    } finally {
      if (generation == _requestGeneration) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> changeFundingFilter(String value) async {
    if (value == fundingFilter) return;
    fundingFilter = value;
    // A new funding filter is a fresh question: re-apply the profile criteria so
    // a relaxation carried over from the previous filter does not silently make
    // this listing unfiltered too.
    _userDroppedProfileFilters = false;
    await loadInitial();
  }

  /// Escape hatch offered by the empty state: drop every filter (funding +
  /// profile-derived criteria) and reload. Lets a student reach the catalog
  /// instead of being stuck behind criteria they cannot see.
  Future<void> clearAllFilters() async {
    fundingFilter = 'all';
    statusFilter = <ScholarshipListStatus>{};
    _userDroppedProfileFilters = true;
    await loadInitial();
  }

  /// La feuille « Filtrer » a été validée : UNE requête, quel que soit le
  /// nombre de cases changées. Rien ne part si rien n'a changé.
  Future<void> applyFilters({
    required Set<ScholarshipListStatus> statuses,
    required String funding,
  }) async {
    if (setEquals(statuses, statusFilter) && funding == fundingFilter) return;
    statusFilter = Set<ScholarshipListStatus>.of(statuses);
    if (funding != fundingFilter) {
      fundingFilter = funding;
      // Même règle que [changeFundingFilter] : nouvelle question, critères du
      // profil réappliqués.
      _userDroppedProfileFilters = false;
    }
    await loadInitial();
  }

  Future<void> changeSort(ScholarshipListSort value) async {
    if (value == sort) return;
    sort = value;
    await loadInitial();
  }

  List<LiveScholarshipModel> _parse(List<dynamic> raw) => raw
      .whereType<Map>()
      .map((item) =>
          LiveScholarshipModel.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}
