import 'package:dio/dio.dart';

/// Ce qu'une erreur de synchro dit du réseau, en une valeur FERMÉE — celle
/// qui part dans `sync_full_complete.error_kind`.
///
/// Jusqu'en octobre 2026, un échec de synchro ne disait rien de sa cause : un
/// téléphone hors réseau, un serveur en panne et un jeton expiré tombaient
/// tous dans `success = 0`. La hausse des échecs sur Android 2.3.0 (6,5 % →
/// 9,6 % pour les mêmes utilisateurs) ne pouvait donc pas être attribuée.
enum SyncErrorKind {
  timeout,
  connection,
  rateLimited,
  unauthorized,
  http4xx,
  http5xx,
  other;

  String get wireValue => switch (this) {
        SyncErrorKind.timeout => 'timeout',
        SyncErrorKind.connection => 'connection',
        SyncErrorKind.rateLimited => 'rate_limited',
        SyncErrorKind.unauthorized => 'unauthorized',
        SyncErrorKind.http4xx => 'http_4xx',
        SyncErrorKind.http5xx => 'http_5xx',
        SyncErrorKind.other => 'other',
      };
}

SyncErrorKind classifySyncError(Object error) {
  if (error is! DioException) return SyncErrorKind.other;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return SyncErrorKind.timeout;
    case DioExceptionType.connectionError:
      return SyncErrorKind.connection;
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 429) return SyncErrorKind.rateLimited;
      if (status == 401 || status == 403) return SyncErrorKind.unauthorized;
      if (status >= 500) return SyncErrorKind.http5xx;
      if (status >= 400) return SyncErrorKind.http4xx;
      return SyncErrorKind.other;
    case DioExceptionType.unknown:
      // Dio range ici les SocketException / HandshakeException que l'adaptateur
      // n'a pas su qualifier : sur mobile, c'est presque toujours le réseau.
      return error.error == null
          ? SyncErrorKind.other
          : SyncErrorKind.connection;
    // badCertificate, cancel — et toute valeur que Dio ajouterait : jamais
    // passagère. Volontairement non exhaustif, pour qu'un `pub upgrade` ne
    // casse pas la compilation.
    default:
      return SyncErrorKind.other;
  }
}

/// Vrai pour une panne qui peut passer d'elle-même : délai dépassé, connexion
/// coupée, serveur en 5xx. Jamais pour un 4xx : un 401 ou un 429 rejoué tout
/// de suite échoue pareil (ou aggrave la limite de débit).
bool isTransientSyncError(Object error) => switch (classifySyncError(error)) {
      SyncErrorKind.timeout ||
      SyncErrorKind.connection ||
      SyncErrorKind.http5xx =>
        true,
      _ => false,
    };

/// Rejoue [operation] tant qu'elle échoue sur une panne passagère, au plus
/// [attempts] fois, avec une attente croissante entre deux essais.
///
/// La synchro du catalogue faisait déjà trois essais par ressource ; les
/// appels authentifiés de la même synchro (profil, dossiers, favoris) n'en
/// faisaient qu'UN : une seule coupure de quelques secondes — fréquente sur
/// les réseaux mobiles du public visé — faisait échouer toute la synchro.
Future<T> retryTransient<T>(
  Future<T> Function() operation, {
  int attempts = 3,
  Duration Function(int attempt)? delay,
}) async {
  final wait =
      delay ?? (attempt) => Duration(milliseconds: 400 * (1 << attempt));
  for (var attempt = 0;; attempt++) {
    try {
      return await operation();
    } catch (error) {
      if (attempt >= attempts - 1 || !isTransientSyncError(error)) rethrow;
      await Future<void>.delayed(wait(attempt));
    }
  }
}
