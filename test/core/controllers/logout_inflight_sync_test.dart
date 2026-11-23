// Audit du 22/11/2026, n° 3 — déconnexion pendant une synchro en vol.
//
// `logout()` remet l'état à zéro tout de suite, mais la session Supabase reste
// valide encore quelques secondes (retrait du jeton push). Les réponses de la
// synchro lancée à la connexion (profil, dossiers, favoris) arrivaient APRÈS
// le reset et remettaient en mémoire les données du compte A, les écrivaient
// sur disque, puis la synchro suivante les fusionnait dans le compte B
// (téléphone partagé). Même chose pour la création distante d'un dossier.
//
// Le faux backend ci-dessous retient chaque réponse jusqu'à ce que le test la
// libère, APRÈS la déconnexion.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';
import 'package:karatou/app/core/utils/country_utils.dart';

import '../../widget_test_helpers.dart';

/// Compte A connecté, réseau lent : chaque réponse attend son `Completer`.
class _SlowAccountApi extends MockApiClient {
  final profile = Completer<Map<String, dynamic>>();
  final cases = Completer<List<dynamic>>();
  final savedItems = Completer<List<dynamic>>();
  final createdCase = Completer<Map<String, dynamic>>();

  int profileReads = 0;
  int caseCreates = 0;
  int savedItemCreates = 0;

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> getProfile() {
    profileReads++;
    return profile.future;
  }

  @override
  Future<List<dynamic>> listCases() => cases.future;

  @override
  Future<List<dynamic>> listSavedItems() => savedItems.future;

  @override
  Future<Map<String, dynamic>> createSavedItem(
      Map<String, dynamic> payload) async {
    savedItemCreates++;
    return <String, dynamic>{'id': 'saved-srv-1'};
  }

  @override
  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) {
    caseCreates++;
    return createdCase.future;
  }

  /// Le catalogue ne répond jamais : seule la partie « compte » compte ici.
  @override
  Future<CatalogListPayload> listCatalogEnvelope(String resource) =>
      Completer<CatalogListPayload>().future;
}

/// Session Supabase du compte A : `hasAuthSession` reste vrai jusqu'à
/// `clearSession`, comme pendant le retrait du jeton push (jusqu'à 3 s) qui
/// la précède dans `logout`. La première vérification de session (celle de la
/// synchro de démarrage, partie avant la connexion) attend [bootAuthCheck].
class _WindowAccountApi extends _SlowAccountApi {
  bool authed = true;
  Completer<bool>? bootAuthCheck;

  @override
  Future<bool> hasAuthSession() {
    final boot = bootAuthCheck;
    if (boot != null) {
      bootAuthCheck = null;
      return boot.future;
    }
    return Future<bool>.value(authed);
  }
}

/// `clearSession` n'aboutit que quand le test ouvre [gate] : la fenêtre entre
/// la remise à zéro et l'effacement de la session reste ouverte jusque-là.
class _GatedAuth extends Mock implements AuthService {
  _GatedAuth(this.api);

  final _WindowAccountApi api;
  final gate = Completer<void>();

  @override
  Future<void> clearSession() async {
    await gate.future;
    api.authed = false;
  }
}

/// L'API d'orientation répond 401 : comme le client réel, elle déclare la
/// session perdue (`handleSessionLost`, donc remise à zéro) AVANT que
/// l'erreur ne remonte au contrôleur.
class _OrientationApi extends MockApiClient {
  _OrientationApi(this.onUnauthorized);

  final Future<void> Function() onUnauthorized;
  int submits = 0;

  @override
  Future<Map<String, dynamic>> submitOrientation(
      Map<String, dynamic> payload) async {
    submits++;
    await onUnauthorized();
    final options = RequestOptions(path: '/orientation/submit');
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<void>(requestOptions: options, statusCode: 401),
    );
  }
}

/// Solde de parrainage du compte A, retenu jusqu'à ce que le test le libère.
class _CreditsApi extends MockApiClient {
  final credits = Completer<Map<String, dynamic>>();
  final voucher = Completer<Map<String, dynamic>>();

  @override
  Future<bool> hasAuthSession() async => true;

  @override
  Future<Map<String, dynamic>> getMyReferralCredits() => credits.future;

  @override
  Future<Map<String, dynamic>> redeemReviewVoucher(String clientRef) =>
      voucher.future;
}

/// Compte A connecté, compte servi tout de suite ; la dernière ressource du
/// catalogue (« scholarships ») attend le test. Les pays contiennent un pays
/// hors MVP, que le verrou doit retirer.
class _SlowCatalogApi extends MockApiClient {
  final scholarships = Completer<CatalogListPayload>();

  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<Map<String, dynamic>> getProfile() async => _accountAProfile;
  @override
  Future<List<dynamic>> listCases() async => <dynamic>[];
  @override
  Future<List<dynamic>> listSavedItems() async => <dynamic>[];
  @override
  Future<List<dynamic>> listContent(String resource) async => <dynamic>[];

