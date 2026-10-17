// M1 — les quatre outils IA ne doivent apparaître NULLE PART tant que
// `AppConfig.aiToolsEnabled` est faux.
//
// ## Ce que ce masquage retire, et pourquoi il fallait le mesurer
//
// Motif historique (lot 7) : le consentement promettait « jamais ton nom »
// pendant que le serveur recopiait `Nom : ${dto.name}` vers Groq, sans garde.
// Lot 11 a fermé la fuite côté serveur (`AiConsentGuard` + invites sans nom).
// Le masque reste jusqu'au déploiement couplé avec la build 49 : basculer
// le drapeau pendant que la 48 tape encore la prod ferait 403 les testeurs.
//
// ## Pourquoi ce fichier tient à DEUX assertions et pas une
//
// Un test qui monterait seulement le tiroir passerait au vert avec six chemins
// encore ouverts. C'est exactement le motif PARC-05 de ce dépôt — dix-huit
// points d'entrée, une garde posée sur un seul — et le rejouer ici aurait laissé
// l'illégalité en place SOUS un test vert, ce qui est pire que pas de test.
//
//   (a) L'INVENTAIRE STATIQUE fige les dix appels et leur répartition. Un
//       onzième appelant, ou un cinquième fichier hôte, fait rougir — même si
//       personne ne pense à écrire un test de rendu pour lui.
//   (b) LES TESTS DE RENDU montent les quatre fichiers hôtes, drapeau à faux, et
//       exigent qu'aucune des quatre tuiles n'existe. C'est ce volet-là qui
//       attrape le cas que l'inventaire ne voit pas : un appel DÉPLACÉ hors du
//       bloc gardé, à compte constant.
//
// Et la CONTRE-ÉPREUVE, drapeau à vrai : les dix entrées reviennent. Sans elle,
// un écran cassé — un `build` qui lève, une liste vide pour une autre raison —
// donnerait les mêmes verts que le masquage.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/ai_advisor/ai_chat_screen.dart';
import 'package:karatou/app/features/assist_bridge/assist_bridge_sheet.dart';
import 'package:karatou/app/features/cases/case_detail_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';
import 'package:karatou/app/features/shell/kpb_tools_drawer.dart';
import 'package:karatou/app/features/tools/motivation_letters_screen.dart';
import 'package:karatou/app/features/tools/student_tools_screen.dart';

import '../widget_test_helpers.dart';
import '../support/eef_tour_fakes.dart';

/// Les quatre écrans dont le serveur ne vérifie aucun consentement.
const _aiScreenNames = <String>[
  'CvGeneratorScreen',
  'MotivationLettersScreen',
  'InterviewSimulatorScreen',
  'DocumentReviewScreen',
];

/// Le motif d'une INSTANCIATION : le nom suivi d'une parenthèse ouvrante, sauf
/// quand cette parenthèse ouvre la DÉCLARATION `({super.key…})` du fichier de
/// définition (`(` puis `{`) — sans quoi l'inventaire compterait des fantômes.
///
/// Il acceptait à l'origine `CvGeneratorScreen()` seulement, c'est-à-dire un appel
/// SANS paramètre. Depuis la build 55 le hub passe `fromEefHub: true` : un motif
/// qui exigeait les parenthèses vides ne voyait plus ces trois appels, et
/// l'inventaire aurait baissé en silence (ou, pire, laissé passer un appel avec
/// paramètre ajouté ailleurs). Le motif voit donc l'appel avec ou sans paramètre ;
/// les comptes figés ci-dessous n'ont pas bougé, et un test plus bas le mord.
final _aiScreenCall = RegExp('\\b(${_aiScreenNames.join('|')})\\((?!\\{)');

