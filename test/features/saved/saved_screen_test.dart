// « Mes suivis » (chantier G) :
//   · un vrai écran (Scaffold + AppBar), « Bourses suivies » EN PREMIER ;
//   · puces de statut, tri, glisser pour retirer avec « Annuler » ;
//   · état vide avec appel à l'action ;
//   · backend sans la route (404) : la section se masque, les bourses suivies
//     localement restent listées depuis le catalogue.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/navigation/shell_tabs.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/services/followed_scholarships_store.dart';
import 'package:karatou/app/features/saved/followed_scholarships_section.dart';
import 'package:karatou/app/features/saved/saved_screen.dart';

import '../../widget_test_helpers.dart';

FollowedScholarship _item(
  String id,
  String title,
  FollowedDisplayStatus status, {
  DateTime? opensAt,
  DateTime? closesAt,
}) =>
    FollowedScholarship(
      id: id,
      title: title,
      countryId: 'gbr',
      countryName: 'Royaume-Uni',
      displayStatus: status,
      opensAt: opensAt,
      closesAt: closesAt,
      dateConfidence: 'confirmed',
    );

Future<MockApiClient> _pump(
  WidgetTester tester, {
  FollowedScholarshipsPage? page,
  Object? error,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final api = MockApiClient();
  if (error != null) {
    when(() => api.fetchFollowedScholarships(any())).thenThrow(error);
  } else {
    when(() => api.fetchFollowedScholarships(any()))
        .thenAnswer((_) async => page!);
  }
  when(() => api.unsubscribeScholarshipAlert(any())).thenAnswer((_) async {});
  when(() => api.subscribeScholarshipAlert(any())).thenAnswer((_) async {});
  when(() => api.createSavedItem(any()))
      .thenAnswer((_) async => <String, dynamic>{'id': 'saved-1'});
  when(() => api.deleteSavedItem(any())).thenAnswer((_) async {});
  await pumpTestApp(
    tester,
    child: const SavedScreen(),
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
  final now = DateTime.now();

  setUp(() {
    resetGetxSingleton();
    FollowedScholarshipsStore.instance.debugReset();
  });

  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    FollowedScholarshipsStore.instance.debugReset();
    resetGetxSingleton();
  });

  testWidgets('Scaffold + AppBar, et « Bourses suivies » en premier',
      (tester) async {
    await _pump(
      tester,
      page: FollowedScholarshipsPage(
        items: [
          _item('chevening', 'Chevening', FollowedDisplayStatus.open,
              closesAt: now.add(const Duration(days: 20))),
        ],
        total: 1,
        globalOptOut: false,
      ),
    );

    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('followed_title')),
        findsOneWidget);
    final section = find.byKey(const ValueKey('followed-scholarships-section'));
    expect(section, findsOneWidget);
    expect(find.text('Chevening'), findsOneWidget);
    // Avant le calendrier des échéances.
    expect(
      tester.getTopLeft(section).dy,
      lessThan(tester.getTopLeft(find.text('deadlines_title')).dy),
    );
    // Le serveur connaît le suivi : la bourse compte comme suivie partout.
    expect(
        Get.find<AppController>().isFollowingScholarship('chevening'), isTrue);
    expect(Get.find<AppController>().serverSupportsFollow, isTrue);
  });

  testWidgets('puces de statut : « Ouvre le … » avant la date d\'ouverture',
      (tester) async {
    await _pump(
      tester,
      page: FollowedScholarshipsPage(
        items: [
          _item('daad', 'DAAD', FollowedDisplayStatus.openingConfirmed,
              opensAt: now.add(const Duration(days: 9))),
          _item('mext', 'MEXT', FollowedDisplayStatus.closed),
        ],
        total: 2,
        globalOptOut: false,
      ),
    );

    expect(find.text('scholarship_status_opens_on'), findsOneWidget);
    expect(find.text('scholarship_status_closed'), findsOneWidget);
    expect(find.text('scholarship_status_open'), findsNothing);
  });

  testWidgets('tri par nom', (tester) async {
    await _pump(
      tester,
      page: FollowedScholarshipsPage(
        items: [
          _item('z', 'Zeta', FollowedDisplayStatus.open),
          _item('a', 'Alpha', FollowedDisplayStatus.closed),
        ],
        total: 2,
        globalOptOut: false,
      ),
    );
    double y(String text) => tester.getTopLeft(find.text(text)).dy;

    // Statut d'abord : l'ouverte avant la close.
    expect(y('Zeta'), lessThan(y('Alpha')));

    await tester.tap(find.byKey(const ValueKey('followed-sort-name')));
    await tester.pumpAndSettle();
    expect(y('Alpha'), lessThan(y('Zeta')));
  });

  testWidgets('glisser pour retirer, puis « Annuler » rétablit',
      (tester) async {
    final api = await _pump(
      tester,
      page: FollowedScholarshipsPage(
        items: [_item('chevening', 'Chevening', FollowedDisplayStatus.open)],
        total: 1,
        globalOptOut: false,
      ),
    );
    final controller = Get.find<AppController>();

    await tester.drag(find.text('Chevening'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Chevening'), findsNothing);
    expect(controller.isFollowingScholarship('chevening'), isFalse);
    verify(() => api.unsubscribeScholarshipAlert('chevening')).called(1);
    expect(find.text('followed_undo'), findsOneWidget);

    await tester.tap(find.text('followed_undo'));
    await tester.pumpAndSettle();
    expect(controller.isFollowingScholarship('chevening'), isTrue);
    expect(find.text('Chevening'), findsOneWidget);

    // Laisse le message se fermer (minuterie de 4 s).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('état vide : appel à l\'action vers l\'onglet Bourses',
      (tester) async {
    await _pump(tester, page: FollowedScholarshipsPage.empty);

    expect(find.text('followed_empty_title'), findsOneWidget);
    expect(find.text('saved_empty_title'), findsNothing,
        reason: 'un seul état vide, celui qui propose une action');

    await tester.tap(find.byKey(const ValueKey('followed-empty-cta')));
    await tester.pumpAndSettle();
    expect(Get.find<AppController>().shellIndex, StudentShellTab.scholarships);
  });

  testWidgets(
      '404 : la section se masque, la bourse suivie reste listée (catalogue)',
      (tester) async {
    await _pump(
      tester,
      error: DioException(
        requestOptions: RequestOptions(path: '/me/followed-scholarships'),
        response: Response<void>(
          requestOptions: RequestOptions(path: '/me/followed-scholarships'),
          statusCode: 404,
        ),
      ),
    );
    final controller = Get.find<AppController>();
    controller.scholarships.add(const ScholarshipModel(
      id: 'eiffel',
      name: LocalizedText(fr: 'Bourse Eiffel', en: 'Eiffel'),
      countryId: 'fra',
      levelEligible: LocalizedText(fr: 'Master', en: 'Master'),
      typeOfFunding: LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: LocalizedText(fr: '', en: ''),
      keyRequirements: [],
      relatedFieldIds: [],
      baseMatch: 50,
    ));
    controller.setScholarshipFollow('eiffel', following: true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('followed-scholarships-section')),
        findsNothing);
    expect(find.text('followed_scholarships_section'), findsOneWidget);
    expect(find.text('Bourse Eiffel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('tri par date limite : la plus proche d\'abord, inconnues à la fin', () {
    final sorted = sortFollowedScholarships(
      [
        _item('none', 'Sans date', FollowedDisplayStatus.forecast),
        _item('late', 'Tard', FollowedDisplayStatus.open,
            closesAt: now.add(const Duration(days: 90))),
        _item('soon', 'Bientôt', FollowedDisplayStatus.open,
            closesAt: now.add(const Duration(days: 5))),
      ],
      FollowedSort.deadline,
    );
    expect(sorted.map((e) => e.id), ['soon', 'late', 'none']);
  });
}
