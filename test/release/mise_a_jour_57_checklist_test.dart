// La checklist de la 57 est le mode d'emploi de la release unique : on verrouille
// ce qui, une fois faux, coûte un numéro de build, une semaine sans
// notifications ou un écran bloquant pour tout le parc.
//
// Contexte (constat du 16/10/2026) : la 2.3.0 est en vente ; la 57 doit donc
// partir en 2.3.1 (ITMS-90062), et elle n'embarque plus le SDK OneSignal — sans
// le backend de #351, elle ne reçoit aucune notification. D'où un couplage
// `requires-new` et l'ordre serveur → admin → app.
//
// La version est posée depuis le 18/10/2026 (`pubspec.yaml` : `2.3.1+57`, PR de
// préparation, checklist §0.2) : le test exige la 57 et que la checklist nomme
// la version réellement posée.
//
// Ce test lit les documents ; il ne lance aucune commande (elles touchent les
// boutiques et la production).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _path = 'docs/mise-a-jour-57-checklist.md';

String _read(String path) => File(path).readAsStringSync();

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

({String name, String build}) _pubspec() {
  final m = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(_read('pubspec.yaml'))!;
  return (name: m.group(1)!, build: m.group(2)!);
}

void main() {
  group('La checklist de la 57', () {
    final doc = _read(_path);
    final flat = doc.replaceAll(RegExp(r'\s+'), ' ');

    test('porte la version 2.3.1 (57) et plus aucun contrôle sur 56', () {
      final shipping = _pubspec();
      expect(
        shipping.build,
        '57',
        reason: 'pubspec.yaml porte +${shipping.build}, pas la 57 préparée '
            'par cette checklist',
      );
      // La PR de préparation est faite : la checklist doit nommer la version
      // réellement posée (2.3.1, choisie par le propriétaire).
      expect(shipping.name, '2.3.1');
      expect(doc, contains('${shipping.name} (57)'));
      expect(doc, contains('version: ${shipping.name}+57'));
      expect(doc, contains('FLUTTER_BUILD_NUMBER=57'));
      expect(doc, contains('Préflight iOS OK — 2.3.1 (57)'));
      expect(doc, contains('Préflight Android OK — 2.3.1 (57)'));
      expect(doc, contains('../kpb-release-57'));
      for (final stale in [
        'FLUTTER_BUILD_NUMBER=56',
        'Préflight iOS OK — 2.3.0',
        'Préflight Android OK — 2.3.0',
        '../kpb-release-56',
        'EXPECTED_VERSION_CODE="56"',
        'backend_coupling=tolerates-old',
      ]) {
        expect(
          doc.contains(stale),
          isFalse,
          reason: 'la checklist de la 57 contient encore « $stale »',
        );
      }
    });

    test('la version marketing est 2.3.1 parce que 2.3.0 est en vente', () {
      expect(flat, contains('ITMS-90062'));
      expect(flat, contains('**2.3.0 en vente**'));
      final prep = _section(doc, '### 0.2');
      expect(prep, contains('`version: 2.3.1+57`'));
      expect(prep, contains('EXPECTED_BUILD="57"'));
      expect(prep, contains('EXPECTED_VERSION_CODE="57"'));
      // Le registre : version en vente, 56 consommée, 57 courante — et ce qui
      // n'est pas dans le dépôt reste À VALIDER, jamais inventé.
      expect(prep, contains('Version marketing EN VENTE : `2.3.0`'));
      expect(prep, contains('À VALIDER (propriétaire)'));
      expect(prep, contains('mise_a_jour_56_checklist_test.dart'));
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
        expect(
          re.hasMatch(doc),
          isFalse,
          reason: 'la checklist contient : $name',
        );
      });
    });

    test('serveur, puis admin, puis app — dans cet ordre', () {
      final server = doc.indexOf('## 1. Serveur, puis admin');
      final android = doc.indexOf('## 3. Android');
      final ios = doc.indexOf('## 4. iOS');
      final preflight = doc.indexOf('## 5. Préflight');
      expect(server, isNot(-1));
      expect(android, greaterThan(server));
      expect(ios, greaterThan(android));
      expect(preflight, greaterThan(ios));
      final step1 = _section(doc, '## 1. Serveur, puis admin');
      expect(step1, contains('`deploy.yml`'));
      expect(step1, contains('`scope` = `full`'));
      expect(step1, contains('`ref` = `RELEASE`'));
      expect(step1, contains('**`api` puis `admin`**'));
      expect(step1, contains('FCM_SERVICE_ACCOUNT_JSON'));
      // Les six migrations, chacune nommée et présente dans le dépôt.
      final migrations = RegExp(
        r'`(2026\d{10}_[a-z0-9_]+)`',
      ).allMatches(step1).map((m) => m.group(1)!).toSet();
      expect(migrations, hasLength(6));
      for (final migration in migrations) {
        expect(
          File(
            'backend/prisma/migrations/$migration/migration.sql',
          ).existsSync(),
          isTrue,
          reason: 'la migration $migration n\'existe pas',
        );
      }
    });

    test('le préflight : requires-new, ref, dérogation après la preuve', () {
      final blocks = _blocksAt(doc);
      final launch = blocks
          .where(
            (b) => b.text.contains('gh workflow run release-preflight.yml'),
          )
          .toList();
      expect(launch, hasLength(1));
      final command = launch.single.text.replaceAll(RegExp(r'\\\s*\n\s*'), ' ');
      for (final part in [
        '--ref main',
        r'-f ref="$RELEASE"',
        '-f backend_coupling=requires-new',
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
      expect(
        proof,
        lessThan(waiver),
        reason: 'la dérogation est lancée avant la preuve des sondes',
      );
      expect(doc, contains('n\'est PAS une preuve'));
    });

    test('la production est vérifiée AVANT l\'app : SHA, FCM, drapeaux', () {
      final step2 = _section(
        doc,
        '## 2. Vérifications',
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(step2, contains(r'"${RELEASE:0:12}"'));
      expect(step2, contains(".push"));
      expect(step2, contains('`push.fcm`'));
      expect(step2, contains('scholarshipMatch'));
      expect(step2, contains('onboardingV2'));
      expect(step2.toLowerCase(), contains('ne pas continuer'));
    });

    test('la clé PostHog : saisie seule, longueur, --posthog-only après', () {
      final blocks = _blocksAt(doc);
      final readers = blocks.where(
        (b) => b.text.contains('read -rs POSTHOG_API_KEY'),
      );
      expect(readers, isNotEmpty);
      for (final block in readers) {
        expect(block.text, isNot(contains('flutter build')));
        expect(
          block.text.trim().split('\n').where((l) => !l.startsWith('#')).length,
          1,
        );
      }
      final build = blocks.indexWhere(
        (b) =>
            b.text.contains('flutter build ios --release') &&
            b.text.contains('--dart-define=POSTHOG_API_KEY='),
      );
      final only = blocks.indexWhere((b) => b.text.contains('--posthog-only'));
      expect(build, isNot(-1));
      expect(only, greaterThan(build));
      expect(doc.indexOf('Product → Archive', blocks[only].end), isNot(-1));
      expect(doc, contains(r'${#POSTHOG_API_KEY}'));
    });

    test('les anciens AAB sont interdits d\'import, nommés', () {
      final android = _section(doc, '## 3. Android');
      expect(android, contains('NE PAS importer'));
      expect(android, contains('37322572087'));
      expect(android, contains('36945000021'));
      expect(android, contains('release_android'));
      expect(doc, contains('plus rien ne se fusionne'));
    });

    test('paliers Play 10 → 50 → 100 %, publication progressive iOS', () {
      final rollout = _section(doc, '## 9.');
      final flatRollout = rollout.replaceAll(RegExp(r'\s+'), ' ');
      final p10 = flatRollout.indexOf('**Play 10 %**');
      final p50 = flatRollout.indexOf('**50 %**');
      final p100 = flatRollout.indexOf('**100 %**');
      expect(p10, isNot(-1));
      expect(p50, greaterThan(p10));
      expect(p100, greaterThan(p50));
      expect(flatRollout, contains('phased release'));
      expect(flatRollout, contains('1,09 %'));
      expect(flatRollout, contains('0,47 %'));
      final submit = _section(
        doc,
        '## 8. Soumettre',
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(submit, contains('Phased release for automatic updates'));
      expect(submit, contains('**déploiement par paliers à 10 %**'));
    });

    test('recommendedVersion = version marketing ; minVersion à 85 %', () {
      final rollout = _section(doc, '## 9.').replaceAll(RegExp(r'\s+'), ' ');
      expect(rollout, contains('**`KPB_RECOMMENDED_APP_VERSION=2.3.1`**'));
      expect(
        rollout,
        contains('la **version marketing**, jamais le numéro de build'),
      );
      expect(rollout, contains('`lib/app/core/utils/version_utils.dart`'));
      expect(
        rollout,
        contains('`lib/app/core/services/app_version_gate.dart`'),
      );
      expect(rollout, contains('**environ 85 %**'));
      expect(rollout, contains('`GET /admin/app-builds`'));
      // Et le code dit toujours ce que la consigne suppose.
      expect(
        _read('lib/app/core/utils/version_utils.dart'),
        contains("split('+').first"),
      );
    });

    test('mode d\'ouverture : legacy → outbox_alerts → outbox_followers', () {
      final rollout = _section(doc, '## 9.');
      final legacy = rollout.indexOf('`KPB_SCHOLARSHIP_OPENING_MODE=legacy`');
      final alerts = rollout.indexOf('`outbox_alerts`');
      final dry = rollout.indexOf(
        '`npm run follow:mirror-alerts` (simulation)',
      );
      final followers = rollout.indexOf('`outbox_followers`');
      final apply = rollout.indexOf(
        '`npm run follow:mirror-alerts -- --apply`',
      );
      expect(legacy, isNot(-1));
      expect(alerts, greaterThan(legacy));
      expect(dry, greaterThan(alerts));
      expect(followers, greaterThan(dry));
      expect(apply, greaterThan(followers));
      // Le test « Mes 10 bourses » s'ouvre en dernier, jamais à la soumission.
      final match = rollout.indexOf('**`KPB_SCHOLARSHIP_MATCH_ENABLED=true`**');
      expect(match, greaterThan(apply));
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

    test('les chemins cités existent', () {
      final links = RegExp(
        r'`((?:docs|scripts|test|lib|\.github)/[A-Za-z0-9_./-]+\.[a-z]+)`',
      ).allMatches(doc).map((m) => m.group(1)!).toSet();
      expect(links, contains('docs/release-57-store-pack.md'));
      expect(links, contains('docs/device-qa-build57.md'));
      for (final link in links) {
        expect(
          File(link).existsSync(),
          isTrue,
          reason: 'la checklist cite `$link`, qui n\'existe pas',
        );
      }
    });
  });

  test('le registre consigne le chantier L et la 57 posée en courant', () {
    final ledger = _read('docs/release-ledger.md');
    expect(ledger, contains('### Chantier L (16/10/2026)'));
    final courant = ledger.split('## Courant').last;
    // Le premier numéro sous « Courant » suit pubspec : la 57 y est posée par
    // la préparation du 18/10/2026, la 56 est passée sous « Consommés ».
    final first = RegExp(
      r'^-\s+`(\d+)`\s+—',
      multiLine: true,
    ).firstMatch(courant)!.group(1);
    expect(first, _pubspec().build);
    // La 56 est consommée, la 2.3.0 en vente ; ce que le dépôt ne sait pas
    // (build réellement en vente, date, SHA) reste À VALIDER, jamais inventé.
    expect(ledger, contains('Version marketing EN VENTE : `2.3.0`'));
    final consumed = ledger.split('## Courant').first;
    final line56 = consumed.substring(
      consumed.indexOf(RegExp(r'^-\s+`56`\s+—', multiLine: true)),
    );
    expect(line56, contains('À VALIDER (propriétaire)'));
    expect(courant, contains('`<RELEASE>`'));
    final entry = ledger.substring(ledger.indexOf('### Chantier L'));
    expect(entry, contains('`requires-new`'));
    expect(entry, contains('2.3.1'));
    expect(entry, contains('À VALIDER (propriétaire)'));
  });
}
