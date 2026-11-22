import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../repositories/app_api_client.dart';

/// A single persisted coach turn, used to rehydrate the chat UI on launch.
class CoachHistoryMessage {
  const CoachHistoryMessage({required this.isUser, required this.content});

  final bool isUser;
  final String content;
}

class CoachStreamEvent {
  const CoachStreamEvent({
    required this.type,
    this.text,
    this.message,
    this.quotaRemaining,
  });

  final String type;
  final String? text;
  final String? message;
  final int? quotaRemaining;

  factory CoachStreamEvent.fromJson(Map<String, dynamic> json) {
    return CoachStreamEvent(
      type: json['type'] as String? ?? 'unknown',
      text: json['text'] as String?,
      message: json['message'] as String?,
      quotaRemaining: json['quotaRemaining'] as int?,
    );
  }
}

class CoachService {
  CoachService({AppApiClient? apiClient})
      : _apiClient = apiClient ?? AppApiClient();

  final AppApiClient _apiClient;
  String? _conversationId;

  static const _boxName = 'kpb.coach';
  Box<String>? _box;

  String? get conversationId => _conversationId;

  Future<Box<String>> _ensureBox() async {
    return _box ??= Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
  }

  String _convKey(String userId) => 'conversation_id::$userId';

  Future<String?> _restoreConversationId(String userId) async {
    try {
      final box = await _ensureBox();
      final stored = box.get(_convKey(userId));
      return (stored != null && stored.isNotEmpty) ? stored : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistConversationId(String userId, String id) async {
    try {
      final box = await _ensureBox();
      await box.put(_convKey(userId), id);
    } catch (_) {
      // Persistence is best-effort; the in-memory id still works this session.
    }
  }

  Future<CoachQuota> fetchQuota(String userId) async {
    if (!AppConfig.enableRemoteSync) {
      return const CoachQuota(remaining: 5, limit: 5, allowed: true);
    }
    final payload = await _apiClient.getCoachQuota(userId);
    return CoachQuota.fromJson(payload);
  }

  Future<String> ensureConversation({
    required String userId,
    required UserProfile profile,
  }) async {
    if (_conversationId != null) return _conversationId!;

    if (!AppConfig.enableRemoteSync) {
      _conversationId = 'local-coach';
      return _conversationId!;
    }

    // Resume the persisted conversation (history lives server-side) before
    // spending a round-trip on creating a brand-new one.
    final restored = await _restoreConversationId(userId);
    if (restored != null) {
      _conversationId = restored;
      return restored;
    }

    final payload = await _apiClient.createCoachConversation(
      userId: userId,
      profile: _profilePayload(profile),
    );
    _conversationId = payload['conversationId'] as String? ?? 'local-coach';
    await _persistConversationId(userId, _conversationId!);
    return _conversationId!;
  }

  /// Loads the persisted conversation history so the chat can be rehydrated on
  /// launch. Returns an empty list when remote sync is disabled or the fetch
  /// fails (the caller then falls back to a fresh greeting).
  Future<List<CoachHistoryMessage>> fetchHistory(String conversationId) async {
    if (!AppConfig.enableRemoteSync) return const [];
    try {
      final items = await _apiClient.getCoachMessages(conversationId);
      return items
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => CoachHistoryMessage(
              isUser: (item['role'] as String?) == 'user',
              content: (item['content'] as String?)?.trim() ?? '',
            ),
          )
          .where((m) => m.content.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> fetchSuggestions(String userId) async {
    if (!AppConfig.enableRemoteSync) {
      return [
        'coach_suggestion_budget_schools'.tr,
        'coach_suggestion_top_business_schools'.tr,
        'coach_suggestion_tech_programs'.tr,
      ];
    }
    final items = await _apiClient.getCoachSuggestions(userId);
    return items.map((item) => item.toString()).toList();
  }

  Stream<CoachStreamEvent> sendMessage({
    required String userId,
    required UserProfile profile,
    required String message,
  }) async* {
    final conversationId = await ensureConversation(
      userId: userId,
      profile: profile,
    );

    if (!AppConfig.enableRemoteSync) {
      yield CoachStreamEvent(
        type: 'token',
        text: 'coach_requires_connection'.tr,
      );
      yield const CoachStreamEvent(type: 'done', quotaRemaining: 4);
      return;
    }

    await for (final event in _apiClient.streamCoachReply(
      conversationId: conversationId,
      userId: userId,
      message: message,
      profile: _profilePayload(profile),
    )) {
      yield CoachStreamEvent.fromJson(event);
    }
  }

  Map<String, dynamic> _profilePayload(UserProfile profile) {
    return {
      'fullName': profile.fullName,
      'currentLevel': profile.currentLevel,
      'targetCountryIds': profile.targetCountryIds,
      'annualTuitionBudgetEur': profile.annualTuitionBudgetEur,
      // So the coach answers in the student's language (FR or EN) rather than
      // always French.
      'preferredLanguage': profile.preferredLanguage,
    };
  }
}

class CoachQuota {
  const CoachQuota({
    required this.remaining,
    required this.limit,
    required this.allowed,
    this.unlimited = false,
  });

  final int remaining;
  final int limit;
  final bool allowed;

  /// Pass Karatou actif : usage illimité, sous un garde-fou quotidien que le
  /// serveur applique (`limit` est alors celui du JOUR, pas de la semaine).
  final bool unlimited;

  factory CoachQuota.fromJson(Map<String, dynamic> json) {
    final remaining = json['quotaRemaining'] as int? ?? 0;
    return CoachQuota(
      remaining: remaining,
      limit: json['quotaLimit'] as int? ?? 5,
      allowed: remaining > 0,
      unlimited: json['unlimited'] == true,
    );
  }
}
