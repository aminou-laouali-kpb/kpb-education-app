import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_models.dart';
import '../../../core/ui/app_tokens.dart';

/// « 6 janv. 2027 » dans la langue active, au jour près.
///
/// `try`/`catch` : `DateFormat` avec une locale explicite lève quand ses
/// données ne sont pas chargées (hors `MaterialApp`, donc en test) ; le repli
/// numérique ne lève pas et reste exact.
String formatScholarshipDay(DateTime date) {
  final local = date.toLocal();
  final locale = Get.locale?.languageCode == 'en' ? 'en' : 'fr';
  try {
    return DateFormat('d MMM y', locale).format(local);
  } catch (_) {
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

/// « fév. 2027 » : une ouverture ESTIMÉE ne se dit qu'au mois près.
String formatScholarshipMonth(DateTime date) {
  final utc = date.toUtc();
  final locale = Get.locale?.languageCode == 'en' ? 'en' : 'fr';
  try {
    return DateFormat('MMM y', locale).format(utc);
  } catch (_) {
    return '${utc.month.toString().padLeft(2, '0')}/${utc.year}';
  }
}

/// Le texte de la ligne de statut.
String scholarshipStatusLabel(ScholarshipStatusLine line) {
  final date = line.date;
  switch (line.kind) {
    case ScholarshipStatusKind.open:
      return date == null
          ? 'scholarship_status_open_no_date'.tr
          : 'scholarship_status_open'
              .trParams({'date': formatScholarshipDay(date)});
    case ScholarshipStatusKind.opensOn:
      return 'scholarship_status_opens_on'
          .trParams({'date': formatScholarshipDay(date!)});
    case ScholarshipStatusKind.openingEstimated:
      return date == null
          ? 'scholarship_status_opening_unknown'.tr
          : 'scholarship_status_opening_estimated'
              .trParams({'date': formatScholarshipMonth(date)});
    case ScholarshipStatusKind.closed:
      return 'scholarship_status_closed'.tr;
  }
}

/// Couleurs et icône d'un statut (texte foncé sur fond clair : contraste AA).
(Color foreground, Color background, IconData icon) scholarshipStatusStyle(
  ScholarshipStatusKind kind,
) =>
    switch (kind) {
      ScholarshipStatusKind.open => (
          KpbColors.success,
          KpbColors.successLight,
          Icons.lock_open_rounded,
        ),
      ScholarshipStatusKind.opensOn => (
          KpbColors.actionPrimary,
          KpbColors.actionPrimarySoft,
          Icons.event_available_rounded,
        ),
      ScholarshipStatusKind.openingEstimated => (
          KpbColors.warning,
          KpbColors.warningLight,
          Icons.schedule_rounded,
        ),
      ScholarshipStatusKind.closed => (
          KpbColors.textMuted,
          KpbColors.surfaceMuted,
          Icons.lock_rounded,
        ),
    };

/// La puce de statut (fiche, Mes suivis). Texte ≥ 12 sp.
class ScholarshipStatusChip extends StatelessWidget {
  const ScholarshipStatusChip({super.key, required this.line});

  final ScholarshipStatusLine line;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = scholarshipStatusStyle(line.kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              scholarshipStatusLabel(line),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
