// Audit 57, F24 — la synchro réécrivait les consentements.
//
// `syncRemoteData` envoyait à CHAQUE lancement la copie locale de
// `promotionsEmailOptIn` / `promotionsPushOptIn` (et des autres
// consentements). Un désabonnement par le lien de l'e-mail, ou un refus sur un
// autre téléphone, était donc annulé au lancement suivant, et le serveur
// horodatait un consentement jamais redonné.
//
// Ces tests passent par la VRAIE synchro (Hive temporaire, serveur simulé qui
// applique le PATCH comme le backend : une clé absente ne change rien).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/data/profile_consent_fields.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/repositories/local_app_repository.dart';
import 'package:karatou/app/core/services/case_message_outbox.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';
import 'package:karatou/app/core/services/connectivity_service.dart';

import '../../widget_test_helpers.dart';

/// Le serveur : un profil, et le PATCH appliqué clé par clé.
class _Server {
  _Server(this.state);

  final Map<String, dynamic> state;

  /// Nombre de passages `false → true` de l'opt-in e-mail, c.-à-d. de preuves
  /// de consentement horodatées par le serveur.
  int emailConsentStamps = 0;
  int pushConsentStamps = 0;

  void apply(Map<String, dynamic> patch) {
    if (patch['promotionsEmailOptIn'] == true &&
        state['promotionsEmailOptIn'] != true) {
      emailConsentStamps++;
    }
    if (patch['promotionsPushOptIn'] == true &&
        state['promotionsPushOptIn'] != true) {
      pushConsentStamps++;
    }
    state.addAll(patch);
  }
}

class _Api extends MockApiClient {
  _Api(this.server);

  final _Server server;
  final List<Map<String, dynamic>> patches = [];

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> payload) async {
    patches.add(Map<String, dynamic>.of(payload));
    server.apply(payload);
    return Map<String, dynamic>.of(server.state);
  }

  @override
  Future<Map<String, dynamic>> getProfile() async =>
      Map<String, dynamic>.of(server.state);

  @override
  Future<List<dynamic>> listCases() async => const <dynamic>[];

  @override
  Future<List<dynamic>> listSavedItems() async => const <dynamic>[];

  @override
  Future<CatalogListPayload> listCatalogEnvelope(String resource) async =>
      const CatalogListPayload(items: [], source: CatalogDataSource.database);

  @override
  Future<List<dynamic>> listContent(String resource) async => const <dynamic>[];
}

Map<String, dynamic> _serverProfile({
  bool email = true,
  bool push = true,
  bool newsletter = true,
  List<String> disabled = const [],
}) =>
    <String, dynamic>{
      'id': 'test-user-1',
      'accountType': 'student',
      'fullName': 'Test User',
      'preferredLanguage': 'fr',
      'countryOfResidence': 'CI',
      'currentLevel': 'Licence',
      'scholarshipNewsletterOptIn': newsletter,
      'promotionsEmailOptIn': email,
      'promotionsPushOptIn': push,
      'disabledNotificationTypes': disabled,
    };

