import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';

/// Ce que [PushService] attend du backend KPB. [AppApiClient] l'implémente ;
/// les tests branchent un faux.
abstract class PushBackend {
  Future<void> registerDeviceToken(String token, String platform);
  Future<void> unregisterDeviceToken(String token);
  Future<void> reportPushOpened(Map<String, String> payload);
}

/// Notifications push par Firebase Cloud Messaging, en direct.
///
/// Ce qui part, et vers qui (périmètre volontairement fermé) :
/// - vers Google (FCM) : rien que le SDK n'envoie de lui-même pour obtenir un
///   jeton d'appareil — aucun identifiant de profil, aucune étiquette, aucun
///   e-mail ;
/// - vers NOTRE backend : ce jeton et la plateforme (`android` / `ios`),
///   rattachés au compte connecté. C'est le backend qui choisit les
///   destinataires (niveau, pays visé, échéances) à partir du profil qu'il
///   détient déjà — d'où l'abandon des étiquettes de ciblage que l'on confiait
///   à OneSignal.
///
/// Le jeton n'est enregistré que si l'élève a AUTORISÉ les notifications : un
/// jeton sans autorisation fait compter « livrée » une notification que le
/// système n'affichera jamais, et les statistiques de campagne mentiraient.
///
/// Chaque méthode est un no-op tant que [initialize] n'a pas réussi : les tests
/// de widgets (qui ne l'appellent jamais) et un démarrage sans Firebase restent
/// sûrs.
class PushService {
  PushService._internal();
  static final PushService instance = PushService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  PushBackend? _backend;
  FirebaseMessaging? _messaging;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  String? _userId;
  String? _registeredToken;
  String? _registeredFor;

