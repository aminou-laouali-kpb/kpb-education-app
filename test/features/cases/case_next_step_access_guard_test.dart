// Troisième relecture de la PR #407 : « Prochaine étape » était réécrite au
// « tu » sur la fiche du dossier seulement ; l'accueil, la liste, le
// calendrier et les notifications relisaient le champ brut et restaient au
// « vous ». Toute surface élève doit passer par `nextStepTitleFor` /
// `nextStepDescriptionFor` (case_timeline_copy.dart). Ce garde échoue si un
// écran relit le champ brut avec `resolve(x.nextStepTitle)`.
//
// Hors champ, et c'est voulu : le modèle, le codec, le cache, le contrôleur
// (qui ÉCRIVENT le champ) et l'espace parent, qui lit des JSON bruts et ne
// s'adresse pas à l'élève.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _accesUnique = 'lib/app/features/cases/case_timeline_copy.dart';

void main() {
  test('aucun écran ne relit nextStepTitle / nextStepDescription bruts', () {
    final lecture =
        RegExp(r'resolve\(\s*[\w.!]+\.nextStep(Title|Description)\s*\)|'
            r'\.nextStep(Title|Description)\s*\.resolve\(');
    final fautifs = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path == _accesUnique) continue;
      // Sur le fichier entier, pas ligne à ligne : `dart format` peut couper
      // `resolve(\n item.nextStepTitle)` sur deux lignes.
      final texte = f.readAsStringSync();
      for (final m in lecture.allMatches(texte)) {
        final ligne = '\n'.allMatches(texte.substring(0, m.start)).length + 1;
        fautifs.add('${f.path}:$ligne  ${m.group(0)}');
      }
    }
    expect(fautifs, isEmpty,
        reason: 'Passe par controller.nextStepTitleFor(c) / '
            'nextStepDescriptionFor(c) :\n${fautifs.join('\n')}');
  });

  test('le garde voit bien le motif qu’il interdit (garde contre un test vide)',
      () {
    final lecture =
        RegExp(r'resolve\(\s*[\w.!]+\.nextStep(Title|Description)\s*\)|'
            r'\.nextStep(Title|Description)\s*\.resolve\(');
    expect(lecture.hasMatch('controller.resolve(item.nextStepTitle),'), isTrue);
    expect(lecture.hasMatch('ctrl.resolve(c.nextStepDescription);'), isTrue);
    expect(lecture.hasMatch('controller.nextStepTitleFor(item),'), isFalse);
  });
}
