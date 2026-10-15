import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_models.dart';
import '../../../core/ui/app_tokens.dart';

/// La ligne de statut d'une carte de la liste des bourses : UNE phrase, tirée
/// du cycle courant, à la place de l'ancien paragraphe de pilules à 9,5 px.
///
///   « Ouverte · clôture 6 janv. »      ouverte, clôture confirmée
///   « Ouverte · clôture à confirmer »  ouverte, sans date ferme
///   « Ouvre le 3 mars »                ouverture CONFIRMÉE à venir
///   « Ouverture estimée fév. 2027 »    ouverture estimée — au mois près
///   « Clôture estimée nov. 2026 »      période estimée déjà commencée
///   « Date à confirmer »               on ne sait rien
///   « Clôturée »
///
/// La règle de fond est celle de la fiche et de « Mes suivis »
/// ([LiveScholarshipModel.statusLine]) : jamais « Ouverte » avant la date
/// d'ouverture, jamais un jour précis pour une date estimée.
enum ScholarshipListLineKind {
  open,
  openNoDate,
  opensOn,
  openingEstimated,
  closingEstimated,
  toConfirm,
  closed,
}

/// La ligne calculée : de quoi l'afficher et la tester.
@immutable
class ScholarshipListLine {
  const ScholarshipListLine(this.kind, {this.date, this.closingSoonDays});

  final ScholarshipListLineKind kind;

  /// La date que la phrase cite (clôture, ouverture…), ou null.
  final DateTime? date;

  /// Non nul : clôture CONFIRMÉE dans 14 jours au plus — nombre de jours
  /// restants (0 = aujourd'hui). Jamais posé sur une date estimée.
  final int? closingSoonDays;

  bool get closingSoon => closingSoonDays != null;
}

/// Seuil de « Clôture proche » (jours calendaires, clôture confirmée).
const int scholarshipClosingSoonDays = 14;

int _calendarDaysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  return DateTime(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime(a.year, a.month, a.day)).inDays;
}

/// La ligne de statut de [scholarship] à l'instant [now].
ScholarshipListLine scholarshipListLine(
  LiveScholarshipModel scholarship, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final line = scholarship.statusLine(now: ref);
  if (line == null) {
    return const ScholarshipListLine(ScholarshipListLineKind.toConfirm);
  }
  final date = line.date;
  switch (line.kind) {
    case ScholarshipStatusKind.closed:
      return const ScholarshipListLine(ScholarshipListLineKind.closed);
    case ScholarshipStatusKind.opensOn:
      return ScholarshipListLine(ScholarshipListLineKind.opensOn, date: date);
    case ScholarshipStatusKind.open:
      if (date == null) {
        return const ScholarshipListLine(ScholarshipListLineKind.openNoDate);
      }
      final days = _calendarDaysBetween(ref, date);
      return ScholarshipListLine(
        ScholarshipListLineKind.open,
        date: date,
        closingSoonDays:
            days >= 0 && days <= scholarshipClosingSoonDays ? days : null,
      );
    case ScholarshipStatusKind.openingEstimated:
      if (date != null && date.isAfter(ref)) {
        return ScholarshipListLine(
          ScholarshipListLineKind.openingEstimated,
          date: date,
        );
      }
      // Ouverture estimée déjà passée : la période estimée est peut-être en
      // cours. On cite sa clôture estimée si elle est à venir, au mois près.
      final cycle = scholarship.currentCycle;
      final estimatedClose = cycle?.estimatedCloseAt ?? cycle?.closesAt;
      if (estimatedClose != null && estimatedClose.isAfter(ref)) {
        return ScholarshipListLine(
          ScholarshipListLineKind.closingEstimated,
          date: estimatedClose,
        );
      }
      return const ScholarshipListLine(ScholarshipListLineKind.toConfirm);
  }
}

String _locale() => Get.locale?.languageCode == 'en' ? 'en' : 'fr';

/// « 6 janv. » — l'année n'est dite que si la date tombe à plus de 300 jours
/// (« 6 janv. 2028 »), pour qu'un « janv. » ne se lise jamais sur la mauvaise
/// année. `try`/`catch` : hors `MaterialApp` (tests), les données de locale ne
/// sont pas chargées et le repli numérique reste exact.
String formatScholarshipListDay(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final ref = now ?? DateTime.now();
  final withYear = local.difference(ref).inDays.abs() > 300;
  try {
    return DateFormat(withYear ? 'd MMM y' : 'd MMM', _locale()).format(local);
  } catch (_) {
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return withYear ? '$day/$month/${local.year}' : '$day/$month';
  }
}

