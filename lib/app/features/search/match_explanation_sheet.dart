import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/profile_fit_badge.dart';
import '../../core/ui/kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Match explanation bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
void showMatchExplanation(
  BuildContext context,
  String title,
  ProfileFit? fit,
  List<String> reasons,
  AppController controller,
) {
  // `isScrollControlled` + défilement : sans eux, la feuille était plafonnée à
  // 9/16 de l'écran et la colonne rognée en bas — le seul bouton d'action,
  // « Améliorer mon profil », disparaissait sur un iPhone SE ou au texte
  // agrandi, sans aucun moyen de l'atteindre.
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: KpbSpacing.md),
              decoration: BoxDecoration(
                color: context.kpb.gray200,
                borderRadius: KpbRadius.pillBr,
              ),
            ),
            // Qualitative fit (no badge without a profile — the reasons then
            // invite the student to complete it).
            if (fit != null) ...[
              ProfileFitBadge(fit: fit, fontSize: 15),
              const SizedBox(height: KpbSpacing.md),
            ],
            // Title
            Text(
              title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.kpb.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'match_why_this_match'.tr,
              style: TextStyle(fontSize: 13, color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.lg),
            // Reasons
            ...reasons.map((reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: KpbColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                              fontSize: 14, color: context.kpb.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: KpbSpacing.md),
            // CTA
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Get.back();
                  controller.goToTab(StudentShellTab.profile);
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text('improve_profile'.tr),
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
          ],
        ),
      ),
    ),
  );
}
