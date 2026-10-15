// ─────────────────────────────────────────────────────────────────────────────
// Accueil « Ta prochaine étape » (chantier K) — la logique, sans widget.
//
// L'accueil d'un élève porte UNE action : la plus utile selon son état réel.
// Elle fusionne trois surfaces qui se disputaient la première place (l'anneau
// du héros, « Mon plan » et « Parcours découverte ») et qui proposaient
// parfois trois actions différentes au même moment.
//
// ## Ordre de priorité (le premier qui s'applique gagne)
//
//   1. [HomeNextStepKind.caseAction] — un dossier actif ATTEND l'élève
//      (documents demandés, réponse attendue, paiement) : quelqu'un attend
//      de l'autre côté, rien n'est plus utile ;
//   2. [HomeNextStepKind.followedClosingSoon] — une bourse SUIVIE clôture
//      bientôt (clôture CONFIRMÉE dans 14 jours ou moins, calcul unique de
//      `scholarship_urgency.dart`) : la plus proche. Jamais sur une date
//      estimée ;
//   3. profil incomplet (`needsProfileCompletionBanner`) :
//      [HomeNextStepKind.completeProfileTest] quand le test « Mes 10
//      bourses » est ouvert à cet élève (drapeau `scholarshipMatch`) — le
//      test remplit le profil ET montre ses bourses ; sinon
//      [HomeNextStepKind.completeProfileOnboarding] (comportement d'avant) ;
//   4. [HomeNextStepKind.orientation] — pas encore de test d'orientation ;
//   5. [HomeNextStepKind.startCase] — aucun dossier actif ;
//   6. [HomeNextStepKind.explore] — tout est en route : explorer.
//
// Pur et synchrone : testé directement (test/features/home/).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../scholarships/scholarship_urgency.dart';

enum HomeNextStepKind {
  caseAction,
  followedClosingSoon,
  completeProfileTest,
  completeProfileOnboarding,
  orientation,
  startCase,
  explore,
}

/// Une bourse du catalogue et son urgence (calcul unique).
@immutable
class HomeUrgentScholarship {
  const HomeUrgentScholarship(this.scholarship, this.urgency);

  final ScholarshipModel scholarship;
  final ScholarshipUrgency urgency;
}

@immutable
class HomeNextStep {
  const HomeNextStep(this.kind, {this.studentCase, this.urgent});

  final HomeNextStepKind kind;

  /// Le dossier visé ([HomeNextStepKind.caseAction]).
  final StudentCase? studentCase;

  /// La bourse visée ([HomeNextStepKind.followedClosingSoon]).
  final HomeUrgentScholarship? urgent;

  @override
  String toString() => 'HomeNextStep($kind)';
}

/// Statuts où le dossier attend une action de l'ÉLÈVE.
const Set<CaseStatus> kHomeCaseAwaitingStudent = <CaseStatus>{
  CaseStatus.documentsNeeded,
  CaseStatus.awaitingStudent,
  CaseStatus.awaitingPayment,
};

/// Les dossiers actifs (ni terminés, ni annulés, ni refusés), dans l'ordre.
List<StudentCase> homeActiveCases(Iterable<StudentCase> cases) => cases
    .where((c) =>
        c.status != CaseStatus.completed &&
        c.status != CaseStatus.cancelled &&
        c.status != CaseStatus.rejected)
    .toList(growable: false);

/// Les bourses dont la clôture CONFIRMÉE est proche, la plus proche d'abord
/// (à égalité, l'ordre reçu). Calcul unique : [scholarshipUrgencyOfCatalog].
List<HomeUrgentScholarship> homeClosingSoon(
  Iterable<ScholarshipModel> scholarships, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final out = <HomeUrgentScholarship>[];
  for (final s in scholarships) {
    final urgency = scholarshipUrgencyOfCatalog(s, now: ref);
    if (urgency.isClosingSoon) out.add(HomeUrgentScholarship(s, urgency));
  }
  // Tri stable : List.sort ne l'est pas, on départage par la position.
  final indexed = out.asMap().entries.toList()
    ..sort((a, b) {
      final byDays = (a.value.urgency.daysLeft ?? 0)
          .compareTo(b.value.urgency.daysLeft ?? 0);
      return byDays != 0 ? byDays : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// LA prochaine étape de l'élève (voir l'ordre en tête de fichier).
HomeNextStep resolveHomeNextStep({
  required List<StudentCase> activeCases,
  required Iterable<ScholarshipModel> followedScholarships,
  required bool needsProfileCompletion,
  required bool scholarshipTestAvailable,
  required bool hasOrientationResult,
  DateTime? now,
}) {
  for (final c in activeCases) {
    if (kHomeCaseAwaitingStudent.contains(c.status)) {
      return HomeNextStep(HomeNextStepKind.caseAction, studentCase: c);
    }
  }
  final closing = homeClosingSoon(followedScholarships, now: now);
  if (closing.isNotEmpty) {
    return HomeNextStep(
      HomeNextStepKind.followedClosingSoon,
      urgent: closing.first,
    );
  }
  if (needsProfileCompletion) {
    return HomeNextStep(
      scholarshipTestAvailable
          ? HomeNextStepKind.completeProfileTest
          : HomeNextStepKind.completeProfileOnboarding,
    );
  }
  if (!hasOrientationResult) {
    return const HomeNextStep(HomeNextStepKind.orientation);
  }
  if (activeCases.isEmpty) {
    return const HomeNextStep(HomeNextStepKind.startCase);
  }
  return const HomeNextStep(HomeNextStepKind.explore);
}

/// Le contenu de « Tes échéances » : la date urgente (une bourse dont la
/// clôture confirmée est proche — suivie d'abord, sinon la plus proche du
/// catalogue) et les dossiers actifs (2 au plus). Ce que la carte « prochaine
/// étape » montre déjà n'y figure pas une seconde fois.
@immutable
class HomeDeadlines {
  const HomeDeadlines({this.urgent, this.cases = const <StudentCase>[]});

  final HomeUrgentScholarship? urgent;
  final List<StudentCase> cases;

  bool get isEmpty => urgent == null && cases.isEmpty;
}

HomeDeadlines resolveHomeDeadlines({
  required List<StudentCase> activeCases,
  required Iterable<ScholarshipModel> catalog,
  required bool Function(String scholarshipId) isFollowing,
  HomeNextStep? nextStep,
  DateTime? now,
  int maxCases = 2,
}) {
  final skipScholarship = nextStep?.urgent?.scholarship.id;
  final skipCase = nextStep?.studentCase?.id;
  final closing = homeClosingSoon(catalog, now: now)
      .where((u) => u.scholarship.id != skipScholarship)
      .toList(growable: false);
  HomeUrgentScholarship? urgent;
  for (final u in closing) {
    if (isFollowing(u.scholarship.id)) {
      urgent = u;
      break;
    }
  }
  urgent ??= closing.isEmpty ? null : closing.first;
  final cases = activeCases
      .where((c) => c.id != skipCase)
      .take(maxCases)
      .toList(growable: false);
  return HomeDeadlines(urgent: urgent, cases: cases);
}
