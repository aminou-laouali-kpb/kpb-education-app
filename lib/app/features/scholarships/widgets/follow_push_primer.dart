import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/controllers/app_controller.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/push_permission.dart';
import '../../../core/services/remote_feature_flags.dart';
import '../../../core/ui/app_tokens.dart';

/// Le drapeau « la feuille du premier Suivre a déjà été montrée », sur cet
/// appareil. Interface pour qu'un test le pose, le lise ou le fasse tomber en
/// panne (une panne vaut « déjà montrée » : jamais de feuille en boucle).
abstract interface class FollowPrimerStore {
  Future<bool> hasBeenShown();
  Future<void> markShown();
}

class SharedPreferencesFollowPrimerStore implements FollowPrimerStore {
  const SharedPreferencesFollowPrimerStore();

  /// Versionnée : passer à `_v2` remontrerait la feuille à tout le monde.
  static const String key =
      '${AppConfig.storageNamespace}.follow_push_primer_v1';

  @override
  Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}

/// Demande d'autorisation des notifications AU PREMIER « Suivre ».
///
/// C'est le seul endroit de l'app qui déclenche la demande système d'office
/// (l'onboarding ne le fait plus) : à cet instant l'élève sait pourquoi il en
/// a besoin. Ordre :
/// 1. autorisation déjà accordée, push inerte ou invité → rien ;
/// 2. déjà refusée → « Notifications coupées » et un lien vers les réglages
///    (le système ne reposera plus la question) ;
/// 3. jamais demandée → une feuille d'explication, PUIS la demande système ;
///    un refus mène à « Notifications coupées ».
/// Une seule fois par appareil, quelle que soit la réponse.
abstract final class FollowPushPrimer {
  static FollowPrimerStore _store = const SharedPreferencesFollowPrimerStore();

  @visibleForTesting
  static set debugStore(FollowPrimerStore? store) =>
      _store = store ?? const SharedPreferencesFollowPrimerStore();

  /// Appelé juste après qu'un « Suivre » a été posé. Ne lève jamais.
  static Future<void> maybePrime(BuildContext context) async {
    try {
      final controller =
          Get.isRegistered<AppController>() ? Get.find<AppController>() : null;
      if (controller == null ||
          controller.profile == null ||
          controller.isGuestMode) {
        return;
      }
      final permission = PushPermission.instance;
      final status = await permission.status();
      if (status == PushPermissionStatus.unavailable ||
          status == PushPermissionStatus.granted) {
        return;
      }
      bool shown;
      try {
        shown = await _store.hasBeenShown();
      } catch (_) {
        shown = true;
      }
      if (shown) return;
      try {
        await _store.markShown();
      } catch (_) {
        return;
      }
      if (!context.mounted) return;

      if (status == PushPermissionStatus.denied) {
        await showPushDeniedSheet(context);
        return;
      }

      if (!RemoteFeatureFlags.instance.followPushPrimerEnabled) {
        final answer = await permission.request();
        if (answer == PushPermissionStatus.denied && context.mounted) {
          await showPushDeniedSheet(context);
        }
        return;
      }

      unawaited(AnalyticsService.instance.logPermissionPrimerShown());
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: KpbColors.surface,
        builder: (sheetContext) => const _PrimerSheet(),
      );
      if (accepted != true) {
        unawaited(
            AnalyticsService.instance.logPermissionPrimerResult('dismissed'));
        return;
      }
      final answer = await permission.request();
      final granted = answer == PushPermissionStatus.granted;
      unawaited(AnalyticsService.instance
          .logPermissionPrimerResult(granted ? 'granted' : 'denied'));
      if (answer == PushPermissionStatus.denied && context.mounted) {
        await showPushDeniedSheet(context);
      }
    } catch (error) {
      debugPrint('[FollowPushPrimer] skipped: $error');
    }
  }
}

/// « Notifications coupées » : l'élève a refusé, seul le réglage de l'app peut
/// les rallumer. Le bouton ouvre directement ce réglage.
Future<void> showPushDeniedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: KpbColors.surface,
    builder: (sheetContext) => _SheetBody(
      key: const ValueKey<String>('push-denied-sheet'),
      icon: Icons.notifications_off_outlined,
      iconColor: KpbColors.warning,
      iconBackground: KpbColors.warningLight,
      title: 'push_denied_title'.tr,
      body: 'push_denied_body'.tr,
      primaryLabel: 'push_denied_open_settings'.tr,
      onPrimary: () {
        Navigator.of(sheetContext).pop();
        unawaited(PushPermission.instance.openSettings());
      },
      secondaryLabel: 'push_primer_later'.tr,
      onSecondary: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class _PrimerSheet extends StatelessWidget {
  const _PrimerSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetBody(
      key: const ValueKey<String>('push-primer-sheet'),
      icon: Icons.notifications_active_outlined,
      iconColor: KpbColors.actionPrimary,
      iconBackground: KpbColors.actionPrimarySoft,
      title: 'push_primer_title'.tr,
      body: 'push_primer_body'.tr,
      primaryLabel: 'push_primer_enable'.tr,
      onPrimary: () => Navigator.of(context).pop(true),
      secondaryLabel: 'push_primer_later'.tr,
      onSecondary: () => Navigator.of(context).pop(false),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: KpbFontSize.lg,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: KpbFontSize.md,
                height: 1.45,
                color: KpbColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(primaryLabel),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
