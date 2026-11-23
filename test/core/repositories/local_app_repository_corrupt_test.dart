// Un instantané local illisible ne doit plus bloquer le démarrage à chaque
// lancement : l'app repart d'un état vierge et garde une copie pour diagnostic.
// Cette copie (profil, dossiers en clair) part avec la déconnexion et la
// suppression du compte (audit du 22/11/2026, n° 34).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/repositories/local_app_repository.dart';

class _MockApiClient extends Mock implements AppApiClient {}

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

  test('clear() efface aussi la copie mise de côté (suppression du compte)',
      () async {
    final key = '${AppConfig.storageNamespace}.snapshot';
    SharedPreferences.setMockInitialValues({key: '{"localeCode": "fr", trunc'});
    final repository = await LocalAppRepository.create();
    await repository.loadSnapshot();

    await repository.clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), isNull);
    expect(prefs.getString('$key.corrupt'), isNull);
  });

  test('la déconnexion efface la copie et réécrit l\'état anonyme', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    Get.testMode = true;
    addTearDown(Get.reset);
    final key = '${AppConfig.storageNamespace}.snapshot';
    SharedPreferences.setMockInitialValues({key: '{"localeCode": "fr", trunc'});
    final repository = await LocalAppRepository.create();
    final apiClient = _MockApiClient();
    when(() => apiClient.hasAuthSession()).thenAnswer((_) async => false);
    final controller = AppController(
      repository: repository,
      apiClient: apiClient,
    );
    await controller.hydrate();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('$key.corrupt'), isNotNull);

    await controller.logout();

    expect(prefs.getString('$key.corrupt'), isNull);
    // L'état anonyme est bien réécrit après l'effacement, pas effacé par lui.
    expect(prefs.getString(key), isNotNull);
  });
}
