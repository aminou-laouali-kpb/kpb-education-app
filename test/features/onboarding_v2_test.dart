// Onboarding « la valeur d'abord » (chantier I3), derrière `features.onboardingV2`.
//
// Les deux parcours sont éprouvés ici :
//  · drapeau FERMÉ (défaut) : l'ancien parcours, à l'identique — ses valeurs
//    par défaut historiques et pas de « Passer » en page 1 ;
//  · drapeau OUVERT : aucun champ pré-rempli sans choix de l'élève, « Passer »
//    dès la page 1, erreurs écrites dans le champ (jamais un toast), l'âge et
//    l'accord du tuteur conservés par « Passer », le plancher de 16 ans
//    toujours appliqué.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/observability/analytics_event_contract.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';

import '../support/screen_harness.dart';

const _tall = Size(390, 1400);

void main() {
  final events = <(String, Map<String, Object>)>[];

  setUp(() {
    events.clear();
    AnalyticsService.instance.logEventSink = (name, params) async {
      events.add((name, params));
    };
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    RemoteFeatureFlags.resetForTest();
    Get.reset();
  });

  /// Un profil restauré qui porte l'identité (nom, email), la date de
  /// naissance et le consentement, mais AUCUN choix de liste ni de puce : ce
  /// que l'écran affiche alors dans ces champs vient de lui seul.
  UserProfile restoredIdentity({DateTime? birthDate}) {
    final now = DateTime.now();
    return UserProfile(
      id: 'test-user-1',
      accountType: AccountType.student,
      fullName: 'Test User',
      email: 'test@example.com',
      phone: '',
      whatsApp: '',
      countryOfResidence: '',
      preferredLanguage: 'fr',
      birthDate: birthDate ?? DateTime(now.year - 20, now.month, now.day),
      consentedAt: now,
    );
  }

  Future<AppController> pumpOnboarding(
    WidgetTester tester, {
    required bool v2,
    UserProfile? profile,
  }) async {
    RemoteFeatureFlags.resetForTest();
    if (v2) {
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({
        'onboardingV2': true,
      });
    }
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: false,
        profile: profile ?? restoredIdentity(),
      ),
    );
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
    await tester.pumpWidget(GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.buildTheme(),
      // « Passer » mène à l'accueil : une page témoin, pour que la
      // navigation ne lève pas.
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
      home: const OnboardingScreen(),
    ));
    await tester.pump();
    return controller;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> tapPrimary(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester, String field, String option) async {
    final dropdown = find.ancestor(
      of: find.text(field),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> enterPhone(WidgetTester tester) async {
    final phone = find.byWidgetPredicate(
      (w) => w is TextField && w.keyboardType == TextInputType.phone,
    );
    await tester.ensureVisible(phone);
    await tester.enterText(phone, '90000000');
    await tester.pump();
  }

  DropdownButtonFormField<String> dropdown(WidgetTester tester, String label) {
    return tester.widget<DropdownButtonFormField<String>>(find.ancestor(
      of: find.text(label),
      matching: find.byType(DropdownButtonFormField<String>),
    ));
  }

  /// La valeur affichée d'une liste déroulante (celle de son état).
  String? shownValue(WidgetTester tester, String label) {
    final state = tester.state<FormFieldState<String>>(find.ancestor(
      of: find.text(label),
      matching: find.byType(DropdownButtonFormField<String>),
    ));
    return state.value;
  }

  List<Map<String, Object>> validationFailures() => [
        for (final (name, params) in events)
          if (name == AnalyticsEventName.onboardingValidationFailed) params,
      ];

  group('drapeau FERMÉ — l\'ancien parcours, inchangé', () {
    testWidgets('pas de « Passer » en page 1, valeurs par défaut historiques',
        (tester) async {
      final controller = await pumpOnboarding(tester, v2: false);
      expect(RemoteFeatureFlags.instance.onboardingV2Enabled, isFalse);

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Passer'), findsNothing);
      expect(shownValue(tester, 'Pays'), 'Niger');
      expect(dropdown(tester, 'Pays').validator, isNull);

      await enterPhone(tester);
      await tapPrimary(tester, 'Continuer');

      expect(find.text('2 / 3'), findsOneWidget);
      // Le profil enregistré porte les choix jamais faits : c'est le défaut
      // que le drapeau ouvert retire, et que le drapeau fermé garde tel quel.
      final saved = controller.profile!;
      expect(saved.countryOfResidence, 'Niger');
      expect(saved.currentLevel, 'High school');
      expect(saved.targetLevel, 'Bachelor');
      expect(saved.languageLevel, 'Intermediate');
      expect(saved.gradeRange, '12 - 14/20');
      expect(shownValue(tester, 'Niveau actuel'), 'High school');
      // « Passer » à partir de la page 2, comme avant.
      expect(find.widgetWithText(TextButton, 'Passer'), findsOneWidget);
    });
  });

  group('drapeau OUVERT — la valeur d\'abord', () {
    testWidgets('« Passer » dès la page 1, et aucun pays pré-rempli',
        (tester) async {
      await pumpOnboarding(tester, v2: true);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Passer'), findsOneWidget);
      expect(shownValue(tester, 'Pays'), isNull);
      expect(find.text('Niger'), findsNothing);
    });

    testWidgets(
        'aucun pré-remplissage silencieux : un champ non choisi reste vide, '
        'et les erreurs s\'écrivent dans le champ', (tester) async {
      final controller = await pumpOnboarding(tester, v2: true);

      // Page 1 : le pays n'est plus choisi d'office — il est exigé, et
      // l'erreur est DANS le champ.
      await enterPhone(tester);
      await tapPrimary(tester, 'Continuer');
      expect(find.text('1 / 3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Pays'),
            matching: find.byType(DropdownButtonFormField<String>),
          ),
          matching: find.text('Ce champ est obligatoire'),
        ),
        findsOneWidget,
      );
      expect(find.byType(GetSnackBar), findsNothing);
      expect(validationFailures().last, {
        AnalyticsParamKey.step: 1,
        AnalyticsParamKey.reason: 'required_fields'
      });

      await choose(tester, 'Pays', 'Sénégal');
      await tapPrimary(tester, 'Continuer');
      expect(find.text('2 / 3'), findsOneWidget);
      expect(controller.profile!.countryOfResidence, 'Sénégal');

      // Page 2 : rien n'est pré-choisi.
      for (final label in [
        'Niveau actuel',
        'Niveau visé',
        'Niveau d\'anglais',
        'Moyenne académique sur les 3 dernières années',
      ]) {
        expect(shownValue(tester, label), isNull, reason: label);
      }
      expect(controller.profile!.currentLevel, isNull);
      expect(controller.profile!.targetLevel, isNull);
      expect(controller.profile!.languageLevel, isNull);
      expect(controller.profile!.gradeRange, isNull);

      // Niveau actuel et visé exigés, erreurs dans leurs champs.
      await tapPrimary(tester, 'Continuer');
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Ce champ est obligatoire'), findsNWidgets(2));
      expect(find.byType(GetSnackBar), findsNothing);

      await choose(tester, 'Niveau actuel', 'Lycée');
      await choose(tester, 'Niveau visé', 'Licence');
      await tapPrimary(tester, 'Continuer');
      expect(find.text('3 / 3'), findsOneWidget);
      final saved = controller.profile!;
      expect(saved.currentLevel, 'High school');
      expect(saved.targetLevel, 'Bachelor');
      // Non choisis : VIDES, pas « Intermédiaire » ni « 12-14/20 ».
      expect(saved.languageLevel, isNull);
      expect(saved.gradeRange, isNull);
    });

    testWidgets(
        'étape 3 : filière ou pays manquant → erreur SOUS les puces, '
        'jamais de toast', (tester) async {
      await pumpOnboarding(tester, v2: true);
      await enterPhone(tester);
      await choose(tester, 'Pays', 'Niger');
      await tapPrimary(tester, 'Continuer');
      await choose(tester, 'Niveau actuel', 'Lycée');
      await choose(tester, 'Niveau visé', 'Licence');
      await tapPrimary(tester, 'Continuer');
      expect(find.text('3 / 3'), findsOneWidget);
      events.clear();

      await tapPrimary(tester, 'Démarrer');
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Choisis au moins une filière qui t\'intéresse.'),
          findsOneWidget);
      expect(find.byType(GetSnackBar), findsNothing);
      expect(validationFailures(), [
        {AnalyticsParamKey.step: 3, AnalyticsParamKey.reason: 'fields_missing'},
      ]);

      // Une filière choisie : son erreur s'efface, celle des pays apparaît.
      final chip = find.byType(FilterChip).first;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      expect(find.text('Choisis au moins une filière qui t\'intéresse.'),
          findsNothing);
      await tapPrimary(tester, 'Démarrer');
      expect(find.text('Choisis au moins un pays où tu aimerais étudier.'),
          findsOneWidget);
      expect(find.byType(GetSnackBar), findsNothing);
    });

    testWidgets(
        'un mineur qui passe dès la page 1 garde sa date de naissance ET '
        'l\'accord du tuteur saisis', (tester) async {
      final now = DateTime.now();
      final seventeen = DateTime(now.year - 17, now.month, now.day);
      final controller = await pumpOnboarding(
        tester,
        v2: true,
        profile: restoredIdentity(birthDate: seventeen),
      );

      // L'étape tuteur est là (mineur déclaré) ; on la remplit.
      final name = find.widgetWithText(TextFormField, 'Nom du parent / tuteur');
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Awa Diallo');
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Contact du parent / tuteur (WhatsApp ou email)',
        ),
        '+227 90 00 00 00',
      );
      final consent = find.text('Mon parent / tuteur a donné son accord.');
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pump();

      final skip = find.widgetWithText(TextButton, 'Passer');
      await tester.tap(skip);
      await tester.pumpAndSettle();

      expect(controller.hasCompletedOnboarding, isTrue);
      expect(controller.onboardingSkipped, isTrue);
      final profile = controller.profile!;
      expect(profile.birthDate, seventeen);
      expect(profile.isMinor, isTrue);
      expect(profile.guardianConsentedAt, isNotNull);
      expect(profile.guardianName, 'Awa Diallo');
      expect(profile.guardianContact, '+227 90 00 00 00');
    });

    testWidgets(
        'un mineur qui passe SANS accord : l\'âge est gardé, aucun accord '
        'n\'est inventé (l\'étape tuteur de « Mes 10 bourses » le demandera)',
        (tester) async {
      final now = DateTime.now();
      final seventeen = DateTime(now.year - 17, now.month, now.day);
      final controller = await pumpOnboarding(
        tester,
        v2: true,
        profile: restoredIdentity(birthDate: seventeen),
      );
      // Un nom tapé, mais pas d'accord : rien du tuteur ne voyage.
      final name = find.widgetWithText(TextFormField, 'Nom du parent / tuteur');
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Awa Diallo');

      await tester.tap(find.widgetWithText(TextButton, 'Passer'));
      await tester.pumpAndSettle();

      final profile = controller.profile!;
      expect(profile.birthDate, seventeen);
      expect(profile.guardianConsentedAt, isNull);
      expect(profile.guardianName, isNull);
    });

    testWidgets(
        '« Passer » ne contourne pas le plancher de 16 ans : erreur dans le '
        'champ, on reste sur l\'onboarding', (tester) async {
      final now = DateTime.now();
      final controller = await pumpOnboarding(
        tester,
        v2: true,
        profile: restoredIdentity(
          birthDate: DateTime(now.year - 10, now.month, now.day),
        ),
      );
      // L'erreur est déjà dans le champ de la date, sans « Continuer ».
      expect(find.textContaining('16 ans'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Passer'));
      await settle(tester);

      expect(find.text('1 / 3'), findsOneWidget);
      expect(controller.hasCompletedOnboarding, isFalse);
      expect(controller.onboardingSkipped, isFalse);
      // Seule l'erreur d'âge : pas celles des autres champs.
      expect(find.text('Ce champ est obligatoire'), findsNothing);
      expect(validationFailures(), [
        {
          AnalyticsParamKey.step: 1,
          AnalyticsParamKey.reason: 'under_minimum_age',
        },
      ]);
    });

    testWidgets('le drapeau est lu à l\'ouverture, pas en cours de saisie',
        (tester) async {
      await pumpOnboarding(tester, v2: true);
      expect(find.widgetWithText(TextButton, 'Passer'), findsOneWidget);
      // Le serveur referme le drapeau pendant la saisie : le formulaire ne
      // change pas sous les doigts de l'élève.
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({});
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Passer'), findsOneWidget);
      expect(shownValue(tester, 'Pays'), isNull);
    });
  });
}