  @override
  Future<CatalogListPayload> listCatalogEnvelope(String resource) async {
    switch (resource) {
      case 'countries':
        return const CatalogListPayload(items: [
          {'id': 'fra', 'name': 'France'},
          {'id': 'jpn', 'name': 'Japon'}, // hors MVP
        ], source: CatalogDataSource.database);
      case 'scholarships':
        return scholarships.future;
      default:
        return const CatalogListPayload(
            items: [], source: CatalogDataSource.database);
    }
  }
}

/// Surface conseiller : chaque lecture (leads, statistiques) attend son
/// `Completer`, dans l'ordre des appels.
class _CommercialApi extends MockApiClient {
  final leads = <Completer<List<CommercialLead>>>[];
  final stats = <Completer<Map<String, dynamic>>>[];
  final leadEmails = <String>[];

  @override
  Future<List<CommercialLead>> listCommercialLeads({
    required String email,
    String filter = 'all',
  }) {
    leadEmails.add(email);
    final c = Completer<List<CommercialLead>>();
    leads.add(c);
    return c.future;
  }

  @override
  Future<Map<String, dynamic>> getCommercialStats({required String email}) {
    final c = Completer<Map<String, dynamic>>();
    stats.add(c);
    return c.future;
  }
}

const _accountAProfile = <String, dynamic>{
  'id': 'user-A',
  'fullName': 'Élève A',
  'email': 'a@example.com',
  'currentLevel': 'terminale',
  'fieldIds': ['d01'],
  'preferredLanguage': 'fr',
};

Map<String, dynamic> _accountACase(String id) => <String, dynamic>{
      'id': id,
      'type': 'scholarship_support',
      'status': 'submitted',
      'title': 'Dossier de A',
      'description': 'Données privées du compte A',
      'contextLabel': 'Bourse',
      'updatedAt': DateTime(2026, 11, 20).toUtc().toIso8601String(),
      'createdAt': DateTime(2026, 11, 20).toUtc().toIso8601String(),
      'messages': const <Map<String, dynamic>>[],
    };

