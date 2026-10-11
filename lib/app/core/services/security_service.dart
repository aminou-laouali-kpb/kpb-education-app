import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

import '../controllers/app_controller.dart';
import '../../features/auth/app_lock_screen.dart';

/// App lock when [AppController.isAppLockEnabled]: after a real background
/// episode, pushes [AppLockScreen]. Unlock uses [LocalAuthentication]
/// (biometrics and/or device PIN).
///
/// **Threat model (short):** Protection against casual shoulder-surfing and unattended device
/// while the app is backgrounded — not a substitute for OS-level encryption or server auth.
/// If the device reports no biometric/PIN capability, [authenticate] allows access so users
/// are not locked out (documented product trade-off).
///
/// ## Pourquoi le verrou s'arme sur l'arrière-plan et non sur le retour
///
/// Cette classe a rendu l'app INUTILISABLE pour quiconque activait l'option, et
/// la mesure est sans ambiguïté : sur l'enregistrement d'écran d'un testeur,
/// l'overlay « Application Verrouillée » revenait **toutes les 1,61 s**
/// (écarts 1,57–1,63 s sur 18 s), indéfiniment, et le Dynamic Island rejouait
/// en boucle l'animation Face ID → coche verte → rescan.
///
/// La boucle se refermait ainsi. On armait le verrou sur chaque `resumed` ;
/// or l'invite biométrique est elle-même un passage hors de l'app, donc sa
/// FERMETURE produit un `resumed`. Au moment où il arrivait :
///
///  · `_authenticating` venait d'être remis à faux par le `finally` de
///    [authenticate] ;
///  · et `Get.currentRoute` n'était plus `/app_lock`, puisque le succès venait
///    de dépiler l'écran.
///
/// Les deux gardes tombaient ensemble, et le verrou se reposait. **Déverrouiller
/// causait le prochain verrouillage.** Aucun ordre entre le `finally` et le
/// `Get.back()` ne corrige ça : les deux gardes décrivent « une authentification
/// est en cours », jamais « l'utilisateur est réellement parti ».
///
/// Le verrou s'arme donc désormais sur l'ÉVÉNEMENT qui le justifie — un vrai
/// passage en arrière-plan — et `resumed` ne fait plus que consommer un armement
/// déjà décidé. `inactive` est délibérément exclu : c'est précisément l'état que
/// l'invite biométrique provoque, et le confondre avec un départ était la cause.
class SecurityService extends GetxService with WidgetsBindingObserver {
  static SecurityService get instance => Get.find<SecurityService>();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  /// Vrai quand un passage en arrière-plan reste à honorer par une
  /// authentification. Armé au démarrage : ouvrir l'app est le premier
  /// événement qui mérite le verrou, et c'était déjà le comportement obtenu
  /// par le `resumed` initial.
  bool _lockArmed = true;

  /// Le geste « montrer l'écran de verrouillage », remplaçable en test.
  ///
  /// Compter les demandes de verrouillage est la SEULE façon de voir la boucle :
  /// un test qui se contente de vérifier qu'un verrou apparaît reste vert sur le
  /// défaut, puisque le défaut est précisément qu'il apparaît trop. La couverture
  /// de cette classe était nulle avant ce correctif.
  @visibleForTesting
  static VoidCallback? showLockScreenOverride;

