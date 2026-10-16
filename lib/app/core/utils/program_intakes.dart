import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/app_models.dart';
import 'intake_label.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Résumé des rentrées d'UNE formation, pour les cartes et les listes.
//
// La fiche détail écrit chaque offre par campus en toutes lettres
// (intake_label.dart). Une carte n'a la place que d'une ligne :
//
//   « Rentrées : mars 2027 (décalée) · sept. 2027 »
//   « Intakes: Mar 2027 (spring) · Sep 2027 »
//   « Rentrées de l'école : Septembre »          (repli établissement)
//   « Prochaine rentrée non publiée »             (toutes les dates passées)
//
// Les règles :
//
//  1. La source, ce sont les offres de la formation (`campusOfferings`). Les
//     dates sont dédoublonnées par mois et par année (Paris et Lyon en
//     octobre 2026 = une seule rentrée), puis triées.
//  2. Sans offre, et seulement alors, on reprend les `intakePeriods` de
//     l'établissement, ANNONCÉES comme rentrées de l'école : une rentrée de
//     l'école n'est pas la promesse que cette formation-là ouvre à cette date.
//  3. Sans l'un ni l'autre : rien. On n'invente aucune date — pas de
//     « septembre » par défaut (les universités « Études en France » n'ont pas
//     de rentrées publiées dans le catalogue).
//  4. Une date PASSÉE n'est pas une rentrée disponible : elle est MASQUÉE. La
//     marquer « passée » sur une carte prendrait la place d'une rentrée
//     ouverte pour une information qui ne sert plus à choisir ; la fiche
//     détail garde, elle, la liste complète des offres. Quand toutes les
//     dates connues sont passées, la carte le dit (« Prochaine rentrée non
//     publiée ») plutôt que de se taire : se taire laisserait croire qu'on ne
//     sait rien, et repartir sur les dates de l'école prêterait à la formation
//     une rentrée que rien n'annonce.
//
//     Une date au jour près (« 01/10/2026 ») est passée dès le lendemain ; une
//     date au mois (« 03/2027 », IGENSIA) le reste jusqu'à la fin du mois ;
//     une année seule (« FALL 2027 ») jusqu'à la fin de l'année.
//  5. Une rentrée décalée (session `spring`, ou à défaut un mois de janvier à
//     juin, comme côté serveur) porte la mention « (décalée) ». Une rentrée
//     reconduite d'un an, que l'école n'a pas encore publiée (offre
//     `intakeEstimated` / `rolledFromIntake`, automne 2026 → 2027), porte
//     « (à confirmer) » — sauf si une autre offre annonce le même mois pour de
//     bon.
//  6. Un texte que l'app ne sait pas dater (« Septembre », texte libre de
//     l'admin) est repris tel quel, après les dates, et n'est jamais filtré.
//     « Septembre 2026 » / « March 2027 » (mois en toutes lettres et année)
//     est une date, au mois près.
//
// La MÊME règle sert partout où une rentrée s'affiche : les rentrées d'une
// école (`schoolIntakeSummary`, comparateur, repli de la fiche), le libellé
// de rentrée d'un pays (`upcomingIntakeText`), les offres de la fiche détail
// (`offeringIsPast`). Une date brute d'école (« 01/10/2026 ») s'écrit en
// toutes lettres (« octobre 2026 ») sans que la base soit réécrite.
//
// L'horloge est injectable ([ProgramIntakes.clock]) : aucun test ne peut
// attendre le 1er octobre.
// ─────────────────────────────────────────────────────────────────────────────

/// Une rentrée datée : un mois d'une année, ou une année seule (« FALL 2027 »).
@immutable
class IntakeDate {
  const IntakeDate({
    required this.year,
    this.month,
    required this.spring,
    this.estimated = false,
  });

  final int year;

  /// Null quand la source ne donne que l'année et la session.
  final int? month;

  /// Rentrée décalée (printemps).
  final bool spring;

