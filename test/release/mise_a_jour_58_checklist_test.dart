// La checklist de la 58 est le mode d'emploi de la 57 corrigée : même version
// marketing (2.3.1, jamais en vente), numéro 58, correctifs de l'audit UX du
// 28/10/2026 (#387, #389). On verrouille ce qui, une fois faux, coûte un numéro
// de build ou envoie une build que l'audit a refusée.
//
// Contexte (07/11/2026) : la 57 est consommée (téléversée le 25/10/2026, jamais
// soumise) ; le backend dont la 58 a besoin est déjà en production (`b1f6a329`,
// #392 et #397) ; d'où un couplage `tolerates-old` et aucun déploiement avant
// l'archive. Le préflight de l'IPA exportée (`--app`), sauté pour la 57, devient
// obligatoire. La recette suit les conditions de l'audit.
//
// La 58 a été téléversée le 08/11/2026 (commit archivé `5332a128`), jamais
// soumise, et remplacée par la 59 (décision du propriétaire du 09/11/2026 ;
// préparation du 09/11/2026 : `pubspec.yaml` porte `2.3.1+59`). Ce test ne lit
// plus la version du dépôt ni l'état courant du registre : il garde le document
// de la 58 tel qu'il doit rester, et la ligne de la 58 sous « Consommés »
// (`mise_a_jour_59_checklist_test.dart` garde désormais la version posée).
//
// Ce test lit les documents ; il ne lance aucune commande (elles touchent les
// boutiques et la production).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _path = 'docs/mise-a-jour-58-checklist.md';
const _packPath = 'docs/release-58-store-pack.md';
const _qaPath = 'docs/device-qa-build58.md';

/// Le backend de production au 07/11/2026 (#398 à #400, déployé à 17 h 38 UTC).
const _production = 'b1f6a329';

/// L'archive de la 57 (`ba84fedf`, téléversée le 25/10/2026).
const _archive57 = 'ba84fedf';

const _reserveAddress = 40;
const _reserveMethod = 120;
const _appleLimit = 4000;
const _minMargin = 50;
const _playLimit = 500;

String _read(String path) => File(path).readAsStringSync();

String _flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

List<({int start, int end, String text})> _blocksAt(String doc) =>
    RegExp(r'```[a-z]*\n(.*?)```', dotAll: true)
        .allMatches(doc)
        .map((m) => (start: m.start, end: m.end, text: m.group(1)!))
        .toList();

String _section(String doc, String headingStart) {
  final start = doc.indexOf(headingStart);
  if (start == -1) {
    throw TestFailure('la section « $headingStart » a disparu');
  }
  final rest = doc.substring(start + headingStart.length);
  final end = rest.indexOf(RegExp(r'^## ', multiLine: true));
  return end == -1 ? rest : rest.substring(0, end);
}

/// La version que la checklist de la 58 décrit. Depuis la préparation de la 59
/// (09/11/2026), `pubspec.yaml` porte `2.3.1+59`.
const ({String name, String build}) _documented = (name: '2.3.1', build: '58');

/// La dernière migration du déploiement de la 58 : celles qui viennent après
/// (59 et suivantes) ne sont pas de son ressort.
const _lastMigration58 = '20261108120000_case_message_client_id';

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

