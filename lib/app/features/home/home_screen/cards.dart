part of '../home_screen.dart';

// « Tes échéances », preuve et partenaires, KPB Intelligence, et les cartes
// du catalogue (dossier actif, bourse).

// ─────────────────────────────────────────────────────────────────────────────
// « Tes échéances » — la date urgente et les dossiers actifs (élève).
// ─────────────────────────────────────────────────────────────────────────────
class _HomeDeadlinesSection extends StatelessWidget {
  const _HomeDeadlinesSection({
    required this.controller,
    required this.deadlines,
  });

  final AppController controller;
  final HomeDeadlines deadlines;

  @override
  Widget build(BuildContext context) {
    final urgent = deadlines.urgent;
    return _homeBlockPadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeSectionTitle(
            title: 'home_deadlines_title'.tr,
            actionKey: const ValueKey<String>('home-deadlines-see-all'),
            actionLabel: 'see_all'.tr,
            // Le calendrier : bourses suivies et dossiers ouverts, chaque
            // ligne vers SA fiche.
            onAction: () => Get.toNamed<void>(AppRoutes.deadlines),
          ),
          const SizedBox(height: KpbSpacing.sm),
          if (urgent != null)
            _UrgentDeadlineRow(controller: controller, urgent: urgent),
          for (final item in deadlines.cases) ...[
            if (urgent != null || item != deadlines.cases.first)
              const SizedBox(height: KpbSpacing.sm),
            _ActiveCaseCard(item: item, controller: controller),
          ],
        ],
      ),
    );
  }
}

/// Titre de section de l'accueil, son lien « Voir tout » à 48 dp.
class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: KpbTextStyles.title),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            key: actionKey,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// La bourse dont la clôture CONFIRMÉE est proche : la puce d'urgence est
/// celle de la liste et de la fiche (même calcul, même libellé).
class _UrgentDeadlineRow extends StatelessWidget {
  const _UrgentDeadlineRow({required this.controller, required this.urgent});

  final AppController controller;
  final HomeUrgentScholarship urgent;

