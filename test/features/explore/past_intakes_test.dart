import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/program_intakes.dart';
import 'package:karatou/app/features/compare/institution_compare_screen.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';

import '../../widget_test_helpers.dart';

// « Rentrées d'octobre 2026 passées » : aujourd'hui = 16/10/2026 (horloge
// injectée). Une rentrée passée n'est annoncée NULLE PART comme disponible —
// fiche (tuile « Rentrée », offres par campus), comparateur, repli école,
// libellé du pays — et une date d'école brute (« 01/10/2026 ») s'écrit en
// toutes lettres, sans que la base soit réécrite.

final _today = DateTime(2026, 10, 16);

CountryModel _france(String nextIntake) => CountryModel(
      id: 'fra',
      name: const LocalizedText(fr: 'France', en: 'France'),
      whyStudy: const LocalizedText(fr: '', en: ''),
      tuitionRange: const LocalizedText(fr: '', en: ''),
      livingCostRange: const LocalizedText(fr: '', en: ''),
      visaOverview: const LocalizedText(fr: '', en: ''),
      admissionDifficulty: const LocalizedText(fr: '', en: ''),
      popularFieldIds: const ['d01'],
      flagEmoji: '🇫🇷',
      nextIntakeLabel: LocalizedText(fr: nextIntake, en: nextIntake),
      marketingDescription: const LocalizedText(fr: '', en: ''),
      whyStudyBulletsFr: const [],
      whyStudyBulletsEn: const [],
      howItWorks: const LocalizedText(fr: '', en: ''),
    );

InstitutionModel _school(String id, List<String> periods) => InstitutionModel(
      id: id,
      name: LocalizedText(fr: id.toUpperCase(), en: id.toUpperCase()),
      countryId: 'fra',
      location: const LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: const LocalizedText(fr: '', en: ''),
      studyLevels: const ['Bachelor'],
      tuitionLabel: const LocalizedText(fr: '', en: ''),
      languageRequirements: const LocalizedText(fr: '', en: ''),
      intakePeriods: periods,
      programIds: const ['prog'],
      isPartner: true,
    );

ProgramModel _program(List<CampusOffering> offerings) => ProgramModel(
      id: 'prog',
      institutionId: 'inseec',
      countryId: 'fra',
      fieldId: 'd02',
      name: const LocalizedText(
        fr: 'IMSc - M1 - Gestionnaire patrimoine',
        en: 'IMSc - M1 - Gestionnaire patrimoine',
      ),
      level: const LocalizedText(fr: 'Master', en: 'Master'),
      duration: const LocalizedText(fr: '5 ans', en: '5 years'),
      tuition: const LocalizedText(fr: '12 990 €/an', en: '12 990 €/year'),
      language: const LocalizedText(fr: 'Français', en: 'French'),
      requirements: const [],
      campusOfferings: offerings,
    );

const _octPast = CampusOffering(
  campus: 'Paris',
  tuitionUpfront: 12990,
  intake: '12/10/2026',
);
const _octPastLyon = CampusOffering(
  campus: 'Lyon',
  tuitionUpfront: 12990,
  intake: '12/10/2026',
);
const _spring = CampusOffering(
  campus: 'Paris',
  tuitionUpfront: 11990,
  intake: '24/02/2027',
  session: 'spring',
);

Future<void> _seed({
  required ProgramModel program,
  required List<InstitutionModel> schools,
  String countryIntake = 'Septembre 2026',
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    countries: [_france(countryIntake)],
    institutions: schools,
    programs: [program],
  );
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  controller.countries
    ..clear()
    ..addAll(snapshot.countries);
  controller.institutions
    ..clear()
    ..addAll(schools);
  controller.programs
    ..clear()
    ..add(program);
  Get.put<AppController>(controller, permanent: true);
}

