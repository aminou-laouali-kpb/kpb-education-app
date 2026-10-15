// Les contrats que le test « Mes 10 bourses » ne doit PAS casser :
//   · le PATCH du profil complet ne porte aucune nouvelle clé (test doré) ;
//   · les dossiers : `scholarshipId` passé, dossier ouvert réutilisé ;
//   · l'analytique : constantes du contrat, clés fermées, jamais nationalité,
//     âge, note ni langue ; contrat publié à jour ;
//   · le push : l'enregistrement d'appareil ne porte toujours que le jeton et
//     la plateforme (aucun tag de profil) ;
//   · les traductions : parité FR/EN, aucun « % » ni « chance ».

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/observability/analytics_event_contract.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

import '../../widget_test_helpers.dart';
import 'match_test_support.dart';

class _CapturingApi extends FakeMatchApi {
  final List<Map<String, dynamic>> profilePayloads = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    profilePayloads.add(payload);
    return <String, dynamic>{};
  }
}

/// Les clés que SEUL `POST /scholarships/match/runs` écrit.
const _matchOnlyKeys = <String>{
  'nationalityCode',
  'secondNationalityCode',
  'highestDiploma',
  'scholarshipTargetLevel',
  'gradeBandOn20',
  'englishLevel',
  'frenchLevel',
  'languageTests',
  'workExperienceBand',
  'scholarshipProfileConfirmedAt',
  'scholarshipMatchAlertsOptIn',
  'answers',
  'residence',
};

