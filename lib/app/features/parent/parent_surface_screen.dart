// Parent surface (App-engagement handoff · Parent App.dc.html).
//
// A 4-tab read-only space for a parent linked to their child: Vue d'ensemble
// / Dossier & finances / Actualités / Paiements. Rebuilt in the handoff's
// navy #0F172A + blue #2563EB system. Central theme: the parent gets a
// read-only view and the STUDENT controls what is shared.
//
// It binds ONLY the data the parent-links endpoints actually return (child
// identity + the cases the student opted into sharing: title, context,
// status, next step). Anything the backend doesn't provide is shown as an
// honest empty / locked / "arrange with advisor" state — never fabricated.
//
// Linking respects the backend direction: the PARENT creates an invite code
// and shares it; the child accepts it in their own app (accept() rejects
// non-student accounts). Payments respect the app's no-in-app-checkout rule
// and route to the KPB advisor on WhatsApp.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_toast.dart';

// Couleurs : tokens sémantiques centraux (KpbColors — architecture §10.2).
/// A shared case, from `/parent-links/cases` — only fields the backend returns.
class _CaseInfo {
  const _CaseInfo({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.nextStepTitle,
    required this.nextStepDesc,
  });
  final String title;
  final String subtitle;
  final String status;
  final String nextStepTitle;
  final String nextStepDesc;

  bool get hasNextStep => nextStepTitle.isNotEmpty || nextStepDesc.isNotEmpty;
}

class ParentSurfaceScreen extends StatefulWidget {
  const ParentSurfaceScreen({super.key});

  @override
  State<ParentSurfaceScreen> createState() => _ParentSurfaceScreenState();
}

class _ParentSurfaceScreenState extends State<ParentSurfaceScreen> {
  final _api = Get.find<AppController>().apiClient;

  bool _loading = true;
  bool _creating = false;
  String? _error;
  String? _inviteCode; // set after the parent generates an invite
  List<dynamic> _children = const [];
  List<dynamic> _cases = const [];
  int _tab = 0;

