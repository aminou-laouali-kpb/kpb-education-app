import '../utils/external_link.dart';

/// L'avis servi par `/config/app` (`notice`) : un message court affiché en
/// haut de l'accueil, qu'on peut fermer.
///
/// C'est le seul moyen de parler à tous les téléphones installés sans nouvelle
/// build ni notification : une date limite qui approche, un incident, un
/// changement de contact.
class AppNotice {
  const AppNotice({required this.fr, this.en, this.url});

  /// Le texte français. Toujours présent : c'est la langue de base de l'app.
  final String fr;

  /// La traduction anglaise, ou `null` (le français s'affiche alors).
  final String? en;

  /// Un lien « En savoir plus » déjà validé, ou `null`.
  final String? url;

  /// Longueur au-delà de laquelle un texte est coupé. Le serveur borne déjà à
  /// 240 ; ceci protège la mise en page d'un serveur qui ne le ferait pas.
  static const int maxLength = 400;

  /// Le texte dans la langue de l'utilisateur, français par défaut.
  String textFor(String? languageCode) =>
      languageCode == 'en' && en != null ? en! : fr;

  /// Lit la charge servie. Rend `null` — aucun avis — pour toute charge
  /// absente ou illisible : un avis mal formé ne s'affiche pas à moitié.
  static AppNotice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fr = _text(raw['fr']);
    if (fr == null) return null;
    final link = raw['url'];
    return AppNotice(
      fr: fr,
      en: _text(raw['en']),
      url: link is String && isOpenableWebUrl(link.trim()) ? link.trim() : null,
    );
  }

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is AppNotice &&
      other.fr == fr &&
      other.en == en &&
      other.url == url;

  @override
  int get hashCode => Object.hash(fr, en, url);
}
