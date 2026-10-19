// Correctifs 57 (XC-06) — « Nouvelles et offres de KPB ».
//
// Deux risques, deux gardes :
//  - un serveur ANTÉRIEUR ne connaît pas `promotionsEmailOptIn` et refuse un
//    champ inconnu (`forbidNonWhitelisted`) : l'envoyer quand même ferait
//    échouer le PATCH ENTIER en 400. Le champ ne part donc que si le serveur
//    l'a annoncé dans le profil ;
//  - le consentement est NON par défaut : rien ne le coche à la place de
//    l'élève.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/notification_opt_out.dart';
import 'package:karatou/app/core/data/profile_api_codec.dart';
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

Future<(AppController, _CapturingApi)> _controller({
  bool? known,
  bool? pushKnown,
  List<String> disabled = const [],
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  final api = _CapturingApi();
  final base = createTestProfile();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: base.copyWith(
          promotionsEmailOptIn: known,
          promotionsPushOptIn: pushKnown,
          disabledNotificationTypes: disabled,
        ),
      ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  AppConfig.enableRemoteSyncOverride = true;
  return (controller, api);
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

  group('ProfileApiCodec', () {
    Map<String, dynamic> base(Map<String, dynamic> extra) =>
        {'id': 'u1', 'accountType': 'student', ...extra};

    test('serveur antérieur (champ absent) : inconnu, pas « non »', () {
      final profile = ProfileApiCodec.userProfileFromApi(base(const {}),
          fallbackLocale: 'fr');
      expect(profile.promotionsEmailOptIn, isNull);
      expect(profile.serverKnowsPromotions, isFalse);
    });

    test('opt-in push : absent = inconnu (et jamais « oui »)', () {
      final profile = ProfileApiCodec.userProfileFromApi(
          base({'promotionsEmailOptIn': true}),
          fallbackLocale: 'fr');
      expect(profile.promotionsPushOptIn, isNull);
      expect(profile.serverKnowsPromotionsPush, isFalse);
      expect(profile.receivesPromotionsPush, isFalse);
    });

    test('opt-in push : lu tel quel, et la coupure kpb_promotions prime', () {
      final yes = ProfileApiCodec.userProfileFromApi(
          base({'promotionsPushOptIn': true}),
          fallbackLocale: 'fr');
      expect(yes.serverKnowsPromotionsPush, isTrue);
      expect(yes.receivesPromotionsPush, isTrue);
      final cut = ProfileApiCodec.userProfileFromApi(
          base({
            'promotionsPushOptIn': true,
            'disabledNotificationTypes': ['kpb_promotions'],
          }),
          fallbackLocale: 'fr');
      expect(cut.receivesPromotionsPush, isFalse);
      final no = ProfileApiCodec.userProfileFromApi(
          base({'promotionsPushOptIn': false}),
          fallbackLocale: 'fr');
      expect(no.receivesPromotionsPush, isFalse);
    });

    test('serveur à jour : lit la valeur telle quelle', () {
      for (final value in [true, false]) {
        final profile = ProfileApiCodec.userProfileFromApi(
            base({'promotionsEmailOptIn': value}),
            fallbackLocale: 'fr');
        expect(profile.promotionsEmailOptIn, value);
        expect(profile.serverKnowsPromotions, isTrue);
      }
    });
  });

  test('la clé push « kpb_promotions » est connue de cette build', () {
    expect(NotificationOptOutType.kpbPromotions, 'kpb_promotions');
    expect(NotificationOptOutType.all, contains('kpb_promotions'));
  });

  test('serveur antérieur : le PATCH n\'envoie pas le champ (pas de 400)',
      () async {
    final (controller, api) = await _controller();
    await controller
        .updateProfile(controller.profile!.copyWith(fullName: 'Awa D.'));
    expect(api.payloads.single, isNot(contains('promotionsEmailOptIn')));
    // L'interrupteur est sans effet tant que le serveur n'a rien annoncé.
    controller.setPromotionsEmailOptIn(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.payloads, hasLength(1));
    expect(controller.profile!.promotionsEmailOptIn, isNull);
  });

  test('serveur à jour : l\'interrupteur envoie le consentement explicite',
      () async {
    final (controller, api) = await _controller(known: false);
    controller.setPromotionsEmailOptIn(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.payloads.last['promotionsEmailOptIn'], isTrue);
    controller.setPromotionsEmailOptIn(false);
    await Future<void>.delayed(Duration.zero);
    expect(api.payloads.last['promotionsEmailOptIn'], isFalse);
  });

  test('couper les push promotionnels ne touche à aucune autre famille',
      () async {
    final (controller, api) = await _controller(known: false);
    controller.setNotificationTypeOptOut(
        NotificationOptOutType.kpbPromotions, true);
    await Future<void>.delayed(Duration.zero);
    expect(api.payloads.last['disabledNotificationTypes'], ['kpb_promotions']);
  });

  // Chantier juridique 57 (App Store 4.5.4) : push promotionnel en OPT-IN.
  test('opt-in push : serveur antérieur, ni champ envoyé ni effet', () async {
    final (controller, api) = await _controller(known: false);
    await controller
        .updateProfile(controller.profile!.copyWith(fullName: 'Awa D.'));
    expect(api.payloads.last, isNot(contains('promotionsPushOptIn')));
    final before = api.payloads.length;
    controller.setPromotionsPushOptIn(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.payloads, hasLength(before));
    expect(controller.profile!.promotionsPushOptIn, isNull);
  });

  test(
      'opt-in push : accepter l\'envoie et lève la coupure ; refuser le retire',
      () async {
    final (controller, api) = await _controller(
      known: false,
      pushKnown: false,
      disabled: const ['kpb_promotions', 'weekly_digest'],
    );
    controller.setPromotionsPushOptIn(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.payloads.last['promotionsPushOptIn'], isTrue);
    expect(api.payloads.last['disabledNotificationTypes'], ['weekly_digest']);
    expect(controller.profile!.receivesPromotionsPush, isTrue);
    // Le consentement e-mail n'est pas touché.
    expect(api.payloads.last['promotionsEmailOptIn'], isFalse);
    controller.setPromotionsPushOptIn(false);
    await Future<void>.delayed(Duration.zero);
    expect(api.payloads.last['promotionsPushOptIn'], isFalse);
    expect(controller.profile!.receivesPromotionsPush, isFalse);
  });
}
