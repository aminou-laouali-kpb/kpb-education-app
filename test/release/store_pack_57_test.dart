// Les papiers de la build 57 disent des chiffres et des faits du code : on les
// recompte et on les relit contre le code.
//
// Même principe que `store_pack_56_test.dart` pour le bloc « Notes for Review »
// (décompte recalculé, déclarations d'activation à distance LIÉES à leur
// phrase). En plus, ce que la 57 ajoute aux papiers :
//
// - le tableau des drapeaux du pack doit lister CHAQUE clé `features.*` que sert
//   `app-config.controller.ts`, avec son vrai défaut (fermé / ouvert) : une clé
//   ajoutée au contrôleur sans ligne au tableau rougit ;
// - `KPB_RECOMMENDED_APP_VERSION` reçoit la VERSION MARKETING parce que le code
//   ignore le numéro de build : le test vérifie que c'est toujours vrai dans
//   `version_utils.dart` et `app_version_gate.dart`, sinon la consigne ment ;
// - la politique de confidentialité (in-app FR + EN, page web) dit la collecte
//   de la nationalité, l'absence de transmission aux écoles, la conservation et
//   les mineurs de 16 et 17 ans ;
// - la fiche de recette couvre ce que la mission exige, cases vides.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _reserveAddress = 40;
const _reserveMethod = 120;
const _appleLimit = 4000;
const _minMargin = 50;
const _playLimit = 500;

const _packPath = 'docs/release-57-store-pack.md';
const _qaPath = 'docs/device-qa-build57.md';
const _controllerPath = 'backend/src/modules/config/app-config.controller.ts';

String _read(String path) => File(path).readAsStringSync();

String _flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

String _notesBlock(String pack) {
  final match = RegExp(
    r'```\n(SIGN-IN\n.*?)\n```',
    dotAll: true,
  ).firstMatch(pack);
  if (match == null) {
    throw TestFailure(
      'le pack 57 ne contient plus le bloc « Notes for Review » '
      '(une clôture qui commence par SIGN-IN)',
    );
  }
  return match.group(1)!;
}

String _filled(String block) => block
    .replaceAll('<ADDRESS>', 'x' * _reserveAddress)
    .replaceAll('<METHOD>', 'x' * _reserveMethod);

/// Le texte d'une section « ## n. … » jusqu'à la suivante.
String _section(String doc, String headingStart) {
  final start = doc.indexOf(headingStart);
  if (start == -1) {
    throw TestFailure('la section « $headingStart » a disparu');
  }
  final rest = doc.substring(start + headingStart.length);
  final end = rest.indexOf(RegExp(r'^## ', multiLine: true));
  return end == -1 ? rest : rest.substring(0, end);
}

/// Les clés de `features: { … }` dans le contrôleur, avec le texte qui calcule
/// chacune (l'expression de la clé, ou la déclaration `const clé = …;` pour une
/// clé abrégée).
Map<String, String> _controllerFeatures() {
  final source = _read(_controllerPath);
  final start = source.indexOf('      features: {');
  if (start == -1) {
    throw TestFailure('features: { introuvable dans le contrôleur');
  }
  final end = source.indexOf('\n      },', start);
  final block = source.substring(start, end);
  final keyLine = RegExp(r'^ {8}([a-zA-Z0-9]+)(:|,)', multiLine: true);
  final matches = keyLine.allMatches(block).toList();
  final out = <String, String>{};
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final key = m.group(1)!;
    final next = i + 1 < matches.length ? matches[i + 1].start : block.length;
    var expression = block.substring(m.start, next);
    if (m.group(2) == ',') {
      // Clé abrégée : l'expression vit dans `const clé = …;` plus haut.
      final decl = RegExp('const $key\\s*=([^;]*);').firstMatch(source);
      expression = decl?.group(1) ?? '';
    }
    out[key] = expression;
  }
  return out;
}

