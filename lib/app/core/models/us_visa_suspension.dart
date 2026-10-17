import 'package:flutter/foundation.dart';

import '../utils/external_link.dart';

/// Un pays dont les ressortissants ne peuvent plus demander de visa étudiant
/// américain (F, M, J).
@immutable
class UsVisaSuspendedCountry {
  const UsVisaSuspendedCountry({
    required this.code,
    required this.nameFr,
    required this.nameEn,
  });

  /// ISO 3166-1 alpha-2, en majuscules.
  final String code;
  final String nameFr;
  final String nameEn;

  String nameFor(String localeCode) => localeCode == 'en' ? nameEn : nameFr;
}

/// La suspension des visas étudiants américains, telle que `/config/app` la
/// sert (`usVisaSuspension`) — décision du propriétaire du 17/10/2026.
///
/// ## Une liste servie, avec un repli embarqué
///
/// La liste change au rythme des proclamations américaines (révision tous les
/// 180 jours), pas à celui des stores : le serveur la sert, et l'exploitation la
/// change par une variable d'environnement (`docs/api-contracts.md`). [fallback]
/// est la même liste que le défaut serveur, vérifiée le 17/10/2026, pour un
/// serveur plus ancien (clé absente) ou injoignable.
///
/// ## Le pays de l'élève ne quitte pas le téléphone
///
/// [concerns] compare la liste au pays de résidence du profil, localement.
/// Rien de cette comparaison n'est envoyé au serveur ni aux mesures d'audience.
@immutable
class UsVisaSuspension {
  const UsVisaSuspension({
    required this.countries,
    this.lastVerifiedAt,
    this.sourceUrl,
  });

  /// Vide : aucune suspension, aucun avis.
  final List<UsVisaSuspendedCountry> countries;

  /// Le jour de la dernière vérification, ou `null` (aucune date affichée).
  final DateTime? lastVerifiedAt;

  /// La page officielle, ouvrable (https) — ou `null` : pas de bouton.
  final String? sourceUrl;

  bool get isActive => countries.isNotEmpty;

  /// La page du Département d'État sur la proclamation 10998 (vérifiée le
  /// 17/10/2026) — même valeur que le défaut serveur.
  static const defaultSourceUrl =
      'https://travel.state.gov/content/travel/en/News/visas-news/'
      'suspension-of-visa-issuance-to-foreign-nationals-to-protect-the-security-of-the-united-states.html';

  /// Le défaut serveur, embarqué. Proclamation 10998 (16/12/2025, en vigueur le
  /// 1/1/2026) : les dix pays de la décision du propriétaire, plus le Burundi et
  /// le Togo, confirmés par sa section 3.
  static final fallback = UsVisaSuspension(
    countries: const [
      UsVisaSuspendedCountry(
          code: 'BF', nameFr: 'Burkina Faso', nameEn: 'Burkina Faso'),
      UsVisaSuspendedCountry(code: 'ML', nameFr: 'Mali', nameEn: 'Mali'),
      UsVisaSuspendedCountry(code: 'NE', nameFr: 'Niger', nameEn: 'Niger'),
      UsVisaSuspendedCountry(code: 'TD', nameFr: 'Tchad', nameEn: 'Chad'),
      UsVisaSuspendedCountry(
          code: 'CG', nameFr: 'Congo', nameEn: 'Republic of the Congo'),
      UsVisaSuspendedCountry(code: 'BJ', nameFr: 'Bénin', nameEn: 'Benin'),
      UsVisaSuspendedCountry(
          code: 'CI', nameFr: 'Côte d\'Ivoire', nameEn: 'Côte d\'Ivoire'),
      UsVisaSuspendedCountry(code: 'SN', nameFr: 'Sénégal', nameEn: 'Senegal'),
      UsVisaSuspendedCountry(code: 'GA', nameFr: 'Gabon', nameEn: 'Gabon'),
      UsVisaSuspendedCountry(
          code: 'MR', nameFr: 'Mauritanie', nameEn: 'Mauritania'),
      UsVisaSuspendedCountry(code: 'BI', nameFr: 'Burundi', nameEn: 'Burundi'),
      UsVisaSuspendedCountry(code: 'TG', nameFr: 'Togo', nameEn: 'Togo'),
    ],
    lastVerifiedAt: DateTime(2026, 10, 17),
    sourceUrl: defaultSourceUrl,
  );

  /// Décode `usVisaSuspension`. Une clé absente ou illisible (serveur plus
  /// ancien) donne [fallback] ; une liste VIDE servie est respectée (`none`
  /// côté serveur : plus d'avis).
  factory UsVisaSuspension.fromJson(Object? raw) {
    if (raw is! Map || raw['countries'] is! List) return fallback;
    final countries = <UsVisaSuspendedCountry>[];
    final seen = <String>{};
    for (final entry in raw['countries'] as List) {
      if (entry is! Map) continue;
      final code = (entry['code'] as Object?)?.toString().trim().toUpperCase();
      if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) continue;
      if (!seen.add(code)) continue;
      String name(String key) {
        final value = entry[key];
        return value is String && value.trim().isNotEmpty ? value.trim() : code;
      }

      countries.add(UsVisaSuspendedCountry(
        code: code,
        nameFr: name('nameFr'),
        nameEn: name('nameEn'),
      ));
    }
    final url = raw['sourceUrl'];
    return UsVisaSuspension(
      countries: List.unmodifiable(countries),
      lastVerifiedAt: _parseDay(raw['lastVerifiedAt']),
      sourceUrl:
          url is String && isOpenableWebUrl(url.trim()) ? url.trim() : null,
    );
  }

  /// La liste, dans la langue de l'élève, séparée par des virgules.
  String namesFor(String localeCode) =>
      countries.map((c) => c.nameFor(localeCode)).join(', ');

  /// Le pays de résidence du profil est-il dans la liste ?
  ///
  /// `countryOfResidence` est un nom saisi (liste française de l'onboarding,
  /// texte libre dans le profil) : on compare des formes normalisées — code,
  /// nom français, nom anglais, alias connus.
  ///
  /// **Le sens de l'échec est choisi** : un pays vide, inconnu ou ambigu rend
  /// `false`, et l'avis reste général (il cite toujours la liste). « Congo »
  /// seul est ambigu (Brazzaville ou Kinshasa) : annoncer « Ton pays est
  /// concerné » à un élève de RD Congo serait faux.
  bool concerns(String? countryOfResidence) {
    final needle = normalize(countryOfResidence);
    if (needle.isEmpty || _ambiguous.contains(needle)) return false;
    for (final country in countries) {
      final forms = <String>{
        country.code.toLowerCase(),
        normalize(country.nameFr),
        normalize(country.nameEn),
        ...?_aliases[country.code],
      }..removeAll(_ambiguous);
      if (forms.contains(needle)) return true;
    }
    return false;
  }

  static const _ambiguous = {'congo'};

  static const _aliases = <String, Set<String>>{
    'BF': {'burkina'},
    'CG': {
      'republique du congo',
      'congo-brazzaville',
      'congo brazzaville',
      'republic of the congo',
      'congo (brazzaville)',
    },
    'CI': {'cote d\'ivoire', 'ivory coast', 'cote divoire'},
  };

  /// Minuscules, sans accents, apostrophes unifiées, espaces réduits.
  @visibleForTesting
  static String normalize(String? raw) {
    final trimmed = raw?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return '';
    const accents = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (char == '’' || char == "'") {
        buffer.write("'");
        continue;
      }
      final index = accents.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static DateTime? _parseDay(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
