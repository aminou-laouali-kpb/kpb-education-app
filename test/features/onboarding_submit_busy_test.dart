// « Créer mon compte » — le dernier bouton du tunnel d'inscription.
//
// C'est la toute première chose que fait un testeur TestFlight, et le dernier
// geste avant que l'app ait un utilisateur. Il enchaînait une demande de
// permission de notification puis un PATCH de profil plafonné à QUINZE
// SECONDES, sans rien changer à l'écran et sans jamais se désactiver.
//
// Sur une connexion lente-mais-connectée — le cas courant du public visé, pas
// un cas limite — l'utilisateur voyait donc un écran figé pendant une quinzaine
// de secondes. Il appuyait de nouveau. Chaque appui relançait la demande de
// permission et un second PATCH.
//
// ## Le point qui décide si ce test prouve quelque chose
//
// Le PATCH est bouché sur un `Completer` que le TEST contrôle. Sans lui,
// l'attente est instantanée : le bouton redeviendrait actif dans la même frame
// et les trois assertions passeraient au vert sur un correctif absent. C'est la
// différence entre mesurer l'état occupé et mesurer sa propre impatience.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';

import '../widget_test_helpers.dart';

/// Un client dont le PATCH de profil ne se résout QUE sur ordre du test, et qui
/// compte ses appels.
class _BlockingProfileApi extends MockApiClient {
  final Completer<Map<String, dynamic>> gate =
      Completer<Map<String, dynamic>>();
  int updateProfileCalls = 0;

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) {
    updateProfileCalls++;
    return gate.future;
  }
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

/// Ouvre l'écran DIRECTEMENT sur sa dernière page.
///
/// `initState` restaure les réponses depuis le profil et positionne la page sur
/// `onboardingStep`. On évite ainsi de rejouer trois formulaires — ce n'est pas
/// ce que ce fichier mesure, et une saisie fragile aurait rendu l'échec
/// ambigu.
Future<AppController> _seedOnLastPage(_BlockingProfileApi api) async {
  // FAUX pendant `hydrate`, VRAI ensuite : `hydrate` déclenche sinon une
  // synchronisation complète qui ne se termine jamais sous un client de test.
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: false,
        onboardingStep: 2,
        profile: createTestProfile(),
      ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

FilledButton _cta(WidgetTester tester) => tester.widget<FilledButton>(
      find
          .descendant(
            of: find.byType(OnboardingScreen),
            matching: find.byType(FilledButton),
          )
          .last,
    );

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

  testWidgets(
      'le bouton devient inactif et affiche un indicateur pendant l\'envoi',
      (tester) async {
    final api = _BlockingProfileApi();
    await _seedOnLastPage(api);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('create_account'.tr), findsOneWidget);

    // Le PATCH ne part que si la synchronisation distante est active. On
    // l'allume APRÈS `hydrate`, jamais avant.
    AppConfig.enableRemoteSyncOverride = true;

    await tester.tap(find.text('create_account'.tr));
    await tester.pump();

    expect(
      _cta(tester).onPressed,
      isNull,
      reason: 'Un bouton principal encore actif pendant quinze secondes '
          'd\'attente muette est indiscernable d\'une app plantée. C\'est le '
          'rapport de bug que la build 49 aurait reçu en premier.',
    );
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('create_account'.tr), findsNothing);

    // Libère le PATCH pour ne pas laisser d'attente pendante derrière le test.
    api.gate.complete(<String, dynamic>{});
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('trois appuis de plus ne déclenchent QU\'UN seul PATCH',
      (tester) async {
    final api = _BlockingProfileApi();
    await _seedOnLastPage(api);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pumpAndSettle();

    AppConfig.enableRemoteSyncOverride = true;
    await tester.tap(find.text('create_account'.tr));
    await tester.pump();

    // Le bouton est désactivé : on frappe donc sa POSITION, comme un utilisateur
    // impatient qui ne voit rien bouger.
    final target = tester.getCenter(find.byType(FilledButton).last);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(target);
      await tester.pump();
    }

    expect(
      api.updateProfileCalls,
      1,
      reason: 'Chaque appui supplémentaire relançait un PATCH — et, avec lui, '
          'un second appel à la demande de permission de notification.',
    );

    api.gate.complete(<String, dynamic>{});
    await tester.pump(const Duration(seconds: 1));
  });

  // NOTE SUR CE QUI N'EST PAS ASSERTÉ ICI.
  //
  // Le plan demandait aussi de compter les appels à
  // `PushService.requestPermission()`. Vérifié : la méthode sort
  // immédiatement quand le service n'est pas initialisé, ce qui est le cas dans
  // ce test (le service se teste à part, avec un FCM simulé :
  // `test/core/services/push_service_test.dart`). Une assertion « appelé une
  // fois » serait donc satisfaite par un no-op et ne prouverait rien.
  //
  // Le compte de PATCH ci-dessus couvre la même propriété : les deux appels
  // vivent dans le même corps de `_submit`, protégé par le même drapeau. Un
  // seul PATCH signifie un seul passage, donc une seule demande de permission.
}
