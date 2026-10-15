part of '../home_screen.dart';

// Carte héros (jauge du profil) et prochaine étape.

/// Decomposes the real [UserProfile.completionScore] inputs into 5 named
/// groups so the gauge card can show sub-bars — same underlying booleans as
/// `completionScore`, just grouped for display. No fabricated categories
/// (no "letters"/"applications"/"community" sub-score — we don't track
/// those yet), so only groups we can actually compute are shown.
List<(String, double)> _gaugeBars(UserProfile? profile) {
  if (profile == null) return const [];
  double frac(List<bool> items) => items.where((e) => e).length / items.length;
  return [
    (
      'home_hero_profile_ring_label'.tr,
      frac([
        profile.fullName.trim().isNotEmpty,
        profile.email.trim().isNotEmpty,
        profile.phone.trim().isNotEmpty,
        profile.countryOfResidence.trim().isNotEmpty,
        profile.preferredLanguage.trim().isNotEmpty,
      ]),
    ),
    (
      'home_gauge_bar_level'.tr,
      frac([
        (profile.currentLevel ?? '').trim().isNotEmpty,
        (profile.targetLevel ?? '').trim().isNotEmpty,
        (profile.languageLevel ?? '').trim().isNotEmpty,
        (profile.gradeRange ?? '').trim().isNotEmpty ||
            (profile.bacSeries ?? '').trim().isNotEmpty,
      ]),
    ),
    (
      'home_gauge_bar_interests'.tr,
      frac([profile.fieldIds.isNotEmpty, profile.targetCountryIds.isNotEmpty]),
    ),
    (
      'home_gauge_bar_documents'.tr,
      frac([profile.availableDocuments.isNotEmpty]),
    ),
    (
      'home_gauge_bar_budget'.tr,
      frac([
        profile.annualTuitionBudgetEur != null &&
            profile.annualTuitionBudgetEur! > 0
      ]),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero / "Progress gauge" Card — dark navy readiness card + sub-score bars.
// The ring + sub-bars are the real profile.completionScore, decomposed.
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final progress = (profile?.completionScore ?? 0.0).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final showRing = controller.isStudent && pct < 100;
    final bars = showRing ? _gaugeBars(profile) : const [];

    return Container(
      decoration: BoxDecoration(
        color: KpbColors.brandNavy,
        borderRadius: KpbRadius.mdBr,
        boxShadow: KpbShadow.blue,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showRing) ...[
                KpbPressable(
                  onTap: () => controller.goToTab(StudentShellTab.profile),
                  child: _AnimatedRing(value: progress),
                ),
                const SizedBox(width: KpbSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showRing) ...[
                      Text(
                        'home_gauge_eyebrow'.tr,
                        style: const TextStyle(
                          color: KpbColors.decorSky,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      controller.isPartner
                          ? 'home_hero_title_partner'.tr
                          : controller.isParent
                              ? 'home_hero_title_parent'.tr
                              : 'home_hero_title_student'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.isStudent
                          ? 'home_hero_subtitle_student'.tr
                          : 'home_hero_subtitle_other'.tr,
                      style: const TextStyle(
                        color: KpbColors.textFaint,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (controller.isGuestMode) ...[
                      // L'invité est, dans l'immense majorité, un ÉTUDIANT qui
                      // découvre l'app : « Devenir partenaire » lui parlait à
                      // côté. On l'envoie vers l'onglet Bourses, où le mur
                      // invité (`scholarships_gate`) le fait créer son compte.
                      // Libellé volontairement sans durée ni nombre : il doit
                      // rester vrai que le test « Mes 10 bourses » soit ouvert
                      // ou non (drapeau serveur `features.scholarshipMatch`).
                      // L'accès partenaire reste au choix du type de compte, à
                      // l'inscription.
                      const SizedBox(height: 16),
                      _HeroCta(
                        key: const ValueKey<String>('home-hero-guest-cta'),
                        label: 'home_hero_cta_find_scholarships'.tr,
                        onTap: () =>
                            controller.goToTab(StudentShellTab.scholarships),
                      ),
                    ] else if (!controller.isStudent) ...[
                      const SizedBox(height: 16),
                      _HeroCta(
                        label: controller.isParent
                            ? 'home_hero_cta_consultation'.tr
                            : 'home_hero_cta_become_partner'.tr,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CaseComposerSheet(
                            caseType: CaseType.consultation,
                            title: 'home_case_title_book_appointment'.tr,
                            contextLabel: 'KPB Education',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bars.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (final b in bars)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: b == bars.last ? 0 : 6),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: b.$2,
                              minHeight: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  KpbColors.decorSky),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: KpbColors.textFaint,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Animated progress ring used in the gauge card (navy background).
class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        height: 76,
        width: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(KpbColors.decorSky),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(v * 100).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(
                      color: KpbColors.textFaint,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
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

class _HeroCta extends StatelessWidget {
  const _HeroCta({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: KpbRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KpbColors.actionPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                size: 16, color: KpbColors.actionPrimary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next Step Card — light, accent-driven next-best-action
// ─────────────────────────────────────────────────────────────────────────────
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.controller, required this.activeCases});
  final AppController controller;
  final List<StudentCase> activeCases;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final step = _resolveStep(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('home_design_discovery_title'.tr, style: KpbTextStyles.title),
        const SizedBox(height: 2),
        Text(
          'home_design_discovery_subtitle'.tr,
          style: const TextStyle(fontSize: 11, color: KpbColors.textMuted),
        ),
        const SizedBox(height: 12),
        KpbPressable(
          onTap: step.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: KpbRadius.lgBr,
              border: Border.all(color: step.iconColor.withValues(alpha: 0.25)),
              boxShadow: c.cardShadow,
            ),
            padding: const EdgeInsets.all(KpbSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: step.iconColor.withValues(alpha: 0.12),
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: Icon(step.icon, color: step.iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: step.iconColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: KpbColors.brandNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: KpbTextStyles.caption.copyWith(
                          color: KpbColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: step.iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _StepData _resolveStep(BuildContext context) {
    final profile = controller.profile;
    final hasOrientation = controller.latestOrientationSession != null;

    // Priority 1 — Case requires immediate action
    final urgentCase = activeCases.firstWhere(
      (c) =>
          c.status == CaseStatus.documentsNeeded ||
          c.status == CaseStatus.awaitingStudent ||
          c.status == CaseStatus.awaitingPayment,
      orElse: () => activeCases.isEmpty ? _placeholder : activeCases.first,
    );

    if (activeCases.isNotEmpty &&
        (urgentCase.status == CaseStatus.documentsNeeded ||
            urgentCase.status == CaseStatus.awaitingStudent ||
            urgentCase.status == CaseStatus.awaitingPayment)) {
      final isPayment = urgentCase.status == CaseStatus.awaitingPayment;
      final isDocs = urgentCase.status == CaseStatus.documentsNeeded;
      return _StepData(
        label: 'home_next_step_label_action_required'.tr,
        title: isPayment
            ? 'home_next_step_title_talk_advisor'.tr
            : isDocs
                ? 'home_next_step_title_documents_to_send'.tr
                : 'home_next_step_title_response_expected'.tr,
        subtitle: controller.resolve(urgentCase.nextStepTitle),
        icon: isPayment
            ? Icons.chat_rounded
            : isDocs
                ? Icons.upload_file_rounded
                : Icons.reply_rounded,
        iconColor: KpbColors.error,
        onTap: () => Get.to(() => CaseDetailScreen(caseId: urgentCase.id)),
      );
    }

    // Priority 2 — Profile incomplete / skipped onboarding
    if (controller.needsProfileCompletionBanner) {
      final pct = ((profile?.completionScore ?? 0) * 100).round();
      return _StepData(
        label: 'home_next_step_label_your_profile'.tr,
        title: 'home_next_step_title_complete_profile'.tr,
        subtitle: controller.onboardingSkipped
            ? 'home_next_step_subtitle_missing_info'.tr
            : 'home_profile_pct_notice'.trParams({'pct': '$pct'}),
        icon: Icons.tune_rounded,
        iconColor: KpbColors.actionPrimary,
        onTap: () => Get.to(() => const OnboardingScreen()),
      );
    }

    // Priority 3 — No orientation done
    if (!hasOrientation) {
      return _StepData(
        label: 'home_next_step_label_discovery'.tr,
        title: 'home_next_step_title_take_orientation'.tr,
        subtitle: 'home_next_step_subtitle_orientation'.tr,
        icon: Icons.psychology_rounded,
        iconColor: KpbColors.actionPrimary,
        onTap: () => Get.to(() => const OrientationScreen()),
      );
    }

    // Priority 4 — Orientation done, no active cases
    if (activeCases.isEmpty) {
      return _StepData(
        label: 'home_next_step_label_next_step'.tr,
        title: 'home_next_step_title_start_case'.tr,
        subtitle: 'home_next_step_subtitle_start_case'.tr,
        icon: Icons.rocket_launch_rounded,
        iconColor: KpbColors.success,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => CaseComposerSheet(
            caseType: CaseType.applicationSupport,
            title: 'home_case_title_new_case'.tr,
            contextLabel: 'KPB Education',
          ),
        ),
      );
    }

    // Default — everything in progress
    return _StepData(
      label: 'home_next_step_label_explore'.tr,
      title: 'home_next_step_title_discover_opportunities'.tr,
      subtitle: 'home_next_step_subtitle_explore'.tr,
      icon: Icons.explore_rounded,
      iconColor: KpbColors.decorSky,
      onTap: () => Get.to(() => const DestinationsScreen()),
    );
  }
}

// Placeholder for firstWhere default (never rendered)
final _placeholder = StudentCase(
  id: '',
  referenceCode: '',
  title: const LocalizedText(fr: '', en: ''),
  description: const LocalizedText(fr: '', en: ''),
  contextLabel: const LocalizedText(fr: '', en: ''),
  status: CaseStatus.draft,
  type: CaseType.consultation,
  preferredContactMethod: ContactMethod.inApp,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  nextStepTitle: const LocalizedText(fr: '', en: ''),
  nextStepDescription: const LocalizedText(fr: '', en: ''),
  timeline: const [],
  messages: const [],
  documentRequests: const [],
);

class _StepData {
  const _StepData({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
}
