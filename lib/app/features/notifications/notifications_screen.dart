import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/notification_opt_out.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/notification_router.dart';
import '../assist_bridge/assist_bridge_sheet.dart';
import '../../core/services/push_permission.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/community_store.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/services/scholarship_match_store.dart';
import '../../core/ui/components/kpb_async_view.dart';
import '../../core/ui/components/kpb_refresh.dart';
import '../../core/ui/components/kpb_toast.dart';
import '../../core/ui/skeleton.dart';
import '../scholarship_match/scholarship_match_actions.dart';
import '../scholarships/widgets/follow_push_primer.dart';
import '../cases/case_detail_screen.dart';
import '../cases/case_timeline_definition.dart';
import '../cases/post_decision_screen.dart';
import '../../core/ui/app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notifications center (App-engagement handoff · net-new).
//
// Combines the durable per-user scholarship feed with notifications derived
// from real dossier state. No placeholder rows are fabricated:
//
//   • Scholarship-opening rows are stored server-side, deep-link to the real
//     Bourses surface, and have durable read state.
//   • Dossier rows are DERIVED live from the real [StudentCase] list:
//       – a case in a student-action status (documentsNeeded / awaitingStudent /
//         awaitingPayment, via the shared `isCaseStudentActionStatus`) →
//         "Action needed", opening the real CaseDetailScreen;
//       – a `rejected` case → "Decision received", opening the real
//         PostDecisionScreen (plan B).
//     The design's scholarship / community / streak rows are DROPPED — those
//     features are MVP-locked / unbacked, so inventing entries would lie.
//   • Relative time is the real `case.updatedAt`; the list is sorted newest
//     first.
//   • The empty state is honest ("you're all caught up"), not a fake list.
//   • "Mark all read" is a session-local dismiss of the exact items currently
//     shown (keyed by case id + kind + updatedAt) — no persistence is faked. If
//     a case sees genuinely new activity (its updatedAt changes) it reappears.
//   • Preferences: the push row reflects the REAL permission state
//     (`PushPermission`) — "Activer" when never asked, "Notifications
//     coupées" + a link to the app settings when refused — plus one switch per
//     persisted opt-out family.
//   • Chantier G: one icon and one call to action per `kind`, rows grouped
//     « Aujourd'hui / Cette semaine / Plus tôt », pull-to-refresh, and the
//     server's unread count feeds the Home bell.
// ─────────────────────────────────────────────────────────────────────────────

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

/// The two real kinds of derived notification.
enum _NotifKind { actionNeeded, decisionReceived }

/// One live-derived notification. NOT stored — recomputed from a real
/// [StudentCase] every build, and always tied to a real destination screen.
class _DerivedNotification {
  const _DerivedNotification({
    required this.caseId,
    required this.kind,
    required this.updatedAt,
  });

  final String caseId;
  final _NotifKind kind;
  final DateTime updatedAt;

  /// Stable signature for the session-local "mark all read" dismiss. Includes
  /// [updatedAt] so genuinely new activity on the same case reappears.
  String get signature =>
      '$caseId|${kind.name}|${updatedAt.millisecondsSinceEpoch}';
}

class _StoredNotification {
  const _StoredNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.route,
    required this.scholarshipId,
    required this.variant,
    required this.createdAt,
    required this.read,
    this.data = const <String, dynamic>{},
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String route;
  final String? scholarshipId;

  /// `data.variant` d'une annonce (`alert`, `favorite`, `dates_confirmed`).
  final String? variant;
  final DateTime createdAt;
  final bool read;

  /// La charge brute (`data`) : la feuille du bot « Passerelle » y lit le
  /// besoin, la fonction et l'événement.
  final Map<String, dynamic> data;

