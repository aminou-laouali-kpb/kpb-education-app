// `GET /scholarships` et `GET /scholarships/:id` côté client (chantier I) :
// l'enveloppe (total réel), les paramètres optionnels, et la fiche relue du
// disque hors ligne.

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/live_scholarships_query.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/scholarships_offline_cache.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _item(String id) => <String, dynamic>{
      'id': id,
      'title': 'Bourse $id',
      'countryName': 'France',
      'countryId': 'fra',
      'fundingType': 'fully_funded',
      'description': '',
      'advantages': <String>[],
      'eligibility': <String>[],
      'level': 'Master',
      'deadlineLabel': '',
      'applicationUrl': '',
      'tags': <String>[],
      'matchScore': 30,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDio dio;
  late AppApiClient api;
  late MemoryScholarshipsOfflineStore store;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    dio = _MockDio();
    when(() => dio.interceptors).thenReturn(Interceptors());
    api = AppApiClient(dio: dio);
    store = MemoryScholarshipsOfflineStore();
    ScholarshipsOfflineCache.debugUse(store);
  });

  tearDown(() => ScholarshipsOfflineCache.debugUse(
        MemoryScholarshipsOfflineStore(),
      ));

  Response<Map<String, dynamic>> ok(String path, Map<String, dynamic> data) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: data,
      );

  group('liste', () {
    void stubList(Map<String, dynamic> data) {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/scholarships',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => ok('/scholarships', data));
    }

    Map<String, dynamic> sentQuery() => verify(
          () => dio.get<Map<String, dynamic>>(
            '/scholarships',
            queryParameters: captureAny(named: 'queryParameters'),
          ),
        ).captured.single as Map<String, dynamic>;

    test('garde le total RÉEL du serveur et sait si `query` a été appliquée',
        () async {
      stubList(<String, dynamic>{
        'items': <dynamic>[_item('a')],
        'total': 137,
        'hasMore': true,
        'query': <String, dynamic>{'q': null, 'status': null, 'sort': 'title'},
      });

      final page = await api.fetchLiveScholarshipsPage(lang: 'fr');

      expect(page.items, hasLength(1));
      expect(page.total, 137);
      expect(page.hasMore, isTrue);
      expect(page.serverAppliedQuery, isTrue);
    });

    test('backend ancien : pas de total, pas de `query`', () async {
      stubList(<String, dynamic>{
        'items': <dynamic>[_item('a')]
      });
      final page = await api.fetchLiveScholarshipsPage(lang: 'fr');
      expect(page.total, isNull);
      expect(page.serverAppliedQuery, isFalse);
    });

    test('sans critère nouveau, la requête est celle d\'avant', () async {
      stubList(<String, dynamic>{'items': <dynamic>[]});
      await api.fetchLiveScholarships(lang: 'fr', fundingType: 'fully_funded');
      expect(sentQuery(), <String, dynamic>{
        'lang': 'fr',
        'limit': 20,
        'offset': 0,
        'fundingType': 'fully_funded',
      });
    });

    test(
        'q, status (ordre stable) et sort ne partent que s\'ils disent '
        'quelque chose', () async {
      stubList(<String, dynamic>{'items': <dynamic>[]});
      await api.fetchLiveScholarshipsPage(
        lang: 'en',
        query: '  eiffel ',
        statuses: <ScholarshipListStatus>{
          ScholarshipListStatus.forecast,
          ScholarshipListStatus.open,
        },
        sort: ScholarshipListSort.deadline,
        offset: 40,
      );
      expect(sentQuery(), <String, dynamic>{
        'lang': 'en',
        'limit': 20,
        'offset': 40,
        'q': 'eiffel',
        'status': 'open,forecast',
        'sort': 'deadline',
      });
    });
  });

  group('fiche hors ligne', () {
    const path = '/scholarships/mext';

    test('une fiche consultée est relue du disque quand le réseau tombe',
        () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          path,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => ok(path, _item('mext')));
      final online = await api.fetchLiveScholarshipDetailWithFallback(
        scholarshipId: 'mext',
        lang: 'fr',
      );
      expect(online?.id, 'mext');
      await pumpEventQueue();
      expect(store.entries.keys, contains('detail::fr::mext'));

      when(
        () => dio.get<Map<String, dynamic>>(
          path,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: path),
          type: DioExceptionType.connectionError,
        ),
      );
      final offline = await api.fetchLiveScholarshipDetailWithFallback(
        scholarshipId: 'mext',
        lang: 'fr',
      );
      expect(offline?.id, 'mext');
      expect(offline?.countryId, 'fra');
    });

    test('un 401 ne relit jamais le disque', () async {
      await ScholarshipsOfflineCache.instance
          .writeDetail('fr', 'mext', _item('mext'));
      when(
        () => dio.get<Map<String, dynamic>>(
          path,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: path),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            statusCode: 401,
          ),
        ),
      );
      await expectLater(
        api.fetchLiveScholarshipDetailWithFallback(
          scholarshipId: 'mext',
          lang: 'fr',
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('les fiches gardées sont plafonnées, les plus anciennes partent',
        () async {
      final cache = ScholarshipsOfflineCache(store);
      for (var i = 0; i < ScholarshipsOfflineCache.maxDetails + 5; i++) {
        await cache.writeDetail('fr', 'id-$i', _item('id-$i'));
      }
      final details =
          store.entries.keys.where((key) => key.startsWith('detail::'));
      expect(details, hasLength(ScholarshipsOfflineCache.maxDetails));
      expect(await cache.readDetail('fr', 'id-0'), isNull);
      expect(await cache.readDetail('fr', 'id-64'), isNotNull);

      await cache.clear();
      expect(store.entries, isEmpty);
    });
  });
}
