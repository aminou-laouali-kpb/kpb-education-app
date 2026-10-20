// Cliquet LIV-T15 : toute variable lue par `/config/app` doit être RELAYÉE
// dans `docker-compose.yml` et DOCUMENTÉE dans `.env.example`.
//
// ## Le défaut que ce fichier existe pour interdire
//
// `docker-compose.yml` n'a aucun `env_file`. Le `.env` du VPS ne sert qu'à
// l'INTERPOLATION du fichier compose : une variable doit être listée
// explicitement dans le bloc `environment:` du service pour entrer dans le
// conteneur. Rien ne le rappelle, et rien ne le vérifiait.
//
// Mesuré : les cinq variables `KPB_EEF_*` de la Phase 0 « Études en France »
// ont été posées dans `.env.example`, dans `docs/release-ledger.md` et dans
// l'étape d'activation de `docs/cutover-build49.md` — et jamais dans
// `docker-compose.yml`. L'étape d'activation ne pouvait donc pas fonctionner :
// l'opérateur aurait posé les variables, relancé le service, lu
// `eefTeaser: false`, et le runbook l'aurait envoyé chercher une faute de
// frappe dans un fichier qui n'en avait pas. Les onze variables antérieures,
// elles, étaient toutes relayées : le motif était respecté par tous les auteurs
// précédents, et rien ne signalait la rupture.
//
// C'est le genre de défaut qu'un test unitaire ne peut pas voir : le contrôleur
// lit `process.env` correctement, et le prouver en passant l'environnement à la
// main prouve le code, pas le déploiement.
//
// ## Ce que ce cliquet ne prouve pas
//
// Que la valeur posée en production est la bonne. Il prouve que le chemin
// existe. La valeur se vérifie par `curl /config/app` après bascule, ce que
// `scripts/delivery-gate.sh` fait.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `process.env.KPB_QUELQUE_CHOSE` dans la source du contrôleur.
final _envRead = RegExp(r'process\.env\.(KPB_[A-Z0-9_]+)');

/// `      - KPB_QUELQUE_CHOSE=...` dans le bloc environment d'un service.
final _composeRelay = RegExp(r'^\s*-\s+(KPB_[A-Z0-9_]+)=', multiLine: true);

/// `KPB_QUELQUE_CHOSE=` en début de ligne dans `.env.example`, commenté ou non.
final _envExampleDecl = RegExp(r'^\s*#?\s*(KPB_[A-Z0-9_]+)=', multiLine: true);

Set<String> _read(RegExp pattern, String path) {
  final text = File(path).readAsStringSync();
  return pattern.allMatches(text).map((m) => m.group(1)!).toSet();
}