void main() {
  group('Pack de soumission de la build 57', () {
    final pack = _read(_packPath);
    final block = _notesBlock(pack);
    final filled = _filled(block);

    test('le texte à coller tient sous 4 000 caractères, marge comprise', () {
      expect(block, contains('<ADDRESS>'));
      expect(block, contains('<METHOD>'));
      expect(
        filled.length,
        lessThanOrEqualTo(_appleLimit - _minMargin),
        reason: '${filled.length} caractères une fois les réserves posées',
      );
      expect(_utf8Length(filled), lessThanOrEqualTo(_appleLimit));
    });

    test('le décompte affiché par le document est le vrai', () {
      final stamp = RegExp(
        r'<!-- notes-for-review: chars=(\d+) bytes=(\d+) reserve=(\d+) -->',
      ).firstMatch(pack);
      expect(stamp, isNotNull);
      expect(int.parse(stamp!.group(3)!), _reserveAddress + _reserveMethod);
      expect(
        filled.length,
        int.parse(stamp.group(1)!),
        reason: 'le document annonce ${stamp.group(1)} caractères, il y en '
            'a ${filled.length}',
      );
      expect(_utf8Length(filled), int.parse(stamp.group(2)!));
      expect(
        pack,
        contains('${_thousands(filled.length)} caractères'),
        reason: 'la prose ne répète pas le décompte',
      );
    });

    test('rien de ce qui doit survivre au raccourcissement n\'a disparu', () {
      for (final needle in [
        'guideline 2.3.1',
        'api.kpbeducation.cloud/api/config/app',
        'update available',
        'NOT AFFILIATED WITH ANY GOVERNMENT',
        'not affiliated with Campus France',
        'excluded from our advisors\' call lists',
        'no in-app purchase',
        'AI consent',
        'Accounts require 16+',
        'Firebase Cloud Messaging',
        'OneSignal SDK is removed',
        'never asked at launch',
        'never a percentage',
        'not sent to schools',
      ]) {
        expect(
          block.toLowerCase(),
          contains(needle.toLowerCase()),
          reason: 'le texte à coller ne contient plus « $needle »',
        );
      }
    });

    test('chaque drapeau fermé est déclaré « OFF at review time », lié', () {
      // Les quatre noms suivent UNE phrase « OFF at review time: », dans cet
      // ordre : la disparition de l'un ne se cache pas derrière les autres.
      expect(
        block,
        matches(
          RegExp(
            r'OFF at review time: features\.scholarshipMatch,[^\n]*'
            r'features\.onboardingV2,[^\n]*'
            r'features\.eefHelpBubble and features\.eefPrivateSchools',
          ),
        ),
      );
      expect(
        RegExp(r'\bON at review time').hasMatch(block),
        isFalse,
        reason: 'un drapeau y est déclaré « ON at review time »',
      );
      // Le test d'éligibilité est décrit pour ce qu'il collecte.
      expect(block, contains('nationality, date of birth'));
    });

    test('le texte ne promet rien, ne chiffre rien, sans pourcentage', () {
      final lower = block.toLowerCase();
      for (final banned in ['guarantee', '€', ' eur ', '%', 'chance']) {
        expect(
          lower.contains(banned),
          isFalse,
          reason: 'le texte à coller contient « $banned »',
        );
      }
    });

    test('les notes Google Play tiennent sous 500 caractères', () {
      final start = pack.indexOf('**Google Play — FR');
      expect(start, isNot(-1));
      final play = RegExp(
        r'```\n(.*?)\n```',
        dotAll: true,
      ).firstMatch(pack.substring(start))!.group(1)!;
      expect(
        play.runes.length,
        lessThanOrEqualTo(_playLimit),
        reason: '${play.runes.length} caractères',
      );
      // Rien de fermé n'est vanté dans les textes à coller des notes de version
      // (la prose du §2 a le droit de dire ce qu'ils ne montrent pas).
      final notes = RegExp(r'```\n(.*?)\n```', dotAll: true)
          .allMatches(_section(pack, '## 2. Notes de version'))
          .map((m) => m.group(1)!)
          .join('\n');
      expect(notes, isNotEmpty);
      for (final closed in [
        'Mes 10 bourses',
        'My 10 scholarships',
        'éligibilité',
        'eligibility',
      ]) {
        expect(
          notes.contains(closed),
          isFalse,
          reason: 'les notes de version vantent « $closed », fermé à '
              'l\'approbation',
        );
      }
    });

    test('les chemins cités mènent à un fichier qui existe', () {
      final links = RegExp(
        r'`((?:docs|scripts|test|lib|backend|web|\.github)/[A-Za-z0-9_./-]+\.[a-z]+)`',
      ).allMatches(pack).map((m) => m.group(1)!).toSet();
      expect(links, contains('docs/mise-a-jour-57-checklist.md'));
      expect(links, contains('docs/device-qa-build57.md'));
      for (final link in links) {
        expect(
          File(link).existsSync(),
          isTrue,
          reason: 'le pack cite `$link`, qui n\'existe pas',
        );
      }
    });

    test('les points juridiques non tranchés sont marqués À VALIDER', () {
      expect(pack, contains('À VALIDER (propriétaire)'));
      final open = _section(pack, '### 4.3 Points qui restent ouverts');
      expect(open, contains('Nationalité'));
      expect(open, contains('À VALIDER (propriétaire)'));
      expect(open, contains('features.scholarshipMatch'));
    });
  });

  group('Tableau des drapeaux : chaque clé de /config/app, son vrai défaut',
      () {
    final pack = _read(_packPath);
    final table = _section(pack, '## 5. Drapeaux');
    final features = _controllerFeatures();
    final rows = <String, String>{
      for (final m in RegExp(
        r'^\| `([a-zA-Z0-9]+)` \|(.*)$',
        multiLine: true,
      ).allMatches(table))
        m.group(1)!: m.group(2)!,
    };

    test('la lecture du contrôleur trouve les clés', () {
      // Garde de la garde : un contrôleur réindenté ne doit pas faire passer
      // le test sur une liste vide.
      expect(features.length, greaterThanOrEqualTo(26));
      expect(
        features.keys,
        containsAll(<String>['eefSpace', 'scholarshipMatch', 'homeNextStep']),
      );
    });

    test('chaque clé servie a sa ligne, et aucune ligne n\'est inventée', () {
      for (final key in features.keys) {
        expect(
          rows.containsKey(key),
          isTrue,
          reason: 'features.$key est servie par le contrôleur mais absente '
              'du tableau du pack 57 §5',
        );
      }
      for (final key in rows.keys) {
        expect(
          features.containsKey(key),
          isTrue,
          reason: 'le tableau liste `$key`, que le contrôleur ne sert pas',
        );
      }
    });

    test('le défaut écrit est celui du code (notDisabled = ouvert)', () {
      features.forEach((key, expression) {
        final open = expression.contains('notDisabled(');
        final cells = rows[key]!.split('|').map((c) => c.trim()).toList();
        // Colonnes : variable | défaut | prod. | lancement | ordre.
        final defaultCell = cells[1];
        expect(
          defaultCell,
          open ? 'ouvert' : 'fermé',
          reason: 'features.$key : le code dit '
              '${open ? 'ouvert (notDisabled)' : 'fermé (enabled)'}',
        );
        // La variable citée est celle que lit le code.
        final env = RegExp(r'KPB_[A-Z0-9_]+').firstMatch(expression)?.group(0);
        if (env != null) {
          expect(
            cells[0],
            contains(env),
            reason: 'features.$key lit $env, le tableau cite ${cells[0]}',
          );
        }
      });
    });

    test('ce qui part fermé au lancement de la 57', () {
      for (final key in [
        'scholarshipMatch',
        'onboardingV2',
        'eefHelpBubble',
        'eefPrivateSchools',
        'eef',
      ]) {
        final cells = rows[key]!.split('|').map((c) => c.trim()).toList();
        expect(
          cells[3],
          startsWith('`false`'),
          reason: 'features.$key doit partir fermé',
        );
      }
      // L'ordre d'ouverture : onboarding V2 avant le test, le test en dernier.
      final order = _flat(table);
      final v2 = order.indexOf('**`KPB_ONBOARDING_V2_ENABLED=true`**');
      final mode = order.indexOf('**Mode d\'ouverture**');
      final match = order.indexOf('**`KPB_SCHOLARSHIP_MATCH_ENABLED=true`**');
      expect(v2, isNot(-1));
      expect(mode, greaterThan(v2));
      expect(match, greaterThan(mode));
    });
  });

  group('Déploiement : version marketing, paliers, mode d\'ouverture', () {
    final pack = _read(_packPath);
    final deploy = _flat(_section(pack, '## 6. Déploiement'));

    test('le code ignore bien le numéro de build (sinon la consigne ment)', () {
      final utils = _read('lib/app/core/utils/version_utils.dart');
      expect(
        utils,
        contains("split('+').first"),
        reason: '_parseVersion ne coupe plus le numéro de build : '
            'KPB_RECOMMENDED_APP_VERSION n\'est plus « la version marketing »',
      );
      final gate = _read('lib/app/core/services/app_version_gate.dart');
      expect(gate, contains('isVersionBelow(info.version, minVersion)'));
      expect(gate.contains('buildNumber'), isFalse);
      final banner = _read(
        'lib/app/core/ui/components/update_recommended_banner.dart',
      );
      expect(banner, contains('info.version'));
      expect(banner.contains('buildNumber'), isFalse);
    });

    test('KPB_RECOMMENDED_APP_VERSION = version marketing ; MIN à 85 %', () {
      expect(deploy, contains('**`KPB_RECOMMENDED_APP_VERSION=2.4.0`**'));
      expect(deploy, contains('la **version marketing**'));
      expect(deploy, contains('`lib/app/core/utils/version_utils.dart`'));
      expect(pack, contains('`lib/app/core/services/app_version_gate.dart`'));
      expect(deploy, contains('**environ 85 %**'));
      expect(deploy, contains('`GET /admin/app-builds`'));
    });

    test('Play 10 % → 50 % → 100 % et publication progressive iOS', () {
      final p10 = deploy.indexOf('| **10 %** |');
      final p50 = deploy.indexOf('| **50 %** |');
      final p100 = deploy.indexOf('| **100 %** |');
      expect(p10, isNot(-1));
      expect(p50, greaterThan(p10));
      expect(p100, greaterThan(p50));
      for (final criterion in [
        '**Plantages**',
        '**ANR**',
        '**Erreurs serveur**',
        '**Retours**',
        'Phased release for automatic updates',
      ]) {
        expect(deploy, contains(criterion));
      }
    });

    test(
      'serveur, puis admin, puis app ; legacy → outbox_alerts → followers',
      () {
        final server = deploy.indexOf('1. **Serveur**');
        final admin = deploy.indexOf('2. **Admin**');
        final app = deploy.indexOf('3. **App**');
        expect(server, isNot(-1));
        expect(admin, greaterThan(server));
        expect(app, greaterThan(admin));
        final legacy = deploy.indexOf('1. **`legacy`**');
        final alerts = deploy.indexOf('2. **`outbox_alerts`**');
        final followers = deploy.indexOf('3. **`outbox_followers`**');
        expect(legacy, isNot(-1));
        expect(alerts, greaterThan(legacy));
        expect(followers, greaterThan(alerts));
        // Les modes cités existent dans le contrat du serveur.
        final contract = _read(
          'backend/src/modules/scholarships-index/opening/'
          'scholarship-opening.contract.ts',
        );
        for (final mode in ['legacy', 'outbox_alerts', 'outbox_followers']) {
          expect(contract, contains("'$mode'"));
        }
        expect(deploy, contains('follow:mirror-alerts -- --apply'));
      },
    );
  });

  group('Politique de confidentialité et inventaire', () {
    final fr = _read('lib/app/core/translations/app_translations_fr.dart');
    final en = _read('lib/app/core/translations/app_translations_en.dart');
    final web = _read('web/public/confidentialite.html');
    final inventory = _read('docs/data-inventory.md');

    String entry(String source, String key) {
      final start = source.indexOf("  '$key':");
      expect(start, isNot(-1), reason: 'clé $key absente');
      final end = source.indexOf(
        RegExp(r"^  '[a-z_0-9]+':", multiLine: true),
        start + key.length + 4,
      );
      return source.substring(start, end);
    }

    test('FR : collecte, finalité, mineurs, partage, conservation', () {
      expect(entry(fr, 'privacy_s2_body'), contains('nationalité(s)'));
      expect(entry(fr, 'privacy_s3_body'), contains('résultat est indicatif'));
      expect(entry(fr, 'privacy_s4_body'), contains('Mineurs de 16 et 17 ans'));
      expect(
        entry(fr, 'privacy_s5_body'),
        contains('ne sont transmises à aucune école'),
      );
      expect(entry(fr, 'privacy_s6_body'), contains('5 derniers résultats'));
    });

    test('EN : les mêmes points, en anglais', () {
      expect(entry(en, 'privacy_s2_body'), contains('nationality'));
      expect(entry(en, 'privacy_s3_body'), contains('result is indicative'));
      expect(entry(en, 'privacy_s4_body'), contains('Minors aged 16 and 17'));
      expect(
        entry(en, 'privacy_s5_body'),
        contains('are not sent to any school'),
      );
      expect(entry(en, 'privacy_s6_body'), contains('last 5 results'));
    });

    test('la page web dit la même chose que la politique in-app (FR)', () {
      for (final sentence in [
        'nationalité(s), pays de résidence, date de naissance',
        'ne sont transmises à aucune école, à aucun organisme de bourse',
        'Mineurs de 16 et 17 ans',
        'seuls vos 5 derniers résultats sont conservés',
        'Le résultat est indicatif',
      ]) {
        expect(
          web,
          contains(sentence),
          reason: 'confidentialite.html ne dit pas « $sentence »',
        );
        expect(
          fr,
          contains(sentence),
          reason: 'la politique in-app ne dit pas « $sentence »',
        );
      }
    });

    test('l\'inventaire dit la transmission, la conservation et l\'écart', () {
      final s5 = inventory.substring(inventory.indexOf('## 5. Build 57'));
      expect(s5, contains('nationalityCode'));
      expect(s5, contains('**Non.**'));
      expect(s5, contains('À VALIDER (propriétaire)'));
      expect(s5, contains('UserNotification'));
      // Le code dit bien ce que l'inventaire affirme : 5 runs gardés, et
      // `inputsSummary` sans nationalité.
      final service = _read(
        'backend/src/modules/scholarship-match/scholarship-match.service.ts',
      );
      expect(service, contains('élague aux 5 derniers'));
      final presenter = _read(
        'backend/src/modules/scholarship-match/match-presenter.ts',
      );
      expect(presenter, contains('ni nationalité, ni date de naissance'));
      final lead = _read('backend/src/modules/cases/case-lead-mail.service.ts');
      expect(
        lead.contains('nationalit'),
        isFalse,
        reason: 'l\'e-mail commercial porte désormais la nationalité : '
            'l\'inventaire et la politique mentent',
      );
    });
  });

  group('Fiche de recette de la build 57', () {
    final qa = _read(_qaPath);
    final rows = _rows(qa);

    test('les numéros sont uniques et continus par préfixe', () {
      expect(rows, isNotEmpty);
      for (final prefix in _prefixes) {
        final numbers = rows.keys
            .where((id) => id.startsWith('$prefix-'))
            .map((id) => int.parse(id.split('-').last))
            .toList();
        expect(numbers, isNotEmpty, reason: 'aucun cas $prefix-');
        expect(
          numbers,
          List<int>.generate(numbers.length, (i) => i + 1),
          reason: '$prefix- doit être numéroté 1, 2, 3… sans trou',
        );
      }
    });

    test('les effectifs de chaque section sont épinglés', () {
      const sizes = {
        'Appareil': 8,
        'Texte': 7,
        'Lecteur': 10,
        'Push': 12,
        'HorsLigne': 7,
        'Accueil': 6,
        'Suivi': 4,
        'Drapeau': 5,
        'Boutique': 5,
      };
      sizes.forEach((prefix, expected) {
        final count = rows.keys.where((id) => id.startsWith('$prefix-'));
        expect(
          count.length,
          expected,
          reason: 'la section $prefix- compte ${count.length} cas, '
              '$expected attendus',
        );
      });
    });

    test('chaque cas exigé existe et porte son sujet DANS SA LIGNE', () {
      const required = <String, List<String>>{
        'Appareil-1': ['3G', '360', '2 Go'],
        'Texte-1': ['1.0'],
        'Texte-2': ['1.5', '1,3'],
        'Lecteur-1': ['Onboarding'],
        'Lecteur-3': ['test'],
        'Lecteur-7': ['Détail'],
        'Lecteur-8': ['Suivre'],
        'Lecteur-9': ['dossier'],
        'Push-3': ['TUÉE', 'fiche'],
        'Push-4': ['TUÉE', 'A9'],
        'Push-8': ['Ancienne build', 'OneSignal'],
        'HorsLigne-1': ['Démarrage à froid hors ligne'],
        'HorsLigne-2': ['Bandeau hors ligne global'],
        'Accueil-1': ['TA PROCHAINE ÉTAPE'],
        'Boutique-1': ['2.4.0 (57)'],
      };
      required.forEach((id, needles) {
        final row = rows[id];
        expect(row, isNotNull, reason: 'le cas $id n\'existe plus');
        for (final needle in needles) {
          expect(
            row,
            contains(needle),
            reason: 'la ligne $id ne porte plus « $needle »',
          );
        }
      });
      // TalkBack ET VoiceOver sur le parcours entier.
      final reader = qa.substring(qa.indexOf('## Lecteurs d\'écran'));
      expect(reader, contains('TalkBack'));
      expect(reader, contains('VoiceOver'));
    });

    test('les cases sont vides : rien n\'est coché d\'avance', () {
      for (final entry in rows.entries) {
        final cells = entry.value.split('|').map((c) => c.trim()).toList();
        // Colonnes : À vérifier | Attendu | iPhone | Android.
        expect(
          cells[cells.length - 3],
          '☐',
          reason: '${entry.key} : case iPhone pré-remplie',
        );
        expect(
          cells[cells.length - 2],
          '☐',
          reason: '${entry.key} : case Android pré-remplie',
        );
      }
      expect(qa.contains('☑ |'), isFalse);
      expect(qa.contains('✓ |'), isFalse);
    });

    test('la fiche dit ce que le code fait vraiment', () {
      // Le plafond de texte agrandi : 1,3 (main.dart).
      expect(_read('lib/main.dart'), contains('maxScaleFactor: 1.3'));
      // L'app tuée passe par `getInitialMessage`.
      expect(
        _read('lib/app/core/services/push_service.dart'),
        contains('getInitialMessage'),
      );
      // Le bandeau hors ligne global vit dans la coquille.
      expect(
        _read('lib/app/features/shell/app_shell.dart'),
        contains('KpbOfflineBanner'),
      );
      // A9 de la fiche 54 existe toujours, et la 57 dit le fermer.
      expect(_read('docs/device-qa-build54.md'), contains('| A9 |'));
      expect(qa, contains('ferme le point A9'));
    });
  });
}

const _prefixes = [
  'Appareil',
  'Texte',
  'Lecteur',
  'Push',
  'HorsLigne',
  'Accueil',
  'Suivi',
  'Drapeau',
  'Boutique',
];

Map<String, String> _rows(String qa) => {
      for (final m in RegExp(
        '^\\| ((?:${_prefixes.join('|')})-\\d+) \\|(.*)\$',
        multiLine: true,
      ).allMatches(qa))
        m.group(1)!: m.group(2)!,
    };

int _utf8Length(String s) => s.runes.fold<int>(0, (n, r) {
      if (r <= 0x7f) return n + 1;
      if (r <= 0x7ff) return n + 2;
      if (r <= 0xffff) return n + 3;
      return n + 4;
    });

String _thousands(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
}
