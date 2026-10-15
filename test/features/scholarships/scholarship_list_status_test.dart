// Chantier I — la ligne de statut de la liste des bourses, le drapeau tiré de
// `countryId`, et le statut filtrable.
//
// Une variante par état de cycle : c'est la phrase que l'élève lit AVANT
// d'ouvrir la fiche, elle ne doit jamais dire plus que ce qu'on sait.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/live_scholarships_query.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/country_utils.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';
import 'package:karatou/app/features/scholarships/widgets/scholarship_list_status.dart';

final _now = DateTime(2026, 10, 15, 12);

LiveScholarshipModel _scholarship({
  Map<String, dynamic>? cycle,
  DateTime? deadlineAt,
  String countryId = '',
  String countryName = 'France',
}) =>
    LiveScholarshipModel.fromJson(<String, dynamic>{
      'id': 's1',
      'title': 'Bourse',
      'countryName': countryName,
      'countryId': countryId,
      'fundingType': 'fully_funded',
      'description': '',
      'advantages': <String>[],
      'eligibility': <String>[],
      'level': '',
      'deadlineLabel': '',
      'applicationUrl': '',
      'tags': <String>[],
      'matchScore': 0,
      if (deadlineAt != null) 'deadlineAt': deadlineAt.toIso8601String(),
      if (cycle != null)
        'currentCycle': <String, dynamic>{
          'id': 'c1',
          'academicYear': '2027-2028',
          ...cycle,
        },
    });

String? _iso(DateTime? date) => date?.toIso8601String();

