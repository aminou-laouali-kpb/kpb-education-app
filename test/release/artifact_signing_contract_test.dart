import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Le numéro de build et le nom de version, lus dans `pubspec.yaml`.
///
/// ## Pourquoi les DÉRIVER plutôt que les épingler
///
/// Ces assertions portaient « 51 » en dur, à trois endroits. Le défaut qu'elles
/// doivent attraper n'est pas « le numéro n'est pas 51 » — c'est **un préflight
/// qui attend un autre numéro que celui porté par l'artefact**, exactement ce
/// qui ferait refuser une archive parfaitement bonne, ou pire, laisserait
/// passer la mauvaise. Comparer les préflights à `pubspec.yaml` teste cette
/// propriété-là, à tous les numéros à venir.
///
/// Le cliquet contre la réutilisation d'un numéro déjà consommé n'est pas perdu
/// pour autant : il vit dans `build_number_test.dart`, qui confronte
/// `pubspec.yaml` au registre de release. Les deux tests répondent à deux
/// questions différentes, et aucun ne remplace l'autre.
({String name, String build}) _shippingVersion() {
  final match =
      RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
          .firstMatch(_read('pubspec.yaml'));
  expect(match, isNotNull, reason: 'pubspec.yaml sans version+build.');
  return (name: match!.group(1)!, build: match.group(2)!);
}

String _plistValue(String xml, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<(string|true|false)(?:>(.*?)</string>|/>)',
    dotAll: true,
  ).firstMatch(xml);
  expect(match, isNotNull, reason: 'Clé plist absente : $key');
  final kind = match!.group(1)!;
  return kind == 'string' ? match.group(2)! : kind;
}

Set<String> _privacyDataTypes(String xml) {
  return RegExp(
    r'<key>NSPrivacyCollectedDataType</key>\s*<string>(.*?)</string>',
    dotAll: true,
  ).allMatches(xml).map((match) => match.group(1)!).toSet();
}

