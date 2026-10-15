import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/scholarship_match.dart';
import '../repositories/app_api_client.dart';
import 'catalog_cache_service.dart';
import 'remote_feature_flags.dart';

// ── Cache ───────────────────────────────────────────────────────────────────

/// Où le dernier run et le brouillon de l'assistant sont gardés, PAR COMPTE.
/// Interface pour qu'un test la remplace ; Hive en production.
abstract class ScholarshipMatchCache {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

/// Boîte Hive versionnée (`kpb.scholarship_match.v1`). Les clés portent
/// l'identifiant du compte : un téléphone partagé ne montre jamais les
/// bourses d'un autre élève, et la déconnexion vide la boîte.
class HiveScholarshipMatchCache implements ScholarshipMatchCache {
  const HiveScholarshipMatchCache();

  static const boxName = 'kpb.scholarship_match.v1';

  Future<Box<String>?> _box() async {
    // Hive n'est initialisé que par `main()` : les tests légers n'ont pas de
    // disque (même règle que le cache des bourses suivies).
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
  Future<void> delete(String key) async => (await _box())?.delete(key);

  @override
  Future<void> clear() async => (await _box())?.clear();
}

/// Cache en mémoire : le repli des tests.
class MemoryScholarshipMatchCache implements ScholarshipMatchCache {
  final Map<String, String> entries = <String, String>{};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<void> delete(String key) async => entries.remove(key);

  @override
  Future<void> clear() async => entries.clear();
}

// ── Issues d'un run ─────────────────────────────────────────────────────────

sealed class MatchRunOutcome {
  const MatchRunOutcome();
}

class MatchRunSucceeded extends MatchRunOutcome {
  const MatchRunSucceeded({required this.run, required this.diff});

  final MatchRun run;
  final MatchRunDiff diff;
}

/// Le serveur dit qu'il manque encore quelque chose : RIEN n'a été écrit.
class MatchRunNeedsAnswers extends MatchRunOutcome {
  const MatchRunNeedsAnswers(this.readiness);

  final MatchReadiness readiness;
}

class MatchRunFailed extends MatchRunOutcome {
  const MatchRunFailed(this.failure);

  final ScholarshipMatchFailure failure;
}

// ── Le magasin ──────────────────────────────────────────────────────────────

/// « Mes 10 bourses » côté app : l'état servi, le dernier run (lisible hors
/// ligne, daté) et le brouillon de l'assistant.
///
/// UN point d'accès pour les trois entrées (carte de l'onglet Bourses,
/// résultats, et l'accueil « Tes bourses » à venir) :
///
/// - [loadState] appelle `GET /scholarships/match/state` au plus UNE fois par
///   passage au premier plan (un retour au premier plan rouvre la question) ;
/// - [latestRun] / [latestRunSyncedAt] : le dernier run connu, servi par le
///   serveur ou relu du cache, MASQUÉ quand le drapeau est fermé ;
/// - [createRun] : UNE requête `POST /scholarships/match/runs`.
///
/// Ne lève jamais : chaque échec est rangé dans [failure].
class ScholarshipMatchStore extends ChangeNotifier with WidgetsBindingObserver {
  ScholarshipMatchStore._();

  static final ScholarshipMatchStore instance = ScholarshipMatchStore._();

  ScholarshipMatchCache _cache = const HiveScholarshipMatchCache();
  DateTime Function() _now = DateTime.now;

  static const int _cacheVersion = 1;

  String? _userId;
  ScholarshipMatchState? _state;
  bool _stateFresh = false;
  MatchRun? _run;
  DateTime? _runSyncedAt;
  bool _runFromCache = false;
  bool _loading = false;
  bool _serverDisabled = false;
  ScholarshipMatchFailure? _failure;
  Future<void>? _inFlight;
  bool _observing = false;

  // ── Lecture ──────────────────────────────────────────────────────────────

  /// Le test est-il visible ? Drapeau `features.scholarshipMatch` ouvert ET
  /// le serveur n'a pas répondu « coupé » (404 `{disabled: true}`) ni « pas
  /// pour ce compte » (403) dans cette session.
  bool get enabled =>
      RemoteFeatureFlags.instance.scholarshipMatchEnabled && !_serverDisabled;

  /// L'état servi par le serveur dans cette session, ou `null`.
  ScholarshipMatchState? get state => enabled ? _state : null;

  /// Le dernier run connu (serveur ou cache), ou `null`. Caché quand le
  /// drapeau est fermé : « Flag off → l'app garde ses runs en cache cachés ».
  MatchRun? get latestRun => enabled ? _run : null;

