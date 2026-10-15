// La bulle verte WhatsApp de l'espace « Études en France » (build 56) : une
// pastille ronde dans le hub et le catalogue, qui ouvre un menu de sujets, dont
// chacun ouvre WhatsApp avec un message déjà écrit.
//
// Ce que ce fichier garantit, pour l'étudiant :
//   · la bulle n'existe QUE dans le hub et le catalogue, quand le serveur a
//     ouvert l'espace ET la bulle (deux interrupteurs, tous deux fermés par
//     défaut) — jamais dans la vitrine, les outils, l'écran des parents ;
//   · chaque sujet montre son libellé ET le message exact qui partira, et rien
//     ne part sans un tap : la feuille est fermée AVANT que WhatsApp s'ouvre ;
//   · un compte dont le pays est suspendu garde la bulle, avec deux lignes
//     neutres qui ne parlent ni de dossier ni de démarrer, ne nomment aucun
//     pays, et se mesurent sous les MÊMES identifiants que le menu standard ;
//   · la bulle ne cache jamais la dernière carte ni la rangée des sources, sur
//     des petits téléphones, à l'échelle de texte 1,3, en français et en
//     anglais ;
//   · la mesure ne porte que trois identifiants fermés (+ `surface` pour
//     l'ouverture du menu), jamais le texte du message ni le pays.
//
// Le lanceur d'URL est intercepté à `UrlLauncherPlatform`, comme partout dans
// ce dossier ; la mesure passe par la couture `EefHelpCard.analytics`.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/components/kpb_error_state.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_data_notice.dart';
import 'package:karatou/app/features/etudes_en_france/eef_entry.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_bubble.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_official_links.dart';
import 'package:karatou/app/features/tools/cv_generator_screen.dart';
import 'package:karatou/app/features/tools/interview_simulator_screen.dart';
import 'package:karatou/app/features/tools/motivation_letters_screen.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/pixel_contrast.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';
import '../../support/eef_tour_fakes.dart';

// ── Les textes attendus, ÉCRITS EN DUR ────────────────────────────────────────
//
// Un test qui relirait la clé que le code lit ne verrait pas qu'on l'a vidée ou
// retouchée : les messages qui partent chez le conseiller sont recopiés ici.

const _frHub = "l'espace Études en France de l'app";
const _frCatalog = "le catalogue de l'espace Études en France de l'app";
const _enHub = 'the Études en France space of the app';
const _enCatalog = 'the catalogue of the Études en France space of the app';

/// Ce que dit chaque sujet : libellé et message, FR et EN, pour le hub (`hub`) et
/// le catalogue (`cat`).
class _Topic {
  const _Topic(
    this.option, {
    required this.frLabel,
    required this.enLabel,
    required this.frHub,
    required this.frCat,
    required this.enHub,
    required this.enCat,
  });

  final EefBubbleOption option;
  final String frLabel;
  final String enLabel;
  final String frHub;
  final String frCat;
  final String enHub;
  final String enCat;

  String message({required bool fr, required bool catalog}) =>
      fr ? (catalog ? frCat : frHub) : (catalog ? enCat : enHub);
}

const _topics = <_Topic>[
  _Topic(
    EefBubbleOption.assistance,
    frLabel: "Contacter l'équipe KPB pour une assistance",
    enLabel: 'Contact the KPB team for assistance',
    frHub:
        "Bonjour KPB Education, je suis dans $_frHub et j'aimerais de l'aide de l'équipe KPB.",
    frCat:
        "Bonjour KPB Education, je suis dans $_frCatalog et j'aimerais de l'aide de l'équipe KPB.",
    enHub:
        "Hello KPB Education, I'm in $_enHub and I'd like help from the KPB team.",
    enCat:
        "Hello KPB Education, I'm in $_enCatalog and I'd like help from the KPB team.",
  ),
  _Topic(
    EefBubbleOption.dossier,
    frLabel: 'Je veux de l\'aide pour mon dossier',
    enLabel: 'I want help with my application',
    frHub:
        "Bonjour KPB Education, je suis dans $_frHub et j'aimerais de l'aide pour préparer mon dossier de candidature.",
    frCat:
        "Bonjour KPB Education, je suis dans $_frCatalog et j'aimerais de l'aide pour préparer mon dossier de candidature.",
    enHub:
        "Hello KPB Education, I'm in $_enHub and I'd like help preparing my application.",
    enCat:
        "Hello KPB Education, I'm in $_enCatalog and I'd like help preparing my application.",
  ),
  _Topic(
    EefBubbleOption.choose,
    frLabel: 'Je ne sais pas quelle formation choisir',
    enLabel: "I don't know which programme to choose",
    frHub:
        "Bonjour KPB Education, je suis dans $_frHub. J'hésite sur le choix de ma formation et j'aimerais en parler.",
    frCat:
        "Bonjour KPB Education, je suis dans $_frCatalog. J'hésite sur le choix de ma formation et j'aimerais en parler.",
    enHub:
        "Hello KPB Education, I'm in $_enHub. I'm unsure which programme to choose and I'd like to talk about it.",
    enCat:
        "Hello KPB Education, I'm in $_enCatalog. I'm unsure which programme to choose and I'd like to talk about it.",
  ),
  _Topic(
    EefBubbleOption.question,
    frLabel: "J'ai une autre question",
    enLabel: 'I have another question',
    frHub: "Bonjour KPB Education, j'ai une question sur $_frHub.",
    frCat: "Bonjour KPB Education, j'ai une question sur $_frCatalog.",
    enHub: 'Hello KPB Education, I have a question about $_enHub.',
    enCat: 'Hello KPB Education, I have a question about $_enCatalog.',
  ),
];

/// Les deux lignes d'un compte dont le pays est suspendu.
const _neutralTopics = <_Topic>[
  _Topic(
    EefBubbleOption.assistance,
    frLabel: 'Parler à un conseiller',
    enLabel: 'Talk to an advisor',
    frHub:
        "Bonjour KPB Education, je suis dans $_frHub. La procédure est suspendue dans mon pays : j'aimerais savoir quelles options existent.",
    frCat:
        "Bonjour KPB Education, je suis dans $_frCatalog. La procédure est suspendue dans mon pays : j'aimerais savoir quelles options existent.",
    enHub:
        "Hello KPB Education, I'm in $_enHub. The procedure is suspended in my country: I'd like to know what options exist.",
    enCat:
        "Hello KPB Education, I'm in $_enCatalog. The procedure is suspended in my country: I'd like to know what options exist.",
  ),
  _Topic(
    EefBubbleOption.question,
    frLabel: "J'ai une autre question",
    enLabel: 'I have another question',
    frHub:
        "Bonjour KPB Education, je suis dans $_frHub. La procédure est suspendue dans mon pays et j'ai une question.",
    frCat:
        "Bonjour KPB Education, je suis dans $_frCatalog. La procédure est suspendue dans mon pays et j'ai une question.",
    enHub:
        "Hello KPB Education, I'm in $_enHub. The procedure is suspended in my country and I have a question.",
    enCat:
        "Hello KPB Education, I'm in $_enCatalog. The procedure is suspended in my country and I have a question.",
  ),
];

/// Ce que dirait une invitation à ouvrir un dossier, en français comme en
/// anglais, et le nom de l'opérateur de l'État : aucun texte destiné à un pays
/// suspendu ne doit en contenir un seul (même garde que eef_help_line_test.dart).
final _openAFileWording = RegExp(
  r'dossier|d[ée]marrer|campus\s*france|\bstart\b|\bfile\b|\breview\b',
  caseSensitive: false,
);

/// Les pays qu'un message ne doit jamais nommer (ni le sien, ni un pays de
/// remplacement). « France » n'y figure pas : c'est le nom de l'espace.
final _countryWording = RegExp(
  r'togo|s[ée]n[ée]gal|c[ôo]te d.ivoire|cameroun|cameroon|maroc|morocco|'
  r'niger\b|mali|burkina|guin[ée]e|b[ée]nin|gabon|congo|tunisi|alg[ée]ri|'
  r'autre pays pour|another country',
  caseSensitive: false,
);

// ── La géométrie : les écrans éprouvés ───────────────────────────────────────

const _se = KpbViewport(
  id: 'phone320',
  name: 'Petit téléphone 320×568',
  size: Size(320, 568),
  padding: EdgeInsets.only(top: 20),
);

const _android640 = KpbViewport(
  id: 'android360x640',
  name: 'Android 360×640',
  size: Size(360, 640),
  padding: EdgeInsets.only(top: 24),
);

const _ipad = KpbViewport(
  id: 'ipad768',
  name: 'iPad 768×1024',
  size: Size(768, 1024),
  padding: EdgeInsets.only(top: 24, bottom: 20),
);

const _matrixViewports = <KpbViewport>[_se, _android640, iphone14, _ipad];

const _bubbleKey = ValueKey('eef-help-bubble');
const _sheetKey = ValueKey('eef-help-bubble-sheet');

/// L'action sémantique « toucher » sur le nœud d'étiquette [label] : ce que fait
/// un lecteur d'écran. Elle appelle directement le gestionnaire, SANS passer par
/// un test de zone touchée — donc sans que le voile de la feuille ne
/// l'intercepte.
void semanticTap(WidgetTester tester, Pattern label) =>
    tester.semantics.tap(find.semantics.byLabel(label));

