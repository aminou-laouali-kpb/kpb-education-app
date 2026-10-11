import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/roadmap_engine.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';

const _frMonths = <String, int>{
  'janvier': 1,
  'février': 2,
  'mars': 3,
  'avril': 4,
  'mai': 5,
  'juin': 6,
  'juillet': 7,
  'août': 8,
  'septembre': 9,
  'octobre': 10,
  'novembre': 11,
  'décembre': 12,
};

const _monthNames = <int, String>{
  1: 'Janvier',
  2: 'Février',
  3: 'Mars',
  4: 'Avril',
  5: 'Mai',
  6: 'Juin',
  7: 'Juillet',
  8: 'Août',
  9: 'Septembre',
  10: 'Octobre',
  11: 'Novembre',
  12: 'Décembre',
};

DateTime? _parseDeadline(String text) {
  final lower = text.toLowerCase();
  // `\w` est ASCII en Dart : « février », « août » et « décembre » n'étaient
  // jamais reconnus. N'importe quel mot hors chiffres convient, la table des
  // mois fait le tri.
  final match = RegExp(r'(\d{1,2})\s+([^\s\d]+)\s+(\d{4})').firstMatch(lower);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = _frMonths[match.group(2)!];
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

/// Vrai si [deadline] est un jour ANTÉRIEUR à aujourd'hui. Une échéance du
/// jour même reste « à venir » jusqu'au soir, même posée à minuit.
bool _isPastDay(DateTime deadline, DateTime now) {
  final d = deadline.toLocal();
  final n = now.toLocal();
  return DateTime(d.year, d.month, d.day)
      .isBefore(DateTime(n.year, n.month, n.day));
}

enum _MilestoneKind { scholarship, roadmap, caseStep, document }

enum _MilestoneFilter { all, saved, cases, upcoming }

class _MilestoneEntry {
  const _MilestoneEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.deadline,
    required this.isSaved,
    required this.route,
    this.deadlineIsEstimated = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final _MilestoneKind kind;
  final DateTime? deadline;
  final bool isSaved;
  final String? route;

  /// Vrai quand [deadline] est une PROJECTION (cycle « estimated » du
  /// catalogue) : la date sert encore à trier, mais l'écran doit dire « date à
  /// confirmer » au lieu d'un compte à rebours au jour près — 20 des 31
  /// fiches publiées sont dans ce cas, et un « J-146 » ferme sur une date que
  /// personne n'a confirmée est un mensonge.
  final bool deadlineIsEstimated;
}

class DeadlineCalendarScreen extends StatefulWidget {
  const DeadlineCalendarScreen({super.key});

  @override
  State<DeadlineCalendarScreen> createState() => _DeadlineCalendarScreenState();
}

class _DeadlineCalendarScreenState extends State<DeadlineCalendarScreen> {
  _MilestoneFilter _filter = _MilestoneFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        backgroundColor: context.kpb.cardBg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'a11y_back'.tr,
          icon: Icon(Icons.arrow_back_rounded, color: context.kpb.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'deadlines_title'.tr,
          style: KpbTextStyles.titleLg.copyWith(color: context.kpb.textPrimary),
        ),
        centerTitle: true,
      ),
      body: GetBuilder<AppController>(
        builder: (_) {
          final entries = _buildMilestones(controller, now);
          final filtered = _applyFilter(entries, now)
            ..sort((a, b) {
              if (a.deadline == null && b.deadline == null) return 0;
              if (a.deadline == null) return 1;
              if (b.deadline == null) return -1;
              return a.deadline!.compareTo(b.deadline!);
            });

          final grouped = <String, List<_MilestoneEntry>>{};
          for (final entry in filtered) {
            final key = entry.deadline != null
                ? '${_monthNames[entry.deadline!.month]} ${entry.deadline!.year}'
                : 'deadlines_date_to_confirm'.tr;
            grouped.putIfAbsent(key, () => []).add(entry);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad,
                    KpbSpacing.lg,
                    KpbSpacing.pagePad,
                    KpbSpacing.md,
                  ),
                  child: _StatsBanner(
                    stats: _buildStats(entries, now),
                    isDark: isDark,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KpbSpacing.pagePad,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'deadlines_filter_all'.tr,
                        active: _filter == _MilestoneFilter.all,
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _filter = _MilestoneFilter.all),
                      ),
                      _FilterChip(
                        label: 'deadlines_filter_saved'.tr,
                        active: _filter == _MilestoneFilter.saved,
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _filter = _MilestoneFilter.saved),
                      ),
                      _FilterChip(
                        label: 'deadlines_filter_cases'.tr,
                        active: _filter == _MilestoneFilter.cases,
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _filter = _MilestoneFilter.cases),
                      ),
                      _FilterChip(
                        label: 'deadlines_filter_upcoming'.tr,
                        active: _filter == _MilestoneFilter.upcoming,
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _filter = _MilestoneFilter.upcoming),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: KpbEmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'deadlines_empty_title'.tr,
                      subtitle: 'deadlines_empty_subtitle'.tr,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad,
                    KpbSpacing.lg,
                    KpbSpacing.pagePad,
                    100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final key = grouped.keys.elementAt(index);
                        return _MonthGroup(
                          monthLabel: key,
                          entries: grouped[key]!,
                          now: now,
                          isDark: isDark,
                        );
                      },
                      childCount: grouped.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<_MilestoneEntry> _applyFilter(
    List<_MilestoneEntry> entries,
    DateTime now,
  ) {
    switch (_filter) {
      case _MilestoneFilter.saved:
        return entries.where((entry) => entry.isSaved).toList();
      case _MilestoneFilter.cases:
        return entries
            .where((entry) =>
                entry.kind == _MilestoneKind.caseStep ||
                entry.kind == _MilestoneKind.document)
            .toList();
      case _MilestoneFilter.upcoming:
        return entries
            .where((entry) =>
                entry.deadline != null && !_isPastDay(entry.deadline!, now))
            .toList();
      case _MilestoneFilter.all:
        return entries.toList();
    }
  }

  Map<String, int> _buildStats(List<_MilestoneEntry> entries, DateTime now) {
    final upcoming = entries
        .where((entry) =>
            entry.deadline != null && !_isPastDay(entry.deadline!, now))
        .length;
    final urgent = entries
        .where((entry) =>
            entry.deadline != null &&
            !_isPastDay(entry.deadline!, now) &&
            entry.deadline!.difference(now).inDays <= 30)
        .length;
    final caseLinked = entries
        .where((entry) =>
            entry.kind == _MilestoneKind.caseStep ||
            entry.kind == _MilestoneKind.document)
        .length;
    return {'upcoming': upcoming, 'urgent': urgent, 'cases': caseLinked};
  }

  List<_MilestoneEntry> _buildMilestones(
    AppController controller,
    DateTime now,
  ) {
    final entries = <_MilestoneEntry>[];
    final savedScholarshipIds = controller.savedItems
        .where((item) => item.type == SavedItemType.scholarship)
        .map((item) => item.itemId)
        .toSet();

    for (final scholarship in controller.scholarships) {
      final title = controller.resolve(scholarship.name);
      final deadline = scholarship.deadlineAt ??
          _parseDeadline(controller.resolve(scholarship.deadlineLabel));
      final isSaved = savedScholarshipIds.contains(scholarship.id);
      entries.add(
        _MilestoneEntry(
          id: 'scholarship-${scholarship.id}',
          title: title,
          subtitle:
              '${countryFlag(scholarship.countryId)} ${controller.resolve(scholarship.typeOfFunding)}',
          kind: _MilestoneKind.scholarship,
          deadline: deadline,
          deadlineIsEstimated: scholarship.deadlineIsEstimated,
          isSaved: isSaved,
          route: AppRoutes.deadlines,
        ),
      );

      if (!isSaved) continue;
      final roadmapDeadline = deadline ?? now.add(const Duration(days: 90));
      for (final step in RoadmapEngine.getSteps()) {
        if (controller.isStepCompleted(scholarship.id, step.type)) continue;
        entries.add(
          _MilestoneEntry(
            id: 'roadmap-${scholarship.id}-${step.type.name}',
            title: controller.resolve(step.title),
            subtitle: '$title · ${controller.resolve(step.description)}',
            kind: _MilestoneKind.roadmap,
            deadline: RoadmapEngine.calculateDate(
              roadmapDeadline,
              step.daysBeforeDeadline,
            ),
            isSaved: true,
            route: AppRoutes.deadlines,
          ),
        );
      }
    }

    for (final item in controller.cases) {
      if (_isClosedCase(item.status)) continue;
      final fallbackDue = item.updatedAt.add(const Duration(days: 7));
      entries.add(
        _MilestoneEntry(
          id: 'case-next-${item.id}',
          title: controller.resolve(item.nextStepTitle),
          subtitle: '${item.referenceCode} · ${controller.resolve(item.title)}',
          kind: _MilestoneKind.caseStep,
          deadline: item.scheduledAt ?? fallbackDue,
          isSaved: false,
          route: '/cases/${item.id}',
        ),
      );

      for (final document
          in item.documentRequests.where((d) => !d.isProvided)) {
        entries.add(
          _MilestoneEntry(
            id: 'case-doc-${item.id}-${document.id}',
            title: controller.resolve(document.title),
            subtitle: 'deadlines_missing_document'
                .trParams({'code': item.referenceCode}),
            kind: _MilestoneKind.document,
            deadline: fallbackDue,
            isSaved: false,
            route: '/cases/${item.id}',
          ),
        );
      }
    }

    return entries;
  }

  bool _isClosedCase(CaseStatus status) {
    return status == CaseStatus.completed ||
        status == CaseStatus.rejected ||
        status == CaseStatus.cancelled;
  }
}

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({required this.stats, required this.isDark});

  final Map<String, int> stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.xlBr,
        border: Border.all(color: context.kpb.gray100),
        boxShadow: KpbShadow.soft,
      ),
      child: Row(
        children: [
          _StatItem(
            count: stats['upcoming']!,
            label: 'deadlines_filter_upcoming'.tr,
            color: isDark ? KpbColors.sky : KpbColors.blue,
            icon: Icons.upcoming_outlined,
          ),
          _StatDivider(),
          _StatItem(
            count: stats['urgent']!,
            label: 'deadlines_stat_within_30_days'.tr,
            color: KpbColors.warning,
            icon: Icons.timer_outlined,
          ),
          _StatDivider(),
          _StatItem(
            count: stats['cases']!,
            label: 'deadlines_filter_cases'.tr,
            color: KpbColors.success,
            icon: Icons.folder_open_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int count;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: KpbTextStyles.labelSm.copyWith(
              color: context.kpb.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      color: context.kpb.gray100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? KpbColors.sky : KpbColors.blue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : context.kpb.cardBg,
          borderRadius: KpbRadius.pillBr,
          border: Border.all(color: active ? activeColor : context.kpb.gray200),
          boxShadow: active ? (isDark ? null : KpbShadow.soft) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : context.kpb.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MonthGroup extends StatelessWidget {
  const _MonthGroup({
    required this.monthLabel,
    required this.entries,
    required this.now,
    required this.isDark,
  });

  final String monthLabel;
  final List<_MilestoneEntry> entries;
  final DateTime now;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(bottom: KpbSpacing.md, top: KpbSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: isDark ? KpbColors.sky : KpbColors.blue,
                  borderRadius: KpbRadius.pillBr,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                monthLabel.toUpperCase(),
                style: KpbTextStyles.label.copyWith(
                  color: context.kpb.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.kpb.surfaceBg,
                  borderRadius: KpbRadius.pillBr,
                ),
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.kpb.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.kpb.cardBg,
            borderRadius: KpbRadius.lgBr,
            border: Border.all(color: context.kpb.gray100),
          ),
          child: Column(
            children: entries.asMap().entries.map((entry) {
              final i = entry.key;
              return Column(
                children: [
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.kpb.gray100,
                    ),
                  _MilestoneTile(entry: entry.value, now: now),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: KpbSpacing.xl),
      ],
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.entry, required this.now});

  final _MilestoneEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = _status(context);
    return InkWell(
      onTap: entry.route == null ? null : () => Get.toNamed(entry.route!),
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.12),
                borderRadius: KpbRadius.mdBr,
              ),
              child: Icon(_icon, color: status.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: KpbTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (entry.isSaved)
                        KpbBadge(
                            label: 'deadlines_badge_tracked'.tr,
                            color: KpbColors.blue),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(entry.subtitle, style: KpbTextStyles.bodySm),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      KpbBadge(label: _kindLabel, color: status.color),
                      KpbBadge(label: status.label, color: status.color),
                    ],
                  ),
                ],
              ),
            ),
            if (entry.route != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.kpb.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    switch (entry.kind) {
      case _MilestoneKind.scholarship:
        return Icons.school_outlined;
      case _MilestoneKind.roadmap:
        return Icons.route_outlined;
      case _MilestoneKind.caseStep:
        return Icons.folder_open_outlined;
      case _MilestoneKind.document:
        return Icons.description_outlined;
    }
  }

  String get _kindLabel {
    switch (entry.kind) {
      case _MilestoneKind.scholarship:
        return 'deadlines_kind_scholarship'.tr;
      case _MilestoneKind.roadmap:
        return 'deadlines_kind_roadmap'.tr;
      case _MilestoneKind.caseStep:
        return 'deadlines_kind_case'.tr;
      case _MilestoneKind.document:
        return 'deadlines_kind_document'.tr;
    }
  }

  ({String label, Color color}) _status(BuildContext context) {
    final deadline = entry.deadline;
    // Une date ESTIMÉE ne reçoit jamais de compte à rebours : la date sert au
    // tri et au regroupement, mais le badge dit la seule chose qu'on sait —
    // qu'elle reste à confirmer. Même règle que l'onglet Bourses.
    if (deadline == null || entry.deadlineIsEstimated) {
      return (
        label: 'deadlines_date_to_confirm'.tr,
        color: context.kpb.textMuted
      );
    }
    // En jours CALENDAIRES : une échéance posée à minuit s'affichait
    // « Passée » toute la journée du jour J, et `inDays` tronqué retirait un
    // jour au compte à rebours.
    final local = deadline.toLocal();
    final today = now.toLocal();
    final days = DateTime.utc(local.year, local.month, local.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
    if (days < 0) {
      return (label: 'deadlines_status_past'.tr, color: context.kpb.textMuted);
    }
    if (days <= 1) {
      return (
        label: 'deadlines_status_today_tomorrow'.tr,
        color: KpbColors.error
      );
    }
    if (days <= 30) {
      return (
        label: 'deadlines_status_days'.trParams({'n': '$days'}),
        color: KpbColors.warning
      );
    }
    // `'$days jours'` vivait ici en dur : un utilisateur anglophone lisait un
    // badge français au-delà de 30 jours.
    return (
      label: 'deadlines_status_days'.trParams({'n': '$days'}),
      color: KpbColors.success
    );
  }
}
