// Le catalogue en cache est décodé dans un isolate au démarrage. Ce test
// prouve que le décodage passe réellement par `Isolate.run` (les modèles
// doivent être transférables) et qu'une ressource corrompue retombe sur vide.
//
// Le démarrage passe par `decodeCachedCatalogInBackground` : un isolate
// (`compute`) sur mobile, un décodage SYNCHRONE sur le web, où `Isolate.run`
// lève `UnsupportedError` — le web perdait alors tout son catalogue en cache.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';

Map<String, String?> _mockRaws() => <String, String?>{
      'fields': jsonEncode(MockCatalog.fields.map((f) => f.toJson()).toList()),
      'countries':
          jsonEncode(MockCatalog.countries.map((c) => c.toJson()).toList()),
      'institutions':
          jsonEncode(MockCatalog.institutions.map((i) => i.toJson()).toList()),
      'programs':
          jsonEncode(MockCatalog.programs.map((p) => p.toJson()).toList()),
      'scholarships':
          jsonEncode(MockCatalog.scholarships.map((s) => s.toJson()).toList()),
    };

void main() {
  test('decodes every resource in a background isolate', () async {
    final raws = _mockRaws();
    final decoded = await Isolate.run(() => decodeCachedCatalog(raws));
    expect(decoded.fields.length, MockCatalog.fields.length);
    expect(decoded.institutions.length, MockCatalog.institutions.length);
    expect(decoded.programs.length, MockCatalog.programs.length);
    expect(decoded.scholarships.length, MockCatalog.scholarships.length);
    expect(decoded.countries.first.id, MockCatalog.countries.first.id);
  });

  test('a corrupt or missing resource decodes to an empty list', () {
    final decoded = decodeCachedCatalog(<String, String?>{
      'fields': '{not json',
      'countries': null,
    });
    expect(decoded.fields, isEmpty);
    expect(decoded.countries, isEmpty);
    expect(decoded.programs, isEmpty);
  });

  group('decodeCachedCatalogInBackground', () {
    test('chemin web simulé : décodage synchrone, sans isolate', () async {
      final decoded =
          await decodeCachedCatalogInBackground(_mockRaws(), isWeb: true);
      expect(decoded.fields.length, MockCatalog.fields.length);
      expect(decoded.programs.length, MockCatalog.programs.length);
      expect(decoded.scholarships.length, MockCatalog.scholarships.length);
    });

    test('chemin mobile : décodage via compute (isolate)', () async {
      final decoded =
          await decodeCachedCatalogInBackground(_mockRaws(), isWeb: false);
      expect(decoded.institutions.length, MockCatalog.institutions.length);
      expect(decoded.countries.first.id, MockCatalog.countries.first.id);
    });

    test('une ressource corrompue retombe sur vide, sur les deux chemins',
        () async {
      for (final isWeb in const [true, false]) {
        final decoded = await decodeCachedCatalogInBackground(
          <String, String?>{'fields': '{not json', 'countries': null},
          isWeb: isWeb,
        );
        expect(decoded.fields, isEmpty);
        expect(decoded.countries, isEmpty);
      }
    });
  });

  test('session.dart ne lance plus Isolate.run directement', () {
    final code = File('lib/app/core/controllers/app_controller/session.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(code, isNot(contains('Isolate.run')));
    expect(code, contains('decodeCachedCatalogInBackground('));
  });
}
