import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';
import '../controllers/app_controller.dart';
import 'shell_tabs.dart';

/// Où mène un raccourci « Bourses » de l'app (chantier I).
///
/// Avant, sept appels poussaient `Get.toNamed(AppRoutes.scholarships)` : une
/// SECONDE liste empilée par-dessus la coquille, qui, elle, a déjà l'onglet
/// Bourses — deux listes, deux états de filtres, et un « retour » qui ramenait
/// à la première. Désormais :
///
///  · une bourse précise est visée → sa FICHE (élève connecté) ;
///  · sinon → l'onglet Bourses de la coquille (on referme ce qui est empilé
///    au-dessus), jamais un second écran de liste.
///
/// Le repli `Get.toNamed(AppRoutes.scholarships)` ne reste que là où il n'y a
/// pas d'onglet Bourses (coquille commerciale, contrôleur absent).
enum ScholarshipNavigationTarget { detail, tab, route }

/// La destination, sans naviguer (testable seule).
///
/// Un invité (ou une session sans profil) va TOUJOURS à l'onglet : la fiche
/// exige un compte (401), et elle n'a pas de porte d'inscription — elle dirait
/// « Erreur de connexion » avec un « Réessayer » sans issue. L'onglet, lui,
/// montre la porte d'invité.
///
/// [fromCatalog] : l'identifiant vient du catalogue local (accueil, recherche).
/// Quand ce catalogue est l'échantillon embarqué (`catalogIsSampleData`), ses
/// identifiants n'existent pas côté serveur : la fiche répondrait « Bourse
/// introuvable ». On ouvre alors l'onglet, qui montre les vraies bourses.
ScholarshipNavigationTarget resolveScholarshipNavigation({
  String? scholarshipId,
  bool fromCatalog = false,
  AppController? controller,
}) {
  final id = scholarshipId?.trim() ?? '';
  final sampleIds = fromCatalog && (controller?.catalogIsSampleData ?? false);
  final signedIn = controller != null &&
      !controller.isGuestMode &&
      controller.profile != null;
  if (id.isNotEmpty && !sampleIds && (signedIn || controller == null)) {
    return ScholarshipNavigationTarget.detail;
  }
  if (controller == null || controller.isCommercial) {
    return ScholarshipNavigationTarget.route;
  }
  return ScholarshipNavigationTarget.tab;
}

/// Ouvre la fiche de [scholarshipId], ou l'onglet Bourses (voir
/// [resolveScholarshipNavigation]).
void openScholarshipOrTab({String? scholarshipId, bool fromCatalog = false}) {
  final controller =
      Get.isRegistered<AppController>() ? Get.find<AppController>() : null;
  switch (resolveScholarshipNavigation(
    scholarshipId: scholarshipId,
    fromCatalog: fromCatalog,
    controller: controller,
  )) {
    case ScholarshipNavigationTarget.detail:
      Get.toNamed<void>(AppRoutes.scholarshipDetailPath(scholarshipId!.trim()));
    case ScholarshipNavigationTarget.route:
      Get.toNamed<void>(AppRoutes.scholarships);
    case ScholarshipNavigationTarget.tab:
      // La coquille est la première route : on referme ce qui est empilé
      // au-dessus (recherche, calculateur, Success Lab…), puis on bascule.
      Get.until((Route<dynamic> route) => route.isFirst);
      controller!.goToTab(StudentShellTab.scholarships);
  }
}
