// La checklist de la 56 est le seul mode d'emploi de l'archive : on verrouille ce
// qui, une fois faux, coûte un numéro de build ou une clé de télémétrie.
//
// Contexte (décision du propriétaire, 05/10/2026) : on n'envoie QUE la 56. La 55
// (téléversée sur App Store Connect le 04/10, jamais soumise ; AAB signé du run
// 37322572087 jamais importé dans Play) est abandonnée. Le piège est double :
// importer l'AAB de la 55 « parce qu'il existe », ou suivre encore la checklist
// de la 55 dont les numéros, les noms de dossier et les contrôles de version
// épinglent 55.
//
// Ce test lit les documents ; il ne prouve pas que les commandes marchent (aucune
// n'est lancée ici, elles touchent les boutiques et la production). Il prouve
// que le document ne dit plus la chose fausse et dit encore la chose protectrice.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Les blocs de code d'un document, dans l'ordre.
List<String> _blocks(String doc) => RegExp(r'```[a-z]*\n(.*?)```', dotAll: true)
    .allMatches(doc)
    .map((m) => m.group(1)!)
    .toList();

/// La version que la checklist de la 56 décrit. Depuis la préparation de la 57
/// (18/10/2026), `pubspec.yaml` porte `2.3.1+57` : ce test ne lit plus la
/// version du dépôt, il garde le document de la 56 tel qu'il doit rester
/// (`mise_a_jour_57_checklist_test.dart` garde désormais la version posée).
const ({String name, String build}) _documented = (name: '2.3.0', build: '56');

/// Les blocs de code AVEC leur position dans le document : l'ordre des commandes
/// se compare entre COMMANDES, jamais entre une commande et une mention en prose
/// (la prose cite `flutter build ios` bien avant que la commande n'apparaisse).
List<({int start, int end, String text})> _blocksAt(String doc) =>
    RegExp(r'```[a-z]*\n(.*?)```', dotAll: true)
        .allMatches(doc)
        .map((m) => (start: m.start, end: m.end, text: m.group(1)!))
        .toList();

/// Les phrases d'un document qui parlent d'un avertissement (mise en garde,
/// bandeau, encart) de suspension. Les retours à la ligne et les `> ` des citations
/// sont aplatis ; une phrase finit à `.`, `;`, `!`, `?` ou à la cellule d'un tableau.
List<String> _suspensionWarnings(String doc) {
  final flat = doc.replaceAll(RegExp(r'\s*\n>?\s*'), ' ');
  final warning = RegExp(
    r'(avertissement|mise en garde|bandeau|encart)[^.\n]{0,40}suspension',
    caseSensitive: false,
  );
  return flat
      .split(RegExp(r'[.;!?]\s+|\s\|\s'))
      .where(warning.hasMatch)
      .toList();
}

/// Ce qui dit qu'un avertissement est RETIRÉ plutôt que montré.
final _saysRemoved = RegExp(
  r"retir|retrait|supprim|disparu|plus (aucun|d')|ne montre(nt)? (plus|ni)|\bni\b|aucun|nulle part",
  caseSensitive: false,
);

/// Le texte d'une section « ## n. … » jusqu'à la suivante.
String _section(String doc, String headingStart) {
  final start = doc.indexOf(headingStart);
  expect(start, isNot(-1), reason: 'la section « $headingStart » a disparu');
  final rest = doc.substring(start + headingStart.length);
  final end = rest.indexOf(RegExp(r'^## ', multiLine: true));
  return end == -1 ? rest : rest.substring(0, end);
}

