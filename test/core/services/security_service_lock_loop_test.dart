// Le verrou d'application ne doit s'armer que sur un VRAI passage en
// arrière-plan — et surtout pas sur le retour de sa propre invite biométrique.
//
// ## Ce que ce fichier empêche de revenir
//
// Sur l'enregistrement d'écran d'un testeur (15/08/2026), l'overlay
// « Application Verrouillée » réapparaissait toutes les **1,61 s**, sans fin
// (écarts 1,57–1,63 s mesurés sur 18 s de vidéo). Une régularité métronomique
// comme celle-là n'est pas un geste d'utilisateur : c'était une boucle.
//
// Le mécanisme : on armait le verrou sur chaque `resumed`, or l'invite
// biométrique est elle-même un passage hors de l'app, donc sa fermeture produit
// un `resumed`. Quand il arrivait, `_isAuthenticating` venait d'être remis à
// faux par le `finally` de `authenticate()`, et la route `/app_lock` venait
// d'être dépilée par le succès. Les deux gardes tombaient ensemble et le verrou
// se reposait : **déverrouiller causait le prochain verrouillage.**
//
// ## Pourquoi ces tests COMPTENT les demandes
//
// Un test qui vérifie « le verrou apparaît » reste vert sur ce défaut : le
// défaut est justement qu'il apparaît, encore et encore. Seul le NOMBRE de
// demandes distingue le bon comportement de la boucle. C'est pour ça que
// `SecurityService.showLockScreenOverride` existe — et c'est aussi la première
// couverture de cette classe, qui n'en avait aucune.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/services/security_service.dart';

import '../../widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var lockRequests = 0;

  setUp(() {
    setupPlatformChannelMocks();
    lockRequests = 0;
    SecurityService.showLockScreenOverride = () => lockRequests++;
  });

  tearDown(() {
    SecurityService.showLockScreenOverride = null;
    resetGetxSingleton();
  });

  /// Un service prêt à l'emploi, avec un [AppController] hydraté localement.
  ///
  /// `armed: false` place l'app au premier plan et déjà déverrouillée : l'état
  /// exact depuis lequel la boucle repartait.
  Future<SecurityService> buildService({
    required bool lockEnabled,
    bool armed = false,
    bool authenticating = false,
  }) async {
    final controller = AppController(
      repository: FakeRepository(),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    controller.isAppLockEnabled = lockEnabled;
    Get.put<AppController>(controller, permanent: true);

    final service = SecurityService();
    Get.put<SecurityService>(service, permanent: true);
    service.setStateForTest(armed: armed, authenticating: authenticating);
    return service;
  }

  group('SecurityService — armement du verrou', () {
    test(
        'le retour de l\'invite biométrique ne rearme PAS le verrou '
        '(la boucle des 1,61 s)', () async {
      final service = await buildService(lockEnabled: true);

      // La séquence exacte que produit une authentification réussie sur iOS :
      // l'invite met l'app en `inactive`, sa fermeture rend un `resumed`.
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(lockRequests, 0,
          reason: 'un aller-retour biométrique ne doit demander aucun verrou');
    });

    test('dix allers-retours biométriques ne demandent toujours rien',
        () async {
      final service = await buildService(lockEnabled: true);

      // La vidéo montrait 11 cycles en 18 s. Ici on en rejoue dix : le compteur
      // doit rester à zéro, pas « rester petit ».
      for (var i = 0; i < 10; i++) {
        service.didChangeAppLifecycleState(AppLifecycleState.inactive);
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      }

      expect(lockRequests, 0);
    });

    test('un vrai passage en arriere-plan verrouille, une fois', () async {
      final service = await buildService(lockEnabled: true);

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(lockRequests, 1,
          reason: 'le correctif ne doit pas avoir desactive le verrou');
    });

    test(
        'un arriere-plan suivi de plusieurs resumed ne verrouille qu\'une fois',
        () async {
      final service = await buildService(lockEnabled: true);

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // Le `resumed` qui suit vient de l'invite qu'on vient de déclencher.
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(lockRequests, 1);
    });

    test('deux passages en arriere-plan verrouillent deux fois', () async {
      final service = await buildService(lockEnabled: true);

      for (var i = 0; i < 2; i++) {
        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      }

      expect(lockRequests, 2,
          reason: 'chaque depart reel merite sa propre authentification');
    });

    test('le demarrage arme le verrou', () async {
      // Pas de `setStateForTest` ici : on veut l'état par défaut du service,
      // celui qu'il a en sortant de son constructeur.
      final controller = AppController(
        repository: FakeRepository(),
        apiClient: MockApiClient(),
      );
      await controller.hydrate();
      controller.isAppLockEnabled = true;
      Get.put<AppController>(controller, permanent: true);

      final service = SecurityService();
      Get.put<SecurityService>(service, permanent: true);

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(lockRequests, 1,
          reason:
              'ouvrir l\'app est le premier evenement qui merite le verrou');
    });

    test('hidden et detached comptent comme un depart', () async {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        lockRequests = 0;
        final service = await buildService(lockEnabled: true);

        service.didChangeAppLifecycleState(state);
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(lockRequests, 1, reason: '$state doit armer le verrou');
        resetGetxSingleton();
      }
    });

    test(
        'un arriere-plan PENDANT une authentification ne rearme pas '
        '(stickyAuth)', () async {
      // `persistAcrossBackgrounding: true` autorise le greffon à mettre l'app de
      // côté au milieu de l'authentification. Ce départ-là est le nôtre, pas
      // celui de l'utilisateur : il ne doit pas produire un second verrou.
      //
      // L'authentification doit se TERMINER avant le `resumed`, sinon ce test
      // ne prouve rien : `_checkAndShowLockScreen` refuse déjà tant que
      // `_isAuthenticating` est vrai, et cette seconde garde masquerait
      // l'absence de la première. Vérifié par mutation — sans cette levée,
      // retirer la condition d'armement laissait le test vert.
      final service =
          await buildService(lockEnabled: true, authenticating: true);

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.setStateForTest(authenticating: false);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(lockRequests, 0);
    });

    test('verrou desactive : aucun ecran, meme apres un vrai depart', () async {
      final service = await buildService(lockEnabled: false);

      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(lockRequests, 0);
    });
  });

  group('SecurityService — verrou non contournable', () {
    testWidgets(
        'une navigation qui retire l\'écran de verrouillage avant le '
        'déverrouillage le remet', (tester) async {
      final service = await buildService(lockEnabled: true);
      service.setStateForTest(awaitingUnlock: true);

      service.onRouteChanged('/home');
      await tester.pump();
      expect(lockRequests, 1);

      // Le verrou lui-même au sommet : rien à faire.
      service.onRouteChanged('/app_lock');
      await tester.pump();
      expect(lockRequests, 1);
    });

    testWidgets('après déverrouillage, naviguer ne remet pas le verrou',
        (tester) async {
      final service = await buildService(lockEnabled: true);
      service.setStateForTest(awaitingUnlock: false);
      service.onRouteChanged('/home');
      await tester.pump();
      expect(lockRequests, 0);
    });

    testWidgets('démarrage à froid : le verrou armé est honoré sans resumed',
        (tester) async {
      await buildService(lockEnabled: true, armed: true);
      // En production, `runApp` produit la première frame (qui déclenche
      // `onReady` de GetX) ; ici on la demande explicitement.
      for (var i = 0; i < 3; i++) {
        tester.binding.scheduleFrame();
        await tester.pump();
      }
      expect(lockRequests, 1);
    });
  });
}
