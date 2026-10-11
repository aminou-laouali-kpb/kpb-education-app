// Un instantané local illisible ne doit plus bloquer le démarrage à chaque
// lancement : l'app repart d'un état vierge et garde une copie pour diagnostic.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/repositories/local_app_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a corrupt snapshot falls back to the initial state and is set aside',
      () async {
    final key = '${AppConfig.storageNamespace}.snapshot';
    SharedPreferences.setMockInitialValues({key: '{"localeCode": "fr", trunc'});
    final repository = await LocalAppRepository.create();

    final snapshot = await repository.loadSnapshot();

    expect(snapshot.hasCompletedOnboarding, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), isNull);
    expect(prefs.getString('$key.corrupt'), '{"localeCode": "fr", trunc');
  });

  test('a field of an unexpected type does not crash either', () async {
    final key = '${AppConfig.storageNamespace}.snapshot';
    SharedPreferences.setMockInitialValues(
        {key: '{"localeCode": 42, "hasCompletedOnboarding": "yes"}'});
    final repository = await LocalAppRepository.create();
    final snapshot = await repository.loadSnapshot();
    expect(snapshot.hasCompletedOnboarding, isFalse);
  });
}
