import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../scholarships/widgets/scholarship_status_line.dart';

/// Les tris de la section.
enum FollowedSort { status, deadline, name }

/// Le statut d'une bourse suivie connue SEULEMENT du catalogue local (suivie
/// hors ligne, pas encore dans la page du serveur) : on n'affirme que ce que la
/// date limite permet d'affirmer.
FollowedScholarship followedFromCatalog(
  ScholarshipModel scholarship,
  String title,
) {
  final deadline = scholarship.deadlineAt;
  final estimated = scholarship.deadlineIsEstimated;
  final closed =
      !estimated && deadline != null && !DateTime.now().isBefore(deadline);
  return FollowedScholarship(
    id: scholarship.id,
    title: title,
    countryId: scholarship.countryId,
    countryName: '',
    displayStatus: closed
        ? FollowedDisplayStatus.closed
        : estimated || deadline == null
            ? FollowedDisplayStatus.forecast
            : FollowedDisplayStatus.open,
    deadlineAt: deadline,
    dateConfidence: estimated ? 'estimated' : 'confirmed',
    viaFavorite: true,
  );
}

int _statusRank(ScholarshipStatusKind kind) => switch (kind) {
      ScholarshipStatusKind.open => 0,
      ScholarshipStatusKind.opensOn => 1,
      ScholarshipStatusKind.openingEstimated => 2,
      ScholarshipStatusKind.closed => 3,
    };

/// Trie [items] : par statut (ouvertes d'abord, puis la plus proche), par date
/// limite (la plus proche d'abord, inconnues à la fin) ou par nom.
@visibleForTesting
List<FollowedScholarship> sortFollowedScholarships(
  List<FollowedScholarship> items,
  FollowedSort sort, {
  DateTime? now,
}) {
  int compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int byName(FollowedScholarship a, FollowedScholarship b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  final sorted = List<FollowedScholarship>.of(items);
  switch (sort) {
    case FollowedSort.name:
      sorted.sort(byName);
    case FollowedSort.deadline:
      sorted.sort((a, b) {
        final byDate = compareDates(
          a.confirmedCloseAt ?? a.estimatedCloseAt,
          b.confirmedCloseAt ?? b.estimatedCloseAt,
        );
        return byDate != 0 ? byDate : byName(a, b);
      });
    case FollowedSort.status:
      sorted.sort((a, b) {
        final la = a.statusLine(now: now);
        final lb = b.statusLine(now: now);
        final rank = _statusRank(la.kind) - _statusRank(lb.kind);
        if (rank != 0) return rank;
        final byDate = la.kind == ScholarshipStatusKind.closed
            ? compareDates(lb.date, la.date)
            : compareDates(la.date, lb.date);
        return byDate != 0 ? byDate : byName(a, b);
      });
  }
  return sorted;
}

/// Section « Bourses suivies » de Mes suivis.
///
/// Données : la page du serveur ([page]) + les bourses suivies localement que
/// le serveur ne connaît pas encore (suivies hors ligne). Une ligne s'efface
/// dès qu'elle n'est plus suivie localement — le glisser pour retirer et son
/// « Annuler » sont immédiats, le serveur suit en arrière-plan.
class FollowedScholarshipsSection extends StatefulWidget {
  const FollowedScholarshipsSection({
    super.key,
    required this.page,
    required this.offline,
    required this.onUnfollowed,
  });

  final FollowedScholarshipsPage page;

  /// La page vient du cache : le réseau a échoué.
  final bool offline;

  /// Une bourse vient d'être retirée (glisser ou bouton) : l'écran propose
  /// « Annuler ».
  final void Function(FollowedScholarship item) onUnfollowed;

  @override
  State<FollowedScholarshipsSection> createState() =>
      _FollowedScholarshipsSectionState();
}

class _FollowedScholarshipsSectionState
    extends State<FollowedScholarshipsSection> {
  FollowedSort _sort = FollowedSort.status;

  List<FollowedScholarship> _visible(AppController controller) {
    final seen = <String>{};
    final items = <FollowedScholarship>[];
    for (final item in widget.page.items) {
      if (!controller.isFollowingScholarship(item.id)) continue;
      if (seen.add(item.id)) items.add(item);
    }
    for (final saved in controller.savedItems) {
      if (saved.type != SavedItemType.scholarship) continue;
      if (seen.contains(saved.itemId)) continue;
      final scholarship = controller.scholarshipByIdOrNull(saved.itemId);
      if (scholarship == null) continue;
      seen.add(saved.itemId);
      items.add(followedFromCatalog(
        scholarship,
        controller.resolve(scholarship.name),
      ));
    }
    return sortFollowedScholarships(items, _sort);
  }

  void _unfollow(AppController controller, FollowedScholarship item) {
    controller.setScholarshipFollow(item.id, following: false);
    widget.onUnfollowed(item);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final items = _visible(controller);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              KpbSpacing.pagePad, 0, KpbSpacing.pagePad, KpbSpacing.md),
          child: Column(
            key: const ValueKey<String>('followed-scholarships-section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: KpbColors.success.withValues(alpha: 0.12),
                      borderRadius: KpbRadius.smBr,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: KpbColors.success, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'followed_scholarships_section'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.md,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.brandNavy,
                        ),
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: KpbColors.surfaceMuted,
                        borderRadius: KpbRadius.pillBr,
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.offline && widget.page.fetchedAt != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 14, color: KpbColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'followed_offline'.trParams({
                          'date': formatScholarshipDay(widget.page.fetchedAt!),
                        }),
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          color: KpbColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              if (items.isEmpty)
                _EmptyFollowed(controller: controller)
              else ...[
                if (items.length > 1) _sortBar(),
                const SizedBox(height: 6),
                KpbCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: KpbColors.border,
                          ),
                        Dismissible(
                          key: ValueKey<String>('followed-${items[i].id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: KpbColors.errorLight,
                              borderRadius: KpbRadius.lgBr,
                            ),
                            child: const Icon(
                              Icons.bookmark_remove_rounded,
                              color: KpbColors.error,
                              size: 22,
                            ),
                          ),
                          onDismissed: (_) => _unfollow(controller, items[i]),
                          child: _FollowedTile(
                            item: items[i],
                            onRemove: () => _unfollow(controller, items[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sortBar() {
    Widget chip(FollowedSort sort, String key) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: ValueKey<String>('followed-sort-${sort.name}'),
            label:
                Text(key.tr, style: const TextStyle(fontSize: KpbFontSize.xs)),
            selected: _sort == sort,
            onSelected: (_) => setState(() => _sort = sort),
          ),
        );

    return Semantics(
      label: 'followed_sort_label'.tr,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(FollowedSort.status, 'followed_sort_status'),
            chip(FollowedSort.deadline, 'followed_sort_deadline'),
            chip(FollowedSort.name, 'followed_sort_name'),
          ],
        ),
      ),
    );
  }
}

