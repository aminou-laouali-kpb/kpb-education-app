part of '../home_screen.dart';

// En tête de l'accueil : la carte « prochaine étape » (élève) ou le héros de
// rôle (parent, partenaire, invité).

// ─────────────────────────────────────────────────────────────────────────────
// Héros de rôle — parent, partenaire, invité. Inchangé dans son propos : un
// titre, une phrase, UN appel à l'action propre au rôle.
// ─────────────────────────────────────────────────────────────────────────────
class _RoleHeroCard extends StatelessWidget {
  const _RoleHeroCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return _homeBlockPadding(
      Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: KpbRadius.mdBr,
          boxShadow: KpbShadow.blue,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                controller.isPartner
                    ? 'home_hero_title_partner'.tr
                    : controller.isParent
                        ? 'home_hero_title_parent'.tr
                        : 'home_hero_title_student'.tr,
                style: const TextStyle(
                  fontFamily: KpbTextStyles.headingFamily,
                  color: Colors.white,
                  fontSize: KpbFontSize.xl,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              'home_hero_subtitle_other'.tr,
              style: const TextStyle(
                color: KpbColors.textFaint,
                fontSize: KpbFontSize.sm,
                height: 1.4,
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            if (controller.isGuestMode)
              // L'invité est, dans l'immense majorité, un ÉTUDIANT qui
              // découvre l'app : « Devenir partenaire » lui parlait à côté.
              //
              // Test « Mes 10 bourses » OUVERT (drapeau serveur
              // `features.scholarshipMatch`) : « Trouve tes bourses (2 min) »
              // garde l'intention 24 h et passe par l'inscription ; l'élève
              // arrive sur le test à son premier accueil. FERMÉ : libellé sans
              // durée, vers l'onglet Bourses, dont le mur invité
              // (`scholarships_gate`) fait créer le compte.
              ListenableBuilder(
                listenable: RemoteFeatureFlags.instance.flagsVersion,
                builder: (context, _) {
                  final testOpen =
                      RemoteFeatureFlags.instance.scholarshipMatchEnabled;
                  return _HeroCta(
                    key: const ValueKey<String>('home-hero-guest-cta'),
                    label: testOpen
                        ? 'home_hero_cta_find_scholarships_test'.tr
                        : 'home_hero_cta_find_scholarships'.tr,
                    onTap: testOpen
                        ? () => unawaited(startScholarshipMatchAsGuest(
                              source: 'home_hero_scholarship_match',
                            ))
                        : () =>
                            controller.goToTab(StudentShellTab.scholarships),
                  );
                },
              )
            else
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
        ),
      ),
    );
  }
}

/// Bouton blanc des cartes sombres de l'accueil (48 dp de haut au moins).
class _HeroCta extends StatelessWidget {
  const _HeroCta({
    super.key,
    required this.label,
    required this.onTap,
    this.expand = false,
  });
  final String label;
  final VoidCallback onTap;

