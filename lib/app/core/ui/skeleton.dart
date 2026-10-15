import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton / shimmer loading components — no extra package needed.
// Each skeleton widget manages its own AnimationController for a smooth pulse.
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonPulse extends StatefulWidget {
  const _SkeletonPulse({
    this.width,
    required this.height,
    required this.borderRadius,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool? _animating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pulsation figée quand le mouvement est coupé (système ou mode données
    // réduites) : le squelette reste lisible, sans trame à calculer.
    final animate = KpbMotion.of(context).enabled;
    if (animate == _animating) return;
    _animating = animate;
    if (animate) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tokens sémantiques (base = bordure, reflet = surface muted) : le
    // skeleton suit le thème sans hexadécimaux locaux.
    final c = context.kpb;
    final baseColor = context.isDark ? c.surfaceBg : c.gray200;
    final shimmerColor = context.isDark ? c.borderLight : c.gray100;
    final colorAnim =
        ColorTween(begin: baseColor, end: shimmerColor).animate(_ctrl);

    return AnimatedBuilder(
      animation: colorAnim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colorAnim.value,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composed skeletons for key screens
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          _SkeletonPulse(width: 180, height: 22, borderRadius: 6),
          SizedBox(height: 8),
          _SkeletonPulse(width: 240, height: 16, borderRadius: 6),
          SizedBox(height: 24),
          // Hero card
          _SkeletonPulse(height: 140, borderRadius: 16),
          SizedBox(height: 24),
          // Section title
          _SkeletonPulse(width: 120, height: 16, borderRadius: 6),
          SizedBox(height: 12),
          // Horizontal chips
          Row(
            children: [
              _SkeletonPulse(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              _SkeletonPulse(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              _SkeletonPulse(width: 80, height: 32, borderRadius: 16),
            ],
          ),
          SizedBox(height: 24),
          _SkeletonPulse(width: 140, height: 16, borderRadius: 6),
          SizedBox(height: 12),
          _SkeletonPulse(height: 88, borderRadius: 12),
          SizedBox(height: 12),
          _SkeletonPulse(height: 88, borderRadius: 12),
          SizedBox(height: 24),
          _SkeletonPulse(width: 160, height: 16, borderRadius: 6),
          SizedBox(height: 12),
          _SkeletonPulse(height: 88, borderRadius: 12),
          SizedBox(height: 12),
          _SkeletonPulse(height: 88, borderRadius: 12),
        ],
      ),
    );
  }
}

class CasesScreenSkeleton extends StatelessWidget {
  const CasesScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) =>
          const _SkeletonPulse(height: 100, borderRadius: 12),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Briques publiques (KpbAsyncView et écrans)
// ─────────────────────────────────────────────────────────────────────────────

/// Un bloc de squelette (pulsation, figée quand le mouvement est coupé).
class KpbSkeletonBox extends StatelessWidget {
  const KpbSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = KpbRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => _SkeletonPulse(
        width: width,
        height: height,
        borderRadius: radius,
      );
}

/// Squelette générique d'une liste de cartes : le défaut de KpbAsyncView.
class KpbSkeletonList extends StatelessWidget {
  const KpbSkeletonList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 88,
    this.padding = const EdgeInsets.all(KpbSpacing.page),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) const SizedBox(height: KpbSpacing.sm + KpbSpacing.xs),
            KpbSkeletonBox(height: itemHeight, radius: KpbRadius.md),
          ],
        ],
      ),
    );
  }
}
