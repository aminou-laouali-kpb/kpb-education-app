// Sur un téléphone partagé, la déconnexion doit effacer TOUT ce qui appartient
// au compte. Crédits, achats, étapes de feuille de route et marqueurs de
// lecture survivaient au logout et étaient ré-écrits pour le compte suivant.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';

import '../../widget_test_helpers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    setupPlatformChannelMocks();
    AppConfig.enableRemoteSyncOverride = false;
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  test('logout clears every per-user field, persisted snapshot included',
      () async {
    final repository = FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        purchasedCourseIds: const ['course-1'],
        reviewCredits: 3,
        completedRoadmapSteps: const {
          'sch-1': ['step-1'],
        },
        caseLastReadAt: const {'case-1': '2026-10-01T00:00:00.000Z'},
        reviewedCaseIds: const ['case-1'],
      ),
    );
    final controller = AppController(
      repository: repository,
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    expect(controller.reviewCredits, 3);

    await controller.logout();

    expect(controller.profile, isNull);
    expect(controller.reviewCredits, 0);
    expect(controller.purchasedCourseIds, isEmpty);

    final saved = await repository.loadSnapshot();
    expect(saved.reviewCredits, 0);
    expect(saved.purchasedCourseIds, isEmpty);
    expect(saved.completedRoadmapSteps, isEmpty);
    expect(saved.caseLastReadAt, isEmpty);
    expect(saved.reviewedCaseIds, isEmpty);
  });
}
