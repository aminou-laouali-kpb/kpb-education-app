import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/academy/academy_course_screen.dart';
import 'package:karatou/app/features/academy/academy_list_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../../widget_test_helpers.dart';

Map<String, dynamic> _course({required bool viewerHasPass}) => {
      'id': 'course-1',
      'slug': 'hsk-1',
      'title': {'fr': 'Préparation HSK 1', 'en': 'HSK 1 preparation'},
      'description': {'fr': 'Les bases.', 'en': 'The basics.'},
      'coverImageUrl': null,
      'priceXOF': 0,
      'priceEUR': 0,
      'lessonCount': 2,
      'totalDurationSeconds': 600,
      'requiresPass': true,
      'freeLessonCount': 1,
      'viewerHasPass': viewerHasPass,
      'lessons': [
        // Servies dans le désordre : l'écran trie par `order`.
        {
          'id': 'l2',
          'title': {'fr': 'Les tons', 'en': 'Tones'},
          'videoUrl': viewerHasPass
              ? 'https://www.youtube.com/watch?v=bbbbbbbbbbb'
              : null,
          'durationSeconds': 300,
          'order': 2,
          'isFreePreview': false,
          'locked': !viewerHasPass,
        },
        {
          'id': 'l1',
          'title': {'fr': 'Introduction', 'en': 'Introduction'},
          'videoUrl': 'https://www.youtube.com/watch?v=aaaaaaaaaaa',
          'durationSeconds': 300,
          'order': 1,
          'isFreePreview': true,
          'locked': false,
        },
      ],
    };

class _AcademyApiClient extends MockApiClient {
  _AcademyApiClient({this.viewerHasPass = false, this.signedIn = true});

  final bool viewerHasPass;
  final bool signedIn;
  final requested = <String>[];

  @override
  Future<bool> hasAuthSession() async => signedIn;

  @override
  Future<List<Map<String, dynamic>>> getAcademyCourses() async =>
      [_course(viewerHasPass: false)];

  @override
  Future<Map<String, dynamic>> getAcademyCourse(String idOrSlug,
      {required bool signedIn}) async {
    requested.add('$idOrSlug|$signedIn');
    return _course(viewerHasPass: viewerHasPass);
  }
}

Future<AppController> _seed(MockApiClient apiClient) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(fullName: 'Awa Diallo'),
      ),
    ),
    apiClient: apiClient,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

/// Aucun prix ni verbe d'achat dans le parcours des cours (règles des stores).
void _expectNoPurchaseWording(WidgetTester tester) {
  for (final forbidden in ['FCFA', 'Acheter', 'Payer', 'payer', 'prix', '€']) {
    expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
  });
  tearDown(() {
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
  });

  group('modèles', () {
    test('une leçon verrouillée ne se lit pas, le programme se trie', () {
      final detail =
          AcademyCourseDetail.fromJson(_course(viewerHasPass: false));
      expect(detail.lessons.map((l) => l.id), ['l1', 'l2']);
      expect(detail.lessons[1].locked, isTrue);
      expect(detail.lessons[1].playable, isFalse);
      expect(detail.playableLessons.map((l) => l.id), ['l1']);
      expect(detail.course.requiresPass, isTrue);
      expect(detail.viewerHasPass, isFalse);
    });

    test('un backend plus ancien reste lisible', () {
      final course = AcademyCourseModel.fromJson({
        'id': 'c',
        'titleFr': 'Ancien',
        'titleEn': 'Old',
        'priceXOF': 15000,
      });
      expect(course.requiresPass, isFalse);
      expect(course.freeLessonCount, 0);
      expect(course.title.fr, 'Ancien');
    });

    test('statut du Pass', () {
      final status = PassStatusModel.fromJson(
          {'active': true, 'activeUntil': '2026-12-22T10:00:00.000Z'});
      expect(status.active, isTrue);
      expect(status.activeUntil, DateTime.utc(2026, 12, 22, 10));
    });
  });

  testWidgets(
      'sans Pass : programme visible, leçon réservée verrouillée, '
      'renvoi vers le Pass, aucun prix', (tester) async {
    final api = _AcademyApiClient();
    await _seed(api);
    await tester.pumpWidget(_wrap(const AcademyCourseScreen(idOrSlug: 'hsk-1')));
    await tester.pumpAndSettle();

    expect(api.requested, ['hsk-1|true']);
    expect(find.text('Préparation HSK 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('academy_pass_banner')), findsOneWidget);
    expect(find.text('Les tons'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.text('5 min · accès libre'), findsOneWidget);
    _expectNoPurchaseWording(tester);

    await tester.tap(find.byKey(const ValueKey('academy_lesson_l2')));
    await tester.pumpAndSettle();
    expect(find.text('Leçon incluse dans le Pass Karatou'), findsOneWidget);
    expect(find.byKey(const ValueKey('academy_locked_pass_cta')), findsOneWidget);
    _expectNoPurchaseWording(tester);
  });

  testWidgets('avec un Pass actif : tout est ouvert, sans bandeau de vente',
      (tester) async {
    await _seed(_AcademyApiClient(viewerHasPass: true));
    await tester.pumpWidget(_wrap(const AcademyCourseScreen(idOrSlug: 'hsk-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('academy_pass_active')), findsOneWidget);
    expect(find.byKey(const ValueKey('academy_pass_banner')), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
  });

  testWidgets('invité : la route publique est demandée', (tester) async {
    final api = _AcademyApiClient(signedIn: false);
    await _seed(api);
    await tester.pumpWidget(_wrap(const AcademyCourseScreen(idOrSlug: 'hsk-1')));
    await tester.pumpAndSettle();
    expect(api.requested, ['hsk-1|false']);
  });

  testWidgets('la liste montre les cours et le badge Pass', (tester) async {
    await _seed(_AcademyApiClient());
    await tester.pumpWidget(_wrap(const AcademyListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Préparation HSK 1'), findsOneWidget);
    expect(find.text('Pass Karatou'), findsOneWidget);
    expect(find.textContaining('2 leçons'), findsOneWidget);
    _expectNoPurchaseWording(tester);
  });

  testWidgets('le profil ne montre les cours que si le serveur les ouvre',
      (tester) async {
    await _seed(_AcademyApiClient());
    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cours de langue (HSK, TOEFL…)'), findsNothing);

    RemoteFeatureFlags.instance.debugSetFeaturesForTest({'academy': true});
    await tester.pumpWidget(_wrap(const ProfileScreen(key: ValueKey('again'))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Cours de langue (HSK, TOEFL…)'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Cours de langue (HSK, TOEFL…)'), findsOneWidget);
  });
}
