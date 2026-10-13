// Les appels authentifiés de la synchro réessaient les pannes PASSAGÈRES, et
// seulement elles ; et un échec dit sa nature dans `sync_full_complete`.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/observability/analytics_event_contract.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/transient_retry.dart';

DioException _dio(DioExceptionType type, {int? status}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      response: status == null
          ? null
          : Response<void>(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
            ),
    );

void main() {
  Duration noWait(int _) => Duration.zero;

  group('classifySyncError', () {
    test('délais, coupures et statuts HTTP ont chacun leur valeur', () {
      expect(classifySyncError(_dio(DioExceptionType.receiveTimeout)),
          SyncErrorKind.timeout);
      expect(classifySyncError(_dio(DioExceptionType.connectionError)),
          SyncErrorKind.connection);
      expect(classifySyncError(_dio(DioExceptionType.badResponse, status: 503)),
          SyncErrorKind.http5xx);
      expect(classifySyncError(_dio(DioExceptionType.badResponse, status: 429)),
          SyncErrorKind.rateLimited);
      expect(classifySyncError(_dio(DioExceptionType.badResponse, status: 401)),
          SyncErrorKind.unauthorized);
      expect(classifySyncError(_dio(DioExceptionType.badResponse, status: 404)),
          SyncErrorKind.http4xx);
      expect(classifySyncError(StateError('x')), SyncErrorKind.other);
    });

    test('les valeurs publiées sont en snake_case', () {
      final snake = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');
      for (final kind in SyncErrorKind.values) {
        expect(kind.wireValue, matches(snake));
      }
    });
  });

  group('retryTransient', () {
    test('une coupure passagère puis une réponse : réussit au 2e essai',
        () async {
      var calls = 0;
      final result = await retryTransient(() async {
        calls++;
        if (calls == 1) throw _dio(DioExceptionType.connectionError);
        return 'ok';
      }, delay: noWait);
      expect(result, 'ok');
      expect(calls, 2);
    });

    test('abandonne après 3 essais et relance la dernière erreur', () async {
      var calls = 0;
      await expectLater(
        retryTransient(() async {
          calls++;
          throw _dio(DioExceptionType.receiveTimeout);
        }, delay: noWait),
        throwsA(isA<DioException>()),
      );
      expect(calls, 3);
    });

    test('un 4xx (401, 429) n\'est JAMAIS rejoué', () async {
      for (final status in [401, 404, 429]) {
        var calls = 0;
        await expectLater(
          retryTransient(() async {
            calls++;
            throw _dio(DioExceptionType.badResponse, status: status);
          }, delay: noWait),
          throwsA(isA<DioException>()),
        );
        expect(calls, 1, reason: 'HTTP $status');
      }
    });
  });

  test('`sync_full_complete` : étape et nature de l\'échec, rien de plus', () {
    final ok = AnalyticsService.fullSyncParams(
      success: true,
      elapsedMs: 1200,
      catalogHiveFallbackCount: 0,
    );
    expect(ok.keys.toSet(), {
      AnalyticsParamKey.success,
      AnalyticsParamKey.elapsedMs,
      AnalyticsParamKey.catalogHiveFallbackCount,
    });
    final failed = AnalyticsService.fullSyncParams(
      success: false,
      elapsedMs: 9000,
      catalogHiveFallbackCount: 5,
      failureStage: 'account',
      errorKind: SyncErrorKind.timeout.wireValue,
    );
    expect(failed[AnalyticsParamKey.failureStage], 'account');
    expect(failed[AnalyticsParamKey.errorKind], 'timeout');
    expect(failed.keys.length, 5);
  });
}