  /// Démarre FCM. À appeler une fois depuis `main()`, après Firebase.
  /// [messaging], [foregroundMessages] et [openedMessages] servent aux tests.
  Future<void> initialize({
    required PushBackend backend,
    FirebaseMessaging? messaging,
    Stream<RemoteMessage>? foregroundMessages,
    Stream<RemoteMessage>? openedMessages,
  }) async {
    if (_initialized) return;
    try {
      final fcm = messaging ?? FirebaseMessaging.instance;
      _backend = backend;
      _messaging = fcm;

      // iOS : pas de bannière système quand l'app est au premier plan — on
      // affiche la nôtre (comme sur Android, où FCM n'affiche rien dans ce cas).
      await fcm.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      _subscriptions
        ..add((foregroundMessages ?? FirebaseMessaging.onMessage)
            .listen(_onForegroundMessage))
        ..add((openedMessages ?? FirebaseMessaging.onMessageOpenedApp)
            .listen(_onMessageOpened))
        ..add(fcm.onTokenRefresh.listen((_) => unawaited(_syncToken())));

      _initialized = true;

      // Démarrage à froid depuis un tap : le navigateur GetX n'existe pas
      // encore, on route après la première image.
      final initial = await fcm.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _onMessageOpened(initial));
      }
    } catch (error) {
      debugPrint('[Push] init skipped: $error');
    }
  }

  /// Demande l'autorisation au système (invite unique sur iOS), puis enregistre
  /// le jeton si l'élève accepte.
  Future<void> requestPermission() async {
    final fcm = _messaging;
    if (!_initialized || fcm == null) return;
    try {
      await fcm.requestPermission();
    } catch (error) {
      debugPrint('[Push] requestPermission failed: $error');
    }
    await _syncToken();
  }

  /// Rattache cet appareil au compte KPB connecté. Appelé à la connexion, à la
  /// fin de l'onboarding et au démarrage à froid d'une session existante.
  Future<void> login({required String userId}) async {
    if (!_initialized || userId.trim().isEmpty) return;
    _userId = userId.trim();
    await _syncToken();
  }

  /// Détache l'appareil (déconnexion, suppression de compte).
  ///
  /// Deux gestes, parce que l'un peut échouer : on retire le jeton côté
  /// backend, ET on l'invalide chez FCM. Si la requête ne passe pas (hors
  /// ligne, session déjà close), le jeton invalidé fera répondre `UNREGISTERED`
  /// au prochain envoi, et le backend le supprimera de lui-même.
  Future<void> logout() async {
    if (!_initialized) return;
    final token = _registeredToken;
    _userId = null;
    _registeredToken = null;
    _registeredFor = null;
    if (token != null) {
      try {
        await _backend?.unregisterDeviceToken(token);
      } catch (error) {
        debugPrint('[Push] unregister failed: $error');
      }
    }
    try {
      await _messaging?.deleteToken();
    } catch (error) {
      debugPrint('[Push] deleteToken failed: $error');
    }
  }

  /// Remet le singleton à zéro entre deux tests.
  @visibleForTesting
  Future<void> debugReset() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
    _backend = null;
    _messaging = null;
    _userId = null;
    _registeredToken = null;
    _registeredFor = null;
  }

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _syncToken() async {
    final fcm = _messaging;
    final backend = _backend;
    final userId = _userId;
    if (fcm == null || backend == null || userId == null) return;
    try {
      final settings = await fcm.getNotificationSettings();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        // Autorisation retirée depuis les réglages : on cesse d'annoncer un
        // appareil joignable.
        final stale = _registeredToken;
        if (stale != null) {
          _registeredToken = null;
          _registeredFor = null;
          await backend.unregisterDeviceToken(stale);
        }
        return;
      }

      // iOS : le jeton FCM dépend du jeton APNs, qui peut arriver après le
      // premier appel. Sans lui `getToken()` lève ; `onTokenRefresh` relancera.
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await fcm.getAPNSToken() == null) {
        return;
      }

      final token = await fcm.getToken();
      if (token == null || token.isEmpty) return;
      if (token == _registeredToken && userId == _registeredFor) return;
      await backend.registerDeviceToken(token, pushPlatformName());
      _registeredToken = token;
      _registeredFor = userId;
    } catch (error) {
      debugPrint('[Push] token sync failed: $error');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    try {
      Get.snackbar(
        notification.title ?? '',
        notification.body ?? '',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(12),
        onTap: (_) => _onMessageOpened(message),
      );
    } catch (error) {
      debugPrint('[Push] foreground banner skipped: $error');
    }
  }

  void _onMessageOpened(RemoteMessage message) {
    final opened = pushOpenedPayload(message.data);
    if (opened.isNotEmpty) {
      unawaited(_reportOpened(opened));
    }
    final route = resolvePushRoute(message.data);
    try {
      if (route == null) {
        Get.offAllNamed(AppRoutes.home);
      } else {
        Get.toNamed(route);
      }
    } catch (error) {
      debugPrint('[Push] route "$route" not navigable: $error');
      try {
        Get.offAllNamed(AppRoutes.home);
      } catch (_) {}
    }
  }

  Future<void> _reportOpened(Map<String, String> payload) async {
    try {
      await _backend?.reportPushOpened(payload);
    } catch (error) {
      debugPrint('[Push] open report failed: $error');
    }
  }
}

/// `android` ou `ios` — les deux seules valeurs que `POST /device-tokens`
/// accepte.
@visibleForTesting
String pushPlatformName() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

/// Destination d'un tap, depuis la charge `data` du message.
///
/// La charge est EXTERNE : on la normalise, et on rend `null` (→ accueil) quand
/// elle ne désigne rien de navigable, pour qu'un tap ne meure jamais en
/// silence. Les anciennes activations de bourse routaient vers la liste et
/// portaient l'identifiant à part : on les promeut vers la fiche.
String? resolvePushRoute(Map<String, dynamic> data) {
  final raw = data['route'];
  var route = raw is String ? AppRoutes.normalizeExternalRoute(raw) : null;
  final scholarshipId = data['scholarshipId'];
  if (route == AppRoutes.scholarships &&
      scholarshipId is String &&
      scholarshipId.trim().isNotEmpty) {
    route = AppRoutes.normalizeExternalRoute(
      AppRoutes.scholarshipDetailPath(scholarshipId.trim()),
    );
  }
  return route;
}

/// Ce que l'app renvoie au backend quand l'élève ouvre une notification :
/// l'identifiant de campagne et/ou la clé du rappel — rien d'autre.
Map<String, String> pushOpenedPayload(Map<String, dynamic> data) {
  final payload = <String, String>{};
  for (final key in const ['campaignId', 'notificationKey']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      payload[key] = value.trim();
    }
  }
  return payload;
}