/// L'étiquette sémantique d'une tuile : « libellé. message ».
RegExp _optionLabel(String label) => RegExp('^${RegExp.escape(label)}\\. ');

Finder _option(EefBubbleOption option) =>
    find.byKey(ValueKey('eef-help-bubble-option-${option.id}'));

// ── Un lanceur qui regarde si la feuille est encore là ───────────────────────

/// Enregistre, à CHAQUE lancement, si la feuille de la bulle est encore dans
/// l'arbre (« la feuille se ferme, PUIS WhatsApp s'ouvre ») et combien de
/// `eef_help_cta_tapped` étaient déjà partis (« la mesure part AVANT
/// l'ouverture »).
class _ProbingLauncher extends RecordingUrlLauncher {
  _ProbingLauncher(this.sheetIsOpen, this.tappedCount);

  final bool Function() sheetIsOpen;
  final int Function() tappedCount;
  final List<bool> sheetOpenAtLaunch = <bool>[];
  final List<int> tappedAtLaunch = <int>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    sheetOpenAtLaunch.add(sheetIsOpen());
    tappedAtLaunch.add(tappedCount());
    return super.launchUrl(url, options);
  }
}

/// Un événement tel que `AnalyticsService` l'émet vers Firebase : son nom et ses
/// paramètres EXACTS (couture `logEventSink`).
class _Emitted {
  const _Emitted(this.name, this.params);

  final String name;
  final Map<String, Object> params;

  @override
  String toString() => '$name$params';
}

DioException _dio(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/search'),
      type: type,
    );

