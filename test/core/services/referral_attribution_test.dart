// Parrainage côté app (build 57) : extraction stricte du code depuis le Play
// Install Referrer, lecture UNE fois par installation, identifiant
// d'installation, et issues fermées de `POST /referrals/redeem`.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/referral_attribution.dart';

class _MockApi extends Mock implements AppApiClient {}

/// Stockage en mémoire, qu'on peut faire tomber en panne.
class _MemoryStore implements ReferralLocalStore {
  bool checked = false;
  PendingReferralCode? pending;
  String? installIdValue;
  bool broken = false;
  int markCalls = 0;

  void _guard() {
    if (broken) throw StateError('stockage en panne');
  }

  @override
  Future<bool> installReferrerChecked() async {
    _guard();
    return checked;
  }

  @override
  Future<void> markInstallReferrerChecked() async {
    _guard();
    markCalls++;
    checked = true;
  }

  @override
  Future<PendingReferralCode?> readPendingCode() async {
    _guard();
    return pending;
  }

  @override
  Future<void> writePendingCode(PendingReferralCode code) async {
    _guard();
    pending = code;
  }

  @override
  Future<void> clearPendingCode() async {
    _guard();
    pending = null;
  }

  @override
  Future<String?> readInstallId() async {
    _guard();
    return installIdValue;
  }

  @override
  Future<void> writeInstallId(String id) async {
    _guard();
    installIdValue = id;
  }
}

DioException _status(int code, {Object? data}) => DioException(
      requestOptions: RequestOptions(path: '/referrals/redeem'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/referrals/redeem'),
        statusCode: code,
        data: data,
      ),
    );

