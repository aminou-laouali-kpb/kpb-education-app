// Revue avant la 58 (constats 17, 22, 12, 15) : la fin de connexion.
//
// 17 — Une lecture du profil qui ÉCHOUE n'est jamais « pas de profil ». Avant,
//      `syncRemoteData` avalait l'erreur, le profil restait null, l'élève qui
//      avait déjà un compte partait à l'onboarding et ses réponses écrasaient
//      son profil serveur.
// 22 — La connexion n'attend plus le catalogue : seulement le profil.
// 12 — Un compte connecté ne devient jamais invité.
// 15 — Déconnexion et mode invité repartent de l'Accueil.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/navigation/shell_tabs.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';

import '../../widget_test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Un compte connecté dont le profil répond selon [profile], et dont TOUT le
/// reste (dossiers, catalogue) ne répond jamais — comme une 3G qui traîne.
class _AccountApi extends MockApiClient {
  _AccountApi(this.profile);

  final Future<Map<String, dynamic>> Function() profile;
  int profileReads = 0;
  final List<Map<String, dynamic>> patches = [];

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> getProfile() {
    profileReads++;
    return profile();
  }

  @override
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> payload) async {
    patches.add(payload);
    return <String, dynamic>{};
  }

  @override
  Future<List<dynamic>> listCases() => Completer<List<dynamic>>().future;

  @override
  Future<CatalogListPayload> listCatalogEnvelope(String resource) =>
      Completer<CatalogListPayload>().future;
}

DioException _timeout() => DioException(
      requestOptions: RequestOptions(path: '/profiles/me'),
      type: DioExceptionType.connectionTimeout,
    );

DioException _status(int code) => DioException(
      requestOptions: RequestOptions(path: '/profiles/me'),
      type: DioExceptionType.badResponse,
      response: Response<void>(
        requestOptions: RequestOptions(path: '/profiles/me'),
        statusCode: code,
      ),
    );

const _completeProfile = <String, dynamic>{
  'id': 'user-42',
  'fullName': 'Awa Diallo',
  'email': 'awa@example.com',
  'currentLevel': 'terminale',
  'fieldIds': ['d01', 'd03'],
  'preferredLanguage': 'fr',
};

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

  /// Nouvel appareil : rien en cache, on vient de se connecter.
  Future<AppController> freshDevice(_AccountApi api) async {
    AppConfig.enableRemoteSyncOverride = false;
    final controller = AppController(
      repository: FakeRepository(
          snapshot:
              AppSnapshot(localeCode: 'fr', hasCompletedOnboarding: false)),
      apiClient: api,
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    AppConfig.enableRemoteSyncOverride = true;
    return controller;
  }

  group('finishAuthSession — lecture du profil', () {
    test(
        'échec réseau : compte « indisponible », pas d\'onboarding, aucune '
        'écriture', () async {
      final api = _AccountApi(() => Future.error(_timeout()));
      final controller = await freshDevice(api);

      final outcome = await controller.finishAuthSession();

      expect(outcome, AuthSessionOutcome.accountUnavailable);
      expect(controller.accountLoadFailed, isTrue);
      expect(controller.profile, isNull);
      expect(controller.hasCompletedOnboarding, isFalse);
      expect(api.patches, isEmpty, reason: 'rien n\'est poussé au serveur');
      expect(api.profileReads, 3, reason: 'retryTransient : trois essais');
    });

    test('serveur en panne (503) : même chose', () async {
      final api = _AccountApi(() => Future.error(_status(503)));
      final controller = await freshDevice(api);

      expect(await controller.finishAuthSession(),
          AuthSessionOutcome.accountUnavailable);
      expect(controller.hasCompletedOnboarding, isFalse);
    });

    test('404 : pas de profil, l\'onboarding est légitime', () async {
      final api = _AccountApi(() => Future.error(_status(404)));
      final controller = await freshDevice(api);

      expect(await controller.finishAuthSession(), AuthSessionOutcome.ready);
      expect(controller.accountLoadFailed, isFalse);
      expect(controller.hasCompletedOnboarding, isFalse);
    });

    test(
        'compte existant : prêt dès le profil lu, sans attendre dossiers ni '
        'catalogue', () async {
      final api = _AccountApi(() async => Map.of(_completeProfile));
      final controller = await freshDevice(api);

      // Avant : finishAuthSession attendait toute la synchro (dossiers,
      // catalogue) — ici, elle ne finit jamais.
      final outcome = await controller
          .finishAuthSession()
          .timeout(const Duration(seconds: 5));

      expect(outcome, AuthSessionOutcome.ready);
      expect(controller.profile?.id, 'user-42');
      expect(controller.hasCompletedOnboarding, isTrue);
    });

    test('une nouvelle tentative réussie lève l\'état « indisponible »',
        () async {
      var fail = true;
      final api = _AccountApi(() =>
          fail ? Future.error(_timeout()) : Future.value(_completeProfile));
      final controller = await freshDevice(api);

      expect(await controller.finishAuthSession(),
          AuthSessionOutcome.accountUnavailable);
      fail = false;
      expect(
          await controller.finishAuthSession().timeout(
                const Duration(seconds: 5),
              ),
          AuthSessionOutcome.ready);
      expect(controller.accountLoadFailed, isFalse);
      expect(controller.hasCompletedOnboarding, isTrue);
    });
  });

  group('mode invité et onglet', () {
    Future<AppController> signedOutController({int tab = 0}) async {
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
      controller.goToTab(tab);
      return controller;
    }

    test('un compte connecté ne devient jamais invité', () async {
      final auth = _MockAuthService();
      when(() => auth.isLoggedIn).thenReturn(true);
      Get.put<AuthService>(auth, permanent: true);
      final controller = await signedOutController();

      controller.enterGuestMode();

      expect(controller.isGuestMode, isFalse);
      expect(controller.profile, isNotNull);
    });

    test('la déconnexion depuis Profil ramène l\'onglet à l\'Accueil',
        () async {
      final controller =
          await signedOutController(tab: StudentShellTab.count - 1);
      expect(controller.shellIndex, StudentShellTab.count - 1);

      await controller.logout();

      expect(controller.shellIndex, 0);
    });

    test('« Explorer sans compte » s\'ouvre sur l\'Accueil', () async {
      final controller =
          await signedOutController(tab: StudentShellTab.count - 1);

      controller.enterGuestMode();

      expect(controller.isGuestMode, isTrue);
      expect(controller.shellIndex, 0);
    });
  });
}
