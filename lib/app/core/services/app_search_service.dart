import 'dart:math';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../models/app_models.dart';
import '../utils/study_level.dart';

/// Snapshot of catalog + profile state needed for search and match scoring.
class AppSearchContext {
  const AppSearchContext({
    required this.localeCode,
    required this.fields,
    required this.countries,
    required this.institutions,
    required this.programs,
    required this.scholarships,
    required this.profile,
    required this.latestOrientationSession,
  });

  final String localeCode;
  final List<FieldModel> fields;
  final List<CountryModel> countries;
  final List<InstitutionModel> institutions;
  final List<ProgramModel> programs;
  final List<ScholarshipModel> scholarships;
  final UserProfile? profile;
  final OrientationSession? latestOrientationSession;
}

/// Search across catalog entities and profile-aware match scoring.
class AppSearchService {
  AppSearchService(this._ctx, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppSearchContext _ctx;

  /// Horloge injectable : seul [scholarshipsByDeadline] la lit.
  final DateTime Function() _clock;

  String _resolve(LocalizedText text) => text.resolve(_ctx.localeCode);

  FieldModel? _fieldByIdOrNull(String id) =>
      _ctx.fields.firstWhereOrNull((item) => item.id == id);

  InstitutionModel? _institutionByIdOrNull(String id) =>
      _ctx.institutions.firstWhereOrNull((item) => item.id == id);

  ProgramModel? _programByIdOrNull(String id) =>
      _ctx.programs.firstWhereOrNull((item) => item.id == id);

  List<SearchResult> run(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <SearchResult>[];

    for (final f in _ctx.fields) {
      if (_matchesField(f, q)) {
        results.add(SearchResult(
          type: SearchResultType.field,
          id: f.id,
          title: _resolve(f.name),
          subtitle: _resolve(f.description),
        ));
      }
    }
    for (final c in _ctx.countries) {
      if (_matchesLocalized(c.name, q)) {
        results.add(SearchResult(
          type: SearchResultType.country,
          id: c.id,
          title: _resolve(c.name),
          subtitle: _resolve(c.tuitionRange),
        ));
      }
    }
    for (final i in _ctx.institutions) {
      if (_matchesLocalized(i.name, q) || _matchesLocalized(i.location, q)) {
        results.add(SearchResult(
          type: SearchResultType.institution,
          id: i.id,
          title: _resolve(i.name),
          subtitle: _resolve(i.location),
        ));
      }
    }
    for (final p in _ctx.programs) {
      if (_matchesLocalized(p.name, q) || _matchesLocalized(p.level, q)) {
        results.add(SearchResult(
          type: SearchResultType.program,
          id: p.id,
          title: _resolve(p.name),
          subtitle: _resolve(p.level),
        ));
      }
    }
    for (final s in _ctx.scholarships) {
      if (_matchesLocalized(s.name, q)) {
        results.add(SearchResult(
          type: SearchResultType.scholarship,
          id: s.id,
          title: _resolve(s.name),
          subtitle: _resolve(s.typeOfFunding),
        ));
      }
    }
    return results;
  }

  bool _matchesLocalized(LocalizedText text, String q) =>
      text.fr.toLowerCase().contains(q) || text.en.toLowerCase().contains(q);

  bool _matchesField(FieldModel f, String q) {
    if (_matchesLocalized(f.name, q)) return true;
    if (_matchesLocalized(f.description, q)) return true;
    if (f.careers.any((c) => _matchesLocalized(c, q))) return true;
    if (f.subjects.any((s) => _matchesLocalized(s, q))) return true;
    return false;
  }

  int fieldMatch(FieldModel field) => _matchField(field);

  int _matchField(FieldModel field) {
    final p = _ctx.profile;
    if (p == null) return 40;
    var score = 30;
    if (p.fieldIds.contains(field.id)) score += 20;
    if (_ctx.latestOrientationSession != null) {
      final session = _ctx.latestOrientationSession!;
      final rec = session.recommendations
          .where((r) => r.fieldId == field.id)
          .firstOrNull;
      if (rec != null) score += min((rec.score ~/ 4), 25);
    }
    if (field.relatedCountryIds.any((id) => p.targetCountryIds.contains(id))) {
      score += 10;
    }
    if (p.wantsScholarshipSupport && field.relatedScholarshipIds.isNotEmpty) {
      score += 5;
    }
    return min(score, 98);
  }

  int programMatch(ProgramModel program) => _matchProgram(program);

  int _matchProgram(ProgramModel program) {
    final p = _ctx.profile;
    if (p == null) return 40;
    var score = 30;
    if (p.fieldIds.contains(program.fieldId)) score += 25;
    if (p.targetCountryIds.contains(program.countryId)) score += 20;
    if (p.targetLevel != null) {
      final programLevel = program.level.fr.toLowerCase();
      final targetLevel = p.targetLevel ?? '';
      if (programLevel.contains(targetLevel.toLowerCase()) ||
          targetLevel.toLowerCase().contains(programLevel)) {
        score += 15;
      }
    }
    if (_ctx.latestOrientationSession != null) {
      final orientationFieldIds = _ctx.latestOrientationSession!.recommendations
          .map((r) => r.fieldId)
          .toList();
      if (orientationFieldIds.contains(program.fieldId)) score += 10;
    }
    return min(score, 98);
  }

  int institutionMatch(InstitutionModel institution) =>
      _matchInstitution(institution);

  int _matchInstitution(InstitutionModel institution) {
    final p = _ctx.profile;
    if (p == null) return 40;
    var score = 0;
    if (p.targetCountryIds.contains(institution.countryId)) score += 25;

    final matchingPrograms = _ctx.programs
        .where((prog) =>
            institution.programIds.contains(prog.id) &&
            p.fieldIds.contains(prog.fieldId))
        .length;
    score += min(matchingPrograms * 10, 30);

    if (p.targetLevel != null &&
        institution.studyLevels.any(
            (l) => l.toLowerCase().contains(p.targetLevel!.toLowerCase()))) {
      score += 15;
    }

    final grade = p.gradeRange ?? '';
    if (grade.contains('15') || grade.contains('16') || grade.contains('17')) {
      score += 20;
    } else if (grade.contains('12') ||
        grade.contains('13') ||
        grade.contains('14')) {
      score += 10;
    }

    if (institution.isPartner) score += 15;

    return min(score, 98);
  }

  /// Memoized for the lifetime of this service (one controller state).
  late final List<FieldModel> recommendedFields = () {
    final sorted = _ctx.fields.map((f) => MapEntry(f, _matchField(f))).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(6).map((e) => e.key).toList();
  }();

  /// Memoized for the lifetime of this service (one controller state).
  late final List<ProgramModel> recommendedPrograms = () {
    final sorted = _ctx.programs
        .map((p) => MapEntry(p, _matchProgram(p)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }();

  /// Memoized for the lifetime of this service (one controller state).
  late final List<InstitutionModel> recommendedInstitutions = () {
    final sorted = _ctx.institutions
        .map((i) => MapEntry(i, _matchInstitution(i)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(6).map((e) => e.key).toList();
  }();

  List<String> matchExplanation(SearchResultType type, String id) {
    final p = _ctx.profile;
    if (p == null) {
      return ['match_complete_profile'.tr];
    }
    final reasons = <String>[];
    switch (type) {
      case SearchResultType.field:
        final f = _fieldByIdOrNull(id);
        if (f == null) break;
        if (p.fieldIds.contains(f.id)) {
          reasons.add('match_field_in_interests'.tr);
        }
        final session = _ctx.latestOrientationSession;
        if (session != null &&
            session.recommendations.any((r) => r.fieldId == f.id)) {
          reasons.add('match_from_orientation'.tr);
        }
        if (f.relatedCountryIds
            .any((cid) => p.targetCountryIds.contains(cid))) {
          reasons.add('match_available_target_country'.tr);
        }
      case SearchResultType.country:
        if (p.targetCountryIds.contains(id)) {
          reasons.add('match_target_country'.tr);
        }
      case SearchResultType.institution:
        final inst = _institutionByIdOrNull(id);
        if (inst == null) break;
        if (p.targetCountryIds.contains(inst.countryId)) {
          reasons.add('match_in_target_country'.tr);
        }
        if (inst.isPartner) reasons.add('match_kpb_partner'.tr);
      case SearchResultType.program:
        final prog = _programByIdOrNull(id);
        if (prog == null) break;
        if (p.fieldIds.contains(prog.fieldId)) {
          reasons.add('match_field_match'.tr);
        }
        if (p.targetCountryIds.contains(prog.countryId)) {
          reasons.add('match_target_country'.tr);
        }
      case SearchResultType.scholarship:
        // Aucune explication de « match » pour une bourse : le client ne
        // calcule plus de palier de compatibilité (voir
        // [scholarshipsByDeadline]). Les raisons d'éligibilité viennent du
        // serveur, avec le test « Mes 10 bourses ».
        break;
    }
    if (reasons.isEmpty) reasons.add('match_general'.tr);
    return reasons;
  }

  /// Les bourses de l'accueil, dans un ordre NEUTRE et vérifiable — aucun
  /// score, aucun palier de compatibilité.
  ///
  /// ## Pourquoi plus de score
  ///
  /// L'ancienne formule `_matchScholarship` partait du `baseMatch` éditorial
  /// (78 pour certaines fiches), ajoutait des points pour le pays visé, le
  /// domaine, la tranche de notes et l'envie de bourse, puis plafonnait à 98.
  /// Elle ne lisait AUCUNE condition d'éligibilité : une bourse réservée à une
  /// autre nationalité ou à un autre niveau sortait « Très bon match » sur
  /// l'accueil et dans la Recherche, parce que 78 franchit à lui seul le seuil
  /// de 70. C'est le serveur (« Mes 10 bourses ») qui vérifie les conditions
  /// publiées ; le client ne prétend plus le faire.
  ///
  /// ## L'ordre retenu, et ce qu'il affirme
  ///
  ///  1. une bourse dont la clôture CONFIRMÉE est passée (copie hors ligne
  ///     périmée) n'est pas proposée ;
  ///  2. filtre simple sur le niveau visé, SEULEMENT quand les deux niveaux
  ///     sont connus : une fiche dont le libellé ne cite aucun niveau reconnu
  ///     reste visible (« inconnu » n'est jamais une exclusion) ;
  ///  3. clôture confirmée d'abord, la plus proche en tête ; puis les clôtures
  ///     estimées, puis les fiches sans date ; à égalité, l'ordre alphabétique.
  ///
  /// Chaque critère se lit sur la fiche elle-même : l'ordre ne dit rien du
  /// profil au-delà du niveau visé, et l'écran ne doit pas dire le contraire.
  ///
  /// Un ÉLÈVE qui a un run « Mes 10 bourses » voit à l'accueil les cartes de
  /// ce run (`_HomeScholarshipsSection`) ; cette liste reste la source des
  /// parents, des invités, de tous tant que le test est fermé, et TOUJOURS de
  /// la carte « Deadline urgente ».
  ///
  /// Memoized for the lifetime of this service (one controller state).
  late final List<ScholarshipModel> scholarshipsByDeadline =
      _computeScholarshipsByDeadline();

  List<ScholarshipModel> _computeScholarshipsByDeadline() {
    final now = _clock();
    final targetLevels =
        scholarshipStudyLevelsInText(_ctx.profile?.targetLevel);

    bool levelAllows(ScholarshipModel scholarship) {
      if (targetLevels.isEmpty) return true;
      final offered = {
        ...scholarshipStudyLevelsInText(scholarship.levelEligible.fr),
        ...scholarshipStudyLevelsInText(scholarship.levelEligible.en),
      };
      return offered.isEmpty || offered.any(targetLevels.contains);
    }

    // 0 = clôture confirmée à venir, 1 = clôture estimée, 2 = sans date.
    int bucket(ScholarshipModel scholarship) {
      if (scholarship.deadlineAt == null) return 2;
      return scholarship.deadlineIsEstimated ? 1 : 0;
    }

    final kept = _ctx.scholarships
        .where((s) =>
            s.windowStatus(now: now) != ScholarshipWindowStatus.closed &&
            levelAllows(s))
        .toList()
      ..sort((left, right) {
        final byBucket = bucket(left).compareTo(bucket(right));
        if (byBucket != 0) return byBucket;
        final leftClose = left.deadlineAt;
        final rightClose = right.deadlineAt;
        if (leftClose != null && rightClose != null) {
          final byDate = leftClose.compareTo(rightClose);
          if (byDate != 0) return byDate;
        }
        final byName = _resolve(left.name)
            .toLowerCase()
            .compareTo(_resolve(right.name).toLowerCase());
        if (byName != 0) return byName;
        return left.id.compareTo(right.id);
      });
    return List<ScholarshipModel>.unmodifiable(kept);
  }
}
