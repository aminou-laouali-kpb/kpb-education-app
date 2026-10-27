// Les drapeaux distants de la 57 dans « VPS ops » : parrainage, communauté, bot
// « Passerelle », bot « Vérif », test « Mes 10 bourses », onboarding V2.
//
// Le plan d'ouverture (docs/runbook-campagne-ambassadeurs.md §8,
// docs/release-57-store-pack.md §5, docs/mise-a-jour-57-checklist.md §9) disait
// « poser la variable dans le `.env` de production, recréer api » — en SSH, alors
// que le port 22 du VPS n'est pas joignable depuis un poste de travail. Ces
// actions fermées l'exécutent.
//
// Comme `vps_ops_eef_switches_test.dart`, ce fichier JOUE le script (avec un faux
// `docker`) et les étapes de preuve du workflow (avec un faux `curl`) : une
// preuve qu'on n'a jamais vue échouer ne prouve rien.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scriptPath = '.github/scripts/vps-ops.sh';
const _workflowPath = '.github/workflows/vps-ops.yml';
const _controller = 'dist/modules/config/app-config.controller.js';
const _verifBotConfig = 'dist/modules/community/community-verif-bot.config.js';

/// Une action : la clé du `.env`, la valeur écrite, la clé `features.*` prouvée
/// (null : `/config/app` ne la sert pas), si elle OUVRE (simulée par défaut), et
/// le fichier compilé + motif que le garde « backend déployé » cherche.
class _Flag {
  const _Flag(this.action, this.envKey, this.value, this.jsonKey, this.opens,
      [this.compiled = _controller, this.pattern]);
  final String action;
  final String envKey;
  final String value;
  final String? jsonKey;
  final bool opens;
  final String compiled;
  final String? pattern;

  /// Ce que `features.<jsonKey>` doit valoir après l'action.
  bool get served => value == 'true' || value == 'on';
}

const _flags = <_Flag>[
  _Flag(
      'referral-leaderboard-on',
      'KPB_REFERRAL_LEADERBOARD_ENABLED',
      'true',
      'referralLeaderboard',
      true,
      _controller,
      'KPB_REFERRAL_LEADERBOARD_ENABLED'),
  _Flag('referral-leaderboard-off', 'KPB_REFERRAL_LEADERBOARD_ENABLED', 'false',
      'referralLeaderboard', false),
  _Flag(
      'referral-onboarding-code-on',
      'KPB_REFERRAL_ONBOARDING_CODE_ENABLED',
      'true',
      'referralOnboardingCode',
      true,
      _controller,
      'KPB_REFERRAL_ONBOARDING_CODE_ENABLED'),
  _Flag('referral-onboarding-code-off', 'KPB_REFERRAL_ONBOARDING_CODE_ENABLED',
      'false', 'referralOnboardingCode', false),
  _Flag(
      'referral-install-referrer-on',
      'KPB_REFERRAL_INSTALL_REFERRER_ENABLED',
      'true',
      'referralInstallReferrer',
      true,
      _controller,
      'KPB_REFERRAL_INSTALL_REFERRER_ENABLED'),
  _Flag(
      'referral-install-referrer-off',
      'KPB_REFERRAL_INSTALL_REFERRER_ENABLED',
      'false',
      'referralInstallReferrer',
      false),
  _Flag('community-on', 'KPB_COMMUNITY_ENABLED', 'true', 'community', true,
      _controller, 'KPB_COMMUNITY_ENABLED'),
  _Flag('community-off', 'KPB_COMMUNITY_ENABLED', 'false', 'community', false),
  _Flag('assist-bridge-on', 'KPB_ASSIST_BRIDGE_MODE', 'on', 'assistBridge',
      true, _controller, 'assistBridge'),
  _Flag('assist-bridge-shadow', 'KPB_ASSIST_BRIDGE_MODE', 'shadow',
      'assistBridge', false),
  _Flag('assist-bridge-off', 'KPB_ASSIST_BRIDGE_MODE', 'off', 'assistBridge',
      false),
  _Flag('verif-bot-auto', 'KPB_COMMUNITY_VERIF_BOT_MODE', 'auto', null, true,
      _verifBotConfig, 'KPB_COMMUNITY_VERIF_BOT_MODE'),
  _Flag('verif-bot-review', 'KPB_COMMUNITY_VERIF_BOT_MODE', 'review', null,
      false),
  _Flag('verif-bot-off', 'KPB_COMMUNITY_VERIF_BOT_MODE', 'off', null, false),
  _Flag('onboarding-v2-on', 'KPB_ONBOARDING_V2_ENABLED', 'true', 'onboardingV2',
      true, _controller, 'KPB_ONBOARDING_V2_ENABLED'),
  _Flag('onboarding-v2-off', 'KPB_ONBOARDING_V2_ENABLED', 'false',
      'onboardingV2', false),
  _Flag('scholarship-match-on', 'KPB_SCHOLARSHIP_MATCH_ENABLED', 'true',
      'scholarshipMatch', true, _controller, 'KPB_SCHOLARSHIP_MATCH_ENABLED'),
  _Flag('scholarship-match-off', 'KPB_SCHOLARSHIP_MATCH_ENABLED', 'false',
      'scholarshipMatch', false),
];

