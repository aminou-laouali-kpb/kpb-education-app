// La table mondiale des pays et des indicatifs (inscription).
//
// Elle est GÉNÉRÉE (scripts/generate-world-countries.js) depuis la table ISO
// du serveur et depuis libphonenumber. Ces tests ne font pas confiance au
// générateur : ils relisent la table du serveur, et ils comparent quelques
// indicatifs à des valeurs écrites ici à la main (source : plan de
// numérotation de l'UIT), indépendantes de libphonenumber.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/data/world_countries.dart';
import 'package:karatou/app/core/utils/search_text.dart';

/// Le pli du serveur (`foldCountryText`) : minuscules, sans accents, toute
/// suite de caractères non alphanumériques réduite à une espace.
String serverFold(String value) =>
    foldForSearch(value).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

typedef IsoRow = ({String alpha3, String alpha2, List<String> forms});

/// Les lignes de `backend/src/common/iso-countries.ts`, pays inhabités exclus.
List<IsoRow> readServerRows() {
  final source = File('backend/src/common/iso-countries.ts').readAsStringSync();
  final start = source.indexOf('const ROWS');
  final body = source.substring(
      source.indexOf('= [', start) + 3, source.indexOf('\n];', start));
  final uninhabited = RegExp(r'const UNINHABITED = new Set\(\[([^\]]*)\]\)')
      .firstMatch(source)!
      .group(1)!;
  final skipped = RegExp(r"'([a-z]{3})'")
      .allMatches(uninhabited)
      .map((m) => m.group(1)!)
      .toSet();
  final literal = RegExp(r"'((?:[^'\\]|\\.)*)'");
  final rows = <IsoRow>[];
  for (final row in RegExp(r'\[([^\[\]]*)\]').allMatches(body)) {
    final cells = literal
        .allMatches(row.group(1)!)
        .map((m) => m.group(1)!.replaceAll(r"\'", "'"))
        .toList();
    if (skipped.contains(cells[0])) continue;
    rows.add((alpha3: cells[0], alpha2: cells[1], forms: cells.sublist(2)));
  }
  return rows;
}

/// Pays proposés par l'app que la table du serveur ne porte pas encore (hors
/// norme ISO 3166-1). Le serveur lit leur nom comme un pays inconnu, comme
/// « Autre » : pas de fuseau horaire propre, pas d'éligibilité par pays.
/// Même liste que `EXTRA_COUNTRIES` dans scripts/generate-world-countries.js.
const appOnlyIso2 = {'XK'};

