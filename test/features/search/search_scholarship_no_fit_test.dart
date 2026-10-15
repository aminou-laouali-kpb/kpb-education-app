// Chantier H2 — la Recherche n'affiche plus de palier de compatibilité sur une
// bourse.
//
// Le palier venait de `scholarshipFit`, lui-même tiré de `_matchScholarship` :
// un `baseMatch` éditorial (78) plus des points pour le pays visé, le domaine
// et la tranche de notes. Une bourse fermée au niveau ou à la nationalité de
// l'étudiant sortait donc « Très bon match ». Le test garde l'écart avec les
// écoles, qui gardent leur palier (calculé, lui, sur le profil).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/search/search_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  testWidgets(
      'une bourse trouvée n\'a ni palier ni pourcentage, même à baseMatch 78',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpTestApp(
      tester,
      child: const SearchScreen(),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    );

    final controller = Get.find<AppController>();
    controller.scholarships.add(const ScholarshipModel(
      id: 'sch-zeta',
      name: LocalizedText(fr: 'Bourse Zetaxyz', en: 'Zetaxyz Scholarship'),
      countryId: 'france',
      levelEligible: LocalizedText(fr: 'Licence', en: 'Bachelor'),
      typeOfFunding: LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: LocalizedText(fr: '', en: ''),
      keyRequirements: [],
      relatedFieldIds: ['d01'],
      baseMatch: 78,
    ));
    controller.update();

    await tester.enterText(find.byType(TextField), 'zetaxyz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Bourse Zetaxyz'), findsOneWidget,
        reason: 'tiroir : la bourse doit être trouvée');
    expect(find.byType(ProfileFitBadge), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    for (final fit in ProfileFit.values) {
      expect(find.text(fit.labelKey.tr), findsNothing);
    }
  });
}
