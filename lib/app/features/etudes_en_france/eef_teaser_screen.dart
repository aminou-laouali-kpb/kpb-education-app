import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/eef_calendar.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_interest_controller.dart';
import 'eef_interest_sheet.dart';
import 'eef_official_links.dart';

/// La vitrine de l'espace « Études en France » — Phase 0.
///
/// ## Ce que cet écran fait, et ce qu'il refuse de faire
///
/// Il annonce un espace qui n'existe pas encore, et demande à l'étudiant s'il
/// l'intéresse. Trois disciplines l'encadrent, chacune tirée d'un défaut que ce
/// dépôt a déjà réparé une fois :
///
///  1. **Aucune fonctionnalité annoncée au présent.** « en préparation »,
///     jamais « disponible ». Le module `premium_screen.dart` porte la même
///     règle et explique pourquoi : afficher un prix et un tunnel de paiement
///     qui n'existent pas, c'est mentir à l'écran.
///
///  2. **Aucune date en dur.** La fenêtre de campagne vient de `/config/app`
///     via [EefCalendar]. Une build vit environ quatre-vingt-dix jours ; une
///     date d'ouverture compilée devient fausse pendant sa vie utile et n'est
///     plus corrigible sans passer par les stores. Quand rien n'est servi,
///     l'écran ne dit RIEN sur les dates — il n'invente pas une échéance qu'un
///     étudiant utiliserait pour organiser son dossier.
///
///  3. **Aucun succès optimiste.** Le bouton n'affiche « c'est noté » que
///     lorsque le serveur l'a confirmé (voir [EefInterestController]).
///
/// ## Sur le nom
///
/// L'espace s'appelle « Études en France », pas « Campus France » : Campus
/// France est un opérateur de l'État français et rien n'atteste d'un
/// partenariat. On nomme la procédure qu'on accompagne, on n'emprunte pas
/// l'enseigne — et une mention de non-affiliation le dit à l'écran.
class EefTeaserScreen extends StatefulWidget {
  const EefTeaserScreen({super.key, this.source = 'direct'});

  /// Par quelle porte on est arrivé — arrive tel quel dans l'entonnoir.
  final String source;

  @override
  State<EefTeaserScreen> createState() => _EefTeaserScreenState();
}

class _EefTeaserScreenState extends State<EefTeaserScreen> {
  late final EefInterestController _controller;
  late final bool _isGuest;

  String? _country;

  @override
  void initState() {
    super.initState();
    final app = Get.find<AppController>();
    _isGuest = app.isGuestMode;
    _country = app.profile?.countryOfResidence;
    // `AppApiClient` n'est PAS enregistré dans GetX : il vit sur AppController,
    // qui l'a construit. Un `Get.find<AppApiClient>()` aurait levé au premier
    // montage réel — et jamais dans un test qui l'aurait injecté à la main.
    _controller = EefInterestController(apiClient: app.apiClient);
    AnalyticsService.instance.logEefTeaserViewed(widget.source);
    // Un invité n'a pas de session : l'appel partirait pour revenir en 401.
    if (!_isGuest) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSheet() async {
    // « Modifier ma réponse » rouvre la feuille d'une vitrine déjà déclarée : le
    // même flux de retrait que le bouton de la carte « C'est noté » y est proposé.
    await showEefInterestSheet(
      context,
      controller: _controller,
      onWithdraw: _confirmWithdraw,
    );
  }

  /// Confirme puis exécute le retrait.
  ///
  /// La confirmation n'est pas un réflexe : sans elle, un tap accidentel sur un
  /// bouton pleine largeur effacerait une déclaration, et rien n'annulerait le
  /// geste — la ligne est supprimée, pas archivée.
  ///
  /// Le retour est dit à l'écran dans les DEUX sens. Un retrait qui échoue en
  /// silence laisserait l'étudiant croire qu'il n'est plus dans la liste alors
  /// qu'il y est : c'est le même mensonge que « c'est noté » sur une ligne
  /// jamais écrite, dans l'autre direction. Le message d'échec nomme donc
  /// l'adresse de recours, parce qu'un « réessaie » seul n'aide pas quelqu'un
  /// qui veut exercer un droit.
  Future<void> _confirmWithdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('eef_withdraw_confirm_title'.tr),
        content: Text('eef_withdraw_confirm_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('eef_withdraw_cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: KpbColors.error),
            child: Text('eef_withdraw_confirm_cta'.tr),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _controller.withdraw();
    if (!mounted) return;

    KpbToast.show(
      kind: ok ? KpbToastKind.success : KpbToastKind.error,
      message: ok ? 'eef_withdraw_done'.tr : 'eef_withdraw_failed'.tr,
      context: context,
    );
  }

