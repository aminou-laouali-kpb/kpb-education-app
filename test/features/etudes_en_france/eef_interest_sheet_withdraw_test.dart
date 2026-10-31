// Le lien « Me retirer de la liste » DANS la feuille de déclaration d'intérêt
// (build 55).
//
// ## Le défaut
//
// Le texte de consentement dit « Tu peux te retirer à tout moment, depuis cet
// écran. » — et, dans la feuille, le retrait vivait DERRIÈRE elle (sur le hub ou
// la vitrine). Un étudiant qui relit la promesse au moment de modifier sa
// déclaration cherchait le geste dans la feuille, et ne le trouvait pas.
//
// ## Ce que ce fichier garantit
//
//   · le lien n'existe QUE là où une déclaration existe (modification, et
//     nouvelle réponse d'une vitrine déjà déclarée) — pas en première
//     déclaration, avant « Valider », où il n'y a rien à retirer ;
//   · il réutilise le flux de retrait EXISTANT de l'écran porteur : la même
//     confirmation « Te retirer de la liste ? », la même méthode du contrôleur,
//     les mêmes messages `eef_withdraw_*` — qui, eux, sont lus SUR l'écran porteur
//     (la feuille est déjà fermée), donc jamais cachés derrière elle ;
//   · en première déclaration, la promesse reste vraie : dès que « Valider »
//     réussit, l'écran porteur montre « Me retirer de la liste » ;
//   · le texte consenti n'a pas bougé (voir aussi eef_consent_version_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_interest_controller.dart';
import 'package:karatou/app/features/etudes_en_france/eef_interest_sheet.dart';
import 'package:karatou/app/features/etudes_en_france/eef_teaser_screen.dart';

import '../../support/pixel_contrast.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';
import '../../support/eef_tour_fakes.dart';

const _declaredBody = <String, dynamic>{
  'declared': true,
  'currentLevel': 'licence',
  'targetLevel': 'master',
  'fieldIds': ['d01', 'd07'],
  'wantsPremium': false,
  'consentedAt': '2026-09-30T10:00:00.000Z',
};

const _notDeclaredBody = <String, dynamic>{'declared': false};

