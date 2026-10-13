import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Bloc `run:` de l'étape nommée, dans un job donné.
///
/// On découpe le YAML à la main plutôt que d'ajouter une dépendance : le fichier
/// est indenté de façon stable et le test doit rester lisible par la personne
/// qui relit la CI.
String _stepBlock(String yaml, String stepName) {
  final start = yaml.indexOf('      - name: $stepName\n');
  expect(start, isNot(-1),
      reason: 'Étape absente de flutter-ci.yml : $stepName');
  final rest = yaml.substring(start + 1);
  final next = rest.indexOf('\n      - ');
  return next == -1 ? rest : rest.substring(0, next);
}

void main() {
  group('Aucune release muette ni illisible', () {
    final ci = _read('.github/workflows/flutter-ci.yml');
    final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
    final iosPreflight = _read('scripts/preflight-ios-archive.sh');
    final androidPreflight = _read('scripts/preflight-android-aab.sh');

    // ── Symboles ──────────────────────────────────────────────────────────
    //
    // Sans phase d'envoi des dSYM, les plantages remontent en adresses mémoire
    // brutes. La build 50 est partie chez les testeurs dans cet état : ses
    // rapports sont inexploitables, et aucun signal ne le disait.
    group('dSYM envoyés à Crashlytics', () {
      test('la phase existe et est branchée sur la cible Runner', () {
        final phase = RegExp(
          r'([0-9A-F]{24}) /\* Upload dSYMs to Crashlytics \*/ = \{',
        ).firstMatch(pbxproj);
        expect(phase, isNotNull,
            reason: 'Phase de build absente du projet Xcode');

        // Déclarée ET référencée : une phase orpheline ne s'exécute jamais.
        final id = phase!.group(1)!;
        expect(
          pbxproj,
          contains('$id /* Upload dSYMs to Crashlytics */,'),
          reason:
              'Phase déclarée mais absente de buildPhases : elle ne tournerait '
              'jamais.',
        );
      });

      test('elle téléverse vraiment, et échoue au lieu d\'avertir', () {
        expect(pbxproj, contains(r'FirebaseCrashlytics/upload-symbols'));
        expect(
          pbxproj,
          contains(r'GoogleService-Info.plist'),
          reason: 'upload-symbols a besoin du plist Firebase',
        );
        // Un avertissement dans un journal de build est ce qui laisse passer une
        // archive incomplète. Sur un archivage, l'absence de dSYM doit être
        // fatale.
        expect(
          pbxproj,
          contains(r'aucun dSYM produit'),
          reason: 'l\'absence de dSYM doit être une erreur, pas un warning',
        );
      });

      test('la Release produit bien un dSYM à envoyer', () {
        // La phase serait un mensonge si la configuration ne générait pas de
        // dSYM : elle échouerait à chaque archivage.
        //
        // On isole les blocs `name = Release;` au lieu de chercher la chaîne
        // n'importe où : la configuration Profile porte elle aussi
        // `dwarf-with-dsym`, donc une recherche globale passerait même avec une
        // Release retombée en `dwarf` — le test aurait couvert le défaut au
        // lieu de le montrer.
        final releaseBlocks = RegExp(
          r'isa = XCBuildConfiguration;(.*?)\n\t\t\tname = (\w+);',
          dotAll: true,
        )
            .allMatches(pbxproj)
            .where((m) => m.group(2) == 'Release')
            .map((m) => m.group(1)!)
            .where((block) => block.contains('DEBUG_INFORMATION_FORMAT'))
            .toList();
        expect(
          releaseBlocks,
          isNotEmpty,
          reason:
              'aucune configuration Release ne fixe DEBUG_INFORMATION_FORMAT',
        );
        for (final block in releaseBlocks) {
          expect(
            block,
            contains('DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"'),
            reason: 'sans dwarf-with-dsym, aucun dSYM n\'est produit',
          );
        }
      });
    });

    // ── Télémétrie ────────────────────────────────────────────────────────
    //
    // La build 50 iOS est partie sans clé PostHog : sa télémétrie produit est
    // perdue définitivement. Le préflight iOS a été durci ; le job Android
    // substituait encore le secret sans jamais le regarder.
    group('clé PostHog exigée sur les deux plateformes', () {
      test('le job AAB refuse une clé absente, mal formée ou trop courte', () {
        final step = _stepBlock(ci, 'Verify PostHog project key');
        expect(step, contains(r'if [ -z "${POSTHOG_API_KEY:-}" ]'));
        expect(step, contains('phc_*)'));
        expect(step, contains(r'if [ "${#POSTHOG_API_KEY}" -lt 40 ]'));
      });

      // Le 04/10/2026, une build iOS est partie avec une clé PostHog DOUBLÉE
      // (deux fois la même clé, 96 caractères) : préfixe `phc_` et plus de 40
      // caractères, donc acceptée par l'ancien contrôle. Le préflight iOS refuse
      // maintenant tout ce qui n'est pas `^phc_[A-Za-z0-9]{30,60}$` ; le job
      // Android doit refuser exactement la même chose. On JOUE donc l'étape.
      test('iOS et Android partagent la même expression de clé', () {
        const rule = r'^phc_[A-Za-z0-9]{30,60}$';
        expect(iosPreflight, contains(rule));
        expect(_stepBlock(ci, 'Verify PostHog project key'), contains(rule));
      });

      group('le job AAB joué sur des clés fabriquées', () {
        // Extrait le script `run: |` de l'étape et le déduit de son indentation.
        String script() {
          final step = _stepBlock(ci, 'Verify PostHog project key');
          final lines = step.split('\n');
          final at = lines.indexWhere((l) => l.trim() == 'run: |');
          expect(at, isNot(-1));
          final body = lines.sublist(at + 1);
          final indent = body.firstWhere((l) => l.trim().isNotEmpty).length -
              body.firstWhere((l) => l.trim().isNotEmpty).trimLeft().length;
          return body
              .map((l) =>
                  l.length >= indent ? l.substring(indent) : l.trimLeft())
              .join('\n');
        }

        ProcessResult run(String key) => Process.runSync(
              'bash',
              ['-c', script()],
              environment: {'POSTHOG_API_KEY': key},
            );

        const single = 'phc_rk9a5wRGbWJeoHxiuB2ppA7ZHzqSyk7uvMkSkkzP4Ckz';

        test('une clé plausible passe', () {
          expect(run(single).exitCode, 0, reason: '${run(single).stderr}');
        });

        test('une clé DOUBLÉE est refusée', () {
          final doubled = '$single$single';
          expect(doubled.length, 96);
          final result = run(doubled);
          expect(result.exitCode, isNot(0),
              reason: 'la clé doublée de la build iOS du 04/10 doit rougir');
          expect('${result.stdout}${result.stderr}', isNot(contains(single)),
              reason: 'la clé ne doit jamais être imprimée');
        });

        test('vide, sans préfixe, trop courte et caractères interdits', () {
          for (final key in [
            '',
            'pk_$single',
            'phc_court',
            '${single}_x y',
            '$single\n$single',
          ]) {
            expect(run(key).exitCode, isNot(0), reason: 'clé refusée : "$key"');
          }
        });
      });

      test('le contrôle passe AVANT la construction de l\'AAB', () {
        final check = ci.indexOf('- name: Verify PostHog project key');
        final build = ci.indexOf('- name: Build signed production AAB');
        expect(check, isNot(-1));
        expect(build, isNot(-1));
        expect(
          check < build,
          isTrue,
          reason:
              'contrôler après la construction ferait perdre le build entier, '
              'et surtout laisserait l\'artefact exister',
        );
      });

      test('iOS et Android refusent les mêmes choses', () {
        for (final rule in ['phc_', '40']) {
          expect(iosPreflight, contains(rule));
        }
        final step = _stepBlock(ci, 'Verify PostHog project key');
        for (final rule in ['phc_', '40']) {
          expect(
            step,
            contains(rule),
            reason: 'règle « $rule » présente côté iOS mais pas côté Android',
          );
        }
      });
    });

    // ── Push ──────────────────────────────────────────────────────────────
    //
    // Le push se désactive comme PostHog et comme l'IA : par une variable
    // absente, sans un mot. `PushSenderService` se dégrade en no-op
    // journalisé — le fil d'actualité s'écrit, la notification ne part pas, et
    // le dispatcher rend `push_unconfigured`. Personne ne le voyait.
    group('une panne de push ne peut plus être silencieuse', () {
      final health = _read('backend/src/modules/health/health.controller.ts');
      final opsScript = _read('.github/scripts/vps-ops.sh');
      final opsWorkflow = _read('.github/workflows/vps-ops.yml');

      test('/health annonce l\'état du push, comme celui de l\'IA', () {
        expect(
          health,
          contains('configured: this.pushSender.isConfigured'),
          reason:
              '/health exposait ai.configured et RIEN sur le push, alors que '
              'les deux s\'éteignent de la même façon.',
        );
      });

      test('la route n\'expose qu\'un booléen, jamais la clé REST', () {
        // La clé REST OneSignal est un secret, contrairement à l'App ID. Ni sa
        // valeur ni sa longueur n'ont leur place sur une route publique.
        //
        // On teste le CODE, pas la prose : les commentaires de ce contrôleur
        // nomment la variable pour expliquer la règle, et une recherche brute
        // les aurait comptés comme une fuite. Une première version de ce test
        // rougissait exactement ainsi — sur son propre commentaire.
        final code = health
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
            .replaceAll(RegExp(r'//.*'), '');
        for (final variable in ['ONESIGNAL', 'FCM_SERVICE_ACCOUNT']) {
          expect(
            code.contains(variable),
            isFalse,
            reason: 'le contrôleur ne doit jamais lire $variable lui-même',
          );
        }
        expect(code.contains('restApiKey'), isFalse);
        // Ne sortent que les booléens dérivés du service.
        expect(code, contains('this.pushSender.isConfigured'));
        expect(code, contains('...this.pushSender.providers'));
      });

      test('l\'outillage d\'ops rend compte des trois variables', () {
        expect(
            opsScript, contains('report_key FCM_SERVICE_ACCOUNT_JSON masked'));
        expect(opsScript, contains('report_key ONESIGNAL_APP_ID public'));
        expect(opsScript, contains('report_key ONESIGNAL_REST_API_KEY masked'));
        // `masked` est le mode qui n'imprime que « posée ». Un basculement en
        // `public` ferait sortir un secret dans un journal de CI public — la
        // clé privée du compte de service Firebase en tête.
        for (final secret in [
          'FCM_SERVICE_ACCOUNT_JSON',
          'ONESIGNAL_REST_API_KEY',
        ]) {
          expect(
            opsScript.contains('report_key $secret public'),
            isFalse,
            reason: '$secret ne doit JAMAIS être imprimée',
          );
        }
      });

      // Le défaut le plus vicieux n'est pas l'absence de configuration : c'est
      // un serveur bien configuré qui pointe sur une AUTRE application
      // OneSignal. Tout « réussit », et aucun téléphone ne reçoit rien.
      // Deux façons de lire la MAUVAISE valeur, toutes deux corrigées :
      // `.env` peut porter la clé deux fois (compose garde la dernière), et une
      // clé posée dans `.env` peut n'être jamais relayée au conteneur. On lit
      // donc l'environnement du processus, qui est la seule vérité.
      test('l\'état est lu dans le CONTENEUR, pas deviné depuis .env', () {
        // Assertion portée sur le CORPS de `effective_env`, pas sur le fichier.
        // Une première version cherchait `docker inspect` n'importe où dans le
        // script — or il y figure aussi dans `recreate_api_same_image`. La
        // mutation qui ramenait `effective_env` à un `grep .env | head -1`
        // passait donc au vert : le test cherchait la bonne chaîne au mauvais
        // endroit.
        final start = opsScript.indexOf('effective_env() {');
        expect(start, isNot(-1), reason: 'fonction effective_env absente');
        final body = opsScript.substring(
          start,
          opsScript.indexOf('\n}\n', start),
        );

        expect(
          body,
          contains('docker inspect'),
          reason: 'la valeur effective est celle que le processus voit',
        );
        expect(body, contains('.Config.Env'));
        // Une clé posée deux fois dans `.env` garde la DERNIÈRE — `set_env_key`
        // le documente à quelques lignes de là. Lire la première ferait dire au
        // rapport le contraire de la configuration réelle.
        expect(body, contains('tail -1'));
        expect(
          body.contains('head -1'),
          isFalse,
          reason: 'lire le premier assignement contredirait set_env_key',
        );
      });

      // Un écart mérite un regard, pas une action. Le rendre bloquant aurait
      // invité à basculer le serveur vers la source — et à couper le push pour
      // tous les clients DÉJÀ installés, dont la build peut porter un autre
      // App ID (défaut modifié depuis, ou --dart-define).
      test('une divergence d\'App ID avertit, elle ne bloque pas', () {
        final block = opsScript.substring(opsScript.indexOf('show_push_state'));
        expect(block, contains("::warning::l'App ID du serveur"));
        expect(
          block.contains("::error::l'App ID du serveur"),
          isFalse,
          reason: 'agir sur cette comparaison sans lire l\'artefact distribué '
              'casserait le push pour les utilisateurs en place',
        );
      });

      // L'app courante n'embarque plus OneSignal : l'App ID à comparer est
      // celui des builds ANTÉRIEURES, figé comme ces artefacts. Il ne peut
      // donc plus être extrait de la source — et ne doit pas y revenir.
      test('l\'App ID est comparé à celui des anciennes builds', () {
        expect(opsScript, contains(r'EXPECTED_ONESIGNAL_APP_ID'));
        expect(
          RegExp(r"EXPECTED_ONESIGNAL_APP_ID: '[0-9a-f-]{36}'")
              .hasMatch(opsWorkflow),
          isTrue,
          reason: 'le workflow doit porter l\'App ID figé des anciennes builds',
        );
        expect(
          _read('lib/app/core/config/app_config.dart'),
          isNot(contains('ONESIGNAL')),
          reason: 'OneSignal est retiré de l\'app',
        );
      });
    });

    // Le contrat de soumission est ce qu'un opérateur ouvre le jour J. Il
    // s'intitulait « — build 49 » et énumérait la 49 partout, alors que les 50
    // et 52 étaient parties : il décrivait l'identité d'un artefact périmé.
    //
    // Pire, un correctif partiel — mettre à jour la version marketing sans le
    // numéro de build — y a fabriqué un artefact IMPOSSIBLE, 2.2.0+49, qui n'a
    // jamais existé et n'existera jamais. Le numéro n'y figure donc plus : il
    // vit dans le registre, sa seule source.
    test('le contrat de soumission ne recopie aucun numéro de build', () {
      final contract = _read('docs/mobile-store-submission-contract.md');
      final identity = contract.substring(
        contract.indexOf('Immutable artifact identity'),
        contract.indexOf('```bash'),
      );
      expect(
        RegExp(r'\|\s*`\d+`\s*\|').hasMatch(identity),
        isFalse,
        reason:
            'un numéro de build recopié dans le tableau d\'identité dérive à '
            'chaque release et finit par décrire un artefact impossible',
      );
      expect(identity, contains('release-ledger.md'));
      // La version MARKETING, elle, est légitimement épinglée — un test la
      // verrouille sur pubspec.yaml — mais elle doit y correspondre.
      final shipping = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+', multiLine: true)
          .firstMatch(_read('pubspec.yaml'))!
          .group(1)!;
      expect(
        identity,
        contains('`$shipping`'),
        reason:
            'le contrat annonce une version marketing différente de pubspec',
      );
    });

    // Le même défaut existait des DEUX côtés : le préflight iOS annonçait
    // « 2.1.0 (49) » en dur alors qu'il exigeait déjà la 53. Un opérateur
    // lisant ce message aurait cru valider un artefact qui n'était pas celui-là.
    test('le préflight iOS n\'annonce pas une version qu\'il ne vérifie pas',
        () {
      final tail = iosPreflight.substring(iosPreflight.length - 700);
      expect(
        RegExp(r'Préflight iOS OK — \d+\.\d+\.\d+ \(\d+\)').hasMatch(tail),
        isFalse,
        reason: 'version et build en dur dans le message de succès',
      );
      expect(tail, contains(r'${EXPECTED_VERSION} (${EXPECTED_BUILD})'));
    });

    // Un rapport de succès qui ment sur ce qu'il a contrôlé est pire qu'un
    // rapport absent : il annonçait « (49) » alors que le script exigeait 51.
    test(
        'le préflight Android n\'annonce pas une version qu\'il ne vérifie pas',
        () {
      final tail = androidPreflight.substring(androidPreflight.length - 400);
      expect(
        RegExp(r'Préflight Android OK.*\(\d+\)').hasMatch(tail),
        isFalse,
        reason: 'numéro de build en dur dans le message de succès',
      );
      expect(tail, contains(r'${EXPECTED_VERSION_CODE}'));
    });
  });
}
