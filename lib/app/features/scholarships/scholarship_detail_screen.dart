import 'dart:async';

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
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';
import '../scholarship_match/widgets/match_assessment_block.dart';
import 'scholarship_video_player_screen.dart';
import 'widgets/how_to_apply_sheet.dart';
import 'widgets/follow_scholarship_button.dart';
import 'widgets/scholarship_status_line.dart';
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
  bool _successLabEnabled = false;
  String? _error;

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
      if (mounted && _scholarship == null) {
        setState(() => _error = exception.toString());
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
  bool _showNotifyOpening(AppController controller, LiveScholarshipModel s) {
    if (!RemoteFeatureFlags.instance.openingAlertToggleEnabled) return false;
    if (_follow == null || _notifyOpeningUnavailable) return false;
    if (controller.isGuestMode || controller.profile == null) return false;
    if (!controller.isFollowingScholarship(s.id)) return false;
    return s.statusLine()?.kind != ScholarshipStatusKind.closed;
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

  @override
  Widget build(BuildContext context) {
    final scholarship = _scholarship;
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
      body: scholarship == null
          ? _buildUnavailable()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                children: [
                  _HeaderCard(scholarship: scholarship),
                  const SizedBox(height: 12),
                  FollowScholarshipButton(
                    scholarshipId: scholarship.id,
                    scholarshipTitle: scholarship.title,
                    variant: FollowButtonVariant.full,
                  ),
                  GetBuilder<AppController>(
                    builder: (controller) {
                      if (!_showNotifyOpening(controller, scholarship)) {
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
                  ScholarshipMatchAssessmentBlock(
                    scholarshipId: scholarship.id,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => showHowToApplySheet(
                      context,
                      scholarshipTitle: scholarship.title,
                      steps: scholarship.applicationSteps,
                      onOpenOfficialForm:
                          isOpenableWebUrl(scholarship.applicationUrl)
                              ? () => _openUrl(scholarship.applicationUrl)
                              : null,
                    ),
                    icon: const Icon(Icons.format_list_numbered_rounded),
                    label: Text(
                      'live_scholarships_section_application_steps'.tr,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (_canStartWorkspace(scholarship)) ...[
                    const SizedBox(height: 10),
                    KpbButton(
                      key: const ValueKey<String>(
                        'scholarship-start-success-lab',
                      ),
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
                  if (scholarship.advantages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BulletSection(
                      title: 'live_scholarships_section_advantages'.tr,
                      items: scholarship.advantages,
                      color: KpbColors.success,
                    ),
                  ],
                  if (scholarship.eligibility.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BulletSection(
                      title: 'live_scholarships_section_eligibility'.tr,
                      items: scholarship.eligibility,
                      color: KpbColors.actionPrimary,
                    ),
                  ],
                  if (scholarship.keyRequirements.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BulletSection(
                      title: 'live_scholarships_section_key_requirements'.tr,
                      items: scholarship.keyRequirements,
                      color: KpbColors.lawPurple,
                    ),
                  ],
                  if (scholarship.videos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _VideosSection(
                      videos: scholarship.videos,
                      onOpen: _openVideo,
                    ),
                  ],
                  const SizedBox(height: 18),
                  // `isNotEmpty` ne suffisait pas : le catalogue contient des
                  // `applicationUrl` sans schéma (« exemple.org/apply »), que
                  // rien ne peut ouvrir. Un bouton principal qui ne peut PAS
                  // marcher est masqué, pas grisé et pas silencieux.
                  if (isOpenableWebUrl(scholarship.applicationUrl)) ...[
                    FilledButton.icon(
                      onPressed: () => _openUrl(scholarship.applicationUrl),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text('live_scholarships_official_form'.tr),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CaseComposerSheet(
                        caseType: CaseType.scholarshipSupport,
                        title: scholarship.title,
                        contextLabel: scholarship.countryName,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text('live_scholarships_apply_with_kpb'.tr),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUnavailable() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: KpbEmptyState(
        icon:
            _error == null ? Icons.search_off_rounded : Icons.wifi_off_rounded,
        title: _error == null
            ? 'scholarship_detail_not_found'.tr
            : 'live_scholarships_connection_error_title'.tr,
        subtitle: _error == null
            ? 'scholarship_detail_not_found_body'.tr
            : 'live_scholarships_connection_error_subtitle'.tr,
        action: KpbButton(text: 'retry'.tr, onPressed: _load),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.scholarship});

  final LiveScholarshipModel scholarship;

  @override
  Widget build(BuildContext context) {
    final cycle = scholarship.currentCycle;
    // Une date ESTIMÉE ne doit pas devenir une « Date limite » au jour près.
    //
    // La carte de la liste se tait déjà dans ce cas (`_deadlineBadge` rend
    // `null` quand le cycle est estimé) ; la fiche détail, elle, retombait sur
    // `deadlineAt` — qui vient de `estimatedCloseAt` à l'import — et
    // l'affichait formatée en jj/mm/aaaa. Les deux écrans disaient donc deux
    // choses différentes de la même bourse, et c'est le plus détaillé des deux
    // qui affirmait le plus faux.
    //
    // `null` ici n'efface rien : le bloc plus bas retombe alors sur
    // `deadlineLabel`, c'est-à-dire la phrase « À venir, généralement aux mois
    // de … » — la formulation honnête, à la granularité de ce qu'on sait.
    // Prédicat IDENTIQUE à celui de `_deadlineBadge`
    // (live_scholarships_screen.dart) — volontairement recopié à l'octet près
    // plutôt que « équivalent » : c'est leur divergence qui faisait dire deux
    // choses aux deux écrans.
    final isEstimated = cycle?.isEstimated ?? false;
    // « Ouverte » seulement si elle l'est VRAIMENT : un cycle `open` dont la
    // date d'ouverture est à venir se lit « Ouvre le … ».
    final statusLine = scholarship.statusLine();
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [scholarship.countryName, scholarship.level]
                .where((value) => value.isNotEmpty)
                .join(' · '),
            style: const TextStyle(color: KpbColors.textMuted),
          ),
          if (statusLine != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ScholarshipStatusChip(line: statusLine),
            ),
          ],
          const SizedBox(height: 16),
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
                      : _formatDate(deadline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
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
                color: KpbColors.textFaint,
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

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

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
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 10),
                      child: Icon(Icons.check_circle_rounded,
                          size: 17, color: color),
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
