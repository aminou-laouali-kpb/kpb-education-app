import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/referral_campaign.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/referral_attribution.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../../core/utils/external_link.dart';
import '../../core/utils/share_origin.dart';
import 'ambassador_competition_screen.dart';
import 'referral_outcome_messages.dart';

/// WhatsApp-native referral loop (KPB-69 + KPB-77): the student shares a tracked
/// code, can redeem a friend's code, and spends earned credits (one per referred
/// friend who creates a case) on a no-cash WhatsApp advisor review voucher.
///
/// Build 57 : le champ « code d'un ami » est prérempli par le code en attente
/// (lien d'invitation via le Play Install Referrer, ou code saisi à
/// l'onboarding sans réseau) — l'élève CONFIRME toujours ; et un participant à
/// la compétition ambassadeurs y trouve l'entrée de son classement
/// (`features.referralLeaderboard`).
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key, this.attribution});

  /// Le service de parrainage (défaut : l'instance partagée).
  final ReferralAttribution? attribution;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _ctrl = Get.find<AppController>();
  final _codeCtrl = TextEditingController();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _redeeming = false;
  bool _redeemingVoucher = false;
  PendingReferralCode? _pending;
  ReferralCampaignStanding? _competition;

  ReferralAttribution get _attribution =>
      widget.attribution ?? ReferralAttribution.instance;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_loadPending());
    if (RemoteFeatureFlags.instance.referralLeaderboardEnabled) {
      unawaited(_loadCompetition());
    }
  }

  /// Le code en attente de confirmation, prérempli — jamais validé sans l'élève.
  Future<void> _loadPending() async {
    final pending = await _attribution.pendingCode();
    if (!mounted || pending == null) return;
    setState(() {
      _pending = pending;
      if (_codeCtrl.text.isEmpty) _codeCtrl.text = pending.code;
    });
    unawaited(AnalyticsService.instance.logReferralCodePromptViewed(
      surface: 'referral_screen',
      prefill: referralPrefillWire(pending),
    ));
  }

  /// L'entrée « Compétition ambassadeurs » : seulement pour un participant, et
  /// sans bruit en cas d'échec (l'écran Parrainage ne dépend pas de la
  /// compétition).
  Future<void> _loadCompetition() async {
    try {
      final standing = ReferralCampaignStanding.fromJson(
        await _ctrl.apiClient.getCurrentReferralCampaign(),
      );
      if (mounted && standing.participating) {
        setState(() => _competition = standing);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _ctrl.apiClient.getMyReferral();
      await _ctrl.refreshReviewCredits();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      // Stay graceful — the screen shows a retry-able empty state.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Spend a credit for a WhatsApp advisor review voucher (KPB-77). No cash:
  /// on success the student gets a code to show their advisor on WhatsApp.
  Future<void> _redeemVoucher() async {
    if (_ctrl.reviewCredits < 1 || _redeemingVoucher) return;
    setState(() => _redeemingVoucher = true);
    try {
      final res = await _ctrl.redeemReviewVoucher(const Uuid().v4());
      if (!mounted) return;
      setState(() {}); // reflect the new balance
      if (res['ok'] == true) {
        await _showVoucherDialog((res['voucherCode'] as String?) ?? '');
      } else {
        KpbToast.info('referral_credits_none'.tr);
      }
    } catch (_) {
      if (!mounted) return;
      KpbToast.error('referral_voucher_error'.tr);
    } finally {
      if (mounted) setState(() => _redeemingVoucher = false);
    }
  }

  Future<void> _showVoucherDialog(String code) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('referral_voucher_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('referral_voucher_body'.tr),
            const SizedBox(height: KpbSpacing.md),
            SelectableText(
              code.isEmpty ? '—' : code,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: KpbColors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('close'.tr),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              openWhatsAppOrToast(
                prefill: kpbWhatsAppPrefill(
                  custom: 'referral_voucher_whatsapp_prefill'
                      .trParams({'code': code}),
                ),
                source: 'referral_voucher',
                contextType: 'referral_reward',
              );
            },
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: Text('referral_voucher_whatsapp_cta'.tr),
          ),
        ],
      ),
    );
  }

  String get _code => (_data?['code'] as String?) ?? '';
  int _stat(String k) => (_data?[k] as num?)?.toInt() ?? 0;

  // @link → the smart store-redirect page (App Store / Play Store detection),
  // so the invited friend has something to tap, not just a code to remember.
  String _inviteMessage() => 'referral_invite_message'.trParams({
        'code': _code,
        'link': AppConfig.appDownloadUrl,
      });

  Future<void> _inviteOnWhatsApp(BuildContext origin) async {
    final text = _inviteMessage();
    final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    unawaited(AnalyticsService.instance.logReferralInviteShared());
    if (!await kpbOpenExternalUrl(waUri)) {
      // WhatsApp not installed → OS share sheet with the same message.
      if (origin.mounted) await kpbShare(origin, text: text);
    }
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty || _redeeming) return;
    setState(() => _redeeming = true);
    final prefill = referralPrefillWire(_pending);
    // L'en-tête `X-KPB-Device-Id` (identifiant d'installation) part avec CETTE
    // requête seulement — voir ReferralAttribution.redeem.
    final outcome = await _attribution.redeem(_ctrl.apiClient, code);
    unawaited(AnalyticsService.instance.logReferralCodeSubmitted(
      surface: 'referral_screen',
      prefill: prefill,
      result: outcome.wireName,
    ));
    if (outcome == ReferralRedeemOutcome.attributed) {
      unawaited(AnalyticsService.instance.logReferralRedeemed());
    }
    if (!mounted) return;
    setState(() {
      _redeeming = false;
      if (outcome.isSuccess) {
        _pending = null;
        _codeCtrl.clear();
      } else if (!outcome.isRetryable && _pending?.code == code) {
        _pending = null;
      }
    });
    KpbToast.show(
      kind: switch (outcome) {
        ReferralRedeemOutcome.attributed => KpbToastKind.success,
        ReferralRedeemOutcome.unknownCode ||
        ReferralRedeemOutcome.selfReferral ||
        ReferralRedeemOutcome.notAllowed =>
          KpbToastKind.error,
        _ => KpbToastKind.info,
      },
      message: referralOutcomeMessageKey(outcome, onReferralScreen: true).tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('referral_title'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(KpbSpacing.pagePad),
              children: [
                Text('referral_intro'.tr,
                    style: TextStyle(color: context.kpb.textSecondary)),
                const SizedBox(height: KpbSpacing.lg),

                // ── Compétition ambassadeurs (build 57) ─────────────
                if (_competition != null) ...[
                  _CompetitionEntry(standing: _competition!),
                  const SizedBox(height: KpbSpacing.lg),
                ],

                // ── My code ─────────────────────────────────────────
                KpbCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('referral_your_code'.tr,
                          style: KpbTextStyles.titleMd),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _code.isEmpty ? '—' : _code,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: KpbColors.blue,
                              ),
                            ),
                          ),
                          if (_code.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              tooltip: 'copy'.tr,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _code));
                                KpbToast.success('referral_code_copied'.tr);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: KpbSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: Builder(
                          builder: (button) => FilledButton.icon(
                            onPressed: _code.isEmpty
                                ? null
                                : () => _inviteOnWhatsApp(button),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: Text('referral_invite_whatsapp'.tr),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KpbSpacing.lg),

                // ── Referral reward credits (KPB-77) ────────────────
                KpbCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text('referral_credits_title'.tr,
                                style: KpbTextStyles.titleMd),
                          ),
                          Text(
                            '${_ctrl.reviewCredits}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: KpbColors.blue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('referral_credits_label'.tr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.kpb.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('referral_credits_intro'.tr,
                          style: TextStyle(
                              fontSize: 13, color: context.kpb.textSecondary)),
                      const SizedBox(height: KpbSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              (_ctrl.reviewCredits < 1 || _redeemingVoucher)
                                  ? null
                                  : _redeemVoucher,
                          icon: _redeemingVoucher
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.card_giftcard_rounded,
                                  size: 18),
                          label: Text('referral_redeem_voucher_cta'.tr),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KpbSpacing.lg),

                // ── Stats ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        value: '${_stat('signedUpCount')}',
                        label: 'referral_friends_joined'.tr,
                      ),
                    ),
                    const SizedBox(width: KpbSpacing.md),
                    Expanded(
                      child: _StatTile(
                        value: '${_stat('caseCreatedCount')}',
                        label: 'referral_friends_cases'.tr,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KpbSpacing.lg),

                // ── Redeem a friend's code ──────────────────────────
                KpbCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('referral_have_code'.tr,
                          style: KpbTextStyles.titleMd),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('referral-code-field'),
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        // La mention « code repris de ton lien » suit le champ.
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'referral_code_hint'.tr,
                        ),
                      ),
                      if (_pending != null &&
                          _codeCtrl.text.trim().toUpperCase() ==
                              _pending!.code) ...[
                        const SizedBox(height: KpbSpacing.xs),
                        Text(
                          _pending!.origin ==
                                  PendingReferralOrigin.installReferrer
                              ? 'referral_pending_note'.tr
                              : 'referral_pending_typed_note'.tr,
                          key: const ValueKey('referral-pending-note'),
                          style: KpbTextStyles.caption
                              .copyWith(color: context.kpb.textSecondary),
                        ),
                      ],
                      const SizedBox(height: KpbSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _redeeming ? null : _redeem,
                          child: _redeeming
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text('referral_redeem_cta'.tr),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// L'entrée vers l'écran « Compétition ambassadeurs », pour un participant.
class _CompetitionEntry extends StatelessWidget {
  const _CompetitionEntry({required this.standing});

  final ReferralCampaignStanding standing;

  @override
  Widget build(BuildContext context) {
    final rank = standing.rank;
    return KpbCard(
      key: const ValueKey('referral-competition-entry'),
      onTap: () => Get.to(() => const AmbassadorCompetitionScreen()),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.emoji_events_outlined,
                color: KpbColors.actionPrimary),
          ),
          const SizedBox(width: KpbSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('comp_title'.tr, style: KpbTextStyles.titleMd),
                Text(
                  rank == null
                      ? 'comp_entry_sub'.tr
                      : 'comp_rank_a11y'.trParams({
                          'rank': 'comp_rank_value'.trParams({'rank': '$rank'}),
                        }),
                  style: KpbTextStyles.caption,
                ),
              ],
            ),
          ),
          const ExcludeSemantics(child: Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: KpbColors.blue)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.kpb.textSecondary)),
        ],
      ),
    );
  }
}
