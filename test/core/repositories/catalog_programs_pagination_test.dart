// `/catalog/programs` côté app : TOUTES les formations, page après page
// (décision du propriétaire du 17/10/2026 — aucun plafond de formations).
//
// Les builds précédentes demandaient un instantané `limit=1000` ; au-delà, la
// fin de la liste disparaissait de l'app sans erreur. Ces tests verrouillent la
// boucle : curseur suivi jusqu'au bout, dédoublonnage, reprise quand le total
// bouge, compatibilité avec un serveur sans curseur, et échec franc plutôt
// qu'un catalogue tronqué.

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _row(int i) => <String, dynamic>{'id': 'p$i'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDio dio;
  late AppApiClient api;
  final sent = <Map<String, dynamic>>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    dio = _MockDio();
    when(() => dio.interceptors).thenReturn(Interceptors());
    api = AppApiClient(dio: dio);
    sent.clear();
  });

  /// Le serveur : [pages] appelée avec les paramètres envoyés.
  void serve(Map<String, dynamic> Function(Map<String, dynamic> query) pages) {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/catalog/programs',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      final query = Map<String, dynamic>.from(
          invocation.namedArguments[#queryParameters] as Map);
      sent.add(query);
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/catalog/programs'),
        statusCode: 200,
        data: pages(query),
      );
    });
  }

  /// Un serveur à jour (17/10/2026) sur un catalogue de [total] lignes.
  Map<String, dynamic> Function(Map<String, dynamic>) catalog(int total) =>
      (query) {
        final offset = query['offset'] as int;
        final limit = query['limit'] as int;
        final end = (offset + limit).clamp(0, total);
        return <String, dynamic>{
          'items': [for (var i = offset; i < end; i++) _row(i)],
          'total': total,
          'limit': limit,
          'offset': offset,
          'nextOffset': end < total ? end : null,
          'source': 'database',
        };
      };

  test('récupère TOUT le catalogue, bien au-delà de 1 000', () async {
    serve(catalog(2350));
    final payload = await api.listCatalogEnvelope('programs');
    expect(payload.items, hasLength(2350));
    expect(payload.isTrustworthy, isTrue);
    expect(sent, hasLength(5));
    expect(sent.map((q) => q['offset']), [0, 500, 1000, 1500, 2000]);
    // Pages de 500, projection allégée.
    expect(sent.every((q) => q['limit'] == catalogProgramPageSize), isTrue);
    expect(sent.every((q) => q['view'] == 'compact'), isTrue);
  });

  test('une seule page quand le catalogue tient dedans', () async {
    serve(catalog(12));
    expect((await api.listCatalogEnvelope('programs')).items, hasLength(12));
    expect(sent, hasLength(1));
  });

  test('serveur antérieur (sans nextOffset) : lu jusqu\'au total', () async {
    serve((query) {
      final page = catalog(1200)(query)..remove('nextOffset');
      return page;
    });
    expect((await api.listCatalogEnvelope('programs')).items, hasLength(1200));
    expect(sent, hasLength(3));
  });

  test('une ligne qui glisse d\'une page à l\'autre n\'apparaît qu\'une fois',
      () async {
    serve((query) {
      final page = catalog(800)(query);
      if (query['offset'] == 500) {
        (page['items'] as List).insert(0, _row(499));
      }
      return page;
    });
    final ids = (await api.listCatalogEnvelope('programs'))
        .items
        .map((e) => (e as Map)['id'])
        .toList();
    expect(ids, hasLength(800));
    expect(ids.toSet(), hasLength(800));
  });

  test('le total change en route : la lecture reprend une fois', () async {
    var calls = 0;
    serve((query) {
      calls++;
      // Première lecture : 900 lignes, puis un import en ajoute 10.
      final total = calls == 1 ? 900 : 910;
      return catalog(total)(query);
    });
    final payload = await api.listCatalogEnvelope('programs');
    expect(payload.items, hasLength(910));
    expect(sent.map((q) => q['offset']), [0, 500, 0, 500]);
  });

  test('une page dégradée est rendue telle quelle, pour être refusée',
      () async {
    serve((query) => <String, dynamic>{
          'items': [_row(1)],
          'total': 1,
          'source': 'mock',
        });
    final payload = await api.listCatalogEnvelope('programs');
    expect(payload.source, CatalogDataSource.mock);
    expect(payload.isTrustworthy, isFalse);
  });

  test('une page en échec fait échouer TOUTE la lecture (cache gardé)',
      () async {
    serve((query) {
      if (query['offset'] == 500) {
        throw DioException(requestOptions: RequestOptions(path: '/x'));
      }
      return catalog(1200)(query);
    });
    await expectLater(
        api.listCatalogEnvelope('programs'), throwsA(isA<DioException>()));
  });

  test('un curseur qui ne progresse pas ne boucle pas', () async {
    serve((query) => <String, dynamic>{
          'items': [_row(query['offset'] as int)],
          'total': 99999,
          'nextOffset': 0,
          'source': 'database',
        });
    final payload = await api.listCatalogEnvelope('programs');
    expect(payload.items, hasLength(1));
    expect(sent, hasLength(1));
  });
}