  @override
  Widget build(BuildContext context) {
    final s = urgent.scholarship;
    final name = controller.resolve(s.name);
    final label = scholarshipUrgencyLabel(urgent.urgency);
    return KpbPressable(
      key: ValueKey<String>('home-deadline-scholarship-${s.id}'),
      semanticLabel: '$name, $label',
      // La fiche de la bourse dont la clôture approche (chantier I).
      onTap: () => openScholarshipOrTab(scholarshipId: s.id, fromCatalog: true),
      child: ExcludeSemantics(
        child: KpbCard(
          padding: const EdgeInsets.all(KpbSpacing.md),
          child: Row(
            children: [
              Text(_flag(s.countryId), style: KpbTextStyles.title),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: KpbTextStyles.titleMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KpbSpacing.xs),
                    ScholarshipUrgencyChip(urgency: urgent.urgency),
                  ],
                ),
              ),
              const SizedBox(width: KpbSpacing.sm),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: KpbColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Écoles partenaires et preuve d'impact. Deux appels réseau, deux replis :
// chacun disparaît (espace compris) quand son appel échoue ou ne rend rien
// — `/impact/stats` en 404 ne laisse plus de trou.
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTrustSection extends StatelessWidget {
  const _HomeTrustSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tel qu'il existe (le chantier J le refera) ; marges et espace du
        // bas portés seulement quand il a des partenaires à montrer.
        PartnersStrip(padding: EdgeInsets.only(bottom: KpbSpacing.xl)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
          child: HomeImpactProof(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPB Intelligence — l'UNIQUE entrée de l'accueil vers l'assistant (l'en-tête
// n'en porte plus). L'invité est envoyé vers le mur de création de compte.
// ─────────────────────────────────────────────────────────────────────────────
class _KpbIntelligenceCard extends StatelessWidget {
  const _KpbIntelligenceCard();

  @override
  Widget build(BuildContext context) {
    return _homeBlockPadding(
      KpbPressable(
        key: const ValueKey<String>('home-intelligence-entry'),
        semanticLabel:
            '${'home_intelligence_title'.tr}. ${'home_intelligence_body'.tr}',
        onTap: () => openAiChatIfConsented(context, Get.find<AppController>()),
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: KpbColors.brandNavy,
              borderRadius: KpbRadius.lgBr,
            ),
            padding: const EdgeInsets.all(KpbSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: KpbColors.actionPrimary,
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: const Icon(Icons.smart_toy_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: KpbSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home_intelligence_title'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.md,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'home_intelligence_body'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.sm,
                          height: 1.35,
                          color: KpbColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KpbSpacing.sm),
                const Icon(Icons.arrow_forward_rounded,
                    size: 20, color: KpbColors.actionOnDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Case Card — compact, status-driven
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveCaseCard extends StatelessWidget {
  const _ActiveCaseCard({required this.item, required this.controller});
  final StudentCase item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final si = _statusInfo(item.status);

    // Real document-completion ratio (no fabricated "X/10 steps" — only shown
    // when the case actually has document requests to count).
    final docs = item.documentRequests;
    final docsDone = docs.where((d) => d.isProvided).length;
    final docsPct = docs.isEmpty ? null : docsDone / docs.length;

    return KpbPressable(
      key: ValueKey<String>('home-deadline-case-${item.id}'),
      onTap: () => Get.to<void>(() => CaseDetailScreen(caseId: item.id)),
      child: KpbCard(
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: si.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.resolve(item.title),
                        style: KpbTextStyles.titleMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller.resolve(item.nextStepTitle),
                        style: KpbTextStyles.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: si.color,
                      borderRadius: KpbRadius.pillBr,
                    ),
                    child: Text(
                      si.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (docsPct != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: docsPct,
                        minHeight: 6,
                        backgroundColor: KpbColors.surfaceMuted,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            KpbColors.actionPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'home_case_documents_ratio'.trParams(
                          {'done': '$docsDone', 'total': '${docs.length}'}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({Color color, String label}) _statusInfo(CaseStatus s) {
    switch (s) {
      case CaseStatus.documentsNeeded:
        return (
          color: KpbColors.warning,
          label: 'case_status_documents_needed'.tr
        );
      case CaseStatus.awaitingPayment:
        return (
          color: KpbColors.error,
          label: 'case_status_awaiting_payment'.tr
        );
      case CaseStatus.awaitingStudent:
        return (
          color: KpbColors.error,
          label: 'case_status_awaiting_student'.tr
        );
      case CaseStatus.scheduled:
        return (color: KpbColors.success, label: 'case_status_scheduled'.tr);
      case CaseStatus.inProgress:
        return (
          color: KpbColors.actionPrimary,
          label: 'case_status_in_progress'.tr
        );
      case CaseStatus.underReview:
        return (color: KpbColors.warning, label: 'case_status_under_review'.tr);
      case CaseStatus.counselorAssigned:
        return (
          color: KpbColors.decorSky,
          label: 'case_status_counselor_assigned'.tr
        );
      case CaseStatus.submitted:
        return (color: KpbColors.decorSky, label: 'case_status_submitted'.tr);
      case CaseStatus.applicationSubmitted:
        return (
          color: KpbColors.actionPrimary,
          label: 'case_status_application_submitted'.tr
        );
      case CaseStatus.waitingDecision:
        return (
          color: KpbColors.warning,
          label: 'case_status_waiting_decision'.tr
        );
      default:
        return (
          color: KpbColors.textFaint,
          label: 'case_status_in_progress'.tr
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light Scholarship Card (liste neutre de l'accueil)
// ─────────────────────────────────────────────────────────────────────────────
class _ScholarshipCard extends StatelessWidget {
  const _ScholarshipCard({
    required this.scholarshipId,
    required this.name,
    required this.flag,
    required this.funding,
    required this.onTap,
  });

  final String scholarshipId;
  final String name;
  final String flag;
  final String funding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return KpbPressable(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: KpbTextStyles.titleLg),
                // Plus de palier « Très bon match » : il venait d'un score
                // client qui ne lisait aucune condition d'éligibilité.
                const Spacer(),
                FollowScholarshipButton(
                  scholarshipId: scholarshipId,
                  scholarshipTitle: name,
                  variant: FollowButtonVariant.icon,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: KpbTextStyles.titleSm.copyWith(
                color: KpbColors.brandNavy,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.payments_rounded,
                    size: 14, color: KpbColors.success),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    funding,
                    style: KpbTextStyles.labelSm
                        .copyWith(color: KpbColors.success),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
