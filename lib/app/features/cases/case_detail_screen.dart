import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/observability/crashlytics_observability.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/safe_crashlytics.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/services/document_upload_service.dart';
import '../ai_advisor/ai_consent.dart';
import '../services/service_packages_screen.dart';
import '../tools/interview_simulator_screen.dart';
import 'case_status_timeline.dart';
import 'post_decision_screen.dart';
import 'case_timeline_definition.dart';
import 'document_review_screen.dart';

part 'case_detail_screen/header.dart';
part 'case_detail_screen/cards.dart';
part 'case_detail_screen/thread.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

// Best-effort flag: the case model has no country field, so we only show a flag
// when a known country name actually appears in the case title/context — never
// a fabricated one. Falls back to a neutral folder glyph otherwise.
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

IconData _caseTypeIcon(CaseType type) {
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

Future<void> _openWhatsapp({
  String? prefill,
  String? advisorName,
}) async {
  // Gate every case hand-off behind the verified-advisor card so an impostor
  // number is obvious before the user leaves the app. No `phone:` on purpose:
  // case hand-offs always target the official KPB line, never a counsellor's
  // personal number (anti-fraud, Item 12).
  await showVerifiedAdvisorThenWhatsApp(
    advisorName: advisorName,
    prefill: prefill,
    source: 'case_detail',
    contextType: 'case',
  );
}

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  AppController get _ctrl => Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.markCaseMessagesRead(widget.caseId);
      if (AppConfig.enableRemoteSync) {
        _ctrl.connectCaseDetailSocket(widget.caseId);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.disconnectCaseDetailSocket();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Le chemin d'envoi pendant le masquage M2 : le conseiller, sur WhatsApp,
  /// avec le nom du document et la référence du dossier déjà écrits.
  ///
  /// Rien n'est coché « fourni » ici, et c'est volontaire. C'est le conseiller
  /// qui marquera la demande satisfaite quand il aura réellement reçu le
  /// fichier — l'inverse exact de ce que faisait l'écran avant, où la coche
  /// partait AVANT l'appel réseau et survivait à son échec.
  Future<void> _sendDocumentViaWhatsApp(
    StudentCase caseItem,
    DocumentRequest doc,
  ) async {
    await _openWhatsapp(
      advisorName: caseItem.assignedAdvisorName,
      prefill: 'case_document_whatsapp_prefill'.trParams({
        'document': _ctrl.resolve(doc.title),
        'reference': caseItem.referenceCode,
      }),
    );
  }

  Future<void> _promptUpload(String caseId, DocumentRequest doc) async {
    unawaited(showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text('case_upload_take_photo'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await DocumentUploadService.captureFromCamera();
                  if (file != null) {
                    _ctrl.uploadDocument(caseId, doc.id, file.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text('case_upload_from_gallery'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await DocumentUploadService.pickFromGallery();
                  if (file != null) {
                    _ctrl.uploadDocument(caseId, doc.id, file.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text('case_upload_pick_pdf'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final file = await DocumentUploadService.pickPdf();
                    if (file != null) {
                      _ctrl.uploadDocument(caseId, doc.id, file.path);
                    }
                  } on FileTooLargeException catch (error) {
                    Get.snackbar(
                      'case_tunnel_file_too_large_title'.tr,
                      error.localizedBody(),
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } catch (error, stack) {
                    // `e.toString()` était peint à l'écran tel quel : sur ce
                    // chemin, une DioException complète — URL, en-têtes, code —
                    // pouvait s'afficher à un étudiant. Un message utile va à
                    // l'écran, la trace va aux journaux.
                    safeRecordError(
                      error,
                      stack,
                      reason: 'caseDocumentPickPdf',
                      domain: CrashlyticsObsDomain.cases,
                      operation: 'pick_case_document_pdf',
                    );
                    Get.snackbar(
                      'common_error'.tr,
                      'case_tunnel_add_file_failed'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    ));
  }

  /// Admission-milestone review (KPB-75): rate the counsellor 1–5 + optional
  /// testimonial → POST to the moderation queue. Marked handled either way so
  /// it is asked at most once.
  Future<void> _promptReview(StudentCase c) async {
    final counsellorId = c.counsellorId;
    if (counsellorId == null) return;
    final textCtrl = TextEditingController();
    var rating = 5;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.all(KpbSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('review_prompt_title'.tr, style: KpbTextStyles.title),
                const SizedBox(height: 4),
                Text('review_prompt_sheet_body'.tr,
                    style: KpbTextStyles.bodySm),
                const SizedBox(height: KpbSpacing.md),
                Row(
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      tooltip: 'a11y_rate'.tr,
                      icon: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: KpbColors.gold,
                        size: 32,
                      ),
                      onPressed: () => setSheet(() => rating = i + 1),
                    ),
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration:
                      InputDecoration(labelText: 'review_prompt_hint'.tr),
                ),
                const SizedBox(height: KpbSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('review_prompt_submit'.tr),
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );

    // Un envoi qui échoue ne « consomme » pas la demande d'avis : avant,
    // l'avis était perdu et la carte disparaissait sans moyen de réessayer.
    var sendFailed = false;
    if (submitted == true) {
      try {
        await _ctrl.apiClient.submitCounsellorReview(
          counsellorId: counsellorId,
          rating: rating,
          body: textCtrl.text.trim(),
          reviewerName: _ctrl.profile?.fullName ?? 'KPB',
          caseId: c.id,
        );
        Get.snackbar('review_prompt_title'.tr, 'review_prompt_thanks'.tr,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12));
      } catch (_) {
        sendFailed = true;
        Get.snackbar('review_prompt_title'.tr, 'review_prompt_error'.tr,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12));
      }
    }
    textCtrl.dispose();
    // Asked once — don't re-prompt after a submit or a dismissal. A failed
    // send keeps the prompt so the student can retry.
    if (!sendFailed && mounted) {
      setState(() => _ctrl.markCaseReviewed(c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (_) {
        // The case can disappear from the list mid-session (e.g. its local id
        // is swapped for the server id after a remote create), so look it up
        // null-safely instead of crashing with a StateError.
        final c = _ctrl.cases.firstWhereOrNull((e) => e.id == widget.caseId);
        if (c == null) {
          return Scaffold(
            backgroundColor: KpbColors.canvas,
            appBar: AppBar(
              backgroundColor: KpbColors.canvas,
              surfaceTintColor: KpbColors.canvas,
              elevation: 0,
              title: Text('case_not_found_title'.tr),
              leading: IconButton(
                tooltip: 'a11y_back'.tr,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Get.back(),
              ),
            ),
            body: KpbEmptyState(
              icon: Icons.folder_off_outlined,
              title: 'case_not_found_body_title'.tr,
              subtitle: 'case_not_found_subtitle'.tr,
              actionLabel: 'case_not_found_action'.tr,
              onAction: () {
                _ctrl.goToTab(StudentShellTab.cases);
                if (Get.key.currentState?.canPop() ?? false) {
                  Get.back();
                }
              },
            ),
          );
        }

        final steps = buildCaseTimelineSteps(
          currentStatus: c.status,
          events: c.timeline,
          assignedAdvisorName: c.assignedAdvisorName,
        );
        final progress = caseTimelineProgress(c.status);

        final docs = c.documentRequests;
        final docsDone = docs.where((d) => d.isProvided).length;

        return Scaffold(
          backgroundColor: KpbColors.canvas,
          body: SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                // ── Header : back · flag · institution · program · ring ──────
                _DossierHeader(
                  ctrl: _ctrl,
                  studentCase: c,
                  progress: progress,
                ),
                const SizedBox(height: 14),

                // ── Decision received → honest "plan B" surface ──────────────
                // Real entry point for the post-decision screen (Notifications
                // isn't built yet): only when the case is genuinely rejected.
                if (c.status == CaseStatus.rejected) ...[
                  _NavCard(
                    icon: Icons.flag_rounded,
                    iconColor: KpbColors.error,
                    iconBg: KpbColors.errorLight,
                    title: 'post_decision_entry_title'.tr,
                    subtitle: 'post_decision_entry_subtitle'.tr,
                    onTap: () => Get.to(() => PostDecisionScreen(caseId: c.id)),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Admission-milestone review prompt (KPB-75) ───────────────
                if (c.status == CaseStatus.completed &&
                    c.counsellorId != null &&
                    !_ctrl.hasReviewedCase(c.id)) ...[
                  _ReviewPromptCard(
                    onLater: () => setState(() => _ctrl.markCaseReviewed(c.id)),
                    onReview: () => _promptReview(c),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Offline banner ───────────────────────────────────────────
                if (!ConnectivityService.instance.isOnline) ...[
                  const _OfflineBanner(),
                  const SizedBox(height: 14),
                ],

                // ── Next step (real: c.nextStep*) ────────────────────────────
                _NextStepCard(
                  label: 'next_step'.tr,
                  title: _ctrl.resolve(c.nextStepTitle),
                  description: _ctrl.resolve(c.nextStepDescription),
                ),
                const SizedBox(height: 14),

                // ── Step checklist (status-driven, real timeline) ────────────
                _SectionLabel('case_steps_heading'.tr),
                const SizedBox(height: 8),
                CaseStatusTimeline(steps: steps),
                const SizedBox(height: 14),

                // ── Photo / PDF tip (honest: app compresses, no OCR/scan) ────
                // Ce conseil décrit une compression que l'app n'applique plus à
                // rien tant que l'envoi est masqué (M2) : il partirait donc
                // décrire une mécanique inexistante.
                if (AppConfig.documentUploadEnabled) ...[
                  _InfoTip(
                    icon: Icons.photo_camera_rounded,
                    text: 'case_document_photo_tip'.tr,
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Interview simulator (masqué par M1) ──────────────────────
                if (AppConfig.aiToolsEnabled) ...[
                  _NavCard(
                    icon: Icons.mic_rounded,
                    iconColor: KpbColors.warning,
                    iconBg: KpbColors.warningLight,
                    title: 'case_interview_sim_title'.tr,
                    subtitle: 'case_interview_sim_subtitle'.tr,
                    onTap: () => openAiToolIfConsented(
                      context,
                      () => const InterviewSimulatorScreen(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Documents ────────────────────────────────────────────────
                if (docs.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SectionLabel('case_section_documents'.tr),
                      ),
                      Text(
                        'home_case_documents_ratio'.trParams(
                            {'done': '$docsDone', 'total': '${docs.length}'}),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DocumentsCard(
                    docs: docs,
                    ctrl: _ctrl,
                    // M2 : tant que l'envoi en app est masqué, le bouton ne
                    // disparaît pas — il change de destination. Un document
                    // qu'un conseiller a réellement demandé doit rester
                    // envoyable, sinon ce jalon devient l'impasse que ce lot est
                    // censé supprimer.
                    uploadEnabled: AppConfig.documentUploadEnabled,
                    onUpload: (doc) => AppConfig.documentUploadEnabled
                        ? _promptUpload(c.id, doc)
                        : _sendDocumentViaWhatsApp(c, doc),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── AI document review (masqué par M1) ───────────────────────
                if (AppConfig.aiToolsEnabled) ...[
                  _NavCard(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: KpbColors.actionPrimary,
                    iconBg: KpbColors.actionPrimarySoft,
                    title: 'case_ai_review_cta'.tr,
                    subtitle: 'case_ai_review_subtitle'.tr,
                    onTap: () => openAiToolIfConsented(
                      context,
                      () => const DocumentReviewScreen(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Advisor ──────────────────────────────────────────────────
                if (c.assignedAdvisorName != null) ...[
                  _AdvisorCard(
                    name: c.assignedAdvisorName!,
                    onWhatsapp: () => _openWhatsapp(
                      advisorName: c.assignedAdvisorName,
                      prefill: c.isReferenceProvisional
                          ? 'case_whatsapp_advisor_prefill_provisional'
                              .trParams({'title': _ctrl.resolve(c.title)})
                          : 'case_whatsapp_advisor_prefill'
                              .trParams({'reference': c.referenceCode}),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── WhatsApp CTA (official KPB line; verified-advisor gate) ───
                _GreenWhatsAppCta(
                  onTap: () => _openWhatsapp(
                    advisorName: c.assignedAdvisorName,
                    prefill: c.isReferenceProvisional
                        ? 'case_whatsapp_continue_prefill_provisional'
                            .trParams({'title': _ctrl.resolve(c.title)})
                        : 'case_whatsapp_continue_prefill'
                            .trParams({'reference': c.referenceCode}),
                  ),
                ),
                const SizedBox(height: 10),
                const KpbAntiFraudNotice(source: 'case_detail'),
                const SizedBox(height: 14),

                // ── Prepare application package ──────────────────────────────
                _NavCard(
                  icon: Icons.assignment_turned_in_rounded,
                  iconColor: KpbColors.actionPrimary,
                  iconBg: KpbColors.actionPrimarySoft,
                  title: 'case_prepare_package_title'.tr,
                  subtitle: 'case_prepare_package_subtitle'.tr,
                  onTap: () => Get.to(
                    () => ServicePackagesScreen(
                      caseId: c.id,
                      caseReference: c.referenceCode,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Share with a parent (opt-in, per case) ───────────────────
                _ParentShareCard(
                  value: c.parentCanView,
                  onChanged: (v) => _ctrl.setCaseParentVisibility(c.id, v),
                ),
                const SizedBox(height: 14),

                // ── History ──────────────────────────────────────────────────
                if (c.timeline.isNotEmpty) ...[
                  _SectionLabel('case_section_history'.tr),
                  const SizedBox(height: 8),
                  Container(
                    decoration: _cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: c.timeline.asMap().entries.map((e) {
                        return _TimelineItem(
                          event: e.value,
                          isLast: e.key == c.timeline.length - 1,
                          ctrl: _ctrl,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Messages ─────────────────────────────────────────────────
                _SectionLabel(
                  '${'case_section_messages'.tr}${c.messages.isNotEmpty ? ' (${c.messages.length})' : ''}${_ctrl.unreadMessagesForCase(c.id) > 0 ? ' · ${_ctrl.unreadMessagesForCase(c.id)} ${'case_unread_suffix'.tr}' : ''}',
                ),
                const SizedBox(height: 8),
                if (c.messages.isEmpty)
                  Container(
                    decoration: _cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: KpbEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'no_messages'.tr,
                      subtitle: 'send_message_hint'.tr,
                    ),
                  )
                else
                  Column(
                    children: c.messages
                        .map((msg) => _MessageBubble(msg: msg, ctrl: _ctrl))
                        .toList(),
                  ),
                const SizedBox(height: 8),

                // ── Typing indicator ─────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _ctrl.isCaseAdvisorTyping
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            key: const ValueKey('typing'),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: KpbColors.surface,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                                bottomLeft: Radius.circular(4),
                              ),
                              border: Border.all(color: KpbColors.border),
                              boxShadow: _cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                _TypingDot(delay: Duration.zero),
                                SizedBox(width: 4),
                                _TypingDot(delay: Duration(milliseconds: 200)),
                                SizedBox(width: 4),
                                _TypingDot(delay: Duration(milliseconds: 400)),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-typing')),
                ),

                // ── Message input ────────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: KpbColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KpbColors.border),
                    boxShadow: _cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'message_input_hint'.tr,
                            hintStyle:
                                const TextStyle(color: KpbColors.textFaint),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                          ),
                          onChanged: (value) {
                            _ctrl.sendCaseTyping(c.id, value.isNotEmpty);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'a11y_send_message'.tr,
                        child: GestureDetector(
                          onTap: () {
                            final text = _messageController.text.trim();
                            if (text.isEmpty) return;
                            _ctrl.addCaseMessage(c.id, text);
                            _messageController.clear();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: KpbColors.actionPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
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

BoxDecoration _cardDecoration() => BoxDecoration(
      color: KpbColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: KpbColors.border),
      boxShadow: _cardShadow,
    );

({String label, Color bg, Color fg}) _statusPill(CaseStatus status) {
  switch (status) {
    case CaseStatus.submitted:
      return (
        label: 'status_submitted'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.underReview:
      return (
        label: 'status_under_review'.tr,
        bg: KpbColors.warningLight,
        fg: KpbColors.warning
      );
    case CaseStatus.documentsNeeded:
      return (
        label: 'status_documents_needed'.tr,
        bg: KpbColors.warningLight,
        fg: KpbColors.warning
      );
    case CaseStatus.counselorAssigned:
      return (
        label: 'status_counselor_assigned'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.awaitingStudent:
      return (
        label: 'status_awaiting_student'.tr,
        bg: KpbColors.errorLight,
        fg: KpbColors.error
      );
    case CaseStatus.scheduled:
      return (
        label: 'status_scheduled'.tr,
        bg: KpbColors.successLight,
        fg: KpbColors.success
      );
    case CaseStatus.inProgress:
      return (
        label: 'status_in_progress'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.applicationSubmitted:
      return (
        label: 'status_application_submitted'.tr,
        bg: KpbColors.actionPrimarySoft,
        fg: KpbColors.actionPrimary
      );
    case CaseStatus.waitingDecision:
      return (
        label: 'status_waiting_decision'.tr,
        bg: KpbColors.warningLight,
        fg: KpbColors.warning
      );
    case CaseStatus.awaitingPayment:
      return (
        label: 'status_awaiting_payment'.tr,
        bg: KpbColors.errorLight,
        fg: KpbColors.error
      );
    case CaseStatus.completed:
      return (
        label: 'status_completed'.tr,
        bg: KpbColors.successLight,
        fg: KpbColors.success
      );
    case CaseStatus.rejected:
      return (
        label: 'status_rejected'.tr,
        bg: KpbColors.errorLight,
        fg: KpbColors.error
      );
    case CaseStatus.cancelled:
      return (
        label: 'status_cancelled'.tr,
        bg: KpbColors.surfaceMuted,
        fg: KpbColors.textMuted
      );
    case CaseStatus.draft:
      return (
        label: 'status_draft'.tr,
        bg: KpbColors.surfaceMuted,
        fg: KpbColors.textMuted
      );
  }
}
