part of '../home_screen.dart';

// Outils étudiants, carrousel des parcours, conseiller WhatsApp.

class _StudentToolsBanner extends StatelessWidget {
  const _StudentToolsBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => const StudentToolsScreen()),
      child: Container(
        padding: const EdgeInsets.all(KpbSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              KpbColors.actionPrimary.withValues(alpha: 0.15),
              KpbColors.success.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: KpbRadius.xlBr,
          border: Border.all(
            color: KpbColors.actionPrimary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KpbColors.actionPrimary.withValues(alpha: 0.15),
                borderRadius: KpbRadius.mdBr,
              ),
              child: const Icon(
                Icons.build_circle_rounded,
                color: KpbColors.actionPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_student_tools_title'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: KpbColors.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'home_student_tools_subtitle'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: KpbColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: KpbColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "They did it before you" — real Parcours & Témoignages stories (PR #109),
// just surfaced on Home. Fetches once; self-hides until real stories load.
// Does not modify anything under lib/app/features/parcours/.
// ─────────────────────────────────────────────────────────────────────────────
class _ParcoursHomeCarousel extends StatefulWidget {
  const _ParcoursHomeCarousel();

  @override
  State<_ParcoursHomeCarousel> createState() => _ParcoursHomeCarouselState();
}

class _ParcoursHomeCarouselState extends State<_ParcoursHomeCarousel> {
  @override
  void initState() {
    super.initState();
    // Safe to call repeatedly — skips the network round-trip once populated.
    // Après la première frame : l'appel fait un `update()` synchrone, interdit
    // pendant un build (« setState() called during build » en debug).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.find<AppController>().fetchParcoursStories();
    });
  }

  void _open(ParcoursStory story, List<ParcoursStory> videoStories) {
    if (story.isVideo) {
      final playable = videoStories
          .where((v) => (v.youtubeId ?? '').isNotEmpty)
          .toList(growable: false);
      if ((story.youtubeId ?? '').isEmpty || playable.isEmpty) {
        Get.snackbar(
          'parcours_appbar_title'.tr,
          'parcours_video_unavailable'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final index = playable.indexWhere((v) => v.slug == story.slug);
      Get.to(() => ParcoursPlayerScreen(
            videos: playable,
            initialIndex: index < 0 ? 0 : index,
          ));
    } else {
      Get.to(() => ParcoursStoryScreen(story: story));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final stories = controller.parcoursStories.take(6).toList();
        if (stories.isEmpty) return const SizedBox.shrink();
        final videoStories =
            controller.parcoursStories.where((s) => s.isVideo).toList();
        final locale = controller.localeCode;

        // This section lives in its own SliverToBoxAdapter (outside the padded
        // Column at the top of the scroll view), so it must carry the page
        // gutter itself — same recipe as HScrollSection ("Bourses pour toi",
        // "Universités recommandées"): header padded, and the horizontal list
        // padded via its `padding` so cards align with the gutter but still
        // scroll edge-to-edge.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'home_parcours_title'.tr,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: KpbColors.brandNavy,
                          ),
                        ),
                        Text(
                          'home_parcours_subtitle'.tr,
                          style: const TextStyle(
                              fontSize: 10.5, color: KpbColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.to(() => const ParcoursScreen()),
                    child: Text(
                      'see_all'.tr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.actionPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
                itemCount: stories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (ctx, i) {
                  final story = stories[i];
                  return _ParcoursHomeCard(
                    story: story,
                    locale: locale,
                    onTap: () => _open(story, videoStories),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParcoursHomeCard extends StatelessWidget {
  const _ParcoursHomeCard({
    required this.story,
    required this.locale,
    required this.onTap,
  });

  final ParcoursStory story;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = story.title.resolve(locale);
    final who = story.personName.isNotEmpty
        ? story.personName
        : story.role.resolve(locale);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 172,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              color: KpbColors.brandNavy,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        story.isVideo
                            ? Icons.play_arrow_rounded
                            : Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  if (story.durationMinutes != null)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${story.durationMinutes} min',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.brandNavy,
                      height: 1.3,
                    ),
                  ),
                  if (who.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: KpbColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Talk to a KPB counselor" — dark navy WhatsApp hand-off card. No in-app
// payment/checkout anywhere on Home; every advisor contact routes through
// the official KPB WhatsApp line.
// ─────────────────────────────────────────────────────────────────────────────
class _CounselorWhatsAppCard extends StatelessWidget {
  const _CounselorWhatsAppCard();

  void _open() {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill: kpbWhatsAppPrefill(),
      source: 'home',
      contextType: 'home_counselor_card',
    );
  }

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: _open,
      child: Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: KpbRadius.xlBr,
        ),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KpbColors.whatsapp,
                borderRadius: KpbRadius.mdBr,
              ),
              child:
                  const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_counselor_cta_title'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'home_counselor_cta_subtitle'.tr,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: KpbColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: KpbColors.decorSky, size: 17),
          ],
        ),
      ),
    );
  }
}