  factory _StoredNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map : const {};
    final rawScholarshipId = json['scholarshipId'] ?? data['scholarshipId'];
    final rawVariant = data['variant'];
    return _StoredNotification(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      route: json['route'] as String? ?? '',
      scholarshipId: rawScholarshipId is String ? rawScholarshipId : null,
      variant: rawVariant is String ? rawVariant : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      read: json['readAt'] != null,
      data: Map<String, dynamic>.from(data),
    );
  }

  /// Où mène un tap : la fiche de la bourse, « Mes suivis » pour un groupé…
  String? get destination => resolveNotificationRoute(<String, dynamic>{
        'route': route,
        'kind': kind,
        if (scholarshipId != null) 'scholarshipId': scholarshipId,
      });

  _StoredNotification markRead() => _StoredNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        route: route,
        scholarshipId: scholarshipId,
        variant: variant,
        createdAt: createdAt,
        read: true,
        data: data,
      );
}

/// Icône, couleurs et appel à l'action d'une notification, selon son `kind`.
/// Un `kind` inconnu (famille ajoutée côté serveur après cette build) garde un
/// rendu neutre plutôt que d'emprunter celui d'une autre famille.
@visibleForTesting
({IconData icon, Color color, Color background, String ctaKey})
    notificationKindStyle(String kind, {String? variant}) {
  final k = kind.toLowerCase();
  if (k == scholarshipOpenedBundleKind) {
    return (
      icon: Icons.bookmarks_rounded,
      color: KpbColors.success,
      background: KpbColors.successLight,
      ctaKey: 'notif_cta_open_followed',
    );
  }
  if (k == 'scholarship_opened') {
    final datesOnly = variant == 'dates_confirmed';
    return (
      icon: datesOnly ? Icons.event_available_rounded : Icons.lock_open_rounded,
      color: datesOnly ? KpbColors.actionPrimary : KpbColors.success,
      background:
          datesOnly ? KpbColors.actionPrimarySoft : KpbColors.successLight,
      ctaKey: 'notif_cta_open_scholarship',
    );
  }
  // Bot « Passerelle » (contrat §15) : une suggestion de l'équipe KPB.
  if (k == assistBridgeKind) {
    return (
      icon: Icons.support_agent_rounded,
      color: KpbColors.actionPrimary,
      background: KpbColors.actionPrimarySoft,
      ctaKey: 'notif_cta_assist_bridge',
    );
  }
  // Communauté (contrat §11) : avant les règles par sous-chaîne, pour qu'un
  // `community_*` n'emprunte jamais le rendu d'une autre famille.
  if (k == 'community_verified_answer') {
    return (
      icon: Icons.verified_rounded,
      color: KpbColors.success,
      background: KpbColors.successLight,
      ctaKey: 'notif_cta_open_discussion',
    );
  }
  if (k == 'community_moderation') {
    return (
      icon: Icons.shield_outlined,
      color: KpbColors.brandNavy,
      background: KpbColors.surfaceMuted,
      ctaKey: 'notif_cta_open',
    );
  }
  if (k.startsWith('community')) {
    return (
      icon: Icons.forum_outlined,
      color: KpbColors.actionPrimary,
      background: KpbColors.actionPrimarySoft,
      ctaKey: 'notif_cta_open_discussion',
    );
  }
  if (k.contains('deadline') || k.contains('reminder')) {
    return (
      icon: Icons.alarm_rounded,
      color: KpbColors.warning,
      background: KpbColors.warningLight,
      ctaKey: 'notif_cta_deadline',
    );
  }
  if (k.contains('message') || k.contains('counsel')) {
    return (
      icon: Icons.chat_bubble_outline_rounded,
      color: KpbColors.actionPrimary,
      background: KpbColors.actionPrimarySoft,
      ctaKey: 'notif_cta_message',
    );
  }
  if (k.startsWith('case') || k.contains('milestone')) {
    return (
      icon: Icons.folder_open_rounded,
      color: KpbColors.brandNavy,
      background: KpbColors.surfaceMuted,
      ctaKey: 'notif_cta_case',
    );
  }
  if (k == NotificationOptOutType.dailyScholarship) {
    return (
      icon: Icons.school_rounded,
      color: KpbColors.actionPrimary,
      background: KpbColors.actionPrimarySoft,
      ctaKey: 'notif_cta_open_scholarship',
    );
  }
  if (k == NotificationOptOutType.weeklyDigest) {
    return (
      icon: Icons.calendar_month_rounded,
      color: KpbColors.actionPrimary,
      background: KpbColors.actionPrimarySoft,
      ctaKey: 'notif_cta_open',
    );
  }
  if (k == NotificationOptOutType.parcoursWeekly) {
    return (
      icon: Icons.auto_awesome_rounded,
      color: KpbColors.lawPurple,
      background: KpbColors.surfaceMuted,
      ctaKey: 'notif_cta_open',
    );
  }
  return (
    icon: Icons.notifications_none_rounded,
    color: KpbColors.actionPrimary,
    background: KpbColors.actionPrimarySoft,
    ctaKey: 'notif_cta_open',
  );
}