/// Un `.env` de production plausible : chaque drapeau de la 57 à son défaut, et
/// des voisins qui ne doivent JAMAIS bouger.
const _baseEnv = 'KPB_EEF_TEASER_ENABLED=true\n'
    'KPB_EEF_SPACE_ENABLED=true\n'
    'KPB_MIN_APP_VERSION=0.0.0\n'
    'KPB_REFERRAL_LEADERBOARD_ENABLED=false\n'
    'KPB_REFERRAL_ONBOARDING_CODE_ENABLED=false\n'
    'KPB_REFERRAL_INSTALL_REFERRER_ENABLED=false\n'
    'KPB_COMMUNITY_ENABLED=false\n'
    'KPB_ASSIST_BRIDGE_MODE=shadow\n'
    'KPB_COMMUNITY_VERIF_BOT_MODE=review\n'
    'KPB_SCHOLARSHIP_MATCH_ENABLED=false\n'
    'KPB_ONBOARDING_V2_ENABLED=false\n'
    'POSTGRES_PASSWORD=s3cret\n';

// ── Un faux `docker` ──────────────────────────────────────────────────────────
//
// Il refuse (99) tout appel imprévu. `inspect … .Config.Env` rend l'empreinte de
// build PLUS le `.env` du VPS : c'est ce que voit un conteneur recréé qui a relu
// le fichier. Avec FAKE_STALE_CONTAINER=1, il ne rend que l'empreinte — un
// conteneur qui n'a PAS relu le `.env` — et la preuve du script doit rougir.
const _fakeDocker = r'''#!/usr/bin/env bash
echo "$*" >> "$FAKE_DOCKER_LOG"
case "$*" in
  "inspect -f {{.Config.Image}} kpb_api") echo "kpb-backend:abc123" ;;
  "inspect -f {{.Image}} kpb_api") echo "sha256:img1" ;;
  "inspect -f {{range .Config.Env}}{{println .}}{{end}} kpb_api")
    echo "KPB_BUILD_SHA=deadbeef"
    [ "${FAKE_STALE_CONTAINER:-0}" = "1" ] || { cat "$VPS_PATH/.env"; echo; } ;;
  "inspect kpb_api") : ;;
  "compose exec -T api grep "*)
    shift 4
    (cd "$FAKE_CONTAINER_ROOT" && "$@") ;;
  "compose up -d --no-deps --no-build api") : ;;
  *) echo "faux docker : appel inconnu : $*" >&2; exit 99 ;;
esac
''';

class _Run {
  _Run(this.exitCode, this.output, this.env, this.dockerCalls, this.backups);
  final int exitCode;
  final String output;
  final String env;
  final List<String> dockerCalls;
  final List<String> backups;

  bool get recreated => dockerCalls
      .any((c) => c.startsWith('compose up -d --no-deps --no-build'));

  String? value(String key) {
    String? found;
    for (final line in const LineSplitter().convert(env)) {
      if (line.startsWith('$key=')) found = line.substring(key.length + 1);
    }
    return found;
  }
}

