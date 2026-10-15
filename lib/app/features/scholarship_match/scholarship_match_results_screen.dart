import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/scholarship_match.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/scholarship_match_store.dart';
import '../../core/services/share_card_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/share_link.dart';
import '../scholarships/live_scholarships_screen.dart';
import '../scholarships/widgets/follow_push_primer.dart';
import 'match_format.dart';
import 'scholarship_match_actions.dart';
import 'scholarship_match_flow_controller.dart';
import 'scholarship_match_flow_screen.dart';
import 'widgets/excluded_summary.dart';
import 'widgets/match_result_card.dart';

/// Les résultats du test (`/scholarship-match`).
///
/// États honnêtes : le nombre RÉEL (jamais une liste gonflée), « Aucune
/// compatible » quand c'est vrai, le texte de niveau servi par le serveur
/// (« 1 bourse doctorale… »), le run hors ligne daté, « Plus disponible »,
/// et un run périmé relancé UNE fois à l'ouverture (jamais au rendu d'une
/// carte), avec un toast des différences.
class ScholarshipMatchResultsScreen extends StatefulWidget {
  const ScholarshipMatchResultsScreen({
    super.key,
    this.source = 'unknown',
    this.initialDiff,
    this.forceRefresh = false,
    this.now,
  });

  final String source;

  /// Les différences du run qui vient d'être calculé (toast à l'ouverture).
  final MatchRunDiff? initialDiff;

  /// « Mettre à jour » de la carte : relance même si le run n'est pas
  /// déclaré périmé.
  final bool forceRefresh;

  /// Horloge injectée (tests).
  final DateTime? now;

  @override
  State<ScholarshipMatchResultsScreen> createState() =>
      _ScholarshipMatchResultsScreenState();
}

