// Ambassadeur surface (App-engagement handoff · US-032→035).
//
// A self-contained gamified referral space with its own 3-tab bottom nav —
// Tableau de bord / Filleuls / Retraits — recreated from `Ambassadeur App.dc.html`.
// Uses the handoff's navy #0F172A + blue #2563EB visual system (kept local to
// this surface). Data comes from GET /referrals/dashboard; the backend returns
// a sample preview until the student activates their space.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../../core/services/remote_feature_flags.dart';
import 'ambassador_competition_screen.dart';
import 'referral_screen.dart';
import '../../core/ui/components/kpb_toast.dart';

// Couleurs : tokens sémantiques centraux (KpbColors — architecture §10.2).
// Couleurs catégorielles des avatars (séries distinctes — exception §14 de
// l'architecture), déterministes par hash du nom. Valeurs = tokens.
const _avatarColors = [
  KpbColors.actionPrimary,
  KpbColors.success,
  KpbColors.decorIndigo,
  KpbColors.warning,
  KpbColors.businessSky,
  KpbColors.error,
];

Color _avatarColor(String seed) {
  var h = 0;
  for (final ch in seed.codeUnits) {
    h = (h * 31 + ch) & 0x7fffffff;
  }
  return _avatarColors[h % _avatarColors.length];
}

String _fmtFcfa(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${n < 0 ? '−' : ''}${buf.toString()} FCFA';
}

String _fmtCompact(int n) {
  if (n >= 1000) return '${(n / 1000).round()} k';
  return '$n';
}

class AmbassadorScreen extends StatefulWidget {
  const AmbassadorScreen({super.key});

  @override
  State<AmbassadorScreen> createState() => _AmbassadorScreenState();
}

class _AmbassadorScreenState extends State<AmbassadorScreen> {
  final _ctrl = Get.find<AppController>();