class _FollowedTile extends StatelessWidget {
  const _FollowedTile({required this.item, required this.onRemove});

  final FollowedScholarship item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final line = item.statusLine();
    final subtitle = item.countryName.trim();
    return InkWell(
      onTap: item.detailAvailable
          ? () => Get.toNamed<void>(AppRoutes.scholarshipDetailPath(item.id))
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KpbSpacing.md, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KpbColors.surfaceMuted,
                borderRadius: KpbRadius.mdBr,
              ),
              child: Center(
                child: Text(
                  countryFlag(item.countryId),
                  style: const TextStyle(fontSize: KpbFontSize.xl),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: KpbFontSize.md,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.brandNavy,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        color: KpbColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ScholarshipStatusChip(line: line),
                      if (!item.notifyOpening &&
                          line.kind != ScholarshipStatusKind.closed)
                        _MutedPill(label: 'followed_opening_muted'.tr),
                    ],
                  ),
                  if (!item.detailAvailable) ...[
                    const SizedBox(height: 6),
                    Text(
                      'followed_detail_unavailable'.tr,
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        color: KpbColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'followed_remove_a11y'.trParams({'title': item.title}),
              onPressed: onRemove,
              icon: const Icon(Icons.bookmark_remove_outlined,
                  color: KpbColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedPill extends StatelessWidget {
  const _MutedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: KpbColors.surfaceMuted,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 14, color: KpbColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: KpbFontSize.xs,
              fontWeight: FontWeight.w700,
              color: KpbColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFollowed extends StatelessWidget {
  const _EmptyFollowed({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        children: [
          const Icon(Icons.bookmark_add_outlined,
              size: 32, color: KpbColors.actionPrimary),
          const SizedBox(height: 10),
          Text(
            'followed_empty_title'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: KpbFontSize.md,
              fontWeight: FontWeight.w800,
              color: KpbColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'followed_empty_body'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: KpbFontSize.sm,
              height: 1.45,
              color: KpbColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          KpbButton(
            key: const ValueKey<String>('followed-empty-cta'),
            label: 'followed_empty_cta'.tr,
            icon: Icons.search_rounded,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              controller.goToTab(StudentShellTab.scholarships);
            },
          ),
        ],
      ),
    );
  }
}