Future<AppController> _controller(
  FakeMatchApi api, {
  List<StudentCase> cases = const <StudentCase>[],
}) async {
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        cases: cases,
      ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = true;
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

StudentCase _case({
  required String id,
  String? scholarshipId,
  CaseStatus status = CaseStatus.submitted,
  CaseType type = CaseType.scholarshipSupport,
}) {
  final now = DateTime(2026, 10, 1);
  const empty = LocalizedText(fr: '', en: '');
  return StudentCase(
    id: id,
    referenceCode: 'KPB-2026-001',
    type: type,
    title: const LocalizedText(fr: 'Eiffel', en: 'Eiffel'),
    description: empty,
    contextLabel: empty,
    status: status,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: now,
    updatedAt: now,
    nextStepTitle: empty,
    nextStepDescription: empty,
    timeline: const <CaseTimelineEvent>[],
    messages: const <CaseMessage>[],
    documentRequests: const <DocumentRequest>[],
    scholarshipId: scholarshipId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetMatchWorld());
  tearDown(tearDownMatchWorld);

  test('PATCH /profiles/me : AUCUNE clé nouvelle (test doré)', () async {
    final api = _CapturingApi();
    final controller = await _controller(api);
    await controller
        .updateProfile(controller.profile!.copyWith(fullName: 'Awa D.'));

    expect(api.profilePayloads, hasLength(1));
    final keys = api.profilePayloads.single.keys.toSet();
    expect(keys.intersection(_matchOnlyKeys), isEmpty);
    expect(keys, <String>{
      'fullName',
      'phone',
      'whatsApp',
      'countryOfResidence',
      'preferredLanguage',
      'currentLevel',
      'targetLevel',
      'languageLevel',
      'fieldIds',
      'targetCountryIds',
      'gradeRange',
      'bacSeries',
      'annualTuitionBudgetEur',
      'preferredCurrency',
      'wantsScholarshipSupport',
      'scholarshipNewsletterOptIn',
      'disabledNotificationTypes',
      'availableDocuments',
      'aiConsentedAt',
    });
  });

  group('dossiers liés à une bourse', () {
    test('« Être accompagné » envoie scholarshipId au POST /cases', () async {
      final api = FakeMatchApi();
      final controller = await _controller(api);
      controller.submitCase(
        type: CaseType.scholarshipSupport,
        title: 'Candidature — Bourse Eiffel',
        description: 'x',
        contextLabel: 'France',
        contactMethod: ContactMethod.inApp,
        scholarshipId: 'eiffel',
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.createdCases.single['scholarshipId'], 'eiffel');
      expect(controller.cases.first.scholarshipId, 'eiffel');
    });

    test('un dossier sans bourse n\'envoie pas la clé', () async {
      final api = FakeMatchApi();
      final controller = await _controller(api);
      controller.submitCase(
        type: CaseType.consultation,
        title: 't',
        description: 'x',
        contextLabel: 'c',
        contactMethod: ContactMethod.inApp,
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.createdCases.single, isNot(contains('scholarshipId')));
    });

    test('un dossier OUVERT local est réutilisé, sans requête', () async {
      final api = FakeMatchApi();
      final controller = await _controller(api, cases: [
        _case(
            id: 'case-closed',
            scholarshipId: 'eiffel',
            status: CaseStatus.completed),
        _case(id: 'case-open', scholarshipId: 'eiffel'),
      ]);
      final found = await controller.findOpenScholarshipCase('eiffel');
      expect(found!.id, 'case-open');
      expect(api.caseLookups, isEmpty);
    });

    test(
        'sinon GET /cases?scholarshipId= ; une ligne sans le bon lien est '
        'ignorée (serveur plus ancien)', () async {
      final api = FakeMatchApi()
        ..casesForScholarship = <dynamic>[
          {
            'id': 'other',
            'type': 'scholarship_support',
            'status': 'submitted',
            'scholarshipId': null,
          },
          {
            'id': 'remote-1',
            'referenceCode': 'KPB-2026-009',
            'type': 'scholarship_support',
            'status': 'under_review',
            'scholarshipId': 'eiffel',
          },
        ];
      final controller = await _controller(api);
      final found = await controller.findOpenScholarshipCase('eiffel');
      expect(api.caseLookups, ['eiffel']);
      expect(found!.id, 'remote-1');
      expect(found.scholarshipId, 'eiffel');
    });

    test('aucun dossier : null (le compositeur s\'ouvrira)', () async {
      final api = FakeMatchApi();
      final controller = await _controller(api);
      expect(await controller.findOpenScholarshipCase('eiffel'), isNull);
    });
  });

  group('analytique scholarship_match_*', () {
    test('treize noms ≤ 40 caractères, tous au contrat publié', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      expect(AnalyticsEventName.scholarshipMatchEvents, hasLength(13));
      for (final name in AnalyticsEventName.scholarshipMatchEvents) {
        expect(name, startsWith('scholarship_match_'));
        expect(name.length, lessThanOrEqualTo(40), reason: name);
        expect(doc, contains('`$name`'), reason: '$name absent du contrat');
      }
    });

    test('clés fermées : une clé personnelle est RETIRÉE avant l\'envoi', () {
      final params = AnalyticsService.scholarshipMatchParams(<String, Object?>{
        'source': 'scholarships_tab',
        'missing_count': 3,
        'is_rerun': true,
        'nationality': 'ner',
        'age': 17,
        'birth_date': '2009-05-10',
        'grade': '12_14',
        'english_level': 'b1',
      });
      expect(params, {
        'source': 'scholarships_tab',
        'missing_count': 3,
        'is_rerun': 1,
      });
    });

    test('aucune clé autorisée ne désigne une donnée personnelle', () {
      final personal = RegExp(
        r'national|country|pays|age$|^age|birth|naissance|grade|note|'
        r'english|french|langu|score|name|mail|phone|whatsapp',
        caseSensitive: false,
      );
      for (final key in AnalyticsService.scholarshipMatchAllowedParams) {
        expect(personal.hasMatch(key), isFalse, reason: key);
      }
    });

    test('les étapes partent sous des identifiants fermés, jamais une valeur',
        () async {
      final sent = <String, Map<String, Object>>{};
      AnalyticsService.instance.logEventSink =
          (name, params) async => sent[name] = params;
      addTearDown(() => AnalyticsService.instance.logEventSink = null);
      await AnalyticsService.instance.logScholarshipMatchStepCompleted(
        step: 'nationality',
        changedPrefill: false,
      );
      expect(sent['scholarship_match_step_completed'], {
        'match_step': 'nationality',
        'changed_prefill': 0,
      });
    });
  });

  test('push : l\'enregistrement d\'appareil ne porte que jeton et plateforme',
      () {
    final client = File('lib/app/core/repositories/app_api_client.dart')
        .readAsStringSync();
    final register = RegExp(
      r"'/device-tokens',\s*data: <String, dynamic>\{'token': token, "
      r"'platform': platform\}",
    );
    expect(register.hasMatch(client), isTrue);
    for (final path in [
      'lib/app/core/services/push_service.dart',
      'lib/app/core/services/push_permission.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final forbidden in [
        'nationality',
        'birthDate',
        'gradeBand',
        'englishLevel',
        'scholarshipMatch',
      ]) {
        expect(source.contains(forbidden), isFalse,
            reason: '$path mentionne $forbidden');
      }
    }
  });

  test('traductions : parité FR/EN, ni « % » ni « chance »', () {
    final keys = AppTranslations().keys;
    final fr =
        keys['fr']!.keys.where((k) => k.startsWith('scholarship_match_'));
    final en =
        keys['en']!.keys.where((k) => k.startsWith('scholarship_match_'));
    expect(fr.toSet(), en.toSet());
    expect(fr.length, greaterThan(100));
    for (final lang in ['fr', 'en']) {
      for (final key in fr) {
        final value = keys[lang]![key]!;
        expect(value.contains('%'), isFalse, reason: '$lang/$key');
        expect(value.toLowerCase().contains('chance'), isFalse,
            reason: '$lang/$key');
      }
    }
  });
}
