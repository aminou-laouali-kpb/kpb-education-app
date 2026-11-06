// Guide France : la carte « Universités publiques » mène à Études en France
// (audit build 57, T6-18). Avant : un encadré « Bientôt disponible · <date
// calculée> » et aucun lien du guide vers l'espace, qui était pourtant ouvert.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/etudes_en_france/eef_public_unis_card.dart';

Widget _app() => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: const Scaffold(body: EefPublicUnisCard()),
    );

void main() {
  setUp(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.eefTeaserEnabledOverride = null;
  });
  tearDown(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.eefTeaserEnabledOverride = null;
    Get.reset();
  });

  testWidgets('espace ouvert : la carte est là et cliquable', (tester) async {
    AppConfig.eefSpaceEnabledOverride = true;
    await tester.pumpWidget(_app());

    final card = find.byKey(const ValueKey<String>('eef-public-unis-card'));
    expect(card, findsOneWidget);
    expect(tester.widget<KpbCard>(card).onTap, isNotNull);
    final fr = AppTranslations().keys['fr']!;
    expect(find.text(fr['france_public_unis_card_title']!), findsOneWidget);
    // Plus aucune date calculée ni « Bientôt disponible ».
    expect(find.textContaining('Bientôt'), findsNothing);
  });

  testWidgets('espace fermé : rien, plutôt qu\'une date inventée',
      (tester) async {
    AppConfig.eefSpaceEnabledOverride = false;
    AppConfig.eefTeaserEnabledOverride = false;
    RemoteFeatureFlags.instance.debugSetFeaturesForTest(const {});
    await tester.pumpWidget(_app());

    expect(find.byKey(const ValueKey<String>('eef-public-unis-card')),
        findsNothing);
  });

  testWidgets('le drapeau s\'ouvre après le premier rendu : la carte apparaît',
      (tester) async {
    AppConfig.eefSpaceEnabledOverride = false;
    AppConfig.eefTeaserEnabledOverride = false;
    await tester.pumpWidget(_app());
    expect(find.byKey(const ValueKey<String>('eef-public-unis-card')),
        findsNothing);

    AppConfig.eefSpaceEnabledOverride = true;
    RemoteFeatureFlags.instance.debugSetFeaturesForTest(const {});
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('eef-public-unis-card')),
        findsOneWidget);
  });
}
