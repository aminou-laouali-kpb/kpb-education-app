// Revue avant la 58, constats 18, 19 et 20 — la file des messages de dossier.
//
// 18. Un message écrit dans un dossier tout juste créé (id local `case-<ms>`)
//     partait vers cet id, que le serveur ne connaît pas : 404, message perdu.
//     Hors ligne, il restait en file sous l'id local, que rien ne remappait.
// 19. Un POST réussi suivi d'un `getCase` en échec remettait le message en
//     file : le conseiller le recevait deux fois.
// 20. Un message en file ou en échec définitif s'affichait comme envoyé, et
//     la file ne se vidait qu'au passage hors ligne → en ligne.
//
// Vraie file Hive (dossier temporaire), serveur simulé.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hive_flutter/hive_flutter.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/case_message_outbox.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';
import 'package:karatou/app/core/services/connectivity_service.dart';

import '../../widget_test_helpers.dart';

const _localId = 'case-1700000000000';
const _serverId = 'srv-1';

DioException _networkError(String path) => DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionTimeout,
    );

DioException _httpError(String path, int status) => DioException(
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
      ),
      type: DioExceptionType.badResponse,
    );

/// Le serveur : des dossiers, et des messages qui n'existent que s'ils ont
/// été postés vers un id qu'il connaît.
class _Api extends MockApiClient {
  final Map<String, List<Map<String, dynamic>>> messages = {
    _serverId: <Map<String, dynamic>>[],
  };
  bool serverCaseExists = false;

  /// Tous les POST de message reçus, réussis ou non : (id, texte).
  final List<(String, String)> postAttempts = [];

  Completer<void>? createGate;
  int failNextPosts = 0;
  bool failGetCase = false;

  List<String> get delivered => [
        for (final m in messages[_serverId]!) m['body'] as String,
      ];

  @override
  Future<bool> hasAuthSession() async => true;

  Map<String, dynamic> _caseJson(String id) => <String, dynamic>{
        'id': id,
        'referenceCode': 'KPB-1134',
        'type': 'CONSULTATION',
        'title': 'Mon dossier',
        'status': 'SUBMITTED',
        // Plus récent que la copie locale : la version serveur gagne la
        // fusion de la synchro.
        'updatedAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'createdAt': DateTime(2026, 11, 1).toUtc().toIso8601String(),
        'messages': messages[id] ?? const <Map<String, dynamic>>[],
      };

  @override
  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) async {
    final gate = createGate;
    if (gate != null) await gate.future;
    serverCaseExists = true;
    return _caseJson(_serverId);
  }

  @override
  Future<Map<String, dynamic>> createCaseMessage(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final body = payload['body'] as String;
    postAttempts.add((caseId, body));
    final path = '/cases/$caseId/messages';
    if (failNextPosts > 0) {
      failNextPosts--;
      throw _networkError(path);
    }
    if (caseId != _serverId || !serverCaseExists) throw _httpError(path, 404);
    final message = <String, dynamic>{
      'id': 'msg-${messages[_serverId]!.length + 1}',
      'senderRole': 'student',
      'senderName': payload['senderName'],
      'body': body,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    messages[_serverId]!.add(message);
    return message;
  }

  @override
  Future<Map<String, dynamic>> getCase(String caseId) async {
    if (failGetCase) throw _networkError('/cases/$caseId');
    if (caseId != _serverId || !serverCaseExists) {
      throw _httpError('/cases/$caseId', 404);
    }
    return _caseJson(caseId);
  }

  @override
  Future<List<dynamic>> listCases() async =>
      serverCaseExists ? <dynamic>[_caseJson(_serverId)] : const <dynamic>[];

  @override
  Future<Map<String, dynamic>> getProfile() async => <String, dynamic>{
        'id': 'test-user-1',
        'accountType': 'student',
        'fullName': 'Test User',
        'preferredLanguage': 'fr',
        'countryOfResidence': 'CI',
        'currentLevel': 'Licence',
      };

  @override
  Future<List<dynamic>> listSavedItems() async => const <dynamic>[];

  @override
  Future<CatalogListPayload> listCatalogEnvelope(String resource) async =>
      const CatalogListPayload(items: [], source: CatalogDataSource.database);

  @override
  Future<List<dynamic>> listContent(String resource) async => const <dynamic>[];
}

