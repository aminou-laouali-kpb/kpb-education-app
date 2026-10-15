// Fiche d'une bourse (chantier I2) :
//   · l'en-tête de statut dans toutes ses variantes (Ouverte, Clôture proche,
//     Ouverture estimée, Date à confirmer, Clôturée), avec le calcul d'urgence
//     partagé, et un contraste AA effectivement PEINT ;
//   · « Vérifiée le … · Source officielle » (lastVerifiedAt servi par l'API,
//     lien sortant) ;
//   · la barre fixe : « Postuler » (cycle ouvert + lien) ou « Suivre », et
//     « Être accompagné » — sans `scholarshipId` quand le drapeau
//     `scholarshipMatch` est fermé ;
//   · des puces neutres, aucune icône de validation ;
//   · l'arrivée depuis un push, app tuée : le tap attend la première image,
//     ouvre la vraie route, montre un squelette puis l'en-tête.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/notification_router.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/cases/case_composer_sheet.dart';
import 'package:karatou/app/features/scholarships/scholarship_detail_screen.dart';
import 'package:karatou/app/features/scholarships/widgets/scholarship_status_line.dart';

import '../../support/chip_paint.dart';
import '../../widget_test_helpers.dart';

class _RecordingLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

DateTime _inDays(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, 23, 59);
}

Map<String, dynamic> _cycle({
  String status = 'open',
  String confidence = 'confirmed',
  DateTime? closesAt,
  DateTime? estimatedOpenAt,
  DateTime? estimatedCloseAt,
  String? sourceUrl,
  DateTime? verifiedAt,
}) =>
    <String, dynamic>{
      'id': 'c1',
      'academicYear': '2027-2028',
      'status': status,
      'dateConfidence': confidence,
      if (closesAt != null) 'closesAt': closesAt.toIso8601String(),
      if (estimatedOpenAt != null)
        'estimatedOpenAt': estimatedOpenAt.toIso8601String(),
      if (estimatedCloseAt != null)
        'estimatedCloseAt': estimatedCloseAt.toIso8601String(),
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      if (verifiedAt != null) 'verifiedAt': verifiedAt.toIso8601String(),
    };

LiveScholarshipModel _scholarship({
  Map<String, dynamic>? cycle,
  String applicationUrl = 'https://apply.example.org/chevening',
  String? sourceUrl,
  String? lastVerifiedAt,
  List<String> advantages = const <String>[],
  List<String> eligibility = const <String>[],
  List<String> keyRequirements = const <String>[],
  String deadlineLabel = '',
  String title = 'Chevening',
}) =>
    LiveScholarshipModel.fromJson(<String, dynamic>{
      'id': 'chevening',
      'title': title,
      'countryName': 'Royaume-Uni',
      'fundingType': 'fully_funded',
      'description': '',
      'advantages': advantages,
      'eligibility': eligibility,
      'keyRequirements': keyRequirements,
      'level': 'Master',
      'deadlineLabel': deadlineLabel,
      'applicationUrl': applicationUrl,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      if (lastVerifiedAt != null) 'lastVerifiedAt': lastVerifiedAt,
      'tags': <String>[],
      'matchScore': 0,
      if (cycle != null) 'currentCycle': cycle,
    });

void _stub(MockApiClient mock, Future<LiveScholarshipModel?> Function() load) {
  when(() => mock.fetchLiveScholarshipDetailWithFallback(
        scholarshipId: any(named: 'scholarshipId'),
        lang: any(named: 'lang'),
        initial: any(named: 'initial'),
      )).thenAnswer((_) => load());
  when(() => mock.fetchScholarshipAlerts()).thenAnswer((_) async => <String>{});
  when(() => mock.getSuccessLabAccess()).thenAnswer(
    (_) async => <String, dynamic>{'enabled': false, 'reasons': <String>[]},
  );
  when(() => mock.listCasesForScholarship(any()))
      .thenAnswer((_) async => <dynamic>[]);
}

Future<void> _seed(MockApiClient mock) async {
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    ),
    apiClient: mock,
  );
  await controller.hydrate();
  AppConfig.enableRemoteSyncOverride = false;
  Get.put<AppController>(controller, permanent: true);
}

