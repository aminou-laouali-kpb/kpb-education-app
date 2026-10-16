import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/my_plan_engine.dart';
import '../../core/models/app_models.dart';
import '../../core/models/scholarship_match.dart';
import '../../core/navigation/scholarship_navigation.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/services/scholarship_match_store.dart';
import '../../core/ui/components/update_recommended_banner.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/skeleton.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../ai_advisor/ai_consent.dart';
import '../cases/case_composer_sheet.dart';
import '../cases/case_detail_screen.dart';
import '../destinations/destinations_screen.dart';
import '../etudes_en_france/eef_home_card.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../orientation/orientation_screen.dart';
import '../parcours/parcours_screen.dart';
import '../parcours/parcours_story_screen.dart';
import '../partners/partners_strip.dart';
import '../scholarship_match/match_format.dart';
import '../scholarship_match/scholarship_match_actions.dart';
import '../scholarship_match/scholarship_match_entry_card.dart';
import '../scholarship_match/scholarship_match_flow_screen.dart';
import '../scholarship_match/scholarship_match_results_screen.dart';
import '../scholarships/scholarship_urgency.dart';
import '../scholarships/widgets/follow_scholarship_button.dart';
import 'home_impact_proof.dart';
import 'home_next_step.dart';

part 'home_screen/header.dart';
part 'home_screen/hero.dart';
part 'home_screen/cards.dart';
part 'home_screen/engagement.dart';
part 'home_screen/scholarships.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flag helpers
// ─────────────────────────────────────────────────────────────────────────────
String _flag(String id) => countryFlag(id);

/// Width reserved on the left of the home app bar for the AppShell's floating
/// hamburger. That button is NOT this bar's `leading` — it is an overlay in
/// `AppShell`'s Stack (`Positioned(top: 0, left: 0)` → `SafeArea` → `Padding`
/// of `KpbSpacing.xs` → a 48 pt `IconButton`), so it occupies x ∈ [4, 52] in
/// the same vertical band as the toolbar. 56 pt clears it with 4 pt of air.
const double _kHomeDrawerGutter = 56;

/// Côté des boutons de l'en-tête : la cible tactile minimale (48 dp).
const double _kHomeHeaderButton = 48;

/// Test hook: the greeting occupies this slot in the home app bar. Its measured
/// width IS the budget the salutation gets, so the regression guard asserts it
/// stays wide enough for a long West-African first name on a 393 pt screen.
@visibleForTesting
const Key homeGreetingSlotKey = ValueKey('home_greeting_slot');

/// Longest first name we render in full before hard-truncating. Real names are
/// far shorter ("Mouhamadou" = 10); the cap only guards against a pathological
/// single-token `fullName` scaling the greeting into illegibility.
const int _kGreetingFirstNameMaxChars = 18;

/// First token of the display name, defensively capped.
String _greetingFirstName(String? fullName) {
  final first = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
  if (first.length <= _kGreetingFirstNameMaxChars) return first;
  return '${first.substring(0, _kGreetingFirstNameMaxChars - 1)}…';
}

// ─────────────────────────────────────────────────────────────────────────────
// Accueil « Ta prochaine étape » (chantier K)
//
// Une question : « Quelle est ma prochaine étape ? ». Sept blocs au plus,
// chacun derrière un interrupteur (`RemoteFeatureFlags.homeBlockEnabled`),
// dans cet ordre :
//
//   0. en tête : la carte « prochaine étape » (élève) — UNE action, voir
//      home_next_step.dart — ou le héros de rôle (parent, partenaire,
//      invité), inchangé. L'espace « Études en France » s'y accroche
//      (carte saisonnière, drapeau serveur, masquée par défaut) ;
//   1. « Tes bourses » (run du test, carte du test, ou liste neutre — H) ;
//   2. « Tes échéances » : date urgente (calcul unique de
//      scholarship_urgency.dart) et dossiers actifs — élève seulement ;
//   3. écoles partenaires (`PartnersStrip`) et preuve d'impact ;
//   4. KPB Intelligence — l'unique entrée de l'accueil ;
//   5. Parcours (« Ils l'ont fait avant toi ») ;
//   6. conseiller WhatsApp.
//
// Pas de raccourci qui double un onglet (Bourses, Dossiers, Écoles, Profil),
// pas d'animation en cascade. Tout bloc qui dépend d'un appel réseau se
// REPLIE (hauteur nulle, espacement compris) quand l'appel échoue ou ne rend
// rien : jamais de trou ni d'erreur au milieu de l'accueil.
// ─────────────────────────────────────────────────────────────────────────────

/// Les blocs de l'accueil.
enum HomeBlock {
  nextStep('homeNextStep'),
  roleHero(null),
  eef(null),
  scholarships('homeScholarships'),
  deadlines('homeDeadlines'),
  partners('homePartners'),
  intelligence('homeIntelligence'),
  parcours('homeParcours'),
  counselor('homeCounselor');

