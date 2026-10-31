import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/success_lab_api_codec.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/skeleton.dart';
import '../cases/scholarship_support_case.dart';
import '../scholarship_match/widgets/match_assessment_block.dart';
import 'scholarship_urgency.dart';
import 'scholarship_video_player_screen.dart';
import 'widgets/application_requirement_badge.dart';
import 'widgets/how_to_apply_sheet.dart';
import 'widgets/follow_scholarship_button.dart';
import 'widgets/scholarship_status_line.dart';
import '../../core/models/community.dart';
import '../community/hub/community_entity_section.dart';
import '../../core/utils/external_link.dart';
import '../../core/utils/whatsapp_utils.dart';

class ScholarshipDetailScreen extends StatefulWidget {
  const ScholarshipDetailScreen({
    super.key,
    required this.scholarshipId,
    this.initialScholarship,
    this.apiClient,
  });

  final String scholarshipId;
  final LiveScholarshipModel? initialScholarship;
  final AppApiClient? apiClient;

  @override
  State<ScholarshipDetailScreen> createState() =>
      _ScholarshipDetailScreenState();
}

class _ScholarshipDetailScreenState extends State<ScholarshipDetailScreen> {
  late final AppApiClient _apiClient;
  LiveScholarshipModel? _scholarship;

  /// Bloc `follow` du serveur (chantier C) ; null sur un backend plus ancien.
  ScholarshipFollowState? _follow;

  /// Choix « Me prévenir à l'ouverture » posé dans cette page, en attendant
  /// que le serveur le confirme.
  bool? _notifyOpeningOverride;
  bool _notifyOpeningSaving = false;

  /// Le serveur a répondu 404 au PATCH : l'interrupteur se masque.
  bool _notifyOpeningUnavailable = false;
  bool _loading = false;
  bool _startingWorkspace = false;
  bool _startingSupport = false;
  bool _successLabEnabled = false;
  String? _error;

