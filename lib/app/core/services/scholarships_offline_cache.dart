import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'catalog_cache_service.dart';

/// Le stockage clé → JSON du cache hors ligne des bourses. Interface pour
/// qu'un test le remplace ; Hive en production.
abstract class ScholarshipsOfflineStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
}

/// Boîte Hive `kpb.scholarships.cache`.
class HiveScholarshipsOfflineStore implements ScholarshipsOfflineStore {
  const HiveScholarshipsOfflineStore();

  static const boxName = 'kpb.scholarships.cache';

  Future<Box<String>?> _box() async {
    // Hive n'est initialisé que par `main()` (via le cache catalogue) : les
    // tests de widgets légers n'ont pas de disque, et le cache se tait.
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

/// Stockage en mémoire : les tests, et le repli quand Hive n'est pas là.
class MemoryScholarshipsOfflineStore implements ScholarshipsOfflineStore {
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

/// Une première page de liste relue du disque.
@immutable
class CachedScholarshipsPage {
  const CachedScholarshipsPage({
    required this.items,
    required this.fetchedAt,
    this.total,
  });

  /// Items bruts (JSON), tels que le serveur les a servis.
  final List<dynamic> items;

  /// Quand le serveur les a servis : « Hors ligne — données du … ».
  final DateTime fetchedAt;
  final int? total;
}

/// Une fiche relue du disque.
@immutable
class CachedScholarshipDetail {
  const CachedScholarshipDetail({required this.json, required this.fetchedAt});

  final Map<String, dynamic> json;
  final DateTime fetchedAt;
}

/// Cache disque de la liste des bourses (première page) et des fiches
/// consultées, pour l'onglet Bourses hors ligne.
///
/// · Les items sont gardés BRUTS (le JSON du serveur) : relus, ils passent par
///   le même `LiveScholarshipModel.fromJson` que la réponse en ligne — aucun
///   second format à tenir à jour.
/// · Une recherche libre n'est pas gardée (une clé par frappe gonflerait la
///   boîte pour rien) ; les fiches sont plafonnées à [maxDetails], les plus
///   anciennes consultées partent d'abord.
/// · Tout appartient au compte connecté : la déconnexion vide la boîte
///   (`_resetScholarshipFollowState`). Les items portent l'état « suivie » et
///   le score de l'élève.
/// · Rien ici ne lève : un cache qui n'écrit pas ne doit rien casser.
class ScholarshipsOfflineCache {
  ScholarshipsOfflineCache([ScholarshipsOfflineStore? store])
      : _store = store ?? const HiveScholarshipsOfflineStore();

  static ScholarshipsOfflineCache instance = ScholarshipsOfflineCache();

  /// Remplace l'instance partagée (tests).
  @visibleForTesting
  static void debugUse(ScholarshipsOfflineStore store) =>
      instance = ScholarshipsOfflineCache(store);

  static const int maxDetails = 60;
  static const String _detailIndexKey = '__detail_index';

  final ScholarshipsOfflineStore _store;

  static String _listKey(String signature) => 'list::$signature';
  static String _detailKey(String lang, String id) => 'detail::$lang::$id';

  Future<void> writeFirstPage(
    String signature,
    List<dynamic> items, {
    int? total,
    DateTime? fetchedAt,
  }) async {
    try {
      await _store.write(
        _listKey(signature),
        jsonEncode(<String, dynamic>{
          'fetchedAt': (fetchedAt ?? DateTime.now()).toUtc().toIso8601String(),
          'total': total,
          'items': items,
        }),
      );
    } catch (_) {}
  }

  Future<CachedScholarshipsPage?> readFirstPage(String signature) async {
    try {
      final raw = await _store.read(_listKey(signature));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final at = DateTime.tryParse('${decoded['fetchedAt']}');
      final items = decoded['items'];
      if (at == null || items is! List) return null;
      final total = decoded['total'];
      return CachedScholarshipsPage(
        items: items,
        fetchedAt: at,
        total: total is num ? total.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeDetail(
    String lang,
    String id,
    Map<String, dynamic> json, {
    DateTime? fetchedAt,
  }) async {
    if (id.isEmpty) return;
    try {
      final key = _detailKey(lang, id);
      await _store.write(
        key,
        jsonEncode(<String, dynamic>{
          'fetchedAt': (fetchedAt ?? DateTime.now()).toUtc().toIso8601String(),
          'item': json,
        }),
      );
      // Index des fiches, de la plus ancienne à la plus récente consultée.
      final index = await _readIndex()
        ..remove(key)
        ..add(key);
      while (index.length > maxDetails) {
        await _store.remove(index.removeAt(0));
      }
      await _store.write(_detailIndexKey, jsonEncode(index));
    } catch (_) {}
  }

  Future<CachedScholarshipDetail?> readDetail(String lang, String id) async {
    try {
      final raw = await _store.read(_detailKey(lang, id));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final at = DateTime.tryParse('${decoded['fetchedAt']}');
      final item = decoded['item'];
      if (at == null || item is! Map) return null;
      return CachedScholarshipDetail(
        json: Map<String, dynamic>.from(item),
        fetchedAt: at,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _readIndex() async {
    final raw = await _store.read(_detailIndexKey);
    if (raw == null || raw.isEmpty) return <String>[];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.whereType<String>().toList() : <String>[];
  }

  /// Déconnexion : tout part.
  Future<void> clear() async {
    try {
      await _store.clear();
    } catch (_) {}
  }
}
