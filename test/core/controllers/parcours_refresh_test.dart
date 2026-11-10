// La liste des parcours doit se rafraîchir toute seule (audit avant la 59).
//
// ## Le défaut
//
// `fetchParcoursStories` relisait le cache, puis sortait sans appeler le
// serveur dès que la liste n'était plus vide. Une fois la liste gardée sur le
// téléphone, elle n'était donc PLUS JAMAIS redemandée, sauf par un élève qui
// tire l'écran. Une histoire retirée, un identifiant de vidéo corrigé ou un
// nouveau récit n'arrivaient pas — pendant toute la vie de la build.
//
// ## La règle
//
// Une liste relue du cache est redemandée une fois par session si le cache a
// plus d'un jour (ou pas de date : il a été écrit par une build d'avant).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';

import '../../widget_test_helpers.dart';

ParcoursStory _story(String id) => ParcoursStory(
      id: id,
      slug: id,
      kind: ParcoursKind.text,
      title: LocalizedText(fr: 'Histoire $id', en: 'Story $id'),
    );

class _Api extends MockApiClient {
  int calls = 0;
  bool fail = false;
  List<ParcoursStory> served = <ParcoursStory>[_story('neuve')];

  @override
  Future<List<ParcoursStory>> listParcoursStories() async {
    calls++;
    if (fail) throw StateError('hors réseau');
    return served;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    final dir = await Directory.systemTemp.createTemp('hive_parcours');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  setUp(() async {
    resetGetxSingleton();
    setupPlatformChannelMocks();
    CatalogCacheService.resetForTests();
    await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
    await CatalogCacheService.init();
  });

  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  /// Un lancement de l'app : un contrôleur neuf sur le même cache.
  Future<AppController> launch(_Api api) async {
    AppConfig.enableRemoteSyncOverride = false;
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      ),
      apiClient: api,
    );
    await controller.hydrate();
    AppConfig.enableRemoteSyncOverride = true;
    return controller;
  }

  Future<void> seedLegacyCache() => CatalogCacheService.instance.write(
        'parcours_stories',
        <dynamic>[_story('ancienne').toJson()],
      );

  test(
      'un cache écrit par une build d\'avant est redemandé au serveur, '
      'sans que l\'élève tire l\'écran', () async {
    await seedLegacyCache();
    final api = _Api();
    final controller = await launch(api);

    final asked = await controller.fetchParcoursStories();

    expect(asked, isTrue);
    expect(api.calls, 1);
    expect(controller.parcoursStories.map((s) => s.id), ['neuve']);
  });

  test('une fois par session : le second écran ne redemande pas', () async {
    await seedLegacyCache();
    final api = _Api();
    final controller = await launch(api);

    await controller.fetchParcoursStories();
    await controller.fetchParcoursStories();
    await controller.fetchParcoursStories();

    expect(api.calls, 1);
  });

  test('au lancement suivant, un cache de moins d\'un jour suffit', () async {
    await seedLegacyCache();
    final first = _Api();
    await (await launch(first)).fetchParcoursStories();
    expect(first.calls, 1);

    resetGetxSingleton();
    final second = _Api();
    final controller = await launch(second);
    final asked = await controller.fetchParcoursStories();

    expect(asked, isFalse);
    expect(second.calls, 0);
    expect(controller.parcoursStories.map((s) => s.id), ['neuve']);
  });

  test('si le serveur ne répond pas, la liste gardée reste affichée', () async {
    await seedLegacyCache();
    final api = _Api()..fail = true;
    final controller = await launch(api);

    await controller.fetchParcoursStories();
    await controller.fetchParcoursStories();

    expect(controller.parcoursStories.map((s) => s.id), ['ancienne']);
    expect(controller.parcoursError, isNull);
    // Un échec compte comme une tentative : pas de relance à chaque écran.
    expect(api.calls, 1);
  });

  test('tirer l\'écran redemande toujours', () async {
    await seedLegacyCache();
    final api = _Api();
    final controller = await launch(api);

    await controller.fetchParcoursStories();
    await controller.fetchParcoursStories(force: true);

    expect(api.calls, 2);
  });
}
