import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/repositories/app_repository.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';
import 'package:karatou/app/core/services/catalog_remote_sync.dart';

// The three situations the UI must tell apart, from the consumer side: the app
// on its bundled fake seed, the app on real-but-dated rows, and the app on live
// rows. Before this, all three collapsed into one boolean.

class _FakeRepository implements AppRepository {
  AppSnapshot _snapshot = AppSnapshot.initial();

  @override
  Future<AppSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = AppSnapshot.initial();
  }
}

class _MockApiClient extends Mock implements AppApiClient {}

const _catalogResources = <String>[
  'fields',
  'countries',
  'institutions',
  'programs',
  'scholarships',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    final tempDir = await Directory.systemTemp.createTemp('hive_catalog_state');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  // ── The aggregation rule ────────────────────────────────────────────────

  group('aggregateCatalogDataState — the worst situation wins', () {
    test('every resource live → live', () {
      expect(
        aggregateCatalogDataState(const [
          CatalogSyncOutcome.live,
          CatalogSyncOutcome.live,
        ]),
        CatalogDataState.live,
      );
    });

    test('an authoritative empty catalog is live data, not a degradation', () {
      expect(
        aggregateCatalogDataState(const [
          CatalogSyncOutcome.live,
          CatalogSyncOutcome.empty,
        ]),
        CatalogDataState.live,
        reason: '"the server has zero rows" is a fact about the catalog; the '
            'lists were emptied to match it, so nothing is stale or fake',
      );
    });

    test('one resource replayed from cache downgrades the whole state', () {
      expect(
        aggregateCatalogDataState(const [
          CatalogSyncOutcome.live,
          CatalogSyncOutcome.live,
          CatalogSyncOutcome.offlineCache,
          CatalogSyncOutcome.empty,
        ]),
        CatalogDataState.offline,
        reason: 'claiming "live" would cover dated rows one tap away',
      );
    });

    test('order does not matter — the fold is commutative', () {
      const worst = CatalogDataState.offline;
      expect(
        aggregateCatalogDataState(const [
          CatalogSyncOutcome.offlineCache,
          CatalogSyncOutcome.live,
        ]),
        worst,
      );
      expect(
        aggregateCatalogDataState(const [
          CatalogSyncOutcome.live,
          CatalogSyncOutcome.offlineCache,
        ]),
        worst,
      );
    });

    test('nothing resolved at all → sample (the bundled seed is what shows)',
        () {
      expect(
        aggregateCatalogDataState(const <CatalogSyncOutcome>[]),
        CatalogDataState.sample,
      );
    });
  });

  // ── offline → live without a restart ───────────────────────────────────

  group('AppController.catalogDataState across syncs', () {
    late _FakeRepository repository;
    late _MockApiClient api;
    late AppController controller;

    setUp(() async {
      Get.testMode = true;
      AppConfig.enableRemoteSyncOverride = true;
      CatalogCacheService.resetForTests();
      await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
      await CatalogCacheService.init();

      repository = _FakeRepository();
      api = _MockApiClient();
      when(() => api.hasAuthSession()).thenAnswer((_) async => false);
      // `/content/*` is out of the aggregation on purpose; keep it quiet.
      when(() => api.listContent(any())).thenAnswer((_) async => <dynamic>[]);

      controller = AppController(repository: repository, apiClient: api);
    });

    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      Get.testMode = false;
    });

    test('starts on sample: the lists are the bundled seed until a sync lands',
        () {
      expect(controller.catalogDataState, CatalogDataState.sample);
      expect(controller.catalogIsSampleData, isTrue);
      expect(controller.catalogSnapshotAt, isNull);
    });

    test(
        'service down with a real snapshot → offline, then live once the '
        'service answers again — no restart involved', () async {
      // A previous run left a real (here: authoritatively empty) snapshot.
      for (final resource in _catalogResources) {
        await CatalogCacheService.instance.write(resource, const <dynamic>[]);
      }
      when(() => api.listCatalogEnvelope(any()))
          .thenThrow(StateError('503 CATALOG_UNAVAILABLE'));

      await controller.syncRemoteData(force: true);

      expect(controller.catalogDataState, CatalogDataState.offline,
          reason: 'the rows on screen are real, just dated — never "sample"');
      expect(controller.catalogIsSampleData, isFalse,
          reason: 'the historical boolean must not claim fake data here');
      expect(controller.catalogSnapshotAt, isNotNull,
          reason: 'the banner needs the snapshot age, and the cache has it');

      // Network/service comes back on the next sync.
      when(() => api.listCatalogEnvelope('fields')).thenAnswer(
        (_) async => const CatalogListPayload(
          items: [
            {'id': 'd01'}
          ],
          source: CatalogDataSource.database,
        ),
      );
      when(() => api.listCatalogEnvelope(any(that: isNot('fields'))))
          .thenAnswer(
        (_) async => const CatalogListPayload(
          items: [],
          source: CatalogDataSource.database,
        ),
      );

      await controller.syncRemoteData(force: true);

      expect(controller.catalogDataState, CatalogDataState.live,
          reason: 'a later successful sync must clear the banner state');
      expect(controller.catalogSnapshotAt, isNull,
          reason: 'no stale age to show once the data is live');
      expect(controller.fields.map((f) => f.id), ['d01']);
    });

    test('service down with no snapshot → sample (fake bundled rows on screen)',
        () async {
      when(() => api.listCatalogEnvelope(any()))
          .thenThrow(StateError('503 CATALOG_UNAVAILABLE'));

      await controller.syncRemoteData(force: true);

      expect(controller.catalogDataState, CatalogDataState.sample);
      expect(controller.catalogSnapshotAt, isNull);
    });

    test(
        'a sync that dies after real rows loaded degrades to offline, not '
        'sample', () async {
      when(() => api.listCatalogEnvelope(any())).thenAnswer(
        (_) async => const CatalogListPayload(
          items: [],
          source: CatalogDataSource.database,
        ),
      );
      await controller.syncRemoteData(force: true);
      expect(controller.catalogDataState, CatalogDataState.live);

      // Now the service dies AND the snapshot is gone (cache wiped) — the sync
      // throws out of the catalog block entirely.
      await CatalogCacheService.instance.clear();
      when(() => api.listCatalogEnvelope(any()))
          .thenThrow(StateError('503 CATALOG_UNAVAILABLE'));

      await controller.syncRemoteData(force: true);

      expect(controller.catalogDataState, CatalogDataState.offline,
          reason: 'real rows are still in memory from the previous sync; '
              'calling them "sample data" would be a lie');
    });
  });

  // Audit build 57, n° 2 : « Données d'exemple — connexion au serveur
  // impossible » s'affichait à chaque lancement, cache réel ou pas, tant que la
  // 1re synchro n'était pas finie — alors que le serveur répondait.
  group('lancement : aucun faux bandeau avant la fin de la 1re synchro', () {
    late _MockApiClient api;
    late AppController controller;
    late Completer<CatalogListPayload> pendingCatalog;

    setUp(() async {
      Get.testMode = true;
      AppConfig.enableRemoteSyncOverride = true;
      CatalogCacheService.resetForTests();
      await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
      await CatalogCacheService.init();
      api = _MockApiClient();
      when(() => api.hasAuthSession()).thenAnswer((_) async => false);
      when(() => api.listContent(any())).thenAnswer((_) async => <dynamic>[]);
      // La synchro reste en cours : c'est la fenêtre des 4 à 58 s mesurées.
      pendingCatalog = Completer<CatalogListPayload>();
      when(() => api.listCatalogEnvelope(any()))
          .thenAnswer((_) => pendingCatalog.future);
      controller = AppController(repository: _FakeRepository(), apiClient: api);
    });

    tearDown(() {
      if (!pendingCatalog.isCompleted) {
        pendingCatalog.complete(const CatalogListPayload(
          items: [],
          source: CatalogDataSource.database,
        ));
      }
      AppConfig.enableRemoteSyncOverride = null;
      Get.testMode = false;
    });

    test('élève qui revient : le cache réel n\'est pas « données d\'exemple »',
        () async {
      final cache = CatalogCacheService.instance;
      await cache.write(
          'fields', MockCatalog.fields.map((e) => e.toJson()).toList());
      await cache.write(
          'countries', MockCatalog.countries.map((e) => e.toJson()).toList());
      await cache.write('institutions',
          MockCatalog.institutions.map((e) => e.toJson()).toList());
      await cache.write(
          'programs', MockCatalog.programs.map((e) => e.toJson()).toList());
      await cache.write('scholarships',
          MockCatalog.scholarships.map((e) => e.toJson()).toList());

      await controller.hydrate();

      expect(controller.catalogFirstSyncSettled, isFalse);
      expect(controller.catalogIsSampleData, isFalse,
          reason: 'les lignes à l\'écran sont celles du dernier chargement');
      expect(controller.catalogDataState, CatalogDataState.offline);
    });

    test('installation neuve : synchro en cours, rien n\'est encore conclu',
        () async {
      await controller.hydrate();

      expect(controller.catalogIsSampleData, isTrue);
      expect(controller.catalogFirstSyncSettled, isFalse,
          reason: 'la coquille ne montre aucun bandeau tant que c\'est faux');
    });

    test('installation neuve, serveur qui répond : live, synchro conclue',
        () async {
      when(() => api.listCatalogEnvelope(any())).thenAnswer(
        (_) async => const CatalogListPayload(
          items: [],
          source: CatalogDataSource.database,
        ),
      );
      await controller.syncRemoteData(force: true);

      expect(controller.catalogFirstSyncSettled, isTrue);
      expect(controller.catalogDataState, CatalogDataState.live);
    });

    test('installation neuve, serveur en panne : échantillon, synchro conclue',
        () async {
      when(() => api.listCatalogEnvelope(any()))
          .thenThrow(StateError('503 CATALOG_UNAVAILABLE'));
      await controller.syncRemoteData(force: true);

      expect(controller.catalogFirstSyncSettled, isTrue);
      expect(controller.catalogIsSampleData, isTrue,
          reason: 'seul cas où « connexion impossible » est vrai');
    });
  });
}
