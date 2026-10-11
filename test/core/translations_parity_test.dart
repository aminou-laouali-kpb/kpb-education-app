import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

import '../widget_test_helpers.dart';

void main() {
  group('AppTranslations parity', () {
    final keys = AppTranslations().keys;

    test('both fr and en blocks are present', () {
      expect(keys.containsKey('fr'), isTrue);
      expect(keys.containsKey('en'), isTrue);
    });

    test('fr and en expose an identical key set', () {
      final fr = keys['fr']!.keys.toSet();
      final en = keys['en']!.keys.toSet();
      expect(fr.difference(en), isEmpty,
          reason: 'Keys in FR but missing in EN: ${fr.difference(en)}');
      expect(en.difference(fr), isEmpty,
          reason: 'Keys in EN but missing in FR: ${en.difference(fr)}');
    });

    test('no translation value is blank', () {
      for (final lang in keys.entries) {
        for (final entry in lang.value.entries) {
          expect(entry.value.trim(), isNotEmpty,
              reason: 'Blank value for ${lang.key}/${entry.key}');
        }
      }
    });
  });

  group('language switching', () {
    tearDown(Get.reset);

    testWidgets('switchLanguage updates the active locale code',
        (tester) async {
      await pumpTestApp(tester, child: const SizedBox.shrink());
      final controller = Get.find<AppController>();

      expect(controller.localeCode, 'fr');

      controller.switchLanguage('en');
      await tester.pump();

      expect(controller.localeCode, 'en');
    });

    testWidgets('.tr renders FR by default and flips to EN on updateLocale',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('fr'),
          fallbackLocale: const Locale('fr'),
          home: Scaffold(
            body: Builder(builder: (_) => Text('app_language'.tr)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Langue de l'application"), findsOneWidget);

      unawaited(Get.updateLocale(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('App language'), findsOneWidget);
    });
  });
}
