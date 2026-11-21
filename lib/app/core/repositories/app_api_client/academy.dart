part of '../app_api_client.dart';

/// Cours Academy et Pass Karatou.
///
/// L'app ne vend rien : elle lit les cours publiés et, pour un élève connecté,
/// si son Pass ouvre les leçons réservées.
mixin _AcademyApi on _ApiClientBase {
  /// Les cours visibles (publiés, au moins une leçon publiée).
  Future<List<Map<String, dynamic>>> getAcademyCourses() async {
    final response = await _dio.get<Map<String, dynamic>>('/academy/courses');
    final items = response.data?['items'];
    return items is List
        ? items.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];
  }

  /// Un cours et son programme. [signedIn] choisit la route : connecté, le
  /// serveur ouvre les leçons réservées si le Pass est actif ; sinon, la route
  /// publique les sert verrouillées.
  Future<Map<String, dynamic>> getAcademyCourse(
    String idOrSlug, {
    required bool signedIn,
  }) async {
    final key = Uri.encodeComponent(idOrSlug);
    final response = await _dio.get<Map<String, dynamic>>(
      signedIn ? '/me/academy/courses/$key' : '/academy/courses/$key',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Le statut du Pass Karatou de l'élève connecté.
  Future<Map<String, dynamic>> getMyPass() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/pass');
    return response.data ?? <String, dynamic>{};
  }
}
