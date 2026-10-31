// Le bandeau hors ligne couvre TOUTES les routes, une seule fois.
//
// Jusqu'à la build 56, `KpbOfflineBanner` n'était monté que dans
// `app_shell.dart` : sur l'onboarding, une fiche, le test « Mes 10 bourses »
// ou un dossier ouvert par-dessus le shell, une coupure réseau ne se voyait pas.
// Il vit désormais dans le `builder:` de GetMaterialApp (lib/main.dart), via
// `KpbOfflineBannerHost`, au-dessus du Navigator.
//
// Le `builder:` de main.dart est une fermeture privée, inatteignable d'un test :
// on monte donc le même hôte dans un GetMaterialApp de test, ET on relit les
// sources pour garder le branchement réel (comme le clamp de police de
// screen_matrix_test.dart).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/services/connectivity_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/components/kpb_offline_banner.dart';

/// Une route HORS shell, avec une AppBar : c'est elle qui révélerait un double
/// padding d'encoche.
class _DetailPage extends StatelessWidget {
  const _DetailPage(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    // Lu AU NIVEAU DE LA ROUTE, avant que le Scaffold ne consomme l'encoche
    // pour son AppBar : c'est ce que chaque écran de l'app reçoit.
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Text('top=$top', key: const ValueKey('detail_top_padding')),
    );
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  Get.addTranslations(AppTranslations().keys);
  Get.locale = const Locale('fr');
  // Le téléphone Android compact : 360×800, barre de statut de 24 pt. Posé
  // sur la VUE, pas par un MediaQuery englobant : GetMaterialApp construit le
  // sien à partir de la vue.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  tester.view.padding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: const Locale('fr'),
      theme: AppTheme.buildTheme(),
      // Le branchement de lib/main.dart, clamp de police mis à part.
      builder: (context, child) =>
          KpbOfflineBannerHost(child: child ?? const SizedBox.shrink()),
      home: const _DetailPage('Onboarding'),
    ),
  );
  await tester.pumpAndSettle();
}

String _detailTopPadding(WidgetTester tester) => tester
    .widgetList<Text>(find.byKey(const ValueKey('detail_top_padding')))
    .last
    .data!;

void main() {
  tearDown(() {
    // Le service est un singleton : on rend le réseau aux tests suivants.
    ConnectivityService.instance.debugSetOnline(true);
    Get.reset();
  });

  testWidgets('en ligne : aucun bandeau, padding intact', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Mode hors-ligne'), findsNothing);
    expect(_detailTopPadding(tester), 'top=24.0');
  });

  testWidgets(
      'hors ligne : bandeau visible sur une route hors shell, une seule fois, '
      'et sur la route poussée ensuite', (tester) async {
    await _pumpApp(tester);

    ConnectivityService.instance.debugSetOnline(false);
    await tester.pumpAndSettle();

    expect(find.byType(KpbOfflineBanner), findsOneWidget);
    expect(find.text('Mode hors-ligne'), findsOneWidget);
    // Le bandeau a absorbé l'encoche : la route ne la réapplique pas.
    expect(_detailTopPadding(tester), 'top=0.0');

    // Une fiche poussée par-dessus : toujours un seul bandeau, toujours visible.
    unawaited(Get.to<void>(() => const _DetailPage('Fiche bourse')));
    await tester.pumpAndSettle();
    expect(find.text('Fiche bourse'), findsOneWidget);
    expect(find.byType(KpbOfflineBanner), findsOneWidget);
    expect(find.text('Mode hors-ligne'), findsOneWidget);
    expect(_detailTopPadding(tester), 'top=0.0');

    // Retour du réseau : le bandeau disparaît, l'encoche revient, la pile de
    // navigation est intacte (l'arbre n'a pas changé de structure).
    ConnectivityService.instance.debugSetOnline(true);
    await tester.pumpAndSettle();
    expect(find.text('Mode hors-ligne'), findsNothing);
    expect(find.text('Fiche bourse'), findsOneWidget);
    expect(_detailTopPadding(tester), 'top=24.0');
  });

  group('le branchement réel', () {
    String code(String path) => File(path)
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('main.dart monte l\'hôte dans le builder de GetMaterialApp', () {
      final main = code('lib/main.dart');
      final builder = RegExp(
              r'builder: \(context, child\) \{.*?\n          \},',
              dotAll: true)
          .firstMatch(main);
      expect(builder, isNotNull,
          reason: 'builder: de GetMaterialApp introuvable');
      expect(builder!.group(0), contains('KpbOfflineBannerHost('));
    });

    test('le shell ne monte plus son propre bandeau (pas de doublon)', () {
      expect(code('lib/app/features/shell/app_shell.dart'),
          isNot(contains('KpbOfflineBanner')));
      // Et personne d'autre dans lib/ : l'hôte est la seule instance.
      final mounts = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.endsWith('kpb_offline_banner.dart')) continue;
        if (code(path).contains('KpbOfflineBanner()')) mounts.add(path);
      }
      expect(mounts, isEmpty,
          reason: 'KpbOfflineBanner monté hors de KpbOfflineBannerHost : '
              '$mounts');
    });
  });

  // Audit build 57, T7-07 : la coupure du réseau ne pose plus un bandeau
  // flottant par-dessus le bandeau permanent (deux signaux pour un état).
  test('la coupure n\'ajoute pas de toast au bandeau permanent', () {
    final source = File('lib/app/core/services/connectivity_service.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(source, isNot(contains('offlinePending')));
    // Le retour du réseau garde le sien.
    expect(source, contains('online_title'));
  });
}
