// L'avis de l'app dans « VPS ops » : `app-notice-set` (audit avant la 59).
//
// `GET /config/app` sert `notice` depuis `KPB_APP_NOTICE_FR`, `_EN` et `_URL`,
// mais aucune action ne posait ces clés : le seul moyen de parler à tous les
// téléphones installés sans nouvelle build n'était pas utilisable. Cette action
// les pose, sur le modèle d'`app-whatsapp-set` : constantes dans le script,
// relues en PR, simulation par défaut.
//
// C'est la première valeur en TEXTE LIBRE que le script écrit dans le `.env`.
// Deux pièges, tous deux joués ici :
//
//   • `set_env_key` passait la valeur à `sed "s|…|…|"` : un `|` coupait la
//     commande, un `&` recopiait l'ancienne ligne. Elle écrit désormais la
//     valeur telle quelle ;
//   • Docker Compose RÉINTERPRÈTE le `.env` : `$NOM` devient une variable du
//     serveur, ` #` coupe le texte, un guillemet en tête rend le fichier
//     illisible. Le script refuse ces textes avant d'écrire.
//
// Comme `vps_ops_flags_57_test.dart`, ce fichier JOUE le script (avec un faux
// `docker`). Et parce que les règles de refus viennent du comportement de
// Docker Compose, le dernier groupe les prouve avec le VRAI `docker compose
// config` : une règle qu'on n'a jamais vue mordre ne prouve rien.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scriptPath = '.github/scripts/vps-ops.sh';
const _workflowPath = '.github/workflows/vps-ops.yml';
const _controllerSource = 'backend/src/modules/config/app-config.controller.ts';
const _controller = 'dist/modules/config/app-config.controller.js';
const _keys = ['KPB_APP_NOTICE_FR', 'KPB_APP_NOTICE_EN', 'KPB_APP_NOTICE_URL'];

/// Un `.env` de production plausible : un secret aux caractères hostiles, un
/// interrupteur, et un avis DÉJÀ posé (à remplacer, jamais à doubler).
const _baseEnv = 'POSTGRES_PASSWORD=s3|cr&t\\x\$y\n'
    'KPB_EEF_SPACE_ENABLED=true\n'
    'KPB_APP_NOTICE_FR=Ancien avis\n'
    'KPB_APP_WHATSAPP_NUMBER=+33768674292\n';

/// Un avis réaliste, avec tout ce qu'un texte français contient et que `sed`
/// ou un shell abîmeraient : apostrophes, `&`, `|`, guillemets, accents, émoji.
const _fr =
    "Maroc : l'inscription « Études en France » ferme le 15 nov. — bourses & visas | n'attends pas 😀";
const _en =
    'Morocco: "Études en France" closes on 15 Nov. — scholarships & visas';
const _url = 'https://www.campusfrance.org/fr/page?a=1&b=2#dates';

// ── Un faux `docker` ──────────────────────────────────────────────────────────
//
// Il refuse (99) tout appel imprévu. `inspect … .Config.Env` rend l'empreinte de
// build PLUS le `.env` du VPS : ce que voit un conteneur recréé qui a relu le
// fichier. Avec FAKE_STALE_CONTAINER=1 il ne rend que l'empreinte, et la preuve
// du script doit rougir.
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

/// Une valeur écrite comme une constante du script : entre apostrophes
/// droites, une apostrophe du texte devenant `'\''`.
String _bashQuoted(String value) => "'${value.replaceAll("'", r"'\''")}'";

/// Le script, avec les trois constantes de l'avis remplacées — exactement ce
/// que fait la PR qui pose un avis.
String _scriptWith({String fr = '', String en = '', String url = ''}) {
  var script = File(_scriptPath).readAsStringSync();
  for (final entry in {
    'APP_NOTICE_FR': fr,
    'APP_NOTICE_EN': en,
    'APP_NOTICE_URL': url,
  }.entries) {
    final line = RegExp("^${entry.key}=''\$", multiLine: true);
    expect(line.allMatches(script), hasLength(1),
        reason: "constante ${entry.key}='' introuvable ou plus VIDE par défaut "
            'dans $_scriptPath');
    script =
        script.replaceFirst(line, '${entry.key}=${_bashQuoted(entry.value)}');
  }
  return script;
}

class _Run {
  _Run(this.exitCode, this.output, this.env, this.dockerCalls, this.files,
      this.envMode);
  final int exitCode;
  final String output;

