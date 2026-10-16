// Le harnais d'écrans réels : monte un écran dans le MÊME emballage que la
// production, à des dimensions de vrai téléphone, en français.
//
// Il n'invente rien. Il EXTRAIT ce qui dormait déjà dans
// test/goldens/review_captures_test.dart (`_app()` = GetMaterialApp +
// AppTheme.buildTheme() + AppTranslations() + Locale('fr'), `setViewport()`,
// `_seedController()`, un `pumpAndSettle` borné) — un fichier tagué `golden`,
// donc exclu de la CI, et qui ne contient pas un seul `expect`. La machinerie
// existait ; ce qui manquait, c'était une assertion.
//
// Quatre choses que ce harnais fait et que `pumpTestApp` ne fait pas :
//
//  1. LES TRADUCTIONS. `TestAppWrapper` (test/widget_test_helpers.dart:116-122)
//     ne passe ni `translations:` ni `locale:`. GetX rend alors la clé brute
//     pour chaque `.tr` (get-4.7.3 internacionalization.dart:88 : `if
//     (Get.locale?.languageCode == null) return this;`). Une trentaine de tests
//     du dépôt s'appuient sur ce comportement et affirment `find.text('nav_cases')`.
//     On ne touche donc PAS à `pumpTestApp` : on monte un second harnais, celui
//     qui parle français. C'est la seule façon d'ajouter l'assertion « aucune clé
//     brute à l'écran » sans réécrire 82 assertions à la veille d'une livraison.
//
//  2. LA TAILLE. Douze fichiers de test posent un viewport de 1080 à 1440 points
//     de large — ce qui n'est pas un téléphone, et fait disparaître les
//     débordements au lieu de les mesurer. Ici : 393×852 et 360×800.
//
//  3. LES ENCOCHES. Une barre de statut et une barre de gestes ne sont pas de la
//     décoration : elles retirent 81 points de hauteur utile sur un iPhone 14.
//     `pumpTestApp` les met à zéro.
//
//  4. LE CLAMP DE POLICE. La production borne l'échelle de texte de l'OS à
//     [1,0 ; 1,5] (le `builder:` de lib/main.dart). Un harnais qui rend tout à 1,0 ne voit
//     jamais ce que voit un parent de 55 ans qui a grossi la police de son
//     téléphone — c'est-à-dire une bonne partie du public de cette app.
//
// Et une chose qu'il refuse de faire : avaler une exception. Le `catch (_)` de
// review_captures_test.dart:64-68 attrapait TOUT pour survivre aux animations en
// boucle. Ici, seul le dépassement de délai de `pumpAndSettle` est toléré ; le
// reste remonte.

import 'dart:io';

import 'package:flutter/material.dart';
// `rendering.dart` pour `RenderParagraph` : material ne le réexporte pas, et
// c'est lui qui porte `didExceedMaxLines`, le seul signal de troncature.
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_theme.dart';

import '../widget_test_helpers.dart';

/// Un vrai téléphone : sa taille logique ET ses encoches.
class KpbViewport {
  const KpbViewport({
    required this.id,
    required this.name,
    required this.size,
    required this.padding,
  });

  /// Identifiant court et stable — il entre dans les clés du budget, donc il ne
  /// doit pas changer quand on reformule [name].
  final String id;

  final String name;
  final Size size;

  /// Ce que l'OS retire : barre de statut en haut, barre de gestes en bas.
  final EdgeInsets padding;

  @override
  String toString() => name;
}

/// iPhone 14 — la géométrie de référence de l'App Store, et celle que
/// `test/features/home_screen_test.dart:26` utilise déjà.
/// 47 pt de barre de statut (Dynamic Island), 34 pt de barre de gestes.
const iphone14 = KpbViewport(
  id: 'iphone14',
  name: 'iPhone 14 393×852',
  size: Size(393, 852),
  padding: EdgeInsets.only(top: 47, bottom: 34),
);

/// Android d'entrée de gamme — le téléphone réel d'une bonne partie du public
/// KPB, et le viewport le plus serré du dépôt (`a11y_scale_test.dart:78`).
/// 24 pt de barre de statut, pas de barre de gestes (navigation matérielle).
const compactAndroid = KpbViewport(
  id: 'android360',
  name: 'Android compact 360×800',
  size: Size(360, 800),
  padding: EdgeInsets.only(top: 24),
);

const kpbPhoneViewports = <KpbViewport>[iphone14, compactAndroid];

