import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../navigation/force_update_screen.dart';
import '../utils/version_utils.dart';

/// Force-update gate: compares the installed build against the backend's
/// `/config/app` minimum supported version and replaces the whole navigation
/// stack with [ForceUpdateScreen] when the build is too old.
///
/// Every failure path (offline, endpoint missing, malformed payload) fails
/// open — an update gate must never brick the app when the backend is
/// unreachable.
///
/// ## Ce qui a changé à la 59 (audit avant l'archive)
///
/// - **Elle se rejoue.** La garde ne tournait qu'une fois, au démarrage à
///   froid, sans nouvel essai : sautée sur réseau instable, et jamais repassée
///   sur un Android qui garde l'app en mémoire des jours. Elle est maintenant
///   évaluée sur CHAQUE réponse fraîche de `/config/app`
///   (`RemoteFeatureFlags.onFreshConfig`) : au démarrage, aux nouveaux essais,
///   et au retour au premier plan. Jamais sur la réponse gardée en mémoire du
///   téléphone : une vieille consigne ne doit bloquer personne.
/// - **Un seul appel.** Elle ne lit plus `/config/app` elle-même : la réponse
///   lui est passée, au lieu de deux appels identiques à chaque démarrage.
///
/// Elle compare toujours la seule version marketing (`x.y.z`), jamais le
/// numéro qui suit le « + » : c'est ce que dit la consigne de déploiement
/// (`KPB_MIN_APP_VERSION` = une version marketing), gardée par
/// `test/release/store_pack_57_test.dart`.
abstract final class AppVersionGate {
  static bool _shown = false;

  /// La version installée, injectable pour les tests.
  @visibleForTesting
  static Future<({String version})> Function() installed = _readInstalled;

  static Future<({String version})> _readInstalled() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version);
  }

  @visibleForTesting
  static void resetForTest() {
    _shown = false;
    installed = _readInstalled;
  }

  /// La version minimale servie, ou une chaîne vide.
  ///
  /// Pure et visible pour les tests. Une valeur absente ou qui n'est pas un
  /// texte vaut « aucun minimum » : la garde échoue ouverte.
  static String minVersionOf(Map<String, dynamic> config) {
    final raw = config['minVersion'];
    return raw is String ? raw.trim() : '';
  }

  /// Évalue une réponse fraîche de `/config/app`. Ne lève jamais.
  static Future<void> evaluate(Map<String, dynamic> config) async {
    if (_shown) return;
    try {
      final minVersion = minVersionOf(config);
      if (minVersion.isEmpty) return;

      final info = await installed();
      if (!isVersionBelow(info.version, minVersion)) return;

      final rawUrl = defaultTargetPlatform == TargetPlatform.iOS
          ? config['iosStoreUrl']
          : config['androidStoreUrl'];
      final storeUrl = rawUrl is String ? rawUrl.trim() : '';

      // Boot fires this check before GetMaterialApp has attached its
      // navigator; wait (bounded) for the first frame before replacing the
      // stack, and give up rather than crash if it never mounts.
      for (var i = 0; i < 100 && Get.context == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (Get.context == null || _shown) return;

      _shown = true;
      await Get.offAll<void>(() => ForceUpdateScreen(storeUrl: storeUrl));
    } catch (error) {
      debugPrint('Force-update check skipped: $error');
    }
  }
}
