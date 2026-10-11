// Plainte Android : « la partie où on doit ajouter l'email n'apparaît pas ».
//
// Le profil local d'une étudiante n'avait pas d'email (créé par « Passer »
// l'onboarding). L'app envoyait quand même `email: ''` dans le PATCH ; le
// serveur le validait `@IsEmail()` et rejetait la requête ENTIÈRE en 400. Le
// patch restait en attente, `syncRemoteData` sautait donc à jamais le
// rapatriement du profil serveur — qui, lui, a toujours l'email du compte.
//
// L'email est l'identité de connexion : le serveur ne l'écrit jamais via ce
// PATCH. Il n'a rien à y faire.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
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
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  for (final email in ['', 'suzane@gmail', 'test@example.com']) {
    test(
        'le PATCH de profil n\'envoie jamais l\'email (email=${email.isEmpty ? 'vide' : email})',
        () async {
      AppConfig.enableRemoteSyncOverride = false;
      final api = _CapturingApi();
      final controller = AppController(
        repository: FakeRepository(
          snapshot: AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(email: email),
          ),
        ),
        apiClient: api,
      );
      await controller.hydrate();
      Get.put<AppController>(controller, permanent: true);

      AppConfig.enableRemoteSyncOverride = true;
      await controller
          .updateProfile(controller.profile!.copyWith(fullName: 'Suzane S.'));

      expect(api.payloads, hasLength(1));
      expect(api.payloads.single, isNot(contains('email')));
      expect(api.payloads.single['fullName'], 'Suzane S.');
    });
  }

  // Téléphone et WhatsApp ne sont pas persistés localement (RGPD) : après un
  // redémarrage à froid le profil local les a vides. Le PATCH les envoyait
  // quand même, et le serveur effaçait le numéro WhatsApp.
  test('le PATCH n\'envoie pas un téléphone ou un WhatsApp vides', () async {
    AppConfig.enableRemoteSyncOverride = false;
    final api = _CapturingApi();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(phone: '').copyWith(whatsApp: ''),
        ),
      ),
      apiClient: api,
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);

    AppConfig.enableRemoteSyncOverride = true;
    await controller
        .updateProfile(controller.profile!.copyWith(fullName: 'Awa D.'));

    expect(api.payloads, hasLength(1));
    expect(api.payloads.single, isNot(contains('whatsApp')));
    expect(api.payloads.single, isNot(contains('phone')));
  });
}
