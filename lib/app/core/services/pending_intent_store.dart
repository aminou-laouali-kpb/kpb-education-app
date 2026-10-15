import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Une intention laissée par un invité avant de créer son compte : « ouvre
/// cet écran une fois que j'aurai un compte ».
@immutable
class PendingIntent {
  const PendingIntent({
    required this.route,
    required this.source,
    required this.expiresAt,
  });

  final String route;
  final String source;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'route': route,
        'source': source,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  static PendingIntent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final route = raw['route'];
    final source = raw['source'];
    final expiresAt = DateTime.tryParse('${raw['expiresAt']}');
    if (route is! String || route.isEmpty || expiresAt == null) return null;
    return PendingIntent(
      route: route,
      source: source is String ? source : 'unknown',
      expiresAt: expiresAt,
    );
  }
}

/// Où l'intention est gardée. Interface pour les tests ; SharedPreferences en
/// production.
abstract class PendingIntentStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SharedPreferencesPendingIntentStorage implements PendingIntentStorage {
  const SharedPreferencesPendingIntentStorage();

  /// Versionnée : un format futur ne relira jamais celui-ci de travers.
  static const key = '${AppConfig.storageNamespace}.pending_intent_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> delete() async =>
      (await SharedPreferences.getInstance()).remove(key);
}

class MemoryPendingIntentStorage implements PendingIntentStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}

/// L'intention en attente (UNE à la fois, la plus récente gagne).
///
/// Écrite par le bouton « Faire le test » d'un invité, lue au PREMIER rendu de
/// l'accueil après l'onboarding ou « Passer » — jamais pendant l'écran des
/// premiers résultats (AhaMoment), qui garde la priorité. Expire après 24 h :
/// passé ce délai, l'élève qui ouvre l'app n'attend plus cet écran.
abstract final class PendingIntentStore {
  static const Duration ttl = Duration(hours: 24);

  static PendingIntentStorage _storage =
      const SharedPreferencesPendingIntentStorage();

  @visibleForTesting
  static set debugStorage(PendingIntentStorage? storage) =>
      _storage = storage ?? const SharedPreferencesPendingIntentStorage();

  /// Garde [route] pour après l'inscription. Ne lève jamais.
  static Future<void> save({
    required String route,
    required String source,
    DateTime? now,
  }) async {
    final intent = PendingIntent(
      route: route,
      source: source,
      expiresAt: (now ?? DateTime.now()).add(ttl),
    );
    try {
      await _storage.write(jsonEncode(intent.toJson()));
    } catch (_) {}
  }

  /// L'intention valable, sans la consommer.
  static Future<PendingIntent?> peek({DateTime? now}) async {
    try {
      final raw = await _storage.read();
      if (raw == null || raw.isEmpty) return null;
      final intent = PendingIntent.fromJson(jsonDecode(raw));
      if (intent == null || intent.isExpired(now ?? DateTime.now())) {
        return null;
      }
      return intent;
    } catch (_) {
      return null;
    }
  }

  /// Rend l'intention valable et l'EFFACE (elle ne sert qu'une fois). Une
  /// intention expirée ou illisible est effacée et rend `null`.
  static Future<PendingIntent?> consume({DateTime? now}) async {
    final intent = await peek(now: now);
    try {
      await _storage.delete();
    } catch (_) {}
    return intent;
  }
}
