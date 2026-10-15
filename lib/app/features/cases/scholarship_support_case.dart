import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/remote_feature_flags.dart';
import 'case_composer_sheet.dart';

/// Peut-on lier un dossier à sa bourse (`scholarshipId`) ?
///
/// Le champ `scholarshipId` de `POST /cases` et le filtre
/// `GET /cases?scholarshipId=` arrivent avec le serveur du chantier D, dont le
/// drapeau `scholarshipMatch` est le témoin côté app. Sur un serveur sans lui,
/// le `ValidationPipe` (`forbidNonWhitelisted`) refuserait la création du
/// dossier (400) : drapeau fermé, le dossier part SANS lien, et on ne cherche
/// pas de dossier lié.
bool get canLinkCaseToScholarship =>
    RemoteFeatureFlags.instance.scholarshipMatchEnabled;

/// « Être accompagné » pour une bourse : rouvre le dossier d'accompagnement
/// OUVERT déjà lié à cette bourse (local, puis `GET /cases?scholarshipId=`),
/// sinon ouvre le compositeur prérempli. Rend vrai quand un dossier existant a
/// été réutilisé.
///
/// [onResolved] est appelé dès que l'on sait si un dossier est réutilisé,
/// avant toute navigation (mesure analytique).
///
/// Partagé par la fiche de la bourse et les résultats « Mes 10 bourses ».
Future<bool> startScholarshipSupportCase(
  BuildContext context, {
  required String scholarshipId,
  required String title,
  required String contextLabel,
  String? countryId,
  AppController? controller,
  ValueChanged<bool>? onResolved,
}) async {
  final app = controller ?? Get.find<AppController>();
  final link = canLinkCaseToScholarship && scholarshipId.trim().isNotEmpty;
  final existing =
      link ? await app.findOpenScholarshipCase(scholarshipId) : null;
  onResolved?.call(existing != null);
  if (existing != null) {
    unawaited(Get.toNamed<void>('/cases/${Uri.encodeComponent(existing.id)}'));
    return true;
  }
  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CaseComposerSheet(
      caseType: CaseType.scholarshipSupport,
      title: title,
      contextLabel: contextLabel,
      countryId: countryId,
      scholarshipId: link ? scholarshipId : null,
    ),
  );
  return false;
}
