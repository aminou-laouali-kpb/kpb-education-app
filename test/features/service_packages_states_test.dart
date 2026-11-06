// « Services KPB » : un catalogue vide et une erreur donnent chacun une action
// (audit build 57, T4-05). Avant : un texte nu, sans bouton — « Aucun service
// disponible » et rien à faire.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/kpb_error_state.dart';
import 'package:karatou/app/features/services/service_packages_screen.dart';

import '../widget_test_helpers.dart';

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  Future<void> pumpScreen(WidgetTester tester, MockApiClient api) async {
    setupPlatformChannelMocks();
    await tester.pumpWidget(GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: ServicePackagesScreen(apiClient: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('catalogue vide : un bouton vers le conseiller', (tester) async {
    final api = MockApiClient();
    when(() => api.listServicePackages()).thenAnswer((_) async => <dynamic>[]);
    await pumpScreen(tester, api);

    final fr = AppTranslations().keys['fr']!;
    expect(find.byKey(const ValueKey<String>('service-packages-empty')),
        findsOneWidget);
    expect(find.text(fr['service_packages_empty']!), findsOneWidget);
    expect(find.text(fr['premium_advisor_cta']!), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('erreur : « Réessayer », qui relance vraiment', (tester) async {
    final api = MockApiClient();
    var calls = 0;
    when(() => api.listServicePackages()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw StateError('hors ligne');
      return <dynamic>[];
    });
    await pumpScreen(tester, api);

    expect(find.byType(KpbErrorState), findsOneWidget);
    final fr = AppTranslations().keys['fr']!;
    await tester.tap(find.text(fr['retry']!));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(KpbErrorState), findsNothing);
    expect(find.byKey(const ValueKey<String>('service-packages-empty')),
        findsOneWidget);
  });
}