/// Exécute `vps-ops.sh` pour de bon. [backendReads] : les motifs que le faux
/// conteneur porte (null = tous ceux des actions, c'est-à-dire un backend 57).
_Run _runOps(
  String action, {
  String? dryRun,
  String initialEnv = _baseEnv,
  String? composeText,
  Set<String>? backendReads,
  bool staleContainer = false,
}) {
  final root = Directory.systemTemp.createTempSync('vps_ops_57_');
  addTearDown(() => root.deleteSync(recursive: true));

  final vps = Directory('${root.path}/vps')..createSync();
  final bin = Directory('${root.path}/bin')..createSync();
  File('${vps.path}/.env').writeAsStringSync(initialEnv);
  File('${vps.path}/docker-compose.yml').writeAsStringSync(
      composeText ?? File('docker-compose.yml').readAsStringSync());

  final reads = backendReads ??
      {
        for (final f in _flags)
          if (f.pattern != null) f.pattern!
      };
  final container = Directory('${root.path}/container')..createSync();
  for (final file in {_controller, _verifBotConfig}) {
    final patterns = _flags
        .where((f) => f.compiled == file && f.pattern != null)
        .map((f) => f.pattern!)
        .where(reads.contains);
    File('${container.path}/$file')
      ..createSync(recursive: true)
      ..writeAsStringSync(['// compilé', ...patterns].join('\n'));
  }
  final docker = File('${bin.path}/docker')..writeAsStringSync(_fakeDocker);
  Process.runSync('chmod', ['+x', docker.path]);
  final log = File('${root.path}/docker.log')..writeAsStringSync('');

  final result = Process.runSync(
    'bash',
    [File(_scriptPath).absolute.path],
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'VPS_PATH': vps.path,
      'ACTION': action,
      if (dryRun != null) 'DRY_RUN': dryRun,
      'FAKE_DOCKER_LOG': log.path,
      'FAKE_CONTAINER_ROOT': container.path,
      if (staleContainer) 'FAKE_STALE_CONTAINER': '1',
    },
    includeParentEnvironment: false,
  );

  return _Run(
    result.exitCode,
    '${result.stdout}\n${result.stderr}',
    File('${vps.path}/.env').readAsStringSync(),
    log.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
    vps
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((n) => n.startsWith('.env.bak.'))
        .toList(),
  );
}

/// Les lignes d'un `.env`, sauf celle de [key].
List<String> _others(String env, String key) => const LineSplitter()
    .convert(env)
    .where((l) => l.isNotEmpty && !l.startsWith('$key='))
    .toList();

// ── Le workflow ───────────────────────────────────────────────────────────────

String _step(String workflow, String namePrefix) {
  final starts = RegExp(r'^      - name: (.*)$', multiLine: true)
      .allMatches(workflow)
      .toList();
  for (var i = 0; i < starts.length; i++) {
    if (starts[i].group(1)!.startsWith(namePrefix)) {
      final end = i + 1 < starts.length ? starts[i + 1].start : workflow.length;
      return workflow.substring(starts[i].start, end);
    }
  }
  fail('Étape « $namePrefix… » introuvable dans $_workflowPath');
}

String _pythonProgram(String step) {
  final match =
      RegExp(r'''python3 -c '\n(.*?)\n[ ]*' < "\$config"''', dotAll: true)
          .firstMatch(step);
  expect(match, isNotNull);
  return match!.group(1)!;
}

String _runScript(String step) {
  final lines = step.split('\n');
  final at = lines.indexWhere((l) => l == '        run: |');
  expect(at, greaterThan(-1));
  final body = <String>[];
  for (final line in lines.skip(at + 1)) {
    if (line.trim().isNotEmpty && !line.startsWith(' ' * 10)) break;
    body.add(line.length >= 10 ? line.substring(10) : '');
  }
  return body.join('\n');
}

Map<String, String> _envBlock(String step) {
  final lines = step.split('\n');
  final at = lines.indexWhere((l) => l == '        env:');
  if (at < 0) return const {};
  final env = <String, String>{};
  for (final line in lines.skip(at + 1)) {
    final m = RegExp(r'^          (\w+): (.*)$').firstMatch(line);
    if (m == null) break;
    env[m.group(1)!] = m.group(2)!;
  }
  return env;
}

const _healthUrl = 'http://kpb.test';

const _fakeCurl = r'''#!/usr/bin/env bash
echo "$*" >> "$FAKE_CURL_LOG"
[ "${FAKE_CURL_FAIL:-0}" = "1" ] && exit 22
out=""; prev=""
for arg in "$@"; do
  [ "$prev" = "-o" ] && out="$arg"
  prev="$arg"
done
cp "$FAKE_CONFIG" "$out"
''';

class _StepRun {
  _StepRun(this.code, this.output, this.curlCalls);
  final int code;
  final String output;
  final List<String> curlCalls;
}

