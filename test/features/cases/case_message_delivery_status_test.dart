// Revue avant la 58, constats 18 et 20, côté écran.
//
// - Une bulle de l'élève dont l'envoi n'est pas confirmé affiche « En attente
//   d'envoi » ; refusée, « Non envoyé » avec « Réessayer ». Avant, toute bulle
//   s'affichait comme envoyée.
// - L'écran ouvert sur l'id local d'un dossier tout juste créé suit le dossier
//   sous son id serveur au lieu de passer à « Dossier introuvable ».
//
// Les messages sont envoyés par le contrôleur, pas par la zone de saisie (qui
// peut être masquée derrière un drapeau) : ce qui est vérifié ici, c'est
// l'affichage de l'état.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/connectivity_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/cases/case_detail_screen.dart';

import '../../widget_test_helpers.dart';

class _Api extends MockApiClient {
  Completer<Map<String, dynamic>>? postGate;
  int? rejectWith;
  final List<String> delivered = [];

  Map<String, dynamic> _caseJson(String id) => <String, dynamic>{
        'id': id,
        'referenceCode': 'KPB-1134',
        'type': 'CONSULTATION',
        'title': 'Dossier Campus France',
        'status': 'SUBMITTED',
        'createdAt': DateTime(2026, 11, 1).toUtc().toIso8601String(),
        'updatedAt': DateTime(2026, 11, 1).toUtc().toIso8601String(),
        'messages': [
          for (var i = 0; i < delivered.length; i++)
            <String, dynamic>{
              'id': 'msg-$i',
              'senderRole': 'student',
              'senderName': 'Test User',
              'body': delivered[i],
              'createdAt': DateTime(2026, 11, 1).toUtc().toIso8601String(),
            },
        ],
      };

  @override
  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) async =>
      _caseJson('srv-1');

  @override
  Future<Map<String, dynamic>> createCaseMessage(
    String caseId,
    Map<String, dynamic> payload,
  ) async {
    final gate = postGate;
    if (gate != null) return gate.future;
    final status = rejectWith;
    if (status != null) {
      final options = RequestOptions(path: '/cases/$caseId/messages');
      throw DioException(
        requestOptions: options,
        response:
            Response<dynamic>(requestOptions: options, statusCode: status),
        type: DioExceptionType.badResponse,
      );
    }
    delivered.add(payload['body'] as String);
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getCase(String caseId) async =>
      _caseJson(caseId);
}

StudentCase _case(String id) {
  final at = DateTime(2026, 11, 1);
  return StudentCase(
    id: id,
    referenceCode: 'KPB-2026-001',
    type: CaseType.consultation,
    title: const LocalizedText(
        fr: 'Dossier Campus France', en: 'Campus France case'),
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

final _fr = AppTranslations().keys['fr']!;

Future<AppController> _pump(
  WidgetTester tester,
  _Api api,
  StudentCase seeded,
) async {
  setupPlatformChannelMocks();
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  AppConfig.enableRemoteSyncOverride = false;
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
  controller.outboxRetryDelay = const Duration(hours: 1);

  await tester.pumpWidget(GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr'),
    fallbackLocale: const Locale('fr'),
    home: CaseDetailScreen(caseId: seeded.id),
  ));
  await tester.pump();
  return controller;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  setUp(() {
    resetGetxSingleton();
    ConnectivityService.instance.debugSetOnline(true);
  });

  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  testWidgets('un message dont l\'envoi n\'est pas confirmé est « en attente »',
      (tester) async {
    final api = _Api()..postGate = Completer<Map<String, dynamic>>();
    final controller = await _pump(tester, api, _case('srv-1'));

    controller.addCaseMessage('srv-1', 'Voici mes relevés');
    await tester.pump();
    // ignore: avoid_print

    expect(find.text('Voici mes relevés'), findsOneWidget);
    expect(find.text(_fr['case_message_pending']!), findsOneWidget);

    api.postGate!.complete(<String, dynamic>{});
    api.delivered.add('Voici mes relevés');
    await tester.pump();
    await tester.pump();
    expect(find.text(_fr['case_message_pending']!), findsNothing);
    expect(find.text('Voici mes relevés'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refusé : « Non envoyé », et « Réessayer » le renvoie',
      (tester) async {
    final api = _Api()..rejectWith = 400;
    final controller = await _pump(tester, api, _case('srv-1'));

    controller.addCaseMessage('srv-1', 'Mon message');
    await tester.pump();
    await tester.pump();

    expect(find.text(_fr['case_message_failed']!), findsOneWidget);
    expect(find.text(_fr['retry']!), findsOneWidget);
    // Laisse le bandeau d'erreur se refermer.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    api.rejectWith = null;
    await tester.tap(find.text(_fr['retry']!));
    await tester.pump();
    await tester.pump();

    expect(api.delivered, ['Mon message']);
    expect(find.text(_fr['case_message_failed']!), findsNothing);
    expect(find.text('Mon message'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'ouvert sur l\'id local, l\'écran suit le dossier après sa création '
      'distante', (tester) async {
    final api = _Api();
    final controller = await _pump(tester, api, _case('case-1700000000000'));
    expect(find.text('Dossier Campus France'), findsWidgets);

    // Un message écrit dans le dossier encore local lance sa création.
    controller.addCaseMessage('case-1700000000000', 'Bonjour');
    await tester.pump();
    await tester.pump();

    expect(controller.resolveCaseId('case-1700000000000'), 'srv-1');
    expect(find.text(_fr['case_not_found_body_title']!), findsNothing);
    expect(find.text('Dossier Campus France'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
