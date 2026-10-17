// Bot « Passerelle » (C3 bis) — la feuille ouverte par une notification
// `assist_bridge` :
//   · la charge est relue sans confiance (identifiant, besoin, WhatsApp) ;
//   · « Tu peux le faire directement dans l'app » : bouton fonction, bouton
//     WhatsApp (ligne KPB de la configuration), « Plus tard » ;
//   · chaque geste est mesuré (`opened_feature`, `opened_whatsapp`,
//     `dismissed`, y compris une fermeture par glissement) puis exécuté ;
//   · besoin ou fonction inconnus (serveur plus récent) : texte générique,
//     jamais de bouton vers une porte inconnue ;
//   · FR/EN à parité, échelle de texte 1,5 sans débordement, titre annoncé.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/notification_opt_out.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/translations/app_translations_en.dart';
import 'package:karatou/app/core/translations/app_translations_fr.dart';
import 'package:karatou/app/features/assist_bridge/assist_bridge_sheet.dart';

Map<String, dynamic> _data({
  String needId = 'document_review',
  String feature = 'document_review',
  String? eventId = 'ev_1',
  String route = '/document-review',
  String whatsapp = 'kpb',
}) =>
    <String, dynamic>{
      'needId': needId,
      'feature': feature,
      if (eventId != null) 'eventId': eventId,
      'route': route,
      'whatsapp': whatsapp,
      'sender': 'kpb_assistant',
      'type': 'assist_bridge',
    };

class _Recorder {
  final reports = <String>[];
  final features = <String>[];
  final whatsapps = <String>[];

  AssistBridgeHandlers get handlers => AssistBridgeHandlers(
        report: (eventId, action) async => reports.add('$eventId:$action'),
        openFeature: (p) async => features.add(p.feature),
        openWhatsApp: (p) async => whatsapps.add(p.needId),
      );
}

