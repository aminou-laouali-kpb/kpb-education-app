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
import '../models/community.dart';
import '../models/live_scholarships_query.dart';
import '../models/scholarship_match.dart';
import '../services/notification_router.dart' show NotificationRouterBackend;
import '../services/push_service.dart' show PushBackend;
import '../services/scholarships_offline_cache.dart';
import '../utils/community_mention_tokens.dart';
import 'app_version_headers.dart';

part 'app_api_client/eef.dart';
part 'app_api_client/premium.dart';
part 'app_api_client/success_lab.dart';
part 'app_api_client/engagement.dart';
part 'app_api_client/coach.dart';
part 'app_api_client/commercial.dart';
part 'app_api_client/catalog.dart';
part 'app_api_client/cases.dart';
part 'app_api_client/marketplace.dart';
part 'app_api_client/scholarship_match.dart';
part 'app_api_client/community.dart';

/// Dio CONCATENATES `baseUrl + path` (`dio/lib/src/options.dart`) — it does
/// not resolve URIs. Since `resolveApiBaseUrl` ends in `/api` with no trailing
/// slash, a path without a leading slash silently produced
/// `https://api.kpbeducation.cloud/apitools/cv-summary` → 404. That shipped:
/// three AI features (CV summary, letter personalisation, interview
/// simulator) and the impact stats were dead in production, all reporting
/// « vérifiez votre connexion ». Normalising here kills the trap for good —
/// fixing the five call sites alone would let the next one reintroduce it.
String _normalizePath(String path) => path.startsWith('/') ? path : '/$path';

/// L'en-tête de l'identifiant d'installation, envoyé sur `POST /referrals/redeem`
/// SEULEMENT (lu par `referrals.controller.ts`).
const referralDeviceIdHeader = 'X-KPB-Device-Id';

/// Vrai quand [error] dit « cette route n'existe pas sur ce backend » (404,
/// 405, 501) — le cas d'une build plus récente que le serveur. Pas une panne :
/// l'écran masque la fonction au lieu d'afficher une erreur, et réessaiera à la
/// prochaine ouverture.
bool isEndpointUnavailable(Object error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  return status == 404 || status == 405 || status == 501;
}

/// Les références acceptées par `POST /me/notifications/read-by-ref` : au plus
/// 20, motif `^[A-Za-z0-9:_-]+$`, 200 caractères au plus, sans doublon.
List<String> sanitizeNotificationRefs(Iterable<String> refs) {
  final pattern = RegExp(r'^[A-Za-z0-9:_-]+$');
  final out = <String>[];
  for (final raw in refs) {
    final ref = raw.trim();
    if (ref.isEmpty || ref.length > 200 || !pattern.hasMatch(ref)) continue;
    if (out.contains(ref)) continue;
    out.add(ref);
    if (out.length == 20) break;
  }
  return out;
}

/// What the per-domain mixins need from the client: the shared [Dio] (one
/// instance, one auth interceptor) and the long AI receive timeout.
abstract class _ApiClientBase {
  Dio get _dio;
  Options get _aiOptions;
}

/// REST client of the app. Generic calls and the profile live here; each
/// domain lives in its own mixin under `app_api_client/`.
class AppApiClient extends _ApiClientBase
    with
        _EefApi,
        _PremiumApi,
        _SuccessLabApi,
        _EngagementApi,
        _CoachApi,
        _CommercialApi,
        _CatalogApi,
        _CasesApi,
        _MarketplaceApi,
        _ScholarshipMatchApi,
        _CommunityApi
    implements PushBackend, NotificationRouterBackend {
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

  @override
  final Dio _dio;
  final Duration _aiReceiveTimeout;

  /// Per-request override for AI generation calls: only the wait for the
  /// response grows; connect/send keep the short default, so a real network
  /// failure is still reported quickly.
  @override
  Options get _aiOptions => Options(receiveTimeout: _aiReceiveTimeout);

  /// True when an authenticated Supabase session is present.
  Future<bool> hasAuthSession() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return token != null && token.isNotEmpty;
  }

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

  // ── Push (FCM) ─────────────────────────────────────────────────────────
  // Le backend garde les jetons d'appareil et cible lui-même ; voir
  // PushService.

  @override
  Future<void> registerDeviceToken(String token, String platform) async {
    await _dio.post<void>(
      '/device-tokens',
      data: <String, dynamic>{'token': token, 'platform': platform},
    );
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    await _dio.delete<void>('/device-tokens/${Uri.encodeComponent(token)}');
  }

  /// Tap sur une notification : remplace les taux d'ouverture que donnait le
  /// tableau de bord OneSignal.
  @override
  Future<void> reportPushOpened(Map<String, String> payload) async {
    await _dio.post<void>('/me/push-opens', data: payload);
  }

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
