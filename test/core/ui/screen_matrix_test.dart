// LA MATRICE D'ÉCRANS RÉELS — 22 surfaces × 2 téléphones × 4 échelles de texte.
//
// Ce fichier n'est PAS tagué `golden`. Il tourne donc dans le portillon de fusion
// (`flutter test --exclude-tags="golden || known-defect"`, flutter-ci.yml), ce qui
// est tout l'intérêt : la machinerie qu'il utilise existait déjà dans
// test/goldens/review_captures_test.dart, exclue de la CI et sans un seul
// `expect`. On lui a ajouté des assertions et on l'a sortie de l'exclusion.
//
// Trois assertions par cas :
//   1. le nombre d'objets de rendu qui débordent ne dépasse pas son budget ;
//   2. aucune AUTRE erreur de rendu (une `LocaleDataException`, un `Null is not a
//      subtype of Future<List>` — les pannes qui font qu'un écran s'affiche vide
//      sans que personne ne le sache) ;
//   3. aucune clé de traduction brute à l'écran (`nav_cases` au lieu de
//      « Dossiers »), détectée par appartenance au dictionnaire et non par une
//      expression régulière de forme — voir test/support/raw_key_guard.dart.
//
// Et trois auto-contrôles qui rendent le harnais lui-même réfutable, parce que
// sur ce projet l'outil de vérification a été le menteur quatre fois :
//   · la SENTINELLE DE POLICE : si Inter n'est pas chargée, Flutter mesure Ahem
//     (un carré par glyphe) et toute assertion de largeur devient une mesure
//     d'autre chose, en restant verte ;
//   · le CANARI : un Column volontairement 10 px trop haut qui DOIT être
//     signalé — s'il se taît, les 106 cas « sans débordement » ne valent rien ;
//   · le CLAMP SURVEILLÉ : les bornes [1,0 ; 1,5] sont recopiées du `builder:` de
//     lib/main.dart, qu'un test ne peut pas atteindre. On relit donc le fichier
//     source et on échoue si les nombres ont divergé.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/features/ai_advisor/ai_chat_screen.dart';
import 'package:karatou/app/features/auth/auth_welcome_screen.dart';
import 'package:karatou/app/features/auth/magic_link_email_screen.dart';
import 'package:karatou/app/features/auth/magic_link_verify_screen.dart';
import 'package:karatou/app/features/cases/cases_screen.dart';
import 'package:karatou/app/features/community/hub/community_composer_screen.dart';
import 'package:karatou/app/features/community/hub/community_hub_screen.dart';
import 'package:karatou/app/features/community/hub/community_post_screen.dart';
import 'package:karatou/app/features/france/france_private_admission_screen.dart';
import 'package:karatou/app/features/home/home_screen.dart';
import 'package:karatou/app/features/housing/housing_estimator_screen.dart';
import 'package:karatou/app/features/matches/aha_moment_screen.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';
import 'package:karatou/app/features/onboarding/onboarding_referral_step.dart';
import 'package:karatou/app/features/referral/ambassador_competition_screen.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';
import 'package:karatou/app/features/shell/kpb_tools_drawer.dart';
import 'package:karatou/app/features/universities/universities_screen.dart';

import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../features/community/community_test_support.dart';
import '../../features/scholarships/scholarships_test_support.dart';
import '../../widget_test_helpers.dart';
import 'screen_overflow_budget.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Les surfaces qui ne construisent PAS leur propre Scaffold : elles rendent un
/// `Container` / `CustomScrollView` nu et ont besoin d'un Scaffold ambiant.
const _needsAmbientScaffold = {'HomeScreen', 'CasesScreen', 'KpbToolsDrawer'};

/// Les onglets du shell. `AppShell` donne un `drawer:` à SON Scaffold
/// (app_shell.dart:73-77) : c'est cette géométrie-là qu'il faut reproduire, et
/// c'est faute de l'avoir fait que la troncature du « Salut, … » est restée
/// invisible pendant toute une tournée de revue de captures.
const _shellTabs = {
  'HomeScreen',
  'LiveScholarshipsScreen',
  'UniversitiesScreen',
  'CasesScreen',
  'ProfileScreen',
};

/// Un client de bourses qui répond, pour que l'écran sorte de son état de
/// chargement au lieu d'être mesuré en shimmer.
MockApiClient _scholarshipApi() {
  final api = MockApiClient();
  // TOUS les critères passent par `whenScholarshipsPage` : un argument nommé
  // oublié et le `when` ne correspond plus, mocktail rend `null`, et l'écran
  // s'afficherait vide sans que le test le dise.
  whenScholarshipsPage(api)
      .thenAnswer((_) async => scholarshipsPage(<dynamic>[]));
  when(() => api.fetchScholarshipAlerts()).thenAnswer((_) async => <String>{});
  return api;
}