void _phone(WidgetTester tester, {Size size = const Size(1080, 2400)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<MockApiClient> _pump(
  WidgetTester tester,
  LiveScholarshipModel scholarship, {
  Size size = const Size(1080, 2400),
}) async {
  _phone(tester, size: size);
  final mock = MockApiClient();
  _stub(mock, () async => scholarship);
  await _seed(mock);
  await tester.pumpWidget(GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr'),
    fallbackLocale: const Locale('fr'),
    home: ScholarshipDetailScreen(
      scholarshipId: scholarship.id,
      initialScholarship: scholarship,
      apiClient: mock,
    ),
  ));
  await tester.pumpAndSettle();
  return mock;
}

final _header = find.byKey(const ValueKey<String>('scholarship-status-header'));
final _bar = find.byKey(const ValueKey<String>('scholarship-action-bar'));
final _apply = find.byKey(const ValueKey<String>('scholarship-action-apply'));
final _support =
    find.byKey(const ValueKey<String>('scholarship-action-support'));
final _follow = find.byKey(const ValueKey<String>('follow-chevening'));

String _headerText(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: _header, matching: find.byType(Text)))
    .map((text) => text.data ?? '')
    .join(' | ');

void main() {
  late UrlLauncherPlatform previousLauncher;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    RemoteFeatureFlags.resetForTest();
    previousLauncher = UrlLauncherPlatform.instance;
  });
  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    AppConfig.enableRemoteSyncOverride = null;
    RemoteFeatureFlags.resetForTest();
    resetGetxSingleton();
  });

  group('en-tête de statut', () {
    testWidgets('ouverte : « Ouverte · clôture … », en haut de la fiche',
        (tester) async {
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(60))));
      expect(_header, findsOneWidget);
      expect(_headerText(tester), startsWith('Ouverte · clôture '));
      // Avant le titre : c'est la première chose lue.
      expect(
        tester.getTopLeft(_header).dy,
        lessThan(tester.getTopLeft(find.text('Chevening')).dy),
      );
    });

    testWidgets(
        'clôture proche : libellé, jours restants, texte foncé sur '
        'ambre (contraste peint AA)', (tester) async {
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(5))));
      expect(_headerText(tester), contains('Clôture proche · '));
      expect(_headerText(tester), contains('Il te reste 5 jours'));

      final box = tester.widget<Container>(_header);
      final fill = (box.decoration! as BoxDecoration).color!;
      final label = tester.widget<Text>(find.descendant(
        of: _header,
        matching: find.textContaining('Clôture proche'),
      ));
      final ink = label.style!.color!;
      expect(contrastRatio(ink, fill), greaterThanOrEqualTo(kChipMinContrast));
      expect(ink.computeLuminance(), lessThan(fill.computeLuminance()));
    });

    testWidgets('dernier jour', (tester) async {
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(0))));
      expect(_headerText(tester), contains('Dernier jour pour candidater'));
    });

    testWidgets('ouverture estimée', (tester) async {
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(
            status: 'forecast',
            confidence: 'estimated',
            estimatedOpenAt: DateTime.utc(DateTime.now().year + 1, 2, 1),
          ),
        ),
      );
      expect(_headerText(tester), startsWith('Ouverture estimée'));
    });

    testWidgets('date à confirmer (aucune date), avec le libellé servi',
        (tester) async {
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(status: 'forecast', confidence: 'estimated'),
          deadlineLabel: 'Généralement en mars',
        ),
      );
      expect(_headerText(tester), startsWith('Date à confirmer'));
      expect(_headerText(tester), contains('Généralement en mars'));
    });

    testWidgets(
        'clôture ESTIMÉE dépassée : « Date à confirmer », jamais '
        '« Clôturée »', (tester) async {
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(
            status: 'closed',
            confidence: 'estimated',
            estimatedCloseAt: _inDays(-10),
          ),
        ),
      );
      expect(_headerText(tester), startsWith('Date à confirmer'));
      expect(find.textContaining('Clôturée'), findsNothing);
    });

    testWidgets('clôture confirmée passée : « Clôturée »', (tester) async {
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(-2))));
      expect(_headerText(tester), startsWith('Clôturée'));
    });
  });

  group('Vérifiée le … · Source officielle', () {
    testWidgets('date servie et lien sortant vers la source', (tester) async {
      final launcher = _RecordingLauncher();
      UrlLauncherPlatform.instance = launcher;
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(closesAt: _inDays(60)),
          lastVerifiedAt: '2026-10-03T10:00:00.000Z',
          sourceUrl: 'https://www.chevening.org/scholarships',
        ),
      );
      final verified = tester.widget<Text>(
        find.byKey(const ValueKey<String>('scholarship-verified-on')),
      );
      expect(
        verified.data,
        'Vérifiée le ${formatScholarshipDay(DateTime.parse('2026-10-03T10:00:00.000Z'))}',
      );
      final source =
          find.byKey(const ValueKey<String>('scholarship-official-source'));
      expect(find.text('Source officielle'), findsOneWidget);
      expect(tester.getSize(source).height, greaterThanOrEqualTo(48));

      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(launcher.launched, ['https://www.chevening.org/scholarships']);
    });

    testWidgets(
        'la vérification la plus récente gagne, la source du cycle '
        'aussi', (tester) async {
      final launcher = _RecordingLauncher();
      UrlLauncherPlatform.instance = launcher;
      final cycleVerified = DateTime.utc(2026, 10, 12, 9);
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(
            closesAt: _inDays(60),
            sourceUrl: 'https://www.chevening.org/apply-2027',
            verifiedAt: cycleVerified,
          ),
          lastVerifiedAt: '2026-01-03T10:00:00.000Z',
          sourceUrl: 'https://www.chevening.org',
        ),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('scholarship-verified-on')),
            )
            .data,
        'Vérifiée le ${formatScholarshipDay(cycleVerified)}',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('scholarship-official-source')),
      );
      await tester.pumpAndSettle();
      expect(launcher.launched, ['https://www.chevening.org/apply-2027']);
    });

    testWidgets('rien de servi (backend plus ancien) : rien d\'affiché',
        (tester) async {
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(60))));
      expect(
        find.byKey(const ValueKey<String>('scholarship-verified-on')),
        findsNothing,
      );
      expect(find.text('Source officielle'), findsNothing);
    });

    test('lastVerifiedAt est lu depuis l\'API', () {
      final s = _scholarship(lastVerifiedAt: '2026-10-03T10:00:00.000Z');
      expect(s.lastVerifiedAt, DateTime.utc(2026, 10, 3, 10));
      expect(s.verifiedAt, DateTime.utc(2026, 10, 3, 10));
      expect(_scholarship().lastVerifiedAt, isNull);
    });
  });

  group('barre d\'actions', () {
    testWidgets(
        'cycle ouvert + lien : « Postuler » + « Être accompagné » ; '
        '« Suivre » remonte près du titre', (tester) async {
      final launcher = _RecordingLauncher();
      UrlLauncherPlatform.instance = launcher;
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(30))));

      expect(find.descendant(of: _bar, matching: _apply), findsOneWidget);
      expect(find.descendant(of: _bar, matching: _support), findsOneWidget);
      expect(find.text('Postuler'), findsOneWidget);
      expect(find.text('Être accompagné'), findsOneWidget);
      expect(find.descendant(of: _bar, matching: _follow), findsNothing);
      expect(_follow, findsOneWidget);
      expect(tester.getSize(_apply).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(_support).height, greaterThanOrEqualTo(48));

      await tester.tap(_apply);
      await tester.pumpAndSettle();
      expect(launcher.launched, ['https://apply.example.org/chevening']);
    });

    testWidgets('cycle pas encore ouvert : « Suivre » dans la barre',
        (tester) async {
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(
            status: 'forecast',
            confidence: 'estimated',
            estimatedOpenAt: DateTime.utc(DateTime.now().year + 1, 2, 1),
          ),
        ),
      );
      expect(_apply, findsNothing);
      expect(find.descendant(of: _bar, matching: _follow), findsOneWidget);
      expect(find.descendant(of: _bar, matching: _support), findsOneWidget);
      expect(_follow, findsOneWidget);
    });

    testWidgets(
        'date estimée ou inconnue : pas de « Postuler » principal, mais le '
        'formulaire officiel reste joignable (« Comment candidater »)',
        (tester) async {
      final launcher = _RecordingLauncher();
      UrlLauncherPlatform.instance = launcher;
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(status: 'forecast', confidence: 'estimated'),
        ),
      );
      expect(_apply, findsNothing);

      final howTo = find.text('live_scholarships_section_application_steps'.tr);
      await tester.ensureVisible(howTo);
      await tester.pumpAndSettle();
      await tester.tap(howTo);
      await tester.pumpAndSettle();
      final official = find.text('live_scholarships_official_form'.tr);
      expect(official, findsOneWidget);
      await tester.tap(official);
      await tester.pumpAndSettle();
      expect(launcher.launched, ['https://apply.example.org/chevening']);
    });

    testWidgets('clôturée : « Suivre », jamais « Postuler »', (tester) async {
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(-2))));
      expect(_apply, findsNothing);
      expect(find.descendant(of: _bar, matching: _follow), findsOneWidget);
    });

    testWidgets('ouverte sans lien ouvrable : « Suivre »', (tester) async {
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(closesAt: _inDays(30)),
          applicationUrl: 'exemple.org/apply',
        ),
      );
      expect(_apply, findsNothing);
      expect(find.descendant(of: _bar, matching: _follow), findsOneWidget);
    });

    testWidgets(
        '« Être accompagné », drapeau scholarshipMatch FERMÉ : pas de '
        'scholarshipId, pas de recherche de dossier lié', (tester) async {
      final mock = await _pump(
        tester,
        _scholarship(cycle: _cycle(closesAt: _inDays(30))),
      );
      expect(RemoteFeatureFlags.instance.scholarshipMatchEnabled, isFalse);
      await tester.tap(_support);
      await tester.pumpAndSettle();

      final sheet = tester.widget<CaseComposerSheet>(
        find.byType(CaseComposerSheet),
      );
      expect(sheet.caseType, CaseType.scholarshipSupport);
      expect(sheet.scholarshipId, isNull);
      expect(sheet.title, 'Chevening');
      verifyNever(() => mock.listCasesForScholarship(any()));
    });

    testWidgets(
        '« Être accompagné », drapeau OUVERT : le dossier porte la '
        'bourse', (tester) async {
      RemoteFeatureFlags.instance.debugSetFeaturesForTest(
        const <String, bool>{'scholarshipMatch': true},
      );
      await _pump(tester, _scholarship(cycle: _cycle(closesAt: _inDays(30))));
      await tester.tap(_support);
      await tester.pumpAndSettle();

      final sheet = tester.widget<CaseComposerSheet>(
        find.byType(CaseComposerSheet),
      );
      expect(sheet.scholarshipId, 'chevening');
    });

    testWidgets('360×640, titre long : aucun débordement', (tester) async {
      await _pump(
        tester,
        _scholarship(
          cycle: _cycle(closesAt: _inDays(5)),
          title: 'Bourse d\'excellence du gouvernement pour les études de '
              'master en ingénierie et sciences appliquées',
          lastVerifiedAt: '2026-10-03T10:00:00.000Z',
          sourceUrl: 'https://www.chevening.org',
        ),
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      expect(_apply, findsOneWidget);
      expect(_support, findsOneWidget);
    });
  });

  testWidgets('puces neutres : aucune icône de validation', (tester) async {
    await _pump(
      tester,
      _scholarship(
        cycle: _cycle(closesAt: _inDays(30)),
        advantages: const ['Frais de scolarité', 'Allocation mensuelle'],
        eligibility: const ['Licence obtenue', 'Deux ans d\'expérience'],
        keyRequirements: const ['Lettre de motivation'],
      ),
    );
    for (final icon in <IconData>[
      Icons.check,
      Icons.check_rounded,
      Icons.check_circle,
      Icons.check_circle_rounded,
      Icons.check_circle_outline,
      Icons.check_circle_outline_rounded,
      Icons.task_alt_rounded,
    ]) {
      expect(find.byIcon(icon), findsNothing, reason: '$icon');
    }
    await tester.scrollUntilVisible(
      find.text('Lettre de motivation'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('scholarship-bullet')),
      findsWidgets,
    );
  });

  group('arrivée depuis un push', () {
    final router = NotificationRouter.instance;

    setUp(() {
      router.debugReset();
      AnalyticsService.instance.logEventSink = (_, __) async {};
    });
    tearDown(() {
      router.debugReset();
      AnalyticsService.instance.logEventSink = null;
    });

    testWidgets(
        'app tuée : le tap attend la première image, ouvre la fiche, '
        'squelette puis en-tête', (tester) async {
      _phone(tester);
      final mock = MockApiClient();
      final detail = Completer<LiveScholarshipModel?>();
      _stub(mock, () => detail.future);
      await _seed(mock);

      // Le tap arrive AVANT que l'app ne soit montée (démarrage à froid).
      await router.open(<String, dynamic>{
        'kind': 'scholarship_deadline',
        'route': '/scholarships',
        'scholarshipId': 'chevening',
      });
      expect(router.pendingCount, 1);

      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        getPages: AppRoutes.pages,
        home: const Scaffold(body: Text('accueil')),
      ));
      router.markReady();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // La vraie route `/scholarships/:id`, sans données de liste : squelette.
      expect(find.byType(ScholarshipDetailScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('scholarship-detail-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_bar, findsNothing);

      detail.complete(_scholarship(cycle: _cycle(closesAt: _inDays(5))));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('scholarship-detail-skeleton')),
        findsNothing,
      );
      expect(_headerText(tester), contains('Clôture proche'));
      expect(_bar, findsOneWidget);
      verify(() => mock.fetchLiveScholarshipDetailWithFallback(
            scholarshipId: 'chevening',
            lang: any(named: 'lang'),
            initial: null,
          )).called(1);

      // Retour : l'accueil, sous la fiche.
      Get.back<void>();
      await tester.pumpAndSettle();
      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets(
        'fiche introuvable depuis un push : état vide honnête, '
        '« Réessayer »', (tester) async {
      _phone(tester);
      final mock = MockApiClient();
      _stub(mock, () async => null);
      await _seed(mock);

      await tester.pumpWidget(GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        getPages: AppRoutes.pages,
        home: const Scaffold(body: Text('accueil')),
      ));
      router.markReady();
      await router.open(<String, dynamic>{
        'route': AppRoutes.scholarshipDetailPath('chevening'),
      });
      await tester.pumpAndSettle();

      expect(find.text('Bourse introuvable'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(_bar, findsNothing);
    });
  });
}
