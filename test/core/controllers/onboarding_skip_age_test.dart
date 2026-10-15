// « Passer » l'onboarding V2 dès la page 1 : l'âge et l'accord du tuteur déjà
// saisis sont conservés AVANT toute synchro.
//
// Le cas qui compte : aucun profil local encore (page 1 jamais validée). Sans
// la déclaration, `skipOnboarding()` créait un profil vide — la date de
// naissance tapée était perdue, et le profil poussé puis rapatrié n'avait plus
// d'âge : un mineur déclaré redevenait un profil « sans âge ».

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';

import '../../widget_test_helpers.dart';

class _CapturingApi extends MockApiClient {
  final List<Map<String, dynamic>> payloads = [];

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> payload) async {
    payloads.add(payload);
    return <String, dynamic>{};
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    setupPlatformChannelMocks();
    // `skipOnboarding` navigue vers l'accueil sans contexte.
    Get.testMode = true;
  });
  tearDown(() {
    Get.testMode = false;
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  Future<(AppController, _CapturingApi)> freshController() async {
    AppConfig.enableRemoteSyncOverride = false;
    final api = _CapturingApi();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(localeCode: 'fr', hasCompletedOnboarding: false),
      ),
      apiClient: api,
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    AppConfig.enableRemoteSyncOverride = true;
    return (controller, api);
  }

  final now = DateTime.now();
  final seventeen = DateTime(now.year - 17, now.month, now.day);

  test(
      'mineur sans profil local : la date et l\'accord du tuteur entrent dans '
      'le profil ET partent dans le PATCH', () async {
    final (controller, api) = await freshController();
    expect(controller.profile, isNull);

    controller.skipOnboarding(
      ageDeclaration: OnboardingAgeDeclaration(
        birthDate: seventeen,
        guardianName: 'Awa Diallo',
        guardianContact: '+227 90 00 00 00',
        guardianConsented: true,
      ),
    );
    await pumpEventQueue();

    final profile = controller.profile!;
    expect(controller.onboardingSkipped, isTrue);
    expect(profile.birthDate, seventeen);
    expect(profile.isMinor, isTrue);
    expect(profile.guardianConsentedAt, isNotNull);
    expect(profile.guardianName, 'Awa Diallo');

    expect(api.payloads, hasLength(1));
    final payload = api.payloads.single;
    expect(payload['birthDate'], seventeen.toIso8601String());
    expect(payload['guardianName'], 'Awa Diallo');
    expect(payload['guardianContact'], '+227 90 00 00 00');
    expect(payload['guardianConsentedAt'], isNotNull);
  });

  test('mineur SANS accord : l\'âge est gardé, aucun accord inventé', () async {
    final (controller, api) = await freshController();

    controller.skipOnboarding(
      ageDeclaration: OnboardingAgeDeclaration(birthDate: seventeen),
    );
    await pumpEventQueue();

    expect(controller.profile!.birthDate, seventeen);
    expect(controller.profile!.guardianConsentedAt, isNull);
    final payload = api.payloads.single;
    expect(payload['birthDate'], seventeen.toIso8601String());
    expect(payload, isNot(contains('guardianConsentedAt')));
    expect(payload, isNot(contains('guardianName')));
  });

  test('majeur : la date est gardée, rien du tuteur ne voyage', () async {
    final (controller, api) = await freshController();
    final adult = DateTime(now.year - 20, now.month, now.day);

    controller.skipOnboarding(
      ageDeclaration: OnboardingAgeDeclaration(
        birthDate: adult,
        guardianName: 'X',
        guardianContact: 'Y',
        guardianConsented: true,
      ),
    );
    await pumpEventQueue();

    expect(controller.profile!.birthDate, adult);
    expect(controller.profile!.guardianConsentedAt, isNull);
    expect(api.payloads.single, isNot(contains('guardianName')));
  });

  test('ancien parcours (sans déclaration) : comportement inchangé', () async {
    final (controller, api) = await freshController();

    controller.skipOnboarding();
    await pumpEventQueue();

    expect(controller.onboardingSkipped, isTrue);
    expect(controller.hasCompletedOnboarding, isTrue);
    expect(controller.profile!.birthDate, isNull);
    // Aucun PATCH immédiat : c'est la synchro suivante qui s'en charge, comme
    // avant.
    expect(api.payloads, isEmpty);
  });
}
