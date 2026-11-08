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

DioException _httpError(String path, int status, [Object? data]) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: data,
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

  /// Les corps exacts reçus.
  final List<Map<String, dynamic>> payloads = [];

  /// Serveur actuel en production, dont le DTO ignore `clientMessageId`.
  bool legacyServer = false;

  Completer<void>? createGate;
  int failNextPosts = 0;

  /// Le prochain POST attend ce verrou (POST lent, ou app tuée pendant).
  Completer<void>? nextPostGate;

  /// Le prochain POST est refusé avec ce statut (4xx).
  int? rejectNextWith;

  /// Le prochain POST est ENREGISTRÉ, puis sa réponse ne revient jamais
  /// (app tuée, réseau coupé après coup).
  bool commitNextThenHang = false;
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
    payloads.add(Map<String, dynamic>.of(payload));
    final path = '/cases/$caseId/messages';
    // Comme `main.ts` : ValidationPipe whitelist + forbidNonWhitelisted. Un
    // champ hors du DTO fait refuser TOUT le message (avant ce correctif,
    // `senderName`/`senderRole` : chaque message d'élève en 400 depuis juin).
    final allowed = legacyServer ? {'body'} : {'body', 'clientMessageId'};
    final extra = payload.keys.where((k) => !allowed.contains(k)).toList();
    if (extra.isNotEmpty) {
      throw _httpError(path, 400, <String, dynamic>{
        'statusCode': 400,
        'message': [for (final k in extra) 'property $k should not exist'],
        'error': 'Bad Request',
      });
    }
    final gate = nextPostGate;
    if (gate != null) {
      nextPostGate = null;
      await gate.future;
    }
    final reject = rejectNextWith;
    if (reject != null) {
      rejectNextWith = null;
      throw _httpError(path, reject);
    }
    if (failNextPosts > 0) {
      failNextPosts--;
      throw _networkError(path);
    }
    if (caseId != _serverId || !serverCaseExists) throw _httpError(path, 404);
    // Comme le backend : même identifiant client dans le même dossier → le
    // message existant, sans second.
    final clientId = payload['clientMessageId'] as String?;
    final existing = clientId == null
        ? null
        : messages[_serverId]!
            .where((m) => m['clientMessageId'] == clientId)
            .firstOrNull;
    if (existing != null) return existing;
    final message = <String, dynamic>{
      'id': 'msg-${messages[_serverId]!.length + 1}',
      'senderRole': 'student',
      'senderName': payload['senderName'],
      'body': body,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'clientMessageId': clientId,
    };
    messages[_serverId]!.add(message);
    if (commitNextThenHang) {
      commitNextThenHang = false;
      await Completer<void>().future;
    }
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