void main() {
  group('accord avec la table du serveur', () {
    final rows = readServerRows();

    test('la lecture de la table du serveur n\'est pas une garde morte', () {
      expect(rows.length, greaterThanOrEqualTo(240));
      expect(rows.any((r) => r.alpha2 == 'NE'), isTrue);
      // Les lignes écrites sur plusieurs lignes (alias nombreux) sont lues.
      expect(rows.any((r) => r.alpha2 == 'CD'), isTrue);
      expect(rows.any((r) => r.alpha2 == 'US'), isTrue);
    });

    test(
        'tous les pays habités du serveur sont proposés, et aucun autre '
        'que les exceptions nommées', () {
      expect(
        worldCountries.map((c) => c.iso2).toSet(),
        {...rows.map((r) => r.alpha2), ...appOnlyIso2},
      );
    });

    test('une exception disparaît le jour où le serveur connaît le pays', () {
      // Sinon la liste d'exceptions masquerait un désaccord réel.
      final known = rows.map((r) => r.alpha2).toSet();
      expect(appOnlyIso2.intersection(known), isEmpty,
          reason: 'Le serveur connaît maintenant ce pays : retire-le de '
              'appOnlyIso2 et de EXTRA_COUNTRIES.');
      expect(worldCountryByIso2('XK')?.nameFr, 'Kosovo');
      expect(worldCountryByIso2('XK')?.dialCode, '+383');
    });

    test(
        'le nom ENREGISTRÉ de chaque pays est relu par le serveur comme ce '
        'pays-là, et aucun autre', () {
      // `countryOfResidence` part au serveur sous `nameFr` ; le serveur le
      // résout par nom français, nom anglais ou alias, après pliage. Un nom
      // qu'il ne relirait pas donnerait un profil « pays inconnu » : pas de
      // fuseau horaire, pas d'éligibilité par pays.
      final owners = <String, Set<String>>{};
      for (final row in rows) {
        for (final form in [row.alpha3, row.alpha2, ...row.forms]) {
          owners.putIfAbsent(serverFold(form), () => {}).add(row.alpha2);
        }
      }
      final wrong = [
        for (final country in worldCountries)
          if (appOnlyIso2.contains(country.iso2))
            // Le serveur ne doit PAS le prendre pour un autre pays.
            if (owners.containsKey(serverFold(country.nameFr)))
              '${country.iso2} « ${country.nameFr} » est lu comme '
                  '${owners[serverFold(country.nameFr)]}'
            else
              ...const <String>[]
          else if (owners[serverFold(country.nameFr)]?.length != 1 ||
              owners[serverFold(country.nameFr)]!.single != country.iso2)
            '${country.iso2} « ${country.nameFr} » → '
                '${owners[serverFold(country.nameFr)]}',
      ];
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });
  });

  group('la table', () {
    test('un indicatif est « + » et des chiffres, rien d\'autre', () {
      final pattern = RegExp(r'^\+\d{1,4}$');
      final wrong = [
        for (final c in worldCountries)
          if (!pattern.hasMatch(c.dialCode)) '${c.iso2} ${c.dialCode}',
      ];
      expect(wrong, isEmpty);
    });

    test('codes et noms sont uniques : une valeur enregistrée = un pays', () {
      final codes = worldCountries.map((c) => c.iso2).toList();
      expect(codes.toSet().length, codes.length);
      expect(codes.every(RegExp(r'^[A-Z]{2}$').hasMatch), isTrue);
      final names = worldCountries.map((c) => foldForSearch(c.nameFr)).toList();
      expect(names.toSet().length, names.length);
    });

    test('les bornes par pays élargissent, elles ne resserrent jamais', () {
      for (final c in worldCountries) {
        expect(c.minDigits, lessThanOrEqualTo(WorldCountry.defaultMinDigits),
            reason: c.iso2);
        expect(c.maxDigits, greaterThanOrEqualTo(WorldCountry.defaultMaxDigits),
            reason: c.iso2);
        expect(c.minDigits, greaterThanOrEqualTo(4), reason: c.iso2);
        expect(c.maxDigits, lessThanOrEqualTo(15), reason: c.iso2);
      }
    });

    test('indicatifs comparés à une liste écrite à la main (UIT)', () {
      // Des pays que l'ancienne liste n'avait pas, sur tous les continents.
      const expected = {
        'KE': '+254', 'EG': '+20', 'ET': '+251', 'TZ': '+255', 'UG': '+256', //
        'AO': '+244', 'MZ': '+258', 'SD': '+249', 'LY': '+218', 'ZA': '+27',
        'GQ': '+240', 'ST': '+239', 'MU': '+230', 'SC': '+248', 'SO': '+252',
        'ER': '+291', 'SS': '+211', 'ZM': '+260', 'ZW': '+263', 'MW': '+265',
        'HT': '+509', 'LB': '+961', 'SA': '+966', 'AE': '+971', 'QA': '+974',
        'IN': '+91', 'CN': '+86', 'JP': '+81', 'BR': '+55', 'RU': '+7',
        'IT': '+39', 'PT': '+351', 'NL': '+31', 'LU': '+352', 'SE': '+46',
        'AU': '+61', 'MX': '+52', 'PK': '+92', 'BD': '+880', 'ID': '+62',
      };
      expected.forEach((iso2, dialCode) {
        expect(worldCountryByIso2(iso2)?.dialCode, dialCode, reason: iso2);
      });
    });

    test('le drapeau vient du code ISO', () {
      expect(worldCountryByIso2('NE')!.flag, '🇳🇪');
      expect(worldCountryByIso2('ke')!.flag, '🇰🇪');
    });
  });

  group('rien ne change pour les pays de l\'ancienne liste', () {
    // Les 34 pays et les 37 indicatifs que l'inscription proposait, tels
    // qu'ils étaient écrits : mêmes noms enregistrés, mêmes indicatifs.
    const before = {
      'Niger': '+227', 'Nigeria': '+234', 'Sénégal': '+221', //
      'Côte d\'Ivoire': '+225', 'Mali': '+223', 'Guinée': '+224',
      'Burkina Faso': '+226', 'Togo': '+228', 'Bénin': '+229',
      'Mauritanie': '+222', 'Ghana': '+233', 'Cameroun': '+237',
      'Sierra Leone': '+232', 'Gambie': '+220', 'Liberia': '+231',
      'Guinée-Bissau': '+245', 'Cap-Vert': '+238', 'RD Congo': '+243',
      'Congo': '+242', 'Gabon': '+241', 'Tchad': '+235',
      'Centrafrique': '+236', 'Madagascar': '+261', 'Rwanda': '+250',
      'Burundi': '+257', 'Djibouti': '+253', 'Comores': '+269',
      'Tunisie': '+216', 'Algérie': '+213', 'France': '+33', 'Canada': '+1',
      'Royaume-Uni': '+44', 'Allemagne': '+49', 'Maroc': '+212',
      'Turquie': '+90', 'Espagne': '+34', 'États-Unis': '+1',
      'Belgique': '+32', 'Suisse': '+41',
    };

    test('même nom enregistré, même indicatif', () {
      before.forEach((name, dialCode) {
        final country = worldCountryByName(name);
        expect(country, isNotNull, reason: name);
        expect(country!.nameFr, name);
        expect(country.dialCode, dialCode, reason: name);
      });
    });

    test('le Niger reste en tête : l\'indicatif par défaut ne change pas', () {
      final ordered = worldCountriesInListOrder('fr');
      expect(ordered.first.iso2, 'NE');
      expect(ordered.length, worldCountries.length);
      expect(ordered.map((c) => c.iso2).toSet().length, ordered.length);
      expect(
        ordered.take(priorityCountryIso2.length).map((c) => c.iso2),
        priorityCountryIso2,
      );
    });
  });

  test('en anglais, le reste de la liste suit l\'ordre des noms anglais', () {
    final rest = worldCountriesInListOrder('en')
        .skip(priorityCountryIso2.length)
        .map((c) => foldForSearch(c.nameFor('en')))
        .toList();
    expect(rest, [...rest]..sort());
    expect(worldCountryByIso2('DE')!.nameFor('en'), 'Germany');
    expect(worldCountryByIso2('DE')!.nameFor('fr'), 'Allemagne');
    expect(worldCountryByIso2('DE')!.nameFor(null), 'Allemagne');
  });

  group('retrouver un pays', () {
    test('par nom tapé sans majuscule ni accent, en français ou en anglais',
        () {
      expect(worldCountryByName('senegal')?.iso2, 'SN');
      expect(worldCountryByName('  NIGER ')?.iso2, 'NE');
      expect(worldCountryByName('Ivory Coast'), isNull); // alias du serveur
      expect(worldCountryByName('Germany')?.iso2, 'DE');
      expect(worldCountryByName('Côte d’Ivoire')?.iso2, 'CI');
    });

    test('« Autre », vide ou inconnu : aucun pays, on ne devine pas', () {
      expect(worldCountryByName('Autre'), isNull);
      expect(worldCountryByName(''), isNull);
      expect(worldCountryByName(null), isNull);
      expect(worldCountryByName('Atlantide'), isNull);
    });
  });

  group('recherche', () {
    final all = worldCountriesInListOrder('fr');
    List<String> found(String query) =>
        filterWorldCountries(all, query).map((c) => c.iso2).toList();

    test('requête vide : toute la liste, dans son ordre', () {
      expect(filterWorldCountries(all, '  '), all);
    });

    test('sans accent, et dans les deux langues', () {
      expect(found('cote'), contains('CI'));
      expect(found('keny'), ['KE']);
      expect(found('egypt'), ['EG']);
      expect(found('égyp'), ['EG']);
    });

    test('par indicatif, avec ou sans « + »', () {
      expect(found('254'), ['KE']);
      expect(found('+254'), ['KE']);
      expect(found('+1'), containsAll(['US', 'CA']));
      // « 22 » : tous les indicatifs qui commencent par 22, Niger en tête.
      expect(found('22').first, 'NE');
    });

    test('par code ISO', () {
      expect(found('ke'), contains('KE'));
    });

    test('rien ne correspond : liste vide', () {
      expect(found('zzzz'), isEmpty);
    });
  });
}
