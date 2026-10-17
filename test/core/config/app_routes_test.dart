import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/config/app_routes.dart';

void main() {
  group('AppRoutes.normalizeExternalRoute', () {
    test('returns known static routes', () {
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.home),
        AppRoutes.home,
      );
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.search),
        AppRoutes.search,
      );
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.caseCreate),
        AppRoutes.caseCreate,
      );
    });

    test('resolves the high-intent deep-link targets (KPB-63)', () {
      for (final route in [
        AppRoutes.orientation,
        AppRoutes.eligibility,
        AppRoutes.saved,
        AppRoutes.deadlines,
        AppRoutes.alumni,
        AppRoutes.salon,
        AppRoutes.services,
        AppRoutes.profile,
      ]) {
        expect(AppRoutes.normalizeExternalRoute(route), route);
        // …and surrounding whitespace from a payload is tolerated.
        expect(AppRoutes.normalizeExternalRoute('  $route '), route);
      }
    });

    test('resolves /scholarships even under the MVP lock (graceful)', () {
      // `/scholarships` always normalizes now: under the MVP lock its page
      // renders a "coming soon" placeholder, so a deep-link never dies
      // silently (it no longer returns null).
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.scholarships),
        AppRoutes.scholarships,
      );
    });

    test('normalizes valid case detail route', () {
      expect(
        AppRoutes.normalizeExternalRoute('/cases/abc123'),
        '/cases/abc123',
      );
    });

    test('normalizes a valid scholarship detail route', () {
      expect(
        AppRoutes.normalizeExternalRoute('/scholarships/sch-123'),
        '/scholarships/sch-123',
      );
      expect(
        AppRoutes.scholarshipDetailPath('sch-123'),
        '/scholarships/sch-123',
      );
      expect(AppRoutes.normalizeExternalRoute('/scholarships/'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/scholarships/a/b'), isNull);
    });

    test('normalizes a Parcours story route (weekly push)', () {
      expect(
        AppRoutes.normalizeExternalRoute('/parcours/awa-diallo-medecine'),
        '/parcours/awa-diallo-medecine',
      );
      expect(
        AppRoutes.normalizeExternalRoute('  /parcours/awa-diallo '),
        '/parcours/awa-diallo',
      );
      expect(
        AppRoutes.parcoursDetailPath('awa diallo'),
        '/parcours/awa%20diallo',
      );
      expect(AppRoutes.normalizeExternalRoute('/parcours/'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/parcours/a/b'), isNull);
    });

    test('normalizes Success Lab list and workspace routes', () {
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.successLab),
        AppRoutes.successLab,
      );
      expect(
        AppRoutes.normalizeExternalRoute('/success-lab/workspace-1'),
        '/success-lab/workspace-1',
      );
      expect(
        AppRoutes.successLabWorkspacePath('workspace 1'),
        '/success-lab/workspace%201',
      );
      expect(
        AppRoutes.normalizeExternalRoute(
          '/success-lab/workspace-1/diagnostic',
        ),
        '/success-lab/workspace-1/diagnostic',
      );
      expect(
        AppRoutes.successLabDiagnosticPath('workspace 1'),
        '/success-lab/workspace%201/diagnostic',
      );
      expect(
        AppRoutes.normalizeExternalRoute(
          '/success-lab/workspace-1/study-review',
        ),
        '/success-lab/workspace-1/study-review',
      );
      expect(
        AppRoutes.successLabStudyReviewPath('workspace 1'),
        '/success-lab/workspace%201/study-review',
      );
      expect(
        AppRoutes.normalizeExternalRoute(
          '/success-lab/workspace-1/schedule',
        ),
        '/success-lab/workspace-1/schedule',
      );
      expect(
        AppRoutes.successLabSchedulePath('workspace 1'),
        '/success-lab/workspace%201/schedule',
      );
      expect(
        AppRoutes.normalizeExternalRoute(
          '/success-lab/workspace-1/submission',
        ),
        '/success-lab/workspace-1/submission',
      );
      expect(
        AppRoutes.successLabSubmissionPath('workspace 1'),
        '/success-lab/workspace%201/submission',
      );
      expect(
        AppRoutes.normalizeExternalRoute(
          '/success-lab/workspace-1/outcome',
        ),
        '/success-lab/workspace-1/outcome',
      );
      expect(
        AppRoutes.successLabOutcomePath('workspace 1'),
        '/success-lab/workspace%201/outcome',
      );
      expect(AppRoutes.normalizeExternalRoute('/success-lab/'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/success-lab/a/other'), isNull);
    });

    test('resolves the « Études en France » catalogue deep link', () {
      // La route vit sous `/etudes-en-france/`, donc elle ressemble à un
      // identifiant de détail. Ce test fixe qu'elle est reconnue TELLE QUELLE
      // et non découpée en « espace + segment inconnu ».
      expect(
        AppRoutes.normalizeExternalRoute(AppRoutes.etudesEnFranceCatalog),
        AppRoutes.etudesEnFranceCatalog,
      );
      expect(
        AppRoutes.normalizeExternalRoute('  /etudes-en-france/catalogue '),
        AppRoutes.etudesEnFranceCatalog,
      );
      expect(
        AppRoutes.normalizeExternalRoute('/etudes-en-france/inconnu'),
        isNull,
      );
    });

    test('maps legacy create route to current route', () {
      expect(
        AppRoutes.normalizeExternalRoute('/cases/create'),
        AppRoutes.caseCreate,
      );
    });

    test('accepts surrounding whitespace from payloads', () {
      expect(
        AppRoutes.normalizeExternalRoute('   /search   '),
        AppRoutes.search,
      );
    });

    test('rejects invalid or unsupported routes', () {
      expect(AppRoutes.normalizeExternalRoute(null), isNull);
      expect(AppRoutes.normalizeExternalRoute(''), isNull);
      expect(AppRoutes.normalizeExternalRoute('cases/abc'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/cases/'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/cases/a/b'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/unknown'), isNull);
    });
  });

  group('AppRoutes.pages', () {
    test('registers all critical named routes for external openability', () {
      final names = AppRoutes.pages.map((page) => page.name).toSet();

      expect(names, contains(AppRoutes.home));
      expect(names, contains(AppRoutes.search));
      expect(names, contains(AppRoutes.caseCreate));
      expect(names, contains(AppRoutes.caseDetail));
      // `/scholarships` is always registered (renders a "coming soon" under the
      // MVP lock) so deep-links to it resolve gracefully.
      expect(names, contains(AppRoutes.scholarships));
      expect(names, contains(AppRoutes.scholarshipDetail));
      expect(names, contains(AppRoutes.successLab));
      expect(names, contains(AppRoutes.successLabWorkspace));
      expect(names, contains(AppRoutes.successLabDiagnostic));
      expect(names, contains(AppRoutes.successLabStudyReview));
      expect(names, contains(AppRoutes.successLabSchedule));
      expect(names, contains(AppRoutes.successLabSubmission));
      expect(names, contains(AppRoutes.successLabOutcome));
      // Le push hebdomadaire « récit de la semaine » vise `/parcours/<slug>`.
      expect(names, contains(AppRoutes.parcoursDetail));
      // High-intent re-engagement targets (KPB-63).
      for (final route in [
        AppRoutes.orientation,
        AppRoutes.eligibility,
        AppRoutes.saved,
        AppRoutes.deadlines,
        AppRoutes.alumni,
        AppRoutes.salon,
        AppRoutes.services,
        AppRoutes.profile,
      ]) {
        expect(names, contains(route));
      }
      // Espace « Études en France » : la route est enregistrée MÊME drapeaux
      // éteints, et c'est le point du test. La notification push du jour J
      // arrive avant que le drapeau serveur soit lu ; une route absente en
      // ferait un cul-de-sac silencieux, alors qu'`EefEntry` sait retomber sur
      // « bientôt disponible ».
      expect(names, contains(AppRoutes.etudesEnFrance));
      // Le catalogue a sa propre route, pour la même raison : une notification
      // peut viser la recherche elle-même plutôt que l'accueil de l'espace.
      expect(names, contains(AppRoutes.etudesEnFranceCatalog));
      // « Mes 10 bourses » : enregistrée MÊME drapeau fermé (l'écran retombe
      // sur l'onglet Bourses), pour la même raison.
      expect(names, contains(AppRoutes.scholarshipMatch));
      // Communauté : enregistrée MÊME drapeau fermé — les notifications
      // `community_*` visent `/community/posts/<id>`, et l'écran dit lui-même
      // « bientôt » quand le drapeau est fermé.
      expect(names, contains(AppRoutes.community));
      expect(names, contains(AppRoutes.communityPost));
      expect(names.length, equals(27));
    });
  });
}
