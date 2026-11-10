// Le pliage de la recherche (audit avant la 59) : « senegal » doit trouver
// « Sénégal », « cote d'ivoire » doit trouver « Côte d’Ivoire ».

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/utils/search_text.dart';
import 'package:karatou/app/features/travel/airports_data.dart';

bool _finds(String query, String text) =>
    foldForSearch(text).contains(foldForSearch(query));

void main() {
  group('foldForSearch', () {
    test('retire les accents et met en minuscules', () {
      expect(foldForSearch('Sénégal'), 'senegal');
      expect(foldForSearch('INGÉNIERIE'), 'ingenierie');
      expect(foldForSearch('Français Langue Étrangère'),
          'francais langue etrangere');
    });

    test('ramène l\'apostrophe typographique à l\'apostrophe droite', () {
      expect(foldForSearch('Côte d’Ivoire'), "cote d'ivoire");
    });

    test('déplie les ligatures', () {
      expect(foldForSearch('Sœur'), 'soeur');
    });

    test('resserre les espaces, y compris insécables', () {
      expect(foldForSearch('  Master  en   droit '), 'master en droit');
    });

    test('laisse un texte vide vide', () {
      expect(foldForSearch(''), '');
      expect(foldForSearch('   '), '');
    });
  });

  group('ce que tape un élève sur un clavier sans accents', () {
    const cases = <String, String>{
      'senegal': 'Sénégal',
      'ingenierie': 'Licence en Ingénierie informatique',
      "cote d'ivoire": 'Côte d’Ivoire',
      'benin': 'Bénin',
      'genie civil': 'Génie civil',
      'etudes en france': 'Études en France',
    };
    cases.forEach((query, text) {
      test('« $query » trouve « $text »', () {
        expect(_finds(query, text), isTrue);
      });
    });

    test('et l\'inverse : une requête accentuée trouve un texte sans accents',
        () {
      expect(_finds('Sénégal', 'SENEGAL'), isTrue);
    });
  });

  test('les aéroports se trouvent sans accents', () {
    const airport = Airport('LFW', 'Lomé', 'Togo');
    expect(airport.matches('lome'), isTrue);
    expect(airport.matches('lfw'), isTrue);
    expect(airport.matches('dakar'), isFalse);
  });
}