/// L'inventaire figé : fichier hôte → nombre d'instanciations.
///
/// MESURÉ le 15/08/2026 par `grep -rn` sur le dépôt suivi par git. Chacun de ces
/// quatre fichiers est monté plus bas avec le drapeau à faux : la liste et les
/// tests de rendu se couvrent mutuellement.
const _expectedCallSites = <String, int>{
  'lib/app/features/shell/kpb_tools_drawer.dart': 4,
  'lib/app/features/tools/student_tools_screen.dart': 3,
  'lib/app/features/cases/case_detail_screen.dart': 2,
  'lib/app/features/ai_advisor/ai_chat_screen.dart': 1,
  // Le hub de l'espace « Études en France » (build 54) : CV, lettres, entretien.
  // Même masque que la boîte à outils (`AppConfig.aiToolsEnabled`), couvert plus
  // bas dans les deux sens.
  'lib/app/features/etudes_en_france/eef_home_screen.dart': 3,
  // La feuille du bot « Passerelle » (C3 bis) : son bouton « relecture » ouvre
  // la relecture IA derrière le même masque, couvert plus bas dans les deux sens.
  'lib/app/features/assist_bridge/assist_bridge_sheet.dart': 1,
};

/// Une suggestion « relecture » du bot Passerelle (C3 bis).
const _assistBridgeReview = AssistBridgePayload(
  needId: 'document_review',
  feature: 'document_review',
  route: '/document-review',
);

/// On mesure le dépôt SUIVI PAR GIT, pas les brouillons locaux d'une autre
/// session — même patron que test/core/no_remote_animation_test.dart.
List<String> _trackedLibFiles() {
  try {
    final result = Process.runSync('git', ['ls-files', '--', 'lib']);
    if (result.exitCode == 0) {
      return (result.stdout as String)
          .split('\n')
          .where((path) => path.endsWith('.dart'))
          .toList();
    }
  } catch (_) {
    // git absent : repli sur le scan filesystem.
  }
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.replaceAll('\\', '/'))
      .toList();
}

Map<String, int> _measuredCallSites() {
  final counts = <String, int>{};
  for (final relativePath in _trackedLibFiles()) {
    final file = File(relativePath);
    if (!file.existsSync()) continue;
    for (final line in file.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      final calls = _aiScreenCall.allMatches(line).length;
      if (calls > 0) {
        counts[relativePath] = (counts[relativePath] ?? 0) + calls;
      }
    }
  }
  return counts;
}

