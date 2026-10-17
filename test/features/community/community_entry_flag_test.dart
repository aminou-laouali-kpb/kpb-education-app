// Le drapeau distant `features.community` : fermé (ou absent), RIEN de
// nouveau n'est visible — ni carte d'accueil, ni accès du Profil, ni section
// de fiche, ni ligne de préférences — et aucun appel `/community/*` ne part.
// Ouvert, chaque entrée apparaît pour un élève, jamais pour un parent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/notification_opt_out.dart';
import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/community_store.dart';
import 'package:karatou/app/core/services/notification_router.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/community/hub/community_entity_section.dart';
import 'package:karatou/app/features/community/hub/community_entry.dart';
import 'package:karatou/app/features/home/home_screen.dart';
import 'package:karatou/app/features/notifications/notifications_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../../widget_test_helpers.dart';
import 'community_test_support.dart';

const _eiffel = CommunityMention(
  type: CommunityEntityType.scholarship,
  id: 'eiffel',
  label: 'Bourse Eiffel',
);

Future<AppController> _controller(AppSnapshot snapshot) async {
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  return controller;
}

void putController(AppController controller) {
  if (Get.isRegistered<AppController>()) {
    Get.delete<AppController>(force: true);
  }
  Get.put<AppController>(controller, permanent: true);
}

Future<void> _pumpNotifications(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = MockApiClient();
  when(() => api.fetchUserNotifications(any())).thenAnswer(
      (_) async => <String, dynamic>{'items': <dynamic>[], 'unreadCount': 0});
  await pumpTestApp(tester,
      child: const NotificationsScreen(),
      mockApiClient: api,
      initialSnapshot: studentSnapshot());
}

void main() {
  setUp(() => resetCommunityWorld(flag: false));
  tearDown(tearDownCommunityWorld);

  group('le drapeau', () {
    test('clé absente, fausse ou non booléenne : fermé', () {
      expect(RemoteFeatureFlags.instance.communityEnabled, isFalse);
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({'community': false});
      expect(RemoteFeatureFlags.instance.communityEnabled, isFalse);
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({'community': true});
      expect(RemoteFeatureFlags.instance.communityEnabled, isTrue);
    });

    test('ouvert : élève seulement (ni invité, ni parent)', () async {
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({'community': true});
      expect(CommunityStore.instance.enabled, isFalse); // pas de contrôleur
      final student = await _controller(studentSnapshot());
      putController(student);
      expect(CommunityStore.instance.enabled, isTrue);
      final parent = await _controller(parentCommunitySnapshot());
      putController(parent);
      expect(CommunityStore.instance.enabled, isFalse);
    });

    test('accueil : la carte « Communauté » n’existe que drapeau ouvert',
        () async {
      final student = await _controller(studentSnapshot());
      expect(homeBlocksFor(student), isNot(contains(HomeBlock.community)));
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({'community': true});
      final blocks = homeBlocksFor(student);
      expect(blocks, contains(HomeBlock.community));
      expect(blocks.indexOf(HomeBlock.community),
          blocks.indexOf(HomeBlock.deadlines) + 1);
      final parent = await _controller(parentCommunitySnapshot());
      expect(homeBlocksFor(parent), isNot(contains(HomeBlock.community)));
    });
  });

  group('drapeau fermé : rien de nouveau à l’écran', () {
    testWidgets(
        'carte d’accueil et section de fiche : hauteur nulle, aucun '
        'appel', (tester) async {
      final api = FakeCommunityApi();
      await pumpCommunityApp(
        tester,
        api: api,
        child: const Scaffold(
          body: Column(
            children: [
              CommunityHomeCard(),
              CommunityEntitySection(entity: _eiffel),
            ],
          ),
        ),
      );
      expect(find.byKey(const ValueKey('comm-home-card')), findsNothing);
      expect(find.byKey(const ValueKey('comm-entity-section')), findsNothing);
      expect(api.countCalls, isEmpty);
      expect(api.spaceCalls, isEmpty);
    });

    testWidgets('Profil : ni accès « Communauté », ni « Utilisateurs bloqués »',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 5000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpTestApp(tester,
          child: const ProfileScreen(), initialSnapshot: studentSnapshot());
      expect(find.text('comm_title'), findsNothing);
      expect(find.byKey(const ValueKey('profile-comm-blocked')), findsNothing);
    });

    testWidgets('Profil, drapeau ouvert : les deux entrées apparaissent',
        (tester) async {
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({'community': true});
      await tester.binding.setSurfaceSize(const Size(1440, 5000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpTestApp(tester,
          child: const ProfileScreen(), initialSnapshot: studentSnapshot());
      expect(find.text('comm_title'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('profile-comm-blocked')), findsOneWidget);
    });

    testWidgets('préférences de notification : pas de ligne « community »',
        (tester) async {
      await _pumpNotifications(tester);
      expect(find.text('comm_notif_pref_title'), findsNothing);
    });

    testWidgets('préférences, drapeau ouvert : la ligne « community » est là',
        (tester) async {
      RemoteFeatureFlags.instance.debugSetFeaturesForTest({'community': true});
      await _pumpNotifications(tester);
      expect(find.text('comm_notif_pref_title'), findsOneWidget);
    });
  });

  group('notifications et liens profonds', () {
    test('les routes de la communauté passent le portillon externe', () {
      expect(AppRoutes.normalizeExternalRoute('/community'), '/community');
      expect(AppRoutes.normalizeExternalRoute('/community/posts/cp_1'),
          '/community/posts/cp_1');
      expect(AppRoutes.normalizeExternalRoute('/community/posts/'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/community/posts/a/b'), isNull);
      expect(AppRoutes.communityPostPath('cp 1'), '/community/posts/cp%201');
      expect(
        resolveNotificationRoute(<String, dynamic>{
          'kind': 'community_reply',
          'route': '/community/posts/cp_1',
          'data': {'postId': 'cp_1'},
        }),
        '/community/posts/cp_1',
      );
    });

    test(
        'chaque `kind` community_* a son rendu (jamais celui d’une autre '
        'famille)', () {
      for (final kind in [
        'community_reply',
        'community_followed_reply',
      ]) {
        final style = notificationKindStyle(kind);
        expect(style.icon, Icons.forum_outlined, reason: kind);
        expect(style.ctaKey, 'notif_cta_open_discussion');
      }
      expect(notificationKindStyle('community_verified_answer').icon,
          Icons.verified_rounded);
      expect(notificationKindStyle('community_moderation').icon,
          Icons.shield_outlined);
    });

    test('la clé d’opt-out `community` est connue de cette build', () {
      expect(NotificationOptOutType.community, 'community');
      expect(NotificationOptOutType.all, contains('community'));
    });
  });
}
