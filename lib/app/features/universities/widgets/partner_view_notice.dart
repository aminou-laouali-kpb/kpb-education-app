import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui/kpb_components.dart';
import 'partner_view_notice_store.dart';

/// Où en est l'avis « vue Partenaires » de l'écran Universités.
///
/// ## Le parcours choisi (décision du propriétaire du 17/10/2026)
///
/// La vue reste sur « Partenaires » par défaut ; il faut seulement que
/// l'existence de « Tous » soit évidente, sans modale bloquante.
///
///  * [full] — tant que l'élève n'a pas fermé l'avis : la carte complète, avec
///    le texte du propriétaire et « Voir toutes les universités » ;
///  * [reminder] — avis fermé, mais « Tous » jamais ouvert : une seule ligne
///    discrète, « Tu vois seulement les universités partenaires. Voir tout ».
///    Fermer l'avis ne prouve pas qu'on a compris qu'il existe autre chose ;
///  * [hidden] — dès que l'élève a ouvert « Tous » une fois : plus rien. Il
///    sait que l'onglet existe, et le sélecteur reste visible en permanence.
///
/// Pendant la lecture du stockage local ([loading]), rien ne s'affiche (un
/// instant) plutôt qu'une carte qui disparaîtrait aussitôt.
enum PartnerNoticeStage { loading, full, reminder, hidden }

PartnerNoticeStage partnerNoticeStageFor(PartnerViewNoticeMemory memory) {
  if (memory.allViewOpened) return PartnerNoticeStage.hidden;
  if (memory.dismissed) return PartnerNoticeStage.reminder;
  return PartnerNoticeStage.full;
}

/// Le sélecteur « Partenaires | Tous », toujours visible en tête de liste, avec
/// le nombre de formations de chaque vue (filtres actifs compris).
///
/// Avant, le choix vivait DANS le panneau « Filtres », replié par défaut : rien
/// à l'écran ne disait qu'il existait d'autres universités que les partenaires.
class UniversityViewSwitcher extends StatelessWidget {
  const UniversityViewSwitcher({
    super.key,
    required this.partnerOnly,
    required this.partnerCount,
    required this.allCount,
    required this.onChanged,
  });

  final bool partnerOnly;
  final int partnerCount;
  final int allCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('university_view_switcher'),
      container: true,
      label: 'uni_view_switch_label'.tr,
      child: Container(
        padding: const EdgeInsets.all(KpbSpacing.xs),
        decoration: const BoxDecoration(
          color: KpbColors.surfaceMuted,
          borderRadius: KpbRadius.smBr,
        ),
        // Deux segments de même hauteur, même quand l'un passe sur deux
        // lignes à grande échelle de texte.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Segment(
                  key: const ValueKey('university_view_partners'),
                  label: 'uni_view_partners'.tr,
                  count: partnerCount,
                  icon: Icons.verified_rounded,
                  selected: partnerOnly,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: KpbSpacing.xs),
              Expanded(
                child: _Segment(
                  key: const ValueKey('university_view_all'),
                  label: 'uni_view_all'.tr,
                  count: allCount,
                  icon: Icons.public_rounded,
                  selected: !partnerOnly,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motion = KpbMotion.of(context);
    final fg = selected ? KpbColors.actionPrimary : KpbColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: 'uni_view_count_semantics'
          .trParams({'label': label, 'count': '$count'}),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: KpbRadius.xsBr,
          child: AnimatedContainer(
            duration: motion.fast,
            curve: motion.curve,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected ? KpbColors.surface : Colors.transparent,
              borderRadius: KpbRadius.xsBr,
              border: Border.all(
                color: selected
                    ? KpbColors.actionPrimary.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: KpbShadow.softNavy,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : const [],
            ),
            alignment: Alignment.center,
            // `Wrap` : à l'échelle de texte 1,5 le compteur passe sous le
            // libellé au lieu de le couper.
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Icon(icon, size: 16, color: fg),
                Text(
                  label,
                  style: KpbTextStyles.titleSm.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? KpbColors.actionPrimarySoft
                        : KpbColors.surface,
                    borderRadius: KpbRadius.pillBr,
                  ),
                  child: Text(
                    '$count',
                    style: KpbTextStyles.caption.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// L'avis lui-même : la carte complète, la ligne de rappel, ou rien — voir
/// [PartnerNoticeStage]. Ne s'affiche que sur la vue « Partenaires ».
class PartnerViewNotice extends StatelessWidget {
  const PartnerViewNotice({
    super.key,
    required this.stage,
    required this.onShowAll,
    required this.onDismiss,
  });

  final PartnerNoticeStage stage;
  final VoidCallback onShowAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final motion = KpbMotion.of(context);
    final Widget child = switch (stage) {
      PartnerNoticeStage.full => _FullNotice(
          onShowAll: onShowAll,
          onDismiss: onDismiss,
        ),
      PartnerNoticeStage.reminder => _Reminder(onShowAll: onShowAll),
      PartnerNoticeStage.loading ||
      PartnerNoticeStage.hidden =>
        const SizedBox(width: double.infinity),
    };
    // Le passage carte → rappel → rien se fait en douceur (et sans animation
    // quand le système ou l'économiseur de données les coupe).
    return AnimatedSize(
      duration: motion.base,
      curve: motion.curve,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _FullNotice extends StatelessWidget {
  const _FullNotice({required this.onShowAll, required this.onDismiss});

  final VoidCallback onShowAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bodyStyle =
        KpbTextStyles.bodySm.copyWith(color: KpbColors.textPrimary);
    return Container(
      key: const ValueKey('partner_view_notice'),
      margin: const EdgeInsets.only(top: KpbSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
          KpbSpacing.md, KpbSpacing.sm, KpbSpacing.xs, KpbSpacing.sm),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        borderRadius: KpbRadius.smBr,
        border: Border.all(
          color: KpbColors.actionPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.verified_rounded,
                    size: 18, color: KpbColors.actionPrimary),
              ),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'uni_partner_notice_title'.tr,
                    style: KpbTextStyles.titleSm.copyWith(
                      color: KpbColors.brandNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('partner_view_notice_close'),
                onPressed: onDismiss,
                tooltip: 'uni_partner_notice_close'.tr,
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: KpbColors.textSecondary),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: KpbSpacing.sm),
            // Un seul paragraphe, lu d'un bloc par TalkBack ; la mise en garde
            // du propriétaire en gras, au milieu, jamais séparable du reste.
            child: Text.rich(
              key: const ValueKey('partner_view_notice_body'),
              TextSpan(
                style: bodyStyle,
                children: [
                  TextSpan(text: 'uni_partner_notice_body'.tr),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: 'uni_partner_notice_caveat'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(text: 'uni_partner_notice_switch_hint'.tr),
                ],
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.xs),
          KpbButton(
            key: const ValueKey('partner_view_notice_show_all'),
            variant: KpbButtonVariant.tertiary,
            icon: Icons.public_rounded,
            label: 'uni_partner_notice_cta'.tr,
            onPressed: onShowAll,
          ),
        ],
      ),
    );
  }
}

class _Reminder extends StatelessWidget {
  const _Reminder({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('partner_view_reminder'),
      padding: const EdgeInsets.only(top: KpbSpacing.xs),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.info_outline_rounded,
                size: 16, color: KpbColors.textMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'uni_partner_reminder'.tr,
              style: KpbTextStyles.caption.copyWith(
                color: KpbColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('partner_view_reminder_show_all'),
            onPressed: onShowAll,
            child: Text('uni_partner_reminder_cta'.tr),
          ),
        ],
      ),
    );
  }
}