void main() {
  const controllerPath = 'backend/src/modules/config/app-config.controller.ts';

  final read = _read(_envRead, controllerPath);
  final relayed = _read(_composeRelay, 'docker-compose.yml');
  final documented = _read(_envExampleDecl, '.env.example');

  test('l\'extraction lit encore les sources — garde morte, sinon', () {
    // Si le contrôleur est renommé ou l'expression cassée, les trois ensembles
    // deviennent vides et tous les tests ci-dessous passent en ne prouvant
    // rien. C'est le mode d'échec habituel de ce genre de cliquet.
    expect(
      read.length,
      greaterThan(10),
      reason: 'Aucune variable extraite de $controllerPath : garde morte.',
    );
    expect(relayed.length, greaterThan(30),
        reason: 'Aucune variable extraite de docker-compose.yml.');
    expect(documented, isNotEmpty,
        reason: 'Aucune variable extraite de .env.example.');
  });

  test('chaque variable lue par /config/app entre dans le conteneur', () {
    final missing = read.difference(relayed).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Ces variables sont lues par le contrôleur mais ABSENTES du bloc '
          'environment: de docker-compose.yml. Le .env ne sert qu\'à '
          'l\'interpolation — une variable non relayée n\'atteint jamais le '
          'conteneur, et la poser en production n\'a aucun effet :\n'
          '${missing.map((v) => '  - $v').join('\n')}',
    );
  });

  test('chaque variable lue par /config/app est documentée dans .env.example',
      () {
    final missing = read.difference(documented).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Ces variables gouvernent une surface visible par les '
          'utilisateurs et ne sont documentées nulle part. L\'exploitation ne '
          'peut pas poser ce qu\'elle ne sait pas exister :\n'
          '${missing.map((v) => '  - $v').join('\n')}',
    );
  });

  // Non-vacuité, nommément : le test générique ci-dessus ne rougit que si le
  // contrôleur LIT la variable. Si quelqu'un retire la lecture, les deux
  // interrupteurs disparaissent de /config/app sans qu'aucun test générique ne
  // le voie — l'app lirait alors « clé absente » pour toujours.
  test('les interrupteurs de la 56 sont lus, relayés et documentés', () {
    for (final variable in [
      'KPB_EEF_HELP_BUBBLE_ENABLED',
      'KPB_EEF_PRIVATE_SCHOOLS_ENABLED',
    ]) {
      expect(read, contains(variable),
          reason: '$controllerPath ne lit plus $variable.');
      expect(relayed, contains(variable),
          reason: '$variable n\'est pas relayée dans docker-compose.yml.');
      expect(documented, contains(variable),
          reason: '$variable n\'est pas documentée dans .env.example.');
    }
  });

  // « Mes 10 bourses » (chantier D) : une variable pour la carte de l'app
  // (`features.scholarshipMatch`) ET les routes /scholarships/match/*. Livrée
  // éteinte : un défaut `true` dans compose ouvrirait le test en production au
  // premier redéploiement, avant la validation juridique de la collecte.
  test('le drapeau « Mes 10 bourses » est lu, relayé, documenté et fermé', () {
    const variable = 'KPB_SCHOLARSHIP_MATCH_ENABLED';
    expect(read, contains(variable),
        reason: '$controllerPath ne lit plus $variable.');
    expect(relayed, contains(variable),
        reason: '$variable n\'est pas relayée dans docker-compose.yml.');
    expect(documented, contains(variable),
        reason: '$variable n\'est pas documentée dans .env.example.');
    expect(
      File('docker-compose.yml').readAsStringSync(),
      contains('- $variable=\${$variable:-false}'),
      reason:
          '$variable doit avoir `false` pour défaut dans docker-compose.yml.',
    );
  });

  // Onboarding « la valeur d'abord » (chantier I3) : `features.onboardingV2`,
  // FERMÉ par défaut. Un défaut `true` dans compose basculerait tout le parc
  // installé sur le nouveau parcours au premier redéploiement.
  test('le drapeau « onboardingV2 » est lu, relayé, documenté et fermé', () {
    const variable = 'KPB_ONBOARDING_V2_ENABLED';
    expect(read, contains(variable),
        reason: '$controllerPath ne lit plus $variable.');
    expect(relayed, contains(variable),
        reason: '$variable n\'est pas relayée dans docker-compose.yml.');
    expect(documented, contains(variable),
        reason: '$variable n\'est pas documentée dans .env.example.');
    expect(
      File('docker-compose.yml').readAsStringSync(),
      contains('- $variable=\${$variable:-false}'),
      reason:
          '$variable doit avoir `false` pour défaut dans docker-compose.yml.',
    );
    expect(
      File('docs/api-contracts.md').readAsStringSync(),
      contains('`features.onboardingV2`'),
      reason: 'features.onboardingV2 doit être documenté dans api-contracts.',
    );
  });

  // Communauté (C1 + C2) : une variable pour `features.community` ET les routes
  // élève /community/*. Livrée éteinte : un défaut `true` dans compose ouvrirait
  // une surface d'échanges entre utilisateurs (mineurs compris) au premier
  // redéploiement, avant les déclarations stores.
  test('le drapeau « communauté » est lu, relayé, documenté et fermé', () {
    const variable = 'KPB_COMMUNITY_ENABLED';
    expect(read, contains(variable),
        reason: '$controllerPath ne lit plus $variable.');
    expect(relayed, contains(variable),
        reason: '$variable n\'est pas relayée dans docker-compose.yml.');
    expect(documented, contains(variable),
        reason: '$variable n\'est pas documentée dans .env.example.');
    expect(
      File('docker-compose.yml').readAsStringSync(),
      contains('- $variable=\${$variable:-false}'),
      reason:
          '$variable doit avoir `false` pour défaut dans docker-compose.yml.',
    );
    expect(
      File('docs/api-contracts.md').readAsStringSync(),
      contains('`features.community`'),
      reason: 'features.community doit être documenté dans api-contracts.',
    );
  });

  // Parrainage côté app (build 57) : trois clés `features.*` indépendantes.
  // Livrées éteintes : un défaut `true` dans compose lirait le referrer, ou
  // ouvrirait l'étape d'onboarding et l'écran de la compétition, sur tout le
  // parc 2.3.1 au premier redéploiement — avant la Data safety mise à jour.
  test(
      'les trois drapeaux du parrainage sont lus, relayés, documentés et '
      'fermés', () {
    final compose = File('docker-compose.yml').readAsStringSync();
    final contracts = File('docs/api-contracts.md').readAsStringSync();
    for (final (variable, key) in [
      ('KPB_REFERRAL_INSTALL_REFERRER_ENABLED', 'referralInstallReferrer'),
      ('KPB_REFERRAL_ONBOARDING_CODE_ENABLED', 'referralOnboardingCode'),
      ('KPB_REFERRAL_LEADERBOARD_ENABLED', 'referralLeaderboard'),
    ]) {
      expect(read, contains(variable),
          reason: '$controllerPath ne lit plus $variable.');
      expect(relayed, contains(variable),
          reason: '$variable n\'est pas relayée dans docker-compose.yml.');
      expect(documented, contains(variable),
          reason: '$variable n\'est pas documentée dans .env.example.');
      expect(compose, contains('- $variable=\${$variable:-false}'),
          reason: '$variable doit avoir `false` pour défaut dans compose.');
      expect(contracts, contains('`features.$key`'),
          reason: 'features.$key doit être documenté dans api-contracts.');
    }
  });

  // Bot « Vérif » (C3) : ni `/config/app` ni l'app ne le lisent — c'est un
  // réglage SERVEUR, lu par `community-verif-bot.config.ts`. Il passe quand
  // même par compose (sinon `auto` posé dans le `.env` du VPS n'entrerait
  // jamais dans le conteneur) avec le défaut décidé : `review` (validation
  // humaine d'abord), et la reformulation LLM fermée.
  test('le mode du bot Vérif est lu, relayé (défaut review) et documenté', () {
    const configPath =
        'backend/src/modules/community/community-verif-bot.config.ts';
    final readByBot = _read(_envRead, configPath);
    final compose = File('docker-compose.yml').readAsStringSync();
    for (final (variable, fallback) in [
      ('KPB_COMMUNITY_VERIF_BOT_MODE', 'review'),
      ('KPB_COMMUNITY_VERIF_BOT_LLM', 'false'),
    ]) {
      expect(readByBot, contains(variable),
          reason: '$configPath ne lit plus $variable.');
      expect(compose, contains('- $variable=\${$variable:-$fallback}'),
          reason: '$variable doit être relayée avec le défaut `$fallback`.');
      expect(documented, contains(variable),
          reason: '$variable n\'est pas documentée dans .env.example.');
      expect(File('docs/api-contracts.md').readAsStringSync(),
          contains('`$variable`'),
          reason: '$variable doit être documentée dans api-contracts.');
    }
  });

  // Bot « Passerelle » (C3 bis) : réglage SERVEUR, lu par
  // `assist-bridge.config.ts` (et, pour la seule clé `features.assistBridge`,
  // par `/config/app` via cette fonction). Il passe par compose avec les
  // défauts décidés : `shadow` (détecte sans rien envoyer) et la source coach
  // FERMÉE — une valeur `on` ou `true` écrite dans compose ouvrirait l'envoi
  // ou la lecture des messages privés au premier redéploiement.
  test('le bot Passerelle est lu, relayé (défauts shadow / false) et documenté',
      () {
    const configPath =
        'backend/src/modules/assist-bridge/assist-bridge.config.ts';
    final readByBot = _read(_envRead, configPath);
    final compose = File('docker-compose.yml').readAsStringSync();
    for (final (variable, fallback) in [
      ('KPB_ASSIST_BRIDGE_MODE', 'shadow'),
      ('KPB_ASSIST_BRIDGE_COACH', 'false'),
    ]) {
      expect(readByBot, contains(variable),
          reason: '$configPath ne lit plus $variable.');
      expect(compose, contains('- $variable=\${$variable:-$fallback}'),
          reason: '$variable doit être relayée avec le défaut `$fallback`.');
      expect(documented, contains(variable),
          reason: '$variable n\'est pas documentée dans .env.example.');
      expect(File('docs/api-contracts.md').readAsStringSync(),
          contains('`$variable`'),
          reason: '$variable doit être documentée dans api-contracts.');
    }
    expect(File(controllerPath).readAsStringSync(),
        contains("assistBridge: assistBridgeMode() === 'on'"),
        reason: '`features.assistBridge` ne doit s\'ouvrir qu\'en mode on.');
  });

  // Visas étudiants américains (décision du 17/10/2026) : la liste est
  // PILOTABLE sans build. Défauts VIDES dans compose — le serveur sert alors la
  // liste vérifiée et datée ; une liste écrite dans compose serait figée dans le
  // dépôt, donc périmée à la première évolution de la proclamation.
  test('la suspension des visas américains est lue, relayée et documentée', () {
    final compose = File('docker-compose.yml').readAsStringSync();
    for (final variable in [
      'KPB_US_VISA_SUSPENDED_COUNTRIES',
      'KPB_US_VISA_SUSPENSION_VERIFIED_AT',
      'KPB_US_VISA_SUSPENSION_SOURCE_URL',
    ]) {
      expect(read, contains(variable),
          reason: '$controllerPath ne lit plus $variable.');
      expect(compose, contains('- $variable=\${$variable:-}'),
          reason: '$variable doit être relayée avec un défaut VIDE.');
      expect(documented, contains(variable),
          reason: '$variable n\'est pas documentée dans .env.example.');
    }
    expect(
      File('docs/api-contracts.md').readAsStringSync(),
      contains('`usVisaSuspension`'),
      reason: 'usVisaSuspension doit être documenté dans api-contracts.',
    );
  });

  test('les drapeaux KPB_EEF_* sont fermés par défaut dans compose', () {
    // Le sens de l'échec, figé. Une vitrine allumée par défaut serait
    // impossible à éteindre sans redéploiement du fichier compose, alors que
    // tout l'intérêt de cette architecture est l'inverse.
    final compose = File('docker-compose.yml').readAsStringSync();
    for (final flag in [
      'KPB_EEF_TEASER_ENABLED',
      'KPB_EEF_SPACE_ENABLED',
      'KPB_EEF_ENABLED',
      // Build 56 : la bulle de contact et la mention des écoles privées. Deux
      // interrupteurs distincts, fermés par défaut comme les autres.
      'KPB_EEF_HELP_BUBBLE_ENABLED',
      'KPB_EEF_PRIVATE_SCHOOLS_ENABLED',
    ]) {
      expect(
        compose,
        contains('- $flag=\${$flag:-false}'),
        reason: '$flag doit avoir `false` pour défaut dans docker-compose.yml.',
      );
    }
    // Et les dates : défaut VIDE, jamais une date de repli. Une échéance
    // inventée est indistinguable d'une information pour qui la lit.
    //
    // Même règle pour les liens officiels et la version recommandée : vides par
    // défaut, le serveur retombe alors sur des liens vérifiés / n'invite à rien.
    // Un lien ou une version écrits dans le fichier compose seraient figés dans
    // le dépôt, donc périmés dès la première évolution de la plateforme.
    for (final date in [
      'KPB_EEF_CAMPAIGN_OPENS_AT',
      'KPB_EEF_CAMPAIGN_CLOSES_AT',
      'KPB_EEF_PLATFORM_URL',
      'KPB_EEF_SUSPENDED_SOURCES',
      'KPB_RECOMMENDED_APP_VERSION',
    ]) {
      expect(
        compose,
        contains('- $date=\${$date:-}'),
        reason: '$date doit avoir un défaut VIDE, pas une valeur de repli.',
      );
    }
  });

  // Même invariant, étendu à TOUT le backend : les drapeaux des tâches
  // planifiées (KPB_SCHOLARSHIP_REFRESH_ENABLED, KPB_WEEKLY_DIGEST_ENABLED…)
  // étaient lus par leurs services, documentés dans .env.example, et absents
  // du fichier compose — les activer sur le VPS ne changeait rien.
  test('chaque variable lue par le backend entre dans le conteneur', () {
    final anyEnvRead = RegExp(r'process\.env\.([A-Z][A-Z0-9_]+)');
    final relayedAny = RegExp(r'^\s*-\s+([A-Z][A-Z0-9_]+)=', multiLine: true)
        .allMatches(File('docker-compose.yml').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    // Lues par le backend mais volontairement NON relayées : les contrôleurs
    // de paiement (webhooks) ne sont pas enregistrés dans AppModule. Relayer
    // les clés activerait un paiement en ligne sans confirmation serveur.
    final intentionallyNotRelayed = RegExp(
      r'^(KPB_CINETPAY_|KPB_PAYDUNYA_)|^(NODE_ENV|PORT|DATABASE_URL|'
      r'KPB_RUN_POSTGRES_INTEGRATION|JEST_WORKER_ID|CI)$',
    );
    final readAny = <String>{};
    for (final file in Directory('backend/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.ts') && !f.path.endsWith('.spec.ts'))) {
      readAny.addAll(
        anyEnvRead.allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
      );
    }
    expect(readAny.length, greaterThan(50), reason: 'Garde morte.');
    final missing = readAny
        .difference(relayedAny)
        .where((v) => !intentionallyNotRelayed.hasMatch(v))
        .toList()
      ..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Lues par backend/src mais absentes de docker-compose.yml :\n'
          '${missing.map((v) => '  - $v').join('\n')}',
    );
  });
  // Audit 57, F03 : le test précédent ne voit que `process.env.X`. Les
  // lectures INDIRECTES — `readEnvInt('KPB_…')`, `readEnvHour('KPB_…')`,
  // `readHour(env, 'KPB_…')`, `requiredSecret(env, 'KPB_…')`,
  // `{ name: 'KPB_…' }`, `limitEnv: 'KPB_…'` — lui échappaient :
  // `KPB_PUSH_MAX_PER_DAY` était lue par le dispatcher, ni relayée ni
  // documentée, et la poser sur le VPS n'avait aucun effet. Ici : toute chaîne
  // littérale qui N'EST QU'un nom `KPB_…` dans le code du backend (hors
  // commentaires et tests) doit être relayée.
  test(
      'chaque variable KPB_* nommée par le backend (lecture indirecte) entre '
      'dans le conteneur', () {
    final literal = RegExp(r'''['"](KPB_[A-Z0-9_]+)['"]''');
    final blockComment = RegExp(r'/\*[\s\S]*?\*/');
    final lineComment = RegExp(r'^\s*//.*$', multiLine: true);
    final relayedAny = RegExp(r'^\s*-\s+([A-Z][A-Z0-9_]+)=', multiLine: true)
        .allMatches(File('docker-compose.yml').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    // Nommées par le backend mais volontairement NON relayées :
    // `KPB_ALLOW_PRODUCTION_SEED` lève, pour UN lancement posé à la main, le
    // refus des seeds sur la production (`common/seed-safety.ts`) ; le relayer
    // l'installerait à demeure dans le conteneur.
    const intentionallyNotRelayed = {'KPB_ALLOW_PRODUCTION_SEED'};
    final named = <String>{};
    for (final file in Directory('backend/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.ts') && !f.path.endsWith('.spec.ts'))) {
      final code = file
          .readAsStringSync()
          .replaceAll(blockComment, '')
          .replaceAll(lineComment, '');
      named.addAll(literal.allMatches(code).map((m) => m.group(1)!));
    }
    // Non-vacuité : les formes indirectes connues sont bien vues.
    for (final variable in [
      'KPB_PUSH_MAX_PER_DAY', // readEnvInt
      'KPB_PUSH_QUIET_START', // readEnvHour / readHour
      'KPB_PUSH_OUTBOX_BATCH', // { name: … }
    ]) {
      expect(named, contains(variable),
          reason: 'Garde morte : $variable n\'est plus vue dans backend/src.');
    }
    final missing = named
        .difference(relayedAny)
        .difference(intentionallyNotRelayed)
        .toList()
      ..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Nommées par backend/src (lecture indirecte) mais absentes du '
          'bloc environment: de docker-compose.yml :\n'
          '${missing.map((v) => '  - $v').join('\n')}',
    );
    // Et documentée, comme ses voisines.
    expect(_read(_envExampleDecl, '.env.example'),
        contains('KPB_PUSH_MAX_PER_DAY'),
        reason:
            'KPB_PUSH_MAX_PER_DAY n\'est pas documentée dans .env.example.');
  });
}