StudentCase _case(String id) {
  final at = DateTime(2026, 11, 1);
  return StudentCase(
    id: id,
    referenceCode: 'KPB-2026-001',
    type: CaseType.consultation,
    title: const LocalizedText(fr: 'Mon dossier', en: 'My case'),
    description: const LocalizedText(fr: '', en: ''),
    contextLabel: const LocalizedText(fr: '', en: ''),
    status: CaseStatus.submitted,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: at,
    updatedAt: at,
    nextStepTitle: const LocalizedText(fr: '', en: ''),
    nextStepDescription: const LocalizedText(fr: '', en: ''),
    timeline: const [],
    messages: const [],
    documentRequests: const [],
  );
}

Future<(AppController, _Api)> _device(StudentCase seeded) async {
  AppConfig.enableRemoteSyncOverride = false;
  final api = _Api();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        cases: [seeded],
      ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  AppConfig.enableRemoteSyncOverride = true;
  // Pas de relance automatique sauf dans le test qui la vérifie.
  controller.outboxRetryDelay = const Duration(hours: 1);
  return (controller, api);
}

/// Laisse filer les envois non attendus (`unawaited`) et la file Hive.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

CaseMessage _studentBubble(AppController controller, String text) => controller
    .caseById(_localId)!
    .messages
    .lastWhere((m) => m.senderRole == 'student' && m.body.fr == text);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CaseMessageOutbox outbox;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    final dir = await Directory.systemTemp.createTemp('hive_case_outbox');
    Hive.init(dir.path);
    outbox = await CaseMessageOutbox.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  setUp(() async {
    resetGetxSingleton();
    setupPlatformChannelMocks();
    ConnectivityService.instance.debugSetOnline(true);
    await outbox.clear();
    CatalogCacheService.resetForTests();
    await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
    await CatalogCacheService.init();
  });

  tearDown(() {
    ConnectivityService.instance.debugSetOnline(true);
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('n° 18 — dossier tout juste créé', () {
    test(
        'en ligne : le message attend la création, part vers l\'id serveur, '
        'et le dossier reste trouvable sous l\'id local', () async {
      final (controller, api) = await _device(_case(_localId));
      api.createGate = Completer<void>();

      controller.addCaseMessage(_localId, 'Bonjour, c\'est urgent');
      await _settle();

      expect(api.postAttempts, isEmpty,
          reason: 'jamais de POST vers un id que le serveur ne connaît pas');
      expect(
        controller.caseMessageDelivery(
            _studentBubble(controller, 'Bonjour, c\'est urgent')),
        CaseMessageDelivery.pending,
      );

      api.createGate!.complete();
      await _settle();

      expect(api.postAttempts, [(_serverId, 'Bonjour, c\'est urgent')]);
      expect(api.delivered, ['Bonjour, c\'est urgent']);
      expect(outbox.pendingCount, 0);
      expect(controller.resolveCaseId(_localId), _serverId);
      final resolved = controller.caseById(_localId);
      expect(resolved, isNotNull,
          reason: 'l\'écran ouvert par « Voir » ne doit pas passer à '
              '« Dossier introuvable »');
      expect(resolved!.id, _serverId);
      expect(
        resolved.messages.where((m) => m.body.fr == 'Bonjour, c\'est urgent'),
        hasLength(1),
      );
    });

    test(
        'un message écrit pendant la création, envoyé depuis l\'écran resté '
        'sur l\'id local après la création, arrive aussi', () async {
      final (controller, api) = await _device(_case(_localId));
      controller.addCaseMessage(_localId, 'Premier');
      await _settle();
      controller.addCaseMessage(_localId, 'Second');
      await _settle();

      expect(api.delivered, ['Premier', 'Second']);
      expect(api.postAttempts.map((a) => a.$1).toSet(), {_serverId});
    });

    test(
        'hors ligne : la synchro ne brûle aucun essai sur l\'id local, puis '
        'envoie vers l\'id serveur après la création', () async {
      final (controller, api) = await _device(_case(_localId));
      // Entrée écrite hors ligne, par une version antérieure (sans id de
      // bulle).
      await outbox.enqueue(
        caseId: _localId,
        body: 'Écrit dans le métro',
        senderName: 'Test User',
      );

      await controller.flushPendingCaseMessages();
      expect(api.postAttempts, isEmpty);
      expect(outbox.pending.single.retries, 0,
          reason: 'pas de 404 compté comme un échec');

      await controller.syncRemoteData(force: true);
      await _settle();

      expect(api.postAttempts, [(_serverId, 'Écrit dans le métro')]);
      expect(api.delivered, ['Écrit dans le métro']);
      expect(outbox.pendingCount, 0);
    });
  });

  group('n° 19 — pas de double envoi', () {
    test('POST réussi puis relecture du dossier en échec : envoyé une fois',
        () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;
      api.failGetCase = true;

      controller.addCaseMessage(_serverId, 'Voici ma disponibilité');
      await _settle();

      expect(outbox.pendingCount, 0,
          reason: 'le message est parti : rien à remettre en file');
      await controller.flushPendingCaseMessages();
      expect(api.delivered, ['Voici ma disponibilité']);
      expect(api.postAttempts, hasLength(1));
      final bubble = controller
          .caseById(_serverId)!
          .messages
          .lastWhere((m) => m.body.fr == 'Voici ma disponibilité');
      expect(controller.caseMessageDelivery(bubble), CaseMessageDelivery.sent);
    });
  });

  group('n° 20 — état d\'envoi visible et relances', () {
    test(
        'échec réseau : « en attente », puis « non envoyé » après les essais, '
        'la bulle survit à la synchro, et « Réessayer » l\'envoie', () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;
      api.failNextPosts = 1 + CaseMessageOutbox.maxRetries;

      controller.addCaseMessage(_serverId, 'La pièce demandée');
      await _settle();
      CaseMessage bubble() => controller
          .caseById(_serverId)!
          .messages
          .lastWhere((m) => m.body.fr == 'La pièce demandée');
      expect(controller.caseMessageDelivery(bubble()),
          CaseMessageDelivery.pending);

      for (var i = 0; i < CaseMessageOutbox.maxRetries; i++) {
        await controller.flushPendingCaseMessages();
      }
      expect(
          controller.caseMessageDelivery(bubble()), CaseMessageDelivery.failed);
      expect(api.delivered, isEmpty);

      // La copie serveur (plus récente) ne connaît pas ce message : elle ne
      // doit pas effacer la bulle.
      await controller.syncRemoteData(force: true);
      await _settle();
      expect(
          controller.caseMessageDelivery(bubble()), CaseMessageDelivery.failed);

      await controller.retryCaseMessage(bubble().id);
      await _settle();
      expect(api.delivered, ['La pièce demandée']);
      expect(outbox.pendingCount, 0);
      final copies = controller
          .caseById(_serverId)!
          .messages
          .where((m) => m.body.fr == 'La pièce demandée')
          .toList();
      expect(copies, hasLength(1));
      expect(controller.caseMessageDelivery(copies.single),
          CaseMessageDelivery.sent);
    });

    test('après un échec réseau, relance seule sans transition de réseau',
        () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;
      controller.outboxRetryDelay = const Duration(milliseconds: 20);
      api.failNextPosts = 1;

      controller.addCaseMessage(_serverId, 'Réseau lent');
      await _settle();

      expect(api.delivered, ['Réseau lent']);
      expect(outbox.pendingCount, 0);
    });

    test('le retour au premier plan vide la file', () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;
      await outbox.enqueue(
        caseId: _serverId,
        body: 'Écrit hier soir',
        senderName: 'Test User',
      );

      controller.onAppResumed();
      await _settle();

      expect(api.delivered, ['Écrit hier soir']);
      expect(outbox.pendingCount, 0);
    });
  });
}