  /// La conversion invité.
  ///
  /// L'ACTION est celle de [KpbGuestGate] — `leaveGuestForSignup` puis retour au
  /// routeur de démarrage —, seule la mise en page diffère : ici la vitrine
  /// reste lisible pour un visiteur (c'est du matériel d'acquisition), et seul
  /// le bouton est remplacé. Sans `leaveGuestForSignup`, le routeur voit
  /// `isGuestMode == true` et renvoie droit dans la coquille invité : c'est la
  /// boucle que ce mur existe pour rompre.
  void _convertGuest() {
    Get.find<AppController>().leaveGuestForSignup(source: 'eef_teaser');
    Get.offAll<void>(() => const AppBootScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('eef_title'.tr)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            KpbSpacing.md,
            KpbSpacing.pagePad,
            KpbSpacing.xl,
          ),
          children: [
            _EefHero(country: _country),
            const SizedBox(height: KpbSpacing.lg),
            const _EefWhatItWillDo(),
            const SizedBox(height: KpbSpacing.lg),
            const _EefPlanSplit(),
            const SizedBox(height: KpbSpacing.lg),
            _EefCallToAction(
              controller: _controller,
              isGuest: _isGuest,
              onDeclare: _openSheet,
              onWithdraw: _confirmWithdraw,
              onSignUp: _convertGuest,
            ),
            const SizedBox(height: KpbSpacing.lg),
            const EefAffiliationNotice(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// L'en-tête
// ─────────────────────────────────────────────────────────────────────────────

/// L'en-tête, à hauteur INTRINSÈQUE.
///
/// Pas de `SliverAppBar` à `expandedHeight` figé, et pas non plus de hauteur
/// mesurée au `TextPainter` : on supprime la contrainte au lieu de la calculer.
/// L'écran France a dû mesurer la sienne parce qu'un `expandedHeight: 220`
/// débordait de 88 px à l'échelle de texte 1,0 — un titre de 24 px passe sur
/// deux lignes dès 360 px de large, et un glyphe emoji est plus haut que
/// `fontSize × 1,3`. Une carte qui prend la hauteur de son contenu, dans une
/// liste défilante, ne peut pas déborder : il n'y a plus de nombre à faire
/// coïncider avec le rendu.
class _EefHero extends StatelessWidget {
  const _EefHero({required this.country});

  /// Le pays de résidence tel qu'il est saisi, passé à [EefCalendar.timingLabel]
  /// pour que la décision « dire une date ou se taire » soit prise au même
  /// endroit pour toutes les surfaces.
  final String? country;

  @override
  Widget build(BuildContext context) {
    // Le même point unique que la carte d'accueil. La vitrine portait la règle
    // « la suspension remplace les dates » dans son propre corps ; la carte ne
    // l'avait pas. Elle vit maintenant dans `EefCalendar.timingLabel`, donc une
    // troisième surface ne peut plus l'oublier.
    final timing = EefCalendar.timingLabel(country: country);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: const BoxDecoration(
        gradient: KpbColors.heroGradient,
        borderRadius: KpbRadius.lgBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Le statut, dit avant le titre : c'est l'information qui empêche de
          // lire le reste comme une offre déjà ouverte.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.sm,
              vertical: KpbSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: KpbColors.glassBg,
              borderRadius: KpbRadius.pillBr,
              border: Border.all(color: KpbColors.glassBorder),
            ),
            child: Text(
              'eef_status_preparing'.tr,
              style:
                  KpbTextStyles.labelSm.copyWith(color: KpbColors.textOnDark),
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          Text(
            'eef_hero_title'.tr,
            style:
                KpbTextStyles.displayXs.copyWith(color: KpbColors.textOnDark),
          ),
          const SizedBox(height: KpbSpacing.sm),
          Text(
            'eef_hero_body'.tr,
            style:
                KpbTextStyles.body.copyWith(color: KpbColors.textOnDarkMuted),
          ),
          // ── Suspension : plus d'avertissement (05/10/2026) ──
          //
          // Décision du propriétaire : l'avertissement « le traitement des
          // dossiers est suspendu » n'est plus affiché nulle part dans l'espace
          // (vitrine, hub, catalogue) : un étudiant du Niger peut mener sa
          // procédure depuis un autre pays, et le texte lui disait le contraire.
          // La suspension REMPLAÇAIT les dates ; `EefCalendar.timingLabel` se
          // tait toujours pour un pays suspendu, donc la vitrine ne dit alors ni
          // l'un ni l'autre — jamais « ouverture le 1er octobre ».
          // Les dates n'apparaissent QUE si le serveur en a servi. Aucun repli,
          // aucune date calculée par une règle maison : une échéance inventée
          // est indistinguable d'une information pour qui la lit.
          if (timing != null) ...[
            const SizedBox(height: KpbSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: KpbColors.actionOnDark,
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timing,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: KpbColors.actionOnDark),
                      ),
                      // Une date administrative se vérifie à sa source.
                      EefOfficialLink(
                        url: EefCalendar.platformUrl,
                        labelKey: 'eef_official_platform_link',
                        color: KpbColors.actionOnDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // La borne SERVIE est l'ouverture, nationale et confirmée. Les
            // clôtures divergent d'un pays à l'autre — 15 novembre au Maroc,
            // « information à venir » en Algérie, non publiées dans la plupart
            // des pays au moment d'écrire ceci. On ne les invente pas, et on
            // dit qu'elles existent : sans cette ligne, un étudiant lirait
            // « à partir du 1er octobre » comme « j'ai tout le temps ».
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_deadline_varies_notice'.tr,
              style: KpbTextStyles.caption
                  .copyWith(color: KpbColors.textOnDarkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ce que l'espace fera
// ─────────────────────────────────────────────────────────────────────────────

class _EefWhatItWillDo extends StatelessWidget {
  const _EefWhatItWillDo();

  static const _items = <({IconData icon, String titleKey, String bodyKey})>[
    (
      icon: Icons.school_outlined,
      titleKey: 'eef_pillar_catalog_title',
      bodyKey: 'eef_pillar_catalog_body',
    ),
    (
      icon: Icons.tune_rounded,
      titleKey: 'eef_pillar_shortlist_title',
      bodyKey: 'eef_pillar_shortlist_body',
    ),
    (
      icon: Icons.description_outlined,
      titleKey: 'eef_pillar_documents_title',
      bodyKey: 'eef_pillar_documents_body',
    ),
    (
      icon: Icons.checklist_rtl_rounded,
      titleKey: 'eef_pillar_endtoend_title',
      bodyKey: 'eef_pillar_endtoend_body',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'eef_pillars_heading'.tr,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: KpbSpacing.sm),
        for (final item in _items) ...[
          KpbCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: KpbColors.actionPrimary, size: 22),
                const SizedBox(width: KpbSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.titleKey.tr, style: KpbTextStyles.titleSm),
                      const SizedBox(height: KpbSpacing.xs),
                      Text(
                        item.bodyKey.tr,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: context.kpb.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gratuit / Premium
// ─────────────────────────────────────────────────────────────────────────────

/// Le découpage gratuit / Premium, annoncé dès la vitrine.
///
/// Il est ici parce que la vitrine demande à l'étudiant s'il serait intéressé
/// par le payant : poser la question sans dire ce que le payant contient, ce
/// serait demander un chèque en blanc et mesurer du bruit.
///
/// Deux listes plutôt qu'un tableau à deux colonnes : à 360 px de large et à
/// l'échelle de texte 1,3, deux colonnes de texte se réduisent à des mots
/// coupés. Un tableau qui ne tient pas informe moins bien qu'une liste qui
/// tient.
class _EefPlanSplit extends StatelessWidget {
  const _EefPlanSplit();

  static const _freeKeys = <String>[
    'eef_free_catalog',
    'eef_free_shortlist_preview',
    'eef_free_letter_preview',
    'eef_free_deadlines',
  ];

  static const _premiumKeys = <String>[
    'eef_premium_shortlist_full',
    'eef_premium_documents',
    'eef_premium_interview',
    'eef_premium_review',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'eef_plans_heading'.tr,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: KpbSpacing.sm),
        _PlanCard(
          label: 'eef_plan_free_label'.tr,
          icon: Icons.lock_open_rounded,
          accent: KpbColors.success,
          entryKeys: _freeKeys,
        ),
        const SizedBox(height: KpbSpacing.sm),
        _PlanCard(
          label: 'eef_plan_premium_label'.tr,
          icon: Icons.workspace_premium_outlined,
          accent: KpbColors.warning,
          entryKeys: _premiumKeys,
          footnoteKey: 'eef_plan_premium_footnote',
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.entryKeys,
    this.footnoteKey,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final List<String> entryKeys;
  final String? footnoteKey;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: KpbTextStyles.titleSm.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          for (final key in entryKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: context.kpb.textMuted,
                    ),
                  ),
                  const SizedBox(width: KpbSpacing.sm),
                  Expanded(child: Text(key.tr, style: KpbTextStyles.bodySm)),
                ],
              ),
            ),
          if (footnoteKey != null) ...[
            const SizedBox(height: KpbSpacing.xs),
            Text(
              footnoteKey!.tr,
              style:
                  KpbTextStyles.caption.copyWith(color: context.kpb.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// L'appel à l'action
// ─────────────────────────────────────────────────────────────────────────────

class _EefCallToAction extends StatelessWidget {
  const _EefCallToAction({
    required this.controller,
    required this.isGuest,
    required this.onDeclare,
    required this.onWithdraw,
    required this.onSignUp,
  });

  final EefInterestController controller;
  final bool isGuest;
  final VoidCallback onDeclare;
  final VoidCallback onWithdraw;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return KpbCard(
        variant: KpbCardVariant.highlighted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('eef_cta_heading'.tr, style: KpbTextStyles.titleSm),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_guest_body'.tr,
              style:
                  KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              label: 'eef_guest_cta'.tr,
              icon: Icons.login_rounded,
              fullWidth: true,
              onTap: onSignUp,
            ),
          ],
        ),
      );
    }

    // Déjà déclaré : on remercie et on ne repose pas la question. Le bouton
    // reste, en secondaire, pour corriger une réponse — notamment pour cocher
    // l'intérêt Premium après réflexion.
    if (controller.declared) {
      return KpbCard(
        variant: KpbCardVariant.highlighted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: KpbColors.success,
                  size: 20,
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Text(
                    'eef_interest_recorded_title'.tr,
                    style: KpbTextStyles.titleSm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_interest_recorded_body'.tr,
              style:
                  KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              label: 'eef_interest_edit_cta'.tr,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              onTap: onDeclare,
            ),
            // Le retrait, à l'endroit où l'étudiant se trouve quand il y pense.
            //
            // Le texte de consentement disait déjà « tu peux te retirer à tout
            // moment » avant que ce bouton existe : c'était une promesse sans
            // mécanisme, et les seules issues réelles étaient d'écrire à une
            // adresse générique ou de supprimer son compte ENTIER pour retirer
            // une ligne de prospection. Un consentement qu'on ne peut pas
            // révoquer n'en est pas un.
            //
            // En `tertiary` et non en `danger` : se retirer d'une liste
            // d'intérêt n'est pas une suppression de compte, et un bouton rouge
            // pleine largeur dramatiserait un geste banal. La confirmation
            // suffit à éviter le tap accidentel.
            KpbButton(
              label: 'eef_withdraw_cta'.tr,
              variant: KpbButtonVariant.tertiary,
              fullWidth: true,
              onTap: onWithdraw,
            ),
          ],
        ),
      );
    }

    return KpbCard(
      variant: KpbCardVariant.highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('eef_cta_heading'.tr, style: KpbTextStyles.titleSm),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            'eef_cta_body'.tr,
            style: KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
          ),
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            label: 'eef_cta_declare'.tr,
            icon: Icons.favorite_outline_rounded,
            fullWidth: true,
            loading: controller.busy,
            onTap: controller.busy ? null : onDeclare,
          ),
        ],
      ),
    );
  }
}
