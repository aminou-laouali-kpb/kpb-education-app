import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/catalog_source.dart';

/// Hive-backed offline snapshot cache for the `/catalog/*` endpoints.
///
/// We keep this intentionally schema-less: each catalog resource is stored as
/// a single JSON-encoded string under its resource key (e.g. `fields`,
/// `countries`). The box also records a `last_synced_at` timestamp so the UI
/// can show "last updated …" for airtime-sensitive users.
///
/// Hive is preferred over SharedPreferences here because catalog payloads can
/// reach hundreds of KB and Hive reads without parsing the entire prefs blob.
///
/// Each resource additionally carries the provenance of its rows
/// ([CatalogDataSource]). Only `database` rows are ever handed back: if some
/// future code path caches a degraded payload, [read] refuses to serve it
/// instead of pinning fake data on the device forever.
class CatalogCacheService {
  CatalogCacheService._(this._box);

  static const _boxName = 'kpb.catalog.cache';
  static const _lastSyncKey = '__last_synced_at';
  static const _formatVersionKey = '__cache_format_version';
  static const _sourcePrefix = '__source::';

  /// Bumped when JSON shape or semantics under each resource key change materially.
  ///
  /// v2 also acts as the eviction of caches poisoned by the backend's silent
  /// mock-catalog fallback: builds that shipped v1 wrote fixture rows (fake
  /// scholarships) into this box and, because an empty API response was a
  /// no-op, kept them across every later refresh. Bumping the version makes
  /// [init] wipe the box once on first launch of the fixed build, so no user
  /// needs to reinstall. Cost: one lost offline snapshot; until the next
  /// successful sync the app shows its bundled sample catalog behind the
  /// existing "sample data" banner, which is honest.
  static const _currentFormatVersion = 2;
  static const _staleAfter = Duration(days: 14);

  final Box<String> _box;

  static CatalogCacheService? _instance;
  static bool get isInitialized => _instance != null;
  static CatalogCacheService get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('CatalogCacheService.init() was not called.');
    }
    return value;
  }

  static Future<CatalogCacheService> init() async {
    if (_instance != null) return _instance!;
    final box = await Hive.openBox<String>(_boxName);
    final stored = box.get(_formatVersionKey);
    final version = stored == null ? null : int.tryParse(stored) ?? 0;
    if (version != _currentFormatVersion) {
      // Unknown, older or newer format: drop everything rather than reason
      // about rows we cannot vouch for. Also covers the v1 poisoned caches.
      await box.clear();
      await box.put(_formatVersionKey, '$_currentFormatVersion');
    }
    return _instance = CatalogCacheService._(box);
  }

  /// Hive box name; exposed so tests can seed a legacy-format cache.
  @visibleForTesting
  static const boxName = _boxName;

  /// Format version this build expects; exposed for the migration test.
  @visibleForTesting
  static const currentFormatVersion = _currentFormatVersion;

  /// Drops the singleton so a test can exercise [init] again.
  @visibleForTesting
  static void resetForTests() => _instance = null;

  /// Persists [items] for [resource], recording where they came from.
  ///
  /// Callers must not cache untrusted rows; passing a non-database [source] is
  /// tolerated (it is recorded faithfully) but [read] will then refuse them.
  Future<void> write(
    String resource,
    List<dynamic> items, {
    CatalogDataSource source = CatalogDataSource.database,
  }) async {
    await _box.put(resource, jsonEncode(items));
    await _box.put('$_sourcePrefix$resource', source.wireValue);
    await _box.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// True when [resource] has a stored snapshot, *including an empty one*.
  ///
  /// An empty snapshot is meaningful: it records that the server authoritatively
  /// answered "no rows". It must not be confused with "never synced".
  bool hasCached(String resource) {
    if (!sourceFor(resource).isTrustworthy) return false;
    return _box.get(resource) != null;
  }

  /// Provenance recorded for [resource]; `database` when nothing was recorded.
  CatalogDataSource sourceFor(String resource) =>
      CatalogDataSource.parse(_box.get('$_sourcePrefix$resource'));

  /// The raw JSON stored for [resource], or null when absent or untrusted.
  /// Lets callers decode off the main isolate (see `decodeCachedCatalog`).
  String? readRaw(String resource) {
    if (!sourceFor(resource).isTrustworthy) return null;
    final raw = _box.get(resource);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  List<dynamic> read(String resource) {
    if (!sourceFor(resource).isTrustworthy) return const <dynamic>[];
    final raw = _box.get(resource);
    if (raw == null || raw.isEmpty) return const <dynamic>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {
      // Corrupt cache — fall through to empty list.
    }
    return const <dynamic>[];
  }

  DateTime? get lastSyncedAt {
    final raw = _box.get(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get isStale {
    final at = lastSyncedAt;
    if (at == null) return true;
    return DateTime.now().difference(at) > _staleAfter;
  }

  Future<void> clear() async {
    await _box.clear();
    await _box.put(_formatVersionKey, '$_currentFormatVersion');
  }
}
