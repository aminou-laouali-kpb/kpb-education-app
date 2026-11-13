// Rotation des journaux Docker (audit avant la 59).
//
// `docker-compose.yml` n'avait aucun bloc `logging` : Docker garde alors le
// journal de chaque conteneur dans un fichier unique qui grossit sans limite,
// sur le disque qui porte aussi la base de données et les pièces des élèves.
// Un disque plein arrête Postgres ; personne ne le voit venir.
//
// Deux lectures, parce qu'une seule ne suffit pas :
//   • le TEXTE du fichier : chaque service déclare sa rotation. Un service
//     ajouté plus tard sans elle fait rougir ce test ;
//   • la configuration RÉSOLUE par le vrai `docker compose config` : c'est ce
//     que Docker appliquera. Une ancre YAML mal écrite se lit très bien dans le
//     texte et ne pose aucune limite.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _composePath = 'docker-compose.yml';

/// Les blocs de service du fichier : nom → texte du bloc.
Map<String, String> _serviceBlocks(String compose) {
  final lines = const LineSplitter().convert(compose);
  final start = lines.indexOf('services:');
  // Appelée au chargement du fichier, hors de tout test : pas d'`expect` ici.
  if (start < 0) throw StateError('pas de bloc `services:` dans $_composePath');
  final blocks = <String, StringBuffer>{};
  String? current;
  for (final line in lines.skip(start + 1)) {
    // Une clé de premier niveau (networks:, volumes:) ferme les services.
    if (RegExp(r'^[A-Za-z]').hasMatch(line)) break;
    final name = RegExp(r'^  ([a-z0-9][a-z0-9_-]*):\s*$').firstMatch(line);
    if (name != null) {
      current = name.group(1)!;
      blocks[current] = StringBuffer();
      continue;
    }
    if (current != null) blocks[current]!.writeln(line);
  }
  return blocks.map((name, text) => MapEntry(name, text.toString()));
}

/// Taille en octets d'une valeur Docker (`10m`, `500k`, `1g`).
int _bytes(String size) {
  final match = RegExp(r'^(\d+)([kmg])$').firstMatch(size.toLowerCase());
  expect(match, isNotNull, reason: 'taille illisible : $size');
  const unit = {'k': 1024, 'm': 1024 * 1024, 'g': 1024 * 1024 * 1024};
  return int.parse(match!.group(1)!) * unit[match.group(2)!]!;
}

bool _composeAvailable() {
  try {
    return Process.runSync('docker', ['compose', 'version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  final compose = File(_composePath).readAsStringSync();
  final services = _serviceBlocks(compose);

  group('chaque service fait tourner ses journaux', () {
    test('le fichier décrit bien les six services de production', () {
      expect(
        services.keys,
        containsAll(['api', 'admin', 'web', 'db', 'db-backup', 'clamav']),
      );
    });

    test('aucun service sans bloc `logging`', () {
      final without = services.entries
          .where((entry) =>
              !RegExp(r'^    logging:', multiLine: true).hasMatch(entry.value))
          .map((entry) => entry.key)
          .toList();
      expect(without, isEmpty,
          reason: 'services sans rotation des journaux : $without — leur '
              'journal grossirait sans limite sur le disque de la base');
    });

    test('la rotation est `json-file`, bornée en taille et en nombre', () {
      final anchor = RegExp(
        r'^x-logging: &default-logging\n((?:  .*\n)+)',
        multiLine: true,
      ).firstMatch(compose);
      expect(anchor, isNotNull, reason: 'ancre `x-logging` introuvable');
      final body = anchor!.group(1)!;
      expect(body, contains('driver: json-file'));
      final size = RegExp(r'max-size: "([^"]+)"').firstMatch(body)?.group(1);
      final files = RegExp(r'max-file: "(\d+)"').firstMatch(body)?.group(1);
      expect(size, isNotNull, reason: 'max-size absent : aucune limite');
      expect(files, isNotNull,
          reason: 'max-file absent : un seul fichier, '
              'qui serait vidé d\'un coup au lieu de tourner');
      // Assez pour relire un incident, assez peu pour ne jamais peser : six
      // services ne doivent pas pouvoir écrire plus de 3 Go de journaux.
      expect(_bytes(size!), inInclusiveRange(1024 * 1024, 100 * 1024 * 1024));
      expect(int.parse(files!), inInclusiveRange(2, 10));
      expect(
        _bytes(size) * int.parse(files) * services.length,
        lessThanOrEqualTo(3 * 1024 * 1024 * 1024),
      );
    });

    test('chaque service prend CETTE rotation, pas une variante', () {
      for (final entry in services.entries) {
        expect(entry.value, contains('    logging: *default-logging\n'),
            reason: '${entry.key} ne référence pas l\'ancre commune');
      }
    });
  });

  group('ce que Docker Compose appliquera', () {
    final available = _composeAvailable();
    final onCi = Platform.environment['GITHUB_ACTIONS'] == 'true';

    test('docker compose est présent sur la CI (ce groupe ne s\'y saute pas)',
        () {
      if (onCi) {
        expect(available, isTrue,
            reason: 'sans docker compose, la preuve ci-dessous serait sautée '
                'et passerait verte sans rien prouver');
      }
    });

    test('la configuration résolue pose la limite sur chaque service', () {
      // Les variables que le fichier EXIGE (`${NOM:?…}`) reçoivent une valeur
      // de test : on lit la forme du fichier, pas une configuration réelle.
      final required = RegExp(r'\$\{([A-Z0-9_]+):\?')
          .allMatches(compose)
          .map((m) => m.group(1)!)
          .toSet();
      final result = Process.runSync(
        'docker',
        [
          'compose',
          '--env-file',
          '.env.example',
          '-f',
          _composePath,
          'config',
          '--format',
          'json',
        ],
        environment: {for (final name in required) name: 'valeur-de-test'},
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final resolved = (jsonDecode(result.stdout as String)
          as Map<String, dynamic>)['services'] as Map<String, dynamic>;
      expect(resolved.keys.toSet(), services.keys.toSet());
      for (final entry in resolved.entries) {
        final logging =
            (entry.value as Map<String, dynamic>)['logging'] as Map?;
        expect(logging, isNotNull,
            reason: '${entry.key} : aucun `logging` dans la configuration '
                'résolue');
        expect(logging!['driver'], 'json-file', reason: entry.key);
        final options = logging['options'] as Map?;
        expect(options?['max-size'], isNotNull, reason: entry.key);
        expect(options?['max-file'], isNotNull, reason: entry.key);
      }
    }, skip: available ? false : 'docker compose absent de ce poste');
  });
}
