// Chantier K — l'ordre de priorité de la carte « Ta prochaine étape » et le
// contenu de « Tes échéances » (logique pure, home_next_step.dart).

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/features/home/home_next_step.dart';
import 'package:karatou/app/features/scholarships/scholarship_urgency.dart';

final _now = DateTime(2026, 10, 15, 10);

StudentCase _case(String id, CaseStatus status) => StudentCase(
      id: id,
      referenceCode: 'KPB-$id',
      title: LocalizedText(fr: 'Dossier $id', en: 'Case $id'),
      description: const LocalizedText(fr: '', en: ''),
      contextLabel: const LocalizedText(fr: '', en: ''),
      status: status,
      type: CaseType.applicationSupport,
      preferredContactMethod: ContactMethod.inApp,
      createdAt: _now,
      updatedAt: _now,
      nextStepTitle: const LocalizedText(fr: 'Envoie ton relevé', en: 'Send'),
      nextStepDescription: const LocalizedText(fr: '', en: ''),
      timeline: const [],
      messages: const [],
      documentRequests: const [],
    );

ScholarshipModel _scholarship(
  String id, {
  int? inDays,
  bool estimated = false,
}) =>
    ScholarshipModel(
      id: id,
      name: LocalizedText(fr: 'Bourse $id', en: 'Scholarship $id'),
      countryId: 'france',
      levelEligible: const LocalizedText(fr: '', en: ''),
      typeOfFunding: const LocalizedText(fr: '', en: ''),
      deadlineLabel: const LocalizedText(fr: '', en: ''),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 0,
      deadlineAt: inDays == null ? null : _now.add(Duration(days: inDays)),
      deadlineIsEstimated: estimated,
    );

HomeNextStep _resolve({
  List<StudentCase> cases = const [],
  List<ScholarshipModel> followed = const [],
  bool profileIncomplete = false,
  bool testOpen = false,
  bool oriented = true,
}) =>
    resolveHomeNextStep(
      activeCases: homeActiveCases(cases),
      followedScholarships: followed,
      needsProfileCompletion: profileIncomplete,
      scholarshipTestAvailable: testOpen,
      hasOrientationResult: oriented,
      now: _now,
    );

