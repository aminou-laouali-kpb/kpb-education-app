// « Compétition ambassadeurs » — l'écran in-app du classement (build 57 / 2.3.1),
// derrière le drapeau distant `features.referralLeaderboard`.
//
// Ce qu'il montre à un PARTICIPANT (`GET /referrals/campaigns/current`) : la
// phase (à venir / en cours / terminée) et son compte à rebours à l'heure du
// SERVEUR, son rang, ses filleuls qualifiés / à vérifier / en attente, la règle
// dite honnêtement (« un filleul compte quand son profil est complété »), son
// code avec un lien d'invitation à partager, la page publique du classement et
// le règlement (`rulesUrl` du classement public, quand il est servi), et la
// mention « provisoire » tant que la campagne n'est pas close.
//
// Ce qu'il ne montre JAMAIS : un montant (ni prix, ni commission), un autre
// participant, une donnée de filleul.
//
// À un NON-participant : rien de promis. L'API ne lui donne pas le slug de la
// campagne, et l'app ne le code pas en dur : pas de lien vers un classement
// public qu'on ne saurait pas désigner.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/referral_campaign.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/skeleton.dart';
import '../../core/utils/external_link.dart';
import '../../core/utils/share_link.dart';

/// L'écran autonome (entrée depuis l'écran Parrainage).
class AmbassadorCompetitionScreen extends StatelessWidget {
  const AmbassadorCompetitionScreen({super.key, this.apiClient, this.clock});

  final AppApiClient? apiClient;

  /// Horloge injectée (tests).
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('comp_title'.tr)),
      body: AmbassadorCompetitionView(apiClient: apiClient, clock: clock),
    );
  }
}

/// Le contenu, réutilisé par l'espace ambassadeur (sans programme rémunéré) :
/// [nonParticipant] y remplace l'état « tu ne participes pas » par l'écran de
/// candidature existant.
class AmbassadorCompetitionView extends StatefulWidget {
  const AmbassadorCompetitionView({
    super.key,
    this.apiClient,
    this.clock,
    this.nonParticipant,
  });

  final AppApiClient? apiClient;
  final DateTime Function()? clock;
  final Widget? nonParticipant;

  @override
  State<AmbassadorCompetitionView> createState() =>
      _AmbassadorCompetitionViewState();
}

class _AmbassadorCompetitionViewState extends State<AmbassadorCompetitionView> {
  ReferralCampaignStanding? _standing;
  String? _rulesUrl;
  bool _loading = true;
  bool _offline = false;
  bool _failed = false;
  bool _logged = false;
  Timer? _ticker;
  late DateTime _now;

  DateTime _clock() => (widget.clock ?? DateTime.now)();

  AppApiClient get _api =>
      widget.apiClient ?? Get.find<AppController>().apiClient;

  @override
  void initState() {
    super.initState();
    _now = _clock();
    unawaited(_load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _offline = false;
    });
    ReferralCampaignStanding? standing;
    var failed = false;
    var offline = false;
    try {
      standing = ReferralCampaignStanding.fromJson(
        await _api.getCurrentReferralCampaign(),
        receivedAt: _clock(),
      );
    } catch (error) {
      if (isEndpointUnavailable(error)) {
        // Backend plus ancien que la build : personne ne participe ici.
        standing = ReferralCampaignStanding.notParticipating;
      } else {
        failed = true;
        offline = error is DioException && error.response == null;
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = failed;
      _offline = offline;
      if (standing != null) _standing = standing;
      _now = _clock();
    });
    final current = _standing;
    if (current == null) return;
    _startTicker(current);
    if (!_logged) {
      _logged = true;
      unawaited(AnalyticsService.instance.logReferralCompetitionViewed(
        phase: current.participating ? current.phaseAt(_now).name : 'none',
      ));
    }
    if (current.participating) unawaited(_loadRules(current.slug));
  }

  /// Le règlement n'est lu QUE pour son lien : une panne ne gêne rien.
  Future<void> _loadRules(String slug) async {
    try {
      final url =
          referralRulesUrlFrom(await _api.getPublicCampaignLeaderboard(slug));
      if (mounted) setState(() => _rulesUrl = url);
    } catch (_) {}
  }

  void _startTicker(ReferralCampaignStanding standing) {
    _ticker?.cancel();
    if (!standing.participating ||
        standing.phaseAt(_now) == ReferralCampaignPhase.ended) {
      return;
    }
    _ticker = Timer.periodic(referralCountdownTick, (_) {
      if (!mounted) return;
      setState(() => _now = _clock());
      if (standing.phaseAt(_now) == ReferralCampaignPhase.ended) {
        _ticker?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final standing = _standing;
    return KpbAsyncView(
      phase: KpbAsyncView.phaseOf(
        loading: _loading,
        hasData: standing != null,
        failed: _failed,
      ),
      onRetry: _load,
      errorTitle: _offline ? 'comp_offline_title'.tr : 'comp_error_title'.tr,
      errorMessage: _offline ? 'comp_offline_body'.tr : 'comp_error_body'.tr,
      skeleton: const KpbSkeletonList(itemCount: 3, itemHeight: 120),
      builder: (context) {
        final s = standing!;
        if (!s.participating) {
          return widget.nonParticipant ?? const _NotParticipating();
        }
        return _StandingBody(
          standing: s,
          now: _now,
          rulesUrl: _rulesUrl,
          onRefresh: _load,
        );
      },
    );
  }
}

class _NotParticipating extends StatelessWidget {
  const _NotParticipating();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: KpbEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'comp_not_participating_title'.tr,
        subtitle: 'comp_not_participating_body'.tr,
      ),
    );
  }
}

