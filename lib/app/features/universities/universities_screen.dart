import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/program_intakes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/program_filter_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/ui/shell_chrome.dart';
import '../../core/ui/skeleton_loader.dart';
import '../../core/utils/study_level.dart';
import '../../core/utils/tuition_utils.dart';
import '../compare/institution_compare_screen.dart';
import '../explore/country_detail_screen.dart';
import '../explore/program_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Couleurs : tokens sémantiques centraux (KpbColors — architecture §6/§10.2).

/// The five compact filters in the approved university-list design. The
/// advanced catalog filters remain available from the trailing `Filtres` chip.
enum _QuickFilter { matches, france, canada, saved, budget }

/// M6 — Écoles list: destinations carousel, filters and a match-ranked list of
/// formations. Visual restyle to the App-engagement handoff; the GetX
/// controller, catalog filtering and pagination are unchanged.
class UniversitiesScreen extends StatefulWidget {
  const UniversitiesScreen({super.key, this.initialFieldId});

  /// Pre-filter from orientation or deep link.
  final String? initialFieldId;

  @override
  State<UniversitiesScreen> createState() => _UniversitiesScreenState();
}

class _UniversitiesScreenState extends State<UniversitiesScreen> {
  late ProgramFilterState _filters;
  bool _filtersExpanded = false;
  _QuickFilter _quickFilter = _QuickFilter.matches;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  static const _pageSize = 25;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _filters = ProgramFilterState(
      partnerOnly: true,
      fieldId: widget.initialFieldId,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// `maxScrollExtent` at which the last page was requested. Without it every
  /// scroll event near the bottom added a page and rebuilt (filter + sort of
  /// the whole catalogue), and `_visibleCount` grew without bound.
  double? _pageRequestedAtExtent;

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 400) return;
    if (_pageRequestedAtExtent == position.maxScrollExtent) return;
    // Load next page when within 400 px of the bottom — once per extent: a
    // new page grows the extent, which re-arms the trigger.
    _pageRequestedAtExtent = position.maxScrollExtent;
    setState(() => _visibleCount += _pageSize);
  }

  void _resetFilters() {
    setState(() {
      _visibleCount = _pageSize;
      _pageRequestedAtExtent = null;
      _searchController.clear();
      _filters = ProgramFilterState(partnerOnly: _filters.partnerOnly);
      _quickFilter = _QuickFilter.matches;
    });
  }

  void _setPartnerOnly(bool value) {
    if (_filters.partnerOnly == value) return;
    setState(() {
      _filters = _filters.copyWith(partnerOnly: value);
      _quickFilter = _QuickFilter.matches;
      _visibleCount = _pageSize;
      _pageRequestedAtExtent = null;
    });
  }

  void _selectQuickFilter(_QuickFilter filter, AppController controller) {
    String? countryIdFor(String isoCode) {
      for (final country in controller.countries) {
        final id = country.id.toLowerCase();
        if (id == isoCode ||
            id == (isoCode == 'fr' ? 'fra' : 'can') ||
            controller.resolve(country.name).toLowerCase() ==
                (isoCode == 'fr' ? 'france' : 'canada')) {
          return country.id;
        }
      }
      return null;
    }

    setState(() {
      _quickFilter = filter;
      _visibleCount = _pageSize;
      _pageRequestedAtExtent = null;
      switch (filter) {
        case _QuickFilter.matches:
          _filters = _filters.copyWith(
            clearCountryId: true,
            budgetMaxEur: 30000,
          );
          break;
        case _QuickFilter.france:
          final franceId = countryIdFor('fr');
          if (franceId != null) {
            _filters = _filters.copyWith(countryId: franceId);
          }
          break;
        case _QuickFilter.canada:
          final canadaId = countryIdFor('ca');
          if (canadaId != null) {
            _filters = _filters.copyWith(countryId: canadaId);
          }
          break;
        case _QuickFilter.saved:
          break;
        case _QuickFilter.budget:
          _filters = _filters.copyWith(
            clearCountryId: true,
            budgetMaxEur: 3000000 / TuitionUtils.fcfaPerEur,
          );
          break;
      }
    });
  }

  void _openCompare(AppController controller) {
    final institutions = controller.institutions;
    if (institutions.length < 2) return;
    Get.to(
      () => InstitutionCompareScreen(
        institutionId1: institutions[0].id,
        institutionId2: institutions[1].id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        var programs = ProgramFilterService.apply(
          controller.programs,
          _filters,
          controller,
        );
        if (_quickFilter == _QuickFilter.saved) {
          programs = programs
              .where(
                (program) => controller.isSaved(
                  SavedItemType.program,
                  program.id,
                ),
              )
              .toList();
        }
        programs.sort((left, right) {
          final matchOrder = controller
              .programMatch(right)
              .compareTo(controller.programMatch(left));
          if (matchOrder != 0) return matchOrder;
          return controller
              .resolve(left.name)
              .toLowerCase()
              .compareTo(controller.resolve(right.name).toLowerCase());
        });
        final destinations = controller.countries.take(8).toList();

        return Scaffold(
          backgroundColor: KpbColors.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  hasProfile: controller.profile != null,
                  onCompare: controller.institutions.length >= 2
                      ? () => _openCompare(controller)
                      : null,
                ),
                Expanded(
                  child: controller.programs.isEmpty && controller.isSyncing
                      ? _ProgramSkeletonList()
                      : controller.programs.isEmpty
                          ? KpbEmptyState(
                              icon: Icons.menu_book_outlined,
                              title: 'explore_no_programs_title'.tr,
                              subtitle: 'universities_empty_sync_subtitle'.tr,
                            )
                          : _Body(
                              controller: controller,
                              programs: programs,
                              destinations: destinations,
                              filters: _filters,
                              quickFilter: _quickFilter,
                              filtersExpanded: _filtersExpanded,
                              searchController: _searchController,
                              scrollController: _scrollController,
                              visibleCount: _visibleCount,
                              onPartnerOnly: _setPartnerOnly,
                              onToggleExpanded: () => setState(
                                  () => _filtersExpanded = !_filtersExpanded),
                              onQuickFilter: (filter) =>
                                  _selectQuickFilter(filter, controller),
                              // Taper une recherche garde la puce active : la
                              // remettre sur « Meilleures correspondances »
                              // sans réappliquer son filtre laissait un filtre
                              // France/budget actif mais invisible, et perdait
                              // le filtre « Enregistrés ».
                              onQueryChanged: (value) => setState(() {
                                _filters = _filters.copyWith(query: value);
                                _visibleCount = _pageSize;
                                _pageRequestedAtExtent = null;
                              }),
                              onFiltersChanged: (next) => setState(() {
                                _filters = next;
                                _quickFilter = _QuickFilter.matches;
                              }),
                              onReset: _resetFilters,
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed header — title + subtitle + Compare pill (opens the comparator).
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.hasProfile, this.onCompare});

  /// Sans profil, le tri n'est pas personnalisé : on invite à le compléter
  /// plutôt que d'annoncer un classement qui n'existe pas.
  final bool hasProfile;
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 56 à gauche : le shell peint son hamburger flottant en haut-à-gauche de
      // chaque onglet (4 + 48 pt). À 16, le titre passait derrière.
      padding: const EdgeInsets.fromLTRB(56, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'nav_universities'.tr,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: KpbColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasProfile
                      ? 'uni_list_subtitle'.tr
                      : 'uni_list_subtitle_no_profile'.tr,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: KpbColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onCompare != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onCompare,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: KpbColors.actionPrimarySoft,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: KpbColors.actionPrimary.withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.compare_arrows_rounded,
                        size: 16, color: KpbColors.actionPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'compare'.tr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.actionPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrolling body — destinations carousel, filters, and the paginated list.
// Everything shares one ScrollController so infinite-scroll pagination still
// fires as the user reaches the bottom.
// ─────────────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.programs,
    required this.destinations,
    required this.filters,
    required this.quickFilter,
    required this.filtersExpanded,
    required this.searchController,
    required this.scrollController,
    required this.visibleCount,
    required this.onPartnerOnly,
    required this.onToggleExpanded,
    required this.onQuickFilter,
    required this.onQueryChanged,
    required this.onFiltersChanged,
    required this.onReset,
  });

  final AppController controller;
  final List<ProgramModel> programs;
  final List<CountryModel> destinations;
  final ProgramFilterState filters;
  final _QuickFilter quickFilter;
  final bool filtersExpanded;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final int visibleCount;
  final ValueChanged<bool> onPartnerOnly;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_QuickFilter> onQuickFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ProgramFilterState> onFiltersChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final shown = programs.take(visibleCount).toList();
    final hasMore = programs.length > visibleCount;

    // Header slots: [0] carousel, [1] filter block. Then rows (or an inline
    // empty state) and an optional load-more footer.
    const headerSlots = 2;
    final bodyCount = shown.isEmpty ? 1 : shown.length + (hasMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      // 24 pt laissaient la dernière carte de programme sous la pastille
      // copilote et la barre de navigation, qui flottent au-dessus de l'onglet.
      padding: EdgeInsets.only(bottom: KpbShellChrome.bottomReserve(context)),
      itemCount: headerSlots + bodyCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DestinationCarousel(destinations: destinations);
        }
        if (index == 1) {
          return _FilterBlock(
            controller: controller,
            filters: filters,
            quickFilter: quickFilter,
            expanded: filtersExpanded,
            searchController: searchController,
            resultCount: programs.length,
            onPartnerOnly: onPartnerOnly,
            onToggleExpanded: onToggleExpanded,
            onQuickFilter: onQuickFilter,
            onQueryChanged: onQueryChanged,
            onFiltersChanged: onFiltersChanged,
            onReset: onReset,
          );
        }

        if (shown.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 32),
            child: KpbEmptyState(
              icon: Icons.search_off_rounded,
              title: 'catalog_no_match_title'.tr,
              subtitle: 'catalog_no_match_body'.tr,
              actionLabel: 'm6_reset_filters'.tr,
              onAction: onReset,
            ),
          );
        }

        final bodyIndex = index - headerSlots;
        if (bodyIndex == shown.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final program = shown[bodyIndex];
        final institution =
            controller.institutionByIdOrNull(program.institutionId);
        final level = programLevelLabel(controller.resolve(program.level));
        final city =
            institution != null ? controller.resolve(institution.location) : '';
        final tuition = controller.resolve(program.tuition);
        // L'étiquette d'origine, et son équivalent SÉPARÉMENT — deux lignes, pas
        // une chaîne collée. Avant, la conversion REMPLAÇAIT l'étiquette et
        // « MAD 40 000/an » s'affichait « ~ 26 238 280 FCFA/an ».
        final tuitionEquivalent = TuitionUtils.equivalentFor(
          tuition,
          controller.profile?.preferredCurrency,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SchoolRow(
            flag: countryFlag(program.countryId),
            name: controller.resolve(program.name),
            subtitle: city.isNotEmpty ? '$level · $city' : level,
            feesLabel: tuition,
            feesEquivalent: tuitionEquivalent,
            intake: ProgramIntakeLine(
              program: program,
              institution: institution,
            ),
            fit: controller.programFit(program),
            saved: controller.isSaved(SavedItemType.program, program.id),
            onSave: () =>
                controller.toggleSaved(SavedItemType.program, program.id),
            onTap: () =>
                Get.to(() => ProgramDetailScreen(programId: program.id)),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Destinations carousel — dark navy country guide cards.
// ─────────────────────────────────────────────────────────────────────────────
class _DestinationCarousel extends StatelessWidget {
  const _DestinationCarousel({required this.destinations});
  final List<CountryModel> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();
    final controller = Get.find<AppController>();

    // FLU-06 — la hauteur du carrousel GRANDIT avec l'échelle de texte.
    //
    // `height: 126` en dur contenait exactement le contenu à l'échelle 1,0…
    // et rien d'autre : dès 1,1 — le PREMIER cran d'agrandissement d'Android —
    // les trois cartes visibles débordaient de 3 px chacune, et de 19 px à
    // 1,3.
    //
    // La formule part du 126 MESURÉ-BON à l'échelle 1,0 et lui ajoute
    // exactement la croissance des quatre lignes de texte (drapeau 26, nom
    // 12,5, sous-titre 9,5, CTA 9). Première tentative instructive : recalculer
    // la hauteur entière depuis des hauteurs de ligne devinées donnait 17,7 px
    // de débordement à l'échelle 1,0 — les glyphes émoji sont plus hauts que
    // toute estimation raisonnable. On n'invente donc pas la base, on la
    // reprend de la mesure ; seule la CROISSANCE est calculée, et elle ne
    // dépend que des tailles de police, qui sont dans ce fichier.
    final scaler = MediaQuery.textScalerOf(context);
    double growth(double fontSize) => (scaler.scale(fontSize) - fontSize) * 1.4;
    final cardHeight =
        126 + growth(26) + growth(12.5) + growth(9.5) + growth(9);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: SizedBox(
        height: cardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: destinations.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final country = destinations[index];
            // Un libellé de rentrée PASSÉ n'est pas affiché.
            final intake = upcomingIntakeText(
                    controller.resolve(country.nextIntakeLabel)) ??
                '';
            final tuition = controller.resolve(country.tuitionRange);
            final sub = intake.isNotEmpty ? intake : tuition;
            return _DestinationCard(
              flag: displayCountryFlag(
                  id: country.id, flagEmoji: country.flagEmoji),
              name: controller.resolve(country.name),
              sub: sub,
              onTap: () =>
                  Get.to(() => CountryDetailScreen(countryId: country.id)),
            );
          },
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.flag,
    required this.name,
    required this.sub,
    required this.onTap,
  });

  final String flag;
  final String name;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
        decoration: BoxDecoration(
          color: KpbColors.brandNavy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: KpbColors.textFaint,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'full_guide'.tr,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.decorSky,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 11, color: KpbColors.decorSky),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter block — search, Partners/All pills, an advanced-filter toggle and the
// expandable advanced panel (country · budget · level · field · language).
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBlock extends StatelessWidget {
  const _FilterBlock({
    required this.controller,
    required this.filters,
    required this.quickFilter,
    required this.expanded,
    required this.searchController,
    required this.resultCount,
    required this.onPartnerOnly,
    required this.onToggleExpanded,
    required this.onQuickFilter,
    required this.onQueryChanged,
    required this.onFiltersChanged,
    required this.onReset,
  });

  final AppController controller;
  final ProgramFilterState filters;
  final _QuickFilter quickFilter;
  final bool expanded;
  final TextEditingController searchController;
  final int resultCount;
  final ValueChanged<bool> onPartnerOnly;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_QuickFilter> onQuickFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ProgramFilterState> onFiltersChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    // Le seuil de budget, dans la devise que l'utilisateur lit.
    final budgetLabel = CurrencyUtils.formatEur(
      filters.budgetMaxEur.round(),
      controller.profile?.preferredCurrency,
      perYear: false,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuickFilterRow(
            selected: quickFilter,
            advancedSelected: expanded || filters.hasActiveFilters,
            onSelected: onQuickFilter,
            onOpenAdvanced: onToggleExpanded,
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: KpbInputDecoration.build(
                context,
                label: 'm6_search_program'.tr,
                prefixIcon: Icons.search_rounded,
              ),
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _FilterPill(
                  label: 'm6_tab_partners'.tr,
                  selected: filters.partnerOnly,
                  onTap: () => onPartnerOnly(true),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'm6_tab_all'.tr,
                  selected: !filters.partnerOnly,
                  onTap: () => onPartnerOnly(false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CountryFilter(
              countries: controller.countries,
              selectedId: filters.countryId,
              onChanged: (id) => onFiltersChanged(
                filters.copyWith(countryId: id, clearCountryId: id == null),
              ),
            ),
            const SizedBox(height: 12),
            // Le seuil est stocké en euros parce que c'est l'unité de
            // comparaison interne, mais il est AFFICHÉ dans la devise de
            // l'utilisateur. Écrire « 30000 € » à quelqu'un qui lit en francs CFA
            // — le défaut de TOUS les profils, `preferredCurrency` valant 'XOF'
            // par défaut — c'est lui demander de faire la conversion de tête
            // pendant qu'il compare des écoles. La parité EUR/XOF étant fixe, le
            // montant affiché est exact.
            Text(
              'm6_filter_budget'.trParams({'max': budgetLabel}),
              style: KpbTextStyles.caption,
            ),
            Slider(
              value: filters.budgetMaxEur,
              min: 1000,
              max: 30000,
              divisions: 29,
              label: budgetLabel,
              onChanged: (value) =>
                  onFiltersChanged(filters.copyWith(budgetMaxEur: value)),
            ),
            _ChipRow(
              label: 'm6_filter_level'.tr,
              options: programLevelFilters
                  .map((e) => (e.key, 'm6_level_${e.key}'.tr))
                  .toList(),
              selectedKey: filters.levelKey,
              onSelected: (key) => onFiltersChanged(
                filters.copyWith(levelKey: key, clearLevelKey: key == null),
              ),
            ),
            const SizedBox(height: 8),
            _ChipRow(
              label: 'm6_filter_field'.tr,
              options: [
                (null, 'catalog_filter_all'.tr),
                ...controller.fields
                    .map((f) => (f.id, controller.resolve(f.name))),
              ],
              selectedKey: filters.fieldId,
              onSelected: (key) => onFiltersChanged(
                filters.copyWith(fieldId: key, clearFieldId: key == null),
              ),
            ),
            const SizedBox(height: 8),
            _ChipRow(
              label: 'm6_filter_language'.tr,
              options: programLanguageFilters
                  .map((e) => (e.key, 'm6_language_${e.key}'.tr))
                  .toList(),
              selectedKey: filters.languageKey,
              onSelected: (key) => onFiltersChanged(
                filters.copyWith(
                    languageKey: key, clearLanguageKey: key == null),
              ),
            ),
            if (filters.hasActiveFilters)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onReset,
                  child: Text('m6_reset'.tr),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'catalog_program_count'.trParams({'count': '$resultCount'}),
            style: KpbTextStyles.caption.copyWith(color: KpbColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Horizontal filter row from the handoff. It intentionally keeps the more
/// detailed existing catalog controls behind one extra chip rather than
/// dropping search, partner selection, or the full accessibility path.
class _QuickFilterRow extends StatelessWidget {
  const _QuickFilterRow({
    required this.selected,
    required this.advancedSelected,
    required this.onSelected,
    required this.onOpenAdvanced,
  });

  final _QuickFilter selected;
  final bool advancedSelected;
  final ValueChanged<_QuickFilter> onSelected;
  final VoidCallback onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final budgetLimit = CurrencyUtils.compactEur(
      3000000 / TuitionUtils.fcfaPerEur,
      Get.find<AppController>().profile?.preferredCurrency,
    );
    final filters = <({String label, _QuickFilter value})>[
      (label: 'uni_filter_matches'.tr, value: _QuickFilter.matches),
      (label: 'uni_filter_france'.tr, value: _QuickFilter.france),
      (label: 'uni_filter_canada'.tr, value: _QuickFilter.canada),
      (label: 'uni_filter_saved'.tr, value: _QuickFilter.saved),
      (label: '< $budgetLimit', value: _QuickFilter.budget),
    ];

    return SizedBox(
      key: const ValueKey('university_quick_filters'),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        itemCount: filters.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == filters.length) {
            return _FilterPill(
              label: advancedSelected
                  ? 'm6_filters_active'.tr
                  : 'm6_filters_title'.tr,
              selected: advancedSelected,
              icon: advancedSelected
                  ? Icons.expand_less_rounded
                  : Icons.tune_rounded,
              onTap: onOpenAdvanced,
            );
          }
          final filter = filters[index];
          return _FilterPill(
            label: filter.label,
            selected: selected == filter.value,
            onTap: () => onSelected(filter.value),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? KpbColors.actionPrimary : KpbColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KpbColors.actionPrimarySoft : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? KpbColors.actionPrimary.withValues(alpha: 0.3)
                : KpbColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// School row — flag · name · level·city · fees · match badge · save heart.
// ─────────────────────────────────────────────────────────────────────────────
class _SchoolRow extends StatelessWidget {
  const _SchoolRow({
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.feesLabel,
    this.feesEquivalent,
    this.intake,
    required this.fit,
    required this.saved,
    required this.onSave,
    required this.onTap,
  });

  final String flag;
  final String name;
  final String subtitle;

  /// L'étiquette de frais TELLE QU'ELLE EST ÉCRITE dans le catalogue.
  final String feesLabel;

  /// L'équivalent dans la devise de l'utilisateur, sur SA PROPRE LIGNE — ou
  /// `null` quand on ne sait pas le calculer sans taux à entretenir.
  ///
  /// Deux textes et non une chaîne concaténée : mesuré, « 11 490 € – 11 690 €/an
  /// selon le campus · ≈ 7 536 946 – 7 668 137 FCFA » ne tient pas en une seule
  /// ligne, ni même en deux, dans les ~200 pt de large de cette colonne. Coller
  /// les deux moitiés forçait un ellipsis qui mangeait justement le prix ajouté.
  final String? feesEquivalent;

  /// La ligne des rentrées de la formation ([ProgramIntakeLine]), ou null.
  final Widget? intake;

  /// Qualitative profile fit — null (no badge) without a student profile.
  final ProfileFit? fit;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
          boxShadow: const [
            BoxShadow(
              color: KpbShadow.softNavy,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.brandNavy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: KpbColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (intake != null) ...[
                    const SizedBox(height: 3),
                    intake!,
                  ],
                  if (feesLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      feesLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.actionPrimary,
                      ),
                      // DEUX lignes, et c'est MESURÉ, pas estimé. La plus longue
                      // étiquette réelle du catalogue — « 11 490 € – 11 690 €/an
                      // selon le campus », les écoles multi-campus — ne tient pas
                      // en une ligne dans les ~200 pt de cette colonne : elle
                      // était coupée par un ellipsis, sans exception et sans
                      // qu'aucun test du dépôt ne le voie. Une ligne de plus dans
                      // une liste défilante ne coûte rien ; un demi-prix, si.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (feesEquivalent != null)
                      Text(
                        feesEquivalent!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.kpb.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                  // Sous les frais, pas dans la colonne de droite : le libellé
                  // (« Très bon match ») est plus large que l'ancien « 40 % » et
                  // y rognait le prix — mesuré par universities_tuition_display.
                  if (fit != null) ...[
                    const SizedBox(height: 6),
                    ProfileFitBadge(fit: fit!, fontSize: 11),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: 'a11y_save'.tr,
                  child: GestureDetector(
                    onTap: onSave,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: saved
                            ? KpbColors.errorLight
                            : KpbColors.surfaceMuted,
                      ),
                      child: Icon(
                        saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 15,
                        color: saved ? KpbColors.error : KpbColors.textFaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton list shown while the catalog is syncing (first launch).
// ─────────────────────────────────────────────────────────────────────────────
class _ProgramSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => SkeletonLoader.card(height: 90),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advanced filter widgets — country dropdown and horizontal chip rows.
// ─────────────────────────────────────────────────────────────────────────────
class _CountryFilter extends StatelessWidget {
  const _CountryFilter({
    required this.countries,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CountryModel> countries;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selectedId,
      decoration: KpbInputDecoration.build(
        context,
        label: 'm6_filter_country'.tr,
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('catalog_filter_all'.tr),
        ),
        ...countries.map(
          (country) => DropdownMenuItem<String?>(
            value: country.id,
            child: Text(
              '${countryFlag(country.id, fallbackEmoji: country.flagEmoji)} ${Get.find<AppController>().resolve(country.name)}',
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  final String label;
  final List<(String?, String)> options;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KpbTextStyles.caption),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((option) {
              final (key, text) = option;
              final selected = selectedKey == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(selected ? null : key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? KpbColors.actionPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: selected
                            ? KpbColors.actionPrimary
                            : KpbColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            selected ? Colors.white : KpbColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