  AmbassadorDashboard? _dash;
  bool _loading = true;
  String? _error;
  int _tab = 0;
  bool _withdrawing = false;
  bool _withdrawn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ctrl.apiClient.getAmbassadorDashboard();
      if (mounted) setState(() => _dash = AmbassadorDashboard.fromApi(data));
    } catch (_) {
      if (mounted) setState(() => _error = 'amb_load_error'.tr);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTab(int i) {
    setState(() => _tab = i);
  }

  Future<void> _shareCode() async {
    final d = _dash;
    if (d == null) return;
    // @link → the smart store-redirect page, so the recipient has something
    // to tap (the message used to carry only the code, with no link at all).
    final msg = 'amb_share_message'.trParams({
      'code': d.ambassador.code,
      'link': AppConfig.appDownloadUrl,
    });
    await SharePlus.instance.share(ShareParams(text: msg));
    _toast('amb_toast_share'.tr);
  }

  Future<void> _withdraw() async {
    final d = _dash;
    if (d == null || _withdrawing || _withdrawn) return;
    if (!d.canWithdraw) {
      _toast(
          'amb_withdraw_min'
              .trParams({'amount': _fmtFcfa(d.minWithdrawalFCFA)}),
          kind: KpbToastKind.error);
      return;
    }
    setState(() => _withdrawing = true);
    try {
      final res = await _ctrl.apiClient.requestAmbassadorWithdrawal();
      final amount = (res['amountFCFA'] as num?)?.toInt() ?? d.withdrawableFCFA;
      if (mounted) {
        setState(() => _withdrawn = true);
        _toast('amb_toast_withdraw'.trParams({'amount': _fmtFcfa(amount)}),
            kind: KpbToastKind.success);
      }
    } catch (_) {
      _toast('amb_withdraw_error'.tr, kind: KpbToastKind.error);
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  void _toast(String msg, {KpbToastKind kind = KpbToastKind.info}) {
    if (!mounted) return;
    KpbToast.show(kind: kind, message: msg, context: context);
  }

  @override
  Widget build(BuildContext context) {
    final d = _dash;
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        title: Text('amb_appbar'.tr),
        backgroundColor: Colors.transparent,
      ),
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? _ErrorState(
                  message: _error ?? 'amb_load_error'.tr, onRetry: _load)
              : (AppConfig.ambassadorCashEnabled || d.activated)
                  // KPB-160: the cash surface (FCFA, leaderboard, withdrawals,
                  // self-activation) shows only for an ops-activated ambassador
                  // or when the programme is globally enabled — preserving
                  // active ambassadors regardless of the flag. Everyone else
                  // gets the application screen (no payout mechanics).
                  ? Column(
                      children: [
                        if (d.isSample) const _SampleBanner(),
                        Expanded(
                          // Render only the active tab, each in its OWN scroll
                          // view, so a short tab doesn't inherit the tallest
                          // tab's height (no dead scroll region). PageStorageKey
                          // preserves each tab's scroll offset across switches.
                          child: SingleChildScrollView(
                            key: PageStorageKey<int>(_tab),
                            child: switch (_tab) {
                              1 => _ReferralsTab(d: d),
                              2 => _PayoutTab(
                                  d: d,
                                  withdrawing: _withdrawing,
                                  withdrawn: _withdrawn,
                                  onWithdraw: _withdraw,
                                ),
                              _ => _DashboardTab(d: d, onShare: _shareCode),
                            },
                          ),
                        ),
                        _BottomNav(current: _tab, onTap: _goTab),
                      ],
                    )
                  // Build 57 (`features.referralLeaderboard`) : un
                  // ambassadeur SANS espace rémunéré qui participe à la
                  // compétition voit son classement à la place de l'écran de
                  // candidature (runbook §8, point 4). Non-participant, drapeau
                  // fermé ou backend plus ancien : la candidature, inchangée.
                  : RemoteFeatureFlags.instance.referralLeaderboardEnabled
                      ? const AmbassadorCompetitionView(
                          nonParticipant: _AmbassadorApplication(),
                        )
                      : const _AmbassadorApplication(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Application screen (KPB-160) — shown when the cash programme is gated: no
// FCFA, leaderboard, withdrawal or self-activation. Keeps the programme
// discoverable via an application path without exposing payout mechanics.
// ─────────────────────────────────────────────────────────────────────────────

class _AmbassadorApplication extends StatelessWidget {
  const _AmbassadorApplication();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: KpbColors.actionPrimarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.diversity_3_outlined,
                  size: 38, color: KpbColors.actionPrimary),
            ),
            const SizedBox(height: 24),
            Text(
              'amb_apply_title'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: KpbColors.brandNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'amb_apply_body'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KpbColors.textMuted,
                height: 1.45,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: KpbColors.actionPrimary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.support_agent_rounded),
                label: Text('amb_apply_cta_advisor'.tr),
                onPressed: () => openWhatsAppOrToast(
                  prefill: 'amb_apply_wa_prefill'.tr,
                  source: 'ambassador_application',
                  contextType: 'ambassador',
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Get.to(() => const ReferralScreen()),
              child: Text('amb_apply_cta_referral'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard tab
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.d, required this.onShare});
  final AmbassadorDashboard d;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final a = d.ambassador;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navy header
        Container(
          color: KpbColors.brandNavy,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(initials: a.initials, seed: a.displayName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.displayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        if (a.campus.isNotEmpty)
                          Text(a.campus,
                              style: const TextStyle(
                                  color: KpbColors.textFaint, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  if (a.rankLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: KpbColors.decorIndigo.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.workspace_premium,
                            size: 13, color: KpbColors.decorIndigoLight),
                        const SizedBox(width: 4),
                        Text(a.rankLabel,
                            style: const TextStyle(
                                color: KpbColors.decorIndigoLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Referral code card (dashed)
              DottedBorderBox(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('amb_code_label'.tr,
                              style: const TextStyle(
                                  color: KpbColors.decorSky,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7)),
                          const SizedBox(height: 2),
                          Text(a.code,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onShare,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: KpbColors.whatsapp,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.chat, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('amb_share'.tr,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                      child: _StatCard(
                          value: '${d.activeReferrals}',
                          label: 'amb_stat_active'.tr,
                          color: KpbColors.textPrimary)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatCard(
                          value: '${d.placed}',
                          label: 'amb_stat_placed'.tr,
                          color: KpbColors.success)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatCard(
                          value: _fmtCompact(d.earnedFCFA),
                          label: 'amb_stat_earned'.tr,
                          color: KpbColors.actionPrimary,
                          valueSize: 17)),
                ],
              ),
              const SizedBox(height: 13),
              _ObjectiveCard(d: d),
              const SizedBox(height: 13),
              _HowYouEarnCard(rewards: d.rewards),
              const SizedBox(height: 13),
              if (d.leaderboard.isNotEmpty)
                _LeaderboardCard(city: a.city, entries: d.leaderboard),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    this.valueSize = 21,
  });
  final String value;
  final String label;
  final Color color;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: KpbColors.textFaint)),
        ],
      ),
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({required this.d});
  final AmbassadorDashboard d;

  @override
  Widget build(BuildContext context) {
    final target = d.objectiveTarget <= 0 ? 1 : d.objectiveTarget;
    final ratio = (d.objectiveCurrent / target).clamp(0.0, 1.0);
    final remaining = (d.objectiveTarget - d.objectiveCurrent).clamp(0, 9999);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                    'amb_objective_title'
                        .trParams({'n': '${d.objectiveTarget}'}),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textPrimary)),
              ),
              Text('${d.objectiveCurrent} / ${d.objectiveTarget}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.actionPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: KpbColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation(KpbColors.actionPrimary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'amb_objective_hint'.trParams({
              'n': '$remaining',
              'bonus': _fmtFcfa(d.objectiveBonusFCFA),
              'target': '${d.objectiveTarget}',
            }),
            style: const TextStyle(fontSize: 11, color: KpbColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HowYouEarnCard extends StatelessWidget {
  const _HowYouEarnCard({required this.rewards});
  final List<AmbassadorReward> rewards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('amb_how_title'.tr,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 11),
          for (final r in rewards) ...[
            _RewardRow(reward: r),
            if (r != rewards.last) const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.reward});
  final AmbassadorReward reward;

  @override
  Widget build(BuildContext context) {
    final placed = reward.reason == 'referral_placed';
    final icon = placed ? Icons.school : Icons.person_add;
    final iconBg =
        placed ? KpbColors.successLight : KpbColors.actionPrimarySoft;
    final iconColor = placed ? KpbColors.success : KpbColors.actionPrimary;
    final label = placed ? 'amb_reward_placed'.tr : 'amb_reward_signup'.tr;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KpbColors.gray700)),
        ),
        const SizedBox(width: 8),
        Text('+${_fmtFcfa(reward.amountFCFA)}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: iconColor)),
      ],
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.city, required this.entries});
  final String city;
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              city.isEmpty
                  ? 'amb_leaderboard_title_generic'.tr
                  : 'amb_leaderboard_title'.trParams({'city': city}),
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 11),
          for (final e in entries) ...[
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${e.rank}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: (e.rank == 1 || e.rank == 3)
                              ? KpbColors.warning
                              : KpbColors.textMuted)),
                ),
                _Avatar(initials: e.initials, seed: e.name, size: 30),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              e.isMe ? FontWeight.w800 : FontWeight.w600,
                          color: KpbColors.textPrimary)),
                ),
                Text('amb_referrals_count'.trParams({'n': '${e.referrals}'}),
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textMuted)),
              ],
            ),
            if (e != entries.last) const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filleuls tab
