part of '../app_api_client.dart';

/// Coach IA : quota, conversations, réponse en flux.
mixin _CoachApi on _ApiClientBase {
  // ── Coach IA (M10) ────────────────────────────────────────────

  Future<Map<String, dynamic>> getCoachQuota(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/coach/quota',
      queryParameters: {'userId': userId},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createCoachConversation({
    required String userId,
    required Map<String, dynamic> profile,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/coach/conversations',
      data: {'userId': userId, 'profile': profile},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> getCoachMessages(String conversationId) async {
    final response = await _dio.get<List<dynamic>>(
      '/coach/conversations/$conversationId/messages',
    );
    return response.data ?? const [];
  }

  Future<List<dynamic>> getCoachSuggestions(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/coach/suggestions',
      queryParameters: {'userId': userId},
    );
    final data = response.data ?? <String, dynamic>{};
    return data['suggestions'] as List<dynamic>? ?? const [];
  }

  /// Réponse du coach en flux SSE.
  ///
  /// Le message part dans le CORPS d'un `POST` (audit du 22/11/2026, constat
  /// 33) : en query string sur l'ancien `GET`, ce texte libre — où l'élève
  /// décrit ses notes, ses finances, sa famille — finissait dans les journaux
  /// d'accès des proxys, du CDN et de l'hébergeur. Le serveur garde le `GET`
  /// pour les versions déjà installées ; cette version ne l'appelle plus.
  ///
  /// [userId] n'est pas envoyé : le serveur prend l'élève authentifié.
  Stream<Map<String, dynamic>> streamCoachReply({
    required String conversationId,
    required String userId,
    required String message,
    required Map<String, dynamic> profile,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/coach/conversations/$conversationId/messages/stream',
      data: coachStreamRequestBody(message: message, profile: profile),
      options: Options(
        responseType: ResponseType.stream,
        headers: const {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) return;

    var buffer = '';
    // Décodage en FLUX : décoder chaque paquet séparément corrompait un
    // caractère accentué coupé entre deux paquets (« é » → « �� »).
    await for (final chunk
        in const Utf8Decoder(allowMalformed: true).bind(stream)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        try {
          yield jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          // Ignore malformed SSE chunks.
        }
      }
    }
  }
}

/// Corps de `POST /coach/conversations/:id/messages/stream`.
///
/// Mêmes champs de profil que l'ancien `GET` : pas de `fullName` (le serveur
/// ne transmet jamais le nom au modèle) ni de budget. Le serveur refuse tout
/// champ inconnu (validation `forbidNonWhitelisted`) : n'ajouter ici qu'un
/// champ que `StreamCoachMessageDto` déclare.
@visibleForTesting
Map<String, dynamic> coachStreamRequestBody({
  required String message,
  required Map<String, dynamic> profile,
}) {
  final targetCountryIds = profile['targetCountryIds'];
  final currentLevel = profile['currentLevel'];
  final preferredLanguage = profile['preferredLanguage'];
  return <String, dynamic>{
    'message': message,
    'profile': <String, dynamic>{
      if (currentLevel is String) 'currentLevel': currentLevel,
      'targetCountryIds': targetCountryIds is List
          ? targetCountryIds.whereType<String>().toList()
          : const <String>[],
      if (preferredLanguage is String) 'preferredLanguage': preferredLanguage,
    },
  };
}