/// Un bouton qui ouvre la feuille, dans une app traduite.
Future<void> _pumpLauncher(
  WidgetTester tester,
  Map<String, dynamic> data,
  _Recorder recorder, {
  Locale locale = const Locale('fr'),
  double textScale = 1.0,
  Size size = const Size(360, 720),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: locale,
      fallbackLocale: const Locale('fr'),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAssistBridgeSheet(
                data,
                context: context,
                handlers: recorder.handlers,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    AppConfig.aiToolsEnabledOverride = null;
    Get.reset();
  });

  group('AssistBridgePayload', () {
    test('lit la charge, tolère le reste', () {
      final p = AssistBridgePayload.fromData(_data());
      expect(p.needId, 'document_review');
      expect(p.feature, 'document_review');
      expect(p.eventId, 'ev_1');
      expect(p.whatsapp, isTrue);
      expect(p.knownNeed, isTrue);

      final odd = AssistBridgePayload.fromData(<String, dynamic>{
        'needId': 42,
        'eventId': 'ev/../1',
        'whatsapp': '+227 90 00 00 00',
      });
      expect(odd.needId, 'unknown');
      expect(odd.knownNeed, isFalse);
      expect(odd.eventId, isNull, reason: 'identifiant illisible : rien');
      expect(odd.whatsapp, isFalse,
          reason: 'jamais un numéro venu de la charge');
    });

    test('la fonction : masque des outils IA, route inconnue écartée', () {
      AppConfig.aiToolsEnabledOverride = false;
      expect(
          assistBridgeFeatureAvailable(AssistBridgePayload.fromData(_data())),
          isFalse);
      AppConfig.aiToolsEnabledOverride = true;
      expect(
          assistBridgeFeatureAvailable(AssistBridgePayload.fromData(_data())),
          isTrue);
      expect(
        assistBridgeFeatureAvailable(AssistBridgePayload.fromData(
            _data(feature: 'futur', route: '/inconnue'))),
        isFalse,
      );
      expect(
        assistBridgeFeatureAvailable(AssistBridgePayload.fromData(
            _data(feature: 'futur', route: '/scholarship-match'))),
        isTrue,
        reason: 'fonction inconnue mais route connue de cette build',
      );
    });

    test('message WhatsApp pré-rempli : une clé `*_prefill` par besoin', () {
      for (final need in assistBridgeKnownNeeds) {
        final key = assistBridgePrefillKey(
            AssistBridgePayload.fromData(_data(needId: need, feature: need)));
        expect(key, 'assist_bridge_${need}_prefill');
        expect(appTranslationsFr[key], isNotNull, reason: key);
        expect(appTranslationsEn[key], isNotNull, reason: key);
        // Aucun numéro dans les textes : la ligne vient de la configuration.
        expect(appTranslationsFr[key], isNot(matches(RegExp(r'\d{6,}'))));
      }
    });
  });

  test('textes FR/EN à parité pour chaque besoin, sans promesse ni %', () {
    final keys = <String>[
      'assist_bridge_badge',
      'assist_bridge_from',
      'assist_bridge_sheet_title',
      'assist_bridge_whatsapp',
      'assist_bridge_later',
      'assist_bridge_settings_hint',
      'assist_bridge_pref_title',
      'assist_bridge_pref_subtitle',
      'notif_cta_assist_bridge',
      'assist_bridge_body_generic',
      'assist_bridge_cta_generic',
      for (final need in assistBridgeKnownNeeds) ...[
        'assist_bridge_body_$need',
        'assist_bridge_cta_$need',
      ],
    ];
    for (final key in keys) {
      final fr = appTranslationsFr[key];
      final en = appTranslationsEn[key];
      expect(fr, isNotNull, reason: 'FR manquant : $key');
      expect(en, isNotNull, reason: 'EN manquant : $key');
      expect('$fr $en', isNot(matches(RegExp(r'%|chance|garanti|guarantee'))));
      expect(fr, isNot(matches(RegExp(r'\b(vous|votre|vos)\b'))),
          reason: 'tutoiement : $key');
    }
    expect(appTranslationsFr['assist_bridge_badge'], 'Assistant KPB');
    expect(NotificationOptOutType.all, contains('assist_bridge'));
  });

  testWidgets(
      'feuille : badge, titre annoncé, texte du besoin, trois gestes ; '
      '« fonction » mesuré puis exécuté', (tester) async {
    AppConfig.aiToolsEnabledOverride = true;
    final rec = _Recorder();
    final semantics = tester.ensureSemantics();
    await _pumpLauncher(tester, _data(), rec);

    expect(find.text('Assistant KPB'), findsOneWidget);
    expect(find.text('Un message de l\'équipe KPB'), findsOneWidget);
    expect(
        find.text('Tu peux le faire directement dans l\'app'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('Tu peux le faire directement dans l\'app')),
      matchesSemantics(
          isHeader: true, label: 'Tu peux le faire directement dans l\'app'),
    );
    expect(find.textContaining('outil de relecture'), findsOneWidget);
    expect(find.text('Faire relire mon CV ou ma lettre'), findsOneWidget);
    expect(find.text('Écrire à KPB sur WhatsApp'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    expect(find.textContaining('bot'), findsNothing,
        reason: 'le mot « bot » n\'apparaît jamais comme expéditeur');

    await tester.tap(find.byKey(const ValueKey('assist-bridge-feature')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assist-bridge-sheet')), findsNothing);
    expect(rec.reports, ['ev_1:opened_feature']);
    expect(rec.features, ['document_review']);
    expect(rec.whatsapps, isEmpty);
    semantics.dispose();
  });

  testWidgets('WhatsApp : mesuré puis ouvert vers la ligne KPB',
      (tester) async {
    final rec = _Recorder();
    await _pumpLauncher(tester,
        _data(needId: 'visa', feature: 'services', route: '/services'), rec);
    expect(find.text('Voir l\'aide visa'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('assist-bridge-whatsapp')));
    await tester.pumpAndSettle();
    expect(rec.reports, ['ev_1:opened_whatsapp']);
    expect(rec.whatsapps, ['visa']);
    expect(rec.features, isEmpty);
  });

  testWidgets('« Plus tard » et glissement : `dismissed`, rien d\'ouvert',
      (tester) async {
    final rec = _Recorder();
    await _pumpLauncher(
        tester,
        _data(
            needId: 'scholarship_match',
            feature: 'scholarship_match',
            route: '/scholarship-match'),
        rec);
    await tester.tap(find.byKey(const ValueKey('assist-bridge-later')));
    await tester.pumpAndSettle();
    expect(rec.reports, ['ev_1:dismissed']);

    // Fermeture sans bouton (tap hors de la feuille).
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(rec.reports, ['ev_1:dismissed', 'ev_1:dismissed']);
    expect(rec.features, isEmpty);
    expect(rec.whatsapps, isEmpty);
  });

  testWidgets(
      'outils IA masqués : pas de bouton vers la relecture, WhatsApp reste',
      (tester) async {
    AppConfig.aiToolsEnabledOverride = false;
    final rec = _Recorder();
    await _pumpLauncher(tester, _data(), rec);
    expect(find.byKey(const ValueKey('assist-bridge-feature')), findsNothing);
    expect(
        find.byKey(const ValueKey('assist-bridge-whatsapp')), findsOneWidget);
  });

  testWidgets(
      'besoin et fonction inconnus (serveur plus récent) : texte générique, '
      'aucun bouton vers une porte inconnue, sans identifiant : aucune mesure',
      (tester) async {
    final rec = _Recorder();
    await _pumpLauncher(
        tester,
        _data(
            needId: 'logement',
            feature: 'housing',
            route: '/housing',
            eventId: null,
            whatsapp: ''),
        rec);
    expect(
        find.text('Une fonction de l\'app peut t\'aider pour ce que tu '
            'cherches.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('assist-bridge-feature')), findsNothing);
    expect(find.byKey(const ValueKey('assist-bridge-whatsapp')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('assist-bridge-later')));
    await tester.pumpAndSettle();
    expect(rec.reports, isEmpty);
  });

  testWidgets('anglais : textes EN', (tester) async {
    final rec = _Recorder();
    await _pumpLauncher(
        tester,
        _data(
            needId: 'etudes_en_france',
            feature: 'etudes_en_france',
            route: '/etudes-en-france'),
        rec,
        locale: const Locale('en'));
    expect(find.text('You can do it right in the app'), findsOneWidget);
    expect(find.text('Open Studying in France'), findsOneWidget);
    expect(find.text('Message KPB on WhatsApp'), findsOneWidget);
    expect(find.text('KPB Assistant'), findsOneWidget);
  });

  testWidgets('échelle de texte 1,5 sur un petit téléphone : aucun débordement',
      (tester) async {
    AppConfig.aiToolsEnabledOverride = true;
    for (final need in assistBridgeKnownNeeds) {
      final rec = _Recorder();
      await _pumpLauncher(
        tester,
        _data(needId: need, feature: need),
        rec,
        textScale: 1.5,
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull, reason: need);
      // La feuille défile : « Plus tard » reste atteignable.
      final later = find.byKey(const ValueKey('assist-bridge-later'));
      await tester.ensureVisible(later);
      await tester.pumpAndSettle();
      await tester.tap(later);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assist-bridge-sheet')), findsNothing);
      expect(rec.reports, ['ev_1:dismissed'], reason: need);
    }
  });
}