// ─────────────────────────────────────────────────────────────────────────────

class _ReferralsTab extends StatelessWidget {
  const _ReferralsTab({required this.d});
  final AmbassadorDashboard d;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('amb_referrals_title'.tr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 2),
          Text('amb_referrals_sub'.trParams({'n': '${d.activeReferrals}'}),
              style:
                  const TextStyle(fontSize: 11.5, color: KpbColors.textMuted)),
          const SizedBox(height: 13),
          if (d.referrals.isEmpty)
            const _EmptyHint(
                icon: Icons.group_outlined, textKey: 'amb_referrals_empty')
          else
            for (final r in d.referrals) ...[
              _ReferralCard(entry: r),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 5),
          _TipBanner(text: 'amb_referrals_tip'.tr),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.entry});
  final ReferralEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(entry.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _Avatar(initials: entry.initials, seed: entry.name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textPrimary)),
                if (entry.note.isNotEmpty)
                  Text(entry.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: KpbColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: s.bg, borderRadius: BorderRadius.circular(100)),
                child: Text(s.label,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: s.fg)),
              ),
              const SizedBox(height: 3),
              Text(
                entry.gainFCFA > 0 ? '+${_fmtFcfa(entry.gainFCFA)}' : '—',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: entry.gainFCFA > 0
                        ? KpbColors.success
                        : KpbColors.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Retraits tab
// ─────────────────────────────────────────────────────────────────────────────

class _PayoutTab extends StatelessWidget {
  const _PayoutTab({
    required this.d,
    required this.withdrawing,
    required this.withdrawn,
    required this.onWithdraw,
  });
  final AmbassadorDashboard d;
  final bool withdrawing;
  final bool withdrawn;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('amb_payout_title'.tr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 2),
          Text('amb_payout_sub'.tr,
              style:
                  const TextStyle(fontSize: 11.5, color: KpbColors.textMuted)),
          const SizedBox(height: 13),
          // Balance card
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
                color: KpbColors.brandNavy,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('amb_balance_label'.tr,
                    style: const TextStyle(
                        color: KpbColors.decorSky,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(_fmtFcfa(withdrawn ? 0 : d.balanceFCFA),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7)),
                if (d.ambassador.payoutAccountMasked.isNotEmpty)
                  Text(
                      'amb_wave_account'.trParams(
                          {'account': d.ambassador.payoutAccountMasked}),
                      style: const TextStyle(
                          color: KpbColors.textFaint, fontSize: 11.5)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onWithdraw,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: withdrawn
                          ? KpbColors.success
                          : KpbColors.actionPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (withdrawing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        else ...[
                          const Icon(Icons.account_balance_wallet,
                              size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            withdrawn
                                ? 'amb_withdraw_pending'.tr
                                : 'amb_withdraw'.trParams(
                                    {'amount': _fmtFcfa(d.balanceFCFA)}),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text('amb_history'.tr,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: KpbColors.textFaint)),
          const SizedBox(height: 7),
          Container(
            decoration: _cardDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: d.history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: _EmptyHint(
                        icon: Icons.receipt_long_outlined,
                        textKey: 'amb_history_empty'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < d.history.length; i++) ...[
                        _HistoryRow(item: d.history[i]),
                        if (i < d.history.length - 1)
                          const Divider(
                              height: 1, color: KpbColors.surfaceMuted),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final AmbassadorHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final style = _historyStyle(item.kind);
    final positive = item.amountFCFA >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: style.bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(style.icon, size: 16, color: style.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: KpbColors.textPrimary)),
                if (item.date.isNotEmpty)
                  Text(item.date,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: KpbColors.textFaint)),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${_fmtFcfa(item.amountFCFA)}',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: positive ? KpbColors.success : KpbColors.error),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      border: Border.all(color: KpbColors.border),
      borderRadius: BorderRadius.circular(16),
    );

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.initials, required this.seed, required this.size});
  final String initials;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: _avatarColor(seed), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.32,
              fontWeight: FontWeight.w800)),
    );
  }
}