void main() {
  group('ordre de priorité de « Ta prochaine étape »', () {
    test('1. un dossier qui attend l\'élève passe avant tout', () {
      final step = _resolve(
        cases: [
          _case('a', CaseStatus.inProgress),
          _case('b', CaseStatus.documentsNeeded),
        ],
        followed: [_scholarship('soon', inDays: 3)],
        profileIncomplete: true,
        testOpen: true,
        oriented: false,
      );
      expect(step.kind, HomeNextStepKind.caseAction);
      expect(step.studentCase!.id, 'b');
    });

    test('un dossier terminé, annulé ou refusé n\'est pas une étape', () {
      final step = _resolve(cases: [
        _case('done', CaseStatus.completed),
        _case('x', CaseStatus.cancelled),
        _case('no', CaseStatus.rejected),
      ]);
      expect(step.kind, HomeNextStepKind.startCase);
    });

    test('2. puis la bourse SUIVIE qui clôture bientôt (la plus proche)', () {
      final step = _resolve(
        cases: [_case('a', CaseStatus.inProgress)],
        followed: [
          _scholarship('later', inDays: 10),
          _scholarship('sooner', inDays: 2),
          _scholarship('far', inDays: 60),
        ],
        profileIncomplete: true,
        testOpen: true,
      );
      expect(step.kind, HomeNextStepKind.followedClosingSoon);
      expect(step.urgent!.scholarship.id, 'sooner');
      expect(step.urgent!.urgency.daysLeft, 2);
    });

    test('jamais sur une date ESTIMÉE, ni au-delà de 14 jours, ni passée', () {
      final step = _resolve(
        followed: [
          _scholarship('estimated', inDays: 3, estimated: true),
          _scholarship('far', inDays: kScholarshipClosingSoonDays + 1),
          _scholarship('past', inDays: -1),
          _scholarship('rolling'),
        ],
        oriented: false,
      );
      expect(step.kind, HomeNextStepKind.orientation);
    });

    test('3. profil incomplet, test ouvert : compléter via le test', () {
      expect(
        _resolve(profileIncomplete: true, testOpen: true, oriented: false).kind,
        HomeNextStepKind.completeProfileTest,
      );
    });

    test('3. profil incomplet, test fermé : l\'onboarding (comme avant)', () {
      expect(
        _resolve(profileIncomplete: true, oriented: false).kind,
        HomeNextStepKind.completeProfileOnboarding,
      );
    });

    test('4. orientation, 5. premier dossier, 6. explorer', () {
      expect(_resolve(oriented: false).kind, HomeNextStepKind.orientation);
      expect(_resolve().kind, HomeNextStepKind.startCase);
      expect(
        _resolve(cases: [_case('a', CaseStatus.inProgress)]).kind,
        HomeNextStepKind.explore,
      );
    });
  });

  group('« Tes échéances »', () {
    test('la bourse suivie d\'abord, puis la plus proche du catalogue', () {
      final catalog = [
        _scholarship('nearest', inDays: 1),
        _scholarship('followed', inDays: 9),
        _scholarship('far', inDays: 40),
      ];
      final followed = resolveHomeDeadlines(
        activeCases: const [],
        catalog: catalog,
        isFollowing: (id) => id == 'followed',
        now: _now,
      );
      expect(followed.urgent!.scholarship.id, 'followed');

      final none = resolveHomeDeadlines(
        activeCases: const [],
        catalog: catalog,
        isFollowing: (_) => false,
        now: _now,
      );
      expect(none.urgent!.scholarship.id, 'nearest');
    });

    test('ce que la prochaine étape montre n\'est pas répété', () {
      final cases = homeActiveCases([
        _case('wait', CaseStatus.awaitingStudent),
        _case('b', CaseStatus.inProgress),
        _case('c', CaseStatus.submitted),
        _case('d', CaseStatus.scheduled),
      ]);
      final step = resolveHomeNextStep(
        activeCases: cases,
        followedScholarships: const [],
        needsProfileCompletion: false,
        scholarshipTestAvailable: false,
        hasOrientationResult: true,
        now: _now,
      );
      final deadlines = resolveHomeDeadlines(
        activeCases: cases,
        catalog: [_scholarship('only', inDays: 4)],
        isFollowing: (_) => true,
        nextStep: const HomeNextStep(HomeNextStepKind.explore),
        now: _now,
      );
      expect(deadlines.urgent!.scholarship.id, 'only');

      final withoutDup = resolveHomeDeadlines(
        activeCases: cases,
        catalog: const [],
        isFollowing: (_) => true,
        nextStep: step,
        now: _now,
      );
      expect(withoutDup.cases.map((c) => c.id), ['b', 'c'],
          reason: 'deux dossiers au plus, sans celui de la prochaine étape');

      final scholarshipStep = resolveHomeNextStep(
        activeCases: const [],
        followedScholarships: [_scholarship('only', inDays: 4)],
        needsProfileCompletion: false,
        scholarshipTestAvailable: false,
        hasOrientationResult: true,
        now: _now,
      );
      expect(
        resolveHomeDeadlines(
          activeCases: const [],
          catalog: [_scholarship('only', inDays: 4)],
          isFollowing: (_) => true,
          nextStep: scholarshipStep,
          now: _now,
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('urgence du catalogue = le calcul unique de scholarship_urgency', () {
    test('confirmée proche, confirmée lointaine, estimée, passée, sans date',
        () {
      expect(
        scholarshipUrgencyOfCatalog(_scholarship('a', inDays: 5), now: _now)
            .kind,
        ScholarshipUrgencyKind.closingSoon,
      );
      expect(
        scholarshipUrgencyOfCatalog(_scholarship('b', inDays: 40), now: _now)
            .kind,
        ScholarshipUrgencyKind.open,
      );
      expect(
        scholarshipUrgencyOfCatalog(
          _scholarship('c', inDays: 5, estimated: true),
          now: _now,
        ).isClosingSoon,
        isFalse,
      );
      expect(
        scholarshipUrgencyOfCatalog(_scholarship('d', inDays: -2), now: _now)
            .kind,
        ScholarshipUrgencyKind.closed,
      );
      expect(
        scholarshipUrgencyOfCatalog(_scholarship('e'), now: _now).kind,
        ScholarshipUrgencyKind.dateToConfirm,
      );
    });
  });
}
