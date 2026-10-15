import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/models/scholarship_match.dart';

/// « 13/10 » — jour et mois, heure locale (un instant : la date d'un run).
String matchDayMonth(DateTime instant) {
  final local = instant.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}';
}

/// « 13/10/2026 » — heure locale.
String matchFullDate(DateTime instant) {
  final local = instant.toLocal();
  return '${matchDayMonth(local)}/${local.year}';
}

String _locale() => Get.locale?.languageCode == 'en' ? 'en' : 'fr';

/// « 15 nov. » — une date du CATALOGUE, lue en UTC : convertie en heure
/// locale, une borne écrite `23:59:59Z` basculerait au lendemain à l'est
/// d'UTC (même règle que la liste des bourses).
String matchCatalogDay(DateTime date) {
  final utc = date.toUtc();
  try {
    return DateFormat('d MMM', _locale()).format(utc);
  } catch (_) {
    // Données de locale absentes (hors MaterialApp, tests) : repli numérique.
    return '${utc.day.toString().padLeft(2, '0')}/'
        '${utc.month.toString().padLeft(2, '0')}';
  }
}

/// « janv. 2027 » — une date ESTIMÉE ne se dit qu'au mois.
String matchCatalogMonth(DateTime date) {
  final utc = date.toUtc();
  try {
    return DateFormat('MMM yyyy', _locale()).format(utc);
  } catch (_) {
    return '${utc.month.toString().padLeft(2, '0')}/${utc.year}';
  }
}

/// La sorte de pastille de fenêtre, pour sa couleur.
enum MatchWindowTone { open, upcoming, closed, neutral }

/// Le texte de la pastille « fenêtre de candidature », ou `null`.
///
/// Règles (les mêmes que la liste des bourses) :
/// - « Clôturée » SEULEMENT pour une date limite CONFIRMÉE passée — c'est
///   aussi la règle hors ligne, où le statut servi a pu vieillir ;
/// - une date estimée ne se dit qu'au mois, sans compte à rebours ;
/// - rien plutôt qu'une affirmation qu'on ne peut pas tenir.
(String, MatchWindowTone)? matchWindowLabel(MatchWindow? window, DateTime now) {
  if (window == null) return null;
  if (window.isConfirmedClosed(now)) {
    return ('scholarship_match_window_closed'.tr, MatchWindowTone.closed);
  }
  final confirmedClose = window.dateConfirmed ? window.closesAt : null;
  final confirmedOpen = window.dateConfirmed ? window.opensAt : null;
  switch (window.status) {
    case MatchWindowStatus.suspended:
      return ('scholarship_match_window_suspended'.tr, MatchWindowTone.closed);
    case MatchWindowStatus.open:
      if (confirmedClose != null) {
        return (
          'scholarship_match_window_open_until'
              .trParams({'date': matchCatalogDay(confirmedClose)}),
          MatchWindowTone.open,
        );
      }
      final estimatedClose = window.estimatedCloseAt ?? window.closesAt;
      if (estimatedClose != null) {
        return (
          'scholarship_match_window_open_estimated_close'
              .trParams({'month': matchCatalogMonth(estimatedClose)}),
          MatchWindowTone.open,
        );
      }
      return ('scholarship_match_window_open'.tr, MatchWindowTone.open);
    case MatchWindowStatus.forecast:
      if (confirmedOpen != null && confirmedOpen.isAfter(now)) {
        return (
          'scholarship_match_window_opens_on'
              .trParams({'date': matchCatalogDay(confirmedOpen)}),
          MatchWindowTone.upcoming,
        );
      }
      final estimatedOpen = window.estimatedOpenAt ??
          (window.dateConfirmed ? null : window.opensAt);
      if (estimatedOpen != null) {
        return (
          'scholarship_match_window_estimated_open'
              .trParams({'month': matchCatalogMonth(estimatedOpen)}),
          MatchWindowTone.upcoming,
        );
      }
      final estimatedClose = window.estimatedCloseAt ??
          (window.dateConfirmed ? null : window.closesAt);
      if (estimatedClose != null) {
        return (
          'scholarship_match_window_estimated_close'
              .trParams({'month': matchCatalogMonth(estimatedClose)}),
          MatchWindowTone.upcoming,
        );
      }
      return null;
    case MatchWindowStatus.closed:
    case MatchWindowStatus.unknown:
      return null;
  }
}

/// « 6 compatibles · 4 à vérifier » — les éléments AFFICHÉS, jamais gonflés.
String matchCountsLabel(MatchRun run) {
  final compatible = run.compatibleItems.length;
  final toVerify = run.toVerifyItems.length;
  final compatibleText = compatible == 1
      ? 'scholarship_match_count_compatible_one'.tr
      : 'scholarship_match_count_compatible'.trParams({'count': '$compatible'});
  final toVerifyText = toVerify == 1
      ? 'scholarship_match_count_to_verify_one'.tr
      : 'scholarship_match_count_to_verify'.trParams({'count': '$toVerify'});
  return '$compatibleText · $toVerifyText';
}
