import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/success_lab_api_codec.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/shell_chrome.dart';
import '../../core/ui/skeleton.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../scholarship_match/scholarship_match_actions.dart';
import '../scholarship_match/scholarship_match_entry_card.dart';
import 'scholarship_detail_screen.dart';
import 'scholarship_guide_info_screen.dart';
import 'scholarship_urgency.dart';
import 'scholarships_controller.dart';
import 'widgets/follow_scholarship_button.dart';
import 'widgets/scholarship_filter_sheet.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture
// §6/§10.2). L'ancienne _Palette locale du handoff a été absorbée au lot 5 ;
// green/red/amberBg/redBg normalisés sur les rôles AA.
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

/// Le drapeau d'une carte : tiré de `countryId` (alpha-3 du serveur), et non
/// plus du nom du pays — une quinzaine de noms seulement étaient reconnus, et
/// « Royaume-Uni — University of Cambridge » retombait sur 🌍. Repli : le nom
/// tel quel (fiches d'un backend qui ne sert pas encore `countryId`), puis 🌍.
String scholarshipFlag(LiveScholarshipModel scholarship) {
  final byId = countryFlag(scholarship.countryId);
  if (scholarship.countryId.isNotEmpty || byId != '🌍') return byId;
  return countryFlag(scholarship.countryName);
}

/// Funding tag colours — bound to the real [fundingType]. Texte foncé sur fond
/// clair, 12 sp au moins.
(Color, Color, String) _fundingTag(LiveScholarshipModel s) {
  if (s.isFullyFunded) {
    return (
      KpbColors.successLight,
      KpbColors.success,
      'live_scholarships_fully_funded'.tr,
    );
  }
  if (s.isPartiallyFunded) {
    return (
      KpbColors.warningLight,
      KpbColors.warning,
      'live_scholarships_partially_funded'.tr,
    );
  }
  return (
    KpbColors.surfaceMuted,
    KpbColors.textSecondary,
    'live_scholarships_funding_unknown'.tr,
  );
}

/// Live scholarship index screen — fetches from the scraped /scholarships API.
/// Displays scholarships filtered and ranked by the user's profile.
class LiveScholarshipsScreen extends StatefulWidget {
  /// Optional [apiClient] for tests; production uses [AppApiClient] when null.
  const LiveScholarshipsScreen({
    super.key,
    this.apiClient,
    this.embeddedInShell = false,
  });

  final AppApiClient? apiClient;

  /// Vrai quand la liste est l'onglet Bourses de la coquille : elle n'a alors
  /// jamais de flèche retour. `Navigator.canPop` y était lu au moment d'une
  /// reconstruction déclenchée pendant qu'une fiche était empilée (« Suivre »
  /// appelle `AppController.update()`) ; la flèche restait ensuite, et la
  /// toucher dépilait la seule page : écran noir (audit build 57, n° 1).
  final bool embeddedInShell;

  @override
  State<LiveScholarshipsScreen> createState() => _LiveScholarshipsScreenState();
}

class _LiveScholarshipsScreenState extends State<LiveScholarshipsScreen> {
  late final AppApiClient _apiClient;
  late final ScholarshipsController _scholarshipsController;
  final ScrollController _paginationController = ScrollController();
  bool _successLabEnabled = false;

  List<LiveScholarshipModel> get _items => _scholarshipsController.items;
  bool get _loading => _scholarshipsController.loading;
  String? get _error => _scholarshipsController.error;

  /// Vrai quand le serveur a répondu 401 : l'index des bourses est réservé aux
  /// comptes. Ce n'est PAS une panne de réseau, et le dire l'était.
  bool get _authRequired =>
      _scholarshipsController.failure == ScholarshipsFailure.authRequired;

  @override
  void initState() {
    super.initState();
    final appController = Get.find<AppController>();
    final profile = appController.profile;
    _apiClient = widget.apiClient ?? appController.apiClient;
    _scholarshipsController = ScholarshipsController(
      apiClient: _apiClient,
      lang: profile?.preferredLanguage == 'en' ? 'en' : 'fr',
      level: profile?.targetLevel,
      fieldIds: profile?.fieldIds,
    )..addListener(_onScholarshipsChanged);
    _paginationController.addListener(_onScroll);
    _scholarshipsController.loadInitial();
    unawaited(_refreshSuccessLabAccess());
  }

