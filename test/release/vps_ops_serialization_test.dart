import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Groupe de concurrence de PREMIER NIVEAU d'un workflow.
///
/// On ancre sur une colonne 0 (`^concurrency:`) pour ne pas attraper un bloc
/// `concurrency:` posé à l'intérieur d'un job, indenté.
String _topLevelConcurrencyGroup(String yaml, String label) {
  final block = RegExp(
    r'^concurrency:\s*\n((?:[ \t]+\S.*\n)+)',
    multiLine: true,
  ).firstMatch(yaml);
  expect(block, isNotNull,
      reason: 'Aucun bloc concurrency de premier niveau dans $label');
  final group = RegExp(r'^\s+group:\s*(\S+)\s*$', multiLine: true)
      .firstMatch(block!.group(1)!);
  expect(group, isNotNull, reason: 'concurrency sans `group:` dans $label');
  return group!.group(1)!;
}

void main() {
  group('Les opérations VPS ne peuvent pas s\'entrelacer', () {
    final deploy = _read('.github/workflows/deploy.yml');
    final ops = _read('.github/workflows/vps-ops.yml');
    final script = _read('.github/scripts/vps-ops.sh');

    // Le tag `kpb-backend:<tag>` est MUTABLE : `deploy.yml` le réécrit pendant
    // `docker compose build`. Une opération de drapeau qui relit ce tag sur le
    // conteneur en cours peut donc, selon l'ordre, démarrer l'image fraîchement
    // reconstruite AVANT ses migrations et sa barrière de santé — ou remettre
    // l'ancienne image APRÈS la release.
    //
    // Le test compare les deux groupes entre eux au lieu d'épingler la chaîne
    // « deploy-vps » : renommer le groupe de `deploy.yml` sans toucher à
    // `vps-ops.yml` désérialiserait les deux workflows en silence, et c'est
    // exactement ce défaut qu'on veut voir échouer ici.
    test('vps-ops partage le groupe de concurrence de deploy', () {
      final deployGroup = _topLevelConcurrencyGroup(deploy, 'deploy.yml');
      final opsGroup = _topLevelConcurrencyGroup(ops, 'vps-ops.yml');
      expect(
        opsGroup,
        deployGroup,
        reason:
            'vps-ops.yml et deploy.yml doivent partager un groupe de concurrence, '
            'sinon une opération de drapeau peut s\'entrelacer avec une release.',
      );
    });

    // Faire attendre, jamais annuler : un déploiement interrompu en plein
    // `docker compose build` laisse le VPS dans un état intermédiaire, ce qu'un
    // drapeau arrivé une minute plus tard ne justifie jamais.
    test('la file attend au lieu d\'annuler', () {
      for (final entry in {'deploy.yml': deploy, 'vps-ops.yml': ops}.entries) {
        expect(
          RegExp(r'^concurrency:\s*\n(?:[ \t]+\S.*\n)*?[ \t]+cancel-in-progress:\s*false',
                  multiLine: true)
              .hasMatch(entry.value),
          isTrue,
          reason: '${entry.key} : cancel-in-progress doit valoir false',
        );
      }
    });

    // Ceinture, la sérialisation étant la bretelle. Un tag ne peut pas être rendu
    // immuable depuis `image: kpb-backend:${KPB_IMAGE_TAG}` ; l'ID d'image, lui,
    // l'est. Relevé avant et après, il détecte le cas où le tag aurait bougé.
    test('la recréation vérifie que l\'image n\'a pas bougé', () {
      final normalized = script.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        normalized,
        contains(r"id_before=$(docker inspect -f '{{.Image}}' kpb_api)"),
        reason: 'ID d\'image non relevé avant la recréation',
      );
      expect(
        normalized,
        contains(r"id_after=$(docker inspect -f '{{.Image}}' kpb_api)"),
        reason: 'ID d\'image non relevé après la recréation',
      );
      expect(
        normalized,
        contains(r'if [ "$id_before" != "$id_after" ]; then'),
        reason: 'les deux ID ne sont pas comparés',
      );
      expect(
        normalized,
        contains(r'if [ "$sha" != "$sha_after" ]; then'),
        reason:
            'KPB_BUILD_SHA non revérifié : c\'est l\'empreinte de release perdue '
            'le 30/08/2026',
      );
    });

    // `--no-build` est ce qui transforme un tag non résolu en échec franc plutôt
    // qu'en reconstruction silencieuse depuis la source.
    test('la recréation ne peut jamais reconstruire', () {
      expect(
        script.replaceAll(RegExp(r'\s+'), ' '),
        contains('docker compose up -d --no-deps --no-build api'),
        reason: 'sans --no-build, compose reconstruit depuis la source',
      );
    });
  });

  // ── La liste fermée doit être fermée des DEUX côtés ───────────────────────
  //
  // `vps-ops.yml` propose les actions, `vps-ops.sh` les exécute. Les deux
  // fichiers doivent s'accorder, et rien ne le vérifiait : une option ajoutée
  // au menu sans branche dans le `case` part jusqu'au VPS pour y mourir sur
  // « ACTION inconnue » (code 2) — après avoir pris le verrou de concurrence
  // partagé avec `deploy`. Une branche sans option, elle, est du code mort
  // qu'on croit disponible.
  group('Le menu des actions et le script disent la même chose', () {
    final workflow = _read('.github/workflows/vps-ops.yml');
    final script = _read('.github/scripts/vps-ops.sh');

    Set<String> menuActions() {
      final block =
          RegExp(r'options:\s*\n((?:\s*- \S+\n)+)').firstMatch(workflow);
      expect(block, isNotNull, reason: 'liste `options:` introuvable');
      return RegExp(r'- (\S+)')
          .allMatches(block!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
    }

    Set<String> scriptBranches() {
      final block = RegExp(r'case "\$ACTION" in\n(.*?)\n  \*\)', dotAll: true)
          .firstMatch(script);
      expect(block, isNotNull, reason: 'bloc `case "\$ACTION"` introuvable');
      return RegExp(r'^  ([a-z][a-z0-9-]*)\)', multiLine: true)
          .allMatches(block!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
    }

    test('chaque action proposée a une branche qui l\'exécute', () {
      final orphans = menuActions().difference(scriptBranches());
      expect(orphans, isEmpty,
          reason: 'proposées au menu mais absentes du script : $orphans — '
              'elles échoueraient sur le VPS en « ACTION inconnue »');
    });

    test('les drapeaux restants de la 57 sont des deux côtés', () {
      for (final action in [
        'onboarding-v2-on',
        'onboarding-v2-off',
        'scholarship-match-on',
        'scholarship-match-off',
      ]) {
        expect(menuActions(), contains(action));
        expect(scriptBranches(), contains(action));
      }
    });

    test('chaque branche du script est proposée au menu', () {
      final unreachable = scriptBranches().difference(menuActions());
      expect(unreachable, isEmpty,
          reason: 'implémentées mais absentes du menu : $unreachable — '
              'code mort qu\'on croit disponible');
    });
  });

  // ── Réparer clamav doit RECRÉER, jamais seulement redémarrer ──────────────
  //
  // `docker compose restart` relance le processus dans le conteneur existant et
  // ne relit pas `docker-compose.yml`. Une `mem_limit` n'est appliquée qu'à la
  // création.
  //
  // Le 08/09/2026 : limite portée à 3g, fusionnée, déployée — et le conteneur
  // tournait toujours avec 1536 Mo, même identifiant qu'avant. Le correctif
  // était juste dans le fichier et faux dans la réalité, et l'action de
  // réparation, en `restart`, ne pouvait pas le corriger non plus.
  group('La réparation de clamav applique la configuration', () {
    final script = _read('.github/scripts/vps-ops.sh');
    final body = RegExp(r'^recreate_clamav\(\) \{$(.*?)^\}$',
            multiLine: true, dotAll: true)
        .firstMatch(script)
        ?.group(1);

    test('la fonction existe', () {
      expect(body, isNotNull,
          reason: 'recreate_clamav introuvable — action de réparation absente');
    });

    test('elle recrée le conteneur', () {
      expect(body, contains('--force-recreate'),
          reason: 'sans --force-recreate, la nouvelle mem_limit ne '
              's applique pas');
    });

    test('elle ne se contente PAS d\'un restart', () {
      expect(body, isNot(contains('compose restart')),
          reason: 'docker compose restart ne relit pas docker-compose.yml : '
              'c est le defaut du 08/09/2026, ou clamd a ete rallume avec '
              'l ancienne limite de 1536 Mo');
    });

    // Sans cette vérification, on répète exactement l'erreur : croire la
    // configuration sur parole au lieu de regarder ce qui tourne.
    test('elle VÉRIFIE la limite réellement appliquée', () {
      expect(body, contains('HostConfig.Memory'),
          reason: 'la limite posée doit etre lue sur le conteneur, pas '
              'supposee depuis le fichier');
    });
  });
}
