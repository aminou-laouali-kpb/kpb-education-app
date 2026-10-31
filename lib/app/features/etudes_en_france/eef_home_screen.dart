import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/eef_calendar.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../ai_advisor/ai_consent.dart';
import '../tools/cv_generator_screen.dart';
import '../tools/interview_simulator_screen.dart';
import '../tools/motivation_letters_screen.dart';
import 'eef_help_bubble.dart';
import 'eef_help_card.dart';
import 'eef_interest_controller.dart';
import 'eef_interest_sheet.dart';
import 'eef_official_links.dart';
import 'eef_profile_prefill.dart';
import 'eef_tour.dart';

/// L'espace « Études en France » : le hub.
///
/// ## Ce qu'il est, et ce qu'il n'est pas
///
/// Il réunit, en un écran, ce qui EXISTE déjà et sert la candidature : chercher
/// sa formation (le catalogue serveur), préparer son CV, ses lettres de
/// motivation et son entretien (les outils existants), parler à un conseiller, et
/// tenir son profil à jour. Chaque tuile ouvre un écran qui marche.
///
/// Il ne montre PAS de modules « en préparation ». La coquille de la build 49
/// annonçait trois chantiers dont un seul existait ; ce hub n'annonce que ce
/// qu'il livre. La sélection de formations, la fiche formation, la checklist et
/// le projet d'études arrivent dans une build suivante, et cet écran ne les
/// promet pas : une tuile qui mène nulle part est exactement le « produit cassé »
/// que la coquille refusait d'être.
///
/// ## Ce que le hub dit de la procédure
///
/// La candidature elle-même se dépose sur la plateforme officielle — pas dans
/// KPB. Le héros le dit dans son corps (jamais dans son titre : la règle de
/// nommage interdit d'utiliser le nom de l'agence comme enseigne), avec le lien
/// vers cette plateforme, et la même règle que la vitrine : la suspension d'un
/// pays REMPLACE la date, elle ne s'y ajoute pas (`EefCalendar.timingLabel`).
class EefHomeScreen extends StatefulWidget {
  const EefHomeScreen({super.key, this.source = 'direct'});

  /// Par quelle porte l'étudiant est arrivé (voir `logEefSpaceViewed`).
  final String source;

  @override
  State<EefHomeScreen> createState() => _EefHomeScreenState();
}

