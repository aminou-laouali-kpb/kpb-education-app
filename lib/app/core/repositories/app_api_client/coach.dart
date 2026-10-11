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

  Stream<Map<String, dynamic>> streamCoachReply({
    required String conversationId,
    required String userId,
    required String message,
    required Map<String, dynamic> profile,
  }) async* {
    final response = await _dio.get<ResponseBody>(
      '/coach/conversations/$conversationId/messages/stream',
      queryParameters: {
        'userId': userId,
        'message': message,
        // Pas de `fullName` : le serveur ne transmet jamais le nom au modèle,
        // et une query string finit dans les journaux des proxys.
        'currentLevel': profile['currentLevel'],
        'targetCountryIds':
            (profile['targetCountryIds'] as List<dynamic>?)?.join(',') ?? '',
        'lang': profile['preferredLanguage'] ?? '',
      },
      options: Options(responseType: ResponseType.stream),
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
