import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/followed_scholarships_store.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/study_level.dart';
import '../deadlines/deadline_calendar_screen.dart';
import '../explore/program_detail_screen.dart';
import '../explore/country_detail_screen.dart';
import 'followed_scholarships_section.dart';

/// « Mes suivis » : les bourses suivies d'abord (page du serveur, cache
/// Hive), puis le calendrier des échéances et les autres favoris.
///
/// Écran poussé (route `/saved`, push groupé « {n} bourses que tu suis sont
/// ouvertes », en-têtes Bourses et Accueil, Profil) : il porte son propre
/// Scaffold et sa barre — il n'en avait aucune.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, this.store});

  /// Pour les tests ; l'instance partagée sinon.
  final FollowedScholarshipsStore? store;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late final FollowedScholarshipsStore _store =
      widget.store ?? FollowedScholarshipsStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    unawaited(_loadFollowed());
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  bool _followedEnabled(AppController controller) =>
      RemoteFeatureFlags.instance.followedScholarshipsEnabled &&
      AppConfig.enableRemoteSync &&
      controller.profile != null &&
      !controller.isGuestMode;

  Future<void> _loadFollowed() async {
    final controller = Get.find<AppController>();
    final profile = controller.profile;
    if (!_followedEnabled(controller) || profile == null) return;
    await _store.load(
      client: controller.apiClient,
      userId: profile.id,
      lang: controller.localeCode,
    );
    final page = _store.page;
    if (_store.endpoint == FollowedEndpointState.available && page != null) {
      controller.noteServerSupportsFollow();
      controller.rememberServerFollowedScholarships(
        page.items.map((item) => item.id),
      );
    }
  }

  Future<void> _refresh() async {
    final controller = Get.find<AppController>();
    await Future.wait<void>(<Future<void>>[
      controller.pullToRefresh(),
      _loadFollowed(),
    ]);
  }

  /// La section serveur s'affiche dès qu'une page existe (fraîche ou du
  /// cache) ; elle se masque si le serveur ne connaît pas la route (404).
  FollowedScholarshipsPage? _sectionPage(AppController controller) {
    if (!_followedEnabled(controller)) return null;
    if (_store.endpoint == FollowedEndpointState.unavailable) return null;
    return _store.page;
  }

  void _onUnfollowed(AppController controller, FollowedScholarship item) {
    showSavedUndoSnackbar(
      'followed_removed'.trParams({'title': item.title}),
      () => controller.setScholarshipFollow(item.id, following: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        title: Text('followed_title'.tr),
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: KpbColors.canvas,
        elevation: 0,
      ),
      body: GetBuilder<AppController>(
        builder: (_) {
          final items = controller.savedItems;
          final sectionPage = _sectionPage(controller);
          final showSection = sectionPage != null;
          // Sans la section (backend sans la route, hors connexion au premier
          // passage), les bourses suivies restent listées depuis le catalogue.
          final scholarships = showSection
              ? const <SavedItem>[]
              : items
                  .where((e) => e.type == SavedItemType.scholarship)
                  .where(
                      (e) => controller.scholarshipByIdOrNull(e.itemId) != null)
                  .toList();

          final fields =
              items.where((e) => e.type == SavedItemType.field).toList();
          final countries =
              items.where((e) => e.type == SavedItemType.country).toList();
          final institutions =
              items.where((e) => e.type == SavedItemType.institution).toList();
          final programs =
              items.where((e) => e.type == SavedItemType.program).toList();

          return KpbRefresh(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad,
                      KpbSpacing.lg,
                      KpbSpacing.pagePad,
                      KpbSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items.isEmpty
                              ? 'saved_none_yet'.tr
                              : (items.length > 1
                                      ? 'saved_count_other'
                                      : 'saved_count_one')
                                  .trParams({'count': '${items.length}'}),
                          style: KpbTextStyles.bodySm,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Bourses suivies (en premier) ─────────────────────────────
                if (sectionPage != null)
                  SliverToBoxAdapter(
                    child: FollowedScholarshipsSection(
                      page: sectionPage,
                      offline: _store.offline,
                      onUnfollowed: (item) => _onUnfollowed(controller, item),
                    ),
                  ),

                // ── Deadline calendar banner ────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad, 0,
                        KpbSpacing.pagePad, KpbSpacing.md),
                    child: GestureDetector(
                      onTap: () => Get.to(() => const DeadlineCalendarScreen()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: KpbSpacing.md, vertical: 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [KpbColors.blue, KpbColors.sky],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: KpbRadius.lgBr,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: KpbRadius.smBr,
                              ),
                              child: const Icon(
                                Icons.calendar_month_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'deadlines_title'.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: KpbFontSize.md,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'track_admission_deadlines'.tr,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: KpbFontSize.xs,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Empty state ─────────────────────────────────────────────
                if (items.isEmpty && !showSection)
                  SliverFillRemaining(
                    child: KpbEmptyState(
                      icon: Icons.bookmark_border_rounded,
                      title: 'saved_empty_title'.tr,
                      subtitle: 'saved_empty_subtitle'.tr,
                    ),
                  )
                else ...[
                  // ── Bourses (repli local, sans la section serveur) ────────
                  if (scholarships.isNotEmpty)
                    _SavedGroup(
                      icon: Icons.workspace_premium_outlined,
                      iconColor: KpbColors.success,
                      label: 'followed_scholarships_section'.tr,
                      items: scholarships,
                      controller: controller,
                      onRemove: (item) => controller
                          .setScholarshipFollow(item.itemId, following: false),
                      onRestore: (item) => controller
                          .setScholarshipFollow(item.itemId, following: true),
                      buildItem: (item) {
                        final scholarship =
                            controller.scholarshipByIdOrNull(item.itemId);
                        if (scholarship == null) return const SizedBox.shrink();
                        return _SavedTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.kpb.surfaceBg,
                              borderRadius: KpbRadius.mdBr,
                            ),
                            child: Center(
                              child: Text(
                                countryFlag(scholarship.countryId),
                                style:
                                    const TextStyle(fontSize: KpbFontSize.xl),
                              ),
                            ),
                          ),
                          title: controller.resolve(scholarship.name),
                          subtitle:
                              controller.resolve(scholarship.typeOfFunding),
                          onTap: () => Get.toNamed<void>(
                            AppRoutes.scholarshipDetailPath(scholarship.id),
                          ),
                          onRemove: () => controller.setScholarshipFollow(
                            scholarship.id,
                            following: false,
                          ),
                        );
                      },
                    ),

                  // ── Filières ──────────────────────────────────────────────
                  if (fields.isNotEmpty)
                    _SavedGroup(
                      icon: Icons.school_outlined,
                      iconColor: KpbColors.blue,
                      label: 'saved_group_fields'.tr,
                      items: fields,
                      controller: controller,
                      buildItem: (item) {
                        // Catalog id may no longer exist (renamed/deactivated by
                        // a backend sync) — skip rather than crash the tab with
                        // StateError from firstWhere.
                        final field = controller.fieldByIdOrNull(item.itemId);
                        if (field == null) return const SizedBox.shrink();
                        return _SavedTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: field.accentColor.withValues(alpha: 0.12),
                              borderRadius: KpbRadius.mdBr,
                            ),
                            child: Icon(Icons.school_rounded,
                                color: field.accentColor, size: 20),
                          ),
                          title: controller.resolve(field.name),
                          subtitle: field.careers
                              .take(2)
                              .map((c) => controller.resolve(c))
                              .join(', '),
                          onRemove: () =>
                              controller.toggleSaved(item.type, item.itemId),
                        );
                      },
                    ),

                  // ── Pays ──────────────────────────────────────────────────
                  if (countries.isNotEmpty)
                    _SavedGroup(
                      icon: Icons.public_rounded,
                      iconColor: KpbColors.sky,
                      label: 'saved_group_countries'.tr,
                      items: countries,
                      controller: controller,
                      buildItem: (item) {
                        final country =
                            controller.countryByIdOrNull(item.itemId);
                        if (country == null) return const SizedBox.shrink();
                        return _SavedTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.kpb.surfaceBg,
                              borderRadius: KpbRadius.mdBr,
                            ),
                            child: Center(
                              child: Text(
                                countryFlag(country.id),
                                style:
                                    const TextStyle(fontSize: KpbFontSize.xl),
                              ),
                            ),
                          ),
                          title: controller.resolve(country.name),
                          subtitle: country.popularFieldIds.take(2).join(', '),
                          onRemove: () =>
                              controller.toggleSaved(item.type, item.itemId),
                          onTap: () => Get.to(
                              () => CountryDetailScreen(countryId: country.id)),
                        );
                      },
                    ),

                  // ── Universités ───────────────────────────────────────────
                  if (institutions.isNotEmpty)
                    _SavedGroup(
                      icon: Icons.account_balance_outlined,
                      iconColor: KpbColors.navy,
                      label: 'saved_group_institutions'.tr,
                      items: institutions,
                      controller: controller,
                      buildItem: (item) {
                        final institution =
                            controller.institutionByIdOrNull(item.itemId);
                        if (institution == null) return const SizedBox.shrink();
                        return _SavedTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: KpbColors.navy.withValues(alpha: 0.1),
                              borderRadius: KpbRadius.mdBr,
                            ),
                            child: const Icon(Icons.account_balance_rounded,
                                color: KpbColors.navy, size: 20),
                          ),
                          title: controller.resolve(institution.name),
                          subtitle: controller.resolve(institution.location),
                          badge: institution.isPartner
                              ? 'saved_partner_badge'.tr
                              : null,
                          onRemove: () =>
                              controller.toggleSaved(item.type, item.itemId),
                        );
                      },
                    ),

                  // ── Programmes ────────────────────────────────────────────
                  if (programs.isNotEmpty)
                    _SavedGroup(
                      icon: Icons.menu_book_outlined,
                      iconColor: KpbColors.gold,
                      label: 'saved_group_programs'.tr,
                      items: programs,
                      controller: controller,
                      buildItem: (item) {
                        final program =
                            controller.programByIdOrNull(item.itemId);
                        if (program == null) return const SizedBox.shrink();
                        return _SavedTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: KpbColors.gold.withValues(alpha: 0.1),
                              borderRadius: KpbRadius.mdBr,
                            ),
                            child: const Icon(Icons.menu_book_rounded,
                                color: KpbColors.gold, size: 20),
                          ),
                          title: controller.resolve(program.name),
                          subtitle:
                              '${programLevelLabel(controller.resolve(program.level))} · ${controller.resolve(program.duration)}',
                          onTap: () => Get.to(
                            () => ProgramDetailScreen(programId: program.id),
                          ),
                          onRemove: () =>
                              controller.toggleSaved(item.type, item.itemId),
                        );
                      },
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// « Retiré » + « Annuler » : le seul message de cet écran, pour toutes ses
/// listes. Un bandeau KpbToast d'information, avec l'action « Annuler » ; la
/// durée par défaut d'un bandeau à action laisse le temps d'appuyer.
void showSavedUndoSnackbar(String message, VoidCallback onUndo) {
  KpbToast.info(
    message,
    action: KpbToastAction(label: 'followed_undo'.tr, onPressed: onUndo),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved group (collapsible section)
// ─────────────────────────────────────────────────────────────────────────────
class _SavedGroup extends StatefulWidget {
  const _SavedGroup({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.items,
    required this.controller,
    required this.buildItem,
    this.onRemove,
    this.onRestore,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final List<SavedItem> items;
  final AppController controller;
  final Widget Function(SavedItem item) buildItem;

  /// Retrait (glisser) et rétablissement (Annuler). Par défaut, le favori.
  final void Function(SavedItem item)? onRemove;
  final void Function(SavedItem item)? onRestore;

  @override
  State<_SavedGroup> createState() => _SavedGroupState();
}

class _SavedGroupState extends State<_SavedGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad, 0, KpbSpacing.pagePad, KpbSpacing.md),
        child: Column(
          children: [
            // Group header
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.1),
                      borderRadius: KpbRadius.smBr,
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: KpbFontSize.md,
                      fontWeight: FontWeight.w700,
                      color: context.kpb.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.kpb.surfaceBg,
                      borderRadius: KpbRadius.pillBr,
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: TextStyle(
                        fontSize: KpbFontSize.xs,
                        fontWeight: FontWeight.w700,
                        color: context.kpb.textMuted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.kpb.gray300,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: KpbSpacing.sm),
              KpbCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: widget.items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    return Column(
                      children: [
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: context.kpb.gray100,
                          ),
                        Dismissible(
                          key: Key('saved-${item.type.name}-${item.itemId}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: context.kpb.errorLight,
                              borderRadius: KpbRadius.lgBr,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: KpbColors.error,
                              size: 22,
                            ),
                          ),
                          confirmDismiss: (_) async => true,
                          onDismissed: (_) {
                            final remove = widget.onRemove;
                            if (remove != null) {
                              remove(item);
                            } else {
                              widget.controller
                                  .toggleSaved(item.type, item.itemId);
                            }
                            showSavedUndoSnackbar('item_deleted'.tr, () {
                              final restore = widget.onRestore;
                              if (restore != null) {
                                restore(item);
                              } else {
                                widget.controller
                                    .ensureSaved(item.type, item.itemId);
                              }
                            });
                          },
                          child: widget.buildItem(item),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved tile
// ─────────────────────────────────────────────────────────────────────────────
class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onRemove,
    this.badge,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: KpbSpacing.md, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: KpbTextStyles.titleMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        KpbBadge(label: badge!, color: KpbColors.gold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: KpbTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'a11y_remove'.tr,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: KpbColors.error.withValues(alpha: 0.08),
                    borderRadius: KpbRadius.smBr,
                  ),
                  child: const Icon(Icons.bookmark_remove_rounded,
                      color: KpbColors.error, size: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