void main() {
  group('La checklist de la 58', () {
    final doc = _read(_path);
    final flat = _flat(doc);

    test('porte la version 2.3.1 (58) et plus aucune commande de la 57', () {
      const shipping = _documented;
      expect(doc, contains('${shipping.name} (58)'));
      expect(doc, contains('version: ${shipping.name}+58'));
      expect(doc, contains('FLUTTER_BUILD_NUMBER=58'));
      expect(doc, contains('Préflight iOS OK — 2.3.1 (58)'));
      expect(doc, contains('Préflight Android OK — 2.3.1 (58)'));
      expect(doc, contains('../kpb-release-58'));
      for (final stale in [
        'FLUTTER_BUILD_NUMBER=57',
        'Préflight iOS OK — 2.3.1 (57)',
        'Préflight Android OK — 2.3.1 (57)',
        '../kpb-release-57',
        'EXPECTED_VERSION_CODE="57"',
        'EXPECTED_BUILD="57"',
        'backend_coupling=requires-new',
        'version: 2.3.1+57`',
      ]) {
        expect(
          doc.contains(stale),
          isFalse,
          reason: 'la checklist de la 58 contient encore « $stale »',
        );
      }
      // Les préflights attendent désormais la 59 : c'est
      // `mise_a_jour_59_checklist_test.dart` qui les garde.
    });

    test('même version marketing : 2.3.0 en vente, 2.3.1 jamais vendue', () {
      expect(flat, contains('ITMS-90062'));
      expect(flat, contains('**2.3.0 en vente**'));
      final prep = _section(doc, '### 0.2');
      expect(prep, contains('`version: 2.3.1+58`'));
      expect(prep, contains('EXPECTED_BUILD="58"'));
      expect(prep, contains('EXPECTED_VERSION_CODE="58"'));
      expect(prep, contains('Version marketing EN VENTE : `2.3.0`'));
      expect(prep, contains('mise_a_jour_57_checklist_test.dart'));
      expect(prep, contains('« REMPLACÉE par la 58 »'));
    });

    test('RELEASE est un marqueur à renseigner, jamais un SHA inventé', () {
      expect(doc, contains('export RELEASE=<SHA>'));
      expect(
        RegExp(r'\b[0-9a-f]{40}\b').hasMatch(doc),
        isFalse,
        reason: 'un SHA complet figure dans la checklist : inventé ?',
      );
    });

    test('aucun secret n\'est écrit dans le document', () {
      final secrets = <String, RegExp>{
        'clé PostHog': RegExp(r'phc_[A-Za-z0-9]{20,}'),
        'clé privée': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY'),
        'jeton GitHub': RegExp(r'\bgh[pousr]_[A-Za-z0-9]{20,}'),
        'compte de service': RegExp(r'"private_key"'),
        'empreinte figée': RegExp(r'\b[0-9A-Fa-f]{64}\b'),
      };
      secrets.forEach((name, re) {
        expect(re.hasMatch(doc), isFalse,
            reason: 'la checklist contient : $name');
      });
    });

    test('§0.3 : seule la ligne version bouge dans pubspec.yaml depuis la 57',
        () {
      final step = _section(doc, '### 0.3');
      expect(step, contains('git log --oneline --first-parent $_archive57'));
      expect(step, contains(r"grep -v '^[+-][[:space:]]*#'"));
      final expected = RegExp(r'^#     ([+-].*)$', multiLine: true)
          .allMatches(step)
          .map((m) => m.group(1)!)
          .toList();
      expect(expected, [
        '-version: 2.3.1+57',
        '+version: 2.3.1+58',
        '+  local_auth_platform_interface: ^1.1.0',
      ]);
      // La ligne `version:` du dépôt est celle de la 59 depuis le 09/11/2026 :
      // la 58 se garde par son document.
      expect(_read('pubspec.yaml').split('\n').toSet(),
          isNot(contains('version: 2.3.1+57')));
      // Les PR depuis l'archive de la 57, nommées.
      final flatStep = _flat(step);
      for (final pr in ['#386', '#387', '#389', '#392', '#397', '#383']) {
        expect(flatStep, contains(pr));
      }
      expect(
          flatStep, contains('aucune autre dépendance, aucun autre manifeste'));
      expect(flatStep, contains('android.speech.RecognitionService, #407'));
      expect(flatStep, contains('Info.plist et PrivacyInfo : rien'));
      for (final pr in ['#404', '#405', '#406', '#407', '#408']) {
        expect(flatStep, contains(pr));
      }
    });

    test('backend : tolerates-old, production ancêtre, aucun déploiement avant',
        () {
      final step1 = _section(doc, '## 1. Serveur et admin');
      expect(step1,
          contains('git merge-base --is-ancestor $_production "\$RELEASE"'));
      expect(
        step1,
        contains('git diff --stat $_production "\$RELEASE" -- backend admin '
            'docker-compose.yml'),
      );
      expect(_flat(step1), contains('**Ne pas déployer avant le préflight.**'));
      // #408 : la seule migration du déploiement dû après l'envoi, vérifiée
      // sur le disque (une migration de plus ou de moins casse ce test).
      expect(step1, contains('`20261108120000_case_message_client_id`'));
      final migrations = Directory('backend/prisma/migrations')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.where((p) => p.isNotEmpty).last)
          .where((n) =>
              n.compareTo('20261028120000_profile_completion_without_consent') >
              0)
          // La 58 est figée : les migrations venues après elle (la 59 et
          // suivantes) relèvent de leur propre checklist.
          .where((n) => n.compareTo(_lastMigration58) <= 0)
          .toList();
      expect(migrations, ['20261108120000_case_message_client_id']);
      expect(flat, contains('**Couplage backend : `tolerates-old`**'));
      // Le registre dit le même couplage, avec sa raison.
      final ledger = _read('docs/release-ledger.md');
      final entry = ledger.substring(
        ledger.indexOf('### Préparation de la build 58'),
      );
      expect(entry, contains('**Couplage backend : `tolerates-old`.**'));
      expect(entry, contains(_production));
    });

    test('le préflight : tolerates-old, ref, dérogation après la preuve', () {
      final blocks = _blocksAt(doc);
      final launch = blocks
          .where(
              (b) => b.text.contains('gh workflow run release-preflight.yml'))
          .toList();
      expect(launch, hasLength(1));
      final command = launch.single.text.replaceAll(RegExp(r'\\\s*\n\s*'), ' ');
      for (final part in [
        '--ref main',
        r'-f ref="$RELEASE"',
        '-f backend_coupling=tolerates-old',
        '-f require_24h_stability=false',
      ]) {
        expect(command, contains(part));
      }
      final proof = blocks.indexWhere(
        (b) => b.text.contains('gh run list --workflow uptime.yml'),
      );
      final waiver = blocks.indexWhere(
        (b) => b.text.contains('gh workflow run release-preflight.yml'),
      );
      expect(proof, isNot(-1));
      expect(proof, lessThan(waiver));
      expect(doc, contains('n\'est PAS une preuve'));
      // Le workflow connaît toujours ce mode.
      expect(_read('.github/workflows/release-preflight.yml'),
          contains('- tolerates-old'));
    });

    test('le préflight de l\'IPA exportée est obligatoire cette fois', () {
      final ios = _section(doc, '## 4. iOS');
      final flatIos = _flat(ios);
      expect(
        ios,
        contains('scripts/preflight-ios-archive.sh --xcconfig '
            'ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app'),
      );
      expect(flatIos, contains('obligatoire pour la 58'));
      expect(flatIos, contains('**Export**'));
      expect(flatIos, contains('Pas d\'envoi direct depuis l\'Organizer'));
    });

    test('la clé PostHog : saisie seule, --posthog-only après la construction',
        () {
      final blocks = _blocksAt(doc);
      final readers =
          blocks.where((b) => b.text.contains('read -rs POSTHOG_API_KEY'));
      expect(readers, isNotEmpty);
      for (final block in readers) {
        expect(block.text, isNot(contains('flutter build')));
      }
      final build = blocks.indexWhere(
        (b) =>
            b.text.contains('flutter build ios --release') &&
            b.text.contains('--dart-define=POSTHOG_API_KEY='),
      );
      final only = blocks.indexWhere((b) => b.text.contains('--posthog-only'));
      expect(build, isNot(-1));
      expect(only, greaterThan(build));
    });

    test('les anciens AAB sont interdits d\'import, nommés', () {
      final android = _section(doc, '## 3. Android');
      expect(android, contains('NE PAS importer'));
      expect(android, contains('37322572087'));
      expect(android, contains('36945000021'));
      expect(android, contains('de la 56 ou de la 57'));
      expect(doc, contains('plus rien ne se fusionne'));
    });

    test('la recette suit les conditions de l\'audit', () {
      final audit = _flat(_section(doc, '### 6.1'));
      for (final needle in [
        'TestFlight, en release',
        'iPhone SE',
        '360 dp',
        '**vraie 3G**',
        '**vrai mode avion**',
        '**VoiceOver réel**',
        '**notifications réelles**',
        '**tap**',
        '**connexion Google**',
        '**☰ invité en 1re session**',
        '**« Suivre » puis retour**',
        '**« Être accompagné »**',
        '**HorsLigne-1**',
        '**HorsLigne-5**',
      ]) {
        expect(audit, contains(needle),
            reason: 'l\'étape 6.1 ne dit plus « $needle »');
      }
    });

    test('chaque étape de distribution porte son 🔒', () {
      for (final heading in [
        '## 1. Serveur',
        '## 3. Android',
        '## 4. iOS',
        '## 6. Recette',
        '## 8. Soumettre',
      ]) {
        final line = doc
            .split('\n')
            .firstWhere((l) => l.startsWith(heading), orElse: () => '');
        expect(line, contains('🔒'), reason: '« $heading » n\'a plus 🔒');
      }
      expect(flat, contains('aucune ne se fait sans le feu vert explicite'));
    });

    test('soumettre la build 58, jamais la 57', () {
      final submit = _flat(_section(doc, '## 8. Soumettre'));
      expect(submit, contains('rattacher la build **`58`** — jamais la 57'));
      expect(submit, contains('pack 58 §3'));
      expect(submit, contains('Phased release for automatic updates'));
      expect(submit, contains('**déploiement par paliers à 10 %**'));
    });

    test('les chemins cités existent', () {
      final links = RegExp(
        r'`((?:docs|scripts|test|lib|\.github)/[A-Za-z0-9_./-]+\.[a-z]+)`',
      ).allMatches(doc).map((m) => m.group(1)!).toSet();
      expect(links, contains(_packPath));
      expect(links, contains(_qaPath));
      expect(links, contains('docs/release-57-store-pack.md'));
      for (final link in links) {
        expect(File(link).existsSync(), isTrue,
            reason: 'la checklist cite `$link`, qui n\'existe pas');
      }
    });
  });

  group('Pack de soumission de la build 58', () {
    final pack = _read(_packPath);
    final block = RegExp(r'```\n(SIGN-IN\n.*?)\n```', dotAll: true)
        .firstMatch(pack)
        ?.group(1);

    test('les notes de revue nomment « Pass Karatou », plus « Premium »', () {
      expect(block, isNotNull, reason: 'bloc « Notes for Review » absent');
      expect(block, contains('"Pass Karatou" is a "coming soon" screen'));
      expect(block!.contains('"Premium" is a'), isFalse);
      // Le titre de l'écran le dit vraiment.
      expect(
        _read('lib/app/core/translations/app_translations_fr.dart'),
        contains("'premium_screen_title': 'Pass Karatou'"),
      );
      // Les drapeaux fermés à la revue sont toujours nommés.
      for (final flag in [
        'features.community',
        'features.assistBridge',
        'features.referralOnboardingCode',
        'features.referralLeaderboard',
      ]) {
        expect(block, contains(flag));
      }
      expect(block.contains('ON at review time'), isFalse);
    });

    test('le texte à coller tient sous 4 000 caractères, décompte exact', () {
      final filled = block!
          .replaceAll('<ADDRESS>', 'x' * _reserveAddress)
          .replaceAll('<METHOD>', 'x' * _reserveMethod);
      expect(filled.length, lessThanOrEqualTo(_appleLimit - _minMargin));
      expect(_utf8Length(filled), lessThanOrEqualTo(_appleLimit));
      final stamp = RegExp(
        r'<!-- notes-for-review: chars=(\d+) bytes=(\d+) reserve=(\d+) -->',
      ).firstMatch(pack)!;
      expect(int.parse(stamp.group(1)!), filled.length);
      expect(int.parse(stamp.group(2)!), _utf8Length(filled));
      expect(int.parse(stamp.group(3)!), _reserveAddress + _reserveMethod);
      expect(pack, contains('${_thousands(filled.length)} caractères'));
    });

    test('les notes Google Play tiennent sous 500 caractères', () {
      final play = RegExp(
        r'\*\*Google Play — FR \(500 caractères au plus\)\*\*\n```\n(.*?)\n```',
        dotAll: true,
      ).firstMatch(pack)!.group(1)!;
      expect(play.length, lessThanOrEqualTo(_playLimit));
      expect(pack, contains('**${play.length} caractères**'));
    });
  });

  group('Fiche de recette de la build 58', () {
    final qa = _read(_qaPath);
    final rows = <String, String>{
      for (final m in RegExp(r'^\| ([A-Za-z]+-\d+) \|(.*)$', multiLine: true)
          .allMatches(qa))
        m.group(1)!: m.group(2)!,
    };

    test('les numéros sont uniques et continus par préfixe', () {
      for (final prefix in [
        'Audit',
        'Appareil',
        'Texte',
        'Lecteur',
        'Push',
        'HorsLigne',
        'Accueil',
        'Suivi',
        'Drapeau',
        'Parrain',
        'Boutique',
      ]) {
        final numbers = rows.keys
            .where((id) => id.startsWith('$prefix-'))
            .map((id) => int.parse(id.split('-').last))
            .toList();
        expect(numbers, isNotEmpty, reason: 'aucun cas $prefix-');
        expect(numbers, List<int>.generate(numbers.length, (i) => i + 1),
            reason: '$prefix- doit être numéroté 1, 2, 3… sans trou');
      }
    });

    test('chaque condition de l\'audit a sa ligne', () {
      const required = <String, List<String>>{
        'Audit-1': ['« Suivre » puis retour', 'écran noir'],
        'Audit-2': ['vraie 3G', 'Données d\'exemple'],
        'Audit-3': ['☰ invité en 1re session', 'premier tap'],
        'Audit-4': ['Être accompagné', 'opaque'],
        'Audit-7': ['Connexion Google', 'vraie 3G'],
        'Audit-8': ['Vrai mode avion', 'Connexion rétablie'],
        'Audit-17': ['Démarrage hors ligne', 'Études en France'],
        'Lecteur-12': ['VoiceOver réel'],
        'Push-1': ['Autorisation'],
        'HorsLigne-5': ['alerte d\'ouverture'],
        'Boutique-1': ['2.3.1 (58)'],
        'Drapeau-1': ['community=false', 'assistBridge=false'],
      };
      required.forEach((id, needles) {
        final row = rows[id];
        expect(row, isNotNull, reason: 'le cas $id n\'existe plus');
        for (final needle in needles) {
          expect(row, contains(needle),
              reason: 'la ligne $id ne porte plus « $needle »');
        }
      });
      expect(qa, contains('**iPhone SE**'));
      expect(qa, contains('360 × 640 dp'));
      expect(qa, contains('**en release**'));
    });
  });

  const release58 = '5332a128504e21c79ea7247685ba9ad97fbfc672';
  group('Le registre', () {
    final ledger = _read('docs/release-ledger.md');
    final consumed = ledger.split('## Courant').first;
    final courant = ledger.split('## Courant').last;

    test(
        'la 58 est consommée (téléversée le 08/11/2026, remplacée par la 59), '
        'la 57 aussi', () {
      final start58 =
          consumed.indexOf(RegExp(r'^-\s+`58`\s+—', multiLine: true));
      expect(start58, isNot(-1), reason: 'la 58 n\'est pas sous Consommés');
      final line58 = _flat(consumed.substring(start58));
      for (final needle in [
        '`2.3.1 (58)`',
        '08/11/2026',
        'jamais soumise',
        'remplacée par la 59',
        'je veux qu\'il y ait tout déjà',
        'commit archivé `$release58`',
        '42491189220',
        '42502087027',
        '`tolerates-old`',
        '--app',
      ]) {
        expect(line58, contains(needle),
            reason: 'la ligne « 58 » du registre ne dit plus « $needle »');
      }
      // Plus aucune ligne « 58 » sous Courant.
      expect(
          RegExp(r'^-\s+`58`\s+—', multiLine: true).hasMatch(courant), isFalse);
      expect(ledger, contains('Version marketing EN VENTE : `2.3.0`'));

      final start57 =
          consumed.indexOf(RegExp(r'^-\s+`57`\s+—', multiLine: true));
      expect(start57, isNot(-1), reason: 'la 57 n\'est pas sous Consommés');
      final line57 = _flat(consumed.substring(start57));
      for (final needle in [
        '25/10/2026',
        'jamais soumise',
        'remplacée par la 58',
        _archive57,
        '(`--app`) n\'a pas tourné',
      ]) {
        expect(line57, contains(needle),
            reason: 'la ligne « 57 » du registre ne dit plus « $needle »');
      }
      // Le SHA de la 58 n'est plus posé comme RELEASE : la 59, courante, est
      // avant l'archive (`build_number_test.dart`).
      expect(
        RegExp('RELEASE`?\\s*(=|:)\\s*`?$release58').hasMatch(ledger),
        isFalse,
      );
    });
  });
}
