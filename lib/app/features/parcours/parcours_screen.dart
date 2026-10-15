// M-Parcours (Chantier C) — "Parcours & Témoignages KPB".
//
// A free section of inspiring career/education journeys, served from the
// backend catalog (`/content/parcours`) and cached offline. Two kinds share
// the screen: videos open an in-app YouTube player; written interviews open a
// Q&A reader. Discovery is by field-domain theme chips + a search bar.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/mock_catalog.dart';
import '../../core/models/app_models.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import 'parcours_feed_screen.dart';
import 'parcours_story_screen.dart';

// Couleurs : tokens sémantiques centraux (KpbColors — architecture §10.2).
/// Localized short label for a field domain id (d01..d12).
String parcoursFieldLabel(String? fieldId, String localeCode) {
  if (fieldId == null) return '';
  for (final f in MockCatalog.fields) {
    if (f.id == fieldId) return f.name.resolve(localeCode);
  }
  return '';
}

class ParcoursScreen extends StatefulWidget {
  const ParcoursScreen({super.key});

  @override
  State<ParcoursScreen> createState() => _ParcoursScreenState();
}

class _ParcoursScreenState extends State<ParcoursScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AppController>().fetchParcoursStories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      Get.find<AppController>().fetchParcoursStories(force: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('parcours_appbar_title'.tr),
        backgroundColor: Colors.transparent,
      ),
      body: GetBuilder<AppController>(
        builder: (controller) {
          final all = controller.parcoursStories;

          if (controller.isLoadingParcours && all.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (all.isEmpty) {
            if (controller.parcoursError == null) {
              return _ParcoursEmptyState(
                icon: Icons.video_library_outlined,
                title: 'parcours_empty_soon_title'.tr,
                subtitle: 'parcours_empty_soon_subtitle'.tr,
                onRetry: _refresh,
              );
            }
            return _ParcoursEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'parcours_empty_error_title'.tr,
              subtitle: controller.parcoursError ??
                  'parcours_empty_error_subtitle'.tr,
              onRetry: _refresh,
            );
          }

          final stories = controller.filteredParcoursStories;
          // The player's "up next" playlist should only contain videos.
          final videoStories =
              stories.where((s) => s.isVideo).toList(growable: false);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _ParcoursIntro()),
                SliverToBoxAdapter(
                  child: _ParcoursSearchField(
                    controller: _searchController,
                    onChanged: controller.setParcoursQuery,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FeedEntryButton(
                    // The feed plays what the filters currently select, so the
                    // two discovery modes never disagree about what is on offer.
                    onTap: () => _openFeed(controller.filteredParcoursStories),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ThemeFilterBar(
                    fieldIds: controller.parcoursFieldIds,
                    selected: controller.parcoursFieldFilter,
                    localeCode: controller.localeCode,
                    onSelected: controller.setParcoursFieldFilter,
                  ),
                ),
                if (stories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ParcoursEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'parcours_empty_filter_title'.tr,
                      subtitle: 'parcours_empty_filter_subtitle'.tr,
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad,
                      KpbSpacing.sm,
                      KpbSpacing.pagePad,
                      0,
                    ),
                    sliver: SliverList.separated(
                      itemCount: stories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KpbSpacing.md),
                      itemBuilder: (context, index) {
                        final story = stories[index];
                        return _StoryCard(
                          story: story,
                          localeCode: controller.localeCode,
                          onTap: () => _openStory(story, videoStories),
                        );
                      },
                    ),
                  ),
                  const SliverPadding(
                    // Bottom inset clears the floating nav bar if shown.
                    padding: EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad,
                      KpbSpacing.md,
                      KpbSpacing.pagePad,
                      100,
                    ),
                    sliver: SliverToBoxAdapter(child: _ConvertCard()),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _openFeed(List<ParcoursStory> stories) {
    if (stories.isEmpty) return;
    Get.to(() => ParcoursFeedScreen(stories: stories));
  }

  void _openStory(ParcoursStory story, List<ParcoursStory> videoStories) {
    AnalyticsService.instance.logParcoursView(
      slug: story.slug,
      kind: story.isVideo ? 'video' : 'text',
      source: 'library',
    );
    if (story.isVideo) {
      // Only hand the player videos with a real YouTube id — a malformed
      // "video" story with no id would otherwise open a permanently blank
      // player (and desync the "up next" list).
      final playable = videoStories
          .where((v) => (v.youtubeId ?? '').isNotEmpty)
          .toList(growable: false);
      if ((story.youtubeId ?? '').isEmpty || playable.isEmpty) {
        KpbToast.error('parcours_video_unavailable'.tr);
        return;
      }
      final index = playable.indexWhere((v) => v.slug == story.slug);
      Get.to(
        () => ParcoursPlayerScreen(
          videos: playable,
          initialIndex: index < 0 ? 0 : index,
        ),
      );
    } else {
      Get.to(() => ParcoursStoryScreen(story: story));
      // The reader logs its own view (source 'library' by default) — see
      // ParcoursStoryScreen — so nothing else to emit here.
    }
  }
}

