import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/intake_label.dart';
import 'package:karatou/app/core/utils/program_intakes.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';

import '../../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Décision du 16/10/2026 : les rentrées d'automne OMNES 2026 sont reconduites
// en 2027 (même jour et mois), avec campus et prix 2026-2027, en attendant la
// grille d'OMNES. Une offre reconduite porte `rolledFromIntake` et
// `intakeEstimated` (backend/src/modules/catalog/omnes-fall-roll.ts) : l'app
// le dit sobrement — « Date reconduite de 2026, à confirmer · tarif
// 2026-2027 » sous l'offre, « (à confirmer) » sur les cartes.
// ─────────────────────────────────────────────────────────────────────────────

final _today = DateTime(2026, 10, 16);

const _rolled = CampusOffering(
  campus: 'Paris',
  tuitionUpfront: 8850,
  tuitionInstallments: 9293,
  intake: '01/10/2027',
  rolledFromIntake: '01/10/2026',
  intakeEstimated: true,
);

const _spring = CampusOffering(
  campus: 'Paris',
  tuitionUpfront: 6690,
  tuitionInstallments: 7025,
  intake: '01/03/2027',
  session: 'spring',
  rhythm: 'initiale',
);

ProgramModel _program(List<CampusOffering> offerings) => ProgramModel(
      id: 'omnes-p-dc41accace3b7cf8',
      institutionId: 'omnes-ece',
      countryId: 'fra',
      fieldId: 'd01',
      name: const LocalizedText(
        fr: 'ECE - B1 - Cybersécurité et réseaux',
        en: 'ECE - B1 - Cybersécurité et réseaux',
      ),
      level: const LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
      duration: const LocalizedText(fr: '3 ans', en: '3 years'),
      tuition: const LocalizedText(fr: '8 850 €/an', en: '8 850 €/year'),
      language: const LocalizedText(fr: 'Français', en: 'Français'),
      requirements: const [],
      campusOfferings: offerings,
    );

String? _short(ProgramModel p, String locale) =>
    programIntakeSummary(p, now: _today).shortLabel(locale);

void main() {
  group('offre reconduite — modèle et mention', () {
    setUp(() {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
    });

    test('lit et réécrit les deux marques (cache hors ligne)', () {
      final back = CampusOffering.fromJson(_rolled.toJson());
      expect(back.rolledFromIntake, '01/10/2026');
      expect(back.intakeEstimated, isTrue);
      expect(back.isIntakeEstimated, isTrue);
      expect(back.rolledFromYear, 2026);
      // Une offre publiée n'en écrit aucune.
      expect(_spring.toJson().containsKey('intakeEstimated'), isFalse);
      expect(_spring.toJson().containsKey('rolledFromIntake'), isFalse);
      final fromApi = CampusOffering.fromJson({
        'campus': 'Lyon',
        'intake': '14/09/2027 · 01/10/2027',
        'rolledFromIntake': '14/09/2026 · 01/10/2026',
        'intakeEstimated': true,
      });
      expect(fromApi.rolledFromYear, 2026);
    });

    test('la mention, en français et en anglais', () {
      expect(
        offeringEstimateNote(_rolled),
        'Date reconduite de 2026, à confirmer · tarif 2026-2027',
      );
      expect(
        offeringEstimateSemantics(_rolled),
        'Date reconduite de la rentrée 2026, à confirmer par l\'école. '
        'Tarif de l\'année 2026-2027.',
      );
      expect(offeringEstimateNote(_spring), isNull);
      expect(
        offeringEstimateNote(
          const CampusOffering(
            campus: 'Paris',
            intake: '01/10/2027',
            intakeEstimated: true,
          ),
        ),
        'Date et tarif à confirmer',
      );
      Get.locale = const Locale('en');
      expect(
        offeringEstimateNote(_rolled),
        'Date carried over from 2026, to be confirmed · 2026-2027 fee',
      );
      Get.locale = const Locale('fr');
    });

    test('la rentrée reconduite reste une rentrée d’octobre 2027', () {
      expect(offeringIntakeLabel(_rolled, 'fr'), "Rentrée d'octobre 2027");
      expect(offeringIsPast(_rolled, now: _today), isFalse);
    });
  });

  group('offre reconduite — cartes et listes', () {
    setUp(() {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
    });

    test('« (à confirmer) » à côté de la date, la décalée intacte', () {
      expect(
        _short(_program([_rolled, _spring]), 'fr'),
        'Rentrées : mars 2027 (décalée) · oct. 2027 (à confirmer)',
      );
      Get.locale = const Locale('en');
      expect(
        _short(_program([_rolled, _spring]), 'en'),
        'Intakes: Mar 2027 (spring) · Oct 2027 (to be confirmed)',
      );
      Get.locale = const Locale('fr');
    });

    test('un même mois publié ailleurs l’emporte : plus de mention', () {
      const published = CampusOffering(campus: 'Lyon', intake: '05/10/2027');
      expect(
        _short(_program([_rolled, published]), 'fr'),
        'Rentrée : oct. 2027',
      );
      expect(
        _short(_program([published, _rolled]), 'fr'),
        'Rentrée : oct. 2027',
      );
    });

    test('le lecteur d’écran entend « date à confirmer »', () {
      expect(
        programIntakeSummary(_program([_rolled]), now: _today)
            .semanticsLabel('fr'),
        'Rentrée : octobre 2027, date à confirmer',
      );
    });
  });

  group('ProgramDetailScreen — offre reconduite', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      resetGetxSingleton();
    });
    tearDown(resetGetxSingleton);

    Future<void> seed(ProgramModel program) async {
      AppConfig.enableRemoteSyncOverride = false;
      setupPlatformChannelMocks();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        programs: [program],
      );
      final controller = AppController(
        repository: FakeRepository(snapshot: snapshot),
        apiClient: MockApiClient(),
      );
      await controller.hydrate();
      controller.programs
        ..clear()
        ..add(program);
      Get.put<AppController>(controller, permanent: true);
    }

    testWidgets(
        'l’offre reconduite dit « à confirmer », la décalée garde son prix',
        (tester) async {
      final previousClock = ProgramIntakes.clock;
      ProgramIntakes.clock = () => _today;
      addTearDown(() => ProgramIntakes.clock = previousClock);
      final handle = tester.ensureSemantics();
      await seed(_program([_spring, _rolled]));
      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        home: const ProgramDetailScreen(programId: 'omnes-p-dc41accace3b7cf8'),
      ));
      await tester.pumpAndSettle();

      expect(find.text("Rentrée d'octobre 2027"), findsOneWidget);
      expect(
        find.text('Date reconduite de 2026, à confirmer · tarif 2026-2027'),
        findsOneWidget,
      );
      expect(
        find.text('Rentrée décalée · mars 2027 · Formation initiale'),
        findsOneWidget,
      );
      expect(find.text('6 690 €/an'), findsOneWidget);
      // Une seule mention : l'offre de printemps est publiée par l'école.
      expect(find.textContaining('reconduite'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(
          r"^Paris, Rentrée d'octobre 2027, 8 850 €/an, "
          r'Date reconduite de la rentrée 2026, à confirmer par',
        )),
        findsOneWidget,
      );
      handle.dispose();
      expect(tester.takeException(), isNull);
    });
  });
}
