part of 'app_models.dart';

/// Un cours Academy (préparation HSK, TOEFL…), tel que le sert
/// `GET /academy/courses`.
///
/// Les champs ajoutés avec le Pass Karatou (`slug`, `requiresPass`…) ont des
/// valeurs par défaut : un backend plus ancien, ou les données embarquées,
/// restent lisibles.
class AcademyCourseModel {
  const AcademyCourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.priceXOF,
    required this.priceEUR,
    required this.lessonCount,
    this.slug,
    this.totalDurationSeconds = 0,
    this.requiresPass = false,
    this.freeLessonCount = 0,
  });

  final String id;
  final String? slug;
  final LocalizedText title;
  final LocalizedText description;
  final String? coverImageUrl;
  final int priceXOF;
  final double priceEUR;
  final int lessonCount;
  final int totalDurationSeconds;

  /// Réservé au Pass Karatou, sauf les leçons d'aperçu.
  final bool requiresPass;
  final int freeLessonCount;

  factory AcademyCourseModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return AcademyCourseModel(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String?,
      title: parseLoc('title'),
      description: parseLoc('description'),
      coverImageUrl: json['coverImageUrl'] as String?,
      priceXOF: (json['priceXOF'] as num?)?.toInt() ?? 0,
      priceEUR: (json['priceEUR'] as num?)?.toDouble() ?? 0.0,
      lessonCount: (json['lessonCount'] as num?)?.toInt() ?? 0,
      totalDurationSeconds:
          (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      requiresPass: json['requiresPass'] == true,
      freeLessonCount: (json['freeLessonCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Une leçon d'un cours. Verrouillée ([locked]), elle garde son titre et sa
/// durée (le programme reste lisible) mais le serveur ne livre pas sa vidéo.
class AcademyLessonModel {
  const AcademyLessonModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.durationSeconds,
    required this.order,
    this.thumbnailUrl,
    this.isFreePreview = false,
    this.locked = false,
  });

  final String id;
  final LocalizedText title;

  /// Vide pour une leçon verrouillée.
  final String videoUrl;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int order;
  final bool isFreePreview;
  final bool locked;

  /// Une leçon se lit quand elle n'est pas verrouillée ET qu'une vidéo est là.
  bool get playable => !locked && videoUrl.isNotEmpty;

  factory AcademyLessonModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return AcademyLessonModel(
      id: json['id'] as String? ?? '',
      title: parseLoc('title'),
      videoUrl: json['videoUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isFreePreview: json['isFreePreview'] == true,
      locked: json['locked'] == true,
    );
  }
}

/// Un cours et son programme, pour le lecteur qui le demande : `viewerHasPass`
/// dit si les leçons réservées lui sont ouvertes.
class AcademyCourseDetail {
  const AcademyCourseDetail({
    required this.course,
    required this.lessons,
    required this.viewerHasPass,
  });

  final AcademyCourseModel course;
  final List<AcademyLessonModel> lessons;
  final bool viewerHasPass;

  List<AcademyLessonModel> get playableLessons =>
      lessons.where((lesson) => lesson.playable).toList(growable: false);

  factory AcademyCourseDetail.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'];
    final lessons = rawLessons is List
        ? rawLessons
            .whereType<Map<String, dynamic>>()
            .map(AcademyLessonModel.fromJson)
            .toList()
        : <AcademyLessonModel>[];
    lessons.sort((a, b) => a.order.compareTo(b.order));
    return AcademyCourseDetail(
      course: AcademyCourseModel.fromJson(json),
      lessons: lessons,
      viewerHasPass: json['viewerHasPass'] == true,
    );
  }
}

/// Le Pass Karatou de l'élève connecté (`GET /me/pass`).
class PassStatusModel {
  const PassStatusModel({required this.active, this.activeUntil});

  static const none = PassStatusModel(active: false);

  final bool active;
  final DateTime? activeUntil;

  factory PassStatusModel.fromJson(Map<String, dynamic> json) {
    final until = json['activeUntil'];
    return PassStatusModel(
      active: json['active'] == true,
      activeUntil: until is String ? DateTime.tryParse(until) : null,
    );
  }
}
