import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/live_scholarships_query.dart';
import '../../../core/ui/kpb_components.dart';

/// La feuille « Filtrer » de la liste des bourses, et celle du tri.
///
/// Même patron que les filtres « Études en France » (`eef_catalog_filters`) :
/// l'élève coche dans un BROUILLON, et rien ne part avant « Voir les bourses »
/// — une seule requête, quel que soit le nombre de cases. Fermer la feuille
/// (balayage, retour, fond) ne change rien. Le widget d'EEF n'est pas réutilisé
/// tel quel : il est lié à son contrôleur de catalogue (facettes comptées par le
/// serveur, recherche de villes), et nos deux familles tiennent en sept cases.

/// Ce que la feuille « Filtrer » rend quand l'élève valide.
@immutable
class ScholarshipFilterChoice {
  const ScholarshipFilterChoice({
    required this.statuses,
    required this.funding,
  });

  final Set<ScholarshipListStatus> statuses;

  /// `all` | `fully_funded` | `partially_funded`.
  final String funding;
}

const _fundingOptions = <String>['all', 'fully_funded', 'partially_funded'];

String _statusLabelKey(ScholarshipListStatus status) => switch (status) {
      ScholarshipListStatus.open => 'scholarships_filter_status_open',
      ScholarshipListStatus.upcoming => 'scholarships_filter_status_upcoming',
      ScholarshipListStatus.forecast => 'scholarships_filter_status_forecast',
    };

String _fundingLabelKey(String funding) => switch (funding) {
      'fully_funded' => 'live_scholarships_filter_fully_funded',
      'partially_funded' => 'live_scholarships_filter_partially_funded',
      _ => 'live_scholarships_filter_all',
    };

/// Le libellé d'un tri (« Clôture la plus proche »…).
String scholarshipSortLabel(ScholarshipListSort sort) => switch (sort) {
      ScholarshipListSort.relevance => 'scholarships_sort_relevance'.tr,
      ScholarshipListSort.deadline => 'scholarships_sort_deadline'.tr,
      ScholarshipListSort.verified => 'scholarships_sort_verified'.tr,
      ScholarshipListSort.title => 'scholarships_sort_title'.tr,
    };

/// Ouvre la feuille « Filtrer » ; `null` = fermée sans valider.
Future<ScholarshipFilterChoice?> showScholarshipFilterSheet(
  BuildContext context, {
  required Set<ScholarshipListStatus> statuses,
  required String funding,
}) {
  return showModalBottomSheet<ScholarshipFilterChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ScholarshipFilterSheet(
      initialStatuses: statuses,
      initialFunding: funding,
    ),
  );
}

/// Ouvre la feuille du tri ; `null` = fermée sans choisir.
Future<ScholarshipListSort?> showScholarshipSortSheet(
  BuildContext context, {
  required ScholarshipListSort current,
}) {
  return showModalBottomSheet<ScholarshipListSort>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        key: const ValueKey<String>('scholarships-sort-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitle('scholarships_sort_sheet_title'.tr),
          for (final sort in ScholarshipListSort.values)
            _ChoiceRow(
              key: ValueKey<String>('scholarships-sort-${sort.wire}'),
              label: scholarshipSortLabel(sort),
              selected: sort == current,
              radio: true,
              onTap: () {
                KpbHaptics.selection();
                Navigator.of(sheetContext).pop(sort);
              },
            ),
          const SizedBox(height: KpbSpacing.md),
        ],
      ),
    ),
  );
}

class _ScholarshipFilterSheet extends StatefulWidget {
  const _ScholarshipFilterSheet({
    required this.initialStatuses,
    required this.initialFunding,
  });

  final Set<ScholarshipListStatus> initialStatuses;
  final String initialFunding;

  @override
  State<_ScholarshipFilterSheet> createState() =>
      _ScholarshipFilterSheetState();
}

class _ScholarshipFilterSheetState extends State<_ScholarshipFilterSheet> {
  late final Set<ScholarshipListStatus> _statuses =
      Set<ScholarshipListStatus>.of(widget.initialStatuses);
  late String _funding = widget.initialFunding;

  bool get _hasDraft => _statuses.isNotEmpty || _funding != 'all';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      key: const ValueKey<String>('scholarships-filter-sheet'),
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _SheetTitle('scholarships_filter_title'.tr)),
              if (_hasDraft)
                Padding(
                  padding: const EdgeInsets.only(right: KpbSpacing.sm),
                  child: TextButton(
                    key: const ValueKey<String>('scholarships-filter-clear'),
                    onPressed: () => setState(() {
                      _statuses.clear();
                      _funding = 'all';
                    }),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text('scholarships_filter_clear'.tr),
                  ),
                ),
            ],
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _SectionLabel('scholarships_filter_status_section'.tr),
                for (final status in ScholarshipListStatus.values)
                  _ChoiceRow(
                    key: ValueKey<String>(
                      'scholarships-filter-status-${status.wire}',
                    ),
                    label: _statusLabelKey(status).tr,
                    selected: _statuses.contains(status),
                    onTap: () => setState(() {
                      if (!_statuses.remove(status)) _statuses.add(status);
                    }),
                  ),
                _SectionLabel('scholarships_filter_funding_section'.tr),
                for (final funding in _fundingOptions)
                  _ChoiceRow(
                    key: ValueKey<String>(
                      'scholarships-filter-funding-$funding',
                    ),
                    label: _fundingLabelKey(funding).tr,
                    selected: _funding == funding,
                    radio: true,
                    onTap: () => setState(() => _funding = funding),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KpbSpacing.pagePad,
                KpbSpacing.sm,
                KpbSpacing.pagePad,
                KpbSpacing.md,
              ),
              child: FilledButton(
                key: const ValueKey<String>('scholarships-filter-apply'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  KpbHaptics.confirm();
                  Navigator.of(context).pop(
                    ScholarshipFilterChoice(
                      statuses: Set<ScholarshipListStatus>.of(_statuses),
                      funding: _funding,
                    ),
                  );
                },
                child: Text('scholarships_filter_apply'.tr),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        0,
        KpbSpacing.pagePad,
        KpbSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: KpbTextStyles.title.copyWith(color: context.kpb.textPrimary),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        KpbSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: KpbTextStyles.bodySm.copyWith(
            color: context.kpb.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Une option : case (ou bouton radio) et libellé. La ligne entière est la
/// cible tactile, 48 dp au moins, un seul arrêt de focus.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.radio = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final color = selected ? KpbColors.actionPrimary : c.textSecondary;
    final icon = radio
        ? (selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded)
        : (selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded);
    return Semantics(
      container: true,
      checked: radio ? null : selected,
      inMutuallyExclusiveGroup: radio ? true : null,
      selected: radio ? selected : null,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: KpbSpacing.xs,
                    ),
                    child: Text(
                      label,
                      style: KpbTextStyles.body.copyWith(color: c.textPrimary),
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
