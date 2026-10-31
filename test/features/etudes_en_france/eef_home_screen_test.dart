// Le hub de l'espace « Études en France » (build 54), monté tel qu'en production.
//
// Ce que ce fichier garantit, pour l'étudiant : que chaque tuile mène quelque
// part (aucun « en préparation »), que la suspension d'un pays REMPLACE la date,
// que la déclaration se voit, se modifie et se retire DEPUIS ce hub (le texte de
// consentement le promet), et que rien ne déborde sur un petit téléphone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';
import '../../support/eef_tour_fakes.dart';

/// Un écran assez haut pour construire TOUTE la liste paresseuse d'un coup : les
/// tests de contenu cherchent des tuiles, pas la position du pli.
const _tall = KpbViewport(
  id: 'tall',
  name: 'Écran haut 393×2600',
  size: Size(393, 2600),
  padding: EdgeInsets.zero,
);

const _declaredBody = <String, dynamic>{
  'declared': true,
  'currentLevel': 'licence',
  'targetLevel': 'master',
  'fieldIds': ['d01', 'd07'],
  'wantsPremium': false,
  'consentedAt': '2026-09-30T10:00:00.000Z',
};

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics helpAnalytics;

  setUp(() {
    useSeenTour();
    api = MockApiClient();
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    helpAnalytics = RecordingHelpAnalytics();
    EefHelpCard.analytics = helpAnalytics;
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = true;
    AppConfig.aiToolsEnabledOverride = null;
    Get.locale = const Locale('fr');
    EefCalendar.clock = () => DateTime(2026, 9, 28);
    EefCalendar.windowSource = () => EefCampaignWindow(
          opensAt: DateTime(2026, 10, 1),
          platformUrl: 'https://www.campusfrance.org/fr',
          suspendedCountries: const ['Niger'],
          suspendedSources: const {
            'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
          },
        );
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.aiToolsEnabledOverride = null;
    Get.reset();
  });

  void stubInterest(Map<String, dynamic>? body) {
    when(() => api.getEefInterest())
        .thenAnswer((_) async => body ?? <String, dynamic>{'declared': false});
  }

  Future<KpbScreenReport> pump(
    WidgetTester tester, {
    String country = 'Sénégal',
    String? currentLevel,
    List<String>? fieldIds,
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
  }) async {
    await seedKpbController(
      apiClient: api,
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        isGuestMode: guest,
        profile: guest
            ? null
            : createTestProfile(countryOfResidence: country).copyWith(
                currentLevel: currentLevel,
                fieldIds: fieldIds,
              ),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: const EefHomeScreen(),
      viewport: viewport,
      textScale: textScale,
    );
  }

  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
  }

  group('les tuiles', () {
    testWidgets(
        'chaque tuile promise existe, et aucune n\'est « en préparation »',
        (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      expect(find.text('Trouver ma formation'), findsOneWidget);
      expect(find.text('Préparer mon dossier'), findsOneWidget);
      // Les trois outils : mêmes libellés que la boîte à outils.
      expect(find.text('cv_generator_title'.tr), findsOneWidget);
      expect(find.text('letters_title'.tr), findsOneWidget);
      expect(find.text('interview_title'.tr), findsOneWidget);
      // Aucun module annoncé qui n'existe pas.
      expect(find.text('En préparation'), findsNothing);
      expect(find.textContaining('arrivent'), findsNothing);
    });

    testWidgets('le masque des outils IA vaut aussi dans le hub',
        (tester) async {
      AppConfig.aiToolsEnabledOverride = false;
      stubInterest(null);
      await pump(tester, viewport: _tall);

      expect(find.text('Trouver ma formation'), findsOneWidget);
      expect(find.text('cv_generator_title'.tr), findsNothing);
      expect(find.text('letters_title'.tr), findsNothing);
      expect(find.text('interview_title'.tr), findsNothing);
      // Le hub reste utile : catalogue et conseiller ne dépendent pas de l'IA.
      // Le conseiller, c'est désormais la carte d'aide (elle a remplacé la
      // tuile « Parler à un conseiller », qui menait au même WhatsApp).
      expect(find.text("Démarrer l'étude de mon dossier sur WhatsApp"),
          findsOneWidget);
    });

    testWidgets('le héros dit où se dépose la candidature — dans son corps',
        (tester) async {
      stubInterest(null);
      await pump(tester);

      // Elle ne dit PAS que toute candidature passe par la plateforme Études en
      // France : le catalogue compte des formations en DAP blanche ou jaune et
      // hors procédure.
      expect(
        find.textContaining('selon la procédure indiquée sur chaque formation'),
        findsOneWidget,
      );
      // L'enseigne du titre ne nomme pas l'agence (eef_naming_test).
      expect(find.text('Prépare ta candidature aux universités françaises'),
          findsOneWidget);
    });

    // Le texte qui portait « BTS », « écoles de commerce » et « budget » est
    // celui de la VITRINE (`eef_pillar_catalog_body`) — ce qui part en production.
    // On lit donc les VALEURS des textes qui décrivent le catalogue, en FR et EN,
    // au lieu de chercher ces mots sur un écran qui ne les a jamais affichés.
    test('la promesse du catalogue ne cite plus ce qui n\'existe pas', () {
      final keys = AppTranslations().keys;
      final forbidden = RegExp(
        r'BTS|commerce|business|budget|écoles? d.ingénieurs|engineering schools',
        caseSensitive: false,
      );
      for (final locale in ['fr', 'en']) {
        for (final key in [
          'eef_pillar_catalog_body',
          'eef_hub_formations_body',
          'eef_catalog_title',
        ]) {
          final text = keys[locale]![key]!;
          expect(forbidden.hasMatch(text), isFalse,
              reason:
                  '$key ($locale) promet ce que le catalogue n\'a pas : $text');
        }
      }
    });
  });

  group('suspension et dates', () {
    testWidgets('un étudiant sénégalais lit la date, le caveat et le lien',
        (tester) async {
      stubInterest(null);
      await pump(tester, country: 'Sénégal');

      expect(find.textContaining('1er octobre 2026'), findsOneWidget);
      expect(find.text('eef_deadline_varies_notice'.tr), findsOneWidget);
      expect(find.text('Voir la plateforme officielle'), findsWidgets);
      expect(find.text('eef_suspended_notice'.tr), findsNothing);
    });

    // 05/10/2026 — décision du propriétaire : plus d'avertissement jaune dans le
    // hub. La suspension REMPLAÇAIT la date ; sans l'avertissement, le héros ne
    // montre ni l'un ni l'autre (jamais « ouverture le 1er octobre » à un compte
    // dont le pays est suspendu).
    testWidgets('un étudiant nigérien ne lit NI l\'avertissement NI la date',
        (tester) async {
      stubInterest(null);
      await pump(tester, country: 'Niger');

      expect(find.text('eef_suspended_notice'.tr), findsNothing);
      expect(find.text('Voir la source officielle'), findsNothing);
      expect(find.byIcon(Icons.report_problem_outlined), findsNothing);
      expect(find.textContaining('1er octobre 2026'), findsNothing);
      expect(find.text('eef_deadline_varies_notice'.tr), findsNothing);
      expect(find.text('Voir la plateforme officielle'), findsNothing);
    });
  });

  group('mon profil Études en France', () {
    testWidgets('pas encore déclaré → invitation à compléter', (tester) async {
      stubInterest(null);
      await pump(tester);
      await scrollDown(tester);

      expect(find.text('Mon profil Études en France'), findsOneWidget);
      expect(find.text('Être rappelé(e) par un conseiller'), findsOneWidget);
      expect(find.text('Me retirer de la liste'), findsNothing);
    });

    testWidgets('déclaré → résumé lisible, Modifier et Me retirer',
        (tester) async {
      stubInterest(_declaredBody);
      await pump(tester);
      await scrollDown(tester);

      expect(find.text('Niveau actuel : Licence'), findsOneWidget);
      expect(find.text('Niveau visé : Master'), findsOneWidget);
      expect(
        find.textContaining('Informatique'),
        findsOneWidget,
        reason: 'les domaines se lisent en clair, pas en « d01 »',
      );
      expect(find.textContaining('d01'), findsNothing);
      expect(find.text('Modifier mon profil'), findsOneWidget);
      // La promesse du texte de consentement : « depuis cet écran ».
      expect(find.text('Me retirer de la liste'), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets('« Me retirer » confirme, retire, et le dit', (tester) async {
      stubInterest(_declaredBody);
      when(() => api.withdrawEefInterest())
          .thenAnswer((_) async => <String, dynamic>{'declared': false});
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Me retirer de la liste'));
      await tester.pumpAndSettle();
      expect(find.text('Te retirer de la liste ?'), findsOneWidget);

      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      verify(() => api.withdrawEefInterest()).called(1);
      expect(find.text('Tu es retiré de la liste.'), findsOneWidget);
      // Le bloc revient à « pas déclaré ».
      expect(find.text('Être rappelé(e) par un conseiller'), findsOneWidget);
    });

    testWidgets('un retrait qui échoue le DIT et garde la déclaration',
        (tester) async {
      stubInterest(_declaredBody);
      when(() => api.withdrawEefInterest())
          .thenAnswer((_) async => <String, dynamic>{'declared': true});
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Me retirer de la liste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Retrait impossible'), findsOneWidget);
      expect(find.text('Modifier mon profil'), findsOneWidget);
    });

    testWidgets('annuler la confirmation ne retire rien', (tester) async {
      stubInterest(_declaredBody);
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Me retirer de la liste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => api.withdrawEefInterest());
      expect(find.text('Modifier mon profil'), findsOneWidget);
    });

    testWidgets(
        '« Modifier » passe par PATCH et ne redemande pas le consentement',
        (tester) async {
      stubInterest(_declaredBody);
      when(() => api.updateEefProfile(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
          )).thenAnswer((_) async => <String, dynamic>{
            ..._declaredBody,
            'fieldIds': ['d01', 'd07', 'd02'],
          });
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Modifier mon profil'));
      await tester.pumpAndSettle();

      // La feuille d'édition : ni consentement, ni intérêt Premium.
      expect(find.text('eef_consent_notice'.tr), findsNothing);
      expect(find.text('eef_field_wants_premium'.tr), findsNothing);
      expect(find.text('Tes domaines (plusieurs choix possibles)'),
          findsOneWidget);

      // Un domaine de plus : d02.
      final d02 = find.byType(FilterChip).at(1);
      await tester.ensureVisible(d02);
      await tester.tap(d02);
      await tester.pump();
      await tester.ensureVisible(find.text('Valider'));
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      verify(() => api.updateEefProfile(
            currentLevel: 'licence',
            targetLevel: 'master',
            fieldIds: ['d01', 'd02', 'd07'],
          )).called(1);
      verifyNever(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          ));
    });

    // EEF-UX-13 (2) : la première déclaration part de ce que le profil sait déjà,
    // par une table FERMÉE — jamais une copie de la chaîne du profil.
    testWidgets('la première déclaration est préremplie depuis le profil',
        (tester) async {
      stubInterest(null);
      when(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => _declaredBody);
      await pump(
        tester,
        // « bachelor_2 » est une ANNÉE du profil ; la déclaration attend un
        // NIVEAU. « zz » n'est pas un domaine connu : il doit être écarté.
        currentLevel: 'bachelor_2',
        fieldIds: ['d03', 'zz', 'd05'],
      );
      await scrollDown(tester);

      await tester.tap(find.text('Être rappelé(e) par un conseiller'));
      await tester.pumpAndSettle();

      // Le consentement est annoncé, avant le bouton qui le donne.
      expect(find.text('eef_consent_notice'.tr), findsOneWidget);

      await tester.ensureVisible(find.text('Valider'));
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      verify(() => api.declareEefInterest(
            consentVersion: 'eef-consent-v1',
            currentLevel: 'licence',
            // Le profil de test vise un master : la même table fermée s'applique
            // au niveau visé.
            targetLevel: 'master',
            fieldIds: ['d03', 'd05'],
            wantsPremium: false,
          )).called(1);
    });

    testWidgets(
        'un invité n\'a pas de déclaration : il est invité à créer un compte',
        (tester) async {
      await pump(tester, guest: true);
      await scrollDown(tester);

      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(find.text('Être rappelé(e) par un conseiller'), findsNothing);
      // Et aucun appel : un invité n'a pas de session, l'appel reviendrait en 401.
      verifyNever(() => api.getEefInterest());
    });
  });

  // Le consentement promet un retrait « depuis cet écran », et le hub est
  // l'endroit où il est tenu : une lecture en échec ne doit pas faire croire à
  // « pas déclaré » (CTA « Compléter mon profil », « Me retirer » caché).
  group('lecture de la déclaration en échec', () {
    testWidgets(
        'dit l\'incertitude, propose de réessayer, n\'invite pas à déclarer',
        (tester) async {
      when(() => api.getEefInterest()).thenThrow(StateError('hors ligne'));
      await pump(tester);
      await scrollDown(tester);

      expect(
          find.textContaining('Impossible de lire ton profil'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Être rappelé(e) par un conseiller'), findsNothing);
    });

    testWidgets('« Réessayer » relit, et retrouve la déclaration',
        (tester) async {
      var online = false;
      when(() => api.getEefInterest()).thenAnswer((_) async {
        if (!online) throw StateError('hors ligne');
        return _declaredBody;
      });
      await pump(tester);
      await scrollDown(tester);
      expect(find.text('Réessayer'), findsOneWidget);

      online = true;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Me retirer de la liste'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    });
  });

  // « À chaque étape où c'est un peu flou, on pose une question. » Le hub porte
  // UNE carte pleine (la principale) et une ligne (procédure) : la ligne
  // « documents » est retirée (audit build 57, T5-08 : trois appels au même
  // WhatsApp). Ce groupe prouve qu'elles sont au bon endroit, pas en double, et
  // qu'un pays suspendu n'y lit jamais « démarre ton dossier ».
  group('aide à chaque étape floue', () {
    const hubCta = "Démarrer l'étude de mon dossier sur WhatsApp";
    const hubQuestion = "C'est flou ? Tu veux de l'aide ?";
    const compactCta = "Demander de l'aide sur WhatsApp";
    const procedureQuestion = "Procédure, dates, dépôt : c'est flou ?";
    const documentsQuestion = 'Tu ne sais pas quels documents préparer ?';
    final openAFile = RegExp(
      r'dossier|d[ée]marrer|campus\s*france',
      caseSensitive: false,
    );

    double top(WidgetTester tester, Finder finder) =>
        tester.getTopLeft(finder.first).dy;

    /// Les textes rendus par les cartes d'aide, et eux seuls.
    String helpTexts(WidgetTester tester) => tester
        .widgetList<Text>(find.descendant(
          of: find.byType(EefHelpCard),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join(' | ');

    testWidgets('deux emplacements, UNE seule carte pleine', (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      expect(find.byType(EefHelpCard), findsNWidgets(2));
      // La carte principale : une fois. Sa mention (qui n'existe que sur une
      // carte pleine) aussi : il n'y a pas deux cartes.
      expect(find.text(hubQuestion), findsOneWidget);
      expect(find.text(hubCta), findsOneWidget);
      expect(find.text('eef_help_fineprint'.tr), findsOneWidget);
      // La ligne de procédure, une fois ; plus de ligne « documents ».
      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.text(documentsQuestion), findsNothing);
      expect(find.text(compactCta), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets(
        'chacune est à sa place : sous le héros, sous « Trouver ma '
        'formation »', (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      final hero = top(
          tester,
          find.text('Prépare ta candidature aux '
              'universités françaises'));
      final procedure = top(tester, find.text(procedureQuestion));
      final formations = top(tester, find.text('Trouver ma formation'));
      final main = top(tester, find.text(hubQuestion));
      final toolsHeading = top(tester, find.text('Préparer mon dossier'));
      final interview = top(tester, find.text('interview_title'.tr));
      final profile = top(tester, find.text('Mon profil Études en France'));

      expect(hero, lessThan(procedure));
      expect(procedure, lessThan(formations));
      expect(formations, lessThan(main));
      expect(main, lessThan(toolsHeading));
      expect(toolsHeading, lessThan(interview));
      expect(interview, lessThan(profile));
    });

    testWidgets('elle REMPLACE l\'ancienne tuile « Parler à un conseiller »',
        (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      // Deux invitations vers la même conversation, c'est une de trop.
      expect(find.text('Parler à un conseiller'), findsNothing);
      expect(find.text('eef_hub_advisor_body'.tr), findsNothing);
    });

    testWidgets('outils IA masqués : la ligne « documents » disparaît avec eux',
        (tester) async {
      AppConfig.aiToolsEnabledOverride = false;
      stubInterest(null);
      await pump(tester, viewport: _tall);

      expect(find.byType(EefHelpCard), findsNWidgets(2));
      expect(find.text(documentsQuestion), findsNothing);
      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.text(hubCta), findsOneWidget);
    });

    testWidgets('chaque emplacement est mesuré UNE fois', (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      expect(helpAnalytics.shownCalls, hasLength(2));
      expect(
        helpAnalytics.shownCalls.toSet(),
        {
          const RecordedHelpEvent('procedure', 'hub', 'compact'),
          const RecordedHelpEvent('hub', 'hub', 'card'),
        },
      );

      // Le profil se charge, la liste se reconstruit : pas de seconde « vue ».
      await scrollDown(tester);
      expect(helpAnalytics.shownCalls, hasLength(2));
    });

    testWidgets('le tap sur la carte principale ouvre WhatsApp avec l\'étape',
        (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      await tester.tap(find.text(hubCta));
      await tester.pumpAndSettle();

      expect(launcher.launched, hasLength(1));
      expect(Uri.parse(launcher.launched.single).host, 'wa.me');
      expect(launcher.lastText, frHelpPrefill("accueil de l'espace"));
      expect(helpAnalytics.tappedCalls,
          [const RecordedHelpEvent('hub', 'hub', 'card')]);
    });

    testWidgets('le tap sur la ligne « procédure » nomme SON étape',
        (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      await tester.tap(find.text(compactCta).first);
      await tester.pumpAndSettle();

      expect(launcher.lastText, frHelpPrefill('procédure, dates et dépôt'));
      expect(helpAnalytics.tappedCalls,
          [const RecordedHelpEvent('procedure', 'hub', 'compact')]);
    });

    testWidgets('un invité n\'a pas de compte, mais a un conseiller',
        (tester) async {
      await pump(tester, guest: true, viewport: _tall);

      expect(find.text(hubCta), findsOneWidget);
      await tester.tap(find.text(hubCta));
      await tester.pumpAndSettle();
      expect(launcher.lastText, frHelpPrefill("accueil de l'espace"));
    });

    group('pays suspendu (Niger)', () {
      testWidgets('UNE carte visible, au libellé neutre — jamais « démarre »',
          (tester) async {
        stubInterest(null);
        await pump(tester, country: 'Niger', viewport: _tall);

        expect(find.text('Parler à un conseiller des autres options'),
            findsOneWidget);
        expect(find.text('eef_help_fineprint'.tr), findsOneWidget);
        // Les deux lignes ont disparu : la mise en garde est déjà à l'écran.
        expect(find.text(procedureQuestion), findsNothing);
        expect(find.text(documentsQuestion), findsNothing);
        expect(find.text(compactCta), findsNothing);
        // Rien de ce que dit la carte normale.
        expect(find.text(hubCta), findsNothing);
        expect(find.text(hubQuestion), findsNothing);

        final texts = helpTexts(tester);
        expect(openAFile.hasMatch(texts), isFalse,
            reason: 'texte des cartes d\'aide pour un pays suspendu : $texts');
      });

      testWidgets('le message prérempli demande les autres options',
          (tester) async {
        stubInterest(null);
        await pump(tester, country: 'Niger', viewport: _tall);

        await tester
            .tap(find.text('Parler à un conseiller des autres options'));
        await tester.pumpAndSettle();

        expect(
            launcher.lastText, frSuspendedHelpPrefill("accueil de l'espace"));
        expect(openAFile.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
        expect(launcher.lastText, isNot(contains('Niger')));
      });

      testWidgets('seule la carte principale est mesurée', (tester) async {
        stubInterest(null);
        await pump(tester, country: 'Niger', viewport: _tall);

        expect(helpAnalytics.shownCalls,
            [const RecordedHelpEvent('hub', 'hub', 'card')]);
      });
    });
  });

  group('géométrie', () {
    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        testWidgets('${viewport.id} ×$scale — profil déclaré', (tester) async {
          stubInterest(_declaredBody);
          final report = await pump(
            tester,
            viewport: viewport,
            textScale: scale,
          );
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(report.otherErrors, isEmpty, reason: report.toString());
          expect(rawTranslationKeysOnScreen(tester), isEmpty);

          await scrollDown(tester);
          expect(truncatedTexts(tester), isEmpty);
        });

        testWidgets('${viewport.id} ×$scale — pays suspendu', (tester) async {
          stubInterest(null);
          final report = await pump(
            tester,
            country: 'Niger',
            viewport: viewport,
            textScale: scale,
          );
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(truncatedTexts(tester), isEmpty);
        });
      }
    }
  });
}
