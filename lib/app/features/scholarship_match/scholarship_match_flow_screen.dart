import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/scholarship_match.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/scholarship_match_store.dart';
import '../../core/ui/kpb_components.dart';
import 'scholarship_match_actions.dart';
import 'scholarship_match_flow_controller.dart';
import 'scholarship_match_results_screen.dart';
import 'steps/match_recap_step.dart';
import 'steps/match_steps.dart';

/// L'assistant du test : une question par écran, seulement ce qui manque,
/// puis « Vérifie tes infos » et UNE requête.
///
/// Le brouillon est écrit après chaque réponse (Hive, par compte) : un
/// téléphone tué en pleine saisie reprend au même écran. Un échec garde le
/// brouillon et propose « Réessayer ».
class ScholarshipMatchFlowScreen extends StatefulWidget {
  const ScholarshipMatchFlowScreen({
    super.key,
    this.mode = MatchFlowMode.missing,
    this.source = 'unknown',
    this.returnToResults = false,
  });

  final MatchFlowMode mode;
  final String source;

  /// Ouvert depuis les résultats (« Refaire le test », « Modifier mes
  /// infos ») : on y revient au lieu d'empiler un second écran.
  final bool returnToResults;

  @override
  State<ScholarshipMatchFlowScreen> createState() =>
      _ScholarshipMatchFlowScreenState();
}