class _StandingBody extends StatelessWidget {
  const _StandingBody({
    required this.standing,
    required this.now,
    required this.rulesUrl,
    required this.onRefresh,
  });

  final ReferralCampaignStanding standing;
  final DateTime now;
  final String? rulesUrl;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final s = standing;
    final lang = Get.locale?.languageCode ?? 'fr';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          _PhaseCard(standing: s, now: now, name: s.name(lang)),
          if (s.provisional) ...[
            const SizedBox(height: KpbSpacing.md),
            _Notice(
              key: const ValueKey('comp-provisional'),
              icon: Icons.info_outline_rounded,
              text: 'comp_provisional'.tr,
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          _RankCard(standing: s),
          const SizedBox(height: KpbSpacing.md),
          KpbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CounterRow(
                  label: 'comp_qualified'.tr,
                  hint: 'comp_qualified_hint'.tr,
                  value: s.qualified,
                  color: KpbColors.success,
                ),
                const Divider(height: KpbSpacing.lg),
                _CounterRow(
                  label: 'comp_to_review'.tr,
                  hint: 'comp_to_review_hint'.tr,
                  value: s.toReview,
                  color: KpbColors.warning,
                ),
                const Divider(height: KpbSpacing.lg),
                _CounterRow(
                  label: 'comp_pending'.tr,
                  hint: 'comp_pending_hint'.tr,
                  value: s.pending,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          Text(
            'comp_rule_explainer'.tr,
            style: KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
          ),
          if (s.code.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.lg),
            _CodeCard(code: s.code),
          ],
          const SizedBox(height: KpbSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey('comp-public-link'),
            onPressed: () => kpbOpenExternalUrlString(s.publicLeaderboardUrl),
            icon: const Icon(Icons.leaderboard_outlined, size: 18),
            label: Text('comp_public_cta'.tr),
          ),
          if (rulesUrl != null)
            TextButton.icon(
              key: const ValueKey('comp-rules-link'),
              onPressed: () => kpbOpenExternalUrlString(rulesUrl),
              icon: const Icon(Icons.gavel_outlined, size: 18),
              label: Text('comp_rules_cta'.tr),
            ),
          const SizedBox(height: KpbSpacing.md),
          Text(
            'comp_organizer_note'.tr,
            style: KpbTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.standing,
    required this.now,
    required this.name,
  });

  final ReferralCampaignStanding standing;
  final DateTime now;
  final String name;

  String _formatRemaining(Duration remaining) {
    final p = CountdownParts.of(remaining);
    final params = {'d': '${p.days}', 'h': '${p.hours}', 'm': '${p.minutes}'};
    if (p.days > 0) return 'comp_time_dhm'.trParams(params);
    if (p.hours > 0) return 'comp_time_hm'.trParams(params);
    return 'comp_time_m'.trParams(params);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final phase = standing.phaseAt(now);
    final remaining = standing.remainingAt(now);
    final (KpbStatus status, String label) = switch (phase) {
      ReferralCampaignPhase.upcoming => (
          KpbStatus.info,
          'comp_phase_upcoming'.tr
        ),
      ReferralCampaignPhase.running => (
          KpbStatus.success,
          'comp_phase_running'.tr
        ),
      ReferralCampaignPhase.ended => (KpbStatus.neutral, 'comp_phase_ended'.tr),
    };
    final String countdown = switch (phase) {
      ReferralCampaignPhase.upcoming when remaining != null =>
        'comp_starts_in'.trParams({'time': _formatRemaining(remaining)}),
      ReferralCampaignPhase.running when remaining != null =>
        'comp_ends_in'.trParams({'time': _formatRemaining(remaining)}),
      ReferralCampaignPhase.ended => 'comp_ended_body'.tr,
      _ => '',
    };
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KpbStatusChip(
            key: ValueKey('comp-phase-${phase.name}'),
            status: status,
            label: label,
          ),
          const SizedBox(height: KpbSpacing.sm),
          Semantics(
            header: true,
            child: Text(
              name.isEmpty ? 'comp_title'.tr : name,
              style: KpbTextStyles.title.copyWith(color: c.textPrimary),
            ),
          ),
          if (countdown.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.xs),
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.schedule_rounded,
                      size: 18, color: c.textSecondary),
                ),
                const SizedBox(width: KpbSpacing.xs),
                Expanded(
                  child: Text(
                    countdown,
                    key: const ValueKey('comp-countdown'),
                    style: KpbTextStyles.body.copyWith(color: c.textSecondary),
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

class _RankCard extends StatelessWidget {
  const _RankCard({required this.standing});

  final ReferralCampaignStanding standing;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final s = standing;
    final rank = s.rank;
    final rankText = rank == null
        ? 'comp_rank_none'.tr
        : 'comp_rank_value'.trParams({'rank': '$rank'});
    final identity = s.publicName.isEmpty
        ? ''
        : (s.city.isEmpty
            ? s.publicName
            : 'comp_name_city'
                .trParams({'name': s.publicName, 'city': s.city}));
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (identity.isNotEmpty) ...[
            Text(identity, style: KpbTextStyles.titleMd),
            const SizedBox(height: KpbSpacing.sm),
          ],
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Text(
                    'comp_rank_label'.tr,
                    style: KpbTextStyles.label.copyWith(color: c.textSecondary),
                  ),
                ),
                Semantics(
                  label: 'comp_rank_a11y'.trParams({'rank': rankText}),
                  excludeSemantics: true,
                  child: Text(
                    rankText,
                    key: const ValueKey('comp-rank'),
                    style: (rank == null
                            ? KpbTextStyles.title
                            : KpbTextStyles.displaySm)
                        .copyWith(color: KpbColors.actionPrimary),
                  ),
                ),
              ],
            ),
          ),
          if (!s.rankable) ...[
            const SizedBox(height: KpbSpacing.sm),
            _Notice(
              key: const ValueKey('comp-unrankable'),
              icon: Icons.hourglass_empty_rounded,
              text: 'comp_unrankable'.tr,
            ),
          ],
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.color,
  });

  final String label;
  final String hint;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KpbTextStyles.titleMd),
                Text(
                  hint,
                  style: KpbTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: KpbSpacing.md),
          Text(
            '$value',
            style: KpbTextStyles.headlineSm.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  Future<void> _share() async {
    final link = buildInviteLink(
      source: ShareSource.competition,
      referralCode: code,
    );
    unawaited(AnalyticsService.instance.logReferralInviteShared());
    await SharePlus.instance.share(ShareParams(
      text: 'comp_share_message'.trParams({'code': code, 'link': link}),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'comp_your_code'.tr,
            style: KpbTextStyles.label.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  key: const ValueKey('comp-code'),
                  style: KpbTextStyles.title.copyWith(
                    color: KpbColors.actionPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'copy'.tr,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  KpbToast.success('referral_code_copied'.tr);
                },
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('comp-share'),
            onPressed: _share,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text('comp_share_cta'.tr),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.sm + KpbSpacing.xs),
      decoration: BoxDecoration(
        color: c.skyLight,
        borderRadius: BorderRadius.circular(KpbRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 18, color: KpbColors.actionPrimary),
          ),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: KpbTextStyles.bodySm.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