/// Les trois groupes du fil.
enum NotificationAgeGroup { today, thisWeek, earlier }

/// « Aujourd'hui » = même jour local ; « Cette semaine » = les 6 jours d'avant ;
/// « Plus tôt » sinon. Une date dans le futur (horloge décalée) compte pour
/// aujourd'hui.
@visibleForTesting
NotificationAgeGroup notificationAgeGroup(DateTime at, {DateTime? now}) {
  final ref = (now ?? DateTime.now()).toLocal();
  final local = at.toLocal();
  final today = DateTime(ref.year, ref.month, ref.day);
  final day = DateTime(local.year, local.month, local.day);
  if (!day.isBefore(today)) return NotificationAgeGroup.today;
  if (today.difference(day).inDays < 7) return NotificationAgeGroup.thisWeek;
  return NotificationAgeGroup.earlier;
}

/// Whether the current case list yields at least one derived notification.
/// Drives the home bell's unread dot HONESTLY — there is no stored feed, so the
/// dot only shows when real case activity would produce a row here.
bool hasDerivedNotifications(AppController controller, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(_rejectedDotWindow);
  for (final c in controller.cases) {
    if (isCaseStudentActionStatus(c.status)) return true;
    // `rejected` est définitif : compté sans limite, il allumait le point
    // rouge pour toujours. Il ne compte que tant que la décision est récente.
    if (c.status == CaseStatus.rejected && c.updatedAt.isAfter(cutoff)) {
      return true;
    }
  }
  return false;
}