  /// Le `.env` APRÈS l'exécution.
  final String env;
  final List<String> dockerCalls;

  /// Les fichiers du répertoire du VPS après l'exécution.
  final List<String> files;

  /// Les droits du `.env` après l'exécution (`600`).
  final String envMode;

  List<String> get backups =>
      files.where((n) => n.startsWith('.env.bak.')).toList();

  bool get recreated => dockerCalls
      .any((c) => c.startsWith('compose up -d --no-deps --no-build'));

  /// Les lignes d'une clé dans le `.env` final (une seule attendue).
  List<String> lines(String key) => const LineSplitter()
      .convert(env)
      .where((l) => l.startsWith('$key='))
      .toList();

  String? value(String key) {
    final found = lines(key);
    return found.isEmpty ? null : found.last.substring(key.length + 1);
  }
}

/// Exécute `vps-ops.sh` pour de bon, action `app-notice-set` par défaut.
///
/// [composeText] est, par défaut, le VRAI `docker-compose.yml` : `require_relay`
/// lit donc le relais réel. [backendServesNotice] : le contrôleur compilé du
/// faux conteneur lit-il `KPB_APP_NOTICE_FR` ?
_Run _runOps({
  String action = 'app-notice-set',
  String? script,
  String? dryRun,
  String initialEnv = _baseEnv,
  String? composeText,
  bool backendServesNotice = true,
  bool staleContainer = false,
  Map<String, String> extraEnvironment = const {},
}) {
  final root = Directory.systemTemp.createTempSync('vps_ops_notice_');
  addTearDown(() => root.deleteSync(recursive: true));

  final vps = Directory('${root.path}/vps')..createSync();
  final bin = Directory('${root.path}/bin')..createSync();
  final envFile = File('${vps.path}/.env')..writeAsStringSync(initialEnv);
  Process.runSync('chmod', ['600', envFile.path]);
  File('${vps.path}/docker-compose.yml').writeAsStringSync(
      composeText ?? File('docker-compose.yml').readAsStringSync());
  final container = Directory('${root.path}/container')..createSync();
  File('${container.path}/$_controller')
    ..createSync(recursive: true)
    ..writeAsStringSync([
      '// compilé',
      'support: { whatsappNumber: process.env.KPB_APP_WHATSAPP_NUMBER }',
      if (backendServesNotice) 'notice: process.env.KPB_APP_NOTICE_FR',
    ].join('\n'));
  final docker = File('${bin.path}/docker')..writeAsStringSync(_fakeDocker);
  Process.runSync('chmod', ['+x', docker.path]);
  final log = File('${root.path}/docker.log')..writeAsStringSync('');
  final played = File('${root.path}/vps-ops.sh')
    ..writeAsStringSync(script ?? File(_scriptPath).readAsStringSync());

  final result = Process.runSync(
    'bash',
    [played.path],
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'VPS_PATH': vps.path,
      'ACTION': action,
      if (dryRun != null) 'DRY_RUN': dryRun,
      'FAKE_DOCKER_LOG': log.path,
      'FAKE_CONTAINER_ROOT': container.path,
      if (staleContainer) 'FAKE_STALE_CONTAINER': '1',
      ...extraEnvironment,
    },
    includeParentEnvironment: false,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  return _Run(
    result.exitCode,
    '${result.stdout}\n${result.stderr}',
    envFile.readAsStringSync(),
    log.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
    vps.listSync().map((e) => e.path.split('/').last).toList(),
    (Process.runSync('ls', ['-l', envFile.path]).stdout as String)
        .substring(0, 10),
  );
}

/// Les lignes du `.env` qui ne sont PAS celles de l'avis.
List<String> _others(String env) => const LineSplitter()
    .convert(env)
    .where((l) => l.isNotEmpty && !_keys.any((k) => l.startsWith('$k=')))
    .toList();

