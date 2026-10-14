// Le calendrier d'échéances ne montre que ce que l'élève SUIT (chantier G),
// et chaque ligne de bourse ouvre la fiche de SA bourse — elle renvoyait
// vers le calendrier lui-même (`/deadlines`), une boucle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/followed_scholarships_store.dart';
import 'package:karatou/app/features/deadlines/deadline_calendar_screen.dart';

import '../../widget_test_helpers.dart';

ScholarshipModel _sheet(String id, String name) => ScholarshipModel(
      id: id,
      name: LocalizedText(fr: name, en: name),
      countryId: 'fra',
      levelEligible: const LocalizedText(fr: 'Master', en: 'Master'),
      typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: const LocalizedText(fr: '', en: ''),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 50,
      deadlineAt: DateTime.now().add(const Duration(days: 40)),
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    setupPlatformChannelMocks();
    FollowedScholarshipsStore.instance.debugReset();
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    FollowedScholarshipsStore.instance.debugReset();
    resetGetxSingleton();
  });

  testWidgets(
      'seules les bourses suivies, et chaque ligne ouvre la fiche de sa bourse',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          savedItems: const [
            SavedItem(type: SavedItemType.scholarship, itemId: 'eiffel'),
          ],
        ),
      ),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    controller.scholarships
      ..clear()
      ..addAll([
        _sheet('eiffel', 'Bourse Eiffel'),
        _sheet('chevening', 'Chevening'),
      ]);

    await tester.pumpWidget(GetMaterialApp(
      home: const DeadlineCalendarScreen(),
      getPages: [
        GetPage(
          name: '/scholarships/:id',
          page: () => Text('detail:${Get.parameters['id']}'),
        ),
        GetPage(
          name: '/deadlines',
          page: () => const Text('calendrier encore'),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bourse Eiffel'), findsOneWidget);
    expect(find.text('Chevening'), findsNothing,
        reason: 'une bourse non suivie n\'a rien à faire dans MES échéances');

    await tester.tap(find.text('Bourse Eiffel'));
    await tester.pumpAndSettle();
    expect(find.text('detail:eiffel'), findsOneWidget);
    expect(find.text('calendrier encore'), findsNothing);
  });
}
