import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/community.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/community_store.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/kpb_toast.dart';
import '../../../core/ui/kpb_haptics.dart';
import '../../../core/utils/community_mention_tokens.dart';
import 'community_format.dart';

/// Signaler une publication, une réponse ou un membre (motifs du contrat).
/// Rend vrai quand le signalement est parti. Signaler reste permis sans
/// charte et sous sanction (contrat §6.4).
Future<bool> showCommunityReportSheet(
  BuildContext context, {
  required CommunityReportTarget target,
  required String targetId,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: KpbColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KpbRadius.lg)),
    ),
    builder: (_) => CommunityReportSheet(target: target, targetId: targetId),
  );
  return sent ?? false;
}

class CommunityReportSheet extends StatefulWidget {
  const CommunityReportSheet({
    super.key,
    required this.target,
    required this.targetId,
  });

  final CommunityReportTarget target;
  final String targetId;

  @override
  State<CommunityReportSheet> createState() => _CommunityReportSheetState();
}

class _CommunityReportSheetState extends State<CommunityReportSheet> {
  CommunityReportReason? _reason;
  final TextEditingController _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String get _title => switch (widget.target) {
        CommunityReportTarget.post => 'comm_report_post_title'.tr,
        CommunityReportTarget.reply => 'comm_report_reply_title'.tr,
        CommunityReportTarget.member => 'comm_report_member_title'.tr,
      };

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _sending = true);
    try {
      await CommunityStore.instance.api.reportCommunity(
        target: widget.target,
        targetId: widget.targetId,
        reason: reason,
        details: _details.text,
      );
      unawaited(AnalyticsService.instance.logCommunityReportSent(
        target: widget.target.wire,
        reason: reason.wire,
      ));
      unawaited(KpbHaptics.success());
      if (!mounted) return;
      Navigator.of(context).pop(true);
      KpbToast.success('comm_report_sent'.tr);
    } on CommunityException catch (error) {
      CommunityStore.instance.noteFailure(error);
      if (!mounted) return;
      setState(() => _sending = false);
      KpbToast.error(communityFailureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                KpbSpacing.page, KpbSpacing.md, KpbSpacing.page, KpbSpacing.md),
            children: [
              Semantics(
                header: true,
                child: Text(_title, style: KpbTextStyles.title),
              ),
              const SizedBox(height: 4),
              Text('comm_report_intro'.tr, style: KpbTextStyles.bodySm),
              const SizedBox(height: KpbSpacing.sm),
              RadioGroup<CommunityReportReason>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(
                  children: [
                    for (final reason in CommunityReportReason.values)
                      RadioListTile<CommunityReportReason>(
                        key: ValueKey<String>('comm-report-${reason.wire}'),
                        value: reason,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          communityReportReasonLabel(reason),
                          style: KpbTextStyles.titleSm,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              TextField(
                controller: _details,
                maxLength: CommunityLimitsSpec.reportDetailsMax,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'comm_report_details_label'.tr,
                  hintText: 'comm_report_details_hint'.tr,
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              FilledButton(
                key: const ValueKey<String>('comm-report-send'),
                onPressed: _reason == null || _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('comm_report_send'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirme puis bloque [author]. Rend vrai si le membre est bloqué.
Future<bool> confirmAndBlockCommunityMember(
  BuildContext context,
  CommunityAuthor author,
) async {
  final memberId = author.memberId;
  if (memberId == null || author.isTeam) {
    KpbToast.info('comm_err_block_team'.tr);
    return false;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
          'comm_block_confirm_title'.trParams({'name': author.displayName})),
      content: Text('comm_block_confirm_body'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('cancel'.tr),
        ),
        TextButton(
          key: const ValueKey<String>('comm-block-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('comm_block_action'.tr),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    final blocked =
        await CommunityStore.instance.setBlocked(memberId, blocked: true);
    unawaited(
        AnalyticsService.instance.logCommunityBlockToggled(enabled: true));
    KpbToast.success('comm_block_done'.trParams({'name': author.displayName}));
    return blocked;
  } on CommunityException catch (error) {
    KpbToast.error(communityFailureMessage(error));
    return false;
  }
}
