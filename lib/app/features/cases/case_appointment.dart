import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// « Rendez-vous : mardi 12 nov. à 14 h 00 » — la date que le conseiller a
/// fixée, à l'heure du téléphone (le codec rend déjà `scheduledAt` en local).
///
/// Revue avant la 58, constat 35 : l'élève lisait « Prépare ton rendez-vous »
/// sans date ni heure, alors que le parent lié la voyait. `null` quand aucun
/// rendez-vous n'est fixé : rien n'est inventé.
///
/// `null` aussi quand le rendez-vous est PASSÉ : le serveur ne remet jamais
/// `scheduledAt` à zéro, et une date passée sans année se lisait comme un
/// rendez-vous à venir (relecture de la PR #407). L'année n'est écrite que si
/// elle diffère de l'année en cours.
String? caseAppointmentLabel(
  DateTime? scheduledAt,
  String localeCode, {
  DateTime? now,
}) {
  if (scheduledAt == null) return null;
  final local = scheduledAt.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (local.isBefore(today)) return null;
  final withYear = local.year != today.year;
  final fr = localeCode.startsWith('fr');
  final pattern = fr
      ? (withYear ? "EEEE d MMM y 'à' HH 'h' mm" : "EEEE d MMM 'à' HH 'h' mm")
      : (withYear ? "EEEE, MMM d, y 'at' HH:mm" : "EEEE, MMM d 'at' HH:mm");
  final date = DateFormat(pattern, fr ? 'fr' : 'en').format(local);
  return 'case_next_step_appointment'.trParams({'date': date});
}
