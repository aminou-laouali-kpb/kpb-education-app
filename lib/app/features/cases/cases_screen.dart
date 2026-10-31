import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/shell_chrome.dart';
import '../../core/ui/skeleton.dart';
import 'case_composer_sheet.dart';
import 'case_detail_screen.dart';
import 'case_timeline_definition.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

const _flagMap = <String, String>{
  'japon': '🇯🇵',
  'japan': '🇯🇵',
  'france': '🇫🇷',
  'allemagne': '🇩🇪',
  'germany': '🇩🇪',
  'états-unis': '🇺🇸',
  'etats-unis': '🇺🇸',
  'united states': '🇺🇸',
  'usa': '🇺🇸',
  'canada': '🇨🇦',
  'royaume-uni': '🇬🇧',
  'united kingdom': '🇬🇧',
  'australie': '🇦🇺',
  'australia': '🇦🇺',
  'chine': '🇨🇳',
  'china': '🇨🇳',
  'corée du sud': '🇰🇷',
  'south korea': '🇰🇷',
  'turquie': '🇹🇷',
  'turkey': '🇹🇷',
  'italie': '🇮🇹',
  'italy': '🇮🇹',
  'espagne': '🇪🇸',
  'spain': '🇪🇸',
  'maroc': '🇲🇦',
  'morocco': '🇲🇦',
  'tunisie': '🇹🇳',
  'tunisia': '🇹🇳',
  'suisse': '🇨🇭',
  'switzerland': '🇨🇭',
  'belgique': '🇧🇪',
  'belgium': '🇧🇪',
  'sénégal': '🇸🇳',
  'senegal': '🇸🇳',
};

