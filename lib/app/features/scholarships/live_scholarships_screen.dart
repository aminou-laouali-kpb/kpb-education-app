import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/success_lab_api_codec.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/shell_chrome.dart';
import '../../core/utils/whatsapp_utils.dart';
import 'scholarship_detail_screen.dart';
import 'scholarship_guide_info_screen.dart';
import 'scholarships_controller.dart';
import 'widgets/follow_scholarship_button.dart';
import 'widgets/scholarship_status_line.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture
// §6/§10.2). L'ancienne _Palette locale du handoff a été absorbée au lot 5 ;
// green/red/amberBg/redBg normalisés sur les rôles AA.
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

const _flagMap = <String, String>{
  'Japan': '🇯🇵',
  'Japon': '🇯🇵',
  'France': '🇫🇷',
  'Germany': '🇩🇪',
  'Allemagne': '🇩🇪',
  'United States': '🇺🇸',
  'États-Unis': '🇺🇸',
  'USA': '🇺🇸',
  'Canada': '🇨🇦',
  'United Kingdom': '🇬🇧',
  'Royaume-Uni': '🇬🇧',
  'UK': '🇬🇧',
  'Australia': '🇦🇺',
  'Australie': '🇦🇺',
  'China': '🇨🇳',
  'Chine': '🇨🇳',
  'South Korea': '🇰🇷',
  'Corée du Sud': '🇰🇷',
  'Turkey': '🇹🇷',
  'Turquie': '🇹🇷',
  'Italy': '🇮🇹',
  'Italie': '🇮🇹',
  'Spain': '🇪🇸',
  'Espagne': '🇪🇸',
  'Morocco': '🇲🇦',
  'Maroc': '🇲🇦',
  'Tunisia': '🇹🇳',
  'Tunisie': '🇹🇳',
  'Switzerland': '🇨🇭',
  'Suisse': '🇨🇭',
  'Belgium': '🇧🇪',
  'Belgique': '🇧🇪',
  'Netherlands': '🇳🇱',
  'Pays-Bas': '🇳🇱',
  'Sweden': '🇸🇪',
  'Suède': '🇸🇪',
  'Senegal': '🇸🇳',
  'Sénégal': '🇸🇳',
  'International': '🌍',
};

String _flag(String country) => _flagMap[country] ?? '🌍';

String _shortDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

/// La fenêtre couvre-t-elle des MOIS ENTIERS (1er → dernier jour) ?
///
/// C'est la convention de saisie pour « on connaît la saison, pas la date » :
/// l'opérateur borne au mois, et la phrase affichée doit alors parler en mois.
/// Toute autre fenêtre a été saisie au jour près et est rendue telle quelle.
///
/// ## Tout se compare en UTC, et c'est le cœur du sujet
///
/// Ces bornes sont des dates SANS heure, écrites en UTC par le catalogue :
/// `2027-03-01T00:00:00.000Z` et `2027-04-30T23:59:59.000Z`. Les convertir en
/// heure locale les fait changer de jour calendaire pour presque tout le monde :
/// à l'ouest d'UTC, le 1er mars devient le 28 février ; à l'est — donc au Niger,
/// au Sénégal, en Côte d'Ivoire, c'est-à-dire notre public — le 30 avril à
/// 23 h 59 UTC devient le 1er mai. Dans les deux cas le test échouait pour la
/// convention même qu'il doit reconnaître, et la carte retombait sur des dates
/// précises trompeuses : exactement ce que ce lot corrige.
/// Le prédicat de [_isWholeMonthWindow], exposé aux tests.
///
/// Il vaut la peine d'être testé directement : sa première version comparait
/// en heure LOCALE et échouait, hors UTC, pour la convention même qu'elle doit
/// reconnaître. Un test qui passerait par l'écran entier n'aurait pas pu isoler
/// ce cas — et il aurait été vert sur une machine à UTC+0.
@visibleForTesting
bool isWholeMonthWindowForTest(DateTime open, DateTime close) =>
    _isWholeMonthWindow(open, close);

bool _isWholeMonthWindow(DateTime open, DateTime close) {
  final from = open.toUtc();
  final to = close.toUtc();
  // Dernier jour de `to` : le jour 0 du mois SUIVANT, calculé en UTC.
  final lastDayOfCloseMonth = DateTime.utc(to.year, to.month + 1, 0).day;
  return from.day == 1 && to.day == lastDayOfCloseMonth && !to.isBefore(from);
}

