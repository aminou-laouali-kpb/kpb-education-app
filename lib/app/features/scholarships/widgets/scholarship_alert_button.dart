import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/repositories/app_api_client.dart';
import '../../../core/services/push_service.dart';

class ScholarshipAlertButton extends StatefulWidget {
  const ScholarshipAlertButton({
    super.key,
    required this.scholarshipId,
    required this.scholarshipTitle,
    required this.initialEnabled,
    required this.onChanged,
    this.apiClient,
    this.compact = false,
  });

  final String scholarshipId;
  final String scholarshipTitle;
  final bool initialEnabled;
  final ValueChanged<bool> onChanged;
  final AppApiClient? apiClient;
  final bool compact;

  @override
  State<ScholarshipAlertButton> createState() => _ScholarshipAlertButtonState();
}

class _ScholarshipAlertButtonState extends State<ScholarshipAlertButton> {
  late bool _enabled = widget.initialEnabled;
  bool _pending = false;

  @override
  void didUpdateWidget(covariant ScholarshipAlertButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pending && oldWidget.initialEnabled != widget.initialEnabled) {
      _enabled = widget.initialEnabled;
    }
  }

  Future<void> _toggle() async {
    if (_pending) return;
    final next = !_enabled;
    setState(() {
      _enabled = next;
      _pending = true;
    });
    widget.onChanged(next);
    final client = widget.apiClient ?? AppApiClient();
    try {
      if (next) {
        await client.subscribeScholarshipAlert(widget.scholarshipId);
        await PushService.instance.requestPermission();
      } else {
        await client.unsubscribeScholarshipAlert(widget.scholarshipId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _enabled = !next);
      widget.onChanged(!next);
      Get.snackbar(
        'scholarships_title'.tr,
        'live_scholarships_alert_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = KpbColors.actionPrimary;
    final blueBorder = KpbColors.actionPrimary.withValues(alpha: 0.3);
    const green = KpbColors.success;
    const greenBg = KpbColors.successLight;
    final label = _enabled
        ? 'live_scholarships_alert_enabled'.tr
        : 'live_scholarships_alert'.tr;
    final foreground = _enabled ? green : blue;
    final background = _enabled ? greenBg : Colors.white;

    return Semantics(
      button: true,
      toggled: _enabled,
      label: '$label — ${widget.scholarshipTitle}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(widget.compact ? 100 : 16),
        child: InkWell(
          onTap: _pending ? null : _toggle,
          borderRadius: BorderRadius.circular(widget.compact ? 100 : 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.compact ? 42 : 48,
              minWidth: widget.compact ? 42 : 48,
            ),
            child: Ink(
              decoration: BoxDecoration(
                border: Border.all(color: _enabled ? green : blueBorder),
                borderRadius: BorderRadius.circular(widget.compact ? 100 : 16),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 9 : 14,
                vertical: widget.compact ? 8 : 12,
              ),
              child: Row(
                mainAxisSize:
                    widget.compact ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_pending)
                    SizedBox(
                      width: widget.compact ? 14 : 17,
                      height: widget.compact ? 14 : 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    Icon(
                      _enabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      size: widget.compact ? 15 : 18,
                      color: foreground,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: widget.compact ? 10 : 13.5,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