  bool get _linked => _children.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refresh();
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'parent_load_error'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _createInvite() async {
    setState(() => _creating = true);
    try {
      final res = await _api.createParentInvite();
      final code = (res['inviteCode'] as String?)?.trim() ?? '';
      if (!mounted) return;
      if (code.isEmpty) {
        _toast('parent_invite_create_error'.tr);
      } else {
        setState(() => _inviteCode = code);
      }
    } catch (_) {
      _toast('parent_invite_create_error'.tr);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _shareInvite() {
    final code = _inviteCode;
    if (code == null) return;
    openWhatsAppOrToast(
      prefill: 'parent_invite_share_msg'.trParams({'code': code}),
      source: 'parent_surface',
      contextType: 'parent_invite',
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    KpbToast.error(msg, context: context);
  }

  void _whatsapp(String prefill, String contextType) {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill: prefill,
      source: 'parent_surface',
      contextType: contextType,
    );
  }

  String get _childName {
    final child = (_children.first as Map)['child'] as Map? ?? const {};
    final full = (child['fullName'] as String?)?.trim() ?? '';
    if (full.isEmpty) return 'parent_child_default'.tr;
    return full.split(RegExp(r'\s+')).first;
  }

  String get _childInitials {
    final child = (_children.first as Map)['child'] as Map? ?? const {};
    return _initials((child['fullName'] as String?)?.trim() ?? '');
  }

  _CaseInfo? get _sharedCase {
    if (_cases.isEmpty) return null;
    final c = _cases.first as Map<String, dynamic>;
    return _CaseInfo(
      title: (c['title'] as String?)?.trim() ?? '',
      subtitle: (c['contextLabel'] as String?)?.trim() ?? '',
      status: (c['status'] as String?)?.trim() ?? '',
      nextStepTitle: (c['nextStepTitle'] as String?)?.trim() ?? '',
      nextStepDesc: (c['nextStepDescription'] as String?)?.trim() ?? '',
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '👤';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      // P3: a failed load must show the error/retry state, never fall through
      // to any placeholder data.
      body = _ErrorState(message: _error!, onRetry: _refresh);
    } else if (!_linked) {
      body = _OnboardingLink(
        code: _inviteCode,
        creating: _creating,
        onCreate: _createInvite,
        onShare: _shareInvite,
        onRefresh: _refresh,
      );
    } else {
      body = _LinkedSurface(
        tab: _tab,
        onTab: (i) => setState(() => _tab = i),
        childName: _childName,
        childInitials: _childInitials,
        sharedCase: _sharedCase,
        onRefresh: _refresh,
        onAdvisor: () => _whatsapp('parent_wa_advisor'.tr, 'parent_advisor'),
        onAskAccess: () =>
            _whatsapp('parent_wa_ask_access'.tr, 'parent_ask_access'),
        onUploadProof: () => _whatsapp('parent_wa_upload'.tr, 'parent_upload'),
        onPay: (item) => _whatsapp(
            'parent_wa_pay'.trParams({'item': item}), 'parent_payment'),
      );
    }

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
          title: Text('parent_appbar'.tr), backgroundColor: Colors.transparent),
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding — parent CREATES an invite code and shares it (child accepts it in
// their own app; the backend rejects a parent calling accept()).
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingLink extends StatelessWidget {
  const _OnboardingLink({
    required this.code,
    required this.creating,
    required this.onCreate,
    required this.onShare,
    required this.onRefresh,
  });
  final String? code;
  final bool creating;
  final VoidCallback onCreate;
  final VoidCallback onShare;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text('parent_onboarding_title'.tr,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.6,
                            color: KpbColors.textPrimary)),
                    const SizedBox(height: 14),
                    Text('parent_onboarding_sub'.tr,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: KpbColors.textMuted)),
                    const SizedBox(height: 20),
                    if (code != null) ...[
                      Text('parent_invite_code_label'.tr,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: KpbColors.textMuted)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: KpbColors.actionPrimary, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.key_rounded,
                                size: 18, color: KpbColors.actionPrimary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(code!,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: KpbColors.textPrimary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('parent_code_share_note'.tr,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: KpbColors.textMuted)),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: KpbColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _bullet(Icons.check_circle, KpbColors.success,
                              'parent_onboarding_b1'.tr),
                          _bullet(
                              Icons.shield_outlined,
                              KpbColors.actionPrimary,
                              'parent_onboarding_b2'.tr),
                          _bullet(Icons.chat, KpbColors.whatsapp,
                              'parent_onboarding_b3'.tr),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (code == null)
              _primaryButton(
                icon: Icons.qr_code_2_rounded,
                label: 'parent_create_cta'.tr,
                busy: creating,
                onTap: onCreate,
              )
            else ...[
              _primaryButton(
                icon: Icons.chat,
                label: 'parent_share_cta'.tr,
                onTap: onShare,
                color: KpbColors.whatsapp,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => onRefresh(),
                child: Text('parent_link_refresh'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool busy = false,
    Color color = KpbColors.actionPrimary,
  }) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
      ),
    );
  }

  static Widget _bullet(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.5),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KpbColors.gray700)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked surface — 4 tabs, real data + honest empty/locked states.
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedSurface extends StatelessWidget {
  const _LinkedSurface({
    required this.tab,
    required this.onTab,
    required this.childName,
    required this.childInitials,
    required this.sharedCase,
    required this.onRefresh,
    required this.onAdvisor,
    required this.onAskAccess,
    required this.onUploadProof,
    required this.onPay,
  });
  final int tab;
  final ValueChanged<int> onTab;
  final String childName;
  final String childInitials;
  final _CaseInfo? sharedCase;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdvisor;
  final VoidCallback onAskAccess;
  final VoidCallback onUploadProof;
  final void Function(String item) onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
              key: PageStorageKey<int>(tab),
              physics: const AlwaysScrollableScrollPhysics(),
              child: switch (tab) {
                1 => _CaseTab(
                    childName: childName,
                    sharedCase: sharedCase,
                    onAskAccess: onAskAccess,
                    onUploadProof: onUploadProof),
                2 => _PaymentsTab(childName: childName, onPay: onPay),
                3 =>
                  _UpdatesTab(sharedCase: sharedCase, onAskAccess: onAskAccess),
                _ => _OverviewTab(
                    childName: childName,
                    childInitials: childInitials,
                    sharedCase: sharedCase,
                    onAdvisor: onAdvisor),
              },
            ),
          ),
        ),
        _BottomNav(current: tab, onTap: onTab),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.childName,
    required this.childInitials,
    required this.sharedCase,
    required this.onAdvisor,
  });
  final String childName;
  final String childInitials;
  final _CaseInfo? sharedCase;
  final VoidCallback onAdvisor;

  @override
  Widget build(BuildContext context) {
    final c = sharedCase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: KpbColors.brandNavy,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(childInitials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('parent_greeting_generic'.tr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text(
                        'parent_linked_readonly'.trParams({'child': childName}),
                        style: const TextStyle(
                            color: KpbColors.textFaint, fontSize: 11.5)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shield_outlined,
                      size: 12, color: KpbColors.decorSky),
                  const SizedBox(width: 4),
                  Text('parent_readonly_chip'.tr,
                      style: const TextStyle(
                          color: KpbColors.decorSky,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c == null)
                _cardBox(children: [
                  Row(children: [
                    const Icon(Icons.hourglass_empty_rounded,
                        size: 18, color: KpbColors.textFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'parent_waiting_title'.trParams({'child': childName}),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: KpbColors.textPrimary)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('parent_waiting_body'.tr,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: KpbColors.textMuted)),
                ])
              else ...[
                _cardBox(children: [
                  Text(c.title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.textPrimary)),
                  if (c.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(c.subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: KpbColors.textMuted)),
                  ],
                  if (c.status.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _StatusChip(status: c.status),
                  ],
                ]),
                if (c.hasNextStep) ...[
                  const SizedBox(height: 13),
                  _cardBox(children: [
                    Text('parent_nextstep_label'.tr,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: KpbColors.actionPrimary)),
                    const SizedBox(height: 8),
                    if (c.nextStepTitle.isNotEmpty)
                      Text(c.nextStepTitle,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.4,
                              color: KpbColors.textPrimary)),
                    if (c.nextStepDesc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(c.nextStepDesc,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: KpbColors.textMuted)),
                    ],
                  ]),
                ],
              ],
              const SizedBox(height: 13),
              _AdvisorCta(onTap: onAdvisor),
              const SizedBox(height: 13),
              const _PrivacyNote(textKey: 'parent_privacy_note'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvisorCta extends StatelessWidget {
  const _AdvisorCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _cardBox(padded: false, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: KpbColors.successLight,
                    borderRadius: BorderRadius.circular(13)),
                child:
                    const Icon(Icons.chat, size: 20, color: KpbColors.whatsapp),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('parent_advisor_title'.tr,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: KpbColors.textPrimary)),
                    Text('parent_advisor_sub'.tr,
                        style: const TextStyle(
                            fontSize: 11, color: KpbColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: KpbColors.borderStrong),
            ],
          ),
        ),
      ]),
    );
  }
}

