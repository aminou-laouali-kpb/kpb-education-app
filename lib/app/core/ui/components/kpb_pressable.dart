import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../kpb_haptics.dart';

// ── KpbPressable ──────────────────────────────────────────────────────────────
// Surface tappable avec un léger enfoncement (press-scale).
//
// Pas de vibration par défaut : vibrer à chaque tap banalise le retour tactile
// et coûte sur les téléphones d'entrée de gamme. Un appelant qui confirme une
// action volontaire passe `haptic: true` (→ [KpbHaptics.confirm]).
// L'enfoncement suit [KpbMotion.of] : instantané si les animations sont
// coupées ou si le mode données réduites est actif.
class KpbPressable extends StatefulWidget {
  const KpbPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  /// Vrai : [KpbHaptics.confirm] à l'appui. Faux par défaut.
  final bool haptic;

  @override
  State<KpbPressable> createState() => _KpbPressableState();
}

class _KpbPressableState extends State<KpbPressable> {
  bool _down = false;

  void _set(bool v) {
    if (mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final motion = KpbMotion.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) KpbHaptics.confirm();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down && motion.enabled ? widget.scale : 1.0,
        duration: motion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
