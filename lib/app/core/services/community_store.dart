import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../controllers/app_controller.dart';
import '../models/community.dart';
import '../repositories/app_api_client.dart';
import 'catalog_cache_service.dart';
import 'remote_feature_flags.dart';

// ── Cache disque ────────────────────────────────────────────────────────────

/// Stockage clé → JSON du cache de la communauté. Interface pour qu'un test
/// le remplace ; Hive en production.
abstract class CommunityCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
}

/// Boîte Hive versionnée `kpb.community.v1`. Les clés portent l'identifiant
/// du compte : un téléphone partagé ne montre jamais le fil d'un autre élève,
/// et la déconnexion vide la boîte.
class HiveCommunityCacheStore implements CommunityCacheStore {
  const HiveCommunityCacheStore();

  static const boxName = 'kpb.community.v1';

  Future<Box<String>?> _box() async {
    // Hive n'est initialisé que par `main()` : les tests légers n'ont pas de
    // disque, et le cache se tait (même règle que le cache des bourses).
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
  Future<String?> read(String key) async => (await _box())?.get(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _box())?.put(key, value);

  @override
  Future<void> remove(String key) async => (await _box())?.delete(key);

  @override
  Future<void> clear() async => (await _box())?.clear();
}

/// Stockage en mémoire : les tests, et le repli sans Hive.
class MemoryCommunityCacheStore implements CommunityCacheStore {
  final Map<String, String> entries = <String, String>{};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<void> remove(String key) async => entries.remove(key);

  @override
  Future<void> clear() async => entries.clear();
}

/// Une charge relue du disque, datée.
@immutable
class CommunityCached {
  const CommunityCached({required this.json, required this.fetchedAt});

  final Map<String, dynamic> json;
  final DateTime fetchedAt;
}

/// Cache disque : la première page de chaque fil, les dernières discussions
/// ouvertes (plafonnées) et la fiche membre. Les charges sont gardées BRUTES
/// et relues par les mêmes `fromJson` que la réponse en ligne. Rien ici ne
/// lève : un cache qui n'écrit pas ne doit rien casser.
class CommunityCache {
  CommunityCache([CommunityCacheStore? store])
      : _store = store ?? const HiveCommunityCacheStore();

  static const int maxPosts = 40;
  static const String _postIndexKey = '__post_index';

  final CommunityCacheStore _store;

  Future<void> write(String key, Map<String, dynamic> json) async {
    try {
      await _store.write(
        key,
        jsonEncode(<String, dynamic>{
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          'json': json,
        }),
      );
    } catch (_) {}
  }

  Future<CommunityCached?> read(String key) async {
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = decoded['json'];
      final at = DateTime.tryParse('${decoded['fetchedAt']}');
      if (json is! Map || at == null) return null;
      return CommunityCached(
        json: Map<String, dynamic>.from(json),
        fetchedAt: at,
      );
    } catch (_) {
      return null;
    }
  }

  /// Écrit une discussion et garde l'index des [maxPosts] plus récentes.
  Future<void> writePost(String key, Map<String, dynamic> json) async {
    await write(key, json);
    try {
      final rawIndex = await _store.read(_postIndexKey);
      final index = rawIndex == null
          ? <String>[]
          : (jsonDecode(rawIndex) as List).whereType<String>().toList();
      index
        ..remove(key)
        ..add(key);
      while (index.length > maxPosts) {
        await _store.remove(index.removeAt(0));
      }
      await _store.write(_postIndexKey, jsonEncode(index));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _store.clear();
    } catch (_) {}
  }
}

// ── Le magasin ──────────────────────────────────────────────────────────────

/// L'état partagé de la communauté côté app : la fiche membre (charte,
/// restriction, quotas), les membres bloqués pendant la session, les
/// compteurs des fiches.
///
/// - [enabled] lit le drapeau DISTANT `features.community` (clé absente =
///   fermé) et le compte : seuls les élèves y ont accès (contrat §2.2) ;
/// - un 404 `community_disabled` reçu en cours de route ferme aussi la
///   fonction pour la session ([serverDisabled]) : le serveur fait foi ;
/// - rien ici ne lève : chaque échec est rangé dans [meFailure].
class CommunityStore extends ChangeNotifier {
  CommunityStore._();

  static final CommunityStore instance = CommunityStore._();

  /// Remplace le client et le cache (tests).
  @visibleForTesting
  void debugConfigure({AppApiClient? api, CommunityCacheStore? cache}) {
    _apiOverride = api;
    if (cache != null) this.cache = CommunityCache(cache);
  }

  @visibleForTesting
  void debugReset() {
    _apiOverride = null;
    cache = CommunityCache(MemoryCommunityCacheStore());
    _clearState();
  }

  AppApiClient? _apiOverride;
  CommunityCache cache = CommunityCache();

  CommunityMe? _me;
  CommunityFailure? _meFailure;
  bool _loadingMe = false;
  Future<CommunityMe?>? _meInFlight;
  bool _serverDisabled = false;
  final Set<String> _blockedThisSession = <String>{};
  final Set<String> _unblockedThisSession = <String>{};
  final Map<String, ({int count, DateTime at})> _counts =
      <String, ({int count, DateTime at})>{};

