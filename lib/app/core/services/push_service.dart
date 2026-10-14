import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/components/kpb_toast.dart';
import 'notification_router.dart';
import 'push_permission.dart';

export 'notification_router.dart'
    show pushOpenedPayload, resolveNotificationRoute, resolvePushRoute;
export 'push_permission.dart' show PushPermissionStatus;

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
      // encore. Le routeur garde le tap en file jusqu'à la première image
      // (`NotificationRouter.markReady`, posé par `main()` après `runApp`).
      final initial = await fcm.getInitialMessage();
      if (initial != null) _onMessageOpened(initial);
    } catch (error) {
      debugPrint('[Push] init skipped: $error');
    }
  }

  /// Demande l'autorisation au système (invite unique sur iOS), puis enregistre
  /// le jeton si l'élève accepte. Rend la réponse ; `unavailable` tant que le
  /// push n'est pas initialisé (tests de widgets, démarrage sans Firebase).
  ///
  /// Ne l'appeler que derrière une explication (la feuille du premier
  /// « Suivre ») : la demande système ne se repose pas.
  Future<PushPermissionStatus> requestPermission() async {
    final fcm = _messaging;
    if (!_initialized || fcm == null) return PushPermissionStatus.unavailable;
    var status = PushPermissionStatus.unavailable;
    try {
      final settings = await fcm.requestPermission();
      status = pushPermissionStatusOf(settings.authorizationStatus);
    } catch (error) {
      debugPrint('[Push] requestPermission failed: $error');
    }
    await _syncToken();
    return status;
  }

  /// L'autorisation actuelle, sans rien demander.
  Future<PushPermissionStatus> permissionStatus() async {
    final fcm = _messaging;
    if (!_initialized || fcm == null) return PushPermissionStatus.unavailable;
    try {
      final settings = await fcm.getNotificationSettings();
      return pushPermissionStatusOf(settings.authorizationStatus);
    } catch (error) {
      debugPrint('[Push] permissionStatus failed: $error');
      return PushPermissionStatus.unavailable;
    }
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
      KpbToast.info(
        notification.body ?? '',
        title: notification.title,
        atTop: true,
        duration: const Duration(seconds: 5),
        onTap: () => _onMessageOpened(message),
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
    // Destination, lecture par références et mesure : le routeur, neutre
    // vis-à-vis du fournisseur, s'en charge — et garde le tap en file tant que
    // l'app n'a pas rendu sa première image.
    unawaited(NotificationRouter.instance.open(message.data));
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

/// Traduction de l'état FCM dans le vocabulaire neutre de l'app.
@visibleForTesting
PushPermissionStatus pushPermissionStatusOf(AuthorizationStatus status) =>
    switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermissionStatus.granted,
      AuthorizationStatus.denied => PushPermissionStatus.denied,
      AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
    };
