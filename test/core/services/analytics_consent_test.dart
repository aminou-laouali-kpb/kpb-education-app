// Garde : l'interrupteur « Analyse d'usage » doit gouverner LES TROIS
// collecteurs — Firebase Analytics, Firebase Crashlytics et PostHog.
//
// Le défaut corrigé : `setCrashlyticsCollectionEnabled` n'apparaissait nulle
// part, donc refuser l'analyse d'usage ne coupait pas les diagnostics de
// plantage, et le formulaire Play devait déclarer « Crash logs » OBLIGATOIRE.
//
// Pourquoi passer par les champs `*Consent` et non par les SDK : sans app
// Firebase par défaut, les appels réels lèvent, et le catch par collecteur les
// avale. Un test écrit contre les SDK resterait donc VERT pendant qu'un
// collecteur continue de collecter — c'est précisément le mode de panne qui a
// laissé Crashlytics allumé. Le test vérifie en plus que le champ qu'il
// remplace pointe bien, en production, sur le vrai applicateur Crashlytics
// (`same(applyCrashlyticsConsent)`) : sinon la couture masquerait le défaut au
// lieu de le détecter.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/observability/crashlytics_observability.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';

import '../../widget_test_helpers.dart';

void main() {
  final service = AnalyticsService.instance;

  // Capturés AVANT toute substitution : ce sont les branchements réellement
  // livrés.
  final defaultFirebase = service.firebaseAnalyticsConsent;
  final defaultCrashlytics = service.crashlyticsConsent;
  final defaultPosthog = service.posthogConsent;
  final defaultPosthogWired = service.posthogWired;

  late List<String> applied;

  setUp(() {
    applied = <String>[];
    service.firebaseAnalyticsConsent =
        (enabled) async => applied.add('firebase:$enabled');
    service.crashlyticsConsent =
        (enabled) async => applied.add('crashlytics:$enabled');
    service.posthogConsent = (enabled) async => applied.add('posthog:$enabled');
    service.posthogWired = true;
  });

  tearDown(() {
    // AnalyticsService est un singleton : sans restauration, les substitutions
    // fuiraient vers les autres tests du même fichier binaire.
    service.firebaseAnalyticsConsent = defaultFirebase;
    service.crashlyticsConsent = defaultCrashlytics;
    service.posthogConsent = defaultPosthog;
    service.posthogWired = defaultPosthogWired;
  });

  group('setCollectionEnabled', () {
    test('un refus coupe les trois collecteurs', () async {
      await service.setCollectionEnabled(false);

      expect(
        applied,
        contains('crashlytics:false'),
        reason: "Refuser l'analyse d'usage doit couper les diagnostics de "
            'plantage : sans cela le formulaire Play doit déclarer '
            '« Crash logs » obligatoire, et l\'interrupteur ment.',
      );
      expect(
        applied.toSet(),
        {'firebase:false', 'crashlytics:false', 'posthog:false'},
      );
      expect(applied, hasLength(3),
          reason: 'un collecteur appelé deux fois, ou un collecteur oublié');
    });

    test('une acceptation rallume les trois collecteurs', () async {
      await service.setCollectionEnabled(true);

      expect(
        applied.toSet(),
        {'firebase:true', 'crashlytics:true', 'posthog:true'},
      );
      expect(applied, hasLength(3));
    });

    test('sans PostHog câblé, Firebase et Crashlytics sont quand même coupés',
        () async {
      // Cas de production réel : aucune clé PostHog n'est fournie. Un `return`
      // anticipé placé avant Crashlytics laisserait alors les plantages
      // remonter sur toutes les installations.
      service.posthogWired = false;

      await service.setCollectionEnabled(false);

      expect(applied.toSet(), {'firebase:false', 'crashlytics:false'});
    });

    test('un collecteur qui échoue ne laisse pas les autres allumés', () async {
      service.crashlyticsConsent = (_) async => throw StateError('no Firebase');

      await service.setCollectionEnabled(false);

      expect(
        applied.toSet(),
        {'firebase:false', 'posthog:false'},
        reason: 'un try/catch unique arrêterait la boucle au premier SDK '
            'absent et laisserait les suivants collecter après un refus',
      );
    });

    test("le champ Crashlytics pointe sur le vrai applicateur en production",
        () {
      expect(
        defaultCrashlytics,
        same(applyCrashlyticsConsent),
        reason: 'si la couture ne mène pas au vrai appel SDK, les tests '
            'ci-dessus mesurent une maquette et ne prouvent rien',
      );
    });
  });

  group('application au démarrage', () {
    // Un refus doit survivre au redémarrage. Le point d'application est dans
    // lib/main.dart et lib/app/core/controllers/app_controller.dart, hors du
    // périmètre de ce lot : la garde est donc structurelle — elle vérifie que
    // le chemin de boot traverse toujours le MÊME entonnoir que l'interrupteur,
    // celui qui couvre désormais Crashlytics.
    test('main() réapplique le choix persisté après hydrate', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(
        main,
        contains('controller.applyAnalyticsConsent()'),
        reason: 'sans cet appel au démarrage, un refus est oublié au prochain '
            'lancement et les trois collecteurs repartent',
      );
    });

    test('applyAnalyticsConsent passe par setCollectionEnabled', () {
      final controller =
          File('lib/app/core/controllers/app_controller/preferences.dart')
              .readAsStringSync();
      final body = RegExp(r'void applyAnalyticsConsent\(\)\s*\{([^}]*)\}')
          .firstMatch(controller);

      expect(body, isNotNull,
          reason: 'AppController.applyAnalyticsConsent a disparu ou changé de '
              'signature : le chemin de démarrage n\'est plus vérifié');
      expect(
        body!.group(1),
        contains('setCollectionEnabled(!analyticsOptOut)'),
        reason: 'le boot doit passer par l\'entonnoir unique ; un appel direct '
            'à un SDK y contournerait Crashlytics',
      );
    });

    // ── Revue du build 49 : la mesure est ACTIVE PAR DÉFAUT ────────────────
    //
    // Les deux gardes ci-dessus lisent le SOURCE. Elles ne peuvent pas dire ce
    // que `hydrate()` calcule réellement, et c'est précisément la question ici :
    // basculer un défaut de consentement, c'est un endroit où « le source
    // contient la bonne ligne » et « le refus de l'utilisateur est respecté »
    // peuvent diverger. Ces trois cas exercent donc le vrai contrôleur.
    test('hydrate() : un indécis collecte, un refus explicite est préservé',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      setupPlatformChannelMocks();

      Future<bool> optOutAfterHydrate(AppSnapshot snapshot) async {
        final controller = AppController(
          repository: FakeRepository(snapshot: snapshot),
          apiClient: MockApiClient(),
        );
        await controller.hydrate();
        return controller.analyticsOptOut;
      }

      const base = AppSnapshot(localeCode: 'fr', hasCompletedOnboarding: true);

      // (1) Jamais tranché → la mesure tourne. C'est le changement demandé.
      expect(
        await optOutAfterHydrate(base),
        isFalse,
        reason: 'sans décision de l\'utilisateur, la mesure d\'audience doit '
            'être active (défaut annoncé dans les CGU)',
      );

      // (2) Un instantané d'indécis qui portait `analyticsOptOut: true` — le
      // cas de TOUS les installés du build 49 — bascule lui aussi, parce que
      // ce `true` n'était pas un choix, seulement l'ancien défaut.
      expect(
        await optOutAfterHydrate(
          const AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            analyticsOptOut: true,
          ),
        ),
        isFalse,
        reason: 'un `optOut` persisté SANS décision est l\'ancien défaut, pas '
            'un refus : il ne doit pas survivre au changement de politique',
      );

      // (3) LA garde qui protège quelqu'un : un refus explicite survit. Si ce
      // cas passe au vert en rendant `false`, le changement de défaut a révoqué
      // une décision prise — exactement ce qu'il ne doit jamais faire.
      expect(
        await optOutAfterHydrate(
          const AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            analyticsOptOut: true,
            analyticsConsentDecided: true,
          ),
        ),
        isTrue,
        reason: 'un refus EXPLICITE doit survivre au changement de défaut',
      );

      // (4) Symétrique : une acceptation explicite reste une acceptation.
      expect(
        await optOutAfterHydrate(
          const AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            analyticsOptOut: false,
            analyticsConsentDecided: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('entonnoir unique', () {
    test(
        'setCrashlyticsCollectionEnabled n\'est appelé qu\'au seul endroit '
        'gouverné par le consentement', () {
      final callers = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // Les lignes de commentaire sont écartées : une simple MENTION du nom
        // de l'appel dans une doc suffirait sinon à satisfaire la garde alors
        // que l'appel réel a disparu.
        final code = entity
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        if (code.contains('setCrashlyticsCollectionEnabled(')) {
          callers.add(entity.path);
        }
      }

      expect(
        callers,
        hasLength(1),
        reason: 'zéro appel = les diagnostics de plantage ignorent '
            'l\'interrupteur (le défaut d\'origine) ; deux appels ou plus = un '
            'chemin peut rallumer la collecte sans consentement. Trouvés : '
            '$callers',
      );
      expect(
        callers.single.replaceAll(r'\', '/'),
        endsWith('lib/app/core/observability/crashlytics_observability.dart'),
      );

      final applier = File(callers.single).readAsStringSync();
      expect(
        applier,
        contains('setCrashlyticsCollectionEnabled(enabled)'),
        reason: 'l\'appel doit propager la décision de l\'utilisateur, pas un '
            'littéral true/false',
      );
      expect(
        applier,
        contains('deleteUnsentReports()'),
        reason: 'un refus doit aussi écarter les rapports déjà en attente sur '
            'le disque, sinon ils partent au lancement suivant',
      );
    });
  });
}
