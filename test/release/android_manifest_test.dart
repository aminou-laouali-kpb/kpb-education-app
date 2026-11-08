// Le manifeste Android dit ce que l'APK demande — et ce que la Play Console
// lira. Deux points sont gardés ici parce qu'ils se paient en refus de mise à
// jour sur une app DÉJÀ publiée : l'identifiant publicitaire (questionnaire
// « advertising ID » / Data Safety) et `QUERY_ALL_PACKAGES`.
//
// POURQUOI TOUT PASSE PAR `_withoutComments`. Le manifeste explique en prose ce
// qu'il refuse : il contient littéralement la phrase « INTERDIT ICI :
// QUERY_ALL_PACKAGES » et cite le nom de la méta-donnée d'opt-out dans ses
// commentaires. Une assertion sur le texte brut serait donc satisfaite par ces
// phrases seules : on pourrait supprimer la déclaration protégée et garder le
// test vert. Sur ce dépôt, trois fois, le défaut a été caché par l'outil censé
// le détecter — d'où cette précaution, et non un `contains` direct.
//
// Pas de build Gradle ici (il échoue sans android/key.properties) : ce test
// affirme le manifeste SOURCE. La suppression, elle, agit sur le manifeste
// FUSIONNÉ — c'est justement pourquoi la ligne à garder est une instruction du
// fusionneur et non une permission.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';

/// La chaîne exacte lue par play-services-measurement-impl
/// (`com.google.android.gms.measurement.internal.zzal`, via
/// `ApplicationInfo.metaData.getBoolean`). Une variante mal orthographiée est
/// ignorée par le SDK sans erreur : c'est l'orthographe elle-même qu'on garde.
const _adIdOptOutKey = 'google_analytics_adid_collection_enabled';

const _adIdPermission = 'com.google.android.gms.permission.AD_ID';

String _withoutComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// Les balises ouvrantes `<tag …>` (auto-fermantes incluses) du corps donné.
List<String> _openingTags(String body, String tag) =>
    RegExp('<$tag\\b[^>]*>').allMatches(body).map((m) => m.group(0)!).toList();

/// Le bloc `<application>` privé de ses `<activity>` : les activités portent
/// leurs propres `<meta-data>`, et une méta-donnée de configuration du SDK
/// posée dans une activité serait ignorée. Les retirer permet d'affirmer le
/// NIVEAU de la déclaration, pas seulement sa présence.
String _applicationBody(String body) {
  final application =
      RegExp(r'<application\b.*?</application>', dotAll: true).firstMatch(body);
  expect(application, isNotNull, reason: '<application> introuvable');
  return application!
      .group(0)!
      .replaceAll(RegExp(r'<activity\b.*?</activity>', dotAll: true), '');
}

void main() {
  final raw = File(_manifestPath).readAsStringSync();
  final body = _withoutComments(raw);

  test("l'espace de noms tools est déclaré sur <manifest>", () {
    // Sans cette déclaration, `tools:node` n'est pas lié : le XML n'est plus
    // bien formé et la suppression ne s'applique jamais.
    final manifestTag = _openingTags(body, 'manifest').single;
    expect(
      manifestTag,
      contains('xmlns:tools="http://schemas.android.com/tools"'),
      reason: 'URI exacte requise : tout autre préfixe/URI ne pilote pas le '
          'fusionneur de manifestes.',
    );
  });

  test('AD_ID est retiré du manifeste fusionné, et jamais demandé', () {
    final declarations = _openingTags(body, 'uses-permission')
        .where((tag) => tag.contains(_adIdPermission))
        .toList();

    expect(
      declarations,
      hasLength(1),
      reason: "firebase_analytics fait entrer $_adIdPermission dans le "
          'manifeste fusionné (play-services-measurement-api / -impl). Sans '
          'cette ligne, la Play Console impose de déclarer un identifiant '
          "publicitaire que l'app n'utilise pas.",
    );
    expect(
      declarations.single,
      contains('tools:node="remove"'),
      reason: "Déclarer AD_ID sans le retirer, c'est le demander : la ligne "
          'doit être une suppression du fusionneur, pas une permission.',
    );
  });

  test("la méta-donnée d'opt-out du SDK de mesure est posée à false", () {
    final metaData = _openingTags(_applicationBody(body), 'meta-data');

    final optOut = metaData
        .where((tag) => tag.contains('android:name="$_adIdOptOutKey"'))
        .toList();
    expect(
      optOut,
      hasLength(1),
      reason: 'Attendue au niveau <application> et orthographiée exactement '
          '« $_adIdOptOutKey » — le SDK ignore silencieusement toute autre '
          'clé.',
    );
    expect(
      optOut.single,
      contains('android:value="false"'),
      reason: 'Le SDK lit un booléen : `false` littéral, pas "0" ni une autre '
          'valeur.',
    );

    // Une clé voisine mal orthographiée (ad_id, adId…) ajoutée « en plus »
    // donnerait l'illusion d'un second verrou tout en étant inerte.
    final lookalikes = metaData.where((tag) {
      final name = RegExp(r'android:name="([^"]*)"').firstMatch(tag)?.group(1);
      if (name == null || name == _adIdOptOutKey) return false;
      return RegExp('ad_?id', caseSensitive: false).hasMatch(name);
    });
    expect(
      lookalikes,
      isEmpty,
      reason: 'Méta-donnée « identifiant publicitaire » mal orthographiée : '
          'inerte, mais rassurante à la lecture.',
    );
  });

  test("QUERY_ALL_PACKAGES n'apparaît nulle part", () {
    // Motif de refus de politique Play, et sur une app déjà publiée le refus
    // porterait sur la mise à jour elle-même.
    expect(
      RegExp('QUERY_ALL_PACKAGES', caseSensitive: false).hasMatch(body),
      isFalse,
      reason: 'La visibilité des paquets passe par le bloc <queries> étroit '
          'déjà présent.',
    );
  });

  test('le service de reconnaissance vocale est visible (dictée Android)', () {
    // Revue avant la 58, constat 40 : sans cette intention dans <queries>,
    // speech_to_text ne voit aucun RecognitionService sur Android 11+ et le
    // micro du tunnel de dossier répond toujours « dictée indisponible ».
    // Lu hors commentaires : la phrase qui l'explique ne suffit pas.
    final queries =
        RegExp(r'<queries\b.*?</queries>', dotAll: true).firstMatch(body);
    expect(queries, isNotNull, reason: '<queries> introuvable');
    expect(
      RegExp(
        r'<intent>\s*<action\s+android:name="android\.speech\.RecognitionService"\s*/>\s*</intent>',
      ).hasMatch(queries!.group(0)!),
      isTrue,
    );
  });
}
