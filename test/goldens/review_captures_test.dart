// Captures de revue visuelle (gate humaine du plan §8/§17) : rend les
// surfaces majeures avec le vrai thème, les vraies polices et les libellés FR,
// à 390×844 @2x, et écrit les PNG dans build/review_captures/.
//
// Exécution locale uniquement :
//   flutter test --tags=golden test/goldens/review_captures_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/features/auth/auth_welcome_screen.dart';
import 'package:karatou/app/features/cases/cases_screen.dart';
import 'package:karatou/app/features/home/home_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';
import 'package:karatou/app/features/universities/universities_screen.dart';

import '../features/scholarships/scholarships_test_support.dart';
import '../widget_test_helpers.dart';

const _outDir = 'build/review_captures';
final _captureKey = GlobalKey();

class _MockAuthService extends Mock implements AuthService {}

Widget _app(Widget home) {
  return RepaintBoundary(
    key: _captureKey,
    child: GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // Certains écrans portent des animations en boucle (shimmer) :
  // pumpAndSettle ne convergerait jamais — on borne alors manuellement.
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 4),
    );
  } catch (_) {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _settle(tester);
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    file.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('capture: $_outDir/$name.png');
}

Future<AppController> _seedController({
  AppSnapshot? snapshot,
  MockApiClient? apiClient,
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: snapshot ??
          AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(fullName: 'Aïcha Diallo'),
          ),
    ),
    apiClient: apiClient ?? MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

Map<String, dynamic> _scholarshipJson(
  String id,
  String name,
  int days,
  int score,
) =>
    <String, dynamic>{
      'id': id,
      'title': name,
      'organization': 'Gouvernement du Japon',
      'country': 'Japon',
      'countryFlag': '🇯🇵',
      'fundingType': 'full',
      'fundingLabel': 'Financement complet',
      'applicationRequirement': 'separate_application',
      'description': 'Bourse complète du gouvernement japonais.',
      'advantages': <String>[
        'Frais de scolarité couverts',
        'Allocation mensuelle'
      ],
      'eligibility': <String>[
        'Moins de 35 ans',
        'Excellent dossier académique'
      ],
      'level': 'Master',
      'deadlineLabel': 'Mai 2027',
      'deadlineAt': DateTime.now().add(Duration(days: days)).toIso8601String(),
      'applicationUrl': 'https://example.org/apply',
      'sourceUrl': 'https://example.org',
      'tags': <String>['scholarship'],
      'matchScore': score,
      'applicationSteps': <dynamic>[],
    };

StudentCase _buildCase(String id, String reference, CaseStatus status) {
  final now = DateTime(2026, 7, 10);
  return StudentCase(
    id: id,
    referenceCode: reference,
    type: CaseType.consultation,
    title: const LocalizedText(
        fr: 'Candidature Master Canada', en: 'Master application Canada'),
    description: const LocalizedText(
        fr: 'Dossier accompagné par un conseiller KPB.',
        en: 'Case handled by a KPB advisor.'),
    contextLabel: const LocalizedText(fr: 'KPB Education', en: 'KPB Education'),
    status: status,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: now,
    updatedAt: now,
    nextStepTitle: const LocalizedText(
        fr: 'Téléverser le relevé de notes', en: 'Upload transcript'),
    nextStepDescription: const LocalizedText(
        fr: 'Le conseiller attend ton relevé de Licence.',
        en: 'Your advisor awaits your transcript.'),
    timeline: const <CaseTimelineEvent>[],
    messages: const <CaseMessage>[],
    documentRequests: const <DocumentRequest>[],
  );
}

void main() {
  setUpAll(() async {
    registerScholarshipListFallbacks();
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  setUp(() {
    resetGetxSingleton();
  });
  tearDown(resetGetxSingleton);

  Future<void> setViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.reset);
  }

  testWidgets('capture — entrée (KPB Intelligence)', (tester) async {
    await setViewport(tester);
    final auth = _MockAuthService();
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => auth.isLoggedIn).thenReturn(false);
    Get.put<AuthService>(auth, permanent: true);

    await tester.pumpWidget(_app(const AuthWelcomeScreen()));
    final ctx = tester.element(find.byType(AuthWelcomeScreen));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/logo/kpb-education-logo-full.png'),
        ctx));
    await tester.pump();
    await _capture(tester, '01-entree');
  });

  testWidgets('capture — accueil connecté', (tester) async {
    await setViewport(tester);
    // Production geometry, not a convenient one:
    //  · a Scaffold that OWNS a drawer — AppShell's does, and that is what makes
    //    AppBar imply an extra (invisible) DrawerButton in Home's SliverAppBar.
    //    Capturing without it hid the real cause of the "Salut, …" truncation
    //    through a whole review round.
    //  · a long West-African first name, the public this app serves.
    await _seedController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(fullName: 'Mouhamadou Diallo'),
      ),
    );
    await tester.pumpWidget(_app(const Scaffold(
      drawer: Drawer(),
      body: HomeScreen(),
    )));
    await _capture(tester, '02-accueil');

    // Second frame, scrolled: the app bar is `floating`, so it comes back over
    // content. This capture is the one that shows whether it is opaque.
    final scrollable = find.byType(CustomScrollView).first;
    await tester.drag(scrollable, const Offset(0, -520));
    await tester.pump();
    await tester.drag(scrollable, const Offset(0, 90)); // snap the bar back in
    await tester.pump();
    await _capture(tester, '02b-accueil-defilement');
  });

  testWidgets('capture — bourses (liste)', (tester) async {
    await setViewport(tester);
    final mock = MockApiClient();
    whenScholarshipsPage(mock)
        .thenAnswer((_) async => scholarshipsPage(<dynamic>[
              _scholarshipJson('mext', 'Bourse MEXT 2027', 5, 86),
              _scholarshipJson('eiffel', 'Bourse Eiffel — France', 41, 72),
              _scholarshipJson('mastercard', 'Mastercard Foundation', 120, 64),
            ]));
    when(() => mock.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{'mext'});
    await _seedController(apiClient: mock);
    await tester.pumpWidget(_app(LiveScholarshipsScreen(apiClient: mock)));
    await _capture(tester, '03-bourses');
  });

  testWidgets('capture — universités', (tester) async {
    await setViewport(tester);
    await _seedController();
    await tester.pumpWidget(_app(const UniversitiesScreen()));
    await _capture(tester, '04-universites');
  });

  testWidgets('capture — dossiers', (tester) async {
    await setViewport(tester);
    await _seedController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(fullName: 'Aïcha Diallo'),
        cases: <StudentCase>[
          _buildCase('c1', 'KPB-2026-014', CaseStatus.submitted),
          _buildCase('c2', 'KPB-2026-009', CaseStatus.underReview),
        ],
      ),
    );
    final controller = Get.find<AppController>()
      ..isSyncing = false
      ..syncError = null;
    controller.update();
    await tester.pumpWidget(_app(const CasesScreen()));
    await _capture(tester, '05-dossiers');
  });

  testWidgets('capture — profil', (tester) async {
    await setViewport(tester);
    await _seedController();
    await tester.pumpWidget(_app(const ProfileScreen()));
    await _capture(tester, '06-profil');
  });
}
