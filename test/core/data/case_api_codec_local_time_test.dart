// Les dates d'un dossier se lisent à l'heure du téléphone (audit build 57,
// T4-19). Le serveur les rend en UTC (« …Z ») ; le codec les gardait en UTC et
// l'écran affichait « 09:30 » pour un message de 10 h 30 au Niger, au Cameroun
// ou au Bénin (UTC+1). Un test qui compare deux heures dépendrait du fuseau de
// la machine : celui-ci vérifie la CAUSE (une date lue n'est plus UTC), vraie
// dans n'importe quel fuseau, et que l'instant est conservé.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/data/case_api_codec.dart';

void main() {
  test('createdAt, updatedAt, scheduledAt, jalons et messages : heure locale',
      () {
    const stamp = '2026-10-20T09:30:00.000Z';
    final instant = DateTime.parse(stamp);
    final parsed = CaseApiCodec.studentCaseFromApi(<String, dynamic>{
      'id': 'c1',
      'referenceCode': 'KPB-2026-1134',
      'createdAt': stamp,
      'updatedAt': stamp,
      'scheduledAt': stamp,
      'timeline': [
        {'id': 't1', 'title': 'x', 'description': 'y', 'createdAt': stamp},
      ],
      'messages': [
        {
          'id': 'm1',
          'senderName': 'Jojo',
          'senderRole': 'counsellor',
          'body': 'Bonjour',
          'createdAt': stamp,
        },
      ],
    });

    final dates = <String, DateTime?>{
      'createdAt': parsed.createdAt,
      'updatedAt': parsed.updatedAt,
      'scheduledAt': parsed.scheduledAt,
      'timeline': parsed.timeline.single.createdAt,
      'message': parsed.messages.single.createdAt,
    };
    expect(dates.values.every((d) => d != null), isTrue);
    dates.forEach((name, value) {
      expect(value!.isUtc, isFalse, reason: '$name est resté en UTC');
      // Même instant, seule l'écriture change.
      expect(value.isAtSameMomentAs(instant), isTrue, reason: name);
    });
  });
}
