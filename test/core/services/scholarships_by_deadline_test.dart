// Chantier H2 — l'ordre des bourses de l'accueil est NEUTRE et vérifiable.
//
// Il remplace `_matchScholarship`, une formule client qui partait du
// `baseMatch` éditorial (78 pour certaines fiches), ajoutait des points pour le
// pays visé, le domaine, la tranche de notes et l'envie de bourse, puis
// affichait « Très bon match » dès 70 — sans lire une seule condition
// d'éligibilité. Ces tests fixent ce qui le remplace :
//
//   · le `baseMatch` ne pèse plus RIEN sur l'ordre ;
//   · clôture confirmée la plus proche d'abord, puis estimée, puis sans date ;
//   · une clôture confirmée passée (copie hors ligne périmée) disparaît ;
//   · filtre de niveau seulement quand les DEUX niveaux sont connus — un
//     libellé sans niveau reconnu n'exclut jamais.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/app_search_service.dart';
import 'package:karatou/app/core/utils/study_level.dart';

final _now = DateTime.utc(2026, 10, 15, 12);

ScholarshipModel _scholarship(
  String id, {
  String level = '',
  DateTime? deadlineAt,
  bool estimated = false,
  int baseMatch = 0,
  String? name,
}) {
  return ScholarshipModel(
    id: id,
    name: LocalizedText(fr: name ?? id, en: name ?? id),
    countryId: 'france',
    levelEligible: LocalizedText(fr: level, en: level),
    typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
    deadlineLabel: const LocalizedText(fr: '', en: ''),
    keyRequirements: const [],
    relatedFieldIds: const [],
    baseMatch: baseMatch,
    deadlineAt: deadlineAt,
    deadlineIsEstimated: estimated,
  );
}

UserProfile _profile({String? targetLevel}) => UserProfile(
      id: 'u1',
      accountType: AccountType.student,
      fullName: 'Awa Diallo',
      email: 'awa@example.com',
      phone: '',
      whatsApp: '',
      countryOfResidence: 'Niger',
      preferredLanguage: 'fr',
      targetLevel: targetLevel,
      // Tout ce que l'ancienne formule récompensait : pays visé, domaine, bonne
      // tranche de notes, envie de bourse. Plus rien de cela ne doit compter.
      fieldIds: const ['d01'],
      targetCountryIds: const ['france'],
      gradeRange: '16-17',
      wantsScholarshipSupport: true,
    );

List<String> _order(
  List<ScholarshipModel> scholarships, {
  UserProfile? profile,
}) {
  final service = AppSearchService(
    AppSearchContext(
      localeCode: 'fr',
      fields: const [],
      countries: const [],
      institutions: const [],
      programs: const [],
      scholarships: scholarships,
      profile: profile,
      latestOrientationSession: null,
    ),
    clock: () => _now,
  );
  return service.scholarshipsByDeadline.map((s) => s.id).toList();
}

void main() {
  group('scholarshipsByDeadline — ordre neutre', () {
    test(
        'le baseMatch ne change plus rien : la clôture la plus proche passe '
        'devant une fiche « 78 »', () {
      final ids = _order([
        _scholarship('flagship',
            baseMatch: 78, deadlineAt: _now.add(const Duration(days: 90))),
        _scholarship('soon',
            baseMatch: 0, deadlineAt: _now.add(const Duration(days: 10))),
      ], profile: _profile());
      expect(ids, ['soon', 'flagship']);
    });

    test('confirmée, puis estimée, puis sans date ; alphabétique à égalité',
        () {
      final ids = _order([
        _scholarship('no-date-b', name: 'Bourse B'),
        _scholarship('estimated',
            deadlineAt: _now.add(const Duration(days: 5)), estimated: true),
        _scholarship('confirmed-late',
            deadlineAt: _now.add(const Duration(days: 60))),
        _scholarship('no-date-a', name: 'Bourse A'),
        _scholarship('confirmed-soon',
            deadlineAt: _now.add(const Duration(days: 20))),
      ]);
      expect(ids, [
        'confirmed-soon',
        'confirmed-late',
        // Une date ESTIMÉE, même plus proche, ne passe pas devant une date
        // confirmée : on ne trie pas sur une projection comme sur un jalon.
        'estimated',
        'no-date-a',
        'no-date-b',
      ]);
    });

    test(
        'une clôture confirmée passée n\'est pas proposée ; une estimée '
        'passée non plus n\'est pas « clôturée » (date non confirmée)', () {
      final ids = _order([
        _scholarship('closed',
            deadlineAt: _now.subtract(const Duration(days: 1))),
        _scholarship('estimated-past',
            deadlineAt: _now.subtract(const Duration(days: 1)),
            estimated: true),
      ]);
      expect(ids, ['estimated-past']);
    });

    test('filtre de niveau quand les deux niveaux sont connus', () {
      final ids = _order([
        _scholarship('licence-only', level: 'Licence'),
        _scholarship('master', level: 'Master, Doctorat'),
        _scholarship('unknown', level: 'Tous les cycles'),
        _scholarship('empty'),
      ], profile: _profile(targetLevel: 'Master'));
      expect(ids, containsAll(<String>['master', 'unknown', 'empty']));
      expect(ids, isNot(contains('licence-only')));
    });

    test('sans niveau visé (ou sans profil), aucun filtre', () {
      final catalog = [
        _scholarship('licence-only', level: 'Licence'),
        _scholarship('master', level: 'Master'),
      ];
      expect(_order(catalog, profile: _profile()), hasLength(2));
      expect(_order(catalog), hasLength(2));
    });

    test(
        '« PhD » du profil lit le doctorat ; « Mastercard » n\'est pas un '
        'master', () {
      final ids = _order([
        _scholarship('phd', level: 'Doctorat (PhD)'),
        _scholarship('mastercard', level: 'Mastercard Foundation — Licence'),
      ], profile: _profile(targetLevel: 'PhD'));
      expect(ids, ['phd']);
    });
  });

  group('scholarshipStudyLevelsInText — miroir du serveur', () {
    test('libellés FR et EN', () {
      expect(scholarshipStudyLevelsInText('Licence, Master'), {
        ScholarshipStudyLevel.bachelor,
        ScholarshipStudyLevel.master,
      });
      expect(scholarshipStudyLevelsInText('Undergraduate'),
          {ScholarshipStudyLevel.bachelor});
      expect(scholarshipStudyLevelsInText('Lycée'),
          {ScholarshipStudyLevel.secondary});
      expect(scholarshipStudyLevelsInText('PhD'),
          {ScholarshipStudyLevel.doctorate});
    });

    test('pièges : négation, post-, sous-chaîne', () {
      expect(scholarshipStudyLevelsInText('Master (pas de doctorat)'),
          {ScholarshipStudyLevel.master});
      expect(scholarshipStudyLevelsInText('Post-doctorat'), isEmpty);
      expect(scholarshipStudyLevelsInText('Post-secondaire'), isEmpty);
      expect(scholarshipStudyLevelsInText('Mastercard'), isEmpty);
      expect(scholarshipStudyLevelsInText(null), isEmpty);
      expect(scholarshipStudyLevelsInText('   '), isEmpty);
    });
  });
}
