import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';

enum AcademyPhase { loading, ready, failed }

/// La liste des cours visibles (`GET /academy/courses`).
class AcademyCatalogController extends ChangeNotifier {
  AcademyCatalogController({required AppApiClient apiClient})
      : _apiClient = apiClient;

  final AppApiClient _apiClient;

  AcademyPhase _phase = AcademyPhase.loading;
  List<AcademyCourseModel> _courses = const [];

  AcademyPhase get phase => _phase;
  List<AcademyCourseModel> get courses => _courses;

  Future<void> load() async {
    _phase = AcademyPhase.loading;
    notifyListeners();
    try {
      final raw = await _apiClient.getAcademyCourses();
      _courses = raw.map(AcademyCourseModel.fromJson).toList(growable: false);
      _phase = AcademyPhase.ready;
    } catch (_) {
      // Pas de repli sur les cours embarqués : ce sont des données de démo.
      _courses = const [];
      _phase = AcademyPhase.failed;
    }
    notifyListeners();
  }
}

/// Un cours et son programme. Connecté, l'élève passe par la route
/// `/me/academy/…`, qui ouvre les leçons réservées si son Pass est actif ;
/// sinon la route publique les sert verrouillées.
class AcademyCourseController extends ChangeNotifier {
  AcademyCourseController({
    required AppApiClient apiClient,
    required this.idOrSlug,
  }) : _apiClient = apiClient;

  final AppApiClient _apiClient;
  final String idOrSlug;

  AcademyPhase _phase = AcademyPhase.loading;
  AcademyCourseDetail? _detail;

  AcademyPhase get phase => _phase;
  AcademyCourseDetail? get detail => _detail;

  Future<void> load() async {
    _phase = AcademyPhase.loading;
    notifyListeners();
    try {
      final signedIn = await _apiClient.hasAuthSession();
      final raw =
          await _apiClient.getAcademyCourse(idOrSlug, signedIn: signedIn);
      _detail = AcademyCourseDetail.fromJson(raw);
      _phase = AcademyPhase.ready;
    } catch (_) {
      _detail = null;
      _phase = AcademyPhase.failed;
    }
    notifyListeners();
  }
}

/// « 3 h 05 min », « 45 min » : la durée d'un cours, arrondie à la minute.
String formatAcademyDuration(int totalSeconds) {
  final minutes = (totalSeconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? '$hours h'
      : '$hours h ${rest.toString().padLeft(2, '0')} min';
}