  /// Quand [latestRun] a été reçu du serveur (date affichée hors ligne).
  DateTime? get latestRunSyncedAt => enabled ? _runSyncedAt : null;

  /// Vrai quand [latestRun] vient du cache parce que le réseau a échoué.
  bool get offline =>
      _run != null &&
      _runFromCache &&
      (_failure == ScholarshipMatchFailure.offline ||
          _failure == ScholarshipMatchFailure.timeout);

  /// Le profil, le catalogue ou l'algorithme ont changé depuis le run.
  bool get isStale => _state?.isStale ?? false;

  bool get loading => _loading;

  /// Le dernier échec, ou `null`.
  ScholarshipMatchFailure? get failure => _failure;

  bool get alertsOptIn => _state?.alertsOptIn ?? false;

  String? get userId => _userId;

  // ── Tests ────────────────────────────────────────────────────────────────

  @visibleForTesting
  set debugCache(ScholarshipMatchCache cache) => _cache = cache;

  @visibleForTesting
  set debugNow(DateTime Function()? now) => _now = now ?? DateTime.now;

  @visibleForTesting
  void debugReset({ScholarshipMatchCache? cache}) {
    _cache = cache ?? MemoryScholarshipMatchCache();
    _now = DateTime.now;
    _userId = null;
    _state = null;
    _stateFresh = false;
    _run = null;
    _runSyncedAt = null;
    _runFromCache = false;
    _loading = false;
    _serverDisabled = false;
    _failure = null;
    _inFlight = null;
  }

  /// Pose un état sans réseau (tests d'écran).
  @visibleForTesting
  void debugSeed({
    required String userId,
    ScholarshipMatchState? state,
    MatchRun? run,
    DateTime? syncedAt,
    bool fromCache = false,
    ScholarshipMatchFailure? failure,
  }) {
    _userId = userId;
    _state = state;
    _stateFresh = state != null;
    _run = run ?? state?.latestRun;
    _runSyncedAt = syncedAt ?? (_run == null ? null : _now());
    _runFromCache = fromCache;
    _failure = failure;
    notifyListeners();
  }

  // ── Clés de cache ────────────────────────────────────────────────────────

  static String _runKey(String userId) => 'user:$userId:run';
  static String _draftKey(String userId) => 'user:$userId:draft';

  // ── Cycle de vie ─────────────────────────────────────────────────────────

