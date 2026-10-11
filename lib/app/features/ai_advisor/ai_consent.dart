import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import 'ai_chat_screen.dart';

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
  await openAiToolIfConsented(context, () => const AiChatScreen());
}

Future<void> openAiToolIfConsented(
  BuildContext context,
  Widget Function() page,
) async {
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
        appBar: AppBar(title: Text('tools_drawer_title'.tr)),
        body: const SafeArea(
          child: KpbGuestGate(
            source: 'ai_tool_gate',
            titleKey: 'guest_ai_tool_gate_title',
            bodyKey: 'guest_ai_tool_gate_body',
            ctaKey: 'guest_ai_tool_gate_cta',
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
    Get.snackbar(
      'profile_sync_pending_title'.tr,
      'profile_sync_pending_body'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }
  if (!await ensureAiConsent(context, controller)) return;
  await Get.to(page);
}
