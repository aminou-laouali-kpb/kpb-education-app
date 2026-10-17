import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/community.dart';
import '../../../core/services/community_store.dart';

/// Une page servie, et sa charge brute quand elle peut aller au cache.
typedef CommunityPageResult = ({
  CommunityPage<CommunityPost> page,
  Map<String, dynamic>? raw,
});

/// Charge la page qui suit [cursor] (`null` : la première).
typedef CommunityPageFetcher = Future<CommunityPageResult> Function(
    String? cursor);

/// Une liste de publications à curseur : fil, recherche, espace d'entité,
/// mes publications.
///
/// - **cache d'abord** : avec une [cacheKey], la première page est relue du
///   disque et montrée tout de suite (datée), puis remplacée par la réponse
///   du serveur ; hors ligne, elle reste, avec « Hors ligne — données du … » ;
/// - **pagination** : [loadMore] demande la page suivante avec le curseur
///   opaque servi, une seule requête à la fois ;
/// - **blocage** : les contenus d'un membre bloqué pendant la session
///   disparaissent sans rechargement ([visibleItems]).
///
/// Ne lève jamais : un échec est rangé dans [failure].
class CommunityListController extends ChangeNotifier {
  CommunityListController({
    required this.fetch,
    this.cacheKey,
    CommunityStore? store,
  }) : _store = store ?? CommunityStore.instance;

  final CommunityPageFetcher fetch;
  final String? cacheKey;
  final CommunityStore _store;

  List<CommunityPost> _items = <CommunityPost>[];
  List<CommunityPost> _pinned = <CommunityPost>[];
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadedOnce = false;
  CommunityException? _failure;
  CommunityException? _moreFailure;
  DateTime? _cachedAt;
  bool _disposed = false;
  int _generation = 0;

  List<CommunityPost> get items => _items;
  List<CommunityPost> get pinned => _pinned;

  /// Épinglées puis publications, sans les membres bloqués de la session.
  List<CommunityPost> get visibleItems => <CommunityPost>[
        ..._pinned,
        ..._items,
      ]
          .where((p) => !_store.isBlockedLocally(p.author.memberId))
          .toList(growable: false);

  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _cursor != null;
  bool get loadedOnce => _loadedOnce;
  CommunityException? get failure => _failure;
  CommunityException? get moreFailure => _moreFailure;

  /// Non nul : la liste affichée vient du cache, datée de cet instant.
  DateTime? get cachedAt => _cachedAt;

  /// Vrai : le cache est montré PARCE QUE le serveur n'a pas répondu.
  bool get showingStaleCache => _cachedAt != null && _failure != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Charge (ou recharge) la première page.
  Future<void> load() async {
    final generation = ++_generation;
    _loading = true;
    _failure = null;
    _moreFailure = null;
    _notify();

    final key = cacheKey;
    if (key != null && _items.isEmpty && _pinned.isEmpty) {
      final cached = await _store.cache.read(key);
      if (generation != _generation) return;
      if (cached != null) {
        final page =
            CommunityPage.fromJson(cached.json, CommunityPost.fromJson);
        _items = List<CommunityPost>.of(page.items);
        _pinned = List<CommunityPost>.of(page.pinned);
        _cursor = null; // le curseur d'une page en cache est périmé
        _cachedAt = cached.fetchedAt;
        _notify();
      }
    }

    try {
      final result = await fetch(null);
      if (generation != _generation) return;
      _items = List<CommunityPost>.of(result.page.items);
      _pinned = List<CommunityPost>.of(result.page.pinned);
      _cursor = result.page.nextCursor;
      _cachedAt = null;
      _failure = null;
      final raw = result.raw;
      if (key != null && raw != null) unawaited(_store.cache.write(key, raw));
    } on CommunityException catch (error) {
      if (generation != _generation) return;
      _failure = error;
      _store.noteFailure(error);
    } catch (_) {
      if (generation != _generation) return;
      _failure = const CommunityException(CommunityFailure.server);
    } finally {
      if (generation == _generation) {
        _loading = false;
        _loadedOnce = true;
        _notify();
      }
    }
  }

  /// La page suivante (rien si une requête est en cours ou la liste finie).
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore || _loading) return;
    final generation = _generation;
    _loadingMore = true;
    _moreFailure = null;
    _notify();
    try {
      final result = await fetch(cursor);
      if (generation != _generation) return;
      final known = _items.map((p) => p.id).toSet()
        ..addAll(_pinned.map((p) => p.id));
      _items = <CommunityPost>[
        ..._items,
        ...result.page.items.where((p) => !known.contains(p.id)),
      ];
      _cursor = result.page.nextCursor;
    } on CommunityException catch (error) {
      if (generation != _generation) return;
      _store.noteFailure(error);
      if (error.failure == CommunityFailure.invalidCursor) {
        // Curseur d'un autre fil (ou périmé) : on repart de la tête.
        _loadingMore = false;
        unawaited(load());
        return;
      }
      _moreFailure = error;
    } catch (_) {
      if (generation != _generation) return;
      _moreFailure = const CommunityException(CommunityFailure.server);
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// Remplace une publication modifiée (compteurs, « utile », suivi).
  void replace(CommunityPost post) {
    _items = [for (final p in _items) p.id == post.id ? post : p];
    _pinned = [for (final p in _pinned) p.id == post.id ? post : p];
    _notify();
  }

  /// Retire une publication supprimée.
  void remove(String postId) {
    _items = _items.where((p) => p.id != postId).toList();
    _pinned = _pinned.where((p) => p.id != postId).toList();
    _notify();
  }

  /// Ajoute en tête une publication que l'élève vient d'écrire.
  void prepend(CommunityPost post) {
    _items = <CommunityPost>[post, ..._items.where((p) => p.id != post.id)];
    _notify();
  }
}
