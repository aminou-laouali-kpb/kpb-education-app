// Centre de notifications (chantier G) :
//   · une icône et un appel à l'action par `kind` ;
//   · groupes « Aujourd'hui / Cette semaine / Plus tôt » ;
//   · le compte de non-lus du serveur alimente la cloche de l'accueil ;
//   · la ligne « Bourses que je suis : ouverture » n'apparaît que si le
//     serveur connaît le suivi (un backend plus ancien retirerait la clé) ;
//   · autorisation refusée → « Notifications coupées » + réglages.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/push_permission.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/ui/skeleton.dart';
import 'package:karatou/app/features/notifications/notifications_screen.dart';

import '../../widget_test_helpers.dart';

class _FixedPermission implements PushPermission {
  _FixedPermission(this.value);

  final PushPermissionStatus value;
  int settingsOpened = 0;

  @override
  Future<PushPermissionStatus> status() async => value;

  @override
  Future<PushPermissionStatus> request() async => value;

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

Map<String, dynamic> _row(
  String id,
  String kind,
  DateTime createdAt, {
  String route = '/scholarships/chevening',
  bool read = false,
}) =>
    <String, dynamic>{
      'id': id,
      'kind': kind,
      'title': 'Titre $id',
      'body': 'Corps $id',
      'route': route,
      'data': <String, dynamic>{'scholarshipId': 'chevening'},
      'readAt': read ? createdAt.toIso8601String() : null,
      'createdAt': createdAt.toIso8601String(),
    };

Future<MockApiClient> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>> rows = const [],
  int unread = 0,
  bool unreadRouteExists = false,
  Future<Map<String, dynamic>> Function()? fetch,
}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final api = MockApiClient();
  when(() => api.fetchUserNotifications(any())).thenAnswer(
    (_) =>
        fetch?.call() ??
        Future.value(<String, dynamic>{'items': rows, 'unreadCount': unread}),
  );
  if (unreadRouteExists) {
    when(() => api.fetchUnreadNotificationCount())
        .thenAnswer((_) async => unread);
  }
  await pumpTestApp(
    tester,
    child: const NotificationsScreen(),
    mockApiClient: api,
    enableRemoteSync: true,
    initialSnapshot: AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(),
    ),
  );
  return api;
}

