// Revue du build 49, point 9 : « au niveau de la date, on met "À venir,
// généralement aux mois de … - …" ».
//
// Trois défauts vivants ont été corrigés en même temps que l'ajout de cette
// formulation, et ils sont tenus ici :
//
//   1. `windowStatus` rendait « Bientôt clôturé » / « Clôturé » sur une date
//      ESTIMÉE — une affirmation au jour près sur une projection. « Clôturé »
//      aurait fait renoncer un étudiant à une bourse encore ouverte.
//   2. `toJson` perdait `dateConfidence` : toute copie passée par le cache
//      hors-ligne revenait « confirmée », et le compte à rebours réapparaissait.
//   3. La fiche détail affichait la date estimée en « Date limite » jj/mm/aaaa
//      alors que la carte de liste se taisait — deux écrans, deux vérités.

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/features/scholarships/widgets/scholarship_status_line.dart';

void main() {
  ScholarshipModel build({
    required DateTime? deadlineAt,
    required bool estimated,
  }) {
    return ScholarshipModel(
      id: 's1',
      name: const LocalizedText(fr: 'Bourse', en: 'Scholarship'),
      countryId: 'fra',
      levelEligible: const LocalizedText(fr: 'Licence', en: 'Bachelor'),
      typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: const LocalizedText(
        fr: 'À venir, généralement aux mois de mars – avril',
        en: 'Upcoming, usually in March – April',
      ),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 30,
      deadlineAt: deadlineAt,
      deadlineIsEstimated: estimated,
    );
  }

  group('windowStatus ne juge jamais une date estimée', () {
    final soon = DateTime.now().add(const Duration(days: 3));
    final past = DateTime.now().subtract(const Duration(days: 10));

    test('une échéance proche mais ESTIMÉE reste « ouvert »', () {
      expect(
        build(deadlineAt: soon, estimated: true).windowStatus(),
        ScholarshipWindowStatus.open,
        reason: '« Bientôt clôturé » sur une projection est une affirmation '
            'que personne n\'a publiée',
      );
    });

    test('une date passée mais ESTIMÉE ne dit pas « clôturé »', () {
      expect(
        build(deadlineAt: past, estimated: true).windowStatus(),
        ScholarshipWindowStatus.open,
        reason: '« Clôturé » à tort fait renoncer à une bourse encore ouverte',
      );
    });

    test('contre-garde : une date CONFIRMÉE est toujours jugée', () {
      // Sans ce test, un correctif qui rendrait « ouvert » pour TOUT le monde
      // passerait pour une réussite.
      expect(
        build(deadlineAt: soon, estimated: false).windowStatus(),
        ScholarshipWindowStatus.closingSoon,
      );
      expect(
        build(deadlineAt: past, estimated: false).windowStatus(),
        ScholarshipWindowStatus.closed,
      );
    });
  });

  // ── Revue automatique de la PR #252 (P2) ────────────────────────────────
  //
  // Les bornes du catalogue sont des dates SANS heure écrites en UTC
  // (`2027-03-01T00:00:00.000Z` → `2027-04-30T23:59:59.000Z`). Converties en
  // heure locale, elles changent de jour calendaire pour presque tout le
  // monde — et à la frontière d'un mois, de MOIS : le 1er mars 00 h UTC devient
  // le 28 février à l'ouest d'UTC.
  //
  // Chantier I : la carte dit désormais « Ouverture estimée mars 2027 » — une
  // date estimée ne se dit plus qu'au mois près, quelle que soit la fenêtre
  // saisie (l'ancien prédicat « fenêtre de mois entiers » n'a plus d'objet).
  // Ce qui reste à garantir, c'est que ce mois se lit en UTC.
  group('le mois d\'une date estimée se lit en UTC, pas en heure locale', () {
    test('1er mars 00 h UTC reste mars, exprimé en local ou non', () {
      final open = DateTime.utc(2027, 3, 1);
      expect(formatScholarshipMonth(open), '03/2027');
      expect(formatScholarshipMonth(open.toLocal()), '03/2027');
    });

    test('30 avril 23 h 59 UTC reste avril, même à l\'est d\'UTC', () {
      final close = DateTime.utc(2027, 4, 30, 23, 59, 59);
      expect(formatScholarshipMonth(close), '04/2027');
      expect(formatScholarshipMonth(close.toLocal()), '04/2027');
    });
  });

  group('l\'aller-retour JSON conserve la confiance de la date', () {
    test('estimée reste estimée après toJson/fromJson', () {
      final original = build(
        deadlineAt: DateTime.utc(2027, 4, 30),
        estimated: true,
      );
      final restored = ScholarshipModel.fromJson(original.toJson());
      expect(
        restored.deadlineIsEstimated,
        isTrue,
        reason: 'la clé `dateConfidence` manquait dans toJson : une fiche '
            'restaurée du cache redevenait « confirmée » et retrouvait son '
            'compte à rebours',
      );
      expect(restored.windowStatus(), ScholarshipWindowStatus.open);
    });

    test('confirmée reste confirmée', () {
      final original = build(
        deadlineAt: DateTime.utc(2027, 4, 30),
        estimated: false,
      );
      expect(
        ScholarshipModel.fromJson(original.toJson()).deadlineIsEstimated,
        isFalse,
      );
    });
  });
}
