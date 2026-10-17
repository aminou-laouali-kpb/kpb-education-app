// La liste des pays dont les visas étudiants américains sont suspendus :
// décodage de `/config/app`, repli embarqué, et comparaison au pays du profil.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/us_visa_suspension.dart';

void main() {
  group('fromJson', () {
    test('clé absente ou illisible (serveur plus ancien) : le repli embarqué',
        () {
      expect(UsVisaSuspension.fromJson(null), same(UsVisaSuspension.fallback));
      expect(UsVisaSuspension.fromJson({'countries': 'BF'}),
          same(UsVisaSuspension.fallback));
    });

    test('une liste vide servie est respectée : plus d\'avis', () {
      final served = UsVisaSuspension.fromJson({'countries': <Object>[]});
      expect(served.isActive, isFalse);
    });

    test('décode codes, noms, jour et source ; écarte le reste', () {
      final served = UsVisaSuspension.fromJson({
        'countries': [
          {'code': 'ng', 'nameFr': 'Nigeria', 'nameEn': 'Nigeria'},
          {'code': 'NG', 'nameFr': 'doublon'},
          {'code': 'XYZ'},
          'BF',
          {'code': 'SL'},
        ],
        'lastVerifiedAt': '2026-11-02',
        'sourceUrl': 'javascript:alert(1)',
      });
      expect(served.countries.map((c) => c.code), ['NG', 'SL']);
      expect(served.countries[1].nameFr, 'SL',
          reason: 'sans nom servi, le code tient lieu de nom');
      expect(served.lastVerifiedAt, DateTime(2026, 11, 2));
      expect(served.sourceUrl, isNull,
          reason: 'un lien non https n\'atteint pas de bouton');
      expect(
        UsVisaSuspension.fromJson({
          'countries': <Object>[],
          'lastVerifiedAt': '2026-02-30',
        }).lastVerifiedAt,
        isNull,
      );
    });
  });

  group('concerns — le pays de résidence du profil', () {
    final list = UsVisaSuspension.fallback;

    test('noms français, anglais, codes, casse et accents', () {
      for (final typed in [
        'Burkina Faso',
        'burkina',
        'SÉNÉGAL',
        'Senegal',
        'Côte d\'Ivoire',
        'Cote d’Ivoire',
        'Ivory Coast',
        'CI',
        'Tchad',
        'Chad',
        'Bénin',
        'Mauritanie',
        'Congo-Brazzaville',
        'République du Congo',
        'Togo',
        'Burundi',
      ]) {
        expect(list.concerns(typed), isTrue, reason: typed);
      }
    });

    test('pays non listé, vide ou ambigu : avis général, jamais « concerné »',
        () {
      for (final typed in [
        null,
        '',
        '   ',
        'Nigeria',
        'Cameroun',
        'France',
        'Autre',
        // Brazzaville ou Kinshasa : on ne sait pas.
        'Congo',
        'RD Congo',
      ]) {
        expect(list.concerns(typed), isFalse, reason: '$typed');
      }
    });
  });

  test('la liste affichée suit la langue', () {
    expect(UsVisaSuspension.fallback.namesFor('fr'),
        startsWith('Burkina Faso, Mali, Niger, Tchad, Congo, Bénin'));
    expect(UsVisaSuspension.fallback.namesFor('en'), contains('Chad'));
  });

  test('le repli embarqué est EXACTEMENT le défaut du serveur', () {
    // Deux copies d'une même liste vérifiée : si l'une bouge sans l'autre, un
    // téléphone hors ligne afficherait une autre liste que le serveur.
    final server = File('backend/src/modules/config/us-visa-suspension.ts')
        .readAsStringSync();
    final block = RegExp(
      r'DEFAULT_US_VISA_SUSPENDED_COUNTRIES[^=]*=\s*\[([^\]]*)\]',
    ).firstMatch(server)!;
    final codes = RegExp(r"'([A-Z]{2})'")
        .allMatches(block.group(1)!)
        .map((m) => m.group(1))
        .toList();
    expect(UsVisaSuspension.fallback.countries.map((c) => c.code), codes);
    expect(server,
        contains("DEFAULT_US_VISA_SUSPENSION_VERIFIED_AT = '2026-10-17'"));
    expect(UsVisaSuspension.fallback.lastVerifiedAt, DateTime(2026, 10, 17));
    expect(server.replaceAll(RegExp(r"'\s*\+\s*'"), ''),
        contains(UsVisaSuspension.defaultSourceUrl));
  });
}
