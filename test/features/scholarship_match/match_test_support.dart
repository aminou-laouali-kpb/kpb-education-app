// Fixtures et faux partagés par les tests du test « Mes 10 bourses ».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/scholarship_match.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/pending_intent_store.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/services/scholarship_match_store.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/scholarship_match/scholarship_match_entry_card.dart';

import '../../widget_test_helpers.dart';

/// Un élément de run, au format servi.
Map<String, dynamic> matchItemJson({
  required String id,
  int rank = 1,
  String section = 'compatible',
  String status = 'eligible',
  bool isNew = false,
  bool available = true,
  String name = 'Bourse',
  List<Map<String, dynamic>>? reasons,
  List<Map<String, dynamic>>? toVerify,
  Map<String, dynamic>? window,
}) =>
    <String, dynamic>{
      'scholarshipId': id,
      'cycleId': 'cycle-$id',
      'rank': rank,
      'section': section,
      'status': status,
      'isNew': isNew,
      'available': available,
      'name': name,
      'scholarship': available
          ? <String, dynamic>{
              'countryId': 'fra',
              'countryName': 'France',
              'fundingType': 'fully_funded',
              'fundingLabel': 'Financement complet',
              'levelLabel': 'Master',
              'deadlineAt': null,
              'deadlineLabel': 'Date à confirmer',
              'applicationUrl': 'https://exemple.org/apply',
              'sourceUrl': 'https://exemple.org',
            }
          : null,
      'window': available
          ? (window ??
              <String, dynamic>{
                'cycleId': 'cycle-$id',
                'academicYear': '2027-2028',
                'status': 'open',
                'dateConfidence': 'confirmed',
                'opensAt': '2026-09-01T00:00:00.000Z',
                'closesAt': '2026-11-15T23:59:59.000Z',
                'estimatedOpenAt': null,
                'estimatedCloseAt': null,
              })
          : null,
      'reasons': reasons ??
          <Map<String, dynamic>>[
            {
              'code': 'nationality_accepted',
              'label': 'Ouverte aux ressortissants du Niger'
            },
            {'code': 'level_accepted', 'label': 'Niveau Master accepté'},
          ],
      'toVerify': toVerify ?? <Map<String, dynamic>>[],
    };

Map<String, dynamic> matchRunJson({
  String id = 'run-1',
  List<Map<String, dynamic>>? items,
  Map<String, dynamic>? levelCatalog,
  String? precisionLimitedBy,
  Map<String, dynamic>? excludedSummary,
}) =>
    <String, dynamic>{
      'id': id,
      'createdAt': '2026-10-13T12:00:00.000Z',
      'algorithmVersion': 'sm-1',
      'trigger': 'wizard',
      'counts': {
        'eligible': 2,
        'toVerify': 1,
        'excluded': 12,
        'notAnalyzed': 3,
        'candidates': 18,
      },
      'items': items ??
          <Map<String, dynamic>>[
            matchItemJson(id: 'eiffel', name: 'Bourse Eiffel'),
            matchItemJson(id: 'turkiye', rank: 2, name: 'Türkiye Burslari'),
            matchItemJson(
              id: 'mcf',
              rank: 3,
              section: 'to_verify',
              status: 'to_verify',
              name: 'Mastercard Foundation',
              toVerify: [
                {
                  'code': 'language_missing',
                  'label': 'IELTS 6.5 demandé — tu n’as pas indiqué de score',
                  'official': {
                    'text': 'Minimum 70 % average and IELTS 6.5',
                    'sourceUrl': 'https://exemple.org/conditions',
                  },
                },
              ],
            ),
          ],
      'excludedSummary': excludedSummary ??
          {
            'groups': [
              {
                'group': 'level',
                'count': 12,
                'label': '12 visent un autre niveau',
                'scholarships': [
                  {'id': 'uwc', 'name': 'UWC Kenya'},
                ],
              },
            ],
            'notAnalyzedCount': 3,
            'notAnalyzedLabel':
                '3 bourses récentes pas encore analysées par KPB',
          },
      'levelCatalog': levelCatalog,
      'precisionLimitedBy': precisionLimitedBy,
    };