String? _dossierFlag(String text) {
  final lower = text.toLowerCase();
  for (final entry in _flagMap.entries) {
    // Mot ENTIER : par sous-chaîne, « Lausanne » ou « Busan » contenaient
    // « usa » (🇺🇸) et « machine » contenait « chine » (🇨🇳).
    final pattern = RegExp(
      '(^|[^\\p{L}])${RegExp.escape(entry.key)}(\$|[^\\p{L}])',
      unicode: true,
    );
    if (pattern.hasMatch(lower)) return entry.value;
  }
  return null;
}

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  CaseType? _selectedType;

  void _openComposer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CaseComposerSheet(
        caseType: CaseType.consultation,
        title: 'new_case'.tr,
        contextLabel: 'KPB Education',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        // Guest mode: dossiers require a signed-in profile. Show an explicit
        // sign-in prompt rather than a blank-empty-state that the user can't
        // act on (Submit would silently fail).
        if (controller.isGuestMode || controller.profile == null) {
          return const _GuestCasesPrompt();
        }

        if (controller.isSyncing && controller.cases.isEmpty) {
          // SafeArea: this tab has no AppBar, so nothing else absorbs the
          // status-bar / Dynamic Island inset (see the header below).
          return const SafeArea(bottom: false, child: CasesScreenSkeleton());
        }

        if (controller.syncError != null && controller.cases.isEmpty) {
          return KpbErrorState(onRetry: controller.pullToRefresh);
        }

        final items = controller.casesByType(_selectedType);
        // Les puces ne servent qu'avec au moins deux types de dossiers ; avec
        // un seul, elles ne filtrent rien (audit build 57, T4-18).
        final showFilters =
            controller.cases.map((item) => item.type).toSet().length >= 2;

        final Widget body = KpbRefresh(
          onRefresh: controller.pullToRefresh,
          child: CustomScrollView(
            slivers: [
              // ── Header ───────────────────────────────────────────────
              // Left inset of 56: the shell paints its floating hamburger in
              // the top-left corner of every tab (48px + 4px margin), so the
              // title has to start to the right of it — same trick as the Home
              // app bar (`titleSpacing: 60`). The vertical inset for the
              // notch / Dynamic Island comes from the SafeArea below.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 14, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'nav_cases'.tr,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: KpbColors.brandNavy,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              // Le total des dossiers, pas celui du filtre :
                              // « 0 dossier » à côté d'un dossier existant
                              // laissait croire qu'il avait disparu.
                              'cases_count'.trParams(
                                  {'count': '${controller.cases.length}'}),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: KpbColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: KpbColors.actionPrimary,
                          foregroundColor: Colors.white,
                          // Override the app theme's
                          // `minimumSize: Size.fromHeight(52)` (infinite min
                          // width): inside this Row the button gets unbounded
                          // max width, and an infinite minWidth would force
                          // w=Infinity and blank the whole tab (layout error).
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('new_case'.tr),
                        onPressed: () => _openComposer(context),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filtres ───────────────────────────────────────────────
              if (showFilters)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _FilterChip(
                          label: 'cases_filter_all'.tr,
                          selected: _selectedType == null,
                          onTap: () => setState(() => _selectedType = null),
                        ),
                        const SizedBox(width: 8),
                        ...CaseType.values.map((type) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: _typeLabel(type),
                              selected: _selectedType == type,
                              onTap: () => setState(() => _selectedType = type),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              if (showFilters)
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── Liste ─────────────────────────────────────────────────
              if (items.isEmpty && controller.cases.isNotEmpty)
                // Un filtre sans résultat n'est pas un compte neuf : pas de
                // « Crée ton premier dossier ».
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: KpbEmptyState(
                    key: const ValueKey<String>('cases-filter-empty'),
                    icon: Icons.filter_alt_off_outlined,
                    title: 'cases_filter_empty_title'.tr,
                    subtitle: 'cases_filter_empty_body'.tr,
                    action: OutlinedButton(
                      onPressed: () => setState(() => _selectedType = null),
                      child: Text('cases_filter_show_all'.tr),
                    ),
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: KpbEmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'no_cases'.tr,
                    subtitle: 'case_empty_hint'.tr,
                    action: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: KpbColors.actionPrimary),
                      onPressed: () => _openComposer(context),
                      child: Text('create_case'.tr),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _CaseCard(
                        item: items[index],
                        controller: controller,
                      );
                    },
                  ),
                ),

              // Keep the last card clear of the floating nav bar AND of the
              // "KPB Intelligence" pill (the old hardcoded 100 only cleared
              // the nav bar, so the pill sat on top of the last card).
              const SliverToBoxAdapter(child: KpbShellBottomSpacer()),
            ],
          ),
        );

        // Guard against being laid out with unbounded width (e.g. while
        // offstage beneath the Overlay theater during boot), which makes the
        // header Row's button measurement assert. Capping maxWidth is a no-op
        // during normal onstage layout since the parent is already narrower.
        final mqWidth = MediaQuery.maybeOf(context)?.size.width ?? 0;
        final safeWidth = (mqWidth.isFinite && mqWidth > 0) ? mqWidth : 400.0;
        return ColoredBox(
          color: KpbColors.canvas,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: safeWidth),
            // This tab has no AppBar/SliverAppBar to absorb the status-bar
            // inset, and the shell keeps the top padding for its tabs
            // (MediaQuery.removePadding only kicks in under a banner). Without
            // this SafeArea the header + filters were drawn *under* the notch /
            // Dynamic Island (reported on TestFlight). `bottom: false` keeps
            // the list full-bleed: the trailing KpbShellBottomSpacer already
            // reserves the floating chrome's band.
            child: SafeArea(
              bottom: false,
              child: body,
            ),
          ),
        );
      },
    );
  }

  String _typeLabel(CaseType type) {
    switch (type) {
      case CaseType.consultation:
        return 'case_type_filter_consultation'.tr;
      case CaseType.applicationSupport:
        return 'case_type_filter_application'.tr;
      case CaseType.scholarshipSupport:
        return 'case_type_scholarship'.tr;
      case CaseType.housingSupport:
        return 'case_type_housing'.tr;
      case CaseType.mentorship:
        return 'case_type_filter_mentorship'.tr;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Case card
// ─────────────────────────────────────────────────────────────────────────────
class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item, required this.controller});
  final StudentCase item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pill = _statusPill(item.status);
    final date =
        DateFormat('dd MMM yyyy', controller.localeCode).format(item.updatedAt);
    final unread = controller.unreadMessagesForCase(item.id);
    final progress = caseTimelineProgress(item.status);
    final pct = (progress * 100).round();
    final title = controller.resolve(item.title);
    final flag =
        _dossierFlag('$title ${controller.resolve(item.contextLabel)}');
    final action = _contextualAction(item.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.to(() => CaseDetailScreen(caseId: item.id)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KpbColors.border),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Leading(flag: flag, type: item.type, color: pill.fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: KpbColors.brandNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.resolve(item.nextStepTitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: KpbColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusPill(label: pill.label, bg: pill.bg, fg: pill.fg),
                      if (unread > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KpbColors.error,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            unread == 1
                                ? 'cases_new_message_badge'.tr
                                : 'cases_new_messages_badge'
                                    .trParams({'count': '$unread'}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Progress (real, status-driven) ──
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: KpbColors.surfaceMuted,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            KpbColors.actionPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Meta row ──
              Row(
                children: [
                  const Icon(Icons.tag_rounded,
                      size: 13, color: KpbColors.textFaint),
                  const SizedBox(width: 3),
                  Text(
                    item.referenceCode,
                    style: const TextStyle(
                        fontSize: 11, color: KpbColors.textFaint),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: KpbColors.textFaint),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'updated_on'.trParams({'date': date}),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: KpbColors.textFaint),
                    ),
                  ),
                  if (item.messages.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 13, color: KpbColors.textFaint),
                    const SizedBox(width: 4),
                    Text(
                      '${item.messages.length}',
                      style: const TextStyle(
                          fontSize: 11, color: KpbColors.textFaint),
                    ),
                  ],
                ],
              ),

              // ── Contextual action button (status-driven) ──
              if (action != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: pill.fg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () =>
                        Get.to(() => CaseDetailScreen(caseId: item.id)),
                    child: Text(action),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _contextualAction(CaseStatus status) {
    switch (status) {
      case CaseStatus.documentsNeeded:
        return 'cases_action_send_documents'.tr;
      case CaseStatus.awaitingPayment:
        return 'cases_action_chat_advisor'.tr;
      case CaseStatus.awaitingStudent:
        return 'cases_action_reply_advisor'.tr;
      case CaseStatus.scheduled:
        return 'cases_action_view_appointment'.tr;
      default:
        return null;
    }
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.flag, required this.type, required this.color});
  final String? flag;
  final CaseType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: flag != null
            ? KpbColors.surfaceMuted
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: flag != null
          ? Text(flag!, style: const TextStyle(fontSize: 22))
          : Icon(_typeIcon(type), color: color, size: 22),
    );
  }

  IconData _typeIcon(CaseType type) {
    switch (type) {
      case CaseType.consultation:
        return Icons.support_agent_rounded;
      case CaseType.applicationSupport:
        return Icons.folder_copy_rounded;
      case CaseType.scholarshipSupport:
        return Icons.workspace_premium_rounded;
      case CaseType.housingSupport:
        return Icons.home_rounded;
      case CaseType.mentorship:
        return Icons.psychology_rounded;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

({String label, Color bg, Color fg}) _statusPill(CaseStatus status) {
  switch (status) {
    case CaseStatus.submitted:
      return (
        label: 'case_status_short_submitted'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.underReview:
      return (
        label: 'case_timeline_status_under_review'.tr,
        bg: KpbColors.warningLight,
        fg: KpbColors.warning
      );
    case CaseStatus.documentsNeeded:
      return (
        label: 'case_section_documents'.tr,
        bg: KpbColors.warningLight,
        fg: KpbColors.warning
      );
    case CaseStatus.counselorAssigned:
      return (
        label: 'case_status_short_counselor'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.awaitingStudent:
      return (
        label: 'case_status_short_action_required'.tr,
        bg: KpbColors.errorLight,
        fg: KpbColors.error
      );
    case CaseStatus.scheduled:
      return (
        label: 'case_status_short_scheduled'.tr,
        bg: KpbColors.successLight,
        fg: KpbColors.success
      );
    case CaseStatus.inProgress:
      return (
        label: 'case_timeline_status_in_progress'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.applicationSubmitted:
      return (
        label: 'case_status_short_application_submitted'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.waitingDecision:
      return (
        label: 'case_stepper_decision_title'.tr,
        bg: KpbColors.warningLight,
        fg: KpbColors.warning
      );
    case CaseStatus.awaitingPayment:
      return (
        label: 'case_status_short_payment'.tr,
        bg: KpbColors.errorLight,
        fg: KpbColors.error
      );
    case CaseStatus.completed:
      return (
        label: 'case_status_short_completed'.tr,
        bg: KpbColors.successLight,
        fg: KpbColors.success
      );
    case CaseStatus.rejected:
      return (
        label: 'case_status_short_rejected'.tr,
        bg: KpbColors.errorLight,
        fg: KpbColors.error
      );
    case CaseStatus.cancelled:
      return (
        label: 'case_status_short_cancelled'.tr,
        bg: KpbColors.surfaceMuted,
        fg: KpbColors.textMuted
      );
    case CaseStatus.draft:
      return (
        label: 'case_status_short_draft'.tr,
        bg: KpbColors.surfaceMuted,
        fg: KpbColors.textMuted
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? KpbColors.actionPrimary : KpbColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? KpbColors.actionPrimary : KpbColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            // textSecondary (7,58:1) : textMuted frôle le seuil AA à 12 px.
            color: selected ? Colors.white : KpbColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest prompt — dossiers require a signed-in profile.
// ─────────────────────────────────────────────────────────────────────────────
class _GuestCasesPrompt extends StatelessWidget {
  const _GuestCasesPrompt();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KpbColors.canvas,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: KpbColors.canvas,
            surfaceTintColor: KpbColors.canvas,
            elevation: 0,
            // Clear the shell's floating hamburger (top-left overlay); the
            // SliverAppBar already absorbs the status-bar inset itself.
            titleSpacing: 60,
            title: Text(
              'nav_cases'.tr,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: KpbColors.brandNavy,
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: KpbColors.actionPrimarySoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.folder_open_rounded,
                        size: 38, color: KpbColors.actionPrimary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'guest_cases_title'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: KpbColors.brandNavy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'guest_cases_body'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: KpbColors.textMuted,
                        height: 1.45,
                        fontSize: 13.5),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: KpbColors.actionPrimary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text('guest_case_gate_cta'.tr),
                    onPressed: () {
                      // Clear guest state so the boot router lands on the auth
                      // welcome screen (otherwise it loops straight back to the
                      // shell) and the conversion is tracked.
                      Get.find<AppController>()
                          .leaveGuestForSignup(source: 'cases_gate');
                      Get.offAll(() => const AppBootScreen());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
