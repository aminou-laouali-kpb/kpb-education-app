// Fiche d'une bourse (chantier G) :
//   · « Suivre » remplace le marque-page ;
//   · « Me prévenir à l'ouverture » n'apparaît que si le serveur sert le bloc
//     `follow` (backend du chantier C) et que l'élève suit la bourse ; il
//     envoie PATCH notifyOpening, et se masque sur un 404 ;
//   · la ligne de statut ne dit jamais « Ouverte » avant la date d'ouverture.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/kpb_toast.dart';
import 'package:karatou/app/features/scholarships/scholarship_detail_screen.dart';

import '../../widget_test_helpers.dart';

Map<String, dynamic> _json({
  Map<String, dynamic>? follow,
  Map<String, dynamic>? cycle,
}) =>
    <String, dynamic>{
      'id': 'chevening',
      'title': 'Chevening',
      'countryName': 'Royaume-Uni',
      'fundingType': 'fully_funded',
      'description': '',
      'advantages': <String>[],
      'eligibility': <String>[],
      'level': 'Master',
      'deadlineLabel': '',
      'applicationUrl': '',
      'tags': <String>[],
      'matchScore': 0,
      if (follow != null) 'follow': follow,
      if (cycle != null) 'currentCycle': cycle,
    };

Future<MockApiClient> _pump(
  WidgetTester tester,
  LiveScholarshipModel scholarship, {
  bool saved = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final mock = MockApiClient();
  when(() => mock.fetchLiveScholarshipDetailWithFallback(
        scholarshipId: any(named: 'scholarshipId'),
        lang: any(named: 'lang'),
        initial: any(named: 'initial'),
      )).thenAnswer((_) async => scholarship);
  when(() => mock.fetchScholarshipAlerts()).thenAnswer((_) async => <String>{});
  when(() => mock.getSuccessLabAccess()).thenAnswer(
    (_) async => <String, dynamic>{'enabled': false, 'reasons': <String>[]},
  );
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        savedItems: saved
            ? const [
                SavedItem(
                  type: SavedItemType.scholarship,
                  itemId: 'chevening',
                ),
              ]
            : const [],
      ),
    ),
    apiClient: mock,
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = false;
  Get.put<AppController>(controller, permanent: true);

  await tester.pumpWidget(GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr'),
    fallbackLocale: const Locale('fr'),
    home: ScholarshipDetailScreen(
      scholarshipId: scholarship.id,
      initialScholarship: scholarship,
      apiClient: mock,
    ),
  ));
  await tester.pumpAndSettle();
  return mock;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  final notify = find.byKey(const ValueKey('scholarship-notify-opening'));

  testWidgets('« Suivre » remplace le marque-page de la fiche', (tester) async {
    await _pump(tester, LiveScholarshipModel.fromJson(_json()));

    expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
    expect(find.text('Suivre'), findsOneWidget);

    await tester.tap(find.text('Suivre'));
    await tester.pumpAndSettle();
    expect(find.text('Suivie'), findsOneWidget);
    expect(
      Get.find<AppController>().isSaved(SavedItemType.scholarship, 'chevening'),
      isTrue,
    );
  });

  testWidgets('backend sans bloc `follow` : pas d\'interrupteur d\'ouverture',
      (tester) async {
    await _pump(tester, LiveScholarshipModel.fromJson(_json()), saved: true);
    expect(find.text('Suivie'), findsOneWidget);
    expect(notify, findsNothing);
  });

  testWidgets('interrupteur : visible quand suivie, PATCH notifyOpening',
      (tester) async {
    final scholarship = LiveScholarshipModel.fromJson(_json(
      follow: <String, dynamic>{
        'following': true,
        'viaFavorite': true,
        'viaAlert': true,
        'notifyOpening': true,
        'globalOptOut': false,
      },
    ));
    final mock = await _pump(tester, scholarship, saved: true);
    when(() => mock.updateScholarshipOpeningAlert(
          any(),
          notifyOpening: any(named: 'notifyOpening'),
        )).thenAnswer((_) async => <String, dynamic>{
          'scholarshipId': 'chevening',
          'following': true,
          'notifyOpening': false,
        });

    expect(notify, findsOneWidget);
    expect(find.text('Me prévenir à l\'ouverture'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(notify).value, isTrue);

    await tester.tap(notify);
    await tester.pumpAndSettle();

    verify(() => mock.updateScholarshipOpeningAlert(
          'chevening',
          notifyOpening: false,
        )).called(1);
    expect(tester.widget<SwitchListTile>(notify).value, isFalse);
  });

  testWidgets('PATCH en 404 : l\'interrupteur se masque, rien ne casse',
      (tester) async {
    final scholarship = LiveScholarshipModel.fromJson(_json(
      follow: <String, dynamic>{'following': true, 'notifyOpening': true},
    ));
    final mock = await _pump(tester, scholarship, saved: true);
    when(() => mock.updateScholarshipOpeningAlert(
          any(),
          notifyOpening: any(named: 'notifyOpening'),
        )).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/me/scholarship-alerts/chevening'),
      response: Response<void>(
        requestOptions:
            RequestOptions(path: '/me/scholarship-alerts/chevening'),
        statusCode: 404,
      ),
    ));

    await tester.tap(notify);
    await tester.pumpAndSettle();

    expect(notify, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'PATCH en échec réseau : l\'interrupteur revient, KpbToast d\'erreur '
      'avec « Réessayer »', (tester) async {
    final scholarship = LiveScholarshipModel.fromJson(_json(
      follow: <String, dynamic>{'following': true, 'notifyOpening': true},
    ));
    final mock = await _pump(tester, scholarship, saved: true);
    when(() => mock.updateScholarshipOpeningAlert(
          any(),
          notifyOpening: any(named: 'notifyOpening'),
        )).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/me/scholarship-alerts/chevening'),
      type: DioExceptionType.connectionError,
    ));

    await tester.tap(notify);
    await tester.pumpAndSettle();

    // Le choix n'a pas été enregistré : l'interrupteur dit la vérité.
    expect(tester.widget<SwitchListTile>(notify).value, isTrue);
    final toast = tester.widget<KpbToastBody>(find.byType(KpbToastBody));
    expect(toast.kind, KpbToastKind.error);
    expect(find.text('Réessayer'), findsOneWidget);

    when(() => mock.updateScholarshipOpeningAlert(
          any(),
          notifyOpening: any(named: 'notifyOpening'),
        )).thenAnswer((_) async => <String, dynamic>{
          'scholarshipId': 'chevening',
          'following': true,
          'notifyOpening': false,
        });
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(notify).value, isFalse);
    expect(tester.takeException(), isNull);

    // Laisse le bandeau se fermer.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });

  testWidgets('cycle `open` dont l\'ouverture est à venir : « Ouvre le … »',
      (tester) async {
    final now = DateTime.now();
    await _pump(
      tester,
      LiveScholarshipModel.fromJson(_json(cycle: <String, dynamic>{
        'id': 'c1',
        'academicYear': '2027-2028',
        'status': 'open',
        'dateConfidence': 'confirmed',
        'opensAt': now.add(const Duration(days: 4)).toIso8601String(),
        'closesAt': now.add(const Duration(days: 60)).toIso8601String(),
      })),
    );

    expect(find.textContaining('Ouvre le'), findsOneWidget);
    expect(find.textContaining('Ouverte'), findsNothing);
  });

  testWidgets('cycle réellement ouvert : « Ouverte · clôture le … »',
      (tester) async {
    final now = DateTime.now();
    await _pump(
      tester,
      LiveScholarshipModel.fromJson(_json(cycle: <String, dynamic>{
        'id': 'c1',
        'academicYear': '2027-2028',
        'status': 'open',
        'dateConfidence': 'confirmed',
        'opensAt': now.subtract(const Duration(days: 4)).toIso8601String(),
        'closesAt': now.add(const Duration(days: 60)).toIso8601String(),
      })),
    );

    expect(find.textContaining('Ouverte · clôture le'), findsOneWidget);
  });
}