/// Conversion card from the handoff ("Tu veux suivre un parcours similaire ?
/// Discute avec KPB →") — the screen's only conversion point in the spec.
/// Routes through the existing verified-advisor → WhatsApp hand-off.
class _ConvertCard extends StatelessWidget {
  const _ConvertCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'parcours_convert_title'.tr,
      child: GestureDetector(
        onTap: () => showVerifiedAdvisorThenWhatsApp(
          prefill: 'parcours_whatsapp_prefill'.tr,
          source: 'parcours',
          contextType: 'parcours',
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KpbColors.brandNavy,
            borderRadius: KpbRadius.lgBr,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: KpbColors.whatsapp,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.forum_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'parcours_convert_title'.tr,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'parcours_convert_subtitle'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: KpbColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: KpbColors.decorSky, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParcoursIntro extends StatelessWidget {
  const _ParcoursIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        0,
      ),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: const BoxDecoration(
        gradient: KpbColors.heroGradient,
        borderRadius: KpbRadius.lgBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'parcours_free_badge'.tr,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: KpbColors.decorSky,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'parcours_intro_title'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'parcours_intro'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcoursSearchField extends StatelessWidget {
  const _ParcoursSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        0,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'parcours_search_hint'.tr,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          filled: true,
          fillColor: context.kpb.cardBg,
          border: OutlineInputBorder(
            borderRadius: KpbRadius.mdBr,
            borderSide: BorderSide(color: context.kpb.gray200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: KpbRadius.mdBr,
            borderSide: BorderSide(color: context.kpb.gray200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: KpbRadius.mdBr,
            borderSide:
                const BorderSide(color: KpbColors.actionPrimary, width: 2),
          ),
        ),
      ),
    );
  }
}

class _ThemeFilterBar extends StatelessWidget {
  const _ThemeFilterBar({
    required this.fieldIds,
    required this.selected,
    required this.localeCode,
    required this.onSelected,
  });

  final List<String> fieldIds;
  final String? selected;
  final String localeCode;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (fieldIds.isEmpty) return const SizedBox(height: KpbSpacing.sm);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          KpbSpacing.md,
          KpbSpacing.pagePad,
          0,
        ),
        children: [
          _Chip(
            label: 'parcours_filter_all'.tr,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final id in fieldIds) ...[
            const SizedBox(width: KpbSpacing.sm),
            _Chip(
              label: parcoursFieldLabel(id, localeCode),
              selected: selected == id,
              onTap: () => onSelected(id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? KpbColors.actionPrimary : context.kpb.textPrimary,
      ),
      // `color` et non `selectedColor` : le chipTheme global fixe `color`
      // (actionPrimary si sélectionnée), prioritaire dans RawChip — le libellé
      // actionPrimary devenait invisible sur fond actionPrimary.
      color: WidgetStatePropertyAll(
        selected ? KpbColors.actionPrimarySoft : context.kpb.cardBg,
      ),
      side: BorderSide(
        color: selected
            ? KpbColors.actionPrimary.withValues(alpha: 0.3)
            : context.kpb.gray200,
      ),
      shape: const StadiumBorder(),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.localeCode,
    required this.onTap,
  });

  final ParcoursStory story;
  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = parcoursFieldLabel(story.fieldId, localeCode);
    final subtitle = _subtitle();
    return KpbCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: KpbRadius.lgBr,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StoryMedia(story: story),
            Padding(
              padding: const EdgeInsets.all(KpbSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title.resolve(localeCode),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KpbTextStyles.titleMd,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KpbTextStyles.bodySm
                          .copyWith(color: context.kpb.textMuted),
                    ),
                  ],
                  if (theme.isNotEmpty) ...[
                    const SizedBox(height: KpbSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          story.isVideo
                              ? Icons.play_circle_outline_rounded
                              : Icons.menu_book_outlined,
                          size: 15,
                          color: KpbColors.actionPrimary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            theme,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KpbTextStyles.labelSm
                                .copyWith(color: KpbColors.actionPrimary),
                          ),
                        ),
                      ],
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

  String _subtitle() {
    final role = story.role.resolve(localeCode);
    final name = story.personName;
    if (name.isNotEmpty && role.isNotEmpty) return '$name · $role';
    if (name.isNotEmpty) return name;
    if (role.isNotEmpty) return role;
    return story.hook.resolve(localeCode);
  }
}

/// The 16:9 media band at the top of a card — a video thumbnail with a play
/// overlay + duration badge, or (for written stories) a gradient banner with a
/// monogram, so the list keeps a uniform rhythm.
class _StoryMedia extends StatelessWidget {
  const _StoryMedia({required this.story});

