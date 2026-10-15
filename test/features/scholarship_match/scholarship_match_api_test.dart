// Le client des routes du test : le chemin et le corps que le serveur reçoit,
// et la lecture des échecs (404 `{disabled: true}` = drapeau fermé, 401, 403,
// 429, délai, hors ligne).

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';

import 'match_test_support.dart';

class _MockDio extends Mock implements Dio {}

DioException _status(int code, {Object? data}) => DioException(
      requestOptions: RequestOptions(path: '/scholarships/match/state'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/scholarships/match/state'),
        statusCode: code,
        data: data,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDio dio;
  late AppApiClient client;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    dio = _MockDio();
    when(() => dio.interceptors).thenReturn(Interceptors());
    client = AppApiClient(dio: dio);
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/'),
        data: body,
        statusCode: 200,
      );

  group('GET /scholarships/match/state', () {
    test('chemin, langue normalisée, état lu', () async {
      String? path;
      Map<String, dynamic>? params;
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((inv) async {
        path = inv.positionalArguments.single as String;
        params = Map<String, dynamic>.from(
            inv.namedArguments[#queryParameters] as Map);
        return ok(matchStateJson());
      });

      final state = await client.fetchScholarshipMatchState(lang: 'de');

      expect(path, '/scholarships/match/state');
      expect(params, {'lang': 'fr'});
      expect(state.catalogSize, 29);
    });

    Future<ScholarshipMatchFailure> failureFor(Object error) async {
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(error);
      try {
        await client.fetchScholarshipMatchState(lang: 'fr');
        fail('aurait dû lever');
      } on ScholarshipMatchException catch (e) {
        return e.failure;
      }
    }

    test('404 {disabled: true} → drapeau fermé', () async {
      final error = _status(404, data: {
        'statusCode': 404,
        'disabled': true,
        'code': 'scholarship_match_disabled',
      });
      expect(isScholarshipMatchDisabledResponse(error), isTrue);
      expect(await failureFor(error), ScholarshipMatchFailure.disabled);
    });

    test('404 nu (backend sans les routes) → traité pareil', () async {
      expect(await failureFor(_status(404)), ScholarshipMatchFailure.disabled);
    });

    test('401, 403, 429, 5xx', () async {
      expect(
          await failureFor(_status(401)), ScholarshipMatchFailure.unauthorized);
      expect(await failureFor(_status(403)), ScholarshipMatchFailure.forbidden);
      expect(
          await failureFor(_status(429)), ScholarshipMatchFailure.rateLimited);
      expect(await failureFor(_status(503)), ScholarshipMatchFailure.server);
    });

    test('délai dépassé et hors ligne', () async {
      expect(
        await failureFor(DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.receiveTimeout,
        )),
        ScholarshipMatchFailure.timeout,
      );
      expect(
        await failureFor(DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        )),
        ScholarshipMatchFailure.offline,
      );
    });
  });

  group('POST /scholarships/match/runs', () {
    test('UNE requête : lang, trigger, answers, confirm', () async {
      Map<String, dynamic>? body;
      String? path;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((inv) async {
        path = inv.positionalArguments.single as String;
        body = Map<String, dynamic>.from(inv.namedArguments[#data] as Map);
        return ok(<String, dynamic>{
          'status': 'ok',
          'run': matchRunJson(),
          'diff': {'addedIds': <String>[], 'removedIds': <String>[]},
        });
      });

      final response = await client.createScholarshipMatchRun(
        lang: 'en',
        answers: {'nationalityCode': 'ner'},
        confirm: true,
        trigger: 'wizard',
      );

      expect(path, '/scholarships/match/runs');
      expect(body, {
        'lang': 'en',
        'trigger': 'wizard',
        'answers': {'nationalityCode': 'ner'},
        'confirm': true,
      });
      expect(response, isA<MatchRunOk>());
    });

    test('statut inconnu → exception « invalid »', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => ok({'status': 'queued'}));
      await expectLater(
        client.createScholarshipMatchRun(lang: 'fr'),
        throwsA(isA<ScholarshipMatchException>().having(
          (e) => e.failure,
          'failure',
          ScholarshipMatchFailure.invalid,
        )),
      );
    });

    test('429 → rateLimited', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(_status(429));
      await expectLater(
        client.createScholarshipMatchRun(lang: 'fr'),
        throwsA(isA<ScholarshipMatchException>().having(
          (e) => e.failure,
          'failure',
          ScholarshipMatchFailure.rateLimited,
        )),
      );
    });
  });

  test('PUT /scholarships/match/alerts {enabled}', () async {
    Map<String, dynamic>? body;
    when(() => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((inv) async {
      expect(inv.positionalArguments.single, '/scholarships/match/alerts');
      body = Map<String, dynamic>.from(inv.namedArguments[#data] as Map);
      return ok({'enabled': true, 'optedInAt': '2026-10-13T00:00:00Z'});
    });
    expect(await client.setScholarshipMatchAlerts(enabled: true), isTrue);
    expect(body, {'enabled': true});
  });

  test('POST /me/scholarship-alerts groupé : ≤ 10 identifiants dédoublonnés',
      () async {
    Map<String, dynamic>? body;
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((inv) async {
      expect(inv.positionalArguments.single, '/me/scholarship-alerts');
      body = Map<String, dynamic>.from(inv.namedArguments[#data] as Map);
      return ok({
        'subscribedIds': ['a'],
        'skippedIds': ['b'],
      });
    });
    final result = await client.subscribeScholarshipAlertsBulk(
      [for (var i = 0; i < 12; i++) 'id$i', 'id0', ' '],
    );
    expect((body!['scholarshipIds'] as List), hasLength(10));
    expect(result.skippedIds, ['b']);
  });

  test('GET /cases?scholarshipId= (déduplication de « Être accompagné »)',
      () async {
    Map<String, dynamic>? params;
    when(() => dio.get<List<dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((inv) async {
      expect(inv.positionalArguments.single, '/cases');
      params = Map<String, dynamic>.from(
          inv.namedArguments[#queryParameters] as Map);
      return Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/cases'),
        data: const <dynamic>[],
        statusCode: 200,
      );
    });
    await client.listCasesForScholarship('eiffel');
    expect(params, {'scholarshipId': 'eiffel'});
  });
}
