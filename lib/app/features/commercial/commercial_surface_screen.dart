// Conseiller / Commercial surface (App-engagement handoff · Commercial App.dc.html).
//
// A 3-tab surface for a KPB counsellor: Leads WhatsApp / Dossiers / Performance,
// plus a pushed lead-detail screen. Rebuilt in the handoff's navy #0F172A +
// blue #2563EB system.
//
// Binds the REAL commercial data already exposed by _CommercialMixin
// (CommercialLead + CommercialStats + case documents). Per-document review
// (Feature D) is wired end to end: the lead detail lists each uploaded document
// with three verdicts (Valider / À refaire / Douteux) posted to
// PATCH /commercial/documents/:id/review. Fields the backend still doesn't
// provide (the verbatim WhatsApp message, 10-step progress) are omitted — the
// surface shows only real data + honest empty states. The counsellor replies on
// WhatsApp and converts a lead via the existing lead-tag endpoint.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_toast.dart';

// Couleurs : tokens sémantiques centraux (KpbColors — architecture §10.2).
// Couleurs catégorielles des avatars (séries distinctes — exception §14 de
// l'architecture), déterministes par hash du nom. Valeurs = tokens.
const _avatarColors = [
  KpbColors.actionPrimary,
  KpbColors.success,
  KpbColors.decorIndigo,
  KpbColors.warning,
  KpbColors.businessSky,
  KpbColors.error,
];

Color _avatarColor(String seed) {
  var h = 0;
  for (final ch in seed.codeUnits) {
    h = (h * 31 + ch) & 0x7fffffff;
  }
  return _avatarColors[h % _avatarColors.length];
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '•';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// Relative age from a timestamp ("il y a 25 min" / "il y a 2 h" / "il y a 3 j").
String _age(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 60) {
    return 'commercial_age_min'.trParams({'n': '${d.inMinutes.clamp(1, 59)}'});
  }
  if (d.inHours < 24) {
    return 'commercial_age_hour'.trParams({'n': '${d.inHours}'});
  }
  return 'commercial_age_day'.trParams({'n': '${d.inDays}'});
}

/// A lead's tag → chip label + colors + whether it counts as "hot" (needs reply).
class _TagStyle {
  const _TagStyle(this.label, this.bg, this.fg, this.darkBg, this.darkFg);
  final String label;
  final Color bg;
  final Color fg;
  final Color darkBg;
  final Color darkFg;
}

_TagStyle _tagStyle(String? tag) {
  switch (tag) {
    case 'converted':
      return _TagStyle(
          'commercial_tag_converted',
          KpbColors.successLight,
          KpbColors.success,
          KpbColors.success.withValues(alpha: 0.3),
          KpbColors.successOnDark);
    case 'qualified':
      return _TagStyle(
          'commercial_tag_qualified',
          KpbColors.businessSky.withValues(alpha: 0.15),
          KpbColors.businessSky,
          KpbColors.businessSky.withValues(alpha: 0.22),
          KpbColors.decorSky);
    default: // 'new' / null → needs a first reply
      return _TagStyle(
          'commercial_tag_new',
          KpbColors.errorLight,
          KpbColors.error,
          KpbColors.error.withValues(alpha: 0.25),
          KpbColors.errorOnDark);
  }
}

bool _needsReply(CommercialLead l) => l.leadTag == null || l.leadTag == 'new';

class CommercialSurfaceScreen extends StatefulWidget {
  const CommercialSurfaceScreen({super.key});

  @override
  State<CommercialSurfaceScreen> createState() =>
      _CommercialSurfaceScreenState();
}

