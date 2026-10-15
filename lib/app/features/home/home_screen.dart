import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/components/update_recommended_banner.dart';
import '../../core/ui/skeleton.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../cases/case_detail_screen.dart';
import '../community/community_screen.dart';
import '../destinations/destinations_screen.dart';
import '../orientation/orientation_screen.dart';
import '../ai_advisor/ai_consent.dart';
import '../explore/country_detail_screen.dart';
import '../etudes_en_france/eef_home_card.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../parcours/parcours_screen.dart';
import '../parcours/parcours_story_screen.dart';
import '../scholarships/widgets/follow_scholarship_button.dart';
import '../tools/student_tools_screen.dart';
import 'counsellor_testimonials_carousel.dart';
import 'daily_scholarship_card.dart';
import 'story_of_week_card.dart';
import 'my_plan_card.dart';
import 'home_impact_proof.dart';

part 'home_screen/header.dart';
part 'home_screen/hero.dart';
part 'home_screen/cards.dart';
part 'home_screen/abroad.dart';
part 'home_screen/engagement.dart';

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
// Couleurs : tokens sémantiques centraux (KpbColors — architecture §6/§10.2).

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — light premium, momentum-first
//
// One job per screen: "Où en es-tu ? Quelle est ta prochaine étape ?"
//   1. AppBar  — greeting + search / saved / profile
//   2. Hero    — brand banner + animated progress ring (momentum)
//   3. ⚡ Prochaine étape — smart next-best-action card
//   4. 🗂 Quick actions — 4 light tiles
//   5. 🤖 Assistant d'Orientation IA · 🌍 Inscriptions à l'Étranger · 🛠 Outils
//   6. 📁 Dossiers actifs · ⏰ Deadline · 🏛 Universités · 🏆 Bourses · 📰 Articles
// ─────────────────────────────────────────────────────────────────────────────

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

        final profile = controller.profile;
        final firstName = _greetingFirstName(profile?.fullName);

        // Data — limited, curated
        final institutions = controller.institutions.take(4).toList();
        final scholarships = _homeScholarships(controller);
        final articles = controller.publishedArticles.take(2).toList();
        final activeCases = controller.cases
            .where((c) =>
                c.status != CaseStatus.completed &&
                c.status != CaseStatus.cancelled &&
                c.status != CaseStatus.rejected)
            .take(2)
            .toList();
        // Toute la liste, pas seulement les 3 cartes affichées.
        final urgentScholarship =
            _findUrgentDeadline(controller.scholarshipsByDeadline);

        return Container(
          color: KpbColors.canvas,
          child: KpbRefresh(
            onRefresh: controller.pullToRefresh,
            child: CustomScrollView(
              slivers: [
                // ── App Bar ───────────────────────────────────────────
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  toolbarHeight: 72,

                  // OPAQUE, deliberately. This bar is `floating`, so it
                  // re-enters over content that is already scrolled. With
                  // `Colors.transparent` the section titles underneath
                  // ("Tes meilleures chances", "Voir tout") showed straight
                  // through and collided with the greeting and the action
                  // buttons — unreadable as soon as you scrolled (revue vidéo
                  // TestFlight). The colour matches the page canvas set on the
                  // wrapping Container, so at rest it is invisible; the shadow
                  // only appears once content is scrolled under it.
                  backgroundColor: KpbColors.canvas,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 3,
                  shadowColor: KpbColors.brandNavy.withValues(alpha: 0.12),

                  // The hamburger at the top-left belongs to AppShell (an
                  // overlay in its Stack), NOT to this bar. But because an
                  // ancestor Scaffold DOES have a drawer, AppBar's
                  // `automaticallyImplyLeading` was silently rendering a second
                  // DrawerButton underneath it: an invisible 56 pt twin. On top
                  // of that, `titleSpacing` is counted TWICE by
                  // NavigationToolbar (`size.width - leading - trailing -
                  // middleSpacing * 2`), so `titleSpacing: 60` cost 120 pt.
                  // Budget on a 393 pt screen was 393 − 56 − 136 − 120 = 81 pt,
                  // i.e. "Salut, …" no matter how short the first name.
                  //
                  // Fix: no implied leading, a zero-width leading that reserves
                  // the overlay's gutter exactly ONCE via `leadingWidth`, and
                  // `titleSpacing: 0` so nothing is double-counted. Budget
                  // becomes 393 − 56 − 136 = 201 pt.
                  automaticallyImplyLeading: false,
                  leading: const SizedBox.shrink(),
                  leadingWidth: _kHomeDrawerGutter,
                  titleSpacing: 0,
                  title: _HomeGreetingHeader(firstName: firstName),
                  actions: [
                    _NotifBellChip(
                      // Le point s'allume aussi pour les non-lus du fil
                      // serveur (« bourse ouverte »), pas seulement pour
                      // l'activité des dossiers.
                      hasUnread: hasDerivedNotifications(controller) ||
                          controller.serverUnreadNotifications > 0,
                      onTap: () async {
                        await Get.to<void>(() => const NotificationsScreen());
                        unawaited(
                          controller.refreshServerUnreadCount(force: true),
                        );
                      },
                      onMounted: controller.refreshServerUnreadCount,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _HomeCopilotButton(
                        onTap: () => openAiChatIfConsented(context, controller),
                      ),
                    ),
                    // « Mes suivis » prend la place du raccourci Profil (déjà
                    // dans la barre d'onglets) : la largeur de la salutation
                    // ne change pas. Drapeau coupé → l'ancien raccourci.
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: RemoteFeatureFlags
                              .instance.homeFollowedEntryEnabled
                          ? _HomeFollowedButton(
                              onTap: () => Get.toNamed<void>(AppRoutes.saved),
                            )
                          : _HomeProfileButton(
                              onTap: () =>
                                  controller.goToTab(StudentShellTab.profile),
                            ),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                        KpbSpacing.sm, KpbSpacing.pagePad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 0. Invitation douce à mettre à jour ─────
                        // Self-hiding: rien tant que le serveur ne recommande
                        // pas de version plus récente, et fermable. Le levier
                        // dur (`minVersion`) reste l'affaire d'AppVersionGate.
                        const UpdateRecommendedBanner(),

                        // ── 1. Hero ─────────────────────────────────
                        StaggeredSlide(
                          index: 0,
                          child: _HeroCard(controller: controller),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 1.5 Preuve sociale vérifiable & datée ────
                        // Self-hides until real impact data is available.
                        const HomeImpactProof(),

                        // ── 1.6 Avis publiés (preuve sociale) ────────
                        // Self-hides until real published reviews exist.
                        const StaggeredSlide(
                          index: 1,
                          child: CounsellorTestimonialsCarousel(),
                        ),

                        // ── 1.7 Mon plan (KPB-164) ───────────────────
                        // Unified progress + THE next action. Self-hides for
                        // guests and once the plan is complete.
                        if (controller.isStudent)
                          const StaggeredSlide(
                            index: 2,
                            child: MyPlanCard(),
                          ),

                        // ── 1.8 Espace « Études en France » ─────────
                        // S'auto-masque quand le module est éteint (drapeau
                        // SERVEUR), donc l'accueil ne porte aucune condition et
                        // la bascule du jour J n'a pas besoin d'un binaire neuf.
                        // Espacement du bas dans la carte : pas de trou quand
                        // elle se masque.
                        const StaggeredSlide(
                          index: 2,
                          child: EefHomeCard(),
                        ),

                        // ── 2. Prochaine étape ──────────────────────
                        if (controller.isStudent) ...[
                          StaggeredSlide(
                            index: 2,
                            child: _NextStepCard(
                              controller: controller,
                              activeCases: activeCases,
                            ),
                          ),
                          const SizedBox(height: KpbSpacing.lg),
                        ],

                        // ── 2.5 Bourse du jour (KPB-162) ────────────
                        // Self-fetching + self-hiding (bottom spacing lives in
                        // the card so there's no gap when nothing is featured).
                        if (controller.isStudent)
                          const StaggeredSlide(
                            index: 2,
                            child: DailyScholarshipCard(),
                          ),

                        // ── 2.6 Récit de la semaine (KPB-169) ───────
                        // Self-fetching + self-hiding: no featured story, no
                        // card. Shown to guests too — it is free content and
                        // one of the few reasons to come back before signing up.
                        const StaggeredSlide(
                          index: 2,
                          child: StoryOfWeekCard(),
                        ),

                        // ── 3. Quick Actions ────────────────────────
                        StaggeredSlide(
                          index: 3,
                          child: _QuickActions(controller: controller),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 3.5 Assistant d'Orientation IA ──────────
                        const StaggeredSlide(
                          index: 4,
                          child: _AiAdvisorBanner(),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 3.6 Inscriptions à l'Étranger ───────────
                        StaggeredSlide(
                          index: 5,
                          child: _AbroadEnrollmentCard(controller: controller),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 3.7 Outils étudiants ────────────────────
                        if (controller.isStudent)
                          StaggeredSlide(
                            index: 6,
                            child: _StudentToolsBanner(),
                          ),
                        const SizedBox(height: KpbSpacing.xl),
                      ],
                    ),
                  ),
                ),

                // ── 4. Dossiers actifs ────────────────────────────────
                if (activeCases.isNotEmpty && controller.isStudent) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'home_active_cases_title'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () => controller.goToTab(StudentShellTab.cases),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.sm)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad),
                    sliver: SliverList.separated(
                      itemCount: activeCases.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KpbSpacing.sm),
                      itemBuilder: (ctx, i) => _ActiveCaseCard(
                        item: activeCases[i],
                        controller: controller,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 5. Deadline urgente ───────────────────────────────
                if (urgentScholarship != null && controller.isStudent)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad, 0,
                          KpbSpacing.pagePad, KpbSpacing.xl),
                      child: _UrgentDeadlineCard(
                        scholarship: urgentScholarship,
                        controller: controller,
                      ),
                    ),
                  ),

                // ── 5.5 Universités recommandées ───────────────────────
                if (institutions.isNotEmpty &&
                    (controller.isStudent || controller.isParent)) ...[
                  SliverToBoxAdapter(
                    child: HScrollSection(
                      title: 'home_recommended_universities_title'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () =>
                          controller.goToTab(StudentShellTab.universities),
                      itemCount: institutions.length,
                      height: 168,
                      itemWidth: 210,
                      itemBuilder: (ctx, i) {
                        final institution = institutions[i];
                        return _InstitutionCard(
                          name: controller.resolve(institution.name),
                          flag: _flag(institution.countryId),
                          location: controller.resolve(institution.location),
                          tuition: controller.resolve(institution.tuitionLabel),
                          isPartner: institution.isPartner,
                          fit: controller.institutionFit(institution),
                          onTap: () =>
                              controller.goToTab(StudentShellTab.universities),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 5.7 Ils l'ont fait avant toi (Parcours & Témoignages) ──
                // Real stories from the existing Parcours feature (PR #109) —
                // just surfaced here, not rebuilt.
                if (controller.isStudent || controller.isParent) ...[
                  const SliverToBoxAdapter(child: _ParcoursHomeCarousel()),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 6. Bourses à suivre (sans palier de compatibilité) ─
                if (scholarships.isNotEmpty &&
                    (controller.isStudent || controller.isParent)) ...[
                  SliverToBoxAdapter(
                    child: HScrollSection(
                      title: 'home_scholarships_title'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () => Get.toNamed(AppRoutes.scholarships),
                      itemCount: scholarships.length,
                      height: 168,
                      itemWidth: 210,
                      itemBuilder: (ctx, i) {
                        final s = scholarships[i];
                        return _ScholarshipCard(
                          scholarshipId: s.id,
                          name: controller.resolve(s.name),
                          flag: _flag(s.countryId),
                          funding: controller.resolve(s.typeOfFunding),
                          onTap: () => Get.toNamed(AppRoutes.scholarships),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 7. Articles récents ───────────────────────────────
                // Community/articles is a V1.1+ module (hidden under MVP lock).
                if (!AppConfig.mvpOnly && articles.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'latest_articles'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () => Get.to(() => const CommunityScreen()),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.sm)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad),
                    sliver: SliverList.separated(
                      itemCount: articles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KpbSpacing.sm),
                      itemBuilder: (ctx, i) => _ArticleCard(
                        article: articles[i],
                        controller: controller,
                      ),
                    ),
                  ),
                ],

                // ── 8. Parler à un conseiller KPB (WhatsApp) ──────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        KpbSpacing.pagePad, 0, KpbSpacing.pagePad, 0),
                    child: _CounselorWhatsAppCard(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Nearest scholarship whose CONFIRMED deadline falls within 30 days.
  /// Les 3 cartes « Bourses à suivre » de l'accueil.
  ///
  /// POINT D'EXTENSION (chantier H3) : pour un ÉTUDIANT qui a un run « Mes 10
  /// bourses », les cartes viendront de ce run (statut texte servi par le
  /// serveur, détail au toucher) ; sans run, une carte « Fais le test ». Le
  /// branchement se fait ICI et nulle part ailleurs : le titre de la section,
  /// la carte et [_findUrgentDeadline] n'ont pas à changer.
  ///
  /// En attendant — et pour toujours chez les parents — l'ordre est neutre et
  /// vérifiable (clôture confirmée la plus proche d'abord), sans aucun palier
  /// de compatibilité : voir [AppController.scholarshipsByDeadline].
  List<ScholarshipModel> _homeScholarships(AppController controller) =>
      controller.scholarshipsByDeadline.take(3).toList();

  ScholarshipModel? _findUrgentDeadline(List<ScholarshipModel> scholarships) {
    ScholarshipModel? nearest;
    var nearestDays = 31;
    for (final s in scholarships) {
      final days = s.daysUntilDeadline();
      if (days != null && days <= 30 && days < nearestDays) {
        nearestDays = days;
        nearest = s;
      }
    }
    return nearest;
  }
}