class _CaseTab extends StatelessWidget {
  const _CaseTab({
    required this.childName,
    required this.sharedCase,
    required this.onAskAccess,
    required this.onUploadProof,
  });
  final String childName;
  final _CaseInfo? sharedCase;
  final VoidCallback onAskAccess;
  final VoidCallback onUploadProof;

  @override
  Widget build(BuildContext context) {
    final c = sharedCase;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('parent_case_title'.tr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 14),
          if (c == null)
            _LockedCard(
              title: 'parent_docs_locked_title'.tr,
              body: 'parent_docs_locked_body'.trParams({'child': childName}),
              onAskAccess: onAskAccess,
            )
          else ...[
            _cardBox(children: [
              Text(c.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.textPrimary)),
              if (c.subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(c.subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: KpbColors.textMuted)),
              ],
              if (c.status.isNotEmpty) ...[
                const SizedBox(height: 10),
                _StatusChip(status: c.status),
              ],
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                  color: KpbColors.warningLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('parent_docs_managed_note'.tr,
                  style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: KpbColors.warning)),
            ),
          ],
          const SizedBox(height: 16),
          _sectionLabel('parent_financing_label'.tr),
          const SizedBox(height: 8),
          _cardBox(children: [
            Text('parent_financing_body'.tr,
                style: const TextStyle(
                    fontSize: 12, height: 1.55, color: KpbColors.textMuted)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onUploadProof,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                    color: KpbColors.actionPrimary,
                    borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 7),
                    Text('parent_fin_upload'.tr,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _UpdatesTab extends StatelessWidget {
  const _UpdatesTab({required this.sharedCase, required this.onAskAccess});
  final _CaseInfo? sharedCase;
  final VoidCallback onAskAccess;

  @override
  Widget build(BuildContext context) {
    final c = sharedCase;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('parent_updates_title'.tr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 2),
          Text('parent_updates_sub'.tr,
              style:
                  const TextStyle(fontSize: 11.5, color: KpbColors.textMuted)),
          const SizedBox(height: 14),
          if (c != null && c.hasNextStep)
            _cardBox(padded: false, children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: KpbColors.actionPrimarySoft,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.flag_rounded,
                          size: 18, color: KpbColors.actionPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              c.nextStepTitle.isNotEmpty
                                  ? c.nextStepTitle
                                  : 'parent_nextstep_label'.tr,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: KpbColors.textPrimary)),
                          if (c.nextStepDesc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(c.nextStepDesc,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.5,
                                    color: KpbColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ])
          else
            _cardBox(children: [
              Text('parent_no_updates'.tr,
                  style: const TextStyle(
                      fontSize: 12, height: 1.55, color: KpbColors.textMuted)),
            ]),
          const SizedBox(height: 10),
          _LockedCard(
            title: 'parent_msg_locked_title'.tr,
            body: 'parent_msg_locked_body'.tr,
            onAskAccess: onAskAccess,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.childName, required this.onPay});
  final String childName;
  final void Function(String item) onPay;

  static const _packs = [
    (
      nameKey: 'parent_pack_review',
      descKey: 'parent_pack_review_desc',
      price: '25 000 FCFA'
    ),
    (
      nameKey: 'parent_pack_full',
      descKey: 'parent_pack_full_desc',
      price: '75 000 FCFA'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('parent_pay_title'.tr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 2),
          Text('parent_pay_sub'.tr,
              style:
                  const TextStyle(fontSize: 11.5, color: KpbColors.textMuted)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: KpbColors.brandNavy,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: KpbColors.decorSky.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.workspace_premium,
                          size: 19, color: KpbColors.decorSky),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'parent_premium_title'
                                  .trParams({'child': childName}),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          Text('parent_premium_sub'.tr,
                              style: const TextStyle(
                                  color: KpbColors.textFaint, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => onPay('parent_premium_item'.tr),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                        color: KpbColors.actionPrimary,
                        borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text('parent_premium_cta'.tr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel('parent_packs_label'.tr),
          const SizedBox(height: 8),
          for (final p in _packs) ...[
            _cardBox(padded: false, children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nameKey.tr,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: KpbColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(p.descKey.tr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: KpbColors.textMuted)),
                          const SizedBox(height: 3),
                          Text(p.price,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: KpbColors.actionPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => onPay(p.nameKey.tr),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: KpbColors.actionPrimary,
                            borderRadius: BorderRadius.circular(100)),
                        child: Text('parent_pay_cta'.tr,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          // HISTORIQUE — no payment history is exposed by the backend yet, so we
          // show an honest empty state rather than fabricated receipts.
          _sectionLabel('parent_pay_history_label'.tr),
          const SizedBox(height: 8),
          _cardBox(children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: KpbColors.canvas,
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.receipt_long_outlined,
                      size: 17, color: KpbColors.textFaint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('parent_pay_history_empty'.tr,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: KpbColors.textMuted)),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 5),
          const _PrivacyNote(
              textKey: 'parent_pay_note', icon: Icons.verified_user),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

Widget _cardBox({required List<Widget> children, bool padded = true}) {
  return Container(
    width: double.infinity,
    padding: padded ? const EdgeInsets.all(16) : EdgeInsets.zero,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: KpbColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

Widget _sectionLabel(String text) => Text(text.toUpperCase(),
    style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: KpbColors.textFaint));

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    // Localized label per known case status; falls back to the raw value.
    final key = 'case_status_$status';
    final label = key.tr;
    final shown = label == key ? status : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: KpbColors.actionPrimarySoft,
          borderRadius: BorderRadius.circular(100)),
      child: Text(shown,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KpbColors.actionPrimary)),
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({
    required this.title,
    required this.body,
    required this.onAskAccess,
    this.compact = false,
  });
  final String title;
  final String body;
  final VoidCallback onAskAccess;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KpbColors.borderStrong, width: 1.5),
      ),
      child: compact
          ? Row(
              children: [
                const Icon(Icons.lock, size: 20, color: KpbColors.textFaint),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(body,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: KpbColors.textMuted))),
                _askBtn(onAskAccess),
              ],
            )
          : Column(
              children: [
                const Icon(Icons.lock, size: 26, color: KpbColors.textFaint),
                const SizedBox(height: 10),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textPrimary)),
                const SizedBox(height: 6),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: KpbColors.textMuted)),
                const SizedBox(height: 12),
                _askBtn(onAskAccess),
              ],
            ),
    );
  }

  Widget _askBtn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: KpbColors.actionPrimary, width: 1.5)),
          child: Text('parent_ask_access'.tr,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.actionPrimary)),
        ),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote(
      {required this.textKey, this.icon = Icons.shield_outlined});
  final String textKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        border:
            Border.all(color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: KpbColors.actionPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(textKey.tr,
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.actionPrimaryPressed)),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.space_dashboard, key: 'parent_nav_overview'),
    (icon: Icons.folder_shared, key: 'parent_nav_case'),
    (icon: Icons.account_balance_wallet, key: 'parent_nav_pay'),
    (icon: Icons.campaign, key: 'parent_nav_updates'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          4, 6, 4, 10 + MediaQuery.of(context).padding.bottom * 0.5),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 28,
                      decoration: BoxDecoration(
                        color: current == i
                            ? KpbColors.actionPrimarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(_items[i].icon,
                          size: 20,
                          color: current == i
                              ? KpbColors.actionPrimary
                              : KpbColors.textFaint),
                    ),
                    const SizedBox(height: 3),
                    Text(_items[i].key.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: current == i
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: current == i
                                ? KpbColors.actionPrimary
                                : KpbColors.textFaint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: KpbColors.textFaint),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