/// Les bornes du clamp de `lib/main.dart:257-260`, recopiées ici.
///
/// Recopiées et non lues : le `builder:` de GetMaterialApp est une fermeture
/// privée de `main.dart`, inatteignable depuis un test. La duplication est donc
/// inévitable — mais elle est SURVEILLÉE : `screen_matrix_test.dart` relit
/// `lib/main.dart` et échoue si ces deux nombres n'y correspondent plus. Une
/// constante dupliquée sans garde est une bombe à retardement ; avec garde, c'est
/// juste une constante.
const kpbMinTextScale = 1.0;
const kpbMaxTextScale = 1.5;

/// Les échelles de texte à éprouver. 1,0 est le défaut ; 1,5 est le plafond de
/// l'app depuis la build 57 (1,3 avant, gardé comme cran intermédiaire) ; 1,1
/// est le cran qui casse en premier (les cartes de destination
/// débordent de 3 px à 1,1, de 19 px à 1,3 — c'est à 1,1 que le défaut naît).
const kpbTextScales = <double>[1.0, 1.1, 1.3, 1.5];

/// L'échelle telle que la production la calcule : la demande de l'OS, bornée.
TextScaler kpbClampedScaler(double requested) =>
    TextScaler.linear(requested).clamp(
      minScaleFactor: kpbMinTextScale,
      maxScaleFactor: kpbMaxTextScale,
    );

