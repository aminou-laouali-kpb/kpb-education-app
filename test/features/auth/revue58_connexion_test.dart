// Revue avant la 58 — la porte d'entrée (constats 11, 21, 12, 16, 17).
//
// 11/21 — Une coupure réseau ou un 429 pendant la vérification du code ne
//         s'affiche plus « Code invalide ou expiré ». « Renvoyer » attend 60 s
//         dès l'arrivée, et son erreur ne s'écrit plus dans le champ du code.
// 12    — Au retour de Google, l'écran d'entrée montre « on prépare ton
//         espace » et n'offre plus « Explorer sans compte ».
// 16    — Le mur du Profil invité dit « Créer mon compte gratuit ».
// 17    — Code accepté mais profil illisible : écran « Réessayer », jamais
//         l'onboarding ; l'écran de démarrage fait de même.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/navigation/app_boot_screen.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/auth/account_recovery_screen.dart';
import 'package:karatou/app/features/auth/auth_welcome_screen.dart';
import 'package:karatou/app/features/auth/magic_link_verify_screen.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

class _FailingProfileApi extends MockApiClient {
  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> getProfile() async => throw DioException(
        requestOptions: RequestOptions(path: '/profiles/me'),
        type: DioExceptionType.connectionTimeout,
      );
}

/// Profil qui ne répond jamais : la fin de connexion reste en cours.
class _PendingProfileApi extends MockApiClient {
  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> getProfile() =>
      Completer<Map<String, dynamic>>().future;
}

const _phone = KpbViewport(
  id: 'phone360',
  name: 'phone 360×640',
  size: Size(360, 640),
  padding: EdgeInsets.only(top: 24, bottom: 0),
);

Map<String, String> get _fr => AppTranslations().keys['fr']!;

