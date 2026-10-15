import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/ai_content_report_service.dart';
import '../app_tokens.dart';
import 'kpb_toast.dart';

Future<void> showAiContentReportSheet({
  required BuildContext context,
  required AiContentSurface surface,
  required String generatedText,
  String? sourceReference,
  AiContentReportService? service,
}) async {
  final receipt = await showModalBottomSheet<AiContentReportReceipt>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AiContentReportSheet(
      surface: surface,
      generatedText: generatedText,
      sourceReference: sourceReference,
      service: service ?? AiContentReportService(),
    ),
  );
  if (receipt == null) return;
  KpbToast.success(
    'ai_report_success_body'.trParams({'code': receipt.referenceCode}),
    title: 'ai_report_success_title'.tr,
  );
}

class _AiContentReportSheet extends StatefulWidget {
  const _AiContentReportSheet({
    required this.surface,
    required this.generatedText,
    required this.service,
    this.sourceReference,
  });

  final AiContentSurface surface;
  final String generatedText;
  final String? sourceReference;
  final AiContentReportService service;

  @override
  State<_AiContentReportSheet> createState() => _AiContentReportSheetState();
}

class _AiContentReportSheetState extends State<_AiContentReportSheet> {
  final _noteController = TextEditingController();
  String? _reason;
  String? _error;
  bool _submitting = false;

  static const _reasons = <(String, String)>[
    (AiContentReportReason.inaccurate, 'ai_report_reason_inaccurate'),
    (AiContentReportReason.unsafe, 'ai_report_reason_unsafe'),
    (AiContentReportReason.offensive, 'ai_report_reason_offensive'),
    (AiContentReportReason.privacy, 'ai_report_reason_privacy'),
    (AiContentReportReason.other, 'ai_report_reason_other'),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await widget.service.submit(
        surface: widget.surface,
        generatedText: widget.generatedText,
        reason: reason,
        sourceReference: widget.sourceReference,
        reporterNote: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(receipt);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'ai_report_submit_error'.tr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: KpbColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ai_report_title'.tr,
                    style: KpbTextStyles.titleMd,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ai_report_body'.tr,
              style: KpbTextStyles.bodySm.copyWith(
                color: KpbColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text('ai_report_reason_label'.tr, style: KpbTextStyles.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((item) {
                return ChoiceChip(
                  label: Text(item.$2.tr),
                  selected: _reason == item.$1,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _reason = item.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              enabled: !_submitting,
              maxLength: AiContentReportService.maxReporterNoteLength,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'ai_report_note_label'.tr,
                hintText: 'ai_report_note_hint'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: KpbColors.error, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: _reason == null || _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _submitting ? 'ai_report_submitting'.tr : 'ai_report_submit'.tr,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
