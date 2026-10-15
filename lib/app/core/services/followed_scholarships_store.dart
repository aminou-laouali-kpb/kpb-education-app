import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_models.dart';
import '../repositories/app_api_client.dart';
import 'catalog_cache_service.dart';

/// Ce que le serveur a dit de `GET /me/followed-scholarships`.
enum FollowedEndpointState {
  /// Pas encore de réponse dans cette session.
  unknown,

  /// La route existe (200 reçu) : le backend connaît le suivi du chantier C.
  available,

  /// 404/405/501 : backend antérieur au chantier C. La section se masque, et
  /// la question est reposée à la prochaine ouverture.
  unavailable,
}

/// Où la dernière page reçue est gardée, par compte. Interface pour qu'un test
/// la remplace ; Hive en production.
abstract class FollowedScholarshipsCache {
  Future<String?> read(String userId);
  Future<void> write(String userId, String json);
  Future<void> clear();
}

/// Cache Hive (`kpb.followed.cache`), une entrée par compte : un téléphone
/// partagé ne montre jamais les suivis d'un autre élève, et la déconnexion
/// vide la boîte.
class HiveFollowedScholarshipsCache implements FollowedScholarshipsCache {
  const HiveFollowedScholarshipsCache();

  static const boxName = 'kpb.followed.cache';

  Future<Box<String>?> _box() async {
    // Hive n'est initialisé que par `main()` (via le cache catalogue) : les
    // tests de widgets légers n'ont pas de disque.
    if (!CatalogCacheService.isInitialized) return null;
    try {
      return Hive.isBoxOpen(boxName)
          ? Hive.box<String>(boxName)
          : await Hive.openBox<String>(boxName);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> read(String userId) async => (await _box())?.get(userId);

  @override
  Future<void> write(String userId, String json) async =>
      (await _box())?.put(userId, json);

  @override
  Future<void> clear() async => (await _box())?.clear();
}

/// Cache en mémoire : le repli quand Hive n'est pas là, et le cache des tests.
class MemoryFollowedScholarshipsCache implements FollowedScholarshipsCache {
  final Map<String, String> _entries = <String, String>{};

  @override
  Future<String?> read(String userId) async => _entries[userId];

  @override
  Future<void> write(String userId, String json) async =>
      _entries[userId] = json;

  @override
  Future<void> clear() async => _entries.clear();
}

/// Les bourses que l'élève suit, vues du serveur : cache d'abord, réseau
/// ensuite, et une dégradation propre face à un backend sans la route.
///
/// Partagé par « Mes suivis » et le calendrier des échéances.
class FollowedScholarshipsStore extends ChangeNotifier {
  FollowedScholarshipsStore._();

  static final FollowedScholarshipsStore instance =
      FollowedScholarshipsStore._();

  FollowedScholarshipsCache _cache = const HiveFollowedScholarshipsCache();

  FollowedScholarshipsPage? _page;
  String? _pageUserId;
  FollowedEndpointState _endpoint = FollowedEndpointState.unknown;
  bool _loading = false;
  bool _offline = false;
  Future<void>? _inFlight;

  /// La dernière page connue (serveur ou cache), ou null.
  FollowedScholarshipsPage? get page => _page;

  FollowedEndpointState get endpoint => _endpoint;

  bool get loading => _loading;

  /// Vrai quand la page affichée vient du cache parce que le réseau a échoué.
  bool get offline => _offline;

  @visibleForTesting
  set debugCache(FollowedScholarshipsCache cache) => _cache = cache;

  /// Charge la page de [userId] : le cache (s'il y a lieu) puis le serveur.
  /// Ne lève jamais.
  Future<void> load({
    required AppApiClient client,
    required String userId,
    required String lang,
  }) {
    final running = _inFlight;
    if (running != null) return running;
    final future = _load(client: client, userId: userId, lang: lang);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _load({
    required AppApiClient client,
    required String userId,
    required String lang,
  }) async {
    if (_pageUserId != userId) {
      _page = null;
      _pageUserId = userId;
      final cached = await _readCache(userId);
      if (cached != null) _page = cached;
    }
    _loading = true;
    notifyListeners();
    try {
      final fresh = await client.fetchFollowedScholarships(lang);
      _page = fresh;
      _endpoint = FollowedEndpointState.available;
      _offline = false;
      unawaited(_writeCache(userId, fresh));
    } catch (error) {
      if (isEndpointUnavailable(error)) {
        _endpoint = FollowedEndpointState.unavailable;
        _offline = false;
      } else {
        _offline = true;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Le compte se déconnecte : tout ce qui lui appartient part.
  Future<void> clear() async {
    _page = null;
    _pageUserId = null;
    _endpoint = FollowedEndpointState.unknown;
    _offline = false;
    try {
      await _cache.clear();
    } catch (_) {}
    notifyListeners();
  }

  @visibleForTesting
  void debugReset() {
    _page = null;
    _pageUserId = null;
    _endpoint = FollowedEndpointState.unknown;
    _loading = false;
    _offline = false;
    _inFlight = null;
    _cache = MemoryFollowedScholarshipsCache();
  }

  Future<FollowedScholarshipsPage?> _readCache(String userId) async {
    try {
      final raw = await _cache.read(userId);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return FollowedScholarshipsPage.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String userId, FollowedScholarshipsPage page) async {
    try {
      await _cache.write(userId, jsonEncode(page.toJson()));
    } catch (_) {
      // Un cache qui n'écrit pas ne doit rien casser : la page est à l'écran.
    }
  }
}
