// La logique sans écran : le magasin (fiche membre, charte, blocages,
// compteurs, déconnexion), la liste à curseur (cache d'abord, pagination,
// curseur périmé), la destination d'une entité citée, et la mesure (aucun
// contenu ni donnée personnelle).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/community.dart';
import 'package:karatou/app/core/observability/analytics_event_contract.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/community_store.dart';
import 'package:karatou/app/features/community/hub/community_entity_navigation.dart';
import 'package:karatou/app/features/community/hub/community_list_controller.dart';

import '../../widget_test_helpers.dart';
import 'community_test_support.dart';

Future<AppController> _student(FakeCommunityApi api) async {
  final controller = AppController(
    repository: FakeRepository(snapshot: studentSnapshot()),
    apiClient: api,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

CommunityPageResult _page(List<String> ids, {String? next}) {
  final raw = <String, dynamic>{
    'items': [for (final id in ids) postJson(id: id)],
    'nextCursor': next,
  };
  return (page: CommunityPage.fromJson(raw, CommunityPost.fromJson), raw: raw);
}

void main() {
  late MemoryCommunityCacheStore cache;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupPlatformChannelMocks();
    cache = resetCommunityWorld();
  });
  tearDown(tearDownCommunityWorld);

  group('CommunityStore', () {
    test('fiche membre chargée une fois, gardée au cache du compte', () async {
      final api = FakeCommunityApi()
        ..meResponse = meJson(charterRequired: true);
      await _student(api);
      final store = CommunityStore.instance;
      final me = await store.loadMe();
      expect(me!.charterRequired, isTrue);
      expect(store.charterRequired, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(cache.entries.keys.single, startsWith('me::test-user-1::fr'));

      expect(await store.acceptCharter(), isTrue);
      expect(api.acceptedVersions, ['2026-10-v1']);
      expect(store.charterRequired, isFalse);
    });

    test('blocages de la session et compteurs mémorisés', () async {
      await _student(FakeCommunityApi());
      final store = CommunityStore.instance;
      await store.setBlocked('cm_x', blocked: true);
      expect(store.isBlockedLocally('cm_x'), isTrue);
      await store.setBlocked('cm_x', blocked: false);
      expect(store.isBlockedLocally('cm_x'), isFalse);

      store.rememberCount(CommunityEntityType.country, 'fra', 4);
      expect(store.cachedCount(CommunityEntityType.country, 'fra'), 4);
      store.invalidateCounts(['country:fra']);
      expect(store.cachedCount(CommunityEntityType.country, 'fra'), isNull);
    });

    test('la déconnexion vide tout : mémoire et disque', () async {
      final api = FakeCommunityApi();
      final controller = await _student(api);
      final store = CommunityStore.instance;
      await store.loadMe();
      await store.setBlocked('cm_x', blocked: true);
      await Future<void>.delayed(Duration.zero);
      expect(cache.entries, isNotEmpty);

      await controller.logout();
      await Future<void>.delayed(Duration.zero);
      expect(store.me, isNull);
      expect(store.isBlockedLocally('cm_x'), isFalse);
      expect(cache.entries, isEmpty);
    });

    test('un échec `disabled` ferme la communauté pour la session', () async {
      await _student(FakeCommunityApi());
      final store = CommunityStore.instance;
      expect(store.enabled, isTrue);
      store.noteFailure(const CommunityException(CommunityFailure.disabled));
      expect(store.enabled, isFalse);
      store.clearServerDisabled();
      expect(store.enabled, isTrue);
    });
  });

  group('CommunityListController', () {
    test('pagination : curseur renvoyé tel quel, sans doublon', () async {
      await _student(FakeCommunityApi());
      final cursors = <String?>[];
      final list = CommunityListController(fetch: (cursor) async {
        cursors.add(cursor);
        return cursor == null
            ? _page(['a', 'b'], next: 'opaque==')
            : _page(['b', 'c']);
      });
      await list.load();
      expect(list.hasMore, isTrue);
      await list.loadMore();
      expect(cursors, [null, 'opaque==']);
      expect(list.items.map((p) => p.id), ['a', 'b', 'c']);
      expect(list.hasMore, isFalse);
      list.dispose();
    });

    test('curseur périmé (400 invalid_cursor) : on repart de la tête',
        () async {
      await _student(FakeCommunityApi());
      var calls = 0;
      final list = CommunityListController(fetch: (cursor) async {
        calls++;
        if (cursor != null) {
          throw const CommunityException(CommunityFailure.invalidCursor);
        }
        return _page(['a'], next: 'old');
      });
      await list.load();
      await list.loadMore();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 3);
      expect(list.moreFailure, isNull);
      list.dispose();
    });

    test('cache d’abord ; hors ligne, la page du disque reste, datée',
        () async {
      await _student(FakeCommunityApi());
      final online = CommunityListController(
        cacheKey: 'feed::k',
        fetch: (_) async => _page(['a', 'b']),
      );
      await online.load();
      await Future<void>.delayed(Duration.zero);
      online.dispose();
      expect(cache.entries.containsKey('feed::k'), isTrue);

      final offline = CommunityListController(
        cacheKey: 'feed::k',
        fetch: (_) async =>
            throw const CommunityException(CommunityFailure.offline),
      );
      await offline.load();
      expect(offline.items.map((p) => p.id), ['a', 'b']);
      expect(offline.showingStaleCache, isTrue);
      expect(offline.cachedAt, isNotNull);
      offline.dispose();
    });

    test('les contenus d’un membre bloqué disparaissent tout de suite',
        () async {
      await _student(FakeCommunityApi());
      final list =
          CommunityListController(fetch: (_) async => _page(['a', 'b']));
      await list.load();
      expect(list.visibleItems, hasLength(2));
      CommunityStore.instance.rememberBlocked('cm_aicha', blocked: true);
      expect(list.visibleItems, isEmpty);
      list.dispose();
    });
  });

  group('destination d’une entité citée', () {
    test('bourse et pays : la fiche ; école sans formation connue : l’espace',
        () async {
      final controller = await _student(FakeCommunityApi());
      CommunityEntityDestination kind(CommunityEntityType type, String id) =>
          resolveCommunityEntityDestination(
            CommunityMention(type: type, id: id, label: id),
            controller: controller,
          ).kind;
      expect(kind(CommunityEntityType.scholarship, 'x'),
          CommunityEntityDestination.fiche);
      expect(kind(CommunityEntityType.country, 'fra'),
          CommunityEntityDestination.fiche);
      expect(kind(CommunityEntityType.institution, 'inconnue'),
          CommunityEntityDestination.space);
      expect(kind(CommunityEntityType.program, 'inconnue'),
          CommunityEntityDestination.space);

      final ProgramModel? program =
          controller.programs.isEmpty ? null : controller.programs.first;
      if (program != null) {
        final viaSchool = resolveCommunityEntityDestination(
          CommunityMention(
              type: CommunityEntityType.institution,
              id: program.institutionId,
              label: 'École'),
          controller: controller,
        );
        expect(viaSchool.kind, CommunityEntityDestination.fiche);
        expect(viaSchool.programId, isNotNull);
      }
    });
  });

  group('mesure', () {
    test('noms d’événements : snake_case, ≤ 40 caractères', () {
      final snake = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');
      for (final name in AnalyticsEventName.communityEvents) {
        expect(name, matches(snake));
        expect(name.length, lessThanOrEqualTo(40), reason: name);
        expect(name, startsWith('community_'));
      }
    });

    test('docs/analytics-event-contract.md documente chaque événement', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final name in AnalyticsEventName.communityEvents) {
        expect(doc, contains('`$name`'), reason: name);
      }
    });

    test('aucune clé hors liste ne part : ni texte, ni nom, ni identifiant',
        () {
      final params = AnalyticsService.communityParams(<String, Object?>{
        AnalyticsParamKey.postType: 'question',
        AnalyticsParamKey.pendingReview: true,
        AnalyticsParamKey.mentionCount: 2,
        'title': 'Qui a eu Eiffel ?',
        'body': 'Mon numéro est…',
        'query': 'eiffel',
        'member_id': 'cm_1',
        'country': 'Niger',
      });
      expect(params.keys.toSet(), {
        AnalyticsParamKey.postType,
        AnalyticsParamKey.pendingReview,
        AnalyticsParamKey.mentionCount,
      });
      expect(params[AnalyticsParamKey.pendingReview], 1);
      final personal = RegExp(
        r'name|nom|mail|phone|tel|whatsapp|country|pays|user|uid|id$|'
        r'profile|age|birth|address|title|body|query|text',
        caseSensitive: false,
      );
      for (final key in AnalyticsService.communityAllowedParams) {
        expect(personal.hasMatch(key), isFalse, reason: key);
      }
    });
  });
}