class _EefHomeScreenState extends State<EefHomeScreen>
    with SingleTickerProviderStateMixin {
  late final EefInterestController _interest;
  late final AppController _app;

  /// L'entrée de la bulle après la visite : au repos à 1,0 (la bulle à sa taille),
  /// elle repart de 0,8 UNE fois, quand la visite se ferme. Créé dans
  /// `initState` et non paresseusement : la bulle peut être absente, et un
  /// `dispose` ne doit pas fabriquer un `Ticker` sur un élément déjà désactivé.
  late final AnimationController _bubbleEntrance;
  late final Animation<double> _bubbleScale;

  @override
  void initState() {
    super.initState();
    _bubbleEntrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
    _bubbleScale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _bubbleEntrance, curve: Curves.easeOut),
    );
    _app = Get.find<AppController>();
    // `AppApiClient` n'est pas enregistré dans GetX : il vit sur AppController.
    _interest = EefInterestController(apiClient: _app.apiClient);
    AnalyticsService.instance.logEefSpaceViewed(widget.source);
    // Un invité n'a pas de session : l'appel partirait pour revenir en 401.
    if (!_app.isGuestMode) _interest.load();
    // La visite guidée : à la PREMIÈRE ouverture du hub réel seulement (ce
    // widget n'est jamais monté par la vitrine ni par l'écran des parents).
    // Après le premier cadre : la feuille a besoin d'un écran déjà posé.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runFirstOpenTour());
    });
  }

  @override
  void dispose() {
    _bubbleEntrance.dispose();
    _interest.dispose();
    super.dispose();
  }

  /// Vrai de la lecture du drapeau jusqu'à la fermeture de la visite : une
  /// seconde porte (le « ? » activé deux fois d'affilée, ou pendant la lecture de
  /// la première ouverture) n'ouvre pas une seconde feuille par-dessus la
  /// première. Posé de façon SYNCHRONE.
  bool _tourActive = false;

  Future<void> _runFirstOpenTour() async {
    if (_tourActive) return;
    _tourActive = true;
    try {
      final shown = await EefTour.showIfFirstOpen(context);
      if (shown) _playBubbleEntrance();
    } finally {
      _tourActive = false;
    }
  }

  /// Le bouton « ? » : rejoue la visite, sans toucher au drapeau « vue ».
  Future<void> _replayTour() async {
    if (_tourActive) return;
    _tourActive = true;
    try {
      await EefTour.show(context, trigger: EefTourTrigger.replay);
      _playBubbleEntrance();
    } finally {
      _tourActive = false;
    }
  }

  /// Une entrée en échelle de la bulle (0,8 à 1,0 en 250 ms), jouée UNE fois à
  /// la fermeture de la visite. Aucune étiquette, pulsation ni pastille ; et
  /// aucune animation du tout quand l'OS demande de réduire les animations.
  void _playBubbleEntrance() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    unawaited(_bubbleEntrance.forward(from: 0));
  }

  void _track(String tile) =>
      AnalyticsService.instance.logEefHubTileOpened(tile);

  void _openCatalog() {
    _track('catalogue');
    Get.toNamed(AppRoutes.etudesEnFranceCatalog, arguments: 'hub');
  }

  /// Les trois outils passent par `openAiToolIfConsented`, qui gère déjà
  /// l'invité (mur de conversion) et le consentement IA : le hub n'a pas à
  /// recopier ces règles, et une porte de plus qui les oublierait rejouerait le
  /// défaut PARC-05.
  void _openTool(String tile, Widget Function() page) {
    _track(tile);
    openAiToolIfConsented(context, page);
  }

  Future<void> _declare() async {
    _track('profil');
    await showEefInterestSheet(
      context,
      controller: _interest,
      onWithdraw: _confirmWithdraw,
    );
  }

  Future<void> _edit() async {
    _track('profil');
    await showEefInterestSheet(
      context,
      controller: _interest,
      mode: EefSheetMode.edit,
      // Le même flux que le bouton « Me retirer de la liste » du profil : la
      // feuille de modification le propose aussi, là où le consentement promet
      // un retrait « depuis cet écran ».
      onWithdraw: _confirmWithdraw,
    );
  }

  /// Confirme puis exécute le retrait — même contrat que la vitrine : la
  /// confirmation évite le tap accidentel, et l'issue est dite dans les deux
  /// sens. Le texte de consentement promet « tu peux te retirer à tout moment,
  /// depuis cet écran » : une fois la vitrine remplacée par ce hub, c'est ici que
  /// la promesse doit être tenue.
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

    final ok = await _interest.withdraw();
    if (!mounted) return;
    KpbToast.show(
      kind: ok ? KpbToastKind.success : KpbToastKind.error,
      message: ok ? 'eef_withdraw_done'.tr : 'eef_withdraw_failed'.tr,
      context: context,
    );
  }

  /// La conversion invité : même action que [KpbGuestGate] (voir la vitrine).
  void _convertGuest() {
    _app.leaveGuestForSignup(source: 'eef_home');
    Get.offAll<void>(() => const AppBootScreen());
  }

  @override
  Widget build(BuildContext context) {
    final country = _app.profile?.countryOfResidence;

    // Reconstruit à l'arrivée des drapeaux serveur : la bulle (et la marge de la
    // liste qui lui fait place) ne dépend que d'eux, du compte et du clavier.
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) => _scaffold(
        country: country,
        bubbleShown: EefHelpBubble.shouldShow(context),
      ),
    );
  }

  Widget _scaffold({required String? country, required bool bubbleShown}) {
    return Scaffold(
      appBar: AppBar(
        title: Text('eef_title'.tr),
        actions: [
          // Revoir la visite guidée. Seulement dans le hub réel.
          _ReplayTourButton(onPressed: _replayTour),
        ],
      ),
      // La bulle verte WhatsApp : l'emplacement standard d'un bouton flottant, en
      // bas à droite. Le `Scaffold` gère la zone sûre et remonte la bulle quand un
      // `SnackBar` (le retrait de la liste) s'affiche.
      floatingActionButton: bubbleShown
          ? ScaleTransition(
              key: const ValueKey('eef-help-bubble-entrance'),
              scale: _bubbleScale,
              child: const EefHelpBubble(surface: EefBubbleSurface.hub),
            )
          : null,
      body: ListenableBuilder(
        listenable: _interest,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            KpbSpacing.md,
            KpbSpacing.pagePad,
            // Plus haute quand la bulle est là : la dernière carte défile
            // jusqu'au-dessus d'elle.
            EefHelpBubble.listBottomPadding(bubbleShown: bubbleShown),
          ),
          children: [
            _Hero(country: country),
            // Où et quand la candidature se dépose : elle se dépose auprès des
            // services officiels, pas ici. Une ligne, qui s'efface d'elle-même
            // pour un pays suspendu.
            const EefHelpCard(step: EefHelpStep.procedure),
            const SizedBox(height: KpbSpacing.lg),
            _HubTile(
              icon: Icons.travel_explore_rounded,
              color: KpbColors.blue,
              title: 'eef_hub_formations_title'.tr,
              subtitle: 'eef_hub_formations_body'.tr,
              emphasized: true,
              onTap: _openCatalog,
            ),
            // LA carte d'aide : le seul endroit du hub où l'incitation prend
            // toute la place. Elle REMPLACE l'ancienne tuile « Parler à un
            // conseiller », qui menait au même WhatsApp : deux invitations vers
            // la même conversation, c'est une de trop. Elle suit « Trouver ma
            // formation » parce que c'est l'étape où l'on hésite.
            const SizedBox(height: KpbSpacing.lg),
            const EefHelpCard(step: EefHelpStep.hub),
            // Les trois outils IA suivent le même masque que la boîte à outils
            // (`AppConfig.aiToolsEnabled`) : deux portes, une règle.
            //
            // Ouverts d'ici, ils reçoivent `fromEefHub: true` (build 55) : chacun
            // montre alors sa ligne « Besoin d'aide pour… ? » vers le conseiller.
            // Ces écrans servent aussi à la boîte à outils et au tiroir « Outils
            // KPB », où rien ne change : c'est l'APPELANT qui le décide, par un
            // paramètre, pas un état global que l'écran irait lire.
            if (AppConfig.aiToolsEnabled) ...[
              const SizedBox(height: KpbSpacing.lg),
              Text('eef_hub_tools_heading'.tr, style: KpbTextStyles.titleSm),
              const SizedBox(height: KpbSpacing.sm),
              _HubTile(
                icon: Icons.description_rounded,
                color: KpbColors.blue,
                title: 'cv_generator_title'.tr,
                subtitle: 'student_tools_cv_subtitle'.tr,
                onTap: () => _openTool(
                  'cv',
                  () => const CvGeneratorScreen(fromEefHub: true),
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              _HubTile(
                icon: Icons.mail_outline_rounded,
                color: KpbColors.success,
                title: 'letters_title'.tr,
                subtitle: 'student_tools_letters_subtitle'.tr,
                onTap: () => _openTool(
                  'lettres',
                  () => const MotivationLettersScreen(fromEefHub: true),
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              _HubTile(
                icon: Icons.record_voice_over_rounded,
                color: KpbColors.gold,
                title: 'interview_title'.tr,
                subtitle: 'student_tools_interview_subtitle'.tr,
                onTap: () => _openTool(
                  'entretien',
                  () => const InterviewSimulatorScreen(fromEefHub: true),
                ),
              ),
              // Pas de 3e carte d'aide ici : le hub avait trois appels au même
              // WhatsApp (audit build 57, T5-08). Restent la procédure (dates)
              // et la carte du hub.
            ],
            const SizedBox(height: KpbSpacing.lg),
            _ProfileBlock(
              controller: _interest,
              isGuest: _app.isGuestMode,
              onDeclare: _declare,
              onEdit: _edit,
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

/// Le bouton « ? » de la barre : rejoue la visite guidée. Une cible de 48 dp, un
/// nom lu par les lecteurs d'écran (« Revoir la visite »).
class _ReplayTourButton extends StatelessWidget {
  const _ReplayTourButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = 'eef_tour_replay'.tr;
    return Semantics(
      // Un nœud à lui, nommé : l'arbre visuel (bouton + infobulle) dit la même
      // chose, on ne l'expose pas deux fois.
      container: true,
      button: true,
      enabled: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        key: const ValueKey('eef-tour-replay'),
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        icon: const Icon(Icons.help_outline_rounded),
      ),
    );
  }
}

/// Le héros : ce que l'étudiant prépare, et où se dépose réellement la
/// candidature.
class _Hero extends StatelessWidget {
  const _Hero({required this.country});

  final String? country;

  @override
  Widget build(BuildContext context) {
    // Le MÊME point unique que la vitrine et la carte d'accueil : la suspension
    // REMPLACE la date. Un étudiant dont le pays est suspendu ne lit jamais
    // « ouverture le 1er octobre » ici.
    final suspended = EefCalendar.isSuspendedFor(country);
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
          Text(
            'eef_hub_hero_title'.tr,
            style:
                KpbTextStyles.displayXs.copyWith(color: KpbColors.textOnDark),
          ),
          const SizedBox(height: KpbSpacing.sm),
          Text(
            'eef_hub_hero_body'.tr,
            style:
                KpbTextStyles.body.copyWith(color: KpbColors.textOnDarkMuted),
          ),
          // 05/10/2026 — plus d'avertissement de suspension dans le héros
          // (décision du propriétaire : un étudiant du Niger peut mener sa
          // procédure depuis un autre pays). La suspension REMPLAÇAIT la date ;
          // elle continue de la remplacer par RIEN, jamais par « ouverture le
          // 1er octobre ». L'aide, elle, reste en variante neutre.
          if (suspended)
            ...[]
          else if (timing != null) ...[
            const SizedBox(height: KpbSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: KpbSpacing.xs),
                      // Les clôtures divergent par pays (le Maroc ferme le
                      // 15 novembre) : une date d'ouverture sans ce caveat se lit
                      // « j'ai tout le temps ».
                      Text(
                        'eef_deadline_varies_notice'.tr,
                        style: KpbTextStyles.caption
                            .copyWith(color: KpbColors.textOnDarkMuted),
                      ),
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
          ],
        ],
      ),
    );
  }
}

/// Une tuile du hub : une icône, un titre, une phrase, un chevron. Une liste
/// plutôt qu'une grille — à l'échelle de texte 1,3 d'un petit téléphone, deux
/// colonnes coupent les titres.
class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: onTap,
      variant:
          emphasized ? KpbCardVariant.highlighted : KpbCardVariant.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KpbRadius.smBr,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: KpbSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KpbTextStyles.titleSm),
                const SizedBox(height: KpbSpacing.xs),
                Text(
                  subtitle,
                  style: KpbTextStyles.bodySm
                      .copyWith(color: context.kpb.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: KpbSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              color: context.kpb.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Mon profil Études en France » : ce que l'étudiant a déclaré, comment le
/// modifier, et comment se retirer.
///
/// ## Pourquoi ce bloc est dans le hub
///
/// La déclaration n'était ouverte que par la vitrine, qui disparaît quand
/// l'espace s'ouvre. Le texte de consentement promet « tu peux te retirer à tout
/// moment, depuis cet écran » : sans ce bloc, la promesse devenait fausse le jour
/// de l'ouverture, et le consentement au rappel, irrévocable depuis l'app.
class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({
    required this.controller,
    required this.isGuest,
    required this.onDeclare,
    required this.onEdit,
    required this.onWithdraw,
    required this.onSignUp,
  });

  final EefInterestController controller;
  final bool isGuest;
  final VoidCallback onDeclare;
  final VoidCallback onEdit;
  final VoidCallback onWithdraw;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('eef_profile_title'.tr, style: KpbTextStyles.titleSm),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_hub_guest_body'.tr,
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

    if (controller.declared) {
      final interest = controller.interest;
      final level = eefLevelLabel(interest.currentLevel);
      final target = eefLevelLabel(interest.targetLevel);
      final fields = interest.fieldIds.map(eefFieldLabel).join(', ');

      return KpbCard(
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
                    'eef_profile_title'.tr,
                    style: KpbTextStyles.titleSm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            if (level != null)
              _ProfileLine(
                'eef_profile_level_line'.trParams({'level': level}),
              ),
            if (target != null)
              _ProfileLine(
                'eef_profile_target_line'.trParams({'level': target}),
              ),
            _ProfileLine(
              fields.isEmpty
                  ? 'eef_profile_no_fields'.tr
                  : 'eef_profile_fields_line'.trParams({'fields': fields}),
            ),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_profile_recorded_body'.tr,
              style: KpbTextStyles.caption.copyWith(
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              label: 'eef_profile_edit_cta'.tr,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              loading: controller.busy,
              onTap: controller.busy ? null : onEdit,
            ),
            // En `tertiary`, pas en `danger` : se retirer d'une liste d'intérêt
            // n'est pas supprimer un compte. La confirmation suffit à éviter le
            // tap accidentel.
            KpbButton(
              label: 'eef_withdraw_cta'.tr,
              variant: KpbButtonVariant.tertiary,
              fullWidth: true,
              onTap: controller.busy ? null : onWithdraw,
            ),
          ],
        ),
      );
    }

    // La lecture a échoué : on ne SAIT pas si l'étudiant a déclaré. Proposer
    // « Compléter mon profil » le ferait redéclarer (et masquerait « Me retirer »,
    // seul endroit où le retrait est tenu) ; on le dit et on propose de réessayer.
    if (controller.readFailed) {
      return KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('eef_profile_title'.tr, style: KpbTextStyles.titleSm),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_profile_read_failed'.tr,
              style:
                  KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              label: 'eef_sheet_retry'.tr,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              loading: controller.phase == EefInterestPhase.loading,
              onTap: controller.load,
            ),
          ],
        ),
      );
    }

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('eef_profile_title'.tr, style: KpbTextStyles.titleSm),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            'eef_profile_empty_body'.tr,
            style: KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
          ),
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            label: 'eef_profile_declare_cta'.tr,
            icon: Icons.person_outline_rounded,
            fullWidth: true,
            loading: controller.busy,
            onTap: controller.busy ? null : onDeclare,
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
      child: Text(text, style: KpbTextStyles.bodySm),
    );
  }
}
