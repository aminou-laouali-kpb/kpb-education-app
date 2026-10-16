import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/app_search_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/intake_label.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';

import '../../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Chantier E/J : une formation peut avoir deux offres sur le MÊME campus — la
// rentrée d'automne et la rentrée décalée (OMNES printemps 2027, IGENSIA mars
// et septembre 2027), chacune à son prix. La fiche doit le dire en toutes
// lettres, et la recherche doit trouver les nouvelles écoles IGENSIA.
// ─────────────────────────────────────────────────────────────────────────────

const _fall = CampusOffering(
  campus: 'Paris',
  tuitionUpfront: 8850,
  tuitionInstallments: 9293,
  intake: '01/10/2026',
);

const _spring = CampusOffering(
  campus: 'Paris',
  tuitionUpfront: 6690,
  tuitionInstallments: 7025,
  intake: '01/03/2027',
  session: 'spring',
  rhythm: 'alternance',
);

InstitutionModel _institution(String id, String name) => InstitutionModel(
      id: id,
      name: LocalizedText(fr: name, en: name),
      countryId: 'fra',
      location: const LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: const LocalizedText(fr: '', en: ''),
      studyLevels: const ['Bachelor'],
      tuitionLabel: const LocalizedText(fr: '', en: ''),
      languageRequirements: const LocalizedText(fr: '', en: ''),
      intakePeriods: const [],
      programIds: const [],
      isPartner: true,
    );

const _program = ProgramModel(
  id: 'omnes-p-dc41accace3b7cf8',
  institutionId: 'omnes-ece',
  countryId: 'fra',
  fieldId: 'd01',
  name: LocalizedText(
    fr: 'ECE - B1 - Cybersécurité et réseaux',
    en: 'ECE - B1 - Cybersécurité et réseaux',
  ),
  level: LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
  duration: LocalizedText(fr: '3 ans', en: '3 years'),
  tuition: LocalizedText(fr: '8 850 €/an', en: '8 850 €/year'),
  language: LocalizedText(fr: 'Français', en: 'Français'),
  requirements: [],
  // Ordre de la base : l'offre de printemps a été AJOUTÉE à la fin.
  campusOfferings: [_spring, _fall],
  recognition: LocalizedText(
    fr: 'Titre RNCP (certifié par l’État)',
    en: 'RNCP title (state-certified)',
  ),
);

Future<void> _seed() async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    institutions: [_institution('omnes-ece', 'ECE')],
    programs: const [_program],
  );
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  controller.institutions
    ..clear()
    ..addAll(snapshot.institutions);
  controller.programs
    ..clear()
    ..add(_program);
  Get.put<AppController>(controller, permanent: true);
}

