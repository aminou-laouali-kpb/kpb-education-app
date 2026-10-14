import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbToast — le SEUL bandeau éphémère de l'app.
//
// Remplace `Get.snackbar` et `ScaffoldMessenger.showSnackBar` (interdits dans
// lib/ par test/core/ui/toast_ban_test.dart). Quatre sortes, une icône et une
// durée par sorte, un message court, un titre FACULTATIF (jamais
// « KPB Education » : l'élève sait dans quelle app il est), une action
// facultative.
//
//   KpbToast.success('profile_updated_body'.tr);
//   KpbToast.error('case_message_send_failed'.tr);
//   KpbToast.info('referral_code_copied'.tr);
//   KpbToast.offlinePending('toast_offline_pending_default'.tr);
//   KpbToast.error('external_link_failed_body'.tr,
//       action: KpbToastAction(label: 'retry'.tr, onPressed: _retry));
//
// Deux surfaces, même rendu :
//  * sans `context` (contrôleurs, services, feuilles) : bandeau GetX en
//    overlay, AU-DESSUS des feuilles et dialogues ;
//  * avec un `context` sous un ScaffoldMessenger : SnackBar Material rattachée
//    à l'écran (elle disparaît avec lui). C'est le cas des écrans qui
//    utilisaient ScaffoldMessenger, et des tests montés dans un MaterialApp nu.
// ─────────────────────────────────────────────────────────────────────────────

/// Les quatre sortes de bandeau.
enum KpbToastKind {
  /// Action réussie (confirmée par le serveur quand il y en a un).
  success,

  /// Échec : l'action n'a pas eu lieu.
  error,

  /// Information neutre (copié, rien à faire…).
  info,

  /// Hors ligne : l'action est gardée sur le téléphone et partira plus tard
  /// (ou ne peut pas partir tant que la connexion manque).
  offlinePending,
}

