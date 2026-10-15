import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/models/app_models.dart';
import '../../core/models/live_scholarships_query.dart';
import '../../core/ui/app_tokens.dart';
import 'widgets/scholarship_status_line.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Urgence d'une bourse — LE calcul partagé par la liste et la fiche.
//
// Point d'entrée : [scholarshipUrgencyOf] (une [LiveScholarshipModel]) ; le
// libellé : [scholarshipUrgencyLabel] ; les couleurs : [scholarshipUrgencyStyle]
// ; la puce prête à poser : [ScholarshipUrgencyChip]. Ne recopie pas ces
// règles dans un écran : c'est leur divergence (la carte qui se tait, la fiche
// qui affirme une date estimée au jour près) qui faisait dire deux choses de la
// même bourse.
//
// Règles :
//   · la base est la ligne de statut du chantier G
//     ([LiveScholarshipModel.statusLine]) : jamais « Ouverte » avant `opensAt` ;
//   · « Clôture proche » : clôture CONFIRMÉE dans [kScholarshipClosingSoonDays]
//     jours ou moins — jamais sur une date estimée ;
//   · « Clôturée » seulement si une date de clôture CONFIRMÉE est passée, ou
//     si l'équipe a fermé le cycle. Le serveur sert aussi `closed` dès qu'une
//     clôture ESTIMÉE est passée (`servedCycleStatus`) : ce cas-là se lit
//     « Date à confirmer », pas « Clôturée » ;
//   · une période ESTIMÉE déjà commencée se dit par sa clôture estimée, au
//     mois près (« Clôture estimée nov. 2026 ») ;
//   · aucune date fiable : « Date à confirmer ».
//
// La liste en dérive aussi ce qu'elle MASQUE hors ligne ([isScholarshipClosed])
// et le statut filtrable de chaque carte ([scholarshipListStatusOf]) — même
// règle que `scholarshipServedStatus` côté serveur (`status=`).
// ─────────────────────────────────────────────────────────────────────────────

/// « Clôture proche » : clôture confirmée dans ce nombre de jours calendaires
/// ou moins (0 = dernier jour).
const int kScholarshipClosingSoonDays = 14;

enum ScholarshipUrgencyKind {
  /// Ouverte, clôture confirmée au-delà du seuil. `date` = clôture.
  open,

  /// Ouverte, clôture confirmée dans le seuil. `date` = clôture.
  closingSoon,

  /// Ouverte, mais sans date de clôture confirmée.
  openDateToConfirm,

  /// Ouverture confirmée à venir. `date` = ouverture.
  opensOn,

  /// Ouverture estimée (au mois près). `date` = ouverture estimée.
  openingEstimated,

  /// Période estimée déjà commencée : `date` = clôture estimée, à venir (au
  /// mois près). Jamais « Clôture proche ».
  closingEstimated,

  /// Aucune date fiable (rien de servi, ou clôture estimée dépassée).
  dateToConfirm,

  /// Clôturée — date confirmée et passée.
  closed,
}

@immutable
class ScholarshipUrgency {
  const ScholarshipUrgency(this.kind, {this.date, this.daysLeft});

  final ScholarshipUrgencyKind kind;
  final DateTime? date;

  /// Jours calendaires avant la clôture confirmée (0 = dernier jour) ; null
  /// hors [ScholarshipUrgencyKind.open] / [ScholarshipUrgencyKind.closingSoon].
  final int? daysLeft;

  /// On peut candidater maintenant.
  bool get isOpen =>
      kind == ScholarshipUrgencyKind.open ||
      kind == ScholarshipUrgencyKind.closingSoon ||
      kind == ScholarshipUrgencyKind.openDateToConfirm;

  bool get isClosingSoon => kind == ScholarshipUrgencyKind.closingSoon;
  bool get isClosed => kind == ScholarshipUrgencyKind.closed;

  @override
  bool operator ==(Object other) =>
      other is ScholarshipUrgency &&
      other.kind == kind &&
      other.date == date &&
      other.daysLeft == daysLeft;

  @override
  int get hashCode => Object.hash(kind, date, daysLeft);

  @override
  String toString() => 'ScholarshipUrgency($kind, $date, $daysLeft)';
}

