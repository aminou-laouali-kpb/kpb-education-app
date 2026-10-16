import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/program_intakes.dart';

// Le résumé des rentrées d'une formation (program_intakes.dart) : source,
// dédoublonnage, tri, rentrée décalée, dates passées, repli école, « + n ».
// Aujourd'hui = 16/10/2026, par l'horloge injectée.

final _today = DateTime(2026, 10, 16);

ProgramModel _program(List<CampusOffering> offerings) => ProgramModel(
      id: 'p',
      institutionId: 'i',
      countryId: 'fra',
      fieldId: 'd01',
      name: const LocalizedText(fr: 'P', en: 'P'),
      level: const LocalizedText(fr: '', en: ''),
      duration: const LocalizedText(fr: '', en: ''),
      tuition: const LocalizedText(fr: '', en: ''),
      language: const LocalizedText(fr: '', en: ''),
      requirements: const [],
      campusOfferings: offerings,
    );

InstitutionModel _school(List<String> periods) => InstitutionModel(
      id: 'i',
      name: const LocalizedText(fr: 'École', en: 'School'),
      countryId: 'fra',
      location: const LocalizedText(fr: '', en: ''),
      overview: const LocalizedText(fr: '', en: ''),
      studyLevels: const [],
      tuitionLabel: const LocalizedText(fr: '', en: ''),
      languageRequirements: const LocalizedText(fr: '', en: ''),
      intakePeriods: periods,
      programIds: const [],
    );

CampusOffering _o(String campus, String intake, [String? session]) =>
    CampusOffering(campus: campus, intake: intake, session: session);

String? _fr(ProgramModel p, {InstitutionModel? school}) =>
    programIntakeSummary(p, institution: school, now: _today).shortLabel('fr');

void main() {
  setUp(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
  });

  test('automne seul : une rentrée, au singulier', () {
    expect(_fr(_program([_o('Paris', '15/09/2027')])), 'Rentrée : sept. 2027');
  });

  test('dédoublonne par mois et trie, quel que soit l’ordre des offres', () {
    final p = _program([
      _o('Lyon', '01/03/2027', 'spring'),
      _o('Paris', '01/10/2027'),
      _o('Lyon', '01/10/2027'),
      _o('Paris', '04/03/2027'),
    ]);
    expect(_fr(p), 'Rentrées : mars 2027 (décalée) · oct. 2027');
  });

  test('IGENSIA : mars et septembre 2027 (mm/aaaa)', () {
    final p = _program([
      _o('Paris', '09/2027', 'fall'),
      _o('Paris', '03/2027', 'spring'),
    ]);
    expect(_fr(p), 'Rentrées : mars 2027 (décalée) · sept. 2027');
  });

  test('une date passée est masquée ; toutes passées → « non publiée »', () {
    // L'automne 2026 d'OMNES (01/10 et 15/09) est passé le 16/10/2026.
    final p = _program([
      _o('Paris', '01/10/2026 · 15/09/2026'),
      _o('Paris', '01/03/2027', 'spring'),
    ]);
    expect(_fr(p), 'Rentrée : mars 2027 (décalée)');

    final past = programIntakeSummary(
      _program([_o('Paris', '01/10/2026')]),
      // L'école annonce une date future : elle ne prête pas sa rentrée à
      // une formation dont les offres sont toutes passées.
      institution: _school(['01/03/2027']),
      now: _today,
    );
    expect(past.allPast, isTrue);
    expect(past.shortLabel('fr'), 'Prochaine rentrée non publiée');
  });

  test('au jour près : passée le lendemain ; au mois : jusqu’à la fin du mois',
      () {
    expect(_fr(_program([_o('Paris', '16/10/2026')])), 'Rentrée : oct. 2026');
    expect(_fr(_program([_o('Paris', '10/2026')])), 'Rentrée : oct. 2026');
    expect(
      _fr(_program([_o('Paris', '15/10/2026')])),
      'Prochaine rentrée non publiée',
    );
  });

  test('« FALL 2027 » (ABC) : l’année et la session', () {
    expect(
      _fr(_program([_o('Paris', 'FALL 2027', 'fall')])),
      'Rentrée : automne 2027',
    );
  });

  test('au-delà de trois rentrées : deux, puis « + n »', () {
    final p = _program([
      _o('Paris', '01/03/2027', 'spring'),
      _o('Paris', '01/10/2027'),
      _o('Paris', '01/03/2028', 'spring'),
      _o('Paris', '01/10/2028'),
    ]);
    expect(_fr(p), 'Rentrées : mars 2027 (décalée) · oct. 2027 + 2');
    // Le lecteur d'écran, lui, entend tout.
    expect(
      programIntakeSummary(p, now: _today).semanticsLabel('fr'),
      'Rentrées : mars 2027, rentrée décalée, octobre 2027, '
      'mars 2028, rentrée décalée, octobre 2028',
    );
  });

  test('sans offre : les rentrées de l’école, annoncées comme telles', () {
    expect(
      _fr(_program(const []), school: _school(['Septembre', '01/03/2027'])),
      "Rentrées de l'école : mars 2027 (décalée) · Septembre",
    );
    expect(
      _fr(_program(const []), school: _school(['Septembre'])),
      "Rentrée de l'école : Septembre",
    );
  });

  test('sans offre ni rentrée d’école : rien (aucune date inventée)', () {
    final none = programIntakeSummary(
      _program(const []),
      institution: _school(const []),
      now: _today,
    );
    expect(none.isEmpty, isTrue);
    expect(none.shortLabel('fr'), isNull);
    expect(none.semanticsLabel('fr'), isNull);
    expect(
      programIntakeSummary(_program(const []), now: _today).isEmpty,
      isTrue,
    );
  });

  test('parle anglais en anglais', () {
    Get.locale = const Locale('en');
    final p = _program([
      _o('Paris', '03/2027', 'spring'),
      _o('Paris', '09/2027', 'fall'),
    ]);
    final s = programIntakeSummary(p, now: _today);
    expect(s.shortLabel('en'), 'Intakes: Mar 2027 (spring) · Sep 2027');
    expect(
      s.semanticsLabel('en'),
      'Intakes: March 2027, spring intake, September 2027',
    );
    expect(
      programIntakeSummary(_program(const []),
              institution: _school(['September']), now: _today)
          .shortLabel('en'),
      'School intake: September',
    );
    Get.locale = const Locale('fr');
  });

  test('le cache suit l’horloge injectée', () {
    final p = _program([_o('Paris', '01/03/2027', 'spring')]);
    final previous = ProgramIntakes.clock;
    addTearDown(() => ProgramIntakes.clock = previous);
    ProgramIntakes.clock = () => _today;
    expect(cachedProgramIntakeSummary(p).dates, hasLength(1));
    ProgramIntakes.clock = () => DateTime(2027, 3, 2);
    expect(cachedProgramIntakeSummary(p).allPast, isTrue);
  });
}
