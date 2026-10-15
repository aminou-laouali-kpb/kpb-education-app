// L'urgence d'une bourse (chantier I2) — LE calcul partagé par la liste et la
// fiche (`scholarship_urgency.dart`) :
//   · « Clôture proche » seulement sur une clôture CONFIRMÉE, à 14 jours ou
//     moins ; jamais sur une date estimée ;
//   · « Clôturée » seulement si une date confirmée est passée — le `closed`
//     que le serveur dérive d'une clôture ESTIMÉE dépassée se lit « Date à
//     confirmer » ;
//   · chaque couple texte / fond passe l'AA, et « Clôture proche » est du texte
//     FONCÉ sur ambre.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/features/scholarships/scholarship_urgency.dart';

import '../../support/chip_paint.dart';

final _now = DateTime(2026, 10, 15, 12);

LiveScholarshipModel _scholarship({
  Map<String, dynamic>? cycle,
  DateTime? deadlineAt,
}) =>
    LiveScholarshipModel.fromJson(<String, dynamic>{
      'id': 's1',
      'title': 'Bourse',
      'countryName': 'France',
      'fundingType': 'fully_funded',
      'description': '',
      'advantages': <String>[],
      'eligibility': <String>[],
      'level': 'Master',
      'deadlineLabel': '',
      'applicationUrl': '',
      'tags': <String>[],
      'matchScore': 0,
      if (deadlineAt != null) 'deadlineAt': deadlineAt.toIso8601String(),
      if (cycle != null) 'currentCycle': cycle,
    });

Map<String, dynamic> _cycle({
  String status = 'open',
  String confidence = 'confirmed',
  DateTime? opensAt,
  DateTime? closesAt,
  DateTime? estimatedOpenAt,
  DateTime? estimatedCloseAt,
}) =>
    <String, dynamic>{
      'id': 'c1',
      'academicYear': '2027-2028',
      'status': status,
      'dateConfidence': confidence,
      if (opensAt != null) 'opensAt': opensAt.toIso8601String(),
      if (closesAt != null) 'closesAt': closesAt.toIso8601String(),
      if (estimatedOpenAt != null)
        'estimatedOpenAt': estimatedOpenAt.toIso8601String(),
      if (estimatedCloseAt != null)
        'estimatedCloseAt': estimatedCloseAt.toIso8601String(),
    };

ScholarshipUrgency _of(LiveScholarshipModel s) =>
    scholarshipUrgencyOf(s, now: _now);

