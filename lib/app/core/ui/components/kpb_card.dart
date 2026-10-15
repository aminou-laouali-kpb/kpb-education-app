import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';
import 'kpb_pressable.dart';

// ── KPB Card (base) ───────────────────────────────────────────────────────────

/// Variantes de carte (architecture §9.1).
enum KpbCardVariant {
  /// Surface blanche, ombre douce — le défaut historique.
  standard,

  /// Carte tappable avec enfoncement (press-scale), sans vibration.
  interactive,

  /// Carte mise en avant : bordure action + fond soft.
  highlighted,
}

class KpbCard extends StatelessWidget {
  const KpbCard({
    super.key,
    required this.child,
    this.variant = KpbCardVariant.standard,
    this.padding = const EdgeInsets.all(KpbSpacing.md),
    this.margin,
    this.color = KpbColors.bgCard,
    this.borderRadius = KpbRadius.lgBr,
    this.shadow = KpbShadow.card,
    this.onTap,
    this.border,
    this.semanticLabel,
  });

  final Widget child;
  final KpbCardVariant variant;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color color;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;
  final VoidCallback? onTap;
  final Border? border;

  /// Libellé lu par le lecteur d'écran quand la carte est tappable. Nul : le
  /// texte de la carte est lu.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final highlighted = variant == KpbCardVariant.highlighted;
    // Défauts sentinelles : résolus theme-aware, les overrides explicites
    // restent respectés.
    final effectiveColor = color == KpbColors.bgCard
        ? (highlighted ? KpbColors.actionPrimarySoft : c.cardBg)
        : color;
    final effectiveShadow =
        identical(shadow, KpbShadow.card) ? c.cardShadow : shadow;
    final effectiveBorder = border ??
        (highlighted
            ? Border.all(color: KpbColors.actionPrimary, width: 1.5)
            : null);

    final card = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: borderRadius,
        boxShadow: effectiveShadow,
        border: effectiveBorder,
      ),
      child: child,
    );

    if (onTap == null) return card;
    if (variant == KpbCardVariant.interactive) {
      return KpbPressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        child: card,
      );
    }
    // Tappable : annoncée comme un bouton aux lecteurs d'écran.
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
