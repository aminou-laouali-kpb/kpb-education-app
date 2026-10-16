import 'package:get/get.dart';

import '../models/app_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Libellé de rentrée d'une offre par campus.
//
// Depuis la rentrée décalée OMNES (printemps 2027) et IGENSIA (mars ET
// septembre 2027), une formation peut avoir deux offres sur le même campus. La
// date brute (« 01/03/2027 ») ne dit pas laquelle est la rentrée décalée : on
// l'écrit en toutes lettres.
//
//   « Rentrée décalée · mars 2027 »   « Rentrée de septembre 2026 »
//   « Spring intake · March 2027 »    « September 2026 intake »
//
// La session vient de l'offre (`session`) ; à défaut, du mois (janvier–juin =
// décalée), comme côté serveur (backend/src/modules/catalog/campus-offerings.ts).
// Une rentrée illisible (texte libre de l'admin) reste affichée telle quelle.
// ─────────────────────────────────────────────────────────────────────────────

const _monthsFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// « de septembre », « d'octobre » : l'élision devant une voyelle.
String _ofMonthFr(int month) {
  final name = _monthsFr[month - 1];
  return RegExp('^[aeiouyéèâ]').hasMatch(name) ? "d'$name" : 'de $name';
}

final _date = RegExp(r'^(?:\d{1,2}/)?(\d{1,2})/(\d{4})$');
final _year = RegExp(r'\b(20\d{2})\b');

/// Mois et année d'une rentrée. Plusieurs dates jointes par « · » (seed
/// d'automne) : la plus tôt.
({int month, int year})? intakeMonthYear(String? intake) {
  ({int month, int year})? best;
  for (final part in (intake ?? '').split('·')) {
    final m = _date.firstMatch(part.trim());
    if (m == null) return null;
    final month = int.parse(m.group(1)!);
    final year = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    if (best == null || year * 100 + month < best.year * 100 + best.month) {
      best = (month: month, year: year);
    }
  }
  return best;
}

/// `spring` (rentrée décalée) ou `fall`, déclarée ou déduite du mois.
String? offeringSession(CampusOffering offering) {
  final declared = offering.session;
  if (declared == 'spring' || declared == 'fall') return declared;
  final my = intakeMonthYear(offering.intake);
  if (my == null) return null;
  return my.month <= 6 ? 'spring' : 'fall';
}

/// Le libellé de rentrée de l'offre, ou null si elle n'en dit rien.
String? offeringIntakeLabel(CampusOffering offering, String localeCode) {
  final raw = offering.intake?.trim() ?? '';
  final en = localeCode.startsWith('en');
  final session = offeringSession(offering);
  final my = intakeMonthYear(raw);
  if (session != null && my != null) {
    final month = en ? _monthsEn[my.month - 1] : _monthsFr[my.month - 1];
    if (session == 'spring') {
      return 'offering_intake_spring_month'.trParams({
        'month': month,
        'year': '${my.year}',
      });
    }
    return 'offering_intake_fall_month'.trParams({
      'month': en ? month : _ofMonthFr(my.month),
      'year': '${my.year}',
    });
  }
  final year = _year.firstMatch(raw)?.group(1);
  if (session != null && year != null) {
    return (session == 'spring'
            ? 'offering_intake_spring_year'
            : 'offering_intake_fall_year')
        .trParams({'year': year});
  }
  if (raw.isEmpty) return null;
  return '${'intake_label'.tr} $raw';
}

/// « Alternance » / « Formation initiale », ou null.
String? offeringRhythmLabel(CampusOffering offering) {
  switch (offering.rhythm) {
    case 'alternance':
      return 'offering_rhythm_alternance'.tr;
    case 'initiale':
      return 'offering_rhythm_initiale'.tr;
    default:
      return null;
  }
}

/// Ordre d'affichage : campus, puis rentrée la plus tôt. Stable.
List<CampusOffering> sortedOfferings(List<CampusOffering> offerings) {
  int key(CampusOffering o) {
    final my = intakeMonthYear(o.intake);
    return my == null ? 0 : my.year * 100 + my.month;
  }

  final indexed = offerings.indexed.toList()
    ..sort((a, b) {
      final byCampus = a.$2.campus.toLowerCase().compareTo(
            b.$2.campus.toLowerCase(),
          );
      if (byCampus != 0) return byCampus;
      final byDate = key(a.$2).compareTo(key(b.$2));
      if (byDate != 0) return byDate;
      return a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// Nombre de campus distincts (une formation peut avoir deux offres à Paris).
int distinctCampusCount(List<CampusOffering> offerings) =>
    offerings.map((o) => o.campus.trim().toLowerCase()).toSet().length;