  /// Date reconduite, à confirmer par l'école.
  final bool estimated;

  /// « (décalée) », « (à confirmer) », « (décalée, à confirmer) » ou rien.
  String _tags() {
    final tags = [
      if (spring) 'program_intake_spring_tag'.tr,
      if (estimated) 'program_intake_estimated_tag'.tr,
    ];
    return tags.isEmpty ? '' : ' (${tags.join(', ')})';
  }

  IntakeDate _withEstimated(bool value) => IntakeDate(
        year: year,
        month: month,
        spring: spring,
        estimated: value,
      );

  /// Clé de tri et de dédoublonnage : l'année, puis le mois (une année seule
  /// se range à son mois type — mars pour une décalée, septembre sinon).
  int get sortKey => year * 100 + (month ?? (spring ? 3 : 9));

  /// « oct. 2026 », « Mar 2027 (spring) ».
  String shortLabel(String localeCode) {
    final en = localeCode.startsWith('en');
    final String base;
    if (month != null) {
      base = '${(en ? _shortEn : _shortFr)[month! - 1]} $year';
    } else {
      base = spring
          ? '$year'
          : 'program_intake_fall_year_short'.trParams({'year': '$year'});
    }
    return '$base${_tags()}';
  }

  /// « octobre 2026 », « mars 2027 (décalée) » : le libellé lisible des
  /// tableaux (comparateur, fiche).
  String longLabel(String localeCode) {
    final String base;
    if (month != null) {
      base = '${intakeMonthName(month!, localeCode)} $year';
    } else {
      base = spring
          ? '$year'
          : 'program_intake_fall_year_short'.trParams({'year': '$year'});
    }
    return '$base${_tags()}';
  }

  /// « octobre 2026 », « mars 2027, rentrée décalée » : ce que lit TalkBack.
  String spokenLabel(String localeCode) {
    final String base;
    if (month != null) {
      base = '${intakeMonthName(month!, localeCode)} $year';
    } else {
      base = spring
          ? '$year'
          : 'program_intake_fall_year_short'.trParams({'year': '$year'});
    }
    return [
      base,
      if (spring) 'program_intake_spring_a11y'.tr,
      if (estimated) 'program_intake_estimated_a11y'.tr,
    ].join(', ');
  }

  @override
  bool operator ==(Object other) =>
      other is IntakeDate &&
      other.year == year &&
      other.month == month &&
      other.spring == spring &&
      other.estimated == estimated;

  @override
  int get hashCode => Object.hash(year, month, spring, estimated);

  @override
  String toString() =>
      'IntakeDate($year, $month, spring: $spring, estimated: $estimated)';
}

const _shortFr = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

const _shortEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Le résumé des rentrées d'une formation. Calculé par [programIntakeSummary].
@immutable
class ProgramIntakeSummary {
  const ProgramIntakeSummary({
    this.dates = const [],
    this.rawLabels = const [],
    this.fromSchool = false,
    this.allPast = false,
  });

  static const empty = ProgramIntakeSummary();

  /// Les rentrées À VENIR, dédoublonnées et triées.
  final List<IntakeDate> dates;

  /// Les rentrées que l'app ne sait pas dater, telles que la source les écrit.
  final List<String> rawLabels;

  /// Vrai quand le résumé vient de l'établissement (la formation n'a pas
  /// d'offre) : la ligne dit alors « Rentrées de l'école ».
  final bool fromSchool;

  /// Des dates étaient connues, elles sont toutes passées, et rien d'autre.
  final bool allPast;

  /// Rien à afficher : la ligne disparaît.
  bool get isEmpty => dates.isEmpty && rawLabels.isEmpty && !allPast;

  int get count => dates.length + rawLabels.length;

  /// Au plus trois rentrées affichées ; au-delà, deux et « + n ».
  static const maxShown = 3;

