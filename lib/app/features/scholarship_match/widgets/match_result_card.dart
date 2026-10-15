import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/scholarship_match.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/country_utils.dart';
import '../../scholarships/widgets/follow_scholarship_button.dart';
import '../match_format.dart';
import 'official_condition_expander.dart';

/// Une bourse du test : nom, pays, financement, fenêtre, statut en TEXTE,
/// au plus 3 raisons servies, les points à vérifier (avec la condition
/// officielle), et les actions.
///
/// Pas d'animation en cascade, texte ≥ 12 sp, cibles ≥ 48 dp.
class MatchResultCard extends StatelessWidget {
  const MatchResultCard({
    super.key,
    required this.item,
    required this.now,
    required this.online,
    this.showSuccessLab = false,
    this.onOpen,
    this.onCase,
    this.onSuccessLab,
    this.onWhatsApp,
    this.onFollowChanged,
  });

  final MatchItem item;
  final DateTime now;

  /// Hors ligne : les actions réseau sont désactivées et le disent.
  final bool online;
  final bool showSuccessLab;
  final VoidCallback? onOpen;
  final VoidCallback? onCase;
  final VoidCallback? onSuccessLab;
  final VoidCallback? onWhatsApp;
  final ValueChanged<bool>? onFollowChanged;

  @override
  Widget build(BuildContext context) {
    final card = item.scholarship;
    final available = item.available;
    final window = matchWindowLabel(item.window, now);
    final compatible = item.isCompatible;
    final statusText = compatible
        ? 'scholarship_match_status_compatible'.tr
        : 'scholarship_match_status_to_verify'.tr;
    final statusColor = compatible ? KpbColors.success : KpbColors.warning;
    final statusBg =
        compatible ? KpbColors.successLight : KpbColors.warningLight;
    final countryLine = <String>[
      if (card?.countryName != null) card!.countryName!,
      if (card?.levelLabel != null) card!.levelLabel!,
    ].join(' · ');

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                countryFlag(card?.countryId ?? ''),
                style: KpbTextStyles.title,
              ),
            ),
            const SizedBox(width: KpbSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      item.name,
                      style: KpbTextStyles.titleMd.copyWith(
                        color: available
                            ? KpbColors.brandNavy
                            : KpbColors.textSecondary,
                      ),
                    ),
                  ),
                  if (countryLine.isNotEmpty)
                    Text(
                      countryLine,
                      style: KpbTextStyles.caption.copyWith(
                        color: KpbColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KpbSpacing.sm),
        Wrap(
          spacing: KpbSpacing.xs,
          runSpacing: KpbSpacing.xs,
          children: [
            _Pill(
              key: ValueKey<String>('match-status-${item.scholarshipId}'),
              text: available ? statusText : 'scholarship_match_unavailable'.tr,
              semantics: available
                  ? 'scholarship_match_status_a11y'
                      .trParams({'status': statusText})
                  : 'scholarship_match_unavailable'.tr,
              color: available ? statusColor : KpbColors.textSecondary,
              background: available ? statusBg : KpbColors.surfaceMuted,
            ),
            if (item.isNew && available)
              _Pill(
                key: ValueKey<String>('match-new-${item.scholarshipId}'),
                text: 'scholarship_match_new'.tr,
                semantics: 'scholarship_match_new'.tr,
                color: KpbColors.actionPrimary,
                background: KpbColors.actionPrimarySoft,
              ),
            if (available && card?.fundingLabel != null)
              _Pill(
                text: card!.fundingLabel!,
                semantics: card.fundingLabel!,
                color: KpbColors.textPrimary,
                background: KpbColors.surfaceMuted,
              ),
            if (available && window != null)
              _Pill(
                key: ValueKey<String>('match-window-${item.scholarshipId}'),
                text: window.$1,
                semantics: 'scholarship_match_window_a11y'
                    .trParams({'window': window.$1}),
                color: switch (window.$2) {
                  MatchWindowTone.open => KpbColors.success,
                  MatchWindowTone.upcoming => KpbColors.actionPrimary,
                  MatchWindowTone.closed => KpbColors.error,
                  MatchWindowTone.neutral => KpbColors.textSecondary,
                },
                background: KpbColors.surface,
                bordered: true,
              ),
          ],
        ),
        if (available) ...[
          if (item.reasons.isNotEmpty) const SizedBox(height: KpbSpacing.sm),
          for (final reason in item.reasons.take(3))
            _Point(
              icon: Icons.check_circle_rounded,
              color: KpbColors.success,
              text: reason.label,
            ),
          for (final point in item.toVerify) ...[
            _Point(
              icon: Icons.warning_amber_rounded,
              color: KpbColors.warning,
              text: point.label,
            ),
            if (point.official != null)
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: OfficialConditionExpander(official: point.official!),
              ),
          ],
          const SizedBox(height: KpbSpacing.xs),
          Wrap(
            spacing: KpbSpacing.xs,
            runSpacing: KpbSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FollowScholarshipButton(
                scholarshipId: item.scholarshipId,
                scholarshipTitle: item.name,
                onChanged: onFollowChanged,
              ),
              TextButton(
                key: ValueKey<String>('match-case-${item.scholarshipId}'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: online ? onCase : null,
                child: Text(
                  online
                      ? 'scholarship_match_case_cta'.tr
                      : 'scholarship_match_needs_connection'.tr,
                ),
              ),
              if (showSuccessLab && online)
                TextButton(
                  key: ValueKey<String>(
                    'match-success-lab-${item.scholarshipId}',
                  ),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onSuccessLab,
                  child: Text('scholarship_match_success_lab_cta'.tr),
                ),
              IconButton(
                key: ValueKey<String>('match-whatsapp-${item.scholarshipId}'),
                tooltip: 'scholarship_match_whatsapp_a11y'
                    .trParams({'title': item.name}),
                icon: const Icon(Icons.chat_rounded, color: KpbColors.success),
                onPressed: onWhatsApp,
              ),
            ],
          ),
        ],
      ],
    );

    return Container(
      key: ValueKey<String>('match-item-${item.scholarshipId}'),
      margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
      decoration: BoxDecoration(
        color: available ? KpbColors.surface : KpbColors.surfaceMuted,
        borderRadius: BorderRadius.circular(KpbRadius.md),
        border: Border.all(color: KpbColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          onTap: available ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.all(KpbSpacing.md),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.text,
    required this.semantics,
    required this.color,
    required this.background,
    this.bordered = false,
  });

  final String text;
  final String semantics;
  final Color color;
  final Color background;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.sm,
          vertical: KpbSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(KpbRadius.pill),
          border:
              bordered ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        ),
        child: Text(
          text,
          style: KpbTextStyles.label.copyWith(color: color),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: KpbTextStyles.bodySm.copyWith(
                color: KpbColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
