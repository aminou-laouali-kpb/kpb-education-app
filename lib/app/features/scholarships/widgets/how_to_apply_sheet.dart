import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/models/app_models.dart';
import 'application_steps_timeline.dart';

Future<void> showHowToApplySheet(
  BuildContext context, {
  required String scholarshipTitle,
  required List<ScholarshipApplicationStepModel> steps,
  required VoidCallback? onOpenOfficialForm,
  // Faux hors période : le bouton reste (choix testé, #360) mais dit que les
  // candidatures ne sont pas encore ouvertes (audit build 57, T3-08).
  bool applicationsOpen = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        maxChildSize: 0.94,
        minChildSize: 0.42,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Semantics(
              header: true,
              child: Text(
                'live_scholarships_section_application_steps'.tr,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scholarshipTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KpbColors.textMuted,
                  ),
            ),
            const SizedBox(height: 20),
            if (steps.isEmpty)
              Text('scholarship_how_to_apply_unavailable'.tr)
            else
              ApplicationStepsTimeline(
                steps: steps,
                accent: KpbColors.actionPrimary,
              ),
            if (onOpenOfficialForm != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenOfficialForm();
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text('live_scholarships_official_form'.tr),
              ),
              if (!applicationsOpen) ...[
                const SizedBox(height: 8),
                Text(
                  'live_scholarships_not_open_note'.tr,
                  key: const ValueKey<String>('how-to-apply-not-open-note'),
                  textAlign: TextAlign.center,
                  style: KpbTextStyles.caption,
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