/// Monte [screen] dans l'emballage de production.
///
/// [inDrawerShell] reproduit la géométrie qui compte pour les écrans d'onglet :
/// `AppShell` donne un `drawer:` à SON Scaffold (app_shell.dart:73-77), et c'est
/// ce détail qui faisait qu'un `AppBar` descendant fabriquait un second
/// `DrawerButton` invisible de 56 pt — la cause de la troncature du « Salut, … »
/// restée cachée pendant toute une tournée de revue, parce que les captures
/// étaient prises sans drawer.
///
/// [ownsScaffold] : la plupart des écrans construisent leur propre `Scaffold`
/// (les 8 outils du tiroir, France, Logement, Profil, Universités, Bourses).
/// Trois ne le font pas et ont besoin d'un Scaffold ambiant : HomeScreen,
/// CasesScreen et le prompt invité. Passez `false` pour ceux-là.
///
/// [themeMode] et [locale] valent clair et français par défaut — l'emballage de
/// production. Un test qui éprouve le thème sombre ou l'anglais les passe
/// explicitement ; les ~20 fichiers existants n'ont rien à changer.
///
/// [viewInsets] est ce que le clavier retire : un écran à champ de saisie doit
/// tenir quand il monte, et le harnais ne le simulait pas.
///
/// [disableAnimations] reproduit le réglage « réduire les animations » de l'OS
/// (`MediaQuery.disableAnimationsOf`). Il vaut faux par défaut : les fichiers
/// existants n'ont rien à changer.
///
/// [routesShareMediaQuery] étend la taille, les encoches, le clavier ET le clamp
/// de police aux routes modales (feuilles, boîtes) poussées sur l'écran — comme
/// en production. Voir le commentaire du `builder:` plus bas.
Future<KpbScreenReport> pumpKpbScreen(
  WidgetTester tester, {
  required Widget screen,
  required KpbViewport viewport,
  double textScale = 1.0,
  bool inDrawerShell = false,
  bool ownsScaffold = true,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('fr'),
  EdgeInsets viewInsets = EdgeInsets.zero,
  bool routesShareMediaQuery = false,
  bool disableAnimations = false,
}) async {
  final mediaQuery = MediaQueryData(
    size: viewport.size,
    padding: viewport.padding,
    viewInsets: viewInsets,
    textScaler: kpbClampedScaler(textScale),
    // « Réduire les animations » de l'OS : faux par défaut, comme avant.
    disableAnimations: disableAnimations,
  );
  await tester.binding.setSurfaceSize(viewport.size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // ARBRE NEUF À CHAQUE CAS. Repomper un GetMaterialApp par-dessus un autre MET À
  // JOUR l'élément existant : les States des écrans survivent, avec leurs images
  // déjà résolues et leurs contrôleurs déjà initialisés. Mesuré : l'écran
  // d'entrée débordait ou non selon sa POSITION dans la boucle — un harnais dont
  // le verdict dépend de l'ordre des cas ne vaut rien.
  //
  // Démonter d'abord, puis remonter, rend chaque cas indépendant.
  await tester.pumpWidget(const SizedBox.shrink());

  // Les traductions et la locale sont (RE)POSÉES ICI, explicitement, à chaque
  // montage. Deux raisons, toutes deux mesurées :
  //
  //  · `Get.reset()` appelle `clearTranslations()` (get-4.7.3
  //    get_common/get_reset.dart) — un test qui remet GetX à zéro entre deux cas
  //    vide donc le dictionnaire ;
  //  · et le `translations:` de GetMaterialApp n'est consommé qu'au premier
  //    montage : repomper un GetMaterialApp par-dessus un autre met à jour
  //    l'élément existant, sans repasser par son initState.
  //
  // Combinés, ces deux faits donnaient un premier cas correct puis cinq cas où
  // CHAQUE `.tr` rendait sa clé brute — 30 clés listées sur l'accueil. Le test
  // aurait accusé l'app d'un défaut qui appartenait au harnais. (Effet de bord
  // utile : c'est cette panne qui a prouvé que l'assertion « aucune clé brute »
  // sait mordre.)
  Get.addTranslations(AppTranslations().keys);
  Get.locale = locale;
  Get.fallbackLocale = const Locale('fr');

  // Un Scaffold est ajouté quand l'écran n'en a pas, ou quand on veut la
  // géométrie du shell (un Scaffold qui POSSÈDE un drawer). Dans le second cas
  // l'imbrication est voulue : c'est celle de la production.
  Widget body = screen;
  if (!ownsScaffold || inDrawerShell) {
    body = Scaffold(
      drawer: inDrawerShell ? const Drawer() : null,
      body: screen,
    );
  }

  // On collecte TOUTES les erreurs de rendu, au lieu de laisser le binding n'en
  // garder qu'une. `tester.takeException()` rend « Multiple exceptions (11) were
  // detected » dès qu'il y en a plusieurs — mesuré sur l'écran Logement : onze
  // erreurs, et le message n'en nomme aucune. Un rapport qui cache ce qu'il a
  // trouvé ne sert à rien.
  final collected = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = collected.add;
  try {
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        // L'emballage de production, ligne pour ligne (lib/main.dart:229-245).
        translations: AppTranslations(),
        locale: locale,
        fallbackLocale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        // Sans ces délégués, Material rend ses propres libellés en anglais et
        // avertit « This application's locale, fr, is not supported by all of
        // its localization delegates » — le harnais mesurerait alors un écran
        // que la production ne sert jamais.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.buildTheme(),
        // Le thème sombre existe dans le dépôt sans être branché sur `main.dart`
        // (light-only) : on le passe tout de même pour qu'un écran qui lit ses
        // couleurs dans le thème soit éprouvé dans les deux.
        darkTheme: AppTheme.buildDarkTheme(),
        themeMode: themeMode,
        // `navigatorObservers` et `getPages` sont volontairement omis : le
        // premier atteint Firebase, le second n'a pas de sens pour un écran monté
        // seul.
        // En production, le clamp de police vit dans le `builder:` de
        // GetMaterialApp, AU-DESSUS du Navigator : une feuille, une boîte de
        // dialogue ou un snackbar le voient donc. Le `MediaQuery` de `home:`
        // ci-dessous, lui, ne couvre que l'écran — une feuille modale poussée
        // dessus reprend alors la taille, la police (1,0) et les encoches de la
        // VUE de test, pas celles du téléphone éprouvé. Un test de feuille doit
        // passer [routesShareMediaQuery] : sinon son « ×1,5 » ne mesure que
        // l'écran, et la feuille est mesurée à 1,0.
        //
        // Désactivé par défaut : les ~20 fichiers existants ont des feuilles et
        // des boîtes dont les seuils ont été posés sans cette couverture.
        builder: routesShareMediaQuery
            ? (context, child) => MediaQuery(
                  data: mediaQuery,
                  child: child ?? const SizedBox.shrink(),
                )
            : null,
        home: MediaQuery(
          // Le clamp de main.dart:256-266, appliqué ici parce que le `builder:`
          // de GetMaterialApp s'exécute AU-DESSUS de ce MediaQuery et clamperait
          // l'échelle de la vue (1,0), pas celle qu'on veut éprouver.
          data: mediaQuery,
          child: body,
        ),
      ),
    );
    await settleBounded(tester);

    // LES IMAGES SONT CHARGÉES AVANT DE MESURER.
    //
    // Dans un test widget, un `Image.asset` n'a aucune taille au premier cadre :
    // le décodage est asynchrone et le binding de test ne le fait pas
    // spontanément. Un écran mesuré ainsi l'est SANS son logo — c'est-à-dire pas
    // l'écran que voit l'utilisateur.
    //
    // Ça n'est pas théorique : l'écran d'entrée (AuthWelcomeScreen, logo KPB en
    // pleine largeur) débordait ou non selon que le décodage avait eu lieu ou pas
    // dans un cas précédent, via le cache d'images global au fichier de test.
    // review_captures_test.dart:200-204 précharge à la main, écran par écran ; ici
    // on le fait pour toutes les images RÉELLEMENT présentes dans l'arbre, donc
    // sans liste à maintenir.
    final providers = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .toSet();
    if (providers.isNotEmpty) {
      final context = tester.element(find.byType(MediaQuery).first);
      await tester.runAsync(() async {
        for (final provider in providers) {
          await precacheImage(provider, context);
        }
      });
      await tester.pump();
      await settleBounded(tester);
    }
  } finally {
    FlutterError.onError = previousOnError;
  }

  return KpbScreenReport(
    viewport: viewport,
    textScale: textScale,
    errors: collected
        .map((details) => details.exceptionAsString().split('\n').first.trim())
        .toList(growable: false),
  );
}

