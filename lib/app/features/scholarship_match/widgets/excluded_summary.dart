import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/scholarship_match.dart';
import '../../../core/ui/app_tokens.dart';

/// « Pourquoi certaines bourses n'apparaissent pas (N) » : des comptes par
/// groupe, servis et déjà rédigés par le serveur ; chaque groupe se déplie sur
/// les noms (20 au plus) et « Signaler une erreur ».
class MatchExcludedSummaryView extends StatelessWidget {
  const MatchExcludedSummaryView({
    super.key,
    required this.summary,
    required this.onReport,
  });

  final MatchExcludedSummary summary;

  /// « Signaler une erreur » sur un groupe (WhatsApp).
  final ValueChanged<MatchExcludedGroup> onReport;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();
    final total = summary.excludedCount;
    // Un Material (et non une boîte décorée) : les tuiles y peignent leur
    // effet d'appui.
    return Material(
      key: const ValueKey<String>('match-excluded-summary'),
      color: KpbColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        side: const BorderSide(color: KpbColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey<String>('match-excluded-tile'),
          minTileHeight: 48,
          title: Text(
            'scholarship_match_excluded_title'.trParams({'count': '$total'}),
            style: KpbTextStyles.titleSm,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            KpbSpacing.md,
            0,
            KpbSpacing.md,
            KpbSpacing.md,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final group in summary.groups)
              ExpansionTile(
                key: ValueKey<String>('match-excluded-${group.group}'),
                minTileHeight: 48,
                tilePadding: EdgeInsets.zero,
                title: Text(group.label, style: KpbTextStyles.bodySm),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in group.scholarships)
                    Padding(
                      padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
                      child: Text(
                        '• ${s.name}',
                        style: KpbTextStyles.bodySm.copyWith(
                          color: KpbColors.textSecondary,
                        ),
                      ),
                    ),
                  TextButton.icon(
                    key: ValueKey<String>(
                        'match-excluded-report-${group.group}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => onReport(group),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: Text('scholarship_match_excluded_report'.tr),
                  ),
                ],
              ),
            if (summary.notAnalyzedLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: KpbSpacing.xs),
                child: Text(
                  summary.notAnalyzedLabel!,
                  key: const ValueKey<String>('match-not-analyzed'),
                  style: KpbTextStyles.bodySm.copyWith(
                    color: KpbColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
