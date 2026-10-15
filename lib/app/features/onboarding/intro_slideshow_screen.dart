import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/app_boot_screen.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';

class IntroSlideshowScreen extends StatefulWidget {
  const IntroSlideshowScreen({super.key});

  @override
  State<IntroSlideshowScreen> createState() => _IntroSlideshowScreenState();
}

class _IntroSlideshowScreenState extends State<IntroSlideshowScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_SlideData> _slides = [
    _SlideData(
      icon: Icons.explore_rounded,
      accent: KpbColors.blue,
      title: 'intro_slide1_title'.tr,
      description: 'intro_slide1_body'.tr,
    ),
    _SlideData(
      icon: Icons.workspace_premium_rounded,
      accent: KpbColors.gold,
      title: 'intro_slide2_title'.tr,
      description: 'intro_slide2_body'.tr,
    ),
    _SlideData(
      icon: Icons.folder_copy_rounded,
      accent: KpbColors.sky,
      title: 'intro_slide3_title'.tr,
      description: 'intro_slide3_body'.tr,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    KpbHaptics.confirm();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishIntro();
    }
  }

  void _finishIntro() {
    Get.find<AppController>().completeIntro();
    Get.offAll(() => const AppBootScreen());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final accent = _slides[_currentPage].accent;
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: Stack(
        children: [
          // Soft brand halo that tints with the current slide's accent.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Align(
              key: ValueKey(accent),
              alignment: const Alignment(0, -0.45),
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.18),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Slides with parallax-on-scroll.
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _slides.length,
            itemBuilder: (context, index) => _SlideView(
              data: _slides[index],
              index: index,
              pageController: _pageController,
            ),
          ),

          // Skip
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: TextButton(
              onPressed: _finishIntro,
              child: Text(
                'skip'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(_slides.length, (index) {
                    final isActive = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 8),
                      height: 8,
                      width: isActive ? 26 : 8,
                      decoration: BoxDecoration(
                        color: isActive ? accent : c.gray300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                KpbPressable(
                  onTap: _onNext,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: KpbRadius.pillBr,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'get_started'.tr : 'continue_action'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
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

class _SlideData {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;

  const _SlideData({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
  });
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.data,
    required this.index,
    required this.pageController,
  });

  final _SlideData data;
  final int index;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, child) {
        // Parallax: 1.0 when this page is centered, fading as it scrolls away.
        double page = index.toDouble();
        if (pageController.hasClients &&
            pageController.position.haveDimensions) {
          page = pageController.page ?? index.toDouble();
        }
        final delta = (index - page);
        final t = (1 - delta.abs()).clamp(0.0, 1.0);
        return Opacity(
          opacity: (0.3 + 0.7 * t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 28),
            child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gradient icon medallion
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [data.accent, data.accent.withValues(alpha: 0.65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: data.accent.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Icon(data.icon, size: 76, color: Colors.white),
            ),
            const SizedBox(height: 56),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: c.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
