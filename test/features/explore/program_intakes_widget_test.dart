import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/program_intake_line.dart';
import 'package:karatou/app/core/utils/program_intakes.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';
import 'package:karatou/app/features/universities/widgets/program_catalog_card.dart';

import '../../widget_test_helpers.dart';

// « Rajouter la rentrée disponible pour chacun des programmes » : la ligne des
// rentrées sur la carte catalogue et en tête de la fiche. Aujourd'hui =
// 16/10/2026 (horloge injectée).

InstitutionModel _school(List<String> periods) => InstitutionModel(
      id: 'school',
      name: const LocalizedText(fr: 'École', en: 'School'),
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
      institutionId: 'school',
      countryId: 'fra',
      fieldId: 'd01',
      name: const LocalizedText(
        fr: 'Bachelor Marketing digital et communication',
        en: 'Bachelor Digital marketing and communication',
      ),
      level: const LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
      duration: const LocalizedText(fr: '3 ans', en: '3 years'),
      tuition: const LocalizedText(fr: '8 850 €/an', en: '8 850 €/year'),
      language: const LocalizedText(fr: 'Français', en: 'French'),
      requirements: const [],
      campusOfferings: offerings,
    );

const _fall2027 = CampusOffering(campus: 'Paris', intake: '01/10/2027');
const _fall2026 = CampusOffering(campus: 'Paris', intake: '01/10/2026');
const _spring2027 = CampusOffering(
  campus: 'Paris',
  intake: '01/03/2027',
  session: 'spring',
);

/// Les cas de la demande : libellé attendu sur la carte (null = pas de ligne).
final _cases = <({
  String name,
  List<CampusOffering> offerings,
  List<String> periods,
  String? label,
})>[
  (
    name: 'automne seul',
    offerings: const [_fall2027],
    periods: const [],
    label: 'Rentrée : oct. 2027',
  ),
  (
    name: 'automne + décalée (automne 2026 passé, masqué)',
    offerings: const [_fall2026, _spring2027, _fall2027],
    periods: const [],
    label: 'Rentrées : mars 2027 (décalée) · oct. 2027',
  ),
  (
    name: 'IGENSIA mars + septembre',
    offerings: const [
      CampusOffering(campus: 'Paris', intake: '09/2027', session: 'fall'),
      CampusOffering(campus: 'Paris', intake: '03/2027', session: 'spring'),
    ],
    periods: const [],
    label: 'Rentrées : mars 2027 (décalée) · sept. 2027',
  ),
  (
    name: 'sans offres, repli école',
    offerings: const [],
    periods: const ['Septembre', 'Février'],
    label: "Rentrées de l'école : Septembre · Février",
  ),
  (
    name: 'sans rien',
    offerings: const [],
    periods: const [],
    label: null,
  ),
];

Future<void> _seed(ProgramModel program, InstitutionModel school) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    institutions: [school],
    programs: [program],
  );
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  controller.institutions
    ..clear()
    ..add(school);
  controller.programs
    ..clear()
    ..add(program);
  Get.put<AppController>(controller, permanent: true);
}

Widget _app(Widget home, {double textScale = 1}) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 780),
          textScaler: TextScaler.linear(textScale),
        ),
        child: home,
      ),
    );

Widget _card(ProgramModel program, InstitutionModel school) => Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProgramCatalogCard(
            name: program.name.fr,
            institution: school.name.fr,
            level: 'Bachelor',
            tuition: program.tuition.fr,
            language: 'Français',
            duration: '3 ans',
            flag: '🇫🇷',
            saved: false,
            isPartner: true,
            onSave: () {},
            onTap: () {},
            intake: ProgramIntakeLine(program: program, institution: school),
          ),
        ],
      ),
    );

void main() {
  late DateTime Function() previousClock;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    previousClock = ProgramIntakes.clock;
    ProgramIntakes.clock = () => DateTime(2026, 10, 16);
  });
  tearDown(() {
    ProgramIntakes.clock = previousClock;
    resetGetxSingleton();
  });

  final intakeLine = find.byKey(const ValueKey('program-intake-line'));

  group('ProgramCatalogCard — la ligne des rentrées', () {
    for (final c in _cases) {
      testWidgets(c.name, (tester) async {
        final program = _program(c.offerings);
        final school = _school(c.periods);
        await _seed(program, school);
        await tester.pumpWidget(_app(_card(program, school)));
        await tester.pumpAndSettle();

        if (c.label == null) {
          expect(intakeLine, findsNothing);
        } else {
          expect(find.text(c.label!), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'le libellé lu est complet (mois en toutes lettres, sans « + n »)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final program = _program(const [
        _spring2027,
        _fall2027,
        CampusOffering(campus: 'Paris', intake: '01/03/2028'),
        CampusOffering(campus: 'Paris', intake: '01/10/2028'),
      ]);
      final school = _school(const []);
      await _seed(program, school);
      await tester.pumpWidget(_app(_card(program, school)));
      await tester.pumpAndSettle();

      expect(
        find.text('Rentrées : mars 2027 (décalée) · oct. 2027 + 2'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Rentrées : mars 2027, rentrée décalée, octobre 2027, '
          'mars 2028, rentrée décalée, octobre 2028',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('pas de débordement à l’échelle de texte 1,5', (tester) async {
      final program = _program(const [
        _spring2027,
        _fall2027,
        CampusOffering(campus: 'Paris', intake: '01/03/2028'),
        CampusOffering(campus: 'Paris', intake: '01/10/2028'),
      ]);
      final school = _school(const []);
      await _seed(program, school);
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(_card(program, school), textScale: 1.5));
      await tester.pumpAndSettle();
      expect(intakeLine, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ProgramDetailScreen — les rentrées en tête de fiche', () {
    for (final c in _cases) {
      testWidgets(c.name, (tester) async {
        final program = _program(c.offerings);
        final school = _school(c.periods);
        await _seed(program, school);
        await tester
            .pumpWidget(_app(const ProgramDetailScreen(programId: 'prog')));
        await tester.pumpAndSettle();

        if (c.label == null) {
          expect(intakeLine, findsNothing);
        } else {
          expect(
            find.descendant(of: intakeLine, matching: find.text(c.label!)),
            findsOneWidget,
          );
          // Sous le titre, avant les offres par campus.
          final lineY = tester.getTopLeft(intakeLine).dy;
          final titleY = tester.getTopLeft(find.text(program.name.fr)).dy;
          expect(lineY, greaterThan(titleY));
          if (c.offerings.isNotEmpty) {
            final campusY =
                tester.getTopLeft(find.text('Disponible sur 1 campus')).dy;
            expect(lineY, lessThan(campusY));
          }
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('pas de débordement à l’échelle de texte 1,5', (tester) async {
      final program = _program(const [_fall2026, _spring2027, _fall2027]);
      final school = _school(const []);
      await _seed(program, school);
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        const ProgramDetailScreen(programId: 'prog'),
        textScale: 1.5,
      ));
      await tester.pumpAndSettle();
      expect(intakeLine, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
