// Audit du 22/11/2026, n° 19 : un seul socket temps réel pour tous les écrans
// de dossier. Fermer le dossier B, ouvert par-dessus le dossier A (depuis une
// notification), coupait le temps réel de A resté affiché en dessous :
// `disconnectCaseDetailSocket()` détruisait le socket sans regarder à quel
// écran il appartenait.
//
// Maintenant chaque écran tient un jeton : le socket suit le dossier de
// l'écran du dessus, et seul le dernier écran qui ferme un dossier le quitte.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/services/case_socket_service.dart';

import '../../widget_test_helpers.dart';

/// Socket de test : journalise les entrées et sorties de room, sans réseau.
/// [alive] simule l'état du socket socket.io : faux quand il a été détruit
/// sans reconnexion (refus de la poignée de main, « io server disconnect »).
class _FakeCaseSocket extends CaseSocketService {
  final List<String> log = <String>[];
  String? _joined;
  bool alive = false;
  void Function(Map<String, dynamic> data)? typing;

  @override
  String? get currentCaseId => _joined;

  @override
  bool get isConnected => alive;

  @override
  bool get isActive => alive;

  @override
  Future<void> connect(String caseId) async {
    await disconnect();
    _joined = caseId;
    alive = true;
    log.add('join:$caseId');
  }

  @override
  Future<void> disconnect() async {
    final joined = _joined;
    if (joined != null) log.add('leave:$joined');
    _joined = null;
    alive = false;
  }

  @override
  void onTyping(void Function(Map<String, dynamic> data) callback) =>
      typing = callback;
}

/// Session d'authentification présente ; [authGate], s'il est posé, retient
/// la réponse (réseau lent).
class _AuthedApi extends MockApiClient {
  Completer<void>? authGate;

  @override
  Future<bool> hasAuthSession() async {
    final gate = authGate;
    if (gate != null) await gate.future;
    return true;
  }
}

