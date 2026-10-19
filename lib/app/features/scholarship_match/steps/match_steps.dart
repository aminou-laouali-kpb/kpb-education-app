import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/models/scholarship_match.dart';
import '../../../core/ui/app_tokens.dart';
import '../../legal/legal_pages.dart';
import '../scholarship_match_flow_controller.dart';
import '../widgets/match_choice.dart';
import '../widgets/match_country_list.dart';

/// Le libellé d'un jeton de réponse (« b1 » → « Je me débrouille (B1) »).
String matchTokenLabel(String family, String token) =>
    'scholarship_match_${family}_$token'.tr;

/// Une question de l'assistant (ou l'accueil), selon sa clé.
class MatchStepView extends StatelessWidget {
  const MatchStepView({
    super.key,
    required this.controller,
    required this.stepKey,
  });

  final ScholarshipMatchFlowController controller;
  final String stepKey;

  @override
  Widget build(BuildContext context) {
    return switch (stepKey) {
      MatchFlowScreen.intro => _IntroStep(controller: controller),
      MatchReadinessKey.nationalityCode =>
        _NationalityStep(controller: controller),
      MatchReadinessKey.birthDate => _BirthDateStep(controller: controller),
      MatchReadinessKey.guardianConsent =>
        _GuardianStep(controller: controller),
      MatchReadinessKey.highestDiploma => _TokenStep(
          controller: controller,
          title: 'scholarship_match_q_diploma'.tr,
          family: 'diploma',
          valueKey: MatchDraftKey.highestDiploma,
          tokens: MatchTokens.diplomas,
        ),
      MatchReadinessKey.scholarshipTargetLevel =>
        _TargetStep(controller: controller),
      MatchReadinessKey.fields => _FieldsStep(controller: controller),
      MatchReadinessKey.gradeBandOn20 => _GradeStep(controller: controller),
      MatchReadinessKey.englishLevel => _LanguageStep(controller: controller),
      MatchReadinessKey.workExperienceBand => _TokenStep(
          controller: controller,
          title: 'scholarship_match_q_experience'.tr,
          help: 'scholarship_match_q_experience_help'.tr,
          family: 'exp',
          valueKey: MatchDraftKey.workExperienceBand,
          tokens: MatchTokens.experienceBands,
        ),
      MatchReadinessKey.residence => _ResidenceStep(controller: controller),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Le cadre défilable commun aux questions à puces.
class _ScrollStep extends StatelessWidget {
  const _ScrollStep({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.page,
        KpbSpacing.md,
        KpbSpacing.page,
        KpbSpacing.lg,
      ),
      children: children,
    );
  }
}

// ── Écran 0 ─────────────────────────────────────────────────────────────────

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.questionCount;
    return _ScrollStep(
      children: [
        const Icon(Icons.travel_explore_rounded,
            size: 48, color: KpbColors.actionPrimary),
        const SizedBox(height: KpbSpacing.md),
        Semantics(
          header: true,
          child: Text(
            'scholarship_match_intro_title'.tr,
            style: KpbTextStyles.headlineSm,
          ),
        ),
        const SizedBox(height: KpbSpacing.sm),
        Text(
          count == 0
              ? 'scholarship_match_intro_body_none'.tr
              : count == 1
                  ? 'scholarship_match_intro_body_one'.tr
                  : 'scholarship_match_intro_body'
                      .trParams({'count': '$count'}),
          style: KpbTextStyles.body,
        ),
        const SizedBox(height: KpbSpacing.lg),
        Container(
          padding: const EdgeInsets.all(KpbSpacing.md),
          decoration: BoxDecoration(
            color: KpbColors.surfaceMuted,
            borderRadius: BorderRadius.circular(KpbRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 20, color: KpbColors.textSecondary),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'scholarship_match_intro_privacy'.tr,
                      style: KpbTextStyles.bodySm,
                    ),
                    TextButton(
                      key: const ValueKey<String>('match-intro-privacy'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () =>
                          Get.to<void>(() => const PrivacyPolicyScreen()),
                      child: Text('scholarship_match_intro_privacy_link'.tr),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Nationalité ─────────────────────────────────────────────────────────────

class _NationalityStep extends StatelessWidget {
  const _NationalityStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    final options = controller.state.options;
    final selected = controller.value<String>(MatchDraftKey.nationalityCode);
    final second =
        controller.value<String>(MatchDraftKey.secondNationalityCode);
    final prefill = controller.prefillFor(MatchReadinessKey.nationalityCode);
    final suggested =
        prefill == null ? null : options.countryName(prefill.value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.page,
        KpbSpacing.md,
        KpbSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MatchQuestionHeader(
            title: 'scholarship_match_q_nationality'.tr,
            // Facultative, et utilisée seulement avec l'accord donné au
            // récapitulatif (case « J'accepte… »).
            help: '${'scholarship_match_q_nationality_help'.tr} '
                '${'scholarship_match_nationality_optional'.tr}',
          ),
          if (suggested != null && prefill != null)
            MatchChoice(
              key: const ValueKey<String>('match-nationality-suggestion'),
              label: 'scholarship_match_nationality_suggestion'
                  .trParams({'country': suggested}),
              selected: selected == prefill.value,
              onTap: () =>
                  controller.set(MatchDraftKey.nationalityCode, prefill.value),
            ),
          Expanded(
            child: MatchCountryList(
              searchKey: const ValueKey<String>('match-nationality-search'),
              countries: options.countries,
              selected: selected,
              onSelected: (code) =>
                  controller.set(MatchDraftKey.nationalityCode, code),
            ),
          ),
          TextButton.icon(
            key: const ValueKey<String>('match-second-nationality'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              second == null
                  ? 'scholarship_match_second_nationality'.tr
                  : 'scholarship_match_second_nationality_set'.trParams(
                      {'country': options.countryName(second) ?? second}),
            ),
            onPressed: () async {
              final code = await showMatchCountrySheet(
                context,
                title: 'scholarship_match_second_nationality'.tr,
                countries: options.countries,
                selected: second,
              );
              if (code != null && code != selected) {
                controller.set(MatchDraftKey.secondNationalityCode, code);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Résidence (récapitulatif → « Modifier ») : la même liste servie.
class _ResidenceStep extends StatelessWidget {
  const _ResidenceStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.page,
        KpbSpacing.md,
        KpbSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MatchQuestionHeader(
            title: 'scholarship_match_q_residence'.tr,
            help: 'scholarship_match_q_residence_help'.tr,
          ),
          Expanded(
            child: MatchCountryList(
              countries: controller.state.options.countries,
              selected: controller.value<String>(MatchDraftKey.residence),
              onSelected: (code) =>
                  controller.set(MatchDraftKey.residence, code),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date de naissance ───────────────────────────────────────────────────────

class _BirthDateStep extends StatelessWidget {
  const _BirthDateStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    final iso = controller.value<String>(MatchDraftKey.birthDate);
    final age = controller.age;
    final parts = iso?.split('-');
    final display = parts == null || parts.length != 3
        ? 'birth_date_hint'.tr
        : '${parts[2]}/${parts[1]}/${parts[0]}';
    return _ScrollStep(
      children: [
        MatchQuestionHeader(
          title: 'scholarship_match_q_birth_date'.tr,
          help: 'scholarship_match_q_birth_date_help'.tr,
        ),
        Semantics(
          button: true,
          label: '${'birth_date'.tr} : $display',
          excludeSemantics: true,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('match-birth-date'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(display, style: KpbTextStyles.body),
            onPressed: () async {
              final now = DateTime.now();
              // 16 ans révolus au moins : le serveur n'en accepte pas moins.
              final lastDate = DateTime(now.year - 16, now.month, now.day);
              final current = iso == null ? null : DateTime.tryParse(iso);
              var initial =
                  current ?? DateTime(now.year - 18, now.month, now.day);
              if (initial.isAfter(lastDate)) initial = lastDate;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(now.year - 80),
                lastDate: lastDate,
                helpText: 'birth_date'.tr,
              );
              if (picked != null) {
                controller.set(MatchDraftKey.birthDate, matchIsoDay(picked));
              }
            },
          ),
        ),
        if (age != null && age < 16) ...[
          const SizedBox(height: KpbSpacing.sm),
          Text(
            'onboarding_under_16_body'.tr,
            style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
          ),
        ],
      ],
    );
  }
}

// ── Représentant légal (mineur) ─────────────────────────────────────────────

/// Mêmes textes que l'onboarding (`minor_guardian_*`, `guardian_*`) : un
/// compte créé par « Passer » n'a ni date de naissance ni accord.
class _GuardianStep extends StatefulWidget {
  const _GuardianStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  State<_GuardianStep> createState() => _GuardianStepState();
}

class _GuardianStepState extends State<_GuardianStep> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.value<String>(MatchDraftKey.guardianName) ?? '',
  );
  late final TextEditingController _contact = TextEditingController(
    text: widget.controller.value<String>(MatchDraftKey.guardianContact) ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final consented = c.value<bool>(MatchDraftKey.guardianConsent) == true;
    return _ScrollStep(
      children: [
        MatchQuestionHeader(
          title: 'minor_guardian_title'.tr,
          help: 'minor_guardian_intro'.tr,
        ),
        TextField(
          key: const ValueKey<String>('match-guardian-name'),
          controller: _name,
          decoration: InputDecoration(labelText: 'guardian_name'.tr),
          textInputAction: TextInputAction.next,
          onChanged: (v) => c.set(MatchDraftKey.guardianName, v),
        ),
        const SizedBox(height: KpbSpacing.sm),
        TextField(
          key: const ValueKey<String>('match-guardian-contact'),
          controller: _contact,
          decoration: InputDecoration(labelText: 'guardian_contact'.tr),
          onChanged: (v) => c.set(MatchDraftKey.guardianContact, v),
        ),
        const SizedBox(height: KpbSpacing.sm),
        CheckboxListTile(
          key: const ValueKey<String>('match-guardian-consent'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: consented,
          title: Text(
            'guardian_consent_checkbox'.tr,
            style: KpbTextStyles.bodySm,
          ),
          onChanged: (v) => c.set(MatchDraftKey.guardianConsent, v ?? false),
        ),
      ],
    );
  }
}

// ── Questions à puces ───────────────────────────────────────────────────────

class _TokenStep extends StatelessWidget {
  const _TokenStep({
    required this.controller,
    required this.title,
    required this.family,
    required this.valueKey,
    required this.tokens,
    this.help,
  });

  final ScholarshipMatchFlowController controller;
  final String title;
  final String? help;
  final String family;
  final String valueKey;
  final List<String> tokens;

  @override
  Widget build(BuildContext context) {
    final selected = controller.value<String>(valueKey);
    return _ScrollStep(
      children: [
        MatchQuestionHeader(title: title, help: help),
        for (final token in tokens)
          MatchChoice(
            key: ValueKey<String>('match-$family-$token'),
            label: matchTokenLabel(family, token),
            selected: selected == token,
            onTap: () => controller.set(valueKey, token),
          ),
      ],
    );
  }
}

class _TargetStep extends StatelessWidget {
  const _TargetStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.target;
    final diploma = controller.value<String>(MatchDraftKey.highestDiploma);
    return _ScrollStep(
      children: [
        MatchQuestionHeader(
          title: 'scholarship_match_q_target'.tr,
          help: 'scholarship_match_q_target_help'.tr,
        ),
        for (final level in controller.targetLevelOptions)
          MatchChoice(
            key: ValueKey<String>('match-target-$level'),
            label: matchTokenLabel('target', level),
            selected: selected == level,
            onTap: () =>
                controller.set(MatchDraftKey.scholarshipTargetLevel, level),
          ),
        if (matchTargetNeedsMoreDiploma(selected, diploma))
          Padding(
            padding: const EdgeInsets.only(top: KpbSpacing.sm),
            child: Text(
              'scholarship_match_target_diploma_hint'.tr,
              style: KpbTextStyles.bodySm.copyWith(
                color: KpbColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _FieldsStep extends StatelessWidget {
  const _FieldsStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    final fields = controller.state.options.fields;
    final chosen = controller.stringList(MatchDraftKey.fieldIds);
    final undecided = chosen.isEmpty &&
        controller.value<bool>(MatchDraftKey.fieldsDecided) == true;
    return _ScrollStep(
      children: [
        MatchQuestionHeader(
          title: 'scholarship_match_q_fields'.tr,
          help: 'scholarship_match_q_fields_help'.tr,
        ),
        for (final field in fields)
          MatchChoice(
            key: ValueKey<String>('match-field-${field.id}'),
            label: field.name,
            multiple: true,
            selected: chosen.contains(field.id),
            onTap: !chosen.contains(field.id) && chosen.length >= 3
                ? null
                : () {
                    final next = List<String>.of(chosen);
                    if (!next.remove(field.id)) next.add(field.id);
                    controller.set(MatchDraftKey.fieldIds, next);
                    controller.set(MatchDraftKey.fieldsDecided, true);
                  },
          ),
        MatchChoice(
          key: const ValueKey<String>('match-field-undecided'),
          label: 'scholarship_match_fields_undecided'.tr,
          selected: undecided,
          onTap: () {
            controller.set(MatchDraftKey.fieldIds, const <String>[]);
            controller.set(MatchDraftKey.fieldsDecided, true);
          },
        ),
      ],
    );
  }
}

class _GradeStep extends StatelessWidget {
  const _GradeStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.value<String>(MatchDraftKey.gradeBandOn20);
    return _ScrollStep(
      children: [
        MatchQuestionHeader(
          title: 'scholarship_match_q_grade'.tr,
          help: 'scholarship_match_q_grade_help'.tr,
        ),
        for (final band in MatchTokens.gradeBands)
          MatchChoice(
            key: ValueKey<String>('match-grade-$band'),
            label: matchTokenLabel('grade', band),
            selected: selected == band,
            onTap: () => controller.set(MatchDraftKey.gradeBandOn20, band),
          ),
        TextButton(
          key: const ValueKey<String>('match-grade-convert'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () async {
            final band = await showMatchGradeConvertSheet(context);
            if (band != null) {
              controller.set(MatchDraftKey.gradeBandOn20, band);
            }
          },
          child: Text('scholarship_match_grade_other_scale'.tr),
        ),
      ],
    );
  }
}

class _LanguageStep extends StatefulWidget {
  const _LanguageStep({required this.controller});

  final ScholarshipMatchFlowController controller;

  @override
  State<_LanguageStep> createState() => _LanguageStepState();
}

class _LanguageStepState extends State<_LanguageStep> {
  late bool _showFrench =
      widget.controller.value<String>(MatchDraftKey.frenchLevel) != null;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final english = c.value<String>(MatchDraftKey.englishLevel);
    final french = c.value<String>(MatchDraftKey.frenchLevel);
    final tests = c.languageTests;
    return _ScrollStep(
      children: [
        MatchQuestionHeader(title: 'scholarship_match_q_english'.tr),
        for (final band in MatchTokens.languageBands)
          MatchChoice(
            key: ValueKey<String>('match-lang-$band'),
            label: matchTokenLabel('lang', band),
            selected: english == band,
            onTap: () => c.set(MatchDraftKey.englishLevel, band),
          ),
        for (final test in tests)
          Padding(
            padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
            child: Text(
              'scholarship_match_test_value'.trParams({
                'test': matchTokenLabel('test', test.type),
                'score': matchScoreText(test.score),
              }),
              style: KpbTextStyles.bodySm,
            ),
          ),
        TextButton.icon(
          key: const ValueKey<String>('match-language-test'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.workspace_premium_outlined),
          label: Text('scholarship_match_has_test_score'.tr),
          onPressed: () async {
            final test = await showMatchLanguageTestSheet(context);
            if (test != null) c.putLanguageTest(test);
          },
        ),
        if (!_showFrench)
          TextButton(
            key: const ValueKey<String>('match-french-toggle'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => setState(() => _showFrench = true),
            child: Text('scholarship_match_q_french_optional'.tr),
          )
        else ...[
          const SizedBox(height: KpbSpacing.md),
          MatchQuestionHeader(title: 'scholarship_match_q_french'.tr),
          for (final band in MatchTokens.languageBands)
            MatchChoice(
              key: ValueKey<String>('match-french-$band'),
              label: matchTokenLabel('lang', band),
              selected: french == band,
              onTap: () => c.set(
                MatchDraftKey.frenchLevel,
                french == band ? null : band,
              ),
            ),
        ],
      ],
    );
  }
}

/// « 6.5 » plutôt que « 6.500000 », « 95 » plutôt que « 95.0 ».
String matchScoreText(double score) => score == score.roundToDouble()
    ? score.toInt().toString()
    : score.toStringAsFixed(1);

// ── Feuilles ────────────────────────────────────────────────────────────────

/// « Mon système n'est pas sur 20 » : note sur 4, 10 ou 100, convertie en
/// tranche sur 20. Rend la tranche, ou `null`.
Future<String?> showMatchGradeConvertSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KpbColors.surface,
    builder: (_) => const _GradeConvertSheet(),
  );
}

class _GradeConvertSheet extends StatefulWidget {
  const _GradeConvertSheet();

  @override
  State<_GradeConvertSheet> createState() => _GradeConvertSheetState();
}

class _GradeConvertSheetState extends State<_GradeConvertSheet> {
  double _scale = 4;
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  String? get _band {
    final value = double.tryParse(_value.text.replaceAll(',', '.'));
    return value == null ? null : matchGradeBandFromScale(value, _scale);
  }

  @override
  Widget build(BuildContext context) {
    final band = _band;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KpbSpacing.page,
          KpbSpacing.md,
          KpbSpacing.page,
          MediaQuery.of(context).viewInsets.bottom + KpbSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MatchQuestionHeader(
                title: 'scholarship_match_grade_other_scale'.tr),
            for (final scale in const <double>[4, 10, 100])
              MatchChoice(
                key: ValueKey<String>('match-scale-${scale.toInt()}'),
                label: 'scholarship_match_grade_scale'
                    .trParams({'scale': '${scale.toInt()}'}),
                selected: _scale == scale,
                onTap: () => setState(() => _scale = scale),
              ),
            TextField(
              key: const ValueKey<String>('match-scale-value'),
              controller: _value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'scholarship_match_grade_scale_value'.tr,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KpbSpacing.sm),
            if (band != null)
              Text(
                'scholarship_match_grade_converted'
                    .trParams({'band': matchTokenLabel('grade', band)}),
                style: KpbTextStyles.bodySm,
              ),
            const SizedBox(height: KpbSpacing.md),
            FilledButton(
              key: const ValueKey<String>('match-scale-apply'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed:
                  band == null ? null : () => Navigator.of(context).pop(band),
              child: Text('scholarship_match_apply'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

/// « J'ai un score » : type de test et score (bornes du serveur). Rend le
/// score, ou `null`.
Future<MatchLanguageTest?> showMatchLanguageTestSheet(BuildContext context) {
  return showModalBottomSheet<MatchLanguageTest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KpbColors.surface,
    builder: (_) => const _LanguageTestSheet(),
  );
}

class _LanguageTestSheet extends StatefulWidget {
  const _LanguageTestSheet();

  @override
  State<_LanguageTestSheet> createState() => _LanguageTestSheetState();
}

class _LanguageTestSheetState extends State<_LanguageTestSheet> {
  String _type = 'ielts';
  final _score = TextEditingController();

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }

  MatchLanguageTest? get _test => MatchLanguageTest.fromJson(
        <String, dynamic>{'type': _type, 'score': _score.text},
      );

  @override
  Widget build(BuildContext context) {
    final test = _test;
    final scale = MatchTokens.languageTestScales[_type]!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KpbSpacing.page,
          KpbSpacing.md,
          KpbSpacing.page,
          MediaQuery.of(context).viewInsets.bottom + KpbSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MatchQuestionHeader(title: 'scholarship_match_has_test_score'.tr),
              for (final type in MatchTokens.languageTestScales.keys)
                MatchChoice(
                  key: ValueKey<String>('match-test-$type'),
                  label: matchTokenLabel('test', type),
                  selected: _type == type,
                  onTap: () => setState(() => _type = type),
                ),
              TextField(
                key: const ValueKey<String>('match-test-score'),
                controller: _score,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'scholarship_match_test_score_label'.trParams({
                    'min': matchScoreText(scale.$1),
                    'max': matchScoreText(scale.$2),
                  }),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: KpbSpacing.md),
              FilledButton(
                key: const ValueKey<String>('match-test-apply'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed:
                    test == null ? null : () => Navigator.of(context).pop(test),
                child: Text('scholarship_match_apply'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