Future<void> _settle() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    setupPlatformChannelMocks();
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  Future<(AppController, T, FakeRepository)>
      signedInWith<T extends MockApiClient>(T api) async {
    AppConfig.enableRemoteSyncOverride = false;
    final repository = FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    );
    final controller = AppController(repository: repository, apiClient: api);
    await controller.hydrate();
    Get.put<AppController>(controller, permanent: true);
    AppConfig.enableRemoteSyncOverride = true;
    return (controller, api, repository);
  }

  Future<(AppController, _SlowAccountApi, FakeRepository)> signedInA() =>
      signedInWith(_SlowAccountApi());

  test(
      'les réponses d\'une synchro arrivées après la déconnexion ne '
      'réécrivent ni l\'état ni le snapshot', () async {
    final (controller, api, repository) = await signedInA();

    unawaited(controller.syncRemoteData(silent: true, force: true));
    await _settle();
    expect(api.profileReads, 1, reason: 'la synchro attend le profil');
    expect(controller.isSyncing, isTrue);

    await controller.logout();
    expect(controller.isSyncing, isFalse,
        reason: 'la synchro du compte parti ne bloque pas le suivant');

    // Le réseau répond enfin, avec les données du compte A.
    api.profile.complete(_accountAProfile);
    api.cases.complete(<dynamic>[_accountACase('srv-case-A')]);
    api.savedItems.complete(<dynamic>[
      <String, dynamic>{'type': 'scholarship', 'itemId': 'sch-A'},
    ]);
    await _settle();

    expect(controller.profile, isNull);
    expect(controller.cases, isEmpty);
    expect(controller.savedItems, isEmpty);
    expect(controller.isSyncing, isFalse);
    expect(api.savedItemCreates, 0,
        reason: 'les favoris de A ne sont pas recréés côté serveur');

    final saved = await repository.loadSnapshot();
    expect(saved.profile, isNull);
    expect(saved.cases, isEmpty);
    expect(saved.savedItems, isEmpty);
  });

  test(
      'un dossier créé côté serveur après la déconnexion ne revient pas '
      'dans l\'état', () async {
    final (controller, api, repository) = await signedInA();

    controller.submitCase(
      type: CaseType.scholarshipSupport,
      title: 'Dossier de A',
      description: 'Données privées du compte A',
      contextLabel: 'Bourse',
      contactMethod: ContactMethod.whatsapp,
    );
    await _settle();
    expect(api.caseCreates, 1);

    await controller.logout();
    expect(controller.cases, isEmpty);

    api.createdCase.complete(_accountACase('srv-case-A'));
    await _settle();

    expect(controller.cases, isEmpty);
    final saved = await repository.loadSnapshot();
    expect(saved.cases, isEmpty);
  });

  test(
      'déconnexion pendant la synchro lancée par finishAuthSession : la '
      'relance ne relit pas le compte parti dans la fenêtre du jeton push',
      () async {
    final bootAuthCheck = Completer<bool>();
    final api = _WindowAccountApi()..bootAuthCheck = bootAuthCheck;
    final (controller, _, repository) = await signedInWith(api);
    // Le réseau a déjà les réponses du compte A : seule la relance peut
    // encore les lire.
    api.profile.complete(_accountAProfile);
    api.cases.complete(<dynamic>[_accountACase('srv-case-A')]);
    api.savedItems.complete(<dynamic>[
      <String, dynamic>{'type': 'scholarship', 'itemId': 'sch-A'},
    ]);

    // Synchro de démarrage, partie avant la connexion : finishAuthSession
    // attend sa fin pour relancer celle du compte.
    unawaited(controller.syncRemoteData(silent: true));
    await _settle();
    expect(controller.isSyncing, isTrue);
    await controller.finishAuthSession();
    await _settle();
    expect(api.profileReads, 0, reason: 'la relance attend la synchro');

    // Déconnexion : la session de A reste valide jusqu'à `clearSession`.
    final auth = _GatedAuth(api);
    Get.put<AuthService>(auth, permanent: true);
    final loggedOut = controller.logout();
    await _settle();
    expect(controller.profile, isNull);
    expect(api.authed, isTrue, reason: 'fenêtre du retrait du jeton push');

    // La synchro de démarrage se termine DANS la fenêtre : la relance de
    // finishAuthSession ne part pas.
    bootAuthCheck.complete(false);
    await _settle();
    // Un « tirer pour rafraîchir » dans la même fenêtre non plus.
    unawaited(controller.pullToRefresh());
    await _settle();

    expect(api.profileReads, 0,
        reason: 'aucune lecture du compte parti après la remise à zéro');
    expect(controller.profile, isNull);
    expect(controller.cases, isEmpty);
    expect(controller.savedItems, isEmpty);
    expect(controller.isSyncing, isFalse,
        reason: 'aucune synchro ne prend le verrou dans la fenêtre');

    auth.gate.complete();
    await loggedOut;
    await _settle();

    expect(api.profileReads, 0);
    expect(controller.profile, isNull);
    expect(controller.cases, isEmpty);
    expect(controller.savedItems, isEmpty);
    expect(api.savedItemCreates, 0);
    final saved = await repository.loadSnapshot();
    expect(saved.profile, isNull);
    expect(saved.cases, isEmpty);
    expect(saved.savedItems, isEmpty);
  });

  test(
      'déconnexion terminée avant la fin de la synchro de démarrage : '
      'finishAuthSession ne relance aucune synchro', () async {
    final bootAuthCheck = Completer<bool>();
    final api = _WindowAccountApi()..bootAuthCheck = bootAuthCheck;
    final (controller, _, _) = await signedInWith(api);

    unawaited(controller.syncRemoteData(silent: true));
    await _settle();
    await controller.finishAuthSession();
    await _settle();

    final auth = _GatedAuth(api)..gate.complete();
    Get.put<AuthService>(auth, permanent: true);
    await controller.logout();
    expect(api.authed, isFalse);

    // La synchro de démarrage finit APRÈS la déconnexion complète : la
    // relance prévue pour le compte parti n'a plus lieu d'être.
    bootAuthCheck.complete(false);
    await _settle();

    expect(controller.isSyncing, isFalse,
        reason: 'aucune synchro relancée pour le compte parti');
    expect(api.profileReads, 0);
  });

  test(
      'orientation en 401 avec session perdue : le repli local ne '
      'réinjecte ni le profil ni le résultat du compte parti', () async {
    // `handleSessionLost` renvoie vers l'écran de démarrage sans contexte.
    Get.testMode = true;
    addTearDown(() => Get.testMode = false);
    late AppController controller;
    final api = _OrientationApi(() => controller.handleSessionLost());
    final (c, _, repository) = await signedInWith(api);
    controller = c;

    await expectLater(
      controller.submitOrientation(<String, List<String>>{
        'q1': ['a'],
      }),
      throwsA(isA<DioException>()),
    );
    await _settle();

    expect(api.submits, 1);
    expect(controller.profile, isNull);
    expect(controller.latestOrientationSession, isNull);
    expect(controller.orientationHistory, isEmpty);
    final saved = await repository.loadSnapshot();
    expect(saved.profile, isNull);
    expect(saved.orientationHistory, isEmpty);
  });

  test(
      'solde de parrainage arrivé après la déconnexion : ni affiché ni '
      'écrit pour le compte suivant', () async {
    final (controller, api, repository) = await signedInWith(_CreditsApi());

    unawaited(controller.refreshReviewCredits());
    final redeem = controller.redeemReviewVoucher('ref-1');
    await _settle();

    await controller.logout();
    expect(controller.reviewCredits, 0);

    api.credits.complete(<String, dynamic>{'balance': 7});
    api.voucher.complete(<String, dynamic>{
      'ok': true,
      'balance': 6,
      'voucherCode': 'V-A',
    });
    final res = await redeem;
    await _settle();

    expect(res['ok'], isTrue, reason: 'la réponse est rendue telle quelle');
    expect(controller.reviewCredits, 0);
    final saved = await repository.loadSnapshot();
    expect(saved.reviewCredits, 0);
  });
  test(
      'déconnexion pendant la synchro du catalogue : le catalogue va '
      'jusqu\'au bout (verrou MVP, état des données)', () async {
    final dir = await Directory.systemTemp.createTemp('hive_logout_catalog');
    Hive.init(dir.path);
    CatalogCacheService.resetForTests();
    await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
    await CatalogCacheService.init();
    addTearDown(CatalogCacheService.resetForTests);
    expect(AppConfig.mvpOnly, isTrue);

    final (controller, api, repository) = await signedInWith(_SlowCatalogApi());

    unawaited(controller.syncRemoteData(silent: true, force: true));
    await _settle();
    expect(controller.isSyncing, isTrue);
    expect(controller.countries.map((c) => c.id), contains('jpn'),
        reason: 'pays déjà remplacés, verrou pas encore appliqué');

    await controller.logout();
    api.scholarships.complete(const CatalogListPayload(
        items: [], source: CatalogDataSource.database));
    await _settle();

    // Le catalogue n'appartient à aucun compte : il est terminé normalement.
    expect(controller.countries.where((c) => !isMvpCountryId(c.id)), isEmpty,
        reason: 'le verrou MVP s\'applique toujours au catalogue');
    expect(controller.catalogDataState, CatalogDataState.live);
    expect(controller.catalogFirstSyncSettled, isTrue);
    // Les données du compte parti, elles, ne reviennent pas.
    expect(controller.profile, isNull);
    final saved = await repository.loadSnapshot();
    expect(saved.profile, isNull);
    expect(saved.cases, isEmpty);
    expect(saved.savedItems, isEmpty);
  });

  test(
      'conseiller B connecté pendant un chargement de A : ses leads et ses '
      'statistiques sont bien demandés', () async {
    final (controller, api, _) = await signedInWith(_CommercialApi());
    controller.profile = createTestProfile(
      id: 'commercial-A',
      email: 'a@kpb.test',
      accountType: AccountType.commercial,
    );

    unawaited(controller.fetchCommercialLeads());
    unawaited(controller.fetchCommercialStats());
    await _settle();
    expect(controller.isLoadingCommercialLeads, isTrue);
    expect(controller.isLoadingCommercialStats, isTrue);

    await controller.logout();
    expect(controller.isLoadingCommercialLeads, isFalse);
    expect(controller.isLoadingCommercialStats, isFalse);

    controller.profile = createTestProfile(
      id: 'commercial-B',
      email: 'b@kpb.test',
      accountType: AccountType.commercial,
    );
    unawaited(controller.fetchCommercialLeads());
    unawaited(controller.fetchCommercialStats());
    await _settle();
    expect(api.leadEmails, ['a@kpb.test', 'b@kpb.test'],
        reason: 'le chargement de B n\'est pas pris pour un doublon de A');

    // La réponse tardive de A ne termine pas le chargement de B.
    api.leads.first.complete(const <CommercialLead>[]);
    api.stats.first.complete(<String, dynamic>{});
    await _settle();
    expect(controller.isLoadingCommercialLeads, isTrue);
    expect(controller.isLoadingCommercialStats, isTrue);

    api.leads.last.complete(<CommercialLead>[
      CommercialLead.fromApi(<String, dynamic>{'id': 'lead-B'}),
    ]);
    api.stats.last.complete(<String, dynamic>{});
    await _settle();
    expect(controller.isLoadingCommercialLeads, isFalse);
    expect(controller.isLoadingCommercialStats, isFalse);
    expect(controller.commercialLeads.map((l) => l.id), ['lead-B']);
  });
}
