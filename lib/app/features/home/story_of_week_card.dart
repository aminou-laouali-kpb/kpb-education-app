import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import '../parcours/parcours_feed_screen.dart';
import '../parcours/parcours_story_screen.dart';

/// Home "Récit de la semaine" card (KPB-169).
///
/// Self-fetches the editorial pick and renders NOTHING until it has one — no
/// skeleton, no "bientôt". When nothing is featured (or the call fails) the
/// card simply isn't there, which is the honest state: an empty editorial slot
/// is empty, not a placeholder.
class StoryOfWeekCard extends StatefulWidget {
  const StoryOfWeekCard({super.key});

  @override
  State<StoryOfWeekCard> createState() => _StoryOfWeekCardState();
}

class _StoryOfWeekCardState extends State<StoryOfWeekCard> {
  static const _source = 'story_of_week';

  final _ctrl = Get.find<AppController>();
  ParcoursStory? _story;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ParcoursStory? story;
    try {
      story = await _ctrl.apiClient.fetchStoryOfWeek();
    } catch (_) {
      // Best-effort: any failure just hides the card.
      story = null;
    }
    if (!mounted) return;
    setState(() {
      _story = story;
      _loaded = true;
    });
    if (story != null) {
      unawaited(AnalyticsService.instance.logStoryOfWeekViewed(story.slug));
    }
  }

  void _open(ParcoursStory story) {
    AnalyticsService.instance.logStoryOfWeekOpened(story.slug);
    if (story.isVideo) {
      Get.to(() => ParcoursFeedScreen(stories: [story]));
    } else {
      Get.to(
        () => ParcoursStoryScreen(story: story, analyticsSource: _source),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    if (!_loaded || story == null) return const SizedBox.shrink();
    final localeCode = _ctrl.localeCode;
    final hook = story.hook.resolve(localeCode);
    final role = story.role.resolve(localeCode);
    final subtitle = hook.isNotEmpty ? hook : story.summary.resolve(localeCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
      child: Material(
        color: KpbColors.brandNavy,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _open(story),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: story.effectiveThumbnailUrl.isEmpty
                        ? const DecoratedBox(
                            decoration:
                                BoxDecoration(gradient: KpbColors.heroGradient),
                            child: Icon(Icons.auto_stories_rounded,
                                color: Colors.white, size: 26),
                          )
                        : KpbNetworkImage(
                            imageUrl: story.effectiveThumbnailUrl,
                            targetWidth: 76,
                            placeholderIcon: story.isVideo
                                ? Icons.ondemand_video_rounded
                                : Icons.auto_stories_rounded,
                            iconSize: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'story_of_week_title'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: KpbColors.decorSky,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        story.title.resolve(localeCode),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      if (story.personName.isNotEmpty || role.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          [story.personName, role]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: KpbColors.textFaint,
                          ),
                        ),
                      ],
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: KpbColors.textFaint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: KpbColors.decorSky),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