/// Le nom du mois dans la langue active (« mars », « March »).
///
/// En UTC, pour la raison écrite dans [_isWholeMonthWindow] : une borne de mois
/// convertie en local peut basculer sur le mois voisin, et on afficherait
/// « février » pour une fenêtre qui commence le 1er mars.
///
/// `try`/`catch` obligatoire, et ce n'est pas de la superstition : `DateFormat`
/// avec une locale explicite lève `LocaleDataException` si les données de cette
/// locale ne sont pas chargées — ce qui arrive hors d'un `MaterialApp`, donc
/// dans les tests. Le repli numérique ne peut pas lever et reste exact. C'est
/// exactement le patron déjà documenté et éprouvé dans `EefCalendar.dayLabel`.
String _monthName(DateTime date) {
  final utc = date.toUtc();
  final locale = Get.locale?.languageCode == 'en' ? 'en' : 'fr';
  try {
    return DateFormat('MMMM', locale).format(utc);
  } catch (_) {
    return utc.month.toString().padLeft(2, '0');
  }
}

(String, Color, Color)? _cyclePill(LiveScholarshipModel scholarship) {
  final cycle = scholarship.currentCycle;
  if (cycle == null) return null;
  if (cycle.isOpen) {
    // Jamais « Candidatures ouvertes » avant la date d'ouverture confirmée :
    // c'est ce que dira le push d'ouverture, la carte ne doit pas le devancer.
    final opensAt = cycle.opensAt;
    if (opensAt != null && opensAt.isAfter(DateTime.now())) {
      return (
        'scholarship_status_opens_on'
            .trParams({'date': formatScholarshipDay(opensAt)}),
        KpbColors.actionPrimarySoft,
        KpbColors.actionPrimary,
      );
    }
    final closing = cycle.closesAt ?? cycle.estimatedCloseAt;
    if (closing != null && closing.isBefore(DateTime.now())) {
      return (
        'live_scholarships_deadline_closed'.tr,
        KpbColors.surfaceMuted,
        KpbColors.textMuted,
      );
    }
    return (
      'live_scholarships_open_now'.tr,
      KpbColors.successLight,
      KpbColors.success,
    );
  }
  final estimatedOpen = cycle.estimatedOpenAt ?? cycle.opensAt;
  final estimatedClose = cycle.estimatedCloseAt ?? cycle.closesAt;
  if (estimatedOpen != null && estimatedClose != null) {
    // ── « À venir, généralement aux mois de mars – avril » ────────────────
    //
    // Quand la fenêtre couvre des MOIS ENTIERS (1er du mois → dernier jour du
    // mois), c'est la convention de saisie pour « on connaît la saison, pas la
    // date ». L'afficher en « 01/03/2027 – 30/04/2027 » revenait à annoncer au
    // jour près une campagne dont personne n'a publié le calendrier : deux
    // dates exactes qui ne sont que les bornes d'un mois. La granularité de la
    // phrase doit être celle de ce qu'on sait.
    if (_isWholeMonthWindow(estimatedOpen, estimatedClose)) {
      final from = _monthName(estimatedOpen);
      final to = _monthName(estimatedClose);
      return (
        from == to
            ? 'live_scholarships_upcoming_month'.trParams({'from': from})
            : 'live_scholarships_upcoming_months'
                .trParams({'from': from, 'to': to}),
        KpbColors.warningLight,
        KpbColors.warning,
      );
    }
    // Fenêtre estimée qui NE tombe pas sur des bornes de mois : l'opérateur a
    // saisi des dates précises, on les rend telles quelles.
    return (
      'live_scholarships_period_estimated'.trParams({
        'open': _shortDate(estimatedOpen),
        'close': _shortDate(estimatedClose),
      }),
      KpbColors.warningLight,
      KpbColors.warning,
    );
  }
  if (estimatedOpen != null) {
    return (
      'live_scholarships_open_estimated'
          .trParams({'date': _shortDate(estimatedOpen)}),
      KpbColors.warningLight,
      KpbColors.warning,
    );
  }
  return null;
}

// ── Real-data helpers ──────────────────────────────────────────────────────