void main() {
  const path = 'docs/mise-a-jour-56-checklist.md';

  group('La checklist de la 56', () {
    final doc = _read(path);
    const shipping = _documented;

    test('porte la version de la 56 et plus aucun contrôle sur 55', () {
      expect(shipping.build, '56');
      expect(doc, contains('${shipping.name} (${shipping.build})'));
      expect(doc, contains('FLUTTER_BUILD_NUMBER=${shipping.build}'));
      expect(doc, contains('Préflight iOS OK — ${shipping.name} (56)'));
      expect(doc, contains('Préflight Android OK — ${shipping.name} (56)'));
      // Les chaînes qui, attendues à 55, feraient refuser (ou pire accepter)
      // la mauvaise build.
      for (final stale in [
        'FLUTTER_BUILD_NUMBER=55',
        'Préflight iOS OK — 2.3.0 (55)',
        'Préflight Android OK — 2.3.0 (55)',
        '../kpb-release-55',
        'versionCode` 55',
        'EXPECTED_VERSION_CODE="55"',
        'version: 2.3.0+55',
        '+version: 2.3.0+54',
      ]) {
        expect(doc.contains(stale), isFalse,
            reason: 'la checklist de la 56 contient encore « $stale »');
      }
    });

    test('RELEASE est un marqueur à renseigner, jamais un SHA inventé', () {
      expect(doc, contains('export RELEASE=<SHA>'));
      expect(RegExp(r'RELEASE=\$?\(?[`"]?[0-9a-f]{40}').hasMatch(doc), isFalse,
          reason: 'un SHA de 40 caractères est posé comme RELEASE');
      expect(RegExp(r'\b[0-9a-f]{40}\b').hasMatch(doc), isFalse,
          reason: 'un SHA complet figure dans la checklist : inventé ?');
    });

    test('aucun secret n\'est écrit dans le document', () {
      final secrets = <String, RegExp>{
        'clé PostHog': RegExp(r'phc_[A-Za-z0-9]{20,}'),
        'clé privée': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY'),
        'jeton GitHub': RegExp(r'\bgh[pousr]_[A-Za-z0-9]{20,}'),
        'clé AWS': RegExp(r'\bAKIA[0-9A-Z]{12,}'),
        'clé sk-': RegExp(r'\bsk-[A-Za-z0-9]{20,}'),
        'mot de passe en clair':
            RegExp(r'password\s*[:=]\s*\S{6,}', caseSensitive: false),
        // L'empreinte SHA-256 d'un certificat est publique, mais la checklist
        // renvoie à la console au lieu d'en figer une : pas de 64 hexa.
        'empreinte figée': RegExp(r'\b[0-9A-Fa-f]{64}\b'),
      };
      secrets.forEach((name, re) {
        expect(re.hasMatch(doc), isFalse,
            reason: 'la checklist contient : $name');
      });
    });

    test('l\'AAB de la 55 est interdit d\'import, nommé et daté', () {
      final paragraph = RegExp(
        r'[^\n]*(?:\n(?!\n)[^\n]*)*NE PAS importer[^\n]*(?:\n(?!\n)[^\n]*)*',
      ).firstMatch(doc);
      expect(paragraph, isNotNull, reason: '« NE PAS importer » a disparu');
      final text = paragraph!.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('37322572087'),
          reason:
              'le run de l\'AAB 55 n\'est plus nommé à côté de l\'interdit');
      expect(text, contains('AAB'));
      expect(text, contains('55'));
      // Et l'AAB du 02/10 (la 54) reste interdit lui aussi.
      expect(doc, contains('36945000021'));
    });

    test('la porte « 24 h » : dérogation après preuve des sondes', () {
      expect(doc, contains('require_24h_stability=false'));
      expect(doc, contains('n\'est PAS une preuve'));
      expect(doc, contains('gh run list --workflow uptime.yml'));
      // La dérogation ne se LANCE qu'après la commande de preuve : on compare
      // les positions des deux COMMANDES (blocs de code), pas des mentions en
      // prose, qui peuvent la citer plus tôt.
      final blocks = _blocks(doc);
      final proof = blocks
          .indexWhere((b) => b.contains('gh run list --workflow uptime.yml'));
      final waiver = blocks.indexWhere((b) =>
          b.contains('gh workflow run release-preflight.yml') &&
          b.contains('require_24h_stability=false'));
      expect(proof, isNot(-1),
          reason: 'la commande de preuve des sondes a disparu');
      expect(waiver, isNot(-1),
          reason: 'la commande du préflight avec dérogation a disparu');
      expect(proof, lessThan(waiver),
          reason: 'la dérogation est lancée avant la preuve des sondes');
      expect(doc, contains('tolerates-old'));
    });

    test('le contrôle de la clé PostHog : saisie seule, longueur, préflight',
        () {
      final blocks = _blocks(doc);
      final readers =
          blocks.where((b) => b.contains('read -rs POSTHOG_API_KEY')).toList();
      expect(readers, isNotEmpty);
      for (final block in readers) {
        expect(block, isNot(contains('flutter build')),
            reason: '`read -rs` et `flutter build` dans le même bloc');
        expect(
            block.trim().split('\n').where((l) => !l.startsWith('#')).length, 1,
            reason: 'la saisie doit vivre SEULE dans son bloc');
      }
      expect(doc, contains(r'${#POSTHOG_API_KEY}'));
      expect(doc, contains('--posthog-only'));
    });

    test('--posthog-only : après la COMMANDE de construction, avant l\'archive',
        () {
      // On compare des blocs de code, pas des mentions en prose : la phrase qui
      // dit que Xcode 27 « bloquerait `flutter build ios` » précède de loin la
      // commande, et un `indexOf('flutter build ios')` s'y ancrait.
      final blocks = _blocksAt(doc);
      final build = blocks.indexWhere((b) =>
          b.text.contains('flutter build ios --release') &&
          b.text.contains('--dart-define=POSTHOG_API_KEY='));
      final only = blocks.indexWhere((b) =>
          b.text.contains('scripts/preflight-ios-archive.sh') &&
          b.text.contains('--xcconfig ios/Flutter/Generated.xcconfig') &&
          b.text.contains('--posthog-only'));
      expect(build, isNot(-1),
          reason: 'la commande `flutter build ios --release` avec la clé a '
              'disparu');
      expect(only, isNot(-1),
          reason: 'la commande `--posthog-only` sur Generated.xcconfig a '
              'disparu');
      expect(build, lessThan(only),
          reason: '`--posthog-only` contrôlerait un Generated.xcconfig '
              'PÉRIMÉ : il doit suivre la construction');
      final archive = doc.indexOf('Product → Archive', blocks[only].end);
      expect(archive, isNot(-1),
          reason: 'plus de « Product → Archive » après le contrôle');
      // Et aucun `flutter build` ne s'intercale entre le contrôle et l'archive.
      expect(doc.substring(blocks[only].end, archive),
          isNot(contains('flutter build ios --release \\')));
    });

    test('le lancement du préflight : ref, commit, couplage, porte 24 h', () {
      // Le bloc qui LANCE le préflight, pas la prose qui en parle : chaque
      // paramètre se lit dans CE bloc. `tolerates-old` cité n'importe où dans le
      // document (il l'est partout) ne prouvait rien du lancement.
      final launch = _blocksAt(doc)
          .where(
              (b) => b.text.contains('gh workflow run release-preflight.yml'))
          .toList();
      expect(launch, hasLength(1),
          reason: 'une seule commande de lancement du préflight attendue');
      final command = launch.single.text.replaceAll(RegExp(r'\\\s*\n\s*'), ' ');
      for (final part in [
        '--ref main', // le workflow vit sur main, jamais sur une branche
        r'-f ref="$RELEASE"', // le préflight juge le commit à archiver
        '-f backend_coupling=tolerates-old', // la prod sert 0641601, pas RELEASE
        '-f require_24h_stability=false',
      ]) {
        expect(command, contains(part),
            reason: 'le lancement du préflight ne porte plus « $part » :\n'
                '$command');
      }
      // Les valeurs qui échoueraient en production.
      expect(command.contains('requires-new'), isFalse);
      expect(command.contains('-f ref=main'), isFalse);
      expect(command.contains('require_24h_stability=true'), isFalse);
    });

    test('l\'AAB vient de Flutter CI release_android sur main, au bon commit',
        () {
      final android = _section(doc, '## 2. Android');
      expect(android, contains('Flutter CI'));
      expect(android, contains('release_android'));
      expect(android, contains('main'));
      expect(android, contains('`RELEASE`'));
      expect(android, contains('tag `v2.3.0`'));
      // Rien d'autre ne fusionne sur main entre RELEASE et le préflight.
      expect(doc, contains('plus rien ne se fusionne'));
    });

    test('étape 0 : les décisions à avoir prises AVANT d\'archiver', () {
      final step0 = _section(doc, '## 0.');
      // (a) est TRANCHÉE le 06/10/2026 : la phrase est retirée, rien à décider ni
      // à retirer avant l'archive. Ni la clé ni la phrase ne survivent.
      expect(step0, contains('tranchée le 06/10/2026'));
      expect(step0, contains('la phrase est retirée'));
      expect(step0, contains('rémunéré par des écoles privées'));
      expect(step0.contains('eef_help_private_disclosure'), isFalse);
      expect(step0.contains('KPB peut être rémunéré'), isFalse);
      expect(step0.contains('« oui » → garder la phrase'), isFalse);
      expect(step0, contains('_useFeesFallback'));
      expect(step0, contains('eef_help_private_point_fees_fallback'));
      expect(step0, contains('Niger'));
      expect(step0.toLowerCase(), contains('aucune mention d\'école privée'));
      // Les interrupteurs restent fermés à l'archive : état A.
      expect(step0, contains('FERMÉS'));
      expect(step0, contains('eefHelpBubble'));
      expect(step0, contains('eefPrivateSchools'));
      expect(step0, contains('état A'));
      // Les textes compilés se tranchent avant l'archive, pas après.
      expect(step0.toLowerCase(), contains('avant l\'archive'));
    });

    test('le couplage backend dit vrai : tolerates-old, backend 0641601', () {
      expect(doc, contains('0641601'));
      expect(doc, contains('eefHelpBubble'));
      expect(doc, contains('eefPrivateSchools'));
      // La 56 tolère l'ancien backend (clé absente = fermé) ; ne déployer le
      // backend qu'au moment d'allumer, jamais avant le préflight.
      expect(doc.toLowerCase(), contains('clé absente'));
      expect(doc, contains('git diff --stat 0641601'));
    });

    test('la version ASC 2.3.0 reçoit la build 56 à la place de la 55', () {
      final submit = _section(doc, '## 7. Soumettre');
      expect(submit, contains('2.3.0'));
      expect(submit, contains('build 56'));
      expect(submit.toLowerCase(), contains('à la place de la 55'));
    });

    test('chaque étape de distribution porte son 🔒', () {
      for (final heading in [
        '## 2. Android',
        '## 3. iOS',
        '## 5. Recette',
        '## 7. Soumettre',
      ]) {
        final line = doc
            .split('\n')
            .firstWhere((l) => l.startsWith(heading), orElse: () => '');
        expect(line, contains('🔒'),
            reason: 'l\'étape « $heading » n\'a plus 🔒');
      }
      expect(doc.replaceAll(RegExp(r'\s*\n>\s*'), ' '),
          contains('aucune ne se fait sans le feu vert explicite'));
    });

    test('Xcode 27 : les constats de la 55 sont gardés', () {
      expect(doc, contains('Xcode 27'));
      expect(doc, contains('lipo -verify_arch'));
      expect(doc, contains('sudo xcodebuild -license accept'));
    });

    test('l\'état de la production est daté, et mesuré à l\'étape 1', () {
      // Le relevé est du 03/10 ; une fenêtre de recette `eef-space-on` a pu
      // rouvrir `eefSpace` depuis. Dire « au 05/10 … fermé » affirmerait une
      // mesure qui n'a pas eu lieu, et ferait sauter la fermeture.
      expect(doc, contains('relevé du 03/10/2026'));
      expect(doc, contains('NON remesuré le 05/10'));
      expect(doc.contains('État de départ au 05/10/2026'), isFalse,
          reason: 'l\'en-tête date de 05/10 une mesure du 03/10');
      final step1 = _section(doc, '## 1.');
      expect(step1, contains('.features | {eef, eefTeaser, eefSpace'));
      expect(step1, contains('vaut `true`'),
          reason: 'l\'étape 1 ne dit pas quoi faire si l\'espace est ouvert');
      for (final off in [
        'eef-private-schools-off',
        'eef-bubble-off',
        'eef-space-off'
      ]) {
        expect(step1, contains(off),
            reason: 'l\'étape 1 ne dit plus de lancer `$off` si un '
                'interrupteur est ouvert');
      }
      expect(step1.toLowerCase(), contains('ne pas continuer'));

      final ledger = _read('docs/release-ledger.md');
      expect(ledger, contains('NON remesuré le 05/10'));
      expect(ledger.contains('mais l\'espace reste fermé'), isFalse,
          reason: 'le registre affirme l\'espace fermé sans mesure du jour');
      expect(ledger, contains('a pu rouvrir'));
    });

    // Le retrait de la phrase de rémunération est un texte COMPILÉ : s'il n'est pas
    // fusionné dans `main` AVANT de relever `RELEASE`, l'AAB et l'archive portent
    // encore la phrase, et elle ne pourra plus changer sans nouvelle build.
    test('la PR du retrait est fusionnée AVANT RELEASE, et prouvée sur RELEASE',
        () {
      final step0 = _section(doc, '## 0.');
      final merged = RegExp(
        r'PR[^\n]{0,80}retrait de la phrase de rémunération[^\n]{0,160}'
        r'fusionnée',
        dotAll: true,
      );
      expect(merged.hasMatch(step0.replaceAll(RegExp(r'\s+'), ' ')), isTrue,
          reason: 'l\'étape 0 ne demande pas la fusion de la PR du retrait');
      final step1 = _section(doc, '## 1.');
      expect(
        step1,
        contains(
          'git show "\$RELEASE:lib/app/core/translations/app_translations.dart" '
          '| grep -c eef_help_private_disclosure',
        ),
        reason: 'l\'étape 1 ne prouve pas l\'absence de la clé sur RELEASE',
      );
      expect(step1, contains('0 : la clé de la phrase de rémunération'),
          reason: 'le résultat attendu (0) n\'est pas dit');
    });

    test('les chemins cités existent', () {
      final links = RegExp(
              r'`((?:docs|scripts|test|lib|\.github)/[A-Za-z0-9_./-]+\.[a-z]+)`')
          .allMatches(doc)
          .map((m) => m.group(1)!)
          .toSet();
      expect(links, contains('docs/release-56-store-pack.md'));
      expect(links, contains('docs/device-qa-build56.md'));
      for (final link in links) {
        expect(File(link).existsSync(), isTrue,
            reason: 'la checklist cite `$link`, qui n\'existe pas');
      }
    });
  });

  group('La 55 est marquée remplacée, sans réécriture', () {
    const banner = 'REMPLACÉE par la 56 le 05/10/2026';
    for (final file in [
      'docs/mise-a-jour-55-checklist.md',
      'docs/release-55-store-pack.md',
      'docs/device-qa-build55.md',
    ]) {
      test('$file porte le bandeau en tête', () {
        final lines = _read(file).split('\n');
        final head = lines.take(8).join('\n');
        expect(head, contains(banner),
            reason: 'bandeau absent des premières lignes de $file');
        expect(head, contains('la 55 n\'a jamais été soumise'));
        expect(head, contains('docs/mise-a-jour-56-checklist.md'));
        expect(lines.first, startsWith('#'),
            reason: 'le titre doit rester la première ligne');
      });
    }

    test('le contenu de la checklist 55 n\'a pas été réécrit', () {
      // Le bandeau s'ajoute ; l'étape 3 (clé PostHog) et sa preuve restent.
      final old = _read('docs/mise-a-jour-55-checklist.md');
      expect(old, contains('## 3. iOS'));
      expect(old, contains('FLUTTER_BUILD_NUMBER=55'));
    });
  });

  group('Les papiers de la 56 retiennent le scénario décidé', () {
    final pack = _read('docs/release-56-store-pack.md');
    final qa = _read('docs/device-qa-build56.md');

    test('le pack : la 55 jamais soumise, la 56 garde 2.3.0', () {
      expect(pack.contains('Les trois scénarios de la 55'), isFalse,
          reason: 'le pack décrit encore trois scénarios : un seul a eu lieu');
      expect(pack, contains('jamais soumise'));
      expect(pack, contains('2.3.0'));
      expect(pack, contains('docs/mise-a-jour-56-checklist.md'));
      // `pubspec.yaml` ne porte plus « 2.3.0+55 » dans l'état annoncé.
      expect(pack.contains('porte encore\n> `2.3.0+55`'), isFalse);
      expect(pack.contains('`2.3.0+55`'), isFalse);
    });

    test(
        'l\'avertissement de suspension est dit retiré dans les quatre papiers',
        () {
      // #324 (hub, catalogue) et #326 (vitrine) : plus aucun avertissement. Un
      // papier qui dit qu'un compte du Niger en voit un dicte une recette fausse.
      // On balaie le pack, la recette, l'ouverture ET le runbook : chacun parle
      // de l'avertissement, et chaque phrase qui en parle doit le dire retiré.
      for (final file in [
        'docs/release-56-store-pack.md',
        'docs/device-qa-build56.md',
        'docs/ouverture-espace-eef.md',
        'docs/runbook-ouverture-espace-reel.md',
      ]) {
        final sentences = _suspensionWarnings(_read(file));
        expect(sentences, isNotEmpty,
            reason: '$file ne dit plus que l\'avertissement de suspension est '
                'retiré (assertion positive)');
        for (final sentence in sentences) {
          expect(_saysRemoved.hasMatch(sentence), isTrue,
              reason: '$file parle d\'un avertissement de suspension sans le '
                  'dire retiré :\n$sentence');
        }
      }
    });

    test('le balayage rougit sur une phrase qui montre encore l\'avertissement',
        () {
      // Contre-épreuve du balayage lui-même : il doit voir ce qu'il cherche.
      for (final bad in [
        'Un compte du Niger voit encore l\'encart jaune de suspension.',
        'La vitrine affiche la mise en garde de suspension avec sa source.',
        'Le bandeau de suspension reste visible dans le hub.',
      ]) {
        final sentences = _suspensionWarnings(bad);
        expect(sentences, isNotEmpty, reason: 'phrase non repérée : $bad');
        expect(sentences.every(_saysRemoved.hasMatch), isFalse,
            reason: 'phrase jugée « retirée » à tort : $bad');
      }
      for (final good in [
        'Plus aucun avertissement de suspension nulle part.',
        'Ne montre ni la date ni l\'avertissement de suspension (retiré).',
      ]) {
        expect(_suspensionWarnings(good).every(_saysRemoved.hasMatch), isTrue,
            reason: 'phrase juste jugée fautive : $good');
      }
    });

    test(
        'la fiche de recette ne conditionne plus la fenêtre à l\'état de la 55',
        () {
      expect(
          qa.contains(
              'n\'ouvrir la fenêtre que si la 55 n\'est pas déjà en vente'),
          isFalse);
      expect(qa, contains('docs/release-56-store-pack.md'));
    });

    test('ouverture et runbook : plus de « ouvrir avec la 55 »', () {
      for (final file in [
        'docs/ouverture-espace-eef.md',
        'docs/runbook-ouverture-espace-reel.md',
      ]) {
        final text = _read(file)
            .replaceAll(RegExp(r'\s*\n>?\s*'), ' ')
            .replaceAll('**', '');
        expect(text, contains('REMPLACÉE par la 56'),
            reason: '$file ne dit pas que la 55 est remplacée');
        // La décision, dite positivement : sa disparition (« s'ouvre avec la 55 »)
        // ne doit pas passer inaperçue.
        expect(text,
            matches(RegExp(r"s'ouvr(e|ira) avec la 56, jamais avec la 55")),
            reason:
                '$file ne dit plus « s\'ouvre avec la 56, jamais avec la 55 »');
        // Les phrases périmées : celles d'AVANT la décision (tableau et corps du
        // texte), pas seulement l'ancien libellé de l'option.
        for (final stale in [
          'Ouvrir avec la 55 ou attendre la 56',
          'ouvrir avec la 55 si elle est approuvée',
          'la 55, ou la 56 si elle la rattrape',
          'ou la 56 qui la reprend',
          'le bandeau n\'existe que dans la 55 et après',
          'ouvrir quand la 55 est en vente',
          'Ouvrir avant que la 55 soit en vente',
          'avec la 55 du store',
          'La 55 n\'existe pas encore dans les boutiques',
          'Archiver, soumettre et faire approuver la 55',
        ]) {
          expect(text.contains(stale), isFalse,
              reason: '$file garde la phrase périmée « $stale »');
        }
      }
      // Le tableau des préalables du runbook nomme la 56 seule.
      final runbook =
          _read('docs/runbook-ouverture-espace-reel.md').replaceAll('**', '');
      expect(
          runbook, contains('la 56 ; la 55, jamais soumise, est abandonnée'));
    });
  });
}
