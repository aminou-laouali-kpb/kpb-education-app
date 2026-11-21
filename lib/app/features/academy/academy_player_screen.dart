import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';

class AcademyPlayerScreen extends StatefulWidget {
  const AcademyPlayerScreen({
    super.key,
    required this.course,
    required this.lessons,
    this.initialLessonIndex = 0,
  });

  final AcademyCourseModel course;

  /// Les seules leçons LISIBLES par cet élève, dans l'ordre du cours : les
  /// leçons verrouillées n'arrivent jamais jusqu'au lecteur.
  final List<AcademyLessonModel> lessons;
  final int initialLessonIndex;

  @override
  State<AcademyPlayerScreen> createState() => _AcademyPlayerScreenState();
}

class _AcademyPlayerScreenState extends State<AcademyPlayerScreen> {
  late List<AcademyLessonModel> _lessons;
  late int _currentIndex;
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    _lessons = widget.lessons.where((lesson) => lesson.playable).toList();
    _currentIndex = widget.initialLessonIndex
        .clamp(0, _lessons.isEmpty ? 0 : _lessons.length - 1)
        .toInt();
    if (_lessons.isNotEmpty) {
      _initPlayer(_lessons[_currentIndex].videoUrl);
    }
  }

  void _initPlayer(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      if (_ytController != null) {
        _ytController!.load(videoId);
      } else {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          // KPB-157: never auto-play — data is metered for our audience, so the
          // user taps play (matches the scholarship player).
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  void _onLessonTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    _initPlayer(_lessons[index].videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ytController = _ytController;

    if (ytController == null) {
      return Scaffold(
        backgroundColor: context.kpb.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'academy_player_no_session'.tr,
            style: KpbTextStyles.body.copyWith(color: context.kpb.textPrimary),
          ),
        ),
      );
    }

    final controller = Get.find<AppController>();
    final currentLesson = _lessons[_currentIndex];

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: ytController,
        showVideoProgressIndicator: true,
        progressIndicatorColor: KpbColors.blue,
        onReady: () => ytController.addListener(() {}),
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: context.kpb.pageBg,
          appBar: AppBar(
            backgroundColor:
                Colors.black, // Keep video header black for cinematic feel
            elevation: 0,
            title: Text(
              controller.resolve(widget.course.title),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Player Area - always on black background
              Container(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: player,
                ),
              ),

              // Lesson Info
              Container(
                color: context.kpb.surfaceBg,
                padding: const EdgeInsets.all(KpbSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.resolve(currentLesson.title),
                      style: KpbTextStyles.headline
                          .copyWith(color: context.kpb.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'academy_player_session_progress'.trParams({
                        'current': '${_currentIndex + 1}',
                        'total': '${_lessons.length}',
                      }),
                      style: KpbTextStyles.bodySm
                          .copyWith(color: context.kpb.textSecondary),
                    ),
                  ],
                ),
              ),

              Divider(color: context.kpb.gray100, height: 1),

              // Lessons List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _lessons.length,
                  separatorBuilder: (_, __) => Divider(
                      color: context.kpb.gray100, height: 1, indent: 70),
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    final isCurrent = index == _currentIndex;
                    final activeColor = KpbColors.blue;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: KpbSpacing.lg, vertical: 4),
                      onTap: () => _onLessonTap(index),
                      tileColor: isCurrent
                          ? activeColor.withValues(alpha: 0.05)
                          : Colors.transparent,
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              isCurrent ? activeColor : context.kpb.surfaceBg,
                          borderRadius: KpbRadius.mdBr,
                          border: isCurrent
                              ? null
                              : Border.all(color: context.kpb.gray200),
                        ),
                        child: Center(
                          child: Icon(
                            isCurrent
                                ? Icons.play_arrow_rounded
                                : Icons.check_circle_outline_rounded,
                            color:
                                isCurrent ? Colors.white : context.kpb.gray400,
                            size: 24,
                          ),
                        ),
                      ),
                      title: Text(
                        controller.resolve(lesson.title),
                        style: TextStyle(
                          color:
                              isCurrent ? activeColor : context.kpb.textPrimary,
                          fontSize: 15,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${(lesson.durationSeconds / 60).floor()} min',
                        style: KpbTextStyles.caption
                            .copyWith(color: context.kpb.textMuted),
                      ),
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
