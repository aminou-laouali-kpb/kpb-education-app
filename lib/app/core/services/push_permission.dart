import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

import 'push_service.dart';

/// Ce que l'app sait de l'autorisation des notifications sur cet appareil.
enum PushPermissionStatus {
  /// Autorisées (ou « provisoires » sur iOS) : les push s'affichent.
  granted,

  /// Refusées : le système ne reposera plus la question, seul le réglage de
  /// l'app peut les rallumer.
  denied,

  /// Jamais demandées.
  notDetermined,

  /// Push inerte (Firebase absent, test de widget) : on ne sait rien, et on
  /// ne montre donc ni feuille d'explication ni écran « coupées ».
  unavailable,
}

/// L'autorisation des notifications, derrière UNE interface.
///
/// Les écrans (« Suivre », préférences) ne parlent qu'à elle, jamais au SDK :
/// un changement de fournisseur de push ne touche que l'adaptateur, et un test
/// remplace [instance] par un faux pour prouver le parcours « feuille
/// d'explication → demande système → refus → réglages ».
abstract class PushPermission {
  /// L'état actuel, sans rien demander.
  Future<PushPermissionStatus> status();

  /// Montre la demande système (une seule fois sur iOS) et rend la réponse.
  Future<PushPermissionStatus> request();

  /// Ouvre les réglages de l'app. Rend faux si le système a refusé.
  Future<bool> openSettings();

  static PushPermission? _override;

  /// L'adaptateur en service : FCM ([PushService]) + les réglages système.
  static PushPermission get instance =>
      _override ?? const SystemPushPermission();

  @visibleForTesting
  static set debugOverride(PushPermission? value) => _override = value;
}

/// L'adaptateur de production : l'état et la demande passent par
/// [PushService] (FCM), le lien vers les réglages par `permission_handler`.
class SystemPushPermission implements PushPermission {
  const SystemPushPermission();

  @override
  Future<PushPermissionStatus> status() =>
      PushService.instance.permissionStatus();

  @override
  Future<PushPermissionStatus> request() =>
      PushService.instance.requestPermission();

  @override
  Future<bool> openSettings() async {
    try {
      return await handler.openAppSettings();
    } catch (error) {
      debugPrint('[Push] openAppSettings failed: $error');
      return false;
    }
  }
}