/// Countdown badge derived from the REAL [LiveScholarshipModel.deadlineAt].
/// Returns null when the scholarship has no parsed date — the UI then shows a
/// neutral label rather than a fabricated countdown.
class _DeadlineBadge {
  const _DeadlineBadge(this.text, this.bg, this.fg, {this.soon = false});
  final String text;
  final Color bg;
  final Color fg;
  final bool soon;
}

_DeadlineBadge? _deadlineBadge(LiveScholarshipModel s) {
  final at = s.deadlineAt;
  if (at == null) return null;
  // Un compte à rebours au jour près sur une date ESTIMÉE serait un mensonge.
  // L'importeur remplit `deadlineAt` depuis `estimatedCloseAt` quand le cycle
  // n'est pas confirmé (import-scholarship-catalog.ts) — utile pour classer les
  // bourses par échéance, mais pas pour l'affirmer à l'étudiant. La plupart des
  // institutions africaines et des consortiums Erasmus ne publient AUCUNE date
  // pour la campagne suivante : la fenêtre estimée est alors la seule vérité
  // disponible, et `_cyclePill` l'affiche déjà comme telle (« Période estimée
  // du … au … », en ambre). On laisse donc la pastille de cycle parler seule.
  if (s.currentCycle?.isEstimated ?? false) return null;
  final days = at.difference(DateTime.now()).inDays;
  if (days < 0) {
    return _DeadlineBadge('live_scholarships_deadline_closed'.tr,
        KpbColors.surfaceMuted, KpbColors.textMuted);
  }
  final text = 'live_scholarships_deadline_days'.trParams({'count': '$days'});
  if (days <= 7) {
    return _DeadlineBadge(text, KpbColors.errorLight, KpbColors.error,
        soon: true);
  }
  if (days <= 30) {
    return _DeadlineBadge(text, KpbColors.warningLight, KpbColors.warning,
        soon: days <= 14);
  }
  return _DeadlineBadge(
      text, KpbColors.actionPrimarySoft, KpbColors.actionPrimary);
}

/// Color-coded funding chip — bound to the real [fundingType].
(Color, Color, String) _fundingChip(LiveScholarshipModel s) {
  if (s.isFullyFunded) {
    return (
      KpbColors.successLight,
      KpbColors.success,
      'live_scholarships_fully_funded'.tr
    );
  }
  if (s.isPartiallyFunded) {
    return (
      KpbColors.warningLight,
      KpbColors.warning,
      'live_scholarships_partially_funded'.tr
    );
  }
  return (
    KpbColors.surfaceMuted,
    KpbColors.textMuted,
    'live_scholarships_funding_unknown'.tr
  );
}

/// Live scholarship index screen — fetches from the scraped /scholarships API.
/// Displays scholarships filtered and ranked by the user's profile.
class LiveScholarshipsScreen extends StatefulWidget {
  /// Optional [apiClient] for tests; production uses [AppApiClient] when null.
  const LiveScholarshipsScreen({super.key, this.apiClient});

  final AppApiClient? apiClient;

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
  String get _fundingFilter => _scholarshipsController.fundingFilter;

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
                leading: Navigator.canPop(context)
                    ? IconButton(
                        tooltip: 'a11y_back'.tr,
                        icon: const Icon(Icons.arrow_back_rounded,
                            size: 20, color: KpbColors.brandNavy),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                title: Text(
                  'scholarships_title'.tr,
                  style: const TextStyle(
                    fontSize: 20,
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
                    icon: const Icon(Icons.bookmarks_outlined,
                        color: KpbColors.brandNavy),
                    onPressed: () => Get.toNamed<void>(AppRoutes.saved),
                  ),
                  IconButton(
                    tooltip: 'a11y_refresh'.tr,
                    icon: const Icon(Icons.refresh_rounded,
                        color: KpbColors.textMuted),
                    onPressed: _load,
                  ),
                ],
              ),

