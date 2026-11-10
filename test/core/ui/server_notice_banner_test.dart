// L'avis servi par le serveur, en haut de l'accueil (build 59).
//
// Il doit s'afficher quand un texte est posé, se fermer, ne pas revenir pour
// le même texte — même après un redémarrage — et revenir pour un nouveau. Et
// il doit tenir sur un petit écran avec une grande police.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/remote_config_cache.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/ui/components/server_notice_banner.dart';

import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';

class _MockApi extends Mock implements AppApiClient {}

class _NoCache implements RemoteConfigCache {
  @override
  Future<RemoteConfigSnapshot?> read() async => null;

  @override
  Future<void> write(RemoteConfigSnapshot snapshot) async {}
}

class _MemoryDismissals implements ServerNoticeDismissalStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String noticeText) async => value = noticeText;
}

const _fr = 'Maroc : la campagne Études en France ferme le 15 novembre.';
const _en = 'Morocco: the Études en France campaign closes on 15 November.';

Future<void> _serve(_MockApi api, Map<String, dynamic>? notice) async {
  when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
        'minVersion': '0.0.0',
        'notice': notice,
      });
  await RemoteFeatureFlags.instance.refresh(api);
}

void main() {
  late _MockApi api;
  late _MemoryDismissals dismissals;

  setUp(() {
    api = _MockApi();
    dismissals = _MemoryDismissals();
    RemoteFeatureFlags.resetForTest();
    RemoteFeatureFlags.cache = _NoCache();
  });

  tearDown(() {
    RemoteFeatureFlags.resetForTest();
    Get.reset();
  });

  Future<KpbScreenReport> pump(
    WidgetTester tester, {
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
  }) =>
      pumpKpbScreen(
        tester,
        screen: Padding(
          padding: const EdgeInsets.all(16),
          child: ServerNoticeBanner(storage: dismissals),
        ),
        viewport: viewport,
        textScale: textScale,
        locale: locale,
        ownsScaffold: false,
      );

  testWidgets('rien tant que le serveur ne pose aucun avis', (tester) async {
    await _serve(api, null);
    await pump(tester);

    expect(find.byIcon(Icons.campaign_outlined), findsNothing);
  });

  testWidgets('affiche le texte posé, sans bouton quand il n\'y a pas de lien',
      (tester) async {
    await _serve(api, {'fr': _fr});
    await pump(tester);

    expect(find.text(_fr), findsOneWidget);
    expect(find.text('En savoir plus'), findsNothing);
  });

  testWidgets('avec un lien, propose « En savoir plus »', (tester) async {
    await _serve(api, {'fr': _fr, 'url': 'https://www.campusfrance.org/fr'});
    await pump(tester);

    expect(find.text('En savoir plus'), findsOneWidget);
  });

  testWidgets('en anglais, affiche la traduction', (tester) async {
    await _serve(api, {'fr': _fr, 'en': _en});
    await pump(tester, locale: const Locale('en'));

    expect(find.text(_en), findsOneWidget);
    expect(find.text(_fr), findsNothing);
  });

  testWidgets('fermé, il disparaît et ne revient pas au lancement suivant',
      (tester) async {
    await _serve(api, {'fr': _fr});
    await pump(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.text(_fr), findsNothing);
    expect(dismissals.value, _fr);

    // Lancement suivant : même avis servi, mémoire relue.
    await pump(tester);
    expect(find.text(_fr), findsNothing);
  });

  testWidgets('un nouvel avis s\'affiche même si le précédent a été fermé',
      (tester) async {
    dismissals.value = _fr;
    await _serve(api, {'fr': 'Maintenance ce soir de 22 h à 23 h.'});
    await pump(tester);

    expect(find.text('Maintenance ce soir de 22 h à 23 h.'), findsOneWidget);
  });

  testWidgets('un avis posé pendant que l\'app est ouverte apparaît',
      (tester) async {
    await _serve(api, null);
    await pump(tester);
    expect(find.text(_fr), findsNothing);

    await tester.runAsync(() => _serve(api, {'fr': _fr}));
    await tester.pump();

    expect(find.text(_fr), findsOneWidget);
  });

  group('géométrie — aucun débordement, aucun texte coupé, aucune clé brute',
      () {
    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        testWidgets('${viewport.id} ×$scale', (tester) async {
          await _serve(api, {
            'fr': '$_fr Vérifie la date de ton pays avant de déposer ton '
                'dossier, et écris à ton conseiller si tu as un doute.',
            'url': 'https://www.campusfrance.org/fr',
          });
          final report = await pump(
            tester,
            viewport: viewport,
            textScale: scale,
          );

          expect(find.text('En savoir plus'), findsOneWidget);
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(report.otherErrors, isEmpty, reason: report.toString());
          expect(truncatedTexts(tester), isEmpty);
          expect(rawTranslationKeysOnScreen(tester), isEmpty);
        });
      }
    }
  });
}