/// « fév. 2027 » : une date ESTIMÉE ne se dit qu'au mois près, lue en UTC
/// (borne de mois saisie à minuit UTC : en heure locale, le 1er mars
/// deviendrait le 28 février à l'ouest d'UTC).
String formatScholarshipListMonth(DateTime date) {
  final utc = date.toUtc();
  try {
    return DateFormat('MMM y', _locale()).format(utc);
  } catch (_) {
    return '${utc.month.toString().padLeft(2, '0')}/${utc.year}';
  }
}

/// La phrase de la ligne.
String scholarshipListLineLabel(ScholarshipListLine line, {DateTime? now}) {
  final date = line.date;
  switch (line.kind) {
    case ScholarshipListLineKind.open:
      return 'scholarships_list_status_open'.trParams({
        'date': formatScholarshipListDay(date!, now: now),
      });
    case ScholarshipListLineKind.openNoDate:
      return 'scholarships_list_status_open_no_date'.tr;
    case ScholarshipListLineKind.opensOn:
      return 'scholarships_list_status_opens_on'.trParams({
        'date': formatScholarshipListDay(date!, now: now),
      });
    case ScholarshipListLineKind.openingEstimated:
      return 'scholarships_list_status_opening_estimated'.trParams({
        'date': formatScholarshipListMonth(date!),
      });
    case ScholarshipListLineKind.closingEstimated:
      return 'scholarships_list_status_closing_estimated'.trParams({
        'date': formatScholarshipListMonth(date!),
      });
    case ScholarshipListLineKind.toConfirm:
      return 'scholarships_list_status_to_confirm'.tr;
    case ScholarshipListLineKind.closed:
      return 'scholarships_list_status_closed'.tr;
  }
}

/// Le libellé « Clôture proche » ([ScholarshipListLine.closingSoonDays]).
String scholarshipClosingSoonLabel(int days) => days == 0
    ? 'scholarships_list_closing_today'.tr
    : 'scholarships_list_closing_soon'.trParams({'count': '$days'});

/// Couleur et icône : texte FONCÉ (AA ≥ 4,5:1 sur la carte blanche).
(Color, IconData) _style(ScholarshipListLineKind kind) => switch (kind) {
      ScholarshipListLineKind.open || ScholarshipListLineKind.openNoDate => (
          KpbColors.success,
          Icons.lock_open_rounded,
        ),
      ScholarshipListLineKind.opensOn => (
          KpbColors.actionPrimary,
          Icons.event_available_rounded,
        ),
      ScholarshipListLineKind.openingEstimated ||
      ScholarshipListLineKind.closingEstimated =>
        (
          KpbColors.warning,
          Icons.schedule_rounded,
        ),
      ScholarshipListLineKind.toConfirm => (
          KpbColors.textSecondary,
          Icons.help_outline_rounded,
        ),
      ScholarshipListLineKind.closed => (
          KpbColors.textSecondary,
          Icons.lock_rounded,
        ),
    };

/// La ligne de statut d'une carte (icône + phrase, 13 sp), suivie au besoin
/// de l'étiquette « Clôture proche · J-5 » en texte foncé sur ambre.
class ScholarshipListStatusRow extends StatelessWidget {
  const ScholarshipListStatusRow({super.key, required this.line, this.now});

  final ScholarshipListLine line;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style(line.kind);
    final label = scholarshipListLineLabel(line, now: now);
    final soon = line.closingSoonDays;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          key: const ValueKey<String>('scholarship-list-status'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: KpbFontSize.sm,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (soon != null) ScholarshipClosingSoonTag(days: soon),
      ],
    );
  }
}

/// « Clôture proche · J-5 » : texte navy sur ambre plein (≈ 9:1).
class ScholarshipClosingSoonTag extends StatelessWidget {
  const ScholarshipClosingSoonTag({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('scholarship-closing-soon'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: KpbColors.gold,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        scholarshipClosingSoonLabel(days),
        style: const TextStyle(
          fontSize: KpbFontSize.xs,
          fontWeight: FontWeight.w800,
          color: KpbColors.brandNavy,
        ),
      ),
    );
  }
}
