// FollowedScholarshipsStore — « Mes suivis » vu du serveur : cache d'abord,
// réseau ensuite, et une dégradation propre face à un backend sans la route
// (404 : la section se masque, rien ne casse).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/followed_scholarships_store.dart';

import '../../widget_test_helpers.dart';

DioException _status(int? code) => DioException(
      requestOptions: RequestOptions(path: '/me/followed-scholarships'),
      response: code == null
          ? null
          : Response<void>(
              requestOptions: RequestOptions(path: '/me/followed-scholarships'),
              statusCode: code,
            ),
      type: code == null
          ? DioExceptionType.connectionError
          : DioExceptionType.badResponse,
    );

FollowedScholarshipsPage _page(List<String> ids) => FollowedScholarshipsPage(
      items: [
        for (final id in ids)
          FollowedScholarship(
            id: id,
            title: 'Bourse $id',
            countryId: 'fra',
            countryName: 'France',
            displayStatus: FollowedDisplayStatus.open,
          ),
      ],
      total: ids.length,
      globalOptOut: false,
      fetchedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  final store = FollowedScholarshipsStore.instance;
  late MemoryFollowedScholarshipsCache cache;
  late MockApiClient api;

  setUp(() {
    store.debugReset();
    cache = MemoryFollowedScholarshipsCache();
    store.debugCache = cache;
    api = MockApiClient();
  });

  tearDown(store.debugReset);

  test('200 : la page est servie, la route est connue, le cache est écrit',
      () async {
    when(() => api.fetchFollowedScholarships(any()))
        .thenAnswer((_) async => _page(['chevening']));

    await store.load(client: api, userId: 'u1', lang: 'fr');

    expect(store.endpoint, FollowedEndpointState.available);
    expect(store.page?.items.single.id, 'chevening');
    expect(store.offline, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(await cache.read('u1'), contains('chevening'));
  });

  test('404 : backend antérieur au chantier C — la section se masque',
      () async {
    when(() => api.fetchFollowedScholarships(any())).thenThrow(_status(404));

    await store.load(client: api, userId: 'u1', lang: 'fr');

    expect(store.endpoint, FollowedEndpointState.unavailable);
    expect(store.page, isNull);
    expect(store.offline, isFalse,
        reason: 'une route absente n\'est pas une panne réseau');
  });

  test('hors ligne avec un cache : la page du cache, marquée hors ligne',
      () async {
    when(() => api.fetchFollowedScholarships(any()))
        .thenAnswer((_) async => _page(['daad']));
    await store.load(client: api, userId: 'u1', lang: 'fr');
    await Future<void>.delayed(Duration.zero);

    // Nouvelle session : la mémoire est vide, le cache ne l'est pas.
    store.debugReset();
    store.debugCache = cache;
    when(() => api.fetchFollowedScholarships(any())).thenThrow(_status(null));

    await store.load(client: api, userId: 'u1', lang: 'fr');

    expect(store.page?.items.single.id, 'daad');
    expect(store.offline, isTrue);
    expect(store.endpoint, FollowedEndpointState.unknown);
  });

  test('le cache est par compte : jamais les suivis d\'un autre élève',
      () async {
    await cache.write('u1', '{"items":[{"id":"chevening"}],"total":1}');
    when(() => api.fetchFollowedScholarships(any())).thenThrow(_status(null));

    await store.load(client: api, userId: 'u2', lang: 'fr');

    expect(store.page, isNull);
  });

  test('clear() vide la mémoire et le cache (déconnexion)', () async {
    when(() => api.fetchFollowedScholarships(any()))
        .thenAnswer((_) async => _page(['chevening']));
    await store.load(client: api, userId: 'u1', lang: 'fr');
    await Future<void>.delayed(Duration.zero);

    await store.clear();

    expect(store.page, isNull);
    expect(store.endpoint, FollowedEndpointState.unknown);
    expect(await cache.read('u1'), isNull);
  });
}
