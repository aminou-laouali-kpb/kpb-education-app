import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/app_controller.dart';
import '../../../core/ui/app_tokens.dart';
import 'follow_push_primer.dart';

/// Les trois formes du bouton.
enum FollowButtonVariant {
  /// Pastille icône + « Suivre » / « Suivie » (cartes de liste, recherche).
  compact,

  /// Icône seule, cible 48 dp, libellé dans l'infobulle et la sémantique
  /// (cartes étroites de l'accueil).
  icon,

  /// Pleine largeur, 48 dp (fiche de la bourse).
  full,
}

/// « Suivre » / « Suivie » — UN contrôle pour une bourse : favori + alerte
/// d'ouverture + rappels de date limite.
///
/// - Il passe par le favori local ([AppController.setScholarshipFollow] →
///   `ensureSaved`) : l'état change tout de suite, même hors ligne, et se
///   resynchronise comme tous les favoris.
/// - Il remplace le marque-page de la fiche et la cloche « M'avertir » de la
///   liste : la cloche ne veut plus dire que « notifications ».
/// - Au premier « Suivre », la feuille d'explication précède la demande
///   système d'autorisation ([FollowPushPrimer]).
/// - Cible tactile ≥ 48 dp dans toutes ses formes.
class FollowScholarshipButton extends StatelessWidget {
  const FollowScholarshipButton({
    super.key,
    required this.scholarshipId,
    required this.scholarshipTitle,
    this.variant = FollowButtonVariant.compact,
    this.onChanged,
  });

  final String scholarshipId;
  final String scholarshipTitle;
  final FollowButtonVariant variant;

  /// Le nouvel état, après le tap.
  final ValueChanged<bool>? onChanged;

  Future<void> _toggle(BuildContext context, AppController controller) async {
    final following = controller.toggleScholarshipFollow(scholarshipId);
    onChanged?.call(following);
    if (following) await FollowPushPrimer.maybePrime(context);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final following = controller.isFollowingScholarship(scholarshipId);
        final label = following
            ? 'follow_scholarship_following'.tr
            : 'follow_scholarship_follow'.tr;
        final semanticsLabel = following
            ? 'follow_scholarship_a11y_following'
                .trParams({'title': scholarshipTitle})
            : 'follow_scholarship_a11y_follow'
                .trParams({'title': scholarshipTitle});
        final icon = following
            ? Icons.bookmark_added_rounded
            : Icons.bookmark_add_outlined;
        final foreground =
            following ? KpbColors.success : KpbColors.actionPrimary;
        final background =
            following ? KpbColors.successLight : KpbColors.surface;
        final border = following
            ? KpbColors.success.withValues(alpha: 0.5)
            : KpbColors.actionPrimary.withValues(alpha: 0.35);
        void onTap() => unawaited(_toggle(context, controller));

        return Semantics(
          button: true,
          toggled: following,
          label: semanticsLabel,
          // Le libellé complet (« Suivre la bourse X ») remplace celui des
          // enfants ; l'action est reportée ici pour rester activable au
          // lecteur d'écran.
          onTap: onTap,
          excludeSemantics: true,
          child: switch (variant) {
            FollowButtonVariant.icon => Tooltip(
                message: label,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey<String>('follow-$scholarshipId'),
                      customBorder: const CircleBorder(),
                      onTap: onTap,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: background,
                            shape: BoxShape.circle,
                            border: Border.all(color: border),
                          ),
                          child: Icon(icon, size: 19, color: foreground),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            FollowButtonVariant.compact => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey<String>('follow-$scholarshipId'),
                    borderRadius: BorderRadius.circular(100),
                    onTap: onTap,
                    child: Center(
                      widthFactor: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16, color: foreground),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: KpbFontSize.xs,
                                fontWeight: FontWeight.w800,
                                color: foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            FollowButtonVariant.full => SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: ValueKey<String>('follow-$scholarshipId'),
                  onPressed: onTap,
                  icon: Icon(icon, color: foreground),
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: KpbFontSize.md,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: background,
                    side: BorderSide(color: border),
                  ),
                ),
              ),
          },
        );
      },
    );
  }
}
