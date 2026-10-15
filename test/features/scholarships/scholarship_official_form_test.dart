// « Formulaire officiel » — le bouton bleu pleine largeur qui ne faisait RIEN.
// Depuis le chantier I2, c'est « Postuler », dans la barre fixe du bas de la
// fiche (cycle ouvert + lien de candidature) ; les règles restent les mêmes.
//
// ## Deux défauts empilés
//
// Le premier est visible dans trois lignes de code :
//
// ```dart
// final uri = Uri.tryParse(value);
// if (uri != null && await canLaunchUrl(uri)) {
//   await launchUrl(uri, mode: LaunchMode.externalApplication);
// }
// ```
//
// Aucune branche d'échec. Quand `canLaunchUrl` rend faux, la fonction rend la
// main : pas de message, pas de journal, pas de repli. L'étudiant appuie sur
// l'action même sans laquelle il rate la bourse, et rien ne bouge.
//
// Le second explique POURQUOI ça rendait faux. `targetSdkVersion` vaut 36 :
// depuis API 30, `canLaunchUrl` est filtré par la visibilité des paquets, et ni
// notre manifeste ni celui d'url_launcher_android ne déclarait d'intention
// VIEW/https. Le même mécanisme menaçait le renvoi WhatsApp, c'est-à-dire
// l'unique chemin de monétisation de l'app.
//
// ## Ce que ce fichier peut, et ce qu'il ne peut pas
//
// Il vérifie le comportement CLIENT : bouton masqué sur une URL inouvrable,
// présent sur une URL valide, et repli conseiller quand le lancement échoue.
// Il ne peut PAS vérifier la visibilité des paquets, qui n'existe que sur un
// vrai Android — ce volet est consigné dans la PR comme non substituable.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/scholarships/scholarship_detail_screen.dart';

import '../../widget_test_helpers.dart';

/// Un lanceur qui ÉCHOUE, comme le fait un Android sans intention déclarée.
class _FailingLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> attempted = <String>[];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    attempted.add(url);
    throw PlatformException(
      code: 'ACTIVITY_NOT_FOUND',
      message: 'No Activity found to handle Intent',
    );
  }
}

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

Map<String, dynamic> _json(String? applicationUrl) => <String, dynamic>{
      'id': 'mext-2027',
      'title': 'MEXT Japan Scholarship',
      'countryName': 'Japan',
      'fundingType': 'fully_funded',
      'applicationRequirement': 'separate_application',
      'description': 'Full Japanese government scholarship.',
      'advantages': <String>[],
      'eligibility': <String>[],
      'level': 'Master',
      'deadlineLabel': 'May 2027',
      'deadlineAt':
          DateTime.now().add(const Duration(days: 40)).toIso8601String(),
      if (applicationUrl != null) 'applicationUrl': applicationUrl,
      'tags': <String>['scholarship'],
      'matchScore': 82,
      'applicationSteps': <dynamic>[],
    };

void _stub(MockApiClient mock, LiveScholarshipModel scholarship) {
  when(() => mock.fetchLiveScholarshipDetailWithFallback(
        scholarshipId: any(named: 'scholarshipId'),
        lang: any(named: 'lang'),
        initial: any(named: 'initial'),
      )).thenAnswer((_) async => scholarship);
  when(() => mock.fetchScholarshipAlerts()).thenAnswer((_) async => <String>{});
  when(() => mock.getSuccessLabAccess()).thenAnswer(
    (_) async => <String, dynamic>{'enabled': false, 'reasons': <String>[]},
  );
}

Future<void> _seed(MockApiClient apiClient) async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
    ),
    apiClient: apiClient,
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

Future<ScholarshipDetailScreen> _pumpDetail(
  WidgetTester tester,
  String? applicationUrl,
) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final mock = MockApiClient();
  final scholarship = LiveScholarshipModel.fromJson(_json(applicationUrl));
  _stub(mock, scholarship);
  await _seed(mock);

  final screen = ScholarshipDetailScreen(
    scholarshipId: scholarship.id,
    initialScholarship: scholarship,
    apiClient: mock,
  );
  await tester.pumpWidget(_wrap(screen));
  await tester.pumpAndSettle();
  return screen;
}

void main() {
  late UrlLauncherPlatform previous;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    previous = UrlLauncherPlatform.instance;
  });
  tearDown(() {
    UrlLauncherPlatform.instance = previous;
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  testWidgets('URL sans schéma — le bouton est ABSENT, pas silencieux',
      (tester) async {
    UrlLauncherPlatform.instance = _RecordingLauncher();
    await _pumpDetail(tester, 'exemple.org/apply');

    expect(
      find.byKey(const ValueKey<String>('scholarship-action-apply')),
      findsNothing,
      reason: 'Le catalogue contient des `applicationUrl` sans schéma. '
          '`Uri.parse` les accepte — il y voit un chemin relatif — puis le '
          'lancement échoue. Un bouton principal qui ne PEUT PAS marcher se '
          'masque, comme sur l\'écran de mise à jour forcée.',
    );
  });

  testWidgets('URL valide — le bouton est présent et ouvre le lien',
      (tester) async {
    final launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
    await _pumpDetail(tester, 'https://example.org/mext/apply');

    final button =
        find.byKey(const ValueKey<String>('scholarship-action-apply'));
    expect(button, findsOneWidget);

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(launcher.launched, ['https://example.org/mext/apply']);
  });

  testWidgets(
      'lancement en échec — un repli conseiller apparaît (rien, avant correctif)',
      (tester) async {
    final launcher = _FailingLauncher();
    UrlLauncherPlatform.instance = launcher;
    await _pumpDetail(tester, 'https://example.org/mext/apply');

    final button =
        find.byKey(const ValueKey<String>('scholarship-action-apply'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      launcher.attempted,
      isNotEmpty,
      reason: 'On TENTE le lancement au lieu de demander la permission à '
          '`canLaunchUrl`, qui ment sur Android 11+.',
    );
    expect(
      find.text('external_link_failed_title'.tr),
      findsOneWidget,
      reason: 'Avant correctif, absolument rien n\'apparaissait : le bouton '
          'était indiscernable d\'une app plantée.',
    );
    expect(find.text('external_link_failed_cta'.tr), findsOneWidget);

    // Le bandeau porte une animation de six secondes. La laisser courir fait
    // échouer le test à la destruction de l'arbre — « Ticker was still
    // active » — c'est-à-dire pour une raison qui n'a rien à voir avec le lien.
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}