DateTime _inDays(int days) => DateTime(2026, 10, 15 + days, 23, 59);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });
  setUp(() {
    Get.reset();
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
  });
  tearDown(Get.reset);

  group('scholarshipUrgencyOf', () {
    test('ouverte, clôture confirmée lointaine : « Ouverte »', () {
      final u = _of(_scholarship(cycle: _cycle(closesAt: _inDays(60))));
      expect(u.kind, ScholarshipUrgencyKind.open);
      expect(u.daysLeft, 60);
      expect(u.isOpen, isTrue);
    });

    test('clôture confirmée dans 5 jours : « Clôture proche »', () {
      final u = _of(_scholarship(cycle: _cycle(closesAt: _inDays(5))));
      expect(u.kind, ScholarshipUrgencyKind.closingSoon);
      expect(u.daysLeft, 5);
      expect(u.isOpen, isTrue);
    });

    test('seuil : 14 jours = proche, 15 jours = ouverte', () {
      expect(
        _of(_scholarship(cycle: _cycle(closesAt: _inDays(14)))).kind,
        ScholarshipUrgencyKind.closingSoon,
      );
      expect(
        _of(_scholarship(cycle: _cycle(closesAt: _inDays(15)))).kind,
        ScholarshipUrgencyKind.open,
      );
    });

    test('dernier jour : proche, 0 jour', () {
      final u = _of(_scholarship(cycle: _cycle(closesAt: _inDays(0))));
      expect(u.kind, ScholarshipUrgencyKind.closingSoon);
      expect(u.daysLeft, 0);
    });

    test('ouverte à date ESTIMÉE : jamais « Clôture proche »', () {
      final u = _of(_scholarship(
        cycle: _cycle(confidence: 'estimated', estimatedCloseAt: _inDays(3)),
        deadlineAt: _inDays(3),
      ));
      expect(u.kind, ScholarshipUrgencyKind.openDateToConfirm);
      expect(u.isOpen, isTrue);
      expect(u.isClosingSoon, isFalse);
    });

    test('cycle `open` dont l\'ouverture est à venir : « Ouvre le … »', () {
      final u = _of(_scholarship(
        cycle: _cycle(opensAt: _inDays(4), closesAt: _inDays(60)),
      ));
      expect(u.kind, ScholarshipUrgencyKind.opensOn);
      expect(u.isOpen, isFalse);
    });

    test('prévision estimée : « Ouverture estimée … »', () {
      final u = _of(_scholarship(
        cycle: _cycle(
          status: 'forecast',
          confidence: 'estimated',
          estimatedOpenAt: DateTime.utc(2027, 2, 1),
        ),
      ));
      expect(u.kind, ScholarshipUrgencyKind.openingEstimated);
    });

    test('prévision sans aucune date : « Date à confirmer »', () {
      final u = _of(_scholarship(
        cycle: _cycle(status: 'forecast', confidence: 'estimated'),
      ));
      expect(u.kind, ScholarshipUrgencyKind.dateToConfirm);
    });

    test(
        '`closed` servi parce que la clôture ESTIMÉE est passée : « Date à '
        'confirmer », pas « Clôturée »', () {
      final u = _of(_scholarship(
        cycle: _cycle(
          status: 'closed',
          confidence: 'estimated',
          estimatedCloseAt: _inDays(-10),
        ),
        deadlineAt: _inDays(-10),
      ));
      expect(u.kind, ScholarshipUrgencyKind.dateToConfirm);
      expect(u.isClosed, isFalse);
    });

    test('clôture confirmée passée : « Clôturée »', () {
      final u = _of(_scholarship(
        cycle: _cycle(closesAt: _inDays(-1)),
      ));
      expect(u.kind, ScholarshipUrgencyKind.closed);
    });

    test(
        'cycle confirmé fermé, seule une clôture ESTIMÉE passée : « Date à '
        'confirmer »', () {
      final u = _of(_scholarship(
        cycle: _cycle(status: 'closed', estimatedCloseAt: _inDays(-3)),
      ));
      expect(u.kind, ScholarshipUrgencyKind.dateToConfirm);
    });

    test('cycle confirmé fermé par l\'équipe, sans date : « Clôturée »', () {
      final u = _of(_scholarship(cycle: _cycle(status: 'closed')));
      expect(u.kind, ScholarshipUrgencyKind.closed);
    });

    test('cycle confirmé fermé par l\'équipe avant sa clôture : « Clôturée »',
        () {
      final u = _of(_scholarship(
        cycle: _cycle(status: 'closed', closesAt: _inDays(20)),
      ));
      expect(u.kind, ScholarshipUrgencyKind.closed);
    });

    test(
        'cycle ESTIMÉ fermé par l\'équipe (aucune clôture estimée passée '
        'pour l\'expliquer) : « Clôturée »', () {
      expect(
        _of(_scholarship(
          cycle: _cycle(status: 'closed', confidence: 'estimated'),
        )).kind,
        ScholarshipUrgencyKind.closed,
      );
      expect(
        _of(_scholarship(
          cycle: _cycle(
            status: 'closed',
            confidence: 'estimated',
            estimatedCloseAt: _inDays(30),
          ),
        )).kind,
        ScholarshipUrgencyKind.closed,
      );
    });

    test(
        'période ESTIMÉE déjà commencée : « Clôture estimée … », au mois '
        'près, jamais « Clôture proche »', () {
      final u = _of(_scholarship(
        cycle: _cycle(
          status: 'forecast',
          confidence: 'estimated',
          estimatedOpenAt: _inDays(-20),
          estimatedCloseAt: _inDays(3),
        ),
      ));
      expect(u.kind, ScholarshipUrgencyKind.closingEstimated);
      expect(u.date, _inDays(3));
      expect(u.isClosingSoon, isFalse);
      expect(u.isOpen, isFalse);
      // Estimée, ouverture ET clôture passées : rien de fiable.
      expect(
        _of(_scholarship(
          cycle: _cycle(
            status: 'forecast',
            confidence: 'estimated',
            estimatedOpenAt: _inDays(-60),
            estimatedCloseAt: _inDays(-2),
          ),
        )).kind,
        ScholarshipUrgencyKind.dateToConfirm,
      );
    });

    test('fiche sans cycle : la date limite seule parle', () {
      expect(
        _of(_scholarship(deadlineAt: _inDays(-2))).kind,
        ScholarshipUrgencyKind.closed,
      );
      expect(
        _of(_scholarship(deadlineAt: _inDays(40))).kind,
        ScholarshipUrgencyKind.open,
      );
      expect(_of(_scholarship()).kind, ScholarshipUrgencyKind.dateToConfirm);
    });
  });

  group('libellés', () {
    test('même vocabulaire que la liste', () {
      String label(LiveScholarshipModel s) =>
          scholarshipUrgencyLabel(_of(s), now: _now);

      expect(
        label(_scholarship(cycle: _cycle(closesAt: DateTime(2026, 12, 6)))),
        'Ouverte · clôture 6 déc.',
      );
      expect(
        label(_scholarship(cycle: _cycle(closesAt: DateTime(2027, 1, 6)))),
        'Ouverte · clôture 6 janv. 2027',
      );
      expect(
        label(_scholarship(cycle: _cycle(closesAt: _inDays(5)))),
        'Clôture proche · 20 oct.',
      );
      expect(
        label(_scholarship(
          cycle: _cycle(
            status: 'forecast',
            confidence: 'estimated',
            estimatedOpenAt: DateTime.utc(2027, 2, 1),
          ),
        )),
        startsWith('Ouverture estimée'),
      );
      expect(label(_scholarship()), 'Date à confirmer');
      expect(
        label(_scholarship(cycle: _cycle(closesAt: _inDays(-1)))),
        'Clôturée',
      );
    });

    test('anglais', () {
      Get.locale = const Locale('en');
      expect(
        scholarshipUrgencyLabel(
          _of(_scholarship(cycle: _cycle(closesAt: _inDays(5)))),
          now: _now,
        ),
        'Closing soon · 20 Oct',
      );
    });
  });

  group('contraste', () {
    test('chaque couple texte / fond passe l\'AA (4,5:1)', () {
      for (final kind in ScholarshipUrgencyKind.values) {
        final style = scholarshipUrgencyStyle(kind);
        expect(
          contrastRatio(style.foreground, style.background),
          greaterThanOrEqualTo(kChipMinContrast),
          reason: '$kind',
        );
      }
    });

    test('« Clôture proche » : texte FONCÉ sur ambre', () {
      final style = scholarshipUrgencyStyle(ScholarshipUrgencyKind.closingSoon);
      expect(style.background, KpbColors.gold);
      expect(
        style.foreground.computeLuminance(),
        lessThan(style.background.computeLuminance()),
      );
    });

    test('aucune icône de validation', () {
      final validation = <IconData>{
        Icons.check,
        Icons.check_rounded,
        Icons.check_circle,
        Icons.check_circle_rounded,
        Icons.check_circle_outline,
        Icons.check_circle_outline_rounded,
        Icons.verified,
        Icons.verified_outlined,
        Icons.task_alt,
        Icons.task_alt_rounded,
      };
      for (final kind in ScholarshipUrgencyKind.values) {
        expect(validation, isNot(contains(scholarshipUrgencyStyle(kind).icon)));
      }
    });
  });
}