int _calendarDaysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// L'urgence d'une bourse à l'instant [now] (défaut : maintenant). Jamais
/// null : sans rien de fiable, c'est « Date à confirmer ».
ScholarshipUrgency scholarshipUrgencyOf(
  LiveScholarshipModel scholarship, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final line = scholarship.statusLine(now: ref);
  if (line == null) {
    return const ScholarshipUrgency(ScholarshipUrgencyKind.dateToConfirm);
  }
  final date = line.date;
  switch (line.kind) {
    case ScholarshipStatusKind.closed:
      return _isConfirmedClosed(scholarship, ref)
          ? const ScholarshipUrgency(ScholarshipUrgencyKind.closed)
          : const ScholarshipUrgency(ScholarshipUrgencyKind.dateToConfirm);
    case ScholarshipStatusKind.open:
      if (date == null) {
        return const ScholarshipUrgency(
          ScholarshipUrgencyKind.openDateToConfirm,
        );
      }
      final days = _calendarDaysBetween(ref, date);
      return ScholarshipUrgency(
        days <= kScholarshipClosingSoonDays
            ? ScholarshipUrgencyKind.closingSoon
            : ScholarshipUrgencyKind.open,
        date: date,
        daysLeft: days < 0 ? 0 : days,
      );
    case ScholarshipStatusKind.opensOn:
      return ScholarshipUrgency(ScholarshipUrgencyKind.opensOn, date: date);
    case ScholarshipStatusKind.openingEstimated:
      if (date != null && date.isAfter(ref)) {
        return ScholarshipUrgency(
          ScholarshipUrgencyKind.openingEstimated,
          date: date,
        );
      }
      // Ouverture estimée déjà passée (ou inconnue) : la période estimée est
      // peut-être en cours. On cite sa clôture estimée si elle est à venir —
      // une « Ouverture estimée » au passé ne dirait rien d'utile.
      final cycle = scholarship.currentCycle;
      final estimatedClose = cycle?.estimatedCloseAt ?? cycle?.closesAt;
      if (estimatedClose != null && estimatedClose.isAfter(ref)) {
        return ScholarshipUrgency(
          ScholarshipUrgencyKind.closingEstimated,
          date: estimatedClose,
        );
      }
      return const ScholarshipUrgency(ScholarshipUrgencyKind.dateToConfirm);
  }
}

/// « Clôturée » se mérite : une clôture CONFIRMÉE passée, ou un cycle fermé
/// par l'équipe — c.-à-d. un `closed` que la seule clôture ESTIMÉE dépassée
/// n'explique pas. Même règle que `scholarshipServedStatus` (serveur).
bool _isConfirmedClosed(LiveScholarshipModel s, DateTime ref) {
  final cycle = s.currentCycle;
  final estimated = cycle?.isEstimated ?? false;
  final confirmedClose = cycle?.closesAt ?? (estimated ? null : s.deadlineAt);
  if (confirmedClose != null && !ref.isBefore(confirmedClose)) return true;
  if (cycle == null || cycle.status != 'closed') return false;
  // Fermé en base alors que la clôture confirmée est à venir : l'équipe l'a
  // close, c'est confirmé.
  if (cycle.closesAt != null) return true;
  // `closed` servi parce que la clôture ESTIMÉE est passée : rien de confirmé.
  // Sans clôture estimée passée pour l'expliquer, c'est l'équipe qui l'a
  // fermé (cycle estimé compris).
  final estimatedClose = cycle.estimatedCloseAt;
  return estimatedClose == null || estimatedClose.isAfter(ref);
}

/// La liste ne montre JAMAIS une bourse que la fiche dirait « Clôturée » —
/// ni en ligne, ni depuis le cache hors ligne (qui peut dater de plusieurs
/// jours). Une clôture seulement ESTIMÉE dépassée reste visible (« Date à
/// confirmer »), comme sur la fiche.
bool isScholarshipClosed(LiveScholarshipModel scholarship, {DateTime? now}) =>
    scholarshipUrgencyOf(scholarship, now: now).isClosed;

/// Le statut filtrable que la carte AFFICHE (même règle que le serveur pour
/// `status=`, `scholarshipServedStatus`), ou `null` quand elle est clôturée.
ScholarshipListStatus? scholarshipListStatusOf(
  LiveScholarshipModel scholarship, {
  DateTime? now,
}) =>
    switch (scholarshipUrgencyOf(scholarship, now: now).kind) {
      ScholarshipUrgencyKind.open ||
      ScholarshipUrgencyKind.closingSoon ||
      ScholarshipUrgencyKind.openDateToConfirm =>
        ScholarshipListStatus.open,
      ScholarshipUrgencyKind.opensOn => ScholarshipListStatus.upcoming,
      ScholarshipUrgencyKind.openingEstimated ||
      ScholarshipUrgencyKind.closingEstimated ||
      ScholarshipUrgencyKind.dateToConfirm =>
        ScholarshipListStatus.forecast,
      ScholarshipUrgencyKind.closed => null,
    };