/// Joue l'étape avec EXACTEMENT les variables de son bloc `env:`.
_StepRun _playStep(String step,
    {required String action, required Map<String, Object?>? config}) {
  final root = Directory.systemTemp.createTempSync('vps_ops_57_step_');
  addTearDown(() => root.deleteSync(recursive: true));
  final bin = Directory('${root.path}/bin')..createSync();
  final curl = File('${bin.path}/curl')..writeAsStringSync(_fakeCurl);
  Process.runSync('chmod', ['+x', curl.path]);
  final curlLog = File('${root.path}/curl.log')..writeAsStringSync('');
  final configFile = File('${root.path}/served.json')
    ..writeAsStringSync(jsonEncode(config ?? const {}));
  final script = File('${root.path}/step.sh')
    ..writeAsStringSync(_runScript(step));

  final env = <String, String>{};
  for (final entry in _envBlock(step).entries) {
    switch (entry.value) {
      case r'${{ secrets.VPS_HEALTH_URL }}':
        env[entry.key] = _healthUrl;
      case r'${{ inputs.action }}':
        env[entry.key] = action;
      default:
        fail('${entry.key}: expression « ${entry.value} » non gérée');
    }
  }

  final result = Process.runSync(
    'bash',
    ['-e', script.path],
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'TMPDIR': root.path,
      'FAKE_CURL_LOG': curlLog.path,
      'FAKE_CONFIG': configFile.path,
      if (config == null) 'FAKE_CURL_FAIL': '1',
      ...env,
    },
    includeParentEnvironment: false,
  );
  return _StepRun(
    result.exitCode,
    '${result.stdout}\n${result.stderr}',
    curlLog.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
  );
}

/// `/config/app` avec toutes les clés de la 57 à leur défaut, puis [over].
Map<String, Object?> _served(Map<String, Object?> over,
        {Set<String> absent = const {}}) =>
    {
      'features': {
        for (final e in {
          'referralLeaderboard': false,
          'referralOnboardingCode': false,
          'referralInstallReferrer': false,
          'community': false,
          'assistBridge': false,
          'scholarshipMatch': false,
          'onboardingV2': false,
          ...over,
        }.entries)
          if (!absent.contains(e.key)) e.key: e.value,
      },
    };

List<String> _menuActions(String workflow) =>
    RegExp(r'options:\s*\n((?:\s*- \S+\n)+)')
        .firstMatch(workflow)!
        .group(1)!
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('- '))
        .map((l) => l.substring(2))
        .toList();