void main() {
  group('offeringIntakeLabel', () {
    setUp(() {
      Get.addTranslations(AppTranslations().keys);
    });

    test('dit la rentrée décalée et la rentrée d’automne en toutes lettres',
        () {
      Get.locale = const Locale('fr');
      expect(offeringIntakeLabel(_spring, 'fr'), 'Rentrée décalée · mars 2027');
      expect(offeringIntakeLabel(_fall, 'fr'), "Rentrée d'octobre 2026");
      expect(
        offeringIntakeLabel(
          const CampusOffering(campus: 'Lyon', intake: '15/09/2026'),
          'fr',
        ),
        'Rentrée de septembre 2026',
      );
      // Sans session déclarée, le mois décide : janvier–juin = décalée.
      expect(
        offeringIntakeLabel(
          const CampusOffering(campus: 'Lyon', intake: '22/02/2027'),
          'fr',
        ),
        'Rentrée décalée · février 2027',
      );
      // IGENSIA écrit « mm/aaaa », ABC « FALL 2027 » sans mois.
      expect(
        offeringIntakeLabel(
          const CampusOffering(
              campus: 'Paris', intake: '03/2027', session: 'spring'),
          'fr',
        ),
        'Rentrée décalée · mars 2027',
      );
      expect(
        offeringIntakeLabel(
          const CampusOffering(
              campus: 'Paris', intake: 'FALL 2027', session: 'fall'),
          'fr',
        ),
        "Rentrée d'automne 2027",
      );
      // Texte libre de l'admin : affiché tel quel, comme avant.
      expect(
        offeringIntakeLabel(
          const CampusOffering(campus: 'Paris', intake: 'Sur dossier'),
          'fr',
        ),
        'Rentrée Sur dossier',
      );
      expect(
        offeringIntakeLabel(const CampusOffering(campus: 'Paris'), 'fr'),
        isNull,
      );
    });

    test('parle anglais en anglais', () {
      Get.locale = const Locale('en');
      expect(offeringIntakeLabel(_spring, 'en'), 'Spring intake · March 2027');
      expect(offeringIntakeLabel(_fall, 'en'), 'October 2026 intake');
      Get.locale = const Locale('fr');
    });

    test('compte les campus, pas les offres, et range par campus puis date',
        () {
      const lyon = CampusOffering(campus: 'Lyon', intake: '01/10/2026');
      expect(distinctCampusCount([_spring, _fall]), 1);
      expect(distinctCampusCount([_spring, _fall, lyon]), 2);
      expect(sortedOfferings([_spring, lyon, _fall]), [lyon, _fall, _spring]);
    });

    test('lit et réécrit session et rythme (cache hors ligne)', () {
      final back = CampusOffering.fromJson(_spring.toJson());
      expect(back.session, 'spring');
      expect(back.rhythm, 'alternance');
      expect(_fall.toJson().containsKey('session'), isFalse);
      final program = ProgramModel.fromJson(_program.toJson());
      expect(program.recognition?.fr, 'Titre RNCP (certifié par l’État)');
      expect(program.campusOfferings, hasLength(2));
      final bare = ProgramModel.fromJson({'id': 'x', 'recognition': null});
      expect(bare.recognition, isNull);
    });
  });

  group('ProgramDetailScreen — plusieurs rentrées sur un campus', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      resetGetxSingleton();
    });
    tearDown(resetGetxSingleton);

    testWidgets('montre les deux rentrées de Paris, chacune avec son prix',
        (tester) async {
      await _seed();
      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        home: const ProgramDetailScreen(programId: 'omnes-p-dc41accace3b7cf8'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Disponible sur 1 campus'), findsOneWidget);
      expect(find.text("Rentrée d'octobre 2026"), findsOneWidget);
      expect(
        find.text('Rentrée décalée · mars 2027 · Alternance'),
        findsOneWidget,
      );
      expect(find.text('8 850 €/an'), findsWidgets);
      expect(find.text('6 690 €/an'), findsOneWidget);
      expect(find.text('Reconnaissance du diplôme'), findsOneWidget);
      expect(find.text('Titre RNCP (certifié par l’État)'), findsOneWidget);
      // L'automne d'abord, puis la rentrée décalée, quel que soit l'ordre en base.
      final fallY = tester.getTopLeft(find.text("Rentrée d'octobre 2026")).dy;
      final springY = tester
          .getTopLeft(find.text('Rentrée décalée · mars 2027 · Alternance'))
          .dy;
      expect(fallY, lessThan(springY));
      expect(tester.takeException(), isNull);
    });
  });

  group('Recherche — les écoles IGENSIA Education', () {
    final institutions = [
      _institution('igensia-isb', 'IGENSIA School of Business'),
      _institution('igensia-tech', 'IGENSIA Tech'),
      _institution('igensia-rh', 'IGENSIA RH'),
      _institution('igensia-abc', 'American Business College (ABC)'),
      _institution('omnes-ece', 'ECE'),
    ];
    final service = AppSearchService(AppSearchContext(
      localeCode: 'fr',
      fields: const [],
      countries: const [],
      institutions: institutions,
      programs: const [],
      scholarships: const [],
      profile: null,
      latestOrientationSession: null,
    ));
    List<String> ids(String q) => service
        .run(q)
        .where((r) => r.type == SearchResultType.institution)
        .map((r) => r.id)
        .toList();

    test('« IGENSIA » trouve les trois écoles IGENSIA', () {
      expect(ids('IGENSIA'), ['igensia-isb', 'igensia-tech', 'igensia-rh']);
    });

    test('« ABC » et « American Business College » trouvent ABC', () {
      expect(ids('ABC'), ['igensia-abc']);
      expect(ids('american business college'), ['igensia-abc']);
    });
  });
}