/// Chaque surface et sa recette de montage. Les huit outils du tiroir sont
/// ajoutés depuis la liste du tiroir lui-même, pas recopiés : un outil ajouté
/// demain est couvert sans toucher ce fichier.
Map<String, Future<Widget> Function()> buildScreenSpecs() {
  final specs = <String, Future<Widget> Function()>{
    'HomeScreen': () async {
      await seedKpbController();
      return const HomeScreen();
    },
    'LiveScholarshipsScreen': () async {
      final api = _scholarshipApi();
      await seedKpbController(apiClient: api);
      return LiveScholarshipsScreen(apiClient: api);
    },
    'UniversitiesScreen': () async {
      await seedKpbController();
      return const UniversitiesScreen();
    },
    'CasesScreen': () async {
      await seedKpbController(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(fullName: 'Mouhamadou Diallo'),
        ),
      );
      return const CasesScreen();
    },
    'ProfileScreen': () async {
      await seedKpbController();
      return const ProfileScreen();
    },
    'AiChatScreen': () async {
      // Le profil est obligatoire : sans lui `_bootstrap` sort tout de suite
      // (ai_chat_screen.dart:56) et l'écran se rendrait vide.
      await seedKpbController();
      return const AiChatScreen();
    },
    'AuthWelcomeScreen': () async {
      final auth = _MockAuthService();
      when(() => auth.onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());
      when(() => auth.isLoggedIn).thenReturn(false);
      Get.put<AuthService>(auth, permanent: true);
      return const AuthWelcomeScreen();
    },
    'MagicLinkEmailScreen': () async =>
        MagicLinkEmailScreen(authService: _MockAuthService()),
    'MagicLinkVerifyScreen': () async => MagicLinkVerifyScreen(
          authService: _MockAuthService(),
          // Une adresse longue et réaliste : elle est rendue via `trParams`
          // (magic_link_verify_screen.dart:111), donc sa longueur compte.
          email: 'mouhamadou.diallo@example.org',
        ),
    'KpbToolsDrawer': () async => const KpbToolsDrawer(),
    'FrancePrivateAdmissionScreen': () async {
      await seedKpbController();
      return const FrancePrivateAdmissionScreen();
    },
    'HousingEstimatorScreen': () async => const HousingEstimatorScreen(),
    // Deux routes HORS shell, ajoutées avec le plafond de police à 1,5
    // (build 57) : le parcours d'entrée d'un nouvel élève. L'écran « aha »
    // débordait de 153 px sur Android 360 dès ×1,0 dans ce harnais (libellé
    // « Voir toutes les universités » non flexible) — et réellement dès ×1,3
    // en français avec la police système.
    'OnboardingScreen': () async {
      await seedKpbController();
      return const OnboardingScreen();
    },
    'AhaMomentScreen': () async {
      // Le client simulé ne répond pas : l'écran prend son repli local, trois
      // écoles du catalogue — l'état que voit un élève hors ligne.
      await seedKpbController();
      return const AhaMomentScreen();
    },
  };

  // La communauté (drapeau distant `community` ouvert pour la mesure) :
  // l'accueil, le compositeur et une discussion complète — badges, réponse
  // vérifiée, entités citées, barre de réponse. Les libellés FR sont parmi
  // les plus longs de l'app (« Retour d'expérience », « Réponse vérifiée par
  // KPB ») : c'est à l'échelle 1,5 qu'ils débordaient sur 360 dp.
  Future<FakeCommunityApi> seedCommunity() async {
    resetCommunityWorld();
    final api = FakeCommunityApi();
    await seedKpbController(apiClient: api);
    return api;
  }

  specs['CommunityHubScreen'] = () async {
    await seedCommunity();
    return const CommunityHubScreen(source: 'matrix');
  };
  specs['CommunityComposerScreen'] = () async {
    await seedCommunity();
    return const CommunityComposerScreen();
  };
  specs['CommunityPostScreen'] = () async {
    await seedCommunity();
    return const CommunityPostScreen(postId: 'cp_1', source: 'matrix');
  };

  // Parrainage côté app (build 57) : l'écran de la compétition (participant,
  // en cours, non classable — le cas le plus chargé : notices provisoire et
  // « pas encore classé », trois compteurs, code, liens) et l'étape « code de
  // ton parrain » de fin d'onboarding.
  specs['AmbassadorCompetitionScreen'] = () async {
    final api = MockApiClient();
    when(() => api.getCurrentReferralCampaign()).thenAnswer((_) async => {
          'participating': true,
          'campaign': {
            'slug': 'ambassadeurs-novembre-2026',
            'nameFr': 'Compétition des ambassadeurs — novembre 2026',
            'nameEn': 'Ambassador competition — November 2026',
            'status': 'live',
            'phase': 'running',
            'startsAt': '2026-10-31T23:00:00.000Z',
            'endsAt': '2099-11-10T23:00:00.000Z',
            'provisional': true,
          },
          'me': {
            'publicName': 'Mouhamadou D.',
            'city': 'Ouagadougou',
            'code': 'KTOU-MD-1a2b3c',
            'rank': null,
            'qualified': 128,
            'toReview': 12,
            'pending': 45,
            'rankable': false,
          },
          'serverTime': DateTime.now().toUtc().toIso8601String(),
        });
    when(() => api.getPublicCampaignLeaderboard(any()))
        .thenAnswer((_) async => {
              'campaign': {'rulesUrl': 'https://kpbeducation.cloud/reglement'},
            });
    await seedKpbController(apiClient: api);
    return const AmbassadorCompetitionScreen();
  };
  specs['OnboardingReferralStep'] = () async {
    await seedKpbController();
    return OnboardingReferralStep(onFinished: () {});
  };

  for (final tool in KpbToolsDrawer.toolsForTest) {
    specs['tool:${tool.labelKey}'] = () async {
      await seedKpbController();
      return tool.builder();
    };
  }

  // Les quatre écrans IA sont RETOURNÉS dans la navigation (build 51,
  // `AppConfig.aiToolsEnabled` passé à `true`), donc la boucle `tool:`
  // ci-dessus les couvre désormais — avec leur vrai contexte de tiroir, ce qui
  // vaut mieux que le montage nu qu'on faisait ici.
  //
  // Ce bloc portait quatre entrées `ai:` explicites. Elles existaient pour une
  // raison précise et temporaire, écrite dans leur propre commentaire : pendant
  // le masquage, la boucle ne les voyait pas, et la matrice aurait perdu quatre
  // surfaces pendant des mois pour les retrouver non mesurées le jour de la
  // rebascule. Le masquage levé, les garder ferait compter chaque écran DEUX
  // fois — un doublon qui ne mesure rien de plus.
  //
  // Si le drapeau devait être refermé (`--dart-define=KPB_AI_TOOLS_ENABLED=false`),
  // il faudrait les remettre : c'est le sens de la note laissée ici.

  return specs;
}