  void _onScholarshipsChanged() {
    // Les alertes posées par la cloche des builds précédentes valent
    // « Suivie » partout dans l'app, pas seulement dans cette liste.
    final alerted = _scholarshipsController.alertedScholarshipIds;
    if (alerted.isNotEmpty) {
      Get.find<AppController>().rememberServerFollowedScholarships(alerted);
    }
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_paginationController.hasClients) return;
    if (_paginationController.position.extentAfter < 500) {
      _scholarshipsController.loadMore();
    }
  }

  Future<void> _load() async {
    await Future.wait<void>(<Future<void>>[
      _scholarshipsController.loadInitial(),
      _refreshSuccessLabAccess(),
    ]);
  }

  Future<bool> _refreshSuccessLabAccess() async {
    var enabled = false;
    try {
      final raw = await _apiClient.getSuccessLabAccess();
      enabled = SuccessLabApiCodec.accessFromApi(raw).enabled;
    } catch (_) {
      // Fail closed when auth, configuration, rollout, country resolution, or
      // the network cannot produce an authoritative access decision.
    }
    if (mounted && enabled != _successLabEnabled) {
      setState(() => _successLabEnabled = enabled);
    }
    return enabled;
  }

  Future<void> _openSuccessLab() async {
    if (!_successLabEnabled) return;
    final stillEnabled = await _refreshSuccessLabAccess();
    if (!mounted || !stillEnabled) return;
    await Get.toNamed(AppRoutes.successLab);
  }

  Future<void> _openFilters() async {
    final controller = _scholarshipsController;
    final choice = await showScholarshipFilterSheet(
      context,
      statuses: controller.statusFilter,
      funding: controller.fundingFilter,
    );
    // `null` = fermée sans valider ; écran disparu entre-temps : on ne touche
    // plus à un contrôleur détruit.
    if (choice == null || !mounted) return;
    await controller.applyFilters(
      statuses: choice.statuses,
      funding: choice.funding,
    );
  }

  Future<void> _openSort() async {
    final chosen = await showScholarshipSortSheet(
      context,
      current: _scholarshipsController.sort,
    );
    if (chosen == null || !mounted) return;
    await _scholarshipsController.changeSort(chosen);
  }

  @override
  void dispose() {
    _paginationController
      ..removeListener(_onScroll)
      ..dispose();
    _scholarshipsController
      ..removeListener(_onScholarshipsChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _scholarshipsController;
    final offlineSince = controller.offlineSince;
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: KpbRefresh(
          onRefresh: _load,
          child: CustomScrollView(
            controller: _paginationController,
            slivers: [
              // ── App bar ────────────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: KpbColors.canvas,
                surfaceTintColor: KpbColors.canvas,
                elevation: 0,
                automaticallyImplyLeading: false,
                leading: !widget.embeddedInShell && Navigator.canPop(context)
                    ? IconButton(
                        tooltip: 'a11y_back'.tr,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: KpbColors.brandNavy,
                        ),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                title: Text(
                  'scholarships_title'.tr,
                  style: const TextStyle(
                    fontSize: KpbFontSize.xl,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: KpbColors.brandNavy,
                  ),
                ),
                actions: [
                  if (_successLabEnabled)
                    IconButton(
                      key: const ValueKey<String>(
                        'scholarships-success-lab-entry',
                      ),
                      tooltip: 'success_lab_title'.tr,
                      icon: const Icon(
                        Icons.auto_awesome_outlined,
                        color: KpbColors.textMuted,
                      ),
                      onPressed: _openSuccessLab,
                    ),
                  IconButton(
                    key: const ValueKey<String>('scholarships-followed-entry'),
                    tooltip: 'followed_title'.tr,
                    icon: const Icon(
                      Icons.bookmarks_outlined,
                      color: KpbColors.brandNavy,
                    ),
                    onPressed: () => Get.toNamed<void>(AppRoutes.saved),
                  ),
                  IconButton(
                    tooltip: 'a11y_refresh'.tr,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: KpbColors.textMuted,
                    ),
                    onPressed: _load,
                  ),
                ],
              ),

              // ── Sub-header + « Filtrer » / tri ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'scholarships_sorted_hint'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          color: KpbColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Un `Wrap` et non une rangée qui défile : à l'échelle de
                      // texte 1,3 d'un 360 dp, « Trier : Clôture la plus
                      // proche » passe à la ligne au lieu d'être coupé.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ToolbarButton(
                            key: const ValueKey<String>(
                              'scholarships-filter-button',
                            ),
                            icon: Icons.tune_rounded,
                            label: controller.activeFilterCount == 0
                                ? 'scholarships_filter_button'.tr
                                : 'scholarships_filter_button_count'.trParams({
                                    'count': '${controller.activeFilterCount}',
                                  }),
                            active: controller.activeFilterCount > 0,
                            onTap: _openFilters,
                          ),
                          // Backend sans le chantier I (pas d'écho `query`) :
                          // il ignore `sort`, le bouton ne promet rien.
                          if (controller.serverAppliesQuery)
                            _ToolbarButton(
                              key: const ValueKey<String>(
                                'scholarships-sort-button',
                              ),
                              icon: Icons.sort_rounded,
                              label: 'scholarships_sort_button'.trParams({
                                'sort': scholarshipSortLabel(controller.sort),
                              }),
                              onTap: _openSort,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Le test « Mes 10 bourses » prend la place de la promotion du
              // guide (drapeau `scholarshipMatch`, élèves seulement) ; carte
              // cachée, le guide reste ici comme avant.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: ScholarshipMatchEntryCard(
                    fallback: _GuidePromoCard(
                      onTap: () =>
                          Get.to(() => const ScholarshipGuideInfoScreen()),
                    ),
                  ),
                ),
              ),

              // ── Hors ligne : la dernière liste reçue, datée ─────────────────
              // À la place de l'ancien écran plein « Erreur de connexion » :
              // l'élève garde ce qu'il avait, et sait de quand ça date.
              if (offlineSince != null && !_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KpbCacheStamp(
                      key: const ValueKey<String>('scholarships-offline-stamp'),
                      updatedAt: offlineSince,
                      offline: true,
                      onRetry: _load,
                    ),
                  ),
                ),

              // ── Content ──────────────────────────────────────────────────────
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Semantics(
                          label: index == 0 ? 'async_loading'.tr : null,
                          child: const KpbSkeletonBox(
                            height: 108,
                            radius: KpbRadius.md,
                          ),
                        ),
                      ),
                      childCount: 5,
                    ),
                  ),
                )
              // ── 401 : il faut un compte, et « Réessayer » n'y changerait
              // rien ────────────────────────────────────────────────────────
              // C'est le cas de l'invité, celui que l'app met le plus en avant :
              // il touche l'onglet du MILIEU depuis « Explorer sans compte ».
              // L'écran lui disait « problème de connexion » avec un unique
              // bouton « Réessayer » — un message faux ET une impasse, puisque
              // aucun nombre de tentatives ne fabrique une session.
              else if (_authRequired)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: KpbGuestGate(
                    source: 'scholarships_gate',
                    icon: Icons.workspace_premium_outlined,
                    titleKey: 'scholarships_auth_required_title',
                    bodyKey: 'scholarships_auth_required_body',
                    ctaKey: 'scholarships_auth_required_cta',
                  ),
                )
              // Plus rien sur le disque pour ces filtres (premier lancement
              // hors ligne) : seul cas où l'erreur occupe encore l'écran.
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: KpbEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'live_scholarships_connection_error_title'.tr,
                      subtitle:
                          'live_scholarships_connection_error_subtitle'.tr,
                      action: KpbButton(
                        text: 'retry'.tr,
                        onPressed: _load,
                        bgColor: KpbColors.actionPrimary,
                      ),
                    ),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: _buildEmptyState()),
                )
              else ...[
                if (controller.profileFiltersRelaxed && offlineSince == null)
                  const SliverToBoxAdapter(child: _UnfilteredNotice()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      _countLabel(),
                      key: const ValueKey<String>('scholarships-count'),
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        color: KpbColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final s = _items[index];
                      return StaggeredSlide(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LiveScholarshipCard(
                            scholarship: s,
                            onTap: () => _openDetail(context, s),
                          ),
                        ),
                      );
                    }, childCount: _items.length),
                  ),
                ),
                // Carte du test visible : le guide descend sous la première
                // page de résultats (jamais trois promotions côte à côte).
                SliverToBoxAdapter(
                  child: ScholarshipMatchListener(
                    builder: (context, variant) => variant ==
                            ScholarshipMatchEntryVariant.hidden
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                            child: _GuidePromoCard(
                              onTap: () => Get.to(
                                () => const ScholarshipGuideInfoScreen(),
                              ),
                            ),
                          ),
                  ),
                ),
                if (controller.loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],

              // 100 pt dégageaient la barre de navigation mais pas la pastille
              // copilote (bande 92→140) : la dernière bourse restait dessous.
              const SliverToBoxAdapter(child: KpbShellBottomSpacer()),
            ],
          ),
        ),
      ),
    );
  }

  /// « 42 bourse(s) trouvée(s) » : le total RÉEL du serveur, pas la taille de
  /// la page chargée (20). Hors ligne : ce qui est gardé sur le téléphone.
  String _countLabel() {
    final controller = _scholarshipsController;
    if (controller.offlineSince != null) {
      return 'scholarships_offline_count'.trParams({
        'count': '${_items.length}',
      });
    }
    final total = controller.total;
    final count =
        total != null && total >= _items.length ? total : _items.length;
    return 'live_scholarships_result_count'.trParams({'count': '$count'});
  }

  /// Empty state that names the real reason instead of implying a breakdown.
  ///
  /// Three distinct situations, three distinct messages:
  ///  * a filter is still narrowing the query → say so and offer to drop it;
  ///  * every filter is already off → the published catalog is genuinely empty,
  ///    so promise nothing and offer a refresh;
  /// Never "modifie tes critères" when there are no critères left to modify —
  /// that reads as a loading failure and sends the student looking for a bug in
  /// their own profile.
  Widget _buildEmptyState() {
    final controller = _scholarshipsController;
    final chosenFilterActive = controller.activeFilterCount > 0;
    final profileFilterActive =
        controller.hasProfileFilters && !controller.profileFiltersRelaxed;
    final anyFilterActive = chosenFilterActive || profileFilterActive;

    if (anyFilterActive) {
      return KpbEmptyState(
        key: const ValueKey<String>('scholarships-empty-filtered'),
        icon: Icons.filter_alt_off_rounded,
        title: 'live_scholarships_empty_filtered_title'.tr,
        subtitle: 'live_scholarships_empty_filtered_subtitle'.tr,
        action: KpbButton(
          key: const ValueKey<String>('scholarships-show-all'),
          text: 'live_scholarships_show_all'.tr,
          onPressed: controller.clearAllFilters,
          bgColor: KpbColors.actionPrimary,
        ),
      );
    }

    return KpbEmptyState(
      key: const ValueKey<String>('scholarships-empty-catalog'),
      icon: Icons.hourglass_empty_rounded,
      title: 'live_scholarships_empty_catalog_title'.tr,
      subtitle: 'live_scholarships_empty_catalog_subtitle'.tr,
      action: KpbButton(
        text: 'retry'.tr,
        onPressed: _load,
        bgColor: KpbColors.actionPrimary,
      ),
    );
  }

  void _openDetail(BuildContext context, LiveScholarshipModel s) {
    Get.to(
      () => ScholarshipDetailScreen(
        scholarshipId: s.id,
        initialScholarship: s,
        apiClient: _apiClient,
      ),
      routeName: AppRoutes.scholarshipDetailPath(s.id),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List row
// ─────────────────────────────────────────────────────────────────────────────

/// Une carte de la liste : drapeau, titre, pays · niveau, la ligne de statut
/// (« Ouverte · clôture 6 janv. »), le financement, et « Suivre ».
class LiveScholarshipCard extends StatelessWidget {
  const LiveScholarshipCard({
    super.key,
    required this.scholarship,
    required this.onTap,
    this.now,
  });

  final LiveScholarshipModel scholarship;
  final VoidCallback onTap;

  /// Horloge injectée (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final (fundBg, fundFg, fundLabel) = _fundingTag(s);
    final urgency = scholarshipUrgencyOf(s, now: now);
    final subtitle =
        s.level.isEmpty ? s.countryName : '${s.countryName} · ${s.level}';

    return Material(
      color: KpbColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: KpbColors.surface,
            border: Border.all(color: KpbColors.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Le pays est lu dans le sous-titre : le drapeau est décoratif.
              ExcludeSemantics(
                child: Text(
                  scholarshipFlag(s),
                  key: const ValueKey<String>('scholarship-card-flag'),
                  style: const TextStyle(fontSize: KpbFontSize.xxl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: KpbFontSize.md,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: KpbFontSize.sm,
                        color: KpbColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // LE calcul d'urgence de la fiche (« Clôture proche »
                    // seulement sur une clôture confirmée à 14 jours ou
                    // moins, estimations au mois près) : la carte et la fiche
                    // ne peuvent plus dire deux choses de la même bourse.
                    ScholarshipUrgencyChip(urgency: urgency, now: now),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: fundBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        fundLabel,
                        style: TextStyle(
                          fontSize: KpbFontSize.xs,
                          fontWeight: FontWeight.w700,
                          color: fundFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // « Suivre » remplace la cloche « M'avertir » : la cloche ne
              // veut plus dire que « notifications ».
              FollowScholarshipButton(
                scholarshipId: s.id,
                scholarshipTitle: s.title,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

/// « Filtrer » / « Trier : … » : 48 dp de haut, libellé entier (jamais coupé),
/// plein quand un filtre est actif.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : KpbColors.textPrimary;
    return Semantics(
      button: true,
      child: Material(
        color: active ? KpbColors.actionPrimary : KpbColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: BorderSide(
            color: active ? KpbColors.actionPrimary : KpbColors.borderStrong,
          ),
        ),
        child: InkWell(
          onTap: () {
            KpbHaptics.selection();
            onTap();
          },
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: KpbFontSize.sm,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Disclosure shown when the listing could not be narrowed to the student's
/// profile and fell back to the whole catalog. Without it the screen would
/// silently pass an unfiltered list off as "sorted for you".
class _UnfilteredNotice extends StatelessWidget {
  const _UnfilteredNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('scholarships-unfiltered-notice'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: KpbColors.warningLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: KpbColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'live_scholarships_unfiltered_notice'.tr,
                style: const TextStyle(
                  fontSize: KpbFontSize.xs,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: KpbColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePromoCard extends StatelessWidget {
  const _GuidePromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('scholarship_guide_promo'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [KpbColors.actionPrimarySoft, KpbColors.surface],
        ),
        border: Border.all(
          color: KpbColors.actionPrimary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: KpbColors.actionPrimary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'scholarship_guide_short_title'.tr,
                      style: const TextStyle(
                        fontSize: KpbFontSize.sm,
                        fontWeight: FontWeight.w900,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'scholarship_guide_promo_body'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: KpbFontSize.xs,
                        height: 1.4,
                        color: KpbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Les deux actions passent SOUS le texte, dans un `Wrap` : à côté
          // du titre, « En savoir plus » écrasait la colonne à l'échelle de
          // texte 1,3 d'un 360 dp (débordement de 46 px, chantier I).
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: onTap,
                child: Text('scholarship_guide_learn_more'.tr),
              ),
              // Secondary, labelled shortcut for students already sold on the
              // guide — "En savoir plus" still opens the editorial screen
              // (owner video review, 08/2026: the card led nowhere
              // actionable).
              TextButton.icon(
                key: const ValueKey('scholarship_guide_promo_whatsapp'),
                onPressed: () => openWhatsAppOrToast(
                  prefill: 'scholarship_guide_whatsapp_prefill'.tr,
                  source: 'live_scholarships_guide_promo',
                  contextType: 'scholarship_guide',
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: Text('scholarship_guide_whatsapp_cta'.tr),
                style: TextButton.styleFrom(
                  foregroundColor: KpbColors.success,
                  textStyle: const TextStyle(
                    fontSize: KpbFontSize.sm,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