  String _prefix() {
    final many = count > 1;
    if (fromSchool) {
      return (many
              ? 'program_intakes_school_many'
              : 'program_intakes_school_one')
          .tr;
    }
    return (many ? 'program_intakes_many' : 'program_intakes_one').tr;
  }

  /// La ligne courte des cartes, ou null s'il n'y a rien à dire.
  String? shortLabel(String localeCode) {
    if (isEmpty) return null;
    if (count == 0) return 'program_intakes_none_upcoming'.tr;
    final entries = [
      for (final d in dates) d.shortLabel(localeCode),
      ...rawLabels,
    ];
    final shown = entries.length > maxShown
        ? entries.take(maxShown - 1).toList()
        : entries;
    final hidden = entries.length - shown.length;
    final tail = hidden > 0
        ? ' ${'program_intakes_more'.trParams({'count': '$hidden'})}'
        : '';
    return '${_prefix()} ${shown.join(' · ')}$tail';
  }

  /// Les rentrées à venir en toutes lettres, SANS préfixe (« octobre 2027 ·
  /// mars 2027 (décalée) ») — pour une cellule de tableau qui porte déjà son
  /// titre. « Prochaine rentrée non publiée » quand tout est passé ; null
  /// quand rien n'est connu.
  String? longLabel(String localeCode) {
    if (isEmpty) return null;
    if (count == 0) return 'program_intakes_none_upcoming'.tr;
    final entries = [
      for (final d in dates) d.longLabel(localeCode),
      ...rawLabels,
    ];
    final shown = entries.length > maxShown
        ? entries.take(maxShown - 1).toList()
        : entries;
    final hidden = entries.length - shown.length;
    final tail = hidden > 0
        ? ' ${'program_intakes_more'.trParams({'count': '$hidden'})}'
        : '';
    return '${shown.join(' · ')}$tail';
  }

  /// Le libellé COMPLET lu par les lecteurs d'écran : toutes les rentrées,
  /// mois en toutes lettres, sans « + n ».
  String? semanticsLabel(String localeCode) {
    if (isEmpty) return null;
    if (count == 0) return 'program_intakes_none_upcoming'.tr;
    final entries = [
      for (final d in dates) d.spokenLabel(localeCode),
      ...rawLabels,
    ];
    return '${_prefix()} ${entries.join(', ')}';
  }
}

/// L'horloge du résumé — injectable pour les tests.
class ProgramIntakes {
  ProgramIntakes._();

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;
}

final _dayMonthYear = RegExp(r'^(?:(\d{1,2})/)?(\d{1,2})/(\d{4})$');

/// « Septembre 2026 », « mars 2027 », « March 2027 », « sept. 2027 ».
final _monthNameYear = RegExp(
  r'^([a-zA-Zéèûôàç]+)\.?\s+(20\d{2})$',
  caseSensitive: false,
);

const _monthNames = <String, int>{
  'janvier': 1,
  'janv': 1,
  'january': 1,
  'jan': 1,
  'fevrier': 2,
  'février': 2,
  'fevr': 2,
  'févr': 2,
  'february': 2,
  'feb': 2,
  'mars': 3,
  'march': 3,
  'mar': 3,
  'avril': 4,
  'avr': 4,
  'april': 4,
  'apr': 4,
  'mai': 5,
  'may': 5,
  'juin': 6,
  'june': 6,
  'jun': 6,
  'juillet': 7,
  'juil': 7,
  'july': 7,
  'jul': 7,
  'aout': 8,
  'août': 8,
  'august': 8,
  'aug': 8,
  'septembre': 9,
  'sept': 9,
  'september': 9,
  'sep': 9,
  'octobre': 10,
  'oct': 10,
  'october': 10,
  'novembre': 11,
  'nov': 11,
  'november': 11,
  'decembre': 12,
  'décembre': 12,
  'dec': 12,
  'déc': 12,
  'december': 12,
};
final _yearOnly = RegExp(r'\b(20\d{2})\b');
final _springWords = RegExp(r'\b(spring|printemps)\b', caseSensitive: false);
final _fallWords = RegExp(r'\b(fall|autumn|automne)\b', caseSensitive: false);

