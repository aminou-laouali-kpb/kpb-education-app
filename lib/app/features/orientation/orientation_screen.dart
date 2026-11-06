import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/orientation_engine.dart';
import '../../core/models/app_models.dart';
import '../../core/services/ai_content_report_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/components/ai_content_report_sheet.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/study_level.dart';
import '../cases/case_composer_sheet.dart';
import '../explore/country_detail_screen.dart';
import '../explore/program_detail_screen.dart';
import '../universities/widgets/program_catalog_card.dart';
import 'orientation_roadmap_screen.dart';

class OrientationScreen extends StatefulWidget {
  const OrientationScreen({super.key});

  @override
  State<OrientationScreen> createState() => _OrientationScreenState();
}

class _OrientationScreenState extends State<OrientationScreen> {
  final Map<String, List<String>> _answers = {};
  int _questionIndex = 0;
  bool _showResults = false;
  bool _isSubmitting = false;

  AppController get _ctrl => Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    final pending = _ctrl.pendingOrientationAnswers;
    if (pending.isNotEmpty) {
      _answers.addAll(pending);
      _questionIndex = _ctrl.pendingOrientationQuestionIndex;
    } else if (_ctrl.latestOrientationSession != null) {
      _showResults = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (_) {
        if (!_ctrl.isStudent) {
          return Scaffold(
            backgroundColor: context.kpb.pageBg,
            body: _ConsultativeView(controller: _ctrl),
          );
        }

        final questions = _ctrl.orientationQuestions;
        final latestResult = _ctrl.latestOrientationSession;
        final hasResult = latestResult != null;

        // Show results if test already done or user just finished
        if (_showResults && hasResult) {
          return Scaffold(
            backgroundColor: context.kpb.pageBg,
            body: _ResultsView(
              result: latestResult,
              controller: _ctrl,
              onRetake: () {
                _ctrl.clearOrientationProgress();
                setState(() {
                  _answers.clear();
                  _questionIndex = 0;
                  _showResults = false;
                });
              },
            ),
          );
        }

        if (_isSubmitting || _ctrl.isSubmittingOrientation) {
          return Scaffold(
            backgroundColor: context.kpb.pageBg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: KpbSpacing.md),
                  Text(
                    'analyzing_answers'.tr,
                    style: KpbTextStyles.body,
                  ),
                ],
              ),
            ),
          );
        }

        if (questions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // A persisted index can exceed the current question count (e.g. the
        // catalog changed since the answers were saved) — clamp before
        // indexing to avoid a RangeError crash.
        if (_questionIndex >= questions.length) {
          _questionIndex = questions.length - 1;
        } else if (_questionIndex < 0) {
          _questionIndex = 0;
        }

        final question = questions[_questionIndex];
        final selectedIds = _answers[question.id] ?? [];
        final progress = (_questionIndex + 1) / questions.length;

        return Scaffold(
          backgroundColor: context.kpb.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Progress header ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, KpbSpacing.md, KpbSpacing.pagePad, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_questionIndex > 0) {
                                setState(() => _questionIndex--);
                              } else {
                                Get.back();
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: context.kpb.cardBg,
                                borderRadius: KpbRadius.mdBr,
                                boxShadow: KpbShadow.card,
                              ),
                              child: Icon(
                                _questionIndex > 0
                                    ? Icons.arrow_back_rounded
                                    : Icons.close_rounded,
                                size: 18,
                                color: context.kpb.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'nav_orientation'.tr,
                                style: KpbTextStyles.titleMd,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: KpbColors.blue.withValues(alpha: 0.1),
                              borderRadius: KpbRadius.pillBr,
                            ),
                            child: Text(
                              '${_questionIndex + 1}/${questions.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: KpbColors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      ClipRRect(
                        borderRadius: KpbRadius.pillBr,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: context.kpb.gray100,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              KpbColors.blue),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Question card ───────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(KpbSpacing.pagePad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: KpbSpacing.md),
                        // Question number badge
                        KpbBadge(
                          label: 'orientation_question_number_badge'
                              .trParams({'n': '${_questionIndex + 1}'}),
                          color: KpbColors.blue,
                        ),
                        const SizedBox(height: KpbSpacing.sm),
                        // Question text
                        Text(
                          _ctrl.resolve(question.prompt),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.kpb.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        if (question.multiSelect) ...[
                          const SizedBox(height: 6),
                          Text(
                            'multiple_answers_allowed'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.kpb.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: KpbSpacing.lg),
                        // Options
                        ...question.options.map((option) {
                          final selected = selectedIds.contains(option.id);
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: KpbSpacing.sm),
                            child: _OptionCard(
                              label: _ctrl.resolve(option.label),
                              selected: selected,
                              onTap: () {
                                setState(() {
                                  final current = [...selectedIds];
                                  if (question.multiSelect) {
                                    if (selected) {
                                      current.remove(option.id);
                                    } else {
                                      current.add(option.id);
                                    }
                                  } else {
                                    current
                                      ..clear()
                                      ..add(option.id);
                                  }
                                  _answers[question.id] = current;
                                  _ctrl.saveOrientationProgress(
                                      _answers, _questionIndex);
                                });
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // ── Bottom CTA ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                      KpbSpacing.sm, KpbSpacing.pagePad, KpbSpacing.md),
                  decoration: BoxDecoration(
                    color: context.kpb.pageBg,
                    boxShadow: KpbShadow.float,
                  ),
                  child: FilledButton(
                    onPressed: selectedIds.isEmpty
                        ? null
                        : () {
                            if (_questionIndex < questions.length - 1) {
                              setState(() => _questionIndex++);
                              _ctrl.saveOrientationProgress(
                                  _answers, _questionIndex);
                            } else {
                              setState(() => _isSubmitting = true);
                              _ctrl.submitOrientation(_answers).then((_) {
                                if (!mounted) return;
                                setState(() {
                                  _isSubmitting = false;
                                  _showResults = true;
                                });
                              }).catchError((_) {
                                if (!mounted) return;
                                setState(() => _isSubmitting = false);
                              });
                            }
                          },
                    child: Text(
                      _questionIndex < questions.length - 1
                          ? 'orientation_next_button'.tr
                          : 'orientation_see_results_button'.tr,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option card (styled answer option)
// ─────────────────────────────────────────────────────────────────────────────
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? KpbColors.blue : context.kpb.cardBg,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(
            color: selected ? KpbColors.blue : context.kpb.gray100,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? KpbShadow.soft : KpbShadow.card,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? Colors.white : KpbColors.bgMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : context.kpb.gray200,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: KpbColors.blue)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.kpb.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results view
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsView extends StatefulWidget {
  const _ResultsView({
    required this.result,
    required this.controller,
    required this.onRetake,
  });

  final dynamic result;
  final AppController controller;
  final VoidCallback onRetake;

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  late final List<_Confetti> _particles;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _particles = _buildParticles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      KpbHaptics.success();
      _confetti.forward();
    });
  }

  List<_Confetti> _buildParticles() {
    final rnd = Random(7);
    const palette = [
      KpbColors.blue,
      KpbColors.sky,
      KpbColors.gold,
      KpbColors.success,
      KpbColors.blueMid,
    ];
    return List.generate(46, (i) {
      final angle = -pi / 2 + (rnd.nextDouble() - 0.5) * (pi * 0.95);
      return _Confetti(
        angle: angle,
        speed: 0.45 + rnd.nextDouble() * 0.85,
        color: palette[i % palette.length],
        size: 6 + rnd.nextDouble() * 8,
        rot: rnd.nextDouble() * pi,
        rotSpeed: (rnd.nextDouble() - 0.5) * 9,
      );
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    // A match percentage can never exceed 100, so never trust `rec.score` as a
    // percentage: the REST backend (and any session persisted by an older
    // build) still stores raw questionnaire points multiplied by 10, which is
    // how a card ended up reading "160 %". The percentage is recomputed here
    // from the stored answers with the same engine that scores an offline
    // session, so every source lands on one normalised scale; `rec.score` is a
    // clamped last resort for a session whose answers we cannot re-score.
    final percentByField = OrientationEngine.matchPercentByField(
      answers: Map<String, List<String>>.from(
        widget.result.answers as Map,
      ),
      questions: controller.orientationQuestions,
    );
    int scoreOf(dynamic rec) =>
        percentByField[rec.fieldId as String] ??
        (rec.score as int).clamp(0, 100);

    // Re-rank on the normalised percentage: the backend orders on AI resilience
    // before the score, which could otherwise put the "best match" badge on a
    // card showing a lower percentage than the one below it.
    final recs = List<dynamic>.from(widget.result.recommendations as List)
      ..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    final topScore = recs.isNotEmpty ? scoreOf(recs.first) : 0;
    final topField =
        recs.isNotEmpty ? controller.fieldByIdOrNull(recs.first.fieldId) : null;

    // Sprint 4 — connect the result to concrete formations: programs in the
    // top recommended fields, best-match first, with a profile-aware fallback.
    final topFieldIds = recs.take(2).map((r) => r.fieldId as String).toSet();
    final matchedPrograms = () {
      final byField = controller.programs
          .where((p) => topFieldIds.contains(p.fieldId))
          .toList()
        ..sort((a, b) =>
            controller.programMatch(b).compareTo(controller.programMatch(a)));
      final picked = byField.take(6).toList();
      return picked.isNotEmpty
          ? picked
          : controller.recommendedPrograms.take(6).toList();
    }();

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Celebratory hero ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _ResultsHero(
                  controller: controller,
                  topScore: topScore,
                  topFieldName: topField != null
                      ? controller.resolve(topField.name)
                      : null,
                ),
              ),

              // ── Recommendations (staggered reveal) ─────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad, KpbSpacing.lg, KpbSpacing.pagePad, 0),
                sliver: SliverList.separated(
                  itemCount: recs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: KpbSpacing.md),
                  itemBuilder: (ctx, i) {
                    final rec = recs[i];
                    final field = controller.fieldByIdOrNull(rec.fieldId);
                    if (field == null) return const SizedBox.shrink();
                    final countries = (rec.relatedCountryIds as List<String>)
                        .map(controller.countryByIdOrNull)
                        .whereType<CountryModel>()
                        .take(3)
                        .toList();
                    final scholarships =
                        (rec.relatedScholarshipIds as List<String>)
                            .map(controller.scholarshipByIdOrNull)
                            .whereType<ScholarshipModel>()
                            .take(3)
                            .toList();
                    return StaggeredSlide(
                      index: i,
                      delayMs: 130,
                      child: _RecommendationCard(
                        rec: rec,
                        score: scoreOf(rec),
                        field: field,
                        countries: countries,
                        scholarships: scholarships,
                        controller: controller,
                        isBest: i == 0,
                        context: ctx,
                        sourceReference: '${widget.result.id}:${rec.fieldId}',
                      ),
                    );
                  },
                ),
              ),

              // ── Matched formations (Sprint 4) ──────────────────────────
              if (matchedPrograms.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, KpbSpacing.xl, KpbSpacing.pagePad, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'orientation_matched_programs_title'.tr,
                          style: KpbTextStyles.titleLg
                              .copyWith(color: context.kpb.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topField != null
                              ? 'orientation_matched_programs_subtitle_field'
                                  .trParams({
                                  'field': controller.resolve(topField.name)
                                })
                              : 'orientation_matched_programs_subtitle_generic'
                                  .tr,
                          style: KpbTextStyles.bodySm
                              .copyWith(color: context.kpb.textSecondary),
                        ),
                        const SizedBox(height: KpbSpacing.md),
                        ...matchedPrograms.map((program) {
                          final institution = controller
                              .institutionByIdOrNull(program.institutionId);
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: KpbSpacing.sm),
                            child: ProgramCatalogCard(
                              name: controller.resolve(program.name),
                              institution: institution != null
                                  ? controller.resolve(institution.name)
                                  : null,
                              level: programLevelLabel(
                                  controller.resolve(program.level)),
                              tuition: controller.resolve(program.tuition),
                              language: controller.resolve(program.language),
                              duration: controller.resolve(program.duration),
                              flag: countryFlag(program.countryId),
                              saved: controller.isSaved(
                                  SavedItemType.program, program.id),
                              isPartner: institution?.isPartner ?? false,
                              onSave: () => controller.toggleSaved(
                                  SavedItemType.program, program.id),
                              onTap: () => Get.to(() =>
                                  ProgramDetailScreen(programId: program.id)),
                              intake: ProgramIntakeLine(
                                program: program,
                                institution: institution,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              // ── Action buttons ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                      KpbSpacing.xl, KpbSpacing.pagePad, KpbSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Primary: jump straight to the schools for the top match
                      FilledButton.icon(
                        icon: const Icon(Icons.school_rounded, size: 18),
                        label: Text('see_schools'.tr),
                        onPressed: () {
                          final topFieldId = recs.isNotEmpty
                              ? recs.first.fieldId as String
                              : null;
                          Get.back();
                          controller.goToUniversitiesForField(topFieldId);
                        },
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      // Sprint 5 — a dated parcours toward the top match.
                      OutlinedButton.icon(
                        icon: const Icon(Icons.timeline_rounded, size: 18),
                        label: Text('my_application_journey'.tr),
                        onPressed: () {
                          final topProgram = matchedPrograms.isNotEmpty
                              ? matchedPrograms.first
                              : null;
                          Get.to(() => OrientationRoadmapScreen(
                                fieldLabel: topField != null
                                    ? controller.resolve(topField.name)
                                    : 'orientation_your_results_fallback'.tr,
                                programId: topProgram?.id,
                                countryId: topProgram?.countryId,
                              ));
                        },
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.explore_rounded, size: 18),
                        label: Text('explore_my_results'.tr),
                        onPressed: () {
                          Get.back();
                          controller.goToTab(StudentShellTab.universities);
                        },
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      // Secondary: open a support case
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: Text('start_a_case'.tr),
                        onPressed: () => showModalBottomSheet<void>(
                          context: Get.context!,
                          isScrollControlled: true,
                          builder: (_) => CaseComposerSheet(
                            caseType: CaseType.applicationSupport,
                            title: 'case_application_title'.tr,
                            contextLabel: 'orientation_case_context_label'.tr,
                          ),
                        ),
                      ),
                      const SizedBox(height: KpbSpacing.md),
                      // Tertiary: retake
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('retake_test'.tr),
                        onPressed: widget.onRetake,
                        style: TextButton.styleFrom(
                          foregroundColor: context.kpb.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Confetti overlay (bursts once over the hero) ───────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (_, __) {
                  if (_confetti.value == 0 || _confetti.isDismissed) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _ConfettiPainter(
                      progress: _confetti.value,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Celebratory results hero — animated medallion + count-up top match
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsHero extends StatelessWidget {
  const _ResultsHero({
    required this.controller,
    required this.topScore,
    required this.topFieldName,
  });

  final AppController controller;
  final int topScore;
  final String? topFieldName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: KpbColors.heroGradient),
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        MediaQuery.of(context).padding.top + KpbSpacing.lg,
        KpbSpacing.pagePad,
        KpbSpacing.xl,
      ),
      child: Column(
        children: [
          // Trophy medallion that springs in
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5), width: 2),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: KpbColors.gold, size: 42),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'orientation_results_congrats'.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'orientation_results_intro'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (topFieldName != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: KpbRadius.lgBr,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: topScore.toDouble()),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutExpo,
                    builder: (_, v, __) => Text(
                      '${v.round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 34,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'orientation_best_match_label'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topFieldName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dependency-free confetti burst
// ─────────────────────────────────────────────────────────────────────────────
class _Confetti {
  const _Confetti({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rot,
    required this.rotSpeed,
  });
  final double angle, speed, size, rot, rotSpeed;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});
  final double progress;
  final List<_Confetti> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.22);
    final t = progress;
    for (final p in particles) {
      final reach = size.width * 0.62 * p.speed;
      final dx = cos(p.angle) * reach * t;
      final dy = sin(p.angle) * reach * t + (size.height * 0.95) * t * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.rot + p.rotSpeed * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendation card
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.rec,
    required this.score,
    required this.field,
    required this.countries,
    required this.scholarships,
    required this.controller,
    required this.isBest,
    required this.context,
    required this.sourceReference,
  });

  final dynamic rec;

  /// Normalised match percentage in `[0, 100]` — see `scoreOf` in
  /// `_ResultsViewState.build`. Never read `rec.score` here: it may still hold
  /// raw questionnaire points.
  final int score;
  final FieldModel field;
  final List<CountryModel> countries;
  final List<ScholarshipModel> scholarships;
  final AppController controller;
  final bool isBest;
  final BuildContext context;
  final String sourceReference;

  @override
  Widget build(BuildContext ctx) {
    final accentColor = field.accentColor;
    final saved = controller.isSaved(SavedItemType.field, field.id);

    return KpbCard(
      border: isBest
          ? Border.all(color: KpbColors.blue.withValues(alpha: 0.3), width: 2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Field header ────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: KpbRadius.lgBr,
                ),
                child: Center(
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBest)
                      KpbBadge(
                          label: 'orientation_best_match_badge'.tr,
                          color: KpbColors.blue),
                    if (isBest) const SizedBox(height: 4),
                    if (rec.iaResilience == 'high')
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: KpbBadge(
                          label: 'orientation_ai_resilient_badge'.tr,
                          color: KpbColors.success,
                        ),
                      ),
                    Text(controller.resolve(field.name),
                        style: KpbTextStyles.title),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'a11y_save'.tr,
                child: GestureDetector(
                  onTap: () =>
                      controller.toggleSaved(SavedItemType.field, field.id),
                  child: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: saved ? KpbColors.blue : context.kpb.gray300,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),

          // ── Match bar ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: KpbRadius.pillBr,
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.kpb.gray100,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: KpbSpacing.md),

          // ── Why it fits ──────────────────────────────────────────────
          Text(
            'orientation_why_it_fits_label'.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.kpb.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            controller.resolve(rec.explanation),
            style: KpbTextStyles.body,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey('orientation_report_ai_output_${field.id}'),
              onPressed: () => showAiContentReportSheet(
                context: ctx,
                surface: AiContentSurface.orientation,
                generatedText: controller.resolve(rec.explanation),
                sourceReference: sourceReference,
              ),
              icon: const Icon(Icons.flag_outlined, size: 14),
              label: Text('ai_report_action'.tr),
              style: TextButton.styleFrom(
                foregroundColor: context.kpb.textMuted,
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          if ((rec.jobs as List<String>).isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.md),
            Text(
              'target_careers'.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (rec.jobs as List<String>).map((job) {
                return KpbBadge(label: job, color: accentColor);
              }).toList(),
            ),
          ],
          if (field.iaResilience.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.sm),
            _IaResilienceChip(level: field.iaResilience),
          ],
          const SizedBox(height: KpbSpacing.md),

          // ── Countries ────────────────────────────────────────────────
          if (countries.isNotEmpty) ...[
            Text(
              'recommended_countries'.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: countries.map<Widget>((country) {
                return GestureDetector(
                  onTap: () =>
                      Get.to(() => CountryDetailScreen(countryId: country.id)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.kpb.surfaceBg,
                      borderRadius: KpbRadius.pillBr,
                    ),
                    child: Text(
                      controller.resolve(country.name),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.kpb.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: KpbSpacing.md),
          ],

          // ── Scholarships ─────────────────────────────────────────────
          if (scholarships.isNotEmpty) ...[
            Text(
              'orientation_available_scholarships_label'.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...scholarships.map<Widget>(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_outlined,
                        size: 14, color: KpbColors.gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        controller.resolve(s.name),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.kpb.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
          ],

          const KpbDivider(),
          const SizedBox(height: KpbSpacing.sm),

          // ── CTAs ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    controller.goToUniversitiesForField(field.id);
                    Get.back();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text('see_schools'.tr),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CaseComposerSheet(
                      caseType: CaseType.consultation,
                      title: controller.resolve(field.name),
                      contextLabel: controller.resolve(field.name),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text('get_support'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Consultative view (non-student)
// ─────────────────────────────────────────────────────────────────────────────
class _ConsultativeView extends StatelessWidget {
  const _ConsultativeView({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Pinned Header ──────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          floating: false,
          backgroundColor: KpbColors.navy,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'a11y_back'.tr,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
            ),
          ),
          title: Text(
            'nav_orientation'.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // ── Content header ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
            ),
            padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                KpbSpacing.sm, KpbSpacing.pagePad, KpbSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('nav_orientation'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 8),
                Text(
                  controller.isParent
                      ? 'home_for_parent'.tr
                      : 'home_for_partner'.tr,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(KpbSpacing.pagePad),
            child: KpbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: KpbColors.blue.withValues(alpha: 0.1),
                      borderRadius: KpbRadius.mdBr,
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: KpbColors.blue, size: 26),
                  ),
                  const SizedBox(height: KpbSpacing.md),
                  Text(
                    controller.isParent
                        ? 'parent_support'.tr
                        : 'partner_redirect'.tr,
                    style: KpbTextStyles.body,
                  ),
                  const SizedBox(height: KpbSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text('book_consultation'.tr),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      // Titre et contexte traduits : le dossier partait avec
                      // un titre anglais visible par l'étudiant.
                      builder: (_) => CaseComposerSheet(
                        caseType: CaseType.consultation,
                        title: 'orientation_consultation_case_title'.tr,
                        contextLabel:
                            'orientation_consultation_case_context'.tr,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sprint 7 — a "future-proof career" badge derived from a field's AI-resilience.
/// Reassures students (and parents) that the recommended path holds up against AI.
class _IaResilienceChip extends StatelessWidget {
  const _IaResilienceChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (level) {
      'high' => (
          KpbColors.success,
          Icons.eco_rounded,
          'orientation_ia_resilience_high'.tr,
        ),
      'medium' => (
          KpbColors.warning,
          Icons.trending_up_rounded,
          'orientation_ia_resilience_medium'.tr,
        ),
      _ => (
          context.kpb.textSecondary,
          Icons.info_outline_rounded,
          'orientation_ia_resilience_low'.tr,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KpbRadius.pillBr,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
