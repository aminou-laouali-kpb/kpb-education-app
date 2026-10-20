// Audit 57, F25 — à la déconnexion, le retrait du jeton push côté serveur
// partait APRÈS l'effacement de la session.
//
// Dio pose l'en-tête `Authorization` dans une tâche ultérieure de la boucle
// d'événements, alors que `signOut` efface la session tout de suite : le
// DELETE /device-tokens partait sans jeton d'accès (401) et l'appareil restait
// rattaché à l'ancien compte. Le faux backend ci-dessous reproduit ce délai
// (un saut de boucle avant de lire la session).

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/services/connectivity_service.dart';
import 'package:karatou/app/core/services/notification_router.dart';
import 'package:karatou/app/core/services/push_service.dart';

import '../../widget_test_helpers.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockSettings extends Mock implements NotificationSettings {}

/// Session Supabase simulée : `clearSession` l'efface AVANT son premier
/// `await`, comme `GoTrueClient.signOut`.
class _FakeAuth extends Mock implements AuthService {
  bool hasSession = true;

  @override
  Future<void> clearSession() async {
    hasSession = false;
  }
}

class _Backend implements PushBackend {
  _Backend(this.auth);

  final _FakeAuth auth;

  /// Pour chaque DELETE : la session existait-elle quand l'en-tête a été posé ?
  final List<bool> unregisterHadSession = [];

  /// Non nul : le DELETE ne répond jamais (réseau qui pend).
  Completer<void>? hang;

  @override
  Future<void> registerDeviceToken(String token, String platform) async {}

  @override
  Future<void> unregisterDeviceToken(String token) async {
    // Comme l'intercepteur de Dio : la session est lue une tâche plus tard.
    await Future<void>(() {});
    unregisterHadSession.add(auth.hasSession);
    final pending = hang;
    if (pending != null) await pending.future;
  }

  @override
  Future<void> reportPushOpened(Map<String, String> payload) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuth auth;
  late _Backend backend;
  late AppController controller;

  Future<void> setUpWorld() async {
    resetGetxSingleton();
    setupPlatformChannelMocks();
    await PushService.instance.debugReset();
    NotificationRouter.instance.debugReset();
    ConnectivityService.instance.debugSetOnline(true);

    final messaging = _MockMessaging();
    when(() => messaging.setForegroundNotificationPresentationOptions(
          alert: any(named: 'alert'),
          badge: any(named: 'badge'),
          sound: any(named: 'sound'),
        )).thenAnswer((_) async {});
    when(() => messaging.onTokenRefresh)
        .thenAnswer((_) => const Stream<String>.empty());
    when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
    when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-token-1');
    when(() => messaging.deleteToken()).thenAnswer((_) async {});
    when(() => messaging.getNotificationSettings()).thenAnswer((_) async {
      final settings = _MockSettings();
      when(() => settings.authorizationStatus)
          .thenReturn(AuthorizationStatus.authorized);
      return settings;
    });

    auth = _FakeAuth();
    backend = _Backend(auth);
    await PushService.instance.initialize(
      backend: backend,
      messaging: messaging,
      foregroundMessages: const Stream<RemoteMessage>.empty(),
      openedMessages: const Stream<RemoteMessage>.empty(),
    );
    await PushService.instance.login(userId: 'usr-42');

    AppConfig.enableRemoteSyncOverride = false;
    controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      ),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    Get.put<AuthService>(auth, permanent: true);
  }

  tearDown(() async {
    ConnectivityService.instance.debugSetOnline(true);
    AppConfig.enableRemoteSyncOverride = null;
    await PushService.instance.debugReset();
    NotificationRouter.instance.debugReset();
    resetGetxSingleton();
  });

  test('le DELETE du jeton part avec la session encore ouverte', () async {
    await setUpWorld();

    await controller.logout();

    expect(backend.unregisterHadSession, [true],
        reason: 'sans session, le serveur répond 401 et garde le jeton');
    expect(auth.hasSession, isFalse, reason: 'la session est bien effacée');
    expect(controller.profile, isNull);
  });

  test('l\'état anonyme reste immédiat pour qui n\'attend pas', () async {
    await setUpWorld();

    final done = controller.logout();
    expect(controller.profile, isNull);
    await done;
  });

  test('hors ligne : la déconnexion n\'attend pas le serveur', () async {
    await setUpWorld();
    ConnectivityService.instance.debugSetOnline(false);
    backend.hang = Completer<void>();

    await controller.logout().timeout(const Duration(seconds: 1));

    expect(auth.hasSession, isFalse);
    backend.hang!.complete();
  });

  testWidgets('serveur qui ne répond pas : la déconnexion aboutit quand même',
      (tester) async {
    await tester.runAsync(setUpWorld);
    backend.hang = Completer<void>();

    var finished = false;
    unawaited(controller.logout().then((_) => finished = true));
    await tester.pump(const Duration(seconds: 1));
    expect(finished, isFalse, reason: 'on laisse sa chance au serveur');
    await tester.pump(const Duration(seconds: 3));
    expect(finished, isTrue, reason: 'mais jamais plus de quelques secondes');
    expect(auth.hasSession, isFalse);
    backend.hang!.complete();
  });
}
