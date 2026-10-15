// Le magasin du test : l'état une fois par passage au premier plan, le dernier
// run en cache LISIBLE HORS LIGNE et daté, le brouillon par compte, et le
// drapeau qui cache tout.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/services/scholarship_match_store.dart';

import 'match_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryScholarshipMatchCache cache;
  final store = ScholarshipMatchStore.instance;

  setUp(() => cache = resetMatchWorld());
  tearDown(tearDownMatchWorld);

  Future<void> load(FakeMatchApi api,
          {String user = 'u1', bool force = false}) =>
      store.loadState(client: api, userId: user, lang: 'fr', force: force);

  test('GET state une seule fois par passage au premier plan', () async {
    final api = FakeMatchApi();
    await load(api);
    await load(api);
    expect(api.stateCalls, 1);
    await load(api, force: true);
    expect(api.stateCalls, 2);
  });

  test('le dernier run servi est gardé en cache, daté, et relu hors ligne',
      () async {
    final syncedAt = DateTime.utc(2026, 10, 12, 9);
    store.debugNow = () => syncedAt;
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()));
    await load(api);
    expect(store.latestRun!.id, 'run-1');
    await Future<void>.delayed(Duration.zero);
    expect(cache.entries.keys, contains('user:u1:run'));

    // Redémarrage : mémoire vidée, réseau coupé.
    store.debugReset(cache: cache);
    final offline = FakeMatchApi()
      ..stateError = const ScholarshipMatchException(
        ScholarshipMatchFailure.offline,
      );
    await load(offline);
    expect(store.latestRun!.id, 'run-1');
    expect(store.latestRunSyncedAt, syncedAt);
    expect(store.offline, isTrue);
    expect(store.failure, ScholarshipMatchFailure.offline);
  });

  test('le cache appartient au compte : un autre élève ne le voit pas',
      () async {
    await load(FakeMatchApi(state: matchStateJson(latestRun: matchRunJson())));
    await Future<void>.delayed(Duration.zero);
    final offline = FakeMatchApi()
      ..stateError =
          const ScholarshipMatchException(ScholarshipMatchFailure.offline);
    await load(offline, user: 'u2');
    expect(store.latestRun, isNull);
  });

  test('404 {disabled} : drapeau fermé, le run en cache est CACHÉ', () async {
    await load(FakeMatchApi(state: matchStateJson(latestRun: matchRunJson())));
    final disabled = FakeMatchApi()
      ..stateError =
          const ScholarshipMatchException(ScholarshipMatchFailure.disabled);
    await load(disabled, force: true);
    expect(store.enabled, isFalse);
    expect(store.latestRun, isNull);
  });

  test('drapeau distant fermé : aucun appel, run en cache caché', () async {
    await load(FakeMatchApi(state: matchStateJson(latestRun: matchRunJson())));
    RemoteFeatureFlags.instance.debugSetFeaturesForTest(
        const <String, bool>{'scholarshipMatch': false});
    final api = FakeMatchApi();
    await load(api, force: true);
    expect(api.stateCalls, 0);
    expect(store.latestRun, isNull);
  });

  test('clé absente de /config/app : le drapeau est lu FERMÉ', () {
    RemoteFeatureFlags.resetForTest();
    expect(RemoteFeatureFlags.instance.scholarshipMatchEnabled, isFalse);
    RemoteFeatureFlags.instance.debugSetFeaturesForTest(const <String, bool>{});
    expect(RemoteFeatureFlags.instance.scholarshipMatchEnabled, isFalse);
  });

  test('un run réussi remplace le dernier run et l\'écrit en cache', () async {
    final api = FakeMatchApi();
    await load(api);
    final outcome = await store.createRun(
      client: api,
      userId: 'u1',
      lang: 'fr',
      answers: {'nationalityCode': 'ner'},
      confirm: true,
    );
    expect(outcome, isA<MatchRunSucceeded>());
    expect(store.latestRun!.id, 'run-1');
    expect(store.isStale, isFalse);
    expect(api.runCalls, hasLength(1));
    await Future<void>.delayed(Duration.zero);
    expect(cache.entries.keys, contains('user:u1:run'));
  });

  test('un run en échec ne touche ni au run ni au brouillon', () async {
    final api = FakeMatchApi(state: matchStateJson(latestRun: matchRunJson()))
      ..runError =
          const ScholarshipMatchException(ScholarshipMatchFailure.timeout);
    await load(api);
    await store.saveDraft('u1', {'v': 1, 'screen': 'recap', 'values': {}});
    final outcome =
        await store.createRun(client: api, userId: 'u1', lang: 'fr');
    expect(outcome, isA<MatchRunFailed>());
    expect(
        (outcome as MatchRunFailed).failure, ScholarshipMatchFailure.timeout);
    expect(store.latestRun!.id, 'run-1');
    expect(await store.readDraft('u1'), isNotNull);
  });

  test('profile_incomplete : rien n\'est remplacé', () async {
    final api = FakeMatchApi()
      ..runResponse = {
        'status': 'profile_incomplete',
        'readiness': {
          'required': ['birthDate'],
        },
      };
    await load(api);
    final outcome =
        await store.createRun(client: api, userId: 'u1', lang: 'fr');
    expect(outcome, isA<MatchRunNeedsAnswers>());
    expect(store.latestRun, isNull);
  });

  test('déconnexion : runs et brouillons du compte effacés', () async {
    await load(FakeMatchApi(state: matchStateJson(latestRun: matchRunJson())));
    await store.saveDraft('u1', {'v': 1});
    await store.clear();
    expect(cache.entries, isEmpty);
    expect(store.latestRun, isNull);
  });

  test('PUT alerts : état confirmé, échec → null', () async {
    final api = FakeMatchApi();
    await load(api);
    expect(await store.setAlerts(client: api, enabled: true), isTrue);
    expect(store.alertsOptIn, isTrue);
    api.alertsError =
        const ScholarshipMatchException(ScholarshipMatchFailure.offline);
    expect(await store.setAlerts(client: api, enabled: false), isNull);
    expect(store.alertsOptIn, isTrue);
  });
}