class _ScholarshipMatchFlowScreenState
    extends State<ScholarshipMatchFlowScreen> {
  final _store = ScholarshipMatchStore.instance;
  late final AppController _app = Get.find<AppController>();
  ScholarshipMatchFlowController? _flow;
  bool _loading = true;
  ScholarshipMatchFailure? _loadFailure;
  bool _submitting = false;
  ScholarshipMatchFailure? _submitFailure;
  bool _completed = false;
  String? _lastViewed;

  String get _userId => scholarshipMatchUserId(_app);
  String get _lang => scholarshipMatchLang(_app);

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _loadFailure = null;
    });
    await _store.loadState(
      client: _app.apiClient,
      userId: _userId,
      lang: _lang,
    );
    if (!mounted) return;
    final state = _store.state;
    if (state == null) {
      setState(() {
        _loading = false;
        _loadFailure = _store.failure ?? ScholarshipMatchFailure.server;
      });
      return;
    }
    final draft = ScholarshipMatchDraft.fromJson(
      await _store.readDraft(_userId),
    );
    if (!mounted) return;
    final flow = ScholarshipMatchFlowController(
      state: state,
      mode: widget.mode,
      draft: draft,
    )..addListener(_onFlowChanged);
    setState(() {
      _flow = flow;
      _loading = false;
    });
    if (!flow.resumed) {
      unawaited(AnalyticsService.instance.logScholarshipMatchStarted(
        source: widget.source,
        missingCount: flow.questionCount,
        isRerun: state.latestRun != null,
      ));
      unawaited(_saveDraft());
    }
    _logViewed();
  }

  void _onFlowChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_saveDraft());
    _logViewed();
  }

  Future<void> _saveDraft() async {
    final flow = _flow;
    if (flow == null || _completed) return;
    await _store.saveDraft(_userId, flow.toDraft().toJson());
  }

  void _logViewed() {
    final flow = _flow;
    if (flow == null) return;
    final current = flow.current;
    if (current == _lastViewed) return;
    _lastViewed = current;
    final progress = flow.progress;
    unawaited(AnalyticsService.instance.logScholarshipMatchStepViewed(
      step: matchStepAnalyticsName(current),
      index: progress?.$1 ?? 0,
      total: progress?.$2 ?? flow.questionCount,
    ));
  }

  @override
  void dispose() {
    final flow = _flow;
    if (flow != null) {
      flow.removeListener(_onFlowChanged);
      if (!_completed) {
        unawaited(AnalyticsService.instance.logScholarshipMatchAbandoned(
          lastStep: matchStepAnalyticsName(flow.current),
        ));
      }
      flow.dispose();
    }
    super.dispose();
  }

  void _continue() {
    final flow = _flow;
    if (flow == null || !flow.canContinue) return;
    final key = flow.current;
    if (key != MatchFlowScreen.intro) {
      unawaited(AnalyticsService.instance.logScholarshipMatchStepCompleted(
        step: matchStepAnalyticsName(key),
        changedPrefill: flow.changedPrefill(key),
      ));
    }
    flow.next();
  }

  String get _trigger => switch (_flow?.mode) {
        MatchFlowMode.full => 'rerun',
        MatchFlowMode.recap => 'edit',
        _ => 'wizard',
      };

  Future<void> _submit() async {
    final flow = _flow;
    if (flow == null || _submitting || !flow.canContinue) return;
    setState(() {
      _submitting = true;
      _submitFailure = null;
    });
    final outcome = await _store.createRun(
      client: _app.apiClient,
      userId: _userId,
      lang: _lang,
      answers: flow.buildAnswers(),
      confirm: true,
      trigger: _trigger,
    );
    if (!mounted) return;
    switch (outcome) {
      case MatchRunSucceeded(:final run, :final diff):
        _completed = true;
        await _store.clearDraft(_userId);
        unawaited(KpbHaptics.success());
        unawaited(AnalyticsService.instance.logScholarshipMatchCompleted(
          eligibleCount: run.counts.eligible,
          toVerifyCount: run.counts.toVerify,
          excludedCount: run.counts.excluded,
          durationS: DateTime.now().difference(flow.startedAt).inSeconds,
          algorithmVersion: run.algorithmVersion ?? 'unknown',
          isRerun: flow.state.latestRun != null,
        ));
        if (!mounted) return;
        if (widget.returnToResults) {
          Navigator.of(context).pop(diff);
        } else {
          unawaited(Get.off<void>(
            () => ScholarshipMatchResultsScreen(
              source: widget.source,
              initialDiff: diff,
            ),
          ));
        }
      case MatchRunNeedsAnswers():
        unawaited(AnalyticsService.instance
            .logScholarshipMatchFailed(reason: 'profile_incomplete'));
        setState(() => _submitting = false);
        KpbToast.info('scholarship_match_still_missing'.tr, context: context);
        flow.jumpToFirstMissing();
      case MatchRunFailed(:final failure):
        unawaited(AnalyticsService.instance
            .logScholarshipMatchFailed(reason: failure.name));
        unawaited(KpbHaptics.error());
        setState(() {
          _submitting = false;
          _submitFailure = failure;
        });
        KpbToast.error(
          scholarshipMatchFailureMessage(failure),
          context: context,
          action: failure == ScholarshipMatchFailure.disabled ||
                  failure == ScholarshipMatchFailure.forbidden
              ? null
              : KpbToastAction(
                  label: 'retry'.tr,
                  onPressed: () => unawaited(_submit()),
                ),
        );
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('scholarship_match_leave_title'.tr),
        content: Text('scholarship_match_leave_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('scholarship_match_leave_stay'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('scholarship_match_leave_quit'.tr),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    final canStepBack = flow?.canGoBack ?? false;
    return PopScope(
      canPop: !canStepBack && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _submitting) return;
        flow?.back();
      },
      child: Scaffold(
        backgroundColor: KpbColors.canvas,
        appBar: AppBar(
          backgroundColor: KpbColors.canvas,
          surfaceTintColor: KpbColors.canvas,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'scholarship_match_flow_title'.tr,
            style: KpbTextStyles.titleMd,
          ),
          actions: [
            IconButton(
              key: const ValueKey<String>('match-flow-close'),
              tooltip: 'scholarship_match_flow_close'.tr,
              icon: const Icon(Icons.close_rounded),
              onPressed: _submitting
                  ? null
                  : () async {
                      // `pop` (et non `maybePop`) : quitter ne remonte pas
                      // les questions une à une. Le brouillon reste gardé.
                      if (await _confirmLeave() && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _buildBody(flow),
        ),
      ),
    );
  }

  Widget _buildBody(ScholarshipMatchFlowController? flow) {
    if (_loading || flow == null) {
      return KpbAsyncView(
        phase: _loading ? KpbAsyncPhase.loading : KpbAsyncPhase.error,
        errorTitle: 'scholarship_match_load_error_title'.tr,
        errorMessage: scholarshipMatchFailureMessage(
          _loadFailure ?? ScholarshipMatchFailure.server,
        ),
        onRetry: _loadFailure == ScholarshipMatchFailure.disabled ||
                _loadFailure == ScholarshipMatchFailure.forbidden
            ? null
            : () => unawaited(_init()),
        builder: (_) => const SizedBox.shrink(),
      );
    }
    if (_submitting) {
      final size = flow.state.catalogSize;
      return Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: KpbSpacing.md),
              Text(
                size > 0
                    ? 'scholarship_match_analysing'.trParams({'count': '$size'})
                    : 'scholarship_match_analysing_generic'.tr,
                key: const ValueKey<String>('match-analysing'),
                style: KpbTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final progress = flow.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KpbSpacing.page,
              0,
              KpbSpacing.page,
              KpbSpacing.xs,
            ),
            child: Semantics(
              label: 'scholarship_match_progress_a11y'.trParams({
                'index': '${progress.$1}',
                'total': '${progress.$2}',
              }),
              excludeSemantics: true,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress.$1 / progress.$2,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(KpbRadius.pill),
                    ),
                  ),
                  const SizedBox(width: KpbSpacing.sm),
                  Text(
                    '${progress.$1}/${progress.$2}',
                    key: const ValueKey<String>('match-progress'),
                    style: KpbTextStyles.label,
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: flow.onRecap
              ? MatchRecapStep(controller: flow)
              : MatchStepView(
                  key: ValueKey<String>('match-step-${flow.current}'),
                  controller: flow,
                  stepKey: flow.current,
                ),
        ),
        if (flow.onRecap && _submitFailure != null)
          _SubmitErrorBox(
            failure: _submitFailure!,
            onRetry: () => unawaited(_submit()),
          ),
        _BottomBar(
          flow: flow,
          onContinue: _continue,
          onSubmit: () => unawaited(_submit()),
        ),
      ],
    );
  }
}

