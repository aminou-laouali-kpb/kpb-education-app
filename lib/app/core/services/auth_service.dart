import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';
// `LaunchMode` comes from supabase_flutter (it re-exports it); only the
// dismiss helper needs to be pulled from url_launcher directly.
import 'package:url_launcher/url_launcher.dart' show closeInAppWebView;

import '../config/app_config.dart';
import '../repositories/app_api_client.dart';

/// Authentication is delegated to Supabase Auth (Google sign-in + email OTP).
///
/// The Supabase SDK owns session persistence and silent token refresh, so this
/// service is a thin wrapper that exposes the small surface the app relies on:
/// [isLoggedIn], [accessToken], [userId], the email-OTP pair
/// ([requestMagicLink] / [verifyMagicLink]), [signInWithGoogle], and session
/// teardown. Business data still lives in the NestJS/Prisma backend, which
/// trusts the Supabase access token via the `StudentAuthGuard`.
class AuthService {
  AuthService._(this._client, this._apiClient);

  final SupabaseClient _client;
  // Retained so future flows can call backend endpoints; the access token is
  // injected into requests by the Dio interceptor, not from here.
  // ignore: unused_field
  final AppApiClient _apiClient;

  static Future<AuthService> create(AppApiClient apiClient) async {
    return AuthService._(Supabase.instance.client, apiClient);
  }

  /// Pour les tests : un client Supabase simulé.
  @visibleForTesting
  factory AuthService.withClient(
          SupabaseClient client, AppApiClient apiClient) =>
      AuthService._(client, apiClient);

  Session? get _session => _client.auth.currentSession;

  String? get accessToken => _session?.accessToken;
  String? get userId => _session?.user.id;
  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  /// Email of the signed-in user (from the Google OAuth identity or the OTP
  /// address). Used to pre-fill onboarding so a freshly-authenticated user is
  /// never asked for the email they just signed in with.
  String? get sessionEmail {
    final email = _session?.user.email?.trim();
    return (email != null && email.isNotEmpty) ? email : null;
  }

  /// Best-effort full name from the OAuth provider metadata (Google returns
  /// `full_name` / `name`). Null when the provider gave none (e.g. email OTP).
  String? get sessionFullName {
    final md = _session?.user.userMetadata;
    final raw = (md?['full_name'] ?? md?['name']);
    final name = raw is String ? raw.trim() : '';
    return name.isNotEmpty ? name : null;
  }

  /// Streams Supabase auth state changes (login/logout/token refresh).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Sends a 6-digit email OTP (also usable as a magic link). Supabase creates
  /// the user on first verification when `shouldCreateUser` is true.
  ///
  /// PAS de `.timeout(...)` ici, ni sur [verifyMagicLink] (relecture de la PR
  /// #404) : un délai côté app n'annule pas la requête déjà partie. Le code
  /// arrivait quand même par e-mail alors que l'écran disait « Impossible
  /// d'envoyer le code », sans ouvrir l'écran de saisie ; et une vérification
  /// « expirée » ouvrait la session plus tard, après un message d'erreur. On
  /// attend la vraie réponse du serveur (ou l'erreur réseau du système).
  Future<void> requestMagicLink({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
      emailRedirectTo: AppConfig.supabaseOAuthRedirect,
    );
  }

  /// Verifies the email OTP code and establishes a session.
  Future<AuthResponse> verifyMagicLink({
    String? token,
    String? email,
    String? code,
  }) async {
    final otp = (code ?? token ?? '').trim();
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    return _client.auth.verifyOTP(
      type: OtpType.email,
      email: normalizedEmail,
      token: otp,
    );
  }

  /// Launch mode for the OAuth consent screen. Pinned to the **system browser**
  /// on purpose — do not switch this back to `platformDefault`.
  ///
  /// `signInWithOAuth` defaults to [LaunchMode.platformDefault], which
  /// `url_launcher_ios` maps to an in-app `SFSafariViewController` for any
  /// `https` URL. supabase_flutter creates the session from the
  /// `io.supabase.kpbeducation://login-callback/` deep link but never calls
  /// `closeInAppWebView()`, so on iOS that Safari sheet stayed presented over
  /// the app: sign-in succeeded, the app navigated on *behind* it, and the user
  /// was left on the blank redirect page having to tap Done (reproduced on
  /// TestFlight, iPhone / iOS 26). Handing the URL to the system browser removes
  /// the overlay entirely — which is exactly what supabase_flutter already
  /// forces for Google on Android, so this also aligns the two platforms.
  ///
  /// [LaunchMode.inAppWebView] is not an option either way: Google rejects
  /// embedded web views (`disallowed_useragent`).
  static const LaunchMode oauthLaunchMode = LaunchMode.externalApplication;

  /// Launches the Google OAuth flow in the system browser.
  ///
  /// The returned bool only says the consent URL was handed to the browser — it
  /// is **not** the auth result. Sign-in completion is observed through
  /// [onAuthStateChange] (`AuthChangeEvent.signedIn`), which fires once the
  /// redirect deep link comes back into the app.
  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.supabaseOAuthRedirect,
      authScreenLaunchMode: oauthLaunchMode,
    );
  }

  /// Dismisses any in-app browser view still presented over the app after an
  /// auth redirect. A no-op when nothing is presented (the iOS plugin closes an
  /// optional `currentSession`), so it is safe to call on every auth return.
  ///
  /// Belt-and-braces next to [oauthLaunchMode]: it also covers a redirect that
  /// arrives while some other flow left an in-app browser view on screen.
  Future<void> dismissAuthWebView() async {
    try {
      await closeInAppWebView();
    } catch (_) {
      // Platform not available (tests) or nothing to close — nothing to do.
    }
  }

  Future<void> logout() async {
    await clearSession();
  }

  Future<void> clearSession() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
