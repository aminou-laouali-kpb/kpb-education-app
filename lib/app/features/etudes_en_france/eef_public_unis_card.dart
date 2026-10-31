import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_entry.dart';

/// La carte « Universités publiques » du guide France : elle mène à l'espace
/// Études en France, par la même porte que la carte de l'accueil.
///
/// Le guide France ne parlait que des écoles privées et annonçait « Universités
/// publiques — Bientôt disponible » avec une date calculée, alors que l'espace
/// Études en France est ouvert : trois dates contradictoires d'un écran à
/// l'autre, et aucun lien du guide vers l'espace (audit build 57, T6-18). Quand
/// l'espace n'est pas visible (drapeau fermé, compte non élève), la carte ne
/// s'affiche pas : plutôt rien qu'une date inventée.
class EefPublicUnisCard extends StatelessWidget {
  const EefPublicUnisCard({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        if (!EefEntry.isVisible) return const SizedBox.shrink();
        return Padding(
          padding: margin,
          child: KpbCard(
            key: const ValueKey<String>('eef-public-unis-card'),
            variant: KpbCardVariant.interactive,
            onTap: () => Get.to<void>(
              () => const EefEntry(source: 'france_guide'),
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
                    Icons.account_balance_outlined,
                    color: KpbColors.actionPrimary,
                  ),
                ),
                const SizedBox(width: KpbSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('france_public_unis_card_title'.tr,
                          style: KpbTextStyles.titleSm),
                      const SizedBox(height: 2),
                      Text(
                        'france_public_unis_card_body'.tr,
                        style: KpbTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: KpbColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
