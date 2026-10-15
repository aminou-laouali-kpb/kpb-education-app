import 'package:flutter/material.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/kpb_haptics.dart';

/// Une réponse « à puce » de l'assistant : pleine largeur, 48 dp au moins,
/// état coché annoncé au lecteur d'écran. Aucune saisie libre.
class MatchChoice extends StatelessWidget {
  const MatchChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.multiple = false,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  /// Choix multiple (case à cocher) plutôt qu'exclusif (bouton radio).
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final border = selected ? KpbColors.actionPrimary : KpbColors.border;
    final icon = multiple
        ? (selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded)
        : (selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded);
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        checked: multiple ? selected : null,
        inMutuallyExclusiveGroup: multiple ? null : true,
        enabled: enabled,
        label: subtitle == null ? label : '$label. $subtitle',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: selected ? KpbColors.actionPrimarySoft : KpbColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KpbRadius.md),
            side: BorderSide(color: border, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(KpbRadius.md),
            onTap: onTap == null
                ? null
                : () {
                    KpbHaptics.selection();
                    onTap!();
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KpbSpacing.md,
                  vertical: KpbSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: selected
                          ? KpbColors.actionPrimary
                          : KpbColors.textMuted,
                    ),
                    const SizedBox(width: KpbSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: KpbTextStyles.titleSm.copyWith(
                              color: KpbColors.textPrimary,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: KpbTextStyles.caption.copyWith(
                                color: KpbColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le titre d'une question et sa phrase d'aide.
class MatchQuestionHeader extends StatelessWidget {
  const MatchQuestionHeader({super.key, required this.title, this.help});

  final String title;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: KpbTextStyles.title),
          ),
          if (help != null) ...[
            const SizedBox(height: KpbSpacing.xs),
            Text(
              help!,
              style: KpbTextStyles.bodySm.copyWith(
                color: KpbColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
