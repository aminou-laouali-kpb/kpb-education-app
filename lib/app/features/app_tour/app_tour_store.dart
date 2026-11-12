import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

/// Le drapeau « l'élève a fermé la visite de l'application », sur cet appareil.
///
/// ## Quand il est écrit
///
/// À la FERMETURE de la visite (« J'ai compris » ou « Passer »), pas à son
/// ouverture : c'est la consigne du propriétaire (« quand il clique, c'est bon,
/// j'ai compris, ça ne s'affiche plus »). Un élève qui quitte l'app au milieu
/// la revoit donc au démarrage suivant. Dans une même session, elle ne
/// s'ouvre qu'une fois, même si l'écriture tombe en panne
/// (`AppTour._autoShownThisRun`).
///
/// ## Ce que le drapeau est, et n'est pas
///
/// Un booléen LOCAL, sans rapport avec le compte : rien ne part vers le
/// serveur. La clé est versionnée (`…_v1`) : une visite refondue peut être
/// rejouée à tout le monde en passant à `_v2`.
abstract interface class AppTourStore {
  /// La visite a-t-elle déjà été fermée sur cet appareil ? Peut LEVER une
  /// exception : l'appelant la traite comme « oui » (on ne montre rien plutôt
  /// que de risquer une visite à chaque ouverture).
  Future<bool> hasBeenSeen();

  /// Note que la visite a été fermée. Peut LEVER une exception.
  Future<void> markSeen();
}

/// Le drapeau, dans `SharedPreferences`, sous `kpb_relaunch_v1.app_tour_v1`.
class SharedPreferencesAppTourStore implements AppTourStore {
  const SharedPreferencesAppTourStore();

  /// Ne change pas sans raison : la changer REJOUE la visite à tous ceux qui
  /// l'ont déjà vue.
  static const String key = '${AppConfig.storageNamespace}.app_tour_v1';

  @override
  Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setBool(key, true);
    if (!ok) throw StateError('Le drapeau de la visite n\'a pas été écrit.');
  }
}
