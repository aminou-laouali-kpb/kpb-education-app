import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import 'ai_chat_screen.dart';
import '../../core/ui/components/kpb_toast.dart';

/// Shared AI-processing consent gate (IA-T4).
///
/// The FAB used to be the only caller. Home Copilot, the "ask the advisor"
/// home CTA, the tools drawer, student-tools cards and case-detail review
/// all have to go through here — otherwise a student who never tapped the
/// FAB would hit the server 403 with no dialog.
///
/// Returns `true` when the student already consented, or just accepted.
/// Returns `false` on decline or if there is no profile (nothing to stamp).
///
/// The profile PATCH is **awaited** before returning. `updateProfile` used
/// to fire-and-forget the push; navigating immediately after accept would
/// race the PATCH and the next Groq call would 403 `ai_consent_required`.
Future<bool> ensureAiConsent(
  BuildContext context,
  AppController controller,
) async {
  final profile = controller.profile;
  if (profile == null) return false;
  if (profile.hasAiConsent) return true;

  final granted = await askAiConsent(context);
  if (granted != true) return false;
  if (!context.mounted) return false;

  await controller.updateProfile(
    profile.copyWith(aiConsentedAt: DateTime.now()),
  );
  return true;
}

Future<bool?> askAiConsent(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('ai_consent_title'.tr),
      content: Text('ai_consent_body'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('ai_consent_decline'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('ai_consent_accept'.tr),
        ),
      ],
    ),
  );
}

Future<void> openAiChatIfConsented(
  BuildContext context,
  AppController controller,
) async {
  // Même parcours que les outils IA : un invité est envoyé vers le mur de
  // création de compte au lieu d'un clic mort (copilote et bannière de
  // l'accueil ne faisaient rien pour lui).
  //
  // Le mur est celui du CHAT, pas celui des outils : il s'intitulait « Outils
  // KPB » et parlait de CV, de lettres et d'entretien alors que l'élève venait
  // de toucher « KPB Intelligence », promesse n° 1 de l'écran d'entrée (audit
  // build 57, T1-03). La source d'entonnoir est distincte aussi.
  await openAiToolIfConsented(
    context,
    () => const AiChatScreen(),
    guestWall: const AiGuestWall(
      barTitleKey: 'coach_ai_title',
      source: 'ai_chat_gate',
      titleKey: 'ai_chat_gate_title',
      bodyKey: 'ai_chat_gate_body',
      ctaKey: 'guest_ai_tool_gate_cta',
    ),
  );
}

/// Le mur montré à un invité qui touche une fonction IA : son titre, son texte,
/// et la source qui part dans l'entonnoir analytique.
class AiGuestWall {
  const AiGuestWall({
    required this.barTitleKey,
    required this.source,
    required this.titleKey,
    required this.bodyKey,
    required this.ctaKey,
  });

  /// Le mur des outils IA (CV, lettres, entretien, relecture).
  static const tools = AiGuestWall(
    barTitleKey: 'tools_drawer_title',
    source: 'ai_tool_gate',
    titleKey: 'guest_ai_tool_gate_title',
    bodyKey: 'guest_ai_tool_gate_body',
    ctaKey: 'guest_ai_tool_gate_cta',
  );

  final String barTitleKey;
  final String source;
  final String titleKey;
  final String bodyKey;
  final String ctaKey;
}

Future<void> openAiToolIfConsented(
  BuildContext context,
  Widget Function() page, {
  AiGuestWall guestWall = AiGuestWall.tools,
}) async {
  final controller = Get.find<AppController>();
  // ── L'invité n'a pas de profil, et sans ceci son clic ne faisait RIEN ────
  //
  // `ensureAiConsent` rend `false` quand `profile == null` (le mode invité pose
  // exactement cela), et l'appelant se contentait de `return`. Le tiroir se
  // refermait donc sur un écran inchangé : pas de dialogue, pas de message, pas
  // d'invitation à créer un compte. Un clic mort, indiscernable d'un bug.
  //
  // Le défaut dormait tant que les quatre outils étaient masqués ; il devient
  // visible exactement le jour où on les ouvre. On l'envoie sur le mur invité
  // du dépôt, qui sait convertir (il quitte le mode invité, remet l'onboarding
  // à faire et journalise `guest_to_signup` avec sa provenance).
  //
  // Le test porte sur `isGuestMode`, PAS sur `profile == null`. Les deux ne sont
  // pas synonymes : une installation authentifiée dont la première
  // synchronisation a échoué n'a pas de profil en cache non plus, et la coquille
  // gère explicitement cet état. L'envoyer sur le mur invité l'aurait mis en
  // BOUCLE — le bouton appelle `leaveGuestForSignup`, qui ne fait rien quand
  // `isGuestMode` est faux, puis `AppBootScreen` voit un compte dont
  // l'onboarding est terminé et le renvoie dans la coquille. Le même clic, sans
  // fin.
  if (controller.isGuestMode) {
    await Get.to<void>(
      () => Scaffold(
        appBar: AppBar(title: Text(guestWall.barTitleKey.tr)),
        body: SafeArea(
          child: KpbGuestGate(
            source: guestWall.source,
            titleKey: guestWall.titleKey,
            bodyKey: guestWall.bodyKey,
            ctaKey: guestWall.ctaKey,
            icon: Icons.auto_awesome_outlined,
          ),
        ),
      ),
    );
    return;
  }
  // Authentifié mais sans profil : la synchronisation n'a pas abouti. Ce n'est
  // ni un invité ni un refus de consentement — le dire, plutôt que de rendre un
  // clic mort.
  if (controller.profile == null) {
    KpbToast.offlinePending(
      'profile_sync_pending_body'.tr,
      title: 'profile_sync_pending_title'.tr,
    );
    return;
  }
  if (!await ensureAiConsent(context, controller)) return;
  await Get.to(page);
}
