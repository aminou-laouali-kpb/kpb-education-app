import 'package:get/get.dart';

import '../models/app_models.dart';
import '../../features/alumni/alumni_directory_screen.dart';
import '../../features/cases/case_create_screen.dart';
import '../../features/cases/case_detail_screen.dart';
import '../../features/community/hub/community_hub_screen.dart';
import '../../features/community/hub/community_post_screen.dart';
import '../../features/deadlines/deadline_calendar_screen.dart';
import '../../features/eligibility/eligibility_simulator_screen.dart';
import '../../features/legal/legal_pages.dart';
import '../../features/etudes_en_france/eef_catalog_screen.dart';
import '../../features/etudes_en_france/eef_entry.dart';
import '../../features/orientation/orientation_screen.dart';
import '../../features/parcours/parcours_link_screen.dart';
import '../../features/parcours/parcours_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/salon/salon_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/scholarship_match/scholarship_match_results_screen.dart';
import '../../features/scholarships/live_scholarships_screen.dart';
import '../../features/scholarships/scholarship_detail_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/services/service_packages_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/success_lab/success_lab_list_screen.dart';
import '../../features/success_lab/success_lab_schedule_screen.dart';
import '../../features/success_lab/success_lab_submission_screen.dart';
import '../../features/success_lab/success_lab_outcome_screen.dart';
import '../../features/success_lab/success_lab_diagnostic_screen.dart';
import '../../features/success_lab/success_lab_study_review_screen.dart';
import '../../features/success_lab/success_lab_workspace_screen.dart';

/// Define named routes specifically for handling deep links and push notifications.
///
/// Most of the app can still use `Get.to(() => Screen())` for internal navigation,
/// but routes defined here allow external URLs (like `kpb://cases/123`) to open
/// specific screens directly.
class AppRoutes {
  static const String home = '/';
  static const String search = '/search';
  static const String scholarships = '/scholarships';
  static const String scholarshipDetail = '/scholarships/:id';
  static const String _scholarshipPrefix = '/scholarships/';

  /// Le test « Mes 10 bourses » (résultats, et l'assistant s'il n'y a pas
  /// encore de run). Volontairement HORS de `/scholarships/` : sous ce
  /// préfixe, `match` serait lu comme l'identifiant d'une bourse. Le push
  /// hebdomadaire « nouvelles bourses compatibles » (opt-in) y atterrit.
  static const String scholarshipMatch = '/scholarship-match';
  static const String successLab = '/success-lab';
  static const String successLabWorkspace = '/success-lab/:workspaceId';
  static const String successLabDiagnostic =
      '/success-lab/:workspaceId/diagnostic';
  static const String successLabStudyReview =
      '/success-lab/:workspaceId/study-review';
  static const String successLabSchedule = '/success-lab/:workspaceId/schedule';
  static const String successLabSubmission =
      '/success-lab/:workspaceId/submission';
  static const String successLabOutcome = '/success-lab/:workspaceId/outcome';
  static const String _successLabPrefix = '/success-lab/';

  /// Un récit Parcours (vidéo ou texte) par son slug. Le push hebdomadaire
  /// « récit de la semaine » vise `/parcours/<slug>` : sans cette route,
  /// `normalizeExternalRoute` la rejetait et l'élève restait sur l'accueil.
  static const String parcoursDetail = '/parcours/:slug';
  static const String _parcoursPrefix = '/parcours/';

  /// La communauté (drapeau distant `community`). Les notifications
  /// `community_*` visent `/community/posts/<postId>` (contrat §11).
  /// Drapeau fermé : l'écran le dit honnêtement, sans fil vide.
  static const String community = '/community';
  static const String communityPost = '/community/posts/:id';
  static const String _communityPostPrefix = '/community/posts/';

  static String communityPostPath(String postId) =>
      '$_communityPostPrefix${Uri.encodeComponent(postId)}';

  static String parcoursDetailPath(String slug) =>
      '$_parcoursPrefix${Uri.encodeComponent(slug)}';

  static String scholarshipDetailPath(String id) =>
      '$_scholarshipPrefix${Uri.encodeComponent(id)}';

  static String successLabWorkspacePath(String workspaceId) =>
      '$_successLabPrefix${Uri.encodeComponent(workspaceId)}';

  static String successLabDiagnosticPath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/diagnostic';

  static String successLabStudyReviewPath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/study-review';

  static String successLabSchedulePath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/schedule';

  static String successLabSubmissionPath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/submission';

