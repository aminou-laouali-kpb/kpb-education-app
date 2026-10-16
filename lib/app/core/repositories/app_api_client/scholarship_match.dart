part of '../app_api_client.dart';

/// Classe une erreur d'un appel `/scholarships/match/*` (ou des routes qui
/// l'accompagnent) en [ScholarshipMatchFailure].
///
/// 404 vaut « drapeau fermé » qu'il porte ou non `{disabled: true}` : un
/// backend sans les routes et un backend au drapeau coupé se traitent de la
/// même façon — la carte se masque, rien d'autre.
ScholarshipMatchFailure classifyScholarshipMatchError(Object error) {
  if (error is ScholarshipMatchException) return error.failure;
  if (error is TimeoutException) return ScholarshipMatchFailure.timeout;
  if (error is FormatException || error is TypeError) {
    return ScholarshipMatchFailure.invalid;
  }
  if (error is! DioException) return ScholarshipMatchFailure.server;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return ScholarshipMatchFailure.timeout;
    case DioExceptionType.connectionError:
      return ScholarshipMatchFailure.offline;
    // badCertificate, cancel, badResponse, unknown — et toute valeur future
    // de Dio : le statut HTTP tranche. Volontairement non exhaustif, pour
    // qu'un `pub upgrade` ne casse pas la compilation.
    default:
      break;
  }
  final status = error.response?.statusCode;
  if (status == null) {
    // `unknown` sans réponse : une SocketException ou équivalent.
    return ScholarshipMatchFailure.offline;
  }
  if (status == 404 || status == 405 || status == 501) {
    return ScholarshipMatchFailure.disabled;
  }
  if (status == 401) return ScholarshipMatchFailure.unauthorized;
  if (status == 403) return ScholarshipMatchFailure.forbidden;
  if (status == 429) return ScholarshipMatchFailure.rateLimited;
  if (status == 408) return ScholarshipMatchFailure.timeout;
  return ScholarshipMatchFailure.server;
}

/// Vrai quand une réponse 404 porte la forme promise par le serveur au
/// drapeau coupé (`{disabled: true}`).
bool isScholarshipMatchDisabledResponse(Object error) {
  if (error is! DioException) return false;
  final data = error.response?.data;
  return error.response?.statusCode == 404 &&
      data is Map &&
      data['disabled'] == true;
}

/// « Mes 10 bourses » (chantier D côté serveur, H côté app).
///
/// Les réponses du test ne voyagent JAMAIS par `PATCH /profiles/me` : elles
/// partent dans `POST /scholarships/match/runs`, en UNE requête qui écrit les
/// réponses et calcule le run dans une transaction. Une panne ici ne touche
/// donc jamais la synchronisation du profil.
mixin _ScholarshipMatchApi on _ApiClientBase {
  static String _lang(String lang) => lang == 'en' ? 'en' : 'fr';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ScholarshipMatchException {
      rethrow;
    } catch (error) {
      final status = error is DioException ? error.response?.statusCode : null;
      throw ScholarshipMatchException(
        classifyScholarshipMatchError(error),
        status,
      );
    }
  }

  /// `GET /scholarships/match/state?lang=` — préparation, listes servies,
  /// dernier run. Lève [ScholarshipMatchException].
  Future<ScholarshipMatchState> fetchScholarshipMatchState({
    required String lang,
  }) =>
      _guard(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/scholarships/match/state',
          queryParameters: <String, dynamic>{'lang': _lang(lang)},
        );
        final data = response.data;
        if (data == null) {
          throw const ScholarshipMatchException(
            ScholarshipMatchFailure.invalid,
          );
        }
        return ScholarshipMatchState.fromJson(data);
      });

  /// `POST /scholarships/match/runs` — UNE requête : réponses + calcul.
  ///
  /// [answers] ne contient que des clés comprises par le serveur ; une clé ou
  /// un jeton inconnus y seraient abandonnés, jamais refusés.
  Future<MatchRunResponse> createScholarshipMatchRun({
    required String lang,
    Map<String, dynamic>? answers,
    bool confirm = false,
    String trigger = 'wizard',
  }) =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/scholarships/match/runs',
          data: <String, dynamic>{
            'lang': _lang(lang),
            'trigger': trigger,
            if (answers != null && answers.isNotEmpty) 'answers': answers,
            if (confirm) 'confirm': true,
          },
        );
        final parsed = MatchRunResponse.fromJson(response.data);
        if (parsed == null) {
          throw const ScholarshipMatchException(
            ScholarshipMatchFailure.invalid,
          );
        }
        return parsed;
      });

  /// `PUT /scholarships/match/alerts` `{enabled}` — l'opt-in EXPLICITE au push
  /// hebdomadaire « nouvelles bourses compatibles ». Rend l'état confirmé.
  Future<bool> setScholarshipMatchAlerts({required bool enabled}) =>
      _guard(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/scholarships/match/alerts',
          data: <String, dynamic>{'enabled': enabled},
        );
        final confirmed = response.data?['enabled'];
        return confirmed is bool ? confirmed : enabled;
      });

  /// `POST /me/scholarship-alerts` `{scholarshipIds}` — « Suivre les N
  /// compatibles » en une requête (≤ 10 identifiants). Idempotent : un favori
  /// déjà présent n'est jamais retiré.
  Future<MatchBulkFollowResult> subscribeScholarshipAlertsBulk(
    List<String> scholarshipIds,
  ) =>
      _guard(() async {
        final ids = scholarshipIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty && id.length <= 64)
            .toSet()
            .take(10)
            .toList(growable: false);
        final response = await _dio.post<Map<String, dynamic>>(
          '/me/scholarship-alerts',
          data: <String, dynamic>{'scholarshipIds': ids},
        );
        return MatchBulkFollowResult.fromJson(response.data);
      });

  /// `GET /cases?scholarshipId=` — les dossiers DE L'ÉLÈVE liés à cette
  /// bourse (déduplication de « Être accompagné »).
  Future<List<dynamic>> listCasesForScholarship(String scholarshipId) async {
    final response = await _dio.get<List<dynamic>>(
      '/cases',
      queryParameters: <String, dynamic>{'scholarshipId': scholarshipId},
    );
    return response.data ?? <dynamic>[];
  }
}