/// Ce que le rendu d'un écran a produit : les débordements d'un côté, le reste
/// des erreurs de l'autre. Les séparer est utile parce qu'ils se corrigent
/// différemment — un débordement est une question de mise en page, une
/// `LocaleDataException` est une question de harnais.
class KpbScreenReport {
  const KpbScreenReport({
    required this.viewport,
    required this.textScale,
    required this.errors,
  });

  final KpbViewport viewport;
  final double textScale;

  /// Tous les messages d'erreur, première ligne, dans l'ordre d'apparition.
  final List<String> errors;

  static final _overflow = RegExp(r'overflowed by ([0-9.]+) pixels');

  List<String> get overflows =>
      errors.where(_overflow.hasMatch).toList(growable: false);

  List<String> get otherErrors =>
      errors.where((e) => !_overflow.hasMatch(e)).toList(growable: false);

  /// Le total de pixels débordés — un nombre stable à mettre au budget, qui
  /// bouge dès qu'une mise en page change.
  double get overflowPixels => overflows.fold(0, (sum, message) {
        final match = _overflow.firstMatch(message);
        return sum + (double.tryParse(match?.group(1) ?? '') ?? 0);
      });

  String get label => '$viewport ×$textScale';

  @override
  String toString() => overflows.isEmpty && otherErrors.isEmpty
      ? '$label : ok'
      : '$label : ${overflows.length} débordement(s) '
          '(${overflowPixels.toStringAsFixed(1)} px)'
          '${otherErrors.isEmpty ? '' : ', ${otherErrors.length} autre(s) erreur(s)'}';
}

/// Les textes que la mise en page a VISUELLEMENT TRONQUÉS — coupés par un
/// ellipsis ou débordant leur `maxLines`.
///
/// Le troisième mensonge de mise en page, après le viewport trop large et la
/// police Ahem, et le plus discret des trois : un débordement lève une exception,
/// une troncature ne fait rien. `tester.takeException()` n'en voit rien, la
/// matrice d'écrans non plus. Un prix coupé à « 12 990 €/an · ≈ 8 5… » est
/// pourtant exactement le genre d'information à moitié dite que ce chantier
/// existe pour supprimer.
///
/// Rend le texte en clair de chaque paragraphe tronqué. Les widgets `Text`
/// construisent un `RichText` en interne, donc chercher `RichText` couvre les
/// deux.
List<String> truncatedTexts(WidgetTester tester) {
  final out = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph && renderObject.didExceedMaxLines) {
      out.add(renderObject.text.toPlainText());
    }
  }
  return out;
}

