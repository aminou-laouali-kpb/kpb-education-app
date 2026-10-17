// Le client des routes `/community/*` : le chemin, les paramètres et le corps
// que le serveur reçoit, et la lecture des erreurs du contrat (§3).

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';

class _MockDio extends Mock implements Dio {}

DioException _error(int status,
        {Object? data, Map<String, List<String>>? headers}) =>
    DioException(
      requestOptions: RequestOptions(path: '/community/posts'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/community/posts'),
        statusCode: status,
        data: data,
        headers: Headers.fromMap(headers ?? const <String, List<String>>{}),
      ),
    );

Response<dynamic> _ok(Object? body, {int status = 200}) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      data: body,
      statusCode: status,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDio dio;
  late AppApiClient client;

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

  group('lecture', () {
    test('GET /community/feed : onglet, type, hashtag normalisé, curseur',
        () async {
      String? path;
      Map<String, dynamic>? params;
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((inv) async {
        path = inv.positionalArguments.single as String;
        params = Map<String, dynamic>.from(
            inv.namedArguments[#queryParameters] as Map);
        return _ok(<String, dynamic>{
          'tab': 'for_you',
          'items': [
            {'id': 'cp_1', 'type': 'question', 'title': 'A', 'author': {}},
          ],
          'nextCursor': 'abc',
          'pinned': <dynamic>[],
        });
      });

      final result = await client.fetchCommunityFeed(
        tab: CommunityFeedTab.forYou,
        type: CommunityPostType.experience,
        hashtag: '#ÉtudesFrance',
        cursor: 'xyz',
        lang: 'de',
      );
      expect(path, '/community/feed');
      expect(params, {
        'tab': 'for_you',
        'type': 'experience',
        'hashtag': 'etudesfrance',
        'cursor': 'xyz',
        'lang': 'fr',
      });
      expect(result.page.items.single.id, 'cp_1');
      expect(result.page.nextCursor, 'abc');
      expect(result.raw['tab'], 'for_you');
    });

    test('« Sans réponse » n’envoie pas de type (le serveur l’ignore)',
        () async {
      Map<String, dynamic>? params;
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((inv) async {
        params = Map<String, dynamic>.from(
            inv.namedArguments[#queryParameters] as Map);
        return _ok(<String, dynamic>{'items': <dynamic>[]});
      });
      await client.fetchCommunityFeed(
          tab: CommunityFeedTab.unanswered, type: CommunityPostType.advice);
      expect(params!.containsKey('type'), isFalse);
    });

    test('compteurs : 50 références au plus, sans doublon', () async {
      Map<String, dynamic>? params;
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((inv) async {
        params = Map<String, dynamic>.from(
            inv.namedArguments[#queryParameters] as Map);
        return _ok(<String, dynamic>{
          'items': [
            {'type': 'country', 'id': 'fra', 'discussionCount': 7},
          ],
        });
      });
      final refs = <({CommunityEntityType type, String id})>[
        (type: CommunityEntityType.country, id: 'fra'),
        (type: CommunityEntityType.country, id: 'fra'),
        for (var i = 0; i < 60; i++)
          (type: CommunityEntityType.scholarship, id: 's$i'),
      ];
      final counts = await client.fetchCommunityEntityCounts(refs);
      final sent = (params!['refs'] as String).split(',');
      expect(sent, hasLength(50));
      expect(sent.first, 'country:fra');
      expect(sent.toSet(), hasLength(50));
      expect(counts.single.discussionCount, 7);
    });

    test('compteur d’une fiche : chemin encodé', () async {
      String? path;
      when(() => dio.get<dynamic>(any())).thenAnswer((inv) async {
        path = inv.positionalArguments.single as String;
        return _ok(<String, dynamic>{
          'type': 'scholarship',
          'id': 'a/b',
          'discussionCount': 12,
        });
      });
      final count = await client.fetchCommunityEntityCount(
          type: CommunityEntityType.scholarship, id: 'a/b');
      expect(path, '/community/entities/scholarship/a%2Fb/count');
      expect(count, 12);
    });
  });

  group('écriture', () {
    test('POST /community/posts : type, titre et corps (jetons compris)',
        () async {
      Object? body;
      when(() => dio.post<dynamic>(any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((inv) async {
        body = inv.namedArguments[#data];
        return _ok(<String, dynamic>{
          'id': 'cp_new',
          'type': 'question',
          'title': 'T',
          'author': {},
          'moderation': {'status': 'pending_review', 'reason': 'auto_filter'},
        }, status: 201);
      });
      final post = await client.createCommunityPost(
        type: CommunityPostType.question,
        title: '  Qui a eu Eiffel ?  ',
        body: 'Qui a eu @[Eiffel](scholarship:e1) ?',
      );
      expect(body, {
        'type': 'question',
        'title': 'Qui a eu Eiffel ?',
        'body': 'Qui a eu @[Eiffel](scholarship:e1) ?',
      });
      expect(post.moderation!.pending, isTrue);
    });

    test('« utile » : PUT pour marquer, DELETE pour retirer', () async {
      when(() => dio.put<dynamic>(any())).thenAnswer((_) async =>
          _ok(<String, dynamic>{'helpfulCount': 3, 'hasMarkedHelpful': true}));
      when(() => dio.delete<dynamic>(any())).thenAnswer((_) async =>
          _ok(<String, dynamic>{'helpfulCount': 2, 'hasMarkedHelpful': false}));
      final on = await client.setCommunityHelpful(
          isReply: true, id: 'cr_1', helpful: true);
      expect(on.helpfulCount, 3);
      verify(() => dio.put<dynamic>('/community/replies/cr_1/helpful'))
          .called(1);
      final off = await client.setCommunityHelpful(
          isReply: false, id: 'cp_1', helpful: false);
      expect(off.hasMarkedHelpful, isFalse);
      verify(() => dio.delete<dynamic>('/community/posts/cp_1/helpful'))
          .called(1);
    });

    test('signaler : détail borné à 500, champ omis si vide', () async {
      final bodies = <Object?>[];
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((inv) async {
        bodies.add(inv.namedArguments[#data]);
        return _ok(<String, dynamic>{'id': 'crp_1'}, status: 201);
      });
      await client.reportCommunity(
        target: CommunityReportTarget.member,
        targetId: 'cm_1',
        reason: CommunityReportReason.scam,
        details: 'x' * 800,
      );
      await client.reportCommunity(
        target: CommunityReportTarget.post,
        targetId: 'cp_1',
        reason: CommunityReportReason.spam,
        details: '   ',
      );
      final first = bodies.first as Map;
      expect(first['targetType'], 'member');
      expect(first['reason'], 'scam');
      expect((first['details'] as String).length, 500);
      expect((bodies.last as Map).containsKey('details'), isFalse);
    });

    test('bloquer : POST ; débloquer : DELETE', () async {
      when(() => dio.post<dynamic>(any()))
          .thenAnswer((_) async => _ok(<String, dynamic>{'isBlocked': true}));
      when(() => dio.delete<dynamic>(any()))
          .thenAnswer((_) async => _ok(<String, dynamic>{'isBlocked': false}));
      expect(await client.setCommunityBlock(memberId: 'cm_1', blocked: true),
          isTrue);
      expect(await client.setCommunityBlock(memberId: 'cm_1', blocked: false),
          isFalse);
      verify(() => dio.post<dynamic>('/community/members/cm_1/block'))
          .called(1);
    });

    test('accepter la charte envoie la version courante', () async {
      Object? body;
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((inv) async {
        body = inv.namedArguments[#data];
        return _ok(<String, dynamic>{
          'acceptedVersion': '2026-10-v1',
          'acceptedAt': '2026-10-17T10:00:00.000Z',
        });
      });
      final result = await client.acceptCommunityCharter('2026-10-v1');
      expect(body, {'version': '2026-10-v1'});
      expect(result.version, '2026-10-v1');
      expect(result.acceptedAt, isNotNull);
    });
  });

  group('erreurs (contrat §3)', () {
    CommunityException classify(Object error) => classifyCommunityError(error);

    test('404 community_disabled (forme spéciale) → disabled', () {
      final e = classify(_error(404, data: {
        'statusCode': 404,
        'disabled': true,
        'code': 'community_disabled',
        'message': 'Community is disabled.',
      }));
      expect(e.failure, CommunityFailure.disabled);
    });

    test('404 sans code (backend sans les routes) → disabled', () {
      expect(classify(_error(404)).failure, CommunityFailure.disabled);
    });

    test('404 métier → notFound', () {
      expect(
          classify(_error(404, data: {'code': 'community_post_not_found'}))
              .failure,
          CommunityFailure.notFound);
    });

    test('429 : scope, limite et Retry-After', () {
      final e = classify(_error(429, data: {
        'code': 'community_rate_limited',
        'details': {'scope': 'replies_per_hour', 'limit': 10},
      }, headers: {
        'retry-after': ['120'],
      }));
      expect(e.failure, CommunityFailure.rateLimited);
      expect(e.details['scope'], 'replies_per_hour');
      expect(e.retryAfterSeconds, 120);
    });

    test('codes 403 / 400 / 409 du contrat', () {
      expect(
          classify(_error(403, data: {
            'code': 'community_charter_required',
            'details': {'charterVersion': '2026-10-v1'},
          })).failure,
          CommunityFailure.charterRequired);
      expect(
          classify(_error(403, data: {
            'code': 'community_read_only',
            'details': {'kind': 'ban', 'until': null},
          })).details['kind'],
          'ban');
      expect(
          classify(_error(400, data: {'code': 'community_too_many_mentions'}))
              .failure,
          CommunityFailure.tooManyMentions);
      expect(
          classify(_error(409, data: {'code': 'community_post_not_open'}))
              .failure,
          CommunityFailure.postNotOpen);
      expect(
          classify(_error(400, data: {
            'message': ['title must be longer than or equal to 8 characters'],
          })).failure,
          CommunityFailure.validation);
    });

    test('réseau : hors ligne et délai', () {
      expect(
          classify(DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError,
          )).failure,
          CommunityFailure.offline);
      expect(
          classify(DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.receiveTimeout,
          )).failure,
          CommunityFailure.timeout);
    });

    test('le client lève CommunityException, jamais une DioException',
        () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(_error(403, data: {'code': 'community_students_only'}));
      await expectLater(
        client.fetchCommunityMe(),
        throwsA(isA<CommunityException>().having(
            (e) => e.failure, 'failure', CommunityFailure.studentsOnly)),
      );
    });
  });
}