/// Le lien de la feuille, par sa clé : « Me retirer de la liste » existe aussi
/// sur l'écran qui porte la feuille.
final _sheetLink = find.byKey(const ValueKey('eef-sheet-withdraw'));

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;

  setUp(() {
    useSeenTour();
    api = MockApiClient();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = true;
    AppConfig.aiToolsEnabledOverride = null;
    Get.locale = const Locale('fr');
    EefCalendar.windowSource = () => const EefCampaignWindow();
  });

  tearDown(() {
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = null;
    Get.reset();
  });

  void stubInterest(Map<String, dynamic> body) {
    when(() => api.getEefInterest()).thenAnswer((_) async => body);
  }

  void stubWithdraw(Map<String, dynamic> body) {
    when(() => api.withdrawEefInterest()).thenAnswer((_) async => body);
  }

  void stubDeclare() {
    when(() => api.declareEefInterest(
          consentVersion: any(named: 'consentVersion'),
          currentLevel: any(named: 'currentLevel'),
          targetLevel: any(named: 'targetLevel'),
          fieldIds: any(named: 'fieldIds'),
          wantsPremium: any(named: 'wantsPremium'),
        )).thenAnswer((_) async => _declaredBody);
  }

  // ── La feuille, seule ───────────────────────────────────────────────────────

  /// Monte un bouton qui ouvre la feuille avec un `onWithdraw` espion.
  Future<({EefInterestController controller, List<String> calls})> pumpSheet(
    WidgetTester tester, {
    required bool declared,
    EefSheetMode mode = EefSheetMode.declare,
    bool withCallback = true,
    Locale locale = const Locale('fr'),
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    ThemeMode themeMode = ThemeMode.light,
    List<bool?>? results,
  }) async {
    stubInterest(declared ? _declaredBody : _notDeclaredBody);
    await seedKpbController(
      apiClient: api,
      snapshot: AppSnapshot(
        localeCode: locale.languageCode,
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    );
    final controller = EefInterestController(apiClient: api);
    addTearDown(controller.dispose);
    await controller.load();

    final calls = <String>[];
    await pumpKpbScreen(
      tester,
      screen: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showEefInterestSheet(
                  context,
                  controller: controller,
                  mode: mode,
                  onWithdraw: withCallback
                      ? () async {
                          calls.add('withdraw');
                        }
                      : null,
                );
                results?.add(result);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
      viewport: viewport,
      textScale: textScale,
      locale: locale,
      themeMode: themeMode,
      routesShareMediaQuery: true,
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    return (controller: controller, calls: calls);
  }

  group('où le lien existe', () {
    testWidgets(
        'PREMIÈRE déclaration : rien à retirer, donc pas de lien — et '
        'le consentement est là', (tester) async {
      await pumpSheet(tester, declared: false);

      expect(_sheetLink, findsNothing);
      expect(find.text('eef_consent_notice'.tr), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
    });

    testWidgets('MODIFICATION (EefSheetMode.edit) : le lien est là',
        (tester) async {
      await pumpSheet(tester, declared: true, mode: EefSheetMode.edit);

      expect(_sheetLink, findsOneWidget);
      expect(
          find.descendant(
              of: _sheetLink, matching: find.text('Me retirer de la liste')),
          findsOneWidget);
      // En modification, ni consentement ni intérêt Premium (inchangé).
      expect(find.text('eef_consent_notice'.tr), findsNothing);
      expect(find.text('eef_field_wants_premium'.tr), findsNothing);
    });

    testWidgets(
        'vitrine déjà déclarée (mode « declare » + déclaration) : le '
        'lien est SOUS le consentement qui le promet', (tester) async {
      await pumpSheet(tester, declared: true, mode: EefSheetMode.declare);

      expect(find.text('eef_consent_notice'.tr), findsOneWidget);
      expect(_sheetLink, findsOneWidget);

      final notice = tester.getRect(find.text('eef_consent_notice'.tr)).bottom;
      final link = tester.getRect(_sheetLink).top;
      final confirm = tester.getRect(find.text('Valider')).top;
      expect(notice, lessThanOrEqualTo(link),
          reason: 'la promesse, puis le geste qui la tient');
      expect(link, lessThan(confirm));
    });

    testWidgets('sans écran porteur pour le tenir, pas de lien muet',
        (tester) async {
      await pumpSheet(
        tester,
        declared: true,
        mode: EefSheetMode.edit,
        withCallback: false,
      );

      expect(_sheetLink, findsNothing);
    });

    // Dès que le serveur confirme, `controller.declared` passe à vrai — PENDANT
    // que la feuille se referme (~200 ms). Le lien lisait ce drapeau vivant : il
    // apparaissait dans la feuille qui se ferme et la faisait grandir, alors que
    // « pas de lien en première déclaration » est la règle. La question « y avait-il
    // une déclaration ? » se pose à l'OUVERTURE de la feuille, pas à chaque image.
    testWidgets(
        'première déclaration : le lien n\'apparaît JAMAIS, pas même pendant '
        'la fermeture de la feuille', (tester) async {
      final results = <bool?>[];
      await pumpSheet(tester, declared: false, results: results);
      stubDeclare();

      await tester.ensureVisible(find.text('Valider'));
      await tester.tap(find.text('Valider'));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(_sheetLink, findsNothing, reason: 'image $frame');
      }
      await tester.pumpAndSettle();

      expect(results, [true], reason: 'la déclaration a bien été confirmée');
      expect(find.text('eef_sheet_title'.tr), findsNothing);
    });
  });

  group('le geste', () {
    testWidgets(
        'le lien ferme la feuille PUIS lance le flux de l\'écran porteur',
        (tester) async {
      final results = <bool?>[];
      final opened = await pumpSheet(
        tester,
        declared: true,
        mode: EefSheetMode.edit,
        results: results,
      );

      await tester.ensureVisible(_sheetLink);
      await tester.tap(_sheetLink);
      await tester.pumpAndSettle();

      // Une fois, et la feuille est refermée : le flux (confirmation, message)
      // se lit sur l'écran porteur, pas derrière la feuille.
      expect(opened.calls, ['withdraw']);
      expect(find.text('eef_profile_edit_title'.tr), findsNothing);
      expect(results, [false]);
      // La feuille elle-même ne retire RIEN : c'est le flux existant qui le fait.
      verifyNever(() => api.withdrawEefInterest());
    });

    testWidgets('« Annuler » ne lance aucun retrait', (tester) async {
      final opened = await pumpSheet(
        tester,
        declared: true,
        mode: EefSheetMode.edit,
      );

      await tester.ensureVisible(find.text('Annuler'));
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(opened.calls, isEmpty);
    });

    testWidgets('pendant un envoi, le lien est inerte', (tester) async {
      final opened = await pumpSheet(
        tester,
        declared: true,
        mode: EefSheetMode.edit,
      );
      // Un envoi en cours : le contrôleur est « submitting ».
      when(() => api.updateEefProfile(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
          )).thenAnswer((_) => Future<Map<String, dynamic>>.delayed(
            const Duration(seconds: 30),
            () => _declaredBody,
          ));
      await tester.ensureVisible(find.text('Valider'));
      await tester.tap(find.text('Valider'));
      await tester.pump();

      final button = tester.widget<TextButton>(
        find.descendant(of: _sheetLink, matching: find.byType(TextButton)),
      );
      expect(button.onPressed, isNull);
      expect(opened.calls, isEmpty);

      // Libère le délai pour ne pas laisser de minuteur en vol.
      await tester.pump(const Duration(seconds: 31));
    });
  });

  // ── Depuis le hub : le flux existant, de bout en bout ───────────────────────

  group('depuis le hub', () {
    Future<void> pumpHub(
      WidgetTester tester, {
      Locale locale = const Locale('fr'),
      KpbViewport viewport = iphone14,
      double textScale = 1.0,
    }) async {
      await seedKpbController(
        apiClient: api,
        snapshot: AppSnapshot(
          localeCode: locale.languageCode,
          hasCompletedOnboarding: true,
          profile: createTestProfile(countryOfResidence: 'Sénégal'),
        ),
      );
      await pumpKpbScreen(
        tester,
        screen: const EefHomeScreen(),
        viewport: viewport,
        textScale: textScale,
        locale: locale,
        routesShareMediaQuery: true,
      );
    }

    Future<void> openEditSheet(WidgetTester tester) async {
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier mon profil'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'Modifier → « Me retirer » → confirmation → retiré, dit, et '
        'la feuille est fermée', (tester) async {
      stubInterest(_declaredBody);
      stubWithdraw(_notDeclaredBody);
      await pumpHub(tester);
      await openEditSheet(tester);

      expect(_sheetLink, findsOneWidget);
      await tester.ensureVisible(_sheetLink);
      await tester.tap(_sheetLink);
      await tester.pumpAndSettle();

      // LE flux du hub : la même confirmation.
      expect(find.text('Te retirer de la liste ?'), findsOneWidget);
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      verify(() => api.withdrawEefInterest()).called(1);
      // Le message est lu SUR le hub : la feuille est fermée.
      expect(find.text('Tu es retiré de la liste.'), findsOneWidget);
      expect(_sheetLink, findsNothing);
      expect(find.text('Être rappelé(e) par un conseiller'), findsOneWidget);
    });

    testWidgets('un retrait qui échoue le DIT et garde la déclaration',
        (tester) async {
      stubInterest(_declaredBody);
      stubWithdraw(_declaredBody);
      await pumpHub(tester);
      await openEditSheet(tester);

      await tester.ensureVisible(_sheetLink);
      await tester.tap(_sheetLink);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Retrait impossible'), findsOneWidget);
      expect(find.text('Modifier mon profil'), findsOneWidget);
    });

    // Le retrait raté laissait son échec au contrôleur : rouvrir « Modifier mon
    // profil » affichait « Envoi impossible… Rien n'a été enregistré » et
    // remplaçait « Valider » par « Réessayer » — une erreur d'ENVOI pour un envoi
    // que personne n'avait tenté. Le lien de la feuille rend ce parcours naturel :
    // feuille → Me retirer → réseau coupé → on rouvre la feuille.
    Future<void> expectReopenedSheetIsClean(WidgetTester tester) async {
      // Le message d'échec du retrait se lit sur le hub, puis s'efface.
      expect(find.textContaining('Retrait impossible'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      await openEditSheet(tester);

      // Le titre de la feuille porte le même libellé que le bouton du hub : c'est
      // la feuille elle-même qu'on cherche.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('Envoi impossible'), findsNothing);
      expect(find.textContaining("Rien n'a été enregistré"), findsNothing);
      expect(find.text('Réessayer'), findsNothing);
      await tester.ensureVisible(find.text('Valider'));
      expect(find.text('Valider'), findsOneWidget);
    }

    testWidgets(
        'après un retrait en échec lancé DEPUIS LE LIEN de la feuille, la '
        'feuille rouverte ne montre pas d\'erreur d\'envoi', (tester) async {
      stubInterest(_declaredBody);
      // Le serveur répond encore « déclaré » : le retrait n'a pas eu lieu.
      stubWithdraw(_declaredBody);
      await pumpHub(tester);
      await openEditSheet(tester);

      await tester.ensureVisible(_sheetLink);
      await tester.tap(_sheetLink);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      await expectReopenedSheetIsClean(tester);
    });

    testWidgets('idem après un retrait en échec lancé par le BOUTON du hub',
        (tester) async {
      stubInterest(_declaredBody);
      stubWithdraw(_declaredBody);
      await pumpHub(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Me retirer de la liste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      await expectReopenedSheetIsClean(tester);
    });

    testWidgets('annuler la confirmation ne retire rien', (tester) async {
      stubInterest(_declaredBody);
      stubWithdraw(_notDeclaredBody);
      await pumpHub(tester);
      await openEditSheet(tester);

      await tester.ensureVisible(_sheetLink);
      await tester.tap(_sheetLink);
      await tester.pumpAndSettle();
      expect(find.text('Te retirer de la liste ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => api.withdrawEefInterest());
      expect(find.text('Modifier mon profil'), findsOneWidget);
    });

    // La promesse du consentement, en première déclaration : avant « Valider »
    // il n'y a rien à retirer ; dès que le serveur a confirmé, l'écran porteur
    // montre le geste.
    testWidgets(
        'première déclaration : « Me retirer » apparaît sur le hub dès '
        'que « Valider » a réussi', (tester) async {
      var declared = false;
      when(() => api.getEefInterest())
          .thenAnswer((_) async => declared ? _declaredBody : _notDeclaredBody);
      when(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async {
        declared = true;
        return _declaredBody;
      });
      await pumpHub(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.text('Me retirer de la liste'), findsNothing);

      await tester.tap(find.text('Être rappelé(e) par un conseiller'));
      await tester.pumpAndSettle();
      // Avant « Valider » : le consentement promet, il n'y a rien à retirer.
      expect(find.text('eef_consent_notice'.tr), findsOneWidget);
      expect(_sheetLink, findsNothing);

      await tester.ensureVisible(find.text('Valider'));
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('eef_sheet_title'.tr), findsNothing);
      expect(find.text('Me retirer de la liste'), findsOneWidget);
    });

    testWidgets('en anglais, à 360 dp × 1,3 : le lien tient dans la feuille',
        (tester) async {
      stubInterest(_declaredBody);
      await pumpHub(
        tester,
        locale: const Locale('en'),
        viewport: compactAndroid,
        textScale: 1.3,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit my profile'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(_sheetLink);
      expect(
        find.descendant(
            of: _sheetLink, matching: find.text('Remove me from the list')),
        findsOneWidget,
      );
      expect(truncatedTexts(tester), isEmpty);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });
  });

  // ── Depuis la vitrine ───────────────────────────────────────────────────────

  group('depuis la vitrine', () {
    testWidgets(
        '« C\'est noté » porte déjà « Me retirer » ; « Modifier ma '
        'réponse » rouvre la feuille AVEC le lien', (tester) async {
      stubInterest(_declaredBody);
      stubWithdraw(_notDeclaredBody);
      await seedKpbController(
        apiClient: api,
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(countryOfResidence: 'Sénégal'),
        ),
      );
      await pumpKpbScreen(
        tester,
        screen: const EefTeaserScreen(),
        viewport: iphone14,
        routesShareMediaQuery: true,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();

      // La confirmation « C'est noté » n'est PAS un état de la feuille : c'est
      // la carte de la vitrine, qui porte déjà le retrait.
      expect(find.text("C'est noté"), findsOneWidget);
      expect(find.text('Me retirer de la liste'), findsOneWidget);

      await tester.tap(find.text('Modifier ma réponse'));
      await tester.pumpAndSettle();
      expect(_sheetLink, findsOneWidget);

      await tester.ensureVisible(_sheetLink);
      await tester.tap(_sheetLink);
      await tester.pumpAndSettle();
      expect(find.text('Te retirer de la liste ?'), findsOneWidget);
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      verify(() => api.withdrawEefInterest()).called(1);
      expect(find.text('Tu es retiré de la liste.'), findsOneWidget);
    });

    testWidgets(
        'un retrait en échec ne laisse pas d\'erreur d\'envoi à la feuille '
        'rouverte', (tester) async {
      stubInterest(_declaredBody);
      stubWithdraw(_declaredBody);
      await seedKpbController(
        apiClient: api,
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(countryOfResidence: 'Sénégal'),
        ),
      );
      await pumpKpbScreen(
        tester,
        screen: const EefTeaserScreen(),
        viewport: iphone14,
        routesShareMediaQuery: true,
      );
      Future<void> openSheet() async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Modifier ma réponse'));
        await tester.pumpAndSettle();
      }

      await openSheet();
      await tester.ensureVisible(_sheetLink);
      await tester.tap(_sheetLink);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Retrait impossible'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      await openSheet();

      expect(_sheetLink, findsOneWidget);
      expect(find.textContaining('Envoi impossible'), findsNothing);
      expect(find.text('Réessayer'), findsNothing);
      await tester.ensureVisible(find.text('Valider'));
      expect(find.text('Valider'), findsOneWidget);
    });

    testWidgets('première déclaration depuis la vitrine : pas de lien',
        (tester) async {
      stubInterest(_notDeclaredBody);
      stubDeclare();
      await seedKpbController(
        apiClient: api,
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(countryOfResidence: 'Sénégal'),
        ),
      );
      await pumpKpbScreen(
        tester,
        screen: const EefTeaserScreen(),
        viewport: iphone14,
        routesShareMediaQuery: true,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('eef_cta_declare'.tr));
      await tester.pumpAndSettle();

      expect(find.text('eef_consent_notice'.tr), findsOneWidget);
      expect(_sheetLink, findsNothing);
    });
  });

  // ── Le texte consenti n'a pas bougé ─────────────────────────────────────────

  group('le texte consenti', () {
    test('est inchangé : la promesse « depuis cet écran » reste telle quelle',
        () {
      final keys = AppTranslations().keys;
      expect(
        keys['fr']!['eef_consent_notice'],
        "En validant, tu acceptes qu'un conseiller KPB te contacte au sujet de "
        'cet espace, et que ta réponse serve à préparer notre accompagnement. '
        'Tu peux te retirer à tout moment, depuis cet écran.',
      );
      expect(kEefConsentVersion, 'eef-consent-v1');
    });

    test('le lien réutilise les textes de retrait existants (aucun nouveau)',
        () {
      final keys = AppTranslations().keys;
      for (final locale in ['fr', 'en']) {
        expect(keys[locale]!['eef_withdraw_cta'], isNotEmpty);
        expect(keys[locale]!['eef_withdraw_confirm_title'], isNotEmpty);
        expect(keys[locale]!['eef_withdraw_done'], isNotEmpty);
        expect(keys[locale]!['eef_withdraw_failed'], isNotEmpty);
      }
    });
  });

  // ── Contraste ───────────────────────────────────────────────────────────────

  group('contraste >= 4,5:1 (mesuré sur les pixels)', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('le lien de la feuille — ${mode.name}', (tester) async {
        await pumpSheet(
          tester,
          declared: true,
          mode: EefSheetMode.edit,
          themeMode: mode,
        );
        await tester.ensureVisible(_sheetLink);
        await tester.pumpAndSettle();

        final measured = await measurePixelContrast(
          tester,
          find.descendant(of: _sheetLink, matching: find.byType(Text)).first,
        );
        expect(measured.ratio, greaterThanOrEqualTo(4.5),
            reason: measured.toString());
      });
    }
  });
}
