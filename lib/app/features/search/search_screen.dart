import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/config/app_routes.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../explore/country_detail_screen.dart';
import '../explore/program_detail_screen.dart';
import '../scholarships/widgets/follow_scholarship_button.dart';
import 'match_explanation_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _textController = TextEditingController();
  Timer? _debounce;
  List<SearchResult> _results = const [];
  String _query = '';

  AppController get _ctrl => Get.find<AppController>();

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = value.trim();
        _results = _ctrl.search(_query);
      });
    });
  }

  void _onSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _ctrl.addSearchQuery(value.trim());
    }
  }

  void _onResultTap(SearchResult result) {
    _ctrl.addSearchQuery(_query);
    switch (result.type) {
      case SearchResultType.field:
        try {
          final field = _ctrl.fieldById(result.id);
          _openFieldDetail(context, field, _ctrl);
        } catch (_) {
          KpbToast.info(
            'search_field_not_found_body'.tr,
            title: 'search_field_not_found_title'.tr,
          );
        }
      case SearchResultType.country:
        Get.to(() => CountryDetailScreen(countryId: result.id));
      case SearchResultType.institution:
        _ctrl.goToTab(StudentShellTab.universities);
        Get.back();
      case SearchResultType.program:
        Get.to(() => ProgramDetailScreen(programId: result.id));
      case SearchResultType.scholarship:
        Get.back();
        Get.toNamed(AppRoutes.scholarships);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(KpbSpacing.sm, KpbSpacing.sm,
                  KpbSpacing.pagePad, KpbSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'a11y_back'.tr,
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.kpb.cardBg,
                        borderRadius: KpbRadius.mdBr,
                        boxShadow: KpbShadow.card,
                      ),
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        onChanged: _onQueryChanged,
                        onSubmitted: _onSubmitted,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'search_hint'.tr,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: context.kpb.textMuted,
                          ),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20, color: context.kpb.gray400),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  tooltip: 'a11y_clear_search'.tr,
                                  onPressed: () {
                                    _textController.clear();
                                    setState(() {
                                      _query = '';
                                      _results = const [];
                                    });
                                  },
                                  icon: Icon(Icons.close_rounded,
                                      size: 18, color: context.kpb.gray400),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Body ───────────────────────────────────────────────
            Expanded(
              child: _query.isEmpty
                  ? _buildIdleView()
                  : _results.isEmpty
                      ? _buildEmptyResults()
                      : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Idle view (history + suggestions) ──────────────────────────

  Widget _buildIdleView() {
    final history = _ctrl.searchHistory;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (history.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 16, color: context.kpb.gray400),
                const SizedBox(width: 6),
                Text('recent_searches'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.kpb.textSecondary)),
                const Spacer(),
                GestureDetector(
                  onTap: _ctrl.clearSearchHistory,
                  child: Text('search_clear_history'.tr,
                      style: TextStyle(fontSize: 12, color: KpbColors.blue)),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history.map((q) {
                return GestureDetector(
                  onTap: () {
                    _textController.text = q;
                    _textController.selection = TextSelection.fromPosition(
                        TextPosition(offset: q.length));
                    _onQueryChanged(q);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.kpb.cardBg,
                      borderRadius: KpbRadius.pillBr,
                      border: Border.all(color: context.kpb.gray100),
                    ),
                    child: Text(q,
                        style: TextStyle(
                            fontSize: 13, color: context.kpb.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: KpbSpacing.xl),
          ],
          Text('search_suggestions'.tr,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.kpb.textSecondary)),
          const SizedBox(height: KpbSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'catalog_filter_cs'.tr,
              'search_suggestion_france'.tr,
              'search_suggestion_school'.tr,
              'Business',
              'Canada',
              'search_suggestion_engineering'.tr,
            ].map((s) {
              return GestureDetector(
                onTap: () {
                  _textController.text = s;
                  _textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: s.length));
                  _onQueryChanged(s);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KpbColors.blue.withValues(alpha: 0.08),
                    borderRadius: KpbRadius.pillBr,
                  ),
                  child: Text(s,
                      style: const TextStyle(
                          fontSize: 13,
                          color: KpbColors.blue,
                          fontWeight: FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Empty results ──────────────────────────────────────────────

  Widget _buildEmptyResults() {
    return KpbEmptyState(
      icon: Icons.search_off_rounded,
      title: 'search_no_results_title'.trParams({'query': _query}),
      subtitle: 'search_no_results_subtitle'.tr,
    );
  }

  // ── Results grouped by type ────────────────────────────────────

  Widget _buildResults() {
    final grouped = <SearchResultType, List<SearchResult>>{};
    for (final r in _results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.pagePad, vertical: KpbSpacing.xs),
          child: Text(
            'search_results_count'.trParams({'n': '${_results.length}'}),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.kpb.textMuted),
          ),
        ),
        for (final type in SearchResultType.values)
          if (grouped.containsKey(type))
            _ResultSection(
              type: type,
              results: grouped[type]!,
              onTap: _onResultTap,
              controller: _ctrl,
            ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result section
// ─────────────────────────────────────────────────────────────────────────────
class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.type,
    required this.results,
    required this.onTap,
    required this.controller,
  });

  final SearchResultType type;
  final List<SearchResult> results;
  final ValueChanged<SearchResult> onTap;
  final AppController controller;

  static Map<SearchResultType, String> get _labels => {
        SearchResultType.field: 'search_section_fields'.tr,
        SearchResultType.country: 'search_section_countries'.tr,
        SearchResultType.institution: 'search_section_institutions'.tr,
        SearchResultType.program: 'search_section_programs'.tr,
        SearchResultType.scholarship: 'letter_category_scholarship'.tr,
      };

  static const _icons = {
    SearchResultType.field: Icons.school_rounded,
    SearchResultType.country: Icons.public_rounded,
    SearchResultType.institution: Icons.account_balance_rounded,
    SearchResultType.program: Icons.menu_book_rounded,
    SearchResultType.scholarship: Icons.emoji_events_rounded,
  };

  static const _colors = {
    SearchResultType.field: KpbColors.blue,
    SearchResultType.country: KpbColors.financeGreen,
    SearchResultType.institution: KpbColors.lawPurple,
    SearchResultType.program: KpbColors.businessSky,
    SearchResultType.scholarship: KpbColors.gold,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[type] ?? KpbColors.blue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad, KpbSpacing.md,
              KpbSpacing.pagePad, KpbSpacing.xs),
          child: Row(
            children: [
              Icon(_icons[type], size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                _labels[type] ?? '',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: KpbRadius.pillBr,
                ),
                child: Text(
                  '${results.length}',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        ),
        ...results.take(5).map((r) => _SearchResultTile(
              result: r,
              color: color,
              controller: controller,
              onTap: () => onTap(r),
            )),
        if (results.length > 5)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: KpbSpacing.pagePad, vertical: KpbSpacing.xs),
            child: Text(
              '+${results.length - 5} ${'other_results'.tr}',
              style: TextStyle(
                  fontSize: 12,
                  color: context.kpb.textMuted,
                  fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single result tile
// ─────────────────────────────────────────────────────────────────────────────
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.color,
    required this.controller,
    required this.onTap,
  });

  final SearchResult result;
  final Color color;
  final AppController controller;
  final VoidCallback onTap;

  ProfileFit? get _fit {
    switch (result.type) {
      case SearchResultType.field:
        try {
          return controller.fieldFit(controller.fieldById(result.id));
        } catch (_) {
          return null;
        }
      case SearchResultType.program:
        try {
          return controller.programFit(controller.programById(result.id));
        } catch (_) {
          return null;
        }
      case SearchResultType.institution:
        try {
          return controller
              .institutionFit(controller.institutionById(result.id));
        } catch (_) {
          return null;
        }
      // Aucun palier pour une bourse : l'ancien venait d'un score client qui
      // partait du `baseMatch` éditorial et ne lisait aucune condition
      // d'éligibilité (« Très bon match » sur une bourse fermée à ton niveau).
      // Seul le test « Mes 10 bourses », côté serveur, dit ce qui est
      // compatible.
      case SearchResultType.scholarship:
      case SearchResultType.country:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fit = _fit;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: KpbSpacing.pagePad, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: KpbRadius.mdBr,
              ),
              child: Icon(
                _ResultSection._icons[result.type],
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.kpb.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.subtitle.isNotEmpty)
                    Text(
                      result.subtitle,
                      style: TextStyle(
                          fontSize: 12, color: context.kpb.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (fit != null)
              GestureDetector(
                onTap: () => showMatchExplanation(
                  context,
                  result.title,
                  fit,
                  controller.matchExplanation(result.type, result.id),
                  controller,
                ),
                child: ProfileFitBadge(fit: fit, fontSize: 10.5),
              ),
            if (result.type == SearchResultType.scholarship)
              FollowScholarshipButton(
                scholarshipId: result.id,
                scholarshipTitle: result.title,
                variant: FollowButtonVariant.icon,
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: context.kpb.gray300),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field detail bottom sheet (reused from explore_screen)
// ─────────────────────────────────────────────────────────────────────────────
void _openFieldDetail(
  BuildContext context,
  FieldModel field,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.lg),
        child: ListView(
          controller: scrollController,
          children: [
            const SizedBox(height: KpbSpacing.sm),
            Container(
              padding: const EdgeInsets.all(KpbSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    field.accentColor,
                    field.accentColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: KpbRadius.lgBr,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.resolve(field.name),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.resolve(field.description),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KpbSpacing.lg),
            if (field.careers.isNotEmpty) ...[
              Text('possible_careers'.tr,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.kpb.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: field.careers.take(8).map((c) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: field.accentColor.withValues(alpha: 0.1),
                      borderRadius: KpbRadius.pillBr,
                    ),
                    child: Text(
                      controller.resolve(c),
                      style: TextStyle(
                          fontSize: 12,
                          color: field.accentColor,
                          fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: KpbSpacing.lg),
            ],
            if (field.subjects.isNotEmpty) ...[
              Text('main_subjects'.tr,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.kpb.textPrimary)),
              const SizedBox(height: 8),
              ...field.subjects.take(6).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: field.accentColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.resolve(s),
                            style: TextStyle(
                                fontSize: 13, color: context.kpb.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: KpbSpacing.xl),
          ],
        ),
      ),
    ),
  );
}
