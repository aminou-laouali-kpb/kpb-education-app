// La carte d'aide « c'est flou ? tu veux de l'aide ? » de l'espace « Études en
// France » (EefHelpCard), éprouvée seule, dans l'emballage de production.
//
// Ce que ce fichier garantit, pour l'étudiant :
//   · un tap ouvre WhatsApp vers la ligne du conseiller, avec un message qui
//     NOMME l'étape — et ne contient aucune donnée personnelle ;
//   · un étudiant dont le pays est suspendu ne lit JAMAIS d'invitation à
//     « démarrer l'étude de son dossier » : ni dans la carte, ni dans le message ;
//   · les textes existent dans les deux langues, ne promettent ni admission ni
//     visa, ne citent aucun prix, et ne nomment pas l'opérateur de l'État ;
//   · la mesure ne porte que l'étape, l'écran et la forme.
//
// Le lanceur d'URL est intercepté au niveau de `UrlLauncherPlatform`, la couture
// officielle du plugin (même technique que force_update_screen_test.dart) : le
// code de production n'a pas été modifié pour être testable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

/// Le nom de chaque étape tel que l'écrit le message prérempli, ÉCRIT EN DUR
/// ici : un test qui lirait la même clé que le code ne détecterait pas qu'on
/// l'a vidée ou renommée.
const _frStepLabels = <EefHelpStep, String>{
  EefHelpStep.hub: "accueil de l'espace",
  EefHelpStep.procedure: 'procédure, dates et dépôt',
  EefHelpStep.documents: 'documents à fournir',
  EefHelpStep.catalogResults: 'choix de ma formation',
  EefHelpStep.catalogProcedure: "procédure d'une formation",
  EefHelpStep.catalogEmpty: 'recherche de formation sans résultat',
  EefHelpStep.catalogUnpublished: 'catalogue pas encore disponible',
};

const _enStepLabels = <EefHelpStep, String>{
  EefHelpStep.hub: 'space home',
  EefHelpStep.procedure: 'procedure, dates and submission',
  EefHelpStep.documents: 'documents to provide',
  EefHelpStep.catalogResults: 'choosing my programme',
  EefHelpStep.catalogProcedure: 'application procedure of a programme',
  EefHelpStep.catalogEmpty: 'programme search with no result',
  EefHelpStep.catalogUnpublished: 'catalogue not yet available',
};

String _frPrefill(EefHelpStep step) => frHelpPrefill(_frStepLabels[step]!);

String _frSuspendedPrefill(EefHelpStep step) =>
    frSuspendedHelpPrefill(_frStepLabels[step]!);

String _enPrefill(EefHelpStep step) =>
    'Hello KPB Education, I am in the Études en France space of the app '
    '(step: ${_enStepLabels[step]}). To move on to the next step, I would like '
    'to start a review of my file.';

String _enSuspendedPrefill(EefHelpStep step) =>
    'Hello KPB Education, I am in the Études en France space of the app '
    '(step: ${_enStepLabels[step]}). The procedure is suspended in my country: '
    'I would like to talk about other study options.';

/// Ce qu'une invitation à ouvrir un dossier dirait, en français comme en
/// anglais, et le nom de l'opérateur de l'État. Aucun texte destiné à un pays
/// suspendu ne doit en contenir un seul.
final _openAFileWording = RegExp(
  r'dossier|d[ée]marrer|campus\s*france|\bstart\b|\bfile\b|\breview\b',
  caseSensitive: false,
);