void main() {
  setUp(() {
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
  });
  tearDown(() {
    PushPermission.debugOverride = null;
    AppConfig.enableRemoteSyncOverride = null;
    RemoteFeatureFlags.resetForTest();
    resetGetxSingleton();
  });

  group('notificationKindStyle', () {
    test('une icône et un appel à l\'action par famille', () {
      final opened = notificationKindStyle('scholarship_opened');
      expect(opened.icon, Icons.lock_open_rounded);
      expect(opened.ctaKey, 'notif_cta_open_scholarship');

      expect(
        notificationKindStyle('scholarship_opened', variant: 'dates_confirmed')
            .icon,
        Icons.event_available_rounded,
      );
      expect(notificationKindStyle('scholarship_opened_bundle').ctaKey,
          'notif_cta_open_followed');
      expect(
          notificationKindStyle('deadline_reminder').icon, Icons.alarm_rounded);
      expect(notificationKindStyle('case_milestone').ctaKey, 'notif_cta_case');
      expect(notificationKindStyle('counselor_message').ctaKey,
          'notif_cta_message');
      expect(notificationKindStyle('famille_future').icon,
          Icons.notifications_none_rounded,
          reason: 'un kind inconnu garde un rendu neutre');
    });
  });

  test('groupes : aujourd\'hui, cette semaine, plus tôt', () {
    final now = DateTime(2026, 10, 14, 15);
    expect(notificationAgeGroup(DateTime(2026, 10, 14, 1), now: now),
        NotificationAgeGroup.today);
    expect(notificationAgeGroup(DateTime(2026, 10, 13, 23), now: now),
        NotificationAgeGroup.thisWeek);
    expect(notificationAgeGroup(DateTime(2026, 10, 8, 9), now: now),
        NotificationAgeGroup.thisWeek);
    expect(notificationAgeGroup(DateTime(2026, 10, 7, 9), now: now),
        NotificationAgeGroup.earlier);
  });

  testWidgets('le fil est groupé, chaque ligne porte son appel à l\'action',
      (tester) async {
    final now = DateTime.now();
    await _pump(tester, unread: 2, rows: [
      _row('a', 'scholarship_opened', now),
      _row('b', 'deadline_reminder', now.subtract(const Duration(days: 2))),
      _row('c', 'scholarship_opened', now.subtract(const Duration(days: 30)),
          read: true),
    ]);

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('notifications_group_today'), findsOneWidget);
    expect(find.text('notifications_group_week'), findsOneWidget);
    expect(find.text('notifications_group_earlier'), findsOneWidget);
    expect(y('notifications_group_today'), lessThan(y('Titre a')));
    expect(y('Titre a'), lessThan(y('notifications_group_week')));
    expect(y('notifications_group_week'), lessThan(y('Titre b')));
    expect(y('Titre b'), lessThan(y('notifications_group_earlier')));
    expect(y('notifications_group_earlier'), lessThan(y('Titre c')));

    expect(find.text('notif_cta_open_scholarship'), findsNWidgets(2));
    expect(find.text('notif_cta_deadline'), findsOneWidget);
    expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);

    // Le compte du serveur fait foi pour la cloche de l'accueil.
    expect(Get.find<AppController>().serverUnreadNotifications, 2);
  });

  testWidgets(
      'premier chargement : un squelette (KpbAsyncView), jamais un « Aucune '
      'notification » prématuré', (tester) async {
    // Animations coupées : le squelette ne pulse pas, `pumpAndSettle` rend la
    // main pendant que le fil serveur est encore en route.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final pending = Completer<Map<String, dynamic>>();
    await _pump(tester, fetch: () => pending.future);

    expect(find.byType(KpbSkeletonList), findsOneWidget);
    expect(find.text('notifications_empty_title'), findsNothing);
    // Les préférences restent accessibles pendant le chargement.
    expect(find.text('notifications_push_section'), findsOneWidget);

    pending.complete(<String, dynamic>{'items': <dynamic>[], 'unreadCount': 0});
    await tester.pumpAndSettle();

    expect(find.byType(KpbSkeletonList), findsNothing);
    expect(find.text('notifications_empty_title'), findsOneWidget);
  });

  testWidgets('« Tout marquer comme lu » éteint le badge serveur',
      (tester) async {
    final api = await _pump(tester, unread: 1, rows: [
      _row('a', 'scholarship_opened', DateTime.now()),
    ]);
    when(() => api.markAllUserNotificationsRead()).thenAnswer((_) async {});

    await tester.tap(find.text('notifications_mark_all_read'));
    await tester.pumpAndSettle();

    expect(Get.find<AppController>().serverUnreadNotifications, 0);
  });

  testWidgets('tirer pour rafraîchir recharge le fil', (tester) async {
    final api = await _pump(tester, rows: const []);
    clearInteractions(api);
    when(() => api.fetchUserNotifications(any())).thenAnswer(
      (_) async => <String, dynamic>{
        'items': [_row('n', 'scholarship_opened', DateTime.now())],
        'unreadCount': 1,
      },
    );

    // Pas d'`await` : la future ne se termine qu'une fois l'animation jouée.
    unawaited(tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show());
    await tester.pumpAndSettle();

    verify(() => api.fetchUserNotifications(any())).called(1);
    expect(find.text('Titre n'), findsOneWidget);
  });

  testWidgets(
      'ligne « Bourses que je suis : ouverture » : absente sur un backend '
      'antérieur', (tester) async {
    await _pump(tester);
    expect(find.text('followed_scholarship_pref_title'), findsNothing);
  });

  testWidgets('… présente quand le serveur sert le badge (chantier C)',
      (tester) async {
    await _pump(tester, unreadRouteExists: true);
    expect(find.text('followed_scholarship_pref_title'), findsOneWidget);
  });

  testWidgets('autorisation refusée : « Notifications coupées » + réglages',
      (tester) async {
    final permission = _FixedPermission(PushPermissionStatus.denied);
    PushPermission.debugOverride = permission;
    await _pump(tester);

    expect(find.text('push_denied_title'), findsOneWidget);
    await tester.tap(find.text('notifications_push_settings_action'));
    await tester.pumpAndSettle();
    expect(permission.settingsOpened, 1);
  });

  testWidgets('autorisation accordée : plus de bouton « Activer »',
      (tester) async {
    PushPermission.debugOverride =
        _FixedPermission(PushPermissionStatus.granted);
    await _pump(tester);

    expect(find.text('notifications_push_granted_title'), findsOneWidget);
    expect(find.text('notifications_push_enable_action'), findsNothing);
  });
}
