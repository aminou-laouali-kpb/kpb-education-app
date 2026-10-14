// Le calendrier d'échéances ne présente JAMAIS une projection comme un jalon.
//
// 20 des 31 fiches publiées ont un cycle « estimated » : leur `deadlineAt` en
// base vient de `estimatedCloseAt` à l'import — une reconduction de l'année
// précédente, pas une date confirmée. L'onglet Bourses sait déjà se taire dans
// ce cas (« Un compte à rebours au jour près sur une date ESTIMÉE serait un
// mensonge »), mais le calendrier lit `/catalog/scholarships`, dont le mapper
// n'exposait ni le statut de cycle ni `dateConfidence` : il posait donc un
// « J-146 » ferme au 08/01/2027 pour la bourse Eiffel, qui est une projection.
//
// Les deux fiches de ce test sont RÉELLES — eiffel_excellence_master_2027
// (estimated, 2027-01-08) et chevening_2027 (confirmed, 2026-10-06) — pour que
// l'assertion parle des données que la production sert vraiment.
//
// Monté dans son vrai contexte (MaterialApp + AppController peuplé), viewport
// 1080×1920 — jamais 800×600 : un test rendu trop petit a déjà tapé dans le
// vide sur ce projet, les lignes hors écran n'existant pas pour les finders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/deadlines/deadline_calendar_screen.dart';

import '../../widget_test_helpers.dart';

ScholarshipModel _sheet({
  required String id,
  required String name,
  required DateTime deadlineAt,
  required bool estimated,
}) =>
    ScholarshipModel(
      id: id,
      name: LocalizedText(fr: name, en: name),
      countryId: 'fra',
      levelEligible: const LocalizedText(fr: 'Master', en: 'Master'),
      typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: const LocalizedText(fr: '', en: ''),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 50,
      deadlineAt: deadlineAt,
      deadlineIsEstimated: estimated,
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    setupPlatformChannelMocks();
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
    Get.fallbackLocale = const Locale('fr');
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  testWidgets(
      'une échéance estimée dit « date à confirmer », une confirmée compte les jours',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          // Les étapes de feuille de route des bourses suivies sont faites :
          // ce test ne parle que des lignes de bourse.
          completedRoadmapSteps: {
            for (final id in [
              'eiffel_excellence_master_2027',
              'chevening_2027'
            ])
              id: [for (final step in RoadmapStepType.values) step.name],
          },
          // Le calendrier ne montre que les bourses SUIVIES (chantier G).
          savedItems: const [
            SavedItem(
              type: SavedItemType.scholarship,
              itemId: 'eiffel_excellence_master_2027',
            ),
            SavedItem(
              type: SavedItemType.scholarship,
              itemId: 'chevening_2027',
            ),
          ],
        ),
      ),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);

    controller.scholarships
      ..clear()
      ..addAll([
        _sheet(
          id: 'eiffel_excellence_master_2027',
          name: 'Bourse Eiffel Master',
          // La valeur RÉELLE servie par la production : estimatedCloseAt
          // reconduit, dateConfidence `estimated`.
          deadlineAt: DateTime(2027, 1, 8),
          estimated: true,
        ),
        _sheet(
          id: 'chevening_2027',
          name: 'Chevening',
          // Dans 20 jours CALENDAIRES, en fin de journée : l'écran compte en
          // jours calendaires, quelle que soit l'heure d'exécution du test.
          deadlineAt: () {
            final n = DateTime.now();
            return DateTime(n.year, n.month, n.day + 20, 23, 59);
          }(),
          estimated: false,
        ),
      ]);

    await tester.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: const DeadlineCalendarScreen(),
    ));
    await tester.pumpAndSettle();

    // La ligne Eiffel : le libellé honnête, et AUCUN décompte.
    expect(find.text('Bourse Eiffel Master'), findsOneWidget);
    expect(
      find.text('deadlines_date_to_confirm'.tr),
      findsWidgets,
      reason: 'La date Eiffel est une projection : le badge doit dire « date à '
          'confirmer », pas « J-146 ».',
    );

    // Chevening (confirmée, à 20 jours) : le décompte, lui, doit exister.
    expect(find.text('Chevening'), findsOneWidget);
    expect(
      find.text('deadlines_status_days'.trParams({'n': '20'})),
      findsOneWidget,
      reason: 'Sans ce contre-exemple, un correctif qui supprimerait TOUT '
          'décompte passerait au vert.',
    );

    // Et l'assertion la plus importante : le texte du décompte n'apparaît
    // qu'UNE fois — celle de Chevening. Si la ligne Eiffel en portait un, il y
    // en aurait deux.
    final dayBadges = find.textContaining(RegExp(r'^\d+ jours$'));
    expect(
      dayBadges,
      findsOneWidget,
      reason: 'Un second badge de décompte signifie qu\'une date estimée est '
          'de nouveau présentée comme un jalon ferme.',
    );
  });
}
