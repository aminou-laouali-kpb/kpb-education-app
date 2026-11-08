// L'onglet « Bourses » en mode INVITÉ — un 401 n'est pas une panne de réseau.
//
// ## L'angle mort que ce fichier ouvre
//
// Le dépôt avait un test de cet écran, et il ne pouvait pas voir le défaut : il
// sème `createTestProfile()`, donc un utilisateur CONNECTÉ. Les 101 fichiers de
// test ne contenaient pas une seule assertion en `isGuestMode: true` — l'app
// possède un état entier que rien ne rendait jamais.
//
// Ce que voyait donc l'invité, sans que personne ne le sache : il accepte
// « Explorer sans compte », touche l'onglet du MILIEU — celui que l'app met le
// plus en avant — et reçoit une icône de wifi barré, « problème de connexion »,
// et un unique bouton « Réessayer ». Sa connexion est parfaite. Le serveur a
// répondu 401 parce que l'index des bourses exige une session, et aucun nombre
// de tentatives ne fabrique une session. Message faux ET impasse, sur la surface
// la plus commerciale du produit.
//
// ## Les deux cas, et pourquoi le second est obligatoire
//
// Un correctif qui afficherait le mur invité pour TOUTE erreur remplacerait un
// mensonge par l'autre : l'utilisateur en tunnel, hors couverture, s'entendrait
// dire de créer un compte qu'il a déjà. Le second groupe l'interdit.

// `Response` existe dans dio ET dans get : le préfixe évite l'ambiguïté.
import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/models/live_scholarships_query.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_entry_card.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';

import '../../widget_test_helpers.dart';
import 'scholarships_test_support.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Le semis qui manquait : invité, sans profil.
Future<AppController> _seedGuest(MockApiClient apiClient) async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: const AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: false,
        isGuestMode: true,
      ),
    ),
    apiClient: apiClient,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);

  // Le CTA du mur route vers l'écran de démarrage, qui interroge AuthService.
  final auth = _MockAuthService();
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  when(() => auth.isLoggedIn).thenReturn(false);
  Get.put<AuthService>(auth, permanent: true);

  return controller;
}

void _stubFailure(MockApiClient mock, Object error) {
  whenScholarshipsPage(mock).thenThrow(error);
  when(() => mock.fetchScholarshipAlerts()).thenAnswer((_) async => <String>{});
  when(() => mock.getSuccessLabAccess()).thenAnswer(
    (_) async => <String, dynamic>{'enabled': false, 'reasons': <String>[]},
  );
}

dio.DioException _unauthorized() => dio.DioException(
      requestOptions: dio.RequestOptions(path: '/scholarships'),
      response: dio.Response<dynamic>(
        requestOptions: dio.RequestOptions(path: '/scholarships'),
        statusCode: 401,
      ),
      type: dio.DioExceptionType.badResponse,
    );

dio.DioException _offline() => dio.DioException(
      requestOptions: dio.RequestOptions(path: '/scholarships'),
      type: dio.DioExceptionType.connectionError,
      error: 'Network is unreachable',
    );

