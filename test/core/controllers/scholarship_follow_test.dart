// « Suivre » côté contrôleur (chantier G) :
//   · le favori local change tout de suite (hors ligne compris) ;
//   · l'alerte d'ouverture part APRÈS la création du favori (jamais deux
//     écritures concurrentes du même favori), et seulement drapeau allumé ;
//   · une bourse suivie côté serveur (cloche d'une ancienne build) compte comme
//     suivie, et la retirer coupe aussi l'alerte ;
//   · le badge serveur de la cloche se tait pour de bon après un 404.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';

import '../../widget_test_helpers.dart';

DioException _notFound() => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 404,
      ),
    );

Future<AppController> _controller(MockApiClient api) async {
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = true;
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    RemoteFeatureFlags.resetForTest();
  });

  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    RemoteFeatureFlags.resetForTest();
    Get.reset();
  });

  test('Suivre : favori tout de suite, alerte APRÈS la création du favori',
      () async {
    final api = MockApiClient();
    final created = Completer<Map<String, dynamic>>();
    final order = <String>[];
    when(() => api.createSavedItem(any())).thenAnswer((_) {
      order.add('saved');
      return created.future;
    });
    when(() => api.subscribeScholarshipAlert(any())).thenAnswer((_) async {
      order.add('alert');
    });
    final controller = await _controller(api);

    final following = controller.toggleScholarshipFollow('chevening');

    expect(following, isTrue);
    expect(controller.isSaved(SavedItemType.scholarship, 'chevening'), isTrue);
    expect(controller.isFollowingScholarship('chevening'), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(order, ['saved'],
        reason: 'l\'alerte attend la fin de la création du favori');

    created.complete(<String, dynamic>{'id': 'saved-1'});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(order, ['saved', 'alert']);
  });

  test('drapeau followOpeningAlert coupé : aucun appel d\'alerte', () async {
    RemoteFeatureFlags.instance
        .debugSetFeaturesForTest(const {'followOpeningAlert': false});
    final api = MockApiClient();
    when(() => api.createSavedItem(any()))
        .thenAnswer((_) async => <String, dynamic>{'id': 'saved-1'});
    final controller = await _controller(api);

    controller.setScholarshipFollow('chevening', following: true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => api.subscribeScholarshipAlert(any()));
  });

  test('ne plus suivre : favori retiré, puis alerte retirée', () async {
    final api = MockApiClient();
    when(() => api.createSavedItem(any()))
        .thenAnswer((_) async => <String, dynamic>{'id': 'saved-1'});
    when(() => api.subscribeScholarshipAlert(any())).thenAnswer((_) async {});
    when(() => api.deleteSavedItem(any())).thenAnswer((_) async {});
    when(() => api.unsubscribeScholarshipAlert(any())).thenAnswer((_) async {});
    final controller = await _controller(api);
    controller.setScholarshipFollow('chevening', following: true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    controller.setScholarshipFollow('chevening', following: false);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isFollowingScholarship('chevening'), isFalse);
    verify(() => api.deleteSavedItem('saved-1')).called(1);
    verify(() => api.unsubscribeScholarshipAlert('chevening')).called(1);
  });

  test('une alerte d\'une ancienne build vaut « Suivie » ; la retirer la coupe',
      () async {
    final api = MockApiClient();
    when(() => api.unsubscribeScholarshipAlert(any())).thenAnswer((_) async {});
    final controller = await _controller(api);

    controller.rememberServerFollowedScholarships(['daad']);
    expect(controller.isFollowingScholarship('daad'), isTrue);
    expect(controller.isSaved(SavedItemType.scholarship, 'daad'), isFalse,
        reason: 'aucun favori en double n\'est créé');

    expect(controller.toggleScholarshipFollow('daad'), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isFollowingScholarship('daad'), isFalse);
    verify(() => api.unsubscribeScholarshipAlert('daad')).called(1);

    // Une liste serveur en retard ne la ressuscite pas.
    controller.rememberServerFollowedScholarships(['daad']);
    expect(controller.isFollowingScholarship('daad'), isFalse);
  });

  test('badge serveur : compte lu, puis plus aucune requête après un 404',
      () async {
    final api = MockApiClient();
    var calls = 0;
    when(() => api.fetchUnreadNotificationCount()).thenAnswer((_) async {
      calls++;
      return 3;
    });
    final controller = await _controller(api);

    await controller.refreshServerUnreadCount(force: true);
    expect(controller.serverUnreadNotifications, 3);
    expect(controller.serverSupportsFollow, isTrue);

    when(() => api.fetchUnreadNotificationCount()).thenThrow(_notFound());
    await controller.refreshServerUnreadCount(force: true);
    expect(controller.serverUnreadNotifications, 0);
    await controller.refreshServerUnreadCount(force: true);
    expect(calls, 1, reason: 'après un 404, on ne redemande plus');
  });

  test('badge serveur : au plus une requête par minute sans `force`', () async {
    final api = MockApiClient();
    var calls = 0;
    when(() => api.fetchUnreadNotificationCount()).thenAnswer((_) async {
      calls++;
      return 1;
    });
    final controller = await _controller(api);

    await controller.refreshServerUnreadCount();
    await controller.refreshServerUnreadCount();
    expect(calls, 1);
  });

  test('la déconnexion efface l\'état de suivi et le badge', () async {
    final api = MockApiClient();
    when(() => api.fetchUnreadNotificationCount()).thenAnswer((_) async => 2);
    final controller = await _controller(api);
    controller.rememberServerFollowedScholarships(['daad']);
    await controller.refreshServerUnreadCount(force: true);

    AppConfig.enableRemoteSyncOverride = false;
    await controller.logout();

    expect(controller.isFollowingScholarship('daad'), isFalse);
    expect(controller.serverUnreadNotifications, 0);
    expect(controller.serverSupportsFollow, isFalse);
  });
}