              // ── Sub-header + filters ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'scholarships_sorted_hint'.tr,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: KpbColors.textMuted,
                            height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'live_scholarships_filter_all'.tr,
                              active: _fundingFilter == 'all',
                              onTap: () => _applyFilter('all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'live_scholarships_filter_fully_funded'.tr,
                              active: _fundingFilter == 'fully_funded',
                              onTap: () => _applyFilter('fully_funded'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'live_scholarships_filter_partially_funded'
                                  .tr,
                              active: _fundingFilter == 'partially_funded',
                              onTap: () => _applyFilter('partially_funded'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _GuidePromoCard(
                    onTap: () =>
                        Get.to(() => const ScholarshipGuideInfoScreen()),
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────────────
              if (_loading)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      _buildShimmerCard,
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
                if (_scholarshipsController.profileFiltersRelaxed)
                  const SliverToBoxAdapter(child: _UnfilteredNotice()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      'live_scholarships_result_count'
                          .trParams({'count': '${_items.length}'}),
                      style: const TextStyle(
                          fontSize: 11, color: KpbColors.textFaint),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final s = _items[index];
                        return StaggeredSlide(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LiveScholarshipCard(
                              scholarship: s,
                              onTap: () => _openDetail(context, s),
                            ),
                          ),
                        );
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
                if (_scholarshipsController.loadingMore)
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

  void _applyFilter(String value) {
    _scholarshipsController.changeFundingFilter(value);
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
    final fundingFilterActive = controller.fundingFilter != 'all';
    final profileFilterActive =
        controller.hasProfileFilters && !controller.profileFiltersRelaxed;
    final anyFilterActive = fundingFilterActive || profileFilterActive;

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

  static Widget _buildShimmerCard(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ShimmerCard(delay: index * 70),
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
// List row (handoff "Scholarships")
// ─────────────────────────────────────────────────────────────────────────────
class _LiveScholarshipCard extends StatelessWidget {
  const _LiveScholarshipCard({
    required this.scholarship,
    required this.onTap,
  });

  final LiveScholarshipModel scholarship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final deadline = _deadlineBadge(s);
    final (fundBg, fundFg, fundLabel) = _fundingChip(s);
    final cycle = _cyclePill(s);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(_flag(s.countryName), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: KpbColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (deadline != null)
                          _pill(deadline.text, deadline.bg, deadline.fg)
                        else
                          _pill(
                            s.deadlineLabel.isEmpty
                                ? 'live_scholarships_no_deadline'.tr
                                : s.deadlineLabel,
                            KpbColors.surfaceMuted,
                            KpbColors.textMuted,
                          ),
                        if (deadline?.soon ?? false)
                          _pill('live_scholarships_deadline_soon'.tr,
                              KpbColors.gold, Colors.white),
                        _pill(fundLabel, fundBg, fundFg),
                        if (cycle != null) _pill(cycle.$1, cycle.$2, cycle.$3),
                      ],
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

Widget _pill(String text, Color bg, Color fg, {bool big = false}) {
  return Container(
    padding:
        EdgeInsets.symmetric(horizontal: big ? 10 : 8, vertical: big ? 3 : 2),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Text(
      text,
      style: TextStyle(
        fontSize: big ? 10.5 : 9.5,
        fontWeight: FontWeight.w800,
        color: fg,
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? KpbColors.actionPrimary : KpbColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: active ? KpbColors.actionPrimary : KpbColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            // textSecondary (7,58:1) : textMuted frôle le seuil AA à 12,5 px.
            color: active ? Colors.white : KpbColors.textSecondary,
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
            const Icon(Icons.info_outline_rounded,
                size: 16, color: KpbColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'live_scholarships_unfiltered_notice'.tr,
                style: const TextStyle(
                  fontSize: 11.5,
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
        border:
            Border.all(color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
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
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'scholarship_guide_short_title'.tr,
                      style: const TextStyle(
                        fontSize: 13,
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
                        fontSize: 10.5,
                        height: 1.4,
                        color: KpbColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onTap,
                child: Text('scholarship_guide_learn_more'.tr),
              ),
            ],
          ),
          // Secondary, labelled shortcut for students already sold on the
          // guide — "En savoir plus" above still opens the editorial screen
          // (owner video review, 08/2026: the card led nowhere actionable).
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
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton card shown while scholarships are loading
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({this.delay = 0});
  final int delay;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final block =
            Color.lerp(KpbColors.canvas, KpbColors.border, _anim.value)!;
        return Container(
          height: 92,
          decoration: BoxDecoration(
            color: KpbColors.surface,
            border: Border.all(color: KpbColors.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: block,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: block,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 140,
                      decoration: BoxDecoration(
                        color: block,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 90,
                      decoration: BoxDecoration(
                        color: block,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: block, shape: BoxShape.circle),
              ),
            ],
          ),
        );
      },
    );
  }
}