  void _ensureObserver() {
    if (_observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // Pas de binding (test unitaire pur) : l'état reste valable pour la vie
      // du processus.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Un retour au premier plan rouvre la question une fois.
    if (state == AppLifecycleState.resumed) _stateFresh = false;
  }

  /// Le compte courant. Un changement de compte efface la mémoire et relit
  /// le dernier run DE CE compte depuis le cache.
  Future<void> restore(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    _state = null;
    _stateFresh = false;
    _run = null;
    _runSyncedAt = null;
    _runFromCache = false;
    _failure = null;
    _serverDisabled = false;
    final cached = await _readRun(userId);
    if (cached != null && _userId == userId) {
      _run = cached.$1;
      _runSyncedAt = cached.$2;
      _runFromCache = true;
    }
    notifyListeners();
  }

  /// `GET /scholarships/match/state`, au plus une fois par passage au premier
  /// plan sauf [force]. Ne lève jamais.
  Future<void> loadState({
    required AppApiClient client,
    required String userId,
    required String lang,
    bool force = false,
  }) {
    final running = _inFlight;
    if (running != null) return running;
    final future = _loadState(
      client: client,
      userId: userId,
      lang: lang,
      force: force,
    );
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _loadState({
    required AppApiClient client,
    required String userId,
    required String lang,
    required bool force,
  }) async {
    _ensureObserver();
    await restore(userId);
    if (!RemoteFeatureFlags.instance.scholarshipMatchEnabled) return;
    if (_stateFresh && !force && _state != null) return;
    _loading = true;
    notifyListeners();
    try {
      final state = await client.fetchScholarshipMatchState(lang: lang);
      if (_userId != userId) return;
      _state = state;
      _stateFresh = true;
      _failure = null;
      _serverDisabled = false;
      final served = state.latestRun;
      if (served != null) {
        _run = served;
        _runSyncedAt = _now();
        _runFromCache = false;
        unawaited(_writeRun(userId, served, _runSyncedAt!));
      } else {
        // Le serveur fait foi : plus de run (élagué, compte remis à zéro).
        _run = null;
        _runSyncedAt = null;
        _runFromCache = false;
        unawaited(_deleteRun(userId));
      }
    } catch (error) {
      final failure = classifyScholarshipMatchError(error);
      _failure = failure;
      if (failure == ScholarshipMatchFailure.disabled ||
          failure == ScholarshipMatchFailure.forbidden) {
        _serverDisabled = true;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// UNE requête `POST /scholarships/match/runs`. Les réponses ne passent
  /// jamais par le PATCH du profil.
  Future<MatchRunOutcome> createRun({
    required AppApiClient client,
    required String userId,
    required String lang,
    Map<String, dynamic>? answers,
    bool confirm = false,
    String trigger = 'wizard',
  }) async {
    _ensureObserver();
    await restore(userId);
    try {
      final response = await client.createScholarshipMatchRun(
        lang: lang,
        answers: answers,
        confirm: confirm,
        trigger: trigger,
      );
      switch (response) {
        case MatchRunOk(:final run, :final diff):
          final syncedAt = _now();
          if (_userId == userId) {
            _run = run;
            _runSyncedAt = syncedAt;
            _runFromCache = false;
            _failure = null;
            _state = _state?.copyWith(
              latestRun: run,
              isStale: false,
              readiness: confirm
                  ? const MatchReadiness(ready: true)
                  : _state?.readiness,
            );
            // Les réponses viennent de changer côté serveur : la prochaine
            // ouverture relit l'état (préparation, valeurs du récapitulatif).
            _stateFresh = false;
            unawaited(_writeRun(userId, run, syncedAt));
            notifyListeners();
          }
          return MatchRunSucceeded(run: run, diff: diff);
        case MatchRunIncomplete(:final readiness):
          return MatchRunNeedsAnswers(readiness);
      }
    } catch (error) {
      final failure = classifyScholarshipMatchError(error);
      if (failure == ScholarshipMatchFailure.disabled ||
          failure == ScholarshipMatchFailure.forbidden) {
        _serverDisabled = true;
        notifyListeners();
      }
      return MatchRunFailed(failure);
    }
  }

  /// `PUT /scholarships/match/alerts`. Rend l'état confirmé, ou `null` en cas
  /// d'échec (l'interrupteur revient alors à sa valeur précédente).
  Future<bool?> setAlerts({
    required AppApiClient client,
    required bool enabled,
  }) async {
    try {
      final confirmed =
          await client.setScholarshipMatchAlerts(enabled: enabled);
      _state = _state?.copyWith(alertsOptIn: confirmed);
      notifyListeners();
      return confirmed;
    } catch (error) {
      final failure = classifyScholarshipMatchError(error);
      if (failure == ScholarshipMatchFailure.disabled) {
        _serverDisabled = true;
        notifyListeners();
      }
      return null;
    }
  }

  // ── Brouillon de l'assistant ─────────────────────────────────────────────

  /// Le brouillon de [userId], ou `null`. Illisible = absent.
  Future<Map<String, dynamic>?> readDraft(String userId) async {
    try {
      final raw = await _cache.read(_draftKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft(String userId, Map<String, dynamic> draft) async {
    try {
      await _cache.write(_draftKey(userId), jsonEncode(draft));
    } catch (_) {
      // Un brouillon qui ne s'écrit pas ne bloque pas l'assistant.
    }
  }

  Future<void> clearDraft(String userId) async {
    try {
      await _cache.delete(_draftKey(userId));
    } catch (_) {}
  }

  /// Le compte se déconnecte : tout ce qui lui appartient part (mémoire,
  /// runs et brouillons en cache).
  Future<void> clear() async {
    _userId = null;
    _state = null;
    _stateFresh = false;
    _run = null;
    _runSyncedAt = null;
    _runFromCache = false;
    _failure = null;
    _serverDisabled = false;
    try {
      await _cache.clear();
    } catch (_) {}
    notifyListeners();
  }

  // ── Cache du run ─────────────────────────────────────────────────────────

  Future<(MatchRun, DateTime)?> _readRun(String userId) async {
    try {
      final raw = await _cache.read(_runKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['v'] != _cacheVersion) return null;
      final run = MatchRun.fromJson(decoded['run']);
      final syncedAt = DateTime.tryParse('${decoded['syncedAt']}');
      if (run == null || syncedAt == null) return null;
      return (run, syncedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRun(String userId, MatchRun run, DateTime syncedAt) async {
    try {
      await _cache.write(
        _runKey(userId),
        jsonEncode(<String, dynamic>{
          'v': _cacheVersion,
          'syncedAt': syncedAt.toUtc().toIso8601String(),
          'run': run.toJson(),
        }),
      );
    } catch (_) {
      // Le run est à l'écran : un cache qui n'écrit pas ne casse rien.
    }
  }

  Future<void> _deleteRun(String userId) async {
    try {
      await _cache.delete(_runKey(userId));
    } catch (_) {}
  }
}
