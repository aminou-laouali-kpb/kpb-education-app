// Revue avant la 58 — lot « dossier à l'écran » (constats 28, 33, 34, 35, 36,
// 37). Chaque groupe échoue sans son correctif :
//
// * 33 — la saisie de message du dossier est fermée (drapeau AppConfig) et
//   remplacée par « Écrire à ton conseiller sur WhatsApp », référence
//   préremplie ; les messages déjà présents restent affichés.
// * 34 — le tunnel ne présélectionne plus « Dans l'application ».
// * 35 — la date du rendez-vous apparaît dans la carte « Prochaine étape ».
// * 36 — l'historique montre la description, pas seulement le titre.
// * 37 — le fil se lit du plus ancien au plus récent.
// * 28 — la ligne de méta de la liste des dossiers n'est plus en textFaint.
//
// Traductions branchées (FR) : on affirme ce que l'élève lit, pas une clé.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/case_api_codec.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/components/verified_advisor_sheet.dart';
import 'package:karatou/app/features/cases/case_appointment.dart';
import 'package:karatou/app/features/cases/case_detail_screen.dart';
import 'package:karatou/app/features/cases/case_tunnel_flow.dart';
import 'package:karatou/app/features/cases/cases_screen.dart';

import '../../widget_test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

final _now = DateTime(2026, 11, 3, 9);

StudentCase _case({
  List<CaseMessage> messages = const [],
  List<CaseTimelineEvent> timeline = const [],
  DateTime? scheduledAt,
  String? advisor = 'Awa Traoré',
}) =>
    StudentCase(
      id: 'srv-58',
      referenceCode: 'KPB-2026-058',
      type: CaseType.consultation,
      title: const LocalizedText(fr: 'Master en France', en: 'Master France'),
      description: const LocalizedText(fr: 'Desc', en: 'Desc'),
      contextLabel: const LocalizedText(fr: 'France', en: 'France'),
      status: scheduledAt == null
          ? CaseStatus.counselorAssigned
          : CaseStatus.scheduled,
      preferredContactMethod: ContactMethod.whatsapp,
      createdAt: _now.subtract(const Duration(days: 2)),
      updatedAt: _now,
      nextStepTitle: const LocalizedText(
          fr: 'Prépare ton rendez-vous', en: 'Prepare your appointment'),
      nextStepDescription: const LocalizedText(fr: '', en: ''),
      timeline: timeline,
      messages: messages,
      documentRequests: const [],
      assignedAdvisorName: advisor,
      scheduledAt: scheduledAt,
    );

Future<void> _seed(StudentCase c, {String locale = 'fr'}) async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: locale,
        hasCompletedOnboarding: true,
        isGuestMode: false,
        profile: createTestProfile(),
        cases: [c],
      ),
    ),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  // L'app livrée force le français (`kShippedLocale`) : pour exercer le chemin
  // anglais, on règle la langue du contrôleur après l'hydratation.
  controller.localeCode = locale;
  Get.put<AppController>(controller, permanent: true);

  final auth = _MockAuthService();
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  when(() => auth.isLoggedIn).thenReturn(false);
  Get.put<AuthService>(auth, permanent: true);
}

