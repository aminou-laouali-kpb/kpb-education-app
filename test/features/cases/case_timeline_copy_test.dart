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
    r"table: '(?:CaseTimelineEvent|Case)',\s*colonne: '(description|nextStepDescription|nextStepTitle)',\s*(motif: true,\s*)?anglais:\s*'((?:[^'\\]|\\.)*)',\s*francais:\s*'((?:[^'\\]|\\.)*)'",
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
    // 11 descriptions de jalon + 8 descriptions et 6 titres d'étape à ce jour.
    expect(regles.length, greaterThanOrEqualTo(25));
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
      if (r.colonne == 'nextStepTitle') {
        expect(studentNextStepCopy(entree, localeCode: 'fr'), attendu,
            reason: '${r.colonne} : « $entree »');
      } else {
        expect(studentTimelineDescription(entree, localeCode: 'fr'), attendu,
            reason: '${r.colonne} : « $entree »');
        expect(studentNextStepCopy(entree, localeCode: 'fr'), attendu,
            reason: '${r.colonne} : « $entree »');
      }
    }
  });

  test('une phrase au « tu » écrite par un conseiller passe telle quelle', () {
    expect(
        studentTimelineDescription('Pense à signer ta lettre.',
            localeCode: 'fr'),
        'Pense à signer ta lettre.');
    expect(
        studentTimelineDescription('Prépare ton rendez-vous.',
            localeCode: 'fr'),
        'Prépare ton rendez-vous.');
  });

  test('vouvoiement, anglais et jargon inconnus sont masqués', () {
    expect(
        studentTimelineDescription('Merci de nous envoyer vos relevés.',
            localeCode: 'fr'),
        isNull);
    expect(
        studentTimelineDescription('Lead to follow up by admin.',
            localeCode: 'fr'),
        isNull);
    expect(
        studentTimelineDescription('Reassigned (round-robin).',
            localeCode: 'fr'),
        isNull);
    expect(studentTimelineDescription('   ', localeCode: 'fr'), isNull);
  });

  group('app en anglais (2e relecture #407)', () {
    test('le texte anglais légitime s’affiche tel quel, sans réécriture', () {
      const envoye = 'Your request was sent. A KPB counselor will reply soon.';
      expect(studentTimelineDescription(envoye, localeCode: 'en'), envoye);
      expect(
          studentTimelineDescription(
              'Awa Traoré is now the owner of this case.',
              localeCode: 'en'),
          'Awa Traoré is now the owner of this case.');
    });

    test('le jargon interne reste masqué dans toutes les langues', () {
      expect(
          studentTimelineDescription(
              'Auto-reassigned after 10h inactivity to Awa.',
              localeCode: 'en'),
          isNull);
      expect(
          studentTimelineDescription(
              'Awa was assigned automatically (round-robin).',
              localeCode: 'en'),
          isNull);
      expect(
          studentTimelineDescription(
              'The case was updated by an admin or counselor.',
              localeCode: 'en'),
          isNull);
    });

    test('« Prochaine étape » n’est pas réécrite en anglais', () {
      expect(
          studentNextStepCopy('Préparez votre rendez-vous', localeCode: 'en'),
          'Préparez votre rendez-vous');
    });
  });

  group('« Prochaine étape » en français', () {
    test('réécrite au « tu » quand une règle la reconnaît', () {
      expect(
          studentNextStepCopy('Préparez votre rendez-vous', localeCode: 'fr'),
          'Prépare ton rendez-vous');
      expect(
          studentNextStepCopy(
              'Confirmez votre disponibilité et préparez vos pièces justificatives.',
              localeCode: 'fr'),
          'Confirme ta disponibilité et prépare tes pièces justificatives.');
    });

    test('un texte inconnu n’est jamais effacé', () {
      expect(studentNextStepCopy('Envoyez vos relevés', localeCode: 'fr'),
          'Envoyez vos relevés');
    });
  });
}
