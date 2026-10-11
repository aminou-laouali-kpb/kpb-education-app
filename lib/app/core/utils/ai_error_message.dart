import 'package:dio/dio.dart';
import 'package:get/get.dart';

/// Honest mapping of AI-tool failures. Extracted from
/// `cv_generator_screen.dart` so every Groq-backed screen says the same
/// thing — and so a 403 `ai_consent_required` can reopen the consent
/// dialog instead of showing "check your connection" (IA-T6).

String? aiConsentBlockCode(Object error) {
  if (error is! DioException) return null;
  if (error.response?.statusCode != 403) return null;
  final data = error.response?.data;
  if (data is Map && data['code'] is String) {
    final code = data['code'] as String;
    // `age_verification_required` manquait ici, et le manque était visible.
    //
    // `AiConsentService` (ai-consent.service.ts:41) rend ce code AVANT les deux
    // autres, dès que le profil n'a pas de date de naissance — profil ancien,
    // compte créé avant la porte d'âge, ou PATCH jamais arrivé. Le code n'étant
    // pas reconnu, `aiErrorMessage` retombait sur le fourre-tout `status == 403`
    // et affichait « connecte-toi » à quelqu'un DÉJÀ connecté : un message faux,
    // qui envoie l'étudiant se déconnecter au lieu de compléter sa date de
    // naissance. Le défaut dormait tant que les outils étaient masqués.
    if (code == 'ai_consent_required' ||
        code == 'guardian_consent_required' ||
        code == 'age_verification_required') {
      return code;
    }
  }
  return null;
}

bool isAiConsentRequiredError(Object error) =>
    aiConsentBlockCode(error) == 'ai_consent_required';

String aiErrorMessage(Object error) {
  const fallback = 'tools_ai_error_check_connection';
  String trOr(String key) {
    final value = key.tr;
    return value == key ? fallback.tr : value;
  }

  if (error is! DioException) {
    return trOr('tools_ai_error_unavailable');
  }
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
      return fallback.tr;
    // The request reached the server and the wait is for the GENERATION:
    // blaming the student's connection was false (measured 26/09/2026 — the
    // API answered, the model was slow).
    case DioExceptionType.receiveTimeout:
      return trOr('tools_ai_error_slow');
    default:
      break;
  }
  final status = error.response?.statusCode;
  final block = aiConsentBlockCode(error);
  if (block == 'guardian_consent_required') {
    return trOr('guardian_consent_required');
  }
  if (block == 'age_verification_required') {
    return trOr('tools_ai_error_birthdate_required');
  }
  if (status == 401 || status == 403) {
    return trOr('tools_ai_error_signin_required');
  }
  final code = _responseCode(error);
  if (status == 429 && code == 'ai_daily_quota_reached') {
    return trOr('tools_ai_error_daily_quota');
  }
  if (status == 413 || code == 'ai_input_too_large') {
    return trOr('tools_ai_error_input_too_large');
  }
  if (status == 429) {
    return trOr('tools_ai_error_rate_limited');
  }
  return trOr('tools_ai_error_unavailable');
}

String? _responseCode(DioException error) {
  final data = error.response?.data;
  return data is Map && data['code'] is String ? data['code'] as String : null;
}