/// Une date candidate, avec le jour quand la source le donne (règle 4).
typedef _Candidate = ({IntakeDate date, int? day});

/// Lit une rentrée : une date, ou null (le texte sera repris tel quel).
_Candidate? _parse(String part, String? declaredSession) {
  final m = _dayMonthYear.firstMatch(part);
  if (m != null) {
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    final day = m.group(1) == null ? null : int.parse(m.group(1)!);
    final spring = declaredSession == 'spring' ||
        (declaredSession != 'fall' && month <= 6);
    return (
      date: IntakeDate(
        year: int.parse(m.group(3)!),
        month: month,
        spring: spring,
      ),
      day: day,
    );
  }
  // « Septembre 2026 » : un mois en toutes lettres et une année.
  final named = _monthNameYear.firstMatch(part);
  if (named != null) {
    final month = _monthNames[named.group(1)!.toLowerCase()];
    if (month != null) {
      return (
        date: IntakeDate(
          year: int.parse(named.group(2)!),
          month: month,
          spring: declaredSession == 'spring' ||
              (declaredSession != 'fall' && month <= 6),
        ),
        day: null,
      );
    }
  }
  // « FALL 2027 » (ABC) : une année et une session, déclarée ou écrite.
  final year = _yearOnly.firstMatch(part)?.group(1);
  if (year == null) return null;
  final session = declaredSession == 'spring' || declaredSession == 'fall'
      ? declaredSession
      : _springWords.hasMatch(part)
          ? 'spring'
          : _fallWords.hasMatch(part)
              ? 'fall'
              : null;
  if (session == null) return null;
  return (
    date: IntakeDate(year: int.parse(year), spring: session == 'spring'),
    day: null,
  );
}

bool _isPast(_Candidate c, DateTime today) {
  final d = c.date;
  if (d.month == null) return d.year < today.year;
  if (c.day != null) {
    return DateTime(d.year, d.month!, c.day!).isBefore(today);
  }
  return d.year * 100 + d.month! < today.year * 100 + today.month;
}

