import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// « Rendez-vous : mardi 12 nov. à 14 h 00 » — la date que le conseiller a
/// fixée, à l'heure du téléphone (le codec rend déjà `scheduledAt` en local).
///
/// Revue avant la 58, constat 35 : l'élève lisait « Prépare ton rendez-vous »
/// sans date ni heure, alors que le parent lié la voyait. `null` quand aucun
/// rendez-vous n'est fixé : rien n'est inventé.
String? caseAppointmentLabel(DateTime? scheduledAt, String localeCode) {
  if (scheduledAt == null) return null;
  final local = scheduledAt.toLocal();
  final date = localeCode.startsWith('fr')
      ? DateFormat("EEEE d MMM 'à' HH 'h' mm", 'fr').format(local)
      : DateFormat("EEEE, MMM d 'at' HH:mm", 'en').format(local);
  return 'case_next_step_appointment'.trParams({'date': date});
}