  final ParcoursStory story;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(16));
    if (story.isVideo) {
      return ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              KpbNetworkImage(
                imageUrl: story.effectiveThumbnailUrl,
                targetWidth: 360,
                placeholderIcon: Icons.ondemand_video_rounded,
                errorIcon: Icons.broken_image_outlined,
                iconSize: 40,
              ),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
              if (story.durationMinutes != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _Pill(
                    label: '${story.durationMinutes} min',
                    background: Colors.black.withValues(alpha: 0.7),
                    foreground: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Written testimonial: gradient banner + monogram + "written story" pill.
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: 96,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: KpbColors.heroGradient),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Row(
          children: [
            _Monogram(name: story.personName),
            const Spacer(),
            _Pill(
              label: 'parcours_kind_written'.tr,
              background: Colors.white.withValues(alpha: 0.22),
              foreground: Colors.white,
              icon: Icons.menu_book_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '★';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KpbRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcoursEmptyState extends StatelessWidget {
  const _ParcoursEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.kpb.gray400),
            const SizedBox(height: KpbSpacing.md),
            Text(title,
                style: KpbTextStyles.titleLg, textAlign: TextAlign.center),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              subtitle,
              style: KpbTextStyles.body.copyWith(color: context.kpb.textMuted),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KpbSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('retry'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player — embeds the selected video, shows its summary/tags, and lets the
// user jump between the other videos.
// ─────────────────────────────────────────────────────────────────────────────

class ParcoursPlayerScreen extends StatefulWidget {
  const ParcoursPlayerScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  final List<ParcoursStory> videos;
  final int initialIndex;

  @override
  State<ParcoursPlayerScreen> createState() => _ParcoursPlayerScreenState();
}

class _ParcoursPlayerScreenState extends State<ParcoursPlayerScreen> {
  late int _currentIndex;
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1);
    final videoId = widget.videos.isEmpty
        ? ''
        : (widget.videos[_currentIndex].youtubeId ?? '');
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      // KPB-157: tap-to-play — no auto-play on metered data.
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _playAt(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    final id = widget.videos[index].youtubeId;
    if (id != null && id.isNotEmpty) _controller?.load(id);
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = Get.find<AppController>().localeCode;
    final controller = _controller!;
    // Defensive: no current call path opens the player with an empty list, but
    // guard so a future caller can't crash on the index access below.
    if (widget.videos.isEmpty) {
      return Scaffold(
        backgroundColor: context.kpb.pageBg,
        appBar: AppBar(title: Text('parcours_appbar_title'.tr)),
        body: Center(child: Text('parcours_empty_filter_title'.tr)),
      );
    }
    final current = widget.videos[_currentIndex];

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: KpbColors.actionPrimary,
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: context.kpb.pageBg,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'parcours_appbar_title'.tr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.black,
                child: AspectRatio(aspectRatio: 16 / 9, child: player),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(KpbSpacing.lg),
                      child: _NowPlaying(
                        story: current,
                        localeCode: localeCode,
                      ),
                    ),
                    Divider(color: context.kpb.gray100, height: 1),
                    if (widget.videos.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            KpbSpacing.lg, KpbSpacing.md, KpbSpacing.lg, 4),
                        child: Text(
                          'parcours_up_next'.tr,
                          style: KpbTextStyles.label
                              .copyWith(color: context.kpb.textMuted),
                        ),
                      ),
                    ...List.generate(widget.videos.length, (index) {
                      final v = widget.videos[index];
                      final isCurrent = index == _currentIndex;
                      return ListTile(
                        onTap: () => _playAt(index),
                        tileColor: isCurrent
                            ? KpbColors.actionPrimary.withValues(alpha: 0.06)
                            : Colors.transparent,
                        leading: ClipRRect(
                          borderRadius: KpbRadius.smBr,
                          child: SizedBox(
                            width: 64,
                            height: 40,
                            child: KpbNetworkImage(
                              imageUrl: v.effectiveThumbnailUrl,
                              targetWidth: 64,
                              placeholderIcon: Icons.ondemand_video_rounded,
                              iconSize: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          v.title.resolve(localeCode),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? KpbColors.actionPrimary
                                : context.kpb.textPrimary,
                            fontSize: 14,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.equalizer_rounded,
                                color: KpbColors.actionPrimary)
                            : null,
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.story, required this.localeCode});

  final ParcoursStory story;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final role = story.role.resolve(localeCode);
    final summary = story.summary.resolve(localeCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          story.title.resolve(localeCode),
          style:
              KpbTextStyles.headline.copyWith(color: context.kpb.textPrimary),
        ),
        if (story.personName.isNotEmpty || role.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            [story.personName, role].where((s) => s.isNotEmpty).join(' · '),
            style:
                KpbTextStyles.bodySm.copyWith(color: KpbColors.actionPrimary),
          ),
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.md),
          Text(
            summary,
            style:
                KpbTextStyles.body.copyWith(color: context.kpb.textSecondary),
          ),
        ],
        if (story.tags.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in story.tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.kpb.gray100,
                    borderRadius: BorderRadius.circular(KpbRadius.pill),
                  ),
                  child: Text(tag,
                      style: KpbTextStyles.caption
                          .copyWith(color: context.kpb.textSecondary)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Entry point to the vertical feed (KPB-169). The grid answers "what is
/// there?"; the feed answers "just show me one". Both stay available — a
/// student on a slow connection may prefer the list.
class _FeedEntryButton extends StatelessWidget {
  const _FeedEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        0,
      ),
      child: Semantics(
        button: true,
        label: 'parcours_feed_cta'.tr,
        child: Material(
          color: KpbColors.actionPrimarySoft,
          borderRadius: KpbRadius.mdBr,
          child: InkWell(
            onTap: onTap,
            borderRadius: KpbRadius.mdBr,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KpbSpacing.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(Icons.swipe_vertical_rounded,
                      size: 19, color: KpbColors.actionPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'parcours_feed_cta'.tr,
                      style: KpbTextStyles.labelSm
                          .copyWith(color: KpbColors.actionPrimary),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: KpbColors.actionPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
