import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/controllers/success_lab_list_controller.dart';
import '../../core/models/success_lab.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'widgets/success_lab_accessibility.dart';
import 'widgets/success_lab_labels.dart';

class SuccessLabListScreen extends StatefulWidget {
  const SuccessLabListScreen({
    super.key,
    this.controller,
  });

  /// Test/preview injection. Production routes build an authenticated,
  /// user-scoped repository from the registered app services.
  final SuccessLabListController? controller;

  @override
  State<SuccessLabListScreen> createState() => _SuccessLabListScreenState();
}

class _SuccessLabListScreenState extends State<SuccessLabListScreen> {
  SuccessLabListController? _controller;
  final ScrollController _scrollController = ScrollController();
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null && _controller != null;
    _controller?.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    if (_controller?.phase == LabLoadPhase.initial) {
      unawaited(_controller!.loadInitial());
    }
  }

  SuccessLabListController? _buildController() {
    if (!Get.isRegistered<AppController>()) return null;
    final app = Get.find<AppController>();
    final authUserId = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>().userId?.trim()
        : null;
    final profileUserId = app.profile?.id.trim();
    final userId = authUserId?.isNotEmpty == true
        ? authUserId
        : profileUserId?.isNotEmpty == true
            ? profileUserId
            : null;
    if (userId == null) return null;
    return SuccessLabListController(
      repository: SuccessLabRepository.standard(
        apiClient: app.apiClient,
        userId: userId,
      ),
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 280) {
      unawaited(_controller?.loadMore());
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    if (_ownsController) _controller?.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final networkState = switch (controller?.phase) {
      LabLoadPhase.offline => SuccessLabNetworkUiState.offline,
      LabLoadPhase.initial ||
      LabLoadPhase.loading ||
      LabLoadPhase.syncing =>
        SuccessLabNetworkUiState.busy,
      _ => SuccessLabNetworkUiState.stable,
    };
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('success_lab_title'.tr),
        actions: [
          IconButton(
            tooltip: 'a11y_refresh'.tr,
            onPressed: controller?.loadInitial,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SuccessLabAccessibleBody(
        networkState: networkState,
        busyLabel: 'success_lab_cached_label'.tr,
        ensureScrollable: controller == null || controller.items.isEmpty,
        child: controller == null
            ? _identityMissing()
            : _buildControllerState(controller),
      ),
    );
  }

  Widget _buildControllerState(SuccessLabListController controller) {
    final phase = controller.phase;
    final showingCache = phase == LabLoadPhase.cached ||
        phase == LabLoadPhase.syncing ||
        phase == LabLoadPhase.offline;
    return KpbAsyncView(
      phase: controller.items.isNotEmpty
          ? KpbAsyncPhase.content
          : switch (phase) {
              LabLoadPhase.initial ||
              LabLoadPhase.loading ||
              LabLoadPhase.syncing =>
                KpbAsyncPhase.loading,
              LabLoadPhase.error => KpbAsyncPhase.error,
              LabLoadPhase.cached ||
              LabLoadPhase.ready =>
                KpbAsyncPhase.content,
              LabLoadPhase.empty ||
              LabLoadPhase.offline ||
              LabLoadPhase.forbidden ||
              LabLoadPhase.featureDisabled =>
                KpbAsyncPhase.empty,
            },
      errorTitle: 'success_lab_error_title'.tr,
      errorMessage: 'success_lab_error_body'.tr,
      onRetry: controller.loadInitial,
      updatedAt: showingCache && controller.items.isNotEmpty
          ? controller.cachedAt
          : null,
      empty: _emptyState(controller),
      builder: (context) => _buildList(controller),
    );
  }

  Widget _emptyState(SuccessLabListController controller) {
    return switch (controller.phase) {
      LabLoadPhase.offline => KpbEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'success_lab_offline_title'.tr,
          subtitle: 'success_lab_offline_empty_body'.tr,
          action: KpbButton(
            label: 'retry'.tr,
            onPressed: controller.loadInitial,
          ),
        ),
      LabLoadPhase.forbidden => KpbEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'success_lab_forbidden_title'.tr,
          subtitle: 'success_lab_forbidden_body'.tr,
        ),
      LabLoadPhase.featureDisabled => KpbEmptyState(
          icon: Icons.construction_rounded,
          title: 'success_lab_disabled_title'.tr,
          subtitle: 'success_lab_disabled_body'.tr,
        ),
      _ => KpbEmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'success_lab_empty_title'.tr,
          subtitle: 'success_lab_empty_body'.tr,
          action: KpbButton(
            label: 'success_lab_empty_action'.tr,
            onPressed: () => Get.toNamed(AppRoutes.scholarships),
          ),
        ),
    };
  }

  Widget _buildList(SuccessLabListController controller) {
    return KpbRefresh(
      onRefresh: controller.loadInitial,
      child: ListView.separated(
        key: const PageStorageKey<String>('success-lab-workspaces'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.page,
          KpbSpacing.sm,
          KpbSpacing.page,
          KpbSpacing.xxl,
        ),
        itemCount: controller.items.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: KpbSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'success_lab_subtitle'.tr,
                  style: KpbTextStyles.body.copyWith(
                    color: context.kpb.textSecondary,
                  ),
                ),
                if (controller.phase == LabLoadPhase.cached ||
                    controller.phase == LabLoadPhase.syncing ||
                    controller.phase == LabLoadPhase.offline) ...[
                  const SizedBox(height: KpbSpacing.md),
                  _DataStateBanner(
                    offline: controller.phase == LabLoadPhase.offline,
                  ),
                ],
              ],
            );
          }
          if (index == controller.items.length + 1) {
            return controller.loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(KpbSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final workspace = controller.items[index - 1];
          return _WorkspaceCard(
            workspace: workspace,
            onTap: () => Get.toNamed(
              AppRoutes.successLabWorkspacePath(workspace.id),
            ),
          );
        },
      ),
    );
  }

  Widget _identityMissing() {
    return KpbEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'success_lab_forbidden_title'.tr,
      subtitle: 'success_lab_missing_identity'.tr,
    );
  }
}