String caseKey(String screen, KpbViewport viewport, double scale) =>
    '$screen@${viewport.id}@$scale';

void main() {
  final specs = buildScreenSpecs();

  setUpAll(() async {
    registerScholarshipListFallbacks();
    TestWidgetsFlutterBinding.ensureInitialized();
    // CasesScreen formate ses dates avec `DateFormat(..., 'fr')`
    // (cases_screen.dart:299) et lèverait une LocaleDataException sans ceci.
    await initializeDateFormatting('fr');
  });

  tearDown(Get.reset);

  group('les auto-contrôles du harnais', () {
    testWidgets('la sentinelle de police prouve qu\'Inter est chargée',
        (tester) async {
      final width = await measureFontSentinel(tester);

      // Mesuré : 169,6 px avec Inter 14 pt. Ahem donnerait 27 × 14 = 378 px.
      // La bande est large parce qu'on ne veut PAS un test de rendu au pixel —
      // on veut savoir si c'est Inter ou un carré par glyphe.
      expect(
        width,
        inInclusiveRange(160, 185),
        reason: 'La sentinelle « $kpbFontSentinelText » mesure '
            '${width.toStringAsFixed(1)} px au lieu de ~170. Ahem en donnerait '
            '$kpbAhemSentinelWidth : si vous en êtes proche, '
            'test/flutter_test_config.dart ne charge plus Inter et TOUTE '
            "assertion de largeur ou de débordement du dépôt mesure autre chose "
            "que l'app.",
      );
      expect(width, lessThan(kpbAhemSentinelWidth * 0.7));
    });

    testWidgets('le canari est signalé — le mécanisme est vivant',
        (tester) async {
      final report = await pumpKpbScreen(
        tester,
        screen: const KpbOverflowCanary(),
        viewport: compactAndroid,
        ownsScaffold: false,
      );

      expect(
        report.overflows,
        isNotEmpty,
        reason: 'Un Column 10 px trop haut n\'a rien déclenché. Le mécanisme '
            'de détection est mort, et les 106 cas « sans débordement » de ce '
            'fichier ne prouvent plus rien.',
      );
      expect(report.overflowPixels, closeTo(10, 0.5));
    });

    test('le clamp du harnais correspond à celui de lib/main.dart', () {
      final production = readMainDartTextScaleClamp();
      expect(
        production,
        isNotNull,
        reason: 'Le motif `minScaleFactor: … maxScaleFactor: …` a disparu de '
            'lib/main.dart. Si la production ne borne plus l\'échelle de texte '
            'ainsi, ce harnais mesure une géométrie qui n\'existe plus : '
            'relisez main.dart avant de toucher à ce test.',
      );
      expect(production!.min, kpbMinTextScale);
      expect(production.max, kpbMaxTextScale);
    });

    test('la matrice couvre tous les outils du tiroir', () {
      // Un outil ajouté au tiroir sans être couvert ici serait un écran livré
      // sans qu'aucun test ne l'ait jamais monté.
      for (final tool in KpbToolsDrawer.toolsForTest) {
        expect(specs.containsKey('tool:${tool.labelKey}'), isTrue,
            reason: '${tool.labelKey} est proposé par le tiroir mais absent de '
                'la matrice.');
      }
      expect(
        specs.length * kpbPhoneViewports.length * kpbTextScales.length,
        screenMatrixCaseCount,
        reason: 'Le nombre de cas a changé (${specs.length} surfaces × '
            '${kpbPhoneViewports.length} téléphones × ${kpbTextScales.length} '
            'échelles). Si c\'est voulu, mettez screenMatrixCaseCount à jour ; '
            'sinon, une surface a été retirée de la couverture.',
      );
    });
  });

  group('la matrice', () {
    for (final entry in specs.entries) {
      final screen = entry.key;
      testWidgets(screen, (tester) async {
        final failures = <String>[];
        for (final viewport in kpbPhoneViewports) {
          for (final scale in kpbTextScales) {
            final key = caseKey(screen, viewport, scale);
            final budget = screenOverflowBudget[key] ?? 0;

            final report = await pumpKpbScreen(
              tester,
              screen: await entry.value(),
              viewport: viewport,
              textScale: scale,
              ownsScaffold: !_needsAmbientScaffold.contains(screen),
              inDrawerShell: _shellTabs.contains(screen),
            );

            if (report.overflows.length > budget) {
              final cause = screenOverflowKnownCauses[screen];
              failures.add(
                '  $key : ${report.overflows.length} débordement(s) '
                '(${report.overflowPixels.toStringAsFixed(1)} px) pour un budget '
                'de $budget\n    ${report.overflows.join('\n    ')}'
                '${cause == null ? '\n    → RÉGRESSION NEUVE : aucune cause connue pour cet écran.' : '\n    cause connue : $cause'}',
              );
            }
            if (report.otherErrors.isNotEmpty) {
              failures.add('  $key : erreur(s) de rendu hors débordement\n'
                  '    ${report.otherErrors.join('\n    ')}');
            }
            final rawKeys = rawTranslationKeysOnScreen(tester);
            if (rawKeys.isNotEmpty) {
              failures.add('  $key : clé(s) de traduction brute à l\'écran → '
                  '${rawKeys.join(', ')}');
            }
            Get.reset();
          }
        }

        expect(
          failures,
          isEmpty,
          reason: '$screen — ${failures.length} cas en défaut sur '
              '${kpbPhoneViewports.length * kpbTextScales.length} :\n'
              '${failures.join('\n')}\n\n'
              'Ne RELEVEZ PAS le budget et n\'élargissez PAS le viewport : '
              'agrandir la surface fait disparaître les débordements sans rien '
              'corriger, et c\'est exactement le mensonge que ce fichier '
              'supprime.',
        );
      });
    }
  });

  group('le cliquet', () {
    testWidgets('un débordement corrigé doit faire baisser le budget',
        (tester) async {
      // On ne rejoue que les 14 cas budgétés : si l'un d'eux est tombé à zéro,
      // quelqu'un a corrigé la mise en page et doit verrouiller le progrès.
      // Seul le passage à ZÉRO déclenche ce test — une oscillation de 3 à 2 due
      // aux métriques de police de la CI Linux ne doit pas rougir.
      final stale = <String>[];
      for (final budgeted in screenOverflowBudget.entries) {
        final parts = budgeted.key.split('@');
        final screen = parts[0];
        final viewport = kpbPhoneViewports.firstWhere((v) => v.id == parts[1]);
        final scale = double.parse(parts[2]);
        final spec = specs[screen];
        expect(spec, isNotNull,
            reason: '${budgeted.key} budgète un écran absent de la matrice.');

        final report = await pumpKpbScreen(
          tester,
          screen: await spec!(),
          viewport: viewport,
          textScale: scale,
          ownsScaffold: !_needsAmbientScaffold.contains(screen),
          inDrawerShell: _shellTabs.contains(screen),
        );
        if (report.overflows.isEmpty) {
          stale.add('  ${budgeted.key} : budget ${budgeted.value}, '
              'plus aucun débordement → retirez cette ligne');
        }
        Get.reset();
      }

      expect(
        stale,
        isEmpty,
        reason: 'Progrès détecté : verrouillez-le en retirant ces lignes de '
            'test/core/ui/screen_overflow_budget.dart, et mettez '
            'screenOverflowCaseCount à jour.\n${stale.join('\n')}',
      );
      expect(screenOverflowBudget.length, screenOverflowCaseCount);
    });
  });
}