/// « 6 janv. » cette année, « 6 janv. 2027 » sinon — au jour près, dans la
/// langue active.
String formatScholarshipShortDay(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final ref = (now ?? DateTime.now()).toLocal();
  if (local.year != ref.year) return formatScholarshipDay(date);
  final locale = Get.locale?.languageCode == 'en' ? 'en' : 'fr';
  try {
    return DateFormat('d MMM', locale).format(local);
  } catch (_) {
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
  }
}

/// Le libellé court (liste, puce, en-tête de fiche).
String scholarshipUrgencyLabel(ScholarshipUrgency urgency, {DateTime? now}) {
  final date = urgency.date;
  switch (urgency.kind) {
    case ScholarshipUrgencyKind.open:
      return 'scholarship_urgency_open'.trParams({
        'date': formatScholarshipShortDay(date!, now: now),
      });
    case ScholarshipUrgencyKind.closingSoon:
      return 'scholarship_urgency_closing_soon'.trParams({
        'date': formatScholarshipShortDay(date!, now: now),
      });
    case ScholarshipUrgencyKind.openDateToConfirm:
      return 'scholarship_status_open_no_date'.tr;
    case ScholarshipUrgencyKind.opensOn:
      return 'scholarship_status_opens_on'.trParams({
        'date': formatScholarshipShortDay(date!, now: now),
      });
    case ScholarshipUrgencyKind.openingEstimated:
      return 'scholarship_status_opening_estimated'.trParams({
        'date': formatScholarshipMonth(date!),
      });
    case ScholarshipUrgencyKind.closingEstimated:
      return 'scholarship_urgency_closing_estimated'.trParams({
        'date': formatScholarshipMonth(date!),
      });
    case ScholarshipUrgencyKind.dateToConfirm:
      return 'scholarship_urgency_date_to_confirm'.tr;
    case ScholarshipUrgencyKind.closed:
      return 'scholarship_status_closed'.tr;
  }
}

/// Couleurs et icône d'une urgence. Chaque couple texte / fond passe l'AA
/// (4,5:1) — vérifié par test. « Clôture proche » : texte FONCÉ sur ambre (le
/// texte ambre sur fond clair, lui, ne passe pas).
typedef ScholarshipUrgencyStyle = ({
  Color foreground,
  Color background,
  IconData icon,
});

ScholarshipUrgencyStyle scholarshipUrgencyStyle(ScholarshipUrgencyKind kind) =>
    switch (kind) {
      ScholarshipUrgencyKind.open ||
      ScholarshipUrgencyKind.openDateToConfirm =>
        (
          foreground: KpbColors.success,
          background: KpbColors.successLight,
          icon: Icons.lock_open_rounded,
        ),
      ScholarshipUrgencyKind.closingSoon => (
          foreground: KpbColors.brandNavy,
          background: KpbColors.gold,
          icon: Icons.hourglass_bottom_rounded,
        ),
      ScholarshipUrgencyKind.opensOn => (
          foreground: KpbColors.actionPrimary,
          background: KpbColors.actionPrimarySoft,
          icon: Icons.event_available_rounded,
        ),
      ScholarshipUrgencyKind.openingEstimated ||
      ScholarshipUrgencyKind.closingEstimated =>
        (
          foreground: KpbColors.warning,
          background: KpbColors.warningLight,
          icon: Icons.schedule_rounded,
        ),
      ScholarshipUrgencyKind.dateToConfirm => (
          foreground: KpbColors.textSecondary,
          background: KpbColors.surfaceMuted,
          icon: Icons.event_note_rounded,
        ),
      ScholarshipUrgencyKind.closed => (
          foreground: KpbColors.textSecondary,
          background: KpbColors.surfaceMuted,
          icon: Icons.lock_rounded,
        ),
    };

/// La puce d'urgence (cartes de liste). Texte ≥ 12 sp, icône décorative.
class ScholarshipUrgencyChip extends StatelessWidget {
  const ScholarshipUrgencyChip({super.key, required this.urgency, this.now});

  final ScholarshipUrgency urgency;

  /// Horloge injectée (tests) : décide si la date dit son année.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final style = scholarshipUrgencyStyle(urgency.kind);
    final label = scholarshipUrgencyLabel(urgency, now: now);
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('scholarship-urgency-chip'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: KpbRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 14, color: style.foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: KpbFontSize.xs,
                  fontWeight: FontWeight.w800,
                  color: style.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
