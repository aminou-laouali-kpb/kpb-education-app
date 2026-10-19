// Le préflight Android REFUSE une build qui n'est pas celle attendue : il est joué,
// pas seulement lu.
//
// `artifact_signing_contract_test.dart` ne vérifie que la PRÉSENCE de la chaîne
// `EXPECTED_VERSION_CODE="56"` dans le script. Or le piège central de la
// préparation de la 56 est un AAB de la 55 (run 37322572087) ou de la 54 (run
// 36945000021) qui existe déjà : si la ligne de comparaison était neutralisée
// (`grep -Fq "android:versionCode=…"` remplacée par `true`), la constante resterait
// là, tous les tests resteraient verts, et le préflight accepterait la 55.
//
// Ce test exécute VRAIMENT `scripts/preflight-android-aab.sh` sur un AAB fabriqué
// (une archive zip contenant `base/manifest/AndroidManifest.xml`) avec des outils
// Java remplacés par des bouchons : `jarsigner` répond « 0 », `keytool` rend un
// certificat auto-signé généré ici et l'empreinte attendue, `java -jar bundletool`
// imprime le manifeste de la fabrique. Le numéro de version du manifeste est
// volontairement DIFFÉRENT de celui du script (les builds voisines) : il doit être
// refusé, avec le message qui nomme le numéro attendu. Une contre-épreuve avec le
// bon numéro va jusqu'au bout : sans elle, un refus pour une autre raison (un
// bouchon défaillant) passerait pour la preuve.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = 'scripts/preflight-android-aab.sh';
const _fingerprint = 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
    'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';

String _expected(String name) {
  final match = RegExp('^$name="([^"]+)"', multiLine: true)
      .firstMatch(File(_script).readAsStringSync());
  expect(match, isNotNull, reason: '$name introuvable dans $_script');
  return match!.group(1)!;
}

class _Run {
  _Run(this.exitCode, this.output);
  final int exitCode;
  final String output;
}

/// Le manifeste que `bundletool dump manifest` imprimerait.
String _manifest({
  required String versionCode,
  // Par défaut, le nom de version que le script attend (lu dans le script) :
  // seul le numéro de build varie d'un cas à l'autre.
  String? versionName,
  String package = 'com.karatou.android',
  String targetSdk = '36',
}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    android:versionCode="$versionCode"
    android:versionName="${versionName ?? _expected('EXPECTED_VERSION_NAME')}"
    package="$package">
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="$targetSdk" />
  <application>
    <meta-data android:name="google_analytics_adid_collection_enabled" android:value="false" />
    <meta-data android:name="firebase_analytics_collection_enabled" android:value="false" />
    <meta-data android:name="firebase_crashlytics_collection_enabled" android:value="false" />
  </application>
</manifest>
''';

void main() {
  bool has(String tool) {
    try {
      return Process.runSync('which', [tool]).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  final missing = [
    for (final t in ['bash', 'python3', 'openssl', 'unzip'])
      if (!has(t)) t
  ];
  final skip = missing.isEmpty ? null : 'outil absent : ${missing.join(', ')}';

  late Directory sandbox;
  late String javaHome;
  late String aab;
  late String bundletool;
  late String pem;

  void stub(String path, String body) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['+x', path]);
  }

  setUpAll(() {
    if (skip != null) return;
    sandbox = Directory.systemTemp.createTempSync('kpb-preflight-android-');
    // Un certificat auto-signé, valide : `openssl x509 -checkend 0` le lit pour de
    // bon.
    final cert = Process.runSync('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      '${sandbox.path}/key.pem',
      '-out',
      '${sandbox.path}/cert.pem',
      '-days',
      '30',
      '-subj',
      '/CN=Upload KPB',
    ]);
    if (cert.exitCode != 0) {
      throw TestFailure(
          'openssl ne produit pas de certificat : ${cert.stderr}');
    }
    pem = '${sandbox.path}/cert.pem';

    javaHome = '${sandbox.path}/jdk';
    stub('$javaHome/bin/jarsigner', 'exit 0');
    stub(
      '$javaHome/bin/keytool',
      '''case "\$*" in
  *-rfc*) cat "$pem" ;;
  *) printf 'Owner: CN=Upload KPB\\nCertificate fingerprints:\\n\\t SHA256: $_fingerprint\\n' ;;
