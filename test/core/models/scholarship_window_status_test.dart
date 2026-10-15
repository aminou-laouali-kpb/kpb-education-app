// La fenêtre de candidature d'une bourse du catalogue (`windowStatus`).
//
// Ces cas vivaient dans le test de l'ancien questionnaire « Suis-je
// éligible ? » (ScholarshipEligibilityScreen, supprimé au chantier H3 : le
// bloc d'évaluation « Mes 10 bourses » de la fiche le remplace). Ils testent
// le modèle, pas l'écran : ils restent.

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';

ScholarshipModel _scholarship({DateTime? deadlineAt}) => ScholarshipModel(
      id: 's',
      name: LocalizedText(fr: '', en: ''),
      countryId: 'uk',
      levelEligible: LocalizedText(fr: '', en: ''),
      typeOfFunding: LocalizedText(fr: '', en: ''),
      deadlineLabel: LocalizedText(fr: '', en: ''),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 0,
      deadlineAt: deadlineAt,
    );

void main() {
  group('ScholarshipModel.windowStatus', () {
    final now = DateTime(2026, 6, 20);

    test('deadline well in the future → open', () {
      expect(
        _scholarship(deadlineAt: DateTime(2026, 12, 1)).windowStatus(now: now),
        ScholarshipWindowStatus.open,
      );
    });

    test('deadline within the soon window → closingSoon', () {
      expect(
        _scholarship(deadlineAt: DateTime(2026, 7, 1)).windowStatus(now: now),
        ScholarshipWindowStatus.closingSoon,
      );
    });

    test('deadline in the past → closed', () {
      expect(
        _scholarship(deadlineAt: DateTime(2026, 6, 1)).windowStatus(now: now),
        ScholarshipWindowStatus.closed,
      );
    });

    test('no deadline → open (rolling)', () {
      expect(
        _scholarship().windowStatus(now: now),
        ScholarshipWindowStatus.open,
      );
    });
  });
}
