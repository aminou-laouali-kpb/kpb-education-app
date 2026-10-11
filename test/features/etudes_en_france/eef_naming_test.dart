// Le cliquet de nommage.
//
// La décision : l'espace s'appelle « Études en France », pas « Campus France ».
// Campus France est un opérateur de l'État français et rien dans ce dépôt
// n'atteste d'un partenariat — le seul endroit qui le cite comme partenaire est
// un commentaire de `partners.service.ts`. Nommer un espace commercial d'après
// l'agence exposerait à une réclamation et laisserait croire à l'étudiant qu'il
// est sur un canal officiel.
//
// Sans ce fichier, la décision se perd au premier ajout de chaîne : elle vit
// aujourd'hui dans un document et dans des commentaires, c'est-à-dire nulle
// part pour la CI. Ici elle a une contre-épreuve.
//
// Ce que la règle AUTORISE : nommer Campus France dans du texte de CORPS, pour
// s'en distinguer. La mention de non-affiliation doit le nommer — c'est même
// tout son objet. Ce qui est interdit, c'est de l'utiliser comme ENSEIGNE (un
// titre, un libellé, un en-tête) ou comme IDENTIFIANT technique.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_routes.dart';

/// Les clés qui servent d'enseigne : titres, libellés, en-têtes, boutons.
final _brandKeyPattern = RegExp(
  r"^eef_("
  r"title|"
  r".*_title|"
  r".*_label|"
  r".*_heading|"
  r".*_cta|"
  r"status_.*|"
  r"cta_declare"
  r")$",
);

/// « campus france », insensible à la casse, aux espaces et aux séparateurs.
/// Écrit ainsi pour qu'un `CampusFrance`, un `campus_france` ou un
/// `campus-france` soient attrapés par la même règle.
final _campusFrance = RegExp(r'campus[\s_-]*france', caseSensitive: false);

Map<String, String> _eefKeysOf(String localeBlock) {
  final out = <String, String>{};
  // Capture la clé et tout ce qui suit jusqu'à la prochaine clé — les valeurs
  // sont souvent réparties sur plusieurs lignes concaténées par le formateur.
  final entries = RegExp(
    r"'(eef_[a-z0-9_]+)':\s*((?:.|\n)*?)(?=\n\s*'[a-z0-9_]+':|\n\s*\},)",
  );
  for (final match in entries.allMatches(localeBlock)) {
    out[match.group(1)!] = match.group(2)!;
  }
  return out;
}

void main() {
  final frBlock = File('lib/app/core/translations/app_translations_fr.dart')
      .readAsStringSync();
  final enBlock = File('lib/app/core/translations/app_translations_en.dart')
      .readAsStringSync();

  group('les traductions', () {
    test('les deux langues déclarent exactement les mêmes clés eef_', () {
      final fr = _eefKeysOf(frBlock).keys.toSet();
      final en = _eefKeysOf(enBlock).keys.toSet();

      expect(fr, isNotEmpty, reason: 'le lecteur de clés ne trouve rien');
      expect(fr.difference(en), isEmpty, reason: 'clés absentes en anglais');
      expect(en.difference(fr), isEmpty, reason: 'clés absentes en français');
    });

    test('aucune clé d\'enseigne ne porte « Campus France »', () {
      for (final block in [frBlock, enBlock]) {
        final offenders = <String>[];
        _eefKeysOf(block).forEach((key, value) {
          if (_brandKeyPattern.hasMatch(key) && _campusFrance.hasMatch(value)) {
            offenders.add(key);
          }
        });

        expect(
          offenders,
          isEmpty,
          reason: 'Ces clés servent d\'enseigne et nomment l\'agence : '
              '$offenders. On nomme la PROCÉDURE (« Études en France »). '
              'Citer Campus France reste permis dans du texte de corps, pour '
              's\'en distinguer.',
        );
      }
    });

    // La contre-épreuve de la règle : la mention de non-affiliation DOIT
    // nommer Campus France, sinon elle ne distingue rien. Sans ce test, on
    // pourrait satisfaire le précédent en supprimant la mention — c'est-à-dire
    // en aggravant précisément le risque qu'elle couvre.
    test('la mention de non-affiliation nomme bien l\'agence', () {
      for (final block in [frBlock, enBlock]) {
        final notice = _eefKeysOf(block)['eef_affiliation_notice'];
        expect(notice, isNotNull);
        expect(_campusFrance.hasMatch(notice!), isTrue,
            reason: 'Une mention de non-affiliation qui ne nomme pas '
                'l\'organisme dont on se distingue ne distingue rien.');
      }
    });
  });

  group('les identifiants techniques', () {
    test('la route nomme la procédure', () {
      expect(AppRoutes.etudesEnFrance, '/etudes-en-france');
      expect(_campusFrance.hasMatch(AppRoutes.etudesEnFrance), isFalse);
    });

    // Les identifiants partent dans les liens profonds, les variables
    // d'environnement que l'exploitation lit, et les tableaux de bord
    // analytiques. Un nom d'agence y serait aussi visible qu'à l'écran.
    test('aucun identifiant du module ne contient « campus france »', () {
      final offenders = <String>[];

      final files = [
        ...Directory('lib/app/features/etudes_en_france')
            .listSync(recursive: true)
            .whereType<File>(),
        File('lib/app/core/data/eef_calendar.dart'),
        File('lib/app/core/models/eef.dart'),
        File('lib/app/core/services/remote_feature_flags.dart'),
      ];

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        for (final line in file.readAsLinesSync()) {
          final code = line.trim();
          // Les commentaires ont le droit d'EXPLIQUER la décision — c'est
          // même là qu'elle se justifie. On ne juge que le code.
          if (code.startsWith('//') || code.startsWith('///')) continue;
          if (_campusFrance.hasMatch(code)) {
            offenders.add('${file.path}: $code');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('les drapeaux serveur sont préfixés KPB_EEF_', () {
      final config =
          File('lib/app/core/config/app_config.dart').readAsStringSync();
      expect(config, contains("'KPB_EEF_TEASER_ENABLED'"));
      expect(config, contains("'KPB_EEF_ENABLED'"));
      expect(config, contains("'KPB_EEF_SPACE_ENABLED'"));
    });
  });
}
