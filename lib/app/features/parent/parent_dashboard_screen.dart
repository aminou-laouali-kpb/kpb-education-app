import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/app_tokens.dart';
import 'parent_case_view_screen.dart';

/// Entry point for parent accounts (Track C1 — Phase 1).
///
/// Shows:
/// - An invite-code flow: parents generate a code and send it to their child
///   by WhatsApp; students accept by typing the code.
/// - A list of the child's cases the student has opted to share.
/// - A "Discuter avec un conseiller" button on any shared case that opens
///   WhatsApp to a KPB advisor (fees are arranged with the advisor, not in-app).
///
/// Kept deliberately simple — parents in this market are often first-time
/// smartphone users who only reliably operate WhatsApp, so the UI stays
/// linear and avoids tabs or nested navigators.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  late final AppApiClient _api = AppApiClient();
  final _codeController = TextEditingController();

  bool _loading = true;
  List<dynamic> _children = const [];
  List<dynamic> _cases = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.listParentChildren(),
        _api.listParentVisibleCases(),
      ]);
      if (!mounted) return;
      setState(() {
        _children = results[0];
        _cases = results[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'parent_load_error'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _createInvite() async {
    try {
      final result = await _api.createParentInvite();
      final code = (result['inviteCode'] as String?) ?? '';
      if (!mounted || code.isEmpty) return;
      _showInviteSheet(code);
    } catch (_) {
      _toast('parent_invite_create_error'.tr);
    }
  }

  void _showInviteSheet(String code) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: KpbSpacing.lg,
          right: KpbSpacing.lg,
          top: KpbSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + KpbSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('parent_invite_code_title'.tr, style: KpbTextStyles.title),
            SizedBox(height: KpbSpacing.sm),
            Text(
              'parent_invite_share_hint'.tr,
              style: KpbTextStyles.bodySm,
            ),
            const SizedBox(height: KpbSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: KpbSpacing.lg,
                vertical: KpbSpacing.md,
              ),
              decoration: BoxDecoration(
                color: KpbColors.skyLight,
                borderRadius: KpbRadius.mdBr,
                border: Border.all(color: KpbColors.sky),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.navy,
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text('copy'.tr),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      _toast('parent_code_copied'.tr);
                    },
                  ),
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat),
                    label: Text('whatsapp'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KpbColors.whatsapp,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final text = Uri.encodeComponent(
                        'parent_invite_whatsapp_message'
                            .trParams({'code': code}),
                      );
                      launchUrl(
                        Uri.parse('https://wa.me/?text=$text'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptInvite() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 8) {
      _toast('parent_code_length_error'.tr);
      return;
    }
    try {
      await _api.acceptParentInvite(code);
      _codeController.clear();
      _toast('parent_link_activated'.tr);
      await _refresh();
    } catch (_) {
      _toast('auth_magic_verify_error'.tr);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final isParent = controller.isParent;

    return Scaffold(
      backgroundColor: KpbColors.bgPage,
      appBar: AppBar(
        title: Text(isParent
            ? 'profile_quick_parent_space'.tr
            : 'profile_quick_parent_mode'.tr),
        backgroundColor: Colors.white,
        foregroundColor: KpbColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(KpbSpacing.pagePad),
          children: [
            if (isParent) _inviteCard() else _acceptCard(),
            const SizedBox(height: KpbSpacing.lg),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(KpbSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _errorCard(_error!)
            else ...[
              if (isParent) _childrenSection(),
              if (isParent) const SizedBox(height: KpbSpacing.lg),
              if (isParent) _casesSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inviteCard() {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: KpbRadius.lgBr,
        boxShadow: KpbShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('parent_invite_child_title'.tr, style: KpbTextStyles.title),
          SizedBox(height: KpbSpacing.sm),
          Text(
            'parent_create_code_hint'.tr,
            style: KpbTextStyles.bodySm,
          ),
          const SizedBox(height: KpbSpacing.md),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: Text('parent_create_invite'.tr),
            onPressed: _createInvite,
          ),
        ],
      ),
    );
  }

  Widget _acceptCard() {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: KpbRadius.lgBr,
        boxShadow: KpbShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'parent_link_account_title'.tr,
            style: KpbTextStyles.title,
          ),
          SizedBox(height: KpbSpacing.sm),
          Text(
            'parent_accept_code_hint'.tr,
            style: KpbTextStyles.bodySm,
          ),
          const SizedBox(height: KpbSpacing.md),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'AB23CDEF',
              counterText: '',
            ),
            style: const TextStyle(
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          FilledButton(
            onPressed: _acceptInvite,
            child: Text('referral_redeem_cta'.tr),
          ),
        ],
      ),
    );
  }

  Widget _childrenSection() {
    if (_children.isEmpty) {
      return _EmptyHint(
        icon: Icons.family_restroom,
        message: 'parent_no_children_linked'.tr,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: KpbSpacing.xs, bottom: KpbSpacing.sm),
          child: Text('linked_children'.tr, style: KpbTextStyles.label),
        ),
        ..._children.map((raw) {
          final link = raw as Map<String, dynamic>;
          final child = link['child'] as Map<String, dynamic>? ?? const {};
          return Container(
            margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
            padding: const EdgeInsets.all(KpbSpacing.md),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: KpbRadius.mdBr,
              boxShadow: KpbShadow.soft,
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: KpbColors.skyLight,
                  child: Icon(Icons.person, color: KpbColors.navy),
                ),
                const SizedBox(width: KpbSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (child['fullName'] as String?) ?? '—',
                        style: KpbTextStyles.titleMd,
                      ),
                      if (child['currentLevel'] != null)
                        Text(
                          child['currentLevel'].toString(),
                          style: KpbTextStyles.bodySm,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _casesSection() {
    if (_cases.isEmpty) {
      return _EmptyHint(
        icon: Icons.folder_open_outlined,
        message: 'parent_no_shared_cases'.tr,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: KpbSpacing.xs, bottom: KpbSpacing.sm),
          child: Text('shared_cases'.tr, style: KpbTextStyles.label),
        ),
        ..._cases.map((raw) {
          final item = raw as Map<String, dynamic>;
          final id = item['id'] as String? ?? '';
          return InkWell(
            borderRadius: KpbRadius.mdBr,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ParentCaseViewScreen(caseId: id),
                ),
              );
              if (mounted) unawaited(_refresh());
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
              padding: const EdgeInsets.all(KpbSpacing.md),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: KpbRadius.mdBr,
                boxShadow: KpbShadow.soft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['title'] as String?) ?? 'deadlines_kind_case'.tr,
                    style: KpbTextStyles.titleMd,
                  ),
                  const SizedBox(height: KpbSpacing.xs),
                  Text(
                    (item['contextLabel'] as String?) ?? '',
                    style: KpbTextStyles.bodySm,
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusChip(status: item['status']?.toString() ?? ''),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: KpbColors.gray500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: const BoxDecoration(
        color: KpbColors.errorLight,
        borderRadius: KpbRadius.mdBr,
      ),
      child: Text(msg, style: const TextStyle(color: KpbColors.error)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: KpbRadius.mdBr,
        boxShadow: KpbShadow.soft,
      ),
      child: Row(
        children: [
          Icon(icon, color: KpbColors.gray500),
          const SizedBox(width: KpbSpacing.md),
          Expanded(child: Text(message, style: KpbTextStyles.bodySm)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KpbSpacing.sm,
        vertical: 4,
      ),
      decoration: const BoxDecoration(
        color: KpbColors.skyLight,
        borderRadius: KpbRadius.pillBr,
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: KpbColors.navy,
        ),
      ),
    );
  }
}