Widget _wrap(Widget home, {String locale = 'fr'}) => GetMaterialApp(
      translations: AppTranslations(),
      locale: Locale(locale),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpDetail(WidgetTester tester, StudentCase c,
    {String locale = 'fr'}) async {
  setupPlatformChannelMocks();
  await _seed(c, locale: locale);
  _tallPhone(tester);
  await tester.pumpWidget(
    _wrap(Scaffold(body: CaseDetailScreen(caseId: c.id)), locale: locale),
  );
  await tester.pumpAndSettle();
}

String _fr(String key) => AppTranslations().keys['fr']![key]!;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  setUp(resetGetxSingleton);
  tearDown(() {
    AppConfig.caseInAppMessagingEnabledOverride = null;
    resetGetxSingleton();
  });

  group('constat 33 — messagerie fermée, renvoi WhatsApp', () {
    testWidgets('par défaut : pas de champ de saisie, bouton WhatsApp',
        (tester) async {
      await _pumpDetail(tester, _case());

      expect(AppConfig.caseInAppMessagingEnabled, isFalse);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(_fr('message_input_hint')), findsNothing);
      expect(find.text(_fr('send_message_hint')), findsNothing);
      expect(find.text(_fr('case_messages_whatsapp_hint')), findsOneWidget);
      expect(find.text('Écrire à ton conseiller sur WhatsApp'), findsOneWidget);
    });

    testWidgets('le bouton préremplit WhatsApp avec la référence du dossier',
        (tester) async {
      await _pumpDetail(tester, _case());

      await tester.ensureVisible(
          find.byKey(const ValueKey('case-write-advisor-whatsapp')));
      await tester
          .tap(find.byKey(const ValueKey('case-write-advisor-whatsapp')));
      await tester.pumpAndSettle();

      final sheet = tester.widget<KpbVerifiedAdvisorSheet>(
          find.byType(KpbVerifiedAdvisorSheet));
      expect(sheet.prefill, contains('KPB-2026-058'));
      expect(sheet.advisorName, 'Awa Traoré');
    });

    testWidgets(
        'sans conseiller attribué : ligne officielle KPB, avec la référence',
        (tester) async {
      await _pumpDetail(tester, _case(advisor: null));

      expect(find.text('Écrire à ton conseiller sur WhatsApp'), findsNothing);
      expect(find.text(_fr('case_messages_whatsapp_hint')), findsNothing);
      expect(
          find.text(_fr('case_messages_whatsapp_hint_team')), findsOneWidget);
      final button = find.byKey(const ValueKey('case-write-advisor-whatsapp'));
      expect(
          find.descendant(
              of: button, matching: find.text(_fr('case_write_kpb_whatsapp'))),
          findsOneWidget);

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      final sheet = tester.widget<KpbVerifiedAdvisorSheet>(
          find.byType(KpbVerifiedAdvisorSheet));
      expect(sheet.advisorName, isNull);
      // Aucun numéro passé : la fiche et l'ouverture visent la ligne
      // officielle KPB (AppConfig.whatsappNumber).
      expect(sheet.expectedNumber, isNull);
      expect(sheet.prefill, contains('KPB-2026-058'));
    });

    testWidgets('les messages déjà présents restent affichés', (tester) async {
      await _pumpDetail(
        tester,
        _case(messages: [
          CaseMessage(
            id: 'm1',
            senderName: 'KPB Operations',
            senderRole: 'system',
            body: const LocalizedText(
                fr: 'Merci pour ta demande.', en: 'Thanks.'),
            createdAt: _now,
          ),
        ]),
      );

      expect(find.text('Merci pour ta demande.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
        'drapeau ouvert : la saisie revient, WhatsApp reste proposé (build 59)',
        (tester) async {
      AppConfig.caseInAppMessagingEnabledOverride = true;
      await _pumpDetail(tester, _case());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Écrire à ton conseiller sur WhatsApp'), findsOneWidget);
    });
  });

  group('constat 34 — canal de contact du tunnel', () {
    test(
        '« Dans l’application » n’est proposé que si la messagerie est ouverte',
        () {
      expect(kCaseTunnelContactMethods, isNot(contains(ContactMethod.inApp)));
      expect(kCaseTunnelContactMethods, contains(ContactMethod.whatsapp));
      AppConfig.caseInAppMessagingEnabledOverride = true;
      expect(kCaseTunnelContactMethods, contains(ContactMethod.inApp));
    });

    testWidgets('l’étape Message présélectionne WhatsApp', (tester) async {
      setupPlatformChannelMocks();
      await _seed(_case());
      _tallPhone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(
        body: CaseTunnelFlow(
          prefill: CaseTunnelPrefill(
            title: 'Master en France',
            contextLabel: 'France • master',
          ),
        ),
      )));
      await tester.pumpAndSettle();
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.text('common_next'.tr));
        await tester.pumpAndSettle();
      }

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final labels = chips.map((c) => ((c.label as Text).data ?? '')).toList();
      expect(labels, isNot(contains(_fr('case_contact_inapp'))));
      final selected = chips.where((c) => c.selected).toList();
      expect(selected, hasLength(1));
      expect((selected.single.label as Text).data, _fr('whatsapp'));
    });
  });

  group('constat 35 — date du rendez-vous', () {
    testWidgets('la carte « Prochaine étape » affiche la date et l’heure',
        (tester) async {
      final rdv = DateTime.now().add(const Duration(days: 3));
      await _pumpDetail(tester, _case(scheduledAt: rdv));

      expect(
        find.text(caseAppointmentLabel(rdv, 'fr')!),
        findsOneWidget,
      );
      expect(find.textContaining('Rendez-vous :'), findsOneWidget);
    });

    testWidgets('un rendez-vous passé n’est plus affiché', (tester) async {
      await _pumpDetail(
        tester,
        _case(scheduledAt: DateTime.now().subtract(const Duration(days: 2))),
      );
      expect(find.textContaining('Rendez-vous :'), findsNothing);
    });

    testWidgets('format : date et heure, année seulement si elle diffère',
        (tester) async {
      // Traductions chargées par GetMaterialApp : le libellé est le vrai.
      await tester.pumpWidget(_wrap(const SizedBox()));
      final now = DateTime(2026, 11, 8, 9);
      expect(
        caseAppointmentLabel(DateTime(2026, 11, 10, 14), 'fr', now: now),
        'Rendez-vous : mardi 10 nov. à 14 h 00',
      );
      expect(
        caseAppointmentLabel(DateTime(2027, 1, 12, 9, 30), 'fr', now: now),
        'Rendez-vous : mardi 12 janv. 2027 à 09 h 30',
      );
      expect(
        caseAppointmentLabel(DateTime(2026, 11, 2, 14), 'fr', now: now),
        isNull,
      );
    });

    testWidgets('sans rendez-vous, rien n’est inventé', (tester) async {
      await _pumpDetail(tester, _case());
      expect(find.textContaining('Rendez-vous :'), findsNothing);
    });
  });

  group('constat 36 — historique lisible', () {
    testWidgets('la description de l’événement est affichée sous le titre',
        (tester) async {
      await _pumpDetail(
        tester,
        _case(timeline: [
          CaseTimelineEvent(
            id: 'e1',
            title: const LocalizedText(fr: 'Action ajoutée', en: 'Task'),
            description: const LocalizedText(
              fr: 'L’action « Relevé de notes » a été ajoutée à ton dossier.',
              en: 'x',
            ),
            createdAt: _now,
            status: CaseStatus.counselorAssigned,
          ),
        ]),
      );

      expect(find.text('Action ajoutée'), findsOneWidget);
      expect(
        find.text('L’action « Relevé de notes » a été ajoutée à ton dossier.'),
        findsOneWidget,
      );
    });
  });

  group('relecture #407 — descriptions déjà en base', () {
    testWidgets('« vous » réécrit au « tu », anglais interne masqué',
        (tester) async {
      CaseTimelineEvent ev(String id, String title, String desc) =>
          CaseTimelineEvent(
            id: id,
            title: LocalizedText(fr: title, en: title),
            description: LocalizedText(fr: desc, en: desc),
            createdAt: _now,
            status: CaseStatus.counselorAssigned,
          );
      await _pumpDetail(
        tester,
        _case(timeline: [
          ev('e1', 'Conseiller attribué',
              'Votre dossier a été attribué à Awa Traoré.'),
          ev('e2', 'Dossier réattribué',
              'Auto-reassigned after 10h inactivity to Awa Traoré.'),
          ev('e3', 'Point de suivi', 'Merci de nous envoyer vos relevés.'),
          ev('e4', 'Note', 'Internal: lead to follow up.'),
        ]),
      );

      expect(find.text('Ton dossier a été attribué à Awa Traoré.'),
          findsOneWidget);
      expect(find.text('Ton dossier a été réattribué à Awa Traoré.'),
          findsOneWidget);
      expect(find.textContaining('Votre'), findsNothing);
      expect(find.textContaining('vos relevés'), findsNothing);
      expect(find.textContaining('Auto-reassigned'), findsNothing);
      expect(find.textContaining('Internal'), findsNothing);
      // Le titre reste : rien ne disparaît de l'historique.
      expect(find.text('Point de suivi'), findsOneWidget);
    });
  });

  group('2e relecture #407 — langue et « Prochaine étape »', () {
    CaseTimelineEvent ev(String id, String title, String desc) =>
        CaseTimelineEvent(
          id: id,
          title: LocalizedText(fr: title, en: title),
          description: LocalizedText(fr: desc, en: desc),
          createdAt: _now,
          status: CaseStatus.counselorAssigned,
        );

    testWidgets('en anglais : descriptions anglaises affichées telles quelles',
        (tester) async {
      await _pumpDetail(
        tester,
        _case(timeline: [
          ev('e1', 'Request sent',
              'Your request is in the “My Cases” tab. The KPB team has received it.'),
          ev('e2', 'New message',
              'The case has been updated with a new message.'),
          ev('e3', 'Case reassigned',
              'Auto-reassigned after 10h inactivity to Awa Traoré.'),
        ]),
        locale: 'en',
      );

      expect(
          find.text(
              'Your request is in the “My Cases” tab. The KPB team has received it.'),
          findsOneWidget);
      expect(find.text('The case has been updated with a new message.'),
          findsOneWidget);
      // Le jargon interne reste masqué, et rien n'est passé en français.
      expect(find.textContaining('Auto-reassigned'), findsNothing);
      expect(find.textContaining('Ton dossier'), findsNothing);
    });

    testWidgets('« Prochaine étape » d’un vieux dossier réécrite au « tu »',
        (tester) async {
      final vieux = _case().copyWith(
        nextStepTitle: const LocalizedText(
            fr: 'Préparez votre rendez-vous', en: 'Préparez votre rendez-vous'),
        nextStepDescription: const LocalizedText(
            fr: 'Confirmez votre disponibilité et préparez vos pièces justificatives.',
            en: 'Confirmez votre disponibilité et préparez vos pièces justificatives.'),
      );
      await _pumpDetail(tester, vieux);

      expect(find.text('Prépare ton rendez-vous'), findsOneWidget);
      expect(
          find.text(
              'Confirme ta disponibilité et prépare tes pièces justificatives.'),
          findsOneWidget);
      expect(find.textContaining('Préparez votre'), findsNothing);
    });

    testWidgets('« Prochaine étape » inconnue : jamais effacée',
        (tester) async {
      final libre = _case().copyWith(
        nextStepTitle: const LocalizedText(fr: 'Envoyez vos relevés', en: 'x'),
      );
      await _pumpDetail(tester, libre);
      expect(find.text('Envoyez vos relevés'), findsOneWidget);
    });
  });

  group('3e relecture #407 — « Prochaine étape » sur la liste', () {
    testWidgets('un vieux dossier au « vous » est tutoyé dans la liste',
        (tester) async {
      final vieux = _case().copyWith(
        nextStepTitle: const LocalizedText(
            fr: 'Préparez votre rendez-vous', en: 'Préparez votre rendez-vous'),
      );
      await pumpTestApp(
        tester,
        child: const CasesScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          isGuestMode: false,
          profile: createTestProfile(),
          cases: [vieux],
        ),
      );

      expect(find.text('Prépare ton rendez-vous'), findsOneWidget);
      expect(find.textContaining('Préparez votre'), findsNothing);
    });
  });

  group('constat 37 — ordre du fil', () {
    test('le codec range les messages du plus ancien au plus récent', () {
      final c = CaseApiCodec.studentCaseFromApi(<String, dynamic>{
        'id': 'c1',
        'referenceCode': 'KPB-2026-1',
        'createdAt': '2026-11-01T08:00:00.000Z',
        'updatedAt': '2026-11-01T12:00:00.000Z',
        'messages': [
          {
            'id': 'recent',
            'body': 'Bonjour',
            'senderRole': 'student',
            'createdAt': '2026-11-01T11:00:00.000Z',
          },
          {
            'id': 'ancien',
            'body': 'Merci pour ta demande.',
            'senderRole': 'system',
            'createdAt': '2026-11-01T10:00:00.000Z',
          },
        ],
      });
      expect(c.messages.map((m) => m.id), ['ancien', 'recent']);
    });
  });

  group('constat 28 — contraste de la liste des dossiers', () {
    testWidgets('référence et date de mise à jour en textMuted',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const CasesScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          isGuestMode: false,
          profile: createTestProfile(),
          cases: [_case()],
        ),
      );

      final reference = tester.widget<Text>(find.text('KPB-2026-058'));
      expect(reference.style?.color, KpbColors.textMuted);
      final updated =
          tester.widget<Text>(find.textContaining('updated_on').first);
      expect(updated.style?.color, KpbColors.textMuted);
    });
  });
}
