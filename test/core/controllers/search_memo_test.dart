// Le score de recherche est mémoïsé par état du contrôleur (il était recalculé
// à chaque lecture, O(établissements × formations) plusieurs fois par build).
// Ce test garde l'autre moitié du contrat : un changement d'état l'invalide.

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

  test('recommendations are reused within a state and refreshed after a change',
      () async {
    final controller = AppController(
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

    final first = controller.recommendedScholarships;
    expect(identical(first, controller.recommendedScholarships), isTrue);

    await controller.updateProfile(
      controller.profile!.copyWith(targetCountryIds: const ['usa']),
    );
    expect(identical(first, controller.recommendedScholarships), isFalse);
  });
}
