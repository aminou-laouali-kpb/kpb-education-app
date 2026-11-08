import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed outbox for case messages that could not be posted (offline,
/// network failure, or a case that still only has its local `case-<ms>` id).
/// Drained by [AppController.flushPendingCaseMessages].
class CaseMessageOutbox {
  CaseMessageOutbox._(this._box);

  static const _boxName = 'kpb.cases.outbox';
  static const maxRetries = 5;

  final Box<String> _box;

  static CaseMessageOutbox? _instance;
  static CaseMessageOutbox get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('CaseMessageOutbox.init() was not called.');
    }
    return value;
  }

  /// La file si elle est ouverte, sinon `null` : lue pendant un `build`
  /// (état d'une bulle), elle ne doit jamais faire planter l'écran.
  static CaseMessageOutbox? get maybeInstance => _instance;

  static Future<CaseMessageOutbox> init() async {
    if (_instance != null) return _instance!;
    final box = await Hive.openBox<String>(_boxName);
    return _instance = CaseMessageOutbox._(box);
  }

  /// [localMessageId] : l'id de la bulle optimiste (`user-…`) affichée dans
  /// le fil, pour que l'écran sache que C'EST ELLE qui attend ou a échoué.
  Future<void> enqueue({
    required String caseId,
    required String body,
    required String senderName,
    String? localMessageId,
  }) async {
    final entry = OutboxEntry(
      key: null,
      caseId: caseId,
      body: body,
      senderName: senderName,
      createdAt: DateTime.now(),
      retries: 0,
      localMessageId: localMessageId,
    );
    await _box.add(entry.encode());
  }

  Iterable<OutboxEntry> get _all => _box
      .toMap()
      .entries
      .map((e) => OutboxEntry.decode(e.key, e.value))
      .whereType<OutboxEntry>();

  /// Entrées encore réessayées automatiquement, dans l'ordre d'écriture.
  Iterable<OutboxEntry> get pending =>
      _all.where((e) => e.retries < maxRetries);

  int get pendingCount => _box.length;

  bool hasPendingFor(String caseId) => pending.any((e) => e.caseId == caseId);

  /// L'entrée qui porte la bulle [localMessageId]. Une entrée écrite par une
  /// version antérieure n'a pas d'id de bulle : on la retrouve alors par son
  /// texte (dans le même dossier quand [caseId] est donné).
  OutboxEntry? entryForMessage(
    String localMessageId, {
    String? body,
    String? caseId,
  }) {
    OutboxEntry? legacy;
    for (final entry in _all) {
      if (entry.localMessageId == localMessageId) return entry;
      if (legacy == null &&
          entry.localMessageId == null &&
          body != null &&
          entry.body == body &&
          (caseId == null || entry.caseId == caseId)) {
        legacy = entry;
      }
    }
    return legacy;
  }

  bool isPermanentlyFailed(OutboxEntry entry) => entry.retries >= maxRetries;

  Future<void> remove(dynamic key) => _box.delete(key);

  /// Drop every queued message (used by account deletion — these entries hold
  /// personal data: case bodies + sender names typed offline).
  Future<void> clear() => _box.clear();

  /// Échec réseau : un essai de plus. Au-delà de [maxRetries], l'entrée n'est
  /// plus réessayée seule mais reste là : la bulle affiche « Non envoyé —
  /// Réessayer » ([isPermanentlyFailed]).
  Future<void> markFailure(dynamic key, OutboxEntry entry) async {
    final next = entry.withRetries(entry.retries + 1);
    await _box.put(key, next.encode());
  }

  /// Refus définitif du serveur (4xx) : inutile de le reposter à chaque
  /// reconnexion, la bulle passe tout de suite en « Non envoyé ».
  Future<void> markPermanentFailure(dynamic key, OutboxEntry entry) =>
      _box.put(key, entry.withRetries(maxRetries).encode());

  /// « Réessayer » : l'entrée repart pour [maxRetries] essais.
  Future<void> resetRetries(OutboxEntry entry) =>
      _box.put(entry.key, entry.withRetries(0).encode());

  /// Le dossier [fromCaseId] (id local `case-<ms>`) a reçu son id serveur :
  /// ses messages en file partent désormais vers [toCaseId].
  Future<void> reassignCase(String fromCaseId, String toCaseId) async {
    for (final entry in _all.where((e) => e.caseId == fromCaseId).toList()) {
      await _box.put(entry.key, entry.withCaseId(toCaseId).encode());
    }
  }

  Iterable<OutboxEntry> get permanentlyFailed =>
      _all.where((e) => e.retries >= maxRetries);
}

class OutboxEntry {
  OutboxEntry({
    required this.key,
    required this.caseId,
    required this.body,
    required this.senderName,
    required this.createdAt,
    required this.retries,
    this.localMessageId,
  });

  final dynamic key;
  final String caseId;
  final String body;
  final String senderName;
  final DateTime createdAt;
  final int retries;

  /// Id de la bulle optimiste du fil (`user-…`). `null` pour une entrée
  /// écrite par une version antérieure.
  final String? localMessageId;

  static OutboxEntry? decode(dynamic key, String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      return OutboxEntry(
        key: key,
        caseId: json['caseId'] as String? ?? '',
        body: json['body'] as String? ?? '',
        senderName: json['senderName'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        retries: json['retries'] as int? ?? 0,
        localMessageId: json['localMessageId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(<String, dynamic>{
        'caseId': caseId,
        'body': body,
        'senderName': senderName,
        'createdAt': createdAt.toIso8601String(),
        'retries': retries,
        if (localMessageId != null) 'localMessageId': localMessageId,
      });

  OutboxEntry _copy({String? caseId, int? retries}) => OutboxEntry(
        key: key,
        caseId: caseId ?? this.caseId,
        body: body,
        senderName: senderName,
        createdAt: createdAt,
        retries: retries ?? this.retries,
        localMessageId: localMessageId,
      );

  OutboxEntry withRetries(int retries) => _copy(retries: retries);

  OutboxEntry withCaseId(String caseId) => _copy(caseId: caseId);
}
