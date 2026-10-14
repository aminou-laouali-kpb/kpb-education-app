// Vertical Parcours feed (KPB-169).
//
// The library screen answers "what is there?"; this one answers "show me one".
// One story per full-height page, swiped vertically — the gesture our audience
// already has in their fingers from every other app on the phone.
//
// Three rules, all load-bearing on an entry-level Android over paid data:
//   • NOTHING auto-plays. A page shows a poster and a play button; the tap is
//     the consent. (Same rule as KPB-157, which killed the library's autoplay.)
//   • ONE player exists at a time. Swiping away disposes it, so memory stays
//     flat no matter how far the student scrolls.
//   • In data-saver mode the poster is not even fetched — the page degrades to
//     a text card instead of silently spending someone's airtime.
//
// Completion is measured here, not guessed: `parcours_view` fires when a page
// settles, `parcours_complete` when the video reaches its end.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import 'parcours_screen.dart' show parcoursFieldLabel;
import 'parcours_story_screen.dart';

/// Analytics surface tag — lets completion be read per surface.
const parcoursFeedSource = 'feed';

class ParcoursFeedScreen extends StatefulWidget {
  const ParcoursFeedScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.analyticsSource = parcoursFeedSource,
  });

  final List<ParcoursStory> stories;
  final int initialIndex;

  /// Surface tag for view/completion events. 'feed' by default; a push or
  /// deep link passes its own so those opens are not counted as feed traffic.
  final String analyticsSource;

  @override
  State<ParcoursFeedScreen> createState() => _ParcoursFeedScreenState();
}

class _ParcoursFeedScreenState extends State<ParcoursFeedScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.stories.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _index);
    if (widget.stories.isNotEmpty) _logView(widget.stories[_index]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _logView(ParcoursStory story) {
    AnalyticsService.instance.logParcoursView(
      slug: story.slug,
      kind: story.isVideo ? 'video' : 'text',
      source: widget.analyticsSource,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _logView(widget.stories[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: Center(
          child: Text(
            'parcours_empty_filter_title'.tr,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'parcours_feed_title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.stories.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final story = widget.stories[index];
          return _FeedPage(
            // Keying on the slug guarantees the player of a swiped-away page is
            // disposed instead of being recycled with a stale video id.
            key: ValueKey(story.slug),
            story: story,
            analyticsSource: widget.analyticsSource,
            isCurrent: index == _index,
            position: index + 1,
            total: widget.stories.length,
          );
        },
      ),
    );
  }
}

/// One full-height story. Starts as a poster; becomes a player only after the
/// student taps, and only while it is the visible page.
class _FeedPage extends StatefulWidget {
  const _FeedPage({
    super.key,
    required this.story,
    required this.analyticsSource,
    required this.isCurrent,
    required this.position,
    required this.total,
  });

  final ParcoursStory story;
  final String analyticsSource;
  final bool isCurrent;
  final int position;
  final int total;

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  YoutubePlayerController? _player;
  bool _completeLogged = false;

  @override
  void didUpdateWidget(covariant _FeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Swiped away mid-playback: tear the player down rather than leave audio
    // running behind another story.
    if (oldWidget.isCurrent && !widget.isCurrent) {
      _tearDownPlayer();
      setState(() {});
    }
  }

  @override
  void dispose() {
    // No setState here — the element is already going away, and calling it
    // during dispose() trips a framework assertion.
    _tearDownPlayer();
    super.dispose();
  }

  void _tearDownPlayer() {
    _player?.removeListener(_onPlayerTick);
    _player?.dispose();
    _player = null;
  }

  void _play() {
    final id = widget.story.youtubeId ?? '';
    if (id.isEmpty) {
      KpbToast.error('parcours_video_unavailable'.tr);
      return;
    }
    final controller = YoutubePlayerController(
      initialVideoId: id,
      // autoPlay stays false at construction; the tap below is the intent.
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    )..addListener(_onPlayerTick);
    setState(() => _player = controller);
  }

  void _onPlayerTick() {
    final player = _player;
    if (player == null || _completeLogged) return;
    if (player.value.playerState == PlayerState.ended) {
      _completeLogged = true;
      AnalyticsService.instance.logParcoursComplete(
        slug: widget.story.slug,
        kind: 'video',
        source: widget.analyticsSource,
      );
    }
  }

  void _openWritten() {
    Get.to(
      () => ParcoursStoryScreen(
        story: widget.story,
        analyticsSource: widget.analyticsSource,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = Get.find<AppController>().localeCode;
    final story = widget.story;
    final player = _player;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (story.isVideo)
          KpbNetworkImage(
            imageUrl: story.effectiveThumbnailUrl,
            // The poster IS the content here, but on data-saver we still don't
            // want to spend airtime on it — the text below carries the story.
            decorative: true,
            fit: BoxFit.cover,
            fallbackColor: Colors.black,
            placeholderIcon: Icons.ondemand_video_rounded,
            iconSize: 44,
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(gradient: KpbColors.heroGradient),
          ),
        // Scrim: keeps the text legible over any poster.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        if (player != null)
          Center(
            child: YoutubePlayer(
              controller: player,
              showVideoProgressIndicator: true,
              progressIndicatorColor: KpbColors.actionPrimary,
            ),
          )
        else if (story.isVideo)
          Center(
            child: Semantics(
              button: true,
              label: 'parcours_feed_play'.tr,
              child: GestureDetector(
                onTap: _play,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 42),
                ),
              ),
            ),
          ),
        Positioned(
          left: KpbSpacing.pagePad,
          right: KpbSpacing.pagePad,
          bottom: 40,
          child: _FeedCaption(
            story: story,
            localeCode: localeCode,
            position: widget.position,
            total: widget.total,
            onRead: story.isVideo ? null : _openWritten,
          ),
        ),
      ],
    );
  }
}

class _FeedCaption extends StatelessWidget {
  const _FeedCaption({
    required this.story,
    required this.localeCode,
    required this.position,
    required this.total,
    this.onRead,
  });

  final ParcoursStory story;
  final String localeCode;
  final int position;
  final int total;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final theme = parcoursFieldLabel(story.fieldId, localeCode);
    final role = story.role.resolve(localeCode);
    final hook = story.hook.resolve(localeCode);
    final summary = story.summary.resolve(localeCode);
    final subtitle = hook.isNotEmpty ? hook : summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (theme.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(KpbRadius.pill),
                ),
                child: Text(
                  theme,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Spacer(),
            Text(
              '$position/$total',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: KpbSpacing.sm),
        Text(
          story.title.resolve(localeCode),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (story.personName.isNotEmpty || role.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            [story.personName, role].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.sm),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
        if (onRead != null) ...[
          const SizedBox(height: KpbSpacing.md),
          FilledButton.icon(
            onPressed: onRead,
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: Text('parcours_feed_read'.tr),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: KpbColors.brandNavy,
            ),
          ),
        ],
        const SizedBox(height: KpbSpacing.sm),
        Row(
          children: [
            Icon(Icons.swipe_vertical_rounded,
                size: 15, color: Colors.white.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              'parcours_feed_swipe_hint'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