Map<String, dynamic> _cycle({
  required String status,
  String confidence = 'confirmed',
  DateTime? opensAt,
  DateTime? closesAt,
  DateTime? estimatedOpenAt,
  DateTime? estimatedCloseAt,
}) =>
    <String, dynamic>{
      'status': status,
      'dateConfidence': confidence,
      'opensAt': _iso(opensAt),
      'closesAt': _iso(closesAt),
      'estimatedOpenAt': _iso(estimatedOpenAt),
      'estimatedCloseAt': _iso(estimatedCloseAt),
    };

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
  });

  ScholarshipListLine line(LiveScholarshipModel s) =>
      scholarshipListLine(s, now: _now);
  String label(LiveScholarshipModel s) =>
      scholarshipListLineLabel(line(s), now: _now);

  group('ligne de statut — une variante par cycle', () {
    test('ouverte, clôture confirmée lointaine : « Ouverte · clôture … »', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 10)),
          closesAt: DateTime(2027, 1, 6, 23, 59),
        ),
      );
      expect(line(s).kind, ScholarshipListLineKind.open);
      expect(line(s).closingSoon, isFalse);
      // Hors MaterialApp, DateFormat retombe sur le numérique, sans l'année
      // pour une date à moins de 300 jours.
      expect(label(s), 'Ouverte · clôture 06/01');
      expect(scholarshipListStatusOf(s, now: _now), ScholarshipListStatus.open);
    });

    test('ouverte, clôture dans 5 jours : « Clôture proche · J-5 »', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 10)),
          closesAt: _now.add(const Duration(days: 5)),
        ),
      );
      expect(line(s).closingSoonDays, 5);
      expect(scholarshipClosingSoonLabel(5), 'Clôture proche · J-5');
      expect(scholarshipClosingSoonLabel(0), 'Clôture aujourd\'hui');
    });

    test('ouverte sans date ferme : « Ouverte · clôture à confirmer »', () {
      final s = _scholarship(cycle: _cycle(status: 'open'));
      expect(line(s).kind, ScholarshipListLineKind.openNoDate);
      expect(label(s), 'Ouverte · clôture à confirmer');
      expect(line(s).closingSoon, isFalse);
    });

    test('ouverte mais ouverture confirmée à venir : jamais « Ouverte »', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: DateTime(2026, 11, 3, 9),
          closesAt: DateTime(2027, 1, 6),
        ),
      );
      expect(line(s).kind, ScholarshipListLineKind.opensOn);
      expect(label(s), 'Ouvre le 03/11');
      expect(
        scholarshipListStatusOf(s, now: _now),
        ScholarshipListStatus.upcoming,
      );
    });

    test('ouverture estimée : au MOIS près, jamais au jour', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'forecast',
          confidence: 'estimated',
          estimatedOpenAt: DateTime.utc(2027, 2, 1),
          estimatedCloseAt: DateTime.utc(2027, 3, 31),
        ),
      );
      expect(line(s).kind, ScholarshipListLineKind.openingEstimated);
      expect(label(s), 'Ouverture estimée 02/2027');
      expect(line(s).closingSoon, isFalse);
      expect(
        scholarshipListStatusOf(s, now: _now),
        ScholarshipListStatus.forecast,
      );
    });

    test('période estimée en cours : « Clôture estimée … », sans urgence', () {
      final s = _scholarship(
        deadlineAt: _now.add(const Duration(days: 3)),
        cycle: _cycle(
          status: 'forecast',
          confidence: 'estimated',
          estimatedOpenAt: _now.subtract(const Duration(days: 20)),
          estimatedCloseAt: DateTime.utc(2026, 10, 18),
        ),
      );
      expect(line(s).kind, ScholarshipListLineKind.closingEstimated);
      expect(label(s), 'Clôture estimée 10/2026');
      expect(line(s).closingSoon, isFalse);
    });

    test('rien de connu : « Date à confirmer »', () {
      expect(label(_scholarship()), 'Date à confirmer');
      expect(
        label(_scholarship(
          cycle: _cycle(status: 'forecast', confidence: 'estimated'),
        )),
        'Date à confirmer',
      );
      expect(
        scholarshipListStatusOf(_scholarship(), now: _now),
        ScholarshipListStatus.forecast,
      );
    });

    test('clôture confirmée passée : « Clôturée », et masquée hors ligne', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 60)),
          closesAt: _now.subtract(const Duration(days: 1)),
        ),
      );
      expect(label(s), 'Clôturée');
      expect(isScholarshipExpired(s, now: _now), isTrue);
      expect(scholarshipListStatusOf(s, now: _now), isNull);
    });

    test('date limite ESTIMÉE passée : jamais « expirée »', () {
      final s = _scholarship(
        deadlineAt: _now.subtract(const Duration(days: 2)),
        cycle: _cycle(status: 'forecast', confidence: 'estimated'),
      );
      expect(isScholarshipExpired(s, now: _now), isFalse);
    });

    test('fiche sans cycle : la date limite seule parle', () {
      final s = _scholarship(deadlineAt: _now.add(const Duration(days: 40)));
      expect(line(s).kind, ScholarshipListLineKind.open);
      expect(
        isScholarshipExpired(
          _scholarship(deadlineAt: _now.subtract(const Duration(days: 1))),
          now: _now,
        ),
        isTrue,
      );
    });

    test('une date à plus de 300 jours dit son année', () {
      expect(
        formatScholarshipListDay(DateTime(2027, 11, 2), now: _now),
        '02/11/2027',
      );
    });

    testWidgets('la ligne et l\'étiquette se lisent à 12 sp au moins',
        (tester) async {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 10)),
          closesAt: _now.add(const Duration(days: 2)),
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScholarshipListStatusRow(line: line(s), now: _now),
        ),
      ));
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.fontSize, greaterThanOrEqualTo(12));
      }
      expect(find.text('Clôture proche · J-2'), findsOneWidget);
    });
  });

  group('drapeaux — tirés de countryId', () {
    test('les pays du catalogue ont leur drapeau', () {
      const expected = <String, String>{
        'fra': '🇫🇷',
        'gbr': '🇬🇧',
        'zaf': '🇿🇦',
        'rwa': '🇷🇼',
        'twn': '🇹🇼',
        'kaz': '🇰🇿',
        'bfa': '🇧🇫',
        'ken': '🇰🇪',
        'tza': '🇹🇿',
        'che': '🇨🇭',
        'brn': '🇧🇳',
        'aze': '🇦🇿',
        'hun': '🇭🇺',
        'rou': '🇷🇴',
        'qat': '🇶🇦',
        'egy': '🇪🇬',
        'gha': '🇬🇭',
        'swe': '🇸🇪',
        'aus': '🇦🇺',
        'jpn': '🇯🇵',
        'ner': '🇳🇪',
        'sen': '🇸🇳',
      };
      expected.forEach((id, flag) {
        expect(countryFlag(id), flag, reason: id);
        expect(countryFlag(id.toUpperCase()), flag, reason: id);
      });
    });

    test('alpha-2 connus et noms historiques', () {
      expect(countryFlag('gb'), '🇬🇧');
      expect(countryFlag('de'), '🇩🇪');
      expect(countryFlag('japan'), '🇯🇵');
      expect(countryFlag('niger'), '🇳🇪');
      expect(countryFlag('uk'), '🇬🇧');
    });

    test('repli 🌍, jamais un drapeau deviné', () {
      expect(countryFlag('int'), '🌍');
      expect(countryFlag(''), '🌍');
      expect(countryFlag('xx'), '🌍');
      expect(countryFlag('zzz'), '🌍');
    });

    test('la carte lit countryId d\'abord, le nom en repli', () {
      expect(
        scholarshipFlag(_scholarship(
          countryId: 'gbr',
          countryName: 'Royaume-Uni — University of Cambridge',
        )),
        '🇬🇧',
      );
      // Backend sans countryId : le nom, s'il est reconnu.
      expect(scholarshipFlag(_scholarship(countryName: 'Japan')), '🇯🇵');
      expect(scholarshipFlag(_scholarship(countryName: 'Atlantis')), '🌍');
    });
  });
}