/// Dashed-border container used for the referral-code card in the navy header.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedRRectPainter(
        color: KpbColors.glassBorder,
        radius: 16,
        strokeWidth: 1.5,
        dashLength: 5,
        gapLength: 4,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KpbColors.glassBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle outline for [DottedBorderBox].
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final source = Path()..addRRect(rrect);
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        border:
            Border.all(color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates,
              size: 16, color: KpbColors.actionPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.actionPrimaryPressed)),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.textKey});
  final IconData icon;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 30, color: KpbColors.textFaint),
          const SizedBox(height: 8),
          Text(textKey.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KpbColors.textMuted)),
        ],
      ),
    );
  }
}

class _SampleBanner extends StatelessWidget {
  const _SampleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: KpbColors.goldLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              size: 16, color: KpbColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text('amb_sample_banner'.tr,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.warning)),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.space_dashboard, key: 'amb_nav_dashboard'),
    (icon: Icons.group, key: 'amb_nav_referrals'),
    (icon: Icons.account_balance_wallet, key: 'amb_nav_payout'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          4, 6, 4, 10 + MediaQuery.of(context).padding.bottom * 0.5),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 28,
                      decoration: BoxDecoration(
                        color: current == i
                            ? KpbColors.actionPrimarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(_items[i].icon,
                          size: 20,
                          color: current == i
                              ? KpbColors.actionPrimary
                              : KpbColors.textFaint),
                    ),
                    const SizedBox(height: 3),
                    Text(_items[i].key.tr,
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: current == i
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: current == i
                                ? KpbColors.actionPrimary
                                : KpbColors.textFaint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: KpbColors.textFaint),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