void main() {
  group('ReferralCodeFormat.fromInstallReferrer — formats réels seulement', () {
    String? read(String? raw) => ReferralCodeFormat.fromInstallReferrer(raw);

    test('le lien d\'invite.html, décodé par Google Play', () {
      expect(read('utm_source=invite&utm_medium=referral&ref=K7PQ2MZA'),
          'K7PQ2MZA');
      expect(read('utm_source=invite&utm_medium=referral&ref=KTOU-AB-1a2b3c'),
          'KTOU-AB-1A2B3C');
    });

    test('un code ambassadeur d\'avant l\'unification (une seule initiale)',
        () {
      expect(read('ref=KTOU-A-00z9xy'), 'KTOU-A-00Z9XY');
    });

    test('une valeur restée encodée est décodée UNE fois de plus', () {
      expect(
        read(
            'utm_source%3Dinvite%26utm_medium%3Dreferral%26ref%3DKTOU-AB-1a2b3c'),
        'KTOU-AB-1A2B3C',
      );
      expect(read('ref%3Dk7pq2mza'), 'K7PQ2MZA');
      // Composant encodé dans une valeur déjà décodée : splitQueryString le lit.
      expect(
          read('utm_source=invite&ref=KTOU%2DAB%2D1a2b3c'), 'KTOU-AB-1A2B3C');
      expect(read('?ref=K7PQ2MZA'), 'K7PQ2MZA');
    });

    test('absence, valeur vide ou installation organique : rien', () {
      for (final raw in <String?>[
        null,
        '',
        '   ',
        'utm_source=google-play&utm_medium=organic',
        'utm_source=invite&utm_medium=referral&ref=',
        'utm_source=invite&utm_medium=referral',
        'reference=K7PQ2MZA',
      ]) {
        expect(read(raw), isNull, reason: '$raw');
      }
    });

    test('un format inconnu ou abîmé n\'est jamais prérempli', () {
      for (final raw in [
        // Alphabet du serveur : ni I, ni O, ni 0, ni 1.
        'ref=K7PQ2MZO',
        'ref=K7PQ2M01',
        // Longueur.
        'ref=K7PQ2MZ',
        'ref=K7PQ2MZAB',
        'ref=KTOU-AB-1a2b3',
        'ref=KTOU-ABC-1a2b3c',
        'ref=KTOX-AB-1a2b3c',
        // Espaces, signes, injection.
        'ref=K7PQ+2MZA',
        'ref=K7PQ 2MZA',
        'ref=<script>',
        'ref=K7PQ2MZA%00',
        // Encodage cassé.
        'ref=%ZZ',
        'utm_source%3Dinvite%26ref%3D%ZZ',
        // Le DERNIER `ref` gagne : vide ici.
        'ref=K7PQ2MZA&ref=',
      ]) {
        expect(read(raw), isNull, reason: raw);
      }
      expect(read('ref=${'A' * 2000}'), isNull);
    });
  });

  group('captureInstallReferrerOnce — une seule lecture par installation', () {
    late _MemoryStore store;
    late int reads;
    late String? served;

    ReferralAttribution make({bool android = true, Object? throwing}) =>
        ReferralAttribution(
          store: store,
          isAndroid: () => android,
          readInstallReferrer: () async {
            reads++;
            if (throwing != null) throw throwing;
            return served;
          },
        );

    setUp(() {
      store = _MemoryStore();
      reads = 0;
      served = 'utm_source=invite&utm_medium=referral&ref=KTOU-AB-1a2b3c';
    });

    test('lit, garde le code en local, et ne relit jamais', () async {
      final attribution = make();
      await attribution.captureInstallReferrerOnce(enabled: true);
      await attribution.captureInstallReferrerOnce(enabled: true);
      // Un nouveau démarrage (nouvelle instance, même stockage) non plus.
      await make().captureInstallReferrerOnce(enabled: true);

      expect(reads, 1);
      expect(store.checked, isTrue);
      expect(store.pending?.code, 'KTOU-AB-1A2B3C');
      expect(store.pending?.origin, PendingReferralOrigin.installReferrer);
    });

    test('drapeau fermé : aucune lecture, et rien de marqué', () async {
      await make().captureInstallReferrerOnce(enabled: false);
      expect(reads, 0);
      expect(store.checked, isFalse,
          reason: 'la lecture doit rester possible le jour où le drapeau '
              's\'ouvre');
      expect(store.pending, isNull);
    });

    test('iOS (ou hôte de test, ou web) : aucune lecture', () async {
      await make(android: false).captureInstallReferrerOnce(enabled: true);
      expect(reads, 0);
      expect(store.checked, isFalse);
    });

    test('le défaut lit la plateforme HÔTE : jamais Android sous flutter test',
        () async {
      final attribution = ReferralAttribution(
        store: store,
        readInstallReferrer: () async {
          reads++;
          return served;
        },
      );
      await attribution.captureInstallReferrerOnce(enabled: true);
      expect(reads, 0);
    });

    test('échec de Google Play : marqué, rien gardé, aucune relecture',
        () async {
      await make(throwing: Exception('SERVICE_UNAVAILABLE'))
          .captureInstallReferrerOnce(enabled: true);
      await make().captureInstallReferrerOnce(enabled: true);
      expect(reads, 1);
      expect(store.pending, isNull);
    });

    test('aucun ref exploitable : marqué, rien gardé', () async {
      served = 'utm_source=google-play&utm_medium=organic';
      await make().captureInstallReferrerOnce(enabled: true);
      expect(store.checked, isTrue);
      expect(store.pending, isNull);
    });

    test('un code déjà saisi par l\'élève n\'est pas écrasé par le lien',
        () async {
      store.pending = const PendingReferralCode(
        code: 'K7PQ2MZA',
        origin: PendingReferralOrigin.typed,
      );
      await make().captureInstallReferrerOnce(enabled: true);
      expect(store.pending?.code, 'K7PQ2MZA');
    });

    test('stockage en panne : on ne lit pas (on ne saurait pas le marquer)',
        () async {
      store.broken = true;
      await make().captureInstallReferrerOnce(enabled: true);
      expect(reads, 0);
    });
  });

  group('installId — UUID v4 aléatoire, stocké en local', () {
    test('créé au premier besoin, puis toujours le même', () async {
      final store = _MemoryStore();
      final attribution = ReferralAttribution(store: store);
      final first = await attribution.installId();
      final second = await ReferralAttribution(store: store).installId();
      expect(first, isNotNull);
      expect(second, first);
      expect(
        first,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
    });

    test('une réinstallation (stockage vide) en crée un autre', () async {
      final a = await ReferralAttribution(store: _MemoryStore()).installId();
      final b = await ReferralAttribution(store: _MemoryStore()).installId();
      expect(a, isNot(b));
    });

    test('stockage en panne : null (en-tête omis), jamais éphémère', () async {
      final store = _MemoryStore()..broken = true;
      expect(await ReferralAttribution(store: store).installId(), isNull);
    });
  });

  group('redeem — issues fermées et sort du code en attente', () {
    late _MemoryStore store;
    late _MockApi api;
    late ReferralAttribution attribution;

    setUp(() {
      store = _MemoryStore()..installIdValue = 'install-uuid-0001';
      api = _MockApi();
      attribution = ReferralAttribution(store: store);
    });

    void answer(Future<Map<String, dynamic>> Function() reply) {
      when(() => api.redeemReferral(any(), deviceId: any(named: 'deviceId')))
          .thenAnswer((_) => reply());
    }

    test('le code part en majuscules, avec l\'identifiant d\'installation',
        () async {
      answer(() async => {'attributed': true, 'alreadyReferred': false});
      final outcome = await attribution.redeem(api, ' ktou-ab-1a2b3c ');
      expect(outcome, ReferralRedeemOutcome.attributed);
      verify(() => api.redeemReferral('KTOU-AB-1A2B3C',
          deviceId: 'install-uuid-0001')).called(1);
    });

    test('succès : le code en attente est oublié', () async {
      store.pending = const PendingReferralCode(
          code: 'K7PQ2MZA', origin: PendingReferralOrigin.installReferrer);
      answer(() async => {'attributed': true, 'alreadyReferred': false});
      await attribution.redeem(api, 'K7PQ2MZA');
      expect(store.pending, isNull);
    });

    test('déjà parrainé : succès silencieux, code oublié', () async {
      store.pending = const PendingReferralCode(
          code: 'K7PQ2MZA', origin: PendingReferralOrigin.installReferrer);
      answer(() async => {'attributed': false, 'alreadyReferred': true});
      final outcome = await attribution.redeem(api, 'K7PQ2MZA');
      expect(outcome, ReferralRedeemOutcome.alreadyReferred);
      expect(outcome.isSuccess, isTrue);
      expect(store.pending, isNull);
    });

    final cases = <String, (DioException, ReferralRedeemOutcome)>{
      '404 code inconnu': (_status(404), ReferralRedeemOutcome.unknownCode),
      '400 forme refusée': (_status(400), ReferralRedeemOutcome.unknownCode),
      '403 auto-parrainage': (
        _status(403, data: {
          'statusCode': 403,
          'message': 'You cannot use your own referral code.',
        }),
        ReferralRedeemOutcome.selfReferral,
      ),
      '403 parrainage croisé': (
        _status(403, data: {'message': 'Mutual referrals are not allowed.'}),
        ReferralRedeemOutcome.notAllowed,
      ),
      '403 dossier déjà déposé': (
        _status(403, data: {
          'message': 'A referral code must be used before your first request.',
        }),
        ReferralRedeemOutcome.notAllowed,
      ),
      '429 limite horaire': (
        _status(429, data: {'code': 'referral_code_rate_limited'}),
        ReferralRedeemOutcome.rateLimited,
      ),
      'hors ligne': (
        DioException(
          requestOptions: RequestOptions(path: '/referrals/redeem'),
          type: DioExceptionType.connectionError,
        ),
        ReferralRedeemOutcome.offline,
      ),
      'délai dépassé': (
        DioException(
          requestOptions: RequestOptions(path: '/referrals/redeem'),
          type: DioExceptionType.receiveTimeout,
        ),
        ReferralRedeemOutcome.offline,
      ),
      '500': (_status(500), ReferralRedeemOutcome.error),
    };

    cases.forEach((name, value) {
      final (error, expected) = value;
      test('$name → ${expected.wireName}', () async {
        answer(() async => throw error);
        expect(await attribution.redeem(api, 'K7PQ2MZA'), expected);
      });
    });

    test('panne passagère : le code saisi est GARDÉ pour plus tard', () async {
      answer(() async => throw _status(429));
      await attribution.redeem(api, 'ktou-ab-1a2b3c');
      expect(store.pending?.code, 'KTOU-AB-1A2B3C');
      expect(store.pending?.origin, PendingReferralOrigin.typed);
    });

    test('panne passagère : le code du lien garde son origine', () async {
      store.pending = const PendingReferralCode(
          code: 'K7PQ2MZA', origin: PendingReferralOrigin.installReferrer);
      answer(() async => throw DioException(
            requestOptions: RequestOptions(path: '/referrals/redeem'),
            type: DioExceptionType.connectionError,
          ));
      await attribution.redeem(api, 'K7PQ2MZA');
      expect(store.pending?.origin, PendingReferralOrigin.installReferrer);
    });

    test('refus définitif d\'une faute de frappe : le code du lien survit',
        () async {
      store.pending = const PendingReferralCode(
          code: 'K7PQ2MZA', origin: PendingReferralOrigin.installReferrer);
      answer(() async => throw _status(404));
      await attribution.redeem(api, 'ZZZZZZZZ');
      expect(store.pending?.code, 'K7PQ2MZA');
      // …mais le code du lien lui-même refusé est oublié.
      await attribution.redeem(api, 'K7PQ2MZA');
      expect(store.pending, isNull);
    });

    test('stockage en panne : l\'en-tête est omis, le rattachement part',
        () async {
      store.broken = true;
      answer(() async => {'attributed': true, 'alreadyReferred': false});
      expect(await attribution.redeem(api, 'K7PQ2MZA'),
          ReferralRedeemOutcome.attributed);
      verify(() => api.redeemReferral('K7PQ2MZA', deviceId: null)).called(1);
    });

    test('les valeurs de mesure sont fermées et en snake_case', () {
      final snake = RegExp(r'^[a-z]+(_[a-z]+)*$');
      for (final o in ReferralRedeemOutcome.values) {
        expect(o.wireName, matches(snake));
      }
    });
  });
}
