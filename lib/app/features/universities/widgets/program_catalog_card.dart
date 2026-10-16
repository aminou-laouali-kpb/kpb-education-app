import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/app_controller.dart';
import '../../../core/ui/kpb_components.dart';
import '../../../core/utils/tuition_utils.dart';

/// Program list card for M6 catalog (spec §5.6).
class ProgramCatalogCard extends StatelessWidget {
  const ProgramCatalogCard({
    super.key,
    required this.name,
    required this.institution,
    required this.level,
    required this.tuition,
    required this.language,
    required this.duration,
    required this.flag,
    required this.saved,
    required this.isPartner,
    required this.onSave,
    required this.onTap,
    this.intake,
  });

  final String name;
  final String? institution;
  final String level;
  final String tuition;
  final String language;
  final String duration;
  final String flag;
  final bool saved;
  final bool isPartner;
  final VoidCallback onSave;
  final VoidCallback onTap;

  /// La ligne des rentrées ([ProgramIntakeLine]), ou null.
  final Widget? intake;

  @override
  Widget build(BuildContext context) {
    final displayedTuition = TuitionUtils.tuitionForDisplay(
      tuition,
      Get.find<AppController>().profile?.preferredCurrency,
    );

    return KpbCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.kpb.surfaceBg,
              borderRadius: KpbRadius.mdBr,
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KpbTextStyles.titleMd, maxLines: 2),
                if (institution != null) ...[
                  const SizedBox(height: 3),
                  Text(institution!, style: KpbTextStyles.caption),
                ],
                if (intake != null) ...[
                  const SizedBox(height: 6),
                  intake!,
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isPartner)
                      KpbBadgeLight(
                        label: 'catalog_partner_badge'.tr,
                        bgColor: KpbColors.skyLight,
                        textColor: KpbColors.blue,
                      ),
                    KpbBadgeLight(label: level),
                    KpbBadgeLight(label: duration),
                    KpbBadgeLight(label: language),
                    KpbBadgeLight(
                      label: displayedTuition,
                      bgColor: KpbColors.goldLight,
                      textColor: KpbColors.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'm6_see_details'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.blue,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'a11y_save'.tr,
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? KpbColors.gold : context.kpb.textMuted,
            ),
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