void main() {
  group('iOS App Store artifact contract', () {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final debugEntitlements = _read('ios/Runner/Runner.entitlements');
    final releaseEntitlements = _read('ios/Runner/RunnerRelease.entitlements');
    final privacy = _read('ios/Runner/PrivacyInfo.xcprivacy');
    final info = _read('ios/Runner/Info.plist');
    final mainSource = _read('lib/main.dart');
    final analytics = _read('lib/app/core/services/analytics_service.dart');
    final crashlytics =
        _read('lib/app/core/observability/crashlytics_observability.dart');
    final push = _read('lib/app/core/services/push_service.dart');
    final preflight = _read('scripts/preflight-ios-archive.sh');

    test('Release uses production APNs and Debug stays development-only', () {
      expect(
        project,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;'),
      );
      expect(_plistValue(releaseEntitlements, 'aps-environment'), 'production');
      expect(_plistValue(debugEntitlements, 'aps-environment'), 'development');
      expect(
        RegExp(
          r'CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease\.entitlements;.*?name = Release;',
          dotAll: true,
        ).hasMatch(project),
        isTrue,
        reason:
            'The Release configuration must select production entitlements.',
      );
    });

    test('app privacy manifest is bundled and declares no tracking', () {
      expect(_plistValue(privacy, 'NSPrivacyTracking'), 'false');
      expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
      expect(
        RegExp(r'PrivacyInfo\.xcprivacy in Resources', multiLine: true)
            .allMatches(project)
            .length,
        greaterThanOrEqualTo(2),
        reason: 'The file needs both a PBXBuildFile and Resources-phase entry.',
      );

      final types = _privacyDataTypes(privacy);
      expect(
        types,
        containsAll(<String>{
          'NSPrivacyCollectedDataTypeName',
          'NSPrivacyCollectedDataTypeEmailAddress',
          'NSPrivacyCollectedDataTypePhoneNumber',
          'NSPrivacyCollectedDataTypeUserID',
          'NSPrivacyCollectedDataTypeDeviceID',
          'NSPrivacyCollectedDataTypeCustomerSupport',
          'NSPrivacyCollectedDataTypeOtherUserContent',
          'NSPrivacyCollectedDataTypeSearchHistory',
          'NSPrivacyCollectedDataTypeProductInteraction',
          'NSPrivacyCollectedDataTypeCrashData',
        }),
      );
      expect(types, isNot(contains('NSPrivacyCollectedDataTypeLocation')));
    });

    test('location purpose string is declared but never requested', () {
      expect(info, contains('NSLocationWhenInUseUsageDescription'));
      expect(
        _plistValue(info, 'NSLocationWhenInUseUsageDescription').toLowerCase(),
        contains('ne collecte pas votre position'),
      );
    });

    test('the push SDK is FCM, and OneSignal is gone from the app', () {
      expect(push, contains('package:firebase_messaging/'));
      expect(_read('pubspec.yaml'), isNot(contains('onesignal_flutter')));
    });

    test('all analytics collectors start inert until consent is restored', () {
      expect(
          _plistValue(info, 'FIREBASE_ANALYTICS_COLLECTION_ENABLED'), 'false');
      expect(
          _plistValue(info, 'FirebaseCrashlyticsCollectionEnabled'), 'false');
      expect(mainSource, contains('..optOut = true'));
      expect(analytics, contains('setAnalyticsCollectionEnabled(enabled)'));
      expect(
        crashlytics,
        contains('setCrashlyticsCollectionEnabled(enabled)'),
      );
      expect(crashlytics, contains('deleteUnsentReports()'));
    });

    test('strict preflight rejects development or unsigned artifacts', () {
      expect(preflight, contains('codesign --verify --deep --strict'));
      expect(preflight, contains('Apple Distribution|iPhone Distribution'));
      expect(preflight, contains('get-task-allow'));
      expect(preflight, contains('aps-environment'));
      expect(preflight, contains('beta-reports-active'));
      expect(preflight, contains('ProvisionedDevices'));
      expect(
          preflight, contains('PrivacyInfo.xcprivacy absent du bundle signé'));
      final shipping = _shippingVersion();
      expect(preflight, contains('EXPECTED_BUILD="${shipping.build}"'),
          reason: 'le préflight iOS attend un autre build que pubspec.yaml');
      expect(preflight, contains('EXPECTED_VERSION="${shipping.name}"'));
      expect(preflight, contains('EXPECTED_BUNDLE_ID="Karatou.karatou"'));
    });
  });

  group('Android Play artifact contract', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final gradle = _read('android/app/build.gradle');
    final preflight = _read('scripts/preflight-android-aab.sh');

    test('advertising ID is removed and native collection starts disabled', () {
      expect(
          manifest, contains('xmlns:tools="http://schemas.android.com/tools"'));
      expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
      expect(manifest, contains('tools:node="remove"'));
      for (final key in <String>[
        'google_analytics_adid_collection_enabled',
        'firebase_analytics_collection_enabled',
        'firebase_crashlytics_collection_enabled',
      ]) {
        expect(
          RegExp(
            'android:name="${RegExp.escape(key)}"\\s+android:value="false"',
          ).hasMatch(manifest),
          isTrue,
          reason: '$key must be false in the source manifest.',
        );
      }
    });

    test('Gradle rejects placeholders, missing keys, and debug certificates',
        () {
      expect(gradle, contains('still contains placeholders'));
      expect(gradle, contains('androiddebugkey'));
      expect(gradle, contains('cn=androiddebug'));
      expect(gradle, contains('certificate.checkValidity()'));
      expect(gradle, contains('keyStore.isKeyEntry(alias)'));
    });

    test('AAB preflight pins identity, version, SDK, and Play certificate', () {
      expect(preflight, contains('EXPECTED_PACKAGE="com.karatou.android"'));
      final shipping = _shippingVersion();
      expect(preflight, contains('EXPECTED_VERSION_NAME="${shipping.name}"'));
      expect(preflight, contains('EXPECTED_VERSION_CODE="${shipping.build}"'),
          reason:
              'le préflight Android attend un autre build que pubspec.yaml');
      expect(preflight, contains('EXPECTED_TARGET_SDK="36"'));
      expect(preflight, contains('"\$JARSIGNER_BIN" -verify'));
      expect(preflight, contains('"\$KEYTOOL_BIN" -printcert -jarfile'));
      expect(preflight, contains('bundletool'));
      expect(preflight, contains('dump manifest --bundle'));
      expect(preflight, contains('bundletool-all'));
      expect(preflight, contains('com.google.android.gms.permission.AD_ID'));
      expect(preflight, contains('base/manifest/AndroidManifest.xml'));
    });
  });

  // Le NOM de version est épinglé, et il n'a bougé qu'une fois, exprès.
  //
  // Les 48 à 52 portaient toutes « 2.1.0 » : ce sont des builds successifs de
  // la même version publiée. Le faire dériver par inadvertance créerait une
  // entrée distincte sur les stores, d'où ce cliquet.
  //
  // Passé à 2.3.0 pour la build 54, délibérément : la 2.2.0 est en vente sur
  // l'App Store depuis le 13/09/2026, et App Store Connect refuse le
  // téléversement d'une build dont la version marketing n'est pas supérieure à
  // la dernière approuvée (ITMS-90062). La 54 n'a jamais été envoyée aux
  // boutiques (constat du 03/10/2026) ; la 55 la remplace et garde ce nom.
  //
  // Passé à 2.2.0 le 03/09/2026, délibérément : `AppVersionGate` compare la
  // version MARKETING au `minVersion` du serveur et `isVersionBelow` ignore le
  // numéro de build (il coupe au `+`). Tant que toutes les builds s'appelaient
  // « 2.1.0 », aucune valeur de `KPB_MIN_APP_VERSION` ne pouvait en distinguer
  // une seule — la porte de mise à jour ne servait à rien.
  //
  // Le NUMÉRO de build, lui, n'est pas épinglé ici : `build_number_test.dart`
  // le confronte au registre de release, qui en est la source.
  test('the shipping marketing version stays 2.3.0', () {
    expect(_shippingVersion().name, '2.3.0');
  });

  // Revue du build 49 : la mesure d'audience est passée d'OPT-IN à ACTIVE PAR
  // DÉFAUT, annoncée dans les CGU. Ce test tenait l'ancienne règle ; il tient
  // maintenant la nouvelle ET la limite qui, elle, n'a pas bougé : un refus
  // explicite reste un refus. C'est la seule moitié qui protège quelqu'un.
  test('analytics is on by default but an explicit refusal is preserved', () {
    final snapshot = _read('lib/app/core/repositories/app_snapshot.dart');
    final repository =
        _read('lib/app/core/repositories/local_app_repository.dart');
    // `hydrate()` (session) et `setAnalyticsAllowed()` (préférences).
    final controller =
        _read('lib/app/core/controllers/app_controller/session.dart') +
            _read('lib/app/core/controllers/app_controller/preferences.dart');

    // Le marqueur « a-t-il tranché ? » reste distinct de « qu'a-t-il dit ? ».
    // C'est lui qui rend le refus explicite reconnaissable, donc préservable.
    expect(snapshot, contains('this.analyticsConsentDecided = false'));
    expect(
      repository,
      contains("json['analyticsConsentDecided'] as bool? ?? false"),
    );
    // Espaces NORMALISÉS avant de chercher. `dart format` a le droit de couper
    // cette affectation en deux lignes selon sa longueur — et il l'a fait dès
    // que le commentaire au-dessus a changé. Un `contains` sur le littéral
    // exact rougissait donc sur une mise en forme, pas sur une régression :
    // un test qui crie pour la mauvaise raison finit désactivé, et c'est ainsi
    // qu'une vraie garde se perd.
    final flat = controller.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      flat,
      contains(
        'analyticsOptOut = analyticsConsentDecided ? snapshot.analyticsOptOut : false;',
      ),
    );
    expect(flat, contains('analyticsConsentDecided = true;'));
  });
}