/// Un téléphone haut. Le mur invité vit dans un `SliverFillRemaining` : sur les
/// 800 px par défaut du binding, il est comprimé sous les en-têtes de l'écran et
/// son bouton devient intouchable.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void main() {
  setUpAll(registerScholarshipListFallbacks);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('401 en mode invité — le mur, pas le wifi barré', () {
    testWidgets('l\'écran ne prétend plus à une panne de connexion',
        (tester) async {
      final mock = MockApiClient();
      _stubFailure(mock, _unauthorized());
      await _seedGuest(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.wifi_off_rounded),
        findsNothing,
        reason: 'La connexion de l\'utilisateur est parfaite : c\'est le '
            'serveur qui exige un compte. Lui montrer un wifi barré l\'envoie '
            'chercher un problème qui n\'existe pas.',
      );
      expect(
        find.text('live_scholarships_connection_error_title'.tr),
        findsNothing,
      );
      expect(
        find.text('retry'.tr),
        findsNothing,
        reason: 'Le bouton « Réessayer » ne pouvait par construction jamais '
            'aboutir : c\'était l\'impasse elle-même.',
      );
    });

    testWidgets('il propose la seule action qui lève l\'obstacle',
        (tester) async {
      final mock = MockApiClient();
      _stubFailure(mock, _unauthorized());
      final controller = await _seedGuest(mock);
      _tallPhone(tester);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(find.text('scholarships_auth_required_cta'.tr), findsOneWidget);
      expect(controller.isGuestMode, isTrue);

      // `ensureVisible` avant le tap : le mur vit dans un `SliverFillRemaining`
      // sous des en-têtes collants, et sur le viewport par défaut le bouton se
      // trouve dans une zone que le test touche « à côté ». Sans cette ligne,
      // `tap()` n'émet qu'un AVERTISSEMENT — pas un échec — et l'assertion qui
      // suit accuse le code de production d'un défaut qui n'existe pas.
      await tester
          .ensureVisible(find.text('scholarships_auth_required_cta'.tr));
      await tester.pumpAndSettle();
      await tester.tap(find.text('scholarships_auth_required_cta'.tr));
      await tester.pumpAndSettle();

      expect(
        controller.isGuestMode,
        isFalse,
        reason: 'Sans quitter le mode invité, le routeur de démarrage renvoie '
            'DIRECTEMENT dans la coquille invité : le bouton bouclerait sur '
            'l\'écran d\'où il vient, sans un mot.',
      );
      expect(controller.hasCompletedOnboarding, isFalse);
    });
  });

  // Revue avant la 58 (décision de l'audit 57) : derrière le mur, ni « Filtrer »,
  // ni « Trier », ni la phrase « Active une alerte… ». Ils relançaient un 401
  // qui ramenait au même mur, et repoussaient son bouton sous le pli d'un SE.
  group('401 en mode invité — rien au-dessus du mur', () {
    testWidgets('ni Filtrer, ni Trier, ni la phrase sur les alertes',
        (tester) async {
      final mock = MockApiClient();
      _stubFailure(mock, _unauthorized());
      await _seedGuest(mock);
      // iPhone SE 1re génération.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('scholarships-filter-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('scholarships-sort-button')),
        findsNothing,
      );
      expect(find.text('scholarships_sorted_hint'.tr), findsNothing);

      // Le bouton du mur tient au-dessus du pli, sans défilement.
      final cta = find.text('scholarships_auth_required_cta'.tr);
      expect(cta, findsOneWidget);
      expect(tester.getBottomLeft(cta).dy, lessThanOrEqualTo(568));
    });

    testWidgets(
        'pendant le chargement non plus : rien n\'apparaît puis ne disparaît',
        (tester) async {
      final mock = MockApiClient();
      final pending = Completer<LiveScholarshipsPage>();
      whenScholarshipsPage(mock).thenAnswer((_) => pending.future);
      when(() => mock.fetchScholarshipAlerts())
          .thenAnswer((_) async => <String>{});
      when(() => mock.getSuccessLabAccess()).thenAnswer(
        (_) async => <String, dynamic>{'enabled': false, 'reasons': <String>[]},
      );
      await _seedGuest(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pump();

      // La requête est en vol : squelettes, et rien au-dessus.
      expect(
        find.byKey(const ValueKey<String>('scholarships-filter-button')),
        findsNothing,
      );
      expect(find.text('scholarships_sorted_hint'.tr), findsNothing);
      expect(find.byType(ScholarshipMatchEntryCard), findsNothing);

      pending.completeError(_unauthorized());
      await tester.pumpAndSettle();
      expect(find.text('scholarships_auth_required_cta'.tr), findsOneWidget);
    });

    testWidgets('un invité qui reçoit des bourses retrouve « Filtrer »',
        (tester) async {
      final mock = MockApiClient();
      whenScholarshipsPage(mock).thenAnswer(
        (_) async => scholarshipsPage(<dynamic>[
          <String, dynamic>{
            'id': 'sch-1',
            'title': 'Bourse ouverte',
            'countryName': 'International',
            'fundingType': 'fully_funded',
            'description': '',
            'advantages': <String>[],
            'eligibility': <String>[],
            'level': 'Master',
            'deadlineLabel': '',
            'applicationUrl': '',
            'tags': <String>[],
            'matchScore': 50,
          },
        ]),
      );
      when(() => mock.fetchScholarshipAlerts())
          .thenAnswer((_) async => <String>{});
      when(() => mock.getSuccessLabAccess()).thenAnswer(
        (_) async => <String, dynamic>{'enabled': false, 'reasons': <String>[]},
      );
      await _seedGuest(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(find.text('Bourse ouverte'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('scholarships-filter-button')),
        findsOneWidget,
      );
    });
  });

  group('une vraie panne réseau reste une vraie panne réseau', () {
    testWidgets('une DioException SANS statut garde l\'écran de connexion',
        (tester) async {
      final mock = MockApiClient();
      _stubFailure(mock, _offline());
      await _seedGuest(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('retry'.tr), findsOneWidget);
      expect(
        find.text('scholarships_auth_required_cta'.tr),
        findsNothing,
        reason: 'Proposer de créer un compte à quelqu\'un qui est hors '
            'couverture remplace un mensonge par l\'autre.',
      );
    });

    testWidgets('une erreur quelconque aussi', (tester) async {
      final mock = MockApiClient();
      _stubFailure(mock, StateError('boom'));
      await _seedGuest(mock);

      await tester.pumpWidget(_wrap(LiveScholarshipsScreen(apiClient: mock)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });
}
