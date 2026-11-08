// La table de l'app (`case_timeline_copy.dart`) doit rester collée à la
// reprise serveur (`backend/src/modules/cases/legacy-english-copy.ts`) : on
// lit les règles du fichier TypeScript lui-même et on rejoue chacune côté app.
// Si quelqu'un ajoute ou reformule une règle serveur sans suivre ici, l'élève
// verrait la description brute masquée (au mieux) ou un texte différent selon
// que la reprise a tourné ou non — ce test le fait échouer avant.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/features/cases/case_timeline_copy.dart';

class _RegleTs {
  _RegleTs(this.colonne, this.motif, this.source, this.cible);
  final String colonne;
  final bool motif;
  final String source;
  final String cible;
}

/// Déséchappe un littéral TS entre apostrophes (`\\.` → `\.`, `\'` → `'`).
String _litteral(String s) =>
    s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!);

List<_RegleTs> _reglesServeur() {
  final src = File('backend/src/modules/cases/legacy-english-copy.ts')
      .readAsStringSync();
  final re = RegExp(
    r"table: '(?:CaseTimelineEvent|Case)',\s*colonne: '(description|nextStepDescription)',\s*(motif: true,\s*)?anglais:\s*'((?:[^'\\]|\\.)*)',\s*francais:\s*'((?:[^'\\]|\\.)*)'",
  );
  return [
    for (final m in re.allMatches(src))
      _RegleTs(m.group(1)!, m.group(2) != null, _litteral(m.group(3)!),
          _litteral(m.group(4)!)),
  ];
}

void main() {
  final regles = _reglesServeur();

  test('la table serveur est bien lue (garde contre un test vide)', () {
    // 11 descriptions de jalon + 8 descriptions d'étape à ce jour.
    expect(regles.length, greaterThanOrEqualTo(19));
  });

  test('chaque règle serveur donne le même texte côté app', () {
    const nom = 'Awa Traoré';
    for (final r in regles) {
      final entree = r.motif
          ? r.source
              .replaceAll('^', '')
              .replaceAll(r'$', '')
              .replaceAll('(.+)', nom)
              .replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!)
          : r.source;
      final attendu = r.cible.replaceAll(r'\1', nom);
      expect(studentTimelineDescription(entree), attendu,
          reason: '${r.colonne} : « $entree »');
    }
  });

  test('une phrase au « tu » écrite par un conseiller passe telle quelle', () {
    expect(studentTimelineDescription('Pense à signer ta lettre.'),
        'Pense à signer ta lettre.');
    expect(studentTimelineDescription('Prépare ton rendez-vous.'),
        'Prépare ton rendez-vous.');
  });

  test('vouvoiement, anglais et jargon inconnus sont masqués', () {
    expect(studentTimelineDescription('Merci de nous envoyer vos relevés.'),
        isNull);
    expect(studentTimelineDescription('Lead to follow up by admin.'), isNull);
    expect(studentTimelineDescription('Reassigned (round-robin).'), isNull);
    expect(studentTimelineDescription('   '), isNull);
  });
}
