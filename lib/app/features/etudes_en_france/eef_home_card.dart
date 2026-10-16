import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/eef_calendar.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_entry.dart';

/// La carte d'accueil de l'espace « Études en France ».
///
/// **Elle s'auto-masque**, comme les autres blocs de l'accueil : quand le
/// module est éteint, elle rend un `SizedBox.shrink()` et l'accueil n'a aucune
/// condition à porter. C'est ce qui fait qu'une bascule serveur suffit —
/// l'accueil n'a pas besoin de savoir qu'il existe un drapeau.
///
/// L'espacement du bas vit DANS la carte, pas autour : sinon l'accueil garderait
/// un trou de 24 px quand la carte se masque (même règle pour tous les blocs de
/// l'accueil, chantier K).
class EefHomeCard extends StatelessWidget {
  const EefHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        if (!EefEntry.isVisible) return const SizedBox.shrink();

        // La ligne de contexte passe par le point unique d'EefCalendar, jamais
        // par un calcul local.
        //
        // Elle le faisait avant, et c'était un défaut : la carte lisait
        // `daysUntilOpening()` et `rangeLabel()` sans consulter la suspension.
        // Un étudiant nigérien lisait donc « ouverture dans 41 jours » ICI —
        // l'écran le plus vu de l'app — alors que la vitrine refuse
        // délibérément de lui donner une date, la source officielle disant que
        // son dossier ne sera pas traité. Une garde sur une porte, pas sur
        // l'autre, et c'est la mieux fréquentée qui n'en avait pas.
        //
        // `timingLabel` rend `null` quand il n'y a rien d'honnête à dire : la
        // carte se contente alors du sous-titre, qui ne parle pas de dates.
        final timing = EefCalendar.timingLabel(
          country: Get.find<AppController>().profile?.countryOfResidence,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
          child: KpbCard(
            variant: KpbCardVariant.interactive,
            onTap: () => Get.to<void>(
              () => const EefEntry(source: 'home_card'),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KpbColors.actionPrimarySoft,
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: KpbColors.actionPrimary,
                  ),
                ),
                const SizedBox(width: KpbSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('eef_title'.tr, style: KpbTextStyles.titleSm),
                      const SizedBox(height: 2),
                      Text(
                        'eef_home_card_subtitle'.tr,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: context.kpb.textMuted),
                      ),
                      if (timing != null) ...[
                        const SizedBox(height: KpbSpacing.xs),
                        Text(
                          timing,
                          style: KpbTextStyles.caption
                              .copyWith(color: KpbColors.actionPrimary),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.kpb.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
