part of '../app_api_client.dart';

/// Liste d’attente Karatou Premium.
mixin _PremiumApi on _ApiClientBase {
  // ── Liste d'attente Karatou Premium ────────────────────────────────────

  /// L'inscription du profil authentifié, ou l'état « pas inscrit ».
  Future<Map<String, dynamic>> getPremiumWaitlist() async {
    final response = await _dio.get<Map<String, dynamic>>('/premium/waitlist');
    return response.data ?? <String, dynamic>{};
  }

  /// Inscrit le profil authentifié sur la liste d'attente.
  ///
  /// Aucun `try`/`catch` ici, volontairement : l'appelant DOIT voir l'échec.
  /// Une erreur avalée à ce niveau ferait afficher « tu es sur la liste » pour
  /// une ligne que le serveur n'a jamais écrite, et l'étudiant attendrait une
  /// notification qui ne viendrait jamais.
  Future<Map<String, dynamic>> joinPremiumWaitlist({
    required String consentVersion,
    required String consentLocale,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/premium/waitlist',
      data: <String, dynamic>{
        // Envoyé EXPLICITEMENT, et le serveur refuse la requête sans lui : sans
        // ce champ, l'horodatage serveur n'était qu'un `now()` déplacé, et
        // n'importe quel rejeu fabriquait une preuve de consentement.
        'consent': true,
        'consentVersion': consentVersion,
        // La version désigne une PAIRE de textes, français et anglais. Sans la
        // langue, la preuve dit « il a accepté l'un des deux » — et l'on ne
        // saurait plus lequel dès qu'il change de langue.
        'consentLocale': consentLocale,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Retire le profil authentifié de la liste d'attente.
  Future<Map<String, dynamic>> leavePremiumWaitlist() async {
    final response =
        await _dio.delete<Map<String, dynamic>>('/premium/waitlist');
    return response.data ?? <String, dynamic>{};
  }
}