class _SubmitErrorBox extends StatelessWidget {
  const _SubmitErrorBox({required this.failure, required this.onRetry});

  final ScholarshipMatchFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final retryable = failure != ScholarshipMatchFailure.disabled &&
        failure != ScholarshipMatchFailure.forbidden;
    return Container(
      key: const ValueKey<String>('match-submit-error'),
      margin: const EdgeInsets.symmetric(horizontal: KpbSpacing.page),
      padding: const EdgeInsets.all(KpbSpacing.sm),
      decoration: BoxDecoration(
        color: KpbColors.errorLight,
        borderRadius: BorderRadius.circular(KpbRadius.sm),
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: KpbColors.error),
            const SizedBox(width: KpbSpacing.sm),
            Expanded(
              child: Text(
                '${scholarshipMatchFailureMessage(failure)} '
                '${'scholarship_match_draft_kept'.tr}',
                style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
              ),
            ),
            if (retryable)
              TextButton(
                key: const ValueKey<String>('match-submit-retry'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onRetry,
                child: Text('retry'.tr),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.flow,
    required this.onContinue,
    required this.onSubmit,
  });

  final ScholarshipMatchFlowController flow;
  final VoidCallback onContinue;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final onRecap = flow.onRecap;
    final label = onRecap
        ? 'scholarship_match_submit'.tr
        : flow.editing != null
            ? 'scholarship_match_apply'.tr
            : flow.current == MatchFlowScreen.intro
                ? 'scholarship_match_start'.tr
                : 'continue'.tr;
    final enabled = flow.canContinue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.page,
        KpbSpacing.sm,
        KpbSpacing.page,
        KpbSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onRecap && !enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
              child: Text(
                flow.recapMissing.isEmpty
                    ? 'scholarship_match_nationality_consent_required'.tr
                    : 'scholarship_match_recap_complete_first'.tr,
                style: KpbTextStyles.caption.copyWith(color: KpbColors.error),
              ),
            ),
          Row(
            children: [
              if (flow.canGoBack) ...[
                OutlinedButton(
                  key: const ValueKey<String>('match-back'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: flow.back,
                  child: Text('back'.tr),
                ),
                const SizedBox(width: KpbSpacing.sm),
              ],
              Expanded(
                child: FilledButton(
                  key: ValueKey<String>(
                    onRecap ? 'match-submit' : 'match-continue',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: enabled ? (onRecap ? onSubmit : onContinue) : null,
                  child: Text(label),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
