import 'dart:async';

import 'package:flutter/material.dart';

import '../app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Staggered Slide Animation
//
// Fait entrer un élément de liste (fondu + léger glissé) après un délai
// `index × pas`. Deux garde-fous pour les téléphones d'entrée de gamme :
//  * seuls les [KpbMotion.staggerMaxItems] premiers éléments sont animés — les
//    suivants (et ceux recréés au défilement) apparaissent tout de suite, au
//    lieu d'attendre index × 70 ms sans limite ;
//  * rien n'est animé quand [KpbMotion.of] coupe le mouvement (animations
//    désactivées par le système, ou mode données réduites).
// ─────────────────────────────────────────────────────────────────────────────
class StaggeredSlide extends StatefulWidget {
  const StaggeredSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delayMs,
  });

  final Widget child;
  final int index;

  /// Pas entre deux éléments, en millisecondes. Nul = [KpbMotion.staggerStep].
  final int? delayMs;

  @override
  State<StaggeredSlide> createState() => _StaggeredSlideState();
}

class _StaggeredSlideState extends State<StaggeredSlide>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;
  Timer? _delay;
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;

    final motion = KpbMotion.of(context);
    if (!motion.enabled || widget.index >= KpbMotion.staggerMaxItems) return;

    final ctrl = AnimationController(vsync: this, duration: motion.reveal);
    _ctrl = ctrl;
    _opacity = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: ctrl, curve: motion.curve));

    final step = widget.delayMs == null
        ? motion.staggerStep
        : Duration(milliseconds: widget.delayMs!);
    final delay = step * widget.index;
    if (delay == Duration.zero) {
      ctrl.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = _opacity;
    final slide = _slide;
    if (opacity == null || slide == null) return widget.child;
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: slide,
        child: widget.child,
      ),
    );
  }
}
