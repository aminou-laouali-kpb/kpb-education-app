import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/services/coach_service.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../../core/ui/app_tokens.dart';
import 'premium_waitlist_controller.dart';
import '../../core/ui/components/kpb_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Karatou Premium — App-engagement handoff (navy/blue).
//
// HONEST-PRODUCT NOTE: there is NO Premium product, price, subscription or
// payment anywhere in the app or backend, and Karatou does no in-app checkout
// (users are helped by a KPB advisor over WhatsApp — see the Parent surface
// `parent_premium_cta` and the AI-coach "Premium coming soon" copy). So this
// screen deliberately does NOT render the design's price ("4 900 FCFA/month"),
// the "Pay on karatou.app/premium" checkout, the "YOUR KARATOU ID — IT
// IDENTIFIES YOUR PAYMENT" block, or any billing state. It is an honest
// "coming soon / activate via a KPB advisor" screen. The single free-vs-premium
// row is the ONE real, verifiable limit: the AI Coach weekly quota (read live
// from CoachService, default 5). The lone CTA hands off to the WhatsApp advisor.
//
// La liste d'attente ajoutée en 2026-09 ne change RIEN à ce qui précède : c'est
// une inscription GRATUITE et sans engagement, qui n'affiche ni prix ni moyen
// de paiement et n'ouvre aucun tunnel d'achat. Elle enregistre « préviens-moi à
// l'ouverture », rien d'autre — et le back-office s'en sert pour compter la
// demande avant de construire le service.
// ─────────────────────────────────────────────────────────────────────────────

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [KpbColors.brandNavy, KpbColors.heroIndigo],
);