class _CommercialSurfaceScreenState extends State<CommercialSurfaceScreen> {
  final _ctrl = Get.find<AppController>();
  int _tab = 0;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.fetchCommercialLeads();
      _ctrl.fetchCommercialStats();
    });
  }

  Future<void> _refresh() async {
    await _ctrl.fetchCommercialLeads();
    await _ctrl.fetchCommercialStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: GetBuilder<AppController>(
        builder: (c) {
          final leads = c.commercialLeads;
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    key: PageStorageKey<int>(_tab),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: switch (_tab) {
                      1 => _CasesTab(
                          leads: leads
                              .where((l) => !_needsReply(l))
                              .toList(growable: false),
                          loading: c.isLoadingCommercialLeads,
                          onOpen: _openLead),
                      2 => _PerformanceTab(
                          advisorName: c.profile?.fullName ?? 'Conseiller',
                          stats: c.commercialStats,
                          leads: leads),
                      _ => _LeadsTab(
                          leads: leads,
                          filter: _filter,
                          loading: c.isLoadingCommercialLeads,
                          error: c.commercialLeadsError,
                          onFilter: (f) => setState(() => _filter = f),
                          onOpen: _openLead,
                          onRetry: _refresh),
                    },
                  ),
                ),
              ),
              _BottomNav(
                current: _tab,
                newCount: leads.where(_needsReply).length,
                onTap: (i) => setState(() => _tab = i),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openLead(CommercialLead lead) {
    Get.to(() => CommercialLeadDetailScreen(lead: lead));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Leads WhatsApp
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  const _LeadsTab({
    required this.leads,
    required this.filter,
    required this.loading,
    required this.error,
    required this.onFilter,
    required this.onOpen,
    required this.onRetry,
  });
  final List<CommercialLead> leads;
  final String filter;
  final bool loading;
  final String? error;
  final ValueChanged<String> onFilter;
  final void Function(CommercialLead) onOpen;
  final Future<void> Function() onRetry;

  int _count(String f) => switch (f) {
        'new' => leads.where(_needsReply).length,
        'qualified' => leads.where((l) => l.leadTag == 'qualified').length,
        'converted' => leads.where((l) => l.leadTag == 'converted').length,
        _ => leads.length,
      };

  List<CommercialLead> get _filtered => switch (filter) {
        'new' => leads.where(_needsReply).toList(),
        'qualified' => leads.where((l) => l.leadTag == 'qualified').toList(),
        'converted' => leads.where((l) => l.leadTag == 'converted').toList(),
        _ => leads,
      };

  @override
  Widget build(BuildContext context) {
    final newCount = _count('new');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('commercial_leads_title'.tr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 2),
          Text('commercial_leads_sub'.trParams({'n': '$newCount'}),
              style:
                  const TextStyle(fontSize: 11.5, color: KpbColors.textMuted)),
          const SizedBox(height: 12),
          // SLA banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: KpbColors.warningLight,
              border:
                  Border.all(color: KpbColors.warning.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 17, color: KpbColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('commercial_sla'.trParams({'n': '$newCount'}),
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: KpbColors.warning)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in const [
                  'all',
                  'new',
                  'qualified',
                  'converted'
                ]) ...[
                  _FilterChip(
                    label: '${'commercial_filter_$f'.tr} (${_count(f)})',
                    selected: filter == f,
                    onTap: () => onFilter(f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (loading && leads.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null && leads.isEmpty)
            _ErrorState(message: error!, onRetry: onRetry)
          else if (_filtered.isEmpty)
            _EmptyHint(
                icon: Icons.inbox_outlined, textKey: 'commercial_leads_empty')
          else
            for (final l in _filtered) ...[
              _LeadCard(lead: l, onTap: () => onOpen(l)),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead, required this.onTap});
  final CommercialLead lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = _tagStyle(lead.leadTag);
    final hot = _needsReply(lead);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: KpbColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: _avatarColor(lead.studentName),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(_initials(lead.studentName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
                if (lead.unreadMessages > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: KpbColors.error,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white, width: 1.5)),
                      child: Text('${lead.unreadMessages}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.textPrimary)),
                  if ((lead.studentLevel ?? lead.title).isNotEmpty)
                    Text(lead.studentLevel ?? lead.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: KpbColors.textMuted)),
                  const SizedBox(height: 3),
                  Text(_age(lead.updatedAt),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hot ? KpbColors.error : KpbColors.textFaint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: s.bg, borderRadius: BorderRadius.circular(100)),
              child: Text(s.label.tr,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: s.fg)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lead detail (pushed)
// ─────────────────────────────────────────────────────────────────────────────

class CommercialLeadDetailScreen extends StatefulWidget {
  const CommercialLeadDetailScreen({super.key, required this.lead});
  final CommercialLead lead;

  @override
  State<CommercialLeadDetailScreen> createState() =>
      _CommercialLeadDetailScreenState();
}

class _CommercialLeadDetailScreenState
    extends State<CommercialLeadDetailScreen> {
  final _ctrl = Get.find<AppController>();
  late String _tag = widget.lead.leadTag ?? 'new';
  bool _converting = false;
  late List<CommercialLeadDocument> _docs = List.of(widget.lead.documents);
  final Set<String> _reviewingDocIds = <String>{};

  void _toast(String msg, {KpbToastKind kind = KpbToastKind.info}) {
    if (!mounted) return;
    KpbToast.show(kind: kind, message: msg, context: context);
  }

  Future<void> _convert() async {
    if (_tag == 'converted' || _converting) return;
    setState(() => _converting = true);
    try {
      await _ctrl.updateCommercialLeadTag(widget.lead.id, leadTag: 'converted');
      if (!mounted) return;
      setState(() => _tag = 'converted');
      _toast(
          'commercial_converted_toast'
              .trParams({'name': widget.lead.studentName}),
          kind: KpbToastKind.success);
    } catch (_) {
      _toast('commercial_convert_error'.tr, kind: KpbToastKind.error);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _reviewDoc(CommercialLeadDocument doc, String status) async {
    if (_reviewingDocIds.contains(doc.id)) return;
    setState(() => _reviewingDocIds.add(doc.id));
    try {
      final updated = await _ctrl.reviewCommercialDocument(
        widget.lead.id,
        doc.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _docs = _docs
            .map((d) => d.id == updated.id ? updated : d)
            .toList(growable: false);
      });
    } catch (_) {
      _toast('commercial_doc_review_error'.tr, kind: KpbToastKind.error);
    } finally {
      if (mounted) setState(() => _reviewingDocIds.remove(doc.id));
    }
  }

  void _replyWhatsApp() {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill:
          'commercial_wa_reply'.trParams({'name': widget.lead.studentName}),
      source: 'commercial_surface',
      contextType: 'commercial_reply',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final s = _tagStyle(_tag);
    final profil = <({String k, String v})>[
      if ((lead.studentLevel ?? '').isNotEmpty)
        (k: 'commercial_field_level'.tr, v: lead.studentLevel!),
      if (lead.referenceCode.isNotEmpty)
        (k: 'commercial_field_ref'.tr, v: lead.referenceCode),
      if (lead.title.isNotEmpty) (k: 'commercial_field_case'.tr, v: lead.title),
      (k: 'commercial_field_status'.tr, v: _caseStatusLabel(lead.status)),
    ];

    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navy header
          Container(
            color: KpbColors.brandNavy,
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 10, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back<void>(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back,
                            size: 19, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: s.darkBg,
                          borderRadius: BorderRadius.circular(100)),
                      child: Text(s.label.tr,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: s.darkFg)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: _avatarColor(lead.studentName),
                          shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(_initials(lead.studentName),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lead.studentName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          if (lead.title.isNotEmpty)
                            Text(lead.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: KpbColors.textFaint,
                                    fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 13,
                      child: GestureDetector(
                        onTap: _replyWhatsApp,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                              color: KpbColors.whatsapp,
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('commercial_reply_wa'.tr,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 10,
                      child: GestureDetector(
                        onTap: _convert,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_converting)
                                const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              else ...[
                                Icon(
                                    _tag == 'converted'
                                        ? Icons.check_circle
                                        : Icons.workspace_premium,
                                    size: 15,
                                    color: KpbColors.successOnDark),
                                const SizedBox(width: 6),
                                Text(
                                    _tag == 'converted'
                                        ? 'commercial_signed'.tr
                                        : 'commercial_mark_signed'.tr,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: KpbColors.border),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('commercial_profile_title'.tr,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: KpbColors.textPrimary)),
                        const SizedBox(height: 10),
                        for (final p in profil)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.k,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: KpbColors.textFaint)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(p.v,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: KpbColors.textPrimary)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if ((lead.discussionMotive ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: KpbColors.warningLight,
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.flag_rounded,
                              size: 15, color: KpbColors.warning),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(lead.discussionMotive!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: KpbColors.warning)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _DocReviewCard(
                    docs: _docs,
                    reviewingIds: _reviewingDocIds,
                    onReview: _reviewDoc,
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

// ─────────────────────────────────────────────────────────────────────────────
// Per-document review (Feature D) — Commercial App.dc.html l.132-146
// ─────────────────────────────────────────────────────────────────────────────

/// A document's review verdict → chip label + bg/fg colors.
class _RevStyle {
  const _RevStyle(this.labelKey, this.bg, this.fg);
  final String labelKey;
  final Color bg;
  final Color fg;
}

_RevStyle? _revStyle(String? status) {
  switch (status) {
    case 'validated':
      return const _RevStyle('commercial_doc_status_validated',
          KpbColors.successLight, KpbColors.success);
    case 'redo':
      return const _RevStyle(
          'commercial_doc_status_redo', KpbColors.errorLight, KpbColors.error);
    case 'doubtful':
      return const _RevStyle('commercial_doc_status_doubtful',
          KpbColors.warningLight, KpbColors.warning);
    default:
      return null;
  }
}

class _DocReviewCard extends StatelessWidget {
  const _DocReviewCard({
    required this.docs,
    required this.reviewingIds,
    required this.onReview,
  });
  final List<CommercialLeadDocument> docs;
  final Set<String> reviewingIds;
  final void Function(CommercialLeadDocument doc, String status) onReview;

  @override
  Widget build(BuildContext context) {
    final pending = docs.where((d) => d.isProvided && !d.isReviewed).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: KpbColors.border),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('commercial_docs_title'.tr,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textPrimary)),
              ),
              if (pending > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: KpbColors.warningLight,
                      borderRadius: BorderRadius.circular(100)),
                  child: Text(
                      'commercial_docs_to_review'.trParams({'n': '$pending'}),
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.warning)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text('commercial_docs_sub'.trParams({'n': '${docs.length}'}),
              style: const TextStyle(fontSize: 11, color: KpbColors.textFaint)),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 18, color: KpbColors.textFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('commercial_docs_empty'.tr,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: KpbColors.textMuted)),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < docs.length; i++) ...[
              _DocRow(
                doc: docs[i],
                reviewing: reviewingIds.contains(docs[i].id),
                onReview: onReview,
              ),
              if (i != docs.length - 1)
                const Divider(
                    height: 22, thickness: 1, color: KpbColors.surfaceMuted),
            ],
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.reviewing,
    required this.onReview,
  });
  final CommercialLeadDocument doc;
  final bool reviewing;
  final void Function(CommercialLeadDocument doc, String status) onReview;

  @override
  Widget build(BuildContext context) {
    final rev = _revStyle(doc.reviewStatus);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: KpbColors.canvas,
          border: Border.all(color: KpbColors.surfaceMuted),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  doc.isProvided
                      ? Icons.description_rounded
                      : Icons.upload_file_outlined,
                  size: 16,
                  color: doc.isProvided
                      ? KpbColors.textMuted
                      : KpbColors.textFaint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(doc.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              if (rev != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                      color: rev.bg, borderRadius: BorderRadius.circular(100)),
                  child: Text(rev.labelKey.tr,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: rev.fg)),
                )
              else
                Text(
                    (doc.isProvided
                            ? 'commercial_doc_provided'
                            : 'commercial_doc_pending')
                        .tr,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: doc.isProvided
                            ? KpbColors.success
                            : KpbColors.textFaint)),
            ],
          ),
          // Reviewer / timestamp line once a verdict exists.
          if (rev != null && (doc.reviewedByName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
                doc.reviewedAt != null
                    ? 'commercial_doc_reviewed_meta'.trParams({
                        'name': doc.reviewedByName!,
                        'age': _age(doc.reviewedAt!),
                      })
                    : 'commercial_doc_reviewed_by'
                        .trParams({'name': doc.reviewedByName!}),
                style:
                    const TextStyle(fontSize: 10, color: KpbColors.textFaint)),
          ],
          // Verdict buttons — only for an uploaded, not-yet-reviewed document.
          if (doc.isProvided && rev == null) ...[
            const SizedBox(height: 10),
            if (reviewing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _VerdictButton(
                      labelKey: 'commercial_doc_validate',
                      fillColor: KpbColors.success,
                      textColor: Colors.white,
                      onTap: () => onReview(doc, 'validated'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _VerdictButton(
                      labelKey: 'commercial_doc_redo',
                      borderColor: KpbColors.error.withValues(alpha: 0.35),
                      textColor: KpbColors.error,
                      onTap: () => onReview(doc, 'redo'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _VerdictButton(
                      labelKey: 'commercial_doc_doubtful',
                      borderColor: KpbColors.warning.withValues(alpha: 0.35),
                      textColor: KpbColors.warning,
                      onTap: () => onReview(doc, 'doubtful'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    required this.labelKey,
    required this.textColor,
    required this.onTap,
    this.fillColor,
    this.borderColor,
  });
  final String labelKey;
  final Color textColor;
  final VoidCallback onTap;
  final Color? fillColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor ?? Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
        ),
        child: Text(labelKey.tr,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: textColor)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Dossiers (active leads: qualified / converted)
// ─────────────────────────────────────────────────────────────────────────────

class _CasesTab extends StatelessWidget {
  const _CasesTab({
    required this.leads,
    required this.loading,
    required this.onOpen,
  });
  final List<CommercialLead> leads;
  final bool loading;
  final void Function(CommercialLead) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('commercial_cases_title'.tr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textPrimary)),
          const SizedBox(height: 2),
          Text('commercial_cases_sub'.trParams({'n': '${leads.length}'}),
              style:
                  const TextStyle(fontSize: 11.5, color: KpbColors.textMuted)),
          const SizedBox(height: 14),
          if (loading && leads.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (leads.isEmpty)
            _EmptyHint(
                icon: Icons.folder_open_outlined,
                textKey: 'commercial_cases_empty')
          else
            for (final l in leads) ...[
              GestureDetector(
                onTap: () => onOpen(l),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: KpbColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: _avatarColor(l.studentName),
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(_initials(l.studentName),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.studentName,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: KpbColors.textPrimary)),
                            if (l.title.isNotEmpty)
                              Text(l.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: KpbColors.textMuted)),
                            Builder(builder: (_) {
                              final pending = l.documents
                                  .where((d) => d.isProvided && !d.isReviewed)
                                  .length;
                              if (pending == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    const Icon(Icons.rate_review_outlined,
                                        size: 11, color: KpbColors.warning),
                                    const SizedBox(width: 4),
                                    Text(
                                        'commercial_docs_to_review'
                                            .trParams({'n': '$pending'}),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: KpbColors.warning)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: KpbColors.actionPrimarySoft,
                            borderRadius: BorderRadius.circular(100)),
                        child: Text(_caseStatusLabel(l.status),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: KpbColors.actionPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Performance
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({
    required this.advisorName,
    required this.stats,
    required this.leads,
  });
  final String advisorName;
  final CommercialStats stats;
  final List<CommercialLead> leads;

  @override
  Widget build(BuildContext context) {
    // Real breakdown by lead tag, computed from the fetched leads.
    final byTag = <String, int>{};
    for (final l in leads) {
      final t = l.leadTag ?? 'new';
      byTag[t] = (byTag[t] ?? 0) + 1;
    }
    final total = leads.isEmpty ? 1 : leads.length;
    final order = ['new', 'qualified', 'converted']
        .where((t) => (byTag[t] ?? 0) > 0)
        .toList();

    final avg = stats.avgFirstResponseMinutes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: KpbColors.brandNavy, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(_initials(advisorName),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(advisorName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: KpbColors.textPrimary)),
                    Text('commercial_perf_role'.tr,
                        style: const TextStyle(
                            fontSize: 11.5, color: KpbColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      value: '${stats.totalLeads}',
                      label: 'commercial_stat_total'.tr,
                      color: KpbColors.textPrimary)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatCard(
                      value: '${stats.convertedLast30Days}',
                      label: 'commercial_stat_converted'.tr,
                      color: KpbColors.success)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatCard(
                      value: avg == null ? '—' : _fmtDuration(avg),
                      label: 'commercial_stat_response'.tr,
                      color: KpbColors.actionPrimary)),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: KpbColors.border),
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('commercial_perf_breakdown'.tr,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.textPrimary)),
                const SizedBox(height: 12),
                if (order.isEmpty)
                  Text('commercial_perf_empty'.tr,
                      style: const TextStyle(
                          fontSize: 12, color: KpbColors.textMuted))
                else
                  for (final t in order) ...[
                    _BreakdownRow(
                      label: 'commercial_tag_$t'.tr,
                      count: byTag[t]!,
                      ratio: byTag[t]! / total,
                    ),
                    if (t != order.last) const SizedBox(height: 10),
                  ],
                const SizedBox(height: 10),
                Text('commercial_perf_note'.tr,
                    style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: KpbColors.textFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    return '$h h';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: KpbColors.border),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: KpbColors.textFaint)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(
      {required this.label, required this.count, required this.ratio});
  final String label;
  final int count;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: KpbColors.textPrimary)),
            ),
            Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.textMuted)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: KpbColors.surfaceMuted,
            valueColor: const AlwaysStoppedAnimation(KpbColors.decorSky),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

String _caseStatusLabel(String status) {
  final key = 'case_status_$status';
  final label = key.tr;
  return label == key ? status : label;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? KpbColors.actionPrimarySoft : KpbColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: selected ? KpbColors.actionPrimary : KpbColors.border,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                // textSecondary (7,58:1) : textMuted frôle le seuil AA à 11,5.
                color: selected
                    ? KpbColors.actionPrimary
                    : KpbColors.textSecondary)),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.textKey});
  final IconData icon;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 34, color: KpbColors.textFaint),
          const SizedBox(height: 10),
          Text(textKey.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: KpbColors.textMuted)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: KpbColors.textFaint),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text('retry'.tr),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav(
      {required this.current, required this.newCount, required this.onTap});
  final int current;
  final int newCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.chat_rounded, key: 'commercial_nav_leads', badge: newCount),
      (icon: Icons.folder_copy_rounded, key: 'commercial_nav_cases', badge: 0),
      (icon: Icons.insights_rounded, key: 'commercial_nav_perf', badge: 0),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KpbColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          4, 6, 4, 10 + MediaQuery.of(context).padding.bottom * 0.5),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
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
                          child: Icon(items[i].icon,
                              size: 20,
                              color: current == i
                                  ? KpbColors.actionPrimary
                                  : KpbColors.textFaint),
                        ),
                        if (items[i].badge > 0 && current != i)
                          Positioned(
                            right: 6,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: KpbColors.error,
                                  borderRadius: BorderRadius.circular(9)),
                              child: Text('${items[i].badge}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(items[i].key.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9.5,
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