  static String successLabOutcomePath(String workspaceId) =>
      '${successLabWorkspacePath(workspaceId)}/outcome';
  // High-intent re-engagement targets (KPB-63): named so push/deep-links can
  // land on the right screen instead of dumping the user on Home.
  static const String orientation = '/orientation';
  static const String eligibility = '/eligibility';

  /// Espace « Études en France ». Nommé d'après la PROCÉDURE et non d'après
  /// Campus France, qui est un opérateur de l'État français : la route part dans
  /// les liens profonds et les charges de notification, donc elle porte le même
  /// choix de nom que l'écran.
  static const String etudesEnFrance = '/etudes-en-france';

  /// Le catalogue dense, joignable en lien profond. La notification du jour J
  /// peut viser directement la recherche plutôt que l'accueil de l'espace :
  /// sans cette route, elle ne le pourrait pas.
  static const String etudesEnFranceCatalog = '/etudes-en-france/catalogue';
  static const String saved = '/saved';
  static const String deadlines = '/deadlines';
  static const String alumni = '/alumni';
  static const String salon = '/salon';
  static const String services = '/services';
  static const String profile = '/profile';

  /// La politique de confidentialité, joignable par une notification (audit
  /// 57, F11) : la campagne « Notre politique évolue » doit ouvrir le texte,
  /// pas l'accueil. Nom figé, partagé avec la console et la documentation.
  static const String legalPrivacy = '/legal/privacy';

  /// Intentionally not under `/cases/...` so it never collides with `/cases/:id` (e.g. id "create").
  static const String caseCreate = '/new-case';
  static const String caseDetail = '/cases/:id';
  static const String _casePrefix = '/cases/';
  static const String _legacyCaseCreate = '/cases/create';

  /// Normalizes external route payloads (quick actions, deep links, FCM).
  /// Returns null when route is unsupported/invalid.
  static String? normalizeExternalRoute(String? rawRoute) {
    final route = rawRoute?.trim();
    if (route == null || route.isEmpty || !route.startsWith('/')) {
      return null;
    }

    // Backward-compatibility for older payloads sent before case-create route rename.
    if (route == _legacyCaseCreate) {
      return caseCreate;
    }

    if (route.startsWith(_casePrefix)) {
      final caseId = route.substring(_casePrefix.length);
      // Reject empty or nested ids (`/cases/` or `/cases/a/b`).
      if (caseId.isEmpty || caseId.contains('/')) return null;
      return '/cases/$caseId';
    }

    if (route.startsWith(_scholarshipPrefix)) {
      final scholarshipId = route.substring(_scholarshipPrefix.length);
      if (scholarshipId.isEmpty || scholarshipId.contains('/')) return null;
      return '$_scholarshipPrefix$scholarshipId';
    }

    if (route.startsWith(_communityPostPrefix)) {
      final postId = route.substring(_communityPostPrefix.length);
      if (postId.isEmpty || postId.contains('/')) return null;
      return '$_communityPostPrefix$postId';
    }

    if (route.startsWith(_parcoursPrefix)) {
      final slug = route.substring(_parcoursPrefix.length);
      if (slug.isEmpty || slug.contains('/')) return null;
      return '$_parcoursPrefix$slug';
    }

    if (route.startsWith(_successLabPrefix)) {
      final tail = route.substring(_successLabPrefix.length);
      final segments = tail.split('/');
      if (segments.length == 2 && segments.first.isNotEmpty) {
        if (segments.last == 'diagnostic' ||
            segments.last == 'study-review' ||
            segments.last == 'schedule' ||
            segments.last == 'submission' ||
            segments.last == 'outcome') {
          return '$_successLabPrefix${segments.first}/${segments.last}';
        }
        return null;
      }
      if (segments.length != 1 || segments.first.isEmpty) return null;
      return '$_successLabPrefix${segments.first}';
    }

    final known = <String>{
      home,
      search,
      caseCreate,
      orientation,
      eligibility,
      // La notification push du jour J atterrit ici. Sans cette entrée,
      // `normalizeExternalRoute` la rejette et l'utilisateur est déposé sur
      // l'accueil — c'est-à-dire que la campagne s'ouvre sans que personne ne
      // trouve la porte.
      etudesEnFrance,
      etudesEnFranceCatalog,
      saved,
      deadlines,
      alumni,
      salon,
      services,
      profile,
      // Campagne « Notre politique évolue » (F11) : le tap ouvre la politique.
      legalPrivacy,
      // Scholarship-opening push notifications land on this acquisition screen.
      scholarships,
      scholarshipMatch,
      successLab,
      community,
    };
    if (known.contains(route)) return route;
    return null;
  }

