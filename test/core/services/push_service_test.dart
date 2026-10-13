// PushService — FCM en direct. Ce qui est gardé ici :
//   · le jeton part vers NOTRE backend, avec la plateforme, et rien d'autre ;
//   · pas de jeton enregistré sans autorisation (sinon les campagnes comptent
//     « livrée » une notification que le système n'affichera jamais) ;
//   · la déconnexion retire le jeton ET l'invalide chez FCM ;
//   · un tap renvoie l'ouverture (campagne / rappel) au backend.
//
// FCM est simulé par mocktail : aucun canal de plateforme n'est touché.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/services/push_service.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockSettings extends Mock implements NotificationSettings {}

class _FakeBackend implements PushBackend {
  final registered = <List<String>>[];
  final unregistered = <String>[];
  final opened = <Map<String, String>>[];

  @override
  Future<void> registerDeviceToken(String token, String platform) async =>
      registered.add([token, platform]);

  @override
  Future<void> unregisterDeviceToken(String token) async =>
      unregistered.add(token);

  @override
  Future<void> reportPushOpened(Map<String, String> payload) async =>
      opened.add(payload);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockMessaging messaging;
  late _FakeBackend backend;
  late StreamController<RemoteMessage> opened;
  late AuthorizationStatus status;

  setUp(() async {
    await PushService.instance.debugReset();
    messaging = _MockMessaging();
    backend = _FakeBackend();
    opened = StreamController<RemoteMessage>.broadcast();
    status = AuthorizationStatus.authorized;

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
      when(() => settings.authorizationStatus).thenReturn(status);
      return settings;
    });

    await PushService.instance.initialize(
      backend: backend,
      messaging: messaging,
      foregroundMessages: const Stream<RemoteMessage>.empty(),
      openedMessages: opened.stream,
    );
  });

  tearDown(() async {
    await opened.close();
    await PushService.instance.debugReset();
  });

  test('le harnais initialise réellement le service', () {
    expect(PushService.instance.isInitialized, isTrue,
        reason: 'sans init, tout est no-op et chaque garde serait creuse');
  });

  test('login enregistre le jeton et la plateforme auprès du backend',
      () async {
    await PushService.instance.login(userId: 'usr-42');
    expect(backend.registered, [
      ['fcm-token-1', 'android'],
    ]);

    // Même jeton, même compte : pas de second appel à chaque synchro.
    await PushService.instance.login(userId: 'usr-42');
    expect(backend.registered, hasLength(1));

    // Autre compte sur le même téléphone : le jeton est réattribué.
    await PushService.instance.login(userId: 'usr-43');
    expect(backend.registered, hasLength(2));
  });

  test('aucun jeton enregistré sans autorisation des notifications', () async {
    status = AuthorizationStatus.denied;
    await PushService.instance.login(userId: 'usr-42');
    expect(backend.registered, isEmpty);
  });

  test('autorisation retirée : le jeton enregistré est retiré', () async {
    await PushService.instance.login(userId: 'usr-42');
    status = AuthorizationStatus.denied;
    await PushService.instance.requestPermission();
    expect(backend.unregistered, ['fcm-token-1']);
  });

  // L'onboarding demande l'autorisation AVANT que le profil existe : le jeton
  // ne doit partir qu'au `login`, rattaché à un compte.
  test('pas d\'enregistrement avant que le compte soit connu', () async {
    await PushService.instance.requestPermission();
    expect(backend.registered, isEmpty);
  });

  test('logout retire le jeton côté backend ET l\'invalide chez FCM', () async {
    await PushService.instance.login(userId: 'usr-42');
    await PushService.instance.logout();
    expect(backend.unregistered, ['fcm-token-1']);
    verify(() => messaging.deleteToken()).called(1);
  });

  test('un tap renvoie l\'ouverture au backend', () async {
    opened.add(const RemoteMessage(data: {
      'campaignId': 'camp-1',
      'route': '/deadlines',
      'type': 'campaign',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(backend.opened, [
      {'campaignId': 'camp-1'},
    ]);
  });

  group('resolvePushRoute', () {
    test('normalise la route de la charge', () {
      expect(resolvePushRoute({'route': '/cases/abc'}), '/cases/abc');
    });

    test('une route inconnue rend null (→ accueil)', () {
      expect(resolvePushRoute({'route': 'https://evil.example'}), isNull);
      expect(resolvePushRoute(const {}), isNull);
    });

    test('promeut les anciennes activations de bourse vers la fiche', () {
      expect(
        resolvePushRoute({
          'route': AppRoutes.scholarships,
          'scholarshipId': ' sch-9 ',
        }),
        AppRoutes.scholarshipDetailPath('sch-9'),
      );
    });
  });

  test('pushOpenedPayload ne renvoie que campagne et clé de rappel', () {
    expect(
      pushOpenedPayload({
        'campaignId': ' camp-1 ',
        'notificationKey': 'deadline:usr-42:sch-9:7',
        'route': '/deadlines',
        'caseId': 'case-1',
      }),
      {
        'campaignId': 'camp-1',
        'notificationKey': 'deadline:usr-42:sch-9:7',
      },
    );
    expect(pushOpenedPayload({'campaignId': '  '}), isEmpty);
  });
}