  static const Duration _countTtl =
      Duration(minutes: 5); // kpb-allow-duration: fraîcheur des compteurs

  AppApiClient get api => _apiOverride ?? Get.find<AppController>().apiClient;

  AppController? get _controller =>
      Get.isRegistered<AppController>() ? Get.find<AppController>() : null;

  /// Langue des libellés serveur (`?lang`).
  String get lang => _controller?.localeCode == 'en' ? 'en' : 'fr';

  /// Clé de cache du compte (jamais partagée entre deux comptes).
  String get accountKey => _controller?.profile?.id ?? 'anon';

  CommunityMe? get me => _me;
  CommunityFailure? get meFailure => _meFailure;
  bool get loadingMe => _loadingMe;
  bool get serverDisabled => _serverDisabled;

  /// La nouvelle communauté est-elle ouverte à CET utilisateur ?
  ///
  /// Drapeau distant ouvert, compte élève, et le serveur n'a pas répondu
  /// « coupée » pendant cette session. Un invité, un parent ou un partenaire
  /// gardent l'écran actuel, inchangé.
  bool get enabled {
    if (!RemoteFeatureFlags.instance.communityEnabled) return false;
    if (_serverDisabled) return false;
    final controller = _controller;
    if (controller == null) return false;
    return controller.isStudent && !controller.isGuestMode;
  }

  /// Le serveur a répondu « coupée » : on se tait jusqu'au prochain
  /// démarrage (ou au prochain rafraîchissement du drapeau).
  void markServerDisabled() {
    if (_serverDisabled) return;
    _serverDisabled = true;
    notifyListeners();
  }

  /// Lève [markServerDisabled] (drapeau rafraîchi et ouvert, tests).
  void clearServerDisabled() {
    if (!_serverDisabled) return;
    _serverDisabled = false;
    notifyListeners();
  }

  /// Range un échec : `disabled` ferme la fonction pour la session.
  void noteFailure(CommunityException error) {
    if (error.failure == CommunityFailure.disabled) markServerDisabled();
  }

  // ── Fiche membre ────────────────────────────────────────────────────────

  String get _meKey => 'me::$accountKey::$lang';

  /// `GET /community/me` (une requête à la fois). Relit le cache d'abord, pour
  /// qu'un écran hors ligne connaisse au moins la charte déjà acceptée.
  Future<CommunityMe?> loadMe({bool force = false}) {
    if (!force && _me != null) return Future.value(_me);
    return _meInFlight ??= _loadMe().whenComplete(() => _meInFlight = null);
  }

  Future<CommunityMe?> _loadMe() async {
    _loadingMe = true;
    if (_me == null) {
      final cached = await cache.read(_meKey);
      final parsed = cached == null ? null : CommunityMe.fromJson(cached.json);
      if (parsed != null) _me = parsed;
    }
    notifyListeners();
    try {
      final fresh = await api.fetchCommunityMe(lang: lang);
      _me = fresh;
      _meFailure = null;
      unawaited(_writeMeCache(fresh));
    } on CommunityException catch (error) {
      _meFailure = error.failure;
      noteFailure(error);
    } catch (_) {
      _meFailure = CommunityFailure.server;
    } finally {
      _loadingMe = false;
      notifyListeners();
    }
    return _me;
  }

  Future<void> _writeMeCache(CommunityMe me) async {
    // On ne garde que ce qu'il faut hors ligne : la charte et la restriction.
    final charter = me.charter;
    await cache.write(_meKey, <String, dynamic>{
      'member': <String, dynamic>{
        'kind': 'member',
        'memberId': me.member.memberId,
        'displayName': me.member.displayName,
        'countryName': me.member.countryName,
        'badges': me.member.badges.map((b) => b.wire).toList(),
      },
      if (charter != null)
        'charter': <String, dynamic>{
          'currentVersion': charter.currentVersion,
          'acceptedVersion': charter.acceptedVersion,
          'acceptedAt': charter.acceptedAt?.toUtc().toIso8601String(),
          'required': charter.required,
          'title': charter.title,
          'rules': charter.rules
              .map((r) => <String, dynamic>{
                    'id': r.id,
                    'title': r.title,
                    'body': r.body,
                  })
              .toList(),
        },
      if (me.restriction != null)
        'restriction': <String, dynamic>{
          'kind': me.restriction!.isBan ? 'ban' : 'read_only',
          'until': me.restriction!.until?.toUtc().toIso8601String(),
          'reason': me.restriction!.reason,
        },
    });
  }

  /// La charte courante doit-elle être acceptée avant d'écrire ?
  bool get charterRequired => _me?.charterRequired ?? true;