/// Un appareil connecté dont la copie locale dit « oui » partout.
Future<(AppController, _Api, FakeRepository)> _device(
  _Server server, {
  FakeRepository? repository,
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  final repo = repository ??
      FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile().copyWith(
            wantsScholarshipNewsletter: true,
            promotionsEmailOptIn: true,
            promotionsPushOptIn: true,
          ),
        ),
      );
  final api = _Api(server);
  final controller = AppController(repository: repo, apiClient: api);
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  AppConfig.enableRemoteSyncOverride = true;
  return (controller, api, repo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    final dir = await Directory.systemTemp.createTemp('hive_consent_sync');
    Hive.init(dir.path);
    await CaseMessageOutbox.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  setUp(() async {
    resetGetxSingleton();
    setupPlatformChannelMocks();
    ConnectivityService.instance.debugSetOnline(true);
    CatalogCacheService.resetForTests();
    await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
    await CatalogCacheService.init();
  });

  tearDown(() {
    ConnectivityService.instance.debugSetOnline(true);
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  test(
      '(a) désabonnement par le lien de l\'e-mail puis synchro : reste non, '
      'et la copie locale passe à non', () async {
    // Le lien « Se désabonner » n'a touché que la base.
    final server = _Server(_serverProfile(email: false));
    final (controller, api, _) = await _device(server);

    await controller.syncRemoteData(force: true);

    expect(server.state['promotionsEmailOptIn'], isFalse,
        reason: 'la synchro ne doit pas réabonner l\'élève');
    expect(server.emailConsentStamps, 0,
        reason: 'aucun faux consentement horodaté');
    expect(controller.profile!.promotionsEmailOptIn, isFalse,
        reason: 'la valeur du serveur remplace la copie locale');
    // Et les synchros suivantes non plus.
    await controller.syncRemoteData(force: true);
    expect(server.state['promotionsEmailOptIn'], isFalse);
    // Audit build 57, T8-07 : sans geste local, la synchro n'écrit rien.
    expect(api.patches, isEmpty);
  });

  test(
      '(b) bascule hors ligne : envoyée une seule fois au retour du réseau, '
      'et survit au redémarrage', () async {
    final server = _Server(_serverProfile());
    final (controller, api, repo) = await _device(server);

    ConnectivityService.instance.debugSetOnline(false);
    controller.setPromotionsEmailOptIn(false);
    await Future<void>.delayed(Duration.zero);
    expect(api.patches, isEmpty, reason: 'hors ligne : rien ne part');
    expect(server.state['promotionsEmailOptIn'], isTrue);

    // Redémarrage à froid : le geste en attente est relu du disque.
    resetGetxSingleton();
    final (restarted, api2, _) = await _device(server, repository: repo);
    expect(restarted.profile!.promotionsEmailOptIn, isFalse);

    ConnectivityService.instance.debugSetOnline(true);
    await restarted.syncRemoteData(force: true);
    await restarted.syncRemoteData(force: true);

    final withKey =
        api2.patches.where((p) => p.containsKey('promotionsEmailOptIn'));
    expect(withKey, hasLength(1), reason: 'envoyé une fois, pas à chaque fois');
    expect(withKey.single['promotionsEmailOptIn'], isFalse);
    expect(server.state['promotionsEmailOptIn'], isFalse);
    expect(restarted.profile!.promotionsEmailOptIn, isFalse);
  });

  test('(c) deux appareils : refus sur A, synchro de B → refus gardé',
      () async {
    final server = _Server(_serverProfile());

    // Téléphone A : refuse le push promotionnel, coupe le récap hebdo et la
    // lettre d'information.
    final (a, _, _) = await _device(server);
    a.setPromotionsPushOptIn(false);
    a.setNotificationTypeOptOut('weekly_digest', true);
    a.setNewsletterOptIn(false);
    await Future<void>.delayed(Duration.zero);
    expect(server.state['promotionsPushOptIn'], isFalse);
    expect(server.state['disabledNotificationTypes'], ['weekly_digest']);
    expect(server.state['scholarshipNewsletterOptIn'], isFalse);

    // Téléphone B : copie locale périmée (« oui » partout, aucune coupure).
    resetGetxSingleton();
    final (b, _, _) = await _device(server);
    await b.syncRemoteData(force: true);

    expect(server.state['promotionsPushOptIn'], isFalse);
    expect(server.pushConsentStamps, 0);
    expect(server.state['disabledNotificationTypes'], ['weekly_digest']);
    expect(server.state['scholarshipNewsletterOptIn'], isFalse);
    expect(b.profile!.promotionsPushOptIn, isFalse);
    expect(b.profile!.disabledNotificationTypes, ['weekly_digest']);
    expect(b.profile!.wantsScholarshipNewsletter, isFalse);
  });

  test(
      '(d) un PATCH de synchro sans geste ne contient aucune clé de '
      'consentement', () async {
    final server = _Server(_serverProfile());
    final (controller, api, _) = await _device(server);
    // Accord IA et accord du représentant connus localement.
    controller.profile = controller.profile!.copyWith(
      aiConsentedAt: DateTime(2026, 9, 1),
      guardianConsentedAt: DateTime(2026, 9, 1),
    );

    // Un geste fait hors ligne reste en attente : au retour du réseau, la
    // synchro pousse les champs ordinaires, et JAMAIS un consentement non
    // touché.
    ConnectivityService.instance.debugSetOnline(false);
    await controller
        .updateProfile(controller.profile!.copyWith(fullName: 'Test User'));
    ConnectivityService.instance.debugSetOnline(true);
    await controller.syncRemoteData(force: true);

    expect(api.patches, isNotEmpty,
        reason: 'un geste en attente pousse les champs ordinaires');
    for (final patch in api.patches) {
      for (final key in ProfileConsentFields.all) {
        expect(patch, isNot(contains(key)), reason: key);
      }
      expect(patch['fullName'], 'Test User',
          reason: 'les champs ordinaires partent toujours');
    }
  });

  // Audit build 57, T8-07 : chaque synchro réécrivait tout le profil serveur
  // avec la copie du téléphone avant de le relire.
  test('(e) sans geste local : aucun PATCH, la valeur du serveur est adoptée',
      () async {
    final server = _Server(_serverProfile());
    server.state['fullName'] = 'Nom corrigé par le conseiller';
    final (controller, api, _) = await _device(server);

    await controller.syncRemoteData(force: true);
    await controller.syncRemoteData(force: true);

    expect(api.patches, isEmpty);
    expect(controller.profile!.fullName, 'Nom corrigé par le conseiller');
  });

  test('(f) avec un geste en attente : PATCH puis relecture', () async {
    final server = _Server(_serverProfile());
    final (controller, api, _) = await _device(server);

    ConnectivityService.instance.debugSetOnline(false);
    await controller
        .updateProfile(controller.profile!.copyWith(fullName: 'Awa D.'));
    expect(api.patches, isEmpty, reason: 'hors ligne : rien ne part');
    ConnectivityService.instance.debugSetOnline(true);

    await controller.syncRemoteData(force: true);

    expect(api.patches, hasLength(1));
    expect(api.patches.single['fullName'], 'Awa D.');
    expect(server.state['fullName'], 'Awa D.');
    expect(controller.profile!.fullName, 'Awa D.');
    // Accusé : la synchro suivante n'écrit plus rien.
    await controller.syncRemoteData(force: true);
    expect(api.patches, hasLength(1));
  });

  test('un geste part bien, avec la clé seule de ce consentement', () async {
    final server = _Server(_serverProfile(email: false, push: false));
    final (controller, api, _) = await _device(
      server,
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile().copyWith(
            promotionsEmailOptIn: false,
            promotionsPushOptIn: false,
          ),
        ),
      ),
    );
    controller.setPromotionsEmailOptIn(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.patches.single['promotionsEmailOptIn'], isTrue);
    expect(api.patches.single, isNot(contains('promotionsPushOptIn')));
    expect(server.emailConsentStamps, 1);
    // Accusé : la synchro suivante ne le renvoie plus (ni rien d'autre : sans
    // geste en attente, elle n'écrit plus le profil).
    await controller.syncRemoteData(force: true);
    expect(api.patches, hasLength(1));
  });

  test('l\'onboarding ne remplace pas les choix qu\'il ne montre pas',
      () async {
    final server = _Server(_serverProfile(disabled: const ['weekly_digest']));
    final (controller, api, _) = await _device(
      server,
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile().copyWith(
            promotionsEmailOptIn: true,
            disabledNotificationTypes: const ['weekly_digest'],
          ),
        ),
      ),
    );
    // Le profil reconstruit par l'onboarding ne porte ni l'opt-in ni les
    // coupures.
    final rebuilt = UserProfile(
      id: 'test-user-1',
      accountType: AccountType.student,
      fullName: 'Test User',
      email: '',
      phone: '',
      whatsApp: '',
      countryOfResidence: 'CI',
      preferredLanguage: 'fr',
    );
    await controller.completeOnboardingSynced(rebuilt);

    expect(controller.profile!.promotionsEmailOptIn, isTrue);
    expect(controller.profile!.disabledNotificationTypes, ['weekly_digest']);
    for (final patch in api.patches) {
      expect(patch, isNot(contains('disabledNotificationTypes')));
      expect(patch, isNot(contains('promotionsEmailOptIn')));
    }
    expect(server.state['disabledNotificationTypes'], ['weekly_digest']);
  });

  test('les gestes en attente survivent au disque (SharedPreferences)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = await LocalAppRepository.create();
    await repository.saveSnapshot(AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(),
      profileNeedsPush: true,
      pendingConsentKeys: const {ProfileConsentFields.promotionsEmail},
    ));
    final reloaded = await (await LocalAppRepository.create()).loadSnapshot();
    expect(reloaded.pendingConsentKeys, {ProfileConsentFields.promotionsEmail});
  });

  group('ProfileConsentFields', () {
    test('changed : seules les valeurs qui bougent', () {
      final p = createTestProfile();
      expect(ProfileConsentFields.changed(p, p), isEmpty);
      expect(
        ProfileConsentFields.changed(p, p.copyWith(promotionsEmailOptIn: true)),
        {ProfileConsentFields.promotionsEmail},
      );
      // L'ordre des coupures n'est pas un changement.
      final ab = p.copyWith(disabledNotificationTypes: const ['a', 'b']);
      final ba = p.copyWith(disabledNotificationTypes: const ['b', 'a']);
      expect(ProfileConsentFields.changed(ab, ba), isEmpty);
    });

    test('changed depuis aucun profil : les valeurs par défaut ne comptent pas',
        () {
      final fresh = UserProfile(
        id: 'x',
        accountType: AccountType.student,
        fullName: '',
        email: '',
        phone: '',
        whatsApp: '',
        countryOfResidence: '',
        preferredLanguage: 'fr',
      );
      expect(ProfileConsentFields.changed(null, fresh), isEmpty);
      expect(
        ProfileConsentFields.changed(
            null, fresh.copyWith(wantsScholarshipNewsletter: true)),
        {ProfileConsentFields.newsletter},
      );
    });
  });
}