Map<String, bool> _evalIf(String step, List<String> actions) {
  final raw = RegExp(r'^        if: \$\{\{ (.*) \}\}$', multiLine: true)
      .firstMatch(step)
      ?.group(1);
  expect(raw, isNotNull);
  final python = raw!
      .replaceAllMapped(RegExp(r"inputs\.action == '([^']+)'"),
          (m) => "(A == '${m.group(1)}')")
      .replaceAll('inputs.dry_run', 'D')
      .replaceAll('success()', 'True')
      .replaceAll('&&', ' and ')
      .replaceAll('||', ' or ')
      .replaceAll('!', ' not ');
  const program = '''
import json, sys
out = {}
for a in json.loads(sys.argv[1]):
    for d in (True, False):
        out["%s|%s" % (a, str(d).lower())] = bool(eval(sys.argv[2], {}, {"A": a, "D": d}))
print(json.dumps(out))
''';
  final result =
      Process.runSync('python3', ['-c', program, jsonEncode(actions), python]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return (jsonDecode(result.stdout as String) as Map<String, dynamic>)
      .cast<String, bool>();
}

void main() {
  final script = File(_scriptPath).readAsStringSync();
  final workflow = File(_workflowPath).readAsStringSync();

  test('le script est de la syntaxe bash valide', () {
    final result = Process.runSync('bash', ['-n', _scriptPath]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  group('le menu', () {
    final actions = _menuActions(workflow);
    for (final f in _flags) {
      test('${f.action} est proposée et a sa branche', () {
        expect(actions, contains(f.action));
        expect(script, contains('\n  ${f.action})\n'));
      });
    }

    test('la simulation est annoncée pour les ouvertures, pas les retours', () {
      final description = RegExp(r"description: 'Simuler seulement \(([^)]*)\)")
          .firstMatch(workflow)!
          .group(1)!
          .split(', ')
          .toSet();
      for (final f in _flags) {
        expect(description.contains(f.action), f.opens, reason: f.action);
      }
    });

    test('l\'en-tête du workflow nomme les clés que ces branches écrivent', () {
      for (final key in _flags.map((f) => f.envKey).toSet()) {
        expect(workflow, contains('`$key`'));
      }
    });
  });

  // ── Les runbooks renvoient vers ces actions, plus vers le SSH ─────────────
  group('les runbooks nomment des actions qui existent', () {
    final actions = _menuActions(workflow).toSet();
    const docs = {
      'docs/runbook-campagne-ambassadeurs.md': [
        'referral-leaderboard-on',
        'referral-onboarding-code-on',
        'referral-install-referrer-on',
        'referral-leaderboard-off',
      ],
      'docs/runbook-bot-passerelle.md': [
        'assist-bridge-on',
        'assist-bridge-shadow',
        'assist-bridge-off',
      ],
      'docs/runbook-bot-verif.md': [
        'verif-bot-auto',
        'verif-bot-review',
        'verif-bot-off',
      ],
    };
    for (final entry in docs.entries) {
      test(entry.key, () {
        final text = File(entry.key).readAsStringSync();
        final cited = RegExp(r'vps-ops\s*→\s*([a-z][a-z0-9-]*)')
            .allMatches(text)
            .map((m) => m.group(1)!)
            .toSet();
        expect(cited, containsAll(entry.value));
        expect(actions, containsAll(cited),
            reason: 'action citée absente du menu');
        // Plus de recette « éditer le .env puis docker compose up » pour ces clés.
        expect(text, isNot(contains('docker compose up -d api')));
      });
    }

    test(
        'la checklist 57 referme « Mes 10 bourses » et l\'onboarding V2 '
        'par VPS ops avant la revue', () {
      final text = File('docs/mise-a-jour-57-checklist.md')
          .readAsStringSync()
          .replaceAll(RegExp(r'\s+'), ' ');
      for (final action in [
        'onboarding-v2-on',
        'onboarding-v2-off',
        'scholarship-match-on',
        'scholarship-match-off',
      ]) {
        expect(text, contains('`$action`'), reason: action);
        expect(actions, contains(action));
      }
      // Plus de « remettre la variable à false dans le .env » pour ces clés.
      expect(text, isNot(contains('remettre la variable à `false`')));
      expect(text, contains('refermer** toute fenêtre de recette'));
    });

    test('le pack 57 liste chaque action et sa clé', () {
      final pack = File('docs/release-57-store-pack.md').readAsStringSync();
      for (final f in _flags) {
        final short = f.action.substring(f.action.lastIndexOf('-'));
        expect(pack, anyOf(contains('`${f.action}`'), contains('`$short`')),
            reason: f.action);
        expect(pack, contains(f.envKey));
      }
    });
  });

  // ── Les valeurs écrites sont celles que le backend lit ────────────────────
  group('valeurs permises, relues dans le code', () {
    final controller =
        File('backend/src/modules/config/app-config.controller.ts')
            .readAsStringSync();
    final flags = File('lib/app/core/services/remote_feature_flags.dart')
        .readAsStringSync();
    final compose = File('docker-compose.yml').readAsStringSync();
    final modes = {
      'KPB_ASSIST_BRIDGE_MODE':
          File('backend/src/modules/assist-bridge/assist-bridge.config.ts')
              .readAsStringSync(),
      'KPB_COMMUNITY_VERIF_BOT_MODE':
          File('backend/src/modules/community/community-verif-bot.config.ts')
              .readAsStringSync(),
    };

    for (final f in _flags) {
      test('${f.action} : ${f.envKey}=${f.value} est une valeur reconnue', () {
        expect(compose, contains('- ${f.envKey}=\${${f.envKey}'),
            reason: 'clé non relayée par compose');
        final mode = modes[f.envKey];
        if (mode == null) {
          expect(f.value, anyOf('true', 'false'));
          expect(controller, contains('process.env.${f.envKey}'));
        } else {
          // Le type union du mode porte la valeur : une faute de frappe serait
          // ramenée au défaut par le serveur, en silence.
          expect(RegExp("Mode = [^;]*'${f.value}'").hasMatch(mode), isTrue,
              reason: '${f.value} n\'est pas un mode de ${f.envKey}');
        }
        expect(
            script, contains('flag57_set ${f.envKey} ${f.value} ${f.action} '));
      });

      if (f.jsonKey != null) {
        test('${f.action} : features.${f.jsonKey} servie et lue par l\'app',
            () {
          expect(controller, contains('${f.jsonKey}:'));
          expect(flags, contains("_flag('${f.jsonKey}'"));
        });
      }
    }

    test('assistBridge n\'est vrai qu\'en mode `on`', () {
      expect(controller, contains("assistBridge: assistBridgeMode() === 'on'"));
    });

    test('les fichiers compilés visés par le garde existent en source', () {
      for (final file in {_controller, _verifBotConfig}) {
        expect(
            File('backend/src/${file.replaceFirst('dist/', '').replaceFirst('.js', '.ts')}')
                .existsSync(),
            isTrue,
            reason: file);
      }
    });
  });

  // ── Le script, joué : ouvertures ──────────────────────────────────────────
  for (final f in _flags.where((f) => f.opens)) {
    group('${f.action} — pose ${f.envKey}=${f.value}', () {
      test('SIMULATION par défaut, et sur toute valeur autre que « false »',
          () {
        for (final dry in [null, 'true', '', 'oui', 'True', '0']) {
          final run = _runOps(f.action, dryRun: dry);
          expect(run.exitCode, 0, reason: 'dry_run=$dry : ${run.output}');
          expect(run.output, contains('SIMULATION'));
          expect(run.env, _baseEnv, reason: 'la simulation a écrit');
          expect(run.recreated, isFalse);
          expect(run.backups, isEmpty);
        }
      });

      test('la simulation CONTRÔLE le backend déployé (sans son code = refus)',
          () {
        for (final dry in [null, 'false']) {
          final run = _runOps(f.action, dryRun: dry, backendReads: const {});
          expect(run.exitCode, isNot(0), reason: run.output);
          expect(run.output,
              contains('Déployer d\'abord le backend de la build 57'));
          expect(run.env, _baseEnv);
          expect(run.recreated, isFalse);
          expect(run.backups, isEmpty);
        }
      });

      test('le garde cherche SON motif dans SON fichier compilé', () {
        final run = _runOps(f.action, dryRun: 'false');
        expect(run.exitCode, 0, reason: run.output);
        expect(run.dockerCalls,
            contains('compose exec -T api grep -q ${f.pattern} ${f.compiled}'));
        // Un backend qui porte toutes les AUTRES clés, pas la sienne : refus.
        final others = {
          for (final o in _flags)
            if (o.pattern != null && o.pattern != f.pattern) o.pattern!
        };
        final refused =
            _runOps(f.action, dryRun: 'false', backendReads: others);
        expect(refused.exitCode, isNot(0), reason: refused.output);
        expect(refused.recreated, isFalse);
      });

      test(
          'application : pose SA clé, sauvegarde, recrée api à l\'identique, '
          'prouve la valeur lue par le conteneur', () {
        final run = _runOps(f.action, dryRun: 'false');
        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(f.envKey), f.value);
        expect(run.backups, hasLength(1));
        expect(run.dockerCalls,
            contains('compose up -d --no-deps --no-build api'));
        expect(run.output, contains('kpb_api lit ${f.envKey}=${f.value}'));
        // AUCUNE autre ligne ne bouge, et la clé est remplacée, pas dupliquée.
        expect(_others(run.env, f.envKey), _others(_baseEnv, f.envKey));
        expect(RegExp('^${f.envKey}=', multiLine: true).allMatches(run.env),
            hasLength(1));
      });

      test('conteneur qui n\'a PAS relu le .env : rouge', () {
        final run = _runOps(f.action, dryRun: 'false', staleContainer: true);
        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.output, contains('le .env n\'a pas été relu'));
      });

      test('clé absente, .env sans saut de ligne final, .env vide', () {
        final noEol = _runOps(f.action,
            dryRun: 'false', initialEnv: 'POSTGRES_PASSWORD=s3cret');
        expect(noEol.exitCode, 0, reason: noEol.output);
        expect(noEol.value('POSTGRES_PASSWORD'), 's3cret');
        expect(noEol.value(f.envKey), f.value);

        final empty = _runOps(f.action, dryRun: 'false', initialEnv: '');
        expect(empty.exitCode, 0, reason: empty.output);
        expect(empty.env, '${f.envKey}=${f.value}\n');
      });

      test('refuse si compose ne relaie pas la clé (rien d\'écrit)', () {
        final compose = File('docker-compose.yml')
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.contains('- ${f.envKey}='))
            .join('\n');
        final run = _runOps(f.action, dryRun: 'false', composeText: compose);
        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.output, contains(f.envKey));
        expect(run.env, _baseEnv);
        expect(run.recreated, isFalse);
      });
    });
  }

  // ── Le script, joué : retours arrière ─────────────────────────────────────
  for (final f in _flags.where((f) => !f.opens)) {
    group('${f.action} — pose ${f.envKey}=${f.value} (retour arrière)', () {
      final opened = _flags.firstWhere((o) => o.envKey == f.envKey && o.opens);
      final from = _baseEnv.replaceFirst(
          RegExp('^${f.envKey}=.*\$', multiLine: true),
          '${f.envKey}=${opened.value}');

      test('AGIT tout de suite, dry_run coché ou non', () {
        for (final dry in [null, 'true', 'false']) {
          final run = _runOps(f.action, dryRun: dry, initialEnv: from);
          expect(run.exitCode, 0, reason: 'dry_run=$dry : ${run.output}');
          expect(run.value(f.envKey), f.value);
          expect(run.recreated, isTrue);
          expect(run.backups, hasLength(1));
          expect(run.output, contains('kpb_api lit ${f.envKey}=${f.value}'));
          expect(_others(run.env, f.envKey), _others(from, f.envKey));
        }
      });

      test('ne dépend PAS du code déployé : on doit toujours pouvoir revenir',
          () {
        final run = _runOps(f.action, initialEnv: from, backendReads: const {});
        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(f.envKey), f.value);
        expect(run.dockerCalls.where((c) => c.startsWith('compose exec')),
            isEmpty);
      });

      test('refuse si compose ne relaie pas la clé', () {
        final compose = File('docker-compose.yml')
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.contains('- ${f.envKey}='))
            .join('\n');
        final run = _runOps(f.action, initialEnv: from, composeText: compose);
        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.env, from);
        expect(run.recreated, isFalse);
      });
    });
  }

  group('ordre du plan : prévient, ne bloque pas', () {
    test('onboarding-code avant le classement', () {
      final run = _runOps('referral-onboarding-code-on');
      expect(run.exitCode, 0, reason: run.output);
      expect(run.output, contains('referral-leaderboard-on'));
    });

    test('Install Referrer avant le code à l\'onboarding', () {
      final run = _runOps('referral-install-referrer-on');
      expect(run.exitCode, 0, reason: run.output);
      expect(run.output, contains('referral-onboarding-code-on'));
    });

    test('bots sans communauté ouverte', () {
      for (final action in ['assist-bridge-on', 'verif-bot-auto']) {
        final run = _runOps(action);
        expect(run.exitCode, 0, reason: run.output);
        expect(run.output, contains('::warning::KPB_COMMUNITY_ENABLED'));
      }
      final open = _runOps('assist-bridge-on',
          initialEnv: '${_baseEnv}KPB_COMMUNITY_ENABLED=true\n');
      expect(open.output, isNot(contains('::warning::KPB_COMMUNITY_ENABLED')));
    });

    test('les critères non mesurables sont rappelés à la simulation', () {
      expect(_runOps('assist-bridge-on').output, contains('2 semaines'));
      expect(_runOps('verif-bot-auto').output, contains('50 réponses'));
    });

    test(
        '« Mes 10 bourses » avant l\'onboarding V2 (pack 57 §5, étapes 2 et 4)',
        () {
      final run = _runOps('scholarship-match-on');
      expect(run.exitCode, 0, reason: run.output);
      expect(run.output, contains('::warning::KPB_ONBOARDING_V2_ENABLED'));
      expect(run.output, contains('onboarding-v2-on'));
      final after = _runOps('scholarship-match-on',
          initialEnv: '${_baseEnv}KPB_ONBOARDING_V2_ENABLED=true\n');
      expect(after.exitCode, 0, reason: after.output);
      expect(after.output,
          isNot(contains('::warning::KPB_ONBOARDING_V2_ENABLED')));
    });

    test('la revue Apple exige ces deux drapeaux fermés : -off rappelé', () {
      for (final (action, key, off) in [
        ('onboarding-v2-on', 'onboardingV2', 'onboarding-v2-off'),
        ('scholarship-match-on', 'scholarshipMatch', 'scholarship-match-off'),
      ]) {
        for (final dry in [null, 'false']) {
          final run = _runOps(action, dryRun: dry);
          expect(run.exitCode, 0, reason: run.output);
          expect(
              run.output,
              contains('::warning::La revue Apple exige '
                  'features.$key=false : refermer par $off'));
        }
      }
    });

    test('« Mes 10 bourses » : consentement à la nationalité rappelé', () {
      final out = _runOps('scholarship-match-on').output;
      expect(out, contains('consentement explicite (décision c'));
      expect(out, contains('90 %'));
    });
  });

  group('show-state et le .env après écriture listent les deux clés', () {
    test(
        'le motif des drapeaux 57 couvre « Mes 10 bourses » et l\'onboarding V2',
        () {
      final run = _runOps('onboarding-v2-off');
      expect(run.exitCode, 0, reason: run.output);
      final shown =
          run.output.substring(run.output.indexOf('── .env après écriture ──'));
      expect(shown, contains('KPB_SCHOLARSHIP_MATCH_ENABLED=false'));
      expect(shown, contains('KPB_ONBOARDING_V2_ENABLED=false'));
      expect(shown, isNot(contains('POSTGRES_PASSWORD')));
      // `show-state` passe par la même fonction.
      final showState =
          RegExp(r'\nshow_state\(\) \{\n(.*?)\n\}\n', dotAll: true)
              .firstMatch(script)!
              .group(1)!;
      expect(showState, contains('show_flags57'));
      expect(showState, contains('« Mes 10 bourses », onboarding V2'));
    });
  });

  // ── Le workflow prouve features.* depuis /config/app ──────────────────────
  group('le workflow prouve l\'état depuis /config/app', () {
    late String proof;
    setUp(() => proof = _step(workflow, 'Prouver l\'état du drapeau 57'));

    test('la preuve vient APRÈS l\'attente de disponibilité de l\'API', () {
      expect(
          workflow.indexOf(
              "- name: Vérifier depuis l'extérieur ce que le serveur annonce vraiment"),
          lessThan(workflow.indexOf(proof)));
      expect(proof, contains(r'if: ${{ success() && ('));
    });

    test(
        'table de vérité : tourne pour les actions à clé features.*, '
        'une ouverture seulement appliquée', () {
      final actions = _menuActions(workflow);
      final proven = {
        for (final f in _flags)
          if (f.jsonKey != null) f.action: f
      };
      final truth = _evalIf(proof, actions);
      for (final action in actions) {
        for (final dry in [true, false]) {
          final f = proven[action];
          final expected = f != null && (!f.opens || !dry);
          expect(truth['$action|$dry'], expected,
              reason: 'action=$action dry_run=$dry');
        }
      }
    });

    test('AUCUNE apostrophe dans le programme Python', () {
      expect(_pythonProgram(proof), isNot(contains("'")));
    });

    for (final f in _flags.where((f) => f.jsonKey != null)) {
      final key = f.jsonKey!;
      test('${f.action} : features.$key=${f.served} prouvée, le reste rouge',
          () {
        final ok = _playStep(proof,
            action: f.action, config: _served({key: f.served}));
        expect(ok.code, 0, reason: ok.output);
        expect(ok.output, contains('$key = ${f.served ? "True" : "False"}'));
        expect(ok.curlCalls.single, contains('$_healthUrl/api/config/app'));
        expect(ok.curlCalls.single, contains('--retry-all-errors'));

        final wrong = _playStep(proof,
            action: f.action, config: _served({key: !f.served}));
        expect(wrong.code, isNot(0), reason: wrong.output);
        expect(wrong.output, contains('features.$key='));

        final text = _playStep(proof,
            action: f.action, config: _served({key: '${f.served}'}));
        expect(text.code, isNot(0));

        final absent = _playStep(proof,
            action: f.action, config: _served({}, absent: {key}));
        expect(absent.code, isNot(0));
        expect(absent.output, contains('features.$key absent'));

        expect(_playStep(proof, action: f.action, config: null).code, isNot(0));
      });

      test('${f.action} : c\'est SA clé qui est vérifiée', () {
        // Toutes les autres à la valeur voulue, la sienne contraire : rouge.
        final all = {
          for (final o in _flags)
            if (o.jsonKey != null) o.jsonKey!: f.served
        }..[key] = !f.served;
        expect(_playStep(proof, action: f.action, config: _served(all)).code,
            isNot(0));
      });
    }

    test('une action inconnue est REFUSÉE, jamais devinée', () {
      for (final action in ['verif-bot-auto', 'eef-space-on']) {
        final r = _playStep(proof, action: action, config: _served({}));
        expect(r.code, isNot(0), reason: r.output);
        expect(r.output, contains('Action inconnue'));
        expect(r.output, isNot(contains('Traceback')));
      }
    });
  });
}
