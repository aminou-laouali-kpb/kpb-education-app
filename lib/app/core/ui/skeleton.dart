import 'package:flutter/material.dart';

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
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
