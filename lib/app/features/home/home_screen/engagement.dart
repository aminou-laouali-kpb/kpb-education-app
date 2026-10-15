part of '../home_screen.dart';

// Carrousel des parcours, conseiller WhatsApp.

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
        KpbToast.error('parcours_video_unavailable'.tr);
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

        // The page gutter is carried here — header padded, and the horizontal
        // list padded via its `padding` so cards align with the gutter but
        // still scroll edge-to-edge. Bottom spacing only when visible: no
        // story (or a failed fetch) leaves no gap.
        return _homeBlockPadding(
          gutter: false,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              'home_parcours_title'.tr,
                              style: KpbTextStyles.title,
                            ),
                          ),
                          Text(
                            'home_parcours_subtitle'.tr,
                            style: KpbTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const ValueKey<String>('home-parcours-see-all'),
                      style:
                          TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () =>
                          Get.to<void>(() => const ParcoursScreen()),
                      child: Text('see_all'.tr),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KpbSpacing.xs),
              SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.pagePad),
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
          ),
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

    return KpbPressable(
      onTap: onTap,
      semanticLabel: who.isEmpty ? title : '$title, $who',
      child: ExcludeSemantics(
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
                height: 88,
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
                              fontSize: KpbFontSize.xs,
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
                        fontSize: KpbFontSize.xs,
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
                        style: KpbTextStyles.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
    return _homeBlockPadding(
      KpbPressable(
        key: const ValueKey<String>('home-counselor-entry'),
        onTap: _open,
        semanticLabel:
            '${'home_counselor_cta_title'.tr}. ${'home_counselor_cta_subtitle'.tr}',
        child: ExcludeSemantics(
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
                  child: const Icon(Icons.chat_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home_counselor_cta_title'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.md,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'home_counselor_cta_subtitle'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.sm,
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
        ),
      ),
    );
  }
}
