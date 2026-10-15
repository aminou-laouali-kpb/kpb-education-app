// Chantier I — ce que la CARTE de la liste dit d'une bourse, le drapeau tiré
// de `countryId`, le statut filtrable et ce que la liste masque.
//
// La carte n'a plus de calcul à elle : elle pose la puce d'urgence de la fiche
// (`scholarship_urgency.dart`). Ces tests gardent ce qu'elle doit en lire :
// une variante par état de cycle, jamais plus que ce qu'on sait.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/live_scholarships_query.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/country_utils.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';
import 'package:karatou/app/features/scholarships/scholarship_urgency.dart';

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

  ScholarshipUrgency urgency(LiveScholarshipModel s) =>
      scholarshipUrgencyOf(s, now: _now);
  String label(LiveScholarshipModel s) =>
      scholarshipUrgencyLabel(urgency(s), now: _now);

  group('puce de la carte — une variante par cycle', () {
    test('ouverte, clôture confirmée lointaine : « Ouverte · clôture … »', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 10)),
          closesAt: DateTime(2027, 1, 6, 23, 59),
        ),
      );
      expect(urgency(s).kind, ScholarshipUrgencyKind.open);
      // Hors MaterialApp, DateFormat retombe sur le numérique ; l'année est
      // dite quand elle n'est pas celle de [now].
      expect(label(s), 'Ouverte · clôture 06/01/2027');
      expect(scholarshipListStatusOf(s, now: _now), ScholarshipListStatus.open);
    });

    test('ouverte, clôture confirmée dans 5 jours : « Clôture proche »', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 10)),
          closesAt: _now.add(const Duration(days: 5)),
        ),
      );
      expect(urgency(s).kind, ScholarshipUrgencyKind.closingSoon);
      expect(urgency(s).daysLeft, 5);
      expect(label(s), 'Clôture proche · 20/10');
      expect(scholarshipListStatusOf(s, now: _now), ScholarshipListStatus.open);
    });

    test('ouverte sans date ferme : « clôture à confirmer », sans urgence', () {
      final s = _scholarship(cycle: _cycle(status: 'open'));
      expect(urgency(s).kind, ScholarshipUrgencyKind.openDateToConfirm);
      expect(label(s), 'Ouverte · date de clôture à confirmer');
      expect(scholarshipListStatusOf(s, now: _now), ScholarshipListStatus.open);
    });

    test('ouverte mais ouverture confirmée à venir : jamais « Ouverte »', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: DateTime(2026, 11, 3, 9),
          closesAt: DateTime(2027, 1, 6),
        ),
      );
      expect(urgency(s).kind, ScholarshipUrgencyKind.opensOn);
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
      expect(urgency(s).kind, ScholarshipUrgencyKind.openingEstimated);
      expect(label(s), 'Ouverture estimée : 02/2027');
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
      expect(urgency(s).kind, ScholarshipUrgencyKind.closingEstimated);
      expect(urgency(s).isClosingSoon, isFalse);
      expect(label(s), 'Clôture estimée 10/2026');
      expect(
        scholarshipListStatusOf(s, now: _now),
        ScholarshipListStatus.forecast,
      );
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

    test('fiche sans cycle : la date limite seule parle', () {
      final s = _scholarship(deadlineAt: _now.add(const Duration(days: 40)));
      expect(urgency(s).kind, ScholarshipUrgencyKind.open);
    });

    testWidgets('la puce se lit à 12 sp au moins', (tester) async {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 10)),
          closesAt: _now.add(const Duration(days: 2)),
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScholarshipUrgencyChip(urgency: urgency(s), now: _now),
        ),
      ));
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.fontSize, greaterThanOrEqualTo(12));
      }
      expect(find.text('Clôture proche · 17/10'), findsOneWidget);
    });
  });

  // Ce que la liste MASQUE (en ligne comme depuis le cache hors ligne) est
  // exactement ce que la fiche dit « Clôturée » — ni plus, ni moins.
  group('masquée par la liste ⇔ « Clôturée » sur la fiche', () {
    test('clôture confirmée passée : clôturée, masquée, hors de tout filtre',
        () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'open',
          opensAt: _now.subtract(const Duration(days: 60)),
          closesAt: _now.subtract(const Duration(days: 1)),
        ),
      );
      expect(label(s), 'Clôturée');
      expect(isScholarshipClosed(s, now: _now), isTrue);
      expect(scholarshipListStatusOf(s, now: _now), isNull);
    });

    test('fiche sans cycle, date limite passée : clôturée', () {
      final s =
          _scholarship(deadlineAt: _now.subtract(const Duration(days: 1)));
      expect(isScholarshipClosed(s, now: _now), isTrue);
    });

    test('cycle fermé par l\'équipe : clôturé, même à dates estimées', () {
      expect(
        isScholarshipClosed(_scholarship(cycle: _cycle(status: 'closed')),
            now: _now),
        isTrue,
      );
      expect(
        isScholarshipClosed(
          _scholarship(
            cycle: _cycle(
              status: 'closed',
              confidence: 'estimated',
              estimatedCloseAt: _now.add(const Duration(days: 30)),
            ),
          ),
          now: _now,
        ),
        isTrue,
      );
    });

    test(
        '`closed` servi parce que la clôture ESTIMÉE est passée : « Date à '
        'confirmer », VISIBLE (la fiche ne dit pas « Clôturée »)', () {
      final s = _scholarship(
        cycle: _cycle(
          status: 'closed',
          confidence: 'estimated',
          estimatedCloseAt: _now.subtract(const Duration(days: 3)),
        ),
      );
      expect(label(s), 'Date à confirmer');
      expect(isScholarshipClosed(s, now: _now), isFalse);
      expect(
        scholarshipListStatusOf(s, now: _now),
        ScholarshipListStatus.forecast,
      );
    });

    test('date limite ESTIMÉE passée : jamais masquée', () {
      final s = _scholarship(
        deadlineAt: _now.subtract(const Duration(days: 2)),
        cycle: _cycle(status: 'forecast', confidence: 'estimated'),
      );
      expect(isScholarshipClosed(s, now: _now), isFalse);
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
