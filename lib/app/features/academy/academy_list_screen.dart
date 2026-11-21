import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_empty_state.dart';
import '../../core/ui/components/kpb_error_state.dart';
import '../../core/ui/components/kpb_network_image.dart';
import '../../core/ui/kpb_theme_ext.dart';
import 'academy_controller.dart';
import 'academy_course_screen.dart';

/// Les cours de langue (HSK, TOEFL…). Ouvert par le drapeau distant `academy`.
class AcademyListScreen extends StatefulWidget {
  const AcademyListScreen({super.key});

  @override
  State<AcademyListScreen> createState() => _AcademyListScreenState();
}

class _AcademyListScreenState extends State<AcademyListScreen> {
  late final AcademyCatalogController _catalog;

  @override
  void initState() {
    super.initState();
    _catalog =
        AcademyCatalogController(apiClient: Get.find<AppController>().apiClient)
          ..load();
  }

  @override
  void dispose() {
    _catalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppController>();
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(title: Text('academy_list_title'.tr)),
      body: ListenableBuilder(
        listenable: _catalog,
        builder: (context, _) {
          switch (_catalog.phase) {
            case AcademyPhase.loading:
              return const Center(child: CircularProgressIndicator());
            case AcademyPhase.failed:
              return KpbErrorState(
                title: 'academy_load_error'.tr,
                onRetry: _catalog.load,
              );
            case AcademyPhase.ready:
              if (_catalog.courses.isEmpty) {
                return KpbEmptyState(
                  icon: Icons.play_lesson_outlined,
                  title: 'academy_list_empty_title'.tr,
                  subtitle: 'academy_list_empty_body'.tr,
                );
              }
              return RefreshIndicator(
                onRefresh: _catalog.load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(KpbSpacing.page),
                  itemCount: _catalog.courses.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: KpbSpacing.md),
                  itemBuilder: (context, index) => _CourseCard(
                    course: _catalog.courses[index],
                    resolve: app.resolve,
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.resolve});

  final AcademyCourseModel course;
  final String Function(LocalizedText) resolve;

  @override
  Widget build(BuildContext context) {
    final cover = course.coverImageUrl;
    return Material(
      color: context.kpb.cardBg,
      borderRadius: KpbRadius.mdBr,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('academy_course_${course.id}'),
        onTap: () => Get.to(
            () => AcademyCourseScreen(idOrSlug: course.slug ?? course.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover != null && cover.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: KpbNetworkImage(imageUrl: cover, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(KpbSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resolve(course.title),
                      style: KpbTextStyles.title
                          .copyWith(color: context.kpb.textPrimary)),
                  const SizedBox(height: KpbSpacing.xs),
                  Text(
                    resolve(course.description),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: KpbTextStyles.bodySm
                        .copyWith(color: context.kpb.textSecondary),
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  Wrap(
                    spacing: KpbSpacing.sm,
                    runSpacing: KpbSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'academy_lessons_count'.trParams({
                          'count': '${course.lessonCount}',
                          'duration': formatAcademyDuration(
                              course.totalDurationSeconds),
                        }),
                        style: KpbTextStyles.caption
                            .copyWith(color: context.kpb.textMuted),
                      ),
                      if (course.requiresPass) _PassChip(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.sm, vertical: KpbSpacing.xs / 2),
      decoration: BoxDecoration(
        color: context.kpb.goldLight,
        borderRadius: KpbRadius.xsBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_outlined,
              size: 14, color: KpbColors.gold),
          const SizedBox(width: KpbSpacing.xs),
          Text('academy_pass_badge'.tr,
              style: KpbTextStyles.caption
                  .copyWith(color: context.kpb.textPrimary)),
        ],
      ),
    );
  }
}
