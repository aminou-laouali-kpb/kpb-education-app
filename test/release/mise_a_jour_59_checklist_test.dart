// La checklist de la 59 est le mode d'emploi de la 58 complétée : même version
// marketing (2.3.1, jamais en vente), numéro 59, ce que le propriétaire a voulu
// dans la version de lancement (décision du 09/11/2026) : espace parent sans
// prix, « Pass Karatou », carte invité, « Déjà un compte ? », messagerie du
// dossier dans les deux sens (drapeau serveur `caseMessaging`, fermé par
// défaut), compétition des ambassadeurs corrigée. On verrouille ce qui, une
// fois faux, coûte un numéro de build ou envoie une build qui ment.
//
// Contexte (09/11/2026) : la 58 est consommée (téléversée le 08/11/2026, commit
// archivé `5332a128`, jamais soumise) ; la production sert `5332a128`. La 59
// tolère ce serveur (chaque nouveauté serveur a son repli dans l'app), d'où un
// couplage `tolerates-old` ; le serveur de la 59 se déploie APRÈS l'envoi aux
// testeurs, avant la recette de la messagerie.
//
// Révision du 13/11/2026 : la production a été déployée sur `main` (`b730a4ef`)
// AVANT l'archive. `tolerates-old` refuse une production en avance sur la
// build ; décision du propriétaire : la 59 se construit sur le commit que sert
// la production, et le préflight passe en `requires-new` (production =
// RELEASE, exactement). Plus aucun déploiement n'est dû, la recette se joue en
// un seul temps contre la production.
//
// Ce test lit les documents et le code ; il ne lance aucune commande (elles
// touchent les boutiques et la production).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _path = 'docs/mise-a-jour-59-checklist.md';
const _packPath = 'docs/release-59-store-pack.md';
const _qaPath = 'docs/device-qa-build59.md';

/// Le backend de production au 09/11/2026 : le commit archivé de la 58,
/// déployé après son envoi.
const _production = '5332a128';

/// La dernière migration du déploiement de la 58, et la seule de la 59.
const _lastMigration58 = '20261108120000_case_message_client_id';
const _migration59 = '20261109120000_case_message_case_created_idx';

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

({String name, String build}) _pubspec() {
  final m = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(_read('pubspec.yaml'))!;
  return (name: m.group(1)!, build: m.group(2)!);
}

