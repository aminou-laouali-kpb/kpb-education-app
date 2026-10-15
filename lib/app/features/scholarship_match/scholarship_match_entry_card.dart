import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/scholarship_match_store.dart';
import '../../core/ui/app_tokens.dart';
import 'match_format.dart';
import 'scholarship_match_actions.dart';
import 'scholarship_match_flow_screen.dart';
import 'scholarship_match_results_screen.dart';

/// La carte d'entrée du test, dans l'onglet Bourses (à la place de la
/// promotion du guide). Cachée drapeau fermé et pour les comptes non élèves ;
/// [fallback] prend alors la place.
///
/// Variantes : pas de run, run (résumé), run périmé, invité.
class ScholarshipMatchEntryCard extends StatefulWidget {
  const ScholarshipMatchEntryCard({
    super.key,
    this.fallback = const SizedBox.shrink(),
    this.source = 'scholarships_tab',
  });

  final Widget fallback;

  /// D'où la carte est vue (analytique).
  final String source;

  /// Une mesure `scholarship_match_entry_viewed` par source et par
  /// processus.
  static final Set<String> _viewedSources = <String>{};

  @visibleForTesting
  static void resetViewedForTest() => _viewedSources.clear();

  @override
  State<ScholarshipMatchEntryCard> createState() =>
      _ScholarshipMatchEntryCardState();
}

class _ScholarshipMatchEntryCardState extends State<ScholarshipMatchEntryCard> {
  bool _requested = false;

  void _maybeLoad(ScholarshipMatchEntryVariant variant) {
    if (variant == ScholarshipMatchEntryVariant.hidden ||
        variant == ScholarshipMatchEntryVariant.guest) {
      return;
    }
    if (ScholarshipMatchEntryCard._viewedSources.add(widget.source)) {
      unawaited(AnalyticsService.instance
          .logScholarshipMatchEntryViewed(source: widget.source));
    }
    if (_requested) return;
    _requested = true;
    final app = Get.find<AppController>();
    // Une fois par passage au premier plan : le magasin garde la réponse.
    unawaited(ScholarshipMatchStore.instance.loadState(
      client: app.apiClient,
      userId: scholarshipMatchUserId(app),
      lang: scholarshipMatchLang(app),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ScholarshipMatchListener(
      builder: (context, variant) {
        // Le premier chargement part d'une frame plus tard : jamais un
        // notifyListeners pendant un build.
        if (!_requested &&
            variant != ScholarshipMatchEntryVariant.hidden &&
            variant != ScholarshipMatchEntryVariant.guest) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeLoad(variant);
          });
        }
        if (variant == ScholarshipMatchEntryVariant.hidden) {
          return widget.fallback;
        }
        return _EntryCardBody(variant: variant, source: widget.source);
      },
    );
  }
}

class _EntryCardBody extends StatelessWidget {
  const _EntryCardBody({required this.variant, required this.source});

  final ScholarshipMatchEntryVariant variant;
  final String source;

  void _openFlow() {
    Get.to<void>(
      () => ScholarshipMatchFlowScreen(source: source),
    );
  }

  void _openResults({bool refresh = false}) {
    Get.to<void>(
      () =>
          ScholarshipMatchResultsScreen(source: source, forceRefresh: refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ScholarshipMatchStore.instance;
    final run = store.latestRun;
    final String title;
    final String body;
    final List<Widget> actions;
    switch (variant) {
      case ScholarshipMatchEntryVariant.guest:
        title = 'scholarship_match_entry_title'.tr;
        body = 'scholarship_match_entry_guest_body'.tr;
        actions = [
          FilledButton(
            key: const ValueKey<String>('scholarship-match-entry-guest-cta'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => unawaited(startScholarshipMatchAsGuest()),
            child: Text('scholarship_match_entry_cta'.tr),
          ),
        ];
      case ScholarshipMatchEntryVariant.noRun:
        title = 'scholarship_match_entry_title'.tr;
        body = 'scholarship_match_entry_body'.tr;
        actions = [
          FilledButton(
            key: const ValueKey<String>('scholarship-match-entry-start'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _openFlow,
            child: Text('scholarship_match_entry_cta'.tr),
          ),
        ];
      case ScholarshipMatchEntryVariant.hasRun:
      case ScholarshipMatchEntryVariant.stale:
        title = run == null
            ? 'scholarship_match_entry_title'.tr
            : 'scholarship_match_entry_run_title'
                .trParams({'counts': matchCountsLabel(run)});
        final syncedAt = run?.createdAt ?? store.latestRunSyncedAt;
        body = syncedAt == null
            ? 'scholarship_match_entry_run_body_undated'.tr
            : 'scholarship_match_entry_run_body'
                .trParams({'date': matchDayMonth(syncedAt)});
        actions = [
          FilledButton(
            key: const ValueKey<String>('scholarship-match-entry-view'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _openResults,
            child: Text('scholarship_match_entry_view'.tr),
          ),
          if (variant == ScholarshipMatchEntryVariant.stale)
            OutlinedButton(
              key: const ValueKey<String>('scholarship-match-entry-update'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => _openResults(refresh: true),
              child: Text('scholarship_match_entry_update'.tr),
            ),
        ];
      case ScholarshipMatchEntryVariant.hidden:
        return const SizedBox.shrink();
    }

    return Container(
      key: ValueKey<String>('scholarship-match-entry-${variant.name}'),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        border: Border.all(
          color: KpbColors.actionPrimary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(KpbRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.fact_check_outlined,
                  color: KpbColors.actionPrimary,
                  size: 28,
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
                        title,
                        style: KpbTextStyles.titleMd.copyWith(
                          color: KpbColors.brandNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.xs),
                    Text(
                      body,
                      style: KpbTextStyles.bodySm.copyWith(
                        color: KpbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: KpbSpacing.sm,
            runSpacing: KpbSpacing.xs,
            children: actions,
          ),
        ],
      ),
    );
  }
}