Map<String, dynamic> _program(String id, {String name = 'Licence Droit'}) =>
    <String, dynamic>{
      'id': id,
      'institutionId': 'eef-univ-x',
      'countryId': 'fra',
      'fieldId': 'd07',
      'nameFr': name,
      'nameEn': name,
      'levelFr': 'Bac+3',
      'levelEn': 'Bachelor',
      'durationFr': '3 ans',
      'durationEn': '3 years',
      'tuitionFr': 'x',
      'tuitionEn': 'x',
      'languageFr': 'Français',
      'languageEn': 'French',
      'requirementsFr': <String>[],
      'requirementsEn': <String>[],
      'procedureType': 'eef',
      'cycle': 'licence3',
      'campusCity': 'Lyon',
      'institution': null,
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  bool? catalogPublished,
}) =>
    <String, dynamic>{
      'items': items,
      'total': items.length,
      'page': <String, dynamic>{
        'limit': 20,
        'hasMore': false,
        'nextCursor': null,
      },
      'facets': <String, dynamic>{},
      'facetsTruncated': <String>[],
      if (catalogPublished != null) 'catalogPublished': catalogPublished,
    };

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics analytics;
  late List<_Emitted> emitted;

  void stubCatalog(Future<Map<String, dynamic>> Function(Invocation) answer) {
    when(() => api.searchEefCatalog(
          query: any(named: 'query'),
          cycles: any(named: 'cycles'),
          procedureTypes: any(named: 'procedureTypes'),
          fieldIds: any(named: 'fieldIds'),
          campusCities: any(named: 'campusCities'),
          institutionIds: any(named: 'institutionIds'),
          selectivities: any(named: 'selectivities'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer(answer);
  }

  void stubThreePrograms() => stubCatalog((_) async => _page(
      [_program('a'), _program('b', name: 'Licence Lettres'), _program('c')]));

  void stubHubInterest() {
    when(() => api.getEefInterest())
        .thenAnswer((_) async => <String, dynamic>{'declared': false});
  }

  void setSuspendedCountries(List<String> countries) {
    EefCalendar.windowSource = () => EefCampaignWindow(
          opensAt: DateTime(2026, 10, 1),
          platformUrl: 'https://www.campusfrance.org/fr',
          suspendedCountries: countries,
          suspendedSources: const {
            'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
          },
        );
  }

  setUp(() {
    useSeenTour();
    api = MockApiClient();
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    analytics = RecordingHelpAnalytics();
    EefHelpCard.analytics = analytics;
    // Ce qui partirait vers Firebase, lu au niveau du service : nom et
    // paramètres exacts, sans passer par le faux d'`EefHelpCard`.
    emitted = <_Emitted>[];
    AnalyticsService.instance.logEventSink =
        (name, params) async => emitted.add(_Emitted(name, params));
    RemoteFeatureFlags.resetForTest();
    AppConfig.aiToolsEnabledOverride = null;
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    // Les deux interrupteurs OUVERTS par défaut dans CE fichier : c'est le
    // harnais des autres fichiers qui garde la bulle fermée.
    AppConfig.eefSpaceEnabledOverride = true;
    AppConfig.eefHelpBubbleEnabledOverride = true;
    Get.locale = const Locale('fr');
    EefCalendar.clock = () => DateTime(2026, 9, 28);
    setSuspendedCountries(const ['Niger']);
    stubHubInterest();
    stubThreePrograms();
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    UrlLauncherPlatform.instance = previousLauncher;
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.aiToolsEnabledOverride = null;
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.eefHelpBubbleEnabledOverride = null;
    AppConfig.eefPrivateSchoolsEnabledOverride = null;
    Get.reset();
  });

  Future<void> seed(
    WidgetTester tester, {
    String country = 'Sénégal',
    bool guest = false,
    AccountType accountType = AccountType.student,
    Locale locale = const Locale('fr'),
  }) async {
    await seedKpbController(
      apiClient: api,
      snapshot: AppSnapshot(
        localeCode: locale.languageCode,
        hasCompletedOnboarding: true,
        isGuestMode: guest,
        profile: guest
            ? null
            : createTestProfile(
                countryOfResidence: country,
                accountType: accountType,
                preferredLanguage: locale.languageCode,
              ),
      ),
    );
  }

  Future<KpbScreenReport> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    String country = 'Sénégal',
    bool guest = false,
    AccountType accountType = AccountType.student,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
    ThemeMode themeMode = ThemeMode.light,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    await seed(
      tester,
      country: country,
      guest: guest,
      accountType: accountType,
      locale: locale,
    );
    return pumpKpbScreen(
      tester,
      screen: screen,
      viewport: viewport,
      textScale: textScale,
      locale: locale,
      themeMode: themeMode,
      viewInsets: viewInsets,
      // La feuille reprend la taille et l'échelle de texte de l'écran éprouvé.
      routesShareMediaQuery: true,
    );
  }

  Future<KpbScreenReport> pumpHub(
    WidgetTester tester, {
    String country = 'Sénégal',
    bool guest = false,
    AccountType accountType = AccountType.student,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
    ThemeMode themeMode = ThemeMode.light,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) =>
      pumpScreen(
        tester,
        const EefHomeScreen(),
        country: country,
        guest: guest,
        accountType: accountType,
        viewport: viewport,
        textScale: textScale,
        locale: locale,
        themeMode: themeMode,
        viewInsets: viewInsets,
      );

  Future<KpbScreenReport> pumpCatalog(
    WidgetTester tester, {
    String country = 'Sénégal',
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
    ThemeMode themeMode = ThemeMode.light,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) =>
      pumpScreen(
        tester,
        const EefCatalogScreen(),
        country: country,
        guest: guest,
        viewport: viewport,
        textScale: textScale,
        locale: locale,
        themeMode: themeMode,
        viewInsets: viewInsets,
      );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(_bubbleKey));
    await settleBounded(tester);
  }

  Future<void> tapOption(WidgetTester tester, EefBubbleOption option) async {
    final tile = _option(option);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    // La feuille se ferme (animation), PUIS WhatsApp s'ouvre.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Fait défiler la liste du bas de l'écran jusqu'au bout.
  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).last, const Offset(0, -9000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -9000));
    await tester.pumpAndSettle();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. OÙ ELLE EST, OÙ ELLE N'EST PAS
  // ═══════════════════════════════════════════════════════════════════════════

  group('où la bulle apparaît', () {
    testWidgets('hub : espace ouvert ET bulle ouverte → UNE bulle',
        (tester) async {
      await pumpHub(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('catalogue : espace ouvert ET bulle ouverte → UNE bulle',
        (tester) async {
      await pumpCatalog(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('hub : bulle fermée (le défaut) → aucune', (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpHub(tester);
      expect(find.byKey(_bubbleKey), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('catalogue : bulle fermée (le défaut) → aucune',
        (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpCatalog(tester);
      expect(find.byKey(_bubbleKey), findsNothing);
      expect(find.text('Licence Droit'), findsWidgets);
    });

    // La bulle n'ouvre rien seule : l'espace doit être ouvert EN PLUS.
    testWidgets('hub monté espace fermé, bulle ouverte → aucune',
        (tester) async {
      AppConfig.eefSpaceEnabledOverride = false;
      await pumpHub(tester);
      expect(find.byKey(_bubbleKey), findsNothing);
    });

    testWidgets('catalogue : espace fermé, bulle ouverte → « bientôt », rien',
        (tester) async {
      AppConfig.eefSpaceEnabledOverride = false;
      await pumpCatalog(tester);
      expect(find.byKey(_bubbleKey), findsNothing);
      expect(find.text('Bientôt disponible'), findsWidgets);
    });

    testWidgets('l\'invité a la bulle (hub et catalogue)', (tester) async {
      await pumpHub(tester, guest: true);
      expect(find.byKey(_bubbleKey), findsOneWidget);
      await pumpCatalog(tester, guest: true);
      expect(find.byKey(_bubbleKey), findsOneWidget);
    });

    testWidgets('un compte parent n\'a pas la bulle, même sur le hub monté',
        (tester) async {
      await pumpHub(tester, accountType: AccountType.parent);
      expect(find.byKey(_bubbleKey), findsNothing);
    });

    testWidgets('un compte partenaire n\'a pas la bulle sur le catalogue',
        (tester) async {
      // (la contre-épreuve — un étudiant l'a — est le test du catalogue plus haut.)
      await pumpScreen(
        tester,
        const EefCatalogScreen(),
        accountType: AccountType.partner,
      );
      expect(find.text('Licence Droit'), findsWidgets);
      expect(find.byKey(_bubbleKey), findsNothing);
    });

    testWidgets('par la porte unique : un parent lit « pour les étudiants »',
        (tester) async {
      await pumpScreen(
        tester,
        const EefEntry(),
        accountType: AccountType.parent,
      );
      expect(find.text('Un espace pour les étudiants'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('la vitrine n\'a jamais la bulle, même drapeaux ouverts',
        (tester) async {
      AppConfig.eefSpaceEnabledOverride = null;
      AppConfig.eefTeaserEnabledOverride = true;
      await pumpScreen(tester, const EefEntry());
      expect(find.byType(EefHomeScreen), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(_bubbleKey), findsNothing);
    });

    // Les écrans d'outils portent déjà leur propre ligne d'aide (et celui de
    // l'entretien un champ de saisie) : la bulle n'y vient pas.
    for (final entry in <String, Widget>{
      'CV': const CvGeneratorScreen(fromEefHub: true),
      'lettres': const MotivationLettersScreen(fromEefHub: true),
      'entretien': const InterviewSimulatorScreen(fromEefHub: true),
    }.entries) {
      testWidgets('l\'outil « ${entry.key} » n\'a pas la bulle',
          (tester) async {
        AppConfig.aiToolsEnabledOverride = true;
        await pumpScreen(tester, entry.value);
        expect(find.byKey(_bubbleKey), findsNothing);
      });
    }

    testWidgets('elle se montre quand le drapeau arrive APRÈS le premier cadre',
        (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpHub(tester);
      expect(find.byKey(_bubbleKey), findsNothing);

      AppConfig.eefHelpBubbleEnabledOverride = true;
      // Ce que fait `RemoteFeatureFlags.refresh` à l'arrivée de /config/app.
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await tester.pump();
      expect(find.byKey(_bubbleKey), findsOneWidget);

      AppConfig.eefHelpBubbleEnabledOverride = false;
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await tester.pump();
      expect(find.byKey(_bubbleKey), findsNothing);
    });

    // Les tests ci-dessus pilotent le REPLI DE COMPILATION (`AppConfig.*Override`).
    // Celui-ci n'en pose AUCUN : il sert de vrais drapeaux par `/config/app` et
    // éprouve que l'écran lit le drapeau SERVEUR. Sans lui, une bulle compilée à
    // vrai ne se retirerait plus sans build — alors que ce retrait à distance est
    // la raison d'être de l'interrupteur.
    for (final onCatalog in [false, true]) {
      testWidgets(
          'obéit aux interrupteurs SERVEUR, sans aucun override '
          '(${onCatalog ? 'catalogue' : 'hub'})', (tester) async {
        AppConfig.eefSpaceEnabledOverride = null;
        AppConfig.eefHelpBubbleEnabledOverride = null;

        Future<void> serve(Map<String, dynamic> features) async {
          when(api.getAppConfig)
              .thenAnswer((_) async => <String, dynamic>{'features': features});
          await RemoteFeatureFlags.instance.refresh(api);
          await settleBounded(tester);
        }

        if (onCatalog) {
          await pumpCatalog(tester);
        } else {
          await pumpHub(tester);
        }
        // Rien de servi, rien de compilé : fermée.
        expect(find.byKey(_bubbleKey), findsNothing);

        await serve({'eefSpace': true, 'eefHelpBubble': true});
        expect(find.byKey(_bubbleKey), findsOneWidget);

        await serve({'eefSpace': true, 'eefHelpBubble': false});
        expect(find.byKey(_bubbleKey), findsNothing);

        await serve({'eefSpace': true, 'eefHelpBubble': true});
        expect(find.byKey(_bubbleKey), findsOneWidget);

        // La bulle n'ouvre rien seule : l'espace fermé la retire.
        await serve({'eefSpace': false, 'eefHelpBubble': true});
        expect(find.byKey(_bubbleKey), findsNothing);

        // Une clé de bulle absente vaut fermée.
        await serve({'eefSpace': true});
        expect(find.byKey(_bubbleKey), findsNothing);
      });
    }

    testWidgets('clavier ouvert → bulle masquée (catalogue)', (tester) async {
      await pumpCatalog(
        tester,
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      expect(find.byKey(_bubbleKey), findsNothing);

      // Contre-épreuve : le même écran, clavier fermé, l'a.
      await pumpCatalog(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
    });

    testWidgets('clavier ouvert → bulle masquée (hub)', (tester) async {
      await pumpHub(
        tester,
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      expect(find.byKey(_bubbleKey), findsNothing);

      await pumpHub(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. SON APPARENCE
  // ═══════════════════════════════════════════════════════════════════════════

  group('l\'apparence', () {
    testWidgets('un cercle de 56 dp, vert WhatsApp, glyphe marine de 26 dp',
        (tester) async {
      await pumpHub(tester);

      final fab = tester.widget<FloatingActionButton>(find.byKey(_bubbleKey));
      expect(tester.getSize(find.byKey(_bubbleKey)), const Size(56, 56));
      expect(fab.shape, isA<CircleBorder>());
      expect(fab.backgroundColor, KpbColors.whatsapp);
      expect(fab.foregroundColor, KpbColors.brandNavy);
      expect(fab.elevation, 4);
      // Pas d'animation Hero hub → catalogue quand on passe de l'un à l'autre.
      expect(fab.heroTag, isNull);

      final icon = tester.widget<Icon>(find.descendant(
        of: find.byKey(_bubbleKey),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, Icons.chat_rounded);
      expect(icon.size, 26);
      // Un cercle sans libellé.
      expect(
        find.descendant(
          of: find.byKey(_bubbleKey),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    // Le blanc ne fait qu'environ 1,98:1 sur ce vert : le glyphe marine est un
    // CHOIX, et cette mesure — sur les pixels peints, pas dans l'arbre — est ce
    // qui l'empêche de redevenir blanc sans qu'on le voie.
    testWidgets('le glyphe marine tient 3:1 sur le vert, MESURÉ sur les pixels',
        (tester) async {
      await pumpHub(tester);

      final glyph = find.descendant(
        of: find.byKey(_bubbleKey),
        matching: find.byType(Icon),
      );
      final measured = await measurePixelContrast(tester, glyph);

      expect(sameColor(measured.background, KpbColors.whatsapp), isTrue,
          reason: 'fond mesuré : $measured');
      expect(sameColor(measured.foreground, KpbColors.brandNavy), isTrue,
          reason: 'glyphe mesuré : $measured');
      expect(measured.ratio, greaterThanOrEqualTo(3.0), reason: '$measured');
      // Le harnais sait mordre : du blanc sur ce vert ne passe PAS.
      expect(wcagContrast(KpbColors.whatsapp, Colors.white), lessThan(3.0));
    });

    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final fr = locale.languageCode == 'fr';
      testWidgets(
          'nom et indice lus par un lecteur d\'écran (${locale.languageCode})',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHub(tester, locale: locale);

        final data = tester.getSemantics(find.byKey(_bubbleKey));
        expect(
          data.label,
          fr
              ? "Écrire à l'équipe KPB sur WhatsApp"
              : 'Message the KPB team on WhatsApp',
        );
        expect(
          data.hint,
          fr
              ? 'Ouvre une liste de messages prêts à envoyer'
              : 'Opens a list of ready-made messages',
        );
        expect(data.flagsCollection.isButton, isTrue);

        // L'infobulle (appui long) dit la même chose.
        final tooltip = tester.widget<FloatingActionButton>(
          find.byKey(_bubbleKey),
        );
        expect(
          tooltip.tooltip,
          fr
              ? "Écrire à l'équipe KPB sur WhatsApp"
              : 'Message the KPB team on WhatsApp',
        );
        handle.dispose();
      });
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. LE MENU
  // ═══════════════════════════════════════════════════════════════════════════

  group('le menu de sujets', () {
    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final fr = locale.languageCode == 'fr';

      testWidgets('hub (${locale.languageCode}) : titre, sous-titre, 4 sujets',
          (tester) async {
        await pumpHub(tester, locale: locale);
        await openMenu(tester);

        expect(find.byKey(_sheetKey), findsOneWidget);
        expect(find.text(fr ? "Écrire à l'équipe KPB" : 'Message the KPB team'),
            findsOneWidget);
        expect(
          find.text(fr
              ? "Choisis ton sujet. WhatsApp s'ouvre avec un message déjà écrit : tu peux le modifier, et rien n'est envoyé sans toi."
              : 'Pick your topic. WhatsApp opens with a message already written: you can edit it, and nothing is sent without you.'),
          findsOneWidget,
        );

        // Quatre sujets — pas cinq : « écoles privées » (PR 3/5) a son propre
        // interrupteur, FERMÉ ici (voir eef_private_schools_test.dart, où il est
        // ouvert et où le menu en a cinq).
        for (final topic in _topics) {
          expect(_option(topic.option), findsOneWidget);
          expect(find.text(fr ? topic.frLabel : topic.enLabel), findsOneWidget);
          // Le message EXACT est écrit sous le libellé.
          expect(
              find.text(topic.message(fr: fr, catalog: false)), findsOneWidget);
        }
        expect(find.byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> &&
              key.value.startsWith('eef-help-bubble-option-');
        }), findsNWidgets(4));

        expect(rawTranslationKeysOnScreen(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'catalogue (${locale.languageCode}) : le message nomme le catalogue',
          (tester) async {
        await pumpCatalog(tester, locale: locale);
        await openMenu(tester);

        for (final topic in _topics) {
          expect(
              find.text(topic.message(fr: fr, catalog: true)), findsOneWidget);
        }
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });

      testWidgets(
          'pays suspendu (${locale.languageCode}) : DEUX lignes neutres, '
          'la bulle reste', (tester) async {
        await pumpHub(tester, country: 'Niger', locale: locale);
        expect(find.byKey(_bubbleKey), findsOneWidget);
        await openMenu(tester);

        expect(_option(EefBubbleOption.assistance), findsOneWidget);
        expect(_option(EefBubbleOption.question), findsOneWidget);
        expect(_option(EefBubbleOption.dossier), findsNothing);
        expect(_option(EefBubbleOption.choose), findsNothing);
        for (final topic in _neutralTopics) {
          expect(find.text(fr ? topic.frLabel : topic.enLabel), findsOneWidget);
          expect(
              find.text(topic.message(fr: fr, catalog: false)), findsOneWidget);
        }
        // Ni le libellé ni le message standard de « assistance » n'y paraissent.
        expect(find.text(fr ? _topics.first.frLabel : _topics.first.enLabel),
            findsNothing);
        expect(find.text(_topics.first.message(fr: fr, catalog: false)),
            findsNothing);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });
    }

    testWidgets('chaque sujet est une tuile d\'au moins 56 dp, un bouton',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);
      await openMenu(tester);

      for (final topic in _topics) {
        final size = tester.getSize(_option(topic.option));
        expect(size.height, greaterThanOrEqualTo(56), reason: topic.option.id);
        final data = tester.getSemantics(_option(topic.option));
        expect(data.flagsCollection.isButton, isTrue);
        // Le libellé ET le message sont lus ensemble.
        expect(data.label, contains(topic.frLabel));
        expect(data.label, contains(topic.frHub));
      }
      handle.dispose();
    });

    testWidgets(
        'le pied : numéro officiel, copier, e-mail, anti-arnaque, mention',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);

      final number = AppConfig.whatsappNumber.trim();
      expect(number, isNotEmpty);
      await tester.ensureVisible(find.textContaining(number));
      expect(find.text('Numéro officiel de KPB Education : $number'),
          findsOneWidget);
      expect(find.textContaining('contact@kpbeducation.com'), findsOneWidget);
      // Les phrases qui existent déjà dans l'app, mot pour mot — cherchées
      // DANS la feuille : l'écran porteur, dessous, peut afficher la même
      // mention quand elle tient dans sa zone de construction.
      final sheet = find.byKey(const ValueKey('eef-help-bubble-sheet'));
      expect(
        find.descendant(of: sheet, matching: find.text('anti_fraud_body'.tr)),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: sheet, matching: find.text('eef_help_fineprint'.tr)),
        findsOneWidget,
      );
      expect(find.text('Copier le numéro'), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets(
        '« Copier le numéro » copie le numéro officiel puis dit « Copié »',
        (tester) async {
      await pumpHub(tester);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await openMenu(tester);
      final copy = find.byKey(const ValueKey('eef-help-bubble-copy'));
      await tester.ensureVisible(copy);
      await tester.pump();
      await tester.tap(copy);
      await tester.pump();

      expect(copied, [AppConfig.whatsappNumber.trim()]);
      expect(find.text('Copié'), findsOneWidget);
      expect(find.text('Copier le numéro'), findsNothing);

      // Une feuille qu'on est en train de fermer est encore dans l'arbre pendant
      // son animation : un seul `pump` ne prouve pas qu'elle reste. On laisse
      // l'animation finir, PUIS on relit.
      await settleBounded(tester);
      expect(find.byKey(_sheetKey), findsOneWidget,
          reason: 'copier le numéro ne doit pas fermer la feuille');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Copié'), findsOneWidget);

      // Copier n'ouvre pas WhatsApp, ne ferme pas la feuille, ne mesure rien.
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
    });

    testWidgets('le pied reste vrai en anglais', (tester) async {
      await pumpHub(tester, locale: const Locale('en'));
      await openMenu(tester);
      final number = AppConfig.whatsappNumber.trim();
      await tester.ensureVisible(find.textContaining(number));
      expect(
          find.text('Official KPB Education number: $number'), findsOneWidget);
      expect(find.text('Copy number'), findsOneWidget);
      expect(find.text('anti_fraud_body'.tr), findsOneWidget);
    });

    testWidgets(
        'fermer la feuille sans choisir : rien ne part, rien n\'est tapé',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);

      // Le voile : un tap tout en haut de l'écran, au-dessus de la feuille.
      await tester.tapAt(const Offset(10, 20));
      await settleBounded(tester);

      expect(find.byKey(_sheetKey), findsNothing);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
      // On peut la rouvrir.
      await openMenu(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(analytics.openedSurfaces, ['hub', 'hub']);
    });

    testWidgets('thème sombre : la feuille se lit, sans erreur',
        (tester) async {
      await pumpHub(tester, themeMode: ThemeMode.dark);
      await openMenu(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. CE QUI PART VERS WHATSAPP
  // ═══════════════════════════════════════════════════════════════════════════

  group('un sujet tapé', () {
    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final fr = locale.languageCode == 'fr';
      for (final topic in _topics) {
        testWidgets(
            '${topic.option.id} (${locale.languageCode}) : hub — le message '
            'exact part, vers le numéro officiel', (tester) async {
          await pumpHub(tester, locale: locale);
          await openMenu(tester);
          await tapOption(tester, topic.option);

          expect(launcher.launched, hasLength(1));
          expect(launcher.lastText, topic.message(fr: fr, catalog: false));
          final uri = Uri.parse(launcher.launched.single);
          expect(uri.host, 'wa.me');
          expect(
            uri.path,
            '/${AppConfig.whatsappNumber.replaceAll(RegExp(r'[^\d]'), '')}',
          );
          expect(rawTranslationKeysOnScreen(tester), isEmpty);
        });

        testWidgets(
            '${topic.option.id} (${locale.languageCode}) : catalogue — le '
            'message nomme le catalogue', (tester) async {
          await pumpCatalog(tester, locale: locale);
          await openMenu(tester);
          await tapOption(tester, topic.option);

          expect(launcher.launched, hasLength(1));
          expect(launcher.lastText, topic.message(fr: fr, catalog: true));
        });
      }

      for (final topic in _neutralTopics) {
        testWidgets(
            'pays suspendu : ${topic.option.id} (${locale.languageCode}) — '
            'le message neutre part', (tester) async {
          await pumpHub(tester, country: 'Niger', locale: locale);
          await openMenu(tester);
          await tapOption(tester, topic.option);

          expect(launcher.lastText, topic.message(fr: fr, catalog: false));
        });
      }
    }

    testWidgets('la feuille est fermée AVANT que WhatsApp s\'ouvre',
        (tester) async {
      final probing = _ProbingLauncher(
        () => find.byKey(_sheetKey).evaluate().isNotEmpty,
        () => analytics.tappedCalls.length,
      );
      UrlLauncherPlatform.instance = probing;
      await pumpHub(tester);
      await openMenu(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);

      await tapOption(tester, EefBubbleOption.choose);

      expect(probing.launched, hasLength(1));
      expect(probing.sheetOpenAtLaunch, [false],
          reason: 'le lancement ne doit pas partir sous une feuille encore là');
      expect(find.byKey(_sheetKey), findsNothing);
    });

    // L'ordre écrit dans le code et dans le contrat publié : `eef_help_cta_tapped`
    // part AVANT l'ouverture de WhatsApp. Si l'ouverture levait avant la mesure,
    // le tap ne serait jamais compté et l'entonnoir « sujet choisi → envoi »
    // divergerait de `whatsapp_handoff`.
    testWidgets('`eef_help_cta_tapped` part AVANT l\'ouverture de WhatsApp',
        (tester) async {
      final probing = _ProbingLauncher(
        () => find.byKey(_sheetKey).evaluate().isNotEmpty,
        () => analytics.tappedCalls.length,
      );
      UrlLauncherPlatform.instance = probing;
      await pumpHub(tester);
      await openMenu(tester);
      await tapOption(tester, EefBubbleOption.question);

      expect(probing.launched, hasLength(1));
      expect(probing.tappedAtLaunch, [1],
          reason: 'la mesure doit être partie quand WhatsApp s\'ouvre');
      expect(analytics.tappedCalls, hasLength(1));
    });

    testWidgets(
        'sans WhatsApp, l\'étudiant lit le toast (le lancement est TENTÉ)',
        (tester) async {
      final failing = FailingUrlLauncher();
      UrlLauncherPlatform.instance = failing;
      await pumpHub(tester);
      await openMenu(tester);
      await tapOption(tester, EefBubbleOption.assistance);

      expect(failing.launched, hasLength(1),
          reason: 'le lancement a bien été TENTÉ, sans canLaunchUrl');
      expect(find.text('whatsapp_open_failed'.tr), findsOneWidget,
          reason: 'sans WhatsApp, l\'étudiant doit lire pourquoi');
      expect(rawTranslationKeysOnScreen(tester), isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    test('le suivi attribue `eef_help_<sujet>` et le type `eef_help`', () {
      final source =
          File('lib/app/features/etudes_en_france/eef_help_bubble.dart')
              .readAsStringSync();
      // L'identifiant du sujet est `bubble_<sujet>` : la source est donc
      // `eef_help_bubble_<sujet>`, comme `eef_help_<help_step>` partout ailleurs.
      expect(source, contains("source: 'eef_help_\${pick.option.id}'"));
      expect(source, contains("contextType: 'eef_help'"));
      expect(source, isNot(contains('canLaunchUrl')));
      for (final option in EefBubbleOption.values) {
        expect('eef_help_${option.id}', startsWith('eef_help_bubble_'));
      }
    });

    // Deux ACTIVATIONS d'affilée, sans cadre entre elles : ce qu'un lecteur
    // d'écran ou un double appui rapide produit. Un tap au doigt ne le peut pas
    // (le voile de la feuille recouvre la bulle dès le cadre suivant), donc c'est
    // l'action sémantique qui éprouve la garde.
    testWidgets('deux activations d\'affilée n\'ouvrent QU\'UNE feuille',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);

      semanticTap(tester, "Écrire à l'équipe KPB sur WhatsApp");
      semanticTap(tester, "Écrire à l'équipe KPB sur WhatsApp");
      await settleBounded(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(analytics.openedSurfaces, ['hub']);

      // Fermée sans choisir, elle se rouvre normalement.
      await tester.tapAt(const Offset(10, 20));
      await settleBounded(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      await openMenu(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(analytics.openedSurfaces, ['hub', 'hub']);
      handle.dispose();
    });

    // Sans hit-test : un double tap au doigt ne peut PAS éprouver la garde (le
    // second tap tombe sur le voile, pas sur la bulle). On appelle donc deux fois
    // le gestionnaire du bouton, sans cadre entre les deux.
    testWidgets(
        'deux appels du gestionnaire sans cadre n\'ouvrent QU\'UNE '
        'feuille', (tester) async {
      await pumpHub(tester);
      final onPressed = tester
          .widget<FloatingActionButton>(find.byKey(_bubbleKey))
          .onPressed!;
      onPressed();
      onPressed();
      await settleBounded(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(analytics.openedSurfaces, ['hub']);
    });

    testWidgets('deux sujets activés d\'affilée n\'envoient QU\'UN message',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);
      await openMenu(tester);

      semanticTap(tester, _optionLabel(_topics[1].frLabel));
      semanticTap(tester, _optionLabel(_topics[3].frLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(launcher.launched, hasLength(1));
      expect(launcher.lastText, _topics[1].frHub);
      expect(analytics.tappedCalls, hasLength(1));
      // Le hub est toujours là : la seconde activation n'a pas dépilé l'écran
      // qui est dessous.
      expect(find.byType(EefHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. LA SUSPENSION, CALCULÉE AU BON MOMENT
  // ═══════════════════════════════════════════════════════════════════════════

  group('la suspension arrive pendant que la feuille est ouverte', () {
    testWidgets('le menu se reconstruit sur l\'arrivée des drapeaux',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      expect(_option(EefBubbleOption.dossier), findsOneWidget);

      // Le serveur dit que le Sénégal est suspendu.
      setSuspendedCountries(const ['Sénégal']);
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_option(EefBubbleOption.dossier), findsNothing);
      expect(_option(EefBubbleOption.choose), findsNothing);
      expect(_option(EefBubbleOption.assistance), findsOneWidget);
      expect(_option(EefBubbleOption.question), findsOneWidget);
      expect(find.text('Parler à un conseiller'), findsOneWidget);
    });

    testWidgets('même sans reconstruction, le message est recalculé AU TAP',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      expect(_option(EefBubbleOption.question), findsOneWidget);

      // La liste change sans que le menu ait été reconstruit : le tap relit.
      setSuspendedCountries(const ['Sénégal']);
      await tapOption(tester, EefBubbleOption.question);

      expect(launcher.lastText, _neutralTopics.last.frHub);
      expect(_openAFileWording.hasMatch(launcher.lastText), isFalse);
    });

    testWidgets(
        'un sujet sans variante neutre ne dit jamais « dossier » à un compte '
        'devenu suspendu', (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      setSuspendedCountries(const ['Sénégal']);
      await tapOption(tester, EefBubbleOption.dossier);

      expect(launcher.launched, hasLength(1));
      expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
          reason: launcher.lastText);
      expect(launcher.lastText, contains('suspendue'));
    });

    // Le message ET la mesure suivent le MÊME sujet : le contrat publié promet
    // qu'un compte suspendu ne produit jamais `bubble_dossier` ni
    // `bubble_choose`, ni en `help_step` ni dans la source WhatsApp.
    for (final tapped in [EefBubbleOption.dossier, EefBubbleOption.choose]) {
      testWidgets(
          '${tapped.id} tapé par un compte devenu suspendu : la mesure dit '
          '`bubble_assistance`, comme le message', (tester) async {
        await pumpHub(tester);
        await openMenu(tester);
        setSuspendedCountries(const ['Sénégal']);
        await tapOption(tester, tapped);

        expect(launcher.lastText, _neutralTopics.first.frHub);
        expect(analytics.tappedCalls, [
          const RecordedHelpEvent('bubble_assistance', 'hub', 'bubble'),
        ]);
        expect(launcher.launched, hasLength(1));
        // La source du suivi WhatsApp suit, elle aussi, le message qui part.
        final handoffs =
            emitted.where((e) => e.name == 'whatsapp_handoff').toList();
        expect(handoffs, hasLength(1));
        expect(handoffs.single.params['source'], 'eef_help_bubble_assistance');
        expect(emitted.map((e) => e.toString()).join(' '),
            isNot(contains(tapped.id)));
      });
    }

    test(
        'l\'option effective : inchangée hors suspension ou avec variante '
        'neutre', () {
      for (final option in EefBubbleOption.values) {
        expect(EefBubbleMessages.effectiveOption(option, suspended: false),
            option);
        expect(
          EefBubbleMessages.effectiveOption(option, suspended: true),
          option.hasNeutral ? option : EefBubbleOption.assistance,
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. LES MESSAGES : bornes et garde-fous
  // ═══════════════════════════════════════════════════════════════════════════

  group('les messages', () {
    for (final locale in ['fr', 'en']) {
      for (final surface in EefBubbleSurface.values) {
        for (final suspended in [false, true]) {
          test(
              '$locale / ${surface.key} / ${suspended ? 'suspendu' : 'standard'} '
              ': bornés, propres, sans @, sans donnée personnelle', () {
            Get.addTranslations(AppTranslations().keys);
            Get.locale = Locale(locale);
            Get.fallbackLocale = const Locale('fr');

            final options = EefBubbleMessages.optionsFor(suspended: suspended);
            expect(options, isNotEmpty);
            for (final option in options) {
              final message = EefBubbleMessages.messageFor(
                option,
                surface,
                suspended: suspended,
              );
              final label =
                  EefBubbleMessages.labelFor(option, suspended: suspended);
              final reason = '${option.id} : $message';

              expect(message, isNotEmpty, reason: reason);
              expect(label, isNotEmpty, reason: option.id);
              expect(message.runes.length, lessThanOrEqualTo(520),
                  reason: reason);
              expect(
                  Uri.encodeComponent(message).length, lessThanOrEqualTo(1800),
                  reason: reason);
              expect(message, isNot(contains('@')), reason: reason);
              expect(message, message.trim(), reason: 'espace de bord');
              expect(message, isNot(contains('\n')), reason: reason);
              expect(looksLikeRawTranslationKey(message), isFalse,
                  reason: reason);
              expect(looksLikeRawTranslationKey(label), isFalse,
                  reason: option.id);
              // Aucune donnée personnelle : le profil n'est pas lu.
              for (final personal in [
                'Mouhamadou',
                'Diallo',
                'example.com',
                '+2250',
              ]) {
                expect(message, isNot(contains(personal)));
              }
              // Jamais un pays.
              expect(_countryWording.hasMatch(message), isFalse,
                  reason: reason);
              if (suspended) {
                expect(_openAFileWording.hasMatch(message), isFalse,
                    reason: 'jeu neutre : $message');
                expect(_openAFileWording.hasMatch(label), isFalse,
                    reason: 'jeu neutre : $label');
              }
            }
          });
        }
      }
    }

    test('le jeu neutre est LE MÊME dans les deux langues : 2 lignes', () {
      expect(
        EefBubbleMessages.optionsFor(suspended: true).map((o) => o.id),
        ['bubble_assistance', 'bubble_question'],
      );
      // Interrupteur des écoles privées FERMÉ (le défaut) : quatre sujets.
      expect(
        EefBubbleMessages.optionsFor(suspended: false).map((o) => o.id),
        [
          'bubble_assistance',
          'bubble_dossier',
          'bubble_choose',
          'bubble_question',
        ],
      );
      // OUVERT : cinq, « écoles privées » en 4e position — et rien de plus pour
      // un compte suspendu, qui garde ses deux lignes neutres.
      expect(
        EefBubbleMessages.optionsFor(suspended: false, privateSchools: true)
            .map((o) => o.id),
        [
          'bubble_assistance',
          'bubble_dossier',
          'bubble_choose',
          'bubble_private',
          'bubble_question',
        ],
      );
      expect(
        EefBubbleMessages.optionsFor(suspended: true, privateSchools: true)
            .map((o) => o.id),
        ['bubble_assistance', 'bubble_question'],
      );
    });

    test('sans paramètre, le menu lit l\'interrupteur serveur', () {
      AppConfig.eefPrivateSchoolsEnabledOverride = null;
      expect(EefBubbleMessages.optionsFor(suspended: false), hasLength(4));
      AppConfig.eefPrivateSchoolsEnabledOverride = true;
      expect(EefBubbleMessages.optionsFor(suspended: false), hasLength(5));
      expect(EefBubbleMessages.optionsFor(suspended: true), hasLength(2));
    });

    test('les identifiants neutres SONT les identifiants standard', () {
      final standard = EefBubbleMessages.optionsFor(suspended: false)
          .map((o) => o.id)
          .toSet();
      final neutral = EefBubbleMessages.optionsFor(suspended: true);
      expect(neutral, hasLength(2), reason: 'un test vide ne prouve rien');
      for (final option in neutral) {
        expect(standard, contains(option.id));
      }
    });

    test('aucun identifiant, aucune surface ne révèle la suspension', () {
      for (final option in EefBubbleOption.values) {
        expect(option.id, isNot(contains('suspend')));
        expect(option.id, isNot(contains('neutral')));
        expect(option.id, matches(RegExp(r'^bubble_[a-z]+$')));
      }
      for (final surface in EefBubbleSurface.values) {
        expect(surface.key, isNot(contains('suspend')));
      }
      // Quatre sujets d'envoi + « écoles privées » (PR 3/5), qui ouvre une feuille.
      expect({for (final o in EefBubbleOption.values) o.id}, hasLength(5));
    });

    test('rien dans le fichier ne nomme la suspension comme mesure', () {
      final source =
          File('lib/app/features/etudes_en_france/eef_help_bubble.dart')
              .readAsStringSync();
      // On a le droit de DIRE « suspended » dans le code (lire le calcul), pas
      // de l'envoyer : aucune chaîne `'…suspend…'` ne sert d'identifiant.
      final literals = RegExp(r"'[a-z_]*suspend[a-z_]*'").allMatches(source);
      expect(literals, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. LA MESURE
  // ═══════════════════════════════════════════════════════════════════════════

  group('la mesure', () {
    testWidgets('bulle vue : UNE fois par visite, hub', (tester) async {
      List<RecordedHelpEvent> bubbleShown() =>
          analytics.shownCalls.where((e) => e.step == 'bubble').toList();

      await pumpHub(tester);
      expect(
          bubbleShown(), [const RecordedHelpEvent('bubble', 'hub', 'bubble')]);

      // Défiler, reconstruire sur l'arrivée des drapeaux : pas une 2e « vue ».
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump();
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await tester.pump();
      expect(bubbleShown(), hasLength(1));
    });

    // La bulle se retire (clavier, drapeau) puis revient dans la MÊME visite : sa
    // mémoire vit dans le `PageStorage` de l'écran, pas dans l'objet qui vient
    // d'être détruit — sinon chaque retour compterait une nouvelle « vue ».
    testWidgets('retirée puis revenue dans la même visite : pas une 2e « vue »',
        (tester) async {
      List<RecordedHelpEvent> bubbleShown() =>
          analytics.shownCalls.where((e) => e.step == 'bubble').toList();

      await pumpHub(tester);
      expect(bubbleShown(), hasLength(1));

      AppConfig.eefHelpBubbleEnabledOverride = false;
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      // Le `Scaffold` joue une animation de sortie du bouton flottant.
      await settleBounded(tester);
      expect(find.byKey(_bubbleKey), findsNothing);

      AppConfig.eefHelpBubbleEnabledOverride = true;
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await settleBounded(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
      expect(bubbleShown(), hasLength(1));
    });

    testWidgets('bulle vue : catalogue', (tester) async {
      await pumpCatalog(tester);
      expect(analytics.shownCalls.where((e) => e.step == 'bubble').toList(),
          [const RecordedHelpEvent('bubble', 'catalog', 'bubble')]);
    });

    testWidgets('rien n\'est « vu » quand la bulle est absente',
        (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpHub(tester);
      expect(analytics.shownCalls.where((e) => e.step == 'bubble'), isEmpty);
    });

    testWidgets('menu ouvert : `eef_bubble_opened` avec la surface',
        (tester) async {
      await pumpCatalog(tester);
      await openMenu(tester);
      expect(analytics.openedSurfaces, ['catalog']);
      // Ouvrir n'est pas envoyer.
      expect(analytics.tappedCalls, isEmpty);
    });

    for (final topic in _topics) {
      testWidgets(
          '${topic.option.id} : `eef_help_cta_tapped` porte EXACTEMENT '
          'help_step / surface / variant', (tester) async {
        await pumpHub(tester);
        await openMenu(tester);
        await tapOption(tester, topic.option);

        expect(analytics.tappedCalls, [
          RecordedHelpEvent(topic.option.id, 'hub', 'bubble'),
        ]);
        // Le texte du message ne passe JAMAIS par la mesure.
        expect(analytics.tappedCalls.single.toString(),
            isNot(contains('Bonjour')));
      });
    }

    testWidgets('compte suspendu : mêmes identifiants, aucun mot révélateur',
        (tester) async {
      await pumpHub(tester, country: 'Niger');
      await openMenu(tester);
      await tapOption(tester, EefBubbleOption.assistance);
      await openMenu(tester);
      await tapOption(tester, EefBubbleOption.question);

      expect(analytics.tappedCalls, [
        const RecordedHelpEvent('bubble_assistance', 'hub', 'bubble'),
        const RecordedHelpEvent('bubble_question', 'hub', 'bubble'),
      ]);
      final everything = [
        ...analytics.shownCalls,
        ...analytics.tappedCalls,
      ].map((e) => e.toString()).join(' ');
      expect(everything, isNot(contains('suspend')));
      expect(everything, isNot(contains('neutral')));
      expect(everything.toLowerCase(), isNot(contains('niger')));
    });

    testWidgets('fermer sans choisir ne mesure aucun `cta_tapped`',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      await tester.tapAt(const Offset(10, 20));
      await settleBounded(tester);
      expect(analytics.tappedCalls, isEmpty);
      expect(analytics.openedSurfaces, ['hub']);
    });

    // Le chemin RÉEL, sans le faux d'`EefHelpCard` : ce que `AnalyticsService`
    // émet, au nom et au paramètre près. C'est `eef_bubble_opened` qui nourrit le
    // taux d'ouverture (`eef_bubble_opened` ÷ `eef_help_card_shown`).
    group('l\'événement émis par le vrai service', () {
      setUp(EefHelpCard.resetForTest);

      test('`eef_bubble_opened` : ce nom et la seule clé `surface`', () {
        EefHelpCard.analytics.bubbleOpened(surface: 'catalog');
        expect(emitted.map((e) => e.name), ['eef_bubble_opened']);
        expect(emitted.single.params, {'surface': 'catalog'});
      });

      test('`eef_help_card_shown` / `eef_help_cta_tapped` : trois propriétés',
          () {
        EefHelpCard.analytics
            .shown(step: 'bubble', surface: 'hub', variant: 'bubble');
        EefHelpCard.analytics
            .tapped(step: 'bubble_question', surface: 'hub', variant: 'bubble');
        expect(emitted.map((e) => e.name),
            ['eef_help_card_shown', 'eef_help_cta_tapped']);
        for (final e in emitted) {
          expect(e.params.keys.toSet(), {'help_step', 'surface', 'variant'});
        }
      });

      testWidgets('de bout en bout : vue, ouverture, sujet, renvoi',
          (tester) async {
        await pumpCatalog(tester);
        await openMenu(tester);
        await tapOption(tester, EefBubbleOption.question);

        final mine = emitted
            .where((e) =>
                e.name == 'eef_bubble_opened' ||
                e.name == 'eef_help_cta_tapped' ||
                e.name == 'whatsapp_handoff' ||
                (e.name == 'eef_help_card_shown' &&
                    e.params['help_step'] == 'bubble'))
            .toList();
        expect(mine.map((e) => e.name), [
          'eef_help_card_shown',
          'eef_bubble_opened',
          'eef_help_cta_tapped',
          'whatsapp_handoff',
        ]);
        expect(mine[0].params,
            {'help_step': 'bubble', 'surface': 'catalog', 'variant': 'bubble'});
        expect(mine[1].params, {'surface': 'catalog'});
        expect(mine[2].params, {
          'help_step': 'bubble_question',
          'surface': 'catalog',
          'variant': 'bubble',
        });
        expect(mine[3].params['source'], 'eef_help_bubble_question');
        expect(mine[3].params['context_type'], 'eef_help');
      });
    });

    test('le contrat publié documente la bulle', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_bubble_opened`',
        '`bubble`',
        '`bubble_assistance`',
        '`bubble_dossier`',
        '`bubble_choose`',
        '`bubble_question`',
        '`eef_help_card_shown`',
        '`eef_help_cta_tapped`',
        'eef_help_bubble_',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. LES TEXTES
  // ═══════════════════════════════════════════════════════════════════════════

  group('les textes', () {
    final keys = AppTranslations().keys;
    Iterable<String> bubbleKeys(String locale) =>
        keys[locale]!.keys.where((k) => k.startsWith('eef_help_bubble_'));

    // La liste EXPLICITE : un préfixe seul ne verrait pas qu'une clé a été
    // retirée du dictionnaire.
    const expected = <String>[
      'eef_help_bubble_tooltip',
      'eef_help_bubble_hint',
      'eef_help_bubble_title',
      'eef_help_bubble_subtitle',
      'eef_help_bubble_place_hub',
      'eef_help_bubble_place_catalog',
      'eef_help_bubble_assistance_label',
      'eef_help_bubble_assistance_label_neutral',
      'eef_help_bubble_assistance_message',
      'eef_help_bubble_assistance_message_neutral',
      'eef_help_bubble_dossier_label',
      'eef_help_bubble_dossier_message',
      'eef_help_bubble_choose_label',
      'eef_help_bubble_choose_message',
      'eef_help_bubble_question_label',
      'eef_help_bubble_question_message',
      'eef_help_bubble_question_message_neutral',
      'eef_help_bubble_number',
      'eef_help_bubble_copy',
      'eef_help_bubble_copied',
      'eef_help_bubble_email',
    ];

    test('chaque clé existe en français ET en anglais, non vide', () {
      for (final locale in ['fr', 'en']) {
        for (final key in expected) {
          expect(keys[locale]![key], isNotNull,
              reason: '$key manque ($locale)');
          expect(keys[locale]![key]!.trim(), isNotEmpty, reason: key);
        }
      }
    });

    test('parité : exactement les mêmes clés `eef_help_bubble_*` en FR et EN',
        () {
      expect(bubbleKeys('fr').toSet(), bubbleKeys('en').toSet());
      expect(bubbleKeys('fr').toSet(), containsAll(expected));
    });

    test('FR et EN diffèrent (aucune traduction oubliée)', () {
      for (final key in expected) {
        // Les gabarits de lieu et de libellé « J'ai une autre question » ne
        // sont pas identiques non plus : aucune exception à ouvrir.
        expect(keys['en']![key], isNot(keys['fr']![key]), reason: key);
      }
    });

    test('les messages portent la place, et RIEN d\'autre à remplacer', () {
      for (final locale in ['fr', 'en']) {
        for (final key in [
          'eef_help_bubble_assistance_message',
          'eef_help_bubble_assistance_message_neutral',
          'eef_help_bubble_dossier_message',
          'eef_help_bubble_choose_message',
          'eef_help_bubble_question_message',
          'eef_help_bubble_question_message_neutral',
        ]) {
          final value = keys[locale]![key]!;
          expect(value, contains('@place'), reason: '$key ($locale)');
          expect(value.replaceAll('@place', ''), isNot(contains('@')),
              reason: '$key ($locale) : un second paramètre ?');
        }
        expect(keys[locale]!['eef_help_bubble_number'], contains('@number'));
      }
    });

    test('le jeu neutre ne parle jamais d\'ouvrir un dossier', () {
      for (final locale in ['fr', 'en']) {
        for (final key in [
          'eef_help_bubble_assistance_label_neutral',
          'eef_help_bubble_assistance_message_neutral',
          'eef_help_bubble_question_message_neutral',
          // Partagés avec le jeu standard et montrés aussi aux comptes suspendus.
          'eef_help_bubble_question_label',
          'eef_help_bubble_place_hub',
          'eef_help_bubble_place_catalog',
          'eef_help_bubble_title',
          'eef_help_bubble_subtitle',
          'eef_help_bubble_tooltip',
          'eef_help_bubble_hint',
        ]) {
          expect(_openAFileWording.hasMatch(keys[locale]![key]!), isFalse,
              reason: '$key ($locale) : ${keys[locale]![key]}');
        }
      }
    });

    // Même balayage que eef_help_line_test.dart:672-745 : aucune promesse, aucun
    // prix, aucun nom d'opérateur de l'État dans les textes de la bulle.
    test('aucun texte de la bulle ne promet, ne chiffre ni ne se déguise', () {
      final promise = RegExp(
        r'(admission|visa|bourse|scholarship)s?\s+(garanti|assur|certain|'
        r'guaranteed|assured|certain)|vous obtiendrez|tu obtiendras|'
        r'you will (get|obtain)|100\s?%',
        caseSensitive: false,
      );
      final price = RegExp(
        r'€|\bfcfa\b|\bxof\b|\bfrancs?\b|\bprix\b|\bprice\b|gratuit|\bfree\b|'
        r'\beuros?\b|\btarif',
        caseSensitive: false,
      );
      final operator = RegExp(r'campus[\s_-]*france', caseSensitive: false);
      for (final locale in ['fr', 'en']) {
        for (final key in expected) {
          final value = keys[locale]![key]!;
          expect(promise.hasMatch(value), isFalse, reason: '$key ($locale)');
          expect(price.hasMatch(value), isFalse, reason: '$key ($locale)');
          expect(operator.hasMatch(value), isFalse,
              reason: '$key ($locale) nomme l\'opérateur de l\'État');
        }
      }
    });

    test('l\'enseigne ne dit pas « Campus France » (titres et libellés)', () {
      for (final locale in ['fr', 'en']) {
        for (final key in expected.where((k) =>
            k.endsWith('_label') ||
            k.endsWith('_label_neutral') ||
            k.endsWith('_title') ||
            k.endsWith('_tooltip'))) {
          expect(keys[locale]![key]!.toLowerCase(),
              isNot(contains('campus france')));
        }
      }
    });

    test('le français est accentué, aussi dans le menu (pas de « Ecrire »)',
        () {
      final fr = keys['fr']!;
      expect(fr['eef_help_bubble_title'], contains('Écrire'));
      expect(fr['eef_help_bubble_assistance_message'], contains('équipe'));
      expect(fr['eef_help_bubble_place_hub'], contains('Études'));
      expect(fr['eef_help_bubble_choose_label'], contains('formation'));
    });

    test('les tuiles ne sont écrites nulle part en dur dans le widget', () {
      final source =
          File('lib/app/features/etudes_en_france/eef_help_bubble.dart')
              .readAsStringSync();
      expect(source, isNot(contains('Bonjour')));
      expect(source, isNot(contains('Hello')));
      expect(source, isNot(contains('Écrire')));
    });

    test('aucune dépendance native ni Flutter n\'a été ajoutée', () {
      // Le widget n'importe que ce que le dépôt a déjà.
      final source =
          File('lib/app/features/etudes_en_france/eef_help_bubble.dart')
              .readAsStringSync();
      final imports = RegExp(r"^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();
      for (final import in imports) {
        expect(
          import.startsWith('dart:') ||
              import.startsWith('package:flutter/') ||
              import.startsWith('package:get/') ||
              import.startsWith('../') ||
              import.startsWith('eef_'),
          isTrue,
          reason: 'import inattendu : $import',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. LA GÉOMÉTRIE
  // ═══════════════════════════════════════════════════════════════════════════

  group('la marge basse des listes', () {
    double bottomPadding(WidgetTester tester, {required bool first}) {
      final list = tester.widget<ListView>(
        first ? find.byType(ListView).first : find.byType(ListView).last,
      );
      return (list.padding! as EdgeInsets).bottom;
    }

    testWidgets('hub : 32 dp sans bulle, 104 dp avec', (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpHub(tester);
      expect(bottomPadding(tester, first: true), 32);

      AppConfig.eefHelpBubbleEnabledOverride = true;
      await pumpHub(tester);
      expect(bottomPadding(tester, first: true), 104);
    });

    testWidgets('catalogue (liste) : 32 dp sans bulle, 104 dp avec',
        (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpCatalog(tester);
      expect(bottomPadding(tester, first: false), 32);

      AppConfig.eefHelpBubbleEnabledOverride = true;
      await pumpCatalog(tester);
      expect(bottomPadding(tester, first: false), 104);
    });

    testWidgets('catalogue (vide) : 32 dp sans bulle, 104 dp avec',
        (tester) async {
      stubCatalog((_) async => _page(const [], catalogPublished: true));
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpCatalog(tester);
      expect(find.text('Aucune formation ne correspond'), findsWidgets);
      expect(bottomPadding(tester, first: false), 32);

      AppConfig.eefHelpBubbleEnabledOverride = true;
      await pumpCatalog(tester);
      expect(bottomPadding(tester, first: false), 104);
    });

    testWidgets('catalogue (rien de publié) : 104 dp avec la bulle',
        (tester) async {
      stubCatalog((_) async => _page(const [], catalogPublished: false));
      await pumpCatalog(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
      expect(bottomPadding(tester, first: false), 104);
    });

    testWidgets('clavier ouvert : la bulle part, la marge redevient 32',
        (tester) async {
      await pumpCatalog(
        tester,
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      expect(find.byKey(_bubbleKey), findsNothing);
      expect(bottomPadding(tester, first: false), 32);
    });
  });

  group('la bulle ne recouvre rien d\'utile', () {
    for (final viewport in _matrixViewports) {
      for (final scale in [1.0, 1.3]) {
        for (final locale in [const Locale('fr'), const Locale('en')]) {
          for (final country in ['Sénégal', 'Niger']) {
            final label = '${viewport.id} ×$scale ${locale.languageCode} '
                '$country';

            testWidgets('hub — $label', (tester) async {
              final report = await pumpHub(
                tester,
                viewport: viewport,
                textScale: scale,
                locale: locale,
                country: country,
              );
              expect(find.byKey(_bubbleKey), findsOneWidget);
              expect(report.otherErrors, isEmpty, reason: '$report');

              await scrollToEnd(tester);
              final bubble = tester.getRect(find.byKey(_bubbleKey));
              final last = tester.getRect(find.byType(EefAffiliationNotice));

              expect(bubble.size, const Size(56, 56));
              expect(
                Offset.zero & viewport.size,
                predicate<Rect>((screen) =>
                    screen.contains(bubble.topLeft) &&
                    screen.contains(bubble.bottomRight)),
                reason: 'la bulle sort de l\'écran : $bubble',
              );
              expect(bubble.overlaps(last), isFalse,
                  reason: 'la bulle $bubble recouvre la dernière carte $last');
            });

            testWidgets('catalogue — $label', (tester) async {
              final report = await pumpCatalog(
                tester,
                viewport: viewport,
                textScale: scale,
                locale: locale,
                country: country,
              );
              expect(report.otherErrors, isEmpty, reason: '$report');

              await scrollToEnd(tester);
              final sources = tester.getRect(find.byType(EefSourcesRow));
              final results = tester.getRect(find.byType(ListView).last);

              // DÉFAUT ANTÉRIEUR À LA BULLE, mesuré : à 320×568 et ×1,3, le champ
              // de recherche, les filtres et la mise en garde de suspension
              // (compte du Niger) occupent TOUT l'écran, et la liste des
              // résultats tient dans 11 dp de haut (505 à 516), avec ou sans
              // bulle. Il n'y a alors ni « dernière carte » à protéger ni place
              // pour un cercle de 56 dp : rognée par le `Stack`, la bulle ne se
              // laisserait plus toucher. Elle est donc RETIRÉE sous 88 dp de
              // liste — et SEULEMENT alors : ni une bulle fantôme, ni une bulle
              // absente quand il y a la place.
              final fits = results.height >= EefHelpBubble.minHostHeight;
              expect(
                  find.byKey(_bubbleKey), fits ? findsOneWidget : findsNothing,
                  reason: 'liste de ${results.height} dp');
              if (!fits) return;

              // Elle se laisse TOUCHER : un tap ouvre bien la feuille.
              expect(find.byKey(_bubbleKey).hitTestable(), findsOneWidget,
                  reason: 'la bulle est rognée ou recouverte');
              final bubble = tester.getRect(find.byKey(_bubbleKey));
              final last = tester.getRect(find.byType(EefDataNotice).last);

              expect(bubble.size, const Size(56, 56));
              expect(bubble.overlaps(sources), isFalse,
                  reason: 'la bulle $bubble recouvre les sources $sources');
              expect(bubble.overlaps(last), isFalse,
                  reason: 'la bulle $bubble recouvre la dernière carte $last');
              // La rangée des sources n'a PAS bougé : bas de l'écran, 48 dp au
              // moins, bulle au-dessus.
              expect(sources.height, greaterThanOrEqualTo(48));
              expect(bubble.bottom, lessThanOrEqualTo(sources.top));
              // 16 dp du bord droit.
              expect(viewport.size.width - bubble.right, 16);
              expect(sources.top - bubble.bottom, 16);
            });
          }
        }
      }
    }

    // L'état d'ÉCHEC rend un `KpbErrorState` (colonne centrée, bouton
    // « Réessayer » pleine largeur) : sans la marge basse de la bulle et sans
    // défilement, la bulle recouvrait le bouton (et parfois le texte) sur les
    // petits écrans — l'extrémité droite du bouton ouvrait le menu au lieu de
    // relancer.
    for (final viewport in _matrixViewports) {
      for (final scale in [1.0, 1.3]) {
        for (final country in ['Sénégal', 'Niger']) {
          testWidgets('catalogue en panne — ${viewport.id} ×$scale $country',
              (tester) async {
            stubCatalog(
                (_) async => throw _dio(DioExceptionType.connectionError));
            final report = await pumpCatalog(
              tester,
              viewport: viewport,
              textScale: scale,
              country: country,
            );
            expect(report.otherErrors, isEmpty, reason: '$report');
            expect(find.text('Réessayer'), findsOneWidget);

            await scrollToEnd(tester);
            final results = tester.getRect(find.byType(ListView).last);
            final fits = results.height >= EefHelpBubble.minHostHeight;
            expect(find.byKey(_bubbleKey), fits ? findsOneWidget : findsNothing,
                reason: 'liste de ${results.height} dp');
            if (!fits) return;

            expect(find.byKey(_bubbleKey).hitTestable(), findsOneWidget);
            final bubble = tester.getRect(find.byKey(_bubbleKey));
            final retry = tester.getRect(find.byWidgetPredicate(
                (w) => w is FilledButton && w.onPressed != null));
            final state = tester.getRect(find.byType(KpbErrorState));
            final sources = tester.getRect(find.byType(EefSourcesRow));
            expect(bubble.overlaps(retry), isFalse,
                reason: 'la bulle $bubble recouvre « Réessayer » $retry');
            expect(bubble.overlaps(state), isFalse,
                reason: 'la bulle $bubble recouvre l\'état d\'échec $state');
            expect(bubble.overlaps(sources), isFalse);
          });
        }
      }
    }

    testWidgets('catalogue en panne : « Réessayer » relance, la bulle reste',
        (tester) async {
      var calls = 0;
      stubCatalog((_) async {
        calls++;
        if (calls == 1) throw _dio(DioExceptionType.connectionError);
        return _page([_program('a')]);
      });
      await pumpCatalog(tester);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byKey(_bubbleKey), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await settleBounded(tester);
      expect(find.text('Licence Droit'), findsWidgets);
      expect(find.byKey(_bubbleKey), findsOneWidget);
    });

    testWidgets('catalogue vide : la dernière mention n\'est pas recouverte',
        (tester) async {
      stubCatalog((_) async => _page(const [], catalogPublished: true));
      await pumpCatalog(tester, viewport: _se, textScale: 1.3);
      await scrollToEnd(tester);

      final bubble = tester.getRect(find.byKey(_bubbleKey));
      final last = tester.getRect(find.byType(EefDataNotice).last);
      final sources = tester.getRect(find.byType(EefSourcesRow));
      expect(bubble.overlaps(last), isFalse, reason: '$bubble / $last');
      expect(bubble.overlaps(sources), isFalse);
    });
  });

  group('la feuille tient sur un petit téléphone', () {
    for (final viewport in [_se, _android640]) {
      for (final locale in [const Locale('fr'), const Locale('en')]) {
        for (final country in ['Sénégal', 'Niger']) {
          testWidgets(
              '${viewport.id} ×1.3 ${locale.languageCode} $country : '
              'défile, ne déborde pas, ne tronque rien', (tester) async {
            await pumpHub(
              tester,
              viewport: viewport,
              textScale: 1.3,
              locale: locale,
              country: country,
            );
            await openMenu(tester);

            expect(find.byKey(_sheetKey), findsOneWidget);
            expect(tester.takeException(), isNull);

            // Atteindre le pied : tout est accessible par le défilement.
            final number = AppConfig.whatsappNumber.trim();
            await tester.ensureVisible(find.textContaining(number));
            await tester.pump();
            await tester.ensureVisible(
              find.byKey(const ValueKey('eef-help-bubble-copy')),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);

            final sheetTexts = <String>[];
            for (final element in find
                .descendant(
                    of: find.byKey(_sheetKey), matching: find.byType(RichText))
                .evaluate()) {
              final render = element.renderObject;
              if (render is RenderParagraph && render.didExceedMaxLines) {
                sheetTexts.add(render.text.toPlainText());
              }
            }
            expect(sheetTexts, isEmpty,
                reason: 'texte tronqué dans la feuille : $sheetTexts');

            for (final option in EefBubbleMessages.optionsFor(
                suspended: country == 'Niger')) {
              await tester.ensureVisible(_option(option));
              await tester.pump();
              expect(tester.getSize(_option(option)).height,
                  greaterThanOrEqualTo(56));
              // La tuile tient dans la largeur de l'écran.
              final rect = tester.getRect(_option(option));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(viewport.size.width));
            }
          });
        }
      }
    }

    testWidgets('iPad : la feuille est bornée à 560 dp', (tester) async {
      await pumpHub(tester, viewport: _ipad);
      await openMenu(tester);
      final width = tester.getSize(find.byKey(_sheetKey)).width;
      expect(width, lessThanOrEqualTo(560));
    });
  });

  group('la bulle entre les écrans', () {
    testWidgets('aucun libellé brut sur le hub ni sur le catalogue',
        (tester) async {
      for (final locale in [const Locale('fr'), const Locale('en')]) {
        await pumpHub(tester, locale: locale);
        await openMenu(tester);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
        await pumpCatalog(tester, locale: locale);
        await openMenu(tester);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      }
    });

    testWidgets('le catalogue en panne garde sa bulle (le conseiller aide)',
        (tester) async {
      stubCatalog((_) async => throw _dio(DioExceptionType.connectionError));
      await pumpCatalog(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
      expect(find.byType(EefSourcesRow), findsOneWidget);
    });
  });
}
