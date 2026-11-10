// La création d'un dossier ne doit plus pouvoir être refusée pour sa longueur.
//
// ## Le défaut (audit avant la 59)
//
// `POST /cases` refusait en 400 une description de plus de 2 000 caractères,
// un intitulé de plus de 120 et un contexte de plus de 160. L'app n'avait
// aucune limite de saisie, et la dictée vocale produit vite un long récit.
// L'app avait déjà affiché « transmise à l'équipe » ; elle réessayait à chaque
// synchronisation et échouait à chaque fois. Aucun conseiller ne recevait la
// demande, sur le parcours qui convertit.
//
// ## Ce que ce fichier verrouille
//
// Le corps envoyé au serveur, pas seulement la fonction de coupe : c'est le
// corps qui était refusé.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/case_api_codec.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';
import 'package:karatou/app/core/services/connectivity_service.dart';

import '../../widget_test_helpers.dart';

class _Api extends MockApiClient {
  final List<Map<String, dynamic>> created = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> createCase(Map<String, dynamic> payload) async {
    created.add(Map<String, dynamic>.from(payload));
    return <String, dynamic>{
      'id': 'srv-1',
      'type': payload['type'],
      'status': 'submitted',
      'title': payload['title'],
      'description': payload['description'],
      'contextLabel': payload['contextLabel'],
      'updatedAt': DateTime(2026, 11, 10).toUtc().toIso8601String(),
      'createdAt': DateTime(2026, 11, 10).toUtc().toIso8601String(),
      'messages': const <Map<String, dynamic>>[],
    };
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    final dir = await Directory.systemTemp.createTemp('hive_case_limits');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  setUp(() async {
    resetGetxSingleton();
    setupPlatformChannelMocks();
    ConnectivityService.instance.debugSetOnline(true);
    CatalogCacheService.resetForTests();
    await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
    await CatalogCacheService.init();
  });

  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  Future<(AppController, _Api)> device() async {
    AppConfig.enableRemoteSyncOverride = false;
    final api = _Api();
    final controller = AppController(
      repository: FakeRepository(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      ),
      apiClient: api,
    );
    await controller.hydrate();
    AppConfig.enableRemoteSyncOverride = true;
    return (controller, api);
  }

  group('CaseApiCodec.clampText', () {
    test('laisse un texte sous la limite intact', () {
      expect(CaseApiCodec.clampText('Bonjour', 120), 'Bonjour');
    });

    test('coupe à la limite', () {
      expect(CaseApiCodec.clampText('a' * 130, 120), hasLength(120));
    });

    test('ne laisse pas un émoji coupé en deux', () {
      // « 😀 » occupe deux unités UTF-16 : la coupe tombe au milieu.
      expect(CaseApiCodec.clampText('ab😀', 3), 'ab');
    });

    test('compte comme le serveur, en unités UTF-16', () {
      // 2 000 émojis : 2 000 caractères visibles pour le champ de saisie,
      // mais 4 000 unités pour le serveur, qui en accepte 3 000.
      final message = CaseApiCodec.clampText(
        '😀' * 2000,
        CaseApiCodec.messageMaxLength,
      );
      expect(message.length, CaseApiCodec.messageMaxLength);
      expect(message.runes.length, 1500);
    });
  });

  test(
      'un récit dicté de 9 000 caractères, un intitulé de 300 et un contexte '
      'de 400 partent coupés aux limites du serveur', () async {
    final (controller, api) = await device();

    controller.submitCase(
      type: CaseType.scholarshipSupport,
      title: 't' * 300,
      description: 'd' * 9000,
      contextLabel: 'c' * 400,
      contactMethod: ContactMethod.whatsapp,
    );
    await _settle();

    expect(api.created, hasLength(1));
    final body = api.created.single;
    expect(body['title'], hasLength(CaseApiCodec.titleMaxLength));
    expect(body['description'], hasLength(CaseApiCodec.descriptionMaxLength));
    expect(
      body['contextLabel'],
      hasLength(CaseApiCodec.contextLabelMaxLength),
    );
  });

  test('une demande ordinaire part sans être modifiée', () async {
    final (controller, api) = await device();

    controller.submitCase(
      type: CaseType.scholarshipSupport,
      title: 'Bourse Eiffel',
      description: 'Bonjour, je voudrais être accompagné.',
      contextLabel: 'Bourse',
      contactMethod: ContactMethod.whatsapp,
    );
    await _settle();

    final body = api.created.single;
    expect(body['title'], 'Bourse Eiffel');
    expect(body['description'], 'Bonjour, je voudrais être accompagné.');
    expect(body['contextLabel'], 'Bourse');
  });

  test(
      'la saisie du tunnel reste sous les 2 000 caractères de l\'ancien '
      'serveur', () {
    expect(CaseApiCodec.messageInputMaxLength, lessThan(2000));
  });
}