class _DataStateBanner extends StatelessWidget {
  const _DataStateBanner({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final label = offline
        ? 'success_lab_offline_cached_body'.tr
        : 'success_lab_cached_label'.tr;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: KpbCard(
          variant: KpbCardVariant.highlighted,
          padding: const EdgeInsets.all(KpbSpacing.sm),
          child: Row(
            children: [
              Icon(
                offline ? Icons.cloud_off_rounded : Icons.sync_rounded,
                size: 18,
                color: KpbColors.actionPrimary,
              ),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: KpbTextStyles.bodySm.copyWith(
                    color: context.kpb.textSecondary,
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

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.workspace,
    required this.onTap,
  });

  final SuccessLabWorkspace workspace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scholarship = workspace.scholarship;
    final progress = workspace.readinessPercent.clamp(0, 100);
    final deadline =
        workspace.cycle?.closesAt ?? workspace.cycle?.estimatedCloseAt;
    final title = scholarship?.name.trim().isNotEmpty == true
        ? scholarship!.name
        : 'success_lab_workspace_fallback'.tr;
    final statusLabel = successLabWorkspaceStatusLabel(workspace.status);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: KpbTextStyles.title.copyWith(
            color: context.kpb.textPrimary,
          ),
        ),
        if (scholarship?.countryName.trim().isNotEmpty == true) ...[
          const SizedBox(height: KpbSpacing.xs),
          Text(
            scholarship!.countryName,
            style: KpbTextStyles.bodySm.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
        ],
      ],
    );
    final statusChip = KpbStatusChip(
      status: successLabWorkspaceKpbStatus(workspace.status),
      label: statusLabel,
      compact: true,
    );
    final header = successLabUseStackedLayout(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: KpbSpacing.sm),
              statusChip,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: KpbSpacing.sm),
              statusChip,
            ],
          );
    final semanticLabel = <String>[
      title,
      if (scholarship?.countryName.trim().isNotEmpty == true)
        scholarship!.countryName,
      statusLabel,
      '${'success_lab_progress_label'.tr}: $progress%',
      if (workspace.nextAction?.label.trim().isNotEmpty == true)
        '${'success_lab_next_action'.tr}: ${workspace.nextAction!.label}',
    ].join('. ');
    return FocusableActionDetector(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        button: true,
        label: semanticLabel,
        onTap: onTap,
        child: ExcludeSemantics(
          child: KpbCard(
            variant: KpbCardVariant.interactive,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: KpbSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: KpbRadius.pillBr,
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 8,
                          backgroundColor: context.kpb.gray200,
                        ),
                      ),
                    ),
                    const SizedBox(width: KpbSpacing.sm),
                    Text(
                      '$progress%',
                      style: KpbTextStyles.titleSm.copyWith(
                        color: KpbColors.actionPrimary,
                      ),
                    ),
                  ],
                ),
                if (workspace.nextAction?.label.trim().isNotEmpty == true) ...[
                  const SizedBox(height: KpbSpacing.md),
                  Text(
                    'success_lab_next_action'.tr,
                    style: KpbTextStyles.label.copyWith(
                      color: context.kpb.textMuted,
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.xs),
                  Text(
                    workspace.nextAction!.label,
                    style: KpbTextStyles.bodySm.copyWith(
                      color: context.kpb.textPrimary,
                    ),
                  ),
                ],
                if (deadline != null) ...[
                  const SizedBox(height: KpbSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: context.kpb.textMuted,
                      ),
                      const SizedBox(width: KpbSpacing.xs),
                      Expanded(
                        child: Text(
                          '${_deadlineLabel(workspace.cycle?.dateConfidence)} · '
                          '${MaterialLocalizations.of(context).formatMediumDate(deadline.toLocal())}',
                          style: KpbTextStyles.bodySm.copyWith(
                            color: context.kpb.textSecondary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.kpb.textMuted,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _deadlineLabel(SuccessLabDateConfidence? confidence) {
    return confidence == SuccessLabDateConfidence.confirmed
        ? 'success_lab_deadline_confirmed'.tr
        : 'success_lab_deadline_estimated'.tr;
  }
}
