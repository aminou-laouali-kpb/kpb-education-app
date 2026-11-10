// Les leviers des deux mois sans nouvelle build (audit avant la 59).
//
// ## Ce qui n'allait pas
//
// 1. `/config/app` n'était lue qu'au lancement et jamais gardée. Sur un réseau
//    lent, l'app retombait sur ses replis de compilation (tout fermé) :
//    l'espace Études en France disparaissait, parfois pour toute la session.
// 2. Ouvrir ou couper une fonction n'atteignait une app restée ouverte qu'après
//    que l'élève l'avait tuée.
// 3. Le numéro WhatsApp n'existait que dans le binaire.
//
// ## Ce que ce fichier verrouille
//
// La dernière réponse est gardée et relue au démarrage ; une relecture a lieu
// au retour au premier plan, pas plus souvent que toutes les cinq minutes ; le
// numéro servi l'emporte sur le numéro compilé, et un échec ne referme rien.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/config/support_contact.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/remote_config_cache.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/utils/whatsapp_utils.dart';

class _MockApiClient extends Mock implements AppApiClient {}

class _MemoryCache implements RemoteConfigCache {
  RemoteConfigSnapshot? stored;
  int writes = 0;
  bool failReads = false;

  @override
  Future<RemoteConfigSnapshot?> read() async {
    if (failReads) throw StateError('stockage illisible');
    return stored;
  }

  @override
  Future<void> write(RemoteConfigSnapshot snapshot) async {
    writes++;
    stored = snapshot;
  }
}

Map<String, dynamic> _config({
  bool eefSpace = true,
  bool caseMessaging = false,
  Object? whatsapp,
  Map<String, dynamic>? notice,
}) =>
    <String, dynamic>{
      'minVersion': '0.0.0',
      'features': <String, dynamic>{
        'eefSpace': eefSpace,
        'caseMessaging': caseMessaging,
      },
      if (whatsapp != null)
        'support': <String, dynamic>{'whatsappNumber': whatsapp},
      'notice': notice,
    };