/// Un état servi : par défaut, un compte créé par « Passer » (presque tout
/// manque) avec une clé inconnue de cette build.
Map<String, dynamic> matchStateJson({
  List<String>? required,
  List<String>? toConfirm,
  List<Map<String, dynamic>>? prefill,
  Map<String, dynamic>? answers,
  Map<String, dynamic>? latestRun,
  bool isStale = false,
  bool alertsOptIn = false,
  List<String>? targetLevelOptions,
}) =>
    <String, dynamic>{
      'algorithmVersion': 'sm-1',
      'readiness': {
        'ready': false,
        'required': required ??
            <String>[
              'nationalityCode',
              'birthDate',
              'highestDiploma',
              'scholarshipTargetLevel',
              'fields',
              'gradeBandOn20',
              'englishLevel',
              'futureUnknownKey',
            ],
        'toConfirm': toConfirm ?? <String>[],
        'optional': ['languageTests', 'targetCountryIds'],
        'targetLevelOptions':
            targetLevelOptions ?? ['bachelor', 'master', 'doctorate'],
      },
      'prefill': prefill ??
          <Map<String, dynamic>>[
            {
              'key': 'residence',
              'value': 'ner',
              'source': 'countryOfResidence',
              'ambiguous': false,
            },
          ],
      'answers': answers ??
          <String, dynamic>{
            'nationalityCode': null,
            'residence': 'ner',
            'birthDate': null,
            'guardianConsented': false,
            'fieldIds': <String>[],
            'targetCountryIds': <String>[],
            'languageTests': <dynamic>[],
            'confirmedAt': null,
          },
      'options': {
        'version': 'abcdef0123456789',
        'countries': [
          {'code': 'ner', 'name': 'Niger', 'priority': true},
          {'code': 'sen', 'name': 'Sénégal', 'priority': true},
          {'code': 'tcd', 'name': 'Tchad', 'priority': true},
          {'code': 'fra', 'name': 'France', 'priority': false},
        ],
        'destinations': [
          {'id': 'fra', 'name': 'France'},
          {'id': 'int', 'name': 'International'},
        ],
        'fields': [
          {'id': 'd01', 'name': 'Informatique'},
          {'id': 'd02', 'name': 'Droit'},
        ],
      },
      'latestRun': latestRun,
      'isStale': isStale,
      'staleReasons': isStale ? ['profile'] : <String>[],
      'catalogSize': 29,
      'alertsOptIn': alertsOptIn,
    };

/// Client de test : les routes du test, comptées.
class FakeMatchApi extends MockApiClient {
  FakeMatchApi({Map<String, dynamic>? state})
      : stateJson = state ?? matchStateJson();

  Map<String, dynamic> stateJson;
  Object? stateError;
  int stateCalls = 0;

  final List<Map<String, dynamic>> runCalls = <Map<String, dynamic>>[];
  Object? runError;
  Map<String, dynamic> runResponse = <String, dynamic>{
    'status': 'ok',
    'run': matchRunJson(),
    'diff': {
      'previousRunId': null,
      'addedIds': <String>[],
      'removedIds': <String>[]
    },
  };

  final List<bool> alertCalls = <bool>[];
  Object? alertsError;

  final List<List<String>> bulkCalls = <List<String>>[];
  final List<String> caseLookups = <String>[];
  List<dynamic> casesForScholarship = <dynamic>[];
  final List<Map<String, dynamic>> createdCases = <Map<String, dynamic>>[];

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<ScholarshipMatchState> fetchScholarshipMatchState({
    required String lang,
  }) async {
    stateCalls++;
    final error = stateError;
    if (error != null) throw error;
    return ScholarshipMatchState.fromJson(stateJson);
  }