esac''',
    );
    // `java -jar bundletool dump manifest --bundle=…` : imprime le manifeste que
    // chaque cas dépose dans KPB_TEST_MANIFEST.
    stub('$javaHome/bin/java', 'cat "\$KPB_TEST_MANIFEST"');

    bundletool = '${sandbox.path}/bundletool-all.jar';
    File(bundletool).writeAsStringSync('stub');

    aab = '${sandbox.path}/app-release.aab';
    final zip = Process.runSync('python3', [
      '-c',
      'import zipfile,sys;'
          'z=zipfile.ZipFile(sys.argv[1],"w");'
          'z.writestr("base/manifest/AndroidManifest.xml","stub");'
          'z.close()',
      aab,
    ]);
    if (zip.exitCode != 0) {
      throw TestFailure('python3 ne produit pas l\'AAB : ${zip.stderr}');
    }
  });

  tearDownAll(() {
    if (skip == null && sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  _Run run(String manifest) {
    final file = File('${sandbox.path}/manifest.xml')
      ..writeAsStringSync(manifest);
    final result = Process.runSync(
      'bash',
      [_script, '--aab', aab, '--expected-cert-sha256', _fingerprint],
      environment: {
        'JAVA_HOME': javaHome,
        'BUNDLETOOL_JAR': bundletool,
        'KPB_TEST_MANIFEST': file.path,
      },
      includeParentEnvironment: true,
    );
    return _Run(result.exitCode, '${result.stdout}${result.stderr}');
  }

  int expectedCode() => int.parse(_expected('EXPECTED_VERSION_CODE'));

  group('Préflight Android : la build attendue est jouée', skip: skip, () {
    test('le script épingle la build de pubspec.yaml', () {
      final shipping =
          RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
              .firstMatch(File('pubspec.yaml').readAsStringSync())!;
      expect(_expected('EXPECTED_VERSION_NAME'), shipping.group(1));
      expect(_expected('EXPECTED_VERSION_CODE'), shipping.group(2));
    });

    test('contre-épreuve : le manifeste de la bonne build passe jusqu\'au bout',
        () {
      final result = run(_manifest(versionCode: '${expectedCode()}'));
      expect(result.exitCode, 0, reason: result.output);
      expect(
          result.output,
          contains(
              'Préflight Android OK — ${_expected('EXPECTED_VERSION_NAME')} '
              '(${expectedCode()})'));
    });

    test('un AAB de la build PRÉCÉDENTE (55) ou de la 54 est refusé', () {
      for (final stale in [expectedCode() - 1, expectedCode() - 2]) {
        final result = run(_manifest(versionCode: '$stale'));
        expect(result.exitCode, isNot(0),
            reason: 'le versionCode $stale a passé');
        expect(result.output,
            contains('versionCode différent de ${expectedCode()}'),
            reason: result.output);
        expect(result.output, isNot(contains('Préflight Android OK')));
      }
    });

    test('un AAB d\'une build SUIVANTE est refusé aussi', () {
      final result = run(_manifest(versionCode: '${expectedCode() + 1}'));
      expect(result.exitCode, isNot(0));
      expect(result.output, contains('versionCode différent de'));
    });

    test('un versionName différent est refusé', () {
      final result = run(
          _manifest(versionCode: '${expectedCode()}', versionName: '2.2.0'));
      expect(result.exitCode, isNot(0));
      expect(
          result.output,
          contains(
              'versionName différent de ${_expected('EXPECTED_VERSION_NAME')}'));
    });

    test('un autre applicationId est refusé', () {
      final result = run(_manifest(
          versionCode: '${expectedCode()}', package: 'com.example.autre'));
      expect(result.exitCode, isNot(0));
      expect(result.output, contains('applicationId différent de'));
    });
  });
}