  /// `POST /community/charter/accept` avec la version courante. Rend vrai si
  /// le serveur l'a enregistrée. Une version périmée (409) recharge la fiche.
  Future<bool> acceptCharter() async {
    final charter = _me?.charter;
    if (charter == null) return false;
    try {
      final result = await api.acceptCommunityCharter(charter.currentVersion);
      final me = _me;
      if (me != null) {
        _me =
            me.withCharter(charter.accepted(result.version, result.acceptedAt));
        unawaited(_writeMeCache(_me!));
      }
      notifyListeners();
      return !charterRequired;
    } on CommunityException catch (error) {
      noteFailure(error);
      if (error.failure == CommunityFailure.charterOutdated) {
        await loadMe(force: true);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Le serveur a répondu `community_charter_required` à une écriture : la
  /// fiche est périmée (nouvelle version), on la recharge.
  Future<void> invalidateCharter() async {
    await loadMe(force: true);
  }

  // ── Blocages de la session ──────────────────────────────────────────────

  /// Vrai : ce membre a été bloqué depuis l'ouverture de l'app. Ses contenus
  /// déjà chargés disparaissent sans attendre un rechargement.
  bool isBlockedLocally(String? memberId) =>
      memberId != null && _blockedThisSession.contains(memberId);

  void rememberBlocked(String memberId, {required bool blocked}) {
    if (blocked) {
      _blockedThisSession.add(memberId);
      _unblockedThisSession.remove(memberId);
    } else {
      _blockedThisSession.remove(memberId);
      _unblockedThisSession.add(memberId);
    }
    notifyListeners();
  }

  /// Bloque / débloque et le retient pour la session. Lève
  /// [CommunityException].
  Future<bool> setBlocked(String memberId, {required bool blocked}) async {
    try {
      final result =
          await api.setCommunityBlock(memberId: memberId, blocked: blocked);
      rememberBlocked(memberId, blocked: result);
      return result;
    } on CommunityException catch (error) {
      noteFailure(error);
      rethrow;
    }
  }

  // ── Compteurs des fiches ────────────────────────────────────────────────

  static String _countKey(CommunityEntityType type, String id) =>
      '${type.wire}:$id';

  /// Le compteur connu (mémoire, 5 min), ou `null`.
  int? cachedCount(CommunityEntityType type, String id) {
    final entry = _counts[_countKey(type, id)];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _countTtl) return null;
    return entry.count;
  }

  void rememberCount(CommunityEntityType type, String id, int count) {
    _counts[_countKey(type, id)] = (count: count, at: DateTime.now());
  }

  /// Le nombre de discussions d'une entité, pour une fiche.
  ///
  /// Mémoire d'abord (5 min) ; sinon la demande rejoint un LOT : toutes les
  /// sections montées dans la même image partent en UN appel
  /// `GET /community/entities/counts?refs=` (50 références au plus par
  /// appel), jamais une requête par fiche. Lève [CommunityException].
  Future<int> countFor(CommunityEntityType type, String id) {
    final known = cachedCount(type, id);
    if (known != null) return Future.value(known);
    final key = _countKey(type, id);
    final pending = _pendingCounts[key];
    if (pending != null) return pending.completer.future;
    final completer = Completer<int>();
    _pendingCounts[key] = (type: type, id: id, completer: completer);
    if (!_countFlushScheduled) {
      _countFlushScheduled = true;
      scheduleMicrotask(_flushCounts);
    }
    return completer.future;
  }

  final Map<String,
          ({CommunityEntityType type, String id, Completer<int> completer})>
      _pendingCounts = {};
  bool _countFlushScheduled = false;

  Future<void> _flushCounts() async {
    _countFlushScheduled = false;
    final batch = Map.of(_pendingCounts);
    _pendingCounts.clear();
    final entries = batch.entries.toList();
    for (var start = 0; start < entries.length; start += 50) {
      final chunk = entries.sublist(
          start, start + 50 > entries.length ? entries.length : start + 50);
      try {
        final counts = await api.fetchCommunityEntityCounts([
          for (final e in chunk) (type: e.value.type, id: e.value.id),
        ]);
        final byKey = <String, int>{
          for (final c in counts) _countKey(c.type, c.id): c.discussionCount,
        };
        for (final e in chunk) {
          // Une référence absente de la réponse : aucune discussion.
          final count = byKey[e.key] ?? 0;
          rememberCount(e.value.type, e.value.id, count);
          e.value.completer.complete(count);
        }
      } on CommunityException catch (error) {
        noteFailure(error);
        for (final e in chunk) {
          e.value.completer.completeError(error);
        }
      } catch (_) {
        for (final e in chunk) {
          e.value.completer
              .completeError(const CommunityException(CommunityFailure.server));
        }
      }
    }
  }

  /// Après une publication : les compteurs des entités citées sont périmés.
  void invalidateCounts(Iterable<String> refs) {
    for (final ref in refs) {
      _counts.remove(ref);
    }
    notifyListeners();
  }

  // ── Session ─────────────────────────────────────────────────────────────

  void _clearState() {
    _me = null;
    _meFailure = null;
    _loadingMe = false;
    _meInFlight = null;
    _serverDisabled = false;
    _blockedThisSession.clear();
    _unblockedThisSession.clear();
    _counts.clear();
    _pendingCounts.clear();
    _countFlushScheduled = false;
  }

  /// Déconnexion, suppression de compte : tout ce qui appartient au compte
  /// part, mémoire et disque.
  void reset() {
    _clearState();
    unawaited(cache.clear());
    notifyListeners();
  }
}