/// `pumpAndSettle` borné — qui tolère UNIQUEMENT son propre dépassement de délai.
///
/// Plusieurs écrans portent une animation en boucle (shimmer de chargement,
/// points de saisie du coach, Lottie) : `pumpAndSettle` ne converge jamais et
/// lève « pumpAndSettle timed out ». C'est le seul cas légitime à absorber, et on
/// borne alors à la main.
///
/// Le `catch (_)` d'origine attrapait aussi les débordements, les
/// `MissingStubError` et les erreurs de rendu — c'est-à-dire exactement ce que ce
/// harnais existe pour voir.
Future<void> settleBounded(
  WidgetTester tester, {
  Duration limit = const Duration(seconds: 4),
  int manualFrames = 12,
}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      limit,
    );
  } on FlutterError catch (error) {
    if (!error.toString().contains('pumpAndSettle timed out')) rethrow;
    for (var i = 0; i < manualFrames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// Un AppController hydraté et enregistré, comme `_seedController` du fichier de
/// captures.
///
/// [fullName] par défaut est un prénom ouest-africain long : c'est le public de
/// cette app, et c'est la longueur qui révèle les troncatures. Un « Test User »
/// de 9 caractères ne prouve rien.
Future<AppController> seedKpbController({
  AppSnapshot? snapshot,
  MockApiClient? apiClient,
  String fullName = 'Mouhamadou Diallo',
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final controller = AppController(
    repository: FakeRepository(
      snapshot: snapshot ??
          AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(fullName: fullName),
          ),
    ),
    apiClient: apiClient ?? MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-contrôle n°1 : la sentinelle de police
// ─────────────────────────────────────────────────────────────────────────────

/// La chaîne témoin, tirée de l'app (`universities_screen.dart`).
const kpbFontSentinelText = 'Voir toutes les universités';
const kpbFontSentinelSize = 14.0;

/// La largeur peinte de [kpbFontSentinelText] à [kpbFontSentinelSize], dans la
/// police réellement chargée.
///
/// À quoi ça sert : si `test/flutter_test_config.dart` cesse de charger Inter,
/// Flutter retombe sur **Ahem**, dont chaque glyphe est un carré du cadratin. La
/// chaîne mesurerait alors 27 × 14 = 378 px au lieu de ~175, et TOUTE assertion
/// de largeur, de troncature ou de débordement du dépôt mesurerait autre chose
/// que l'app — en restant verte.
Future<double> measureFontSentinel(WidgetTester tester) async {
  await tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          kpbFontSentinelText,
          textDirection: TextDirection.ltr,
          style: TextStyle(fontFamily: 'Inter', fontSize: kpbFontSentinelSize),
        ),
      ),
    ),
  );
  return tester.getSize(find.text(kpbFontSentinelText)).width;
}

/// La largeur qu'Ahem produirait : un carré du cadratin par caractère.
final kpbAhemSentinelWidth = kpbFontSentinelText.length * kpbFontSentinelSize;

// ─────────────────────────────────────────────────────────────────────────────
// Auto-contrôle n°2 : le canari
// ─────────────────────────────────────────────────────────────────────────────

/// Un `Column` volontairement 10 px trop haut pour son cadre.
///
/// Il DOIT faire remonter « A RenderFlex overflowed by 10 pixels ». Si le canari
/// se tait, le mécanisme d'assertion est mort et tous les écrans « sans
/// débordement » du fichier ne veulent plus rien dire — c'est arrivé assez
/// souvent sur ce projet pour qu'on paie ce coût.
class KpbOverflowCanary extends StatelessWidget {
  const KpbOverflowCanary({super.key, this.overflowBy = 10});

  final double overflowBy;

  @override
  Widget build(BuildContext context) {
    const boxHeight = 60.0;
    return Center(
      child: SizedBox(
        height: boxHeight,
        width: 200,
        child: Column(
          children: [
            SizedBox(height: boxHeight / 2),
            SizedBox(height: boxHeight / 2 + overflowBy),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Le clamp, surveillé
// ─────────────────────────────────────────────────────────────────────────────

/// Relit `lib/main.dart` et rend les bornes du clamp qui y sont écrites.
///
/// Rend `null` si le motif n'y est plus — ce qui doit faire échouer le test
/// appelant, et non passer silencieusement : un clamp introuvable veut dire que
/// la production a changé de mécanisme et que ce harnais mesure une géométrie qui
/// n'existe plus.
({double min, double max})? readMainDartTextScaleClamp() {
  final file = File('lib/main.dart');
  if (!file.existsSync()) return null;
  final source = file.readAsStringSync();
  final match = RegExp(
    r'minScaleFactor:\s*([0-9.]+)\s*,\s*maxScaleFactor:\s*([0-9.]+)',
  ).firstMatch(source);
  if (match == null) return null;
  final min = double.tryParse(match.group(1)!);
  final max = double.tryParse(match.group(2)!);
  if (min == null || max == null) return null;
  return (min: min, max: max);
}
