import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/external_link.dart';

/// Deferred in-app player: no YouTube platform view is created until the
/// student explicitly opens a video from a scholarship detail.
class ScholarshipVideoPlayerScreen extends StatefulWidget {
  const ScholarshipVideoPlayerScreen({
    super.key,
    required this.scholarshipTitle,
    required this.videos,
    this.initialIndex = 0,
  });

  final String scholarshipTitle;
  final List<ScholarshipVideoModel> videos;
  final int initialIndex;

  @override
  State<ScholarshipVideoPlayerScreen> createState() =>
      _ScholarshipVideoPlayerScreenState();
}

class _ScholarshipVideoPlayerScreenState
    extends State<ScholarshipVideoPlayerScreen> {
  late int _currentIndex;
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1);
    if (widget.videos.isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: widget.videos[_currentIndex].youtubeVideoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _playAt(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _controller?.load(widget.videos[index].youtubeVideoId);
  }

  Future<void> _openOnYoutube() async {
    if (widget.videos.isEmpty) return;
    final video = widget.videos[_currentIndex];
    final uri = video.watchUrl.isNotEmpty
        ? Uri.parse(video.watchUrl)
        : Uri.https(
            'www.youtube.com',
            '/watch',
            {'v': video.youtubeVideoId},
          );
    await kpbOpenExternalUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.scholarshipTitle)),
        body: Center(child: Text('scholarship_video_unavailable'.tr)),
      );
    }

    final current = widget.videos[_currentIndex];
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: KpbColors.blue,
      ),
      builder: (context, player) => Scaffold(
        backgroundColor: context.kpb.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            widget.scholarshipTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: Colors.black,
              child: AspectRatio(aspectRatio: 16 / 9, child: player),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      current.title.isEmpty
                          ? widget.scholarshipTitle
                          : current.title,
                      style: KpbTextStyles.titleLg,
                    ),
                  ),
                  if (current.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(current.description, style: KpbTextStyles.body),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openOnYoutube,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text('scholarship_video_open_youtube'.tr),
                    ),
                  ),
                  if (widget.videos.length > 1) ...[
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text(
                        'scholarship_video_more'.tr,
                        style: KpbTextStyles.titleMd,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var index = 0; index < widget.videos.length; index++)
                      _VideoRow(
                        video: widget.videos[index],
                        selected: index == _currentIndex,
                        onTap: () => _playAt(index),
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

class _VideoRow extends StatelessWidget {
  const _VideoRow({
    required this.video,
    required this.selected,
    required this.onTap,
  });

  final ScholarshipVideoModel video;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title =
        video.title.isEmpty ? 'scholarship_video_explanation'.tr : video.title;
    return Semantics(
      button: true,
      selected: selected,
      label: '${'scholarship_video_play'.tr}: $title',
      child: Card(
        color: selected ? KpbColors.blue.withValues(alpha: 0.08) : null,
        child: ListTile(
          onTap: onTap,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 44,
              child: KpbNetworkImage(
                imageUrl: video.effectiveThumbnailUrl,
                targetWidth: 144,
                placeholderIcon: Icons.play_circle_outline_rounded,
              ),
            ),
          ),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: video.language.isEmpty
              ? null
              : Text(video.language.toUpperCase()),
          trailing: Icon(
            selected ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
            color: KpbColors.blue,
          ),
        ),
      ),
    );
  }
}
