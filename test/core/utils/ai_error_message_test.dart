import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/ai_error_message.dart';

DioException _dio({
  int? status,
  Object? data,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/tools/cv-summary'),
    type: type,
    response: status == null
        ? null
        : Response<dynamic>(
            requestOptions: RequestOptions(path: '/tools/cv-summary'),
            statusCode: status,
            data: data,
          ),
  );
}

void main() {
  setUpAll(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
  });

  test('403 ai_consent_required is detected, not a snackbar key', () {
    final error = _dio(
      status: 403,
      data: {'code': 'ai_consent_required', 'message': 'nope'},
    );
    expect(isAiConsentRequiredError(error), isTrue);
    expect(aiConsentBlockCode(error), 'ai_consent_required');
  });

  test('403 guardian_consent_required is not the reopen-dialog case', () {
    final error = _dio(
      status: 403,
      data: {'code': 'guardian_consent_required'},
    );
    expect(isAiConsentRequiredError(error), isFalse);
    expect(aiConsentBlockCode(error), 'guardian_consent_required');
  });

  test('connect and send timeouts blame the network', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionError,
    ]) {
      final message = aiErrorMessage(_dio(type: type));
      expect(message, isNot(equals('tools_ai_error_check_connection')));
      expect(message.toLowerCase(), contains('connexion'), reason: '$type');
    }
  });

  test('a receive timeout says the generation is slow, not the connection', () {
    final message = aiErrorMessage(_dio(type: DioExceptionType.receiveTimeout));
    expect(message, isNot(equals('tools_ai_error_slow')));
    expect(message.toLowerCase(), isNot(contains('connexion')));
    expect(message, contains('plus de temps que prévu'));

    Get.locale = const Locale('en');
    addTearDown(() => Get.locale = const Locale('fr'));
    expect(aiErrorMessage(_dio(type: DioExceptionType.receiveTimeout)),
        contains('longer than expected'));
  });

  test('the server daily AI quota gets its own message', () {
    expect(
      aiErrorMessage(_dio(
        status: 429,
        data: {'code': 'ai_daily_quota_reached'},
      )),
      'tools_ai_error_daily_quota'.tr,
    );
    // A plain throttler 429 keeps the "try again in a minute" message.
    expect(
      aiErrorMessage(_dio(status: 429)),
      'tools_ai_error_rate_limited'.tr,
    );
  });

  test('an oversized input says the text is too long', () {
    expect(
      aiErrorMessage(_dio(status: 413, data: {'code': 'ai_input_too_large'})),
      'tools_ai_error_input_too_large'.tr,
    );
  });
}