const _amberGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    KpbColors.gold,
    Color(0xFFFDE68A), // kpb-allow-color: dégradé premium (gold → amber-200)
  ],
);

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // Real free-tier weekly AI-coach quota. Defaults to the documented free
  // limit (5) and is refreshed from the live quota when available.
  int _freeWeeklyLimit = 5;

  late final PremiumWaitlistController _waitlist;
  late final bool _isGuest;
  late final bool _isStudent;

  @override
  void initState() {
    super.initState();
    final app = Get.find<AppController>();
    _isGuest = app.isGuestMode;
    // Le serveur refuse l'écriture aux comptes parent et partenaire
    // (`premium-waitlist.controller.ts`). L'écran le dit AVANT le tap plutôt
    // que de laisser partir une requête dont la seule issue est un 403 que le
    // client avalerait — un bouton qui ne fait rien est indiscernable d'un bug.
    _isStudent = app.isStudent;
    // `AppApiClient` n'est PAS enregistré dans GetX : il vit sur AppController,
    // qui l'a construit. Un `Get.find<AppApiClient>()` aurait levé au premier
    // montage réel, et jamais dans un test qui l'injecte à la main.
    _waitlist = PremiumWaitlistController(apiClient: app.apiClient);
    _loadQuota();
    // Un invité n'a pas de session : l'appel partirait pour revenir en 401.
    if (!_isGuest) _waitlist.load();
  }

  @override
  void dispose() {
    _waitlist.dispose();
    super.dispose();
  }

  /// Envoie l'invité sur le mur de conversion du dépôt.
  ///
  /// Il quitte le mode invité, remet l'onboarding à faire et journalise la
  /// provenance — sans quoi le routeur de démarrage le renverrait droit dans la
  /// coquille invité, c'est-à-dire dans la boucle que ce mur rompt.
  Future<void> _openGuestGate() async {
    await Get.to<void>(
      () => Scaffold(
        appBar: AppBar(title: Text('premium_screen_title'.tr)),
        body: const SafeArea(
          child: KpbGuestGate(
            source: 'premium_waitlist_gate',
            titleKey: 'guest_premium_waitlist_title',
            bodyKey: 'guest_premium_waitlist_body',
            ctaKey: 'guest_premium_waitlist_cta',
            icon: Icons.workspace_premium_outlined,
          ),
        ),
      ),
    );
  }

  Future<void> _join() async {
    if (_isGuest) return _openGuestGate();
    final ok = await _waitlist.join();
    if (!mounted) return;
    if (!ok) _showFailure();
  }

  /// Confirme puis exécute le retrait.
  ///
  /// La confirmation n'est pas un réflexe : sans elle, un tap accidentel
  /// effacerait l'inscription, et rien n'annulerait le geste — la ligne est
  /// supprimée, pas archivée.
  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('premium_waitlist_leave'.tr),
        content: Text('premium_waitlist_notice'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('premium_waitlist_leave'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _waitlist.leave();
    if (!mounted) return;
    // Le retour est dit dans les DEUX sens : un retrait qui échoue en silence
    // laisserait l'étudiant croire qu'il n'est plus dans la liste alors qu'il y
    // est — le même mensonge que « c'est noté » sur une ligne jamais écrite,
    // dans l'autre direction.
    if (!ok) _showFailure();
  }

  void _showFailure() {
    final key = switch (_waitlist.failure) {
      PremiumWaitlistFailure.network => 'premium_waitlist_error_network',
      PremiumWaitlistFailure.unauthorized =>
        'premium_waitlist_error_unauthorized',
      _ => 'premium_waitlist_error_server',
    };
    KpbToast.error(key.tr, context: context);
  }

  Future<void> _loadQuota() async {
    final userId = Get.find<AppController>().profile?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      final quota = await CoachService().fetchQuota(userId);
      if (!mounted) return;
      setState(() => _freeWeeklyLimit = quota.limit);
    } catch (_) {
      // Keep the documented default; this screen is informational.
    }
  }

  void _contactAdvisor() {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill: 'premium_wa_prefill'.tr,
      source: 'student_premium',
      contextType: 'premium',
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = '$_freeWeeklyLimit';

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'premium_screen_title'.tr,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _heroCard(count),
                  const SizedBox(height: 14),
                  _pitchCard(),
                  const SizedBox(height: 14),
                  // Le seul bloc interactif de l'écran, placé AVANT le tableau
                  // comparatif : c'est la seule chose qu'on demande à
                  // l'étudiant de faire ici, et l'enterrer sous deux cartes
                  // descriptives aurait mesuré le défilement plutôt que
                  // l'intérêt.
                  AnimatedBuilder(
                    animation: _waitlist,
                    builder: (_, __) => _waitlistCard(),
                  ),
                  const SizedBox(height: 14),
                  _comparisonCard(count),
                  const SizedBox(height: 14),
                  _howToCard(),
                ],
              ),
            ),

            // ── Advisor CTA (no checkout, no price) ─────────────────────────
            _ctaBar(),
          ],
        ),
      ),
    );
  }

  // ── Hero: value proposition framed against the REAL free limit ────────────
  Widget _heroCard(String count) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: KpbShadow.mediumNavy,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: _amberGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: KpbColors.brandNavy, size: 24),
              ),
              const SizedBox(width: 12),
              _SoonPill(label: 'premium_badge_soon'.tr),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'premium_hero_title'.tr,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'premium_hero_sub'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: KpbColors.textFaint,
            ),
          ),
          const SizedBox(height: 14),
          _ValueRow(text: 'premium_value_ai_coach'.trParams({'count': count})),
          const SizedBox(height: 8),
          _ValueRow(text: 'premium_value_advisors'.tr),
          const SizedBox(height: 8),
          _ValueRow(text: 'premium_value_more_soon'.tr),
        ],
      ),
    );
  }

  // ── Ce qu'est le Pass ─────────────────────────────────────────────────────
  //
  // Décrit un service À VENIR — le badge « Bientôt disponible » du hero reste
  // au-dessus. Aucun prix, aucun bouton d'achat, aucun verbe « s'abonner » :
  // Karatou n'encaisse rien dans l'application.
  Widget _pitchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'premium_pitch_title'.tr,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: KpbColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'premium_pitch_body'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: KpbColors.gray700,
            ),
          ),
          const SizedBox(height: 12),
          for (final key in const [
            'premium_pitch_point_shortlist',
            'premium_pitch_point_documents',
            'premium_pitch_point_review',
            'premium_pitch_point_deadlines',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle_rounded,
                        size: 16, color: KpbColors.actionPrimary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      key.tr,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: KpbColors.gray700,
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

  // ── Liste d'attente ───────────────────────────────────────────────────────
  //
  // Inscription gratuite, sans engagement, sans prix affiché. Elle enregistre
  // « préviens-moi à l'ouverture » et rien d'autre.
  //
  // Trois états, et le troisième n'est pas décoratif : un compte parent ou
  // partenaire se voit dire pourquoi il n'y a pas de bouton, plutôt que d'en
  // taper un dont la seule issue serait un 403 avalé en silence.
  Widget _waitlistCard() {
    final registered = _waitlist.registered;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: registered ? KpbColors.actionPrimarySoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: registered ? KpbColors.actionPrimary : KpbColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                registered
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: 18,
                color: KpbColors.actionPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  registered
                      ? 'premium_waitlist_joined_title'.tr
                      : 'premium_waitlist_title'.tr,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            registered
                ? 'premium_waitlist_joined_body'.trParams({'date': _joinedOn()})
                : 'premium_waitlist_body'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: KpbColors.gray700,
            ),
          ),
          const SizedBox(height: 12),
          if (registered)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _waitlist.busy ? null : _confirmLeave,
                child: Text('premium_waitlist_leave'.tr),
              ),
            )
          else if (!_isGuest && !_isStudent)
            Text(
              'premium_waitlist_student_only'.tr,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: KpbColors.textFaint,
              ),
            )
          else ...[
            // Le texte de consentement est AU-DESSUS du bouton, jamais après :
            // c'est ce que `kPremiumWaitlistConsentVersion` désigne, et une
            // mention lue après le tap n'aurait rien prouvé.
            Text(
              'premium_waitlist_notice'.tr,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: KpbColors.textFaint,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: _waitlist.busy ? null : _join,
                style: FilledButton.styleFrom(
                  backgroundColor: KpbColors.actionPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _waitlist.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'premium_waitlist_cta'.tr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// La date d'inscription, telle que l'étudiant la lit.
  ///
  /// Rend une chaîne vide si le serveur n'a pas donné de date : mieux vaut une
  /// phrase amputée qu'un « null » affiché, et l'inscription elle-même est déjà
  /// confirmée par le titre de la carte.
  String _joinedOn() {
    final at = _waitlist.entry.registeredAt;
    if (at == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year}';
  }

  // ── Free vs Premium: ONLY the one real, verifiable row (AI coach quota) ────
  Widget _comparisonCard(String count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Column headers.
          Row(
            children: [
              _cell('premium_compare_feature'.tr,
                  flex: 14, header: true, align: TextAlign.left),
              _cell('premium_compare_free'.tr,
                  flex: 9, header: true, leftBorder: true),
              _cell('premium_compare_premium'.tr,
                  flex: 9, header: true, leftBorder: true, highlight: true),
            ],
          ),
          Container(height: 1, color: KpbColors.surfaceMuted),
          // The single honest row.
          Row(
            children: [
              _cell('premium_row_ai_coach'.tr,
                  flex: 14, align: TextAlign.left, strong: true),
              _cell('premium_free_ai_coach'.trParams({'count': count}),
                  flex: 9, leftBorder: true),
              _cell('premium_unlimited_soon'.tr,
                  flex: 9, leftBorder: true, highlight: true, strong: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(
    String text, {
    required int flex,
    bool header = false,
    bool leftBorder = false,
    bool highlight = false,
    bool strong = false,
    TextAlign align = TextAlign.center,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? KpbColors.actionPrimarySoft : Colors.transparent,
          border: leftBorder
              ? const Border(left: BorderSide(color: KpbColors.surfaceMuted))
              : null,
        ),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: header ? 10 : 12,
            height: 1.3,
            letterSpacing: header ? 0.4 : 0,
            fontWeight: header
                ? FontWeight.w800
                : (strong ? FontWeight.w800 : FontWeight.w600),
            color: header
                ? (highlight ? KpbColors.actionPrimary : KpbColors.textFaint)
                : (highlight ? KpbColors.actionPrimary : KpbColors.gray700),
          ),
        ),
      ),
    );
  }

  // ── How to activate (honest: no in-app payment) ───────────────────────────
  Widget _howToCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'premium_how_title'.tr,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: KpbColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'premium_how_body'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: KpbColors.gray700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: KpbColors.actionPrimarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 16, color: KpbColors.actionPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'premium_no_payment_note'.tr,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: KpbColors.actionPrimaryPressed,
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

  Widget _ctaBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _contactAdvisor,
          style: FilledButton.styleFrom(
            backgroundColor: KpbColors.whatsapp,
            foregroundColor: KpbColors.brandNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.chat_rounded, size: 20),
          label: Text(
            'premium_advisor_cta'.tr,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Cible tactile de 48 dp et libellé pour le lecteur d'écran ; le disque
    // reste de 38 (audit build 57, T4-08).
    return Semantics(
      button: true,
      label: 'a11y_back'.tr,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: KpbColors.border),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 19, color: KpbColors.brandNavy),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoonPill extends StatelessWidget {
  const _SoonPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: KpbColors.decorSky.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: KpbColors.decorSky,
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.check_circle_rounded,
              size: 16, color: KpbColors.successOnDark),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: KpbColors.gray200,
            ),
          ),
        ),
      ],
    );
  }
}