Widget _app(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void main() {
  late DateTime Function() previousClock;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
    previousClock = ProgramIntakes.clock;
    ProgramIntakes.clock = () => _today;
  });
  tearDown(() {
    ProgramIntakes.clock = previousClock;
    resetGetxSingleton();
  });

  group('règles partagées', () {
    test('rentrées d’école : dates brutes en toutes lettres, passées masquées',
        () {
      // Les intakePeriods d'une école OMNES : dates d'automne 2026 brutes,
      // puis les dates de printemps ajoutées par l'import.
      final summary = schoolIntakeSummary(
        const ['01/10/2026', '12/10/2026', '19/10/2026', '01/03/2027'],
        now: _today,
      );
      expect(
        summary.longLabel('fr'),
        'octobre 2026 · mars 2027 (décalée)',
      );
      // Les mois anglais suivent la langue demandée.
      expect(summary.longLabel('en'), startsWith('October 2026 · March 2027'));
      // Tout passé : on le dit, sans date.
      expect(
        schoolIntakeSummary(const ['01/10/2026', '14/09/2026'], now: _today)
            .longLabel('fr'),
        'Prochaine rentrée non publiée',
      );
      // Un texte libre reste tel quel ; « Mars 2027 » est une date.
      expect(
        schoolIntakeSummary(const ['Mars 2027', 'Septembre 2027'], now: _today)
            .longLabel('fr'),
        'mars 2027 (décalée) · septembre 2027',
      );
      expect(
        schoolIntakeSummary(const ['Septembre', 'Février'], now: _today)
            .longLabel('fr'),
        'Septembre · Février',
      );
      expect(
          schoolIntakeSummary(const [], now: _today).longLabel('fr'), isNull);
    });

    test('libellé de pays : « Septembre 2026 » est passé, « Janvier 2027 » non',
        () {
      expect(upcomingIntakeText('Septembre 2026', now: _today), isNull);
      expect(upcomingIntakeText('September 2026', now: _today), isNull);
      // Octobre 2026 : le mois en cours n'est pas encore passé.
      expect(upcomingIntakeText('Octobre 2026', now: _today), 'Octobre 2026');
      expect(upcomingIntakeText('Janvier 2027', now: _today), 'Janvier 2027');
      expect(upcomingIntakeText('Rentrée de septembre', now: _today),
          'Rentrée de septembre');
      expect(upcomingIntakeText('', now: _today), isNull);
    });

    test('une offre est passée quand toutes ses dates le sont', () {
      expect(offeringIsPast(_octPast, now: _today), isTrue);
      expect(offeringIsPast(_spring, now: _today), isFalse);
      expect(
        offeringIsPast(
          const CampusOffering(
              campus: 'Paris', intake: '01/10/2026 · 01/11/2026'),
          now: _today,
        ),
        isFalse,
      );
      // IGENSIA : au mois près ; ABC : à l'année.
      expect(
        offeringIsPast(const CampusOffering(campus: 'Paris', intake: '10/2026'),
            now: _today),
        isFalse,
      );
      expect(
        offeringIsPast(
          const CampusOffering(
              campus: 'Paris', intake: 'FALL 2027', session: 'fall'),
          now: _today,
        ),
        isFalse,
      );
      expect(offeringIsPast(const CampusOffering(campus: 'Paris'), now: _today),
          isFalse);
    });
  });

  group('ProgramDetailScreen', () {
    testWidgets('une offre passée n’est ni listée ni comptée', (tester) async {
      await _seed(
        program: _program(const [_octPast, _octPastLyon, _spring]),
        schools: [
          _school('inseec', const ['12/10/2026', '24/02/2027'])
        ],
      );
      await tester
          .pumpWidget(_app(const ProgramDetailScreen(programId: 'prog')));
      await tester.pumpAndSettle();

      expect(find.text('Disponible sur 1 campus'), findsOneWidget);
      expect(find.text('Rentrée décalée · février 2027'), findsOneWidget);
      expect(find.text("Rentrée d'octobre 2026"), findsNothing);
      expect(find.text('Lyon'), findsNothing);
      // La tuile « Rentrée » : la rentrée à venir de la formation, pas
      // « Septembre 2026 » (pays, passé) ni « 12/10/2026 » (école, brut).
      expect(find.text('février 2027 (décalée)'), findsOneWidget);
      expect(find.textContaining('Septembre 2026'), findsNothing);
      expect(find.textContaining('12/10/2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toutes les offres passées : la section le dit',
        (tester) async {
      await _seed(
        program: _program(const [_octPast, _octPastLyon]),
        schools: [
          _school('inseec', const ['12/10/2026'])
        ],
      );
      await tester
          .pumpWidget(_app(const ProgramDetailScreen(programId: 'prog')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Disponible sur'), findsNothing);
      expect(find.text('Prochaine rentrée non publiée'), findsWidgets);
      expect(
        find.textContaining('Les rentrées publiées (Lyon, Paris) sont passées'),
        findsOneWidget,
      );
      expect(find.text('12 990 €/an'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans offre : le repli école est lisible et à venir',
        (tester) async {
      await _seed(
        program: _program(const []),
        schools: [
          _school('inseec', const ['01/10/2026', '19/10/2026', '01/03/2027']),
        ],
      );
      await tester
          .pumpWidget(_app(const ProgramDetailScreen(programId: 'prog')));
      await tester.pumpAndSettle();

      expect(find.text('octobre 2026 · mars 2027 (décalée)'), findsOneWidget);
      expect(find.textContaining('01/10/2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('comparateur : rentrées d’école à venir, en toutes lettres',
      (tester) async {
    await _seed(
      program: _program(const []),
      schools: [
        _school('inseec', const ['01/10/2026', '12/10/2026', '22/02/2027']),
        _school('ece', const ['01/10/2026', '21/09/2026']),
      ],
    );
    await tester.pumpWidget(_app(const InstitutionCompareScreen(
      institutionId1: 'inseec',
      institutionId2: 'ece',
    )));
    await tester.pumpAndSettle();

    expect(find.text('févr. 2027'), findsNothing);
    expect(find.text('février 2027 (décalée)'), findsOneWidget);
    expect(find.text('Prochaine rentrée non publiée'), findsOneWidget);
    expect(find.textContaining('01/10/2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