  static final List<GetPage> pages = [
    GetPage(
      name: home,
      page: () => const AppShell(),
    ),
    GetPage(
      name: search,
      page: () => const SearchScreen(),
    ),
    // Live-scholarships aggregator (unlocked for launch): serves the real
    // scraped /scholarships feed, with an honest empty state when the feed is
    // empty. Community stays MVP-gated (no real forum content yet).
    GetPage(
      name: scholarships,
      page: () => const LiveScholarshipsScreen(),
    ),
    // Drapeau fermé, invité ou compte non élève : le lien profond retombe
    // sur l'onglet Bourses (l'écran décide, il lit le drapeau à l'ouverture).
    GetPage(
      name: scholarshipMatch,
      page: () => const ScholarshipMatchResultsScreen(source: 'deep_link'),
    ),
    GetPage(
      name: scholarshipDetail,
      page: () {
        final scholarshipId = Get.parameters['id'];
        if (scholarshipId == null || scholarshipId.isEmpty) {
          return const LiveScholarshipsScreen();
        }
        final initial = Get.arguments;
        return ScholarshipDetailScreen(
          scholarshipId: scholarshipId,
          initialScholarship: initial is LiveScholarshipModel ? initial : null,
        );
      },
    ),
    GetPage(
      name: community,
      page: () => const CommunityHubScreen(source: 'deep_link'),
    ),
    GetPage(
      name: communityPost,
      page: () {
        final postId = Get.parameters['id'];
        if (postId == null || postId.isEmpty) {
          return const CommunityHubScreen(source: 'deep_link');
        }
        return CommunityPostScreen(postId: postId, source: 'notification');
      },
    ),
    GetPage(
      name: parcoursDetail,
      page: () {
        final slug = Get.parameters['slug'];
        if (slug == null || slug.isEmpty) return const ParcoursScreen();
        return ParcoursLinkScreen(slug: slug);
      },
    ),
    // Success Lab stays a pushed, deep-linkable workflow. It deliberately does
    // not add a sixth shell tab to the five-tab student navigation.
    GetPage(
      name: successLab,
      page: () => const SuccessLabListScreen(),
    ),
    GetPage(
      name: successLabWorkspace,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabWorkspaceScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabDiagnostic,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabDiagnosticScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabStudyReview,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabStudyReviewScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabSchedule,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabScheduleScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabSubmission,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabSubmissionScreen(workspaceId: workspaceId);
      },
    ),
    GetPage(
      name: successLabOutcome,
      page: () {
        final workspaceId = Get.parameters['workspaceId'];
        if (workspaceId == null || workspaceId.isEmpty) {
          return const SuccessLabListScreen();
        }
        return SuccessLabOutcomeScreen(workspaceId: workspaceId);
      },
    ),
    // High-intent re-engagement destinations (KPB-63). Each is a standalone,
    // pushable screen with its own app bar.
    GetPage(name: orientation, page: () => const OrientationScreen()),
    GetPage(name: eligibility, page: () => const EligibilitySimulatorScreen()),
    // Toujours joignable, même drapeaux éteints : [EefEntry] arbitre entre la
    // vitrine, l'espace réel et `ComingSoonScreen`. Une route absente ferait
    // d'un lien profond un cul-de-sac silencieux.
    GetPage(
      name: etudesEnFrance,
      page: () => const EefEntry(source: 'deep_link'),
    ),
    GetPage(
      name: etudesEnFranceCatalog,
      // Le hub passe `'hub'` en argument ; un lien profond ou une notification
      // n'en passent aucun — la mesure peut ainsi dire quelle porte amène du monde.
      page: () => EefCatalogScreen(
        source: Get.arguments is String ? Get.arguments as String : 'deep_link',
      ),
    ),
    GetPage(name: saved, page: () => const SavedScreen()),
    GetPage(name: deadlines, page: () => const DeadlineCalendarScreen()),
    GetPage(name: alumni, page: () => const AlumniDirectoryScreen()),
    GetPage(name: salon, page: () => const SalonScreen()),
    GetPage(name: services, page: () => const ServicePackagesScreen()),
    GetPage(name: profile, page: () => const ProfileScreen()),
    GetPage(name: legalPrivacy, page: () => const PrivacyPolicyScreen()),
    GetPage(
      name: caseCreate,
      page: () => const CaseCreateScreen(),
    ),
    GetPage(
      name: caseDetail,
      page: () {
        final caseId = Get.parameters['id'];
        if (caseId == null) return const AppShell();
        return CaseDetailScreen(caseId: caseId);
      },
    ),
  ];
}
