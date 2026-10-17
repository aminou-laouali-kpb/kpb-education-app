import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/app_search_service.dart';
import 'package:karatou/app/core/services/program_filter_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/program_intakes.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';

import '../../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Catalogue Amérique du Nord (16/10/2026) : des universités NON partenaires.
// La fiche ne doit ni afficher de badge partenaire, ni annoncer une
// « soumission à l'école partenaire », ni écrire « Sur demande » à côté d'une
// rentrée dont le prix (en USD) est dans la tuile « Frais ». La recherche et le
// filtre pays doivent les trouver.
// ─────────────────────────────────────────────────────────────────────────────

InstitutionModel _institution({
  required String id,
  required String name,
  required String countryId,
  required String city,
  required bool isPartner,
}) =>
    InstitutionModel(
      id: id,
      name: LocalizedText(fr: name, en: name),
      countryId: countryId,
      location: LocalizedText(fr: city, en: city),
      overview: const LocalizedText(
        fr: "KPB n'est pas partenaire de cet établissement.",
        en: 'KPB is not a partner of this institution.',
      ),
      studyLevels: const ['Bachelor'],
      tuitionLabel: const LocalizedText(fr: '', en: ''),
      languageRequirements: const LocalizedText(fr: '', en: ''),
      intakePeriods: const ['Janvier 2027', 'Automne 2027'],
      programIds: const [],
      isPartner: isPartner,
    );

ProgramModel _program({
  required String id,
  required String institutionId,
  required String countryId,
  required String name,
  required String tuition,
  List<CampusOffering> offerings = const [],
}) =>
    ProgramModel(
      id: id,
      institutionId: institutionId,
      countryId: countryId,
      fieldId: 'd01',
      name: LocalizedText(fr: name, en: name),
      level: const LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
      duration: const LocalizedText(fr: '4 ans', en: '4 years'),
      tuition: LocalizedText(fr: tuition, en: tuition),
      language: const LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: const [],
      campusOfferings: offerings,
    );

final _houston = _institution(
  id: 'na-us-houston',
  name: 'University of Houston',
  countryId: 'usa',
  city: 'Houston, Texas',
  isPartner: false,
);
final _uqam = _institution(
  id: 'na-ca-uqam',
  name: 'Université du Québec à Montréal (UQAM)',
  countryId: 'can',
  city: 'Montréal, Québec',
  isPartner: false,
);
final _partner = _institution(
  id: 'omnes-ece',
  name: 'ECE',
  countryId: 'fra',
  city: 'Paris',
  isPartner: true,
);

final _houstonCs = _program(
  id: 'na-us-houston--bs-computer-science',
  institutionId: 'na-us-houston',
  countryId: 'usa',
  name: 'Computer Science, B.S.',
  tuition: '28 065 USD/an (2 semestres, non-résident)',
  offerings: const [
    CampusOffering(campus: 'Houston', intake: '01/2027', session: 'spring'),
    CampusOffering(campus: 'Houston', intake: 'FALL 2027', session: 'fall'),
  ],
);
final _uqamInfo = _program(
  id: 'na-ca-uqam--baccalaureat-informatique-genie-logiciel',
  institutionId: 'na-ca-uqam',
  countryId: 'can',
  name: 'Baccalauréat en informatique et génie logiciel',
  tuition: '',
);
final _eceProgram = _program(
  id: 'omnes-p-x',
  institutionId: 'omnes-ece',
  countryId: 'fra',
  name: 'ECE - B1 - Cybersécurité',
  tuition: '8 850 €/an',
);

Future<AppController> _seed() async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final institutions = [_houston, _uqam, _partner];
  final programs = [_houstonCs, _uqamInfo, _eceProgram];
  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    institutions: institutions,
    programs: programs,
  );
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  controller.institutions
    ..clear()
    ..addAll(institutions);
  controller.programs
    ..clear()
    ..addAll(programs);
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

Future<void> _open(WidgetTester tester, String programId) async {
  await tester.pumpWidget(GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr'),
    fallbackLocale: const Locale('fr'),
    home: ProgramDetailScreen(programId: programId),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('ProgramDetailScreen — établissement non partenaire', () {
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

    testWidgets(
        'ne se dit pas partenaire et n’écrit pas « Sur demande » à côté des rentrées',
        (tester) async {
      await _seed();
      await _open(tester, 'na-us-houston--bs-computer-science');

      expect(
        find.text(
          "Envoi de ta candidature à l'établissement (KPB n'en est pas partenaire)",
        ),
        findsOneWidget,
      );
      expect(find.text("Soumission à l'école partenaire"), findsNothing);
      expect(find.text('Partenaire KPB'), findsNothing);
      expect(find.text('Partenaire Officiel'), findsNothing);
      // Deux rentrées à Houston, sans prix d'offre : le prix est dans la tuile.
      expect(find.text('Disponible sur 1 campus'), findsOneWidget);
      expect(find.text('Sur demande'), findsNothing);
      expect(find.textContaining('28 065 USD/an'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'une école partenaire garde « Soumission à l’école partenaire »',
        (tester) async {
      await _seed();
      await _open(tester, 'omnes-p-x');
      expect(find.text("Soumission à l'école partenaire"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Recherche et filtres — Canada / États-Unis', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      resetGetxSingleton();
    });
    tearDown(resetGetxSingleton);

    test('la recherche trouve « Houston » et le sigle « UQAM »', () {
      final service = AppSearchService(AppSearchContext(
        localeCode: 'fr',
        fields: const [],
        countries: const [],
        institutions: [_houston, _uqam, _partner],
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
      expect(ids('Houston'), ['na-us-houston']);
      expect(ids('UQAM'), ['na-ca-uqam']);
      expect(ids('Montréal'), ['na-ca-uqam']);
    });

    test(
        'le filtre pays isole le Canada et les États-Unis ; « partenaires » les écarte',
        () async {
      final controller = await _seed();
      List<String> run(ProgramFilterState f) =>
          ProgramFilterService.apply(controller.programs, f, controller)
              .map((p) => p.id)
              .toList();
      expect(
          run(const ProgramFilterState(countryId: 'usa', partnerOnly: false)),
          ['na-us-houston--bs-computer-science']);
      expect(
          run(const ProgramFilterState(countryId: 'can', partnerOnly: false)),
          ['na-ca-uqam--baccalaureat-informatique-genie-logiciel']);
      // Vue « Partenaires » (défaut de l'écran Universités) : jamais listées.
      expect(
          run(const ProgramFilterState()).where((id) => id.startsWith('na-')),
          isEmpty);
      expect(
          run(const ProgramFilterState(query: 'houston', partnerOnly: false)),
          ['na-us-houston--bs-computer-science']);
    });
  });
}
