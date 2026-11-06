// Dossiers : un filtre sans résultat n'est pas un compte neuf (audit build 57,
// T4-18). Avant : « Aucun dossier pour le moment / Crée ton premier dossier »
// et « 0 dossier » alors que l'élève en avait un.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/cases/cases_screen.dart';

import '../widget_test_helpers.dart';

StudentCase _case(String id, CaseType type) {
  final now = DateTime(2026, 10, 20);
  return StudentCase(
    id: id,
    referenceCode: 'KPB-$id',
    type: type,
    title: LocalizedText(fr: 'Dossier $id', en: 'Case $id'),
    description: const LocalizedText(fr: 'Desc', en: 'Desc'),
    contextLabel: const LocalizedText(fr: 'France', en: 'France'),
    status: CaseStatus.submitted,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: now,
    updatedAt: now,
    nextStepTitle: const LocalizedText(fr: 'Suite', en: 'Next'),
    nextStepDescription: const LocalizedText(fr: '', en: ''),
    timeline: const <CaseTimelineEvent>[],
    messages: const <CaseMessage>[],
    documentRequests: const <DocumentRequest>[],
  );
}

Future<AppController> _pump(
    WidgetTester tester, List<StudentCase> cases) async {
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        cases: cases,
      ),
    ),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  await tester.pumpWidget(GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr'),
    fallbackLocale: const Locale('fr'),
    home: const Scaffold(body: CasesScreen()),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  // Les cartes formatent leurs dates avec `DateFormat(..., 'fr')`.
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  testWidgets('filtre sans résultat : message propre au filtre, total juste',
      (tester) async {
    await _pump(tester, [
      _case('1', CaseType.consultation),
      _case('2', CaseType.scholarshipSupport),
    ]);
    final fr = AppTranslations().keys['fr']!;
    // Tiroir : deux types, donc les puces sont là, et le total est celui du
    // compte.
    expect(find.text(fr['cases_filter_all']!), findsOneWidget);
    expect(find.text('2 dossier(s)'), findsOneWidget);

    // Un type dont l'élève n'a aucun dossier.
    final mentorship = find.text(fr['case_type_filter_mentorship']!);
    // La rangée de puces défile à l'horizontale.
    await tester.drag(
        find.text(fr['cases_filter_all']!), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(mentorship);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('cases-filter-empty')),
        findsOneWidget);
    expect(find.text(fr['cases_filter_empty_title']!), findsOneWidget);
    // Ni « Crée ton premier dossier », ni « Aucun dossier pour le moment ».
    expect(find.text(fr['no_cases']!), findsNothing);
    expect(find.text(fr['create_case']!), findsNothing);
    expect(find.text('2 dossier(s)'), findsOneWidget);

    await tester.tap(find.text(fr['cases_filter_show_all']!));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey<String>('cases-filter-empty')), findsNothing);
    expect(find.textContaining('KPB-1'), findsOneWidget);
    expect(find.textContaining('KPB-2'), findsOneWidget);
  });

  testWidgets('un seul type de dossier : pas de puces de filtre',
      (tester) async {
    await _pump(tester, [_case('1', CaseType.consultation)]);
    expect(find.text('Tous'), findsNothing);
    expect(find.text('1 dossier(s)'), findsOneWidget);
  });
}
