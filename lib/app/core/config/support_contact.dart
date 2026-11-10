import 'app_config.dart';

/// La ligne WhatsApp officielle de KPB, telle que l'app doit l'utiliser.
///
/// ## Pourquoi ce n'est plus seulement une constante
///
/// Tout le passage au conseiller (dossier, services, parents, bulle Études en
/// France, pages légales) aboutit à une seule ligne. Jusqu'à la 58, son numéro
/// n'existait que dans le binaire ([AppConfig.whatsappNumber]) : restreinte
/// par WhatsApp ou changée par l'équipe, elle restait cassée sur tous les
/// téléphones jusqu'à la build suivante (audit avant la 59).
///
/// `/config/app` peut maintenant servir `support.whatsappNumber`. Quand il le
/// fait, ce numéro l'emporte ; sinon, et hors réseau, le numéro compilé reste
/// le repli. Le serveur ne peut donc que REMPLACER la ligne, jamais la retirer.
abstract final class SupportContact {
  static String? _served;

  /// Le numéro à composer : celui du serveur s'il en sert un, sinon celui de
  /// la build.
  static String get whatsappNumber => _served ?? AppConfig.whatsappNumber;

  /// Vrai quand le numéro vient du serveur — pour les tests et le diagnostic.
  static bool get isServed => _served != null;

  /// Pose (ou retire, avec une valeur illisible) le numéro servi.
  static void setServed(Object? raw) => _served = normalize(raw);

  /// Un numéro international (`+` puis 8 à 15 chiffres), ou `null`.
  ///
  /// Le serveur filtre déjà ; ceci est la bretelle. Un numéro illisible
  /// enverrait chaque élève vers une ligne morte : il vaut « garde le tien ».
  static String? normalize(Object? raw) {
    if (raw is! String) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\s().-]'), '');
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(cleaned) ? cleaned : null;
  }
}