String _expected(String script, String variable) =>
    RegExp('^$variable="([^"]*)"', multiLine: true)
        .firstMatch(_read(script))!
        .group(1)!;

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
  group('La checklist de la 59', () {
    final doc = _read(_path);
    final flat = _flat(doc);

    test('porte la version 2.3.1 (59) et plus aucune commande de la 58', () {
      final shipping = _pubspec();
      expect(
        shipping.build,
        '59',
        reason: 'pubspec.yaml porte +${shipping.build}, pas la 59 préparée '
            'par cette checklist',
      );
      expect(shipping.name, '2.3.1');
      expect(doc, contains('${shipping.name} (59)'));
      expect(doc, contains('version: ${shipping.name}+59'));
      expect(doc, contains('FLUTTER_BUILD_NUMBER=59'));
      expect(doc, contains('Préflight iOS OK — 2.3.1 (59)'));
      expect(doc, contains('Préflight Android OK — 2.3.1 (59)'));
      expect(doc, contains('../kpb-release-59'));
      for (final stale in [
        'FLUTTER_BUILD_NUMBER=58',
        'Préflight iOS OK — 2.3.1 (58)',
        'Préflight Android OK — 2.3.1 (58)',
        '../kpb-release-58',
        'EXPECTED_VERSION_CODE="58"',
        'EXPECTED_BUILD="58"',
        'backend_coupling=tolerates-old',
        'version: 2.3.1+58`',
      ]) {
        expect(
          doc.contains(stale),
          isFalse,
          reason: 'la checklist de la 59 contient encore « $stale »',
        );
      }
      // Les préflights attendent la build que la checklist décrit.
      expect(_expected('scripts/preflight-ios-archive.sh', 'EXPECTED_BUILD'),
          '59');
      expect(_expected('scripts/preflight-ios-archive.sh', 'EXPECTED_VERSION'),
          '2.3.1');
      expect(
          _expected(
              'scripts/preflight-android-aab.sh', 'EXPECTED_VERSION_CODE'),
          '59');
      expect(
          _expected(
              'scripts/preflight-android-aab.sh', 'EXPECTED_VERSION_NAME'),
          '2.3.1');
      // Les messages d'erreur du préflight iOS renvoient à CETTE checklist.
      final ios = _read('scripts/preflight-ios-archive.sh');
      expect(ios, contains('docs/mise-a-jour-59-checklist.md, étape 4'));
      expect(ios, isNot(contains('docs/mise-a-jour-58-checklist.md')));
    });

    test('même version marketing : 2.3.0 en vente, 2.3.1 jamais vendue', () {
      expect(flat, contains('ITMS-90062'));
      expect(flat, contains('**2.3.0 en vente**'));
      final prep = _section(doc, '### 0.2');
      expect(prep, contains('`version: 2.3.1+59`'));
      expect(prep, contains('EXPECTED_BUILD="59"'));
      expect(prep, contains('EXPECTED_VERSION_CODE="59"'));
      expect(prep, contains('Version marketing EN VENTE : `2.3.0`'));
      expect(prep, contains('mise_a_jour_58_checklist_test.dart'));
      expect(prep, contains('« REMPLACÉE par la 59 »'));
      // Les papiers de la 58 portent ce bandeau.
      for (final paper in [
        'docs/mise-a-jour-58-checklist.md',
        'docs/release-58-store-pack.md',
        'docs/device-qa-build58.md',
      ]) {
        expect(_read(paper), contains('REMPLACÉE par la 59 le 09/11/2026'),
            reason: '$paper sans bandeau');
      }
      // La décision du propriétaire est citée.
      expect(flat, contains('« je veux qu\'il y ait tout déjà »'));
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

    test('§0.3 : seule la ligne version bouge dans pubspec.yaml depuis la 58',
        () {
      final step = _section(doc, '### 0.3');
      expect(step, contains('git log --oneline --first-parent $_production'));
      expect(step, contains(r"grep -v '^[+-][[:space:]]*#'"));
      final expected = RegExp(r'^#     ([+-].*)$', multiLine: true)
          .allMatches(step)
          .map((m) => m.group(1)!)
          .toList();
      expect(expected, ['-version: 2.3.1+58', '+version: 2.3.1+59']);
      final pubspecLines = _read('pubspec.yaml').split('\n').toSet();
      expect(pubspecLines, contains('version: ${_pubspec().name}+59'));
      expect(pubspecLines.contains('version: 2.3.1+58'), isFalse);
      final flatStep = _flat(step);
      // Les commits de la 59, nommés.
      for (final commit in [
        '#409',
        '7b6804ad',
        '39fcd758',
        'ce0138d7',
        '595a1813',
        'c263f322',
        '0c19e934',
      ]) {
        expect(flatStep, contains(commit));
      }
      expect(flatStep,
          contains('attendu : RIEN (aucune dépendance, aucun manifeste'));
      expect(step, contains('ios/Podfile.lock'));
    });

    test('backend : requires-new, la production sert exactement RELEASE', () {
      final step1 = _section(doc, '## 1. Serveur et admin');
      expect(step1, contains('déjà en production depuis le 13/11/2026'));
      expect(step1,
          contains('git merge-base --is-ancestor $_production "\$RELEASE"'));
      expect(
        step1,
        contains('git diff --stat $_production "\$RELEASE" -- backend admin '
            'docker-compose.yml'),
      );
      final flat1 = _flat(step1);
      expect(
          flat1,
          contains(
              '**Ne déployer aucun autre commit avant la fin du préflight.**'));
      expect(flat1, contains('**avant** l\'archive'));
      expect(flat1, isNot(contains('dû après')));
      expect(
          flat1,
          contains(
              '**Aucune opération serveur obligatoire après le déploiement.**'));
      // RELEASE est relevé ET comparé au SHA servi, avant l'archive (§0.3),
      // puis revérifié au départ (§2) : un écart fait échouer le préflight.
      for (final heading in ['### 0.3', '## 2. Vérifications']) {
        expect(
          _section(doc, heading),
          contains('test "\$PROD" = "\${RELEASE:0:\${#PROD}}"'),
          reason: '$heading ne compare plus la production à RELEASE',
        );
      }
      expect(
          _flat(_section(doc, '### 0.3')),
          contains(
              'plus rien ne se fusionne sur `main` et plus rien ne se déploie'));
      // La seule migration de la 59, vérifiée sur le disque : une de plus ou
      // de moins casse ce test.
      expect(step1, contains(_migration59));
      final migrations = Directory('backend/prisma/migrations')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.where((p) => p.isNotEmpty).last)
          .where((n) => n.compareTo(_lastMigration58) > 0)
          .toList();
      expect(migrations, [_migration59]);
      // Additive : un index, rien d'autre.
      final sql = _read('backend/prisma/migrations/$_migration59/migration.sql')
          .split('\n')
          .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('--'))
          .toList();
      expect(sql, hasLength(1));
      expect(sql.single, startsWith('CREATE INDEX IF NOT EXISTS'));

      expect(flat, contains('**Couplage backend : `requires-new`**'));
      expect(flat, contains('**Révision du 13/11/2026'));
      // Le registre dit le même couplage, avec sa raison.
      final ledger = _read('docs/release-ledger.md');
      final entry = ledger.substring(
        ledger.indexOf('### Préparation de la build 59'),
      );
      expect(entry, contains('**Couplage backend : `tolerates-old`.**'));
      expect(entry, contains(_production));
    });

    // Le `tolerates-old` n'est vrai que si l'app a un repli pour chaque
    // nouveauté serveur : on le relit dans le code.
    test('tolerates-old : chaque nouveauté serveur a son repli dans l\'app',
        () {
      final flags = _read('lib/app/core/services/remote_feature_flags.dart');
      expect(
          flags,
          contains("_flag('caseMessaging', "
              'AppConfig.caseInAppMessagingEnabled)'));
      expect(_read('lib/app/core/config/app_config.dart'),
          contains('_caseInAppMessagingEnabledOverride ?? false'));
      // Le dossier garde WhatsApp, drapeau ouvert ou non.
      final detail = _read('lib/app/features/cases/case_detail_screen.dart');
      expect(
          detail,
          contains(
              'if (RemoteFeatureFlags.instance.caseMessagingEnabled) ...['));
      expect(detail, contains('_WriteAdvisorOnWhatsAppButton('));
      // Compétition : `ineligible` absent = 0, refus lus au message anglais.
      expect(_read('lib/app/core/models/referral_campaign.dart'),
          contains("ineligible: _count(me['ineligible'])"));
      final redeem = _read('lib/app/core/services/referral_attribution.dart');
      for (final fallback in ['own referral code', 'first request', 'mutual']) {
        expect(redeem, contains("message.contains('$fallback')"));
      }
      // Côté serveur : la clé est servie FERMÉE par défaut, relayée par
      // compose avec le défaut `false`.
      expect(
          _read('backend/src/modules/config/app-config.controller.ts'),
          contains(
              'caseMessaging: enabled(process.env.KPB_CASE_MESSAGING_ENABLED)'));
      expect(
          _read('docker-compose.yml'),
          contains(
              r'- KPB_CASE_MESSAGING_ENABLED=${KPB_CASE_MESSAGING_ENABLED:-false}'));
      expect(
          _read('.env.example'), contains('KPB_CASE_MESSAGING_ENABLED=false'));
      // La saisie élève appelle une route que la production sert déjà.
      expect(_read('backend/src/modules/cases/cases.controller.ts'),
          contains("@Post(':id/messages')"));
    });

    test('les ouvertures après le déploiement : facultatives, par VPS ops', () {
      final after = _flat(_section(doc, '## 9.'));
      expect(after, contains('`case-messaging-on`'));
      expect(after, contains('`case-messaging-off`'));
      expect(
          after,
          contains(
              '**seulement quand l\'équipe est prête à répondre depuis l\'administration**'));
      expect(after, contains('`scholarship-match-on`'));
      expect(after, contains('validation juridique'));
      expect(after, contains('la carte invité de la 59 n\'apparaît pas'));
      final workflow = _read('.github/workflows/vps-ops.yml');
      for (final action in [
        'case-messaging-on',
        'case-messaging-off',
        'scholarship-match-on',
        'scholarship-match-off',
      ]) {
        expect(workflow, contains('          - $action\n'));
      }
      // Fermer la fenêtre de recette avant la soumission.
      final recette = _flat(_section(doc, '## 6.'));
      expect(recette, contains('`case-messaging-off`'));
      // Révision du 13/11/2026 : un seul temps, contre la production qui sert
      // déjà le serveur de la 59 ; l'ancien temps A est dit injouable.
      expect(recette, contains('**Contre la production**'));
      expect(recette, contains('n\'est plus jouable depuis le 13/11/2026'));
    });

    test('le préflight : requires-new, ref, dérogation après la preuve', () {
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
      expect(proof, lessThan(waiver));
      expect(doc, contains('n\'est PAS une preuve'));
      expect(_read('.github/workflows/release-preflight.yml'),
          contains('- requires-new'));
    });

    test('le préflight de l\'IPA exportée reste obligatoire', () {
      final ios = _section(doc, '## 4. iOS');
      final flatIos = _flat(ios);
      expect(
        ios,
        contains('scripts/preflight-ios-archive.sh --xcconfig '
            'ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app'),
      );
      expect(flatIos, contains('obligatoire pour la 59'));
      expect(flatIos, contains('**Export**'));
      expect(flatIos,
          contains('Pas d\'envoi direct depuis l\'Organizer sans ce contrôle'));
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
      expect(android, contains('42491189220'));
      expect(android, contains('37322572087'));
      expect(android, contains('36945000021'));
      expect(android, contains('de la 56 ou de la 57'));
      expect(doc, contains('plus rien ne se fusionne'));
    });

    test('la recette suit les conditions de l\'audit, et celles de la 59', () {
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
        '**la réponse de l\'équipe dans un dossier**',
        '**connexion Google**',
        '**un compte existant sur une installation neuve**',
        '**☰ invité en 1re session**',
        '**« Suivre » puis retour**',
        '**« Être accompagné »**',
        '**espace parent sans prix**',
        '**WhatsApp toujours présent**',
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

    test('soumettre la build 59, jamais la 58 ni la 57', () {
      final submit = _flat(_section(doc, '## 8. Soumettre'));
      expect(submit,
          contains('rattacher la build **`59`** — jamais la 58 ni la 57'));
      expect(submit, contains('pack 59 §3'));
      expect(submit, contains('`caseMessaging=false`'));
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

  group('Pack de soumission de la build 59', () {
    final pack = _read(_packPath);
    final block = RegExp(r'```\n(SIGN-IN\n.*?)\n```', dotAll: true)
        .firstMatch(pack)
        ?.group(1);

    test('aucun prix annoncé, « Pass Karatou », caseMessaging déclarée', () {
      expect(block, isNotNull, reason: 'bloc « Notes for Review » absent');
      expect(block, contains('no price is shown in the app'));
      expect(block!.contains('price is shown for information'), isFalse);
      expect(block, contains('"Pass Karatou" is a "coming soon" screen'));
      expect(block.contains('"Premium" is a'), isFalse);
      // Chaque drapeau fermé à la revue, et la clé de la 59.
      for (final flag in [
        'features.scholarshipMatch',
        'features.onboardingV2',
        'features.community',
        'features.assistBridge',
        'features.referralOnboardingCode',
        'features.referralLeaderboard',
        'features.caseMessaging',
      ]) {
        expect(block, contains(flag));
      }
      final off = block.indexOf('OFF at review time');
      expect(off, isNot(-1));
      expect(block.indexOf('features.caseMessaging'), greaterThan(off));
      expect(block.contains('ON at review time'), isFalse);
      // Le code dit la même chose que les notes : aucun prix côté parent.
      final parent =
          _read('lib/app/features/parent/parent_surface_screen.dart');
      expect(parent, isNot(contains('FCFA')));
      final fr = _read('lib/app/core/translations/app_translations_fr.dart');
      expect(fr, contains("'parent_nav_pay': 'Accompagnement'"));
      expect(fr, contains("'parent_pay_cta': 'Demander le tarif'"));
      expect(fr, contains("'premium_screen_title': 'Pass Karatou'"));
      // La compétition fermée à la revue, ou les notes à réécrire.
      final flatPack = _flat(pack);
      expect(flatPack,
          contains('**La compétition doit rester fermée pendant la revue**'));
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

    test('le tableau des drapeaux du pack 57 connaît caseMessaging', () {
      final pack57 = _read('docs/release-57-store-pack.md');
      expect(
          pack57,
          contains(
              '| `caseMessaging` | `KPB_CASE_MESSAGING_ENABLED` | fermé |'));
      expect(pack57, contains('`case-messaging-on` / `case-messaging-off`'));
    });
  });

  group('Fiche de recette de la build 59', () {
    final qa = _read(_qaPath);
    final rows = <String, String>{
      for (final m in RegExp(r'^\| ([A-Za-z]+-\d+) \|(.*)$', multiLine: true)
          .allMatches(qa))
        m.group(1)!: m.group(2)!,
    };

    test('les numéros sont uniques et continus par préfixe', () {
      for (final prefix in [
        'Nouveau',
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
      // Pas de doublon caché par la table : chaque identifiant une seule fois.
      final all = RegExp(r'^\| ([A-Za-z]+-\d+) \|', multiLine: true)
          .allMatches(qa)
          .map((m) => m.group(1)!)
          .toList();
      expect(all.toSet().length, all.length);
    });

    test('chaque changement de la 59 a sa ligne', () {
      const required = <String, List<String>>{
        'Nouveau-1': ['« Accompagnement »', 'sans aucun prix'],
        'Nouveau-2': ['« Demander le tarif »', 'WhatsApp'],
        'Nouveau-3': ['« Pass Karatou » partout', 'Aucun « Premium »'],
        'Nouveau-4': ['« Déjà un compte ? »'],
        'Nouveau-5': ['installation neuve', 'aucun second compte'],
        'Nouveau-6': ['Carte invité', 'Découvre les bourses'],
        'Nouveau-7': ['inscription', 'test'],
        'Nouveau-9': ['Messagerie fermée', '5332a128', 'WhatsApp'],
        'Nouveau-10': ['de bout en bout', 'bouton WhatsApp reste'],
        'Nouveau-11': ['administration'],
        'Nouveau-12': ['t\'a répondu', 'déjà dans le fil'],
        'Nouveau-14': ['case-messaging-off'],
        'Nouveau-15': ['Compétition', 'règlement'],
        'Nouveau-16': ['Ne compte'],
        'Nouveau-17': ['Refus expliqués', '5332a128'],
        'Nouveau-18': ['Fin de compétition'],
        'Audit-21': ['WhatsApp'],
        'Lecteur-12': ['VoiceOver réel'],
        'Push-1': ['Autorisation'],
        'HorsLigne-5': ['alerte d\'ouverture'],
        'Boutique-1': ['2.3.1 (59)'],
        'Drapeau-1': [
          'community=false',
          'assistBridge=false',
          'caseMessaging=false'
        ],
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
      expect(qa, contains('**Contre la production, en un seul temps**'));
      expect(qa, contains('n\'est plus\n>   jouable'));
      // Plus aucune attente de la 58 sur la build installée.
      expect(rows['Boutique-1'], isNot(contains('→ 58')));
    });
  });

  group('Le registre', () {
    final ledger = _read('docs/release-ledger.md');
    final consumed = ledger.split('## Courant').first;
    final courant = ledger.split('## Courant').last;

    test('la 59 est courante, avant l\'archive ; la 58 est consommée', () {
      final first = RegExp(r'^-\s+`(\d+)`\s+—', multiLine: true)
          .firstMatch(courant)!
          .group(1);
      expect(first, _pubspec().build);
      expect(first, '59');
      final line59 = _flat(courant.substring(0, courant.indexOf('\n### ')));
      expect(line59, contains('`2.3.1 (59)`'));
      for (final before in [
        'EN COURS (archive à faire)',
        'non téléversée',
        '`<RELEASE>`',
      ]) {
        expect(line59, contains(before),
            reason: 'la ligne « 59 » perd un marqueur « avant » : $before');
      }
      expect(line59, contains('**`requires-new`** depuis le 13/11/2026'));
      expect(line59, contains('caseMessaging'));
      for (final paper in [_path, _packPath, _qaPath]) {
        expect(line59, contains(paper));
      }
      expect(ledger, contains('Version marketing EN VENTE : `2.3.0`'));

      final start58 =
          consumed.indexOf(RegExp(r'^-\s+`58`\s+—', multiLine: true));
      expect(start58, isNot(-1), reason: 'la 58 n\'est pas sous Consommés');
      final line58 = _flat(consumed.substring(start58));
      for (final needle in [
        '08/11/2026',
        'jamais soumise',
        'remplacée par la 59',
        '09/11/2026',
      ]) {
        expect(line58, contains(needle));
      }
      // Avant l'archive de la 59, aucun SHA n'est posé comme RELEASE.
      expect(
        RegExp(r'RELEASE`?\s*(=|:)\s*`?[0-9a-f]{40}').hasMatch(ledger),
        isFalse,
      );
    });
  });
}
