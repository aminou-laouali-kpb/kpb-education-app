import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/referral_attribution.dart';
import '../../core/ui/kpb_components.dart';
import '../referral/referral_outcome_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// « Tu as un code de parrain ? » — la dernière étape, FACULTATIVE, de
// l'onboarding élève (drapeau `features.referralOnboardingCode`, build 57).
//
// Montrée APRÈS la synchronisation du profil (`completeOnboardingSynced`) : le
// rattachement `POST /referrals/redeem` part donc sur un profil déjà connu du
// serveur. Elle ne bloque JAMAIS l'entrée dans l'app :
//
//   · « Passer » (et le retour système) mène toujours plus loin ;
//   · code accepté, ou déjà parrainé (succès silencieux) → plus loin ;
//   · hors ligne, limite horaire, panne → le code est GARDÉ (l'écran
//     Parrainage le proposera), un message le dit, et on va plus loin ;
//   · code inconnu, auto-parrainage, refus → le message est dans le champ,
//     l'élève corrige ou passe.
//
// Prérempli par le Play Install Referrer quand il a trouvé un code : jamais de
// rattachement silencieux, l'élève CONFIRME en appuyant sur « Valider ».
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingReferralStep extends StatefulWidget {
  const OnboardingReferralStep({
    super.key,
    required this.onFinished,
    this.apiClient,
    this.attribution,
  });

  /// Appelé une seule fois, quand l'élève sort de l'étape (quelle que soit
  /// l'issue). L'onboarding y mène à l'écran « aha ».
  final VoidCallback onFinished;

  /// Le client (défaut : celui de l'[AppController]).
  final AppApiClient? apiClient;

  /// Le service de parrainage (défaut : l'instance partagée).
  final ReferralAttribution? attribution;

  @override
  State<OnboardingReferralStep> createState() => _OnboardingReferralStepState();
}

class _OnboardingReferralStepState extends State<OnboardingReferralStep> {
  static const _surface = 'onboarding';

  final _codeCtrl = TextEditingController();
  PendingReferralCode? _pending;
  bool _busy = false;
  bool _finished = false;
  String? _errorKey;

  ReferralAttribution get _attribution =>
      widget.attribution ?? ReferralAttribution.instance;

  String get _prefill => referralPrefillWire(_pending);

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onTyped);
    unawaited(_loadPrefill());
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_onTyped);
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onTyped() {
    // Le bouton suit le champ, et une erreur affichée s'efface à la frappe.
    if (!mounted) return;
    setState(() => _errorKey = null);
  }

  Future<void> _loadPrefill() async {
    final pending = await _attribution.pendingCode();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      if (pending != null && _codeCtrl.text.isEmpty) {
        _codeCtrl.text = pending.code;
      }
    });
    unawaited(AnalyticsService.instance
        .logReferralCodePromptViewed(surface: _surface, prefill: _prefill));
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  void _skip() {
    if (_busy || _finished) return;
    unawaited(AnalyticsService.instance
        .logReferralCodeSkipped(surface: _surface, prefill: _prefill));
    _finish();
  }

  Future<void> _validate() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _busy || _finished) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    final api = widget.apiClient ?? Get.find<AppController>().apiClient;
    final outcome = await _attribution.redeem(api, code);
    unawaited(AnalyticsService.instance.logReferralCodeSubmitted(
      surface: _surface,
      prefill: _prefill,
      result: outcome.wireName,
    ));
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case ReferralRedeemOutcome.attributed:
        unawaited(AnalyticsService.instance.logReferralRedeemed());
        unawaited(KpbHaptics.confirm());
        KpbToast.success(referralOutcomeMessageKey(outcome).tr);
        _finish();
      case ReferralRedeemOutcome.alreadyReferred:
        // Succès silencieux : l'élève a déjà un parrain, rien à lui reprocher.
        _finish();
      case ReferralRedeemOutcome.unknownCode:
      case ReferralRedeemOutcome.selfReferral:
      case ReferralRedeemOutcome.notAllowed:
        unawaited(KpbHaptics.error());
        setState(() => _errorKey = referralOutcomeMessageKey(outcome));
      case ReferralRedeemOutcome.rateLimited:
      case ReferralRedeemOutcome.offline:
      case ReferralRedeemOutcome.error:
        KpbToast.info(referralOutcomeMessageKey(outcome).tr);
        _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final canValidate = _codeCtrl.text.trim().isNotEmpty && !_busy;
    final prefilledFromLink =
        _pending?.origin == PendingReferralOrigin.installReferrer &&
            _codeCtrl.text.trim().toUpperCase() == _pending?.code;
    return PopScope(
      canPop: false,
      // Le retour système vaut « Passer » : l'étape ne retient personne.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _skip();
      },
      child: Scaffold(
        backgroundColor: KpbColors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(KpbSpacing.pagePad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: KpbSpacing.lg),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ExcludeSemantics(
                          child: Icon(
                            Icons.card_giftcard_rounded,
                            size: 36,
                            color: KpbColors.actionPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: KpbSpacing.md),
                      Semantics(
                        header: true,
                        child: Text(
                          'onb_ref_title'.tr,
                          style: KpbTextStyles.headlineSm
                              .copyWith(color: KpbColors.brandNavy),
                        ),
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      Text(
                        'onb_ref_subtitle'.tr,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: KpbColors.textMuted),
                      ),
                      const SizedBox(height: KpbSpacing.lg),
                      TextField(
                        key: const ValueKey('onb-ref-code'),
                        controller: _codeCtrl,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _validate(),
                        decoration: InputDecoration(
                          labelText: 'referral_code_hint'.tr,
                          errorText: _errorKey?.tr,
                          errorMaxLines: 3,
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                      if (prefilledFromLink) ...[
                        const SizedBox(height: KpbSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.link_rounded,
                                size: 18, color: c.textSecondary),
                            const SizedBox(width: KpbSpacing.sm),
                            Expanded(
                              child: Text(
                                'onb_ref_prefilled_note'.tr,
                                style: KpbTextStyles.caption
                                    .copyWith(color: c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: KpbSpacing.md),
                      Text(
                        'onb_ref_later_note'.tr,
                        style: KpbTextStyles.caption
                            .copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  KpbSpacing.pagePad,
                  KpbSpacing.md,
                  KpbSpacing.pagePad,
                  KpbSpacing.md + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  border:
                      const Border(top: BorderSide(color: KpbColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: const ValueKey('onb-ref-validate'),
                      onPressed: canValidate ? _validate : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: KpbColors.actionPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: KpbTextStyles.titleMd,
                      ),
                      child: _busy
                          ? Semantics(
                              label: 'async_loading'.tr,
                              child: const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            )
                          : Text('referral_redeem_cta'.tr),
                    ),
                    const SizedBox(height: KpbSpacing.xs),
                    TextButton(
                      key: const ValueKey('onb-ref-skip'),
                      onPressed: _busy ? null : _skip,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: KpbColors.textMuted,
                      ),
                      child: Text('skip'.tr),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
