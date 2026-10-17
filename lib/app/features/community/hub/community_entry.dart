import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/community_store.dart';
import '../../../core/services/remote_feature_flags.dart';
import '../../../core/ui/app_tokens.dart';
import 'community_composer_screen.dart';
import 'community_hub_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Points d'entrée de la nouvelle communauté.
//
// Choix d'emplacement : une CARTE DE L'ACCUEIL (élève, sous « Tes
// échéances ») et un accès rapide du Profil — PAS un sixième onglet.
//   · la barre d'onglets est figée à cinq (spec §4.1, `StudentShellTab`) : un
//     sixième libellé passerait sous le plancher de 12 sp sur un 360 dp et
//     casserait les tests d'écran et la navigation profonde par index ;
//   · l'accueil « Ta prochaine étape » est l'écran le plus vu : la carte y
//     est visible sans détour, et se replie (hauteur nulle) drapeau fermé ;
//   · les fiches bourse, pays et formation portent en plus leur section
//     « Discussions (N) » : la communauté est branchée sur le catalogue, pas
//     un forum à part.
// Drapeau `features.community` fermé : rien de tout cela n'apparaît, et
// l'entrée actuelle (articles, groupe WhatsApp, derrière `KPB_MVP_ONLY`)
// reste exactement ce qu'elle était.
// ─────────────────────────────────────────────────────────────────────────────

/// Ouvre l'accueil de la communauté.
Future<void> openCommunityHub({required String source}) =>
    Get.to<void>(() => CommunityHubScreen(source: source)) ?? Future.value();

/// La carte « Communauté » de l'accueil élève. Hauteur nulle tant que la
/// communauté n'est pas ouverte à ce compte.
class CommunityHomeCard extends StatelessWidget {
  const CommunityHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        RemoteFeatureFlags.instance.flagsVersion,
        CommunityStore.instance,
      ]),
      builder: (context, _) {
        if (!CommunityStore.instance.enabled) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              KpbSpacing.pagePad, 0, KpbSpacing.pagePad, KpbSpacing.xl),
          child: Container(
            key: const ValueKey<String>('comm-home-card'),
            padding: const EdgeInsets.all(KpbSpacing.md),
            decoration: BoxDecoration(
              color: KpbColors.surface,
              borderRadius: KpbRadius.lgBr,
              border: Border.all(color: KpbColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  label: '${'comm_home_title'.tr}. ${'comm_home_body'.tr}',
                  excludeSemantics: true,
                  child: InkWell(
                    key: const ValueKey<String>('comm-home-open'),
                    borderRadius: KpbRadius.smBr,
                    onTap: () => openCommunityHub(source: 'home_card'),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: KpbColors.actionPrimarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.forum_rounded,
                              color: KpbColors.actionPrimary),
                        ),
                        const SizedBox(width: KpbSpacing.sm + 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('comm_home_title'.tr,
                                  style: KpbTextStyles.titleMd),
                              const SizedBox(height: 2),
                              Text('comm_home_body'.tr,
                                  style: KpbTextStyles.bodySm),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: KpbColors.borderStrong),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm + 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('comm-home-ask'),
                    onPressed: () =>
                        openCommunityComposer(context, source: 'home_card'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text('comm_ask_question'.tr),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