Future<(AppController, _Api)> _device(
  StudentCase seeded, {
  FakeRepository? repository,
  _Api? server,
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  final api = server ?? _Api();
  final controller = AppController(
    repository: repository ??
        FakeRepository(
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
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Attend [done] (5 s au plus) : une chaîne longue (création distante,
/// réécriture de la file, vidange, relecture) sous une machine chargée.
Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await _settle();
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
      await _until(() => outbox.pendingCount == 0 && api.delivered.isNotEmpty);

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
      api.failNextPosts = CaseMessageOutbox.maxRetries;

      controller.addCaseMessage(_serverId, 'La pièce demandée');
      await _settle();
      CaseMessage bubble() => controller
          .caseById(_serverId)!
          .messages
          .lastWhere((m) => m.body.fr == 'La pièce demandée');
      expect(controller.caseMessageDelivery(bubble()),
          CaseMessageDelivery.pending);

      for (var i = 0; i < CaseMessageOutbox.maxRetries - 1; i++) {
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

  group('relecture de la #408', () {
    CaseMessage bubbleIn(AppController c, String caseId, String text) => c
        .caseById(caseId)!
        .messages
        .firstWhere((m) => m.id.startsWith('user-') && m.body.fr == text);

    test(
        '(a) l\'écho socket d\'un second « Merci » n\'efface pas le premier, '
        'refusé', () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;

      api.rejectNextWith = 400;
      controller.addCaseMessage(_serverId, 'Merci');
      await _settle();
      final refused = bubbleIn(controller, _serverId, 'Merci');
      expect(
          controller.caseMessageDelivery(refused), CaseMessageDelivery.failed);

      // Le second part ; la relecture échoue, l'écho arrive par le socket.
      api.failGetCase = true;
      controller.addCaseMessage(_serverId, 'Merci');
      await _settle();
      controller.ingestRemoteCaseMessage(_serverId, <String, dynamic>{
        'id': 'msg-echo',
        'senderRole': 'student',
        'senderName': 'Test User',
        'body': 'Merci',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      final thread = controller.caseById(_serverId)!.messages;
      final merci = thread.where((m) => m.body.fr == 'Merci').toList();
      expect(merci.map((m) => m.id), containsAll([refused.id, 'msg-echo']));
      expect(merci, hasLength(2), reason: 'l\'écho remplace le second seul');
      expect(
          controller.caseMessageDelivery(refused), CaseMessageDelivery.failed);
    });

    test('(b) « Non envoyé » (4xx) survit au redémarrage et à la synchro',
        () async {
      final repo = FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [_case(_serverId)],
        ),
      );
      final (controller, api) =
          await _device(_case(_serverId), repository: repo);
      api.serverCaseExists = true;
      api.rejectNextWith = 400;
      controller.addCaseMessage(_serverId, 'Trop long');
      await _settle();
      expect(
          controller.caseMessageDelivery(
              bubbleIn(controller, _serverId, 'Trop long')),
          CaseMessageDelivery.failed);

      // Redémarrage : nouveau contrôleur, même disque.
      resetGetxSingleton();
      final (restarted, _) =
          await _device(_case(_serverId), repository: repo, server: api);
      expect(
          restarted
              .caseMessageDelivery(bubbleIn(restarted, _serverId, 'Trop long')),
          CaseMessageDelivery.failed);

      await restarted.syncRemoteData(force: true);
      await _settle();
      expect(
          restarted
              .caseMessageDelivery(bubbleIn(restarted, _serverId, 'Trop long')),
          CaseMessageDelivery.failed,
          reason: 'la copie serveur ne doit pas effacer la bulle');
    });

    test(
        '(b) app tuée pendant le POST : au redémarrage, « en attente », puis '
        'envoyé par la file', () async {
      final repo = FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [_case(_serverId)],
        ),
      );
      final (controller, api) =
          await _device(_case(_serverId), repository: repo);
      api.serverCaseExists = true;
      api.nextPostGate = Completer<void>(); // ne répond jamais
      controller.addCaseMessage(_serverId, 'Ma disponibilité');
      await _settle();

      resetGetxSingleton();
      final server = _Api()..serverCaseExists = true;
      final (restarted, _) =
          await _device(_case(_serverId), repository: repo, server: server);
      expect(
          restarted.caseMessageDelivery(
              bubbleIn(restarted, _serverId, 'Ma disponibilité')),
          CaseMessageDelivery.pending);

      await restarted.flushPendingCaseMessages();
      expect(server.delivered, ['Ma disponibilité']);
      expect(outbox.pendingCount, 0);
    });

    test(
        '(d) une vidange en cours reprend le message du dossier créé '
        'pendant qu\'elle tournait', () async {
      final (controller, api) = await _device(_case(_localId));
      api.serverCaseExists = true; // srv-1 existe déjà pour l'ancien message
      await outbox.enqueue(
        caseId: _serverId,
        body: 'Ancien',
        senderName: 'Test User',
      );
      final slow = Completer<void>();
      api.nextPostGate = slow;
      final running = controller.flushPendingCaseMessages();
      await _settle();

      controller.addCaseMessage(_localId, 'Nouveau');
      await _settle();
      slow.complete();
      await running;
      await _settle();

      expect(api.delivered, ['Ancien', 'Nouveau']);
      expect(outbox.pendingCount, 0);
    });

    test(
        '(f) app tuée APRÈS que le serveur a reçu le POST : au redémarrage, '
        'un seul message côté serveur et une seule bulle', () async {
      final repo = FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [_case(_serverId)],
        ),
      );
      final (controller, api) =
          await _device(_case(_serverId), repository: repo);
      api.serverCaseExists = true;
      api.commitNextThenHang = true;
      controller.addCaseMessage(_serverId, 'Voici le relevé');
      await _settle();
      expect(api.delivered, ['Voici le relevé']);

      // Redémarrage, même serveur (qui a déjà le message).
      resetGetxSingleton();
      final (restarted, _) =
          await _device(_case(_serverId), repository: repo, server: api);
      await restarted.flushPendingCaseMessages();
      await restarted.syncRemoteData(force: true);
      await _settle();

      expect(api.delivered, ['Voici le relevé'],
          reason: 'le renvoi de la file rend le message existant');
      final copies = restarted
          .caseById(_serverId)!
          .messages
          .where((m) => m.body.fr == 'Voici le relevé')
          .toList();
      expect(copies, hasLength(1), reason: 'une seule bulle');
      expect(restarted.caseMessageDelivery(copies.single),
          CaseMessageDelivery.sent);
      expect(outbox.pendingCount, 0);
    });

    test(
        '(f) au redémarrage, la synchro seule suffit : la copie serveur '
        'remplace la bulle et l\'entrée de file ne repart pas', () async {
      final repo = FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [_case(_serverId)],
        ),
      );
      final (controller, api) =
          await _device(_case(_serverId), repository: repo);
      api.serverCaseExists = true;
      api.commitNextThenHang = true;
      controller.addCaseMessage(_serverId, 'Ma réponse');
      await _settle();

      resetGetxSingleton();
      final (restarted, _) =
          await _device(_case(_serverId), repository: repo, server: api);
      final postsBefore = api.postAttempts.length;
      // Le serveur ne répond plus aux POST : seul le rapprochement par
      // identifiant peut éviter le doublon d'affichage.
      api.failNextPosts = 99;
      await restarted.syncRemoteData(force: true);
      await _settle();

      final copies = restarted
          .caseById(_serverId)!
          .messages
          .where((m) => m.body.fr == 'Ma réponse')
          .toList();
      expect(copies, hasLength(1));
      expect(copies.single.id, startsWith('msg-'));
      expect(outbox.pendingCount, 0);
      await restarted.flushPendingCaseMessages();
      expect(api.postAttempts.length, lessThanOrEqualTo(postsBefore + 1));
      expect(api.delivered, ['Ma réponse']);
    });

    test(
        '(g) le corps envoyé n\'a QUE les clés du DTO, en direct comme depuis '
        'la file', () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;

      controller.addCaseMessage(_serverId, 'Direct');
      await _settle();
      await outbox.enqueue(
        caseId: _serverId,
        body: 'Depuis la file',
        senderName: 'Test User',
        localMessageId: 'user-42',
      );
      await controller.flushPendingCaseMessages();

      expect(api.payloads.map((p) => p.keys.toSet()), [
        {'body', 'clientMessageId'},
        {'body', 'clientMessageId'},
      ]);
      expect(api.payloads.last, {
        'body': 'Depuis la file',
        'clientMessageId': 'user-42',
      });
      expect(api.delivered, ['Direct', 'Depuis la file']);
    });

    test(
        '(h) serveur pas encore à jour (refuse clientMessageId) : renvoyé une '
        'fois sans, livré, jamais « Non envoyé »', () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;
      api.legacyServer = true;

      controller.addCaseMessage(_serverId, 'Bonjour');
      await _settle();
      await outbox.enqueue(
        caseId: _serverId,
        body: 'Depuis la file',
        senderName: 'Test User',
        localMessageId: 'user-43',
      );
      await controller.flushPendingCaseMessages();

      expect(api.delivered, ['Bonjour', 'Depuis la file']);
      expect(api.payloads.map((p) => p.keys.toSet()), [
        {'body', 'clientMessageId'},
        {'body'},
        {'body', 'clientMessageId'},
        {'body'},
      ]);
      expect(outbox.pendingCount, 0);
      final bubble = controller
          .caseById(_serverId)!
          .messages
          .lastWhere((m) => m.body.fr == 'Bonjour');
      expect(controller.caseMessageDelivery(bubble), CaseMessageDelivery.sent);
    });

    test('(h) un autre 400 reste un refus définitif, sans renvoi', () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;
      api.rejectNextWith = 400;

      controller.addCaseMessage(_serverId, 'Trop long');
      await _settle();

      expect(api.payloads, hasLength(1));
      final bubble = controller
          .caseById(_serverId)!
          .messages
          .lastWhere((m) => m.body.fr == 'Trop long');
      expect(
          controller.caseMessageDelivery(bubble), CaseMessageDelivery.failed);
    });

    test(
        '(e) une vieille entrée « Ok » d\'un AUTRE dossier ne rend pas « en '
        'attente » une bulle « Ok » envoyée', () async {
      final (controller, api) = await _device(_case(_serverId));
      api.serverCaseExists = true;
      api.failGetCase = true;
      // Entrée d'une version antérieure, sans id de bulle, en échec
      // définitif, dans un autre dossier.
      await outbox.enqueue(
          caseId: 'srv-autre', body: 'Ok', senderName: 'Test User');
      final legacy = outbox.pending.single;
      await outbox.markPermanentFailure(legacy.key, legacy);

      controller.addCaseMessage(_serverId, 'Ok');
      await _settle();

      expect(
          controller.caseMessageDelivery(bubbleIn(controller, _serverId, 'Ok')),
          CaseMessageDelivery.sent);
    });
  });
}