void main() {
  setUp(resetGetxSingleton);
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('classifyOtpError', () {
    test('réseau, délai, 5xx : jamais « code invalide »', () {
      expect(classifyOtpError(AuthRetryableFetchException()),
          OtpVerifyFailure.network);
      expect(classifyOtpError(TimeoutException('verifyOTP')),
          OtpVerifyFailure.network);
      expect(classifyOtpError(const SocketException('down')),
          OtpVerifyFailure.network);
      expect(classifyOtpError(const AuthException('boom', statusCode: '502')),
          OtpVerifyFailure.network);
    });

    test('429 : trop d\'essais', () {
      expect(classifyOtpError(const AuthException('x', statusCode: '429')),
          OtpVerifyFailure.rateLimited);
      expect(classifyOtpError(const AuthException('Email rate limit exceeded')),
          OtpVerifyFailure.rateLimited);
    });

    test('refus du serveur (4xx) : code invalide', () {
      expect(
          classifyOtpError(
              const AuthException('Token has expired', statusCode: '403')),
          OtpVerifyFailure.invalidCode);
    });
  });

  group('MagicLinkVerifyScreen', () {
    late _MockAuthService auth;

    setUp(() => auth = _MockAuthService());

    Future<void> pumpVerify(WidgetTester tester) => pumpKpbScreen(
          tester,
          screen: MagicLinkVerifyScreen(
            authService: auth,
            email: 'eleve@example.com',
          ),
          viewport: _phone,
        );

    String? fieldError(WidgetTester tester) => tester
        .widget<InputDecorator>(find.descendant(
          of: find.byType(TextField),
          matching: find.byType(InputDecorator),
        ))
        .decoration
        .errorText;

    void stubVerifyError(Object error) {
      when(() => auth.verifyMagicLink(
            email: any(named: 'email'),
            code: any(named: 'code'),
            token: any(named: 'token'),
          )).thenAnswer((_) => Future<AuthResponse>.error(error));
    }

    testWidgets('coupure réseau : message réseau, pas « code invalide »',
        (tester) async {
      stubVerifyError(AuthRetryableFetchException());
      await pumpVerify(tester);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.pump();

      expect(fieldError(tester), _fr['auth_magic_verify_network']);
      expect(fieldError(tester), isNot(_fr['auth_magic_verify_error']));
      // Le bouton reste là pour retenter le même code.
      final button = find.widgetWithText(FilledButton, 'Valider');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('429 : « trop d\'essais »', (tester) async {
      stubVerifyError(const AuthException('rate', statusCode: '429'));
      await pumpVerify(tester);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.pump();

      expect(fieldError(tester), _fr['auth_magic_verify_rate_limited']);
    });

    testWidgets('« Renvoyer » attend 60 s dès l\'arrivée', (tester) async {
      await pumpVerify(tester);

      final resend = find.widgetWithText(TextButton, 'Renvoyer dans 60 s');
      expect(resend, findsOneWidget);
      expect(tester.widget<TextButton>(resend).onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Renvoyer dans 59 s'), findsOneWidget);
    });

    testWidgets(
        'code accepté mais profil illisible : écran « Réessayer », jamais '
        '« Code invalide » ni l\'onboarding', (tester) async {
      when(() => auth.verifyMagicLink(
            email: any(named: 'email'),
            code: any(named: 'code'),
            token: any(named: 'token'),
          )).thenAnswer((_) async => AuthResponse());
      when(() => auth.isLoggedIn).thenReturn(true);
      Get.put<AuthService>(auth, permanent: true);
      setupPlatformChannelMocks();
      final controller = AppController(
        repository: FakeRepository(
          snapshot:
              AppSnapshot(localeCode: 'fr', hasCompletedOnboarding: false),
        ),
        apiClient: _FailingProfileApi(),
      );
      await controller.hydrate();
      Get.put<AppController>(controller, permanent: true);
      AppConfig.enableRemoteSyncOverride = true;

      await pumpVerify(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      // retryTransient : 400 ms puis 800 ms entre les trois essais.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byType(AccountRecoveryScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text(_fr['auth_magic_verify_error']!), findsNothing);
      expect(controller.hasCompletedOnboarding, isFalse);
    });
  });

  testWidgets(
      'retour de Google : « on prépare ton espace », plus d\'« Explorer sans '
      'compte »', (tester) async {
    final events = StreamController<AuthState>();
    addTearDown(events.close);
    final auth = _MockAuthService();
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => auth.isLoggedIn).thenReturn(true);
    when(() => auth.dismissAuthWebView()).thenAnswer((_) async {});
    Get.put<AuthService>(auth, permanent: true);
    setupPlatformChannelMocks();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(localeCode: 'fr', hasCompletedOnboarding: false),
      ),
      apiClient: _PendingProfileApi(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    AppConfig.enableRemoteSyncOverride = true;

    await pumpKpbScreen(
      tester,
      screen: const AuthWelcomeScreen(),
      viewport: const KpbViewport(
        id: 'phone375',
        name: 'phone 375×667',
        size: Size(375, 667),
        padding: EdgeInsets.zero,
      ),
    );
    expect(find.text(_fr['auth_explore_guest']!), findsOneWidget);

    events.add(const AuthState(AuthChangeEvent.signedIn, null));
    await tester.pump();
    await tester.pump();

    expect(find.text(_fr['auth_finishing_session']!), findsOneWidget);
    expect(find.text(_fr['auth_explore_guest']!), findsNothing);
    expect(find.text(_fr['auth_continue_google']!), findsNothing);
    expect(controller.isGuestMode, isFalse);
  });

  testWidgets(
      'démarrage à froid connecté, profil illisible : « Réessayer », pas '
      'd\'onboarding', (tester) async {
    final auth = _MockAuthService();
    when(() => auth.isLoggedIn).thenReturn(true);
    Get.put<AuthService>(auth, permanent: true);
    setupPlatformChannelMocks();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(localeCode: 'fr', hasCompletedOnboarding: false),
      ),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    controller.accountLoadFailed = true;
    Get.put<AppController>(controller, permanent: true);

    await pumpKpbScreen(tester,
        screen: const AppBootScreen(), viewport: _phone);

    expect(find.byType(AccountRecoveryScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text(_fr['auth_account_unavailable_retry']!), findsOneWidget);
  });

  testWidgets('mur du Profil invité : « Créer mon compte gratuit »',
      (tester) async {
    setupPlatformChannelMocks();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          isGuestMode: true,
        ),
      ),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);

    await pumpKpbScreen(
      tester,
      screen: const ProfileScreen(),
      viewport: const KpbViewport(
        id: 'tall',
        name: 'tall 412×915',
        size: Size(412, 915),
        padding: EdgeInsets.zero,
      ),
    );

    expect(find.text(_fr['guest_case_gate_cta']!), findsOneWidget);
    expect(find.text(_fr['auth_continue_email']!), findsNothing);
    expect(find.text(_fr['auth_guest_profile_have_account']!), findsOneWidget);
  });
}