// Status + history visual maps.

class _StatusStyle {
  const _StatusStyle(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

_StatusStyle _statusStyle(ReferralMilestone s) {
  switch (s) {
    case ReferralMilestone.placed:
      return _StatusStyle(
          'amb_status_placed'.tr, KpbColors.successLight, KpbColors.success);
    case ReferralMilestone.applicationCreated:
      return _StatusStyle('amb_status_application'.tr,
          KpbColors.actionPrimarySoft, KpbColors.actionPrimary);
    case ReferralMilestone.quizCompleted:
      return _StatusStyle('amb_status_quiz'.tr,
          KpbColors.businessSky.withValues(alpha: 0.15), KpbColors.businessSky);
    case ReferralMilestone.premiumSubscribed:
      return _StatusStyle('amb_status_premium'.tr,
          KpbColors.lawPurple.withValues(alpha: 0.12), KpbColors.lawPurple);
    case ReferralMilestone.churned:
      return _StatusStyle(
          'amb_status_churned'.tr, KpbColors.errorLight, KpbColors.error);
    case ReferralMilestone.signedUp:
      return _StatusStyle(
          'amb_status_relance'.tr, KpbColors.warningLight, KpbColors.warning);
  }
}

class _HistoryStyle {
  const _HistoryStyle(this.icon, this.bg, this.fg);
  final IconData icon;
  final Color bg;
  final Color fg;
}

_HistoryStyle _historyStyle(String kind) {
  switch (kind) {
    case 'referral_placed':
      return const _HistoryStyle(
          Icons.school, KpbColors.successLight, KpbColors.success);
    case 'referral_signup':
      return const _HistoryStyle(Icons.person_add, KpbColors.actionPrimarySoft,
          KpbColors.actionPrimary);
    case 'bonus_leaderboard':
      return const _HistoryStyle(
          Icons.workspace_premium, KpbColors.warningLight, KpbColors.warning);
    case 'withdrawal':
      return const _HistoryStyle(Icons.account_balance_wallet,
          KpbColors.surfaceMuted, KpbColors.textMuted);
    default:
      return const _HistoryStyle(
          Icons.payments, KpbColors.actionPrimarySoft, KpbColors.actionPrimary);
  }
}