class _ScholarshipMatchResultsScreenState
    extends State<ScholarshipMatchResultsScreen> {
  final _store = ScholarshipMatchStore.instance;
  late final AppController _app = Get.find<AppController>();
  final _shareKey = GlobalKey();
  bool _rerunning = false;
  bool _needsReview = false;
  bool _successLab = false;
  bool? _alertsOverride;
  bool _alertsSaving = false;
  bool _autoRerunDone = false;

  String get _userId => scholarshipMatchUserId(_app);
  String get _lang => scholarshipMatchLang(_app);
  DateTime get _now => widget.now ?? DateTime.now();

  bool get _online => !_store.offline && ConnectivityService.instance.isOnline;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final diff = widget.initialDiff;
      if (diff != null) _showDiff(diff);
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool force = false}) async {
    final variant = scholarshipMatchEntryVariant(_app);
    if (variant == ScholarshipMatchEntryVariant.hidden ||
        variant == ScholarshipMatchEntryVariant.guest) {
      return;
    }
    await _store.loadState(
      client: _app.apiClient,
      userId: _userId,
      lang: _lang,
      force: force,
    );
    if (!mounted) return;
    unawaited(_refreshSuccessLab());
    final run = _store.latestRun;
    final shouldRefresh = widget.forceRefresh || _store.isStale;
    if (!_autoRerunDone && run != null && shouldRefresh && _online) {
      _autoRerunDone = true;
      unawaited(AnalyticsService.instance.logScholarshipMatchRerun(
        reason: widget.forceRefresh ? 'manual' : 'stale',
      ));
      await _rerun(trigger: 'stale_refresh');
    }
  }

  Future<void> _refreshSuccessLab() async {
    final enabled = await scholarshipMatchSuccessLabAccess(_app);
    if (mounted && enabled != _successLab) {
      setState(() => _successLab = enabled);
    }
  }

  Future<void> _rerun({required String trigger}) async {
    if (_rerunning) return;
    setState(() => _rerunning = true);
    final outcome = await _store.createRun(
      client: _app.apiClient,
      userId: _userId,
      lang: _lang,
      trigger: trigger,
    );
    if (!mounted) return;
    setState(() => _rerunning = false);
    switch (outcome) {
      case MatchRunSucceeded(:final diff):
        setState(() => _needsReview = false);
        _showDiff(diff);
      case MatchRunNeedsAnswers():
        // Une valeur a changé sans être confirmée : on garde l'ancien run
        // affiché et on invite à vérifier.
        setState(() => _needsReview = true);
      case MatchRunFailed(:final failure):
        unawaited(AnalyticsService.instance
            .logScholarshipMatchFailed(reason: failure.name));
        if (failure != ScholarshipMatchFailure.disabled &&
            failure != ScholarshipMatchFailure.forbidden) {
          KpbToast.error(
            scholarshipMatchFailureMessage(failure),
            context: context,
            action: KpbToastAction(
              label: 'retry'.tr,
              onPressed: () => unawaited(_rerun(trigger: trigger)),
            ),
          );
        }
    }
  }

  void _showDiff(MatchRunDiff diff) {
    if (diff.isEmpty) return;
    final parts = <String>[
      if (diff.addedIds.isNotEmpty)
        diff.addedIds.length == 1
            ? 'scholarship_match_diff_added_one'.tr
            : 'scholarship_match_diff_added'
                .trParams({'count': '${diff.addedIds.length}'}),
      if (diff.removedIds.isNotEmpty)
        diff.removedIds.length == 1
            ? 'scholarship_match_diff_removed_one'.tr
            : 'scholarship_match_diff_removed'
                .trParams({'count': '${diff.removedIds.length}'}),
    ];
    KpbToast.info(parts.join(' · '), context: context);
  }

  Future<void> _openFlow(MatchFlowMode mode) async {
    final diff = await Get.to<MatchRunDiff>(
      () => ScholarshipMatchFlowScreen(
        mode: mode,
        source: 'results',
        returnToResults: true,
      ),
    );
    if (diff != null && mounted) {
      setState(() => _needsReview = false);
      _showDiff(diff);
    }
  }

  void _openDetail(MatchItem item) {
    unawaited(AnalyticsService.instance.logScholarshipMatchResultOpened(
      itemId: item.scholarshipId,
      rank: item.rank,
      status: item.isCompatible ? 'eligible' : 'to_verify',
    ));
    unawaited(Get.toNamed<void>(
      AppRoutes.scholarshipDetailPath(item.scholarshipId),
    ));
  }

  /// « Suivre les N compatibles » : `ensureSaved` par bourse (une bourse déjà
  /// suivie reste suivie) + UNE requête groupée ; « Annuler » ne retire que
  /// celles que ce geste a ajoutées.
  Future<void> _followAll(MatchRun run) async {
    final ids = run.followableCompatibleIds;
    if (ids.isEmpty) return;
    final added = _app.followScholarships(ids);
    for (final item in run.items.where((i) => ids.contains(i.scholarshipId))) {
      unawaited(AnalyticsService.instance.logScholarshipMatchFollow(
        itemId: item.scholarshipId,
        rank: item.rank,
        bulk: true,
      ));
    }
    unawaited(KpbHaptics.success());
    KpbToast.success(
      'scholarship_match_follow_all_done'.trParams({'count': '${ids.length}'}),
      context: context,
      action: added.isEmpty
          ? null
          : KpbToastAction(
              label: 'followed_undo'.tr,
              onPressed: () {
                for (final id in added) {
                  _app.setScholarshipFollow(id, following: false);
                }
              },
            ),
    );
    await FollowPushPrimer.maybePrime(context);
  }

  Future<void> _setAlerts(bool enabled) async {
    if (_alertsSaving) return;
    final previous = _store.alertsOptIn;
    setState(() {
      _alertsOverride = enabled;
      _alertsSaving = true;
    });
    final confirmed = await _store.setAlerts(
      client: _app.apiClient,
      enabled: enabled,
    );
    if (!mounted) return;
    setState(() {
      _alertsSaving = false;
      _alertsOverride = confirmed ?? previous;
    });
    if (confirmed == null) {
      KpbToast.error('scholarship_match_alerts_error'.tr, context: context);
    } else {
      unawaited(AnalyticsService.instance
          .logScholarshipMatchAlertsToggled(enabled: confirmed));
    }
  }

  Future<void> _share(MatchRun run) async {
    final names = run.items
        .where((i) => i.available)
        .map((i) => '• ${i.name}')
        .join('\n');
    final link = buildInviteLink(
      source: ShareSource.match,
      deepPath: AppRoutes.scholarshipMatch,
    );
    await ShareCardService.instance.shareBoundary(
      boundaryKey: _shareKey,
      text: 'scholarship_match_share_text'
          .trParams({'list': names, 'link': link}),
      source: ShareSource.match,
    );
  }

  void _talkToAdvisor({String source = 'scholarship_match_results'}) {
    unawaited(openScholarshipMatchWhatsApp(
      prefill: 'scholarship_match_advisor_prefill'.tr,
      source: source,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ScholarshipMatchListener(
      builder: (context, variant) {
        if (variant == ScholarshipMatchEntryVariant.hidden ||
            variant == ScholarshipMatchEntryVariant.guest) {
          // Drapeau fermé, invité, parent : le lien profond retombe sur
          // l'onglet Bourses.
          return const LiveScholarshipsScreen();
        }
        return Scaffold(
          backgroundColor: KpbColors.canvas,
          appBar: AppBar(
            backgroundColor: KpbColors.canvas,
            surfaceTintColor: KpbColors.canvas,
            elevation: 0,
            title: Text(
              'scholarship_match_results_title'.tr,
              style: KpbTextStyles.titleMd,
            ),
          ),
          body: _body(),
        );
      },
    );
  }

  Widget _body() {
    final run = _store.latestRun;
    if (run == null) {
      final phase =
          _store.loading || _store.state == null && _store.failure == null
              ? KpbAsyncPhase.loading
              : _store.failure != null && _store.state == null
                  ? KpbAsyncPhase.error
                  : KpbAsyncPhase.empty;
      return KpbAsyncView(
        phase: phase,
        errorTitle: 'scholarship_match_load_error_title'.tr,
        errorMessage: scholarshipMatchFailureMessage(
          _store.failure ?? ScholarshipMatchFailure.server,
        ),
        onRetry: () => unawaited(_load(force: true)),
        empty: KpbEmptyState(
          icon: Icons.fact_check_outlined,
          title: 'scholarship_match_entry_title'.tr,
          subtitle: 'scholarship_match_entry_body'.tr,
          action: FilledButton(
            key: const ValueKey<String>('match-results-start'),
            onPressed: () => unawaited(Get.off<void>(
              () => ScholarshipMatchFlowScreen(source: widget.source),
            )),
            child: Text('scholarship_match_entry_cta'.tr),
          ),
        ),
        builder: (_) => const SizedBox.shrink(),
      );
    }
    return KpbRefresh(
      onRefresh: () => _load(force: true),
      child: ListView(
        key: const ValueKey<String>('match-results-list'),
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.page,
          0,
          KpbSpacing.page,
          KpbSpacing.xl,
        ),
        children: _content(run),
      ),
    );
  }

  List<Widget> _content(MatchRun run) {
    final online = _online;
    final syncedAt = _store.latestRunSyncedAt;
    final compatible = run.compatibleItems;
    final toVerify = run.toVerifyItems;
    final shown = run.items.length;
    final date = run.createdAt ?? syncedAt;
    final alerts = _alertsOverride ?? _store.alertsOptIn;
    final followable = run.followableCompatibleIds;

    Widget card(MatchItem item) => MatchResultCard(
          item: item,
          now: _now,
          online: online,
          showSuccessLab: _successLab && scholarshipMatchCanPrepare(item),
          onOpen: () => _openDetail(item),
          onCase: () => unawaited(startScholarshipMatchCase(
            context,
            item: item,
            controller: _app,
          )),
          onSuccessLab: () => unawaited(startScholarshipMatchSuccessLab(item)),
          onWhatsApp: () => unawaited(openScholarshipMatchWhatsApp(
            prefill: scholarshipMatchWhatsAppPrefill(item.name),
            source: 'scholarship_match_card',
          )),
          onFollowChanged: (following) {
            if (!following) return;
            unawaited(AnalyticsService.instance.logScholarshipMatchFollow(
              itemId: item.scholarshipId,
              rank: item.rank,
              bulk: false,
            ));
          },
        );

    return <Widget>[
      if (_store.offline && syncedAt != null)
        _Banner(
          key: const ValueKey<String>('match-offline'),
          icon: Icons.cloud_off_rounded,
          text: 'scholarship_match_offline'
              .trParams({'date': matchDayMonth(syncedAt)}),
          color: KpbColors.textSecondary,
          background: KpbColors.surfaceMuted,
        ),
      if (_rerunning)
        _Banner(
          key: const ValueKey<String>('match-rerunning'),
          icon: Icons.sync_rounded,
          text: 'scholarship_match_updating'.tr,
          color: KpbColors.actionPrimary,
          background: KpbColors.actionPrimarySoft,
        ),
      RepaintBoundary(
        key: _shareKey,
        child: Container(
          color: KpbColors.canvas,
          padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  date == null
                      ? 'scholarship_match_results_title'.tr
                      : 'scholarship_match_results_header'
                          .trParams({'date': matchFullDate(date)}),
                  key: const ValueKey<String>('match-results-header'),
                  style: KpbTextStyles.title,
                ),
              ),
              const SizedBox(height: KpbSpacing.xs),
              Text(
                matchCountsLabel(run),
                key: const ValueKey<String>('match-results-counts'),
                style: KpbTextStyles.body.copyWith(
                  color: KpbColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      if (_needsReview)
        _Banner(
          key: const ValueKey<String>('match-needs-review'),
          icon: Icons.edit_note_rounded,
          text: 'scholarship_match_needs_review'.tr,
          color: KpbColors.warning,
          background: KpbColors.warningLight,
          actionLabel: 'scholarship_match_edit_info'.tr,
          onAction: () => unawaited(_openFlow(MatchFlowMode.recap)),
        ),
      if (run.levelCatalog?.label != null)
        _Banner(
          key: const ValueKey<String>('match-level-catalog'),
          icon: Icons.info_outline_rounded,
          text: run.levelCatalog!.label!,
          color: KpbColors.textPrimary,
          background: KpbColors.surfaceMuted,
        ),
      if (run.precisionLimitedBy != null)
        _Banner(
          key: const ValueKey<String>('match-precision'),
          icon: Icons.manage_search_rounded,
          text: run.precisionLimitedBy == MatchPrecisionLimit.kpb
              ? 'scholarship_match_precision_kpb'.tr
              : 'scholarship_match_precision_answers'.tr,
          color: KpbColors.textPrimary,
          background: KpbColors.warningLight,
          actionLabel: run.precisionLimitedBy == MatchPrecisionLimit.answers
              ? 'scholarship_match_edit_info'.tr
              : null,
          onAction: run.precisionLimitedBy == MatchPrecisionLimit.answers
              ? () => unawaited(_openFlow(MatchFlowMode.recap))
              : null,
        ),
      if (shown == 0) ...[
        _Banner(
          key: const ValueKey<String>('match-empty'),
          icon: Icons.search_off_rounded,
          text: 'scholarship_match_empty'.tr,
          color: KpbColors.textPrimary,
          background: KpbColors.surfaceMuted,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
          child: Text(
            'scholarship_match_empty_closed_return'.tr,
            style: KpbTextStyles.bodySm.copyWith(
              color: KpbColors.textSecondary,
            ),
          ),
        ),
      ] else if (compatible.isEmpty)
        _Banner(
          key: const ValueKey<String>('match-none-compatible'),
          icon: Icons.fact_check_outlined,
          text: toVerify.length == 1
              ? 'scholarship_match_none_compatible_one'.tr
              : 'scholarship_match_none_compatible'
                  .trParams({'count': '${toVerify.length}'}),
          color: KpbColors.textPrimary,
          background: KpbColors.warningLight,
        ),
      if (shown > 0 && shown < 10)
        _FewerThanTen(
          shown: shown,
          onEdit: () {
            unawaited(AnalyticsService.instance
                .logScholarshipMatchBroadenTapped(suggestion: 'edit_answers'));
            unawaited(_openFlow(MatchFlowMode.recap));
          },
          onAdvisor: () {
            unawaited(AnalyticsService.instance
                .logScholarshipMatchBroadenTapped(suggestion: 'advisor'));
            _talkToAdvisor(source: 'scholarship_match_broaden');
          },
        ),
      if (compatible.isNotEmpty) ...[
        _SectionTitle(
          key: const ValueKey<String>('match-section-compatible'),
          text: 'scholarship_match_section_compatible'.tr,
        ),
        for (final item in compatible) card(item),
      ],
      if (toVerify.isNotEmpty) ...[
        _SectionTitle(
          key: const ValueKey<String>('match-section-to-verify'),
          text: 'scholarship_match_section_to_verify'.tr,
        ),
        for (final item in toVerify) card(item),
      ],
      const SizedBox(height: KpbSpacing.sm),
      MatchExcludedSummaryView(
        summary: run.excludedSummary,
        onReport: (group) => unawaited(openScholarshipMatchWhatsApp(
          prefill: 'scholarship_match_report_prefill'
              .trParams({'group': group.label}),
          source: 'scholarship_match_report',
        )),
      ),
      const SizedBox(height: KpbSpacing.md),
      if (followable.isNotEmpty)
        FilledButton.icon(
          key: const ValueKey<String>('match-follow-all'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: online ? () => unawaited(_followAll(run)) : null,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(
            online
                ? (followable.length == 1
                    ? 'scholarship_match_follow_all_one'.tr
                    : 'scholarship_match_follow_all'
                        .trParams({'count': '${followable.length}'}))
                : 'scholarship_match_needs_connection'.tr,
          ),
        ),
      if (shown > 0) ...[
        const SizedBox(height: KpbSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey<String>('match-share'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => unawaited(_share(run)),
          icon: const Icon(Icons.ios_share_rounded),
          label: Text('scholarship_match_share'.tr),
        ),
      ],
      const SizedBox(height: KpbSpacing.sm),
      Wrap(
        spacing: KpbSpacing.xs,
        runSpacing: KpbSpacing.xs,
        children: [
          TextButton(
            key: const ValueKey<String>('match-redo'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed:
                online ? () => unawaited(_openFlow(MatchFlowMode.full)) : null,
            child: Text('scholarship_match_redo'.tr),
          ),
          TextButton(
            key: const ValueKey<String>('match-edit'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed:
                online ? () => unawaited(_openFlow(MatchFlowMode.recap)) : null,
            child: Text('scholarship_match_edit_info'.tr),
          ),
          TextButton(
            key: const ValueKey<String>('match-advisor'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _talkToAdvisor,
            child: Text('scholarship_match_advisor'.tr),
          ),
        ],
      ),
      const SizedBox(height: KpbSpacing.sm),
      SwitchListTile(
        key: const ValueKey<String>('match-alerts'),
        contentPadding: EdgeInsets.zero,
        value: alerts,
        onChanged: online && !_alertsSaving
            ? (value) => unawaited(_setAlerts(value))
            : null,
        title: Text(
          'scholarship_match_alerts_title'.tr,
          style: KpbTextStyles.bodySm,
        ),
        subtitle: online
            ? null
            : Text(
                'scholarship_match_needs_connection'.tr,
                style: KpbTextStyles.caption,
              ),
      ),
      const SizedBox(height: KpbSpacing.sm),
      Text(
        'scholarship_match_disclaimer'.tr,
        key: const ValueKey<String>('match-disclaimer'),
        style: KpbTextStyles.caption.copyWith(color: KpbColors.textSecondary),
      ),
      SizedBox(height: MediaQuery.of(context).padding.bottom + KpbSpacing.md),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: KpbSpacing.md, bottom: KpbSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: KpbTextStyles.titleSm),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
      padding: const EdgeInsets.all(KpbSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KpbRadius.sm),
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: KpbTextStyles.bodySm.copyWith(
                      color: KpbColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FewerThanTen extends StatelessWidget {
  const _FewerThanTen({
    required this.shown,
    required this.onEdit,
    required this.onAdvisor,
  });

  final int shown;
  final VoidCallback onEdit;
  final VoidCallback onAdvisor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('match-fewer-than-ten'),
      margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
      padding: const EdgeInsets.all(KpbSpacing.sm),
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: BorderRadius.circular(KpbRadius.sm),
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shown == 1
                ? 'scholarship_match_fewer_one'.tr
                : 'scholarship_match_fewer'.trParams({'count': '$shown'}),
            style: KpbTextStyles.bodySm,
          ),
          Text(
            'scholarship_match_see_more_title'.tr,
            style: KpbTextStyles.titleSm,
          ),
          Wrap(
            spacing: KpbSpacing.xs,
            children: [
              TextButton(
                key: const ValueKey<String>('match-broaden-edit'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onEdit,
                child: Text('scholarship_match_see_more_edit'.tr),
              ),
              TextButton(
                key: const ValueKey<String>('match-broaden-advisor'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onAdvisor,
                child: Text('scholarship_match_advisor'.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