  /// Vrai : toute la largeur (carte « prochaine étape »).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.md + 2, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: KpbRadius.pillBr,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: KpbFontSize.md,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.actionPrimary,
                  ),
                ),
              ),
              const SizedBox(width: KpbSpacing.sm),
              const ExcludeSemantics(
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: KpbColors.actionPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// « Ta prochaine étape » — l'anneau du héros, « Mon plan » et « Parcours
// découverte » fusionnés : UNE progression (MyPlanEngine) et UNE action
// (resolveHomeNextStep, ordre documenté dans home_next_step.dart).
// ─────────────────────────────────────────────────────────────────────────────
class _NextStepCard extends StatefulWidget {
  const _NextStepCard({required this.controller, required this.step});
  final AppController controller;
  final HomeNextStep step;

  @override
  State<_NextStepCard> createState() => _NextStepCardState();
}

class _NextStepCardState extends State<_NextStepCard> {
  int? _loggedPercent;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final plan = MyPlanEngine.compute(
      profile: controller.profile,
      hasOrientationResult: controller.latestOrientationSession != null,
      cases: controller.cases,
    );
    final view = _stepView(context, widget.step);

    // Une mesure par pourcentage distinct (PostHog en dérive l'évolution).
    if (controller.profile != null && _loggedPercent != plan.percentRounded) {
      _loggedPercent = plan.percentRounded;
      unawaited(AnalyticsService.instance.logMyPlanProgress(
        percent: plan.percentRounded,
        nextStep: widget.step.kind.name,
      ));
    }

    return _homeBlockPadding(
      Container(
        key: ValueKey<String>('home-next-step-${widget.step.kind.name}'),
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
                if (controller.profile != null) ...[
                  _PlanRing(value: plan.percent),
                  const SizedBox(width: KpbSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'home_next_step_eyebrow'.tr,
                          style: const TextStyle(
                            color: KpbColors.actionOnDark,
                            fontSize: KpbFontSize.xs,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: KpbSpacing.xs),
                      Text(
                        view.label,
                        style: const TextStyle(
                          color: KpbColors.textFaint,
                          fontSize: KpbFontSize.xs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        view.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: KpbTextStyles.headingFamily,
                          color: Colors.white,
                          fontSize: KpbFontSize.lg,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (view.subtitle.isNotEmpty) ...[
              const SizedBox(height: KpbSpacing.sm),
              Text(
                view.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: KpbColors.textFaint,
                  fontSize: KpbFontSize.sm,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: KpbSpacing.md),
            _HeroCta(
              key: const ValueKey<String>('home-next-step-cta'),
              label: view.cta,
              onTap: view.onTap,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  _StepView _stepView(BuildContext context, HomeNextStep step) {
    final controller = widget.controller;
    switch (step.kind) {
      case HomeNextStepKind.caseAction:
        final c = step.studentCase!;
        return _StepView(
          label: 'home_next_step_label_action_required'.tr,
          title: switch (c.status) {
            CaseStatus.awaitingPayment =>
              'home_next_step_title_talk_advisor'.tr,
            CaseStatus.documentsNeeded =>
              'home_next_step_title_documents_to_send'.tr,
            _ => 'home_next_step_title_response_expected'.tr,
          },
          subtitle: controller.resolve(c.nextStepTitle),
          cta: 'home_next_step_cta_case'.tr,
          onTap: () => Get.to<void>(() => CaseDetailScreen(caseId: c.id)),
        );
      case HomeNextStepKind.followedClosingSoon:
        final urgent = step.urgent!;
        return _StepView(
          label: 'home_next_step_label_deadline'.tr,
          title: controller.resolve(urgent.scholarship.name),
          subtitle: scholarshipUrgencyLabel(urgent.urgency),
          cta: 'home_next_step_cta_scholarship'.tr,
          onTap: () => openScholarshipOrTab(
            scholarshipId: urgent.scholarship.id,
            fromCatalog: true,
          ),
        );
      case HomeNextStepKind.completeProfileTest:
        return _StepView(
          label: 'home_next_step_label_your_profile'.tr,
          title: 'home_next_step_title_complete_profile'.tr,
          subtitle: 'home_next_step_subtitle_profile_test'.tr,
          cta: 'home_next_step_cta_test'.tr,
          onTap: () => Get.to<void>(
            () => const ScholarshipMatchFlowScreen(source: 'home_next_step'),
          ),
        );
      case HomeNextStepKind.completeProfileOnboarding:
        final pct = ((controller.profile?.completionScore ?? 0) * 100).round();
        return _StepView(
          label: 'home_next_step_label_your_profile'.tr,
          title: 'home_next_step_title_complete_profile'.tr,
          subtitle: controller.onboardingSkipped
              ? 'home_next_step_subtitle_missing_info'.tr
              : 'home_profile_pct_notice'.trParams({'pct': '$pct'}),
          cta: 'home_next_step_cta_profile'.tr,
          onTap: () => Get.to<void>(() => const OnboardingScreen()),
        );
      case HomeNextStepKind.orientation:
        return _StepView(
          label: 'home_next_step_label_discovery'.tr,
          title: 'home_next_step_title_take_orientation'.tr,
          subtitle: 'home_next_step_subtitle_orientation'.tr,
          cta: 'home_next_step_cta_orientation'.tr,
          onTap: () => Get.to<void>(() => const OrientationScreen()),
        );
      case HomeNextStepKind.startCase:
        return _StepView(
          label: 'home_next_step_label_next_step'.tr,
          title: 'home_next_step_title_start_case'.tr,
          subtitle: 'home_next_step_subtitle_start_case'.tr,
          cta: 'home_next_step_cta_start_case'.tr,
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
      case HomeNextStepKind.explore:
        return _StepView(
          label: 'home_next_step_label_explore'.tr,
          title: 'home_next_step_title_discover_opportunities'.tr,
          subtitle: 'home_next_step_subtitle_explore'.tr,
          cta: 'home_next_step_cta_explore'.tr,
          onTap: () => Get.to<void>(() => const DestinationsScreen()),
        );
    }
  }
}

class _StepView {
  const _StepView({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });
  final String label;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;
}

/// L'anneau de progression du plan (fond navy). Une seule animation, coupée
/// avec le mouvement (réglage système, économiseur de données).
class _PlanRing extends StatelessWidget {
  const _PlanRing({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final motion = KpbMotion.of(context);
    final rounded = (target * 100).round();
    return Semantics(
      label: 'home_next_step_plan_a11y'.trParams({'value': '$rounded'}),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: motion.enabled ? 0 : target, end: target),
        duration: motion.reveal,
        curve: motion.curve,
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(v * 100).round()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: KpbFontSize.xl,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        // Légende visible : « /100 » ne disait pas de quoi est
                        // cette note (audit build 57, T4-29).
                        Text(
                          'home_plan_ring_label'.tr,
                          style: const TextStyle(
                            color: KpbColors.textOnDarkMuted,
                            fontSize: KpbFontSize.xs,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
