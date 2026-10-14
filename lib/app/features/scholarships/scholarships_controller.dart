import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';

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
  }) : _apiClient = apiClient;

  final AppApiClient _apiClient;
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
      // Keep the first request byte-for-byte compatible with the pre-pagination
      // client call. This matters for older servers and existing test doubles.
      var raw = await _apiClient.fetchLiveScholarships(
        lang: lang,
        level: _effectiveLevel,
        fieldIds: _effectiveFieldIds,
        fundingType: fundingFilter == 'all' ? null : fundingFilter,
      );
      if (generation != _requestGeneration) return;

      // Graceful degradation: the profile criteria are a ranking preference, not
      // a reason to show nothing. `relatedFieldIds` is empty on every
      // server-side write path until an admin curates it, so a profile with a
      // field of interest can filter the whole published catalog out. Retry once
      // without those criteria rather than claiming there is no scholarship.
      // Server-side relaxation covers up-to-date deployments; this keeps the
      // screen working against a backend that still filters strictly.
      if (raw.isEmpty && !profileFiltersRelaxed && hasProfileFilters) {
        profileFiltersRelaxed = true;
        raw = await _apiClient.fetchLiveScholarships(
          lang: lang,
          level: null,
          fieldIds: null,
          fundingType: fundingFilter == 'all' ? null : fundingFilter,
        );
        if (generation != _requestGeneration) return;
      }

      final parsed = _parse(raw);
      _items
        ..clear()
        ..addAll(parsed);
      _alertedScholarshipIds
        ..clear()
        ..addAll(
          parsed
              .where((item) => item.isAlertEnabled == true)
              .map((item) => item.id),
        );
      _offset = parsed.length;
      hasMore = raw.length >= pageSize;

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
        error = exception.toString();
        failure = _classify(exception);
      }
    } finally {
      if (generation == _requestGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

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
    final generation = _requestGeneration;
    loadingMore = true;
    notifyListeners();
    try {
      final raw = await _apiClient.fetchLiveScholarships(
        lang: lang,
        level: _effectiveLevel,
        fieldIds: _effectiveFieldIds,
        fundingType: fundingFilter == 'all' ? null : fundingFilter,
        limit: pageSize,
        offset: _offset,
      );
      if (generation != _requestGeneration) return;
      final knownIds = _items.map((item) => item.id).toSet();
      final parsed = _parse(raw)
          .where((item) => knownIds.add(item.id))
          .toList(growable: false);
      _items.addAll(parsed);
      _alertedScholarshipIds.addAll(
        parsed
            .where((item) => item.isAlertEnabled == true)
            .map((item) => item.id),
      );
      // Advance by the server page size rather than only unique rows; otherwise
      // a duplicate page can cause a loop against a drifting result set.
      _offset += raw.length;
      hasMore = raw.length >= pageSize && raw.isNotEmpty;
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
    _userDroppedProfileFilters = true;
    await loadInitial();
  }

  List<LiveScholarshipModel> _parse(List<dynamic> raw) => raw
      .whereType<Map>()
      .map((item) =>
          LiveScholarshipModel.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}
