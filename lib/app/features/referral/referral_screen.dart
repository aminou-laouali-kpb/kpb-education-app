import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../../core/utils/external_link.dart';

/// WhatsApp-native referral loop (KPB-69 + KPB-77): the student shares a tracked
/// code, can redeem a friend's code, and spends earned credits (one per referred
/// friend who creates a case) on a no-cash WhatsApp advisor review voucher.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _inviteOnWhatsApp() async {
    final text = _inviteMessage();
    final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    unawaited(AnalyticsService.instance.logReferralInviteShared());
    if (!await kpbOpenExternalUrl(waUri)) {
      // WhatsApp not installed → OS share sheet with the same message.
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _redeeming = true);
    try {
      final res = await _ctrl.apiClient.redeemReferral(code);
      final attributed = res['attributed'] == true;
      final already = res['alreadyReferred'] == true;
      if (attributed && !already) {
        unawaited(AnalyticsService.instance.logReferralRedeemed());
      }
      if (!mounted) return;
      KpbToast.show(
        kind: already
            ? KpbToastKind.info
            : (attributed ? KpbToastKind.success : KpbToastKind.error),
        message: already
            ? 'referral_redeemed_already'.tr
            : (attributed
                ? 'referral_redeemed_ok'.tr
                : 'referral_redeem_error'.tr),
      );
      if (attributed && !already) _codeCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      KpbToast.error('referral_redeem_error'.tr);
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
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
                        child: FilledButton.icon(
                          onPressed: _code.isEmpty ? null : _inviteOnWhatsApp,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text('referral_invite_whatsapp'.tr),
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
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'referral_code_hint'.tr,
                        ),
                      ),
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
