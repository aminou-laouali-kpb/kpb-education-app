// NotificationRouter — le routage des taps de notification, indépendant du
// fournisseur de push (chantier G). Ce qui est gardé ici :
//   · un tap de démarrage à froid attend la première image (file d'attente),
//     puis est rejoué — il n'est jamais perdu ni joué trop tôt ;
//   · le push groupé (`scholarship_opened_bundle`) ouvre « Mes suivis » ;
//   · ses références d'inbox sont marquées lues (`read-by-ref`), et un backend
//     sans la route (404) ne bloque pas la navigation ;
//   · `push_opened {kind}` est mesuré, avec un `kind` fermé.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/notification_router.dart';

import '../../widget_test_helpers.dart';

class _FakeBackend implements NotificationRouterBackend {
  _FakeBackend({this.error});

  final Object? error;
  final calls = <List<String>>[];

  @override
  Future<int> markNotificationsReadByRef(List<String> refs) async {
    calls.add(refs);
    if (error != null) throw error!;
    return refs.length;
  }
}

DioException _notFound() => DioException(
      requestOptions: RequestOptions(path: '/me/notifications/read-by-ref'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/me/notifications/read-by-ref'),
        statusCode: 404,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final router = NotificationRouter.instance;
  late List<String?> navigated;
  late List<MapEntry<String, Map<String, Object>>> events;

  setUp(() {
    Get.reset();
    router.debugReset();
    navigated = <String?>[];
    events = <MapEntry<String, Map<String, Object>>>[];
    router.navigateOverride = (route) async {
      navigated.add(route);
    };
    router.navigatorReadyOverride = () => true;
    AnalyticsService.instance.logEventSink = (name, params) async {
      events.add(MapEntry(name, params));
    };
  });

  tearDown(() {
    router.debugReset();
    AnalyticsService.instance.logEventSink = null;
    Get.reset();
  });

  group('resolveNotificationRoute', () {
    test('le push groupé ouvre Mes suivis, pas le calendrier', () {
      expect(
        resolveNotificationRoute(<String, dynamic>{
          'route': '/deadlines',
          'type': 'scholarship_opened_bundle',
          'kind': 'scholarship_opened_bundle',
          'count': '3',
        }),
        AppRoutes.saved,
      );
    });

    test('une annonce seule ouvre la fiche de SA bourse', () {
      expect(
        resolveNotificationRoute(<String, dynamic>{
          'route': '/scholarships/chevening',
          'scholarshipId': 'chevening',
          'kind': 'scholarship_opened',
        }),
        AppRoutes.scholarshipDetailPath('chevening'),
      );
    });

    test('une route externe invalide rend null (→ accueil)', () {
      expect(
        resolveNotificationRoute(<String, dynamic>{'route': 'https://evil'}),
        isNull,
      );
    });
  });

  test('notificationRefsOf lit `ref` et `refs` (chaîne ou liste), sans doublon',
      () {
    expect(
      notificationRefsOf(<String, dynamic>{
        'ref': 'scholarship-opened:c1',
        'refs': 'scholarship-opened:c1, scholarship-opened:c2,',
      }),
      <String>['scholarship-opened:c1', 'scholarship-opened:c2'],
    );
    expect(
      notificationRefsOf(<String, dynamic>{
        'refs': <dynamic>['a:1', 2, 'b:2'],
      }),
      <String>['a:1', 'b:2'],
    );
  });

  test('démarrage à froid : le tap attend la première image, puis est rejoué',
      () async {
    await router.open(<String, dynamic>{
      'route': '/scholarships/chevening',
      'kind': 'scholarship_opened',
    });
    expect(navigated, isEmpty, reason: 'pas de navigateur avant runApp');
    expect(router.pendingCount, 1);

    router.markReady();
    await Future<void>.delayed(Duration.zero);
    expect(navigated, <String?>[AppRoutes.scholarshipDetailPath('chevening')]);
    expect(router.pendingCount, 0);
  });

  test('plusieurs taps en file : seul le dernier ouvre une page', () async {
    await router.open(<String, dynamic>{'route': '/scholarships/a'});
    await router.open(<String, dynamic>{'route': '/scholarships/b'});
    router.markReady();
    await Future<void>.delayed(Duration.zero);
    expect(navigated, <String?>['/scholarships/b']);
  });

  test('après la première image, un tap navigue tout de suite', () async {
    router.markReady();
    await router.open(<String, dynamic>{
      'route': '/deadlines',
      'kind': 'scholarship_opened_bundle',
    });
    expect(navigated, <String?>[AppRoutes.saved]);
  });

  test('push groupé : ses références sont marquées lues', () async {
    final backend = _FakeBackend();
    router
      ..attach(backend)
      ..markReady();
    await router.open(<String, dynamic>{
      'route': '/deadlines',
      'kind': 'scholarship_opened_bundle',
      'refs': 'scholarship-opened:c1,scholarship-opened:c2',
    });
    await Future<void>.delayed(Duration.zero);
    expect(backend.calls, [
      ['scholarship-opened:c1', 'scholarship-opened:c2'],
    ]);
  });

  test('backend sans read-by-ref (404) : la navigation a lieu quand même',
      () async {
    final backend = _FakeBackend(error: _notFound());
    router
      ..attach(backend)
      ..markReady();
    await router.open(<String, dynamic>{
      'route': '/scholarships/chevening',
      'kind': 'scholarship_opened',
      'ref': 'scholarship-opened:c1',
    });
    await Future<void>.delayed(Duration.zero);
    expect(backend.calls, hasLength(1));
    expect(navigated, <String?>['/scholarships/chevening']);
  });

  test('push_opened porte le kind, et rien d\'autre', () async {
    router.markReady();
    await router.open(<String, dynamic>{
      'route': '/scholarships/chevening',
      'kind': 'scholarship_opened',
      'scholarshipId': 'chevening',
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.single.key, 'push_opened');
    expect(events.single.value, <String, Object>{'kind': 'scholarship_opened'});
  });

  test('un kind hors vocabulaire est réduit à `unknown`', () {
    expect(
      AnalyticsService.pushOpenedParams('Bourse Chevening ouverte !'),
      <String, Object>{'kind': 'unknown'},
    );
    expect(
      AnalyticsService.pushOpenedParams('deadline_reminder'),
      <String, Object>{'kind': 'deadline_reminder'},
    );
  });

  test('élève pas encore entré dans l\'app : aucune page poussée', () async {
    setupPlatformChannelMocks();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot.initial(),
      ),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    router.markReady();
    await router.open(<String, dynamic>{'route': '/scholarships/chevening'});
    expect(navigated, isEmpty,
        reason:
            'une fiche poussée sur l\'écran de connexion mènerait à un 401');
  });

  group('bot « Passerelle » (assist_bridge)', () {
    Map<String, dynamic> payload() => <String, dynamic>{
          'route': '/scholarship-match',
          'type': 'assist_bridge',
          'needId': 'scholarship_match',
          'feature': 'scholarship_match',
          'eventId': 'ev_1',
          'whatsapp': 'kpb',
          'notificationKey': 'assist_bridge:ev_1',
        };

    test('un tap ouvre la feuille, jamais une page par-dessus', () async {
      final opened = <Map<String, dynamic>>[];
      router.assistBridgeOpener = (data) async => opened.add(data);
      router.markReady();
      await router.open(payload());
      expect(opened.single['needId'], 'scholarship_match');
      expect(navigated, isEmpty);
      expect(events.single.value, <String, Object>{'kind': 'assist_bridge'});
    });

    test('feuille en échec, ou non branchée : la route servie est suivie',
        () async {
      router.assistBridgeOpener =
          (_) async => throw StateError('pas de contexte');
      router.markReady();
      await router.open(payload());
      expect(navigated, <String?>['/scholarship-match']);

      router.assistBridgeOpener = null;
      await router.open(payload());
      expect(navigated, <String?>['/scholarship-match', '/scholarship-match']);
    });

    test('une build ancienne (route inconnue) retombe sur l\'accueil', () {
      expect(
        resolveNotificationRoute(<String, dynamic>{
          'route': '/document-review',
          'kind': 'assist_bridge',
        }),
        isNull,
      );
    });

    test('les autres kinds ne passent jamais par la feuille', () async {
      final opened = <Map<String, dynamic>>[];
      router.assistBridgeOpener = (data) async => opened.add(data);
      router.markReady();
      await router.open(<String, dynamic>{
        'route': '/scholarships/chevening',
        'kind': 'scholarship_opened',
      });
      expect(opened, isEmpty);
      expect(navigated, <String?>['/scholarships/chevening']);
    });
  });
}
