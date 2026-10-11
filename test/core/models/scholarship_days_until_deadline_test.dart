// Le compte à rebours des bourses ne lit plus le libellé texte : il part de
// `deadlineAt`, ignore une date estimée, et compte en jours calendaires.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';

ScholarshipModel _scholarship({DateTime? deadlineAt, bool estimated = false}) {
  return ScholarshipModel.fromJson(<String, dynamic>{
    'id': 's1',
    'nameFr': 'Bourse',
    'nameEn': 'Scholarship',
    'countryId': 'fra',
    'deadlineLabelFr': 'Mai 2026',
    'deadlineLabelEn': 'May 2026',
    if (deadlineAt != null) 'deadlineAt': deadlineAt.toIso8601String(),
    'dateConfidence': estimated ? 'estimated' : 'confirmed',
  });
}

void main() {
  final now = DateTime(2026, 10, 10, 20);

  test('counts calendar days to a confirmed deadline (0 on the day itself)',
      () {
    expect(
      _scholarship(deadlineAt: DateTime(2026, 10, 12, 23, 59))
          .daysUntilDeadline(now: now),
      2,
    );
    expect(
      _scholarship(deadlineAt: DateTime(2026, 10, 10, 23, 59))
          .daysUntilDeadline(now: now),
      0,
    );
  });

  test('null when past, missing or estimated', () {
    expect(
      _scholarship(deadlineAt: DateTime(2026, 10, 9))
          .daysUntilDeadline(now: now),
      isNull,
    );
    expect(_scholarship().daysUntilDeadline(now: now), isNull);
    expect(
      _scholarship(deadlineAt: DateTime(2026, 10, 20), estimated: true)
          .daysUntilDeadline(now: now),
      isNull,
    );
  });
}
