// Le message libre de l'élève au coach part dans le CORPS d'un POST SSE,
// jamais dans l'URL : une query string finit dans les journaux d'accès des
// proxys, du CDN et de l'hébergeur (audit du 22/11/2026, constat 33).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';

class _MockDio extends Mock implements Dio {}

const _secret = "Je m'appelle Awa Diop, mes parents gagnent 150 000 FCFA";

void main() {
  late _MockDio dio;
  late AppApiClient client;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    dio = _MockDio();
    when(() => dio.interceptors).thenReturn(Interceptors());
    when(() => dio.post<ResponseBody>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer(
      (_) async => Response<ResponseBody>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: ResponseBody.fromString(
          'data: {"type":"token","text":"Bonjour é"}\n\n'
          'data: {"type":"done","quotaRemaining":3}\n\n',
          200,
        ),
      ),
    );
    client = AppApiClient(dio: dio);
  });

  Future<List<Map<String, dynamic>>> send() => client.streamCoachReply(
        conversationId: 'conv-1',
        userId: 'user-1',
        message: _secret,
        profile: <String, dynamic>{
          'fullName': 'Awa Diop',
          'currentLevel': 'terminale',
          'targetCountryIds': <String>['fr', 'ca'],
          'annualTuitionBudgetEur': 3000,
          'preferredLanguage': 'fr',
        },
      ).toList();

  test('POST sur la route de flux, message dans le corps, rien dans l\'URL',
      () async {
    final events = await send();

    final call = verify(() => dio.post<ResponseBody>(
          captureAny(),
          data: captureAny(named: 'data'),
          queryParameters: captureAny(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        ));
    call.called(1);
    final path = call.captured[0] as String;
    final body = call.captured[1] as Map<String, dynamic>;
    final query = call.captured[2] as Map<String, dynamic>?;
    final options = call.captured[3] as Options;

    expect(path, '/coach/conversations/conv-1/messages/stream');
    expect(path, isNot(contains('?')));
    expect(query, isNull);
    expect(body['message'], _secret);
    expect(options.responseType, ResponseType.stream);
    // Plus aucun appel GET (l'ancienne route en query string).
    verifyNever(() => dio.get<ResponseBody>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ));

    expect(events, <Map<String, dynamic>>[
      <String, dynamic>{'type': 'token', 'text': 'Bonjour é'},
      <String, dynamic>{'type': 'done', 'quotaRemaining': 3},
    ]);
  });

  test('le corps ne porte ni le nom, ni l\'identifiant, ni un champ inconnu',
      () {
    final body = coachStreamRequestBody(
      message: 'Bonjour',
      profile: <String, dynamic>{
        'fullName': 'Awa Diop',
        'currentLevel': 'terminale',
        'targetCountryIds': <dynamic>['fr', 3, 'ca'],
        'annualTuitionBudgetEur': 3000,
        'preferredLanguage': 'fr',
      },
    );
    // Exactement les champs que StreamCoachMessageDto déclare : le serveur
    // refuse tout champ inconnu (forbidNonWhitelisted).
    expect(body, <String, dynamic>{
      'message': 'Bonjour',
      'profile': <String, dynamic>{
        'currentLevel': 'terminale',
        'targetCountryIds': <String>['fr', 'ca'],
        'preferredLanguage': 'fr',
      },
    });
  });

  test('profil incomplet : champs absents omis, liste vide par défaut', () {
    expect(
      coachStreamRequestBody(message: 'a', profile: <String, dynamic>{}),
      <String, dynamic>{
        'message': 'a',
        'profile': <String, dynamic>{'targetCountryIds': <String>[]},
      },
    );
  });
}