void main() {
  late _MockApiClient api;
  late _MemoryCache cache;
  late DateTime now;

  setUp(() {
    RemoteFeatureFlags.resetForTest();
    api = _MockApiClient();
    cache = _MemoryCache();
    now = DateTime(2026, 11, 10, 12);
    RemoteFeatureFlags.cache = cache;
    RemoteFeatureFlags.clock = () => now;
  });

  tearDown(RemoteFeatureFlags.resetForTest);

  final flags = RemoteFeatureFlags.instance;

  group('la dernière réponse du serveur est gardée', () {
    test('une réponse réussie est écrite sur le téléphone', () async {
      when(api.getAppConfig).thenAnswer((_) async => _config());

      await flags.refresh(api);
      await Future<void>.delayed(Duration.zero);

      expect(cache.writes, 1);
      expect(cache.stored!.savedAt, now);
      expect(cache.stored!.config['features'], containsPair('eefSpace', true));
    });

    test(
        'au lancement suivant, hors réseau, l\'app repart de cette réponse '
        'au lieu de tout refermer', () async {
      cache.stored = RemoteConfigSnapshot(
        savedAt: now.subtract(const Duration(hours: 20)),
        config: _config(eefSpace: true, caseMessaging: true),
      );
      when(api.getAppConfig).thenThrow(StateError('hors réseau'));

      // Avant : le repli de compilation, donc fermé.
      expect(flags.eefSpaceEnabled, AppConfig.eefSpaceEnabled);

      await flags.restoreFromCache();
      await flags.refresh(api);

      expect(flags.eefSpaceEnabled, isTrue);
      expect(flags.caseMessagingEnabled, isTrue);
      expect(flags.featuresServed, isTrue);
      // Le réseau n'a toujours pas répondu : un nouvel essai reste dû.
      expect(flags.loaded, isFalse);
    });

    test('une réponse de plus de sept jours est ignorée', () async {
      cache.stored = RemoteConfigSnapshot(
        savedAt: now.subtract(const Duration(days: 8)),
        config: _config(eefSpace: true),
      );

      await flags.restoreFromCache();

      expect(flags.featuresServed, isFalse);
      expect(flags.eefSpaceEnabled, AppConfig.eefSpaceEnabled);
    });

    test('un stockage illisible ne lève pas et ne change rien', () async {
      cache.failReads = true;

      await flags.restoreFromCache();

      expect(flags.featuresServed, isFalse);
    });

    test('la réponse gardée ne remplace pas une réponse déjà fraîche',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => _config(eefSpace: false));
      await flags.refresh(api);
      cache.stored = RemoteConfigSnapshot(
        savedAt: now,
        config: _config(eefSpace: true),
      );

      await flags.restoreFromCache();

      expect(flags.eefSpaceEnabled, isFalse);
    });

    test('la réponse fraîche l\'emporte sur la réponse gardée', () async {
      cache.stored = RemoteConfigSnapshot(
        savedAt: now.subtract(const Duration(hours: 1)),
        config: _config(caseMessaging: true),
      );
      when(api.getAppConfig)
          .thenAnswer((_) async => _config(caseMessaging: false));

      await flags.restoreFromCache();
      expect(flags.caseMessagingEnabled, isTrue);

      await flags.refresh(api);
      expect(flags.caseMessagingEnabled, isFalse);
      expect(flags.loaded, isTrue);
    });
  });

  group('relecture au retour au premier plan', () {
    test('rien dans les cinq minutes qui suivent la dernière tentative',
        () async {
      when(api.getAppConfig).thenAnswer((_) async => _config());
      await flags.refresh(api);

      now = now.add(const Duration(minutes: 4));
      await flags.refreshIfStale(api);

      verify(api.getAppConfig).called(1);
    });

    test(
        'après cinq minutes, l\'interrupteur ouvert entre-temps atteint '
        'l\'app restée ouverte', () async {
      var messaging = false;
      when(api.getAppConfig)
          .thenAnswer((_) async => _config(caseMessaging: messaging));
      await flags.refresh(api);
      expect(flags.caseMessagingEnabled, isFalse);
      final versionBefore = flags.flagsVersion.value;

      messaging = true;
      now = now.add(const Duration(minutes: 6));
      await flags.refreshIfStale(api);

      expect(flags.caseMessagingEnabled, isTrue);
      expect(flags.flagsVersion.value, greaterThan(versionBefore));
    });

    test('une relecture qui échoue ne referme rien', () async {
      when(api.getAppConfig).thenAnswer((_) async => _config(eefSpace: true));
      await flags.refresh(api);

      when(api.getAppConfig).thenThrow(StateError('hors réseau'));
      now = now.add(const Duration(minutes: 6));
      await flags.refreshIfStale(api);

      expect(flags.eefSpaceEnabled, isTrue);
    });

    test('un échec compte comme une tentative : pas de rafale d\'appels',
        () async {
      when(api.getAppConfig).thenThrow(StateError('hors réseau'));
      await flags.refreshIfStale(api);
      await flags.refreshIfStale(api);
      await flags.refreshIfStale(api);

      verify(api.getAppConfig).called(1);
    });
  });

  group('garde de version : seulement sur une réponse fraîche', () {
    test('une réponse du réseau est passée à l\'écouteur', () async {
      final seen = <Map<String, dynamic>>[];
      flags.onFreshConfig = seen.add;
      when(api.getAppConfig).thenAnswer((_) async => _config());

      await flags.refresh(api);

      expect(seen, hasLength(1));
    });

    test('la réponse gardée ne lui est jamais passée', () async {
      final seen = <Map<String, dynamic>>[];
      flags.onFreshConfig = seen.add;
      cache.stored = RemoteConfigSnapshot(
        savedAt: now,
        config: <String, dynamic>{..._config(), 'minVersion': '99.0.0'},
      );

      await flags.restoreFromCache();

      expect(seen, isEmpty);
    });

    test('un écouteur qui lève ne casse pas la lecture des interrupteurs',
        () async {
      flags.onFreshConfig = (_) => throw StateError('boom');
      when(api.getAppConfig).thenAnswer((_) async => _config(eefSpace: true));

      await flags.refresh(api);

      expect(flags.eefSpaceEnabled, isTrue);
      expect(flags.loaded, isTrue);
    });
  });

  group('numéro WhatsApp servi', () {
    test('sans numéro servi, l\'app garde celui de la build', () async {
      when(api.getAppConfig).thenAnswer((_) async => _config());

      await flags.refresh(api);

      expect(SupportContact.isServed, isFalse);
      expect(SupportContact.whatsappNumber, AppConfig.whatsappNumber);
    });

    test('le numéro servi remplace celui de la build dans les liens', () async {
      when(api.getAppConfig)
          .thenAnswer((_) async => _config(whatsapp: '+227 90 00 00 00'));

      await flags.refresh(api);

      expect(SupportContact.whatsappNumber, '+22790000000');
      expect(
        buildWhatsAppUri(prefill: 'Bonjour').toString(),
        startsWith('https://wa.me/22790000000?text='),
      );
    });

    test('le numéro servi est retrouvé au lancement suivant, hors réseau',
        () async {
      cache.stored = RemoteConfigSnapshot(
        savedAt: now,
        config: _config(whatsapp: '+22790000000'),
      );

      await flags.restoreFromCache();

      expect(SupportContact.whatsappNumber, '+22790000000');
    });

    for (final unreadable in <Object>[
      '0768674292',
      '22790000000',
      'whatsapp',
      '+12',
      42,
    ]) {
      test('« $unreadable » est ignoré : pas de ligne morte', () async {
        when(api.getAppConfig)
            .thenAnswer((_) async => _config(whatsapp: unreadable));

        await flags.refresh(api);

        expect(SupportContact.whatsappNumber, AppConfig.whatsappNumber);
      });
    }

    test('un serveur qui cesse de servir le numéro rend la main à la build',
        () async {
      when(api.getAppConfig)
          .thenAnswer((_) async => _config(whatsapp: '+22790000000'));
      await flags.refresh(api);

      when(api.getAppConfig).thenAnswer((_) async => _config());
      now = now.add(const Duration(minutes: 6));
      await flags.refreshIfStale(api);

      expect(SupportContact.whatsappNumber, AppConfig.whatsappNumber);
    });
  });

  group('avis servi', () {
    test('aucun avis par défaut', () async {
      when(api.getAppConfig).thenAnswer((_) async => _config());
      await flags.refresh(api);
      expect(flags.notice, isNull);
    });

    test('l\'avis est lu, avec sa traduction et son lien', () async {
      when(api.getAppConfig).thenAnswer((_) async => _config(notice: {
            'fr': 'Maroc : la campagne ferme le 15 novembre.',
            'en': 'Morocco: the campaign closes on 15 November.',
            'url': 'https://www.campusfrance.org/fr',
          }));

      await flags.refresh(api);

      final notice = flags.notice!;
      expect(notice.textFor('fr'), 'Maroc : la campagne ferme le 15 novembre.');
      expect(
        notice.textFor('en'),
        'Morocco: the campaign closes on 15 November.',
      );
      expect(notice.url, 'https://www.campusfrance.org/fr');
    });

    test('sans traduction, l\'anglais lit le français', () async {
      when(api.getAppConfig).thenAnswer(
        (_) async => _config(notice: {'fr': 'Maintenance ce soir.'}),
      );

      await flags.refresh(api);

      expect(flags.notice!.textFor('en'), 'Maintenance ce soir.');
    });

    test('un lien qui n\'est pas une adresse web sûre est écarté', () async {
      when(api.getAppConfig).thenAnswer((_) async => _config(notice: {
            'fr': 'Avis',
            'url': 'javascript:alert(1)',
          }));

      await flags.refresh(api);

      expect(flags.notice!.url, isNull);
    });

    test('un avis sans texte français n\'est pas affiché', () async {
      when(api.getAppConfig)
          .thenAnswer((_) async => _config(notice: {'en': 'English only'}));

      await flags.refresh(api);

      expect(flags.notice, isNull);
    });
  });
}