  const HomeBlock(this.flagKey);

  /// Clé de l'interrupteur serveur ; null : toujours là (le héros de rôle
  /// porte l'appel à l'action d'un parent, d'un partenaire ou d'un invité ;
  /// « Études en France » a ses propres drapeaux).
  final String? flagKey;

  /// Clé de test du bloc rendu.
  ValueKey<String> get key => ValueKey<String>('home-block-$name');
}

/// Les blocs de l'accueil, dans l'ordre, pour ce compte.
///
/// - élève : prochaine étape, Études en France, bourses, échéances,
///   partenaires, KPB Intelligence, Parcours, conseiller ;
/// - parent : son héros (« Consultation »), puis la liste NEUTRE des bourses
///   — aucune carte élève (ni prochaine étape, ni échéances) ;
/// - invité : son héros (« Trouve tes bourses »), sans liste de bourses (le
///   catalogue reste derrière le mur invité) ;
/// - partenaire : son héros, inchangé, sans contenu élève.
@visibleForTesting
List<HomeBlock> homeBlocksFor(
  AppController controller, {
  RemoteFeatureFlags? flags,
}) {
  final f = flags ?? RemoteFeatureFlags.instance;
  final student = controller.isStudent;
  final parent = controller.isParent;
  final guest = controller.isGuestMode;
  final blocks = <HomeBlock>[
    student ? HomeBlock.nextStep : HomeBlock.roleHero,
    HomeBlock.eef,
    if (student || parent) HomeBlock.scholarships,
    if (student) HomeBlock.deadlines,
    HomeBlock.partners,
    HomeBlock.intelligence,
    if (student || parent || guest) HomeBlock.parcours,
    HomeBlock.counselor,
  ];
  return blocks.where((b) {
    final key = b.flagKey;
    return key == null || f.homeBlockEnabled(key);
  }).toList(growable: false);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        // Un invité n'a JAMAIS de profil : sans le test `isGuestMode`, son
        // pull-to-refresh remplaçait tout l'accueil par le squelette, et une
        // synchro ratée par une erreur plein écran alors que le catalogue en
        // cache était là.
        final awaitingFirstProfile =
            controller.profile == null && !controller.isGuestMode;
        if (controller.isSyncing && awaitingFirstProfile) {
          return const HomeScreenSkeleton();
        }

        if (controller.syncError != null && awaitingFirstProfile) {
          return KpbErrorState(
            onRetry: controller.pullToRefresh,
          );
        }

        final firstName = _greetingFirstName(controller.profile?.fullName);

        return Container(
          color: KpbColors.canvas,
          child: KpbRefresh(
            onRefresh: controller.pullToRefresh,
            child: CustomScrollView(
              slivers: [
                _appBar(controller, firstName),
                // Un drapeau servi pendant que l'accueil est ouvert retire
                // (ou rend) son bloc sans attendre une autre mise à jour ;
                // le magasin du test change la prochaine étape (test fermé
                // par le serveur → l'onboarding).
                ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[
                    RemoteFeatureFlags.instance.flagsVersion,
                    ScholarshipMatchStore.instance,
                  ]),
                  builder: (context, _) => _body(controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _appBar(AppController controller, String firstName) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      toolbarHeight: 72,

      // OPAQUE, deliberately. This bar is `floating`, so it re-enters over
      // content that is already scrolled. With `Colors.transparent` the
      // section titles underneath showed straight through and collided with
      // the greeting and the action buttons (revue vidéo TestFlight). The
      // colour matches the page canvas set on the wrapping Container, so at
      // rest it is invisible; the shadow only appears once content is
      // scrolled under it.
      backgroundColor: KpbColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: KpbColors.brandNavy.withValues(alpha: 0.12),

      // The hamburger at the top-left belongs to AppShell (an overlay in its
      // Stack), NOT to this bar. Because an ancestor Scaffold DOES have a
      // drawer, `automaticallyImplyLeading` would silently render a second,
      // invisible DrawerButton; and `titleSpacing` is counted TWICE by
      // NavigationToolbar. No implied leading, a zero-width leading that
      // reserves the overlay's gutter exactly ONCE via `leadingWidth`, and
      // `titleSpacing: 0` so nothing is double-counted.
      automaticallyImplyLeading: false,
      leading: const SizedBox.shrink(),
      leadingWidth: _kHomeDrawerGutter,
      titleSpacing: 0,
      title: _HomeGreetingHeader(firstName: firstName),
      // Deux boutons de 48 dp : la cloche et « Mes suivis » (ou Profil,
      // drapeau coupé). KPB Intelligence n'a plus de doublon ici : son entrée
      // unique est un bloc de l'accueil.
      actions: [
        _NotifBellChip(
          // Le point s'allume aussi pour les non-lus du fil serveur
          // (« bourse ouverte »), pas seulement pour l'activité des dossiers.
          hasUnread: hasDerivedNotifications(controller) ||
              controller.serverUnreadNotifications > 0,
          onTap: () async {
            await Get.to<void>(() => const NotificationsScreen());
            unawaited(controller.refreshServerUnreadCount(force: true));
          },
          onMounted: controller.refreshServerUnreadCount,
        ),
        Padding(
          padding: const EdgeInsets.only(right: KpbSpacing.sm),
          child: RemoteFeatureFlags.instance.homeFollowedEntryEnabled
              ? _HomeFollowedButton(
                  onTap: () => Get.toNamed<void>(AppRoutes.saved),
                )
              : _HomeProfileButton(
                  onTap: () => controller.goToTab(StudentShellTab.profile),
                ),
        ),
      ],
    );
  }

  Widget _body(AppController controller) {
    final blocks = homeBlocksFor(controller);
    final activeCases = homeActiveCases(controller.cases);
    final nextStep = controller.isStudent
        ? resolveHomeNextStep(
            activeCases: activeCases,
            followedScholarships: controller.scholarships
                .where((s) => controller.isFollowingScholarship(s.id)),
            needsProfileCompletion: controller.needsProfileCompletionBanner,
            scholarshipTestAvailable: _testAvailable(controller),
            hasOrientationResult: controller.latestOrientationSession != null,
          )
        : null;

    Widget? build(HomeBlock block) {
      switch (block) {
        case HomeBlock.nextStep:
          return _NextStepCard(controller: controller, step: nextStep!);
        case HomeBlock.roleHero:
          return _RoleHeroCard(controller: controller);
        case HomeBlock.eef:
          // Espacement du bas dans la carte : rien quand elle se masque.
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
            child: EefHomeCard(),
          );
        case HomeBlock.scholarships:
          return _HomeScholarshipsSection(
            controller: controller,
            neutral: controller.scholarshipsByDeadline.take(3).toList(),
            // La prochaine étape ouvre déjà le test : pas une seconde carte
            // « Fais le test » juste en dessous.
            hideEntryCard:
                nextStep?.kind == HomeNextStepKind.completeProfileTest,
          );
        case HomeBlock.deadlines:
          final deadlines = resolveHomeDeadlines(
            activeCases: activeCases,
            catalog: controller.scholarshipsByDeadline,
            isFollowing: controller.isFollowingScholarship,
            nextStep: nextStep,
          );
          if (deadlines.isEmpty) return null;
          return _HomeDeadlinesSection(
            controller: controller,
            deadlines: deadlines,
          );
        case HomeBlock.partners:
          return const _HomeTrustSection();
        case HomeBlock.intelligence:
          return const _KpbIntelligenceCard();
        case HomeBlock.parcours:
          return const _ParcoursHomeCarousel();
        case HomeBlock.counselor:
          return const _CounselorWhatsAppCard();
      }
    }

    final children = <Widget>[
      // Invitation douce à mettre à jour : rien tant que le serveur ne
      // recommande pas de version plus récente.
      const Padding(
        padding: EdgeInsets.fromLTRB(
            KpbSpacing.pagePad, KpbSpacing.sm, KpbSpacing.pagePad, 0),
        child: UpdateRecommendedBanner(),
      ),
      for (final block in blocks)
        if (build(block) case final Widget child)
          KeyedSubtree(key: block.key, child: child),
      const SizedBox(height: 100),
    ];
    return SliverList.list(children: children);
  }

  /// Le test « Mes 10 bourses » est-il ouvert à CET élève (drapeau, compte
  /// élève, serveur) ?
  static bool _testAvailable(AppController controller) =>
      switch (scholarshipMatchEntryVariant(controller)) {
        ScholarshipMatchEntryVariant.noRun ||
        ScholarshipMatchEntryVariant.hasRun ||
        ScholarshipMatchEntryVariant.stale =>
          true,
        ScholarshipMatchEntryVariant.hidden ||
        ScholarshipMatchEntryVariant.guest =>
          false,
      };
}

/// Un bloc visible de l'accueil : marges de page et espace du bas. Les blocs
/// qui se replient n'appellent PAS ceci dans leur état replié — l'espace part
/// avec eux.
Widget _homeBlockPadding(Widget child, {bool gutter = true}) => Padding(
      padding: EdgeInsets.fromLTRB(
        gutter ? KpbSpacing.pagePad : 0,
        0,
        gutter ? KpbSpacing.pagePad : 0,
        KpbSpacing.xl,
      ),
      child: child,
    );
