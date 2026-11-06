import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/tools/student_tools_screen.dart';
import 'package:karatou/app/features/tools/interview_simulator_screen.dart';
import 'package:karatou/app/features/tools/document_scanner_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('Student tools', () {
    setUp(resetGetxSingleton);
    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      AppConfig.aiToolsEnabledOverride = null;
      resetGetxSingleton();
    });

    // Ce test décrit le hub COMPLET, donc l'état du drapeau à vrai. Les trois
    // outils IA sont masqués par défaut depuis M1 (`AppConfig.aiToolsEnabled`) :
    // le fait qu'ils DISPARAISSENT drapeau à faux est vérifié dans
    // test/core/masquage_ai_tools_test.dart, avec sa contre-épreuve. Ici on
    // garde l'assertion d'origine — que les cinq cartes se rendent bien — sans
    // laisser croire que l'app les propose aujourd'hui.
    testWidgets('hub lists the five tools when the AI flag is on',
        (tester) async {
      AppConfig.aiToolsEnabledOverride = true;
      await pumpTestApp(
        tester,
        child: const StudentToolsScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      expect(find.text('cv_generator_title'), findsOneWidget);
      expect(find.text('letters_title'), findsOneWidget);
      expect(find.text('interview_title'), findsOneWidget);
      expect(find.text('scanner_title'), findsOneWidget);
      // Statistiques d'impact fermées côté serveur : aucune porte (audit build
      // 57, T5-15), même règle que le tiroir.
      expect(find.text('impact_title'), findsNothing);
    });

    testWidgets('statistiques d\'impact ouvertes : la carte revient',
        (tester) async {
      RemoteFeatureFlags.instance
          .debugSetFeaturesForTest(const {'publicImpactStats': true});
      addTearDown(RemoteFeatureFlags.resetForTest);
      await pumpTestApp(
        tester,
        child: const StudentToolsScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );
      expect(find.text('impact_title'), findsOneWidget);
    });

    testWidgets('interview simulator shows the three interview types',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const InterviewSimulatorScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      expect(find.text('interview_type_visa_title'), findsOneWidget);
      expect(find.text('interview_type_admission_title'), findsOneWidget);
      expect(find.text('interview_type_scholarship_title'), findsOneWidget);
    });

    testWidgets('document scanner renders the checklist with progress',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const DocumentScannerScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      expect(find.text('scanner_doc_passport'), findsOneWidget);
      expect(find.text('scanner_doc_diploma'), findsOneWidget);
      expect(find.textContaining('0 / 6 documents'), findsOneWidget);
    });
  });
}