void main() {
  late _FakeCaseSocket socket;
  late _AuthedApi api;
  late AppController controller;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    setupPlatformChannelMocks();
    AppConfig.enableRemoteSyncOverride = true;
    socket = _FakeCaseSocket();
    api = _AuthedApi();
    controller = AppController(
      repository: FakeRepository(),
      apiClient: api,
      caseSocket: socket,
    );
    Get.put<AppController>(controller, permanent: true);
  });

  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  Future<void> settle() => pumpEventQueue();

  test('fermer B ouvert par-dessus A rebranche le temps réel sur A', () async {
    final leaseA = controller.connectCaseDetailSocket('case-a');
    await settle();
    expect(socket.currentCaseId, 'case-a');

    // Notification « nouveau message » sur B : B s'empile au-dessus de A.
    final leaseB = controller.connectCaseDetailSocket('case-b');
    await settle();
    expect(socket.currentCaseId, 'case-b');

    // Retour arrière : B se ferme, A est de nouveau affiché.
    await controller.disconnectCaseDetailSocket(leaseB);
    await settle();
    expect(socket.currentCaseId, 'case-a',
        reason: 'le dossier resté ouvert en dessous doit garder son temps '
            'réel après la fermeture du dossier du dessus');

    await controller.disconnectCaseDetailSocket(leaseA);
    await settle();
    expect(socket.currentCaseId, isNull);
    expect(socket.log, [
      'join:case-a',
      'leave:case-a',
      'join:case-b',
      'leave:case-b',
      'join:case-a',
      'leave:case-a',
    ]);
  });

  test('deux écrans du même dossier : seul le dernier qui ferme le quitte',
      () async {
    final first = controller.connectCaseDetailSocket('case-a');
    await settle();
    final second = controller.connectCaseDetailSocket('case-a');
    await settle();

    await controller.disconnectCaseDetailSocket(second);
    await settle();
    expect(socket.currentCaseId, 'case-a');

    await controller.disconnectCaseDetailSocket(first);
    await settle();
    expect(socket.currentCaseId, isNull);
    // Une seule entrée dans la room : le second écran n'a pas reconnecté.
    expect(socket.log, ['join:case-a', 'leave:case-a']);
  });

  test('rendre deux fois le même jeton ne coupe pas l’écran du dessous',
      () async {
    final leaseA = controller.connectCaseDetailSocket('case-a');
    final leaseB = controller.connectCaseDetailSocket('case-b');
    await settle();

    await controller.disconnectCaseDetailSocket(leaseB);
    await controller.disconnectCaseDetailSocket(leaseB);
    await settle();
    expect(socket.currentCaseId, 'case-a');

    await controller.disconnectCaseDetailSocket(leaseA);
  });

  test('écran fermé pendant la vérification de session : aucun socket ouvert',
      () async {
    final gate = Completer<void>();
    api.authGate = gate;

    final lease = controller.connectCaseDetailSocket('case-a');
    await settle();
    // L'élève quitte le dossier avant la réponse de `hasAuthSession`.
    await controller.disconnectCaseDetailSocket(lease);
    gate.complete();
    await settle();

    expect(socket.currentCaseId, isNull,
        reason: 'un connect qui reprend après la fermeture de l’écran ne '
            'doit pas laisser un socket sur un dossier qui n’est plus affiché');
    expect(socket.log, isNot(contains('join:case-a')));
  });

  // ── Revue de fdbff58 (R1 à R4) ─────────────────────────────────────────

  test(
      'R1 socket mort (refus de la poignée de main) : rouvrir le même '
      'dossier le relance', () async {
    controller.connectCaseDetailSocket('case-a');
    await settle();
    // Jeton expiré : socket.io détruit le socket sans reconnexion, mais le
    // dossier rejoint reste noté.
    socket.alive = false;
    controller.connectCaseDetailSocket('case-a');
    await settle();
    expect(socket.isActive, isTrue,
        reason: 'rouvrir le dossier (notification) doit recréer un socket '
            'mort, comme avant la pile de jetons');
  });

  test('R2 « en train d’écrire » effacé au retour de B vers A', () async {
    bool? lastSeen;
    controller.addListener(() => lastSeen = controller.isCaseAdvisorTyping);
    controller.connectCaseDetailSocket('case-a');
    await settle();
    final leaseB = controller.connectCaseDetailSocket('case-b');
    await settle();
    socket.typing!({'isTyping': true}); // le conseiller de B écrit
    expect(lastSeen, isTrue);

    await controller.disconnectCaseDetailSocket(leaseB); // retour sur A
    await settle();
    expect(controller.isCaseAdvisorTyping, isFalse);
    expect(lastSeen, isFalse,
        reason: 'sans update() après la remise à false, l’écran A affiche '
            'encore l’indicateur de B');
    await Future<void>.delayed(const Duration(seconds: 5)); // minuterie 4 s
    expect(lastSeen, isFalse);
  });

  test('R3 ouvrir B par-dessus A pendant que le conseiller de A écrit',
      () async {
    bool? lastSeen;
    controller.addListener(() => lastSeen = controller.isCaseAdvisorTyping);
    controller.connectCaseDetailSocket('case-a');
    await settle();
    socket.typing!({'isTyping': true});
    expect(lastSeen, isTrue);
    controller.connectCaseDetailSocket('case-b');
    await settle();
    expect(lastSeen, isFalse);
  });

  test('R4 après logout : room du compte parti quittée, typing ignoré',
      () async {
    controller.connectCaseDetailSocket('case-a');
    await settle();
    final typing = socket.typing!;
    await controller.logout();
    typing({'isTyping': true});
    expect(controller.isCaseAdvisorTyping, isFalse);
    expect(socket.currentCaseId, isNull,
        reason: 'logout doit quitter la room du compte parti');
  });

  test('un signal « en train d’écrire » d’un autre dossier est ignoré',
      () async {
    controller.connectCaseDetailSocket('case-a');
    await settle();
    socket.typing!({'caseId': 'case-b', 'isTyping': true});
    expect(controller.isCaseAdvisorTyping, isFalse);
    socket.typing!({'caseId': 'case-a', 'isTyping': true});
    expect(controller.isCaseAdvisorTyping, isTrue);
  });
}
