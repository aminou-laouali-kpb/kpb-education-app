// Revue avant la 58 (07/11/2026) : local_auth 3 lève des LocalAuthException,
// qui ne sont PAS des PlatformException. `authenticate()` n'attrapait que les
// secondes : annuler Face ID sortait de la méthode (aucun message, plantage
// « fatal » dans Crashlytics), et un Android avec capteur d'empreinte mais sans
// code de verrouillage restait enfermé derrière l'écran de verrouillage.

import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

import 'package:karatou/app/core/services/security_service.dart';

class _FakeLocalAuth extends LocalAuthPlatform {
  _FakeLocalAuth({this.error, this.supported = true});
  final LocalAuthExceptionCode? error;
  final bool supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    if (error != null) throw LocalAuthException(code: error!);
    return true;
  }

  @override
  Future<bool> deviceSupportsBiometrics() async => supported;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => const [];

  @override
  Future<bool> stopAuthentication() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> authWith(_FakeLocalAuth fake) {
    LocalAuthPlatform.instance = fake;
    return SecurityService().authenticate();
  }

  test('annuler Face ID : refus propre, plus d’exception qui s’échappe',
      () async {
    expect(
      await authWith(
          _FakeLocalAuth(error: LocalAuthExceptionCode.userCanceled)),
      isFalse,
    );
  });

  test('trop d’essais : refus, le verrou reste en place', () async {
    expect(
      await authWith(
          _FakeLocalAuth(error: LocalAuthExceptionCode.temporaryLockout)),
      isFalse,
    );
  });

  test('appareil sans code ni empreinte : le verrou se lève, l’élève entre',
      () async {
    for (final code in [
      LocalAuthExceptionCode.noCredentialsSet,
      LocalAuthExceptionCode.noBiometricHardware,
      LocalAuthExceptionCode.noBiometricsEnrolled,
    ]) {
      expect(await authWith(_FakeLocalAuth(error: code)), isTrue,
          reason: code.name);
    }
  });

  test('activer le verrou exige une vraie authentification réussie', () async {
    LocalAuthPlatform.instance =
        _FakeLocalAuth(error: LocalAuthExceptionCode.noCredentialsSet);
    expect(await SecurityService().confirmCanLock(), isFalse);
    LocalAuthPlatform.instance =
        _FakeLocalAuth(error: LocalAuthExceptionCode.userCanceled);
    expect(await SecurityService().confirmCanLock(), isFalse);
    LocalAuthPlatform.instance = _FakeLocalAuth(supported: false);
    expect(await SecurityService().confirmCanLock(), isFalse);
    LocalAuthPlatform.instance = _FakeLocalAuth();
    expect(await SecurityService().confirmCanLock(), isTrue);
  });
}