  /// Invité face à une fiche réservée aux comptes (401/403) : le mur, pas
  /// « Erreur de connexion » en boucle (audit build 57, n° 9).
  bool _guestGated = false;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? Get.find<AppController>().apiClient;
    _scholarship = widget.initialScholarship;
    _follow = widget.initialScholarship?.follow;
    unawaited(
        AnalyticsService.instance.logViewScholarship(widget.scholarshipId));
    unawaited(_load());
  }

  Future<void> _load() async {
    unawaited(_refreshSuccessLabAccess());
    setState(() {
      _loading = _scholarship == null;
      _error = null;
      _guestGated = false;
    });
    try {
      final language =
          Get.find<AppController>().profile?.preferredLanguage == 'en'
              ? 'en'
              : 'fr';
      final detail = await _apiClient.fetchLiveScholarshipDetailWithFallback(
        scholarshipId: widget.scholarshipId,
        lang: language,
        initial: _scholarship,
      );
      if (mounted) {
        setState(() {
          _scholarship = detail;
          _follow = detail?.follow ?? _follow;
          _notifyOpeningOverride = null;
        });
        if ((detail?.follow?.following ?? false) ||
            detail?.isAlertEnabled == true) {
          Get.find<AppController>().rememberServerFollowedScholarships(
              <String>[widget.scholarshipId]);
        }
      }
      try {
        // Les alertes posées par la cloche des builds précédentes valent
        // « Suivie » : sans elles, le bouton proposerait de suivre une bourse
        // dont l'élève reçoit déjà les annonces.
        final alerts = await _apiClient.fetchScholarshipAlerts();
        if (mounted) {
          Get.find<AppController>().rememberServerFollowedScholarships(alerts);
        }
      } catch (_) {
        // Keep the local follow state if alert reconciliation is offline.
      }
    } catch (exception) {
      final status =
          exception is DioException ? exception.response?.statusCode : null;
      final guestGated = (status == 401 || status == 403) &&
          Get.find<AppController>().isGuestMode;
      if (mounted && _scholarship == null) {
        setState(() {
          _error = exception.toString();
          _guestGated = guestGated;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ouvre un lien externe, et DIT quand il ne s'ouvre pas.
  ///
  /// La version d'avant tenait en trois lignes sans branche d'échec : si
  /// `canLaunchUrl` renvoyait faux — ce qu'il fait sur tout Android 11+ sans
  /// intention VIEW déclarée — la fonction rendait la main en silence. Le bouton
  /// bleu pleine largeur « Formulaire officiel », sur l'action même sans
  /// laquelle l'étudiant rate la bourse, ne faisait alors strictement rien.
  ///
  /// Le repli n'est pas un message d'erreur : c'est un conseiller. L'étudiant
  /// qui ne peut pas ouvrir le formulaire a toujours besoin de candidater.
  Future<void> _openUrl(String value) async {
    if (await kpbOpenExternalUrlString(value)) return;
    if (!mounted) return;
    final scholarshipTitle = _scholarship?.title ?? '';
    KpbToast.error(
      'external_link_failed_body'.tr,
      title: 'external_link_failed_title'.tr,
      action: KpbToastAction(
        label: 'external_link_failed_cta'.tr,
        onPressed: () {
          openWhatsAppOrToast(
            prefill: kpbWhatsAppPrefill(
              custom: 'external_link_failed_prefill'
                  .trParams({'title': scholarshipTitle}),
            ),
            source: 'scholarship_official_form_failed',
            contextType: 'scholarship',
          );
        },
      ),
    );
  }

  /// L'interrupteur « Me prévenir à l'ouverture » est-il pertinent ici ?
  /// Seulement si le serveur sert le bloc `follow` (backend du chantier C), si
  /// l'élève suit la bourse, et tant qu'elle n'est pas close.
  bool _showNotifyOpening(
    AppController controller,
    ScholarshipUrgency urgency,
  ) {
    if (!RemoteFeatureFlags.instance.openingAlertToggleEnabled) return false;
    if (_follow == null || _notifyOpeningUnavailable) return false;
    if (controller.isGuestMode || controller.profile == null) return false;
    if (!controller.isFollowingScholarship(widget.scholarshipId)) return false;
    return !urgency.isClosed;
  }

  /// Un « Suivre » tout neuf pose l'alerte : prévenu par défaut, tant que le
  /// serveur n'a pas dit autre chose.
  bool get _notifyOpening {
    final override = _notifyOpeningOverride;
    if (override != null) return override;
    final follow = _follow;
    if (follow == null || !follow.following) return true;
    return follow.notifyOpening;
  }

  Future<void> _setNotifyOpening(bool value) async {
    if (_notifyOpeningSaving) return;
    final previous = _notifyOpening;
    unawaited(KpbHaptics.selection());
    setState(() {
      _notifyOpeningOverride = value;
      _notifyOpeningSaving = true;
    });
    try {
      final response = await _apiClient.updateScholarshipOpeningAlert(
        widget.scholarshipId,
        notifyOpening: value,
      );
      if (!mounted) return;
      final confirmed = response['notifyOpening'];
      setState(() {
        _notifyOpeningOverride = confirmed is bool ? confirmed : value;
        _follow = _follow?.copyWith(
          following: response['following'] is bool
              ? response['following'] as bool
              : true,
          notifyOpening: _notifyOpeningOverride,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notifyOpeningOverride = previous;
        // 404 : la route manque (backend antérieur) ou la bourse n'est plus
        // servie — dans les deux cas l'interrupteur n'a plus rien à piloter.
        if (isEndpointUnavailable(error)) _notifyOpeningUnavailable = true;
      });
      if (!isEndpointUnavailable(error)) {
        unawaited(KpbHaptics.error());
        KpbToast.error(
          'scholarship_notify_opening_error'.tr,
          context: context,
          action: KpbToastAction(
            label: 'retry'.tr,
            onPressed: () => unawaited(_setNotifyOpening(value)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _notifyOpeningSaving = false);
    }
  }

  void _openVideo(int index) {
    final scholarship = _scholarship;
    if (scholarship == null || scholarship.videos.isEmpty) return;
    Get.to(
      () => ScholarshipVideoPlayerScreen(
        scholarshipTitle: scholarship.title,
        videos: scholarship.videos,
        initialIndex: index,
      ),
    );
  }

  Future<bool> _refreshSuccessLabAccess() async {
    var enabled = false;
    try {
      final raw = await _apiClient.getSuccessLabAccess();
      enabled = SuccessLabApiCodec.accessFromApi(raw).enabled;
    } catch (_) {
      // The Success Lab is intentionally invisible unless the backend can
      // confirm flags, rollout membership, and country eligibility.
    }
    if (mounted && enabled != _successLabEnabled) {
      setState(() => _successLabEnabled = enabled);
    }
    return enabled;
  }

  bool _canStartWorkspace(LiveScholarshipModel scholarship) {
    final cycle = scholarship.currentCycle;
    return _successLabEnabled &&
        scholarship.id.trim().isNotEmpty &&
        cycle != null &&
        cycle.id.trim().isNotEmpty &&
        (cycle.status == 'forecast' || cycle.status == 'open');
  }

  Future<void> _startWorkspace() async {
    final scholarship = _scholarship;
    final cycle = scholarship?.currentCycle;
    if (_startingWorkspace ||
        scholarship == null ||
        cycle == null ||
        !_canStartWorkspace(scholarship)) {
      return;
    }

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
    if (userId == null) {
      KpbToast.error(
        'success_lab_missing_identity'.tr,
        title: 'success_lab_start_error_title'.tr,
      );
      return;
    }

    setState(() => _startingWorkspace = true);
    try {
      if (!await _refreshSuccessLabAccess()) return;

      final repository = SuccessLabRepository.standard(
        apiClient: _apiClient,
        userId: userId,
      );
      final workspace = await repository.createWorkspace(
        scholarshipId: scholarship.id,
        cycleId: cycle.id,
      );
      if (!mounted) return;
      await Get.toNamed(
        AppRoutes.successLabWorkspacePath(workspace.id),
      );
    } catch (error) {
      if (!mounted) return;
      final failure = SuccessLabRepository.normalizeFailure(error);
      KpbToast.error(
        _startFailureMessage(failure),
        title: 'success_lab_start_error_title'.tr,
      );
    } finally {
      if (mounted) setState(() => _startingWorkspace = false);
    }
  }

  String _startFailureMessage(SuccessLabFailure failure) {
    return switch (failure.kind) {
      SuccessLabFailureKind.offline => 'success_lab_start_offline'.tr,
      SuccessLabFailureKind.forbidden => 'success_lab_forbidden_body'.tr,
      SuccessLabFailureKind.featureDisabled => 'success_lab_disabled_body'.tr,
      SuccessLabFailureKind.conflict => 'success_lab_start_conflict'.tr,
      SuccessLabFailureKind.notFound ||
      SuccessLabFailureKind.invalidPayload ||
      SuccessLabFailureKind.server ||
      SuccessLabFailureKind.unknown =>
        'success_lab_start_error_body'.tr,
    };
  }

  /// « Être accompagné » : le dossier d'accompagnement de cette bourse (même
  /// chemin que les résultats « Mes 10 bourses », lien `scholarshipId` posé
  /// seulement quand le serveur le connaît — voir [canLinkCaseToScholarship]).
  Future<void> _startSupport() async {
    final scholarship = _scholarship;
    if (scholarship == null || _startingSupport) return;
    unawaited(KpbHaptics.selection());
    setState(() => _startingSupport = true);
    try {
      await startScholarshipSupportCase(
        context,
        scholarshipId: scholarship.id,
        title: scholarship.title,
        contextLabel: scholarship.countryName,
      );
    } finally {
      if (mounted) setState(() => _startingSupport = false);
    }
  }

  /// « Postuler » n'a de sens que si l'on PEUT candidater maintenant, et
  /// qu'un lien de candidature ouvrable existe. Sinon la barre propose
  /// « Suivre ».
  bool _canApply(
    LiveScholarshipModel scholarship,
    ScholarshipUrgency urgency,
  ) =>
      urgency.isOpen && isOpenableWebUrl(scholarship.applicationUrl);

  @override
  Widget build(BuildContext context) {
    final scholarship = _scholarship;
    final urgency =
        scholarship == null ? null : scholarshipUrgencyOf(scholarship);
    final canApply = scholarship != null && _canApply(scholarship, urgency!);
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        title: Text('scholarship_detail_title'.tr),
        actions: [
          IconButton(
            tooltip: 'a11y_refresh'.tr,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: scholarship == null
          ? null
          : _ActionBar(
              scholarship: scholarship,
              canApply: canApply,
              supportBusy: _startingSupport,
              onApply: () => _openUrl(scholarship.applicationUrl),
              onSupport: _startSupport,
            ),
      body: _guestGated && scholarship == null
          ? const KpbGuestGate(
              source: 'scholarship_detail_gate',
              icon: Icons.workspace_premium_outlined,
              titleKey: 'scholarships_auth_required_title',
              bodyKey: 'scholarships_auth_required_body',
              ctaKey: 'scholarships_auth_required_cta',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: KpbAsyncView(
                phase: KpbAsyncView.phaseOf(
                  loading: _loading,
                  hasData: scholarship != null,
                  failed: _error != null,
                ),
                refreshable: true,
                skeleton: const _DetailSkeleton(),
                empty: KpbEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'scholarship_detail_not_found'.tr,
                  subtitle: 'scholarship_detail_not_found_body'.tr,
                  action: KpbButton(text: 'retry'.tr, onPressed: _load),
                ),
                errorTitle: 'live_scholarships_connection_error_title'.tr,
                errorMessage: 'live_scholarships_connection_error_subtitle'.tr,
                onRetry: _load,
                builder: (context) =>
                    _buildContent(context, scholarship!, urgency!, canApply),
              ),
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LiveScholarshipModel scholarship,
    ScholarshipUrgency urgency,
    bool canApply,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // En tête : là où un tap de push (ouverture, rappel de clôture) fait
        // atterrir l'élève — il lit d'abord ce que le push annonçait.
        ScholarshipStatusHeader(scholarship: scholarship, urgency: urgency),
        const SizedBox(height: 12),
        _HeaderCard(
          scholarship: scholarship,
          urgency: urgency,
          // « Suivre » est dans la barre du bas quand on ne peut pas
          // postuler ; sinon il reste ici, à côté du titre.
          showFollow: canApply,
          onOpenSource: _openSource,
        ),
        GetBuilder<AppController>(
          builder: (controller) {
            if (!_showNotifyOpening(controller, urgency)) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _NotifyOpeningTile(
                value: _notifyOpening,
                saving: _notifyOpeningSaving,
                globalOptOut: _follow?.globalOptOut ?? false,
                onChanged: _setNotifyOpening,
              ),
            );
          },
        ),
        // « Mes 10 bourses » : le résultat du test pour CETTE
        // bourse, ou l'invitation à le faire (drapeau ouvert).
        ScholarshipMatchAssessmentBlock(scholarshipId: scholarship.id),
        const SizedBox(height: 10),
        // Dit d'emblée s'il y a quelque chose à faire (attribution automatique
        // ou candidature séparée) : le badge existait mais n'était posé nulle
        // part (audit build 57, T3-08).
        Align(
          alignment: Alignment.centerLeft,
          child: ApplicationRequirementBadge(
            key: const ValueKey<String>('scholarship-requirement-badge'),
            isAutomatic: scholarship.applicationRequirement == 'automatic',
            accent: KpbColors.actionPrimary,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showHowToApplySheet(
            context,
            scholarshipTitle: scholarship.title,
            steps: scholarship.applicationSteps,
            applicationsOpen: canApply,
            onOpenOfficialForm: isOpenableWebUrl(scholarship.applicationUrl)
                ? () => _openUrl(scholarship.applicationUrl)
                : null,
          ),
          icon: const Icon(Icons.format_list_numbered_rounded),
          label: Text('live_scholarships_section_application_steps'.tr),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (_canStartWorkspace(scholarship)) ...[
          const SizedBox(height: 10),
          KpbButton(
            key: const ValueKey<String>('scholarship-start-success-lab'),
            label: 'success_lab_start_action'.tr,
            icon: Icons.auto_awesome_rounded,
            fullWidth: true,
            loading: _startingWorkspace,
            onPressed: _startWorkspace,
          ),
        ],
        if (scholarship.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextSection(
            title: 'live_scholarships_section_description'.tr,
            body: scholarship.description,
          ),
        ],
        // Puces NEUTRES : une coche verte dirait « condition remplie », ce
        // que personne n'a vérifié pour cet élève.
        if (scholarship.advantages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BulletSection(
            title: 'live_scholarships_section_advantages'.tr,
            items: scholarship.advantages,
          ),
        ],
        if (scholarship.eligibility.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BulletSection(
            title: 'live_scholarships_section_eligibility'.tr,
            items: scholarship.eligibility,
          ),
        ],
        if (scholarship.keyRequirements.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BulletSection(
            title: 'live_scholarships_section_key_requirements'.tr,
            items: scholarship.keyRequirements,
          ),
        ],
        if (scholarship.videos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _VideosSection(videos: scholarship.videos, onOpen: _openVideo),
        ],
        // Communauté : « Discussions (N) » sur cette bourse (drapeau distant
        // `community` ; hauteur nulle sinon).
        CommunityEntitySection(
          entity: CommunityMention(
            type: CommunityEntityType.scholarship,
            id: scholarship.id,
            label: scholarship.title,
          ),
          padding: const EdgeInsets.only(top: 12),
        ),
      ],
    );
  }

  /// Le lien « Source officielle » : comme [KpbSourceLink], un lien qui ne
  /// s'ouvre pas le DIT.
  Future<void> _openSource(String url) async {
    if (await kpbOpenExternalUrlString(url)) return;
    if (!mounted) return;
    KpbToast.error(
      'external_link_failed_body'.tr,
      title: 'view_official_source'.tr,
    );
  }
}

/// L'en-tête de statut de la fiche : « Ouverte · clôture 6 janv. »,
/// « Clôture proche · … », « Ouverture estimée : … », « Date à confirmer »,
/// « Clôturée ». C'est la première chose lue — y compris en arrivant d'un push.
/// Le calcul vient de [scholarshipUrgencyOf] (partagé avec la liste).
class ScholarshipStatusHeader extends StatelessWidget {
  const ScholarshipStatusHeader({
    super.key,
    required this.scholarship,
    required this.urgency,
  });

  final LiveScholarshipModel scholarship;
  final ScholarshipUrgency urgency;

  String? _hint() {
    final label = scholarship.deadlineLabel.trim();
    switch (urgency.kind) {
      case ScholarshipUrgencyKind.closingSoon:
        final days = urgency.daysLeft ?? 0;
        if (days <= 0) return 'scholarship_urgency_last_day'.tr;
        if (days == 1) return 'scholarship_urgency_one_day_left'.tr;
        return 'scholarship_urgency_days_left'.trParams({'count': '$days'});
      case ScholarshipUrgencyKind.openingEstimated:
      case ScholarshipUrgencyKind.closingEstimated:
        return 'scholarship_urgency_estimated_hint'.tr;
      case ScholarshipUrgencyKind.dateToConfirm:
        return label.isNotEmpty ? label : 'scholarship_urgency_unknown_hint'.tr;
      case ScholarshipUrgencyKind.closed:
        return 'scholarship_urgency_closed_hint'.tr;
      case ScholarshipUrgencyKind.openDateToConfirm:
        return label.isNotEmpty ? label : null;
      case ScholarshipUrgencyKind.open:
      case ScholarshipUrgencyKind.opensOn:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = scholarshipUrgencyStyle(urgency.kind);
    final label = scholarshipUrgencyLabel(urgency);
    final hint = _hint();
    return Semantics(
      container: true,
      header: true,
      label: hint == null ? label : '$label. $hint',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('scholarship-status-header'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: KpbRadius.mdBr,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(style.icon, size: 22, color: style.foreground),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: style.foreground,
                      fontSize: KpbFontSize.md,
                      height: 1.3,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(
                        color: style.foreground,
                        fontSize: KpbFontSize.sm,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le squelette de la fiche, le temps du premier chargement (arrivée depuis un
/// push ou un lien : aucune donnée de liste à montrer).
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        key: ValueKey<String>('scholarship-detail-skeleton'),
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KpbSkeletonBox(height: 56, radius: KpbRadius.md),
            SizedBox(height: 12),
            KpbSkeletonBox(height: 168, radius: KpbRadius.lg),
            SizedBox(height: 12),
            KpbSkeletonBox(height: 48, radius: KpbRadius.md),
            SizedBox(height: 12),
            KpbSkeletonBox(height: 120, radius: KpbRadius.md),
          ],
        ),
      );
}

/// La barre fixe du bas : « Postuler » (cycle ouvert + lien de candidature)
/// ou « Suivre », et « Être accompagné ». Cibles de 48 dp.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.scholarship,
    required this.canApply,
    required this.supportBusy,
    required this.onApply,
    required this.onSupport,
  });

  final LiveScholarshipModel scholarship;
  final bool canApply;
  final bool supportBusy;
  final VoidCallback onApply;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    const buttonSize = Size.fromHeight(48);
    final Widget first = canApply
        ? Semantics(
            button: true,
            label: 'scholarship_action_apply_a11y'.trParams({
              'title': scholarship.title,
            }),
            excludeSemantics: true,
            onTap: onApply,
            child: FilledButton.icon(
              key: const ValueKey<String>('scholarship-action-apply'),
              onPressed: onApply,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('scholarship_action_apply'.tr),
              style: FilledButton.styleFrom(minimumSize: buttonSize),
            ),
          )
        : FollowScholarshipButton(
            scholarshipId: scholarship.id,
            scholarshipTitle: scholarship.title,
            variant: FollowButtonVariant.full,
          );
    final supportLabel = Text(
      'scholarship_action_support'.tr,
      textAlign: TextAlign.center,
    );
    final onSupportPressed = supportBusy ? null : onSupport;
    final Widget support = Semantics(
      button: true,
      label: 'scholarship_action_support_a11y'.trParams({
        'title': scholarship.title,
      }),
      excludeSemantics: true,
      onTap: onSupportPressed,
      child: canApply
          ? OutlinedButton(
              key: const ValueKey<String>('scholarship-action-support'),
              onPressed: onSupportPressed,
              style: OutlinedButton.styleFrom(minimumSize: buttonSize),
              child: supportLabel,
            )
          : FilledButton(
              key: const ValueKey<String>('scholarship-action-support'),
              onPressed: onSupportPressed,
              style: FilledButton.styleFrom(minimumSize: buttonSize),
              child: supportLabel,
            ),
    );
    return DecoratedBox(
      key: const ValueKey<String>('scholarship-action-bar'),
      decoration: const BoxDecoration(
        color: KpbColors.surface,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(child: first),
              const SizedBox(width: 10),
              Expanded(child: support),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.scholarship,
    required this.urgency,
    required this.showFollow,
    required this.onOpenSource,
  });

  final LiveScholarshipModel scholarship;
  final ScholarshipUrgency urgency;
  final bool showFollow;
  final ValueChanged<String> onOpenSource;

  @override
  Widget build(BuildContext context) {
    final cycle = scholarship.currentCycle;
    // Une date ESTIMÉE ne devient jamais une « Date limite » au jour près :
    // le bloc retombe alors sur `deadlineLabel` (« À venir, généralement aux
    // mois de … »), la formulation honnête à la granularité de ce qu'on sait.
    // Même prédicat que l'urgence ([scholarshipUrgencyOf]).
    final isEstimated = cycle?.isEstimated ?? false;
    final deadline =
        isEstimated ? null : (cycle?.closesAt ?? scholarship.deadlineAt);
    final funding = scholarship.isFullyFunded
        ? 'live_scholarships_fully_funded'.tr
        : scholarship.isPartiallyFunded
            ? 'live_scholarships_partially_funded'.tr
            : 'live_scholarships_funding_unknown'.tr;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    scholarship.title,
                    style: const TextStyle(
                      color: KpbColors.brandNavy,
                      fontSize: KpbFontSize.xl,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (showFollow) ...[
                const SizedBox(width: 8),
                FollowScholarshipButton(
                  scholarshipId: scholarship.id,
                  scholarshipTitle: scholarship.title,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              scholarship.countryName,
              scholarship.level,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(color: KpbColors.textMuted),
          ),
          _VerificationLine(
            verifiedAt: scholarship.verifiedAt,
            sourceUrl: scholarship.officialSourceUrl,
            onOpenSource: onOpenSource,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                  label: 'live_scholarships_funding_tile'.tr,
                  value: funding,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaTile(
                  label: 'live_scholarships_deadline_label'.tr,
                  value: deadline == null
                      ? (scholarship.deadlineLabel.isEmpty
                          ? 'live_scholarships_no_deadline'.tr
                          : scholarship.deadlineLabel)
                      : formatScholarshipDay(deadline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// « Vérifiée le 3 oct. 2026 · Source officielle » : la date de la dernière
/// vérification servie par l'API, et le lien sortant vers la source. Chaque
/// moitié se masque quand elle manque ; rien du tout quand les deux manquent.
class _VerificationLine extends StatelessWidget {
  const _VerificationLine({
    required this.verifiedAt,
    required this.sourceUrl,
    required this.onOpenSource,
  });

  final DateTime? verifiedAt;
  final String? sourceUrl;
  final ValueChanged<String> onOpenSource;

  @override
  Widget build(BuildContext context) {
    final date = verifiedAt;
    final source = sourceUrl;
    final hasSource = isOpenableWebUrl(source);
    if (date == null && !hasSource) return const SizedBox.shrink();
    const textStyle = TextStyle(
      color: KpbColors.textSecondary,
      fontSize: KpbFontSize.xs,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (date != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                widthFactor: 1,
                child: Text(
                  'scholarship_verified_on'.trParams({
                    'date': formatScholarshipDay(date),
                  }),
                  key: const ValueKey<String>('scholarship-verified-on'),
                  style: textStyle,
                ),
              ),
            ),
          if (date != null && hasSource)
            const ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('·', style: textStyle),
              ),
            ),
          if (hasSource)
            Semantics(
              link: true,
              label: 'scholarship_official_source_a11y'.tr,
              excludeSemantics: true,
              onTap: () => onOpenSource(source!),
              child: InkWell(
                key: const ValueKey<String>('scholarship-official-source'),
                onTap: () => onOpenSource(source!),
                borderRadius: KpbRadius.xsBr,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'scholarship_official_source'.tr,
                        style: const TextStyle(
                          color: KpbColors.actionPrimary,
                          fontSize: KpbFontSize.xs,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: KpbColors.actionPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: KpbColors.actionPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KpbColors.canvas,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: KpbFontSize.xs,
                color: KpbColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: KpbFontSize.xs,
                color: KpbColors.brandNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  color: KpbColors.brandNavy,
                  fontSize: KpbFontSize.md,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: title,
        child: Text(
          body,
          style: const TextStyle(
            color: KpbColors.gray700,
            fontSize: KpbFontSize.sm,
            height: 1.55,
          ),
        ),
      );
}

/// Une liste à puces NEUTRES (avantages, conditions, pièces). Pas de coche :
/// une icône de validation suggérerait une éligibilité vérifiée — ce qui est
/// faux tant que personne n'a comparé ces conditions au profil de l'élève.
class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: title,
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const ValueKey<String>('scholarship-bullet'),
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7, left: 2, right: 12),
                      decoration: const BoxDecoration(
                        color: KpbColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: KpbColors.gray700,
                          fontSize: KpbFontSize.sm,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _VideosSection extends StatelessWidget {
  const _VideosSection({required this.videos, required this.onOpen});

  final List<ScholarshipVideoModel> videos;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'scholarship_videos_title'.tr,
        child: SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final video = videos[index];
              final title = video.title.isEmpty
                  ? 'scholarship_video_explanation'.tr
                  : video.title;
              return Semantics(
                button: true,
                label: '${'scholarship_video_play'.tr}: $title',
                child: SizedBox(
                  width: 220,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => onOpen(index),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 112,
                                child: KpbNetworkImage(
                                  imageUrl: video.effectiveThumbnailUrl,
                                  targetWidth: 440,
                                  placeholderIcon:
                                      Icons.play_circle_outline_rounded,
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 28),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: KpbFontSize.xs,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

/// « Me prévenir à l'ouverture » : met en sourdine (ou rallume) l'annonce
/// d'ouverture de cette bourse, sans cesser de la suivre — les rappels de date
/// limite continuent.
class _NotifyOpeningTile extends StatelessWidget {
  const _NotifyOpeningTile({
    required this.value,
    required this.saving,
    required this.globalOptOut,
    required this.onChanged,
  });

  final bool value;
  final bool saving;
  final bool globalOptOut;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // Un Material (et non un Container décoré) : la tuile peint son effet de
    // tap sur le Material le plus proche.
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey<String>('scholarship-notify-opening'),
            value: value,
            onChanged: saving ? null : onChanged,
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
            title: Text(
              'scholarship_notify_opening_title'.tr,
              style: const TextStyle(
                fontSize: KpbFontSize.md,
                fontWeight: FontWeight.w800,
                color: KpbColors.brandNavy,
              ),
            ),
            subtitle: Text(
              'scholarship_notify_opening_subtitle'.tr,
              style: const TextStyle(
                fontSize: KpbFontSize.xs,
                height: 1.4,
                color: KpbColors.textMuted,
              ),
            ),
          ),
          if (globalOptOut && value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'scholarship_notify_opening_global_off'.tr,
                style: const TextStyle(
                  fontSize: KpbFontSize.xs,
                  height: 1.4,
                  color: KpbColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
