import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_button.dart';
import '../../core/ui/components/kpb_error_state.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../premium/premium_screen.dart';
import 'academy_controller.dart';
import 'academy_player_screen.dart';

/// Un cours et son programme.
///
/// Réservé au Pass Karatou, il montre tout le programme mais n'ouvre que les
/// leçons d'aperçu à qui n'a pas de Pass actif. AUCUN prix, aucun verbe
/// d'achat ici : le Pass s'obtient hors de l'app, auprès d'un conseiller KPB
/// (`docs/pass-karatou.md`). Le seul renvoi va vers l'écran du Pass.
class AcademyCourseScreen extends StatefulWidget {
  const AcademyCourseScreen({super.key, required this.idOrSlug});

  final String idOrSlug;

  @override
  State<AcademyCourseScreen> createState() => _AcademyCourseScreenState();
}

class _AcademyCourseScreenState extends State<AcademyCourseScreen> {
  late final AcademyCourseController _course;

  @override
  void initState() {
    super.initState();
    _course = AcademyCourseController(
      apiClient: Get.find<AppController>().apiClient,
      idOrSlug: widget.idOrSlug,
    )..load();
  }

  @override
  void dispose() {
    _course.dispose();
    super.dispose();
  }

  void _openLesson(AcademyCourseDetail detail, AcademyLessonModel lesson) {
    if (!lesson.playable) {
      _showLockedSheet();
      return;
    }
    final playable = detail.playableLessons;
    Get.to(() => AcademyPlayerScreen(
          course: detail.course,
          lessons: playable,
          initialLessonIndex: playable.indexWhere((l) => l.id == lesson.id),
        ));
  }

  void _showLockedSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.kpb.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KpbRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KpbSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: KpbColors.gold, size: 32),
              const SizedBox(height: KpbSpacing.sm),
              Text('academy_lesson_locked_title'.tr,
                  style: KpbTextStyles.title
                      .copyWith(color: sheetContext.kpb.textPrimary)),
              const SizedBox(height: KpbSpacing.sm),
              Text('academy_lesson_locked_body'.tr,
                  style: KpbTextStyles.body
                      .copyWith(color: sheetContext.kpb.textSecondary)),
              const SizedBox(height: KpbSpacing.lg),
              KpbButton(
                key: const ValueKey('academy_locked_pass_cta'),
                label: 'academy_pass_discover_cta'.tr,
                fullWidth: true,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Get.to(() => const PremiumScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppController>();
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: _course,
        builder: (context, _) {
          final detail = _course.detail;
          if (_course.phase == AcademyPhase.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_course.phase == AcademyPhase.failed || detail == null) {
            return KpbErrorState(
              title: 'academy_load_error'.tr,
              onRetry: _course.load,
            );
          }
          final course = detail.course;
          final reserved = course.requiresPass && !detail.viewerHasPass;
          return RefreshIndicator(
            onRefresh: _course.load,
            child: ListView(
              padding: const EdgeInsets.all(KpbSpacing.page),
              children: [
                Text(app.resolve(course.title),
                    style: KpbTextStyles.headline
                        .copyWith(color: context.kpb.textPrimary)),
                const SizedBox(height: KpbSpacing.sm),
                Text(app.resolve(course.description),
                    style: KpbTextStyles.body
                        .copyWith(color: context.kpb.textSecondary)),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  'academy_lessons_count'.trParams({
                    'count': '${detail.lessons.length}',
                    'duration':
                        formatAcademyDuration(course.totalDurationSeconds),
                  }),
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textMuted),
                ),
                if (course.requiresPass) ...[
                  const SizedBox(height: KpbSpacing.md),
                  _PassBanner(
                    hasPass: detail.viewerHasPass,
                    onDiscover: () => Get.to(() => const PremiumScreen()),
                  ),
                ],
                const SizedBox(height: KpbSpacing.lg),
                Text('academy_program_title'.tr,
                    style: KpbTextStyles.titleMd
                        .copyWith(color: context.kpb.textPrimary)),
                const SizedBox(height: KpbSpacing.sm),
                for (final lesson in detail.lessons)
                  _LessonTile(
                    lesson: lesson,
                    title: app.resolve(lesson.title),
                    showFreeBadge: reserved && lesson.isFreePreview,
                    onTap: () => _openLesson(detail, lesson),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PassBanner extends StatelessWidget {
  const _PassBanner({required this.hasPass, required this.onDiscover});

  final bool hasPass;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(hasPass ? 'academy_pass_active' : 'academy_pass_banner'),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: hasPass ? context.kpb.successLight : context.kpb.goldLight,
        borderRadius: KpbRadius.mdBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasPass
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_outlined,
                color: hasPass ? KpbColors.success : KpbColors.gold,
              ),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Text(
                  hasPass
                      ? 'academy_pass_active'.tr
                      : 'academy_pass_banner_title'.tr,
                  style: KpbTextStyles.titleSm
                      .copyWith(color: context.kpb.textPrimary),
                ),
              ),
            ],
          ),
          if (!hasPass) ...[
            const SizedBox(height: KpbSpacing.sm),
            Text('academy_pass_banner_body'.tr,
                style: KpbTextStyles.bodySm
                    .copyWith(color: context.kpb.textSecondary)),
            const SizedBox(height: KpbSpacing.sm),
            TextButton(
              onPressed: onDiscover,
              child: Text('academy_pass_discover_cta'.tr),
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.title,
    required this.showFreeBadge,
    required this.onTap,
  });

  final AcademyLessonModel lesson;
  final String title;
  final bool showFreeBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final open = lesson.playable;
    return ListTile(
      key: ValueKey('academy_lesson_${lesson.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: open ? KpbColors.actionPrimary : context.kpb.mutedBg,
          borderRadius: KpbRadius.smBr,
        ),
        child: Icon(
          open ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
          color: open ? Colors.white : context.kpb.textMuted,
          semanticLabel: open ? null : 'academy_lesson_locked_title'.tr,
        ),
      ),
      title: Text(title,
          style: KpbTextStyles.label.copyWith(
              color:
                  open ? context.kpb.textPrimary : context.kpb.textSecondary)),
      subtitle: Text(
        showFreeBadge
            ? '${formatAcademyDuration(lesson.durationSeconds)} · ${'academy_lesson_free_badge'.tr}'
            : formatAcademyDuration(lesson.durationSeconds),
        style: KpbTextStyles.caption.copyWith(color: context.kpb.textMuted),
      ),
    );
  }
}
