import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/scholarship_match.dart';
import '../../../core/ui/app_tokens.dart';
import '../scholarship_match_flow_controller.dart';
import '../widgets/match_choice.dart';
import 'match_steps.dart';

/// « Vérifie tes infos » : une ligne par valeur utilisée, chacune avec
/// « Modifier ». La RÉSIDENCE y figure : une règle de résidence peut exclure.
/// Les compléments facultatifs sont marqués « améliore la précision ».
class MatchRecapStep extends StatelessWidget {
  const MatchRecapStep({super.key, required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final options = c.state.options;
    String? country(String key) {
      final code = c.value<String>(key);
      return code == null ? null : (options.countryName(code) ?? code);
    }

    final nationality = country(MatchDraftKey.nationalityCode);
    final second = country(MatchDraftKey.secondNationalityCode);
    final iso = c.value<String>(MatchDraftKey.birthDate);
    final parts = iso?.split('-');
    final birth = parts == null || parts.length != 3
        ? null
        : '${parts[2]}/${parts[1]}/${parts[0]}';
    String? token(String family, String key) {
      final v = c.value<String>(key);
      return v == null ? null : matchTokenLabel(family, v);
    }

    final fieldIds = c.stringList(MatchDraftKey.fieldIds);
    final fields = fieldIds.isNotEmpty
        ? fieldIds.map((id) => options.fieldName(id) ?? id).join(', ')
        : c.isAnswered(MatchReadinessKey.fields)
            ? 'scholarship_match_fields_undecided'.tr
            : null;
    final english = token('lang', MatchDraftKey.englishLevel);
    final french = token('lang', MatchDraftKey.frenchLevel);
    final destinations = c
        .stringList(MatchDraftKey.targetCountryIds)
        .map((id) => options.destinationName(id) ?? id)
        .join(', ');
    final tests = c.languageTests
        .map((t) => 'scholarship_match_test_value'.trParams({
              'test': matchTokenLabel('test', t.type),
              'score': matchScoreText(t.score),
            }))
        .join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.page,
        KpbSpacing.md,
        KpbSpacing.page,
        KpbSpacing.lg,
      ),
      children: [
        MatchQuestionHeader(
          title: 'scholarship_match_recap_title'.tr,
          help: 'scholarship_match_recap_help'.tr,
        ),
        _RecapRow(
          rowKey: 'nationality',
          label: 'scholarship_match_recap_nationality'.tr,
          value: nationality == null
              ? null
              : second == null
                  ? nationality
                  : '$nationality, $second',
          onEdit: () => c.edit(MatchReadinessKey.nationalityCode),
        ),
        _RecapRow(
          rowKey: 'residence',
          label: 'scholarship_match_recap_residence'.tr,
          value: country(MatchDraftKey.residence),
          onEdit: () => c.edit(MatchReadinessKey.residence),
        ),
        _RecapRow(
          rowKey: 'birth_date',
          label: 'scholarship_match_recap_birth_date'.tr,
          value: c.isAnswered(MatchReadinessKey.birthDate) ? birth : null,
          onEdit: () => c.edit(MatchReadinessKey.birthDate),
        ),
        if (c.needsGuardian)
          _RecapRow(
            rowKey: 'guardian',
            label: 'minor_guardian_title'.tr,
            value: c.isAnswered(MatchReadinessKey.guardianConsent)
                ? 'scholarship_match_recap_guardian_done'.tr
                : null,
            onEdit: () => c.edit(MatchReadinessKey.guardianConsent),
          ),
        _RecapRow(
          rowKey: 'diploma',
          label: 'scholarship_match_recap_diploma'.tr,
          value: token('diploma', MatchDraftKey.highestDiploma),
          onEdit: () => c.edit(MatchReadinessKey.highestDiploma),
        ),
        _RecapRow(
          rowKey: 'target',
          label: 'scholarship_match_recap_target'.tr,
          value: c.isAnswered(MatchReadinessKey.scholarshipTargetLevel)
              ? token('target', MatchDraftKey.scholarshipTargetLevel)
              : null,
          onEdit: () => c.edit(MatchReadinessKey.scholarshipTargetLevel),
        ),
        _RecapRow(
          rowKey: 'fields',
          label: 'scholarship_match_recap_fields'.tr,
          value: fields,
          onEdit: () => c.edit(MatchReadinessKey.fields),
        ),
        _RecapRow(
          rowKey: 'grade',
          label: 'scholarship_match_recap_grade'.tr,
          value: token('grade', MatchDraftKey.gradeBandOn20),
          onEdit: () => c.edit(MatchReadinessKey.gradeBandOn20),
        ),
        _RecapRow(
          rowKey: 'language',
          label: 'scholarship_match_recap_english'.tr,
          value: english == null
              ? null
              : french == null
                  ? english
                  : '$english · ${'scholarship_match_recap_french'.trParams({
                          'level': french
                        })}',
          onEdit: () => c.edit(MatchReadinessKey.englishLevel),
        ),
        if (c.needsExperience)
          _RecapRow(
            rowKey: 'experience',
            label: 'scholarship_match_recap_experience'.tr,
            value: token('exp', MatchDraftKey.workExperienceBand),
            onEdit: () => c.edit(MatchReadinessKey.workExperienceBand),
          ),
        const SizedBox(height: KpbSpacing.md),
        Semantics(
          header: true,
          child: Text(
            'scholarship_match_recap_boosters'.tr,
            style: KpbTextStyles.titleSm,
          ),
        ),
        const SizedBox(height: KpbSpacing.xs),
        _RecapRow(
          rowKey: 'destinations',
          label: 'scholarship_match_recap_destinations'.tr,
          value: destinations.isEmpty ? null : destinations,
          optional: true,
          onEdit: () async {
            final picked = await showMatchDestinationsSheet(
              context,
              options: options.destinations,
              selected: c.stringList(MatchDraftKey.targetCountryIds),
            );
            if (picked != null) c.set(MatchDraftKey.targetCountryIds, picked);
          },
        ),
        _RecapRow(
          rowKey: 'tests',
          label: 'scholarship_match_recap_test'.tr,
          value: tests.isEmpty ? null : tests,
          optional: true,
          onEdit: () async {
            final test = await showMatchLanguageTestSheet(context);
            if (test != null) c.putLanguageTest(test);
          },
        ),
        const SizedBox(height: KpbSpacing.md),
        // Consentement explicite à l'usage de la nationalité (décision du
        // propriétaire, 18/10/2026) : sans la case, rien ne s'envoie.
        CheckboxListTile(
          key: const ValueKey<String>('match-nationality-consent'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: c.nationalityConsented,
          title: Text(
            'scholarship_match_nationality_consent'.tr,
            style: KpbTextStyles.bodySm,
          ),
          subtitle: Text(
            'scholarship_match_nationality_consent_help'.tr,
            style: KpbTextStyles.caption.copyWith(
              color: KpbColors.textSecondary,
            ),
          ),
          onChanged: (v) =>
              c.set(MatchDraftKey.nationalityConsent, v == true ? true : null),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.onEdit,
    this.optional = false,
  });

  final String rowKey;
  final String label;
  final String? value;
  final VoidCallback onEdit;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final missing = value == null;
    final shown = value ??
        (optional
            ? 'scholarship_match_recap_improves_precision'.tr
            : 'scholarship_match_recap_missing'.tr);
    final color = missing && !optional
        ? KpbColors.error
        : missing
            ? KpbColors.textSecondary
            : KpbColors.textPrimary;
    return Container(
      key: ValueKey<String>('match-recap-$rowKey'),
      padding: const EdgeInsets.symmetric(vertical: KpbSpacing.xs),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KpbColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '$label : $shown',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: KpbTextStyles.caption.copyWith(
                      color: KpbColors.textSecondary,
                    ),
                  ),
                  Text(
                    shown,
                    style: KpbTextStyles.bodySm.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            key: ValueKey<String>('match-recap-edit-$rowKey'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onEdit,
            child: Semantics(
              label: 'scholarship_match_recap_edit_a11y'
                  .trParams({'field': label}),
              excludeSemantics: true,
              child: Text(
                missing && !optional
                    ? 'scholarship_match_recap_fill'.tr
                    : 'scholarship_match_recap_edit'.tr,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Pays visés » : les destinations du catalogue (`options.destinations`),
/// pas les neuf de l'onboarding. Rend la sélection, ou `null`.
Future<List<String>?> showMatchDestinationsSheet(
  BuildContext context, {
  required List<MatchNamedOption> options,
  required List<String> selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KpbColors.surface,
    builder: (_) => _DestinationsSheet(options: options, selected: selected),
  );
}

class _DestinationsSheet extends StatefulWidget {
  const _DestinationsSheet({required this.options, required this.selected});

  final List<MatchNamedOption> options;
  final List<String> selected;

  @override
  State<_DestinationsSheet> createState() => _DestinationsSheetState();
}

class _DestinationsSheetState extends State<_DestinationsSheet> {
  late final Set<String> _chosen = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.page,
            KpbSpacing.md,
            KpbSpacing.page,
            KpbSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MatchQuestionHeader(
                title: 'scholarship_match_recap_destinations'.tr,
                help: 'scholarship_match_recap_improves_precision'.tr,
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final option in widget.options)
                      MatchChoice(
                        key: ValueKey<String>('match-destination-${option.id}'),
                        label: option.name,
                        multiple: true,
                        selected: _chosen.contains(option.id),
                        onTap: () => setState(() {
                          if (!_chosen.remove(option.id)) {
                            _chosen.add(option.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              FilledButton(
                key: const ValueKey<String>('match-destinations-apply'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).pop(
                  widget.options
                      .map((o) => o.id)
                      .where(_chosen.contains)
                      .toList(),
                ),
                child: Text('scholarship_match_apply'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
