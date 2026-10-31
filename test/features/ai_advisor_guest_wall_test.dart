// Mur invité de KPB Intelligence : il parle du CHAT, pas des outils (audit
// build 57, T1-03). Il s'intitulait « Outils KPB » et citait CV, lettres et
// entretien alors que l'élève venait de toucher « KPB Intelligence ».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/kpb_guest_gate.dart';
import 'package:karatou/app/features/ai_advisor/ai_consent.dart';

import '../widget_test_helpers.dart';

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  Future<void> pumpGuest(
      WidgetTester tester, Widget Function(BuildContext) open) async {
    await pumpTestApp(
      tester,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        isGuestMode: true,
      ),
    );
  }

  testWidgets('le chat ouvre son propre mur, avec sa propre source',
      (tester) async {
    await pumpGuest(tester, (context) {
      openAiChatIfConsented(context, Get.find());
      return const SizedBox();
    });
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    final gate = tester.widget<KpbGuestGate>(find.byType(KpbGuestGate));
    expect(gate.source, 'ai_chat_gate');
    expect(gate.titleKey, 'ai_chat_gate_title');
    // La barre dit « KPB Intelligence », pas « Outils KPB ».
    final fr = AppTranslations().keys['fr']!;
    expect(fr['coach_ai_title'], 'KPB Intelligence');
    expect(find.text('coach_ai_title'.tr), findsOneWidget);
    expect(find.text('tools_drawer_title'.tr), findsNothing);
    // Le texte ne parle ni de CV, ni de lettres, ni d'entretien.
    for (final word in const ['CV', 'lettre', 'entretien']) {
      expect(fr[gate.bodyKey], isNot(contains(word)), reason: word);
      expect(fr[gate.titleKey], isNot(contains(word)), reason: word);
    }
  });

  testWidgets('les outils gardent leur mur', (tester) async {
    await pumpGuest(tester, (context) {
      openAiToolIfConsented(context, () => const SizedBox());
      return const SizedBox();
    });
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    final gate = tester.widget<KpbGuestGate>(find.byType(KpbGuestGate));
    expect(gate.source, 'ai_tool_gate');
    expect(gate.titleKey, 'guest_ai_tool_gate_title');
  });
}
