import 'package:get/get.dart';

import '../controllers/app_controller.dart';

/// L'élève a-t-il passé le mur d'entrée — un compte dont l'onboarding est
/// terminé, ou le mode invité ?
///
/// Tout ce qui navigue depuis l'EXTÉRIEUR de l'app (lien `kpb://`, raccourci
/// de l'icône, notification) doit le demander avant de pousser un écran.
/// Sinon un nouvel utilisateur qui choisit « Mes Dossiers » dans le menu de
/// l'icône Android atterrissait dans le shell sans compte ni mode invité : un
/// accueil en squelette ou en erreur, sans chemin vers la connexion (audit
/// avant la 59). Le routeur des notifications avait déjà cette garde ; les
/// liens et les raccourcis ne l'avaient pas.
///
/// Sans contrôleur enregistré (tests d'un service isolé), il répond oui : il
/// n'y a alors aucun mur à contourner.
bool hasPassedEntryWall() {
  if (!Get.isRegistered<AppController>()) return true;
  final controller = Get.find<AppController>();
  return controller.hasCompletedOnboarding || controller.isGuestMode;
}
