// La sonde « hors ligne » (audit avant la 59).
//
// Elle résolvait `dns.google`, une fois : un échec, et l'app affichait « Mode
// hors-ligne » alors que l'API de KPB répondait. Elle sonde maintenant l'hôte
// de l'API d'abord, accepte un second avis, et attend deux échecs de suite.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/services/connectivity_service.dart';

void main() {
  final service = ConnectivityService.instance;

  setUp(service.debugReset);
  tearDown(service.debugReset);

  test('l\'hôte de l\'API de KPB est sondé en premier', () {
    final hosts = ConnectivityService.probeHosts();
    expect(hosts.first, Uri.parse(AppConfig.apiBaseUrl).host);
    expect(hosts, contains('dns.google'));
  });

  test('un seul échec ne suffit pas à passer hors ligne', () async {
    service.resolver = (_) async => false;

    await service.debugCheckNow();

    expect(service.isOnline, isTrue);
  });

  test('deux échecs de suite passent hors ligne', () async {
    service.resolver = (_) async => false;

    await service.debugCheckNow();
    await service.debugCheckNow();

    expect(service.isOnline, isFalse);
  });

  test('un réseau qui filtre Google mais joint KPB reste en ligne', () async {
    final asked = <String>[];
    service.resolver = (host) async {
      asked.add(host);
      return host != 'dns.google';
    };

    await service.debugCheckNow();
    await service.debugCheckNow();

    expect(service.isOnline, isTrue);
    // L'API a répondu : inutile de demander un second avis.
    expect(asked, isNot(contains('dns.google')));
  });

  test('si seul le second avis répond, l\'app reste en ligne', () async {
    service.resolver = (host) async => host == 'dns.google';

    await service.debugCheckNow();
    await service.debugCheckNow();

    expect(service.isOnline, isTrue);
  });

  test('un succès entre deux échecs remet le compteur à zéro', () async {
    var reachable = false;
    service.resolver = (_) async => reachable;

    await service.debugCheckNow();
    reachable = true;
    await service.debugCheckNow();
    reachable = false;
    await service.debugCheckNow();

    expect(service.isOnline, isTrue);
  });

  test('le retour en ligne est immédiat et annoncé', () async {
    final changes = <bool>[];
    final sub = service.onConnectivityChanged.listen(changes.add);
    service.resolver = (_) async => false;
    await service.debugCheckNow();
    await service.debugCheckNow();
    expect(service.isOnline, isFalse);

    service.resolver = (_) async => true;
    await service.debugCheckNow();
    await Future<void>.delayed(Duration.zero);

    expect(service.isOnline, isTrue);
    expect(changes, [false, true]);
    await sub.cancel();
  });
}