const Duration _rejectedDotWindow =
    Duration(days: 7); // kpb-allow-duration: fenêtre métier, pas un mouvement

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Signatures dismissed via "mark all read" for THIS session only. No
  /// persistence — items are live-derived, so we never fake a stored read flag.
  final Set<String> _dismissed = <String>{};
  late final AppApiClient _apiClient;
  List<_StoredNotification> _stored = <_StoredNotification>[];

  /// Premier chargement du fil serveur en cours : un squelette plutôt qu'un
  /// « Aucune notification » qui serait démenti une seconde plus tard.
  bool _storedLoading = true;

  /// L'autorisation réelle des notifications sur ce téléphone.
  PushPermissionStatus _pushStatus = PushPermissionStatus.unavailable;

  /// « Nouvelles bourses compatibles » : le choix posé ici, en attendant que
  /// `PUT /scholarships/match/alerts` le confirme.
  bool? _matchAlertsOverride;
  bool _matchAlertsSaving = false;

  @override
  void initState() {
    super.initState();
    _apiClient = Get.find<AppController>().apiClient;
    unawaited(_loadStored());
    unawaited(_refreshPushStatus());
    unawaited(_loadMatchState());
    // Le badge serveur prouve aussi que le backend sert les routes du suivi :
    // c'est ce qui allume la ligne « Bourses que je suis : ouverture ».
    unawaited(
      Get.find<AppController>().refreshServerUnreadCount(force: true),
    );
  }

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      _loadStored(),
      _refreshPushStatus(),
      Get.find<AppController>().refreshServerUnreadCount(force: true),
    ]);
  }

  /// L'état du test « Mes 10 bourses » porte l'opt-in hebdomadaire. Rien
  /// n'est demandé quand le test est fermé (drapeau, parent, invité).
  Future<void> _loadMatchState() async {
    final app = Get.find<AppController>();
    final variant = scholarshipMatchEntryVariant(app);
    if (variant == ScholarshipMatchEntryVariant.hidden ||
        variant == ScholarshipMatchEntryVariant.guest) {
      return;
    }
    await ScholarshipMatchStore.instance.loadState(
      client: app.apiClient,
      userId: scholarshipMatchUserId(app),
      lang: scholarshipMatchLang(app),
    );
  }

  Future<void> _setMatchAlerts(bool enabled) async {
    if (_matchAlertsSaving) return;
    final store = ScholarshipMatchStore.instance;
    final previous = store.alertsOptIn;
    setState(() {
      _matchAlertsOverride = enabled;
      _matchAlertsSaving = true;
    });
    final confirmed = await store.setAlerts(
      client: _apiClient,
      enabled: enabled,
    );
    if (!mounted) return;
    setState(() {
      _matchAlertsSaving = false;
      _matchAlertsOverride = confirmed ?? previous;
    });
    if (confirmed == null) {
      KpbToast.error('scholarship_match_alerts_error'.tr, context: context);
    } else {
      unawaited(AnalyticsService.instance
          .logScholarshipMatchAlertsToggled(enabled: confirmed));
    }
  }

  /// Opt-in EXPLICITE (éteint tant que l'élève ne l'allume pas), porté par le
  /// serveur du test — pas un `NotificationOptOutType`. Visible seulement
  /// quand le test est ouvert pour cet élève et que son état est connu.
  Widget _matchAlertsRow() {
    return ScholarshipMatchListener(
      builder: (context, variant) {
        final store = ScholarshipMatchStore.instance;
        if (variant == ScholarshipMatchEntryVariant.hidden ||
            variant == ScholarshipMatchEntryVariant.guest ||
            store.state == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          key: const ValueKey<String>('notif-pref-scholarship-match'),
          padding: const EdgeInsets.only(top: 12),
          child: _prefToggleRow(
            icon: Icons.emoji_events_rounded,
            titleKey: 'scholarship_match_alerts_pref_title',
            subtitleKey: 'scholarship_match_alerts_pref_subtitle',
            receive: _matchAlertsOverride ?? store.alertsOptIn,
            onReceiveChanged: (value) => unawaited(_setMatchAlerts(value)),
          ),
        );
      },
    );
  }

  Future<void> _refreshPushStatus() async {
    final status = await PushPermission.instance.status();
    if (mounted && status != _pushStatus) {
      setState(() => _pushStatus = status);
    }
  }

  Future<void> _loadStored() async {
    try {
      final controller = Get.find<AppController>();
      final profile = controller.profile;
      final response = await _apiClient.fetchUserNotifications(
        profile?.preferredLanguage == 'en' ? 'en' : 'fr',
      );
      final items = (response['items'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_StoredNotification.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();
      final unread = response['unreadCount'];
      if (unread is num) {
        controller.setServerUnreadNotifications(unread.toInt());
      }
      if (mounted) setState(() => _stored = items);
    } catch (_) {
      // Dossier-derived rows stay available offline.
    } finally {
      if (mounted && _storedLoading) setState(() => _storedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        bottom: false,
        child: GetBuilder<AppController>(
          builder: (_) {
            final items = _derive(ctrl);
            final hasItems = items.isNotEmpty || _stored.isNotEmpty;
            return KpbRefresh(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _header(items),
                  const SizedBox(height: 13),
                  // Hors ligne, l'échec du fil serveur n'est pas une erreur :
                  // les lignes tirées des dossiers restent, sinon l'état vide.
                  KpbAsyncView(
                    phase: KpbAsyncView.phaseOf(
                      loading: _storedLoading,
                      hasData: hasItems,
                      isEmpty: !hasItems,
                    ),
                    skeleton: const KpbSkeletonList(
                      itemCount: 3,
                      itemHeight: 76,
                      padding: EdgeInsets.zero,
                    ),
                    empty: _emptyState(),
                    builder: (_) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _groupedFeed(ctrl, items),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _prefsSection(ctrl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Le fil, du plus récent au plus ancien, sous « Aujourd'hui », « Cette
  /// semaine » et « Plus tôt » (un groupe vide n'a pas d'en-tête).
  List<Widget> _groupedFeed(
    AppController ctrl,
    List<_DerivedNotification> derived,
  ) {
    final entries = <({DateTime at, Widget card})>[
      for (final item in _stored)
        (at: item.createdAt, card: _storedNotifCard(item)),
      for (final item in derived)
        (at: item.updatedAt, card: _notifCard(ctrl, item)),
    ]..sort((a, b) => b.at.compareTo(a.at));
    final now = DateTime.now();
    final widgets = <Widget>[];
    NotificationAgeGroup? current;
    for (final entry in entries) {
      final group = notificationAgeGroup(entry.at, now: now);
      if (group != current) {
        current = group;
        widgets.add(_groupHeader(group));
      } else {
        widgets.add(const SizedBox(height: 8));
      }
      widgets.add(entry.card);
    }
    return widgets;
  }

  Widget _groupHeader(NotificationAgeGroup group) {
    final key = switch (group) {
      NotificationAgeGroup.today => 'notifications_group_today',
      NotificationAgeGroup.thisWeek => 'notifications_group_week',
      NotificationAgeGroup.earlier => 'notifications_group_earlier',
    };
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 10, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          key.tr,
          style: const TextStyle(
            fontSize: KpbFontSize.xs,
            fontWeight: FontWeight.w800,
            color: KpbColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Derivation ─────────────────────────────────────────────────────────────

  List<_DerivedNotification> _derive(AppController ctrl) {
    final items = <_DerivedNotification>[];
    for (final c in ctrl.cases) {
      final _NotifKind? kind;
      if (c.status == CaseStatus.rejected) {
        kind = _NotifKind.decisionReceived;
      } else if (isCaseStudentActionStatus(c.status)) {
        kind = _NotifKind.actionNeeded;
      } else {
        kind = null;
      }
      if (kind == null) continue;
      final item = _DerivedNotification(
        caseId: c.id,
        kind: kind,
        updatedAt: c.updatedAt,
      );
      if (_dismissed.contains(item.signature)) continue;
      items.add(item);
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> _markAllRead(List<_DerivedNotification> items) async {
    setState(() {
      for (final item in items) {
        _dismissed.add(item.signature);
      }
      _stored = _stored.map((item) => item.markRead()).toList();
    });
    Get.find<AppController>().setServerUnreadNotifications(0);
    try {
      await _apiClient.markAllUserNotificationsRead();
    } catch (_) {
      // Optimistic read state keeps the interaction responsive; the server
      // state will be reconciled on the next successful load.
    }
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header(List<_DerivedNotification> items) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: KpbColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: KpbColors.border),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 19, color: KpbColors.brandNavy),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'notifications_title'.tr,
            style: const TextStyle(
              fontSize: KpbFontSize.xl,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: KpbColors.brandNavy,
            ),
          ),
        ),
        if (items.isNotEmpty || _stored.any((item) => !item.read))
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: () => _markAllRead(items),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'notifications_mark_all_read'.tr,
                  style: const TextStyle(
                    fontSize: KpbFontSize.xs,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.actionPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(
        color: KpbColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.border),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 34),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: KpbColors.actionPrimarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 28, color: KpbColors.actionPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'notifications_empty_title'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: KpbFontSize.md,
              fontWeight: FontWeight.w800,
              color: KpbColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'notifications_empty_body'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: KpbFontSize.sm,
              height: 1.55,
              color: KpbColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Notification card ────────────────────────────────────────────────────

  Widget _notifCard(AppController ctrl, _DerivedNotification item) {
    final c = ctrl.cases.firstWhereOrNull((e) => e.id == item.caseId);
    if (c == null) return const SizedBox.shrink();

    final IconData icon;
    final Color iconColor;
    final Color iconBg;
    final String title;
    final String description;
    final VoidCallback onTap;

    switch (item.kind) {
      case _NotifKind.decisionReceived:
        icon = Icons.mark_email_unread_rounded;
        iconColor = KpbColors.error;
        iconBg = KpbColors.errorLight;
        title = 'notif_decision_received_title'.tr;
        description = 'notif_decision_received_body'
            .trParams({'title': ctrl.resolve(c.title)});
        onTap = () => Get.to(() => PostDecisionScreen(caseId: c.id));
        break;
      case _NotifKind.actionNeeded:
        icon = Icons.pending_actions_rounded;
        iconColor = KpbColors.warning;
        iconBg = KpbColors.warningLight;
        title = 'notif_action_needed_title'
            .trParams({'step': _actionStep(ctrl, c)});
        description = ctrl.resolve(c.nextStepDescription);
        onTap = () => Get.to(() => CaseDetailScreen(caseId: c.id));
        break;
    }

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: KpbFontSize.sm,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          height: 1.5,
                          color: KpbColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _relativeTime(item.updatedAt),
                style: const TextStyle(
                  fontSize: KpbFontSize.xs,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storedNotifCard(_StoredNotification item) {
    final style = notificationKindStyle(item.kind, variant: item.variant);
    final hasDestination = item.destination != null;
    return Semantics(
      button: true,
      label: item.title,
      child: GestureDetector(
        onTap: () => _openStored(item),
        child: Container(
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.read
                  ? KpbColors.border
                  : KpbColors.actionPrimary.withValues(alpha: 0.3),
            ),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(style.icon, size: 18, color: style.color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: KpbFontSize.sm,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          height: 1.5,
                          color: KpbColors.textMuted,
                        ),
                      ),
                    ],
                    if (hasDestination) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            style.ctaKey.tr,
                            style: const TextStyle(
                              fontSize: KpbFontSize.xs,
                              fontWeight: FontWeight.w800,
                              color: KpbColors.actionPrimary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: KpbColors.actionPrimary),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _relativeTime(item.createdAt),
                style: const TextStyle(
                  fontSize: KpbFontSize.xs,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStored(_StoredNotification item) async {
    if (!item.read) {
      setState(() {
        _stored = _stored
            .map((stored) => stored.id == item.id ? stored.markRead() : stored)
            .toList();
      });
      final controller = Get.find<AppController>();
      if (controller.serverUnreadNotifications > 0) {
        controller.setServerUnreadNotifications(
          controller.serverUnreadNotifications - 1,
        );
      }
      try {
        await _apiClient.markUserNotificationRead(item.id);
      } catch (_) {
        // Navigation remains useful even if read-state persistence is offline.
      }
    }
    // Bot « Passerelle » : la feuille « Tu peux le faire dans l'app », comme
    // au tap du push.
    if (item.kind == assistBridgeKind) {
      await showAssistBridgeSheet(<String, dynamic>{
        ...item.data,
        'route': item.route,
      });
      return;
    }
    // Même règle que le tap d'un push : la fiche de la bourse, « Mes suivis »
    // pour un groupé — jamais une liste générique quand l'identifiant est là.
    final route = item.destination;
    if (route != null) await Get.toNamed<void>(route);
  }

  /// The concrete step for an "action needed" row: the case's real
  /// nextStepTitle, falling back to its title, then a generic label — never a
  /// fabricated task.
  String _actionStep(AppController ctrl, StudentCase c) {
    final step = ctrl.resolve(c.nextStepTitle).trim();
    if (step.isNotEmpty) return step;
    final title = ctrl.resolve(c.title).trim();
    if (title.isNotEmpty) return title;
    return 'notif_action_needed_fallback'.tr;
  }

  // ── Preferences (real push capability only) ─────────────────────────────────

  Widget _prefsSection(AppController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'notifications_push_section'.tr,
            style: const TextStyle(
              fontSize: KpbFontSize.xs,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.05 * 12,
              color: KpbColors.textFaint,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: KpbColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KpbColors.border),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _enablePushRow(),
              const SizedBox(height: 12),
              _optOutRow(
                icon: Icons.school_rounded,
                type: NotificationOptOutType.dailyScholarship,
                titleKey: 'daily_scholarship_pref_title',
                subtitleKey: 'daily_scholarship_pref_subtitle',
              ),
              const SizedBox(height: 12),
              _optOutRow(
                icon: Icons.calendar_month_rounded,
                type: NotificationOptOutType.weeklyDigest,
                titleKey: 'weekly_digest_pref_title',
                subtitleKey: 'weekly_digest_pref_subtitle',
              ),
              const SizedBox(height: 12),
              _optOutRow(
                icon: Icons.auto_awesome_rounded,
                type: NotificationOptOutType.parcoursWeekly,
                titleKey: 'parcours_weekly_pref_title',
                subtitleKey: 'parcours_weekly_pref_subtitle',
              ),
              // Un backend antérieur au chantier C retire cette clé à
              // l'écriture : l'interrupteur reviendrait tout seul. Il ne
              // s'affiche donc que si le serveur a prouvé qu'il la connaît.
              if (RemoteFeatureFlags.instance.followedOptOutEnabled &&
                  ctrl.serverSupportsFollow) ...[
                const SizedBox(height: 12),
                _optOutRow(
                  icon: Icons.bookmarks_rounded,
                  type: NotificationOptOutType.followedScholarshipUpdates,
                  titleKey: 'followed_scholarship_pref_title',
                  subtitleKey: 'followed_scholarship_pref_subtitle',
                ),
              ],
              // Communauté : visible seulement drapeau `community` ouvert.
              if (CommunityStore.instance.enabled) ...[
                const SizedBox(height: 12),
                _optOutRow(
                  icon: Icons.forum_outlined,
                  type: NotificationOptOutType.community,
                  titleKey: 'comm_notif_pref_title',
                  subtitleKey: 'comm_notif_pref_subtitle',
                ),
              ],
              // Bot « Passerelle » : visible seulement serveur en mode `on`
              // (qui connaît la clé `assist_bridge`).
              if (RemoteFeatureFlags.instance.assistBridgeEnabled) ...[
                const SizedBox(height: 12),
                _optOutRow(
                  icon: Icons.support_agent_rounded,
                  type: NotificationOptOutType.assistBridge,
                  titleKey: 'assist_bridge_pref_title',
                  subtitleKey: 'assist_bridge_pref_subtitle',
                ),
              ],
              // Nouvelles et offres de KPB (correctifs 57) : visible seulement
              // si le serveur connaît la clé `kpb_promotions` — sinon il la
              // retirerait à l'écriture et l'interrupteur reviendrait seul.
              if (ctrl.profile?.serverKnowsPromotions ?? false) ...[
                const SizedBox(height: 12),
                _optOutRow(
                  icon: Icons.campaign_outlined,
                  type: NotificationOptOutType.kpbPromotions,
                  titleKey: 'kpb_promotions_pref_title',
                  subtitleKey: 'kpb_promotions_pref_subtitle',
                ),
              ],
              _matchAlertsRow(),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: KpbColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KpbColors.surfaceMuted),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: KpbColors.textMuted),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'notifications_push_os_note'.tr,
                        style: const TextStyle(
                          fontSize: KpbFontSize.xs,
                          height: 1.5,
                          color: KpbColors.textMuted,
                        ),
                      ),
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

  /// La ligne d'autorisation, selon l'état RÉEL : accordée (rien à faire),
  /// refusée (« Notifications coupées » + réglages de l'app), sinon « Activer ».
  Widget _enablePushRow() {
    final granted = _pushStatus == PushPermissionStatus.granted;
    final denied = _pushStatus == PushPermissionStatus.denied;
    final title = granted
        ? 'notifications_push_granted_title'.tr
        : denied
            ? 'push_denied_title'.tr
            : 'notifications_enable_push_title'.tr;
    final subtitle = granted
        ? 'notifications_push_granted_subtitle'.tr
        : denied
            ? 'notifications_push_denied_subtitle'.tr
            : 'notifications_enable_push_subtitle'.tr;
    final VoidCallback? onTap = granted
        ? null
        : denied
            ? () => unawaited(PushPermission.instance.openSettings())
            : _requestPush;
    return Semantics(
      button: onTap != null,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: denied
                    ? KpbColors.warningLight
                    : KpbColors.actionPrimarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                  denied
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_rounded,
                  size: 18,
                  color: denied ? KpbColors.warning : KpbColors.actionPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: KpbFontSize.sm,
                      fontWeight: FontWeight.w700,
                      color: KpbColors.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: KpbFontSize.xs,
                      height: 1.45,
                      color: KpbColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: KpbColors.actionPrimary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  denied
                      ? 'notifications_push_settings_action'.tr
                      : 'notifications_push_enable_action'.tr,
                  style: const TextStyle(
                    fontSize: KpbFontSize.xs,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// KPB-162: real, backed per-type toggle — "receive the daily Bourse du jour"
  /// (ON = not opted out). Persists via the profile PATCH and never touches
  /// other notifications.
  /// One row per opt-out-able notification family (KPB-169). The stored value
  /// is an OPT-OUT; the switch shows "receive", which is what the student
  /// thinks in. Toggling one family never touches the others.
  Widget _optOutRow({
    required IconData icon,
    required String type,
    required String titleKey,
    required String subtitleKey,
  }) {
    return GetBuilder<AppController>(
      builder: (c) => _prefToggleRow(
        icon: icon,
        titleKey: titleKey,
        subtitleKey: subtitleKey,
        receive: !(c.profile?.isNotificationTypeDisabled(type) ?? false),
        onReceiveChanged: (receive) =>
            c.setNotificationTypeOptOut(type, !receive),
      ),
    );
  }

  /// Shared layout for a per-type notification preference. Each row is backed by
  /// a real persisted field — no toggle is rendered unless it actually sticks.
  Widget _prefToggleRow({
    required IconData icon,
    required String titleKey,
    required String subtitleKey,
    required bool receive,
    required ValueChanged<bool> onReceiveChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: KpbColors.actionPrimarySoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: KpbColors.actionPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleKey.tr,
                style: const TextStyle(
                  fontSize: KpbFontSize.sm,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitleKey.tr,
                style: const TextStyle(
                  fontSize: KpbFontSize.xs,
                  height: 1.45,
                  color: KpbColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Switch(value: receive, onChanged: onReceiveChanged),
      ],
    );
  }

  Future<void> _requestPush() async {
    // La demande système, seulement sur geste explicite de l'élève. Inerte
    // tant que le push n'est pas initialisé (tests de widgets).
    final status = await PushPermission.instance.request();
    if (!mounted) return;
    setState(() => _pushStatus = status);
    if (status == PushPermissionStatus.denied) {
      await showPushDeniedSheet(context);
    }
  }

  // ── Relative time (reuses the shared time_ago_* keys) ───────────────────────

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'time_ago_just_now'.tr;
    if (diff.inMinutes < 60) {
      return 'time_ago_minutes'.trParams({'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time_ago_hours'.trParams({'n': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return 'time_ago_days'.trParams({'n': '${diff.inDays}'});
    }
    if (diff.inDays < 30) {
      return 'time_ago_weeks'.trParams({'n': '${diff.inDays ~/ 7}'});
    }
    return 'time_ago_months'.trParams({'n': '${diff.inDays ~/ 30}'});
  }
}