void main() {
  setUpAll(initializeDateFormatting);

  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics analytics;

  EefCampaignWindow window({bool nigerSuspended = true}) => EefCampaignWindow(
        platformUrl: 'https://www.campusfrance.org/fr',
        suspendedCountries: nigerSuspended ? const ['Niger'] : const [],
        suspendedSources: nigerSuspended
            ? const {
                'niger': 'https://ne.diplomatie.gouv.fr/informations-visas'
              }
            : const {},
      );

  setUp(() {
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    analytics = RecordingHelpAnalytics();
    EefHelpCard.analytics = analytics;
    RemoteFeatureFlags.resetForTest();
    Get.locale = const Locale('fr');
    EefCalendar.windowSource = window;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    Get.reset();
  });

  Future<KpbScreenReport> pumpCard(
    WidgetTester tester,
    EefHelpStep step, {
    String country = 'Sénégal',
    String fullName = 'Mouhamadou Diallo',
    String email = 'test@example.com',
    String phone = '+22501020304',
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
  }) async {
    await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        isGuestMode: guest,
        profile: guest
            ? null
            : createTestProfile(
                countryOfResidence: country,
                fullName: fullName,
                email: email,
                phone: phone,
              ),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: ListView(
        padding: const EdgeInsets.all(16),
        children: [EefHelpCard(step: step)],
      ),
      viewport: viewport,
      textScale: textScale,
      ownsScaffold: false,
    );
  }

  /// Le texte du bouton (carte) ou du lien (forme compacte) à taper.
  Finder tapTarget(EefHelpStep step, {bool suspended = false}) {
    if (step.compact) return find.text("Demander de l'aide sur WhatsApp");
    final key = suspended ? 'eef_help_neutral_cta' : 'eef_help_${step.key}_cta';
    return find.text(key.tr);
  }

  /// Tous les textes rendus PAR la carte — pas ceux de l'écran autour.
  List<String> cardTexts(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(EefHelpCard),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .where((t) => t.isNotEmpty)
      .toList();

  Uri lastLaunched() {
    expect(launcher.launched, hasLength(1),
        reason: 'un tap doit ouvrir exactement une conversation WhatsApp');
    return Uri.parse(launcher.launched.single);
  }

  String sentText(Uri uri) => uri.queryParameters['text'] ?? '';

  String expectedPath() =>
      '/${AppConfig.whatsappNumber.replaceAll(RegExp(r'[^\d]'), '')}';

  group('le rendu (FR)', () {
    for (final step in EefHelpStep.values.where((s) => !s.compact)) {
      testWidgets('${step.key} : question, phrase, bouton et mention',
          (tester) async {
        final report = await pumpCard(tester, step);

        expect(find.text('eef_help_${step.key}_question'.tr), findsOneWidget);
        expect(find.text('eef_help_${step.key}_body'.tr), findsOneWidget);
        expect(find.text('eef_help_${step.key}_cta'.tr), findsOneWidget);
        // La mention : un accompagnement n'est pas une garantie.
        expect(find.text('eef_help_fineprint'.tr), findsOneWidget);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
        expect(report.overflows, isEmpty, reason: report.toString());
      });
    }

    for (final step in EefHelpStep.values.where((s) => s.compact)) {
      testWidgets('${step.key} : une ligne et un lien, pas de carte',
          (tester) async {
        await pumpCard(tester, step);

        expect(find.text('eef_help_${step.key}_question'.tr), findsOneWidget);
        expect(find.text("Demander de l'aide sur WhatsApp"), findsOneWidget);
        // Ni bouton, ni mention : c'est une ligne.
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('eef_help_fineprint'.tr), findsNothing);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });
    }

    testWidgets('la carte du hub dit les mots du propriétaire', (tester) async {
      await pumpCard(tester, EefHelpStep.hub);

      expect(find.text("C'est flou ? Tu veux de l'aide ?"), findsOneWidget);
      expect(
        find.text(
          "Pour passer à l'étape supérieure, contacte-nous sur WhatsApp pour "
          'démarrer une étude de ton dossier.',
        ),
        findsOneWidget,
      );
      expect(
        find.text("Démarrer l'étude de mon dossier sur WhatsApp"),
        findsOneWidget,
      );
    });
  });

  group('un tap ouvre WhatsApp avec le message de l\'étape (FR)', () {
    for (final step in EefHelpStep.values) {
      testWidgets(step.key, (tester) async {
        await pumpCard(tester, step);

        await tester.tap(tapTarget(step));
        await tester.pumpAndSettle();

        final uri = lastLaunched();
        expect(uri.scheme, 'https');
        expect(uri.host, 'wa.me');
        expect(uri.path, expectedPath(),
            reason: 'la ligne du conseiller, pas un autre numéro');
        expect(sentText(uri), _frPrefill(step));
        // L'étape est NOMMÉE : c'est ce qui rend le message utile.
        expect(sentText(uri), contains(_frStepLabels[step]!));
      });
    }
  });

  group('et en anglais', () {
    testWidgets('les textes et le message prérempli suivent la langue',
        (tester) async {
      await pumpCard(tester, EefHelpStep.hub);
      unawaited(Get.updateLocale(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Unclear? Want some help?'), findsOneWidget);
      expect(
        find.text(
          'To move on to the next step, contact us on WhatsApp to start a '
          'review of your file.',
        ),
        findsOneWidget,
      );
      expect(find.text('Start my file review on WhatsApp'), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);

      await tester.tap(find.text('Start my file review on WhatsApp'));
      await tester.pumpAndSettle();

      expect(sentText(lastLaunched()), _enPrefill(EefHelpStep.hub));
    });

    testWidgets('le lien compact aussi', (tester) async {
      await pumpCard(tester, EefHelpStep.procedure);
      unawaited(Get.updateLocale(const Locale('en')));
      await tester.pumpAndSettle();

      expect(
          find.text('Procedure, dates, submission: unclear?'), findsOneWidget);
      await tester.tap(find.text('Ask for help on WhatsApp'));
      await tester.pumpAndSettle();

      expect(sentText(lastLaunched()), _enPrefill(EefHelpStep.procedure));
    });

    testWidgets('pays suspendu : textes neutres et message neutre',
        (tester) async {
      await pumpCard(tester, EefHelpStep.hub, country: 'Niger');
      unawaited(Get.updateLocale(const Locale('en')));
      await tester.pumpAndSettle();

      expect(
          find.text('Talk to an advisor about other options'), findsOneWidget);
      await tester.tap(find.text('Talk to an advisor about other options'));
      await tester.pumpAndSettle();

      expect(sentText(lastLaunched()), _enSuspendedPrefill(EefHelpStep.hub));
    });
  });

  group('pays suspendu : jamais « démarre ton dossier »', () {
    for (final step in EefHelpStep.values.where((s) => !s.compact)) {
      testWidgets('${step.key} : libellé neutre, message neutre',
          (tester) async {
        await pumpCard(tester, step, country: 'Niger');

        expect(find.text('Parler à un conseiller des autres options'),
            findsOneWidget);
        expect(find.text("Besoin d'y voir plus clair ?"), findsOneWidget);
        // Rien de ce que la carte normale dit.
        expect(find.text('eef_help_${step.key}_question'.tr), findsNothing);
        expect(find.text("Démarrer l'étude de mon dossier sur WhatsApp"),
            findsNothing);

        final visible = cardTexts(tester).join(' | ');
        expect(_openAFileWording.hasMatch(visible), isFalse,
            reason: 'texte visible pour un pays suspendu : $visible');

        await tester
            .tap(find.text('Parler à un conseiller des autres options'));
        await tester.pumpAndSettle();

        final text = sentText(lastLaunched());
        expect(text, _frSuspendedPrefill(step));
        expect(_openAFileWording.hasMatch(text), isFalse,
            reason: 'message prérempli pour un pays suspendu : $text');
      });
    }

    for (final step in EefHelpStep.values.where((s) => s.compact)) {
      testWidgets('${step.key} : la ligne disparaît, rien n\'est mesuré',
          (tester) async {
        await pumpCard(tester, step, country: 'Niger');

        expect(find.text('eef_help_${step.key}_question'.tr), findsNothing);
        expect(find.text("Demander de l'aide sur WhatsApp"), findsNothing);
        expect(cardTexts(tester), isEmpty);
        expect(analytics.shownCalls, isEmpty,
            reason: 'une carte invisible ne compte pas comme vue');
      });
    }

    testWidgets('un étudiant sénégalais, lui, lit la carte normale',
        (tester) async {
      await pumpCard(tester, EefHelpStep.hub, country: 'Sénégal');

      expect(find.text("Démarrer l'étude de mon dossier sur WhatsApp"),
          findsOneWidget);
      expect(
          find.text('Parler à un conseiller des autres options'), findsNothing);
    });

    testWidgets('un invité (sans pays) lit la carte normale', (tester) async {
      await pumpCard(tester, EefHelpStep.hub, guest: true);

      expect(find.text("Démarrer l'étude de mon dossier sur WhatsApp"),
          findsOneWidget);
    });

    // La carte est montée par un `const` : son parent ne la reconstruit jamais.
    // Si elle ne réécoutait pas les drapeaux serveur, une carte montée sur les
    // valeurs de repli resterait sur « démarre ton dossier » après que le
    // serveur a déclaré le pays suspendu.
    testWidgets('la suspension servie APRÈS le montage est prise en compte',
        (tester) async {
      EefCalendar.windowSource = () => window(nigerSuspended: false);
      await pumpCard(tester, EefHelpStep.hub, country: 'Niger');
      expect(find.text("Démarrer l'étude de mon dossier sur WhatsApp"),
          findsOneWidget);

      EefCalendar.windowSource = window;
      RemoteFeatureFlags.instance.flagsVersion.value += 1;
      await tester.pumpAndSettle();

      expect(find.text("Démarrer l'étude de mon dossier sur WhatsApp"),
          findsNothing);
      expect(find.text('Parler à un conseiller des autres options'),
          findsOneWidget);
    });
  });

  group('le message ne contient AUCUNE donnée personnelle', () {
    const name = 'Awa Koné-Diallo';
    const email = 'awa.kone.diallo@example.org';
    const phone = '+221770001122';

    for (final step in EefHelpStep.values) {
      for (final country in ['Sénégal', 'Niger']) {
        testWidgets('${step.key} / $country', (tester) async {
          await pumpCard(
            tester,
            step,
            country: country,
            fullName: name,
            email: email,
            phone: phone,
          );
          final target = tapTarget(step, suspended: country == 'Niger');
          if (target.evaluate().isEmpty) return; // forme compacte masquée
          await tester.tap(target);
          await tester.pumpAndSettle();

          final uri = lastLaunched();
          final text = sentText(uri);
          // Le seul paramètre est le texte : ni nom, ni e-mail en paramètre.
          expect(uri.queryParameters.keys, ['text']);
          expect(uri.path, expectedPath());
          for (final secret in [
            'Awa',
            'Koné',
            'Diallo',
            'awa.kone',
            'example.org',
            '221',
            '770001122',
            country,
            'test-user-1', // l'identifiant interne du profil de test
          ]) {
            expect(text, isNot(contains(secret)), reason: text);
          }
          expect(text, isNot(contains('@')));
          expect(text, isNot(contains(RegExp(r'\d'))),
              reason: 'aucun chiffre : ni téléphone, ni passeport, ni id');
        });
      }
    }
  });

  group('la mesure', () {
    testWidgets('« vue » part UNE fois, même si la carte est reconstruite',
        (tester) async {
      await pumpCard(tester, EefHelpStep.catalogEmpty);

      expect(analytics.shownCalls,
          [const RecordedHelpEvent('catalog_empty', 'catalog', 'card')]);

      // Un drapeau serveur qui arrive reconstruit la carte : pas un nouveau
      // « vu ».
      RemoteFeatureFlags.instance.flagsVersion.value += 1;
      await tester.pumpAndSettle();
      await tester.pump();
      expect(analytics.shownCalls, hasLength(1));
    });

    testWidgets('« tap » part au tap, avec l\'étape, l\'écran et la forme',
        (tester) async {
      await pumpCard(tester, EefHelpStep.documents);
      expect(analytics.tappedCalls, isEmpty);

      await tester.tap(tapTarget(EefHelpStep.documents));
      await tester.pumpAndSettle();

      expect(analytics.tappedCalls,
          [const RecordedHelpEvent('documents', 'hub', 'compact')]);
    });

    test('les propriétés envoyées sont EXACTEMENT trois identifiants fermés',
        () {
      final params = AnalyticsService.eefHelpParams(
        step: 'catalog_empty',
        surface: 'catalog',
        variant: 'card',
      );
      expect(params, {
        'help_step': 'catalog_empty',
        'surface': 'catalog',
        'variant': 'card',
      });
    });

    test('toutes les étapes ont un identifiant et un écran fermés', () {
      final identifier = RegExp(r'^[a-z]+(_[a-z]+)*$');
      expect(EefHelpStep.values.map((s) => s.key).toSet(),
          hasLength(EefHelpStep.values.length),
          reason: 'deux étapes ne partagent pas leur clé');
      for (final step in EefHelpStep.values) {
        expect(step.key, matches(identifier));
        expect({'hub', 'catalog'}, contains(step.surface));
      }
    });
  });

  group('les textes', () {
    final keys = AppTranslations().keys;

    /// Toutes les clés que la carte peut lire.
    Set<String> keysFor(EefHelpStep step) => {
          'eef_help_${step.key}_question',
          if (!step.compact) ...[
            'eef_help_${step.key}_body',
            'eef_help_${step.key}_cta',
          ],
          'eef_help_step_${step.key}',
        };

    const shared = {
      'eef_help_compact_cta',
      'eef_help_neutral_question',
      'eef_help_neutral_body',
      'eef_help_neutral_cta',
      'eef_help_fineprint',
      'eef_help_prefill',
      'eef_help_prefill_suspended',
    };

    test('chaque étape a TOUS ses textes, en français ET en anglais', () {
      for (final locale in ['fr', 'en']) {
        for (final step in EefHelpStep.values) {
          for (final key in {...keysFor(step), ...shared}) {
            expect(keys[locale]![key], isNotNull,
                reason: '$key manque en $locale');
            expect(keys[locale]![key]!.trim(), isNotEmpty);
          }
        }
      }
    });

    test('les deux messages préremplis portent la place de l\'étape', () {
      for (final locale in ['fr', 'en']) {
        for (final key in ['eef_help_prefill', 'eef_help_prefill_suspended']) {
          expect(keys[locale]![key], contains('@step'),
              reason: '$key ($locale) ne nommerait pas l\'étape');
        }
      }
    });

    // Aucune promesse de résultat, aucun prix, aucun nom d'opérateur de l'État.
    test('aucun texte d\'aide ne promet, ne chiffre ni ne se déguise', () {
      final promise = RegExp(
        r'(admission|visa|bourse|scholarship)s?\s+(garanti|assur|certain|'
        r'guaranteed|assured|certain)|vous obtiendrez|tu obtiendras|'
        r'you will (get|obtain)|100\s?%',
        caseSensitive: false,
      );
      final price = RegExp(
        r'€|\bfcfa\b|\bxof\b|\bfrancs?\b|\bprix\b|\bprice\b|gratuit|\bfree\b|'
        r'\beuros?\b|\btarif',
        caseSensitive: false,
      );
      final operator = RegExp(r'campus[\s_-]*france', caseSensitive: false);
      var checked = 0;
      for (final locale in ['fr', 'en']) {
        keys[locale]!.forEach((key, value) {
          if (!key.startsWith('eef_help_')) return;
          checked += 1;
          expect(promise.hasMatch(value), isFalse,
              reason: '$key ($locale) promet un résultat : $value');
          expect(price.hasMatch(value), isFalse,
              reason: '$key ($locale) cite un prix : $value');
          expect(operator.hasMatch(value), isFalse,
              reason: '$key ($locale) nomme l\'opérateur de l\'État : $value');
        });
      }
      expect(checked, greaterThan(40), reason: 'le balayage ne trouve rien');
    });

    test('la mention dit que l\'accompagnement n\'est PAS une garantie', () {
      expect(keys['fr']!['eef_help_fineprint'],
          allOf(contains('pas une garantie'), contains('visa')));
      expect(keys['en']!['eef_help_fineprint'],
          allOf(contains('not a guarantee'), contains('visa')));
    });

    test('le jeu neutre (pays suspendu) ne parle jamais d\'ouvrir un dossier',
        () {
      for (final locale in ['fr', 'en']) {
        for (final key in [
          'eef_help_neutral_question',
          'eef_help_neutral_body',
          'eef_help_neutral_cta',
          'eef_help_prefill_suspended',
        ]) {
          expect(_openAFileWording.hasMatch(keys[locale]![key]!), isFalse,
              reason: '$key ($locale) : ${keys[locale]![key]}');
        }
      }
    });
  });

  group('les procédures qu\'on confond', () {
    test('dossier jaune, Parcoursup et hors procédure — pas les autres', () {
      expect(eefProcedureIsConfusing('hors_eef'), isTrue);
      expect(eefProcedureIsConfusing('dap_jaune'), isTrue);
      expect(eefProcedureIsConfusing('parcoursup'), isTrue);
      expect(eefProcedureIsConfusing('eef'), isFalse);
      expect(eefProcedureIsConfusing('dap_blanche'), isFalse);
      expect(eefProcedureIsConfusing(null), isFalse);
    });

    test('une procédure absente ou inconnue n\'est PAS « connue »', () {
      for (final known in [
        'eef',
        'dap_blanche',
        'dap_jaune',
        'parcoursup',
        'hors_eef',
      ]) {
        expect(eefProcedureIsKnown(known), isTrue, reason: known);
      }
      expect(eefProcedureIsKnown(null), isFalse);
      expect(eefProcedureIsKnown(''), isFalse);
      expect(eefProcedureIsKnown('nouvelle_voie'), isFalse);
    });
  });

  group('géométrie', () {
    for (final step in EefHelpStep.values) {
      for (final viewport in kpbPhoneViewports) {
        for (final scale in kpbTextScales) {
          testWidgets('${step.key} ${viewport.id} ×$scale', (tester) async {
            final report = await pumpCard(
              tester,
              step,
              viewport: viewport,
              textScale: scale,
            );
            expect(report.overflows, isEmpty, reason: report.toString());
            expect(report.otherErrors, isEmpty, reason: report.toString());
            expect(rawTranslationKeysOnScreen(tester), isEmpty);
            expect(truncatedTexts(tester), isEmpty);
          });
        }
      }
    }

    for (final step in EefHelpStep.values.where((s) => !s.compact)) {
      testWidgets('${step.key} pays suspendu 360 × 1,3', (tester) async {
        final report = await pumpCard(
          tester,
          step,
          country: 'Niger',
          viewport: compactAndroid,
          textScale: 1.3,
        );
        expect(report.overflows, isEmpty, reason: report.toString());
        expect(truncatedTexts(tester), isEmpty);
      });
    }

    // La cible tactile minimale d'un lien d'une ligne.
    testWidgets('le lien compact fait au moins 44 pt de haut', (tester) async {
      await pumpCard(tester, EefHelpStep.procedure);
      final box = tester.getSize(
        find.ancestor(
          of: find.text("Demander de l'aide sur WhatsApp"),
          matching: find.byType(InkWell),
        ),
      );
      expect(box.height, greaterThanOrEqualTo(44));
    });
  });
}
