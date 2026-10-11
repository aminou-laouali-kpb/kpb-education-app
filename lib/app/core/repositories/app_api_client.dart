import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import '../config/app_config.dart';
import '../controllers/app_controller.dart';
import '../data/catalog_source.dart';
import '../models/app_models.dart';
import 'app_version_headers.dart';

class AppApiClient {
  AppApiClient({Dio? dio, Duration? aiReceiveTimeout})
      : _aiReceiveTimeout = aiReceiveTimeout ??
            const Duration(seconds: AppConfig.aiRequestTimeoutInSeconds),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(
                  seconds: AppConfig.requestTimeoutInSeconds,
                ),
                receiveTimeout: const Duration(
                  seconds: AppConfig.requestTimeoutInSeconds,
                ),
                sendTimeout: const Duration(
                  seconds: AppConfig.requestTimeoutInSeconds,
                ),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(AppVersionHeadersInterceptor());
    _dio.interceptors.add(_AuthInterceptor(_dio));
  }

  final Dio _dio;
  final Duration _aiReceiveTimeout;

  /// Per-request override for AI generation calls: only the wait for the
  /// response grows; connect/send keep the short default, so a real network
  /// failure is still reported quickly.
  Options get _aiOptions => Options(receiveTimeout: _aiReceiveTimeout);

  /// True when an authenticated Supabase session is present.
  Future<bool> hasAuthSession() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return token != null && token.isNotEmpty;
  }

  /// Dio CONCATENATES `baseUrl + path` (`dio/lib/src/options.dart`) — it does
  /// not resolve URIs. Since `resolveApiBaseUrl` ends in `/api` with no trailing
  /// slash, a path without a leading slash silently produced
  /// `https://api.kpbeducation.cloud/apitools/cv-summary` → 404. That shipped:
  /// three AI features (CV summary, letter personalisation, interview
  /// simulator) and the impact stats were dead in production, all reporting
  /// « vérifiez votre connexion ». Normalising here kills the trap for good —
  /// fixing the five call sites alone would let the next one reintroduce it.
  static String _normalizePath(String path) =>
      path.startsWith('/') ? path : '/$path';

  /// Generic POST for auth endpoints (no token needed).
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _normalizePath(path),
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// POST to an AI generation endpoint (`/tools/*`): same as [post], with the
  /// long AI receive timeout ([AppConfig.aiRequestTimeoutInSeconds]).
  Future<Map<String, dynamic>> postAi(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _normalizePath(path),
      data: payload,
      options: _aiOptions,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Generic GET returning a JSON object.
  Future<Map<String, dynamic>> get(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _normalizePath(path),
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Public app config (`/config/app`) — drives the force-update gate.
  Future<Map<String, dynamic>> getAppConfig() => get('/config/app');

  // Legacy /device-tokens registration removed: push identity is now owned
  // end-to-end by OneSignal (see OneSignalService), and these client methods
  // were never called. The backend table is retained for now.

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/profiles/me');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> payload) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/profiles/me',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// GDPR data export (portability): the backend aggregates every user-owned
  /// record into one JSON document.
  Future<Map<String, dynamic>> getAccountExport() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/profiles/me/export');
    return response.data ?? <String, dynamic>{};
  }

  /// GDPR / store-required account deletion: hard-deletes all server-side data
  /// (and, best-effort, the Supabase auth identity).
  Future<void> deleteAccount() async {
    await _dio.delete<void>('/profiles/me');
  }

  // ── Profile photo (avatar) ─────────────────────────────────────────────
  //
  // The avatar is a PRIVATE object: `GET /profiles/me/avatar` is authenticated
  // and 404s when the user has none. The profile never exposes a storage path,
  // only `hasAvatar` / the URL of this endpoint. A bare `Image.network` on it
  // therefore gets a 401 — see [authImageHeaders].

  /// Absolute URL of the authenticated avatar stream.
  ///
  /// Built from the live Dio `baseUrl` (not `AppConfig.apiBaseUrl`) so an
  /// injected test client points at its own host.
  String get avatarStreamUrl => '${_dio.options.baseUrl}/profiles/me/avatar';

  /// Bearer header for image fetches that go OUTSIDE Dio.
  ///
  /// `cached_network_image` uses its own HTTP client, so [_AuthInterceptor] —
  /// which attaches the token and transparently refreshes on 401 — never runs
  /// for the avatar. The expiry is therefore handled here: an expired session
  /// is refreshed once before the header is handed out.
  ///
  /// Returns null when no usable session exists (guest, signed-out, Supabase
  /// not initialised as in widget tests). Callers must then render the initials
  /// fallback rather than fire a request that can only fail.
  Future<Map<String, String>?> authImageHeaders() async {
    try {
      final auth = Supabase.instance.client.auth;
      var session = auth.currentSession;
      if (session == null) return null;
      if (session.isExpired) {
        try {
          session = (await auth.refreshSession()).session;
        } catch (_) {
          return null;
        }
      }
      final token = session?.accessToken;
      if (token == null || token.isEmpty) return null;
      return <String, String>{'Authorization': 'Bearer $token'};
    } catch (_) {
      // Supabase.instance throws when the SDK was never initialised.
      return null;
    }
  }

  /// Uploads the profile photo (multipart field `file`) and returns the updated
  /// profile. The image must already be downscaled client-side — the caller is
  /// [ProfileAvatar], which caps it at 512 px before we ever touch the network.
  /// Prend des OCTETS, pas un chemin de fichier.
  ///
  /// `image_picker` rend un `XFile`, qui abstrait sa source : disque sur mobile,
  /// mémoire ailleurs (et dans les tests). Passer par `MultipartFile.fromFile`
  /// forçait un accès disque réel — invisible en production, mais l'envoi ne
  /// partait jamais sous l'horloge simulée des tests de widgets, sans erreur ni
  /// trace. Lire via `XFile.readAsBytes()` en amont rend la chaîne complète
  /// observable et fonctionne quelle que soit l'origine du fichier.
  Future<Map<String, dynamic>> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/profiles/me/avatar',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Removes the profile photo. Idempotent by backend contract.
  Future<void> deleteAvatar() async {
    await _dio.delete<void>('/profiles/me/avatar');
  }

  // ── Espace « Études en France » ────────────────────────────────────────

  /// La déclaration d'intérêt du profil authentifié, ou l'état « pas déclaré ».
  Future<Map<String, dynamic>> getEefInterest() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/etudes-en-france/interest',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Déclare l'intérêt du profil authentifié pour l'espace.
  ///
  /// Aucun `try`/`catch` ici, volontairement : l'appelant DOIT voir l'échec.
  /// Une erreur avalée à ce niveau ferait afficher « c'est noté » pour une ligne
  /// que le serveur n'a jamais écrite — le défaut exact que le masquage
  /// `documentUploadEnabled` documente, où « fourni ✓ » était coché avant
  /// l'appel réseau et l'échec disparaissait dans Crashlytics.
  Future<Map<String, dynamic>> declareEefInterest({
    required String consentVersion,
    String? currentLevel,
    String? targetLevel,
    List<String> fieldIds = const <String>[],
    bool wantsPremium = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/etudes-en-france/interest',
      data: <String, dynamic>{
        // Le consentement est envoyé EXPLICITEMENT, et le serveur refuse la
        // requête sans lui. Ce n'est pas une formalité : avant ce champ, le
        // serveur horodatait chaque écriture, donc n'importe quelle requête —
        // un rejeu, un retry automatique — fabriquait une preuve de
        // consentement. `consentVersion` dit QUEL texte a été affiché, sans
        // quoi on ne pourrait produire qu'une date.
        'consent': true,
        'consentVersion': consentVersion,
        if (currentLevel != null && currentLevel.isNotEmpty)
          'currentLevel': currentLevel,
        if (targetLevel != null && targetLevel.isNotEmpty)
          'targetLevel': targetLevel,
        if (fieldIds.isNotEmpty) 'fieldIds': fieldIds,
        'wantsPremium': wantsPremium,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Met à jour les NIVEAUX et les DOMAINES d'une déclaration existante — rien
  /// d'autre (`PATCH /etudes-en-france/interest`).
  ///
  /// Ne touche ni au consentement, ni à la version du texte accepté, ni à
  /// l'intérêt Premium : `POST` est un remplacement complet qui réécrit tout cela
  /// et fabriquerait un consentement au rappel que l'étudiant n'a pas redonné.
  ///
  /// Trois états par champ, comme côté serveur : `null` = inchangé, chaîne ou
  /// liste vide = effacé, valeur = remplacée.
  ///
  /// Pas de `try`/`catch` : l'appelant DOIT voir l'échec, pour la même raison que
  /// [declareEefInterest].
  Future<Map<String, dynamic>> updateEefProfile({
    String? currentLevel,
    String? targetLevel,
    List<String>? fieldIds,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/etudes-en-france/interest',
      data: <String, dynamic>{
        if (currentLevel != null) 'currentLevel': currentLevel,
        if (targetLevel != null) 'targetLevel': targetLevel,
        if (fieldIds != null) 'fieldIds': fieldIds,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Retire la déclaration d'intérêt du profil authentifié.
  ///
  /// Pas de `try`/`catch`, comme la déclaration : l'appelant DOIT voir l'échec.
  /// Afficher « tu es retiré » sur une ligne toujours en base serait le même
  /// mensonge que « c'est noté » sur une ligne jamais écrite.
  Future<Map<String, dynamic>> withdrawEefInterest() async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/etudes-en-france/interest',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Recherche paginée du catalogue « Études en France ».
  ///
  /// PUBLIQUE : aucune session n'est requise. C'est la décision produit
  /// « catalogue gratuit, accompagnement payant » — chercher sa formation avant
  /// de créer un compte est précisément ce qui donne une raison d'en créer un.
  ///
  /// Les listes partent en valeurs séparées par des virgules. Le serveur
  /// accepte aussi la forme répétée (`?cycle=a&cycle=b`) ; on retient la
  /// première parce qu'elle tient dans une URL plus courte, ce qui compte sur
  /// les réseaux du public visé.
  ///
  /// Pas de `try`/`catch` : l'appelant DOIT voir l'échec. Une liste vide rendue
  /// sur une panne se lirait « aucune formation ne correspond », ce qui est un
  /// mensonge — et le contrôleur distingue justement les deux.
  Future<Map<String, dynamic>> searchEefCatalog({
    String? query,
    List<String> cycles = const <String>[],
    List<String> procedureTypes = const <String>[],
    List<String> fieldIds = const <String>[],
    List<String> campusCities = const <String>[],
    List<String> institutionIds = const <String>[],
    List<String> selectivities = const <String>[],
    String? cursor,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/etudes-en-france/search',
      queryParameters: <String, dynamic>{
        ..._eefFilterParams(
          query: query,
          cycles: cycles,
          procedureTypes: procedureTypes,
          fieldIds: fieldIds,
          campusCities: campusCities,
          institutionIds: institutionIds,
          selectivities: selectivities,
        ),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Les villes du catalogue sous les filtres posés — `GET
  /// /etudes-en-france/cities`, PUBLIQUE comme la recherche.
  ///
  /// Sert la feuille « Ville » : la facette `campusCity` de la recherche est
  /// tronquée à 20 villes, alors que la France en compte plusieurs centaines
  /// où une formation est offerte. Cette route rend la liste ENTIÈRE, avec le
  /// compte de formations de chaque ville.
  ///
  /// Mêmes paramètres de filtre que [searchEefCatalog], SAUF `campusCity` :
  /// le serveur l'ignore, et une ville déjà cochée ne doit pas réduire la
  /// liste des villes — on veut pouvoir en cocher une autre. Il n'y a donc
  /// volontairement pas de paramètre `campusCities` ici.
  ///
  /// Pas de `try`/`catch`, comme la recherche : l'appelant DOIT voir l'échec.
  /// C'est lui — `EefCatalogController.loadCities` — qui distingue un backend
  /// plus ancien que l'app (404/405/5xx → repli sur la facette) d'une vraie
  /// panne (réseau, 4xx → « Réessayer »).
  Future<Map<String, dynamic>> fetchEefCities({
    String? query,
    List<String> cycles = const <String>[],
    List<String> procedureTypes = const <String>[],
    List<String> fieldIds = const <String>[],
    List<String> institutionIds = const <String>[],
    List<String> selectivities = const <String>[],
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/etudes-en-france/cities',
      queryParameters: _eefFilterParams(
        query: query,
        cycles: cycles,
        procedureTypes: procedureTypes,
        fieldIds: fieldIds,
        institutionIds: institutionIds,
        selectivities: selectivities,
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Les filtres du catalogue, tels qu'ils partent dans l'URL : listes en
  /// valeurs séparées par des virgules, familles vides omises, texte rogné.
  /// Un seul endroit pour la recherche ET pour la liste des villes — deux
  /// copies finiraient par ne plus filtrer pareil, et la liste des villes
  /// compterait alors autre chose que ce que la recherche rend.
  static Map<String, dynamic> _eefFilterParams({
    String? query,
    List<String> cycles = const <String>[],
    List<String> procedureTypes = const <String>[],
    List<String> fieldIds = const <String>[],
    List<String> campusCities = const <String>[],
    List<String> institutionIds = const <String>[],
    List<String> selectivities = const <String>[],
  }) {
    String? csv(List<String> values) =>
        values.isEmpty ? null : values.join(',');

    return <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (csv(cycles) != null) 'cycle': csv(cycles),
      if (csv(procedureTypes) != null) 'procedureType': csv(procedureTypes),
      if (csv(fieldIds) != null) 'fieldId': csv(fieldIds),
      if (csv(campusCities) != null) 'campusCity': csv(campusCities),
      if (csv(institutionIds) != null) 'institutionId': csv(institutionIds),
      if (csv(selectivities) != null) 'selectivity': csv(selectivities),
    };
  }

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

  // ── Success Lab / competition readiness ────────────────────────────────

  /// Effective server-owned access decision for the authenticated student.
  Future<Map<String, dynamic>> getSuccessLabAccess() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/access',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabWorkspaces({
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces',
      queryParameters: <String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Creates or returns the unique workspace for one scholarship cycle.
  /// Retrying with the same [idempotencyKey] is safe by backend contract.
  Future<Map<String, dynamic>> createSuccessLabWorkspace({
    required String scholarshipId,
    required String cycleId,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces',
      data: <String, dynamic>{
        'scholarshipId': scholarshipId,
        'cycleId': cycleId,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabWorkspace(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Applies one idempotent step transition. [clientMutationId] must remain
  /// unchanged across transport retries.
  Future<Map<String, dynamic>> updateSuccessLabWorkspaceStep({
    required String workspaceId,
    required String stepId,
    required String status,
    required String clientMutationId,
    required int expectedVersion,
    String? notApplicableReason,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/steps/'
      '${Uri.encodeComponent(stepId)}',
      data: <String, dynamic>{
        'status': status,
        'clientMutationId': clientMutationId,
        'expectedVersion': expectedVersion,
        if (notApplicableReason != null)
          'notApplicableReason': notApplicableReason,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateSuccessLabWorkspaceLifecycle({
    required String workspaceId,
    required String action,
    required int expectedVersion,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}',
      data: <String, dynamic>{
        'action': action,
        'expectedVersion': expectedVersion,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabAiNotice({
    required String language,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/consents/ai/notice',
      queryParameters: <String, dynamic>{'language': language},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> grantSuccessLabAiConsent({
    required String languageCode,
    required String noticeVersion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/consents/ai',
      data: <String, dynamic>{
        'languageCode': languageCode,
        'noticeVersion': noticeVersion,
        'accepted': true,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabDiagnostic(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/diagnostic',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabDiagnostic({
    required String workspaceId,
    required String language,
    required String idempotencyKey,
    String? applicationExcerpt,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/diagnostic',
      data: <String, dynamic>{
        'language': language,
        if (applicationExcerpt?.trim().isNotEmpty == true)
          'applicationExcerpt': applicationExcerpt!.trim(),
      },
      options: _aiOptions.copyWith(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabStudyReviewNotice({
    required String language,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/consents/study-review/notice',
      queryParameters: <String, dynamic>{'language': language},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> grantSuccessLabStudyReviewConsent({
    required String languageCode,
    required String noticeVersion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/consents/study-review',
      data: <String, dynamic>{
        'languageCode': languageCode,
        'noticeVersion': noticeVersion,
        'accepted': true,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabArtifacts(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/artifacts',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabArtifactUploadIntent({
    required String workspaceId,
    required String kind,
    required String title,
    required String originalFileName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/artifacts/upload-intents',
      data: <String, dynamic>{
        'kind': kind,
        'title': title,
        'originalFileName': originalFileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> completeSuccessLabArtifactUpload({
    required String versionId,
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/artifact-versions/'
      '${Uri.encodeComponent(versionId)}/complete',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteSuccessLabArtifactVersion({
    required String versionId,
    required String reason,
  }) async {
    await _dio.delete<void>(
      '/competition-readiness/artifact-versions/'
      '${Uri.encodeComponent(versionId)}',
      data: <String, dynamic>{'reason': reason},
    );
  }

  Future<Map<String, dynamic>> createSuccessLabStudyReview({
    required String workspaceId,
    required List<String> artifactVersionIds,
    required String consentReceiptId,
    required String idempotencyKey,
    String? studentMessage,
    String preferredContact = 'in_app',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/review-requests',
      data: <String, dynamic>{
        'artifactVersionIds': artifactVersionIds,
        'consentReceiptId': consentReceiptId,
        if (studentMessage?.trim().isNotEmpty == true)
          'studentMessage': studentMessage!.trim(),
        'preferredContact': preferredContact,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getActiveSuccessLabStudyReview(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/review-requests/active',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabStudyReview(
    String reviewRequestId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateSuccessLabStudyReview({
    required String reviewRequestId,
    required int expectedVersion,
    String? studentMessage,
    String? preferredContact,
    String? timezone,
    Map<String, Object?>? availability,
    List<String>? artifactVersionIds,
    String? consentReceiptId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}',
      data: <String, dynamic>{
        'expectedVersion': expectedVersion,
        if (studentMessage?.trim().isNotEmpty == true)
          'studentMessage': studentMessage!.trim(),
        if (preferredContact?.trim().isNotEmpty == true)
          'preferredContact': preferredContact!.trim(),
        if (timezone?.trim().isNotEmpty == true) 'timezone': timezone!.trim(),
        if (availability != null) 'availability': availability,
        if (artifactVersionIds?.isNotEmpty == true)
          'artifactVersionIds': artifactVersionIds,
        if (consentReceiptId?.trim().isNotEmpty == true)
          'consentReceiptId': consentReceiptId!.trim(),
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabStudyReviewSlotOffers(
    String reviewRequestId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}/slot-offers',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> bookSuccessLabStudyReviewAppointment({
    required String reviewRequestId,
    required int expectedVersion,
    required String slotOfferId,
    required String bookingKey,
    required String timezone,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/review-requests/'
      '${Uri.encodeComponent(reviewRequestId)}/appointments',
      data: <String, dynamic>{
        'expectedVersion': expectedVersion,
        'slotOfferId': slotOfferId,
        'bookingKey': bookingKey,
        'timezone': timezone,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabSubmissions(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/submissions',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> listSuccessLabDecisions(
    String workspaceId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/decisions',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSuccessLabOutcomeConsentNotice({
    required String workspaceId,
    required String language,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/consents/outcome-evidence/notice',
      queryParameters: <String, dynamic>{'language': language},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> grantSuccessLabOutcomeConsent({
    required String workspaceId,
    required String languageCode,
    required String noticeVersion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/consents',
      data: <String, dynamic>{
        'purpose': 'outcome_evidence',
        'languageCode': languageCode,
        'noticeVersion': noticeVersion,
        'accepted': true,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabOutcomeEvidenceUploadIntent({
    required String workspaceId,
    required String kind,
    required String originalFileName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required String consentReceiptId,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/outcome-evidence/upload-intents',
      data: <String, dynamic>{
        'kind': kind,
        'originalFileName': originalFileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'consentReceiptId': consentReceiptId,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> completeSuccessLabOutcomeEvidenceUpload({
    required String evidenceId,
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/outcome-evidence/'
      '${Uri.encodeComponent(evidenceId)}/complete',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabSubmission({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required DateTime submittedAt,
    required String idempotencyKey,
    String? submissionChannel,
    String? applicationReference,
    String? evidenceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/submissions',
      data: <String, dynamic>{
        'expectedWorkspaceVersion': expectedWorkspaceVersion,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
        if (submissionChannel?.trim().isNotEmpty == true)
          'submissionChannel': submissionChannel!.trim(),
        if (applicationReference?.trim().isNotEmpty == true)
          'applicationReference': applicationReference!.trim(),
        if (evidenceId?.trim().isNotEmpty == true)
          'evidenceId': evidenceId!.trim(),
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabAdmissionDecision({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required String issuedByName,
    required String admissionDecision,
    required DateTime receivedAt,
    required String idempotencyKey,
    DateTime? issuedAt,
    String? evidenceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/admission-decisions',
      data: <String, dynamic>{
        'expectedWorkspaceVersion': expectedWorkspaceVersion,
        'issuedByName': issuedByName.trim(),
        'admissionDecision': admissionDecision,
        'receivedAt': receivedAt.toUtc().toIso8601String(),
        if (issuedAt != null) 'issuedAt': issuedAt.toUtc().toIso8601String(),
        if (evidenceId?.trim().isNotEmpty == true)
          'evidenceId': evidenceId!.trim(),
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createSuccessLabFundingDecision({
    required String workspaceId,
    required int expectedWorkspaceVersion,
    required String issuedByName,
    required String fundingDecision,
    required DateTime receivedAt,
    required String idempotencyKey,
    DateTime? issuedAt,
    String? evidenceId,
    String? admissionDecisionId,
    String? fundingAmountMinor,
    String? fundingCurrency,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/workspaces/'
      '${Uri.encodeComponent(workspaceId)}/funding-decisions',
      data: <String, dynamic>{
        'expectedWorkspaceVersion': expectedWorkspaceVersion,
        'issuedByName': issuedByName.trim(),
        'fundingDecision': fundingDecision,
        'receivedAt': receivedAt.toUtc().toIso8601String(),
        if (issuedAt != null) 'issuedAt': issuedAt.toUtc().toIso8601String(),
        if (evidenceId?.trim().isNotEmpty == true)
          'evidenceId': evidenceId!.trim(),
        if (admissionDecisionId?.trim().isNotEmpty == true)
          'admissionDecisionId': admissionDecisionId!.trim(),
        if (fundingAmountMinor != null)
          'fundingAmountMinor': fundingAmountMinor,
        if (fundingCurrency?.trim().isNotEmpty == true)
          'fundingCurrency': fundingCurrency!.trim().toUpperCase(),
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> attachSuccessLabOutcomeEvidence({
    required String outcomeType,
    required String outcomeId,
    required int expectedVersion,
    required String evidenceId,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/competition-readiness/outcomes/'
      '${Uri.encodeComponent(outcomeType)}/'
      '${Uri.encodeComponent(outcomeId)}/evidence',
      data: <String, dynamic>{
        'expectedVersion': expectedVersion,
        'evidenceId': evidenceId,
      },
      options: Options(
        headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Matches (Phase 0 / P0-D — kit US-003/US-004) ──────────────

  /// Top-N server-scored matches for the post-onboarding AHA moment.
  /// Returns `{items: [SchoolMatch JSON], isEstimate: bool}`.
  Future<Map<String, dynamic>> getAhaMatches({int limit = 3}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/matches/aha-moment',
      queryParameters: {'limit': limit},
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Best-scoring program of one institution for the caller.
  Future<Map<String, dynamic>> getSchoolMatch(String institutionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/matches/school/$institutionId',
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Referrals (KPB-69) ────────────────────────────────────────

  /// The caller's stable referral code + attribution stats.
  Future<Map<String, dynamic>> getMyReferral() async {
    final response = await _dio.get<Map<String, dynamic>>('/referrals/me');
    return response.data ?? <String, dynamic>{};
  }

  // ── Ambassadeur program (App-engagement · US-032→035) ─────────────────────

  /// The ambassador dashboard (real data once activated, else a sample
  /// preview). Shape parsed by [AmbassadorDashboard.fromApi].
  Future<Map<String, dynamic>> getAmbassadorDashboard() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/referrals/dashboard');
    return response.data ?? <String, dynamic>{};
  }

  /// Activate ambassador mode for the caller (mints a referral code).
  Future<Map<String, dynamic>> activateAmbassador(
    Map<String, dynamic> input,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/referrals/ambassador/activate',
      data: input,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Request a Wave payout of the FULL available balance (recorded, paid ≤48h).
  /// Returns `{id, amountFCFA, status, etaHours}`.
  Future<Map<String, dynamic>> requestAmbassadorWithdrawal() async {
    final response =
        await _dio.post<Map<String, dynamic>>('/referrals/withdraw');
    return response.data ?? <String, dynamic>{};
  }

  /// Top published counsellor reviews for the Home social-proof carousel.
  /// Returns `{reviews: [{id, counsellorId, reviewerName, rating, body,
  /// createdAt}, ...], count}`. Public endpoint — no auth required.
  Future<Map<String, dynamic>> getPublishedReviews() async {
    final response = await _dio.get<Map<String, dynamic>>('/impact/reviews');
    return response.data ?? <String, dynamic>{};
  }

  /// Attribute the caller to the owner of [code]. Returns
  /// `{attributed, alreadyReferred}`.
  Future<Map<String, dynamic>> redeemReferral(String code) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/referrals/redeem',
      data: {'code': code},
    );
    return response.data ?? <String, dynamic>{};
  }

  /// The caller's no-cash reward balance + recent ledger (KPB-77). Returns
  /// `{balance, history}`.
  Future<Map<String, dynamic>> getMyReferralCredits() async {
    final response = await _dio.get<Map<String, dynamic>>('/referrals/credits');
    return response.data ?? <String, dynamic>{};
  }

  /// Spend credits to mint a WhatsApp advisor review voucher. [clientRef] is a
  /// per-tap idempotency key so a retried call never double-spends. Returns
  /// `{ok, balance, voucherCode}` or `{ok:false, reason}`.
  Future<Map<String, dynamic>> redeemReviewVoucher(String clientRef) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/referrals/credits/redeem-voucher',
      data: {'clientRef': clientRef},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitOrientation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orientation/submit',
      data: payload,
      // Ranking is local, but the explanations come from the LLM.
      options: _aiOptions,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createOrientationSession(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orientation/sessions',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getOrientationResult(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/orientation/results/$sessionId',
    );
    return response.data ?? <String, dynamic>{};
  }

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

  // ── Commercial (M9) ───────────────────────────────────────────

  Future<List<CommercialLead>> listCommercialLeads({
    required String email,
    String filter = 'all',
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/commercial/leads',
      queryParameters: {'email': email, 'filter': filter},
    );
    final items = response.data ?? const [];
    return items
        .map((item) => CommercialLead.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> updateCommercialLead(
    String caseId, {
    String? leadTag,
    String? discussionMotive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/commercial/leads/$caseId',
      data: {
        if (leadTag != null) 'leadTag': leadTag,
        if (discussionMotive != null) 'discussionMotive': discussionMotive,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Records a counsellor's verdict on an uploaded case document.
  /// [status] must be 'validated', 'redo' or 'doubtful'. Returns the updated
  /// document payload (id, reviewStatus, reviewedByName, reviewedAt, …).
  Future<Map<String, dynamic>> reviewCommercialDocument(
    String documentId, {
    required String status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/commercial/documents/$documentId/review',
      data: {'status': status},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getCommercialStats({
    required String email,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/commercial/stats',
      queryParameters: {'email': email},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Parcours & Témoignages (Chantier C) ────────────────────────────────────

  /// Returns the curated Parcours stories (videos + written interviews) from
  /// the DB-backed `/content/parcours` endpoint. Works without a YouTube API
  /// key: the content is served from the backend catalog (or its seed).
  Future<List<ParcoursStory>> listParcoursStories() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/content/parcours',
    );
    final data = response.data ?? <String, dynamic>{};
    final rawItems = (data['items'] as List<dynamic>? ?? const []);
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(ParcoursStory.fromApi)
        .where((s) => s.slug.isNotEmpty)
        .toList();
  }

  /// "Récit de la semaine" (KPB-169). Returns null when no story is featured —
  /// the caller renders nothing rather than promoting an arbitrary story.
  Future<ParcoursStory?> fetchStoryOfWeek() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/content/parcours/featured',
    );
    final story = response.data?['story'];
    if (story is! Map<String, dynamic>) return null;
    final parsed = ParcoursStory.fromApi(story);
    return parsed.slug.isEmpty ? null : parsed;
  }

  Future<List<dynamic>> listCatalog(String resource) async =>
      (await listCatalogEnvelope(resource)).items;

  /// Same call as [listCatalog], keeping the envelope's `source` field.
  ///
  /// The backend tags degraded answers with `source: "mock"` (bundled demo
  /// fixtures served when it cannot reach Postgres). Callers that persist rows
  /// — the offline cache — must check [CatalogListPayload.isTrustworthy] before
  /// storing them, otherwise fake catalog entries get pinned on the device.
  Future<CatalogListPayload> listCatalogEnvelope(String resource) async {
    final queryParameters =
        (resource == 'programs' || resource == 'institutions')
            ? <String, dynamic>{'limit': 1000}
            : null;
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/$resource',
      queryParameters: queryParameters,
    );
    final data = response.data ?? <String, dynamic>{};
    return CatalogListPayload(
      items: data['items'] as List<dynamic>? ?? <dynamic>[],
      source: CatalogDataSource.parse(data['source']),
    );
  }

  Future<Map<String, dynamic>> getCountryDetail(String countryKey) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/countries/${Uri.encodeComponent(countryKey)}',
    );
    return response.data ?? <String, dynamic>{};
  }

  // Country quiz submit endpoint removed (KPB-62): eligibility is scored
  // client-side by the single EligibilityEngine.

  /// Fetch live scraped scholarships, filtered and scored by the user's profile.
  Future<List<dynamic>> fetchLiveScholarships({
    required String lang,
    String? level,
    List<String>? fieldIds,
    String? countryId,
    String? fundingType,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'lang': lang,
      'limit': limit,
      'offset': offset,
      if (level != null) 'level': level,
      if (fieldIds != null && fieldIds.isNotEmpty) 'fields': fieldIds.join(','),
      if (countryId != null) 'countryId': countryId,
      if (fundingType != null) 'fundingType': fundingType,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/scholarships',
      queryParameters: queryParams,
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  /// Fetch one full scholarship when the detail endpoint is available, with a
  /// bounded list-scan fallback for deployments that still expose only
  /// `GET /scholarships`.
  ///
  /// [initial] is returned when a refresh fails after the student already
  /// opened the item from a populated list, so staged backend rollouts do not
  /// turn a useful cached detail into an error screen.
  Future<LiveScholarshipModel?> fetchLiveScholarshipDetailWithFallback({
    required String scholarshipId,
    required String lang,
    LiveScholarshipModel? initial,
  }) async {
    DioException? detailError;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/scholarships/${Uri.encodeComponent(scholarshipId)}',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      final raw = data['item'] is Map
          ? Map<String, dynamic>.from(data['item'] as Map)
          : data;
      if ((raw['id'] as String? ?? '').isNotEmpty) {
        return LiveScholarshipModel.fromJson(raw);
      }
    } on DioException catch (error) {
      detailError = error;
      final status = error.response?.statusCode;
      // Only an unavailable/not-yet-deployed endpoint should trigger the list
      // scan. Connectivity and authentication errors retain any initial item.
      if (status != 404 && status != 405 && status != 501) {
        if (initial != null) return initial;
        rethrow;
      }
    }

    const pageSize = 100;
    const maxPages = 5;
    try {
      for (var page = 0; page < maxPages; page++) {
        final raw = await fetchLiveScholarships(
          lang: lang,
          limit: pageSize,
          offset: page * pageSize,
        );
        for (final entry in raw.whereType<Map>()) {
          final json = Map<String, dynamic>.from(entry);
          if (json['id'] == scholarshipId) {
            return LiveScholarshipModel.fromJson(json);
          }
        }
        if (raw.length < pageSize) break;
      }
    } catch (_) {
      if (initial != null) return initial;
      if (detailError != null) throw detailError;
      rethrow;
    }
    return initial;
  }

  /// Today's featured scholarship (`GET /scholarships/daily`), or null when
  /// none is eligible. Same DTO shape as the detail endpoint; best-effort — the
  /// Home card self-hides on any error.
  Future<LiveScholarshipModel?> fetchDailyScholarship({
    required String lang,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/scholarships/daily',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      final raw = data['scholarship'];
      if (raw is Map && ((raw['id'] as String?) ?? '').isNotEmpty) {
        return LiveScholarshipModel.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Best-effort: the daily card degrades to hidden.
    }
    return null;
  }

  /// Scholarships for which the current student explicitly requested alerts.
  Future<Set<String>> fetchScholarshipAlerts() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/scholarship-alerts',
    );
    final items = response.data?['items'] as List<dynamic>? ?? <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => item['scholarshipId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> subscribeScholarshipAlert(String scholarshipId) async {
    await _dio.post<void>(
      '/me/scholarship-alerts/${Uri.encodeComponent(scholarshipId)}',
    );
  }

  Future<void> unsubscribeScholarshipAlert(String scholarshipId) async {
    await _dio.delete<void>(
      '/me/scholarship-alerts/${Uri.encodeComponent(scholarshipId)}',
    );
  }

  /// Durable in-app notifications created by scholarship activation events.
  Future<Map<String, dynamic>> fetchUserNotifications(String lang) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/notifications',
      queryParameters: {'lang': lang},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> markUserNotificationRead(String id) async {
    await _dio.patch<void>(
      '/me/notifications/${Uri.encodeComponent(id)}/read',
    );
  }

  Future<void> markAllUserNotificationsRead() async {
    await _dio.post<void>('/me/notifications/read-all');
  }

  /// Cheapest flight price for a route/date, proxied from Kayak Price-Insights.
  /// Returns the flat contract map `{configured, cached, currency, results:[]}`.
  Future<Map<String, dynamic>> flightRoutes({
    required String origin,
    required String destination,
    required String departDate,
    String? returnDate,
    String currency = 'EUR',
    String? userTrackId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/flights/routes',
      queryParameters: <String, dynamic>{
        'origin': origin,
        'destination': destination,
        'departDate': departDate,
        'currency': currency,
        if (returnDate != null) 'returnDate': returnDate,
        if (userTrackId != null) 'userTrackId': userTrackId,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Cheapest price per day (or month) across a date range, from Kayak
  /// Price-Insights. Returns `{configured, cached, currency, aggregation, days:[]}`.
  Future<Map<String, dynamic>> flightCalendar({
    required String origin,
    required String destination,
    required String dateFrom,
    required String dateTo,
    String aggregation = 'day',
    String currency = 'EUR',
    String? userTrackId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/flights/calendar',
      queryParameters: <String, dynamic>{
        'origin': origin,
        'destination': destination,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'aggregation': aggregation,
        'currency': currency,
        if (userTrackId != null) 'userTrackId': userTrackId,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listContent(String resource) async {
    final response = await _dio.get<Map<String, dynamic>>('/content/$resource');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listCommunity(String resource) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/community/$resource');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listCases() async {
    final response = await _dio.get<List<dynamic>>('/cases');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> getCase(String caseId) async {
    final response = await _dio.get<Map<String, dynamic>>('/cases/$caseId');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listCaseMessages(String caseId) async {
    final response = await _dio.get<List<dynamic>>('/cases/$caseId/messages');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createCaseMessage(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/messages',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadCaseDocument(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/documents',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Multipart upload to `/cases/:id/documents/upload`. The file should
  /// already be compressed client-side via [DocumentUploadService] before
  /// calling this — students pay by the megabyte.
  Future<Map<String, dynamic>> uploadCaseDocumentFile({
    required String caseId,
    required String filePath,
    required String title,
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap(<String, dynamic>{
      'title': title,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/cases/$caseId/documents/upload',
      data: formData,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const {'Accept': 'application/json'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listAppointments() async {
    final response = await _dio.get<List<dynamic>>('/appointments');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/appointments',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listSavedItems() async {
    final response = await _dio.get<List<dynamic>>('/saved-items');
    return response.data ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createSavedItem(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/saved-items',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteSavedItem(String savedItemId) async {
    await _dio.delete<void>('/saved-items/$savedItemId');
  }

  Future<Map<String, dynamic>> createPartnerLead(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/partner-leads',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Parent links (Track C1) ───────────────────────────────────────────────

  Future<Map<String, dynamic>> createParentInvite() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/parent-links/invites',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> acceptParentInvite(String inviteCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/parent-links/accept',
      data: {'inviteCode': inviteCode},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listParentChildren() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/children',
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listParentVisibleCases() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/cases',
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getParentVisibleCase(String caseId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/parent-links/cases/$caseId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setCaseParentVisibility({
    required String caseId,
    required bool parentCanView,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/parent-links/cases/$caseId/visibility',
      data: {'parentCanView': parentCanView},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Payments ──────────────────────────────────────────────────────────────
  // Intentionally not called from the app. Our (largely African) audience
  // settles fees directly with a KPB advisor over WhatsApp rather than through
  // an in-app checkout. The backend `payments` module + endpoints remain for
  // admin/manual reconciliation; the client just no longer initiates them.

  // ── Counsellor marketplace (Track B) ──────────────────────────────────────

  Future<List<dynamic>> listCounsellors({
    String? country,
    String? specialty,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/counsellors',
      queryParameters: {
        if (country != null) 'country': country,
        if (specialty != null) 'specialty': specialty,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getCounsellor(String counsellorId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/counsellors/$counsellorId',
    );
    return response.data ?? <String, dynamic>{};
  }

  /// Submit an admission-milestone review for a counsellor (KPB-75). Enters
  /// moderation (isPublished=false) until an admin publishes it.
  Future<void> submitCounsellorReview({
    required String counsellorId,
    required int rating,
    required String body,
    required String reviewerName,
    String? caseId,
  }) async {
    await _dio.post<void>(
      '/counsellors/${Uri.encodeComponent(counsellorId)}/reviews',
      data: {
        'rating': rating,
        'body': body,
        'reviewerName': reviewerName,
        if (caseId != null) 'caseId': caseId,
      },
    );
  }

  // ── Phase 3 — Service packages ("Dossier prêt" + kits) ────────────────────

  Future<List<dynamic>> listServicePackages({String? category}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/service-packages',
      queryParameters: {
        if (category != null) 'category': category,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getServicePackage(String code) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/service-packages/$code',
    );
    return response.data ?? <String, dynamic>{};
  }

  // purchaseServicePackage() removed: the app no longer initiates in-app
  // checkout. Students arrange payment with an advisor on WhatsApp (see
  // service_packages_screen). The backend purchase endpoint remains available.

  Future<Map<String, dynamic>> createWhatsAppServicePurchase({
    required String packageCode,
    String? caseId,
    String source = 'service_packages',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/purchases/whatsapp',
      data: {
        'packageCode': packageCode,
        if (caseId != null) 'caseId': caseId,
        'source': source,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listMyPurchases() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/purchases');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  // ── Phase 3 — Alumni mentor directory ─────────────────────────────────────

  Future<List<dynamic>> listAlumni({
    String? country,
    String? university,
    int? limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/alumni',
      queryParameters: {
        if (country != null) 'country': country,
        if (university != null) 'university': university,
        if (limit != null) 'limit': limit.toString(),
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getMyAlumniStatus() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/alumni');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> applyAsAlumni({
    required String university,
    required String programme,
    required int graduationYear,
    required String proofUrl,
    String? countryCode,
    String? bioFr,
    String? bioEn,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/alumni/apply',
      data: {
        'alumniUniversity': university,
        'alumniProgramme': programme,
        'alumniGraduationYear': graduationYear,
        'alumniProofUrl': proofUrl,
        if (countryCode != null) 'alumniCountryCode': countryCode,
        if (bioFr != null) 'alumniBioFr': bioFr,
        if (bioEn != null) 'alumniBioEn': bioEn,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setAlumniBadgeVisible(bool visible) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/me/alumni/badge-visible',
      data: {'visible': visible},
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Phase 3 — Partners (credibility layer) ────────────────────────────────

  Future<List<dynamic>> listPartners(
      {String? category, String? country}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/partners',
      queryParameters: {
        if (category != null) 'category': category,
        if (country != null) 'country': country,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<List<dynamic>> listFeaturedPartners({int limit = 12}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/partners/featured',
      queryParameters: {'limit': limit.toString()},
    );
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  // ── AI document review (Sprint 9 — Document Studio) ───────────────────────

  /// Sends a draft (motivation letter or CV) to the backend for structured
  /// AI feedback. [kind] is `'motivation'` or `'cv'`. Student-authenticated;
  /// the auth token is attached by the interceptor like other student calls.
  Future<Map<String, dynamic>> reviewDocument({
    required String kind,
    required String text,
    String language = 'fr',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/document-review',
      data: {'kind': kind, 'text': text, 'language': language},
      options: _aiOptions,
    );
    return response.data ?? <String, dynamic>{};
  }

  // ── Phase 3 — Salon KPB Virtuel ───────────────────────────────────────────

  Future<List<dynamic>> listSalonEvents() async {
    final response = await _dio.get<Map<String, dynamic>>('/salon/events');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }

  Future<Map<String, dynamic>> getSalonEvent(String slug) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/salon/events/$slug',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> registerForSalonSession(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/salon/sessions/$sessionId/register',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> cancelSalonRegistration(String sessionId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/me/salon/sessions/$sessionId/register',
    );
  }

  Future<List<dynamic>> listMySalonRegistrations() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/me/salon/registrations');
    final data = response.data ?? <String, dynamic>{};
    return (data['items'] as List<dynamic>? ?? <dynamic>[]);
  }
}

/// Whether a failed Supabase token refresh means the session is really dead.
///
/// Only an explicit refusal from the auth server (invalid/revoked refresh
/// token: 400/401/403) or a missing session qualifies. Network errors
/// ([AuthRetryableFetchException], socket/timeout errors) and server errors
/// (5xx, [AuthUnknownException]) are transient: the user stays signed in and
/// the next request retries.
@visibleForTesting
bool isPermanentRefreshFailure(Object error) {
  if (error is AuthSessionMissingException) return true;
  if (error is AuthRetryableFetchException) return false;
  if (error is AuthApiException) {
    final status = int.tryParse(error.statusCode ?? '');
    return status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 429;
  }
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth interceptor — injects the Supabase Bearer token, refreshes on 401
// ─────────────────────────────────────────────────────────────────────────────
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for auth endpoints
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }

    final token = _auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.startsWith('/auth/')) {
      return handler.next(err);
    }

    // Bug A: a request that already went through a post-refresh retry must
    // NOT be retried again — that would loop forever if the new token is also
    // rejected (revoked refresh token, clock skew, backend reboot).
    //
    // No logout here either: a fresh token rejected again is far more often a
    // backend hiccup than a dead session, and logout wipes unsynced local data.
    // A truly revoked session surfaces on the next refresh as a non-retryable
    // AuthApiException, which IS treated as permanent below.
    if (err.requestOptions.extra['authRetried'] == true) {
      return handler.next(err);
    }

    // Concurrent 401 while a refresh is in flight — wait for its outcome,
    // then retry exactly once (guarded by the authRetried flag above).
    if (_isRefreshing) {
      final success = await _refreshCompleter?.future ?? false;
      if (!success) return handler.next(err);
      try {
        return handler.resolve(await _retryRequest(err.requestOptions));
      } catch (_) {
        return handler.next(err);
      }
    }

    if (_auth.currentSession == null) {
      // Guest/local-only session — never wipe onboarding on missing token.
      return handler.next(err);
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    // Bug B: separate the refresh from the retry so the catch only handles
    // refresh failures — a retry that throws AFTER a successful refresh must
    // not call complete() on an already-completed completer (StateError).
    bool refreshed = false;
    // Only a definitive refusal from the auth server ends the session. A
    // network failure, a timeout or a 5xx (outage) must NOT log the user out:
    // logout wipes cases, saved items and the unsynced outbox.
    bool permanent = false;
    try {
      final response = await _auth.refreshSession();
      refreshed = response.session != null;
      permanent = !refreshed;
    } catch (error) {
      refreshed = false;
      permanent = isPermanentRefreshFailure(error);
    }
    if (!_refreshCompleter!.isCompleted) {
      _refreshCompleter!.complete(refreshed);
    }
    _isRefreshing = false;

    if (!refreshed) {
      if (permanent) await _handlePermanentFailure();
      _refreshCompleter = null;
      return handler.next(err);
    }

    try {
      final response = await _retryRequest(err.requestOptions);
      _refreshCompleter = null;
      return handler.resolve(response);
    } catch (_) {
      _refreshCompleter = null;
      return handler.next(err);
    }
  }

  Future<void> _handlePermanentFailure() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      if (Get.isRegistered<AppController>()) {
        await Get.find<AppController>().handleSessionLost();
      }
    } catch (_) {}
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    final token = _auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      // No usable token after refresh — bail out instead of sending
      // a literal "Bearer null".
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'No access token available for retry.',
      );
    }
    options.headers['Authorization'] = 'Bearer $token';
    // Mark so a recursive 401 short-circuits to permanent failure (Bug A).
    options.extra['authRetried'] = true;
    return _dio.fetch(options);
  }
}
