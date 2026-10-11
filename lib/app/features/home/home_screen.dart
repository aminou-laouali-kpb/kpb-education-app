import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/navigation/shell_tabs.dart';
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
import '../tools/student_tools_screen.dart';
import 'counsellor_testimonials_carousel.dart';
import 'daily_scholarship_card.dart';
import 'story_of_week_card.dart';
import 'my_plan_card.dart';
import 'home_impact_proof.dart';

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
        final scholarships =
            controller.recommendedScholarships.take(3).toList();
        final articles = controller.publishedArticles.take(2).toList();
        final activeCases = controller.cases
            .where((c) =>
                c.status != CaseStatus.completed &&
                c.status != CaseStatus.cancelled &&
                c.status != CaseStatus.rejected)
            .take(2)
            .toList();
        final urgentScholarship = _findUrgentDeadline(scholarships);

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
                      hasUnread: hasDerivedNotifications(controller),
                      onTap: () => Get.to(() => const NotificationsScreen()),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _HomeCopilotButton(
                        onTap: () => openAiChatIfConsented(context, controller),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _HomeProfileButton(
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

                // ── 6. Bourses pour toi ───────────────────────────────
                if (scholarships.isNotEmpty &&
                    (controller.isStudent || controller.isParent)) ...[
                  SliverToBoxAdapter(
                    child: HScrollSection(
                      title: 'scholarships_for_you'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () => Get.toNamed(AppRoutes.scholarships),
                      itemCount: scholarships.length,
                      height: 168,
                      itemWidth: 210,
                      itemBuilder: (ctx, i) {
                        final s = scholarships[i];
                        return _ScholarshipCard(
                          name: controller.resolve(s.name),
                          flag: _flag(s.countryId),
                          funding: controller.resolve(s.typeOfFunding),
                          fit: controller.scholarshipFit(s),
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

  /// Find nearest scholarship with deadline within 30 days.
  ScholarshipModel? _findUrgentDeadline(List<ScholarshipModel> scholarships) {
    final now = DateTime.now();
    ScholarshipModel? nearest;
    int nearestDays = 31;

    for (final s in scholarships) {
      final parsed = _parseDeadline(s.deadlineLabel.fr);
      if (parsed != null) {
        final days = parsed.difference(now).inDays;
        if (days >= 0 && days <= 30 && days < nearestDays) {
          nearestDays = days;
          nearest = s;
        }
      }
    }
    return nearest;
  }

  DateTime? _parseDeadline(String label) {
    const months = {
      'janvier': 1,
      'février': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'août': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'décembre': 12,
    };
    final parts = label.toLowerCase().split(' ');
    if (parts.length < 3) return null;
    final day = int.tryParse(parts[0]);
    final month = months[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar — greeting (fills the title slot) + soft-elevated icon chips
// ─────────────────────────────────────────────────────────────────────────────
class _HomeGreetingHeader extends StatelessWidget {
  const _HomeGreetingHeader({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    final greeting = firstName.isNotEmpty
        ? 'home_design_greeting_named'.trParams({'name': firstName})
        : 'home_design_greeting'.tr;

    // Two things happen here, both required.
    //
    // 1. `SizedBox(width: double.infinity)` — AppBar wraps the title in
    //    `_AppBarTitleBox`, which SHRINK-WRAPS its child. Without this the
    //    greeting would report its natural width and the slot's real budget
    //    would be unmeasurable (and unassertable in tests).
    //
    // 2. `FittedBox(scaleDown)` instead of relying on ellipsis — the previous
    //    round of this bug was "fixed" by decluttering the header, which only
    //    moved the cliff. West-African first names are long (« Abdoulaye »,
    //    « Mouhamadou ») and AppBar already clamps title text scaling at
    //    1.34×, so at large accessibility sizes the line still cannot fit any
    //    fixed budget. Scaling the line down keeps the user's name WHOLE —
    //    truncating someone's own name to "Salut, …" is the actual defect.
    //    `maxLines`/`overflow` stay as a backstop if this ever loses the
    //    FittedBox.
    return SizedBox(
      key: homeGreetingSlotKey,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            greeting,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: KpbTextStyles.headingFamily,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: KpbColors.brandNavy,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCopilotButton extends StatelessWidget {
  const _HomeCopilotButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'home_ai_advisor_title'.tr,
      child: KpbPressable(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: KpbColors.actionPrimary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: KpbColors.actionPrimary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.smart_toy_rounded,
              color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _HomeProfileButton extends StatelessWidget {
  const _HomeProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'nav_profile'.tr,
      child: KpbPressable(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: KpbColors.border),
          ),
          child: const Icon(Icons.person_outline_rounded,
              color: KpbColors.brandNavy, size: 20),
        ),
      ),
    );
  }
}

/// Notifications bell (App-engagement handoff). The unread dot is HONEST: it is
/// shown only when the real case list yields at least one live-derived
/// notification (`hasDerivedNotifications`) — there is no stored feed, so it
/// never signals fabricated activity.
class _NotifBellChip extends StatelessWidget {
  const _NotifBellChip({required this.hasUnread, required this.onTap});
  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        button: true,
        label: 'notifications_title'.tr,
        child: KpbPressable(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: c.softShadow,
                  border: Border.all(color: KpbColors.border),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 20, color: KpbColors.textMuted),
              ),
              if (hasUnread)
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: KpbColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decomposes the real [UserProfile.completionScore] inputs into 5 named
/// groups so the gauge card can show sub-bars — same underlying booleans as
/// `completionScore`, just grouped for display. No fabricated categories
/// (no "letters"/"applications"/"community" sub-score — we don't track
/// those yet), so only groups we can actually compute are shown.
List<(String, double)> _gaugeBars(UserProfile? profile) {
  if (profile == null) return const [];
  double frac(List<bool> items) => items.where((e) => e).length / items.length;
  return [
    (
      'home_hero_profile_ring_label'.tr,
      frac([
        profile.fullName.trim().isNotEmpty,
        profile.email.trim().isNotEmpty,
        profile.phone.trim().isNotEmpty,
        profile.countryOfResidence.trim().isNotEmpty,
        profile.preferredLanguage.trim().isNotEmpty,
      ]),
    ),
    (
      'home_gauge_bar_level'.tr,
      frac([
        (profile.currentLevel ?? '').trim().isNotEmpty,
        (profile.targetLevel ?? '').trim().isNotEmpty,
        (profile.languageLevel ?? '').trim().isNotEmpty,
        (profile.gradeRange ?? '').trim().isNotEmpty ||
            (profile.bacSeries ?? '').trim().isNotEmpty,
      ]),
    ),
    (
      'home_gauge_bar_interests'.tr,
      frac([profile.fieldIds.isNotEmpty, profile.targetCountryIds.isNotEmpty]),
    ),
    (
      'home_gauge_bar_documents'.tr,
      frac([profile.availableDocuments.isNotEmpty]),
    ),
    (
      'home_gauge_bar_budget'.tr,
      frac([
        profile.annualTuitionBudgetEur != null &&
            profile.annualTuitionBudgetEur! > 0
      ]),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero / "Progress gauge" Card — dark navy readiness card + sub-score bars.
// The ring + sub-bars are the real profile.completionScore, decomposed.
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final progress = (profile?.completionScore ?? 0.0).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final showRing = controller.isStudent && pct < 100;
    final bars = showRing ? _gaugeBars(profile) : const [];

    return Container(
      decoration: BoxDecoration(
        color: KpbColors.brandNavy,
        borderRadius: KpbRadius.mdBr,
        boxShadow: KpbShadow.blue,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showRing) ...[
                KpbPressable(
                  onTap: () => controller.goToTab(StudentShellTab.profile),
                  child: _AnimatedRing(value: progress),
                ),
                const SizedBox(width: KpbSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showRing) ...[
                      Text(
                        'home_gauge_eyebrow'.tr,
                        style: const TextStyle(
                          color: KpbColors.decorSky,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      controller.isPartner
                          ? 'home_hero_title_partner'.tr
                          : controller.isParent
                              ? 'home_hero_title_parent'.tr
                              : 'home_hero_title_student'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.isStudent
                          ? 'home_hero_subtitle_student'.tr
                          : 'home_hero_subtitle_other'.tr,
                      style: const TextStyle(
                        color: KpbColors.textFaint,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (!controller.isStudent) ...[
                      const SizedBox(height: 16),
                      _HeroCta(
                        label: controller.isParent
                            ? 'home_hero_cta_consultation'.tr
                            : 'home_hero_cta_become_partner'.tr,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CaseComposerSheet(
                            caseType: CaseType.consultation,
                            title: 'home_case_title_book_appointment'.tr,
                            contextLabel: 'KPB Education',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bars.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (final b in bars)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: b == bars.last ? 0 : 6),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: b.$2,
                              minHeight: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  KpbColors.decorSky),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: KpbColors.textFaint,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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

// Animated progress ring used in the gauge card (navy background).
class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        height: 76,
        width: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(KpbColors.decorSky),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(v * 100).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(
                      color: KpbColors.textFaint,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: KpbRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KpbColors.actionPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                size: 16, color: KpbColors.actionPrimary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next Step Card — light, accent-driven next-best-action
// ─────────────────────────────────────────────────────────────────────────────
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.controller, required this.activeCases});
  final AppController controller;
  final List<StudentCase> activeCases;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final step = _resolveStep(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('home_design_discovery_title'.tr, style: KpbTextStyles.title),
        const SizedBox(height: 2),
        Text(
          'home_design_discovery_subtitle'.tr,
          style: const TextStyle(fontSize: 11, color: KpbColors.textMuted),
        ),
        const SizedBox(height: 12),
        KpbPressable(
          onTap: step.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: KpbRadius.lgBr,
              border: Border.all(color: step.iconColor.withValues(alpha: 0.25)),
              boxShadow: c.cardShadow,
            ),
            padding: const EdgeInsets.all(KpbSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: step.iconColor.withValues(alpha: 0.12),
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: Icon(step.icon, color: step.iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: step.iconColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: KpbColors.brandNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: KpbTextStyles.caption.copyWith(
                          color: KpbColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: step.iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _StepData _resolveStep(BuildContext context) {
    final profile = controller.profile;
    final hasOrientation = controller.latestOrientationSession != null;

    // Priority 1 — Case requires immediate action
    final urgentCase = activeCases.firstWhere(
      (c) =>
          c.status == CaseStatus.documentsNeeded ||
          c.status == CaseStatus.awaitingStudent ||
          c.status == CaseStatus.awaitingPayment,
      orElse: () => activeCases.isEmpty ? _placeholder : activeCases.first,
    );

    if (activeCases.isNotEmpty &&
        (urgentCase.status == CaseStatus.documentsNeeded ||
            urgentCase.status == CaseStatus.awaitingStudent ||
            urgentCase.status == CaseStatus.awaitingPayment)) {
      final isPayment = urgentCase.status == CaseStatus.awaitingPayment;
      final isDocs = urgentCase.status == CaseStatus.documentsNeeded;
      return _StepData(
        label: 'home_next_step_label_action_required'.tr,
        title: isPayment
            ? 'home_next_step_title_talk_advisor'.tr
            : isDocs
                ? 'home_next_step_title_documents_to_send'.tr
                : 'home_next_step_title_response_expected'.tr,
        subtitle: controller.resolve(urgentCase.nextStepTitle),
        icon: isPayment
            ? Icons.chat_rounded
            : isDocs
                ? Icons.upload_file_rounded
                : Icons.reply_rounded,
        iconColor: KpbColors.error,
        onTap: () => Get.to(() => CaseDetailScreen(caseId: urgentCase.id)),
      );
    }

    // Priority 2 — Profile incomplete / skipped onboarding
    if (controller.needsProfileCompletionBanner) {
      final pct = ((profile?.completionScore ?? 0) * 100).round();
      return _StepData(
        label: 'home_next_step_label_your_profile'.tr,
        title: 'home_next_step_title_complete_profile'.tr,
        subtitle: controller.onboardingSkipped
            ? 'home_next_step_subtitle_missing_info'.tr
            : 'home_profile_pct_notice'.trParams({'pct': '$pct'}),
        icon: Icons.tune_rounded,
        iconColor: KpbColors.actionPrimary,
        onTap: () => Get.to(() => const OnboardingScreen()),
      );
    }

    // Priority 3 — No orientation done
    if (!hasOrientation) {
      return _StepData(
        label: 'home_next_step_label_discovery'.tr,
        title: 'home_next_step_title_take_orientation'.tr,
        subtitle: 'home_next_step_subtitle_orientation'.tr,
        icon: Icons.psychology_rounded,
        iconColor: KpbColors.actionPrimary,
        onTap: () => Get.to(() => const OrientationScreen()),
      );
    }

    // Priority 4 — Orientation done, no active cases
    if (activeCases.isEmpty) {
      return _StepData(
        label: 'home_next_step_label_next_step'.tr,
        title: 'home_next_step_title_start_case'.tr,
        subtitle: 'home_next_step_subtitle_start_case'.tr,
        icon: Icons.rocket_launch_rounded,
        iconColor: KpbColors.success,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => CaseComposerSheet(
            caseType: CaseType.applicationSupport,
            title: 'home_case_title_new_case'.tr,
            contextLabel: 'KPB Education',
          ),
        ),
      );
    }

    // Default — everything in progress
    return _StepData(
      label: 'home_next_step_label_explore'.tr,
      title: 'home_next_step_title_discover_opportunities'.tr,
      subtitle: 'home_next_step_subtitle_explore'.tr,
      icon: Icons.explore_rounded,
      iconColor: KpbColors.decorSky,
      onTap: () => Get.to(() => const DestinationsScreen()),
    );
  }
}

// Placeholder for firstWhere default (never rendered)
final _placeholder = StudentCase(
  id: '',
  referenceCode: '',
  title: const LocalizedText(fr: '', en: ''),
  description: const LocalizedText(fr: '', en: ''),
  contextLabel: const LocalizedText(fr: '', en: ''),
  status: CaseStatus.draft,
  type: CaseType.consultation,
  preferredContactMethod: ContactMethod.inApp,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  nextStepTitle: const LocalizedText(fr: '', en: ''),
  nextStepDescription: const LocalizedText(fr: '', en: ''),
  timeline: const [],
  messages: const [],
  documentRequests: const [],
);

class _StepData {
  const _StepData({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions — 4 light tiles
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.psychology_rounded,
        'nav_orientation'.tr,
        KpbColors.actionPrimary,
        () => Get.to(() => const OrientationScreen()),
      ),
      (
        Icons.explore_rounded,
        'home_next_step_label_explore'.tr,
        KpbColors.decorSky,
        () => Get.to(() => const DestinationsScreen()),
      ),
      (
        Icons.workspace_premium_rounded,
        'home_quick_action_scholarships'.tr,
        KpbColors.warning,
        () => Get.toNamed(AppRoutes.scholarships),
      ),
      (
        Icons.folder_copy_rounded,
        'home_quick_action_cases'.tr,
        KpbColors.success,
        () => controller.goToTab(StudentShellTab.cases),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('home_design_tools_title'.tr, style: KpbTextStyles.title),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final a in actions)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: a == actions.last ? 0 : 8),
                  child: QuickActionTile(
                    icon: a.$1,
                    label: a.$2,
                    color: a.$3,
                    onTap: a.$4,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assistant d'Orientation IA Banner
// ─────────────────────────────────────────────────────────────────────────────
class _AiAdvisorBanner extends StatelessWidget {
  const _AiAdvisorBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KpbColors.brandNavy,
        borderRadius: KpbRadius.lgBr,
        border: Border.all(
          color: KpbColors.actionPrimary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: KpbColors.actionPrimary.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(KpbSpacing.md),
      child: Row(
        children: [
          // Glowing AI icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KpbColors.actionPrimary,
              borderRadius: KpbRadius.mdBr,
              boxShadow: [
                BoxShadow(
                  color: KpbColors.actionPrimary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'home_ai_advisor_title'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KpbColors.actionPrimary.withValues(alpha: 0.2),
                        borderRadius: KpbRadius.xsBr,
                        border: Border.all(
                          color: KpbColors.actionPrimary.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        'home_badge_new'.tr,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: KpbColors.actionPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'home_find_school_desc'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: KpbColors.textFaint,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => openAiChatIfConsented(
                    context,
                    Get.find<AppController>(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'home_ai_advisor_cta'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: KpbColors.actionPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: KpbColors.actionPrimary,
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Active Case Card — compact, status-driven
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveCaseCard extends StatelessWidget {
  const _ActiveCaseCard({required this.item, required this.controller});
  final StudentCase item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final si = _statusInfo(item.status);

    // Real document-completion ratio (no fabricated "X/10 steps" — only shown
    // when the case actually has document requests to count).
    final docs = item.documentRequests;
    final docsDone = docs.where((d) => d.isProvided).length;
    final docsPct = docs.isEmpty ? null : docsDone / docs.length;

    return KpbPressable(
      onTap: () => Get.to(() => CaseDetailScreen(caseId: item.id)),
      child: KpbCard(
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: si.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.resolve(item.title),
                        style: KpbTextStyles.titleMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller.resolve(item.nextStepTitle),
                        style: KpbTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                KpbBadge(label: si.label, color: si.color, small: true),
              ],
            ),
            if (docsPct != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: docsPct,
                        minHeight: 6,
                        backgroundColor: KpbColors.surfaceMuted,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            KpbColors.actionPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'home_case_documents_ratio'.trParams(
                        {'done': '$docsDone', 'total': '${docs.length}'}),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({Color color, String label}) _statusInfo(CaseStatus s) {
    switch (s) {
      case CaseStatus.documentsNeeded:
        return (
          color: KpbColors.warning,
          label: 'case_status_documents_needed'.tr
        );
      case CaseStatus.awaitingPayment:
        return (
          color: KpbColors.error,
          label: 'case_status_awaiting_payment'.tr
        );
      case CaseStatus.awaitingStudent:
        return (
          color: KpbColors.error,
          label: 'case_status_awaiting_student'.tr
        );
      case CaseStatus.scheduled:
        return (color: KpbColors.success, label: 'case_status_scheduled'.tr);
      case CaseStatus.inProgress:
        return (
          color: KpbColors.actionPrimary,
          label: 'case_status_in_progress'.tr
        );
      case CaseStatus.underReview:
        return (color: KpbColors.warning, label: 'case_status_under_review'.tr);
      case CaseStatus.counselorAssigned:
        return (
          color: KpbColors.decorSky,
          label: 'case_status_counselor_assigned'.tr
        );
      case CaseStatus.submitted:
        return (color: KpbColors.decorSky, label: 'case_status_submitted'.tr);
      case CaseStatus.applicationSubmitted:
        return (
          color: KpbColors.actionPrimary,
          label: 'case_status_application_submitted'.tr
        );
      case CaseStatus.waitingDecision:
        return (
          color: KpbColors.warning,
          label: 'case_status_waiting_decision'.tr
        );
      default:
        return (
          color: KpbColors.textFaint,
          label: 'case_status_in_progress'.tr
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light Institution Card (home)
// ─────────────────────────────────────────────────────────────────────────────
class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.name,
    required this.flag,
    required this.location,
    required this.tuition,
    required this.isPartner,
    required this.fit,
    required this.onTap,
  });

  final String name;
  final String flag;
  final String location;
  final String tuition;
  final bool isPartner;

  /// Null without a student profile — no badge then.
  final ProfileFit? fit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return KpbPressable(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 24)),
                const Spacer(),
                if (fit != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: ProfileFitBadge(fit: fit!, fontSize: 10.5),
                    ),
                  ),
                if (isPartner) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: KpbBadge(
                        label: 'badge_partner'.tr,
                        color: KpbColors.warning,
                        small: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KpbColors.brandNavy,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              location,
              style: KpbTextStyles.caption.copyWith(color: KpbColors.textFaint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              tuition,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KpbColors.actionPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light Scholarship Card (home)
// ─────────────────────────────────────────────────────────────────────────────
class _ScholarshipCard extends StatelessWidget {
  const _ScholarshipCard({
    required this.name,
    required this.flag,
    required this.funding,
    required this.fit,
    required this.onTap,
  });

  final String name;
  final String flag;
  final String funding;
  final ProfileFit fit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return KpbPressable(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 24)),
                const Spacer(),
                Flexible(child: ProfileFitBadge(fit: fit, fontSize: 10.5)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KpbColors.brandNavy,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.payments_rounded,
                    size: 14, color: KpbColors.success),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    funding,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KpbColors.success,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Urgent Deadline Card
// ─────────────────────────────────────────────────────────────────────────────
class _UrgentDeadlineCard extends StatelessWidget {
  const _UrgentDeadlineCard(
      {required this.scholarship, required this.controller});
  final ScholarshipModel scholarship;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final deadline = controller.resolve(scholarship.deadlineLabel);
    // Deadline countdown is parsed from the canonical French label
    // (the month map below is French-only), independent of display locale.
    final daysLeft = _daysLeft(scholarship.deadlineLabel.fr);

    return KpbPressable(
      onTap: () => Get.toNamed(AppRoutes.scholarships),
      child: Container(
        decoration: BoxDecoration(
          color: KpbColors.warningLight,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(
              color: KpbColors.warning.withValues(alpha: 0.4), width: 1.5),
        ),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  daysLeft >= 0 ? '$daysLeft' : '!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: KpbColors.warning,
                    height: 1,
                  ),
                ),
                Text(
                  'home_days_left_label'.tr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            VerticalDivider(
                width: 1,
                thickness: 1,
                color: KpbColors.warning.withValues(alpha: 0.3)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_deadline_near_label'.tr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.warning,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.resolve(scholarship.name),
                    style: KpbTextStyles.titleMd,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'closing_label'.tr} : $deadline',
                    style: const TextStyle(
                        fontSize: 12, color: KpbColors.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: KpbColors.warning,
                borderRadius: KpbRadius.mdBr,
              ),
              child: Text(
                'home_deadline_see_button'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _daysLeft(String label) {
    const months = {
      'janvier': 1,
      'février': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'août': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'décembre': 12,
    };
    final parts = label.toLowerCase().split(' ');
    if (parts.length < 3) return -1;
    final day = int.tryParse(parts[0]);
    final month = months[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return -1;
    final dt = DateTime(year, month, day);
    return dt.difference(DateTime.now()).inDays;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Article Card — compact, 2-line summary
// ─────────────────────────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.controller});
  final ArticleModel article;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: () => Get.to(() => const CommunityScreen()),
      child: KpbCard(
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: const BoxDecoration(
                color: KpbColors.actionPrimary,
                borderRadius: KpbRadius.pillBr,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.resolve(article.title),
                    style: KpbTextStyles.titleMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    controller.resolve(article.summary),
                    style: KpbTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: KpbColors.textFaint),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inscriptions à l'Étranger — Widget & Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AbroadEnrollmentCard extends StatelessWidget {
  const _AbroadEnrollmentCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAbroadCountriesSheet(context, controller),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(
            color: KpbColors.warning.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: KpbColors.warning.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Premium World Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KpbColors.warning,
                    borderRadius: KpbRadius.mdBr,
                    boxShadow: [
                      BoxShadow(
                        color: KpbColors.warning.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'register_abroad_title'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KpbColors.warning.withValues(alpha: 0.15),
                              borderRadius: KpbRadius.xsBr,
                              border: Border.all(
                                color: KpbColors.warning.withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'home_badge_guidance'.tr,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: KpbColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'home_apply_world_desc'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: KpbColors.textFaint,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            // Footer with dynamic flag list & CTA
            Row(
              children: [
                // Horizontal Row of Flags
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: const [
                        'canada',
                        'usa',
                        'uk',
                        'germany',
                        'morocco'
                      ]
                          .map((id) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: KpbRadius.xsBr,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  _flag(id),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // CTA text & arrow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'discover'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: KpbColors.warning,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: KpbColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showAbroadCountriesSheet(BuildContext context, AppController controller) {
  final targetCountryIds = ['canada', 'usa', 'uk', 'germany', 'morocco'];
  final countries = targetCountryIds
      .map((id) => controller.countries.firstWhereOrNull((c) => c.id == id))
      .whereType<CountryModel>()
      .toList();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        padding: EdgeInsets.only(
          left: KpbSpacing.lg,
          right: KpbSpacing.lg,
          top: KpbSpacing.md,
          bottom: KpbSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: KpbRadius.pillBr,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header Title
            Row(
              children: [
                Text(
                  'register_abroad_cta'.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  "🌍",
                  style: TextStyle(fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'home_destinations_desc'.tr,
              style: TextStyle(
                fontSize: 13,
                color: KpbColors.textFaint,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // List of countries
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: countries.map((country) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: KpbColors.brandNavy,
                        borderRadius: KpbRadius.mdBr,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: KpbRadius.mdBr,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Get.back();
                              Get.to(() =>
                                  CountryDetailScreen(countryId: country.id));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(KpbSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Flag circular badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _flag(country.id),
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Text contents
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              controller.resolve(country.name),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            // Difficulty Badge
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.05),
                                                borderRadius: KpbRadius.xsBr,
                                              ),
                                              child: Text(
                                                'home_admission_prefix'
                                                    .trParams({
                                                  'value': controller.resolve(
                                                      country
                                                          .admissionDifficulty)
                                                }),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: KpbColors
                                                      .textDarkSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          controller.resolve(country.whyStudy),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: KpbColors.textFaint,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Budget Row
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.payments_outlined,
                                              size: 14,
                                              color: KpbColors.warning,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'tuition_prefix'.tr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            Text(
                                              controller.resolve(
                                                  country.tuitionRange),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: KpbColors.warning,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right Chevron
                                  const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white30,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Tools Banner — CV generator + Letters shortcut
// ─────────────────────────────────────────────────────────────────────────────

class _StudentToolsBanner extends StatelessWidget {
  const _StudentToolsBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => const StudentToolsScreen()),
      child: Container(
        padding: const EdgeInsets.all(KpbSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              KpbColors.actionPrimary.withValues(alpha: 0.15),
              KpbColors.success.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: KpbRadius.xlBr,
          border: Border.all(
            color: KpbColors.actionPrimary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KpbColors.actionPrimary.withValues(alpha: 0.15),
                borderRadius: KpbRadius.mdBr,
              ),
              child: const Icon(
                Icons.build_circle_rounded,
                color: KpbColors.actionPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_student_tools_title'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: KpbColors.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'home_student_tools_subtitle'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: KpbColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: KpbColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "They did it before you" — real Parcours & Témoignages stories (PR #109),
// just surfaced on Home. Fetches once; self-hides until real stories load.
// Does not modify anything under lib/app/features/parcours/.
// ─────────────────────────────────────────────────────────────────────────────
class _ParcoursHomeCarousel extends StatefulWidget {
  const _ParcoursHomeCarousel();

  @override
  State<_ParcoursHomeCarousel> createState() => _ParcoursHomeCarouselState();
}

class _ParcoursHomeCarouselState extends State<_ParcoursHomeCarousel> {
  @override
  void initState() {
    super.initState();
    // Safe to call repeatedly — skips the network round-trip once populated.
    Get.find<AppController>().fetchParcoursStories();
  }

  void _open(ParcoursStory story, List<ParcoursStory> videoStories) {
    if (story.isVideo) {
      final playable = videoStories
          .where((v) => (v.youtubeId ?? '').isNotEmpty)
          .toList(growable: false);
      if ((story.youtubeId ?? '').isEmpty || playable.isEmpty) {
        Get.snackbar(
          'parcours_appbar_title'.tr,
          'parcours_video_unavailable'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final index = playable.indexWhere((v) => v.slug == story.slug);
      Get.to(() => ParcoursPlayerScreen(
            videos: playable,
            initialIndex: index < 0 ? 0 : index,
          ));
    } else {
      Get.to(() => ParcoursStoryScreen(story: story));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final stories = controller.parcoursStories.take(6).toList();
        if (stories.isEmpty) return const SizedBox.shrink();
        final videoStories =
            controller.parcoursStories.where((s) => s.isVideo).toList();
        final locale = controller.localeCode;

        // This section lives in its own SliverToBoxAdapter (outside the padded
        // Column at the top of the scroll view), so it must carry the page
        // gutter itself — same recipe as HScrollSection ("Bourses pour toi",
        // "Universités recommandées"): header padded, and the horizontal list
        // padded via its `padding` so cards align with the gutter but still
        // scroll edge-to-edge.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'home_parcours_title'.tr,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: KpbColors.brandNavy,
                          ),
                        ),
                        Text(
                          'home_parcours_subtitle'.tr,
                          style: const TextStyle(
                              fontSize: 10.5, color: KpbColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.to(() => const ParcoursScreen()),
                    child: Text(
                      'see_all'.tr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.actionPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
                itemCount: stories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (ctx, i) {
                  final story = stories[i];
                  return _ParcoursHomeCard(
                    story: story,
                    locale: locale,
                    onTap: () => _open(story, videoStories),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParcoursHomeCard extends StatelessWidget {
  const _ParcoursHomeCard({
    required this.story,
    required this.locale,
    required this.onTap,
  });

  final ParcoursStory story;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = story.title.resolve(locale);
    final who = story.personName.isNotEmpty
        ? story.personName
        : story.role.resolve(locale);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 172,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              color: KpbColors.brandNavy,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        story.isVideo
                            ? Icons.play_arrow_rounded
                            : Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  if (story.durationMinutes != null)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${story.durationMinutes} min',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.brandNavy,
                      height: 1.3,
                    ),
                  ),
                  if (who.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: KpbColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Talk to a KPB counselor" — dark navy WhatsApp hand-off card. No in-app
// payment/checkout anywhere on Home; every advisor contact routes through
// the official KPB WhatsApp line.
// ─────────────────────────────────────────────────────────────────────────────
class _CounselorWhatsAppCard extends StatelessWidget {
  const _CounselorWhatsAppCard();

  void _open() {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill: kpbWhatsAppPrefill(),
      source: 'home',
      contextType: 'home_counselor_card',
    );
  }

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: _open,
      child: Container(
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: KpbRadius.xlBr,
        ),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KpbColors.whatsapp,
                borderRadius: KpbRadius.mdBr,
              ),
              child:
                  const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_counselor_cta_title'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'home_counselor_cta_subtitle'.tr,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: KpbColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: KpbColors.decorSky, size: 17),
          ],
        ),
      ),
    );
  }
}