  @override
  Future<MatchRunResponse> createScholarshipMatchRun({
    required String lang,
    Map<String, dynamic>? answers,
    bool confirm = false,
    String trigger = 'wizard',
  }) async {
    runCalls.add(<String, dynamic>{
      'lang': lang,
      'answers': answers,
      'confirm': confirm,
      'trigger': trigger,
    });
    final error = runError;
    if (error != null) throw error;
    // Comme le serveur : le run calculé devient le dernier run de l'état.
    if (runResponse['status'] == 'ok') {
      stateJson = <String, dynamic>{
        ...stateJson,
        'latestRun': runResponse['run'],
        'isStale': false,
      };
    }
    return MatchRunResponse.fromJson(runResponse)!;
  }

  @override
  Future<bool> setScholarshipMatchAlerts({required bool enabled}) async {
    alertCalls.add(enabled);
    final error = alertsError;
    if (error != null) throw error;
    return enabled;
  }

  @override
  Future<MatchBulkFollowResult> subscribeScholarshipAlertsBulk(
    List<String> scholarshipIds,
  ) async {
    bulkCalls.add(List<String>.of(scholarshipIds));
    return MatchBulkFollowResult(subscribedIds: scholarshipIds);
  }

  @override
  Future<List<dynamic>> listCasesForScholarship(String scholarshipId) async {
    caseLookups.add(scholarshipId);
    return casesForScholarship;
  }

  @override
  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) async {
    createdCases.add(payload);
    // Comme le serveur : le dossier créé, lien compris.
    return <String, dynamic>{
      ...payload,
      'id': 'remote-case-${createdCases.length}',
      'referenceCode': 'KPB-2026-10${createdCases.length}',
      'status': 'submitted',
    };
  }

  @override
  Future<Map<String, dynamic>> createSavedItem(
    Map<String, dynamic> payload,
  ) async =>
      <String, dynamic>{'id': 'saved-${payload['itemId']}'};

  @override
  Future<Map<String, dynamic>> getSuccessLabAccess() async =>
      <String, dynamic>{'enabled': false};
}

/// Remet à zéro tout ce que ces tests touchent.
MemoryScholarshipMatchCache resetMatchWorld({bool flag = true}) {
  Get.reset();
  RemoteFeatureFlags.resetForTest();
  if (flag) {
    RemoteFeatureFlags.instance.debugSetFeaturesForTest(
        const <String, bool>{'scholarshipMatch': true});
  }
  final cache = MemoryScholarshipMatchCache();
  ScholarshipMatchStore.instance.debugReset(cache: cache);
  PendingIntentStore.debugStorage = MemoryPendingIntentStorage();
  ScholarshipMatchEntryCard.resetViewedForTest();
  return cache;
}

void tearDownMatchWorld() {
  AppConfig.enableRemoteSyncOverride = null;
  AppConfig.scholarshipMatchEnabledOverride = null;
  RemoteFeatureFlags.resetForTest();
  PendingIntentStore.debugStorage = null;
  Get.reset();
}

/// Monte [child] dans une app traduite (français), avec un AppController
/// hydraté depuis [snapshot].
Future<AppController> pumpMatchApp(
  WidgetTester tester, {
  required Widget child,
  required FakeMatchApi api,
  AppSnapshot? snapshot,
  bool remoteSync = false,
}) async {
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: snapshot ??
          AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(),
          ),
    ),
    apiClient: api,
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = remoteSync;
  Get.put<AppController>(controller, permanent: true);
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Un snapshot de parent.
AppSnapshot parentSnapshot() => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(accountType: AccountType.parent),
    );

/// Un snapshot d'invité.
AppSnapshot guestSnapshot() => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      isGuestMode: true,
    );

/// Tous les textes rendus.
List<String> renderedTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toList();