AppSnapshot _snapshotWithCase() {
  final now = DateTime.now();
  return AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(fullName: 'Awa Traoré'),
    cases: [
      StudentCase(
        id: 'case-m1',
        referenceCode: 'KPB-M1',
        type: CaseType.applicationSupport,
        title: const LocalizedText(fr: 'Dossier master', en: 'Master case'),
        description: const LocalizedText(fr: 'Desc', en: 'Desc'),
        contextLabel: const LocalizedText(fr: 'France', en: 'France'),
        status: CaseStatus.documentsNeeded,
        preferredContactMethod: ContactMethod.inApp,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
        nextStepTitle: const LocalizedText(fr: 'Suite', en: 'Next'),
        nextStepDescription: const LocalizedText(fr: '', en: ''),
        timeline: const <CaseTimelineEvent>[],
        messages: const [],
        documentRequests: const <DocumentRequest>[],
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  // Une surface HAUTE, et c'est structurant : l'écran de dossier et le chat sont
  // des listes paresseuses. Sur les 800 px par défaut du binding, les cartes
  // « simulateur d'entretien » et « relecture IA » ne sont pas construites du
  // tout — un test qui les cherche là trouve « rien » et déclare le masquage
  // réussi alors qu'il n'a rien mesuré. C'est précisément le genre de vert
  // trompeur que ce dépôt collectionne.
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpTestApp(
    tester,
    child: child,
    initialSnapshot: _snapshotWithCase(),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  setUp(() {
    resetGetxSingleton();
    useSeenTour();
  });
  tearDown(() {
    AppConfig.aiToolsEnabledOverride = null;
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('(a) l\'inventaire des points d\'entrée', () {
    // La contre-épreuve du motif : un inventaire dont le détecteur est aveugle
    // reste vert en ne mesurant rien.
    test('le motif voit un appel avec ou sans paramètre, pas la déclaration',
        () {
      for (final line in [
        'builder: () => const CvGeneratorScreen(),',
        '() => const CvGeneratorScreen(fromEefHub: true),',
        'child: const InterviewSimulatorScreen(',
        'const DocumentReviewScreen(apiClient: client)',
      ]) {
        expect(_aiScreenCall.hasMatch(line), isTrue, reason: line);
      }
      for (final line in [
        'const CvGeneratorScreen({super.key, this.fromEefHub = false});',
        'const DocumentReviewScreen({super.key, this.apiClient});',
        'State<CvGeneratorScreen> createState() => _CvGeneratorScreenState();',
        'class MotivationLettersScreen extends StatefulWidget {',
      ]) {
        expect(_aiScreenCall.hasMatch(line), isFalse, reason: line);
      }
    });

    test('aucun appelant hors des fichiers hôtes déclarés', () {
      final measured = _measuredCallSites();
      final undeclared = measured.keys
          .where((path) => !_expectedCallSites.containsKey(path))
          .toList()
        ..sort();

      expect(
        undeclared,
        isEmpty,
        reason: 'Un nouveau fichier instancie un des quatre écrans IA sans '
            'qu\'aucun test de rendu ne le monte drapeau à faux. Ajoutez-le à '
            '_expectedCallSites ET donnez-lui son test plus bas — sinon le '
            'masquage aura un trou, comme PARC-05 en avait dix-sept :\n'
            '  ${undeclared.join('\n  ')}',
      );
    });

    test('et chaque fichier hôte porte exactement le nombre d\'appels connu',
        () {
      final measured = _measuredCallSites();
      final drift = <String>[];
      _expectedCallSites.forEach((path, expected) {
        final actual = measured[path] ?? 0;
        if (actual != expected) {
          drift.add('  $path : $actual appel(s) au lieu de $expected');
        }
      });

      expect(
        drift,
        isEmpty,
        reason: 'Le nombre d\'instanciations a bougé. Si c\'est une entrée '
            'ajoutée, elle doit être DANS le bloc `if (AppConfig.aiToolsEnabled)` '
            'et le test de rendu du fichier doit la couvrir ; si c\'est une '
            'entrée retirée, baissez le compte.\n${drift.join('\n')}',
      );
    });

    test('les quatorze appels totalisent bien quatorze', () {
      final total =
          _measuredCallSites().values.fold<int>(0, (sum, n) => sum + n);
      expect(total, 14);
    });
  });

  group('(b) drapeau à FAUX — aucune tuile IA nulle part', () {
    setUp(() => AppConfig.aiToolsEnabledOverride = false);

    test('le tiroir n\'offre plus aucun des quatre outils', () {
      final labels =
          KpbToolsDrawer.toolsForTest.map((tool) => tool.labelKey).toSet();
      expect(labels, isNot(contains('tools_cv')));
      expect(labels, isNot(contains('tools_motivation_letter')));
      expect(labels, isNot(contains('tools_interview')));
      expect(labels, isNot(contains('tools_doc_review')));

      // Le scanner reste : capture locale, assemblage en PDF, aucun octet qui
      // sort du téléphone. C'est même lui qui prépare le fichier que l'étudiant
      // envoie ensuite au conseiller (M2).
      expect(labels, contains('tools_doc_scanner'));
      expect(labels, contains('tools_budget'));
    });

    testWidgets('la boîte à outils ne montre que les outils sans IA',
        (tester) async {
      await _pump(tester, const StudentToolsScreen());

      expect(find.text('cv_generator_title'), findsNothing);
      expect(find.text('letters_title'), findsNothing);
      expect(find.text('interview_title'), findsNothing);
      expect(find.text('scanner_title'), findsOneWidget);
      expect(find.text('impact_title'), findsOneWidget);
    });

    testWidgets('le hub de l\'espace « Études en France » ne les offre plus',
        (tester) async {
      await _pump(tester, const EefHomeScreen());

      // Le hub est bien monté (contre-épreuve de ce test)…
      expect(find.text('eef_hub_formations_title'), findsOneWidget);
      // …et ne porte aucune des trois tuiles IA.
      expect(find.text('cv_generator_title'), findsNothing);
      expect(find.text('letters_title'), findsNothing);
      expect(find.text('interview_title'), findsNothing);
    });

    testWidgets('l\'écran de dossier perd le simulateur et la relecture',
        (tester) async {
      await _pump(tester, const CaseDetailScreen(caseId: 'case-m1'));

      expect(find.text('case_interview_sim_title'), findsNothing);
      expect(find.text('case_ai_review_cta'), findsNothing);
      // Et il garde sa sortie humaine : le masquage ne crée pas d'impasse.
      expect(find.text('case_continue_whatsapp'), findsOneWidget);
    });

    testWidgets('le coach perd son raccourci « lettre de motivation »',
        (tester) async {
      // Le chemin le plus facile à oublier : il part du COACH, la seule surface
      // IA que le plan garde en ligne parce que son consentement est vérifié
      // côté serveur.
      await _pump(tester, const AiChatScreen());

      expect(find.byIcon(Icons.edit_note_rounded), findsNothing);
      expect(find.byType(MotivationLettersScreen), findsNothing);
    });

    testWidgets('la feuille Passerelle ne propose plus la relecture',
        (tester) async {
      await _pump(
          tester, const AssistBridgeSheet(payload: _assistBridgeReview));

      // La feuille est bien montée (contre-épreuve)…
      expect(find.byKey(const ValueKey('assist-bridge-sheet')), findsOneWidget);
      // …sans bouton vers la relecture IA.
      expect(find.byKey(const ValueKey('assist-bridge-feature')), findsNothing);
    });
  });

  group('(c) contre-épreuve — drapeau à VRAI, les dix entrées reviennent', () {
    setUp(() => AppConfig.aiToolsEnabledOverride = true);

    testWidgets('la feuille Passerelle retrouve le bouton relecture',
        (tester) async {
      await _pump(
          tester, const AssistBridgeSheet(payload: _assistBridgeReview));

      expect(
          find.byKey(const ValueKey('assist-bridge-feature')), findsOneWidget);
    });

    test('le tiroir retrouve ses quatre outils IA', () {
      final labels =
          KpbToolsDrawer.toolsForTest.map((tool) => tool.labelKey).toSet();
      expect(
        labels,
        containsAll(<String>[
          'tools_cv',
          'tools_motivation_letter',
          'tools_interview',
          'tools_doc_review',
        ]),
        reason: 'Le drapeau à vrai ne ramène pas les outils : la liste du '
            'tiroir est probablement figée dans un `static final`, qui gèle la '
            'valeur du drapeau à son premier accès.',
      );
    });

    testWidgets('la boîte à outils retrouve ses trois cartes', (tester) async {
      await _pump(tester, const StudentToolsScreen());

      expect(find.text('cv_generator_title'), findsOneWidget);
      expect(find.text('letters_title'), findsOneWidget);
      expect(find.text('interview_title'), findsOneWidget);
    });

    testWidgets('le hub de l\'espace retrouve ses trois outils',
        (tester) async {
      await _pump(tester, const EefHomeScreen());

      expect(find.text('cv_generator_title'), findsOneWidget);
      expect(find.text('letters_title'), findsOneWidget);
      expect(find.text('interview_title'), findsOneWidget);
    });

    testWidgets('l\'écran de dossier retrouve ses deux cartes', (tester) async {
      await _pump(tester, const CaseDetailScreen(caseId: 'case-m1'));

      expect(find.text('case_interview_sim_title'), findsOneWidget);
      expect(find.text('case_ai_review_cta'), findsOneWidget);
    });

    testWidgets('le coach retrouve son raccourci', (tester) async {
      await _pump(tester, const AiChatScreen());

      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });
  });

  group('aucun de ces écrans n\'est atteignable par une route nommée', () {
    // `Get.toNamed('/…')` et les charges utiles de notification ne peuvent
    // viser que ce qui est déclaré dans la table des routes. Les quatre écrans
    // n'y figurent pas — ils ne s'ouvrent que par `Get.to(() => …)`, donc par
    // les dix appels inventoriés plus haut. Cette assertion verrouille ce fait :
    // le jour où quelqu'un leur donnerait une route, le masquage aurait un
    // onzième chemin que ni l'inventaire ni les tests de rendu ne voient.
    test('la table des routes ne mentionne aucun des quatre écrans', () {
      final routes = File('lib/app/core/config/app_routes.dart')
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      for (final name in const [
        'CvGeneratorScreen',
        'MotivationLettersScreen',
        'InterviewSimulatorScreen',
        'DocumentReviewScreen',
      ]) {
        expect(
          routes.contains(name),
          isFalse,
          reason: '$name a reçu une route nommée. Une route est un point '
              'd\'entrée de plus — atteignable depuis une notification — et il '
              'doit être gardé puis ajouté à ce fichier.',
        );
      }
    });
  });
}