/// Bouton facultatif à droite du message.
@immutable
class KpbToastAction {
  const KpbToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class KpbToast {
  KpbToast._();

  static void success(
    String message, {
    String? title,
    KpbToastAction? action,
    Duration? duration,
    BuildContext? context,
    bool atTop = false,
    VoidCallback? onTap,
  }) =>
      show(
        kind: KpbToastKind.success,
        message: message,
        title: title,
        action: action,
        duration: duration,
        context: context,
        atTop: atTop,
        onTap: onTap,
      );

  static void error(
    String message, {
    String? title,
    KpbToastAction? action,
    Duration? duration,
    BuildContext? context,
    bool atTop = false,
    VoidCallback? onTap,
  }) =>
      show(
        kind: KpbToastKind.error,
        message: message,
        title: title,
        action: action,
        duration: duration,
        context: context,
        atTop: atTop,
        onTap: onTap,
      );

  static void info(
    String message, {
    String? title,
    KpbToastAction? action,
    Duration? duration,
    BuildContext? context,
    bool atTop = false,
    VoidCallback? onTap,
  }) =>
      show(
        kind: KpbToastKind.info,
        message: message,
        title: title,
        action: action,
        duration: duration,
        context: context,
        atTop: atTop,
        onTap: onTap,
      );

  static void offlinePending(
    String message, {
    String? title,
    KpbToastAction? action,
    Duration? duration,
    BuildContext? context,
    bool atTop = false,
    VoidCallback? onTap,
  }) =>
      show(
        kind: KpbToastKind.offlinePending,
        message: message,
        title: title,
        action: action,
        duration: duration,
        context: context,
        atTop: atTop,
        onTap: onTap,
      );

  /// Durée d'affichage par défaut : un échec ou une attente se lit plus
  /// lentement qu'une confirmation ; une action laisse le temps d'appuyer.
  static Duration defaultDuration(KpbToastKind kind, {bool hasAction = false}) {
    if (hasAction) return const Duration(seconds: 6);
    return switch (kind) {
      KpbToastKind.success || KpbToastKind.info => const Duration(seconds: 3),
      KpbToastKind.error ||
      KpbToastKind.offlinePending =>
        const Duration(seconds: 4),
    };
  }

  /// Affiche un bandeau. [title] est facultatif ; un titre vide ou égal au
  /// nom de l'app est ignoré.
  static void show({
    required KpbToastKind kind,
    required String message,
    String? title,
    KpbToastAction? action,
    Duration? duration,
    BuildContext? context,
    bool atTop = false,
    VoidCallback? onTap,
  }) {
    final cleanTitle = _cleanTitle(title);
    final shownFor =
        duration ?? defaultDuration(kind, hasAction: action != null);
    final messenger =
        context == null ? null : ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: _wrapTap(
            KpbToastBody(kind: kind, title: cleanTitle, message: message),
            onTap,
          ),
          duration: shownFor,
          behavior: SnackBarBehavior.floating,
          backgroundColor: KpbColors.brandNavy,
          shape: const RoundedRectangleBorder(borderRadius: KpbRadius.smBr),
          action: action == null
              ? null
              : SnackBarAction(
                  label: action.label,
                  textColor: KpbColors.actionOnDark,
                  onPressed: action.onPressed,
                ),
        ));
      return;
    }

    if (Get.key.currentState == null) {
      // Pas d'app GetX montée (démarrage, test isolé) : rien où afficher.
      debugPrint('KpbToast ignoré (aucun overlay) : $message');
      return;
    }
    final motion = KpbMotion.resolve(Get.context);
    Get.showSnackbar(GetSnackBar(
      messageText: KpbToastBody(
        kind: kind,
        title: cleanTitle,
        message: message,
      ),
      duration: shownFor,
      snackPosition: atTop ? SnackPosition.TOP : SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(KpbSpacing.sm + KpbSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: KpbSpacing.md,
        vertical: KpbSpacing.sm + KpbSpacing.xs,
      ),
      borderRadius: KpbRadius.sm,
      backgroundColor: KpbColors.brandNavy,
      animationDuration: motion.scale(const Duration(milliseconds: 350)),
      onTap: onTap == null ? null : (_) => onTap(),
      mainButton: action == null
          ? null
          : TextButton(
              style: TextButton.styleFrom(
                foregroundColor: KpbColors.actionOnDark,
              ),
              onPressed: () {
                Get.closeCurrentSnackbar();
                action.onPressed();
              },
              child: Text(action.label),
            ),
    ));
  }

  /// Ferme le bandeau visible (surface GetX).
  static void dismiss() {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
  }

  static String? _cleanTitle(String? title) {
    final t = title?.trim();
    if (t == null || t.isEmpty) return null;
    if (t.toLowerCase() == 'kpb education') return null;
    return t;
  }

  static Widget _wrapTap(Widget child, VoidCallback? onTap) => onTap == null
      ? child
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
        );
}

/// Contenu d'un bandeau : icône de la sorte, titre facultatif, message.
/// Public pour les tests et pour un aperçu dans la galerie de thème.
class KpbToastBody extends StatelessWidget {
  const KpbToastBody({
    super.key,
    required this.kind,
    required this.message,
    this.title,
  });

  final KpbToastKind kind;
  final String message;
  final String? title;

  static IconData iconFor(KpbToastKind kind) => switch (kind) {
        KpbToastKind.success => Icons.check_circle_rounded,
        KpbToastKind.error => Icons.error_outline_rounded,
        KpbToastKind.info => Icons.info_outline_rounded,
        KpbToastKind.offlinePending => Icons.cloud_off_rounded,
      };

  // Teintes « sur navy » : toutes ≥ 4,5:1 sur brandNavy.
  static Color colorFor(KpbToastKind kind) => switch (kind) {
        KpbToastKind.success => KpbColors.successOnDark,
        KpbToastKind.error => KpbColors.errorOnDark,
        KpbToastKind.info => KpbColors.actionOnDark,
        KpbToastKind.offlinePending => KpbColors.gold,
      };

  @override
  Widget build(BuildContext context) {
    final heading = title;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(iconFor(kind), size: 20, color: colorFor(kind)),
          ),
          const SizedBox(width: KpbSpacing.sm + KpbSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (heading != null) ...[
                  Text(
                    heading,
                    style: KpbTextStyles.titleSm.copyWith(
                      color: KpbColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: KpbTextStyles.bodySm.copyWith(
                    color: KpbColors.textOnDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
