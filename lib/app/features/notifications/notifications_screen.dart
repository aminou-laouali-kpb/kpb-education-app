import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/notification_opt_out.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/onesignal_service.dart';
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
//   • Preferences render ONE real control: an "Enable push notifications" row
//     wired to the real `OneSignalService.requestPermission()` capability, plus
//     an honest note that delivery is governed by the OS. The design's four
//     per-type toggles are DROPPED — they would persist nowhere.
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
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String route;
  final String? scholarshipId;
  final DateTime createdAt;
  final bool read;

  factory _StoredNotification.fromJson(Map<String, dynamic> json) {
    return _StoredNotification(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      route: json['route'] as String? ?? '',
      scholarshipId: json['scholarshipId'] as String? ??
          ((json['data'] is Map)
              ? (json['data'] as Map)['scholarshipId'] as String?
              : null),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      read: json['readAt'] != null,
    );
  }

  _StoredNotification markRead() => _StoredNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        route: route,
        scholarshipId: scholarshipId,
        createdAt: createdAt,
        read: true,
      );
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

const Duration _rejectedDotWindow = Duration(days: 7);

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

  @override
  void initState() {
    super.initState();
    _apiClient = Get.find<AppController>().apiClient;
    _loadStored();
  }

  Future<void> _loadStored() async {
    try {
      final profile = Get.find<AppController>().profile;
      final response = await _apiClient.fetchUserNotifications(
        profile?.preferredLanguage == 'en' ? 'en' : 'fr',
      );
      final items = (response['items'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_StoredNotification.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();
      if (mounted) setState(() => _stored = items);
    } catch (_) {
      // Dossier-derived rows stay available offline.
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _header(items),
                const SizedBox(height: 13),
                if (!hasItems)
                  _emptyState()
                else ...[
                  for (var i = 0; i < _stored.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _storedNotifCard(_stored[i]),
                  ],
                  if (_stored.isNotEmpty && items.isNotEmpty)
                    const SizedBox(height: 8),
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _notifCard(ctrl, items[i]),
                  ],
                ],
                const SizedBox(height: 18),
                _prefsSection(),
              ],
            );
          },
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
              fontSize: 19,
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
                    fontSize: 11.5,
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: KpbColors.brandNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'notifications_empty_body'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
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
                  fontSize: 9.5,
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
                  color: KpbColors.actionPrimarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 18,
                  color: KpbColors.actionPrimary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.brandNavy,
                      ),
                    ),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 11,
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
                _relativeTime(item.createdAt),
                style: const TextStyle(
                  fontSize: 9.5,
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
      try {
        await _apiClient.markUserNotificationRead(item.id);
      } catch (_) {
        // Navigation remains useful even if read-state persistence is offline.
      }
    }
    var rawRoute = item.route;
    if (rawRoute == AppRoutes.scholarships &&
        (item.scholarshipId?.trim().isNotEmpty ?? false)) {
      rawRoute = AppRoutes.scholarshipDetailPath(item.scholarshipId!.trim());
    }
    final route = AppRoutes.normalizeExternalRoute(rawRoute);
    if (route != null) await Get.toNamed(route);
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

  Widget _prefsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'notifications_push_section'.tr,
            style: const TextStyle(
              fontSize: 12,
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
                          fontSize: 10.5,
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

  Widget _enablePushRow() {
    return Semantics(
      button: true,
      label: 'notifications_enable_push_title'.tr,
      child: GestureDetector(
        onTap: _requestPush,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: KpbColors.actionPrimarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  size: 18, color: KpbColors.actionPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'notifications_enable_push_title'.tr,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: KpbColors.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'notifications_enable_push_subtitle'.tr,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.45,
                      color: KpbColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: KpbColors.actionPrimary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'notifications_push_enable_action'.tr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: KpbColors.brandNavy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitleKey.tr,
                style: const TextStyle(
                  fontSize: 10,
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
    // Real capability: triggers the OS permission prompt (once). A no-op until
    // OneSignal has been initialized (e.g. in widget tests), so it is always
    // safe to call.
    await OneSignalService.instance.requestPermission();
    if (!mounted) return;
    Get.snackbar(
      'notifications_title'.tr,
      'notifications_push_requested'.tr,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      backgroundColor: KpbColors.brandNavy,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
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
