// Le catalogue en cache est décodé dans un isolate au démarrage. Ce test
// prouve que le décodage passe réellement par `Isolate.run` (les modèles
// doivent être transférables) et qu'une ressource corrompue retombe sur vide.

import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';

void main() {
  test('decodes every resource in a background isolate', () async {
    final raws = <String, String?>{
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
}
