import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/app_config.dart';
import '../config/app_routes.dart';

/// Thin wrapper around the OneSignal Flutter SDK.
///
/// Design notes:
/// - Every method is a no-op until [initialize] has run. This keeps the rest of
///   the app (and the widget tests, which never call [initialize]) safe — no
///   OneSignal platform channel is ever touched before init.
/// - We link the OneSignal "external id" to the KPB user id on login so the
///   backend can target a known user across devices, and clear it on logout.
///
/// Ce qui part vers OneSignal, et pourquoi (périmètre volontairement fermé) :
/// - l'external id (identifiant de profil KPB) et le jeton de notification :
///   sans eux il n'y a pas de notification adressée à un utilisateur connu ;
/// - quatre étiquettes de ciblage — `account_type`, `level`, `target_country`,
///   `locale`. On les GARDE parce que le ciblage des notifications est une
///   fonctionnalité réellement utilisée (une alerte bourse n'a de sens que
///   pour le bon niveau et le bon pays visé) ; le prix à payer est de les
///   DÉCLARER dans le formulaire de confidentialité des boutiques plutôt que
///   de prétendre qu'elles n'existent pas.
///
/// Ce qui NE part pas : l'adresse e-mail de l'étudiant. OneSignal ne s'en sert
/// que pour ses propres campagnes courriel, et les nôtres passent par Resend
/// (transactionnel) et Mautic (newsletter bourses). On perdait donc une donnée
/// personnelle par la porte d'un canal qu'on n'utilise pas. Écarté : garder
/// l'envoi derrière une case de consentement — cela aurait fait vivre une
/// permission pour une capacité que personne ne réclame.
class OneSignalService {
  OneSignalService._internal();
  static final OneSignalService instance = OneSignalService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Boot OneSignal. Call once from main() after the bindings are ready.
  /// Safe to call when no App ID is configured (becomes a no-op).
  Future<void> initialize() async {
    if (_initialized || !AppConfig.oneSignalEnabled) return;
    try {
      unawaited(OneSignal.Debug.setLogLevel(
        kReleaseMode ? OSLogLevel.none : OSLogLevel.warn,
      ));
      unawaited(OneSignal.initialize(AppConfig.oneSignalAppId));

      // Route taps on a notification to the in-app destination if provided.
      OneSignal.Notifications.addClickListener(_onNotificationClicked);

      _initialized = true;
    } catch (error) {
      debugPrint('[OneSignal] init skipped: $error');
    }
  }

  /// Ask the OS for notification permission (shows the system prompt once).
  Future<void> requestPermission() async {
    if (!_initialized) return;
    try {
      await OneSignal.Notifications.requestPermission(true);
    } catch (error) {
      debugPrint('[OneSignal] requestPermission failed: $error');
    }
  }

  /// Link this device to a known KPB user (external id = profile id) and attach
  /// targeting tags (empty values remove the tag). Called on login, profile
  /// completion and profile edits.
  Future<void> login({
    required String userId,
    // Retained for source compatibility only. Email is deliberately ignored
    // and is never forwarded to the OneSignal SDK.
    String? email,
    Map<String, String> tags = const {},
  }) async {
    if (!_initialized || userId.trim().isEmpty) return;
    try {
      unawaited(OneSignal.login(userId.trim()));
      _applyTags(tags);
    } catch (error) {
      debugPrint('[OneSignal] login failed: $error');
    }
  }

  /// Unlink the external id from this device. Called on sign-out.
  Future<void> logout() async {
    if (!_initialized) return;
    try {
      unawaited(OneSignal.logout());
    } catch (error) {
      debugPrint('[OneSignal] logout failed: $error');
    }
  }

  /// Update targeting tags (e.g. when the profile changes). An empty value
  /// removes that tag.
  Future<void> setTags(Map<String, String> tags) async {
    if (!_initialized) return;
    try {
      _applyTags(tags);
    } catch (error) {
      debugPrint('[OneSignal] setTags failed: $error');
    }
  }

  // ── Internal ────────────────────────────────────────────────────────────

  /// Non-empty values are set; empty ones are REMOVED rather than skipped, so
  /// a value that disappears from the profile (no more target country, an
  /// unrecognised level) doesn't linger in OneSignal and keep the user inside
  /// a segment that no longer describes them.
  void _applyTags(Map<String, String> tags) {
    final toSet = <String, String>{};
    final toRemove = <String>[];
    for (final entry in tags.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        toRemove.add(entry.key);
      } else {
        toSet[entry.key] = value;
      }
    }
    if (toSet.isNotEmpty) OneSignal.User.addTags(toSet);
    if (toRemove.isNotEmpty) OneSignal.User.removeTags(toRemove);
  }

  void _onNotificationClicked(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    final raw = data?['route'];
    // Normalize the external payload and fall back to the home shell when it
    // resolves to nothing (e.g. an unknown or MVP-locked route) so a tap never
    // dies silently. `/scholarships` resolves to a graceful "coming soon".
    var route = raw is String ? AppRoutes.normalizeExternalRoute(raw) : null;
    final scholarshipId = data?['scholarshipId'];
    // Older backend activations route to the generic list and carry the target
    // id separately. Upgrade that payload client-side so the rollout remains
    // backward compatible while new pushes can send the detail route directly.
    if (route == AppRoutes.scholarships &&
        scholarshipId is String &&
        scholarshipId.trim().isNotEmpty) {
      route = AppRoutes.normalizeExternalRoute(
        AppRoutes.scholarshipDetailPath(scholarshipId.trim()),
      );
    }
    try {
      if (route == null) {
        Get.offAllNamed(AppRoutes.home);
      } else {
        Get.toNamed(route);
      }
    } catch (error) {
      debugPrint('[OneSignal] route "$raw" not navigable: $error');
      try {
        Get.offAllNamed(AppRoutes.home);
      } catch (_) {}
    }
  }
}
