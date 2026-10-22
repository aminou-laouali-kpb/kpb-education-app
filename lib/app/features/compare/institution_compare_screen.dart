import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/program_intakes.dart';
import '../../core/utils/share_origin.dart';
import '../cases/case_composer_sheet.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/profile_fit_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Couleurs : tokens sémantiques centraux (KpbColors — architecture §6/§10.2).

String _flag(String id) => countryFlag(id);

// ─────────────────────────────────────────────────────────────────────────────
// Comparator screen
// ─────────────────────────────────────────────────────────────────────────────
class InstitutionCompareScreen extends StatefulWidget {
  const InstitutionCompareScreen({
    super.key,
    required this.institutionId1,
    required this.institutionId2,
  });

  final String institutionId1;
  final String institutionId2;

  @override
  State<InstitutionCompareScreen> createState() =>
      _InstitutionCompareScreenState();
}

class _InstitutionCompareScreenState extends State<InstitutionCompareScreen> {
  final AppController _controller = Get.find<AppController>();

  // Local state: the two currently-compared institution ids, seeded from the
  // constructor. The picker swaps one of these via setState.
  late String _id1 = widget.institutionId1;
  late String _id2 = widget.institutionId2;

  @override
  Widget build(BuildContext context) {
    final inst1 = _controller.institutionByIdOrNull(_id1);
    final inst2 = _controller.institutionByIdOrNull(_id2);

    if (inst1 == null || inst2 == null) {
      return Scaffold(
        backgroundColor: KpbColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: _circleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Get.back<void>(),
                tooltip: 'a11y_back'.tr,
              ),
            ),
          ),
        ),
      );
    }

    final fit1 = _controller.institutionFit(inst1);
    final fit2 = _controller.institutionFit(inst2);
    final verdict = _verdict(inst1, inst2, fit1, fit2);

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(inst1, inst2),
              const SizedBox(height: 13),
              _table(inst1, inst2, fit1, fit2, verdict),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(child: _caseCta(inst1)),
                  const SizedBox(width: 10),
                  Expanded(child: _caseCta(inst2)),
                ],
              ),
              const SizedBox(height: 10),
              _helpButton(inst1, inst2),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(InstitutionModel inst1, InstitutionModel inst2) {
    return Row(
      children: [
        _circleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Get.back<void>(),
          tooltip: 'a11y_back'.tr,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'compare_title'.tr,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'compare_subtitle'.tr,
                style:
                    const TextStyle(fontSize: 11.5, color: KpbColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Builder(
          builder: (button) => _circleButton(
            icon: Icons.ios_share_rounded,
            onTap: () => _shareComparison(button, inst1, inst2),
            tooltip: 'a11y_share'.tr,
          ),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: KpbColors.surface,
        shape: const CircleBorder(side: BorderSide(color: KpbColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: KpbColors.brandNavy),
          ),
        ),
      ),
    );
  }

  // ── Comparison table card ───────────────────────────────────────────────────
  Widget _table(
    InstitutionModel inst1,
    InstitutionModel inst2,
    ProfileFit? fit1,
    ProfileFit? fit2,
    String? verdict,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: KpbColors.surface,
        border: Border.all(color: KpbColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _pickHeaderRow(inst1, inst2),
          _attrRow(
            'compare_row_match'.tr,
            _fitCell(fit1),
            _fitCell(fit2),
          ),
          _attrRow(
            'saved_group_countries'.tr,
            _cellText(
                '${_flag(inst1.countryId)} ${_countryName(inst1.countryId)}'),
            _cellText(
                '${_flag(inst2.countryId)} ${_countryName(inst2.countryId)}'),
          ),
          _attrRow(
            'compare_row_location'.tr,
            _cellText(_controller.resolve(inst1.location)),
            _cellText(_controller.resolve(inst2.location)),
          ),
          _attrRow(
            'compare_row_tuition'.tr,
            _cellText(_controller.resolve(inst1.tuitionLabel)),
            _cellText(_controller.resolve(inst2.tuitionLabel)),
          ),
          _attrRow(
            'compare_row_language'.tr,
            _cellText(_controller.resolve(inst1.languageRequirements)),
            _cellText(_controller.resolve(inst2.languageRequirements)),
          ),
          _attrRow(
            'compare_row_levels'.tr,
            _cellText(_join(inst1.studyLevels)),
            _cellText(_join(inst2.studyLevels)),
          ),
          _attrRow(
            'compare_row_intakes'.tr,
            _cellText(_intakes(inst1)),
            _cellText(_intakes(inst2)),
          ),
          _attrRow(
            'saved_group_programs'.tr,
            _cellText('compare_program_count'
                .trParams({'n': '${inst1.programIds.length}'})),
            _cellText('compare_program_count'
                .trParams({'n': '${inst2.programIds.length}'})),
          ),
          _attrRow(
            'compare_row_kpb_partner'.tr,
            _partnerChip(inst1.isPartner),
            _partnerChip(inst2.isPartner),
          ),
          if (verdict != null) _verdictRow(verdict),
        ],
      ),
    );
  }

  Widget _pickHeaderRow(InstitutionModel inst1, InstitutionModel inst2) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KpbColors.surfaceMuted)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 9, child: SizedBox()),
            _pickCell(inst1, () => _openPicker(column: 1)),
            _pickCell(inst2, () => _openPicker(column: 2)),
          ],
        ),
      ),
    );
  }

  Widget _pickCell(InstitutionModel inst, VoidCallback onTap) {
    return Expanded(
      flex: 10,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: KpbColors.surfaceMuted)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_flag(inst.countryId),
                  style: const TextStyle(fontSize: 22, height: 1)),
              const SizedBox(height: 4),
              Text(
                _controller.resolve(inst.name),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.brandNavy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded,
                      size: 11, color: KpbColors.actionPrimary),
                  const SizedBox(width: 3),
                  Text(
                    'compare_pick'.tr,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.actionPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attrRow(String label, Widget cell1, Widget cell2) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KpbColors.canvas)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 9,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: KpbColors.textFaint,
                    ),
                  ),
                ),
              ),
            ),
            _valueCell(cell1),
            _valueCell(cell2),
          ],
        ),
      ),
    );
  }

  Widget _valueCell(Widget child) {
    return Expanded(
      flex: 10,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: KpbColors.canvas)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _cellText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: KpbColors.gray700,
        height: 1.4,
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  /// Qualitative fit, or a dash without a student profile (never a score).
  Widget _fitCell(ProfileFit? fit) =>
      fit == null ? _cellText('—') : ProfileFitBadge(fit: fit, fontSize: 11);

  Widget _partnerChip(bool value) => value
      ? _chip('compare_yes'.tr, KpbColors.successLight, KpbColors.success)
      : _chip('compare_no'.tr, KpbColors.surfaceMuted, KpbColors.textMuted);

  Widget _verdictRow(String verdict) {
    return Container(
      color: KpbColors.actionPrimarySoft,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded,
              size: 15, color: KpbColors.actionPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              verdict,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: KpbColors.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTAs ────────────────────────────────────────────────────────────────────
  Widget _caseCta(InstitutionModel inst) {
    return Material(
      color: KpbColors.actionPrimary,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCase(inst),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 17, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'compare_open_case_for'
                      .trParams({'name': _controller.resolve(inst.name)}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpButton(InstitutionModel inst1, InstitutionModel inst2) {
    return Material(
      color: KpbColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openHelp(inst1, inst2),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KpbColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.support_agent_rounded,
                  size: 17, color: KpbColors.actionPrimary),
              const SizedBox(width: 8),
              Text(
                'compare_need_help_choosing'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.actionPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> _openPicker({required int column}) async {
    final currentId = column == 1 ? _id1 : _id2;
    final excludeId = column == 1 ? _id2 : _id1;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UniversityPickerSheet(
        controller: _controller,
        currentId: currentId,
        excludeId: excludeId,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (column == 1) {
        _id1 = chosen;
      } else {
        _id2 = chosen;
      }
    });
  }

  void _openCase(InstitutionModel inst) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaseComposerSheet(
        caseType: CaseType.applicationSupport,
        title: _controller.resolve(inst.name),
        contextLabel: _controller.resolve(inst.location),
        institutionId: inst.id,
      ),
    );
  }

  void _openHelp(InstitutionModel inst1, InstitutionModel inst2) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaseComposerSheet(
        caseType: CaseType.consultation,
        title: 'compare_help_choosing_university'.tr,
        contextLabel:
            '${_controller.resolve(inst1.name)} vs ${_controller.resolve(inst2.name)}',
      ),
    );
  }

  /// Verdict tip — only ever mechanically derived from the two real records.
  /// Returns null (row omitted) when nothing truthful can be said.
  String? _verdict(
    InstitutionModel a,
    InstitutionModel b,
    ProfileFit? fitA,
    ProfileFit? fitB,
  ) {
    // Compare the displayed tiers, not the raw ranking scores: the verdict
    // must never contradict the two badges the student sees just above.
    // ProfileFit is declared best-first, so a lower index is a better fit.
    if (fitA != null && fitB != null && fitA != fitB) {
      final better = fitA.index < fitB.index ? a : b;
      return 'compare_verdict_higher_match'
          .trParams({'name': _controller.resolve(better.name)});
    }
    if (a.isPartner != b.isPartner) {
      final partner = a.isPartner ? a : b;
      return 'compare_verdict_partner'
          .trParams({'name': _controller.resolve(partner.name)});
    }
    final na = a.programIds.length;
    final nb = b.programIds.length;
    if (na != nb) {
      final more = na > nb ? a : b;
      return 'compare_verdict_more_programs'.trParams({
        'name': _controller.resolve(more.name),
        'hi': '${na > nb ? na : nb}',
        'lo': '${na > nb ? nb : na}',
      });
    }
    return null;
  }

  void _shareComparison(
      BuildContext origin, InstitutionModel inst1, InstitutionModel inst2) {
    final name1 = _controller.resolve(inst1.name);
    final name2 = _controller.resolve(inst2.name);
    String line(String name, ProfileFit? fit) => fit == null
        ? 'compare_share_line_plain'.trParams({'name': name})
        : 'compare_share_line'.trParams({'name': name, 'fit': fit.labelKey.tr});
    final fit1 = _controller.institutionFit(inst1);
    final fit2 = _controller.institutionFit(inst2);
    unawaited(kpbShare(
      origin,
      text: 'compare_share_header'.tr +
          line(name1, fit1) +
          'compare_share_tuition'
              .trParams({'tuition': _controller.resolve(inst1.tuitionLabel)}) +
          'compare_share_language'.trParams(
              {'lang': _controller.resolve(inst1.languageRequirements)}) +
          line(name2, fit2) +
          'compare_share_tuition'
              .trParams({'tuition': _controller.resolve(inst2.tuitionLabel)}) +
          'compare_share_language'.trParams(
              {'lang': _controller.resolve(inst2.languageRequirements)}) +
          'compare_share_footer'.tr,
    ));
  }

  String _join(List<String> values) =>
      values.isEmpty ? '—' : values.join(' · ');

  /// Les rentrées À VENIR de l'école, en toutes lettres (« octobre 2026 »,
  /// pas « 01/10/2026 ») — même règle que les cartes (program_intakes.dart).
  String _intakes(InstitutionModel inst) =>
      schoolIntakeSummary(inst.intakePeriods)
          .longLabel(_controller.localeCode) ??
      '—';

  String _countryName(String countryId) {
    try {
      return _controller.resolve(_controller.countryById(countryId).name);
    } catch (_) {
      return countryId;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur d'université — bottom-sheet picker for switching a compared column.
// ─────────────────────────────────────────────────────────────────────────────
class _UniversityPickerSheet extends StatefulWidget {
  const _UniversityPickerSheet({
    required this.controller,
    required this.currentId,
    required this.excludeId,
  });

  final AppController controller;

  /// The column's current institution — highlighted in the list.
  final String currentId;

  /// The opposite column's institution — hidden so the two columns stay
  /// distinct (you can't compare a university with itself).
  final String excludeId;

  @override
  State<_UniversityPickerSheet> createState() => _UniversityPickerSheetState();
}

class _UniversityPickerSheetState extends State<_UniversityPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InstitutionModel> get _results {
    final q = _query.trim().toLowerCase();
    return widget.controller.institutions.where((inst) {
      if (inst.id == widget.excludeId) return false;
      if (q.isEmpty) return true;
      final name = widget.controller.resolve(inst.name).toLowerCase();
      final city = widget.controller.resolve(inst.location).toLowerCase();
      return name.contains(q) || city.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.74,
        child: Container(
          decoration: const BoxDecoration(
            color: KpbColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: KpbShadow.scrimNavy,
                blurRadius: 40,
                offset: Offset(0, -12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'compare_picker_title'.tr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: KpbColors.brandNavy,
                            ),
                          ),
                        ),
                        _closeButton(),
                      ],
                    ),
                    const SizedBox(height: 11),
                    _searchField(),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _pickRow(results[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _closeButton() {
    return Material(
      color: KpbColors.surfaceMuted,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 30,
          height: 30,
          child:
              Icon(Icons.close_rounded, size: 15, color: KpbColors.brandNavy),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: KpbColors.canvas,
        border: Border.all(color: KpbColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 18, color: KpbColors.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KpbColors.brandNavy,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'compare_search_hint'.tr,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KpbColors.textFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickRow(InstitutionModel inst) {
    final fit = widget.controller.institutionFit(inst);
    final selected = inst.id == widget.currentId;
    return Material(
      color: selected ? KpbColors.actionPrimarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(inst.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(
                    color: KpbColors.actionPrimary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Text(_flag(inst.countryId),
                  style: const TextStyle(fontSize: 22, height: 1)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.controller.resolve(inst.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.controller.resolve(inst.location),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: KpbColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (fit != null) ...[
                const SizedBox(width: 8),
                ProfileFitBadge(fit: fit, fontSize: 10.5),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(
          'compare_picker_empty'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: KpbColors.textFaint),
        ),
      ),
    );
  }
}