/// `docker compose` est-il utilisable ici ? Absent d'un poste, le groupe qui en
/// dépend est sauté — mais JAMAIS sur la CI, où un test sauté passerait vert
/// sans rien prouver.
bool _composeAvailable() {
  try {
    return Process.runSync('docker', ['compose', 'version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Ce que le VRAI Docker Compose rend d'un `.env`, pour les trois clés de
/// l'avis relayées comme dans `docker-compose.yml`. Null si Compose échoue.
Map<String, String>? _composeReads(String envText) {
  final root = Directory.systemTemp.createTempSync('compose_notice_');
  addTearDown(() => root.deleteSync(recursive: true));
  // Les lignes de relais sont COPIÉES du vrai fichier : si leur forme change
  // (guillemets, valeur par défaut), ce test lit la nouvelle forme.
  final relays = const LineSplitter()
      .convert(File('docker-compose.yml').readAsStringSync())
      .where((l) => _keys.any((k) => l.trim().startsWith('- $k=')))
      .map((l) => '      ${l.trim()}')
      .toList();
  expect(relays, hasLength(3),
      reason: 'les trois clés de l\'avis doivent être relayées');
  File('${root.path}/docker-compose.yml').writeAsStringSync([
    'services:',
    '  api:',
    '    image: alpine',
    '    environment:',
    ...relays,
    '',
  ].join('\n'));
  File('${root.path}/.env').writeAsStringSync(envText);
  final result = Process.runSync(
    'docker',
    [
      'compose',
      '--project-directory',
      root.path,
      '-f',
      '${root.path}/docker-compose.yml',
      'config',
      '--format',
      'json',
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) return null;
  final config = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final environment = (config['services'] as Map<String, dynamic>)['api']
      ['environment'] as Map<String, dynamic>;
  // `config` écrit `$$` pour un dollar littéral : c'est son échappement, pas
  // la valeur que reçoit le conteneur.
  return {
    for (final key in _keys)
      key: (environment[key] as String? ?? '').replaceAll(r'$$', r'$'),
  };
}

void main() {
  final workflow = File(_workflowPath).readAsStringSync();
  final script = File(_scriptPath).readAsStringSync();

  group('app-notice-set est une action fermée, des deux côtés', () {
    test('elle est au menu du workflow et dans le script', () {
      expect(workflow, contains('          - app-notice-set\n'));
      expect(script, contains('\n  app-notice-set)\n'));
    });

    test('la case « dry_run » dit qu\'elle simule', () {
      final description = RegExp(r"description: 'Simuler seulement \(([^)]*)\)")
          .firstMatch(workflow)
          ?.group(1);
      expect(description, isNotNull);
      expect(description!.split(', '), contains('app-notice-set'));
    });

    test('les constantes sont VIDES par défaut : fusionner ne pose aucun avis',
        () {
      for (final name in ['APP_NOTICE_FR', 'APP_NOTICE_EN', 'APP_NOTICE_URL']) {
        expect(RegExp("^$name=''\$", multiLine: true).hasMatch(script), isTrue,
            reason: '$name doit valoir \'\' sur main tant qu\'aucun avis '
                'n\'est décidé');
      }
    });

    test('le workflow ne reçoit AUCUN texte : pas d\'entrée libre pour l\'avis',
        () {
      expect(workflow, isNot(contains('notice_fr')));
      expect(workflow, isNot(contains('APP_NOTICE_FR:')));
    });

    test(
        'le serveur lit les trois clés, compose les relaie, et la limite est la même',
        () {
      final controller = File(_controllerSource).readAsStringSync();
      final compose = File('docker-compose.yml').readAsStringSync();
      for (final key in _keys) {
        expect(controller, contains('process.env.$key'));
        expect(compose, contains('- $key=\${$key:-}'));
      }
      final serverLimit = RegExp(r'APP_NOTICE_MAX_LENGTH = (\d+);')
          .firstMatch(controller)
          ?.group(1);
      final scriptLimit =
          RegExp(r'^APP_NOTICE_MAX_LENGTH=(\d+)$', multiLine: true)
              .firstMatch(script)
              ?.group(1);
      expect(serverLimit, isNotNull);
      expect(scriptLimit, serverLimit,
          reason: 'le script refuse au-delà de ce que le serveur coupe');
    });
  });

  group('app-notice-set simule par défaut', () {
    for (final dryRun in <String?>[null, 'true', '', 'flase']) {
      test('DRY_RUN=${dryRun ?? '<absent>'} : contrôles joués, rien écrit', () {
        final run = _runOps(
          script: _scriptWith(fr: _fr, en: _en, url: _url),
          dryRun: dryRun,
        );
        expect(run.exitCode, 0, reason: run.output);
        expect(run.output, contains('SIMULATION'));
        expect(run.output, contains('KPB_APP_NOTICE_FR=$_fr'));
        expect(run.env, _baseEnv);
        expect(run.recreated, isFalse);
        expect(run.backups, isEmpty);
      });
    }
  });

  group('app-notice-set pose l\'avis tel qu\'il est écrit', () {
    late _Run run;
    setUp(() {
      run = _runOps(
        script: _scriptWith(fr: _fr, en: _en, url: _url),
        dryRun: 'false',
      );
    });

    test('les trois clés portent le texte, octet pour octet', () {
      expect(run.exitCode, 0, reason: run.output);
      expect(run.value('KPB_APP_NOTICE_FR'), _fr);
      expect(run.value('KPB_APP_NOTICE_EN'), _en);
      expect(run.value('KPB_APP_NOTICE_URL'), _url);
    });

    test(
        'la clé déjà posée est REMPLACÉE, les nouvelles ajoutées, aucune doublée',
        () {
      for (final key in _keys) {
        expect(run.lines(key), hasLength(1), reason: key);
      }
      expect(run.env, isNot(contains('Ancien avis')));
    });

    test('rien d\'autre ne bouge — ni le secret, ni l\'espace, ni le numéro',
        () {
      expect(_others(run.env), _others(_baseEnv));
    });

    test('le .env est sauvegardé, garde ses droits, et rien ne traîne', () {
      expect(run.backups, hasLength(1));
      expect(run.envMode, '-rw-------');
      expect(run.files.where((n) => n.startsWith('.env.tmp')), isEmpty);
    });

    test('l\'API est recréée à l\'identique, jamais reconstruite', () {
      expect(
          run.dockerCalls, contains('compose up -d --no-deps --no-build api'));
    });

    test('le texte lu par le conteneur est comparé à celui du script', () {
      expect(run.output, contains('kpb_api lit KPB_APP_NOTICE_FR=$_fr ✅'));
      expect(run.output, contains('kpb_api lit KPB_APP_NOTICE_URL=$_url ✅'));
    });

    test('un conteneur qui n\'a pas relu le .env fait ÉCHOUER l\'action', () {
      final stale = _runOps(
        script: _scriptWith(fr: _fr),
        dryRun: 'false',
        staleContainer: true,
      );
      expect(stale.exitCode, 1);
      expect(stale.output, contains("le .env n'a pas été relu"));
    });
  });

  group('app-notice-set retire un avis (constantes vides)', () {
    test('les trois clés sont vidées, le reste intact', () {
      final run = _runOps(dryRun: 'false');
      expect(run.exitCode, 0, reason: run.output);
      for (final key in _keys) {
        expect(run.lines(key), ['$key=']);
      }
      expect(_others(run.env), _others(_baseEnv));
      expect(run.recreated, isTrue);
    });

    test('retirer ne dépend pas du code déployé : un backend sans avis passe',
        () {
      final run = _runOps(dryRun: 'false', backendServesNotice: false);
      expect(run.exitCode, 0, reason: run.output);
      expect(run.value('KPB_APP_NOTICE_FR'), '');
    });
  });

  group('app-notice-set refuse d\'écrire', () {
    void refused(_Run run, String because) {
      expect(run.exitCode, 1, reason: run.output);
      expect(run.output, contains('::error::'));
      expect(run.output, contains(because));
      expect(run.env, _baseEnv, reason: 'le .env ne doit pas avoir bougé');
      expect(run.recreated, isFalse);
      expect(run.backups, isEmpty);
    }

    const cases = <String, List<String>>{
      'un dollar (Compose le remplacerait)': [
        r'Frais : 50 $ par dossier',
        r'$'
      ],
      'une variable': [r'Voir $HOME', r'$'],
      'une barre oblique inverse': [r'Chemin C:\temp', 'barre oblique inverse'],
      'un dièse': ['Suis #KPB pour les dates', '#'],
      'un guillemet en tête': [
        '"Études en France" ferme le 15',
        'commence par'
      ],
      'une apostrophe en tête': [
        "'Études en France' ferme le 15",
        'commence par'
      ],
      'un retour à la ligne': ['Ligne une\nLigne deux', 'retour à la ligne'],
      'une tabulation': ['Avant\taprès', 'tabulation'],
      'une espace en tête': [' Avis', 'espace'],
      'une espace en fin': ['Avis ', 'espace'],
      'deux espaces de suite': ['Avis  double', 'deux espaces'],
    };
    cases.forEach((label, data) {
      test('un texte avec $label', () {
        refused(
          _runOps(script: _scriptWith(fr: data[0]), dryRun: 'false'),
          data[1],
        );
      });
    });

    test('le même contrôle vaut pour le texte anglais', () {
      refused(
        _runOps(
            script: _scriptWith(fr: 'Avis', en: r'Fee: $50'), dryRun: 'false'),
        'APP_NOTICE_EN',
      );
    });

    test('un texte que le serveur couperait (241 caractères)', () {
      refused(
        _runOps(script: _scriptWith(fr: 'é' * 241), dryRun: 'false'),
        '241 caractères',
      );
    });

    test('un émoji compte pour deux, comme côté serveur', () {
      refused(
        _runOps(script: _scriptWith(fr: '😀' * 121), dryRun: 'false'),
        '242 caractères',
      );
    });

    test('un texte anglais ou un lien SANS texte français', () {
      refused(
        _runOps(script: _scriptWith(en: 'English only'), dryRun: 'false'),
        'APP_NOTICE_FR est vide',
      );
      refused(
        _runOps(script: _scriptWith(url: _url), dryRun: 'false'),
        'APP_NOTICE_FR est vide',
      );
    });

    const urls = <String, String>{
      'en http': 'http://www.campusfrance.org/',
      'avec une espace': 'https://www.campusfrance.org/une page',
      'avec un identifiant': 'https://kpb:secret@www.campusfrance.org/',
      'sans adresse': 'campusfrance.org',
      'avec un dollar': r'https://www.campusfrance.org/$HOME',
      'en javascript': 'javascript:alert(1)',
    };
    urls.forEach((label, url) {
      test('un lien $label', () {
        refused(
          _runOps(script: _scriptWith(fr: 'Avis', url: url), dryRun: 'false'),
          'APP_NOTICE_URL',
        );
      });
    });

    test('un refus se voit AUSSI en simulation', () {
      final run = _runOps(script: _scriptWith(fr: r'Voir $HOME'));
      expect(run.exitCode, 1);
      expect(run.output, isNot(contains('SIMULATION')));
    });

    test('un backend qui ne sert pas l\'avis : poser n\'aurait aucun effet',
        () {
      refused(
        _runOps(
          script: _scriptWith(fr: _fr),
          dryRun: 'false',
          backendServesNotice: false,
        ),
        'ne sert pas l\'avis',
      );
    });

    test('un checkout sans le relais dans compose', () {
      final compose = File('docker-compose.yml').readAsStringSync().replaceAll(
          RegExp(r'^.*KPB_APP_NOTICE_EN=.*\n', multiLine: true), '');
      refused(
        _runOps(
          script: _scriptWith(fr: _fr),
          dryRun: 'false',
          composeText: compose,
        ),
        'KPB_APP_NOTICE_EN n\'est pas relayée',
      );
    });
  });

  group('la longueur ne dépend pas de la langue du shell', () {
    // 240 « é » : 240 caractères, 480 octets. Un shell en locale C compte des
    // octets avec `${#texte}` et aurait refusé un texte permis.
    for (final locale in <String?>[null, 'C', 'en_US.UTF-8', 'C.UTF-8']) {
      test('240 caractères accentués passent (LC_ALL=${locale ?? '<absent>'})',
          () {
        final run = _runOps(
          script: _scriptWith(fr: 'é' * 240),
          dryRun: 'false',
          extraEnvironment: {if (locale != null) 'LC_ALL': locale},
        );
        expect(run.exitCode, 0, reason: run.output);
        expect(run.value('KPB_APP_NOTICE_FR'), 'é' * 240);
        expect(run.output, contains('240 caractère(s) en français'));
      });
    }
  });

  group('set_env_key écrit la valeur telle quelle (plus de sed)', () {
    test('la fonction ne passe plus la valeur à sed', () {
      final body = RegExp(r'^set_env_key\(\) \{$(.*?)^\}$',
              multiLine: true, dotAll: true)
          .firstMatch(script)
          ?.group(1);
      expect(body, isNotNull, reason: 'set_env_key introuvable');
      expect(body, isNot(contains('sed ')),
          reason: 'une valeur avec | ou & casserait ou réécrirait la ligne');
    });

    test('une clé posée deux fois est remplacée aux deux endroits', () {
      final run = _runOps(
        script: _scriptWith(fr: 'Bourses & visas | dépôt avant le 15'),
        dryRun: 'false',
        initialEnv: 'KPB_APP_NOTICE_FR=un\nAUTRE=x|y&z\nKPB_APP_NOTICE_FR=deux',
      );
      expect(run.exitCode, 0, reason: run.output);
      expect(run.lines('KPB_APP_NOTICE_FR'), [
        'KPB_APP_NOTICE_FR=Bourses & visas | dépôt avant le 15',
        'KPB_APP_NOTICE_FR=Bourses & visas | dépôt avant le 15',
      ]);
      expect(run.env, contains('AUTRE=x|y&z\n'));
    });

    test('les actions d\'avant écrivent toujours leur clé (eef-space-off)', () {
      final run = _runOps(action: 'eef-space-off');
      expect(run.exitCode, 0, reason: run.output);
      expect(
          run.lines('KPB_EEF_SPACE_ENABLED'), ['KPB_EEF_SPACE_ENABLED=false']);
      expect(
        const LineSplitter()
            .convert(run.env)
            .where((l) => !l.startsWith('KPB_EEF_SPACE_ENABLED=')),
        const LineSplitter()
            .convert(_baseEnv)
            .where((l) => !l.startsWith('KPB_EEF_SPACE_ENABLED=')),
      );
      expect(run.envMode, '-rw-------');
    });
  });

  // ── Les règles de refus, prouvées avec le VRAI Docker Compose ─────────────
  //
  // Le faux `docker` rend le `.env` tel quel : il ne dit rien de ce que Compose
  // en fait. Ici le `.env` écrit par l'action est relu par `docker compose
  // config`, et chaque caractère refusé est montré en train d'abîmer le texte.
  group('ce que Docker Compose lit du .env', () {
    final available = _composeAvailable();
    final onCi = Platform.environment['GITHUB_ACTIONS'] == 'true';

    test('docker compose est présent sur la CI (ce groupe ne s\'y saute pas)',
        () {
      if (onCi) {
        expect(available, isTrue,
            reason: 'sans docker compose, les preuves ci-dessous seraient '
                'sautées et passeraient vertes sans rien prouver');
      }
    });

    test('l\'avis posé par l\'action arrive INTACT au conteneur', () {
      final run = _runOps(
        script: _scriptWith(fr: _fr, en: _en, url: _url),
        dryRun: 'false',
      );
      expect(run.exitCode, 0, reason: run.output);
      final read = _composeReads(run.env);
      expect(read, isNotNull, reason: 'Compose ne lit plus le .env écrit');
      expect(read, {
        'KPB_APP_NOTICE_FR': _fr,
        'KPB_APP_NOTICE_EN': _en,
        'KPB_APP_NOTICE_URL': _url,
      });
    }, skip: available ? false : 'docker compose absent de ce poste');

    test('un avis retiré arrive vide', () {
      final run = _runOps(dryRun: 'false');
      expect(_composeReads(run.env), {for (final key in _keys) key: ''});
    }, skip: available ? false : 'docker compose absent de ce poste');

    test('« \$NOM » serait remplacé par une variable du serveur', () {
      final read = _composeReads('KPB_APP_NOTICE_FR=Voir \$PATH ici\n');
      expect(read, isNotNull);
      expect(read!['KPB_APP_NOTICE_FR'], isNot('Voir \$PATH ici'));
    }, skip: available ? false : 'docker compose absent de ce poste');

    test('« # » précédé d\'une espace couperait le texte', () {
      final read =
          _composeReads('KPB_APP_NOTICE_FR=Suis #KPB pour les dates\n');
      expect(read!['KPB_APP_NOTICE_FR'], 'Suis');
    }, skip: available ? false : 'docker compose absent de ce poste');

    for (final quote in ['"', "'"]) {
      test('un texte qui commence par $quote rendrait le .env ILLISIBLE', () {
        final read = _composeReads(
            'KPB_APP_NOTICE_FR=$quoteÉtudes en France$quote ferme le 15\n');
        expect(read, isNull,
            reason: 'Compose lit maintenant ce texte : la règle de refus '
                'n\'a plus de raison d\'être, la relire');
      }, skip: available ? false : 'docker compose absent de ce poste');
    }

    test('des espaces autour seraient retirées', () {
      final read = _composeReads('KPB_APP_NOTICE_FR=  Avis  \n');
      expect(read!['KPB_APP_NOTICE_FR'], 'Avis');
    }, skip: available ? false : 'docker compose absent de ce poste');
  });
}
