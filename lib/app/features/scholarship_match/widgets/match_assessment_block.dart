import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/app_controller.dart';
import '../../../core/models/scholarship_match.dart';
import '../../../core/services/scholarship_match_store.dart';
import '../../../core/ui/app_tokens.dart';
import '../match_format.dart';
import '../scholarship_match_actions.dart';
import '../scholarship_match_entry_card.dart';
import '../scholarship_match_results_screen.dart';
import 'match_result_card.dart';
import 'official_condition_expander.dart';

/// Le bloc d'évaluation de la fiche d'une bourse : la SEULE expérience
/// d'éligibilité par bourse de l'app (il remplace l'ancien questionnaire
/// « Suis-je éligible ? », que rien n'ouvrait plus).
///
/// - le dernier run « Mes 10 bourses » contient cette bourse : son statut
///   (compatible / à vérifier), les raisons servies par le serveur et les
///   points à vérifier avec « Voir la condition officielle » ;
/// - sinon, test ouvert : la carte du test (« Fais le test », ou le résumé du
///   run précédé d'une phrase qui dit que cette bourse n'y est pas ; invité :
///   l'invitation à créer un compte) ;
/// - drapeau fermé, parent, serveur qui a coupé le test : rien.
class ScholarshipMatchAssessmentBlock extends StatefulWidget {
  const ScholarshipMatchAssessmentBlock({
    super.key,
    required this.scholarshipId,
  });

  final String scholarshipId;

  @override
  State<ScholarshipMatchAssessmentBlock> createState() =>
      _ScholarshipMatchAssessmentBlockState();
}

class _ScholarshipMatchAssessmentBlockState
    extends State<ScholarshipMatchAssessmentBlock> {
  /// Le compte pour lequel le run a été demandé (un changement de compte
  /// redemande).
  String? _requestedFor;

  /// Relit le dernier run de ce compte (cache, puis au plus une requête par
  /// passage au premier plan). Jamais pendant un build.
  void _ensureLoaded(ScholarshipMatchEntryVariant variant) {
    if (variant == ScholarshipMatchEntryVariant.hidden ||
        variant == ScholarshipMatchEntryVariant.guest) {
      return;
    }
    final app = Get.find<AppController>();
    final userId = scholarshipMatchUserId(app);
    if (_requestedFor == userId) return;
    _requestedFor = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ScholarshipMatchStore.instance.loadState(
        client: app.apiClient,
        userId: userId,
        lang: scholarshipMatchLang(app),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScholarshipMatchListener(
      builder: (context, variant) {
        _ensureLoaded(variant);
        final store = ScholarshipMatchStore.instance;
        const entry = ScholarshipMatchEntryCard(source: 'scholarship_detail');
        switch (variant) {
          case ScholarshipMatchEntryVariant.hidden:
            return const SizedBox.shrink();
          case ScholarshipMatchEntryVariant.guest:
            return const _Spaced(child: entry);
          case ScholarshipMatchEntryVariant.noRun:
            // Run de ce compte pas encore relu du cache : rien plutôt qu'une
            // invitation démentie une frame plus tard.
            final app = Get.find<AppController>();
            if (store.userId != scholarshipMatchUserId(app)) {
              return const SizedBox.shrink();
            }
            return const _Spaced(child: entry);
          case ScholarshipMatchEntryVariant.hasRun:
          case ScholarshipMatchEntryVariant.stale:
            final run = store.latestRun;
            final item = run?.items.firstWhereOrNull(
              (candidate) => candidate.scholarshipId == widget.scholarshipId,
            );
            if (run == null || item == null) {
              return _Spaced(
                child: Column(
                  key: const ValueKey<String>('match-assessment-not-in-run'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'scholarship_match_assessment_not_in_run'.tr,
                      style: KpbTextStyles.bodySm.copyWith(
                        color: KpbColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.xs),
                    entry,
                  ],
                ),
              );
            }
            return _Spaced(
              child: _Assessment(
                item: item,
                date: run.createdAt ?? store.latestRunSyncedAt,
              ),
            );
        }
      },
    );
  }
}

class _Spaced extends StatelessWidget {
  const _Spaced({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: KpbSpacing.sm),
        child: child,
      );
}

class _Assessment extends StatelessWidget {
  const _Assessment({required this.item, required this.date});

  final MatchItem item;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final compatible = item.isCompatible;
    final available = item.available;
    final status = compatible
        ? 'scholarship_match_status_compatible'.tr
        : 'scholarship_match_status_to_verify'.tr;
    final date = this.date;
    return Container(
      key: ValueKey<String>('match-assessment-${item.scholarshipId}'),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: BorderRadius.circular(KpbRadius.md),
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.fact_check_outlined,
                  color: KpbColors.actionPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'scholarship_match_assessment_title'.tr,
                        style: KpbTextStyles.titleMd.copyWith(
                          color: KpbColors.brandNavy,
                        ),
                      ),
                    ),
                    if (date != null)
                      Text(
                        'scholarship_match_assessment_date'
                            .trParams({'date': matchDayMonth(date)}),
                        style: KpbTextStyles.caption.copyWith(
                          color: KpbColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          MatchPill(
            key: ValueKey<String>(
                'match-assessment-status-${item.scholarshipId}'),
            text: available ? status : 'scholarship_match_unavailable'.tr,
            semantics: available
                ? 'scholarship_match_status_a11y'.trParams({'status': status})
                : 'scholarship_match_unavailable'.tr,
            color: !available
                ? KpbColors.textSecondary
                : compatible
                    ? KpbColors.success
                    : KpbColors.warning,
            background: !available
                ? KpbColors.surfaceMuted
                : compatible
                    ? KpbColors.successLight
                    : KpbColors.warningLight,
          ),
          if (available) ...[
            if (item.reasons.isNotEmpty) const SizedBox(height: KpbSpacing.sm),
            for (final reason in item.reasons.take(3))
              MatchPoint(
                icon: Icons.check_circle_rounded,
                color: KpbColors.success,
                text: reason.label,
              ),
            for (final point in item.toVerify) ...[
              MatchPoint(
                icon: Icons.warning_amber_rounded,
                color: KpbColors.warning,
                text: point.label,
              ),
              if (point.official != null)
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: OfficialConditionExpander(official: point.official!),
                ),
            ],
          ],
          const SizedBox(height: KpbSpacing.xs),
          Text(
            'scholarship_match_disclaimer'.tr,
            style: KpbTextStyles.caption.copyWith(
              color: KpbColors.textSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('match-assessment-see-results'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Get.to<void>(
                () => const ScholarshipMatchResultsScreen(
                  source: 'scholarship_detail',
                ),
              ),
              child: Text('scholarship_match_assessment_see_results'.tr),
            ),
          ),
        ],
      ),
    );
  }
}
