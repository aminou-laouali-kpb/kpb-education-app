part of 'app_models.dart';

/// How well a school, programme or field of study lines up with the student's
/// declared profile (field, target countries, level…).
///
/// Jamais pour une BOURSE : le palier y venait d'un score client qui partait du
/// `baseMatch` éditorial et ne lisait aucune condition d'éligibilité. Seul le
/// test serveur « Mes 10 bourses » dit qu'une bourse est compatible.
///
/// Conformité marque : jamais de pourcentage ni de « chances d'admission ».
/// Le score interne reste un outil de TRI ; seul ce palier qualitatif est
/// montré, et il décrit l'adéquation au profil, pas une probabilité
/// d'admission. Sans profil, les écrans n'affichent aucun palier : l'ancien
/// score de repli (40 % partout) ne mesurait rien.
enum ProfileFit {
  strong,
  good,
  explore;

  /// Tier for an internal 0–100 ranking score.
  static ProfileFit fromScore(int score) {
    if (score >= 70) return ProfileFit.strong;
    if (score >= 50) return ProfileFit.good;
    return ProfileFit.explore;
  }

  /// Tier for a backend match zone (`green` / `yellow` / `blue`).
  static ProfileFit fromZone(SchoolMatchZone zone) => switch (zone) {
        SchoolMatchZone.green => ProfileFit.strong,
        SchoolMatchZone.yellow => ProfileFit.good,
        SchoolMatchZone.blue => ProfileFit.explore,
      };

  String get labelKey => switch (this) {
        ProfileFit.strong => 'profile_fit_strong',
        ProfileFit.good => 'profile_fit_good',
        ProfileFit.explore => 'profile_fit_explore',
      };

  /// (background, foreground) on a light surface.
  (Color, Color) get colors => switch (this) {
        ProfileFit.strong => (KpbColors.successLight, KpbColors.success),
        ProfileFit.good => (
            KpbColors.actionPrimarySoft,
            KpbColors.actionPrimary
          ),
        ProfileFit.explore => (KpbColors.surfaceMuted, KpbColors.textSecondary),
      };
}