ProgramIntakeSummary _summarize(
  Iterable<({String text, String? session, bool estimated})> sources, {
  required bool fromSchool,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final upcoming = <int, IntakeDate>{};
  final raw = <String, String>{};
  var sawDate = false;
  for (final source in sources) {
    for (final piece in source.text.split('·')) {
      final part = piece.trim();
      if (part.isEmpty) continue;
      final read = _parse(part, source.session);
      if (read == null) {
        raw.putIfAbsent(part.toLowerCase(), () => part);
        continue;
      }
      sawDate = true;
      if (_isPast(read, today)) continue;
      final date = read.date._withEstimated(source.estimated);
      final key = date.sortKey;
      final known = upcoming[key];
      // Même mois annoncé deux fois : décalée si l'une des deux l'est, à
      // confirmer seulement si les deux le sont.
      final kept =
          known == null || (!known.spring && date.spring) ? date : known;
      upcoming[key] = known == null
          ? kept
          : kept._withEstimated(known.estimated && date.estimated);
    }
  }
  final dates = upcoming.values.toList()
    ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  final rawLabels = raw.values.toList();
  return ProgramIntakeSummary(
    dates: dates,
    rawLabels: rawLabels,
    fromSchool: fromSchool,
    allPast: sawDate && dates.isEmpty && rawLabels.isEmpty,
  );
}

/// Le résumé des rentrées de [program] (voir l'en-tête du fichier).
///
/// [institution] est l'établissement de la formation
/// (`AppController.institutionByIdOrNull(program.institutionId)`), pour le
/// repli quand la formation n'a pas d'offre.
ProgramIntakeSummary programIntakeSummary(
  ProgramModel program, {
  InstitutionModel? institution,
  DateTime? now,
}) {
  final at = now ?? ProgramIntakes.clock();
  if (program.campusOfferings.isNotEmpty) {
    final fromOfferings = _summarize(
      [
        for (final o in program.campusOfferings)
          if ((o.intake ?? '').trim().isNotEmpty)
            (
              text: o.intake!,
              session: o.session,
              estimated: o.isIntakeEstimated,
            ),
      ],
      fromSchool: false,
      now: at,
    );
    // Des offres sans aucune rentrée écrite ne disent rien : on retombe sur
    // l'école, comme pour une formation sans offre.
    if (!fromOfferings.isEmpty) return fromOfferings;
  }
  final periods = institution?.intakePeriods ?? const <String>[];
  if (periods.isEmpty) return ProgramIntakeSummary.empty;
  return _summarize(
    [for (final p in periods) (text: p, session: null, estimated: false)],
    fromSchool: true,
    now: at,
  );
}

/// Mémoire du résumé, par formation : une liste de 1 000 formations le
/// redemanderait à chaque reconstruction. La clé retient le jour et
/// l'établissement, pour qu'une date qui passe ou une école resynchronisée
/// ne serve pas un résumé périmé.
final _cache = Expando<
    ({
      int day,
      InstitutionModel? institution,
      ProgramIntakeSummary summary
    })>('programIntakeSummary');

/// [programIntakeSummary], calculé une fois par formation et par jour.
ProgramIntakeSummary cachedProgramIntakeSummary(
  ProgramModel program, {
  InstitutionModel? institution,
}) {
  final now = ProgramIntakes.clock();
  final day = now.year * 10000 + now.month * 100 + now.day;
  final hit = _cache[program];
  if (hit != null &&
      hit.day == day &&
      identical(hit.institution, institution)) {
    return hit.summary;
  }
  final summary = programIntakeSummary(
    program,
    institution: institution,
    now: now,
  );
  _cache[program] = (day: day, institution: institution, summary: summary);
  return summary;
}

/// Les rentrées d'un ÉTABLISSEMENT (`intakePeriods`), à venir et lisibles :
/// « 01/10/2026 » devient « octobre 2026 », une date passée disparaît. Pour le
/// comparateur et le repli de la fiche formation.
ProgramIntakeSummary schoolIntakeSummary(
  List<String> periods, {
  DateTime? now,
}) {
  if (periods.isEmpty) return ProgramIntakeSummary.empty;
  return _summarize(
    [for (final p in periods) (text: p, session: null, estimated: false)],
    fromSchool: true,
    now: now ?? ProgramIntakes.clock(),
  );
}

/// Un libellé de rentrée libre (celui d'un pays : « Septembre 2026 »), ou
/// null s'il annonce une date PASSÉE — il n'est alors plus une rentrée
/// disponible. Un texte sans date (« Rentrée de septembre ») est rendu tel
/// quel.
String? upcomingIntakeText(String label, {DateTime? now}) {
  final text = label.trim();
  if (text.isEmpty) return null;
  final summary = _summarize(
    [(text: text, session: null, estimated: false)],
    fromSchool: false,
    now: now ?? ProgramIntakes.clock(),
  );
  return summary.allPast ? null : text;
}

/// Vrai quand TOUTES les rentrées datées d'une offre sont passées (et qu'elle
/// en a au moins une) : l'offre n'est plus disponible. Une offre sans date, ou
/// au texte libre, n'est jamais tenue pour passée.
bool offeringIsPast(CampusOffering offering, {DateTime? now}) {
  final raw = offering.intake?.trim() ?? '';
  if (raw.isEmpty) return false;
  return _summarize(
    [(text: raw, session: offering.session, estimated: false)],
    fromSchool: false,
    now: now ?? ProgramIntakes.clock(),
  ).allPast;
}
