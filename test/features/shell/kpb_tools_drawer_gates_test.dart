// Tiroir « Outils KPB » : pas de porte vers une impasse (audit build 57, T5-15,
// T6-09 et T6-10). Le tableau d'impact n'apparaît que si le serveur ouvre les
// statistiques publiques ; le Logement (V1.1+) suit `mvpOnly`, comme le Profil.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/shell/kpb_tools_drawer.dart';

Set<String> _labels() =>
    KpbToolsDrawer.toolsForTest.map((tool) => tool.labelKey).toSet();

void main() {
  setUp(RemoteFeatureFlags.resetForTest);
  tearDown(RemoteFeatureFlags.resetForTest);

  test('tableau d\'impact : absent tant que les statistiques sont fermées', () {
    // Tiroir : la liste n'est pas vide, sinon « absent » ne prouverait rien.
    expect(_labels(), contains('tools_budget'));
    expect(_labels(), isNot(contains('tools_impact')));
  });

  test('tableau d\'impact : présent quand le serveur ouvre les statistiques',
      () {
    RemoteFeatureFlags.instance
        .debugSetFeaturesForTest(const {'publicImpactStats': true});
    expect(_labels(), contains('tools_impact'));
  });

  test('logement : suit mvpOnly, comme le Profil', () {
    expect(_labels().contains('tools_housing'), !AppConfig.mvpOnly);
  });
}