  /// Vrai entre l'affichage de l'écran de verrouillage et une authentification
  /// réussie. Sert à le REPLACER si une navigation le retire ou passe
  /// par-dessus (raccourci « Mes dossiers », clic de notification :
  /// `Get.offAllNamed(home)` dépilait le verrou sans authentification).
  bool _awaitingUnlock = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Démarrage à froid : l'app démarre déjà `resumed`, sans transition de
  /// cycle de vie, donc l'armement initial n'était jamais consommé et l'app
  /// s'ouvrait déverrouillée après la mort du processus.
  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lockArmed) return;
      _lockArmed = false;
      _checkAndShowLockScreen();
    });
    // Un post-frame callback n'est exécuté qu'à la PROCHAINE frame : on la
    // demande, sinon une app immobile ne l'exécute jamais.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// À appeler à chaque changement de route (routingCallback) : tant que le
  /// déverrouillage n'a pas eu lieu, toute autre route que `/app_lock` au
  /// sommet remet l'écran de verrouillage.
  void onRouteChanged(String? currentRoute) {
    if (!_awaitingUnlock || currentRoute == '/app_lock') return;
    if (!Get.isRegistered<AppController>() ||
        !Get.find<AppController>().isAppLockEnabled) {
      _awaitingUnlock = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_awaitingUnlock && Get.currentRoute != '/app_lock') {
        _showLockScreen();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // L'utilisateur est réellement parti — sauf si c'est notre propre invite
        // biométrique qui a mis l'app de côté. `persistAcrossBackgrounding`
        // (stickyAuth) fait exactement ça sur certains appareils : sans cette
        // condition, une authentification en cours réarmerait le verrou qu'elle
        // est en train de lever.
        if (!_isAuthenticating) _lockArmed = true;
      case AppLifecycleState.resumed:
        if (!_lockArmed) return;
        _lockArmed = false;
        _checkAndShowLockScreen();
      case AppLifecycleState.inactive:
        // Ni un départ, ni un retour. C'est l'état que produit l'invite Face ID
        // ou Touch ID : le traiter comme un départ était la boucle.
        break;
    }
  }

  /// Called when a real background episode is followed by a resume.
  /// If biometrics are enabled in the user's snapshot, we throw the lock screen.
  void _checkAndShowLockScreen() {
    // We only enforce lock if the user has enabled it in their profile/snapshot.
    final controller = Get.find<AppController>();
    if (!controller.isAppLockEnabled) return;

    // Don't show if we are already authenticating or currently showing the lock
    // screen. Ces deux gardes restent utiles pour les chemins concurrents ; elles
    // ne sont simplement plus le seul rempart contre la boucle.
    if (_isAuthenticating || Get.currentRoute == '/app_lock') return;

    _awaitingUnlock = true;
    _showLockScreen();
  }

  void _showLockScreen() {
    final show = showLockScreenOverride;
    if (show != null) {
      show();
      return;
    }
    Get.to(() => const AppLockScreen(),
        transition: Transition.fadeIn, routeName: '/app_lock');
  }

  /// Attempts to authenticate the user using biometrics or device PIN.
  /// Returns true if successful.
  Future<bool> authenticate() async {
    _isAuthenticating = true;
    try {
      final canCheckBiometrics =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();

      if (!canCheckBiometrics) {
        _awaitingUnlock = false;
        return true; // Fallback to allowing access if device has no security
      }

      final ok = await _auth.authenticate(
        localizedReason: 'security_biometric_reason'.tr,
        persistAcrossBackgrounding: true,
      );
      if (ok) _awaitingUnlock = false;
      return ok;
    } on PlatformException catch (_) {
      return false;
    } finally {
      // Always reset, even on unexpected exception types — otherwise the flag
      // stays true and the lock screen is never shown again (app lock silently
      // stops working).
      _isAuthenticating = false;
    }
  }

  /// Pose l'état interne depuis un test.
  ///
  /// `armed: false` décrit l'app au premier plan, déjà déverrouillée — l'état
  /// depuis lequel la boucle partait.
  ///
  /// Les deux paramètres sont **nullables à dessein** : un test doit pouvoir
  /// lever `authenticating` sans toucher à `_lockArmed`. Une première version
  /// écrivait les deux à chaque appel, et le test « stickyAuth » restait vert
  /// alors qu'on retirait la condition qu'il prétendait couvrir — la seconde
  /// garde de [_checkAndShowLockScreen] absorbait la mutation.
  @visibleForTesting
  void setStateForTest({
    bool? armed,
    bool? authenticating,
    bool? awaitingUnlock,
  }) {
    if (armed != null) _lockArmed = armed;
    if (authenticating != null) _isAuthenticating = authenticating;
    if (awaitingUnlock != null) _awaitingUnlock = awaitingUnlock;
  }
}
