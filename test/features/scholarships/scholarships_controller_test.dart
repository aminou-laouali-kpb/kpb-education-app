import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/live_scholarships_query.dart';
import 'package:karatou/app/core/services/scholarships_offline_cache.dart';
import 'package:karatou/app/features/scholarships/scholarships_controller.dart';

import '../../widget_test_helpers.dart';

Map<String, dynamic> scholarshipJson(int index) => <String, dynamic>{
      'id': 'sch-$index',
      'title': 'Scholarship $index',
      'countryName': 'International',
      'fundingType': 'fully_funded',
      'description': '',
      'advantages': <String>[],
      'eligibility': <String>[],
      'level': 'Master',
      'deadlineLabel': '',
      'applicationUrl': '',
      'tags': <String>[],
      'matchScore': 50,
    };

LiveScholarshipsPage _page(List<dynamic> items) =>
    LiveScholarshipsPage(items: items);

void main() {
  test('loads subsequent offset pages and stops after a short page', () async {
    final api = MockApiClient();
    final firstPage = List<dynamic>.generate(20, scholarshipJson);
    final secondPage = <dynamic>[scholarshipJson(20)];

    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => _page(firstPage));
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 20,
      ),
    ).thenAnswer((_) async => _page(secondPage));
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{'sch-2'});

    final controller = ScholarshipsController(apiClient: api, lang: 'fr');
    await controller.loadInitial();

    expect(controller.items, hasLength(20));
    expect(controller.hasMore, isTrue);
    expect(controller.alertedScholarshipIds, contains('sch-2'));

    await controller.loadMore();

    expect(controller.items, hasLength(21));
    expect(controller.hasMore, isFalse);
  });

  // A profile with a field of interest used to filter the whole published
  // catalog out server-side (`relatedFieldIds` is empty on every write path
  // until an admin curates it), and the screen reported "no scholarships found".
  // The profile criteria must degrade to a ranking preference, not an outage.
  test('retries without the profile criteria when they match nothing',
      () async {
    final api = MockApiClient();
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: 'Master',
        fieldIds: <String>['d01'],
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => _page(<dynamic>[]));
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => _page(<dynamic>[scholarshipJson(1)]));
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      level: 'Master',
      fieldIds: const <String>['d01'],
    );
    await controller.loadInitial();

    expect(controller.items, hasLength(1));
    expect(controller.profileFiltersRelaxed, isTrue);
    expect(controller.error, isNull);
  });

  test('keeps the profile criteria when they do match', () async {
    final api = MockApiClient();
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: 'Master',
        fieldIds: <String>['d01'],
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => _page(<dynamic>[scholarshipJson(1)]));
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      level: 'Master',
      fieldIds: const <String>['d01'],
    );
    await controller.loadInitial();

    expect(controller.items, hasLength(1));
    expect(controller.profileFiltersRelaxed, isFalse);
    verifyNever(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    );
  });

  test('re-attempts the profile criteria on a later reload', () async {
    final api = MockApiClient();
    var filteredCalls = 0;
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: <String>['d01'],
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async {
      filteredCalls += 1;
      // Curated only by the time of the second load.
      return _page(
        filteredCalls == 1 ? <dynamic>[] : <dynamic>[scholarshipJson(2)],
      );
    });
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => _page(<dynamic>[scholarshipJson(1)]));
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      fieldIds: const <String>['d01'],
    );
    await controller.loadInitial();
    expect(controller.profileFiltersRelaxed, isTrue);

    await controller.loadInitial();

    expect(filteredCalls, 2);
    expect(controller.profileFiltersRelaxed, isFalse);
  });

  test('clearAllFilters drops funding and profile criteria for good', () async {
    final api = MockApiClient();
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => _page(<dynamic>[scholarshipJson(1)]));
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      level: 'Master',
      fieldIds: const <String>['d01'],
    )..fundingFilter = 'fully_funded';

    await controller.clearAllFilters();

    expect(controller.fundingFilter, 'all');
    expect(controller.profileFiltersRelaxed, isTrue);
    expect(controller.items, hasLength(1));

    // Sticky: a pull-to-refresh must not silently re-apply what the student
    // explicitly cleared.
    await controller.loadInitial();
    expect(controller.profileFiltersRelaxed, isTrue);
  });

  test('keeps list alert state when alert reconciliation is unavailable',
      () async {
    final api = MockApiClient();
    final item = scholarshipJson(1)..['isAlertEnabled'] = true;
    when(
      () => api.fetchLiveScholarshipsPage(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        statuses: null,
        sort: ScholarshipListSort.relevance,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => _page(<dynamic>[item]));
    when(() => api.fetchScholarshipAlerts())
        .thenThrow(Exception('temporarily unavailable'));

    final controller = ScholarshipsController(apiClient: api, lang: 'fr');
    await controller.loadInitial();

    expect(controller.alertedScholarshipIds, contains('sch-1'));
  });

  // ── Chantier I : total, filtres, tri, hors ligne ─────────────────────────
  group('chantier I', () {
    setUpAll(() {
      registerFallbackValue(ScholarshipListSort.relevance);
    });

    final now = DateTime(2026, 10, 15, 12);

    Map<String, dynamic> withCycle(
      int index, {
      required String status,
      String confidence = 'confirmed',
      DateTime? opensAt,
      DateTime? closesAt,
      DateTime? estimatedOpenAt,
      DateTime? deadlineAt,
    }) =>
        <String, dynamic>{
          ...scholarshipJson(index),
          if (deadlineAt != null) 'deadlineAt': deadlineAt.toIso8601String(),
          'currentCycle': <String, dynamic>{
            'id': 'c-$index',
            'academicYear': '2027-2028',
            'status': status,
            'dateConfidence': confidence,
            'opensAt': opensAt?.toIso8601String(),
            'closesAt': closesAt?.toIso8601String(),
            'estimatedOpenAt': estimatedOpenAt?.toIso8601String(),
          },
        };

    void stubAny(
      MockApiClient api,
      Future<LiveScholarshipsPage> Function(Invocation) answer,
    ) {
      when(
        () => api.fetchLiveScholarshipsPage(
          lang: any(named: 'lang'),
          level: any(named: 'level'),
          fieldIds: any(named: 'fieldIds'),
          fundingType: any(named: 'fundingType'),
          statuses: any(named: 'statuses'),
          sort: any(named: 'sort'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(answer);
      when(() => api.fetchScholarshipAlerts())
          .thenAnswer((_) async => <String>{});
    }

    test('le total affiché est celui du serveur, pas la taille de la page',
        () async {
      final api = MockApiClient();
      stubAny(
        api,
        (_) async => LiveScholarshipsPage(
          items: List<dynamic>.generate(20, scholarshipJson),
          total: 137,
          hasMore: true,
          serverAppliedQuery: true,
        ),
      );
      final controller = ScholarshipsController(apiClient: api, lang: 'fr');
      await controller.loadInitial();
      expect(controller.items, hasLength(20));
      expect(controller.total, 137);
      expect(controller.hasMore, isTrue);
    });

    test(
        'la feuille « Filtrer » part en UNE requête, avec statuts et '
        'financement ; rien ne part si rien ne change', () async {
      final api = MockApiClient();
      stubAny(
        api,
        (_) async => LiveScholarshipsPage(
          items: <dynamic>[scholarshipJson(1)],
          total: 1,
          serverAppliedQuery: true,
        ),
      );
      final controller = ScholarshipsController(apiClient: api, lang: 'fr');
      await controller.loadInitial();
      clearInteractions(api);

      await controller.applyFilters(
        statuses: <ScholarshipListStatus>{
          ScholarshipListStatus.open,
          ScholarshipListStatus.upcoming,
        },
        funding: 'fully_funded',
      );

      final call = verify(
        () => api.fetchLiveScholarshipsPage(
          lang: 'fr',
          level: null,
          fieldIds: null,
          fundingType: 'fully_funded',
          statuses: captureAny(named: 'statuses'),
          sort: ScholarshipListSort.relevance,
          limit: 20,
          offset: 0,
        ),
      );
      call.called(1);
      expect(call.captured.single, <ScholarshipListStatus>{
        ScholarshipListStatus.open,
        ScholarshipListStatus.upcoming,
      });
      expect(controller.activeFilterCount, 3);

      clearInteractions(api);
      await controller.applyFilters(
        statuses: <ScholarshipListStatus>{
          ScholarshipListStatus.upcoming,
          ScholarshipListStatus.open,
        },
        funding: 'fully_funded',
      );
      verifyNever(
        () => api.fetchLiveScholarshipsPage(
          lang: any(named: 'lang'),
          level: any(named: 'level'),
          fieldIds: any(named: 'fieldIds'),
          fundingType: any(named: 'fundingType'),
          statuses: any(named: 'statuses'),
          sort: any(named: 'sort'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );

      await controller.clearAllFilters();
      expect(controller.statusFilter, isEmpty);
      expect(controller.fundingFilter, 'all');
      expect(controller.activeFilterCount, 0);
    });

    test('le tri est envoyé au serveur et recharge la liste', () async {
      final api = MockApiClient();
      stubAny(
        api,
        (_) async => LiveScholarshipsPage(
          items: <dynamic>[scholarshipJson(1)],
          serverAppliedQuery: true,
        ),
      );
      final controller = ScholarshipsController(apiClient: api, lang: 'fr');
      await controller.loadInitial();
      clearInteractions(api);

      await controller.changeSort(ScholarshipListSort.deadline);

      verify(
        () => api.fetchLiveScholarshipsPage(
          lang: 'fr',
          level: null,
          fieldIds: null,
          fundingType: null,
          statuses: null,
          sort: ScholarshipListSort.deadline,
          limit: 20,
          offset: 0,
        ),
      ).called(1);
      expect(controller.sort, ScholarshipListSort.deadline);
    });

    test(
        'backend ancien (sans `query`) : le statut est filtré ici, et le '
        'total, faux pour ce filtre, n\'est pas affiché', () async {
      final api = MockApiClient();
      stubAny(
        api,
        (_) async => LiveScholarshipsPage(
          items: <dynamic>[
            withCycle(
              1,
              status: 'open',
              opensAt: now.subtract(const Duration(days: 3)),
              closesAt: now.add(const Duration(days: 30)),
            ),
            withCycle(
              2,
              status: 'forecast',
              confidence: 'estimated',
              estimatedOpenAt: now.add(const Duration(days: 90)),
            ),
          ],
          total: 2,
        ),
      );
      final controller = ScholarshipsController(
        apiClient: api,
        lang: 'fr',
        clock: () => now,
      )..statusFilter = <ScholarshipListStatus>{ScholarshipListStatus.open};
      await controller.loadInitial();

      expect(controller.items.map((item) => item.id), <String>['sch-1']);
      expect(controller.total, isNull);
    });

    group('hors ligne', () {
      late MemoryScholarshipsOfflineStore store;
      late ScholarshipsOfflineCache cache;

      setUp(() {
        store = MemoryScholarshipsOfflineStore();
        cache = ScholarshipsOfflineCache(store);
      });

      test(
          'la première page reçue est relue, datée, quand le réseau tombe ; '
          'les fiches à date limite CONFIRMÉE passée sont masquées', () async {
        final fetchedAt = DateTime(2026, 10, 10, 9, 30);
        final api = MockApiClient();
        var online = true;
        stubAny(api, (_) async {
          if (!online) {
            throw DioException(
              requestOptions: RequestOptions(path: '/scholarships'),
              type: DioExceptionType.connectionError,
            );
          }
          return LiveScholarshipsPage(
            items: <dynamic>[
              withCycle(
                1,
                status: 'open',
                opensAt: fetchedAt.subtract(const Duration(days: 3)),
                closesAt: fetchedAt.add(const Duration(days: 20)),
              ),
              // Ouverte au moment du cache, clôturée (confirmé) depuis.
              withCycle(
                2,
                status: 'open',
                opensAt: fetchedAt.subtract(const Duration(days: 30)),
                closesAt: fetchedAt.add(const Duration(days: 2)),
              ),
              // Estimée : une date passée ne la retire PAS.
              withCycle(
                3,
                status: 'forecast',
                confidence: 'estimated',
                estimatedOpenAt: fetchedAt.subtract(const Duration(days: 5)),
                deadlineAt: fetchedAt.add(const Duration(days: 1)),
              ),
            ],
            total: 3,
            serverAppliedQuery: true,
          );
        });

        var clock = fetchedAt;
        final controller = ScholarshipsController(
          apiClient: api,
          lang: 'fr',
          offlineCache: cache,
          clock: () => clock,
        );
        await controller.loadInitial();
        await pumpEventQueue();
        expect(controller.items, hasLength(3));
        expect(controller.offlineSince, isNull);

        online = false;
        clock = now; // cinq jours plus tard
        await controller.loadInitial();

        expect(controller.error, isNull);
        expect(controller.failure, isNull);
        expect(controller.offlineSince, fetchedAt.toUtc());
        expect(
          controller.items.map((item) => item.id),
          <String>['sch-1', 'sch-3'],
        );
        expect(controller.total, isNull);
        expect(controller.hasMore, isFalse);

        // Pas de page suivante hors ligne : rien ne part.
        clearInteractions(api);
        await controller.loadMore();
        verifyNever(
          () => api.fetchLiveScholarshipsPage(
            lang: any(named: 'lang'),
            level: any(named: 'level'),
            fieldIds: any(named: 'fieldIds'),
            fundingType: any(named: 'fundingType'),
            statuses: any(named: 'statuses'),
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      });

      test('une page gardée pour d\'AUTRES filtres n\'est jamais servie',
          () async {
        final api = MockApiClient();
        var online = true;
        stubAny(api, (_) async {
          if (!online) throw Exception('offline');
          return LiveScholarshipsPage(items: <dynamic>[scholarshipJson(1)]);
        });
        final controller = ScholarshipsController(
          apiClient: api,
          lang: 'fr',
          offlineCache: cache,
        );
        await controller.loadInitial();
        await pumpEventQueue();

        online = false;
        await controller.changeSort(ScholarshipListSort.title);

        // Rien pour ce tri sur le disque : l'erreur (et son « Réessayer »)
        // plutôt qu'une liste rangée autrement que l'écran ne l'annonce.
        expect(controller.offlineSince, isNull);
        expect(controller.failure, ScholarshipsFailure.connection);
        expect(controller.error, isNotNull);
      });

      test('un 401 ne sert jamais le cache d\'un compte précédent', () async {
        await cache.writeFirstPage(
          'fr|all||relevance|profile:none',
          <dynamic>[scholarshipJson(1)],
        );
        final api = MockApiClient();
        stubAny(api, (_) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/scholarships'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/scholarships'),
              statusCode: 401,
            ),
          );
        });
        final controller = ScholarshipsController(
          apiClient: api,
          lang: 'fr',
          offlineCache: cache,
        );
        await controller.loadInitial();

        expect(controller.failure, ScholarshipsFailure.authRequired);
        expect(controller.items, isEmpty);
        expect(controller.offlineSince, isNull);
      });
    });
  });
}
